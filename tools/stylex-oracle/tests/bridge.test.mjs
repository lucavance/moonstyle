import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { test } from 'vite-plus/test';
import { buildStyles } from '../../build-styles.mjs';
import { renderStylexModule, validateManifest } from '../../stylex-bridge.mjs';
import { compileManifest, compileStylexSource } from '../stylex-compiler.mjs';

const root = path.resolve(import.meta.dirname, '../../..');

function manifestFromMoonBit() {
  const result = spawnSync(
    'moon',
    ['-C', 'validation', 'run', 'src/css_manifest', '--target', 'js', '--release'],
    {
      cwd: root,
      encoding: 'utf8',
    },
  );
  assert.equal(result.status, 0, `${result.stdout}${result.stderr}`);
  return validateManifest(JSON.parse(result.stdout.trim().split('\n').at(-1)));
}

function findJavaScriptFiles(directory) {
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const filename = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...findJavaScriptFiles(filename));
    if (entry.isFile() && filename.endsWith('.js')) files.push(filename);
  }
  return files;
}

test('MoonBit manifest compiles through unchanged StyleX Babel', () => {
  const manifest = manifestFromMoonBit();
  assert.equal(renderStylexModule(manifest), renderStylexModule(manifest));
  const compiled = compileManifest(manifest);
  assert.ok(compiled.rules.length > 0);
  assert.match(compiled.css, /:hover/);
  assert.match(compiled.css, /@media \(max-width: 640px\)/);
  assert.match(compiled.css, /@property --x-width/);
  assert.match(compiled.css, /width:var\(--x-width\)/);
});

test('generated MoonBit application JavaScript is not a StyleX authoring input', () => {
  buildStyles();
  fs.mkdirSync(path.join(root, '.generated'), { recursive: true });
  const targetDir = fs.mkdtempSync(path.join(root, '.generated', 'direct-control-'));
  try {
    const result = spawnSync(
      'moon',
      [
        '-C',
        'validation',
        'build',
        'src/demo',
        '--target',
        'js',
        '--release',
        '--target-dir',
        targetDir,
      ],
      { cwd: root, encoding: 'utf8' },
    );
    assert.equal(result.status, 0, `${result.stdout}${result.stderr}`);
    const candidates = findJavaScriptFiles(path.join(targetDir, 'js', 'release', 'build'));
    assert.ok(candidates.length > 0);
    for (const candidate of candidates) {
      const compiled = compileStylexSource(fs.readFileSync(candidate, 'utf8'));
      assert.equal(compiled.rules.length, 0);
      assert.equal(compiled.css, '');
    }
  } finally {
    fs.rmSync(targetDir, { recursive: true, force: true });
  }
});
