import fs from 'node:fs';
import path from 'node:path';

const expectedTopLevel = [
  'schemaVersion',
  'mappingsPackage',
  'outputs',
  'dependencyRoots',
  'cacheDirectory',
];
const expectedOutputs = ['css', 'mappings', 'mappingsManifest', 'bundle'];

function exactKeys(value, expected, label) {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`${label} must be an object`);
  }
  const actual = Object.keys(value).sort((left, right) => left.localeCompare(right));
  const wanted = [...expected].sort((left, right) => left.localeCompare(right));
  if (JSON.stringify(actual) !== JSON.stringify(wanted)) {
    throw new Error(`${label} must contain exactly: ${wanted.join(', ')}`);
  }
}

function projectPath(root, value, label) {
  if (typeof value !== 'string' || value.trim() === '' || path.isAbsolute(value)) {
    throw new Error(`${label} must be a non-empty project-relative path`);
  }
  const resolved = path.resolve(root, value);
  const relative = path.relative(root, resolved);
  if (relative.startsWith('..') || path.isAbsolute(relative)) {
    throw new Error(`${label} must stay inside the project root`);
  }
  return value;
}

export function loadStyleConfig(root) {
  const filename = path.join(root, 'style.config.json');
  const config = JSON.parse(fs.readFileSync(filename, 'utf8'));
  exactKeys(config, expectedTopLevel, 'style.config.json');
  if (config.schemaVersion !== 1) throw new Error('style.config.json schemaVersion must be 1');
  const packageSegments =
    typeof config.mappingsPackage === 'string' ? config.mappingsPackage.split('/') : [];
  if (
    packageSegments.length === 0 ||
    packageSegments.some(
      (segment) =>
        segment === '' ||
        segment === '.' ||
        segment === '..' ||
        !/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(segment),
    )
  ) {
    throw new Error('style.config.json mappingsPackage is invalid');
  }
  if (config.outputs == null || typeof config.outputs !== 'object') {
    throw new Error('style.config.json outputs must be an object');
  }
  exactKeys(config.outputs, expectedOutputs, 'style.config.json outputs');
  const outputs = Object.fromEntries(
    Object.entries(config.outputs).map(([key, value]) => [
      key,
      projectPath(root, value, `outputs.${key}`),
    ]),
  );
  if (!Array.isArray(config.dependencyRoots)) {
    throw new Error('style.config.json dependencyRoots must be an array');
  }
  const dependencyRoots = config.dependencyRoots.map((value, index) =>
    projectPath(root, value, `dependencyRoots[${index}]`),
  );
  if (new Set(dependencyRoots).size !== dependencyRoots.length) {
    throw new Error('style.config.json dependencyRoots must be unique');
  }
  return Object.freeze({
    schemaVersion: 1,
    mappingsPackage: config.mappingsPackage,
    outputs: Object.freeze(outputs),
    dependencyRoots: Object.freeze(dependencyRoots),
    cacheDirectory: projectPath(root, config.cacheDirectory, 'cacheDirectory'),
  });
}

function walkBundles(directory, output) {
  for (const entry of fs
    .readdirSync(directory, { withFileTypes: true })
    .sort((a, b) => a.name.localeCompare(b.name))) {
    const filename = path.join(directory, entry.name);
    if (entry.isDirectory()) walkBundles(filename, output);
    else if (entry.isFile() && entry.name.endsWith('.bundle.json')) output.push(filename);
  }
}

export function discoverDependencyBundles(root, dependencyRoots) {
  const output = [];
  for (const configuredRoot of dependencyRoots) {
    const directory = path.resolve(root, configuredRoot);
    if (!fs.existsSync(directory) || !fs.statSync(directory).isDirectory()) {
      throw new Error(`Dependency root is not a directory: ${configuredRoot}`);
    }
    walkBundles(directory, output);
  }
  return [...new Set(output)]
    .sort((left, right) => left.localeCompare(right))
    .map((filename) => path.relative(root, filename));
}
