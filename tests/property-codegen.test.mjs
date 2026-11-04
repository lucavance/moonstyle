import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import { lexer } from 'css-tree';
import { test } from 'vite-plus/test';
import {
  BORDER_COMPOSITE_PROFILE,
  DAILY_CSS_PROFILE,
  SCALAR_EXPANSION_PROFILE,
  analyzeDefinitionSyntax,
  borderCompositeAtomicProperties,
  deriveBorderCompositeExpansion,
  deriveScalarExpansion,
  generateProperties,
  resolveDefinitionClosure,
  resolveAtomicProperties,
  reviewDailyCssGrammar,
} from '../tools/generate-properties.mjs';

const root = path.resolve(import.meta.dirname, '..');
const properties = path.join(root, 'src', 'properties');
const require = createRequire(import.meta.url);
const outputs = [
  path.join(properties, 'properties.mbt'),
  path.join(root, 'src', 'builder', 'rules.generated.mbt'),
  path.join(root, 'src', 'property-facade.generated.mbt'),
  path.join(properties, 'property-metadata.json'),
  path.join(properties, 'property-coverage.json'),
];
const propertySource = outputs[0];
const propertyMetadata = outputs[3];
const propertyCoverage = outputs[4];

test('daily CSS uses an explicit reviewed subset and fails on grammar drift', () => {
  const metadata = JSON.parse(fs.readFileSync(propertyMetadata, 'utf8'));
  const samples = {
    isolation: ['auto', 'isolate'],
    'white-space': ['normal', 'pre', 'nowrap', 'pre-wrap', 'pre-line', 'break-spaces'],
    'text-wrap': ['wrap', 'nowrap', 'auto', 'balance', 'stable', 'pretty'],
    'vertical-align': [
      'baseline',
      'sub',
      'super',
      'text-top',
      'text-bottom',
      'middle',
      'top',
      'bottom',
      '-2px',
      '15%',
    ],
    'will-change': ['auto', 'scroll-position', 'contents', 'transform, opacity'],
    'font-variation-settings': ['normal', '"wght" 650, "wdth" 95.5', '"XTRA" -1'],
  };
  for (const [name, values] of Object.entries(samples)) {
    const property = metadata.properties.find((entry) => entry.cssName === name);
    assert.equal(property.authoredValueProfile, DAILY_CSS_PROFILE);
    assert.equal(property.grammarReviewDigest, property.syntaxAstDigest);
    for (const value of values)
      assert.ok(lexer.matchProperty(name, value).matched, `${name}: ${value}`);
    assert.throws(() => reviewDailyCssGrammar(name, 'new-keyword'), /grammar changed/);
  }
  assert.deepEqual(reviewDailyCssGrammar('color', '<color>'), {});
});

function digest(filename) {
  return createHash('sha256').update(fs.readFileSync(filename)).digest('hex');
}

test('property generation is deterministic and uses pinned structured data', () => {
  const first = generateProperties();
  const firstDigests = outputs.map(digest);
  const second = generateProperties();
  assert.deepEqual(outputs.map(digest), firstDigests);
  assert.deepEqual(second, first);
  assert.deepEqual(first.sources, {
    '@webref/css': '8.7.8',
    '@mdn/browser-compat-data': '8.1.7',
    'css-tree': '3.2.1',
  });
  assert.equal(first.schemaVersion, 18);
  assert.equal(first.properties.length, 392);
  const page = first.properties.find((property) => property.cssName === 'page');
  assert.equal(page.valueType, 'page-value');
  assert.equal(page.family, 'layout');
  assert.deepEqual(first.scalarExpansion, {
    profile: SCALAR_EXPANSION_PROFILE,
    total: 129,
    strategies: {
      primitive: 54,
      'keyword-enum': 60,
      'property-reference': 9,
      'reviewed-scalar': 6,
    },
    families: {
      layout: 63,
      typography: 28,
      visual: 23,
      interaction: 8,
      motion: 7,
    },
  });
  assert.deepEqual(first.borderCompositeExpansion, {
    profile: BORDER_COMPOSITE_PROFILE,
    total: 40,
    adapters: {
      'border-side': 11,
      'border-colors': 2,
      'border-styles': 2,
      'border-widths': 2,
      color: 6,
      'line-style': 6,
      'line-width': 6,
      'corner-radius': 4,
      outline: 1,
    },
    families: { visual: 40 },
  });
  assert.ok(first.properties.every((property) => property.standardTrack));
  assert.ok(first.properties.every((property) => property.specification.startsWith('https://')));
  assert.deepEqual(
    [...new Set(first.properties.map((property) => property.family))].sort((left, right) =>
      left.localeCompare(right),
    ),
    ['interaction', 'layout', 'motion', 'typography', 'visual'],
  );
  assert.equal(first.coverage.typed, first.properties.length);
  assert.deepEqual(first.coverage, {
    'unsafe-only': 233,
    'unsupported-grammar': 190,
    typed: 392,
    deprecated: 7,
  });
  assert.equal(
    Object.values(first.coverage).reduce((sum, count) => sum + count, 0),
    JSON.parse(fs.readFileSync(propertyCoverage, 'utf8')).properties.length,
  );
  const margin = first.properties.find((property) => property.cssName === 'margin');
  assert.deepEqual(margin.atomicProperties, [
    { cssName: 'margin-top', irName: 'marginTop' },
    { cssName: 'margin-inline-end', irName: 'marginInlineEnd' },
    { cssName: 'margin-bottom', irName: 'marginBottom' },
    { cssName: 'margin-inline-start', irName: 'marginInlineStart' },
  ]);
  assert.ok(
    first.properties.every(
      (property) =>
        property.atomicProperties.length > 0 &&
        new Set(property.atomicProperties.map((target) => target.irName)).size ===
          property.atomicProperties.length,
    ),
  );
});

test('every reviewed property generates a Rule-only clear method', () => {
  const source = fs.readFileSync(path.join(root, 'src', 'builder', 'rules.generated.mbt'), 'utf8');
  const methods = [...source.matchAll(/pub fn Rule::clear_([\da-z_]+)\(/g)].map(
    (match) => match[1],
  );
  const expected = new Set(
    JSON.parse(fs.readFileSync(propertyMetadata, 'utf8')).properties.map(
      (property) => property.functionName,
    ),
  );
  const clearMethods = methods.filter((method) => expected.has(method));
  assert.equal(clearMethods.length, 392);
  assert.equal(new Set(clearMethods).size, 392);
  assert.ok(clearMethods.includes('color'));
  assert.ok(clearMethods.includes('margin'));
  assert.ok(clearMethods.includes('clear'));
  const frameClearMethods = [...source.matchAll(/pub fn Frame::clear_([\da-z_]+)\(/g)]
    .map((match) => match[1])
    .filter((method) => expected.has(method));
  assert.deepEqual(frameClearMethods, []);
});

test('stable scalar allowlist exactly matches the pinned structured-data derivation', () => {
  const propertyApi = JSON.parse(
    fs.readFileSync(path.join(properties, 'property-api.json'), 'utf8'),
  );
  const metadata = JSON.parse(fs.readFileSync(propertyMetadata, 'utf8'));
  const webref = require('@webref/css/css.json');
  const bcd = require('@mdn/browser-compat-data');
  const baseProperties = metadata.properties.filter((property) => !property.valueStrategy);
  const derived = deriveScalarExpansion({
    webrefProperties: webref.properties,
    webrefTypes: webref.types,
    bcdProperties: bcd.css.properties,
    baseProperties,
  });
  assert.equal(baseProperties.length, 223);
  assert.equal(derived.length, 129);
  for (const [family, cssNames] of Object.entries(propertyApi.scalarExpansion.families)) {
    assert.deepEqual(
      derived.filter((property) => property.family === family).map((property) => property.cssName),
      cssNames,
    );
  }

  const generatedExpansion = metadata.properties.filter(
    (property) => property.valueCoverage === 'conservative-scalar',
  );
  assert.deepEqual(
    generatedExpansion.map((property) => property.cssName),
    derived.map((property) => property.cssName),
  );
  assert.ok(
    generatedExpansion.every(
      (property) =>
        property.valueCoverage === 'conservative-scalar' &&
        property.fallbacks &&
        !property.conditions &&
        property.dynamic == null &&
        property.standardTrack &&
        !property.experimental &&
        !property.deprecated &&
        !property.cssName.startsWith('-') &&
        property.valueType !== 'string',
    ),
  );
  for (const excluded of ['all', 'line-clamp', 'ruby-overhang']) {
    assert.ok(!metadata.properties.some((property) => property.cssName === excluded), excluded);
  }
});

test('stable border composite allowlist is exact, typed, and recursively reviewed', () => {
  const propertyApi = JSON.parse(
    fs.readFileSync(path.join(properties, 'property-api.json'), 'utf8'),
  );
  const metadata = JSON.parse(fs.readFileSync(propertyMetadata, 'utf8'));
  const webref = require('@webref/css/css.json');
  const bcd = require('@mdn/browser-compat-data');
  const derived = deriveBorderCompositeExpansion({
    config: propertyApi.borderCompositeExpansion,
    webrefProperties: webref.properties,
    webrefTypes: webref.types,
    webrefFunctions: webref.functions,
    bcdProperties: bcd.css.properties,
    existingProperties: metadata.properties.filter(
      (property) => property.valueStrategy !== 'reviewed-composite',
    ),
  });
  assert.equal(derived.candidates.length, 40);
  assert.deepEqual(
    { profile: BORDER_COMPOSITE_PROFILE, ...derived.summary },
    metadata.borderCompositeExpansion,
  );
  assert.deepEqual(
    derived.candidates.map((property) => property.cssName),
    metadata.properties
      .filter((property) => property.valueStrategy === 'reviewed-composite')
      .map((property) => property.cssName),
  );
  assert.ok(
    derived.candidates.every(
      (property) =>
        property.family === 'visual' &&
        property.valueCoverage === 'stable-intersection' &&
        property.grammarClosureDigest.startsWith('sha256:') &&
        property.grammarReferences.length > 0,
    ),
  );
  assert.ok(
    derived.candidates
      .find((property) => property.cssName === 'border-top-color')
      .grammarReferences.includes('function:stripes()'),
  );
  assert.deepEqual(borderCompositeAtomicProperties('border-block', 'border-side'), [
    'border-block-start-width',
    'border-block-start-style',
    'border-block-start-color',
    'border-block-end-width',
    'border-block-end-style',
    'border-block-end-color',
  ]);
  assert.deepEqual(borderCompositeAtomicProperties('border-inline-color', 'border-colors'), [
    'border-inline-start-color',
    'border-inline-end-color',
  ]);
  const byName = new Map(derived.candidates.map((property) => [property.cssName, property]));
  assert.deepEqual(byName.get('border-top-width').excludedSyntax, ['hairline']);
  assert.deepEqual(byName.get('border-top-left-radius').excludedSyntax, [
    'slash-separated-border-radius-syntax',
  ]);
  assert.deepEqual(byName.get('border-top-color').excludedSyntax, ['image-1D']);
  const driftedConfig = structuredClone(propertyApi.borderCompositeExpansion);
  driftedConfig.groups[0].cssNames[0] = 'border-image';
  assert.throws(
    () =>
      deriveBorderCompositeExpansion({
        config: driftedConfig,
        webrefProperties: webref.properties,
        webrefTypes: webref.types,
        webrefFunctions: webref.functions,
        bcdProperties: bcd.css.properties,
        existingProperties: metadata.properties.filter(
          (property) => property.valueStrategy !== 'reviewed-composite',
        ),
      }),
    /differs from the frozen stable-border-composite-v1 allowlist/,
  );
});

test('definition closure resolution is deterministic and fails closed', () => {
  const types = new Map([
    ['outer', { syntax: '<inner> | none' }],
    ['inner', { syntax: '<length> | thin' }],
  ]);
  const propertiesByName = new Map([['example', { syntax: '<outer>' }]]);
  const first = resolveDefinitionClosure("<'example'>", types, propertiesByName);
  assert.deepEqual(resolveDefinitionClosure("<'example'>", types, propertiesByName), first);
  assert.deepEqual(first.references, ['property:example', 'type:inner', 'type:outer']);
  assert.throws(
    () =>
      resolveDefinitionClosure(
        '<cycle-a>',
        new Map([
          ['cycle-a', { syntax: '<cycle-b>' }],
          ['cycle-b', { syntax: '<cycle-a>' }],
        ]),
        new Map(),
      ),
    /reference cycle/,
  );
  assert.throws(
    () => resolveDefinitionClosure('<missing>', new Map(), new Map()),
    /missing WebRef type definition missing/,
  );
});

test('generated scalar keyword enums are property-specific and lexer-valid', () => {
  const metadata = JSON.parse(fs.readFileSync(propertyMetadata, 'utf8'));
  const webref = require('@webref/css/css.json');
  const bcd = require('@mdn/browser-compat-data');
  const derived = deriveScalarExpansion({
    webrefProperties: webref.properties,
    webrefTypes: webref.types,
    bcdProperties: bcd.css.properties,
    baseProperties: metadata.properties.filter((property) => !property.valueStrategy),
  });
  const enums = derived.filter((property) => property.valueStrategy === 'keyword-enum');
  assert.equal(enums.length, 60);
  assert.equal(new Set(enums.map((property) => property.typeName)).size, enums.length);
  const source = fs.readFileSync(propertySource, 'utf8');
  for (const property of enums) {
    assert.ok(property.keywords.length >= 2, property.cssName);
    assert.ok(
      property.keywords.every(
        (keyword) => lexer.matchProperty(property.cssName, keyword).matched != null,
      ),
      property.cssName,
    );
    assert.match(source, new RegExp(`pub\\(all\\) enum ${property.typeName} \\{`));
    const block = source.match(
      new RegExp(`pub\\(all\\) enum ${property.typeName} \\{([\\s\\S]*?)\\n\\}`),
    )?.[1];
    assert.ok(block, property.typeName);
    assert.ok(
      block
        .trim()
        .split('\n')
        .every((line) => line.trim().startsWith(property.typeName)),
      property.typeName,
    );
  }
});

test('simple property references reuse the reviewed target value category', () => {
  const metadata = JSON.parse(fs.readFileSync(propertyMetadata, 'utf8'));
  const byName = new Map(metadata.properties.map((property) => [property.cssName, property]));
  const references = metadata.properties.filter(
    (property) => property.valueStrategy === 'property-reference',
  );
  assert.equal(references.length, 9);
  for (const property of references) {
    const target = byName.get(property.referenceProperty);
    assert.ok(target, property.cssName);
    assert.equal(property.valueType, target.valueType, property.cssName);
    assert.equal(property.family, target.family, property.cssName);
  }
});

test('reviewed logical sizes retain Length without widening automatic scalar grammar', () => {
  const metadata = JSON.parse(fs.readFileSync(propertyMetadata, 'utf8'));
  const logicalSizes = [
    'block-size',
    'inline-size',
    'max-block-size',
    'max-inline-size',
    'min-block-size',
    'min-inline-size',
  ];
  const reviewed = metadata.properties.filter(
    (property) => property.valueStrategy === 'reviewed-scalar',
  );
  assert.deepEqual(
    reviewed.map((property) => property.cssName),
    logicalSizes,
  );
  const source = fs.readFileSync(propertySource, 'utf8');
  const builder = fs.readFileSync(outputs[1], 'utf8');
  for (const property of reviewed) {
    assert.equal(property.valueType, 'length');
    assert.equal(property.family, 'layout');
    assert.equal(property.scalarAdapter, 'logical-size-length');
    assert.equal(property.grammarTier, 'tier-b');
    assert.equal(property.grammarReason, 'reviewed-scalar:logical-size-length');
    assert.equal(property.referenceProperty, undefined);
    assert.equal(property.valueAdapter, undefined);
    assert.match(property.grammarReviewDigest, /^sha256:[\da-f]{64}$/);
    assert.deepEqual(property.grammarReferences, ['type:box-size']);
    assert.ok(property.excludedSyntax.includes('anchor-size()'));
    assert.ok(property.excludedSyntax.includes('calc-size()'));
    assert.ok(property.excludedSyntax.includes('stretch()'));
    assert.equal(analyzeDefinitionSyntax(property.syntax).safe, false);
    for (const sample of ['1px', '1%']) {
      assert.ok(lexer.matchProperty(property.cssName, sample).matched, property.cssName);
    }
    assert.match(
      source,
      new RegExp(`pub fn ${property.functionName}\\(value : @values\\.Length\\)`),
    );
    assert.match(
      builder,
      new RegExp(`pub fn\\[T : BoxSizeInput\\] Rule::${property.functionName}\\(`),
    );
    assert.equal(property.authoredValueProfile, 'common-values-v1');
    assert.equal(property.authoredValueType, 'BoxSize');
    assert.ok(!property.excludedSyntax.includes('min-content'));
  }
  assert.equal(new Set(reviewed.map((property) => property.grammarReviewDigest)).size, 2);
});

test('logical-size grammar review rejects root and named-type drift', () => {
  const webref = require('@webref/css/css.json');
  const bcd = require('@mdn/browser-compat-data');
  const source = webref.properties.find((property) => property.name === 'block-size');
  const derive = (property, types = webref.types) =>
    deriveScalarExpansion({
      webrefProperties: [property],
      webrefTypes: types,
      bcdProperties: bcd.css.properties,
      baseProperties: [],
    });
  const [reviewed] = derive(source);
  const [withWhitespace] = derive({ ...source, syntax: `  ${source.syntax}  ` });
  assert.equal(withWhitespace.grammarReviewDigest, reviewed.grammarReviewDigest);
  assert.throws(
    () => derive({ ...source, syntax: `${source.syntax} | arbitrary-keyword` }),
    /logical-size grammar changed/,
  );
  assert.throws(
    () =>
      derive(
        source,
        webref.types.map((type) =>
          type.name === 'box-size' ? { ...type, syntax: '<color>' } : type,
        ),
      ),
    /logical-size grammar changed/,
  );
  assert.throws(
    () =>
      derive(
        source,
        webref.types.filter((type) => type.name !== 'box-size'),
      ),
    /requires the reviewed box-size definition/,
  );
  assert.throws(() => derive({ ...source, syntax: '<' }), /unparseable logical-size grammar/);
  assert.deepEqual(
    deriveScalarExpansion({
      webrefProperties: [{ ...source, name: 'unreviewed-logical-size' }],
      webrefTypes: webref.types,
      bcdProperties: { 'unreviewed-logical-size': bcd.css.properties['block-size'] },
      baseProperties: [],
    }),
    [],
  );
});

test('font-width exposes the reviewed finite non-negative Percentage API', () => {
  const metadata = JSON.parse(fs.readFileSync(propertyMetadata, 'utf8'));
  const property = metadata.properties.find((entry) => entry.cssName === 'font-width');
  assert.equal(property.valueType, 'percentage');
  assert.equal(property.family, 'typography');
  assert.equal(property.valueStrategy, 'primitive');
  assert.deepEqual(property.valueConstraints, { minimum: 0, finite: true });
  assert.equal(property.experimental, false);
  const source = fs.readFileSync(propertySource, 'utf8');
  const builder = fs.readFileSync(outputs[1], 'utf8');
  assert.match(source, /pub fn font_width\(value : @values\.Percentage\)/);
  assert.match(source, /pub fn font_width_fallbacks\(/);
  for (const owner of ['Rule', 'Frame']) {
    assert.match(builder, new RegExp(`pub fn\\[T : PercentageInput\\] ${owner}::font_width\\(`));
  }
  assert.match(builder, /pub fn Rule::clear_font_width\(/);
  assert.match(builder, /pub fn StyleContract::allow_font_width\(/);
});

test('definition syntax analysis accepts only the reviewed grammar subset', () => {
  const accepted = ['<length> | auto', '<color>#', '[ <number> | <percentage> ]?', '<length>{1,4}'];
  for (const syntax of accepted) {
    const first = analyzeDefinitionSyntax(syntax);
    const second = analyzeDefinitionSyntax(syntax);
    assert.equal(first.safe, true, syntax);
    assert.deepEqual(second, first);
    assert.match(first.digest, /^sha256:[\da-f]{64}$/);
  }
  for (const syntax of ['<length> || <color>', "<'margin'>"]) {
    assert.equal(analyzeDefinitionSyntax(syntax).safe, true, syntax);
  }
  const rejected = new Map([
    ['<length> && <color>', 'unsupported-combinator-and'],
    ['<transform-function>', 'unsupported-type-transform-function'],
    ['foo()', 'unsupported-function-foo'],
  ]);
  for (const [syntax, reason] of rejected) {
    const analysis = analyzeDefinitionSyntax(syntax);
    assert.equal(analysis.safe, false, syntax);
    assert.equal(analysis.reason, reason, syntax);
  }
});

test('generated common API does not accept raw property names', () => {
  const source = fs.readFileSync(propertySource, 'utf8');
  assert.match(source, /pub fn width\(/);
  assert.match(source, /pub fn background_color\(/);
  assert.match(source, /pub fn margin_inline_start\(/);
  assert.match(source, /pub fn border_start_start_radius\(/);
  assert.match(source, /pub fn width\([\s\S]+\) -> LayoutDeclaration/);
  assert.match(source, /pub fn background_color\([\s\S]+\) -> VisualDeclaration/);
  assert.doesNotMatch(source, /pub fn [^(]+\(property : String/);
  assert.doesNotMatch(source, /unsafe_raw/);
});

test('every typed property generates an ordered fallback API', () => {
  const source = fs.readFileSync(path.join(properties, 'properties.mbt'), 'utf8');
  const metadata = JSON.parse(
    fs.readFileSync(path.join(properties, 'property-metadata.json'), 'utf8'),
  );
  for (const property of metadata.properties.filter((property) => property.fallbacks)) {
    assert.match(source, new RegExp(`pub fn ${property.functionName}_fallbacks\\(`));
  }
});

test('every typed property generates an exact component-contract allow method', () => {
  const source = fs.readFileSync(path.join(root, 'src', 'builder', 'rules.generated.mbt'), 'utf8');
  const metadata = JSON.parse(fs.readFileSync(propertyMetadata, 'utf8'));
  for (const property of metadata.properties) {
    assert.match(
      source,
      new RegExp(`pub fn StyleContract::allow_${property.functionName}\\(`),
      property.functionName,
    );
  }
  assert.equal([...source.matchAll(/pub fn StyleContract::allow_[a-z0-9_]+\(/g)].length, 392);
  assert.match(
    source,
    /pub fn StyleContract::allow_color\([\s\S]*values\? : Array\[@values\.Color\] = \[\],[\s\S]*tokens\? : Array\[@values\.ColorToken\] = \[\],[\s\S]*slots\? : Array\[@values\.ColorSlot\] = \[\],[\s\S]*\) -> StyleContract/,
  );
  assert.match(
    source,
    /pub fn StyleContract::allow_display\([\s\S]*values\? : Array\[@properties\.Display\] = \[\],[\s\S]*\) -> StyleContract/,
  );
  assert.match(
    source,
    /pub fn StyleContract::allow_animation_name\(self : StyleContract, keywords\? : Array\[@values\.CssWideKeyword\] = \[\], lists\? : Array\[AnimationNames\] = \[\]\) -> StyleContract/,
  );
});

test('the reference registry uses only generated safe APIs', () => {
  const source = fs.readFileSync(
    path.join(root, 'validation', 'examples', 'styles', 'styles.mbt'),
    'utf8',
  );
  assert.doesNotMatch(source, /\bunsafe_raw(?:_fallbacks)?\b/);
});

test('atomic property validation rejects unsafe reviewed metadata', () => {
  const definitions = new Map([
    ['margin-top', { name: 'margin-top', styleDeclaration: ['marginTop'] }],
    ['legacy', { name: 'legacy', styleDeclaration: ['legacy'] }],
  ]);
  const compatibility = {
    'margin-top': { __compat: { status: { standard_track: true, deprecated: false } } },
    legacy: { __compat: { status: { standard_track: true, deprecated: true } } },
  };
  assert.throws(
    () =>
      resolveAtomicProperties(
        { cssName: 'margin', atomicProperties: ['margin-top', 'margin-top'] },
        definitions,
        compatibility,
      ),
    /atomicProperties must be unique/,
  );
  assert.throws(
    () =>
      resolveAtomicProperties(
        { cssName: 'margin', atomicProperties: [''] },
        definitions,
        compatibility,
      ),
    /empty atomic property/,
  );
  assert.throws(
    () =>
      resolveAtomicProperties(
        { cssName: 'margin', atomicProperties: ['legacy'] },
        definitions,
        compatibility,
      ),
    /not a non-deprecated standards atomic property/,
  );
});
