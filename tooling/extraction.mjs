import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

export const virtualId = 'virtual:moonstyle.css';
export const resolvedVirtualId = `\0${virtualId}`;
export const inspectorVirtualId = 'virtual:moonstyle-inspector';
export const resolvedInspectorVirtualId = `\0${inspectorVirtualId}`;
const debugManifestBasename = 'vite-debug-manifest.json';
export const debugUpdateEvent = 'moonstyle:debug-update';
export const debugStatusEvent = 'moonstyle:debug-status';
const ansiColorPattern = new RegExp(`${String.fromCodePoint(27)}\\[[0-9;]*m`, 'g');
const extractionIdentityVersion = 'lampclaw-vite-extractor-v2';
export const toolingProtocolVersion = 1;
const moonManifestNames = new Set([
  'moon.mod',
  'moon.mod.json',
  'moon.mod.lock',
  'moon.pkg',
  'moon.work',
  'moon.work.json',
]);
const ignoredBuildDirectories = new Set([
  '.cache',
  '.git',
  '.generated',
  '.mooncakes',
  '_build',
  'dist',
  'node_modules',
]);

export const diagnosticStartMarker = '[moonstyle] check-start';
export const diagnosticEndMarker = '[moonstyle] check-end';

function exactKeys(value, expected, label) {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`${label} must be an object`);
  }
  const actual = Object.keys(value).sort((left, right) => left.localeCompare(right));
  const wanted = [...expected].sort((left, right) => left.localeCompare(right));
  if (JSON.stringify(actual) !== JSON.stringify(wanted)) {
    throw new Error(`${label} must contain exactly: ${wanted.join(', ')}`);
  }
}

function projectPath(root, value, label) {
  if (typeof value !== 'string' || value.trim() === '' || path.isAbsolute(value)) {
    throw new Error(`${label} must be a non-empty project-relative path`);
  }
  const relative = path.relative(root, path.resolve(root, value));
  if (relative.startsWith('..') || path.isAbsolute(relative)) {
    throw new Error(`${label} must stay inside the project root`);
  }
  return value;
}

export function loadStyleConfig(root) {
  const filename = path.resolve(root, 'style.config.json');
  const config = JSON.parse(fs.readFileSync(filename, 'utf8'));
  exactKeys(
    config,
    ['cacheDirectory', 'dependencyRoots', 'mappingsPackage', 'outputs', 'schemaVersion'],
    'style.config.json',
  );
  if (config.schemaVersion !== 1) {
    throw new Error('style.config.json schemaVersion must be 1');
  }
  const packageSegments =
    typeof config.mappingsPackage === 'string' ? config.mappingsPackage.split('/') : [];
  if (
    packageSegments.length === 0 ||
    packageSegments.some(
      (segment) =>
        segment === '' ||
        segment === '.' ||
        segment === '..' ||
        !/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(segment),
    )
  ) {
    throw new Error('style.config.json mappingsPackage is invalid');
  }
  exactKeys(
    config.outputs,
    ['bundle', 'css', 'mappings', 'mappingsManifest'],
    'style.config.json outputs',
  );
  const outputs = Object.fromEntries(
    Object.entries(config.outputs).map(([key, value]) => [
      key,
      projectPath(root, value, `outputs.${key}`),
    ]),
  );
  if (!Array.isArray(config.dependencyRoots)) {
    throw new Error('style.config.json dependencyRoots must be an array');
  }
  const dependencyRoots = config.dependencyRoots.map((value, index) =>
    projectPath(root, value, `dependencyRoots[${index}]`),
  );
  if (new Set(dependencyRoots).size !== dependencyRoots.length) {
    throw new Error('style.config.json dependencyRoots must be unique');
  }
  return {
    ...config,
    outputs,
    dependencyRoots,
    cacheDirectory: projectPath(root, config.cacheDirectory, 'cacheDirectory'),
  };
}

function cleanMessage(value) {
  return String(value).replaceAll(ansiColorPattern, '').replaceAll(/\s+/g, ' ').trim();
}

export function toolchainDiagnostic(message) {
  return {
    code: 'STYLE_TOOLCHAIN',
    severity: 'error',
    message: cleanMessage(message) || 'The style extractor failed without a diagnostic.',
    file: null,
    line: null,
    column: null,
    endLine: null,
    endColumn: null,
    symbol: null,
    module: null,
    artifactPath: null,
    dependencyChain: [],
  };
}

function debugManifestDiagnostic(message) {
  return {
    ...toolchainDiagnostic(message),
    code: 'STYLE_DEBUG_MANIFEST',
    severity: 'warning',
  };
}

export function errorMessage(error) {
  return error instanceof Error ? error.message : String(error);
}

function validPosition(value) {
  return Number.isInteger(value) && value > 0;
}

function validateDiagnostic(value, index) {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`diagnostics[${index}] must be an object`);
  }
  if (typeof value.code !== 'string' || !/^[A-Z][A-Z0-9_]*$/.test(value.code)) {
    throw new Error(`diagnostics[${index}].code is invalid`);
  }
  if (value.severity !== 'error' && value.severity !== 'warning') {
    throw new Error(`diagnostics[${index}].severity is invalid`);
  }
  if (typeof value.message !== 'string' || value.message.trim() === '') {
    throw new Error(`diagnostics[${index}].message is invalid`);
  }
  if (value.file !== null && typeof value.file !== 'string') {
    throw new Error(`diagnostics[${index}].file is invalid`);
  }
  if (value.file === null) {
    for (const key of ['line', 'column', 'endLine', 'endColumn']) {
      if (value[key] !== null) {
        throw new Error(`diagnostics[${index}].${key} must be null without a file`);
      }
    }
  } else {
    for (const key of ['line', 'column', 'endLine', 'endColumn']) {
      if (!validPosition(value[key])) {
        throw new Error(`diagnostics[${index}].${key} is invalid`);
      }
    }
  }
  return { ...value, message: cleanMessage(value.message) };
}

export function parseDiagnostics(output) {
  const source = String(output).trim();
  const candidates = source === '' ? [] : [source];
  for (const line of source.split(/\r?\n/).toReversed()) {
    const candidate = line.trim();
    if (candidate.startsWith('[') && candidate.endsWith(']') && candidate !== source) {
      candidates.push(candidate);
    }
  }
  let parseError;
  for (const candidate of candidates) {
    try {
      const parsed = JSON.parse(candidate);
      if (!Array.isArray(parsed)) throw new Error('diagnostics must be an array');
      return parsed.map(validateDiagnostic);
    } catch (error) {
      parseError = error;
    }
  }
  throw parseError ?? new Error('style extractor returned no JSON diagnostics');
}

function jsonLines(output) {
  const values = [];
  for (const line of String(output).split(/\r?\n/)) {
    const candidate = line.trim();
    if (!candidate.startsWith('{') || !candidate.endsWith('}')) continue;
    try {
      values.push(JSON.parse(candidate));
    } catch {
      // Moon may interleave ordinary build output with its JSON records.
    }
  }
  return values;
}

function moonLocation(value) {
  if (typeof value !== 'string') return null;
  const match = value.match(/^(\d+):(\d+)-(\d+):(\d+)$/);
  if (match === null) return null;
  const [, line, column, endLine, endColumn] = match.map(Number);
  if (![line, column, endLine, endColumn].every(validPosition)) return null;
  return { line, column, endLine, endColumn };
}

function moonDiagnostic(value, index) {
  const location = moonLocation(value.loc);
  const file = typeof value.path === 'string' && location !== null ? value.path : null;
  const rawCode = String(value.error_code ?? '')
    .replaceAll(/[^0-9A-Z_]/gi, '')
    .toUpperCase();
  return validateDiagnostic(
    {
      code: rawCode === '' ? 'MOON_BUILD' : `MOON${rawCode}`,
      severity: value.level === 'warning' ? 'warning' : 'error',
      message: typeof value.message === 'string' ? value.message : 'Moon build failed.',
      file,
      line: file === null ? null : location.line,
      column: file === null ? null : location.column,
      endLine: file === null ? null : location.endLine,
      endColumn: file === null ? null : location.endColumn,
      symbol: null,
      module: null,
      artifactPath: null,
      dependencyChain: [],
    },
    index,
  );
}

export function parseMoonBuildOutput(stdout, stderr = '') {
  const records = [...jsonLines(stdout), ...jsonLines(stderr)];
  const diagnostics = records
    .filter((value) => value?.$message_type === 'diagnostic')
    .map(moonDiagnostic);
  const artifactPaths = records.flatMap((value) =>
    Array.isArray(value?.artifacts_path)
      ? value.artifacts_path.filter((filename) => typeof filename === 'string')
      : [],
  );
  return { artifactPaths, diagnostics };
}

function sourceFilename(root, filename) {
  const absolute = path.isAbsolute(filename) ? filename : path.resolve(root, filename);
  const relative = path.relative(root, absolute);
  if (relative !== '' && !relative.startsWith('..') && !path.isAbsolute(relative)) {
    return relative.split(path.sep).join('/');
  }
  return absolute.split(path.sep).join('/');
}

function sha256(value) {
  return `sha256:${createHash('sha256').update(value).digest('hex')}`;
}

function validateDebugSource(value, label, root) {
  if (value === null) return null;
  exactKeys(value, ['column', 'endColumn', 'endLine', 'file', 'line', 'symbol'], label);
  if (typeof value.file !== 'string' || value.file.trim() === '') {
    throw new Error(`${label}.file is invalid`);
  }
  for (const key of ['line', 'column', 'endLine', 'endColumn']) {
    if (!validPosition(value[key])) throw new Error(`${label}.${key} is invalid`);
  }
  if (
    value.endLine < value.line ||
    (value.endLine === value.line && value.endColumn < value.column)
  ) {
    throw new Error(`${label} ends before it starts`);
  }
  if (value.symbol !== null && typeof value.symbol !== 'string') {
    throw new Error(`${label}.symbol is invalid`);
  }
  const absoluteFile = path.isAbsolute(value.file)
    ? path.normalize(value.file)
    : path.resolve(root, value.file);
  if (!inside(root, absoluteFile)) {
    throw new Error(`${label}.file must stay inside the project root`);
  }
  return {
    ...value,
    file: sourceFilename(root, absoluteFile),
    absoluteFile,
  };
}

function validateDebugOrigin(value, label, root) {
  exactKeys(value, ['exportName', 'module', 'namespace', 'source'], label);
  if (typeof value.module !== 'string' || value.module.trim() === '') {
    throw new Error(`${label}.module is invalid`);
  }
  for (const key of ['exportName', 'namespace']) {
    if (value[key] !== null && typeof value[key] !== 'string') {
      throw new Error(`${label}.${key} is invalid`);
    }
  }
  return { ...value, source: validateDebugSource(value.source, `${label}.source`, root) };
}

function validateDebugOrigins(value, label, root) {
  if (!Array.isArray(value)) throw new Error(`${label} must be an array`);
  return value.map((origin, index) => validateDebugOrigin(origin, `${label}[${index}]`, root));
}

function validateDebugRule(value, index, root, css) {
  const label = `debug manifest rules[${index}]`;
  exactKeys(
    value,
    ['className', 'css', 'ltr', 'order', 'origins', 'priority100', 'property', 'rtl'],
    label,
  );
  for (const key of ['className', 'css', 'ltr', 'property']) {
    if (typeof value[key] !== 'string' || value[key] === '') {
      throw new Error(`${label}.${key} is invalid`);
    }
  }
  if (value.rtl !== null && typeof value.rtl !== 'string') {
    throw new Error(`${label}.rtl is invalid`);
  }
  if (!Number.isSafeInteger(value.priority100) || !Number.isSafeInteger(value.order)) {
    throw new Error(`${label} priority or order is invalid`);
  }
  if (value.order !== index) throw new Error(`${label}.order must equal its array index`);
  if (!css.includes(value.css)) throw new Error(`${label}.css is absent from generated CSS`);
  return {
    ...value,
    origins: validateDebugOrigins(value.origins, `${label}.origins`, root),
  };
}

function validateDebugGlobal(value, index, root, css) {
  const label = `debug manifest globals[${index}]`;
  exactKeys(value, ['css', 'digest', 'kind', 'name', 'order', 'origins'], label);
  for (const key of ['css', 'digest', 'kind', 'name']) {
    if (typeof value[key] !== 'string' || value[key] === '') {
      throw new Error(`${label}.${key} is invalid`);
    }
  }
  if (!Number.isSafeInteger(value.order) || value.order !== index) {
    throw new Error(`${label}.order must equal its array index`);
  }
  if (!css.includes(value.css)) throw new Error(`${label}.css is absent from generated CSS`);
  return {
    ...value,
    origins: validateDebugOrigins(value.origins, `${label}.origins`, root),
  };
}

export function parseDebugManifest(input, root, css, expectedSemanticDigest = null) {
  const value = JSON.parse(input);
  exactKeys(
    value,
    ['cssDigest', 'globals', 'module', 'rules', 'schemaVersion', 'semanticDigest'],
    'debug manifest',
  );
  if (value.schemaVersion !== 1) throw new Error('debug manifest schemaVersion must be 1');
  if (typeof value.module !== 'string' || value.module.trim() === '') {
    throw new Error('debug manifest module is invalid');
  }
  if (!/^sha256:[0-9a-f]{64}$/.test(value.semanticDigest)) {
    throw new Error('debug manifest semanticDigest is invalid');
  }
  if (expectedSemanticDigest !== null && value.semanticDigest !== expectedSemanticDigest) {
    throw new Error('debug manifest semanticDigest does not match the generated bundle');
  }
  if (value.cssDigest !== sha256(css)) {
    throw new Error('debug manifest cssDigest does not match generated CSS');
  }
  if (!Array.isArray(value.rules) || !Array.isArray(value.globals)) {
    throw new Error('debug manifest rules and globals must be arrays');
  }
  const rules = value.rules.map((rule, index) => validateDebugRule(rule, index, root, css));
  if (new Set(rules.map((rule) => rule.className)).size !== rules.length) {
    throw new Error('debug manifest className values must be unique');
  }
  return {
    ...value,
    rules,
    globals: value.globals.map((global, index) => validateDebugGlobal(global, index, root, css)),
  };
}

function debugManifestFilename(root, styleConfig) {
  return path.resolve(root, styleConfig.cacheDirectory, debugManifestBasename);
}

const sourceMapBase64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function encodeVlq(value) {
  let remaining = value < 0 ? (-value << 1) | 1 : value << 1;
  let output = '';
  do {
    let digit = remaining & 31;
    remaining >>>= 5;
    if (remaining > 0) digit |= 32;
    output += sourceMapBase64[digit];
  } while (remaining > 0);
  return output;
}

function sourceMapMappings(segments, lineCount) {
  const lines = Array.from({ length: lineCount }, () => []);
  for (const segment of segments) lines[segment.generatedLine].push(segment);
  let previousSource = 0;
  let previousOriginalLine = 0;
  let previousOriginalColumn = 0;
  let previousName = 0;
  return lines
    .map((line) => {
      let previousGeneratedColumn = 0;
      return line
        .sort((left, right) => left.generatedColumn - right.generatedColumn)
        .map((segment) => {
          const fields = [
            segment.generatedColumn - previousGeneratedColumn,
            segment.source - previousSource,
            segment.originalLine - previousOriginalLine,
            segment.originalColumn - previousOriginalColumn,
          ];
          previousGeneratedColumn = segment.generatedColumn;
          previousSource = segment.source;
          previousOriginalLine = segment.originalLine;
          previousOriginalColumn = segment.originalColumn;
          if (segment.name !== null) {
            fields.push(segment.name - previousName);
            previousName = segment.name;
          }
          return fields.map(encodeVlq).join('');
        })
        .join(',');
    })
    .join(';');
}

function lineStarts(value) {
  const starts = [0];
  for (let index = 0; index < value.length; index += 1) {
    if (value[index] === '\n') starts.push(index + 1);
  }
  return starts;
}

function generatedPosition(starts, offset) {
  let low = 0;
  let high = starts.length - 1;
  while (low <= high) {
    const middle = (low + high) >> 1;
    if (starts[middle] <= offset) low = middle + 1;
    else high = middle - 1;
  }
  return { line: high, column: offset - starts[high] };
}

function primaryDebugOrigin(origins, moduleName) {
  return origins
    .filter((origin) => origin.source !== null)
    .toSorted((left, right) => {
      const moduleOrder = Number(right.module === moduleName) - Number(left.module === moduleName);
      if (moduleOrder !== 0) return moduleOrder;
      return (
        left.source.file.localeCompare(right.source.file) ||
        left.source.line - right.source.line ||
        left.source.column - right.source.column ||
        (left.source.symbol ?? '').localeCompare(right.source.symbol ?? '')
      );
    })[0];
}

export function createCssSourceMap(root, css, manifest) {
  if (manifest === null) return null;
  const starts = lineStarts(css);
  const sources = [];
  const names = [];
  const segments = [];
  let cursor = 0;
  const entries = [...manifest.globals, ...manifest.rules];
  for (const entry of entries) {
    const offset = css.indexOf(entry.css, cursor);
    if (offset < 0) continue;
    cursor = offset + entry.css.length;
    const origin = primaryDebugOrigin(entry.origins, manifest.module);
    if (origin === undefined) continue;
    if (!inside(root, origin.source.absoluteFile)) continue;
    const sourceName = origin.source.absoluteFile.split(path.sep).join('/');
    let source = sources.indexOf(sourceName);
    if (source < 0) source = sources.push(sourceName) - 1;
    const symbol = origin.source.symbol;
    let name = null;
    if (symbol !== null && symbol !== '') {
      name = names.indexOf(symbol);
      if (name < 0) name = names.push(symbol) - 1;
    }
    const mappingOffsets = [offset];
    for (let index = 0; index < entry.css.length - 1; index += 1) {
      if (entry.css[index] === '\n') mappingOffsets.push(offset + index + 1);
    }
    for (const mappingOffset of mappingOffsets) {
      const generated = generatedPosition(starts, mappingOffset);
      segments.push({
        generatedLine: generated.line,
        generatedColumn: generated.column,
        source,
        originalLine: origin.source.line - 1,
        originalColumn: origin.source.column - 1,
        name,
      });
    }
  }
  if (segments.length === 0) return null;
  return {
    version: 3,
    file: virtualId,
    sources,
    // Empty entries keep Vite from inlining project source while preserving
    // source names and authored coordinates in browser developer tools.
    sourcesContent: sources.map(() => ''),
    names,
    mappings: sourceMapMappings(segments, starts.length),
  };
}

export function formatProblem(diagnostic, root) {
  if (diagnostic.file === null) return null;
  const symbol = diagnostic.symbol == null ? '' : ` [${cleanMessage(diagnostic.symbol)}]`;
  return `${sourceFilename(root, diagnostic.file)}:${diagnostic.line}:${diagnostic.column}:${diagnostic.endLine}:${diagnostic.endColumn}: ${diagnostic.severity} ${diagnostic.code}: ${diagnostic.message}${symbol}`;
}

export function extractionArguments(root, styleConfig, { devtools = false, check = false } = {}) {
  if (devtools && check) {
    throw new Error('Developer manifest output cannot be combined with extraction checking');
  }
  const dependencyArguments = styleConfig.dependencyRoots.flatMap((directory) => [
    '--dependency-root',
    path.resolve(root, directory),
  ]);
  return [
    '--diagnostics=json',
    '--tooling-protocol',
    String(toolingProtocolVersion),
    '--css-output',
    styleConfig.outputs.css,
    '--mappings-output',
    styleConfig.outputs.mappings,
    '--mappings-manifest-output',
    styleConfig.outputs.mappingsManifest,
    '--mappings-package',
    styleConfig.mappingsPackage,
    '--bundle-output',
    styleConfig.outputs.bundle,
    '--cache-dir',
    styleConfig.cacheDirectory,
    ...(check ? ['--check'] : []),
    ...(devtools ? ['--debug-manifest-output', debugManifestFilename(root, styleConfig)] : []),
    ...dependencyArguments,
  ];
}

function spawnProcess(command, arguments_, { cwd, env = process.env } = {}) {
  return new Promise((resolve) => {
    const started = process.hrtime.bigint();
    const child = spawn(command, arguments_, {
      cwd,
      env,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let stdout = '';
    let stderr = '';
    child.stdout.setEncoding('utf8');
    child.stderr.setEncoding('utf8');
    child.stdout.on('data', (chunk) => {
      stdout += chunk;
    });
    child.stderr.on('data', (chunk) => {
      stderr += chunk;
    });
    child.on('error', (error) => {
      resolve({
        status: null,
        stdout,
        stderr,
        error,
        durationMs: elapsedMilliseconds(started),
      });
    });
    child.on('close', (status) => {
      resolve({
        status,
        stdout,
        stderr,
        error: null,
        durationMs: elapsedMilliseconds(started),
      });
    });
  });
}

function elapsedMilliseconds(started) {
  return Number((Number(process.hrtime.bigint() - started) / 1e6).toFixed(3));
}

export function extractorBuildArguments(extractorPackage, profile) {
  if (profile !== 'debug' && profile !== 'release') {
    throw new Error(`Unsupported extractor profile: ${profile}`);
  }
  return [
    'run',
    extractorPackage,
    '--target',
    'native',
    ...(profile === 'release' ? ['--release'] : []),
    '--build-only',
    '--output-json',
  ];
}

export async function buildExtractor(root, options = {}) {
  const extractorPackage = options.extractorPackage ?? 'style_extractor';
  const profile = options.profile ?? 'release';
  let arguments_;
  try {
    arguments_ = extractorBuildArguments(extractorPackage, profile);
  } catch (error) {
    return {
      ok: false,
      diagnostics: [toolchainDiagnostic(errorMessage(error))],
      executable: null,
      stage: 'build',
      stdout: '',
      stderr: '',
    };
  }
  const result = await spawnProcess('moon', arguments_, { cwd: root });
  const parsed = parseMoonBuildOutput(result.stdout, result.stderr);
  const buildErrors = parsed.diagnostics.filter((diagnostic) => diagnostic.severity === 'error');
  if (result.status !== 0 || result.error !== null || buildErrors.length > 0) {
    return {
      ok: false,
      diagnostics:
        parsed.diagnostics.length > 0
          ? parsed.diagnostics
          : [toolchainDiagnostic(result.error?.message ?? `${result.stdout}\n${result.stderr}`)],
      executable: null,
      profile,
      stage: 'build',
      ...result,
    };
  }
  const executablePaths = parsed.artifactPaths
    .map((filename) => (path.isAbsolute(filename) ? filename : path.resolve(root, filename)))
    .filter((filename) => fs.existsSync(filename) && fs.statSync(filename).isFile());
  if (executablePaths.length !== 1) {
    return {
      ok: false,
      diagnostics: [
        toolchainDiagnostic(
          `Moon build returned ${executablePaths.length} native extractor artifacts; expected exactly one.`,
        ),
      ],
      executable: null,
      profile,
      stage: 'build',
      ...result,
    };
  }
  return {
    ok: true,
    diagnostics: parsed.diagnostics,
    executable: executablePaths[0],
    profile,
    stage: 'build',
    ...result,
  };
}

function walkDependencyBundles(directory, output) {
  if (!fs.existsSync(directory) || !fs.statSync(directory).isDirectory()) {
    throw new Error(`Dependency root is not a directory: ${directory}`);
  }
  for (const entry of fs
    .readdirSync(directory, { withFileTypes: true })
    .sort((left, right) => left.name.localeCompare(right.name))) {
    const filename = path.join(directory, entry.name);
    if (entry.isDirectory()) walkDependencyBundles(filename, output);
    else if (entry.isFile() && entry.name.endsWith('.bundle.json')) output.push(filename);
  }
}

export function dependencyBundleFiles(root, styleConfig) {
  const output = [];
  for (const directory of styleConfig.dependencyRoots) {
    walkDependencyBundles(path.resolve(root, directory), output);
  }
  return [...new Set(output)].sort((left, right) => left.localeCompare(right));
}

function fileDigest(filename, cache) {
  const stat = fs.statSync(filename, { bigint: true });
  const signature = `${stat.dev}:${stat.ino}:${stat.size}:${stat.mtimeNs}:${stat.ctimeNs}`;
  const cached = cache.get(filename);
  if (cached?.signature === signature) return cached.digest;
  const digest = createHash('sha256').update(fs.readFileSync(filename)).digest('hex');
  cache.set(filename, { signature, digest });
  return digest;
}

function normalizedConfig(styleConfig) {
  return JSON.stringify({
    schemaVersion: styleConfig.schemaVersion,
    mappingsPackage: styleConfig.mappingsPackage,
    outputs: {
      css: styleConfig.outputs.css,
      mappings: styleConfig.outputs.mappings,
      mappingsManifest: styleConfig.outputs.mappingsManifest,
      bundle: styleConfig.outputs.bundle,
    },
    dependencyRoots: styleConfig.dependencyRoots,
    cacheDirectory: styleConfig.cacheDirectory,
  });
}

export function computeExtractionIdentity(
  root,
  styleConfig,
  executable,
  profile,
  digestCache = new Map(),
) {
  const bundles = dependencyBundleFiles(root, styleConfig);
  const digest = createHash('sha256');
  digest.update(extractionIdentityVersion);
  digest.update('\0');
  digest.update(profile);
  digest.update('\0');
  digest.update(fileDigest(executable, digestCache));
  digest.update('\0');
  digest.update(normalizedConfig(styleConfig));
  for (const filename of bundles) {
    digest.update('\0');
    digest.update(sourceFilename(root, filename));
    digest.update('\0');
    digest.update(fileDigest(filename, digestCache));
  }
  return { identity: digest.digest('hex'), bundles };
}

const formalOutputKinds = ['css', 'mappings', 'mappingsManifest', 'bundle'];

function outputFilenames(root, styleConfig, { devtools = false } = {}) {
  const outputs = formalOutputKinds.map((kind) => path.resolve(root, styleConfig.outputs[kind]));
  if (devtools) outputs.push(debugManifestFilename(root, styleConfig));
  return outputs;
}

function optionalContentDigest(filename) {
  return fs.existsSync(filename)
    ? createHash('sha256').update(fs.readFileSync(filename)).digest('hex')
    : null;
}

function outputSnapshot(root, styleConfig) {
  return Object.fromEntries(
    formalOutputKinds.map((kind) => {
      const filename = path.resolve(root, styleConfig.outputs[kind]);
      return [kind, optionalContentDigest(filename)];
    }),
  );
}

function outputChanges(root, styleConfig, before) {
  return formalOutputKinds.map((kind) => ({
    kind,
    path: styleConfig.outputs[kind].split(path.sep).join('/'),
    changed: before[kind] !== optionalContentDigest(path.resolve(root, styleConfig.outputs[kind])),
  }));
}

function extractorCacheStatus(result, { check = false } = {}) {
  if (check) return 'verification';
  const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
  if (/Cache hit for lampclaw\/moonstyle artifact schema/.test(output)) return 'hit';
  if (/Generated without cache for lampclaw\/moonstyle artifact schema/.test(output)) {
    return 'ineligible';
  }
  if (/Generated lampclaw\/moonstyle artifact schema/.test(output)) return 'miss';
  return 'unknown';
}

function timings(buildMs = 0, extractMs = 0, totalStarted = null) {
  return {
    buildMs: Number(buildMs.toFixed(3)),
    extractMs: Number(extractMs.toFixed(3)),
    totalMs: totalStarted === null ? 0 : elapsedMilliseconds(totalStarted),
  };
}

function extractionFailure(result, styleConfig, buildDiagnostics, metadata) {
  let diagnostics;
  try {
    diagnostics = parseDiagnostics(`${result.stdout}\n${result.stderr}`);
  } catch {
    diagnostics = [
      toolchainDiagnostic(result.error?.message ?? `${result.stdout}\n${result.stderr}`),
    ];
  }
  if (diagnostics.length === 0) {
    diagnostics = [toolchainDiagnostic(`${result.stdout}\n${result.stderr}`)];
  }
  return {
    ok: false,
    diagnostics: [...buildDiagnostics, ...diagnostics],
    styleConfig,
    stage: 'extract',
    executed: true,
    skipped: false,
    cssChanged: false,
    ...metadata,
    ...result,
  };
}

export function createExtractorRunner(options = {}) {
  const digestCache = new Map();
  let lastIdentity = null;
  let lastExtraction = null;

  return async function run(root, request = {}) {
    const totalStarted = process.hrtime.bigint();
    const profile = request.profile ?? options.profile ?? 'release';
    const check = request.check ?? options.check ?? false;
    const mode = request.mode ?? (check ? 'check' : 'generate');
    const reasons = [...new Set(request.reasons ?? [])];
    const devtools =
      !check && profile === 'debug' && (request.devtools ?? options.devtools ?? false);
    let styleConfig;
    try {
      styleConfig = loadStyleConfig(root);
    } catch (error) {
      return {
        ok: false,
        diagnostics: [toolchainDiagnostic(errorMessage(error))],
        styleConfig: null,
        profile,
        mode,
        reasons,
        stage: 'config',
        executed: false,
        skipped: false,
        cssChanged: false,
        changedOutputs: [],
        cacheStatus: 'unknown',
        timings: timings(0, 0, totalStarted),
        stdout: '',
        stderr: '',
      };
    }

    const build = await buildExtractor(root, {
      extractorPackage: options.extractorPackage,
      profile,
    });
    if (!build.ok) {
      return {
        ...build,
        styleConfig,
        mode,
        reasons,
        executed: false,
        skipped: false,
        cssChanged: false,
        changedOutputs: formalOutputKinds.map((kind) => ({
          kind,
          path: styleConfig.outputs[kind].split(path.sep).join('/'),
          changed: false,
        })),
        cacheStatus: 'unknown',
        timings: timings(build.durationMs ?? 0, 0, totalStarted),
      };
    }

    let identity;
    let bundles;
    try {
      ({ identity, bundles } = computeExtractionIdentity(
        root,
        styleConfig,
        build.executable,
        profile,
        digestCache,
      ));
    } catch (error) {
      return {
        ok: false,
        diagnostics: [...build.diagnostics, toolchainDiagnostic(errorMessage(error))],
        styleConfig,
        executable: build.executable,
        profile,
        mode,
        reasons,
        stage: 'inputs',
        executed: false,
        skipped: false,
        cssChanged: false,
        changedOutputs: formalOutputKinds.map((kind) => ({
          kind,
          path: styleConfig.outputs[kind].split(path.sep).join('/'),
          changed: false,
        })),
        cacheStatus: 'unknown',
        timings: timings(build.durationMs ?? 0, 0, totalStarted),
        stdout: build.stdout,
        stderr: build.stderr,
      };
    }

    const outputsMissing = outputFilenames(root, styleConfig, { devtools }).some(
      (filename) => !fs.existsSync(filename),
    );
    if (
      !check &&
      !request.force &&
      !outputsMissing &&
      identity === lastIdentity &&
      lastExtraction !== null
    ) {
      return {
        ...lastExtraction,
        diagnostics: [
          ...build.diagnostics,
          ...lastExtraction.diagnostics.filter((diagnostic) => !diagnostic.code.startsWith('MOON')),
        ],
        skipped: true,
        executed: false,
        mode,
        reasons,
        cssChanged: false,
        debugChanged: false,
        changedOutputs: formalOutputKinds.map((kind) => ({
          kind,
          path: styleConfig.outputs[kind].split(path.sep).join('/'),
          changed: false,
        })),
        cacheStatus: 'process-skip',
        timings: timings(build.durationMs ?? 0, 0, totalStarted),
        stdout: build.stdout,
        stderr: build.stderr,
      };
    }

    const cssFilename = path.resolve(root, styleConfig.outputs.css);
    const debugFilename = debugManifestFilename(root, styleConfig);
    const outputsBefore = outputSnapshot(root, styleConfig);
    const cssBefore = optionalContentDigest(cssFilename);
    const debugBefore = devtools ? optionalContentDigest(debugFilename) : null;
    const metadata = {
      executable: build.executable,
      identity,
      bundles,
      profile,
      mode,
      reasons,
    };
    const result = await spawnProcess(
      build.executable,
      extractionArguments(root, styleConfig, { devtools, check }),
      {
        cwd: root,
        env: {
          ...process.env,
          MOONSTYLE_CACHE_IDENTITY: identity,
        },
      },
    );
    let outcome;
    if (result.status !== 0 || result.error !== null) {
      outcome = extractionFailure(result, styleConfig, build.diagnostics, metadata);
    } else if (outputFilenames(root, styleConfig).some((filename) => !fs.existsSync(filename))) {
      outcome = {
        ok: false,
        diagnostics: [
          ...build.diagnostics,
          toolchainDiagnostic(
            'The style extractor completed without writing every configured output.',
          ),
        ],
        styleConfig,
        stage: 'extract',
        executed: true,
        skipped: false,
        cssChanged: false,
        ...metadata,
        ...result,
      };
    } else {
      let debugManifest = null;
      let debugDiagnostic = null;
      if (devtools) {
        try {
          const css = fs.readFileSync(cssFilename, 'utf8');
          const generatedBundle = JSON.parse(
            fs.readFileSync(path.resolve(root, styleConfig.outputs.bundle), 'utf8'),
          );
          if (
            typeof generatedBundle.semanticDigest !== 'string' ||
            generatedBundle.semanticDigest === ''
          ) {
            throw new Error('generated bundle semanticDigest is invalid');
          }
          debugManifest = parseDebugManifest(
            fs.readFileSync(debugFilename, 'utf8'),
            root,
            css,
            generatedBundle.semanticDigest,
          );
        } catch (error) {
          debugDiagnostic = debugManifestDiagnostic(errorMessage(error));
        }
      }
      outcome = {
        ok: true,
        diagnostics:
          debugDiagnostic === null ? build.diagnostics : [...build.diagnostics, debugDiagnostic],
        styleConfig,
        stage: 'extract',
        executed: true,
        skipped: false,
        cssChanged: cssBefore !== optionalContentDigest(cssFilename),
        debugChanged: devtools && debugBefore !== optionalContentDigest(debugFilename),
        debugManifest,
        ...metadata,
        ...result,
      };
    }
    const changedOutputs = outputChanges(root, styleConfig, outputsBefore);
    outcome = {
      ...outcome,
      stage: outcome.ok ? 'complete' : outcome.stage,
      cssChanged: changedOutputs.find((item) => item.kind === 'css')?.changed ?? false,
      changedOutputs,
      cacheStatus: outcome.ok ? extractorCacheStatus(result, { check }) : 'unknown',
      timings: timings(build.durationMs ?? 0, result.durationMs ?? 0, totalStarted),
    };
    lastIdentity = identity;
    if (!check) lastExtraction = outcome;
    return outcome;
  };
}

export async function runExtractor(root, options = {}) {
  const runner = createExtractorRunner(options);
  return runner(root, {
    force: true,
    profile: options.profile ?? 'release',
    check: options.check ?? false,
    mode: options.mode,
    reasons: options.reasons,
  });
}

export function createExtractionQueue(run) {
  let current = null;
  let pending = null;
  let waiting = [];
  const merge = (left, right) => ({
    ...left,
    ...right,
    force: Boolean(left?.force || right?.force),
    reasons: [...new Set([...(left?.reasons ?? []), ...(right?.reasons ?? [])])],
  });
  return function schedule(request = {}) {
    if (current !== null) {
      pending = merge(pending, request);
      return new Promise((resolve, reject) => waiting.push({ resolve, reject }));
    }
    pending = merge(null, request);
    current = (async () => {
      let result;
      try {
        do {
          const next = pending;
          pending = null;
          result = await run(next);
        } while (pending !== null);
        for (const waiter of waiting) waiter.resolve(result);
        waiting = [];
        return result;
      } catch (error) {
        for (const waiter of waiting) waiter.reject(error);
        waiting = [];
        throw error;
      } finally {
        current = null;
      }
    })();
    return current;
  };
}

function inside(directory, filename) {
  const relative = path.relative(directory, filename);
  return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));
}

function insideIgnoredDirectory(filename, root, styleConfig) {
  if (
    typeof styleConfig?.cacheDirectory === 'string' &&
    inside(path.resolve(root, styleConfig.cacheDirectory), filename)
  ) {
    return true;
  }
  const relative = path.relative(root, filename);
  if (relative.startsWith('..') || path.isAbsolute(relative)) return false;
  return relative.split(path.sep).some((segment) => ignoredBuildDirectories.has(segment));
}

export function isRelevantFile(filename, root, styleConfig, watchPaths = [root]) {
  const absolute = path.isAbsolute(filename) ? filename : path.resolve(root, filename);
  if (absolute === path.resolve(root, '.moonstyle.json')) return true;
  if (absolute === path.resolve(root, 'style.config.json')) return true;
  if (!watchPaths.some((directory) => inside(directory, absolute))) return false;
  if (
    styleConfig &&
    Object.values(styleConfig.outputs).some(
      (filename_) => absolute === path.resolve(root, filename_),
    )
  ) {
    return false;
  }
  if (
    styleConfig &&
    absolute.endsWith('.bundle.json') &&
    styleConfig.dependencyRoots.some((directory) => inside(path.resolve(root, directory), absolute))
  ) {
    return true;
  }
  if (
    insideIgnoredDirectory(absolute, root, styleConfig) ||
    watchPaths.some(
      (directory) =>
        inside(directory, absolute) && insideIgnoredDirectory(absolute, directory, null),
    )
  )
    return false;
  const basename = path.basename(absolute);
  if (moonManifestNames.has(basename)) return true;
  return ['.mbt', '.mbtx', '.c', '.h', '.cc', '.cpp'].includes(path.extname(absolute));
}
