import { defineConfig } from 'vite-plus';

export default defineConfig(() => ({
  test: { include: ['tests/**/*.test.mjs', 'tests/e2e.mjs'], fileParallelism: false, maxWorkers: 1, testTimeout: 120000, hookTimeout: 120000 },
  run: { tasks: {
    'check-toolchain': { command: 'node tools/check-toolchain.mjs', cache: false }, 'moon-test': { command: 'moon test --target all', cache: false }, 'generate-authoring': { command: ['node tools/generate-properties.mjs', 'moon run tools/generate-expressions.mbtx'], cache: false }
  } },
  plugins: [],
}));
