import path from 'node:path';
import { defineConfig } from 'vite-plus';

export default defineConfig({
  root: path.resolve(import.meta.dirname, '../..'),
  test: {
    include: ['tools/stylex-oracle/tests/**/*.test.mjs'],
    fileParallelism: false,
    maxWorkers: 1,
    testTimeout: 120_000,
    hookTimeout: 120_000,
  },
});
