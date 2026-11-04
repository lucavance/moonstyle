import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const APPLICATION_ORDER_METADATA_FILE = path.join(
  root,
  'src/properties/property-metadata.json',
);
export const APPLICATION_ORDER_LOCK_FILE = path.join(root, 'src/core/application-order.lock.json');
export const APPLICATION_ORDER_MOONBIT_FILE = path.join(
  root,
  'src/core/application_order.generated.mbt',
);

export const APPLICATION_ORDER_PROFILE = 'stylex-0.19.1-application-order+font-aliases-v1';
export const APPLICATION_ORDER_PRIORITY_SCALE = 100;
export const APPLICATION_ORDER_LOCAL_EXTENSIONS = Object.freeze({
  conflictSlotAliases: Object.freeze({ fontWidth: 'fontStretch' }),
});
export const APPLICATION_ORDER_SUPPLEMENTAL_PROPERTIES = Object.freeze(['font']);
export const APPLICATION_ORDER_OPTIONS = Object.freeze({
  dev: false,
  enableLegacyValueFlipping: false,
  enableLogicalStylesPolyfill: false,
  runtimeInjection: false,
  styleResolution: 'application-order',
  useLayers: false,
});

export const APPLICATION_ORDER_RELATIONAL_SELECTORS = Object.freeze([
  ['ancestor', 'ancestor'],
  ['descendant', 'descendant'],
  ['any-sibling', 'anySibling'],
  ['sibling-before', 'siblingBefore'],
  ['sibling-after', 'siblingAfter'],
]);

export const APPLICATION_ORDER_TYPED_SELECTOR_PSEUDOS = Object.freeze([
  ':hover',
  ':focus',
  ':focus-visible',
  ':focus-within',
  ':active',
  ':disabled',
  ':enabled',
  ':checked',
  ':required',
  ':optional',
  ':read-only',
  ':read-write',
  ':placeholder-shown',
  ':first-child',
  ':last-child',
  ':only-child',
  ':empty',
  ':link',
  ':visited',
  ':valid',
  ':invalid',
  ':in-range',
  ':out-of-range',
  ':indeterminate',
  ':target',
  ':autofill',
  ':nth-child(2n+1)',
  ':nth-last-child(2n)',
  ':nth-of-type(3n)',
  ':nth-last-of-type(3n+1)',
  ':is(:hover,:focus)',
  ':not(:disabled)',
  ':where(:checked)',
]);

export function applicationOrderPriority100(value) {
  const scaled = Math.round(value * APPLICATION_ORDER_PRIORITY_SCALE);
  if (Math.abs(value * APPLICATION_ORDER_PRIORITY_SCALE - scaled) > Number.EPSILON * 1000) {
    throw new Error(`StyleX priority ${value} cannot be represented at scale 100`);
  }
  return scaled;
}

export function applicationOrderDigest(value) {
  return `sha256:${createHash('sha256').update(value).digest('hex')}`;
}

export function readApplicationOrderJson(filename) {
  return JSON.parse(fs.readFileSync(filename, 'utf8'));
}

export function writeApplicationOrderFile(filename, content) {
  fs.mkdirSync(path.dirname(filename), { recursive: true });
  const temporary = `${filename}.tmp`;
  fs.writeFileSync(temporary, content, 'utf8');
  fs.renameSync(temporary, filename);
}

function moonString(value) {
  return JSON.stringify(value);
}

function renderStringIntMatch(name, values, fallback) {
  const entries = Object.entries(values).sort(([left], [right]) => left.localeCompare(right));
  return [
    '///|',
    `pub fn ${name}(value : String) -> Int {`,
    '  match value {',
    ...entries.map(([key, priority]) => `    ${moonString(key)} => ${priority}`),
    `    _ => ${fallback}`,
    '  }',
    '}',
  ].join('\n');
}

// The lock preserves the upstream oracle verbatim. Only the effective tables
// apply our reviewed CSS alias policy; emitted CSS and class hashes stay intact.
export function effectiveApplicationOrderRecords(lock) {
  const records = [...lock.properties, ...lock.supplementalProperties];
  const byProperty = new Map(records.map((record) => [record.property, record]));
  const slotAliases = new Map();
  for (const [alias, canonical] of Object.entries(lock.localExtensions.conflictSlotAliases)) {
    const aliasEntries = byProperty.get(alias)?.entries.filter((entry) => entry.role === 'class');
    const canonicalEntries = byProperty
      .get(canonical)
      ?.entries.filter((entry) => entry.role === 'class');
    if (aliasEntries?.length !== 1 || canonicalEntries?.length !== 1) {
      throw new Error(`Conflict-slot alias ${alias} -> ${canonical} requires one live slot each`);
    }
    slotAliases.set(aliasEntries[0].slot, canonicalEntries[0].slot);
  }
  const effective = records.map((record) => ({
    ...record,
    entries: record.entries.map((entry) => ({
      ...entry,
      slot: slotAliases.get(entry.slot) ?? entry.slot,
    })),
  }));
  const slotOwners = new Map();
  for (const record of effective) {
    for (const entry of record.entries.filter((candidate) => candidate.role === 'class')) {
      const owners = slotOwners.get(entry.slot) ?? [];
      owners.push(record.property);
      slotOwners.set(entry.slot, owners);
    }
  }
  return effective.map((record) => ({
    ...record,
    entries: record.entries.map((entry) => ({
      ...entry,
      slotProperties: slotOwners.get(entry.slot) ?? [],
    })),
  }));
}

export function renderApplicationOrderMoonbit(lock) {
  const records = effectiveApplicationOrderRecords(lock);
  const priorityGroups = new Map();
  for (const property of records) {
    const properties = priorityGroups.get(property.priority100) ?? [];
    properties.push(property.property);
    priorityGroups.set(property.priority100, properties);
  }
  const priorityArms = [...priorityGroups.entries()]
    .sort(([left], [right]) => left - right)
    .map(
      ([priority, properties]) => `    ${properties.map(moonString).join(' | ')} => ${priority}`,
    );
  const entryArms = records.map((property) => {
    const entries = property.entries
      .map((entry) => `(${moonString(entry.slot)}, ${entry.role === 'class'})`)
      .join(', ');
    return `    ${moonString(property.property)} => [${entries}]`;
  });
  const migrationUnsafe = records
    .filter((property) => {
      if (Object.hasOwn(lock.localExtensions.conflictSlotAliases, property.property)) return true;
      if (property.entries.length !== 1) return true;
      const cssProperty = property.property.replace(
        /[A-Z]/g,
        (letter) => `-${letter.toLowerCase()}`,
      );
      return property.css.ltr !== `.<CLASS>{${cssProperty}:inherit}`;
    })
    .map((property) => property.property);
  const emittedAliases = records
    .map((property) => {
      const match = property.css.ltr.match(/^\.<CLASS>\{([^:;{}]+):inherit\}$/);
      if (!match) throw new Error(`${property.property} has a non-scalar oracle rule`);
      const emittedProperty = match[1].replace(/-([a-z])/g, (_, letter) => letter.toUpperCase());
      return [property.property, emittedProperty];
    })
    .filter(([property, emittedProperty]) => property !== emittedProperty);
  return `${[
    '// Generated by tools/generate-application-order.mbtx. Do not edit.',
    '',
    '///|',
    `pub let application_order_profile = ${moonString(lock.profile.name)}`,
    '',
    '///|',
    `pub let application_order_digest = ${moonString(lock.semanticsDigest)}`,
    '',
    '///|',
    `pub let application_order_priority_scale = ${lock.priorityScale}`,
    '',
    '///|',
    'pub fn application_order_priority100(property : String) -> Int {',
    '  if property.has_prefix("--") {',
    `    return ${lock.priorityScale}`,
    '  }',
    '  match property {',
    ...priorityArms,
    `    _ => ${3000 * lock.priorityScale}`,
    '  }',
    '}',
    '',
    '///|',
    'pub fn application_order_properties() -> Array[String] {',
    `  [${lock.properties.map((property) => moonString(property.property)).join(', ')}]`,
    '}',
    '',
    '///|',
    'pub fn application_order_emitted_property(property : String) -> String {',
    '  match property {',
    ...emittedAliases.map(
      ([property, emittedProperty]) =>
        `    ${moonString(property)} => ${moonString(emittedProperty)}`,
    ),
    '    _ => property',
    '  }',
    '}',
    '',
    '///|',
    'pub fn application_order_entries(property : String) -> Array[(String, Bool)] {',
    '  match property {',
    ...entryArms,
    '    _ => [(property, true)]',
    '  }',
    '}',
    '',
    '///|',
    'pub fn application_order_migration_safe(property : String) -> Bool {',
    '  match property {',
    `    ${migrationUnsafe.map(moonString).join(' | ')} => false`,
    '    _ => true',
    '  }',
    '}',
    '',
    renderStringIntMatch(
      'application_order_pseudo_priority100',
      Object.fromEntries(
        Object.entries(lock.conditionPriorities.pseudoClasses).map(([key, value]) => [
          key,
          value * lock.priorityScale,
        ]),
      ),
      40 * lock.priorityScale,
    ),
    '',
    '///|',
    'pub fn application_order_at_rule_priority100(value : String) -> Int {',
    ...Object.entries(lock.conditionPriorities.atRules)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(
        ([prefix, priority], index) =>
          `  ${index === 0 ? 'if' : '} else if'} value.has_prefix(${moonString(prefix)}) {\n    ${priority * lock.priorityScale}`,
      ),
    '  } else {',
    `    ${3000 * lock.priorityScale}`,
    '  }',
    '}',
    '',
    renderStringIntMatch(
      'application_order_relational_priority100',
      lock.conditionPriorities.relationalSelectors100,
      lock.conditionPriorities.relationalFallback100,
    ),
    '',
    '///|',
    `pub let application_order_relational_fallback_priority100 = ${lock.conditionPriorities.relationalFallback100}`,
    '',
    '///|',
    `pub let application_order_pseudo_element_priority100 = ${
      lock.conditionPriorities.pseudoElement * lock.priorityScale
    }`,
  ].join('\n')}\n`;
}

export function applicationOrderInputDigest(metadata) {
  return applicationOrderDigest(
    JSON.stringify({
      metadataSources: metadata.sources,
      properties: metadata.properties.map((property) => property.irName),
      value: 'inherit',
    }),
  );
}

export function validateApplicationOrderLock(lock, metadata) {
  const refresh =
    'run vp -C tools/stylex-oracle install --frozen-lockfile, then node tools/stylex-oracle/generate-application-order.mjs';
  if (!lock || typeof lock !== 'object' || Array.isArray(lock)) {
    throw new Error(`Application-order lock must be an object; ${refresh}`);
  }
  const { schemaVersion, semanticsDigest, ...semanticContent } = lock;
  if (
    schemaVersion !== 4 ||
    lock.priorityScale !== APPLICATION_ORDER_PRIORITY_SCALE ||
    lock.profile?.name !== APPLICATION_ORDER_PROFILE ||
    ['stylexVersion', 'babelPluginVersion', 'sharedVersion'].some(
      (key) => lock.profile[key] !== '0.19.1',
    ) ||
    JSON.stringify(lock.profile.options) !== JSON.stringify(APPLICATION_ORDER_OPTIONS) ||
    JSON.stringify(lock.localExtensions) !== JSON.stringify(APPLICATION_ORDER_LOCAL_EXTENSIONS) ||
    !Array.isArray(lock.properties) ||
    !Array.isArray(lock.supplementalProperties)
  ) {
    throw new Error(`Application-order lock has an unsupported semantic profile; ${refresh}`);
  }
  if (semanticsDigest !== applicationOrderDigest(JSON.stringify(semanticContent))) {
    throw new Error(`Application-order lock content digest is invalid; ${refresh}`);
  }
  if (
    [...lock.properties, ...lock.supplementalProperties].some(
      (record) =>
        !record ||
        typeof record.property !== 'string' ||
        !Number.isInteger(record.priority100) ||
        !Array.isArray(record.entries) ||
        record.entries.length === 0 ||
        record.entries.some(
          (entry) =>
            typeof entry?.slot !== 'string' || !['class', 'tombstone'].includes(entry.role),
        ) ||
        typeof record.css?.ltr !== 'string' ||
        !(record.css.rtl === null || typeof record.css.rtl === 'string'),
    )
  ) {
    throw new Error(`Application-order lock has malformed property records; ${refresh}`);
  }
  const properties = metadata.properties.map((property) => property.irName);
  if (
    lock.inputDigest !== applicationOrderInputDigest(metadata) ||
    properties.length !== 392 ||
    new Set(properties).size !== properties.length ||
    JSON.stringify(lock.properties.map((record) => record.property)) !==
      JSON.stringify(properties) ||
    JSON.stringify(lock.supplementalProperties.map((record) => record.property)) !==
      JSON.stringify(APPLICATION_ORDER_SUPPLEMENTAL_PROPERTIES)
  ) {
    throw new Error(`Application-order semantics are stale for the property metadata; ${refresh}`);
  }
  return lock;
}

export function readApplicationOrderLock(metadata, filename = APPLICATION_ORDER_LOCK_FILE) {
  if (!fs.existsSync(filename)) {
    throw new Error(
      'Application-order lock is missing; run vp -C tools/stylex-oracle install --frozen-lockfile, then node tools/stylex-oracle/generate-application-order.mjs',
    );
  }
  let lock;
  try {
    lock = readApplicationOrderJson(filename);
  } catch (error) {
    if (!(error instanceof SyntaxError)) throw error;
    throw new Error(
      'Application-order lock is invalid JSON; run vp -C tools/stylex-oracle install --frozen-lockfile, then node tools/stylex-oracle/generate-application-order.mjs',
      { cause: error },
    );
  }
  return validateApplicationOrderLock(lock, metadata);
}
