import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { build } from 'vite';
import { test } from 'vite-plus/test';
import moonStyle from '../../tooling/vite/index.mjs';

test('optional Vite adapter builds through installed native CLI and preserves output after errors', async () => {
  const repository = path.resolve(import.meta.dirname, '../..');
  const executable = process.env.MOONSTYLE_BIN ?? path.join(repository, '_build/bin/moonstyle');
  assert.ok(fs.existsSync(executable), 'Install the native CLI before extended verification');
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'moonstyle-vite-consumer-'));
  try {
    fs.mkdirSync(path.join(root, 'styles'));
    fs.writeFileSync(
      path.join(root, 'moon.mod'),
      'name = "local/vite-consumer"\nimport { "lampclaw/moonstyle@0.3.0" }\n',
    );
    fs.writeFileSync(
      path.join(root, 'moon.work'),
      `members = [".", ${JSON.stringify(repository)}]\n`,
    );
    fs.writeFileSync(path.join(root, 'styles/moon.pkg'), 'import { "lampclaw/moonstyle" }\n');
    const source =
      'pub fn registry() -> @moonstyle.Registry { @moonstyle.registry("local/vite-consumer", [@moonstyle.rule("card").color(@moonstyle.rgb(255, 0, 0))]) }\n';
    const styles = path.join(root, 'styles/styles.mbt');
    fs.writeFileSync(styles, source);
    fs.writeFileSync(
      path.join(root, 'entry.mjs'),
      'import "virtual:moonstyle.css"; console.log("Vite host consumer");\n',
    );
    execFileSync(executable, ['init', '--root', root], { encoding: 'utf8' });
    const compile = () =>
      build({
        root,
        configFile: false,
        logLevel: 'silent',
        plugins: [moonStyle({ executable })],
        build: {
          write: false,
          minify: false,
          rollupOptions: { input: path.join(root, 'entry.mjs') },
        },
      });
    const result = await compile();
    assert.ok(
      result.output.some(
        (file) =>
          file.type === 'asset' &&
          file.fileName.endsWith('.css') &&
          String(file.source).includes('rgb(255 0 0)'),
      ),
    );
    const css = path.join(root, 'generated/styles.generated.css');
    const before = fs.readFileSync(css);
    fs.writeFileSync(styles, source + '\ninvalid MoonBit source\n');
    await assert.rejects(compile(), /MOON|Parse|failed/);
    assert.deepEqual(fs.readFileSync(css), before);
    fs.writeFileSync(styles, source.replace('255, 0, 0', '0, 0, 255'));
    const recovered = await compile();
    assert.ok(
      recovered.output.some(
        (file) => file.type === 'asset' && String(file.source).includes('rgb(0 0 255)'),
      ),
    );
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
