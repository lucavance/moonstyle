import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { test } from 'vite-plus/test';
import { toolchainIssues } from '../tools/check-toolchain.mjs';

const root = path.resolve(import.meta.dirname, '..');

const expected = {
  schemaVersion: 1,
  release: { os: 'ubuntu', osVersion: '26.04', architecture: 'x64' },
  tools: { moonCli: '1', node: '2' },
};

test('toolchain contract distinguishes portable and release validation', () => {
  const differentOperatingSystem = {
    schemaVersion: 1,
    release: { os: 'darwin', osVersion: '26', architecture: 'arm64' },
    tools: { moonCli: '1', node: '2' },
  };
  assert.deepEqual(toolchainIssues(expected, differentOperatingSystem), []);
  assert.match(
    toolchainIssues(expected, differentOperatingSystem, { requireRelease: true }).join('\n'),
    /release os: expected ubuntu/,
  );
});

test('toolchain contract reports exact tool drift', () => {
  const drifted = structuredClone(expected);
  drifted.tools.node = '3';
  assert.deepEqual(toolchainIssues(expected, drifted), ['node: expected 2, got 3']);
});

test('package and GitHub workflows use the frozen release toolchain', () => {
  const contract = JSON.parse(fs.readFileSync(path.join(root, 'toolchain.json'), 'utf8'));
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
  assert.equal(manifest.devDependencies['vite-plus'], contract.tools.vitePlus);
  assert.equal(
    manifest.devDependencies.vite,
    `npm:@voidzero-dev/vite-plus-core@${contract.tools.vitePlus}`,
  );
  assert.equal(manifest.overrides.vite, manifest.devDependencies.vite);
  assert.equal(manifest.overrides.postcss, '8.5.32');
  assert.equal(manifest.overrides['source-map-js'], '1.2.2');
  assert.equal(manifest.overrides.browserslist, '4.29.5');
  assert.equal(manifest.devDependencies.playwright, contract.tools.playwright);
  assert.equal(manifest.packageManager, `bun@${contract.tools.bun}`);
  assert.equal(
    fs.readFileSync(path.join(root, '.node-version'), 'utf8').trim(),
    contract.tools.node,
  );
  const setup = fs.readFileSync(
    path.join(root, '.github/actions/setup-moonbit/action.yml'),
    'utf8',
  );
  assert.match(setup, /inputs\.version != inputs\.core-version/);
  assert.match(setup, /https:\/\/cli\.moonbitlang\.com\/install\/unix\.sh/);
  assert.match(setup, /sha256sum --check --strict/);
  assert.match(setup, /MOONBIT_VERSION: \$\{\{ inputs\.version \}\}/);
  assert.match(setup, /bash "\$RUNNER_TEMP\/moonbit-install\.sh" "\$MOONBIT_VERSION"/);
  assert.match(setup, /echo "MOON_HOME=\$RUNNER_TEMP\/moonstyle-moon" >> "\$GITHUB_ENV"/);
  assert.match(
    fs.readFileSync(path.join(root, '.github/actions/setup-moonbit/installer.sha256'), 'utf8'),
    /^[a-f0-9]{64}  moonbit-install\.sh\n$/,
  );

  for (const filename of fs.readdirSync(path.join(root, '.github/workflows'))) {
    const workflow = fs.readFileSync(path.join(root, '.github/workflows', filename), 'utf8');
    assert.ok(workflow.includes('uses: ./.github/actions/setup-moonbit'));
    assert.doesNotMatch(workflow, /hustcer\/setup-moonbit/);
    assert.match(workflow, /runs-on: ubuntu-26\.04/);
    assert.match(
      workflow,
      new RegExp(`version: '${contract.tools.vitePlus.replaceAll('.', '\\.')}'`),
    );
    assert.match(
      workflow,
      new RegExp(`node-version: '${contract.tools.node.replaceAll('.', '\\.')}'`),
    );
    assert.match(
      workflow,
      new RegExp(
        `version: '${contract.tools.moonCompiler.replaceAll('.', '\\.').replace('+', '\\+')}'`,
      ),
    );
    assert.match(
      workflow,
      new RegExp(
        `core-version: '${contract.tools.moonCore.replaceAll('.', '\\.').replace('+', '\\+')}'`,
      ),
    );
    assert.doesNotMatch(workflow, /uses:\s+\S+@(?:main|v\d+)/);
    assert.match(workflow, /run: vp run install-oracle/);
    assert.match(workflow, /actions\/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9/);
  }
});

test('every workflow initializes the MoonBit registry before script execution', () => {
  for (const filename of fs.readdirSync(path.join(root, '.github/workflows'))) {
    const workflow = fs.readFileSync(path.join(root, '.github/workflows', filename), 'utf8');
    const setup = workflow.search(
      /uses: \.\/(?:candidate\/|evidence\/)?\.github\/actions\/setup-moonbit/,
    );
    const version = workflow.indexOf('moon version --all');
    const update = workflow.indexOf('moon update');
    const firstScript = workflow.search(/\b(?:moon|vp) run\b/);
    assert.ok(setup >= 0 && setup < version, `${filename}: report the installed toolchain`);
    assert.ok(version < update, `${filename}: initialize the installed toolchain's registry`);
    assert.ok(update < firstScript, `${filename}: initialize the registry before scripts`);
  }
});

test('standalone scripts declare a reproducible async dependency in import frontmatter', () => {
  const directory = path.join(root, 'tools');
  for (const filename of fs.readdirSync(directory).filter((name) => name.endsWith('.mbtx'))) {
    const script = fs.readFileSync(path.join(directory, filename), 'utf8');
    const imports = /^----\nimport \{\n([\s\S]*?)\n\}\n----\n/.exec(script)?.[1];
    assert.ok(imports, `${filename}: import frontmatter is required`);
    const dependencies = [...imports.matchAll(/"(moonbitlang\/async[^"\s]*)"/g)];
    assert.ok(dependencies.length > 0, `${filename}: declare async explicitly`);
    for (const [, dependency] of dependencies)
      assert.match(dependency, /^moonbitlang\/async@0\.22\.5(?:\/[^@]+)?$/, filename);
  }
});

test('CI validates included examples without application credentials', () => {
  const ci = fs.readFileSync(path.join(root, '.github/workflows/ci.yml'), 'utf8');
  assert.match(ci, /run: vp run validate-ci/);
  for (const filename of fs.readdirSync(path.join(root, '.github/workflows'))) {
    const workflow = fs.readFileSync(path.join(root, '.github/workflows', filename), 'utf8');
    assert.doesNotMatch(workflow, /secrets\.|ssh-key:|repository:/, filename);
  }
  for (const filename of [
    'validation/moon.mod',
    'validation/src/demo/main.mbt',
    'validation/examples/styles/styles.mbt',
    'validation/tests/dependency-fixtures/component-a.bundle.json',
    'docs/quickstart.md',
  ]) {
    assert.ok(fs.existsSync(path.join(root, filename)), filename);
  }
});
