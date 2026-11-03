import { spawnSync } from 'node:child_process';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');
const browserDirectory = path.join(root, '.cache', 'playwright');
const installArguments = ['exec', 'playwright', 'install'];
if (process.argv.includes('--with-deps')) installArguments.push('--with-deps');
installArguments.push('chromium', 'firefox', 'webkit');
const result = spawnSync('vp', installArguments, {
  cwd: root,
  env: { ...process.env, PLAYWRIGHT_BROWSERS_PATH: browserDirectory },
  stdio: 'inherit',
});
process.exitCode = result.status ?? 1;
