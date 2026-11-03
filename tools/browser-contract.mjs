import { stripVTControlCharacters } from 'node:util';

export const REQUIRED_BROWSERS = Object.freeze(['chromium', 'firefox', 'webkit']);

export function waitForHttpServer(child, url, { name, timeoutMs }) {
  return new Promise((resolve, reject) => {
    let output = '';
    let settled = false;
    let poll;
    let timeout;
    const controller = new AbortController();
    const consume = (chunk) => {
      output = (output + chunk.toString()).slice(-16_384);
    };
    const finish = (message) => {
      if (settled) return;
      settled = true;
      clearTimeout(poll);
      clearTimeout(timeout);
      controller.abort();
      child.stdout.off('data', consume);
      child.stderr.off('data', consume);
      child.off('exit', exited);
      child.off('error', failed);
      if (message) reject(new Error(`${message}:\n${stripVTControlCharacters(output)}`));
      else resolve();
    };
    const exited = (code, signal) => finish(`${name} exited with ${signal ?? code}`);
    const failed = (error) => finish(`${name} failed to start: ${error.message}`);
    const probe = async () => {
      try {
        const response = await fetch(url, { signal: controller.signal });
        await response.body?.cancel();
        if (response.ok) {
          finish();
          return;
        }
      } catch {
        // Connection refusal and non-success responses are expected during startup.
      }
      if (!settled) poll = setTimeout(probe, 100);
    };
    child.stdout.on('data', consume);
    child.stderr.on('data', consume);
    child.once('exit', exited);
    child.once('error', failed);
    if (child.exitCode !== null || child.signalCode !== null) {
      exited(child.exitCode, child.signalCode);
      return;
    }
    timeout = setTimeout(
      () => finish(`${name} did not start at ${url} within ${timeoutMs}ms`),
      timeoutMs,
    );
    void probe();
  });
}

export function browserReportIssues(report) {
  const issues = [];
  if (report?.schemaVersion !== 1) issues.push('browser report must use schema version 1');
  if (report?.required !== true) issues.push('browser report must require the complete matrix');
  const results = Array.isArray(report?.results) ? report.results : [];
  if (JSON.stringify(results.map((result) => result.name)) !== JSON.stringify(REQUIRED_BROWSERS)) {
    issues.push('browser report must contain Chromium, Firefox, and WebKit in order');
  }
  for (const browser of REQUIRED_BROWSERS) {
    const result = results.find((entry) => entry.name === browser);
    if (result?.status !== 'passed') {
      issues.push(`${browser}: expected passed, got ${result?.status ?? 'missing'}`);
    }
  }
  return issues;
}
