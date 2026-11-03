import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'vite-plus/test';
import { discoverDependencyBundles, loadStyleConfig } from '../tools/style-config.mjs';

function writeConfig(directory, overrides = {}) {
  const config = {
    schemaVersion: 1,
    mappingsPackage: 'example/app/generated',
    outputs: {
      css: 'generated/styles.css',
      mappings: 'generated/styles.mbt',
      mappingsManifest: 'generated/moon.pkg',
      bundle: 'generated/styles.bundle.json',
    },
    dependencyRoots: ['dependencies'],
    cacheDirectory: '_build/style-cache',
    ...overrides,
  };
  fs.writeFileSync(
    path.join(directory, 'style.config.json'),
    `${JSON.stringify(config, null, 2)}\n`,
  );
}

test('style config discovers dependency bundles recursively and deterministically', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'style-config-'));
  try {
    fs.mkdirSync(path.join(directory, 'dependencies', 'nested'), { recursive: true });
    fs.writeFileSync(path.join(directory, 'dependencies', 'z.bundle.json'), '{}');
    fs.writeFileSync(path.join(directory, 'dependencies', 'nested', 'a.bundle.json'), '{}');
    fs.writeFileSync(path.join(directory, 'dependencies', 'nested', 'ignored.json'), '{}');
    writeConfig(directory);

    const config = loadStyleConfig(directory);
    assert.equal(config.schemaVersion, 1);
    assert.deepEqual(discoverDependencyBundles(directory, config.dependencyRoots), [
      path.join('dependencies', 'nested', 'a.bundle.json'),
      path.join('dependencies', 'z.bundle.json'),
    ]);
    assert.equal(Object.isFrozen(config), true);
    assert.equal(Object.isFrozen(config.outputs), true);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('style config rejects unknown keys, escaping paths, and duplicate roots', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'style-config-invalid-'));
  try {
    writeConfig(directory, { unknown: true });
    assert.throws(() => loadStyleConfig(directory), /must contain exactly/);

    writeConfig(directory, { cacheDirectory: '../outside' });
    assert.throws(() => loadStyleConfig(directory), /must stay inside/);

    writeConfig(directory, { dependencyRoots: ['dependencies', 'dependencies'] });
    assert.throws(() => loadStyleConfig(directory), /must be unique/);

    writeConfig(directory, { mappingsPackage: '../outside' });
    assert.throws(() => loadStyleConfig(directory), /mappingsPackage is invalid/);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
