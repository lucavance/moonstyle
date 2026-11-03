import rabbita from '@rabbita/vite';
import { defineConfig } from 'vite-plus';
import moonStyle from '@lampclaw/moonstyle-tooling/vite';

export default defineConfig({
  root: import.meta.dirname,
  plugins: [
    moonStyle({ extractorPackage: 'cmd/style_extract' }),
    rabbita({ mainPkgDir: 'src/demo' }),
  ],
});
