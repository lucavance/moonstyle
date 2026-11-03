import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'vite-plus/test';
import { validateApplicationOrderLock } from '../tools/application-order.mjs';

const root = path.resolve(import.meta.dirname, '..');
const metadataRelative = 'src/properties/property-metadata.json';
const lockRelative = 'src/core/application-order.lock.json';
const moonbitRelative = 'src/core/application_order.generated.mbt';
const metadata = JSON.parse(fs.readFileSync(path.join(root, metadataRelative), 'utf8'));
const lock = JSON.parse(fs.readFileSync(path.join(root, lockRelative), 'utf8'));

function isolatedProject() {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'style-oracle-isolation-'));
  for (const filename of [
    'tools/application-order.mjs',
    'tools/generate-application-order.mjs',
    'tools/stylex-bridge.mjs',
    'tools/stylex-oracle/generate-application-order.mjs',
    'tools/stylex-oracle/release-contract.mjs',
    'tools/stylex-oracle/package.json',
    'tools/stylex-oracle/bun.lock',
    metadataRelative,
    lockRelative,
    moonbitRelative,
  ]) {
    const destination = path.join(directory, filename);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.copyFileSync(path.join(root, filename), destination);
  }
  return directory;
}

function run(directory, script, ...arguments_) {
  return spawnSync(process.execPath, [script, ...arguments_], {
    cwd: directory,
    encoding: 'utf8',
  });
}

test('ordinary semantic generation works without any installed oracle or root dependencies', () => {
  const directory = isolatedProject();
  try {
    const before = fs.readFileSync(path.join(directory, lockRelative), 'utf8');
    const expectedMoonbit = fs.readFileSync(path.join(directory, moonbitRelative), 'utf8');
    fs.rmSync(path.join(directory, moonbitRelative));
    const result = run(directory, 'tools/generate-application-order.mjs');
    assert.equal(result.status, 0, `${result.stdout}${result.stderr}`);
    assert.match(result.stdout, /from the committed lock/);
    assert.equal(fs.readFileSync(path.join(directory, lockRelative), 'utf8'), before);
    assert.equal(fs.readFileSync(path.join(directory, moonbitRelative), 'utf8'), expectedMoonbit);
    assert.equal(fs.existsSync(path.join(directory, 'node_modules')), false);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('missing or stale semantic locks fail before replacing the generated table', () => {
  const directory = isolatedProject();
  try {
    const table = fs.readFileSync(path.join(directory, moonbitRelative), 'utf8');
    const originalLock = fs.readFileSync(path.join(directory, lockRelative), 'utf8');
    fs.rmSync(path.join(directory, lockRelative));
    const missing = run(directory, 'tools/generate-application-order.mjs');
    assert.notEqual(missing.status, 0);
    assert.match(missing.stderr, /lock is missing.*install-oracle.*refresh-oracle/);
    assert.equal(fs.readFileSync(path.join(directory, moonbitRelative), 'utf8'), table);
    fs.writeFileSync(path.join(directory, lockRelative), '{invalid');
    const malformed = run(directory, 'tools/generate-application-order.mjs');
    assert.notEqual(malformed.status, 0);
    assert.match(malformed.stderr, /lock is invalid JSON.*install-oracle.*refresh-oracle/);
    assert.equal(fs.readFileSync(path.join(directory, moonbitRelative), 'utf8'), table);
    fs.writeFileSync(path.join(directory, lockRelative), originalLock);
    const changedMetadata = structuredClone(metadata);
    changedMetadata.sources.oracleIsolation = 'changed-input';
    fs.writeFileSync(path.join(directory, metadataRelative), JSON.stringify(changedMetadata));
    const stale = run(directory, 'tools/generate-application-order.mjs');
    assert.notEqual(stale.status, 0);
    assert.match(stale.stderr, /semantics are stale.*install-oracle.*refresh-oracle/);
    assert.equal(fs.readFileSync(path.join(directory, lockRelative), 'utf8'), originalLock);
    assert.equal(fs.readFileSync(path.join(directory, moonbitRelative), 'utf8'), table);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('normal generation rejects a tampered lock or unsupported profile', () => {
  const tampered = structuredClone(lock);
  tampered.properties[0].priority100 += 1;
  assert.throws(
    () => validateApplicationOrderLock(tampered, metadata),
    /content digest is invalid/,
  );
  const unsupported = structuredClone(lock);
  unsupported.profile.stylexVersion = '0.20.0';
  assert.throws(
    () => validateApplicationOrderLock(unsupported, metadata),
    /unsupported semantic profile/,
  );
});

test('oracle preflight and refresh report missing dependencies without changing artifacts', () => {
  const directory = isolatedProject();
  try {
    const before = [lockRelative, moonbitRelative].map((filename) =>
      fs.readFileSync(path.join(directory, filename), 'utf8'),
    );
    for (const arguments_ of [['--check-release'], ['--check-dependencies'], []]) {
      const result = run(
        directory,
        'tools/stylex-oracle/generate-application-order.mjs',
        ...arguments_,
      );
      assert.notEqual(result.status, 0);
      assert.match(
        result.stderr,
        /oracle dependency @babel\/core is missing; run vp run install-oracle/,
      );
      assert.deepEqual(
        [lockRelative, moonbitRelative].map((filename) =>
          fs.readFileSync(path.join(directory, filename), 'utf8'),
        ),
        before,
      );
    }
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('release preflight rejects compiler and semantic drift before replacing artifacts', () => {
  const directory = isolatedProject();
  const oracleRoot = path.join(directory, 'tools/stylex-oracle');
  const oracleManifest = JSON.parse(fs.readFileSync(path.join(oracleRoot, 'package.json'), 'utf8'));
  try {
    // Preflight reads package manifests without importing the compiler.
    for (const [name, version] of Object.entries(oracleManifest.devDependencies)) {
      const filename = path.join(oracleRoot, 'node_modules', name, 'package.json');
      fs.mkdirSync(path.dirname(filename), { recursive: true });
      fs.writeFileSync(filename, JSON.stringify({ name, version }));
    }
    const baseline = run(
      directory,
      'tools/stylex-oracle/generate-application-order.mjs',
      '--check-release',
    );
    assert.equal(baseline.status, 0, `${baseline.stdout}${baseline.stderr}`);
    const cases = [
      {
        filename: 'tools/stylex-oracle/package.json',
        change: (source) =>
          source.replace('"@stylexjs/stylex": "0.19.1"', '"@stylexjs/stylex": "^0.19.1"'),
        message: /requires @stylexjs\/stylex exact-pinned/,
      },
      {
        filename: 'tools/stylex-oracle/bun.lock',
        change: (source) =>
          source.replace('"@stylexjs/stylex": "0.19.1"', '"@stylexjs/stylex": "0.19.0"'),
        message: /lockfile manifest pin must be 0\.19\.1/,
      },
      {
        filename: 'tools/stylex-oracle/bun.lock',
        change: (source) =>
          source.replace('"@stylexjs/stylex@0.19.1"', '"@stylexjs/stylex@0.19.0"'),
        message: /@stylexjs\/stylex@0\.19\.1 is missing from the oracle lockfile/,
      },
      {
        filename: 'tools/stylex-oracle/bun.lock',
        change: (source) =>
          source
            .split('\n')
            .map((line) =>
              line.includes('"@stylexjs/stylex": [')
                ? line.replace(/sha512-[^"]+/, 'sha512-tampered')
                : line,
            )
            .join('\n'),
        message: /lockfile integrity differs from the reviewed release/,
      },
      {
        filename: 'tools/stylex-oracle/bun.lock',
        change: () => '{invalid',
        message: /oracle lockfile is missing or invalid/,
      },
      {
        filename: 'tools/stylex-oracle/node_modules/@stylexjs/stylex/package.json',
        change: (source) => source.replace('0.19.1', '0.19.0'),
        message: /installed 0\.19\.0/,
      },
      {
        filename: lockRelative,
        change: (source) => {
          const semantic = JSON.parse(source);
          semantic.profile.name += '-unreviewed';
          return JSON.stringify(semantic);
        },
        message: /unsupported semantic profile/,
      },
      {
        filename: lockRelative,
        change: (source) => {
          const semantic = JSON.parse(source);
          semantic.properties[0].priority100 += 1;
          return JSON.stringify(semantic);
        },
        message: /content digest is invalid/,
      },
    ];
    for (const { filename, change, message } of cases) {
      const absolute = path.join(directory, filename);
      const original = fs.readFileSync(absolute, 'utf8');
      const altered = change(original);
      assert.notEqual(altered, original, `${filename} fixture must change the contract`);
      fs.writeFileSync(absolute, altered);
      const before = [lockRelative, moonbitRelative].map((artifact) =>
        fs.readFileSync(path.join(directory, artifact), 'utf8'),
      );
      const result = run(
        directory,
        'tools/stylex-oracle/generate-application-order.mjs',
        '--check-release',
      );
      assert.notEqual(result.status, 0, `${filename}: ${result.stdout}`);
      assert.match(result.stderr, message);
      assert.deepEqual(
        [lockRelative, moonbitRelative].map((artifact) =>
          fs.readFileSync(path.join(directory, artifact), 'utf8'),
        ),
        before,
      );
      // Refresh also checks compiler pins but can repair a stale semantic lock.
      if (filename.startsWith('tools/stylex-oracle/')) {
        const refresh = run(directory, 'tools/stylex-oracle/generate-application-order.mjs');
        assert.notEqual(refresh.status, 0);
        assert.match(refresh.stderr, message);
        assert.deepEqual(
          [lockRelative, moonbitRelative].map((artifact) =>
            fs.readFileSync(path.join(directory, artifact), 'utf8'),
          ),
          before,
        );
      }
      fs.writeFileSync(absolute, original);
    }
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
