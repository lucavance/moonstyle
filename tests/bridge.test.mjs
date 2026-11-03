import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { test } from 'vite-plus/test';
import { buildStyles } from '../tools/build-styles.mjs';
import { validateManifest } from '../tools/stylex-bridge.mjs';

const repository = path.resolve(import.meta.dirname, '..');
const root = path.join(repository, 'validation');

test('synthetic dependency fixtures preserve the current oracle slots and dependency closure', () => {
  const lock = JSON.parse(
    fs.readFileSync(path.join(repository, 'src/core/application-order.lock.json'), 'utf8'),
  );
  const fixtures = ['component-a', 'component-b'].map((name) =>
    JSON.parse(
      fs.readFileSync(path.join(root, 'tests/dependency-fixtures', `${name}.bundle.json`), 'utf8'),
    ),
  );
  for (const fixture of fixtures) {
    assert.deepEqual(fixture.semantics, {
      profile: lock.profile.name,
      digest: lock.semanticsDigest,
    });
    const { semanticDigest, ...semantic } = fixture;
    assert.equal(
      semanticDigest,
      `sha256:${createHash('sha256').update(JSON.stringify(semantic)).digest('hex')}`,
    );
    assert.equal(fixture.rules.length, 1);
    const rule = fixture.rules[0];
    const oracle = lock.properties.find((property) => property.property === rule.property);
    assert.ok(oracle);
    assert.equal(rule.priority100, oracle.priority100);
    assert.deepEqual(fixture.namespaces, [
      {
        name: 'badge',
        entries: oracle.entries.map((entry) => [
          entry.slot,
          entry.role === 'class' ? rule.className : null,
        ]),
      },
    ]);
  }
  assert.deepEqual(fixtures[0].directDependencies, []);
  assert.deepEqual(fixtures[0].dependencyClosure, []);
  const dependency = {
    module: fixtures[0].module,
    semanticDigest: fixtures[0].semanticDigest,
  };
  assert.deepEqual(fixtures[1].directDependencies, [dependency]);
  assert.deepEqual(fixtures[1].dependencyClosure, [dependency]);
  assert.deepEqual(fixtures[1].contracts, fixtures[0].contracts);
});

test('production artifacts are emitted by the native MoonBit extractor', () => {
  buildStyles();
  const generatorOutputs = [
    'src/properties/property-metadata.json',
    'src/core/application-order.lock.json',
    'src/builder/rules.generated.mbt',
  ].map((filename) => path.join(repository, filename));
  const generatorDigests = generatorOutputs.map((filename) =>
    createHash('sha256').update(fs.readFileSync(filename)).digest('hex'),
  );
  const checked = spawnSync(process.execPath, ['tools/build-styles.mjs', '--check'], {
    cwd: repository,
    encoding: 'utf8',
  });
  assert.equal(checked.status, 0, `${checked.stdout}${checked.stderr}`);
  assert.match(checked.stdout, /Verified lampclaw\/moonstyle artifact schema v13/);
  assert.deepEqual(
    generatorOutputs.map((filename) =>
      createHash('sha256').update(fs.readFileSync(filename)).digest('hex'),
    ),
    generatorDigests,
  );
  const bundle = JSON.parse(
    fs.readFileSync(path.join(root, 'src/generated/styles.bundle.json'), 'utf8'),
  );
  const css = fs.readFileSync(path.join(root, 'src/generated/styles.generated.css'), 'utf8');
  const mappings = fs.readFileSync(path.join(root, 'src/generated/styles.generated.mbt'), 'utf8');
  assert.equal(bundle.schemaVersion, 13);
  assert.equal(bundle.module, 'lampclaw/moonstyle/examples');
  assert.equal(bundle.mappingsPackage, 'lampclaw/moonstyle-validation/src/generated');
  assert.equal(bundle.semantics.profile, 'stylex-0.19.1-application-order+font-aliases-v1');
  assert.match(bundle.semantics.digest, /^sha256:[0-9a-f]{64}$/);
  const { semanticDigest, ...semanticBundle } = bundle;
  assert.equal(
    semanticDigest,
    `sha256:${createHash('sha256').update(JSON.stringify(semanticBundle)).digest('hex')}`,
  );
  assert.deepEqual(
    bundle.directDependencies.map((dependency) => dependency.module),
    ['fixture/component-a', 'fixture/component-b'],
  );
  assert.deepEqual(
    bundle.dependencyClosure.map((dependency) => dependency.module),
    ['fixture/component-a', 'fixture/component-b'],
  );
  assert.deepEqual(bundle.contracts, [
    {
      module: 'fixture/component-a',
      name: 'button',
      mappingsPackage: 'lampclaw/moonstyle-validation/tests/component_a_generated',
      trait: 'ButtonStyleInput',
      properties: [
        {
          name: 'color',
          policy: 'exact',
          values: [],
          tokens: [],
          slots: [{ variable: '--component-button-text', category: 'color' }],
          expressions: [],
        },
        {
          name: 'borderColor',
          policy: 'exact',
          values: [],
          tokens: [{ variable: '--component-button-border', category: 'color' }],
          slots: [],
          expressions: [],
        },
        {
          name: 'backgroundColor',
          policy: 'exact',
          values: ['rgb(210 235 220)'],
          tokens: [{ variable: '--component-button-surface', category: 'color' }],
          slots: [],
          expressions: [],
        },
      ],
    },
  ]);
  assert.ok(Array.isArray(bundle.globals));
  assert.deepEqual(
    bundle.recipes.map(({ module, name }) => ({ module, name })),
    [{ module: 'lampclaw/moonstyle/examples', name: 'badge_recipe' }],
  );
  assert.deepEqual(bundle.markers, [
    {
      module: 'lampclaw/moonstyle/examples',
      mappingsPackage: 'lampclaw/moonstyle-validation/src/generated',
      name: 'demo_group',
      className: 'mybo78b',
    },
  ]);
  assert.deepEqual(bundle.viewTransitionClasses, [
    {
      module: 'lampclaw/moonstyle/examples',
      mappingsPackage: 'lampclaw/moonstyle-validation/src/generated',
      name: 'demo_shared',
      cssName: 'vtr568f1',
      styles: [
        {
          group: 'group',
          declarations: [
            ['animation-duration', ['1000ms']],
            ['font-size-adjust', ['.545']],
          ],
        },
        { group: 'image-pair', declarations: [['opacity', ['.9']]] },
        {
          group: 'old',
          declarations: [
            ['animation-duration', ['1000ms']],
            ['font-weight', ['400']],
          ],
        },
        {
          group: 'new',
          declarations: [
            ['animation-duration', ['1000ms']],
            ['font-weight', ['700']],
          ],
        },
      ],
    },
  ]);
  assert.ok(bundle.globals.some((global) => global.kind === 'position-try'));
  assert.match(css, /Generated by lampclaw\/moonstyle\/extract schema v13/);
  assert.ok(bundle.rules.every((rule) => Number.isInteger(rule.priority100)));
  assert.ok(bundle.rules.every((rule) => !Object.hasOwn(rule, 'priority')));
  assert.match(css, /@position-try --demo-tooltip/);
  assert.match(css, /:where\(\.mybo78b\[aria-expanded='true'\]\)/);
  assert.match(css, /margin-inline-start/);
  assert.doesNotMatch(css, /html\[dir=/);
  assert.match(mappings, /@runtime\.compiled_v5/);
  assert.match(mappings, /pub struct PageStyle/);
  assert.match(mappings, /@contract_0\.ButtonStyleInput for ActiveStyle/);
  assert.match(mappings, /@contract_0\.ButtonStyleInput for ButtonToneStyle/);
  assert.match(mappings, /pub let bundle_ref/);
  assert.match(mappings, /pub fn badge_recipe\(/);
  assert.match(mappings, /pub let demo_group_marker/);
  assert.match(mappings, /pub let demo_shared_view_transition_class/);
  assert.ok(
    bundle.namespaces.some((namespace) => namespace.entries.some((entry) => entry[1] === null)),
  );
  assert.ok(bundle.rules.every((rule) => rule.rtl == null));
  assert.doesNotMatch(css, /data-stylex/);
});

test('dependency bundle failures do not replace generated artifacts', () => {
  buildStyles();
  const outputs = [
    'src/generated/styles.generated.css',
    'src/generated/styles.generated.mbt',
    'src/generated/moon.pkg',
    'src/generated/styles.bundle.json',
  ].map((filename) => path.join(root, filename));
  const before = outputs.map((filename) => fs.readFileSync(filename, 'utf8'));
  const invalid = path.join(root, 'tests', 'dependency-fixtures', 'invalid.bundle.json');
  fs.writeFileSync(invalid, '{invalid', 'utf8');
  try {
    const result = spawnSync(
      'moon',
      [
        'run',
        'cmd/style_extract',
        '--target',
        'native',
        '--release',
        '--',
        '--diagnostics=json',
        '--tooling-protocol',
        '1',
        '--mappings-package',
        'lampclaw/moonstyle-validation/src/generated',
        '--dependency-bundle',
        invalid,
      ],
      { cwd: root, encoding: 'utf8' },
    );
    assert.notEqual(result.status, 0);
    assert.deepEqual(
      outputs.map((filename) => fs.readFileSync(filename, 'utf8')),
      before,
    );
  } finally {
    fs.rmSync(invalid, { force: true });
  }
});

test('extractor tooling protocol accepts v1, warns for legacy callers, and rejects mismatches', () => {
  buildStyles();
  const run = (...arguments_) =>
    spawnSync(
      'moon',
      [
        'run',
        'cmd/style_extract',
        '--target',
        'native',
        '--release',
        '--',
        '--diagnostics=json',
        '--mappings-package',
        'lampclaw/moonstyle-validation/src/generated',
        '--dependency-root',
        path.join(root, 'tests', 'dependency-fixtures'),
        '--check',
        ...arguments_,
      ],
      { cwd: root, encoding: 'utf8' },
    );

  const current = run('--tooling-protocol', '1');
  assert.equal(current.status, 0, `${current.stdout}${current.stderr}`);
  assert.doesNotMatch(current.stdout, /STYLE_TOOLING_PROTOCOL_LEGACY/);

  const legacy = run();
  assert.equal(legacy.status, 0, `${legacy.stdout}${legacy.stderr}`);
  assert.match(legacy.stdout, /STYLE_TOOLING_PROTOCOL_LEGACY/);

  const incompatible = run('--tooling-protocol', '2');
  assert.notEqual(incompatible.status, 0);
  assert.match(`${incompatible.stdout}${incompatible.stderr}`, /STYLE_TOOLING_PROTOCOL/);
  assert.match(`${incompatible.stdout}${incompatible.stderr}`, /requires protocol 1/);
});

test('structured cache packs validate entries and preserve unchanged outputs', () => {
  const temporary = fs.mkdtempSync(path.join(root, '_build', 'style-cache-test-'));
  const directory = path.join(temporary, 'cache');
  const formalOutputs = [
    'src/generated/styles.generated.css',
    'src/generated/styles.generated.mbt',
    'src/generated/moon.pkg',
    'src/generated/styles.bundle.json',
  ].map((filename) => path.join(root, filename));
  const formalBefore = formalOutputs.map((filename) => fs.readFileSync(filename, 'utf8'));
  const outputs = [
    'styles.generated.css',
    'styles.generated.mbt',
    'moon.pkg',
    'styles.bundle.json',
  ].map((filename) => path.join(temporary, 'outputs', filename));
  fs.mkdirSync(path.join(temporary, 'outputs'));
  const run = (...arguments_) =>
    spawnSync(
      'moon',
      [
        'run',
        'cmd/style_extract',
        '--target',
        'native',
        '--release',
        '--',
        '--tooling-protocol',
        '1',
        '--cache-dir',
        directory,
        '--mappings-package',
        'lampclaw/moonstyle-validation/src/generated',
        '--css-output',
        outputs[0],
        '--mappings-output',
        outputs[1],
        '--mappings-manifest-output',
        outputs[2],
        '--bundle-output',
        outputs[3],
        ...arguments_,
      ],
      {
        cwd: root,
        encoding: 'utf8',
        env: {
          ...process.env,
          MOONSTYLE_CACHE_IDENTITY: 'bridge-small-workload',
          MOONSTYLE_CACHE_FORCE: '1',
        },
      },
    );
  try {
    const first = run();
    assert.equal(first.status, 0, `${first.stdout}${first.stderr}`);
    const mtimes = outputs.map((filename) => fs.statSync(filename, { bigint: true }).mtimeNs);
    const second = run();
    assert.equal(second.status, 0, `${second.stdout}${second.stderr}`);
    assert.match(second.stdout, /Cache hit/);
    assert.deepEqual(
      outputs.map((filename) => fs.statSync(filename, { bigint: true }).mtimeNs),
      mtimes,
    );
    assert.ok(fs.readdirSync(directory).some((filename) => filename.endsWith('.cache.json')));

    const pack = fs.readdirSync(directory).find((filename) => filename.endsWith('.cache.json'));
    fs.writeFileSync(path.join(directory, pack), '{"corrupt":true}\n', 'utf8');
    const recovered = run();
    assert.equal(recovered.status, 0, `${recovered.stdout}${recovered.stderr}`);
    assert.match(recovered.stdout, /STYLE_CACHE_CORRUPT/);
    assert.doesNotMatch(recovered.stdout, /Cache hit/);

    const unknown = run('--cache-hint', 'removed');
    assert.notEqual(unknown.status, 0);
    assert.match(`${unknown.stdout}${unknown.stderr}`, /STYLE_CLI_UNKNOWN_ARGUMENT/);

    fs.rmSync(directory, { recursive: true, force: true });
    const bypassed = run('--no-cache');
    assert.equal(bypassed.status, 0, `${bypassed.stdout}${bypassed.stderr}`);
    assert.equal(fs.existsSync(directory), false);
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true });
    assert.deepEqual(
      formalOutputs.map((filename) => fs.readFileSync(filename, 'utf8')),
      formalBefore,
      'cache tests must preserve the four distributed artifacts',
    );
  }
});

test('manifest validation rejects unsupported and unsafe shapes', () => {
  assert.throws(
    () => validateManifest({ schemaVersion: 2, exportName: 'styles', namespaces: [] }),
    /schemaVersion must be 1/,
  );
  assert.throws(
    () =>
      validateManifest({
        schemaVersion: 1,
        exportName: 'styles',
        namespaces: [
          {
            name: 'bad',
            declarations: [{ property: 'width', value: { kind: 'dynamic', suffix: '`;boom()' } }],
          },
        ],
      }),
    /dynamic suffix.*unsafe/,
  );
});
