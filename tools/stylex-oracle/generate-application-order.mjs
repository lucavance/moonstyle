import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { runInNewContext } from 'node:vm';
import {
  APPLICATION_ORDER_METADATA_FILE,
  APPLICATION_ORDER_LOCK_FILE,
  APPLICATION_ORDER_MOONBIT_FILE,
  APPLICATION_ORDER_PROFILE,
  APPLICATION_ORDER_PRIORITY_SCALE,
  APPLICATION_ORDER_LOCAL_EXTENSIONS,
  APPLICATION_ORDER_SUPPLEMENTAL_PROPERTIES,
  APPLICATION_ORDER_OPTIONS,
  APPLICATION_ORDER_RELATIONAL_SELECTORS,
  APPLICATION_ORDER_TYPED_SELECTOR_PSEUDOS,
  applicationOrderDigest,
  applicationOrderInputDigest,
  applicationOrderPriority100,
  readApplicationOrderJson,
  readApplicationOrderLock,
  renderApplicationOrderMoonbit,
  validateApplicationOrderLock,
  writeApplicationOrderFile,
} from '../../verification/application-order.mjs';
import {
  ORACLE_PACKAGE_VERSIONS,
  STYLEX_RELEASE_COMMIT,
  STYLEX_RELEASE_TAG,
  assertOracleReleaseContract,
} from './release-contract.mjs';

const oracleRoot = import.meta.dirname;

export function ensureOracleDependencies() {
  const manifest = readApplicationOrderJson(path.join(oracleRoot, 'package.json'));
  const versions = {};
  for (const [packageName, expected] of Object.entries(ORACLE_PACKAGE_VERSIONS)) {
    const filename = path.join(oracleRoot, 'node_modules', packageName, 'package.json');
    if (!fs.existsSync(filename)) {
      throw new Error(
        `StyleX oracle dependency ${packageName} is missing; run vp -C tools/stylex-oracle install --frozen-lockfile`,
      );
    }
    const installed = readApplicationOrderJson(filename).version;
    if (manifest.devDependencies?.[packageName] !== expected || installed !== expected) {
      throw new Error(
        `StyleX oracle requires ${packageName} exact-pinned to ${expected}, found manifest ${manifest.devDependencies?.[packageName]} and installed ${installed}; run vp -C tools/stylex-oracle install --frozen-lockfile`,
      );
    }
    versions[packageName] = installed;
  }
  return versions;
}

export function ensureOracleReleaseContract({ checkCommittedLock = true } = {}) {
  ensureOracleDependencies();
  const manifest = readApplicationOrderJson(path.join(oracleRoot, 'package.json'));
  const lockFilename = path.join(oracleRoot, 'bun.lock');
  const lockText = fs.existsSync(lockFilename) ? fs.readFileSync(lockFilename, 'utf8') : null;
  const contract = assertOracleReleaseContract({ manifest, lockText });
  if (checkCommittedLock) {
    const metadata = readApplicationOrderJson(APPLICATION_ORDER_METADATA_FILE);
    readApplicationOrderLock(metadata);
  }
  return contract;
}

export function evaluateApplicationOrderOracle(code) {
  const withoutImport = code.replace(/^import[^;]+;\s*/, '');
  if (withoutImport === code) {
    throw new Error('StyleX oracle output did not contain the expected import');
  }
  const executable = withoutImport.replace(
    'export const applicationOrderOracle =',
    'const applicationOrderOracle =',
  );
  if (executable === withoutImport) {
    throw new Error('StyleX oracle output did not contain the expected export');
  }
  // The input is generated locally and Babel has reduced it to a data-only object.
  return runInNewContext(`${executable}\napplicationOrderOracle;`, Object.create(null), {
    timeout: 1_000,
  });
}

export async function generateApplicationOrder({ write = true } = {}) {
  // Refresh can repair a missing or stale semantic lock, but only with the
  // reviewed compiler graph. Validate that graph before loading the compiler.
  ensureOracleReleaseContract({ checkCommittedLock: false });
  const versions = ORACLE_PACKAGE_VERSIONS;
  const { AT_RULE_PRIORITIES, PSEUDO_CLASS_PRIORITIES, PSEUDO_ELEMENT_PRIORITY } =
    await import('@stylexjs/shared');
  const { compileStylexSource } = await import('./stylex-compiler.mjs');
  const metadata = readApplicationOrderJson(APPLICATION_ORDER_METADATA_FILE);
  const properties = metadata.properties.map((property) => property.irName);
  if (properties.length !== 392 || new Set(properties).size !== properties.length) {
    throw new Error('application-order oracle requires exactly 392 unique IR properties');
  }
  if (APPLICATION_ORDER_SUPPLEMENTAL_PROPERTIES.some((property) => properties.includes(property))) {
    throw new Error('supplemental oracle properties must be outside the typed property surface');
  }
  const allProperties = [...properties, ...APPLICATION_ORDER_SUPPLEMENTAL_PROPERTIES];
  const namespaces = allProperties
    .map(
      (property, index) =>
        `  p${String(index).padStart(3, '0')}: { ${JSON.stringify(property)}: 'inherit' }`,
    )
    .join(',\n');
  const relationalFixtureInputs = APPLICATION_ORDER_RELATIONAL_SELECTORS.flatMap(
    ([relation, method]) => [
      ...APPLICATION_ORDER_TYPED_SELECTOR_PSEUDOS.map((selector) => ({
        relation,
        method,
        stateKind: selector.includes('(') ? 'functional' : 'pseudo',
        selector,
      })),
      { relation, method, stateKind: 'attribute', selector: '[aria-expanded="true"]' },
      { relation, method, stateKind: 'compound', selector: ':hover:active' },
    ],
  ).map((fixture, index) => ({
    ...fixture,
    namespace: `r${String(index).padStart(3, '0')}`,
  }));
  const relationalNamespaces = relationalFixtureInputs
    .map(
      (fixture) =>
        `  ${fixture.namespace}: { color: { [stylex.when.${fixture.method}(${JSON.stringify(
          fixture.selector,
        )})]: 'inherit' } }`,
    )
    .join(',\n');
  const containerNamespace =
    "  containerPriority: { color: { '@container (min-width: 1px)': 'inherit' } }";
  const source = [
    "import * as stylex from '@stylexjs/stylex';",
    'export const applicationOrderOracle = stylex.create({',
    [namespaces, relationalNamespaces, containerNamespace].join(',\n'),
    '});',
    '',
  ].join('\n');
  const compiled = compileStylexSource(source, APPLICATION_ORDER_OPTIONS);
  const styles = evaluateApplicationOrderOracle(compiled.code);
  const rules = new Map(
    compiled.rules.map(([className, css, priority]) => [className, { css, priority }]),
  );
  const slotOwners = new Map();
  const rawProperties = allProperties.map((property, index) => {
    const namespaceName = `p${String(index).padStart(3, '0')}`;
    const entries = Object.entries(styles[namespaceName]).filter(([key]) => !key.startsWith('$$'));
    const live = entries.filter(([, value]) => value !== null);
    if (live.length !== 1 || typeof live[0][1] !== 'string') {
      throw new Error(`${property} did not compile to exactly one live application-order entry`);
    }
    const [classSlot, className] = live[0];
    const rule = rules.get(className);
    if (!rule) throw new Error(`${property} emitted class ${className} without a rule`);
    const owners = slotOwners.get(classSlot) ?? [];
    owners.push(property);
    slotOwners.set(classSlot, owners);
    return { property, entries, className, rule };
  });
  const oracleProperties = rawProperties.map(({ property, entries, className, rule }) => ({
    property,
    priority100: applicationOrderPriority100(rule.priority),
    entries: entries.map(([slot, value]) => ({
      slot,
      role: value === null ? 'tombstone' : 'class',
      slotProperties: slotOwners.get(slot) ?? [],
    })),
    css: {
      ltr: rule.css.ltr.replaceAll(className, '<CLASS>'),
      rtl: rule.css.rtl?.replaceAll(className, '<CLASS>') ?? null,
    },
  }));
  const profile = {
    name: APPLICATION_ORDER_PROFILE,
    stylexVersion: versions['@stylexjs/stylex'],
    babelPluginVersion: versions['@stylexjs/babel-plugin'],
    sharedVersion: versions['@stylexjs/shared'],
    options: APPLICATION_ORDER_OPTIONS,
  };
  const conditionPriorities = {
    pseudoClasses: PSEUDO_CLASS_PRIORITIES,
    pseudoElement: PSEUDO_ELEMENT_PRIORITY,
    atRules: AT_RULE_PRIORITIES,
  };
  const colorPriority100 = oracleProperties.find(
    (property) => property.property === 'color',
  )?.priority100;
  if (colorPriority100 === undefined) {
    throw new Error('application-order oracle did not contain the color property');
  }
  const relationalFixtures = relationalFixtureInputs.map((fixture) => {
    const entries = Object.entries(styles[fixture.namespace]).filter(
      ([key]) => !key.startsWith('$$'),
    );
    const live = entries.filter(([, value]) => value !== null);
    if (live.length !== 1 || typeof live[0][1] !== 'string') {
      throw new Error(`${fixture.namespace} did not compile to one relational rule`);
    }
    const className = live[0][1];
    const rule = rules.get(className);
    if (!rule) throw new Error(`${fixture.namespace} emitted ${className} without a rule`);
    return {
      relation: fixture.relation,
      stateKind: fixture.stateKind,
      selector: fixture.selector,
      priority100: applicationOrderPriority100(rule.priority),
      css: rule.css.ltr.replaceAll(className, '<CLASS>'),
    };
  });
  const relationalSelectors100 = Object.fromEntries(
    APPLICATION_ORDER_RELATIONAL_SELECTORS.map(([relation]) => {
      const hover = relationalFixtures.find(
        (fixture) =>
          fixture.relation === relation &&
          fixture.stateKind === 'pseudo' &&
          fixture.selector === ':hover',
      );
      if (!hover) throw new Error(`missing ${relation}(:hover) oracle fixture`);
      return [
        relation,
        hover.priority100 - colorPriority100 - (PSEUDO_CLASS_PRIORITIES[':hover'] ?? 40),
      ];
    }),
  );
  const fallbackPriorities = new Set(
    relationalFixtures
      .filter((fixture) => fixture.stateKind !== 'pseudo')
      .map((fixture) => fixture.priority100 - colorPriority100),
  );
  if (fallbackPriorities.size !== 1) {
    throw new Error('StyleX attribute and compound relational priorities diverged');
  }
  const relationalFallback100 = [...fallbackPriorities][0];
  for (const fixture of relationalFixtures.filter(
    (candidate) => candidate.stateKind === 'pseudo',
  )) {
    const expected =
      colorPriority100 +
      relationalSelectors100[fixture.relation] +
      (PSEUDO_CLASS_PRIORITIES[fixture.selector] ?? 40);
    if (fixture.priority100 !== expected) {
      throw new Error(
        `${fixture.relation}(${fixture.selector}) priority changed: expected ${expected}, received ${fixture.priority100}`,
      );
    }
  }
  conditionPriorities.relationalSelectors100 = relationalSelectors100;
  conditionPriorities.relationalFallback100 = relationalFallback100;
  const containerEntries = Object.entries(styles.containerPriority).filter(
    ([key]) => !key.startsWith('$$'),
  );
  const containerLive = containerEntries.filter(([, value]) => value !== null);
  if (containerLive.length !== 1 || typeof containerLive[0][1] !== 'string') {
    throw new Error('container priority fixture did not compile to one rule');
  }
  const containerClassName = containerLive[0][1];
  const containerRule = rules.get(containerClassName);
  if (!containerRule) throw new Error('container priority fixture emitted no rule');
  const conditionFixtures = {
    container: {
      query: '@container (min-width: 1px)',
      priority100: applicationOrderPriority100(containerRule.priority),
      css: containerRule.css.ltr.replaceAll(containerClassName, '<CLASS>'),
    },
    relational: relationalFixtures,
  };
  const semanticContent = {
    priorityScale: APPLICATION_ORDER_PRIORITY_SCALE,
    profile,
    inputDigest: applicationOrderInputDigest(metadata),
    conditionPriorities,
    conditionFixtures,
    properties: oracleProperties.slice(0, properties.length),
    supplementalProperties: oracleProperties.slice(properties.length),
    localExtensions: APPLICATION_ORDER_LOCAL_EXTENSIONS,
  };
  const lock = {
    schemaVersion: 4,
    ...semanticContent,
    semanticsDigest: applicationOrderDigest(JSON.stringify(semanticContent)),
  };
  validateApplicationOrderLock(lock, metadata);
  const moonbit = renderApplicationOrderMoonbit(lock);
  if (write) {
    writeApplicationOrderFile(APPLICATION_ORDER_LOCK_FILE, `${JSON.stringify(lock, null, 2)}\n`);
    writeApplicationOrderFile(APPLICATION_ORDER_MOONBIT_FILE, moonbit);
    console.log(
      `Generated ${properties.length} typed and ${APPLICATION_ORDER_SUPPLEMENTAL_PROPERTIES.length} supplemental StyleX application-order semantic records (${lock.semanticsDigest}).`,
    );
  }
  return lock;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  Promise.resolve()
    .then(() => {
      if (process.argv.includes('--check-release')) {
        const contract = ensureOracleReleaseContract();
        console.log(
          `Verified StyleX ${STYLEX_RELEASE_TAG} oracle release contract. Recorded source commit: ${STYLEX_RELEASE_COMMIT}.`,
        );
        return contract;
      }
      if (process.argv.includes('--check-dependencies')) {
        ensureOracleDependencies();
        console.log('Verified isolated StyleX oracle dependencies.');
        return;
      }
      return generateApplicationOrder();
    })
    .catch((error) => {
      console.error(error.stack ?? error);
      process.exitCode = 1;
    });
}
