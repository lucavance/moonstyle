import assert from 'node:assert/strict';
import { test } from 'vite-plus/test';
import { evaluateDxBenchmark, summarizeTimings } from '../tools/dx-benchmark.mjs';

test('DX benchmark summarizes samples and enforces relative feedback budgets', () => {
  assert.deepEqual(summarizeTimings([30, 10, 20, 40]), {
    samplesMs: [30, 10, 20, 40],
    medianMs: 25,
    p95Ms: 40,
  });

  const passing = evaluateDxBenchmark({
    debugColdMs: 1_200,
    releaseColdMs: 12_000,
    warmDebugMs: 25,
    debugExecutionMs: 14,
    debugDevtoolsExecutionMs: 28,
    outputsEqual: true,
  });
  assert.equal(passing.met, true);
  assert.equal(passing.checks.debugColdRelative.actual, 0.1);
  assert.equal(passing.checks.devtoolsOverhead.actualMs, 14);

  assert.equal(
    evaluateDxBenchmark({
      debugColdMs: 9_000,
      releaseColdMs: 12_000,
      warmDebugMs: 25,
      debugExecutionMs: 14,
      debugDevtoolsExecutionMs: 28,
      outputsEqual: true,
    }).met,
    false,
  );
  assert.equal(
    evaluateDxBenchmark({
      debugColdMs: 1_200,
      releaseColdMs: 12_000,
      warmDebugMs: 25,
      debugExecutionMs: 14,
      debugDevtoolsExecutionMs: 28,
      outputsEqual: false,
    }).met,
    false,
  );
  assert.equal(
    evaluateDxBenchmark({
      debugColdMs: 1_200,
      releaseColdMs: 12_000,
      warmDebugMs: 25,
      debugExecutionMs: 14,
      debugDevtoolsExecutionMs: 65,
      outputsEqual: true,
    }).met,
    false,
  );
});
