import fs from 'node:fs';
import path from 'node:path';
import { workspaceWatchPaths } from './workspace.mjs';
import {
  createCssSourceMap,
  createExtractionQueue,
  createExtractorRunner,
  debugStatusEvent,
  debugUpdateEvent,
  diagnosticEndMarker,
  diagnosticStartMarker,
  errorMessage,
  formatProblem,
  inspectorVirtualId,
  isRelevantFile,
  loadStyleConfig,
  resolvedInspectorVirtualId,
  resolvedVirtualId,
  toolchainDiagnostic,
  virtualId,
} from './extraction.mjs';

export {
  toolingProtocolVersion,
  diagnosticStartMarker,
  diagnosticEndMarker,
  loadStyleConfig,
  parseDiagnostics,
  parseMoonBuildOutput,
  parseDebugManifest,
  createCssSourceMap,
  formatProblem,
  extractionArguments,
  extractorBuildArguments,
  buildExtractor,
  dependencyBundleFiles,
  computeExtractionIdentity,
  createExtractorRunner,
  runExtractor,
  createExtractionQueue,
  isRelevantFile,
} from './extraction.mjs';

function finishDiagnosticCycle(outcome, root) {
  for (const diagnostic of outcome.diagnostics) {
    const problem = formatProblem(diagnostic, root);
    process.stdout.write(
      `${problem ?? `[moonstyle] ${diagnostic.severity} ${diagnostic.code}: ${diagnostic.message}`}\n`,
    );
  }
  process.stdout.write(`${diagnosticEndMarker}\n`);
}

function viteError(outcome, root) {
  const diagnostic =
    outcome.diagnostics.find((candidate) => candidate.severity === 'error') ??
    outcome.diagnostics[0];
  const problems = outcome.diagnostics
    .map((candidate) => formatProblem(candidate, root))
    .filter(Boolean);
  const error = {
    message: `${diagnostic.code}: ${diagnostic.message}`,
    plugin: 'moonstyle',
    stack: problems.length === 0 ? undefined : problems.join('\n'),
  };
  if (diagnostic.file !== null) {
    const filename = path.isAbsolute(diagnostic.file)
      ? diagnostic.file
      : path.resolve(root, diagnostic.file);
    error.id = filename;
    error.loc = {
      file: filename,
      line: diagnostic.line,
      column: diagnostic.column,
    };
  }
  return error;
}

function sendError(server, outcome, root) {
  server?.ws?.send({ type: 'error', err: viteError(outcome, root) });
}

function inspectorRuntimeUrl() {
  const filename = path
    .resolve(import.meta.dirname, 'moonstyle-inspector-client.mjs')
    .split(path.sep)
    .join('/');
  return `/@fs/${filename}`;
}

function inspectorModuleSource(manifest, status, base) {
  return `
import { mountMoonStyleInspector } from ${JSON.stringify(inspectorRuntimeUrl())};

const inspector = mountMoonStyleInspector({
  manifest: ${JSON.stringify(manifest)},
  status: ${JSON.stringify(status)},
  openSource(source) {
    const file = source.absoluteFile + ':' + source.line + ':' + source.column;
    const url = new URL(${JSON.stringify(`${base}__open-in-editor`)} + '?file=' + encodeURIComponent(file), window.location.origin);
    fetch(url).catch(() => {});
  },
});

if (import.meta.hot) {
  import.meta.hot.on(${JSON.stringify(debugUpdateEvent)}, (payload) => {
    inspector.updateManifest(payload.manifest);
    inspector.setStatus(payload.status);
  });
  import.meta.hot.on(${JSON.stringify(debugStatusEvent)}, (payload) => {
    inspector.setStatus(payload.status);
  });
  import.meta.hot.dispose(() => inspector.dispose());
}
`;
}

export default function moonStyle(options = {}) {
  let root = process.cwd();
  let command = 'serve';
  let base = '/';
  let server;
  let styleConfig;
  let watchPaths = [];
  let latestFailure = null;
  let latestDebugManifest = null;
  let latestDebugStatus = 'unavailable';
  let devtoolsEnabled = options.devtools !== false;
  const runPipeline = createExtractorRunner(options);

  const invalidateDebugModules = () => {
    for (const id of [resolvedVirtualId, resolvedInspectorVirtualId]) {
      const module = server?.moduleGraph?.getModuleById(id);
      if (module) server.moduleGraph.invalidateModule?.(module);
    }
  };

  const sendDebugStatus = (status) => {
    if (!devtoolsEnabled) return;
    latestDebugStatus = status;
    server?.ws?.send({ type: 'custom', event: debugStatusEvent, data: { status } });
  };

  const publishDebugOutcome = (outcome) => {
    if (!devtoolsEnabled) return;
    invalidateDebugModules();
    if (outcome.ok && outcome.debugManifest !== null && outcome.debugManifest !== undefined) {
      latestDebugManifest = outcome.debugManifest;
      latestDebugStatus = 'ready';
      server?.ws?.send({
        type: 'custom',
        event: debugUpdateEvent,
        data: { manifest: latestDebugManifest, status: latestDebugStatus },
      });
    } else {
      sendDebugStatus(latestDebugManifest === null ? 'unavailable' : 'stale');
    }
  };

  const extract = async (request) => {
    process.stdout.write(`${diagnosticStartMarker}\n`);
    let outcome;
    try {
      outcome = await runPipeline(root, {
        ...request,
        profile: command === 'build' ? 'release' : 'debug',
        devtools: devtoolsEnabled,
      });
    } catch (error) {
      outcome = {
        ok: false,
        diagnostics: [toolchainDiagnostic(errorMessage(error))],
        styleConfig: null,
        stage: 'toolchain',
        executed: false,
        skipped: false,
        cssChanged: false,
      };
    }
    finishDiagnosticCycle(outcome, root);
    if (outcome.styleConfig !== null) styleConfig = outcome.styleConfig;
    watchPaths = workspaceWatchPaths(root);
    server?.watcher?.add?.(watchPaths);
    publishDebugOutcome(outcome);
    if (outcome.ok) {
      const recovered = latestFailure !== null;
      latestFailure = null;
      return { ...outcome, recovered };
    }
    latestFailure = outcome;
    return { ...outcome, recovered: false };
  };
  const scheduleExtraction = createExtractionQueue(extract);

  return {
    name: 'moonstyle',
    enforce: 'pre',
    config(_config, environment) {
      if (environment.command === 'serve' && options.devtools !== false) {
        return { css: { devSourcemap: true } };
      }
    },
    configResolved(config) {
      root = config.root;
      watchPaths = workspaceWatchPaths(root);
      command = config.command ?? command;
      base = config.base ?? base;
      devtoolsEnabled = command === 'serve' && options.devtools !== false;
    },
    configureServer(configuredServer) {
      server = configuredServer;
      server.ws.on?.('connection', () => {
        if (latestFailure !== null) sendError(server, latestFailure, root);
      });
    },
    async buildStart() {
      const outcome = await scheduleExtraction({ force: true, reasons: ['build-start'] });
      this.addWatchFile(path.resolve(root, 'style.config.json'));
      for (const filename of watchPaths) this.addWatchFile(filename);
      if (styleConfig !== undefined) {
        for (const directory of styleConfig.dependencyRoots) {
          this.addWatchFile(path.resolve(root, directory));
        }
      }
      if (!outcome.ok) {
        if (command === 'build') this.error(viteError(outcome, root));
        else sendError(server, outcome, root);
      }
    },
    resolveId(id) {
      if (id === virtualId) return resolvedVirtualId;
      if (devtoolsEnabled && id === inspectorVirtualId) return resolvedInspectorVirtualId;
      return null;
    },
    load(id) {
      if (id === resolvedInspectorVirtualId && devtoolsEnabled) {
        return inspectorModuleSource(latestDebugManifest, latestDebugStatus, base);
      }
      if (id !== resolvedVirtualId) return null;
      if (styleConfig === undefined) {
        try {
          styleConfig = loadStyleConfig(root);
        } catch {
          return '';
        }
      }
      const css = path.resolve(root, styleConfig.outputs.css);
      if (!fs.existsSync(css) && latestFailure !== null) return '';
      this.addWatchFile(css);
      const code = fs.readFileSync(css, 'utf8');
      if (!devtoolsEnabled || latestDebugManifest === null) return code;
      const map = createCssSourceMap(root, code, latestDebugManifest);
      return map === null ? code : { code, map };
    },
    transformIndexHtml() {
      if (!devtoolsEnabled) return;
      return [
        {
          tag: 'script',
          attrs: {
            type: 'module',
            src: `${base}@id/__x00__${inspectorVirtualId}`,
          },
          injectTo: 'body',
        },
      ];
    },
    async handleHotUpdate(context) {
      if (!isRelevantFile(context.file, root, styleConfig, watchPaths)) return;
      sendDebugStatus('rebuilding');
      const forceReload = context.file === path.resolve(root, 'style.config.json');
      const recoveryRequiresExtraction =
        ['build', 'config', 'inputs'].includes(latestFailure?.stage) ||
        latestFailure?.diagnostics.some((diagnostic) => diagnostic.code === 'STYLE_TOOLCHAIN');
      const outcome = await scheduleExtraction({
        force: forceReload || recoveryRequiresExtraction,
        reasons: [forceReload ? 'config-change' : 'source-change'],
      });
      if (!outcome.ok) {
        sendError(context.server, outcome, root);
        return [];
      }
      if (forceReload && styleConfig !== undefined) {
        for (const directory of styleConfig.dependencyRoots) {
          context.server.watcher?.add?.(path.resolve(root, directory));
        }
      }
      if (outcome.recovered || forceReload) {
        context.server.ws.send({ type: 'full-reload' });
        return [];
      }
      if (outcome.skipped || (!outcome.cssChanged && !outcome.debugChanged)) return;
      const cssModule = context.server.moduleGraph?.getModuleById(resolvedVirtualId);
      if (cssModule) return [...new Set([...(context.modules ?? []), cssModule])];
    },
  };
}
