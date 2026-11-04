import path from 'node:path';
import rabbita from '@rabbita/vite';
import { defineConfig, lazyPlugins } from 'vite-plus';
import moonStyle from '@lampclaw/moonstyle-tooling/vite';

export default defineConfig(({ mode }) => ({
  root: mode === 'test' ? import.meta.dirname : path.join(import.meta.dirname, 'validation'),
  fmt: {
    ignorePatterns: [
      '**/*.md',
      '**/*.mbt',
      '**/*.mbti',
      'validation/dist/**',
      '**/node_modules/**',
      '**/properties/**/*.json',
      '**/core/application-order.lock.json',
      'validation/src/generated/**',
    ],
    singleQuote: true,
    semi: true,
  },
  lint: {
    jsPlugins: [{ name: 'vite-plus', specifier: 'vite-plus/oxlint-plugin' }],
    rules: { 'vite-plus/prefer-vite-plus-imports': 'error' },
    options: { typeAware: true, typeCheck: true },
  },
  test: {
    include: ['tests/**/*.test.mjs', 'tests/e2e.mjs'],
    fileParallelism: false,
    maxWorkers: 1,
    testTimeout: 120_000,
    hookTimeout: 120_000,
  },
  run: {
    tasks: {
      generate: {
        command: ['moon run tools/generate-expressions.mbtx', 'node tools/build-styles.mjs'],
        cache: false,
      },
      'install-oracle': {
        command: 'vp -C tools/stylex-oracle install --frozen-lockfile',
        cache: false,
      },
      'refresh-oracle': {
        command: 'node tools/stylex-oracle/generate-application-order.mjs',
        cache: false,
      },
      'check-stylex-release': {
        command: 'node tools/stylex-oracle/generate-application-order.mjs --check-release',
        cache: false,
      },
      'test-oracle': {
        command: [
          'node tools/stylex-oracle/generate-application-order.mjs --check-release',
          'vp test run --config tools/stylex-oracle/vite.config.mjs',
        ],
        cache: false,
      },
      'audit-dependencies': {
        command: 'vp exec bun audit --json',
        cache: false,
      },
      'audit-oracle': {
        command: [
          'node tools/stylex-oracle/generate-application-order.mjs --check-release',
          'vp -C tools/stylex-oracle exec bun audit --json',
        ],
        cache: false,
      },
      'check-generated': {
        command: 'node tools/check-generated.mjs',
        cache: false,
        dependsOn: ['generate'],
      },
      'check-interfaces': {
        command: 'node tools/check-interfaces.mjs',
        cache: false,
      },
      'check-api-baseline': {
        command: 'node tools/api-baseline.mjs',
        cache: false,
        dependsOn: ['check-interfaces'],
      },
      'check-docs': {
        command: 'node tools/docs-contract.mjs',
        cache: false,
      },
      'check-consumer': {
        command: 'moon run tools/verify-consumer.mbtx',
        cache: false,
      },
      'check-consumer-snapshot': {
        command: 'moon run tools/verify-consumer.mbtx --snapshot',
        cache: false,
      },
      'check-toolchain': {
        command: 'node tools/check-toolchain.mjs',
        cache: false,
      },
      'update-api-baseline': {
        command: 'node tools/api-baseline.mjs --write',
        cache: false,
      },
      'moon-test': {
        command: [
          'moon test --target all',
          'moon -C validation test src/generated src/css_runtime --target all',
          'moon -C packages/moonstyle-luna test . --target js',
        ],
        cache: false,
      },
      'core-test': {
        command: 'moon test src/core --target all',
        cache: false,
      },
      e2e: {
        command: 'vp test run tests/e2e.mjs',
        cache: false,
      },
      'install-browsers': {
        command: 'node tools/install-browsers.mjs',
        cache: false,
      },
      'install-browsers-ci': {
        command: 'node tools/install-browsers.mjs --with-deps',
        cache: false,
      },
      evidence: {
        command: 'UPDATE_EVIDENCE=1 vp test run tests/e2e.mjs',
        cache: false,
      },
      benchmark: {
        command: 'node tools/benchmark.mjs',
        cache: false,
      },
      'benchmark-dx': {
        command: 'node tools/dx-benchmark.mjs',
        cache: false,
      },
      'benchmark-candidate': {
        command: [
          'node tools/benchmark.mjs --output benchmarks/0.2.0-candidate-1.json',
          'node tools/benchmark.mjs --output benchmarks/0.2.0-candidate-2.json',
        ],
        cache: false,
      },
      scaffold: {
        command: 'node tools/scaffold.mjs',
        cache: false,
      },
      'check-project': {
        command: 'node tooling/cli.mjs doctor --root validation',
        cache: false,
      },
      'check-project-strict': {
        command: 'node tooling/cli.mjs doctor --root validation --strict',
        cache: false,
      },
      'release-audit': {
        command: 'node tools/release-audit.mjs',
        cache: false,
      },
      validate: {
        command: ['vp run validate-source', 'vp run check-consumer-snapshot'],
        cache: false,
      },
      'validate-source': {
        command: [
          'vp run generate',
          'vp run check-project-strict',
          'vp run check-interfaces',
          'vp run check-api-baseline',
          'vp run check-docs',
          'vp run audit-dependencies',
          'vp check',
          'vp test run',
          'moon test --target all',
          'moon -C validation test src/generated src/css_runtime --target all',
          'moon -C packages/moonstyle-luna test . --target js',
          'moon test src/core --target all',
          'vp run benchmark-dx',
          'vp build',
          'vp run check-generated',
          'vp run release-audit',
        ],
        cache: false,
      },
      'validate-ci': {
        command: 'moon run tools/validate-ci.mbtx',
        cache: false,
      },
    },
  },
  plugins:
    mode === 'test'
      ? []
      : lazyPlugins(() => [
          moonStyle({ extractorPackage: 'cmd/style_extract' }),
          rabbita({ mainPkgDir: 'validation/src/demo' }),
        ]),
}));
