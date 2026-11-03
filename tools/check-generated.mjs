import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');
const files = [
  path.join(root, 'src/values/common_inputs.generated.mbt'),
  path.join(root, 'src/builder/common_inputs.generated.mbt'),
  path.join(root, 'src/common_inputs.generated.mbt'),
  path.join(root, 'src/values/math_inputs.generated.mbt'),
  path.join(root, 'src/builder/math_inputs.generated.mbt'),
  path.join(root, 'src/math.generated.mbt'),
  path.join(root, 'src/core/application-order.lock.json'),
  path.join(root, 'src/core/application_order.generated.mbt'),
  path.join(root, 'src/properties/property-metadata.json'),
  path.join(root, 'src/properties/property-coverage.json'),
  path.join(root, 'src/properties/properties.mbt'),
  path.join(root, 'src/builder/rules.generated.mbt'),
  path.join(root, 'src/builder/css_inputs.generated.mbt'),
  path.join(root, 'src/css_inputs.generated.mbt'),
  path.join(root, 'src/property-facade.generated.mbt'),
  path.join(root, 'validation/src/generated/styles.generated.mbt'),
  path.join(root, 'validation/src/generated/moon.pkg'),
  path.join(root, 'validation/src/generated/styles.generated.css'),
  path.join(root, 'validation/src/generated/styles.bundle.json'),
];

function digest(filename) {
  return createHash('sha256').update(fs.readFileSync(filename)).digest('hex');
}

const before = files.map(digest);
const expressions = spawnSync('moon', ['run', 'tools/generate-expressions.mbtx'], {
  cwd: root,
  encoding: 'utf8',
});
if (expressions.status !== 0) throw new Error(`${expressions.stdout}${expressions.stderr}`);
const result = spawnSync(process.execPath, ['tools/build-styles.mjs'], {
  cwd: root,
  encoding: 'utf8',
});
if (result.status !== 0) {
  process.stderr.write(result.stdout);
  process.stderr.write(result.stderr);
  process.exit(result.status ?? 1);
}
const fixtures = spawnSync(process.execPath, ['validation/tests/dependency-fixtures/refresh.mjs'], {
  cwd: root,
  encoding: 'utf8',
});
if (fixtures.status !== 0) {
  process.stderr.write(fixtures.stdout ?? '');
  process.stderr.write(fixtures.stderr ?? '');
  if (fixtures.error) process.stderr.write(`${fixtures.error.message}\n`);
  process.exit(fixtures.status ?? 1);
}
const after = files.map(digest);
if (before.some((value, index) => value !== after[index])) {
  throw new Error('Generated files changed after a second generation pass');
}
console.log(
  'Generated property metadata, MoonBit, CSS, and synthetic dependency fixtures are current.',
);
