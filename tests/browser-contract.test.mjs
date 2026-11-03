import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { createServer } from 'node:http';
import { PassThrough } from 'node:stream';
import { test } from 'vite-plus/test';
import {
  browserReportIssues,
  REQUIRED_BROWSERS,
  waitForHttpServer,
} from '../tools/browser-contract.mjs';

function report(statuses = {}) {
  return {
    schemaVersion: 1,
    required: true,
    results: REQUIRED_BROWSERS.map((name) => ({ name, status: statuses[name] ?? 'passed' })),
  };
}

test('strict browser report accepts exactly three passing engines', () => {
  assert.deepEqual(browserReportIssues(report()), []);
});

test('strict browser report rejects skips and missing engines', () => {
  assert.match(browserReportIssues(report({ firefox: 'skipped' })).join('\n'), /firefox/);
  const missing = report();
  missing.results.pop();
  assert.match(browserReportIssues(missing).join('\n'), /WebKit|webkit/);
});

function childProcess() {
  return Object.assign(new EventEmitter(), {
    stdout: new PassThrough(),
    stderr: new PassThrough(),
    exitCode: null,
    signalCode: null,
  });
}

async function httpServer(t, handler) {
  const server = createServer(handler);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.onTestFinished(() => new Promise((resolve) => server.close(resolve)));
  return `http://127.0.0.1:${server.address().port}`;
}

test('server readiness waits for HTTP success independently of colored console URLs', async (t) => {
  let requests = 0;
  const url = await httpServer(t, (_request, response) => {
    requests += 1;
    response.writeHead(requests === 1 ? 503 : 200).end();
  });
  const child = childProcess();
  const ready = waitForHttpServer(child, url, { name: 'test server', timeoutMs: 2000 });
  child.stdout.write(`Local: ${url.replace(/:(\d+)$/, ':\u001b[1m$1\u001b[22m')}\n`);
  await ready;
  assert.ok(requests >= 2, 'a startup response must not count as a ready server');
  assert.equal(child.listenerCount('exit'), 0);
  assert.equal(child.stdout.listenerCount('data'), 0);
});

test('server readiness reports early process exit with captured diagnostics', async (t) => {
  const url = await httpServer(t, (_request, response) => response.writeHead(503).end());
  const child = childProcess();
  const ready = waitForHttpServer(child, url, { name: 'test server', timeoutMs: 2000 });
  child.stderr.write('configuration failed\n');
  child.emit('exit', 23, null);
  await assert.rejects(ready, /test server exited with 23:\nconfiguration failed/);
  assert.equal(child.listenerCount('error'), 0);
});

test('server readiness has a bounded timeout and preserves useful output', async (t) => {
  const url = await httpServer(t, (_request, response) => response.writeHead(503).end());
  const child = childProcess();
  const ready = waitForHttpServer(child, url, { name: 'test server', timeoutMs: 50 });
  child.stdout.write('\u001b[31mstill starting\u001b[0m\n');
  await assert.rejects(ready, /did not start.*within 50ms:\nstill starting/);
  assert.equal(child.listenerCount('exit'), 0);
});
