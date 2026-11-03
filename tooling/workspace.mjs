import fs from 'node:fs';
import path from 'node:path';

export function moonConfiguration(content) {
  return content.replace(/"(?:\\.|[^"\\])*"|\/\/[^\n]*|\/\*[\s\S]*?\*\//g, (token) =>
    token.startsWith('"') ? token : ' ',
  );
}

// Watch module sources and manifests rather than an ancestor's build directories.
// Invalid manifests remain the compiler's responsibility so watch can recover.
export function workspaceWatchPaths(root) {
  root = path.resolve(root);
  const inputs = new Set([root]);
  let members = [root];
  for (let directory = root; ; directory = path.dirname(directory)) {
    const filename = path.join(directory, 'moon.work');
    if (fs.existsSync(filename)) {
      inputs.add(filename);
      const configuration = moonConfiguration(fs.readFileSync(filename, 'utf8'));
      const list = configuration.match(/\bmembers\s*=\s*\[([\s\S]*?)\]/)?.[1] ?? '';
      members = [...list.matchAll(/"(?:\\.|[^"\\])*"/g)].map((match) =>
        path.resolve(directory, JSON.parse(match[0])),
      );
      break;
    }
    if (directory === path.dirname(directory)) break;
  }
  for (const member of members) {
    const manifest = path.join(member, 'moon.mod');
    if (!fs.existsSync(manifest)) continue;
    inputs.add(manifest);
    const configuration = moonConfiguration(fs.readFileSync(manifest, 'utf8'));
    const source = configuration.match(/^\s*source\s*=\s*("(?:\\.|[^"\\])*")\s*$/m)?.[1];
    const directory = path.resolve(member, source === undefined ? '.' : JSON.parse(source));
    if (fs.existsSync(directory)) inputs.add(directory);
  }
  return [...inputs].sort((left, right) => left.localeCompare(right));
}
