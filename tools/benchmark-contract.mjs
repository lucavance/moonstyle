export const BENCHMARK_REPORT_SCHEMA_VERSION = 4;

export const CANDIDATE_BENCHMARK_REPORTS = Object.freeze([
  'benchmarks/0.2.0-candidate-1.json',
  'benchmarks/0.2.0-candidate-2.json',
]);

export const BENCHMARK_SCENARIOS = Object.freeze({
  small: Object.freeze({
    modules: 2,
    rules: 100,
    warmups: 20,
    measuredRuns: 100,
    ordering: 'balanced-alternating-blocks',
    budgetKind: 'distribution-no-regression',
  }),
  medium: Object.freeze({
    modules: 60,
    rules: 6_000,
    warmups: 10,
    measuredRuns: 20,
    ordering: 'alternating-pairs',
    budgetKind: 'minimum-speedup',
  }),
  large: Object.freeze({
    modules: 100,
    rules: 10_000,
    warmups: 10,
    measuredRuns: 20,
    ordering: 'alternating-pairs',
    budgetKind: 'minimum-speedup',
  }),
});

function round(value) {
  return Number(value.toFixed(3));
}

function normalizedSamples(samples) {
  if (!Array.isArray(samples) || samples.length === 0) {
    throw new Error('benchmark samples must be a non-empty array');
  }
  if (samples.some((sample) => !Number.isFinite(sample))) {
    throw new Error('benchmark samples must contain only finite numbers');
  }
  return samples.map(round);
}

export function summarizeSamples(samples) {
  const normalized = normalizedSamples(samples);
  const ordered = [...normalized].sort((left, right) => left - right);
  const middle = Math.floor(ordered.length / 2);
  const median =
    ordered.length % 2 === 0 ? (ordered[middle - 1] + ordered[middle]) / 2 : ordered[middle];
  return {
    medianMs: round(median),
    p95Ms: ordered[Math.ceil(ordered.length * 0.95) - 1],
    minMs: ordered[0],
    maxMs: ordered.at(-1),
    samplesMs: normalized,
  };
}

export function summarizePairedTimings(fullSamples, adaptiveSamples) {
  const full = normalizedSamples(fullSamples);
  const adaptive = normalizedSamples(adaptiveSamples);
  if (full.length !== adaptive.length) {
    throw new Error('paired benchmark samples must have equal lengths');
  }
  if (full.some((sample) => sample <= 0) || adaptive.some((sample) => sample <= 0)) {
    throw new Error('paired benchmark timing samples must be positive');
  }
  const delta = adaptive.map((sample, index) => round(sample - full[index]));
  return {
    full: summarizeSamples(full),
    adaptive: summarizeSamples(adaptive),
    delta: summarizeSamples(delta),
  };
}

export function scenarioRatios(timings) {
  return {
    speedup: round(timings.full.medianMs / timings.adaptive.medianMs),
    p95Ratio: round(timings.adaptive.p95Ms / timings.full.p95Ms),
  };
}

export function evaluateScenarioBudget(name, timings) {
  if (name === 'small') {
    const medianLimit = Math.max(timings.full.medianMs * 1.05, timings.full.medianMs + 1);
    const p95Limit = Math.max(timings.full.p95Ms * 1.15, timings.full.p95Ms + 1);
    return {
      kind: 'distribution-no-regression',
      thresholds: {
        medianMaximumMs: round(medianLimit),
        p95MaximumMs: round(p95Limit),
      },
      observed: {
        adaptiveMedianMs: timings.adaptive.medianMs,
        adaptiveP95Ms: timings.adaptive.p95Ms,
      },
      met: timings.adaptive.medianMs <= medianLimit && timings.adaptive.p95Ms <= p95Limit,
    };
  }
  const { speedup } = scenarioRatios(timings);
  return {
    kind: 'minimum-speedup',
    thresholds: { minimumSpeedup: 3 },
    observed: { speedup },
    met: speedup >= 3,
  };
}

function equal(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function validTimestamp(value) {
  return typeof value === 'string' && Number.isFinite(Date.parse(value));
}

export function candidatePerformanceIssues(reports, expectedCandidate, expectedSizes) {
  const issues = [];
  if (!Array.isArray(reports) || reports.length !== 2) {
    return ['exactly two candidate benchmark reports are required'];
  }

  for (const [reportIndex, report] of reports.entries()) {
    const label = `report ${reportIndex + 1}`;
    if (report?.schemaVersion !== BENCHMARK_REPORT_SCHEMA_VERSION) {
      issues.push(`${label} must use benchmark schema v${BENCHMARK_REPORT_SCHEMA_VERSION}`);
    }
    if (!validTimestamp(report?.recordedAt)) issues.push(`${label} has an invalid recordedAt`);
    if (!equal(report?.candidate, expectedCandidate)) {
      issues.push(`${label} does not match the current candidate identity`);
    }
    if (!equal(report?.sizes, expectedSizes)) {
      issues.push(`${label} does not match the current generated artifact sizes`);
    }

    const scenarioNames = Object.keys(BENCHMARK_SCENARIOS);
    if (!equal(Object.keys(report?.scenarios ?? {}), scenarioNames)) {
      issues.push(`${label} does not contain the exact benchmark scenarios`);
      continue;
    }
    let allBudgetsMet = true;
    for (const [name, configuration] of Object.entries(BENCHMARK_SCENARIOS)) {
      const scenario = report.scenarios[name];
      if (!scenario || typeof scenario !== 'object') {
        issues.push(`${label} ${name} scenario is invalid`);
        allBudgetsMet = false;
        continue;
      }
      if (scenario.modules !== configuration.modules || scenario.rules !== configuration.rules) {
        issues.push(`${label} ${name} workload differs from the frozen configuration`);
      }
      if (
        !equal(scenario.measurement, {
          warmups: configuration.warmups,
          measuredRuns: configuration.measuredRuns,
          ordering: configuration.ordering,
        })
      ) {
        issues.push(`${label} ${name} measurement configuration differs`);
      }
      const fullSamples = scenario.timings?.full?.samplesMs;
      const adaptiveSamples = scenario.timings?.adaptive?.samplesMs;
      if (
        fullSamples?.length !== configuration.measuredRuns ||
        adaptiveSamples?.length !== configuration.measuredRuns
      ) {
        issues.push(`${label} ${name} must contain exactly ${configuration.measuredRuns} pairs`);
      }
      try {
        const recalculatedTimings = summarizePairedTimings(fullSamples, adaptiveSamples);
        if (!equal(scenario.timings, recalculatedTimings)) {
          issues.push(`${label} ${name} timing summary is not reproducible from its samples`);
        }
        const recalculatedRatios = scenarioRatios(recalculatedTimings);
        if (
          scenario.speedup !== recalculatedRatios.speedup ||
          scenario.p95Ratio !== recalculatedRatios.p95Ratio
        ) {
          issues.push(`${label} ${name} ratios are not reproducible from its samples`);
        }
        const recalculatedBudget = evaluateScenarioBudget(name, recalculatedTimings);
        if (!equal(scenario.budget, recalculatedBudget)) {
          issues.push(`${label} ${name} budget result is not reproducible from its samples`);
        }
        if (scenario.budgetMet !== recalculatedBudget.met) {
          issues.push(`${label} ${name} budgetMet differs from the calculated result`);
        }
        allBudgetsMet &&= recalculatedBudget.met;
      } catch (error) {
        issues.push(`${label} ${name} samples are invalid: ${error.message}`);
        allBudgetsMet = false;
      }
    }
    if (report.budgetsMet !== allBudgetsMet || report.budgetsMet !== true) {
      issues.push(`${label} does not pass every performance budget`);
    }
  }

  if (reports[0]?.recordedAt === reports[1]?.recordedAt) {
    issues.push('candidate benchmark reports must have distinct timestamps');
  } else if (
    validTimestamp(reports[0]?.recordedAt) &&
    validTimestamp(reports[1]?.recordedAt) &&
    Date.parse(reports[0].recordedAt) >= Date.parse(reports[1].recordedAt)
  ) {
    issues.push('candidate benchmark reports must be recorded in order');
  }
  for (const field of ['machine', 'toolchain', 'candidate', 'sizes']) {
    if (!equal(reports[0]?.[field], reports[1]?.[field])) {
      issues.push(`candidate benchmark reports have different ${field} values`);
    }
  }
  return issues;
}
