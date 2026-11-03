import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');
const ignoredDirectories = new Set(['.git', '.mooncakes', '_build', 'node_modules']);

function interfaceFiles(directory = root) {
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.isDirectory() && ignoredDirectories.has(entry.name)) continue;
    const filename = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...interfaceFiles(filename));
    } else if (entry.name === 'pkg.generated.mbti') {
      files.push(path.relative(root, filename));
    }
  }
  return files.sort((left, right) => left.localeCompare(right));
}

function snapshot() {
  return new Map(
    interfaceFiles().map((filename) => [
      filename,
      createHash('sha256')
        .update(fs.readFileSync(path.join(root, filename)))
        .digest('hex'),
    ]),
  );
}

const before = snapshot();
for (const arguments_ of [
  ['info'],
  ['-C', 'validation', 'info'],
  ['-C', 'packages/moonstyle-luna', 'info'],
]) {
  const result = spawnSync('moon', arguments_, { cwd: root, encoding: 'utf8' });
  if (result.status !== 0) {
    process.stdout.write(result.stdout);
    process.stderr.write(result.stderr);
    process.exit(result.status ?? 1);
  }
}

const nativeInfo = spawnSync('moon', ['info', '--target', 'native', '-p', 'extract/cli'], {
  cwd: root,
  encoding: 'utf8',
});
if (nativeInfo.status !== 0) {
  process.stdout.write(nativeInfo.stdout);
  process.stderr.write(nativeInfo.stderr);
  process.exit(nativeInfo.status ?? 1);
}
const nativeCliInterface = path.join(
  root,
  '_build',
  'native',
  'debug',
  'check',
  'lampclaw',
  'moonstyle',
  'extract',
  'cli',
  'cli.mbti',
);
const committedCliInterface = path.join(root, 'src', 'extract', 'cli', 'pkg.generated.mbti');
if (
  !fs.existsSync(nativeCliInterface) ||
  fs.readFileSync(nativeCliInterface, 'utf8') !== fs.readFileSync(committedCliInterface, 'utf8')
) {
  process.stderr.write('Native CLI public interface snapshot was stale.\n');
  process.exit(1);
}

const after = snapshot();
const changed = [...new Set([...before.keys(), ...after.keys()])].filter(
  (filename) => before.get(filename) !== after.get(filename),
);

if (changed.length > 0) {
  process.stderr.write('MoonBit public interface snapshots were stale:\n');
  for (const filename of changed) process.stderr.write(`  ${filename}\n`);
  process.stderr.write('Review and commit the refreshed pkg.generated.mbti files.\n');
  process.exit(1);
}

console.log(`Verified ${after.size} MoonBit public interface snapshots.`);
