import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { test } from 'vite-plus/test';
import { activeDocumentationFiles } from '../tools/docs-contract.mjs';

const root = path.resolve(import.meta.dirname, '..');

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

test('VitePlus selects the pinned Bun package manager and owns the lockfile', () => {
  const manifest = JSON.parse(read('package.json'));
  assert.equal(manifest.packageManager, 'bun@1.4.4');
  assert.equal(manifest.scripts, undefined);
  assert.equal(fs.existsSync(path.join(root, 'bun.lock')), true);
  assert.equal(fs.existsSync(path.join(root, 'package-lock.json')), false);
});

test('the root install excludes the Babel compiler and StyleX oracle dependency graph', () => {
  const manifest = JSON.parse(read('package.json'));
  assert.deepEqual(manifest.workspaces, ['validation']);
  for (const dependency of Object.keys(manifest.devDependencies)) {
    assert.doesNotMatch(dependency, /^@(?:babel|stylexjs)\//);
  }
  assert.doesNotMatch(
    read('bun.lock'),
    /"@(?:stylexjs\/|babel\/(?:core|parser|traverse|types|generator|plugin-|preset-))/,
  );
});

test('VitePlus owns configuration and the public JavaScript task surface', async () => {
  const configSource = read('vite.config.mjs');
  assert.match(configSource, /from 'vite-plus'/);
  assert.doesNotMatch(configSource, /defineConfig[^\n]+from 'vite'/);

  const { default: configFactory } = await import('../vite.config.mjs');
  const config = configFactory({ command: 'build', mode: 'policy-test' });
  for (const task of Object.values(config.run.tasks)) {
    const commands = Array.isArray(task.command) ? task.command : [task.command];
    for (const command of commands) {
      const normalized = command.replace(/^[A-Z_][A-Z0-9_]*=\S+\s+/, '');
      assert.match(normalized, /^(?:vp|moon|node)\s/, `unsupported task command: ${command}`);
    }
  }
});

test('active documentation exposes only VitePlus JavaScript commands', () => {
  const directCommand = /`(?:npm|npx|bun|bunx|node|vite)\s+[^`]+`/g;
  for (const filename of activeDocumentationFiles) {
    assert.deepEqual(
      [...read(filename).matchAll(directCommand)].map((match) => match[0]),
      [],
      `${filename} contains a direct JavaScript tool command`,
    );
  }
});
