import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'vite-plus/test';
import { workspaceWatchPaths } from '../tooling/workspace.mjs';
import {
  computeExtractionIdentity,
  createCssSourceMap,
  createExtractionQueue,
  diagnosticEndMarker,
  diagnosticStartMarker,
  extractorBuildArguments,
  extractionArguments,
  formatProblem,
  isRelevantFile,
  parseDiagnostics,
  parseDebugManifest,
  parseMoonBuildOutput,
  default as moonStyle,
} from '../tooling/vite-plugin-moonstyle.mjs';

const root = path.resolve(import.meta.dirname, '..');

test('a child application watches workspace sources and manifests without ancestor output loops', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'moonstyle-workspace-'));
  const app = path.join(directory, 'validation');
  try {
    fs.mkdirSync(app);
    fs.mkdirSync(path.join(directory, 'src'));
    fs.writeFileSync(
      path.join(directory, 'moon.mod'),
      'name = "example/library"\nsource = "src"\n',
    );
    fs.writeFileSync(path.join(app, 'moon.mod'), 'name = "example/app"\n');
    fs.writeFileSync(
      path.join(directory, 'moon.work'),
      '// members = ["ignored"]\nmembers = [".", "validation"]\n',
    );
    const inputs = workspaceWatchPaths(app);
    assert.ok(inputs.includes(path.join(directory, 'src')));
    assert.ok(inputs.includes(path.join(directory, 'moon.mod')));
    assert.ok(inputs.includes(path.join(directory, 'moon.work')));
    assert.equal(inputs.includes(directory), false);
    const config = {
      outputs: { mappings: 'generated/styles.mbt' },
      dependencyRoots: [],
      cacheDirectory: '_build/cache',
    };
    const relevant = (filename) =>
      isRelevantFile(path.join(directory, filename), app, config, inputs);
    assert.equal(relevant('src/values/value.mbt'), true);
    assert.equal(relevant('moon.mod'), true);
    assert.equal(relevant('moon.work'), true);
    assert.equal(relevant('tools/helper.mbt'), false);
    assert.equal(relevant('_build/generated.mbt'), false);
    assert.equal(relevant('validation/generated/styles.mbt'), false);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

function diagnostic(overrides = {}) {
  return {
    code: 'STYLE1001',
    severity: 'error',
    message: 'CSS property name must not be empty',
    file: 'styles/main.mbt',
    line: 12,
    column: 7,
    endLine: 12,
    endColumn: 29,
    symbol: 'unsafe_raw',
    module: 'local/app',
    artifactPath: null,
    dependencyChain: [],
    ...overrides,
  };
}

test('Vite diagnostics parse structured extractor output into stable editor problems', () => {
  const payload = JSON.stringify([diagnostic()]);
  const [parsed] = parseDiagnostics(`Moon command output\n${payload}\n`);
  assert.equal(parsed.code, 'STYLE1001');
  assert.equal(
    formatProblem(parsed, root),
    'styles/main.mbt:12:7:12:29: error STYLE1001: CSS property name must not be empty [unsafe_raw]',
  );
  assert.equal(diagnosticStartMarker, '[moonstyle] check-start');
  assert.equal(diagnosticEndMarker, '[moonstyle] check-end');
  assert.throws(() => parseDiagnostics('[{"code":"lowercase"}]'), /code is invalid/);
});

test('Vite extraction queue coalesces repeated saves into one trailing extraction', async () => {
  let release;
  const firstRun = new Promise((resolve) => {
    release = resolve;
  });
  let calls = 0;
  const requests = [];
  const schedule = createExtractionQueue(async (request) => {
    requests.push(request);
    calls += 1;
    if (calls === 1) await firstRun;
    return calls;
  });

  const first = schedule({ reasons: ['initial'] });
  const second = schedule({ force: true, reasons: ['config'] });
  const third = schedule({ reasons: ['source'] });
  release();

  assert.deepEqual(await Promise.all([first, second, third]), [2, 2, 2]);
  assert.equal(calls, 2);
  assert.deepEqual(requests, [
    { force: false, reasons: ['initial'] },
    { force: true, reasons: ['config', 'source'] },
  ]);
});

test('Vite extraction watches authored MoonBit and dependency bundles without self-loops', () => {
  const config = {
    outputs: {
      css: 'src/generated/styles.generated.css',
      mappings: 'src/generated/styles.generated.mbt',
      mappingsManifest: 'src/generated/moon.pkg',
      bundle: 'src/generated/styles.bundle.json',
    },
    dependencyRoots: ['dependencies'],
    cacheDirectory: '_build/style-cache',
  };
  assert.equal(isRelevantFile(path.join(root, 'styles', 'main.mbt'), root, config), true);
  assert.equal(isRelevantFile(path.join(root, '.moonstyle.json'), root, config), true);
  assert.equal(isRelevantFile(path.join(root, 'styles', 'native.c'), root, config), true);
  assert.equal(isRelevantFile(path.join(root, 'styles', 'moon.pkg'), root, config), true);
  assert.equal(
    isRelevantFile(path.join(root, 'src', 'generated', 'styles.generated.mbt'), root, config),
    false,
  );
  assert.equal(
    isRelevantFile(path.join(root, 'dependencies', 'library.bundle.json'), root, config),
    true,
  );
  assert.equal(isRelevantFile(path.join(root, '_build', 'cached.mbt'), root, config), false);
  assert.equal(
    isRelevantFile(path.join(root, '_build', 'style-cache', 'entry.mbt'), root, config),
    false,
  );
  assert.equal(isRelevantFile(path.join(root, 'node_modules', 'library.mbt'), root, config), false);
  assert.equal(isRelevantFile(path.join(root, 'README.md'), root, config), false);
});

test('Vite extractor build separates debug and release compilation from execution', () => {
  assert.deepEqual(extractorBuildArguments('style_extractor', 'debug'), [
    'run',
    'style_extractor',
    '--target',
    'native',
    '--build-only',
    '--output-json',
  ]);
  assert.deepEqual(extractorBuildArguments('style_extractor', 'release'), [
    'run',
    'style_extractor',
    '--target',
    'native',
    '--release',
    '--build-only',
    '--output-json',
  ]);
  assert.throws(() => extractorBuildArguments('style_extractor', 'fast'), /Unsupported/);
});

test('Vite extractor parses Moon JSON diagnostics and the native artifact path', () => {
  const parsed = parseMoonBuildOutput(
    [
      JSON.stringify({
        $message_type: 'diagnostic',
        level: 'error',
        error_code: 4021,
        path: 'styles/main.mbt',
        loc: '1:11-1:25',
        message: 'The value has the wrong type.',
      }),
      JSON.stringify({ artifacts_path: ['/tmp/style-extractor'] }),
    ].join('\n'),
  );
  assert.deepEqual(parsed.artifactPaths, ['/tmp/style-extractor']);
  assert.deepEqual(parsed.diagnostics[0], {
    code: 'MOON4021',
    severity: 'error',
    message: 'The value has the wrong type.',
    file: 'styles/main.mbt',
    line: 1,
    column: 11,
    endLine: 1,
    endColumn: 25,
    symbol: null,
    module: null,
    artifactPath: null,
    dependencyChain: [],
  });
});

test('Vite extraction identity covers profile, executable, normalized config, and bundles', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'style-identity-'));
  try {
    fs.mkdirSync(path.join(directory, 'dependencies'));
    fs.writeFileSync(path.join(directory, 'extractor'), 'debug executable');
    fs.writeFileSync(path.join(directory, 'dependencies', 'z.bundle.json'), '{"name":"z"}\n');
    fs.writeFileSync(path.join(directory, 'dependencies', 'a.bundle.json'), '{"name":"a"}\n');
    const config = {
      schemaVersion: 1,
      mappingsPackage: 'local/app/src/generated',
      outputs: {
        css: 'src/generated/styles.generated.css',
        mappings: 'src/generated/styles.generated.mbt',
        mappingsManifest: 'src/generated/moon.pkg',
        bundle: 'src/generated/styles.bundle.json',
      },
      dependencyRoots: ['dependencies'],
      cacheDirectory: '_build/style-cache',
    };
    const first = computeExtractionIdentity(
      directory,
      config,
      path.join(directory, 'extractor'),
      'debug',
    );
    const second = computeExtractionIdentity(
      directory,
      config,
      path.join(directory, 'extractor'),
      'debug',
    );
    assert.equal(second.identity, first.identity);
    assert.deepEqual(
      first.bundles.map((filename) => path.basename(filename)),
      ['a.bundle.json', 'z.bundle.json'],
    );

    const release = computeExtractionIdentity(
      directory,
      config,
      path.join(directory, 'extractor'),
      'release',
    );
    assert.notEqual(release.identity, first.identity);

    fs.writeFileSync(path.join(directory, 'dependencies', 'a.bundle.json'), '{"name":"changed"}\n');
    const changedBundle = computeExtractionIdentity(
      directory,
      config,
      path.join(directory, 'extractor'),
      'debug',
    );
    assert.notEqual(changedBundle.identity, first.identity);

    const changedConfig = computeExtractionIdentity(
      directory,
      { ...config, mappingsPackage: 'local/app/other' },
      path.join(directory, 'extractor'),
      'debug',
    );
    assert.notEqual(changedConfig.identity, changedBundle.identity);

    fs.writeFileSync(path.join(directory, 'extractor'), 'new executable');
    const changedExecutable = computeExtractionIdentity(
      directory,
      config,
      path.join(directory, 'extractor'),
      'debug',
    );
    assert.notEqual(changedExecutable.identity, changedBundle.identity);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

function debugFixture(directory) {
  const css =
    '/* Generated by lampclaw/moonstyle/extract schema v14. Do not edit. */\n.x1e2nbdu{color:red}\n';
  const manifest = {
    schemaVersion: 1,
    module: 'local/app',
    semanticDigest: `sha256:${'a'.repeat(64)}`,
    cssDigest: `sha256:${createHash('sha256').update(css).digest('hex')}`,
    rules: [
      {
        className: 'x1e2nbdu',
        property: 'color',
        ltr: '.x1e2nbdu{color:red}',
        rtl: null,
        css: '.x1e2nbdu{color:red}',
        priority100: 300000,
        order: 0,
        origins: [
          {
            module: 'local/app',
            exportName: 'styles',
            namespace: 'button',
            source: {
              file: 'styles/button.mbt',
              line: 12,
              column: 7,
              endLine: 12,
              endColumn: 31,
              symbol: 'button',
            },
          },
        ],
      },
    ],
    globals: [],
  };
  fs.mkdirSync(path.join(directory, 'styles'), { recursive: true });
  fs.writeFileSync(path.join(directory, 'styles', 'button.mbt'), 'fn button {}\n');
  return { css, manifest };
}

test('debug manifest parsing is strict, root-contained, and source-map ready', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'style-debug-manifest-'));
  try {
    const { css, manifest } = debugFixture(directory);
    const parsed = parseDebugManifest(
      JSON.stringify(manifest),
      directory,
      css,
      manifest.semanticDigest,
    );
    assert.equal(parsed.rules[0].origins[0].source.file, 'styles/button.mbt');
    assert.equal(
      parsed.rules[0].origins[0].source.absoluteFile,
      path.join(directory, 'styles', 'button.mbt'),
    );
    const map = createCssSourceMap(directory, css, parsed);
    assert.equal(map.version, 3);
    assert.deepEqual(map.sources, [path.join(directory, 'styles', 'button.mbt')]);
    assert.deepEqual(map.sourcesContent, ['']);
    assert.deepEqual(map.names, ['button']);
    assert.match(map.mappings, /^;[A-Za-z0-9+/]+;$/);

    assert.throws(
      () => parseDebugManifest(JSON.stringify({ ...manifest, extra: true }), directory, css),
      /contain exactly/,
    );
    assert.throws(
      () =>
        parseDebugManifest(
          JSON.stringify({ ...manifest, cssDigest: `sha256:${'0'.repeat(64)}` }),
          directory,
          css,
        ),
      /cssDigest/,
    );
    const outside = structuredClone(manifest);
    outside.rules[0].origins[0].source.file = '../outside.mbt';
    assert.throws(
      () => parseDebugManifest(JSON.stringify(outside), directory, css),
      /project root/,
    );
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('devtools extraction argument is explicit and stays out of production extraction', () => {
  const config = {
    outputs: {
      css: 'src/generated/styles.generated.css',
      mappings: 'src/generated/styles.generated.mbt',
      mappingsManifest: 'src/generated/moon.pkg',
      bundle: 'src/generated/styles.bundle.json',
    },
    dependencyRoots: [],
    cacheDirectory: '_build/style-cache',
  };
  const production = extractionArguments(root, config);
  assert.equal(production.includes('--debug-manifest-output'), false);
  assert.deepEqual(
    production.slice(
      production.indexOf('--tooling-protocol'),
      production.indexOf('--tooling-protocol') + 2,
    ),
    ['--tooling-protocol', '1'],
  );
  const debug = extractionArguments(root, config, { devtools: true });
  const index = debug.indexOf('--debug-manifest-output');
  assert.notEqual(index, -1);
  assert.equal(
    debug[index + 1],
    path.join(root, '_build', 'style-cache', 'vite-debug-manifest.json'),
  );
  const checked = extractionArguments(root, config, { check: true });
  assert.equal(checked.includes('--check'), true);
  assert.equal(checked.includes('--debug-manifest-output'), false);
  assert.throws(
    () => extractionArguments(root, config, { check: true, devtools: true }),
    /cannot be combined/,
  );
});

test('Vite devtools are serve-only and can be disabled explicitly', () => {
  const enabled = moonStyle();
  assert.deepEqual(enabled.config({}, { command: 'serve' }), {
    css: { devSourcemap: true },
  });
  enabled.configResolved({ root, command: 'serve', base: '/demo/' });
  assert.equal(enabled.resolveId('virtual:moonstyle-inspector'), '\0virtual:moonstyle-inspector');
  assert.match(enabled.transformIndexHtml()[0].attrs.src, /^\/demo\//);

  const disabled = moonStyle({ devtools: false });
  assert.equal(disabled.config({}, { command: 'serve' }), undefined);
  disabled.configResolved({ root, command: 'serve', base: '/' });
  assert.equal(disabled.resolveId('virtual:moonstyle-inspector'), null);
  assert.equal(disabled.transformIndexHtml(), undefined);

  const production = moonStyle();
  assert.equal(production.config({}, { command: 'build' }), undefined);
  production.configResolved({ root, command: 'build', base: '/' });
  assert.equal(production.resolveId('virtual:moonstyle-inspector'), null);
  assert.equal(production.transformIndexHtml(), undefined);
});
