import path from 'node:path';
import { defineConfig } from 'vite-plus';

export default defineConfig({
  root: path.resolve(import.meta.dirname, '..'),
  test: {
    include: ['verification/tests/**/*.test.mjs', 'verification/tests/e2e.mjs'],
    fileParallelism: false,
    maxWorkers: 1,
    testTimeout: 120_000,
    hookTimeout: 120_000,
  },
  fmt: {
    singleQuote: true,
    semi: true,
    ignorePatterns: ['**/node_modules/**', '**/bun.lock', '**/data/css-inputs.json'],
  },
});
