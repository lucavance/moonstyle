import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import net from 'node:net';
import path from 'node:path';
import { afterAll, beforeAll, test } from 'vite-plus/test';
import { waitForHttpServer } from '../browser-contract.mjs';

const root = path.resolve(import.meta.dirname, '../..');
process.env.PLAYWRIGHT_BROWSERS_PATH ??= path.join(root, '.cache', 'playwright');
const { chromium, firefox, webkit } = await import('playwright');
const requireAllBrowsers = process.env.STYLE_REQUIRE_ALL_BROWSERS === '1';
let devServer;
let origin;

function freePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.unref();
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      server.close(() => resolve(address.port));
    });
  });
}

beforeAll(async () => {
  const port = await freePort();
  origin = `http://127.0.0.1:${port}`;
  devServer = spawn('moon', ['run', 'tools/dev.mbtx', '--', '--port', String(port)], {
    cwd: root,
    env: process.env,
    stdio: ['ignore', 'pipe', 'pipe'],
    detached: true,
  });
  await waitForHttpServer(devServer, origin, {
    name: 'MoonStyle native dev server',
    timeoutMs: 60_000,
  });
  for (let attempt = 0; attempt < 120; attempt += 1) {
    const status = await fetch(`${origin}/__moonstyle/status`).then((response) => response.json());
    if (status.state === 'ready') return;
    if (status.state === 'stale') throw Error(JSON.stringify(status));
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw Error('Native development build did not become ready');
}, 60_000);

afterAll(() => {
  if (devServer && devServer.exitCode === null) process.kill(-devServer.pid, 'SIGTERM');
});

const browserMatrix = /** @type {const} */ ([
  ['chromium', chromium],
  ['firefox', firefox],
  ['webkit', webkit],
]);

for (const [browserName, browserType] of browserMatrix) {
  const blockedByCodexSandbox =
    browserName === 'firefox' && process.env.CODEX_CI && !requireAllBrowsers;
  const browserTest = blockedByCodexSandbox ? test.skip : test;
  browserTest(`dev style inspector selects applied rules [${browserName}]`, async () => {
    const browser = await browserType.launch({ headless: true, timeout: 20_000 });
    try {
      const page = await browser.newPage({ viewport: { width: 1024, height: 800 } });
      const errors = [];
      page.on('console', (message) => {
        if (message.type() === 'error') errors.push(message.text());
      });
      page.on('pageerror', (error) => errors.push(error.message));
      await page.goto(origin, { waitUntil: 'domcontentloaded' });
      await page.locator('[data-moonstyle-inspector]').waitFor({ state: 'attached' });
      await page.keyboard.press('Alt+Shift+S');
      await page.locator('[data-moonstyle-inspector] .panel').waitFor();
      await page.locator('[data-moonstyle-inspector] .pick').click();
      const rectangle = await page.locator('#validation-card').boundingBox();
      assert.ok(rectangle);
      await page.mouse.click(rectangle.x + 8, rectangle.y + 8);
      assert.ok(await page.locator('[data-moonstyle-inspector] .rule').count());
      assert.match(
        await page.locator('[data-moonstyle-inspector] .selection').textContent(),
        /#validation-card/,
      );
      assert.match(
        await page.locator('[data-moonstyle-inspector] .source').first().textContent(),
        /examples\/styles\/styles\.mbt:/,
      );
      assert.match(
        await page.locator('[data-moonstyle-inspector] .computed').first().textContent(),
        /^computed:/,
      );
      assert.equal(
        await page.locator('[data-moonstyle-inspector]').getAttribute('data-status'),
        'ready',
      );
      await page.locator('#expression-panel').scrollIntoViewIfNeeded();
      await page.locator('[data-moonstyle-inspector] .pick').click();
      const expressionRectangle = await page.locator('#expression-panel').boundingBox();
      assert.ok(expressionRectangle);
      await page.mouse.click(expressionRectangle.x + 4, expressionRectangle.y + 4);
      assert.match(
        await page.locator('[data-moonstyle-inspector] .selection').textContent(),
        /#expression-panel/,
      );
      assert.match(
        (await page.locator('[data-moonstyle-inspector] .source').allTextContents()).join('\n'),
        /examples\/styles\/expressions\.mbt:/,
      );
      assert.deepEqual(errors, []);
    } finally {
      await browser.close();
    }
  });
}
