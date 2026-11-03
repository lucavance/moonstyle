import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../../..');
const directory = import.meta.dirname;
const read = (filename) => JSON.parse(fs.readFileSync(filename, 'utf8'));
const digest = (value) =>
  `sha256:${createHash('sha256').update(JSON.stringify(value)).digest('hex')}`;
const lock = read(path.join(root, 'src/core/application-order.lock.json'));
const fixtures = ['component-a', 'component-b'].map((name) =>
  read(path.join(directory, `${name}.bundle.json`)),
);

function semanticDigest(bundle) {
  const { semanticDigest: _digest, ...semantic } = bundle;
  return digest(semantic);
}

function validateSyntheticRecords(bundle, property, className, css) {
  assert.equal(bundle.schemaVersion, 13);
  assert.equal(bundle.semanticDigest, semanticDigest(bundle), 'Existing fixture digest is invalid');
  assert.equal(bundle.rules.length, 1);
  const oracle = lock.properties.find((record) => record.property === property);
  assert.ok(oracle, `Current oracle does not contain ${property}`);
  assert.deepEqual(bundle.rules, [
    { property, className, ltr: css, rtl: null, priority100: oracle.priority100 },
  ]);
  assert.deepEqual(bundle.namespaces, [
    {
      name: 'badge',
      entries: oracle.entries.map((entry) => [
        entry.slot,
        entry.role === 'class' ? className : null,
      ]),
    },
  ]);
  for (const key of ['globals', 'recipes', 'markers', 'viewTransitionClasses']) {
    assert.deepEqual(bundle[key], []);
  }
}

assert.equal(lock.schemaVersion, 4);
assert.equal(lock.profile.name, 'stylex-0.19.1-application-order+font-aliases-v1');
validateSyntheticRecords(
  fixtures[0],
  'backgroundColor',
  'dep-a',
  '.dep-a{background-color:rgb(210 235 220)}',
);
validateSyntheticRecords(
  fixtures[1],
  'borderStyle',
  'dep-b',
  '.dep-b{border-style:solid;border-width:3px;border-color:rgb(30 110 75)}',
);
assert.equal(fixtures[0].module, 'fixture/component-a');
assert.equal(fixtures[1].module, 'fixture/component-b');
assert.deepEqual(fixtures[0].directDependencies, []);
assert.deepEqual(fixtures[0].dependencyClosure, []);
const previousDependency = {
  module: fixtures[0].module,
  semanticDigest: fixtures[0].semanticDigest,
};
assert.deepEqual(fixtures[1].directDependencies, [previousDependency]);
assert.deepEqual(fixtures[1].dependencyClosure, [previousDependency]);
assert.deepEqual(fixtures[1].contracts, fixtures[0].contracts);

// Refresh semantic identities; native validation below checks the fixture
// schema and contract structure before any outputs are written.
fixtures[0].semantics = { profile: lock.profile.name, digest: lock.semanticsDigest };
fixtures[0].semanticDigest = semanticDigest(fixtures[0]);
fixtures[1].semantics = { ...fixtures[0].semantics };
const dependency = { module: fixtures[0].module, semanticDigest: fixtures[0].semanticDigest };
fixtures[1].directDependencies = [dependency];
fixtures[1].dependencyClosure = [dependency];
fixtures[1].semanticDigest = semanticDigest(fixtures[1]);

const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'style-synthetic-fixture-'));
try {
  fs.writeFileSync(
    path.join(temporary, 'moon.mod'),
    'name = "local/synthetic-fixture"\nversion = "0.0.0"\nimport { "lampclaw/moonstyle@0.1.0" }\n',
  );
  fs.writeFileSync(path.join(temporary, 'moon.work'), `members = [".", ${JSON.stringify(root)}]\n`);
  fs.mkdirSync(path.join(temporary, 'main'));
  fs.writeFileSync(
    path.join(temporary, 'main/moon.pkg'),
    'import { "lampclaw/moonstyle", "lampclaw/moonstyle/extract" }\npkgtype(kind: "executable")\n',
  );
  const source = [
    '///|',
    'fn main {',
    '  let variables = @moonstyle.variable_scope("component-button")',
    '  let contract = @moonstyle.style_contract("button")',
    '    .allow_color(slots=[variables.color_slot("text", @moonstyle.rgb(23, 33, 43))])',
    '    .allow_border_color(tokens=[variables.color_token("border", @moonstyle.rgb(75, 150, 104))])',
    '    .allow_background_color(values=[@moonstyle.rgb(210, 235, 220)], tokens=[variables.color_token("surface", @moonstyle.rgb(226, 244, 232))])',
    '  let registry = @moonstyle.registry("fixture/component-a", [',
    '    @moonstyle.rule("badge").background_color(@moonstyle.rgb(210, 235, 220)),',
    '  ], contracts=[contract])',
    '  let compiled = @extract.compile_registry(registry, mappings_package="lampclaw/moonstyle-validation/tests/component_a_generated")',
    '  if !compiled.diagnostics.is_empty() { abort(@extract.render_diagnostics_text(compiled.diagnostics)) }',
    ...fixtures.map(
      (fixture) =>
        `  match @extract.decode_bundle(${JSON.stringify(JSON.stringify(fixture))}) {\n` +
        '    Err(errors) => abort(@extract.render_diagnostics_text(errors))\n' +
        '    Ok(bundle) => {\n' +
        '      let errors = @extract.validate_bundle(bundle)\n' +
        '      if !errors.is_empty() { abort(@extract.render_diagnostics_text(errors)) }\n' +
        '    }\n' +
        '  }',
    ),
    '  let output : Json = { "manifest": compiled.manifest, "mappings": compiled.mappings, "mappingsManifest": compiled.mappings_manifest }',
    '  println(output.stringify())',
    '}',
    '',
  ].join('\n');
  fs.writeFileSync(path.join(temporary, 'main/main.mbt'), source);
  const result = spawnSync('moon', ['run', 'main', '--target', 'native', '--release'], {
    cwd: temporary,
    encoding: 'utf8',
    maxBuffer: 8 * 1024 * 1024,
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  const generated = JSON.parse(result.stdout.trim().split('\n').at(-1));
  const native = JSON.parse(generated.manifest);
  assert.equal(native.rules.length, 1);
  const nativeClass = native.rules[0].className;
  assert.notEqual(nativeClass, 'dep-a');
  const renamed = JSON.parse(JSON.stringify(native).replaceAll(nativeClass, 'dep-a'));
  renamed.semanticDigest = semanticDigest(renamed);
  assert.deepEqual(
    renamed,
    fixtures[0],
    'Synthetic A differs from its native contract/value source',
  );
  const mappings = generated.mappings
    .replaceAll(nativeClass, 'dep-a')
    .replaceAll(native.semanticDigest, fixtures[0].semanticDigest);
  assert.match(mappings, /pub extend BadgeStyle with @runtime\.StaticStyleInput::\{to_compiled\}/);
  assert.match(mappings, /pub extend BadgeStyle with @runtime\.StyleInput::\{append_to\}/);
  const outputs = new Map([
    ...fixtures.map((fixture, index) => [
      path.join(directory, `component-${index === 0 ? 'a' : 'b'}.bundle.json`),
      `${JSON.stringify(fixture, null, 2)}\n`,
    ]),
    [path.join(root, 'validation/tests/component_a_generated/styles.generated.mbt'), mappings],
    [
      path.join(root, 'validation/tests/component_a_generated/moon.pkg'),
      generated.mappingsManifest,
    ],
  ]);
  for (const [filename, contents] of outputs) {
    if (process.argv.includes('--write')) fs.writeFileSync(filename, contents);
    else if (filename.endsWith('.json')) {
      assert.deepEqual(read(filename), JSON.parse(contents), `${filename} requires refresh`);
    } else {
      assert.equal(fs.readFileSync(filename, 'utf8'), contents, `${filename} requires refresh`);
    }
  }
  console.log(
    JSON.stringify(
      fixtures.map(({ module, semanticDigest }) => ({ module, semanticDigest })),
      null,
      2,
    ),
  );
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
