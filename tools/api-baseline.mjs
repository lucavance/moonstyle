import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');
const modules = [
  { name: 'lampclaw/moonstyle', directory: path.join(root, 'src') },
  { name: 'lampclaw/moonstyle-luna', directory: path.join(root, 'packages', 'moonstyle-luna') },
];
const output = path.join(root, 'docs', 'api-baseline-0.2.0.json');

function interfaces(moduleDirectory, directory = moduleDirectory) {
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const filename = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === 'tests' || entry.name === '.mooncakes' || entry.name === '_build') {
        continue;
      }
      files.push(...interfaces(moduleDirectory, filename));
    } else if (entry.name === 'pkg.generated.mbti') {
      files.push(path.relative(moduleDirectory, filename));
    }
  }
  return files.sort((left, right) => left.localeCompare(right));
}

const baseline = {
  schemaVersion: 2,
  version: '0.2.0',
  modules: Object.fromEntries(
    modules.map((module) => [
      module.name,
      Object.fromEntries(
        interfaces(module.directory).map((filename) => [
          filename,
          `sha256:${createHash('sha256')
            .update(fs.readFileSync(path.join(module.directory, filename)))
            .digest('hex')}`,
        ]),
      ),
    ]),
  ),
};
const serialized = `${JSON.stringify(baseline, null, 2)}\n`;

if (process.argv.includes('--write')) {
  fs.writeFileSync(output, serialized);
} else {
  const existing = fs.existsSync(output) ? fs.readFileSync(output, 'utf8') : '';
  if (existing !== serialized) {
    throw new Error(
      'Public API baseline changed; review interfaces and run vp run update-api-baseline',
    );
  }
}
