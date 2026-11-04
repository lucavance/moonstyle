// Host adapter: export pinned standards facts and css-tree observations only.
// Generation policy and MoonBit rendering belong to tooling/native.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { createHash } from 'node:crypto';
import { definitionSyntax, lexer } from 'css-tree';

const require = createRequire(import.meta.url);
const root = path.resolve(import.meta.dirname, '../..');
const target = path.join(root, 'tools/data/css-inputs.json');
const canonical = (value) =>
  Array.isArray(value)
    ? '[' + value.map(canonical).join(',') + ']'
    : value !== null && typeof value === 'object'
      ? '{' +
        Object.keys(value)
          .sort()
          .map((key) => JSON.stringify(key) + ':' + canonical(value[key]))
          .join(',') +
        '}'
      : JSON.stringify(value);
const digest = (value) => 'sha256:' + createHash('sha256').update(value).digest('hex');
const source = (name, filename) => {
  let directory = path.dirname(require.resolve(name));
  while (!fs.existsSync(path.join(directory, 'package.json'))) directory = path.dirname(directory);
  const manifest = JSON.parse(fs.readFileSync(path.join(directory, 'package.json'), 'utf8'));
  const bytes = fs.readFileSync(path.join(directory, filename), 'utf8');
  return {
    metadata: { version: manifest.version, license: manifest.license, digest: digest(bytes) },
    data: JSON.parse(bytes),
  };
};
const webref = source('@webref/css', 'css.json');
const bcd = source('@mdn/browser-compat-data', 'data.json');
const cssTree = JSON.parse(fs.readFileSync(require.resolve('css-tree/package.json'), 'utf8'));
const ast = (syntax = '') => {
  try {
    return JSON.parse(canonical(definitionSyntax.parse(syntax)));
  } catch {
    return null;
  }
};
const keywords = (node, output = new Set()) => {
  if (!node || typeof node !== 'object') return output;
  if (node.type === 'Keyword') output.add(node.name);
  for (const value of Object.values(node)) {
    if (Array.isArray(value)) for (const item of value) keywords(item, output);
    else if (value && typeof value === 'object') keywords(value, output);
  }
  return output;
};
const samples = [
  '1px',
  '1%',
  'red',
  '1.5',
  '2',
  '1s',
  '1deg',
  '1dpi',
  'url("x")',
  '1px solid #000',
  '#000 transparent',
  'solid dotted',
  '1px thin',
  '#000',
  'solid',
  '1px 2px',
  '1px auto #000',
];
const payload = {
  schemaVersion: 1,
  sources: {
    '@webref/css': webref.metadata,
    '@mdn/browser-compat-data': bcd.metadata,
    'css-tree': { version: cssTree.version, license: cssTree.license },
  },
  properties: webref.data.properties.map((entry) => {
    const tree = ast(entry.syntax);
    const matches = Object.fromEntries(
      [...new Set([...samples, ...keywords(tree)])].sort().map((value) => {
        try {
          return [value, lexer.matchProperty(entry.name, value).matched != null];
        } catch {
          return [value, false];
        }
      }),
    );
    return {
      ...entry,
      ast: tree,
      status: bcd.data.css.properties[entry.name]?.__compat?.status ?? null,
      matches,
    };
  }),
  types: webref.data.types.map((entry) => ({ ...entry, ast: ast(entry.syntax) })),
  functions: webref.data.functions.map((entry) => ({ ...entry, ast: ast(entry.syntax) })),
};
const document = JSON.stringify({ digest: digest(canonical(payload)), payload }, null, 2) + '\n';
if (process.argv.includes('--check')) {
  if (fs.readFileSync(target, 'utf8') !== document) throw new Error('Standards snapshot is stale');
} else {
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, document);
}
