import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { definitionSyntax, lexer } from 'css-tree';

const root = path.resolve(import.meta.dirname, '..');
const styleModule = path.join(root, 'src');
const builderPackage = path.join(styleModule, 'builder');
const require = createRequire(import.meta.url);
const coverageApi = readJson(path.join(styleModule, 'properties', 'css-coverage-api.json'));

function readJson(filename) {
  return JSON.parse(fs.readFileSync(filename, 'utf8'));
}

function packageData(name) {
  let directory = path.dirname(require.resolve(name));
  while (!fs.existsSync(path.join(directory, 'package.json'))) {
    const parent = path.dirname(directory);
    if (parent === directory) fail(`could not locate package.json for ${name}`);
    directory = parent;
  }
  const packagePath = path.join(directory, 'package.json');
  return {
    directory,
    manifest: readJson(packagePath),
  };
}

function fail(message) {
  throw new Error(`Property API generation failed: ${message}`);
}

function normalizedDefinitionNode(value) {
  if (Array.isArray(value)) return value.map(normalizedDefinitionNode);
  if (value == null || typeof value !== 'object') return value;
  return Object.fromEntries(
    Object.keys(value)
      .sort((left, right) => left.localeCompare(right))
      .map((key) => [key, normalizedDefinitionNode(value[key])]),
  );
}

const supportedPrimitiveTypes = new Set([
  'length',
  'percentage',
  'length-percentage',
  'color',
  'number',
  'integer',
  'time',
  'angle',
  'resolution',
  'url',
]);

const closureTerminalTypes = new Set([...supportedPrimitiveTypes, 'flex']);

export const SCALAR_EXPANSION_PROFILE = 'stable-scalar-v2';
export const BORDER_COMPOSITE_PROFILE = 'stable-border-composite-v1';

const logicalSizeKeywords = new Map([
  ['block-size', 'auto'],
  ['inline-size', 'auto'],
  ['max-block-size', 'none'],
  ['max-inline-size', 'none'],
  ['min-block-size', 'auto'],
  ['min-inline-size', 'auto'],
]);
const reviewedBoxSizeSyntax =
  '<length-percentage [0,∞]> | stretch | contain | min-content | max-content | fit-content | stretch(<length-percentage [0,∞]>) | fit-content(<length-percentage [0,∞]>) | <calc-size()>';
const logicalSizeExcludedSyntax = Object.freeze([
  'stretch',
  'stretch()',
  'contain',
  'min-content',
  'max-content',
  'fit-content',
  'fit-content()',
  'calc-size()',
  'anchor-size()',
]);

const scalarPrimitiveSamples = Object.freeze({
  length: '1px',
  percentage: '1%',
  'length-percentage': '1px',
  color: 'red',
  number: '1.5',
  integer: '2',
  time: '1s',
  angle: '1deg',
  resolution: '1dpi',
  url: 'url("x")',
});

const scalarExpansionFamilies = Object.freeze([
  'layout',
  'typography',
  'visual',
  'interaction',
  'motion',
]);

const scalarExpansionExpectedCounts = Object.freeze({
  total: 129,
  strategies: Object.freeze({
    primitive: 54,
    'keyword-enum': 60,
    'property-reference': 9,
    'reviewed-scalar': 6,
  }),
  families: Object.freeze({
    layout: 63,
    typography: 28,
    visual: 23,
    interaction: 8,
    motion: 7,
  }),
});

const borderCompositeAdapters = Object.freeze({
  'border-side': Object.freeze({ valueType: 'border-side', count: 11 }),
  'border-colors': Object.freeze({ valueType: 'border-colors', count: 2 }),
  'border-styles': Object.freeze({ valueType: 'border-styles', count: 2 }),
  'border-widths': Object.freeze({ valueType: 'border-widths', count: 2 }),
  color: Object.freeze({ valueType: 'color', count: 6 }),
  'line-style': Object.freeze({ valueType: 'line-style', count: 6 }),
  'line-width': Object.freeze({ valueType: 'line-width', count: 6 }),
  'corner-radius': Object.freeze({ valueType: 'corner-radius', count: 4 }),
  outline: Object.freeze({ valueType: 'outline', count: 1 }),
});

const borderCompositeExpectedCssNames = Object.freeze({
  'border-side': Object.freeze([
    'border',
    'border-block',
    'border-block-end',
    'border-block-start',
    'border-bottom',
    'border-inline',
    'border-inline-end',
    'border-inline-start',
    'border-left',
    'border-right',
    'border-top',
  ]),
  'border-colors': Object.freeze(['border-block-color', 'border-inline-color']),
  'border-styles': Object.freeze(['border-block-style', 'border-inline-style']),
  'border-widths': Object.freeze(['border-block-width', 'border-inline-width']),
  color: Object.freeze([
    'border-block-end-color',
    'border-block-start-color',
    'border-bottom-color',
    'border-left-color',
    'border-right-color',
    'border-top-color',
  ]),
  'line-style': Object.freeze([
    'border-block-end-style',
    'border-block-start-style',
    'border-bottom-style',
    'border-left-style',
    'border-right-style',
    'border-top-style',
  ]),
  'line-width': Object.freeze([
    'border-block-end-width',
    'border-block-start-width',
    'border-bottom-width',
    'border-left-width',
    'border-right-width',
    'border-top-width',
  ]),
  'corner-radius': Object.freeze([
    'border-bottom-left-radius',
    'border-bottom-right-radius',
    'border-top-left-radius',
    'border-top-right-radius',
  ]),
  outline: Object.freeze(['outline']),
});

const borderCompositeSamples = Object.freeze({
  'border-side': '1px solid #000',
  'border-colors': '#000 transparent',
  'border-styles': 'solid dotted',
  'border-widths': '1px thin',
  color: '#000',
  'line-style': 'solid',
  'line-width': '1px',
  'corner-radius': '1px 2px',
  outline: '1px auto #000',
});

const borderCompositeExcludedSyntax = Object.freeze({
  'border-side': Object.freeze(['hairline']),
  'border-colors': Object.freeze(['image-1D']),
  'border-styles': Object.freeze([]),
  'border-widths': Object.freeze(['hairline']),
  color: Object.freeze(['image-1D']),
  'line-style': Object.freeze([]),
  'line-width': Object.freeze(['hairline']),
  'corner-radius': Object.freeze(['slash-separated-border-radius-syntax']),
  outline: Object.freeze(['hairline', 'image-1D']),
});

const borderCompositeExpectedCounts = Object.freeze({
  total: 40,
  adapters: Object.freeze(
    Object.fromEntries(
      Object.entries(borderCompositeAdapters).map(([adapter, definition]) => [
        adapter,
        definition.count,
      ]),
    ),
  ),
  families: Object.freeze({ visual: 40 }),
});

const scalarMotionProperties = new Set([
  'offset-distance',
  'offset-rotate',
  'scroll-timeline-axis',
  'transform-box',
  'transition-duration',
  'view-timeline-axis',
  'view-timeline-inset',
]);

const scalarInteractionProperties = new Set([
  'overflow-anchor',
  'overscroll-behavior',
  'overscroll-behavior-block',
  'overscroll-behavior-inline',
  'scroll-snap-align',
  'scroll-snap-stop',
  'scroll-snap-type',
  'scrollbar-width',
]);

const scalarTypographyProperties = new Set([
  'baseline-shift',
  'hanging-punctuation',
  'hyphenate-limit-chars',
  'line-break',
  'orphans',
  'speak',
  'widows',
]);

const scalarVisualProperties = new Set([
  'box-decoration-break',
  'clip-rule',
  'color-interpolation-filters',
  'forced-color-adjust',
  'image-orientation',
  'lighting-color',
  'mask-type',
  'outline-offset',
  'paint-order',
  'print-color-adjust',
  'shape-rendering',
  'vector-effect',
]);

function analyzeDefinitionNode(node) {
  if (node == null || typeof node !== 'object') return null;
  if (node.type === 'Group') {
    if (node.combinator === '&&') return 'unsupported-combinator-and';
    if (node.combinator !== '|' && node.combinator !== ' ' && node.combinator !== '||') {
      return `unsupported-combinator-${node.combinator}`;
    }
    for (const term of node.terms) {
      const reason = analyzeDefinitionNode(term);
      if (reason) return reason;
    }
    return null;
  }
  if (node.type === 'Type') {
    if (!supportedPrimitiveTypes.has(node.name)) return `unsupported-type-${node.name}`;
    return node.opts ? analyzeDefinitionNode(node.opts) : null;
  }
  if (node.type === 'Keyword') return null;
  if (node.type === 'Range') return null;
  if (node.type === 'Multiplier') {
    const optional = !node.comma && node.min === 0 && node.max === 1;
    const commaList = node.comma && node.max === 0;
    const bounded = node.max > 0;
    if (!optional && !commaList && !bounded) return 'unsupported-unbounded-repetition';
    return analyzeDefinitionNode(node.term);
  }
  if (node.type === 'Property') return null;
  if (node.type === 'Function') return `unsupported-function-${node.name}`;
  if (node.type === 'Token' || node.type === 'Comma') return 'unsupported-token-sequence';
  return `unsupported-node-${node.type ?? 'unknown'}`;
}

export function analyzeDefinitionSyntax(syntax) {
  let ast;
  try {
    ast = normalizedDefinitionNode(definitionSyntax.parse(syntax));
  } catch {
    return { ast: null, digest: null, safe: false, reason: 'definition-syntax-parse-error' };
  }
  const serialized = JSON.stringify(ast);
  const reason = analyzeDefinitionNode(ast);
  return {
    ast,
    digest: `sha256:${createHash('sha256').update(serialized).digest('hex')}`,
    safe: reason == null,
    reason: reason ?? 'supported-definition-syntax',
  };
}

export function resolveDefinitionClosure(
  syntax,
  namedTypes,
  namedProperties,
  namedFunctions = new Map(),
) {
  let rootAst;
  try {
    rootAst = normalizedDefinitionNode(definitionSyntax.parse(syntax));
  } catch {
    fail('could not parse the root definition syntax closure');
  }
  const definitions = new Map();
  const references = new Set();

  function visitDefinition(kind, name, stack) {
    const key = `${kind}:${name}`;
    if (stack.includes(key)) {
      fail(`definition syntax reference cycle: ${[...stack, key].join(' -> ')}`);
    }
    if (definitions.has(key)) return;
    const source =
      kind === 'type'
        ? namedTypes.get(name)
        : kind === 'property'
          ? namedProperties.get(name)
          : namedFunctions.get(name);
    if (!source?.syntax) {
      fail(
        `missing WebRef ${kind} definition ${name}` +
          (stack.length > 0 ? ` referenced by ${stack.join(' -> ')}` : ''),
      );
    }
    let ast;
    try {
      ast = normalizedDefinitionNode(definitionSyntax.parse(source.syntax));
    } catch {
      fail(`could not parse WebRef ${kind} definition ${name}`);
    }
    definitions.set(key, { key, syntax: source.syntax, ast });
    visitNode(ast, [...stack, key]);
  }

  function visitNode(node, stack) {
    if (node == null || typeof node !== 'object') return;
    if (node.type === 'Type' && !closureTerminalTypes.has(node.name)) {
      const kind = namedTypes.has(node.name)
        ? 'type'
        : namedFunctions.has(node.name)
          ? 'function'
          : 'type';
      references.add(`${kind}:${node.name}`);
      visitDefinition(kind, node.name, stack);
    } else if (node.type === 'Property') {
      references.add(`property:${node.name}`);
      visitDefinition('property', node.name, stack);
    }
    for (const value of Object.values(node)) {
      if (Array.isArray(value)) {
        for (const entry of value) visitNode(entry, stack);
      } else if (value != null && typeof value === 'object') {
        visitNode(value, stack);
      }
    }
  }

  visitNode(rootAst, []);
  const document = {
    root: rootAst,
    definitions: [...definitions.values()].sort((left, right) => left.key.localeCompare(right.key)),
  };
  return {
    digest: `sha256:${createHash('sha256').update(JSON.stringify(document)).digest('hex')}`,
    references: [...references].sort((left, right) => left.localeCompare(right)),
  };
}

function atomicWrite(filename, content) {
  fs.mkdirSync(path.dirname(filename), { recursive: true });
  const temporary = `${filename}.tmp`;
  fs.writeFileSync(temporary, content, 'utf8');
  fs.renameSync(temporary, filename);
}

function moonFunctionName(cssName) {
  return cssName.replaceAll('-', '_');
}

function moonVariantName(value) {
  const normalized = value
    .split(/[^a-zA-Z0-9]+/)
    .filter(Boolean)
    .map((part) => `${part[0].toUpperCase()}${part.slice(1)}`)
    .join('');
  return /^[0-9]/.test(normalized) ? `Value${normalized}` : normalized;
}

function collectDefinitionNodes(node, type, nodes = []) {
  if (node == null || typeof node !== 'object') return nodes;
  if (node.type === type) nodes.push(node);
  for (const value of Object.values(node)) {
    if (Array.isArray(value)) {
      for (const entry of value) collectDefinitionNodes(entry, type, nodes);
    } else if (value != null && typeof value === 'object') {
      collectDefinitionNodes(value, type, nodes);
    }
  }
  return nodes;
}

function independentlyMatchesProperty(cssName, value) {
  try {
    return lexer.matchProperty(cssName, value).matched != null;
  } catch {
    return false;
  }
}

function scalarExpansionFamily(cssName) {
  if (scalarMotionProperties.has(cssName)) return 'motion';
  if (scalarInteractionProperties.has(cssName)) return 'interaction';
  if (
    ['font-', 'math-', 'ruby-', 'text-'].some((prefix) => cssName.startsWith(prefix)) ||
    scalarTypographyProperties.has(cssName)
  ) {
    return 'typography';
  }
  if (
    ['border-image-', 'fill-', 'flood-', 'stop-', 'stroke-'].some((prefix) =>
      cssName.startsWith(prefix),
    ) ||
    scalarVisualProperties.has(cssName)
  ) {
    return 'visual';
  }
  return 'layout';
}

function isExactPropertyReference(ast) {
  return (
    ast?.type === 'Group' &&
    ast.combinator === ' ' &&
    ast.terms.length === 1 &&
    ast.terms[0].type === 'Property'
  );
}

function reviewedLogicalSize(definition, namedTypes) {
  const keyword = logicalSizeKeywords.get(definition.name);
  const boxSize = namedTypes.get('box-size');
  if (!boxSize?.syntax) fail(`${definition.name} requires the reviewed box-size definition`);

  function grammarDigest(propertySyntax, boxSyntax) {
    const review = {
      root: normalizedDefinitionNode(definitionSyntax.parse(propertySyntax)),
      definitions: [
        { key: 'type:box-size', ast: normalizedDefinitionNode(definitionSyntax.parse(boxSyntax)) },
      ],
    };
    return `sha256:${createHash('sha256').update(JSON.stringify(review)).digest('hex')}`;
  }

  let grammarReviewDigest;
  try {
    grammarReviewDigest = grammarDigest(definition.syntax, boxSize.syntax);
  } catch {
    fail(`${definition.name} has an unparseable logical-size grammar`);
  }
  const reviewedDigest = grammarDigest(
    `${keyword} | <box-size> | <anchor-size()>`,
    reviewedBoxSizeSyntax,
  );
  if (grammarReviewDigest !== reviewedDigest) {
    fail(`${definition.name} logical-size grammar changed; review the existing Length subset`);
  }
  for (const sample of ['1px', '1%']) {
    if (!independentlyMatchesProperty(definition.name, sample)) {
      fail(`${definition.name} no longer independently accepts the reviewed value ${sample}`);
    }
  }

  // Preserve the existing Length API. The broader named grammar remains outside
  // the automatic scalar parser, and its new sizing functions are not admitted.
  return {
    cssName: definition.name,
    family: 'layout',
    valueType: 'length',
    valueStrategy: 'reviewed-scalar',
    valueCoverage: 'conservative-scalar',
    scalarAdapter: 'logical-size-length',
    grammarReviewDigest,
    grammarReferences: ['type:box-size'],
    excludedSyntax: [...logicalSizeExcludedSyntax, ...(keyword === 'none' ? ['none'] : [])],
  };
}

export function deriveScalarExpansion({
  webrefProperties,
  webrefTypes,
  bcdProperties,
  baseProperties,
}) {
  const baseByName = new Map(baseProperties.map((property) => [property.cssName, property]));
  const namedTypes = new Map(
    (webrefTypes ?? []).map((definition) => [definition.name, definition]),
  );
  const candidates = [];
  for (const definition of webrefProperties) {
    const cssName = definition.name;
    const status = bcdProperties[cssName]?.__compat?.status;
    if (
      baseByName.has(cssName) ||
      !status?.standard_track ||
      status.deprecated !== false ||
      status.experimental !== false ||
      cssName.startsWith('-') ||
      cssName === 'all'
    ) {
      continue;
    }
    if (logicalSizeKeywords.has(cssName)) {
      candidates.push(reviewedLogicalSize(definition, namedTypes));
      continue;
    }
    const grammar = analyzeDefinitionSyntax(definition.syntax ?? '');
    if (!grammar.safe) continue;

    const references = collectDefinitionNodes(grammar.ast, 'Property');
    if (references.length > 0) {
      // Embedded references can change the value category; only exact reviewed aliases are safe.
      if (!isExactPropertyReference(grammar.ast)) continue;
      const referenceProperty = references[0].name;
      const target = baseByName.get(referenceProperty);
      if (!target) continue;
      candidates.push({
        cssName,
        family: target.family,
        valueType: target.valueType,
        valueStrategy: 'property-reference',
        valueCoverage: 'conservative-scalar',
        referenceProperty,
      });
      continue;
    }

    const primitiveTypes = [
      ...new Set(
        collectDefinitionNodes(grammar.ast, 'Type')
          .map((node) => node.name)
          .filter((name) => supportedPrimitiveTypes.has(name)),
      ),
    ];
    if (
      primitiveTypes.length === 1 &&
      independentlyMatchesProperty(cssName, scalarPrimitiveSamples[primitiveTypes[0]])
    ) {
      candidates.push({
        cssName,
        family: scalarExpansionFamily(cssName),
        valueType: primitiveTypes[0],
        valueStrategy: 'primitive',
        valueCoverage: 'conservative-scalar',
        ...(cssName === 'font-width' ? { valueConstraints: { minimum: 0, finite: true } } : {}),
      });
      continue;
    }

    const keywords = [
      ...new Set(collectDefinitionNodes(grammar.ast, 'Keyword').map((node) => node.name)),
    ].filter((keyword) => independentlyMatchesProperty(cssName, keyword));
    if (keywords.length < 2) continue;
    const typeName = `${moonVariantName(cssName)}Value`;
    candidates.push({
      cssName,
      family: scalarExpansionFamily(cssName),
      valueType: `enum:${typeName}`,
      valueStrategy: 'keyword-enum',
      valueCoverage: 'conservative-scalar',
      typeName,
      keywords,
    });
  }
  return candidates;
}

function summarizeScalarExpansion(candidates) {
  const strategies = {
    primitive: 0,
    'keyword-enum': 0,
    'property-reference': 0,
    'reviewed-scalar': 0,
  };
  const families = Object.fromEntries(scalarExpansionFamilies.map((family) => [family, 0]));
  for (const candidate of candidates) {
    strategies[candidate.valueStrategy] = (strategies[candidate.valueStrategy] ?? 0) + 1;
    families[candidate.family] = (families[candidate.family] ?? 0) + 1;
  }
  return { total: candidates.length, strategies, families };
}

function validateScalarExpansionAllowlist(config, candidates) {
  if (config?.profile !== SCALAR_EXPANSION_PROFILE) {
    fail(`scalarExpansion.profile must be ${SCALAR_EXPANSION_PROFILE}`);
  }
  const configuredFamilies = config.families;
  if (configuredFamilies == null || typeof configuredFamilies !== 'object') {
    fail('scalarExpansion.families must be an object');
  }
  const extraFamilies = Object.keys(configuredFamilies).filter(
    (family) => !scalarExpansionFamilies.includes(family),
  );
  if (extraFamilies.length > 0) {
    fail(`scalarExpansion contains unknown families: ${extraFamilies.join(', ')}`);
  }
  for (const family of scalarExpansionFamilies) {
    const actual = configuredFamilies[family];
    if (!Array.isArray(actual)) fail(`scalarExpansion.families.${family} must be an array`);
    if (actual.some((cssName) => typeof cssName !== 'string' || cssName.trim() === '')) {
      fail(`scalarExpansion.families.${family} contains an invalid CSS property name`);
    }
    if (new Set(actual).size !== actual.length) {
      fail(`scalarExpansion.families.${family} contains duplicate CSS property names`);
    }
    const expected = candidates
      .filter((candidate) => candidate.family === family)
      .map((candidate) => candidate.cssName);
    if (JSON.stringify(actual) !== JSON.stringify(expected)) {
      const expectedSet = new Set(expected);
      const actualSet = new Set(actual);
      const missing = expected.filter((cssName) => !actualSet.has(cssName));
      const extra = actual.filter((cssName) => !expectedSet.has(cssName));
      fail(
        `scalarExpansion.families.${family} differs from the derived candidates` +
          ` (missing: ${missing.join(', ') || 'none'}; extra: ${extra.join(', ') || 'none'};` +
          ' order must match WebRef)',
      );
    }
  }
  const summary = summarizeScalarExpansion(candidates);
  if (JSON.stringify(summary) !== JSON.stringify(scalarExpansionExpectedCounts)) {
    fail(
      `scalar expansion profile drifted: expected ${JSON.stringify(scalarExpansionExpectedCounts)},` +
        ` received ${JSON.stringify(summary)}`,
    );
  }
  return summary;
}

function borderComponents(prefix) {
  return [`${prefix}-width`, `${prefix}-style`, `${prefix}-color`];
}

export function borderCompositeAtomicProperties(cssName, adapter) {
  if (adapter === 'outline') return ['outline-width', 'outline-style', 'outline-color'];
  if (adapter === 'border-side') {
    if (cssName === 'border') {
      return ['border-top', 'border-inline-end', 'border-bottom', 'border-inline-start'].flatMap(
        borderComponents,
      );
    }
    if (cssName === 'border-block') {
      return ['border-block-start', 'border-block-end'].flatMap(borderComponents);
    }
    if (cssName === 'border-inline') {
      return ['border-inline-start', 'border-inline-end'].flatMap(borderComponents);
    }
    return borderComponents(cssName);
  }
  const pairSuffixes = {
    'border-colors': 'color',
    'border-styles': 'style',
    'border-widths': 'width',
  };
  const suffix = pairSuffixes[adapter];
  if (suffix) {
    const axis = cssName.startsWith('border-block-') ? 'block' : 'inline';
    return [`border-${axis}-start-${suffix}`, `border-${axis}-end-${suffix}`];
  }
  return [cssName];
}

export function deriveBorderCompositeExpansion({
  config,
  webrefProperties,
  webrefTypes,
  webrefFunctions,
  bcdProperties,
  existingProperties,
}) {
  if (config?.profile !== BORDER_COMPOSITE_PROFILE) {
    fail(`borderCompositeExpansion.profile must be ${BORDER_COMPOSITE_PROFILE}`);
  }
  if (!Array.isArray(config.groups)) {
    fail('borderCompositeExpansion.groups must be an array');
  }
  const configuredAdapters = new Set();
  const configured = new Map();
  const adapterCounts = Object.fromEntries(
    Object.keys(borderCompositeAdapters).map((adapter) => [adapter, 0]),
  );
  for (const group of config.groups) {
    const definition = borderCompositeAdapters[group.adapter];
    if (!definition) fail(`unknown border composite adapter ${group.adapter}`);
    if (configuredAdapters.has(group.adapter)) {
      fail(`duplicate border composite adapter ${group.adapter}`);
    }
    configuredAdapters.add(group.adapter);
    if (group.valueType !== definition.valueType) {
      fail(`${group.adapter} must use value type ${definition.valueType}`);
    }
    if (!Array.isArray(group.cssNames) || group.cssNames.length !== definition.count) {
      fail(`${group.adapter} must contain exactly ${definition.count} CSS properties`);
    }
    if (
      JSON.stringify(group.cssNames) !==
      JSON.stringify(borderCompositeExpectedCssNames[group.adapter])
    ) {
      fail(`${group.adapter} differs from the frozen ${BORDER_COMPOSITE_PROFILE} allowlist`);
    }
    for (const cssName of group.cssNames) {
      if (typeof cssName !== 'string' || cssName.trim() === '') {
        fail(`${group.adapter} contains an invalid CSS property name`);
      }
      if (configured.has(cssName)) fail(`duplicate border composite property ${cssName}`);
      configured.set(cssName, { adapter: group.adapter, valueType: group.valueType });
      adapterCounts[group.adapter] += 1;
    }
  }
  const missingAdapters = Object.keys(borderCompositeAdapters).filter(
    (adapter) => !configuredAdapters.has(adapter),
  );
  if (missingAdapters.length > 0) {
    fail(`missing border composite adapters: ${missingAdapters.join(', ')}`);
  }
  const summary = {
    total: configured.size,
    adapters: adapterCounts,
    families: { visual: configured.size },
  };
  if (JSON.stringify(summary) !== JSON.stringify(borderCompositeExpectedCounts)) {
    fail(
      `border composite profile drifted: expected ${JSON.stringify(borderCompositeExpectedCounts)},` +
        ` received ${JSON.stringify(summary)}`,
    );
  }

  const existingNames = new Set(existingProperties.map((property) => property.cssName));
  const propertiesByName = new Map(webrefProperties.map((property) => [property.name, property]));
  const typesByName = new Map(webrefTypes.map((type) => [type.name, type]));
  const functionsByName = new Map(webrefFunctions.map((fn) => [fn.name, fn]));
  const candidates = [];
  for (const definition of webrefProperties) {
    const mapping = configured.get(definition.name);
    if (!mapping) continue;
    const cssName = definition.name;
    const status = bcdProperties[cssName]?.__compat?.status;
    if (
      !status?.standard_track ||
      status.deprecated !== false ||
      status.experimental !== false ||
      cssName.startsWith('-')
    ) {
      fail(`${cssName} is not a stable standards-track border property`);
    }
    if (existingNames.has(cssName)) fail(`${cssName} is already mapped by an earlier profile`);
    const sample = borderCompositeSamples[mapping.adapter];
    if (!independentlyMatchesProperty(cssName, sample)) {
      fail(`${cssName} does not accept the reviewed ${mapping.adapter} sample ${sample}`);
    }
    const closure = resolveDefinitionClosure(
      definition.syntax ?? '',
      typesByName,
      propertiesByName,
      functionsByName,
    );
    candidates.push({
      cssName,
      family: 'visual',
      valueType: mapping.valueType,
      valueStrategy: 'reviewed-composite',
      valueAdapter: mapping.adapter,
      valueCoverage: 'stable-intersection',
      grammarClosureDigest: closure.digest,
      grammarReferences: closure.references,
      excludedSyntax: borderCompositeExcludedSyntax[mapping.adapter],
      atomicProperties: borderCompositeAtomicProperties(cssName, mapping.adapter),
    });
  }
  const missingProperties = [...configured.keys()].filter(
    (cssName) => !candidates.some((candidate) => candidate.cssName === cssName),
  );
  if (missingProperties.length > 0) {
    fail(`WebRef is missing border composite properties: ${missingProperties.join(', ')}`);
  }
  return { candidates, summary };
}

function valueDescriptor(valueType, enums) {
  if (valueType === 'animation-name') {
    return {
      moonType: '@ir.AnimationName',
      expression: 'value',
      styleValue: 'animation',
    };
  }
  if (valueType === 'length') {
    return { moonType: '@values.Length', expression: 'value.to_css()' };
  }
  if (valueType === 'color') {
    return { moonType: '@values.Color', expression: 'value.to_css()' };
  }
  if (valueType === 'time') {
    return { moonType: '@values.Time', expression: 'value.to_css()' };
  }
  if (valueType === 'angle') {
    return { moonType: '@values.Angle', expression: 'value.to_css()' };
  }
  if (valueType === 'percentage') {
    return { moonType: '@values.Percentage', expression: 'value.to_css()' };
  }
  if (valueType === 'length-percentage') {
    return { moonType: '@values.LengthPercentage', expression: 'value.to_css()' };
  }
  if (valueType === 'number') {
    return { moonType: '@values.Number', expression: 'value.to_css()' };
  }
  if (valueType === 'integer') {
    return { moonType: '@values.Integer', expression: 'value.to_css()' };
  }
  if (valueType === 'resolution') {
    return { moonType: '@values.Resolution', expression: 'value.to_css()' };
  }
  if (valueType === 'url') {
    return { moonType: '@values.Url', expression: 'value.to_css()' };
  }
  const structuredTypes = {
    ratio: 'Ratio',
    position: 'Position',
    'background-size': 'BackgroundSize',
    'repeat-style': 'RepeatStyle',
    'transform-list': 'TransformList',
    'transform-origin': 'TransformOrigin',
    'easing-function': 'EasingFunction',
    'grid-track-list': 'GridTrackList',
    'grid-line': 'GridLine',
    'touch-action': 'TouchAction',
    contain: 'Contain',
    'font-variant-numeric': 'FontVariantNumeric',
    'line-width': 'LineWidth',
    'line-style': 'LineStyle',
    'corner-radius': 'CornerRadius',
    'border-side': 'BorderSide',
    'border-widths': 'BorderWidths',
    'border-styles': 'BorderStyles',
    'border-colors': 'BorderColors',
    outline: 'Outline',
    'filter-list': 'FilterList',
    'box-shadow-list': 'BoxShadowList',
    'text-shadow-list': 'TextShadowList',
    'grid-template-areas': 'GridTemplateAreas',
    'container-names': 'ContainerNames',
    'mask-image-list': 'MaskImageList',
    'position-list': 'PositionList',
    'repeat-style-list': 'RepeatStyleList',
    'background-size-list': 'BackgroundSizeList',
    'clip-path': 'ClipPath',
    'content-value': 'ContentValue',
    'anchor-names': 'AnchorNames',
    'position-anchor': 'PositionAnchor',
    'position-area': 'PositionArea',
    'position-try-value': 'PositionTryValue',
    'position-try-fallbacks': 'PositionTryFallbacks',
    'position-try-order': 'PositionTryOrder',
    'view-transition-name': 'ViewTransitionName',
    'view-transition-class': 'ViewTransitionClass',
  };
  if (structuredTypes[valueType]) {
    return {
      moonType: `@values.${structuredTypes[valueType]}`,
      expression: 'value.to_css()',
    };
  }
  if (coverageApi.structuredTypes[valueType]) {
    return {
      moonType: `@values.${coverageApi.structuredTypes[valueType]}`,
      expression: 'value.to_css()',
    };
  }
  if (valueType === 'int') {
    return { moonType: 'Int', expression: 'value.to_string()' };
  }
  if (valueType === 'double') {
    return { moonType: 'Double', expression: 'value.to_string()' };
  }
  if (valueType === 'string') {
    return { moonType: 'String', expression: 'value' };
  }
  if (valueType.startsWith('enum:')) {
    const enumName = valueType.slice('enum:'.length);
    if (!enums.has(enumName)) fail(`unknown enum ${enumName}`);
    return { moonType: enumName, expression: 'value.to_css()' };
  }
  fail(`unknown value type ${valueType}`);
}

function familyDescriptor(family) {
  const families = {
    layout: {
      moonType: 'LayoutDeclaration',
      constructor: 'layout_declaration',
    },
    typography: {
      moonType: 'TypographyDeclaration',
      constructor: 'typography_declaration',
    },
    visual: {
      moonType: 'VisualDeclaration',
      constructor: 'visual_declaration',
    },
    interaction: {
      moonType: 'InteractionDeclaration',
      constructor: 'interaction_declaration',
    },
    motion: {
      moonType: 'MotionDeclaration',
      constructor: 'motion_declaration',
    },
  };
  const descriptor = families[family];
  if (!descriptor) fail(`unknown capability family ${family}`);
  return descriptor;
}

function dynamicDescriptor(valueType) {
  const descriptors = {
    length: ['@values.Length', 'length'],
    color: ['@values.Color', 'color'],
    number: ['@values.Number', 'number'],
    integer: ['@values.Integer', 'integer'],
    percentage: ['@values.Percentage', 'percentage'],
    'length-percentage': ['@values.LengthPercentage', 'length-percentage'],
    time: ['@values.Time', 'time'],
    angle: ['@values.Angle', 'angle'],
    resolution: ['@values.Resolution', 'resolution'],
    url: ['@values.Url', 'url'],
  };
  const descriptor = descriptors[valueType];
  if (!descriptor) fail(`dynamic value type ${valueType} is unsupported`);
  return { moonType: descriptor[0], category: descriptor[1] };
}

function renderEnum(definition) {
  const variants = Object.keys(definition.values);
  if (variants.length === 0) fail(`enum ${definition.name} has no values`);
  const cases = Object.entries(definition.values).map(
    ([variant, css]) => `    ${variant} => ${JSON.stringify(css)}`,
  );
  return [
    '///|',
    `pub(all) enum ${definition.name} {`,
    ...variants.map((variant) => `  ${variant}`),
    '} derive(Eq, Debug)',
    '',
    '///|',
    `pub extend ${definition.name} with Eq::{equal, not_equal}`,
    '',
    '///|',
    `pub extend ${definition.name} with @moonbitlang/core/debug.Debug::{to_repr}`,
    '',
    '///|',
    `pub fn ${definition.name}::to_css(self : ${definition.name}) -> String {`,
    '  match self {',
    ...cases,
    '  }',
    '}',
  ].join('\n');
}

function renderProperty(property, irName, enums) {
  const functionName = moonFunctionName(property.cssName);
  const { moonType, expression, styleValue = 'text' } = valueDescriptor(property.valueType, enums);
  const family = familyDescriptor(property.family);
  const declarationHelper = styleValue === 'animation' ? 'animation_declaration' : 'declaration';
  const blocks = [];
  if (property.conditions) {
    blocks.push(
      [
        '///|',
        `pub fn ${functionName}(`,
        `  value : ${moonType},`,
        '  conditions? : Array[@ir.Condition] = [],',
        `) -> ${family.moonType} {`,
        `  ${family.constructor}(${declarationHelper}(${JSON.stringify(irName)}, ${expression}, conditions))`,
        '}',
      ].join('\n'),
    );
  } else {
    blocks.push(
      [
        '///|',
        `pub fn ${functionName}(value : ${moonType}) -> ${family.moonType} {`,
        `  ${family.constructor}(${declarationHelper}(${JSON.stringify(irName)}, ${expression}, []))`,
        '}',
      ].join('\n'),
    );
  }
  if (styleValue === 'text' && property.fallbacks !== false) {
    const fallbackParameters = property.conditions
      ? [`  values : Array[${moonType}],`, '  conditions? : Array[@ir.Condition] = [],']
      : [`  values : Array[${moonType}],`];
    const fallbackConditions = property.conditions ? 'conditions' : '[]';
    blocks.push(
      [
        '///|',
        `pub fn ${functionName}_fallbacks(`,
        ...fallbackParameters,
        `) -> ${family.moonType} {`,
        `  ${family.constructor}(fallback_declaration(${JSON.stringify(irName)}, values.map(value => ${expression}), ${fallbackConditions}))`,
        '}',
      ].join('\n'),
    );
  }
  if (property.dynamic) {
    const dynamic = dynamicDescriptor(property.valueType);
    const suffix = typeof property.dynamic === 'object' ? (property.dynamic.suffix ?? '') : '';
    blocks.push(
      [
        '///|',
        `pub fn dynamic_${functionName}(`,
        `  variable : @values.CssVar[${dynamic.moonType}],`,
        `) -> ${family.moonType} {`,
        `  ${family.constructor}(@ir.declaration(${JSON.stringify(irName)}, @ir.dynamic(variable.name(), ${JSON.stringify(suffix)}, category=${JSON.stringify(dynamic.category)})))`,
        '}',
      ].join('\n'),
    );
  }
  return blocks.join('\n\n');
}

const builderInputs = Object.freeze({
  length: Object.freeze({ trait: 'LengthInput', method: 'length_input' }),
  color: Object.freeze({ trait: 'ColorInput', method: 'color_input' }),
  number: Object.freeze({ trait: 'NumberInput', method: 'number_input' }),
  percentage: Object.freeze({ trait: 'PercentageInput', method: 'percentage_input' }),
  'length-percentage': Object.freeze({
    trait: 'LengthPercentageInput',
    method: 'length_percentage_input',
  }),
  integer: Object.freeze({ trait: 'IntegerInput', method: 'integer_input' }),
  time: Object.freeze({ trait: 'TimeInput', method: 'time_input' }),
  angle: Object.freeze({ trait: 'AngleInput', method: 'angle_input' }),
  resolution: Object.freeze({ trait: 'ResolutionInput', method: 'resolution_input' }),
  url: Object.freeze({ trait: 'UrlInput', method: 'url_input' }),
  'grid-track-list': Object.freeze({
    trait: 'GridTrackListInput',
    method: 'grid_track_list_input',
  }),
});

const commonValueFamilies = Object.freeze({
  width: 'BoxSize',
  height: 'BoxSize',
  'min-width': 'BoxSize',
  'max-width': 'BoxSize',
  'min-height': 'BoxSize',
  'max-height': 'BoxSize',
  'inline-size': 'BoxSize',
  'block-size': 'BoxSize',
  'min-inline-size': 'BoxSize',
  'max-inline-size': 'BoxSize',
  'min-block-size': 'BoxSize',
  'max-block-size': 'BoxSize',
  'flex-basis': 'FlexBasis',
  'font-size': 'FontSize',
  'line-height': 'LineHeight',
  'border-radius': 'BorderRadii',
  'border-start-start-radius': 'CornerRadius',
  'border-start-end-radius': 'CornerRadius',
  'border-end-start-radius': 'CornerRadius',
  'border-end-end-radius': 'CornerRadius',
  'border-top-left-radius': 'CornerRadius',
  'border-top-right-radius': 'CornerRadius',
  'border-bottom-left-radius': 'CornerRadius',
  'border-bottom-right-radius': 'CornerRadius',
});

function renderBuilderProperty(property, irName, enums) {
  const functionName = moonFunctionName(property.cssName);
  const suffix = typeof property.dynamic === 'object' ? (property.dynamic.suffix ?? '') : '';
  const input = commonValueFamilies[property.cssName]
    ? { trait: `${commonValueFamilies[property.cssName]}Input`, method: 'property_input' }
    : property.cssName === 'background-image'
      ? { trait: 'ImageInput', method: 'image_input' }
      : builderInputs[property.valueType];
  const value = valueDescriptor(property.valueType, enums);
  const builderMoonType = property.valueType.startsWith('enum:')
    ? `@properties.${value.moonType}`
    : value.moonType;
  const blocks = [];
  const clearBlock = [
    '///|',
    '#callsite(autofill(location))',
    `pub fn Rule::clear_${functionName}(`,
    '  self : Rule,',
    '  source? : @ir.SourceSpan? = None,',
    '  location~ : SourceLoc,',
    ') -> Rule {',
    `  let source = resolve_source_span(source, location, ${JSON.stringify(irName)})`,
    `  self.append_clear(${JSON.stringify(irName)}, source)`,
    '}',
  ].join('\n');
  const supportsFallbacks = property.fallbacks !== false;
  if (property.valueType === 'animation-name') {
    blocks.push(
      [
        '///|',
        '#callsite(autofill(location))',
        `pub fn[T : AnimationInput] Rule::${functionName}(`,
        '  self : Rule,',
        '  value : T,',
        '  when? : When = always,',
        '  source? : @ir.SourceSpan? = None,',
        '  location~ : SourceLoc,',
        ') -> Rule {',
        `  let source = resolve_source_span(source, location, ${JSON.stringify(irName)})`,
        `  self.append_animation(${JSON.stringify(irName)}, value, when, source)`,
        '}',
      ].join('\n'),
    );
    blocks.push(clearBlock);
    return blocks.join('\n\n');
  }

  const generic = input ? `[T : ${input.trait}]` : '';
  const parameterType = input ? 'T' : builderMoonType;
  const body = input
    ? `self.append_input(${JSON.stringify(irName)}, value.${input.method}(), when, source, ${JSON.stringify(suffix)}, true)`
    : `self.append_text(${JSON.stringify(irName)}, ${value.expression}, when, source, true)`;
  blocks.push(
    [
      '///|',
      '#callsite(autofill(location))',
      `pub fn${generic} Rule::${functionName}(`,
      '  self : Rule,',
      `  value : ${parameterType},`,
      '  when? : When = always,',
      '  source? : @ir.SourceSpan? = None,',
      '  location~ : SourceLoc,',
      ') -> Rule {',
      `  let source = resolve_source_span(source, location, ${JSON.stringify(irName)})`,
      `  ${body}`,
      '}',
    ].join('\n'),
  );

  const fallbackType = builderMoonType;
  if (supportsFallbacks) {
    blocks.push(
      [
        '///|',
        '#callsite(autofill(location))',
        `pub fn Rule::${functionName}_fallbacks(`,
        '  self : Rule,',
        `  values : Array[${fallbackType}],`,
        '  when? : When = always,',
        '  source? : @ir.SourceSpan? = None,',
        '  location~ : SourceLoc,',
        ') -> Rule {',
        `  let source = resolve_source_span(source, location, ${JSON.stringify(irName)})`,
        property.valueType === 'grid-track-list'
          ? `  self.append_expression_fallbacks(${JSON.stringify(irName)}, values.map(value => value.expression()), when, source)`
          : `  self.append_fallbacks(${JSON.stringify(irName)}, values.map(value => ${value.expression}), when, source)`,
        '}',
      ].join('\n'),
    );
  }

  const frameCall = `self.rule.${functionName}(value, when=when, source=source)`;
  blocks.push(
    [
      '///|',
      '#callsite(autofill(location))',
      `pub fn${generic} Frame::${functionName}(`,
      '  self : Frame,',
      `  value : ${parameterType},`,
      '  when? : When = always,',
      '  source? : @ir.SourceSpan? = None,',
      '  location~ : SourceLoc,',
      ') -> Frame {',
      `  let source = resolve_source_span(source, location, ${JSON.stringify(irName)})`,
      `  self.with_rule(${frameCall})`,
      '}',
    ].join('\n'),
  );

  if (supportsFallbacks) {
    blocks.push(
      [
        '///|',
        '#callsite(autofill(location))',
        `pub fn Frame::${functionName}_fallbacks(`,
        '  self : Frame,',
        `  values : Array[${fallbackType}],`,
        '  when? : When = always,',
        '  source? : @ir.SourceSpan? = None,',
        '  location~ : SourceLoc,',
        ') -> Frame {',
        `  let source = resolve_source_span(source, location, ${JSON.stringify(irName)})`,
        `  self.with_rule(self.rule.${functionName}_fallbacks(values, when=when, source=source))`,
        '}',
      ].join('\n'),
    );
  }
  blocks.push(clearBlock);
  return blocks.join('\n\n');
}

function renderContractProperty(property, irName, enums) {
  const functionName = moonFunctionName(property.cssName);
  if (property.valueType === 'animation-name') {
    return [
      '///|',
      `pub fn StyleContract::allow_${functionName}(self : StyleContract, keywords? : Array[@values.CssWideKeyword] = [], lists? : Array[AnimationNames] = []) -> StyleContract {`,
      `  self.allow_property(${JSON.stringify(irName)}, values=keywords.map(value => value.to_css()), expressions=lists.map(value => value.identity()))`,
      '}',
    ].join('\n');
  }
  const input = builderInputs[property.valueType];
  const value = valueDescriptor(property.valueType, enums);
  const builderMoonType = property.valueType.startsWith('enum:')
    ? `@properties.${value.moonType}`
    : value.moonType;
  const parameters = [`  values? : Array[${builderMoonType}] = [],`];
  const contractArguments = [`    values=values.map(value => ${value.expression}),`];
  const commonFamily = commonValueFamilies[property.cssName];
  if (commonFamily) {
    const contractType = ['CornerRadius', 'BorderRadii'].includes(commonFamily)
      ? 'BoxSizeContractExpression'
      : `${commonFamily}ContractExpression`;
    parameters.push(`  expressions? : Array[&@values.${contractType}] = [],`);
    const contractMethod = {
      BoxSize: 'box_size',
      FlexBasis: 'flex_basis',
      FontSize: 'font_size',
      LineHeight: 'line_height',
      CornerRadius: 'box_size',
      BorderRadii: 'box_size',
    }[commonFamily];
    contractArguments.push(
      `    expressions=expressions.map(value => value.${contractMethod}_contract_expression()),`,
    );
  } else if (
    ['length', 'length-percentage', 'percentage', 'number', 'angle', 'time', 'resolution'].includes(
      property.valueType,
    )
  ) {
    parameters.push(
      property.valueType === 'length'
        ? '  expressions? : Array[&@values.LengthContractExpression] = [],'
        : `  expressions? : Array[@values.MathExpr[${value.moonType}]] = [],`,
    );
    contractArguments.push(
      property.valueType === 'length'
        ? '    expressions=expressions.map(value => value.contract_expression()),'
        : '    expressions=expressions.map(value => value.expression().identity()),',
    );
  }
  if (input && property.valueType !== 'grid-track-list') {
    const categoryType = value.moonType.replace('@values.', '');
    parameters.push(
      `  tokens? : Array[@values.${categoryType}Token] = [],`,
      `  slots? : Array[@values.${categoryType}Slot] = [],`,
    );
    contractArguments.push(
      '    tokens=tokens.map(value => contract_token(value)),',
      '    slots=slots.map(value => contract_slot(value)),',
    );
  }
  if (property.valueType === 'grid-track-list') {
    parameters.push('  expressions? : Array[@values.GridTrackList] = [],');
    contractArguments.push(
      '    expressions=expressions.map(value => value.expression().identity()),',
    );
  }
  if (property.cssName === 'background-image') {
    parameters.push('  expressions? : Array[@values.Image] = [],');
    contractArguments.push(
      '    expressions=expressions.map(value => value.expression().identity()),',
    );
  }
  if (
    [
      'background-position-x',
      'background-position-y',
      'background-size',
      'background-repeat',
      'background-attachment',
      'background-origin',
      'background-clip',
    ].includes(property.cssName)
  ) {
    parameters.push('  expressions? : Array[@values.BackgroundLayers] = [],');
    contractArguments.push(
      `    expressions=expressions.map(value => value.property_expression(${JSON.stringify(irName)}).identity()),`,
    );
  }
  return [
    '///|',
    `pub fn StyleContract::allow_${functionName}(`,
    '  self : StyleContract,',
    ...parameters,
    ') -> StyleContract {',
    '  self.allow_property(',
    `    ${JSON.stringify(irName)},`,
    ...contractArguments,
    '  )',
    '}',
  ].join('\n');
}

function styleDeclarationName(definition) {
  const names = definition.styleDeclaration ?? [];
  return names.find((name) => !name.includes('-')) ?? definition.name;
}

export function resolveAtomicProperties(property, webrefProperties, bcdProperties) {
  const atomicCssNames = property.atomicProperties ?? [property.cssName];
  if (!Array.isArray(atomicCssNames) || atomicCssNames.length === 0) {
    fail(`${property.cssName} atomicProperties must be a non-empty array`);
  }
  if (new Set(atomicCssNames).size !== atomicCssNames.length) {
    fail(`${property.cssName} atomicProperties must be unique`);
  }
  return atomicCssNames.map((cssName) => {
    if (typeof cssName !== 'string' || cssName.trim() === '') {
      fail(`${property.cssName} has an empty atomic property`);
    }
    const atomicDefinition = webrefProperties.get(cssName);
    if (!atomicDefinition) fail(`WebRef does not define atomic property ${cssName}`);
    const atomicStatus = bcdProperties[cssName]?.__compat?.status;
    if (!atomicStatus?.standard_track || atomicStatus.deprecated) {
      fail(`${cssName} is not a non-deprecated standards atomic property in BCD`);
    }
    return { cssName, irName: styleDeclarationName(atomicDefinition) };
  });
}

export function generateProperties() {
  const config = readJson(path.join(styleModule, 'properties', 'property-api.json'));
  if (config.schemaVersion !== 17) fail('property-api schemaVersion must be 17');
  const groupEnums = (config.propertyGroups ?? [])
    .filter((group) => group.keywords)
    .map((group) => {
      if (!group.typeName || !Array.isArray(group.keywords) || group.keywords.length === 0) {
        fail('keyword property groups require typeName and non-empty keywords');
      }
      return {
        name: group.typeName,
        values: Object.fromEntries(
          group.keywords.map((keyword) => [
            `${group.typeName}${moonVariantName(keyword)}`,
            keyword,
          ]),
        ),
      };
    });
  const groupedProperties = (config.propertyGroups ?? []).flatMap((group) => {
    if (!Array.isArray(group.cssNames) || group.cssNames.length === 0) {
      fail('propertyGroups entries require a non-empty cssNames array');
    }
    return group.cssNames.map((cssName) => ({
      cssName,
      family: group.family,
      valueType: group.valueType ?? `enum:${group.typeName}`,
      conditions: group.conditions,
      dynamic: group.dynamic,
    }));
  });
  const baseProperties = [...config.properties, ...groupedProperties];
  if (baseProperties.length !== 196) {
    fail(
      `scalar expansion requires the reviewed 196-property base, found ${baseProperties.length}`,
    );
  }

  const webrefPackage = packageData('@webref/css');
  const bcdPackage = packageData('@mdn/browser-compat-data');
  const cssTreePackage = packageData('css-tree');
  const rootPackage = readJson(path.join(root, 'package.json'));
  for (const { name, version } of [
    { name: '@webref/css', version: webrefPackage.manifest.version },
    { name: '@mdn/browser-compat-data', version: bcdPackage.manifest.version },
    { name: 'css-tree', version: cssTreePackage.manifest.version },
  ]) {
    if (rootPackage.devDependencies[name] !== version) {
      fail(`${name} must be exact-pinned to installed version ${version}`);
    }
  }

  const webref = readJson(path.join(webrefPackage.directory, 'css.json'));
  const bcd = readJson(path.join(bcdPackage.directory, 'data.json'));
  const webrefProperties = new Map(webref.properties.map((entry) => [entry.name, entry]));
  const scalarExpansion = deriveScalarExpansion({
    webrefProperties: webref.properties,
    webrefTypes: webref.types,
    bcdProperties: bcd.css.properties,
    baseProperties,
  });
  const scalarExpansionSummary = validateScalarExpansionAllowlist(
    config.scalarExpansion,
    scalarExpansion,
  );
  const scalarEnums = scalarExpansion
    .filter((property) => property.valueStrategy === 'keyword-enum')
    .map((property) => ({
      name: property.typeName,
      values: Object.fromEntries(
        property.keywords.map((keyword) => [
          `${property.typeName}${moonVariantName(keyword)}`,
          keyword,
        ]),
      ),
    }));
  const borderComposite = deriveBorderCompositeExpansion({
    config: config.borderCompositeExpansion,
    webrefProperties: webref.properties,
    webrefTypes: webref.types,
    webrefFunctions: webref.functions,
    bcdProperties: bcd.css.properties,
    existingProperties: [...baseProperties, ...scalarExpansion],
  });
  const enumDefinitions = [...config.enums, ...groupEnums, ...scalarEnums];
  const configuredProperties = [
    ...baseProperties,
    ...scalarExpansion,
    ...borderComposite.candidates,
    ...coverageApi.properties,
  ].map((property) =>
    coverageApi.overrides[property.cssName]
      ? { ...property, valueType: coverageApi.overrides[property.cssName] }
      : property,
  );
  const enumNames = new Set(enumDefinitions.map((entry) => entry.name));
  if (enumNames.size !== enumDefinitions.length) fail('enum names must be unique');
  const variantNames = enumDefinitions.flatMap((definition) => Object.keys(definition.values));
  if (new Set(variantNames).size !== variantNames.length) fail('enum variants must be unique');

  const functionNames = new Set(['declaration', 'animation_declaration', 'fallback_declaration']);
  const irNames = new Set();
  const metadata = [];
  const generatedProperties = [];
  const generatedBuilderProperties = [];
  const generatedContractProperties = [];
  for (const property of configuredProperties) {
    const functionName = moonFunctionName(property.cssName);
    const generatedFunctionNames = [
      functionName,
      `clear_${functionName}`,
      ...(property.valueType === 'animation-name' || property.fallbacks === false
        ? []
        : [`${functionName}_fallbacks`]),
      ...(property.dynamic ? [`dynamic_${functionName}`] : []),
    ];
    for (const generatedFunctionName of generatedFunctionNames) {
      if (functionNames.has(generatedFunctionName)) {
        fail(`duplicate function ${generatedFunctionName}`);
      }
      functionNames.add(generatedFunctionName);
    }
    const definition = webrefProperties.get(property.cssName);
    if (!definition) fail(`WebRef does not define ${property.cssName}`);
    const compatibility = bcd.css.properties[property.cssName]?.__compat;
    if (!compatibility) fail(`BCD does not define ${property.cssName}`);
    const status = compatibility.status;
    if (!status.standard_track || status.deprecated) {
      fail(`${property.cssName} is not a non-deprecated standards property in BCD`);
    }
    valueDescriptor(property.valueType, enumNames);
    const irName = styleDeclarationName(definition);
    if (irNames.has(irName)) fail(`duplicate StyleX IR property ${irName}`);
    irNames.add(irName);
    const atomicProperties = resolveAtomicProperties(
      property,
      webrefProperties,
      bcd.css.properties,
    );
    const atomicIrNames = atomicProperties.map((target) => target.irName);
    const grammar = analyzeDefinitionSyntax(definition.syntax ?? '');
    const grammarTier = grammar.safe ? 'tier-a' : 'tier-b';
    generatedProperties.push(renderProperty(property, irName, enumNames));
    generatedBuilderProperties.push(renderBuilderProperty(property, irName, enumNames));
    generatedContractProperties.push(renderContractProperty(property, irName, enumNames));
    metadata.push({
      cssName: property.cssName,
      functionName,
      irName,
      valueType: property.valueType,
      family: property.family,
      ...(property.valueStrategy
        ? {
            valueStrategy: property.valueStrategy,
            valueCoverage: property.valueCoverage,
          }
        : {}),
      ...(property.referenceProperty ? { referenceProperty: property.referenceProperty } : {}),
      ...(property.valueConstraints ? { valueConstraints: property.valueConstraints } : {}),
      ...(property.scalarAdapter
        ? {
            scalarAdapter: property.scalarAdapter,
            grammarReviewDigest: property.grammarReviewDigest,
            grammarReferences: property.grammarReferences,
            excludedSyntax: property.excludedSyntax,
          }
        : {}),
      ...(property.valueAdapter
        ? {
            valueAdapter: property.valueAdapter,
            grammarClosureDigest: property.grammarClosureDigest,
            grammarReferences: property.grammarReferences,
            excludedSyntax: property.excludedSyntax,
          }
        : {}),
      ...(commonValueFamilies[property.cssName]
        ? {
            authoredValueProfile: 'common-values-v1',
            authoredValueType: commonValueFamilies[property.cssName],
            excludedSyntax:
              commonValueFamilies[property.cssName] === 'BoxSize' ||
              commonValueFamilies[property.cssName] === 'FlexBasis'
                ? ['stretch', 'stretch()', 'contain', 'calc-size()', 'anchor-size()']
                : [],
          }
        : {}),
      grammarTier: property.valueAdapter || property.scalarAdapter ? 'tier-b' : grammarTier,
      fallbacks: property.valueType !== 'animation-name' && property.fallbacks !== false,
      conditions: property.conditions === true,
      dynamic: property.dynamic ?? null,
      atomicProperties,
      conflicts: atomicIrNames,
      syntax: definition.syntax ?? null,
      syntaxAstDigest: grammar.digest,
      grammarReason: property.scalarAdapter
        ? `reviewed-scalar:${property.scalarAdapter}`
        : property.valueAdapter
          ? 'reviewed-composite:stable-intersection'
          : grammar.safe
            ? grammar.reason
            : `reviewed-adapter:${grammar.reason}`,
      specification: definition.href,
      standardTrack: status.standard_track,
      experimental: status.experimental,
      deprecated: status.deprecated,
    });
  }

  const header = `// Generated by tools/generate-properties.mjs from @webref/css ${webrefPackage.manifest.version} and @mdn/browser-compat-data ${bcdPackage.manifest.version}. Do not edit.`;
  const helper = [
    '///|',
    'fn declaration(',
    '  property : String,',
    '  value : String,',
    '  conditions : Array[@ir.Condition],',
    ') -> @ir.Declaration {',
    '  @ir.declaration(property, @ir.text(value), conditions~, keyframe_allowed=true)',
    '}',
    '',
    '///|',
    'fn animation_declaration(',
    '  property : String,',
    '  value : @ir.AnimationName,',
    '  conditions : Array[@ir.Condition],',
    ') -> @ir.Declaration {',
    '  @ir.declaration(property, @ir.animation(value), conditions~)',
    '}',
    '',
    '///|',
    'fn fallback_declaration(',
    '  property : String,',
    '  values : Array[String],',
    '  conditions : Array[@ir.Condition],',
    ') -> @ir.Declaration {',
    '  @ir.declaration(property, @ir.fallbacks(values), conditions~, keyframe_allowed=true)',
    '}',
  ].join('\n');
  const moonbit = [
    header,
    '',
    ...enumDefinitions.map(renderEnum).flatMap((block) => [block, '']),
    helper,
    '',
    generatedProperties.join('\n\n'),
    '',
  ].join('\n');
  const builderMoonbit = [
    header.replace('Do not edit.', 'Fluent authoring API; do not edit.'),
    '',
    generatedBuilderProperties.join('\n\n'),
    '',
    generatedContractProperties.join('\n\n'),
    '',
  ].join('\n');
  const propertyFacade = [
    header.replace('Do not edit.', 'Root authoring facade; do not edit.'),
    '',
    '///|',
    'pub using @properties {',
    ...enumDefinitions.map((definition) => `  type ${definition.name},`),
    '}',
    '',
  ].join('\n');
  const metadataDocument = {
    schemaVersion: 17,
    sources: {
      '@webref/css': webrefPackage.manifest.version,
      '@mdn/browser-compat-data': bcdPackage.manifest.version,
      'css-tree': cssTreePackage.manifest.version,
    },
    scalarExpansion: {
      profile: SCALAR_EXPANSION_PROFILE,
      ...scalarExpansionSummary,
    },
    borderCompositeExpansion: {
      profile: BORDER_COMPOSITE_PROFILE,
      ...borderComposite.summary,
    },
    properties: metadata,
  };
  const typedProperties = new Set(metadata.map((property) => property.cssName));
  const coverage = webref.properties.map((definition) => {
    const compatibility = bcd.css.properties[definition.name]?.__compat;
    let classification = 'unsafe-only';
    let reason = 'missing-browser-compat-data';
    const grammar = analyzeDefinitionSyntax(definition.syntax ?? '');
    let grammarTier = 'tier-c';
    if (typedProperties.has(definition.name)) {
      classification = 'typed';
      const property = metadata.find((entry) => entry.cssName === definition.name);
      grammarTier = property.grammarTier;
      reason = property.grammarReason;
    } else if (compatibility?.status.deprecated) {
      classification = 'deprecated';
      reason = 'deprecated-in-browser-compat-data';
    } else if (compatibility?.status.standard_track) {
      classification = 'unsupported-grammar';
      reason = 'not-yet-mapped-to-a-safe-value-type';
    } else if (compatibility) {
      reason = 'not-on-the-standards-track';
    }
    return {
      cssName: definition.name,
      syntax: definition.syntax ?? null,
      syntaxAstDigest: grammar.digest,
      grammarTier,
      classification,
      reason:
        classification === 'typed'
          ? reason
          : grammar.safe
            ? `${reason}:missing-reviewed-capability-family`
            : grammar.reason,
    };
  });
  const coverageSummary = {};
  for (const property of coverage) {
    coverageSummary[property.classification] = (coverageSummary[property.classification] ?? 0) + 1;
  }
  const coverageDocument = {
    schemaVersion: 1,
    sources: metadataDocument.sources,
    summary: coverageSummary,
    properties: coverage,
  };

  atomicWrite(path.join(styleModule, 'properties', 'properties.mbt'), moonbit);
  atomicWrite(path.join(builderPackage, 'rules.generated.mbt'), builderMoonbit);
  atomicWrite(path.join(styleModule, 'property-facade.generated.mbt'), propertyFacade);
  atomicWrite(
    path.join(styleModule, 'properties', 'property-metadata.json'),
    `${JSON.stringify(metadataDocument, null, 2)}\n`,
  );
  atomicWrite(
    path.join(styleModule, 'properties', 'property-coverage.json'),
    `${JSON.stringify(coverageDocument, null, 2)}\n`,
  );
  execFileSync('moon', ['run', 'tools/generate-css-inputs.mbtx'], { cwd: root, stdio: 'pipe' });
  execFileSync('moon', ['run', 'tools/generate-common-values.mbtx'], { cwd: root, stdio: 'pipe' });
  execFileSync('moon', ['run', 'tools/generate-theme-paint.mbtx'], { cwd: root, stdio: 'pipe' });
  console.log(`Generated ${metadata.length} typed property functions from WebRef and BCD.`);
  return {
    ...readJson(path.join(styleModule, 'properties', 'property-metadata.json')),
    coverage: coverageSummary,
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    generateProperties();
  } catch (error) {
    console.error(error.stack ?? error);
    process.exitCode = 1;
  }
}
