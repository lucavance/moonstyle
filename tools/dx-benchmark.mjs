import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(import.meta.dirname, '..');
const applicationRoot = path.join(root, 'validation');
const extractorPackage = 'cmd/style_extract';
const artifactNames = ['css', 'mappings', 'mappingsManifest', 'bundle'];

function percentile(values, fraction) {
  const sorted = [...values].sort((left, right) => left - right);
  return sorted[Math.ceil(sorted.length * fraction) - 1];
}

export function summarizeTimings(values) {
  if (!Array.isArray(values) || values.length === 0) {
    throw new Error('DX benchmark timings must contain at least one sample.');
  }
  const sorted = [...values].sort((left, right) => left - right);
  const middle = Math.floor(sorted.length / 2);
  const median =
    sorted.length % 2 === 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle];
  return {
    samplesMs: values.map((value) => Number(value.toFixed(3))),
    medianMs: Number(median.toFixed(3)),
    p95Ms: Number(percentile(values, 0.95).toFixed(3)),
  };
}

export function evaluateDxBenchmark({
  debugColdMs,
  releaseColdMs,
  warmDebugMs,
  debugExecutionMs,
  debugDevtoolsExecutionMs,
  outputsEqual,
}) {
  const coldRatio = debugColdMs / releaseColdMs;
  const warmLimitMs = Math.max(750, debugColdMs * 0.5);
  const devtoolsOverheadMs = Math.max(0, debugDevtoolsExecutionMs - debugExecutionMs);
  const checks = {
    debugColdRelative: {
      actual: Number(coldRatio.toFixed(4)),
      maximum: 0.65,
      met: coldRatio <= 0.65,
    },
    debugWarm: {
      actualMs: Number(warmDebugMs.toFixed(3)),
      maximumMs: Number(warmLimitMs.toFixed(3)),
      met: warmDebugMs <= warmLimitMs,
    },
    devtoolsOverhead: {
      actualMs: Number(devtoolsOverheadMs.toFixed(3)),
      maximumMs: 50,
      met: devtoolsOverheadMs <= 50,
    },
    outputParity: { met: outputsEqual },
  };
  return { checks, met: Object.values(checks).every((check) => check.met) };
}

function timedCommand(command, arguments_, options = {}) {
  const started = process.hrtime.bigint();
  const result = spawnSync(command, arguments_, {
    cwd: applicationRoot,
    encoding: 'utf8',
    ...options,
  });
  const milliseconds = Number(process.hrtime.bigint() - started) / 1e6;
  if (result.status !== 0) {
    throw new Error(
      `${command} ${arguments_.join(' ')} failed:\n${result.stdout ?? ''}${result.stderr ?? ''}`,
    );
  }
  return { milliseconds, stdout: result.stdout ?? '', stderr: result.stderr ?? '' };
}

function artifactPath(output) {
  for (const line of output.split(/\r?\n/).toReversed()) {
    try {
      const value = JSON.parse(line);
      if (Array.isArray(value.artifacts_path) && value.artifacts_path.length === 1) {
        return value.artifacts_path[0];
      }
    } catch {
      // Moon can print ordinary progress lines next to the final JSON record.
    }
  }
  throw new Error(`Moon did not report exactly one extractor artifact:\n${output}`);
}

function buildExtractor(profile, targetDirectory) {
  const result = timedCommand('moon', [
    'run',
    extractorPackage,
    '--target',
    'native',
    ...(profile === 'release' ? ['--release'] : []),
    '--build-only',
    '--output-json',
    '--target-dir',
    targetDirectory,
    '--frozen',
  ]);
  const executable = artifactPath(`${result.stdout}\n${result.stderr}`);
  if (!fs.existsSync(executable))
    throw new Error(`Extractor artifact does not exist: ${executable}`);
  return { ...result, executable };
}

function outputPaths(directory) {
  return {
    css: path.join(directory, 'styles.generated.css'),
    mappings: path.join(directory, 'styles.generated.mbt'),
    mappingsManifest: path.join(directory, 'moon.pkg'),
    bundle: path.join(directory, 'styles.bundle.json'),
  };
}

function executeExtractor(executable, directory, styleConfig, { devtools = false } = {}) {
  fs.mkdirSync(directory, { recursive: true });
  const outputs = outputPaths(directory);
  const debugManifest = path.join(directory, 'styles.debug.json');
  const result = timedCommand(
    executable,
    [
      '--diagnostics=json',
      '--tooling-protocol',
      '1',
      '--no-cache',
      '--css-output',
      outputs.css,
      '--mappings-output',
      outputs.mappings,
      '--mappings-manifest-output',
      outputs.mappingsManifest,
      '--mappings-package',
      styleConfig.mappingsPackage,
      '--bundle-output',
      outputs.bundle,
      '--cache-dir',
      path.join(directory, 'cache'),
      ...(devtools ? ['--debug-manifest-output', debugManifest] : []),
      ...styleConfig.dependencyRoots.flatMap((dependencyRoot) => [
        '--dependency-root',
        path.resolve(applicationRoot, dependencyRoot),
      ]),
    ],
    { cwd: root },
  );
  if (devtools) {
    const parsed = JSON.parse(fs.readFileSync(debugManifest, 'utf8'));
    if (parsed.schemaVersion !== 1 || !Array.isArray(parsed.rules)) {
      throw new Error('Debug extractor benchmark produced an invalid debug manifest.');
    }
  }
  return { ...result, outputs };
}

function digestOutputs(outputs) {
  return Object.fromEntries(
    artifactNames.map((name) => [
      name,
      `sha256:${createHash('sha256').update(fs.readFileSync(outputs[name])).digest('hex')}`,
    ]),
  );
}

function commandVersion(command, arguments_) {
  const result = spawnSync(command, arguments_, { cwd: applicationRoot, encoding: 'utf8' });
  return `${result.stdout ?? ''}${result.stderr ?? ''}`.trim().split('\n')[0];
}

function sampleCount() {
  const value = Number.parseInt(process.env.STYLE_DX_BENCHMARK_SAMPLES ?? '2', 10);
  if (!Number.isInteger(value) || value < 1 || value > 10) {
    throw new Error('STYLE_DX_BENCHMARK_SAMPLES must be an integer from 1 through 10.');
  }
  return value;
}

export function runDxBenchmark() {
  const styleConfig = JSON.parse(
    fs.readFileSync(path.join(applicationRoot, 'style.config.json'), 'utf8'),
  );
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'style-dx-benchmark-'));
  const debugCold = [];
  const releaseCold = [];
  const debugExecution = [];
  const debugDevtoolsExecution = [];
  const releaseExecution = [];
  const parity = [];
  let warmTarget;
  try {
    for (let index = 0; index < sampleCount(); index += 1) {
      const profiles = index % 2 === 0 ? ['debug', 'release'] : ['release', 'debug'];
      const builds = {};
      for (const profile of profiles) {
        const targetDirectory = path.join(temporary, `cold-${index}-${profile}`);
        builds[profile] = buildExtractor(profile, targetDirectory);
        (profile === 'debug' ? debugCold : releaseCold).push(builds[profile].milliseconds);
        if (profile === 'debug') warmTarget = targetDirectory;
      }
      const debug = executeExtractor(
        builds.debug.executable,
        path.join(temporary, `outputs-${index}-debug`),
        styleConfig,
      );
      const debugDevtools = executeExtractor(
        builds.debug.executable,
        path.join(temporary, `outputs-${index}-debug-devtools`),
        styleConfig,
        { devtools: true },
      );
      const release = executeExtractor(
        builds.release.executable,
        path.join(temporary, `outputs-${index}-release`),
        styleConfig,
      );
      debugExecution.push(debug.milliseconds);
      debugDevtoolsExecution.push(debugDevtools.milliseconds);
      releaseExecution.push(release.milliseconds);
      const debugDigests = digestOutputs(debug.outputs);
      const releaseDigests = digestOutputs(release.outputs);
      parity.push({
        sample: index + 1,
        equal:
          JSON.stringify(debugDigests) === JSON.stringify(releaseDigests) &&
          JSON.stringify(debugDigests) === JSON.stringify(digestOutputs(debugDevtools.outputs)),
        debug: debugDigests,
        release: releaseDigests,
      });
    }

    const warmDebug = Array.from(
      { length: 3 },
      () => buildExtractor('debug', warmTarget).milliseconds,
    );
    const timings = {
      coldBuild: {
        debug: summarizeTimings(debugCold),
        release: summarizeTimings(releaseCold),
      },
      warmDebugBuild: summarizeTimings(warmDebug),
      execution: {
        debug: summarizeTimings(debugExecution),
        debugDevtools: summarizeTimings(debugDevtoolsExecution),
        release: summarizeTimings(releaseExecution),
      },
    };
    const budgets = evaluateDxBenchmark({
      debugColdMs: timings.coldBuild.debug.medianMs,
      releaseColdMs: timings.coldBuild.release.medianMs,
      warmDebugMs: timings.warmDebugBuild.medianMs,
      debugExecutionMs: timings.execution.debug.medianMs,
      debugDevtoolsExecutionMs: timings.execution.debugDevtools.medianMs,
      outputsEqual: parity.every((entry) => entry.equal),
    });
    return {
      schemaVersion: 1,
      recordedAt: new Date().toISOString(),
      samples: debugCold.length,
      toolchain: {
        moon: commandVersion('moon', ['version']),
        vitePlus: commandVersion('vp', ['--version']),
        node: process.version,
      },
      machine: {
        platform: os.platform(),
        release: os.release(),
        architecture: os.arch(),
        cpu: os.cpus()[0]?.model ?? 'unknown',
        logicalCpus: os.cpus().length,
      },
      timings,
      parity,
      budgets,
    };
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true });
  }
}

function main() {
  const report = runDxBenchmark();
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  if (!report.budgets.met) process.exitCode = 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
