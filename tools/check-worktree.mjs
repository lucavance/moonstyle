import { spawnSync } from 'node:child_process';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');
const result = spawnSync('git', ['status', '--porcelain=v1', '--untracked-files=all'], {
  cwd: root,
  encoding: 'utf8',
});
if (result.status !== 0) {
  process.stderr.write(result.stderr);
  process.exitCode = result.status ?? 1;
} else if (result.stdout.trim()) {
  process.stderr.write(`Validation changed the worktree:\n${result.stdout}`);
  process.exitCode = 1;
} else {
  process.stdout.write('Validation left the tracked candidate clean.\n');
}
