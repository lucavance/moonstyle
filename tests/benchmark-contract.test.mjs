import assert from 'node:assert/strict';
import { test } from 'vite-plus/test';
import {
  BENCHMARK_REPORT_SCHEMA_VERSION,
  BENCHMARK_SCENARIOS,
  candidatePerformanceIssues,
  evaluateScenarioBudget,
  scenarioRatios,
  summarizePairedTimings,
  summarizeSamples,
} from '../tools/benchmark-contract.mjs';

const candidate = {
  artifactSchemaVersion: 9,
  propertyApiSchemaVersion: 12,
  propertyCount: 384,
  semantics: {
    profile: 'stylex-0.19.1-application-order+font-aliases-v1',
    digest: 'sha256:test',
  },
};
const sizes = {
  css: { rawBytes: 1, gzipBytes: 1 },
  mappings: { rawBytes: 1, gzipBytes: 1 },
  mappingsManifest: { rawBytes: 1, gzipBytes: 1 },
  bundle: { rawBytes: 1, gzipBytes: 1 },
};

function repeated(value, count) {
  return Array.from({ length: count }, () => value);
}

function scenario(name, fullSamples, adaptiveSamples) {
  const configuration = BENCHMARK_SCENARIOS[name];
  const timings = summarizePairedTimings(fullSamples, adaptiveSamples);
  const { speedup, p95Ratio } = scenarioRatios(timings);
  const budget = evaluateScenarioBudget(name, timings);
  return {
    modules: configuration.modules,
    rules: configuration.rules,
    measurement: {
      warmups: configuration.warmups,
      measuredRuns: configuration.measuredRuns,
      ordering: configuration.ordering,
    },
    timings,
    speedup,
    p95Ratio,
    budget,
    budgetMet: budget.met,
  };
}

function report(recordedAt) {
  const scenarios = {
    small: scenario('small', repeated(10, 100), repeated(10.5, 100)),
    medium: scenario('medium', repeated(30, 20), repeated(10, 20)),
    large: scenario('large', repeated(60, 20), repeated(10, 20)),
  };
  return {
    schemaVersion: BENCHMARK_REPORT_SCHEMA_VERSION,
    recordedAt,
    candidate,
    machine: { platform: 'test' },
    toolchain: { moon: 'test' },
    scenarios,
    budgetsMet: Object.values(scenarios).every((entry) => entry.budgetMet),
    sizes: structuredClone(sizes),
  };
}

test('benchmark statistics support arbitrary sample counts', () => {
  assert.deepEqual(summarizeSamples([5, 1, 3, 2]), {
    medianMs: 2.5,
    p95Ms: 5,
    minMs: 1,
    maxMs: 5,
    samplesMs: [5, 1, 3, 2],
  });
  assert.equal(summarizeSamples([1, 9, 3]).medianMs, 3);
});

test('small benchmark budget uses the original distribution thresholds', () => {
  const passing = summarizePairedTimings(repeated(10, 100), repeated(10.5, 100));
  assert.deepEqual(evaluateScenarioBudget('small', passing), {
    kind: 'distribution-no-regression',
    thresholds: { medianMaximumMs: 11, p95MaximumMs: 11.5 },
    observed: { adaptiveMedianMs: 10.5, adaptiveP95Ms: 10.5 },
    met: true,
  });

  const medianFailure = summarizePairedTimings(repeated(10, 100), repeated(11.1, 100));
  assert.equal(evaluateScenarioBudget('small', medianFailure).met, false);

  const tailFailure = summarizePairedTimings(repeated(10, 100), [
    ...repeated(10.5, 94),
    ...repeated(12, 6),
  ]);
  const result = evaluateScenarioBudget('small', tailFailure);
  assert.equal(result.observed.adaptiveMedianMs, 10.5);
  assert.equal(result.observed.adaptiveP95Ms, 12);
  assert.equal(result.met, false);
});

test('medium and large benchmark budgets preserve the three-times speedup boundary', () => {
  assert.equal(
    evaluateScenarioBudget('medium', summarizePairedTimings(repeated(30, 20), repeated(10, 20)))
      .met,
    true,
  );
  assert.equal(
    evaluateScenarioBudget('large', summarizePairedTimings(repeated(29.9, 20), repeated(10, 20)))
      .met,
    false,
  );
});

test('candidate performance evidence is complete and independently reproducible', () => {
  const first = report('2026-07-22T00:00:00.000Z');
  const second = report('2026-07-22T00:01:00.000Z');
  assert.deepEqual(candidatePerformanceIssues([first, second], candidate, sizes), []);

  const drifted = structuredClone(second);
  drifted.candidate.propertyCount = 345;
  assert.match(
    candidatePerformanceIssues([first, drifted], candidate, sizes).join('\n'),
    /current candidate identity|different candidate values/,
  );

  const forged = structuredClone(second);
  forged.scenarios.small.timings.delta.p95Ms = 0;
  assert.match(
    candidatePerformanceIssues([first, forged], candidate, sizes).join('\n'),
    /timing summary is not reproducible/,
  );

  const truncated = structuredClone(second);
  truncated.scenarios.small.timings.full.samplesMs.pop();
  assert.match(
    candidatePerformanceIssues([first, truncated], candidate, sizes).join('\n'),
    /must contain exactly 100 pairs/,
  );

  const staleSizes = structuredClone(second);
  staleSizes.sizes.css.rawBytes += 1;
  assert.match(
    candidatePerformanceIssues([first, staleSizes], candidate, sizes).join('\n'),
    /current generated artifact sizes/,
  );
});
