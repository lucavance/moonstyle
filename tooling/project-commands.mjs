import fs from 'node:fs';
import path from 'node:path';
import {
  createExtractionQueue,
  createExtractorRunner,
  dependencyBundleFiles,
  diagnosticEndMarker,
  diagnosticStartMarker,
  formatProblem,
  isRelevantFile,
  loadStyleConfig,
} from './extraction.mjs';
import { loadCompatibleProjectManifest, moonProject, toolingVersion } from './project.mjs';
import { workspaceWatchPaths } from './workspace.mjs';

export const watchReadyMarker = '[moonstyle] watch-ready';
export const watchStopMarker = '[moonstyle] watch-stop';
const outputKinds = ['css', 'mappings', 'mappingsManifest', 'bundle'];

function projectFilename(root, filename) {
  if (filename == null) return null;
  const absolute = path.isAbsolute(filename) ? filename : path.resolve(root, filename);
  const relative = path.relative(root, absolute);
  return relative !== '' && !relative.startsWith('..') && !path.isAbsolute(relative)
    ? relative.split(path.sep).join('/')
    : absolute.split(path.sep).join('/');
}

function errorDiagnostic(error) {
  return {
    code:
      typeof error?.code === 'string' && /^[A-Z][A-Z0-9_]*$/.test(error.code)
        ? error.code
        : 'STYLE_PROJECT',
    severity: 'error',
    file: typeof error?.file === 'string' ? error.file : null,
    line: null,
    column: null,
    endLine: null,
    endColumn: null,
    symbol: null,
    module: null,
    artifactPath: null,
    dependencyChain: [],
    message: error instanceof Error ? error.message : String(error),
    help: typeof error?.help === 'string' ? error.help : null,
  };
}

function normalizedDiagnostic(diagnostic) {
  return {
    ...diagnostic,
    help: typeof diagnostic.help === 'string' ? diagnostic.help : null,
  };
}

function baseReport(command) {
  return {
    schemaVersion: 1,
    command,
    toolingVersion,
    passed: false,
    dryRun: false,
    changedFiles: [],
    removedFiles: [],
    diagnostics: [],
    extraction: null,
  };
}

function resolvedProject(root, manifest, styleConfig, bundles = []) {
  return {
    root,
    extractorPackage: manifest.extractorPackage,
    mappingsPackage: styleConfig?.mappingsPackage ?? null,
    cacheDirectory: styleConfig?.cacheDirectory ?? null,
    dependencyBundles: bundles.map((filename) => projectFilename(root, filename)),
    outputs:
      styleConfig === null
        ? null
        : Object.fromEntries(
            outputKinds.map((kind) => [kind, styleConfig.outputs[kind].split(path.sep).join('/')]),
          ),
  };
}

function extractionDetails(root, manifest, outcome, mode) {
  const styleConfig = outcome.styleConfig;
  return {
    mode,
    profile: outcome.profile ?? (mode === 'watch' ? 'debug' : 'release'),
    stage: outcome.stage ?? 'toolchain',
    executed: outcome.executed ?? false,
    skipped: outcome.skipped ?? false,
    cacheStatus: outcome.cacheStatus ?? 'unknown',
    reasons: [...new Set(outcome.reasons ?? [])],
    identity: outcome.identity ?? null,
    resolved: resolvedProject(root, manifest, styleConfig, outcome.bundles ?? []),
    outputs:
      outcome.changedOutputs ??
      (styleConfig === null
        ? []
        : outputKinds.map((kind) => ({
            kind,
            path: styleConfig.outputs[kind].split(path.sep).join('/'),
            changed: false,
          }))),
    timingsMs: outcome.timings ?? { buildMs: 0, extractMs: 0, totalMs: 0 },
  };
}

function reportFromOutcome(command, root, manifest, outcome) {
  const report = baseReport(command);
  report.diagnostics = (outcome.diagnostics ?? []).map(normalizedDiagnostic);
  report.extraction = extractionDetails(root, manifest, outcome, command);
  report.changedFiles =
    command === 'check'
      ? []
      : report.extraction.outputs
          .filter((output) => output.changed)
          .map((output) => output.path)
          .sort((left, right) => left.localeCompare(right));
  report.passed = outcome.ok && !report.diagnostics.some((item) => item.severity === 'error');
  return report;
}

function reportFromError(command, error) {
  const report = baseReport(command);
  report.diagnostics = [errorDiagnostic(error)];
  return report;
}

function projectRoot(options) {
  const root = path.resolve(options.root ?? process.cwd());
  if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) {
    const error = new Error(`Project root is not a directory: ${root}`);
    error.code = 'STYLE_PROJECT_ROOT';
    throw error;
  }
  return root;
}

function prepareProject(options) {
  const root = projectRoot(options);
  moonProject(root);
  return { root, manifest: loadCompatibleProjectManifest(root) };
}

export async function runProjectExtraction(command, options = {}) {
  let prepared;
  try {
    prepared = prepareProject(options);
  } catch (error) {
    return reportFromError(command, error);
  }
  const { root, manifest } = prepared;
  const runner = createExtractorRunner({ extractorPackage: manifest.extractorPackage });
  const outcome = await runner(root, {
    force: true,
    profile: 'release',
    check: command === 'check',
    mode: command,
    reasons: ['manual'],
  });
  return reportFromOutcome(command, root, manifest, outcome);
}

function hasSourceSpan(diagnostic) {
  return (
    diagnostic.file !== null &&
    [diagnostic.line, diagnostic.column, diagnostic.endLine, diagnostic.endColumn].every(
      (value) => Number.isInteger(value) && value > 0,
    )
  );
}

function diagnosticLine(diagnostic, root) {
  if (hasSourceSpan(diagnostic)) return formatProblem(diagnostic, root);
  const location = diagnostic.file === null ? '' : ` (${projectFilename(root, diagnostic.file)})`;
  const artifact =
    diagnostic.artifactPath == null ? '' : ` [${projectFilename(root, diagnostic.artifactPath)}]`;
  return `${diagnostic.severity} ${diagnostic.code}${location}: ${diagnostic.message}${artifact}`;
}

function extractionSummary(extraction) {
  const changed = extraction.outputs.filter((output) => output.changed).length;
  return [
    `profile ${extraction.profile}`,
    `cache ${extraction.cacheStatus}`,
    `${extraction.timingsMs.totalMs.toFixed(3)} ms`,
    `changed ${changed}/${extraction.outputs.length}`,
  ].join(' · ');
}

export function renderExtractionReport(report, { json = false, verbose = false } = {}) {
  if (json) return `${JSON.stringify(report, null, 2)}\n`;
  const root = report.extraction?.resolved.root ?? process.cwd();
  const lines = [`moonstyle ${report.command}: ${report.passed ? 'passed' : 'failed'}`];
  for (const filename of report.changedFiles) lines.push(`changed ${filename}`);
  for (const diagnostic of report.diagnostics) {
    lines.push(diagnosticLine(diagnostic, root));
    if (diagnostic.help !== null) lines.push(`  help: ${diagnostic.help}`);
  }
  if (report.extraction !== null) {
    lines.push(extractionSummary(report.extraction));
    if (verbose) {
      const { resolved } = report.extraction;
      lines.push(`  root: ${resolved.root}`);
      lines.push(`  extractor: ${resolved.extractorPackage}`);
      lines.push(`  mappings package: ${resolved.mappingsPackage ?? '(unavailable)'}`);
      lines.push(`  cache directory: ${resolved.cacheDirectory ?? '(unavailable)'}`);
      lines.push(`  identity: ${report.extraction.identity ?? '(unavailable)'}`);
      lines.push(
        `  reasons: ${report.extraction.reasons.length === 0 ? '(none)' : report.extraction.reasons.join(', ')}`,
      );
      for (const bundle of resolved.dependencyBundles) lines.push(`  dependency: ${bundle}`);
      for (const output of report.extraction.outputs) {
        lines.push(
          `  output ${output.kind}: ${output.path} (${output.changed ? 'changed' : 'unchanged'})`,
        );
      }
    }
  }
  return `${lines.join('\n')}\n`;
}

export function classifyWatchReason(filename, root, styleConfig) {
  const absolute = path.isAbsolute(filename) ? filename : path.resolve(root, filename);
  if (absolute === path.resolve(root, '.moonstyle.json')) return 'project-change';
  if (absolute === path.resolve(root, 'style.config.json')) return 'config-change';
  if (
    styleConfig !== null &&
    absolute.endsWith('.bundle.json') &&
    styleConfig.dependencyRoots.some((directory) => {
      const relative = path.relative(path.resolve(root, directory), absolute);
      return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));
    })
  ) {
    return 'dependency-change';
  }
  return 'source-change';
}

function watchStartEvent(root, manifest, styleConfig) {
  let bundles = [];
  if (styleConfig !== null) {
    try {
      bundles = dependencyBundleFiles(root, styleConfig);
    } catch {
      // The first extraction cycle reports unreadable dependency roots.
    }
  }
  return {
    schemaVersion: 1,
    event: 'watch-start',
    command: 'watch',
    toolingVersion,
    root,
    resolved: resolvedProject(root, manifest, styleConfig, bundles),
  };
}

function watchCycleEvent(sequence, report) {
  return {
    ...report,
    event: 'watch-cycle',
    sequence,
  };
}

function watchStopEvent(sequence, signal, passed) {
  return {
    schemaVersion: 1,
    event: 'watch-stop',
    command: 'watch',
    toolingVersion,
    sequence,
    signal,
    passed,
  };
}

function failedWatchOutcome(error, reasons) {
  return {
    ok: false,
    diagnostics: [errorDiagnostic(error)],
    styleConfig: null,
    profile: 'debug',
    mode: 'watch',
    reasons,
    stage: 'project',
    executed: false,
    skipped: false,
    cacheStatus: 'unknown',
    changedOutputs: [],
    timings: { buildMs: 0, extractMs: 0, totalMs: 0 },
  };
}

export async function watchProject(options = {}, { emit = () => {} } = {}) {
  let prepared;
  try {
    prepared = prepareProject(options);
  } catch (error) {
    const root = path.resolve(options.root ?? process.cwd());
    const report = reportFromError('watch', error);
    emit({
      schemaVersion: 1,
      event: 'watch-start',
      command: 'watch',
      toolingVersion,
      root,
      resolved: null,
    });
    emit(watchCycleEvent(1, report));
    emit(watchStopEvent(1, 'startup-error', false));
    return 1;
  }

  const { root } = prepared;
  let manifest = prepared.manifest;
  let runner = createExtractorRunner({ extractorPackage: manifest.extractorPackage });
  let styleConfig = null;
  try {
    styleConfig = loadStyleConfig(root);
  } catch {
    // The first cycle reports invalid configuration and keeps watching for a fix.
  }

  let watcher;
  let watchPaths = [root];
  const workspaceWatchers = new Map();
  try {
    watcher = fs.watch(root, { recursive: true });
  } catch (error) {
    const report = reportFromOutcome(
      'watch',
      root,
      manifest,
      failedWatchOutcome(error, ['initial']),
    );
    emit(watchStartEvent(root, manifest, styleConfig));
    emit(watchCycleEvent(1, report));
    emit(watchStopEvent(1, 'watch-error', false));
    return 1;
  }

  let sequence = 0;
  let stopped = false;
  let debounceTimer = null;
  let pendingForce = false;
  const pendingReasons = new Set();
  let resolveDone;
  const done = new Promise((resolve) => {
    resolveDone = resolve;
  });

  const runCycle = async (request) => {
    if (request.reasons.includes('project-change')) {
      try {
        const nextManifest = loadCompatibleProjectManifest(root);
        if (nextManifest.extractorPackage !== manifest.extractorPackage) {
          runner = createExtractorRunner({ extractorPackage: nextManifest.extractorPackage });
        }
        manifest = nextManifest;
      } catch (error) {
        const report = reportFromOutcome(
          'watch',
          root,
          manifest,
          failedWatchOutcome(error, request.reasons),
        );
        sequence += 1;
        if (!stopped) emit(watchCycleEvent(sequence, report));
        return report;
      }
    }

    if (request.reasons.includes('config-change')) {
      try {
        // Adopt valid output/cache paths before extraction starts so changes
        // emitted by that extraction are filtered against the new config.
        styleConfig = loadStyleConfig(root);
      } catch {
        // The shared runner reports the invalid config; retain the last valid
        // paths so unrelated generated files remain excluded while recovering.
      }
    }

    const outcome = await runner(root, {
      force: request.force,
      profile: 'debug',
      devtools: false,
      check: false,
      mode: 'watch',
      reasons: request.reasons,
    });
    if (outcome.styleConfig !== null) styleConfig = outcome.styleConfig;
    if (!stopped) syncWorkspaceWatchers();
    const report = reportFromOutcome('watch', root, manifest, outcome);
    sequence += 1;
    if (!stopped) emit(watchCycleEvent(sequence, report));
    return report;
  };

  const schedule = createExtractionQueue(runCycle);

  const stop = (signal, exitCode) => {
    if (stopped) return;
    stopped = true;
    if (debounceTimer !== null) clearTimeout(debounceTimer);
    watcher.close();
    for (const additional of workspaceWatchers.values()) additional.close();
    process.off('SIGINT', onSigint);
    process.off('SIGTERM', onSigterm);
    emit(watchStopEvent(sequence, signal, exitCode === 0));
    resolveDone(exitCode);
  };

  const fatal = (error) => {
    const report = reportFromOutcome(
      'watch',
      root,
      manifest,
      failedWatchOutcome(error, ['watch-error']),
    );
    sequence += 1;
    if (!stopped) emit(watchCycleEvent(sequence, report));
    stop('watch-error', 1);
  };

  const flush = () => {
    debounceTimer = null;
    const reasons = [...pendingReasons];
    const force = pendingForce;
    pendingReasons.clear();
    pendingForce = false;
    if (reasons.length === 0 || stopped) return;
    schedule({ force, reasons }).catch(fatal);
  };

  const onChange = (absolute) => {
    if (stopped) return;
    if (absolute === null) {
      pendingReasons.add('source-change');
      pendingForce = true;
    } else {
      if (!isRelevantFile(absolute, root, styleConfig, watchPaths)) return;
      const reason = classifyWatchReason(absolute, root, styleConfig);
      pendingReasons.add(reason);
      if (reason === 'project-change' || reason === 'config-change') pendingForce = true;
    }
    if (debounceTimer !== null) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(flush, 50);
  };
  const syncWorkspaceWatchers = () => {
    watchPaths = workspaceWatchPaths(root);
    const outside = watchPaths.filter((filename) => {
      const relative = path.relative(root, filename);
      return relative.startsWith('..') || path.isAbsolute(relative);
    });
    for (const [filename, additional] of workspaceWatchers) {
      if (!outside.includes(filename)) {
        additional.close();
        workspaceWatchers.delete(filename);
      }
    }
    for (const filename of outside) {
      if (workspaceWatchers.has(filename)) continue;
      const directory = fs.statSync(filename).isDirectory();
      const watchDirectory = directory ? filename : path.dirname(filename);
      const additional = fs.watch(watchDirectory, { recursive: directory });
      additional.on('change', (_eventType, changed) => {
        onChange(changed === null ? null : path.resolve(watchDirectory, String(changed)));
      });
      additional.on('error', fatal);
      workspaceWatchers.set(filename, additional);
    }
  };
  watcher.on('change', (_eventType, filename) => {
    onChange(filename === null ? null : path.resolve(root, String(filename)));
  });
  watcher.on('error', fatal);

  const onSigint = () => stop('SIGINT', 0);
  const onSigterm = () => stop('SIGTERM', 0);
  process.once('SIGINT', onSigint);
  process.once('SIGTERM', onSigterm);

  emit(watchStartEvent(root, manifest, styleConfig));
  await schedule({ force: true, reasons: ['initial'] });
  return done;
}

export function renderWatchEvent(event, { json = false, verbose = false } = {}) {
  if (json) return `${JSON.stringify(event)}\n`;
  if (event.event === 'watch-start') {
    return `${watchReadyMarker} ${event.root}\n`;
  }
  if (event.event === 'watch-stop') {
    return `${watchStopMarker} ${event.signal}\n`;
  }
  const report = { ...event };
  delete report.event;
  delete report.sequence;
  return [
    diagnosticStartMarker,
    renderExtractionReport(report, { verbose }).trimEnd(),
    diagnosticEndMarker,
    '',
  ].join('\n');
}
