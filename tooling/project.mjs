import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { createExtractorRunner, loadStyleConfig } from './extraction.mjs';
import { moonConfiguration } from './workspace.mjs';

export const projectManifestName = '.moonstyle.json';
export const projectManifestSchemaVersion = 1;
export const legacyCompatibilityEndsAt = '0.2.0';

const packageRoot = path.resolve(import.meta.dirname, '..');
const toolingPackage = JSON.parse(fs.readFileSync(path.join(packageRoot, 'package.json'), 'utf8'));
export const toolingVersion = toolingPackage.version;
const templateRoot = path.join(packageRoot, 'templates', 'rabbita-vite');
const legacyFiles = {
  'vite-plugin-lampclaw-style.mjs':
    'sha256:776e2b2cd1934a36636ee4d7e39fbb38480bed949376473a6c2d6a01bf4b38a4',
  'lampclaw-style-inspector-client.mjs':
    'sha256:9d32bb28c3885bcae207388f8f4693273fb96392e811657905a9c68a1d335da7',
};
const legacyViteImport = "import lampclawStyle from './vite-plugin-lampclaw-style.mjs';";
const migratedLegacyViteImport = "import lampclawStyle from '@lampclaw/moonstyle-tooling/vite';";
const publicViteImport = "import moonStyle from '@lampclaw/moonstyle-tooling/vite';";
const expectedManifestKeys = [
  'entrypoints',
  'extractorPackage',
  'managedFiles',
  'schemaVersion',
  'stylesPackage',
  'toolingVersion',
  'viteConfig',
];

class ProjectError extends Error {
  constructor(code, message, { file = null, help = null } = {}) {
    super(message);
    this.code = code;
    this.file = file;
    this.help = help;
  }
}

function diagnostic(code, severity, message, { file = null, help = null } = {}) {
  return { code, severity, file, message, help };
}

function addError(report, error, fallbackCode = 'STYLE_PROJECT') {
  report.diagnostics.push(
    diagnostic(
      error instanceof ProjectError ? error.code : fallbackCode,
      'error',
      error instanceof Error ? error.message : String(error),
      {
        file: error instanceof ProjectError ? error.file : null,
        help: error instanceof ProjectError ? error.help : null,
      },
    ),
  );
}

function createReport(command, dryRun = false) {
  return {
    schemaVersion: 1,
    command,
    toolingVersion,
    passed: true,
    dryRun,
    changedFiles: [],
    removedFiles: [],
    diagnostics: [],
  };
}

function finishReport(report) {
  report.changedFiles = [...new Set(report.changedFiles)].sort((left, right) =>
    left.localeCompare(right),
  );
  report.removedFiles = [...new Set(report.removedFiles)].sort((left, right) =>
    left.localeCompare(right),
  );
  report.passed = !report.diagnostics.some((item) => item.severity === 'error');
  return report;
}

function exactKeys(value, expected, label, file = null) {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) {
    throw new ProjectError('STYLE_PROJECT_SCHEMA', `${label} must be an object`, { file });
  }
  const actual = Object.keys(value).sort((left, right) => left.localeCompare(right));
  const wanted = [...expected].sort((left, right) => left.localeCompare(right));
  if (JSON.stringify(actual) !== JSON.stringify(wanted)) {
    throw new ProjectError(
      'STYLE_PROJECT_SCHEMA',
      `${label} must contain exactly: ${wanted.join(', ')}`,
      { file },
    );
  }
}

function packageName(value, label, file = null) {
  if (typeof value !== 'string' || value.trim() !== value || value === '') {
    throw new ProjectError('STYLE_PROJECT_SCHEMA', `${label} must be a non-empty package name`, {
      file,
    });
  }
  const segments = value.split('/');
  if (
    segments.some(
      (segment) =>
        segment === '' ||
        segment === '.' ||
        segment === '..' ||
        !/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(segment),
    )
  ) {
    throw new ProjectError('STYLE_PROJECT_SCHEMA', `${label} is not a valid MoonBit package name`, {
      file,
    });
  }
  return value;
}

function compareVersions(left, right) {
  const [leftCore, leftPrerelease] = left.split('-', 2);
  const [rightCore, rightPrerelease] = right.split('-', 2);
  const leftParts = leftCore.split('.').map(Number);
  const rightParts = rightCore.split('.').map(Number);
  for (let index = 0; index < 3; index += 1) {
    if (leftParts[index] !== rightParts[index]) return leftParts[index] - rightParts[index];
  }
  if (leftPrerelease === rightPrerelease) return 0;
  if (leftPrerelease === undefined) return 1;
  if (rightPrerelease === undefined) return -1;
  return leftPrerelease.localeCompare(rightPrerelease);
}

function rejectNewerProject(manifest) {
  if (compareVersions(manifest.toolingVersion, toolingVersion) > 0) {
    throw new ProjectError(
      'STYLE_PROJECT_TOOLING_NEWER',
      `Project tooling ${manifest.toolingVersion} is newer than installed tooling ${toolingVersion}`,
      {
        file: projectManifestName,
        help: 'Install the project tooling version before changing managed files.',
      },
    );
  }
}

function relativePath(root, value, label, file = null) {
  if (
    typeof value !== 'string' ||
    value.trim() !== value ||
    value === '' ||
    value === '.' ||
    path.isAbsolute(value) ||
    value.includes('\0')
  ) {
    throw new ProjectError('STYLE_PROJECT_PATH', `${label} must be a project-relative path`, {
      file,
    });
  }
  const normalized = value.split('\\').join('/');
  const resolved = path.resolve(root, normalized);
  const relative = path.relative(root, resolved);
  if (relative === '' || relative.startsWith('..') || path.isAbsolute(relative)) {
    throw new ProjectError('STYLE_PROJECT_PATH', `${label} must stay inside the project root`, {
      file,
    });
  }
  const realRoot = fs.realpathSync(root);
  let ancestor = resolved;
  while (!fs.existsSync(ancestor)) {
    const parent = path.dirname(ancestor);
    if (parent === ancestor) break;
    ancestor = parent;
  }
  const realAncestor = fs.realpathSync(ancestor);
  const realRelative = path.relative(realRoot, realAncestor);
  if (
    realRelative === '..' ||
    realRelative.startsWith(`..${path.sep}`) ||
    path.isAbsolute(realRelative)
  ) {
    throw new ProjectError(
      'STYLE_PROJECT_PATH',
      `${label} must not traverse a symbolic link outside the project root`,
      { file },
    );
  }
  return relative.split(path.sep).join('/');
}

function sha256(content) {
  return `sha256:${createHash('sha256').update(content).digest('hex')}`;
}

function fileDigest(filename) {
  return fs.existsSync(filename) && fs.statSync(filename).isFile()
    ? sha256(fs.readFileSync(filename))
    : null;
}

function readJson(filename, code) {
  try {
    return JSON.parse(fs.readFileSync(filename, 'utf8'));
  } catch (error) {
    throw new ProjectError(code, `${path.basename(filename)} is not valid JSON: ${error.message}`, {
      file: path.basename(filename),
    });
  }
}

function modernModule(root) {
  const jsonFilename = path.join(root, 'moon.mod.json');
  const filename = path.join(root, 'moon.mod');
  if (fs.existsSync(jsonFilename)) {
    throw new ProjectError(
      fs.existsSync(filename) ? 'STYLE_PROJECT_MOON_CONFLICT' : 'STYLE_PROJECT_MOON_LEGACY',
      fs.existsSync(filename)
        ? `Both moon.mod and moon.mod.json exist in ${root}`
        : `Legacy moon.mod.json in ${root} requires migration`,
      {
        file: jsonFilename,
        help: 'Migrate the module to moon.mod with the installed Moon toolchain, review its dependencies, and remove the obsolete JSON manifest before retrying.',
      },
    );
  }
  if (fs.existsSync(filename)) {
    const content = fs.readFileSync(filename, 'utf8');
    const configuration = moonConfiguration(content);
    const name = configuration.match(/^\s*name\s*=\s*"([^"]+)"\s*$/m)?.[1];
    if (name === undefined) {
      throw new ProjectError('STYLE_PROJECT_MOON_MANIFEST', 'moon.mod must define name = "..."', {
        file: 'moon.mod',
      });
    }
    return {
      name: packageName(name, 'moon.mod name', 'moon.mod'),
      filename: 'moon.mod',
      content,
      hasStyleDependency: [...configuration.matchAll(/\bimport\s*\{([^}]*)\}/g)].some((block) =>
        /"lampclaw\/moonstyle(?:@[^"]+)?"/.test(block[1]),
      ),
    };
  }
  throw new ProjectError('STYLE_PROJECT_MOON_MANIFEST', `No moon.mod was found in ${root}`, {
    help: 'Run the command from a MoonBit module root or pass --root.',
  });
}

export function moonProject(root) {
  root = path.resolve(root);
  const module = modernModule(root);
  let workspace = null;
  for (let directory = root; ; directory = path.dirname(directory)) {
    const filename = path.join(directory, 'moon.work');
    if (fs.existsSync(filename)) {
      const configuration = moonConfiguration(fs.readFileSync(filename, 'utf8'));
      const list = configuration.match(/\bmembers\s*=\s*\[([\s\S]*?)\]/)?.[1];
      if (list === undefined) {
        throw new ProjectError('STYLE_PROJECT_WORKSPACE', 'moon.work must define members = [...]', {
          file: filename,
        });
      }
      const members = [...list.matchAll(/"(?:\\.|[^"\\])*"/g)].map((match) =>
        path.resolve(directory, JSON.parse(match[0])),
      );
      for (const member of members) modernModule(member);
      if (!members.some((member) => fs.realpathSync(member) === fs.realpathSync(root))) {
        throw new ProjectError(
          'STYLE_PROJECT_WORKSPACE_MEMBER',
          'The project module is not a member of the nearest moon.work',
          { file: filename },
        );
      }
      workspace = { filename, members };
      break;
    }
    if (directory === path.dirname(directory)) break;
  }
  if (!module.hasStyleDependency) {
    throw new ProjectError(
      'STYLE_PROJECT_MOON_DEPENDENCY',
      'moon.mod does not declare lampclaw/moonstyle',
      {
        file: 'moon.mod',
        help: 'Add lampclaw/moonstyle to the module import block; a workspace member alone does not declare a dependency.',
      },
    );
  }
  return { ...module, workspace };
}

function defaultSettings(root, moduleName, options = {}) {
  const stylesPackage = packageName(
    options.stylesPackage ?? `${moduleName}/styles`,
    '--styles-package',
  );
  const extractorPackage = relativePath(
    root,
    options.extractorPackage ?? 'style_extractor',
    '--extractor-package',
  );
  const viteConfig = relativePath(root, options.viteConfig ?? 'vite.config.mjs', '--vite-config');
  const requestedEntrypoints = options.entrypoints ?? ['entry.mjs'];
  if (!Array.isArray(requestedEntrypoints) || requestedEntrypoints.length === 0) {
    throw new ProjectError('STYLE_PROJECT_USAGE', 'At least one --entry path is required');
  }
  const entrypoints = requestedEntrypoints.map((value, index) =>
    relativePath(root, value, `--entry[${index}]`),
  );
  if (new Set(entrypoints).size !== entrypoints.length) {
    throw new ProjectError('STYLE_PROJECT_USAGE', '--entry paths must be unique');
  }
  return { stylesPackage, extractorPackage, viteConfig, entrypoints };
}

export function loadProjectManifest(root) {
  const filename = path.join(root, projectManifestName);
  if (!fs.existsSync(filename)) {
    throw new ProjectError('STYLE_PROJECT_MANIFEST', `${projectManifestName} was not found`, {
      file: projectManifestName,
      help: 'Run moonstyle init.',
    });
  }
  const value = readJson(filename, 'STYLE_PROJECT_MANIFEST');
  exactKeys(value, expectedManifestKeys, projectManifestName, projectManifestName);
  if (value.schemaVersion !== projectManifestSchemaVersion) {
    throw new ProjectError(
      'STYLE_PROJECT_SCHEMA',
      `${projectManifestName} schemaVersion must be ${projectManifestSchemaVersion}`,
      { file: projectManifestName },
    );
  }
  if (
    typeof value.toolingVersion !== 'string' ||
    !/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(value.toolingVersion)
  ) {
    throw new ProjectError(
      'STYLE_PROJECT_SCHEMA',
      `${projectManifestName} toolingVersion is invalid`,
      {
        file: projectManifestName,
      },
    );
  }
  const stylesPackage = packageName(
    value.stylesPackage,
    `${projectManifestName} stylesPackage`,
    projectManifestName,
  );
  const extractorPackage = relativePath(
    root,
    value.extractorPackage,
    `${projectManifestName} extractorPackage`,
    projectManifestName,
  );
  const viteConfig = relativePath(
    root,
    value.viteConfig,
    `${projectManifestName} viteConfig`,
    projectManifestName,
  );
  if (!Array.isArray(value.entrypoints) || value.entrypoints.length === 0) {
    throw new ProjectError(
      'STYLE_PROJECT_SCHEMA',
      `${projectManifestName} entrypoints is invalid`,
      {
        file: projectManifestName,
      },
    );
  }
  const entrypoints = value.entrypoints.map((entry, index) =>
    relativePath(root, entry, `${projectManifestName} entrypoints[${index}]`, projectManifestName),
  );
  if (new Set(entrypoints).size !== entrypoints.length) {
    throw new ProjectError(
      'STYLE_PROJECT_SCHEMA',
      `${projectManifestName} entrypoints must be unique`,
      {
        file: projectManifestName,
      },
    );
  }
  if (
    value.managedFiles == null ||
    typeof value.managedFiles !== 'object' ||
    Array.isArray(value.managedFiles)
  ) {
    throw new ProjectError(
      'STYLE_PROJECT_SCHEMA',
      `${projectManifestName} managedFiles is invalid`,
      {
        file: projectManifestName,
      },
    );
  }
  const managedFiles = {};
  for (const [filename, digest] of Object.entries(value.managedFiles)) {
    const relative = relativePath(
      root,
      filename,
      `${projectManifestName} managedFiles key`,
      projectManifestName,
    );
    if (relative === projectManifestName || relative === 'style.config.json') {
      throw new ProjectError(
        'STYLE_PROJECT_SCHEMA',
        `${projectManifestName} cannot manage ${relative}`,
        { file: projectManifestName },
      );
    }
    if (typeof digest !== 'string' || !/^sha256:[0-9a-f]{64}$/.test(digest)) {
      throw new ProjectError(
        'STYLE_PROJECT_SCHEMA',
        `${projectManifestName} managedFiles digest for ${relative} is invalid`,
        { file: projectManifestName },
      );
    }
    if (managedFiles[relative] !== undefined) {
      throw new ProjectError(
        'STYLE_PROJECT_SCHEMA',
        `${projectManifestName} managedFiles contains duplicate normalized path ${relative}`,
        { file: projectManifestName },
      );
    }
    managedFiles[relative] = digest;
  }
  return {
    schemaVersion: projectManifestSchemaVersion,
    toolingVersion: value.toolingVersion,
    stylesPackage,
    extractorPackage,
    viteConfig,
    entrypoints,
    managedFiles,
  };
}

export function loadCompatibleProjectManifest(root) {
  const manifest = loadProjectManifest(root);
  rejectNewerProject(manifest);
  return manifest;
}

function template(relative, replacements = {}) {
  let content = fs.readFileSync(path.join(templateRoot, relative), 'utf8');
  for (const [from, to] of Object.entries(replacements)) content = content.replaceAll(from, to);
  return content;
}

function styleConfigTemplate(moduleName) {
  return template('style.config.json.template', { __APP_MODULE__: moduleName });
}

function viteConfigTemplate(settings) {
  return [
    "import { defineConfig } from 'vite';",
    publicViteImport,
    '',
    'export default defineConfig({',
    `  plugins: [moonStyle({ extractorPackage: ${JSON.stringify(settings.extractorPackage)} })],`,
    '});',
    '',
  ].join('\n');
}

function entryTemplate() {
  return "import 'virtual:moonstyle.css';\n";
}

function desiredFiles(settings) {
  return new Map([
    [`${settings.extractorPackage}/main.mbt`, template('style_extractor/main.mbt')],
    [
      `${settings.extractorPackage}/moon.pkg`,
      template('style_extractor/moon.pkg.template', {
        '__APP_MODULE__/styles': settings.stylesPackage,
      }),
    ],
    ['.vscode/tasks.json', template('.vscode/tasks.json.template')],
    [settings.viteConfig, viteConfigTemplate(settings)],
    ...settings.entrypoints.map((entry) => [entry, entryTemplate()]),
  ]);
}

function manifestContent(settings, managedFiles, version = toolingVersion) {
  return `${JSON.stringify(
    {
      schemaVersion: projectManifestSchemaVersion,
      toolingVersion: version,
      stylesPackage: settings.stylesPackage,
      extractorPackage: settings.extractorPackage,
      viteConfig: settings.viteConfig,
      entrypoints: settings.entrypoints,
      managedFiles: Object.fromEntries(
        Object.entries(managedFiles).sort(([left], [right]) => left.localeCompare(right)),
      ),
    },
    null,
    2,
  )}\n`;
}

function mutation(root) {
  return { root, writes: new Map(), deletes: new Set() };
}

function queueWrite(plan, relative, content) {
  const filename = path.join(plan.root, relative);
  if (!fs.existsSync(filename) || fs.readFileSync(filename, 'utf8') !== content) {
    plan.writes.set(relative, content);
  }
}

function projectedContent(plan, relative) {
  if (plan.deletes.has(relative)) return null;
  if (plan.writes.has(relative)) return plan.writes.get(relative);
  const filename = path.join(plan.root, relative);
  return fs.existsSync(filename) && fs.statSync(filename).isFile()
    ? fs.readFileSync(filename, 'utf8')
    : null;
}

function applyMutation(plan, { dryRun = false } = {}) {
  const writes = [...plan.writes].sort(([left], [right]) => left.localeCompare(right));
  const deletes = [...plan.deletes].sort((left, right) => left.localeCompare(right));
  if (dryRun) return [];
  const nonce = `.moonstyle-${process.pid}-${Date.now()}`;
  const staged = [];
  const backups = [];
  const installed = [];
  try {
    for (let index = 0; index < writes.length; index += 1) {
      const [relative, content] = writes[index];
      const target = path.join(plan.root, relative);
      fs.mkdirSync(path.dirname(target), { recursive: true });
      const temporary = `${target}${nonce}-${index}.tmp`;
      fs.writeFileSync(temporary, content, { flag: 'wx' });
      staged.push(temporary);
    }
    for (const relative of deletes) {
      const target = path.join(plan.root, relative);
      if (!fs.existsSync(target)) continue;
      const backup = `${target}${nonce}.bak`;
      fs.renameSync(target, backup);
      backups.push({ target, backup });
    }
    for (let index = 0; index < writes.length; index += 1) {
      const [relative] = writes[index];
      const target = path.join(plan.root, relative);
      if (fs.existsSync(target)) {
        const backup = `${target}${nonce}.bak`;
        fs.renameSync(target, backup);
        backups.push({ target, backup });
      }
      fs.renameSync(staged[index], target);
      installed.push(target);
    }
  } catch (error) {
    for (const target of installed.toReversed()) {
      if (fs.existsSync(target)) fs.rmSync(target);
    }
    for (const { target, backup } of backups.toReversed()) {
      if (fs.existsSync(backup)) fs.renameSync(backup, target);
    }
    for (const temporary of staged) {
      if (fs.existsSync(temporary)) fs.rmSync(temporary);
    }
    throw error;
  }
  const cleanupFailures = [];
  for (const { backup } of backups) {
    try {
      fs.rmSync(backup);
    } catch {
      cleanupFailures.push(path.relative(plan.root, backup).split(path.sep).join('/'));
    }
  }
  return cleanupFailures;
}

function reportBackupCleanup(report, cleanupFailures) {
  for (const relative of cleanupFailures) {
    report.diagnostics.push(
      diagnostic(
        'STYLE_PROJECT_BACKUP_CLEANUP',
        'warning',
        'The transaction committed, but a recovery backup could not be removed',
        { file: relative, help: 'Remove this backup after confirming the upgraded file.' },
      ),
    );
  }
}

function hasViteIntegration(source) {
  if (source === null) return false;
  const imported = source.match(
    /import\s+([A-Za-z_$][A-Za-z0-9_$]*)\s+from\s+["']@lampclaw\/moonstyle-tooling\/vite["']/,
  );
  return imported !== null && new RegExp(`\\b${imported[1]}\\s*\\(`).test(source);
}

function integrationDiagnostics(report, plan, settings, severity = 'warning') {
  const viteSource = projectedContent(plan, settings.viteConfig);
  if (!hasViteIntegration(viteSource)) {
    report.diagnostics.push(
      diagnostic(
        'STYLE_PROJECT_VITE_INTEGRATION',
        severity,
        `${settings.viteConfig} does not use @lampclaw/moonstyle-tooling/vite`,
        {
          file: settings.viteConfig,
          help: `Add ${publicViteImport} and moonStyle({ extractorPackage: ${JSON.stringify(settings.extractorPackage)} }) to plugins.`,
        },
      ),
    );
  }
  for (const entry of settings.entrypoints) {
    const source = projectedContent(plan, entry);
    if (source === null || !/["']virtual:moonstyle\.css["']/.test(source)) {
      report.diagnostics.push(
        diagnostic(
          'STYLE_PROJECT_ENTRY_INTEGRATION',
          severity,
          `${entry} does not import virtual:moonstyle.css`,
          { file: entry, help: "Add import 'virtual:moonstyle.css';" },
        ),
      );
    }
  }
}

function validateStyleConfig(root) {
  try {
    return loadStyleConfig(root);
  } catch (error) {
    throw new ProjectError('STYLE_PROJECT_STYLE_CONFIG', error.message, {
      file: 'style.config.json',
      help: 'Fix style.config.json before retrying.',
    });
  }
}

function explicitSettingsMatch(root, manifest, options) {
  const checks = [
    {
      key: 'stylesPackage',
      flag: '--styles-package',
      normalize: (value, label) => packageName(value, label),
    },
    {
      key: 'extractorPackage',
      flag: '--extractor-package',
      normalize: (value, label) => relativePath(root, value, label),
    },
    {
      key: 'viteConfig',
      flag: '--vite-config',
      normalize: (value, label) => relativePath(root, value, label),
    },
  ];
  for (const { key, flag, normalize } of checks) {
    const requested = options[key] === undefined ? undefined : normalize(options[key], flag);
    if (requested !== undefined && requested !== manifest[key]) {
      throw new ProjectError(
        'STYLE_PROJECT_ALREADY_INITIALIZED',
        `${flag} conflicts with the existing ${projectManifestName}`,
        { file: projectManifestName, help: 'Edit the manifest deliberately, then run upgrade.' },
      );
    }
  }
  if (
    options.entrypoints !== undefined &&
    JSON.stringify(
      options.entrypoints.map((entry, index) => relativePath(root, entry, `--entry[${index}]`)),
    ) !== JSON.stringify(manifest.entrypoints)
  ) {
    throw new ProjectError(
      'STYLE_PROJECT_ALREADY_INITIALIZED',
      `--entry conflicts with the existing ${projectManifestName}`,
      { file: projectManifestName, help: 'Edit the manifest deliberately, then run upgrade.' },
    );
  }
}

export function initProject(options = {}) {
  const report = createReport('init');
  const root = path.resolve(options.root ?? process.cwd());
  const plan = mutation(root);
  try {
    if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) {
      throw new ProjectError('STYLE_PROJECT_ROOT', `Project root is not a directory: ${root}`);
    }
    const moon = moonProject(root);
    const manifestFilename = path.join(root, projectManifestName);
    const existing = fs.existsSync(manifestFilename) ? loadProjectManifest(root) : null;
    if (existing !== null) {
      rejectNewerProject(existing);
      explicitSettingsMatch(root, existing, options);
    }
    const settings = existing ?? defaultSettings(root, moon.name, options);
    if (existing !== null && existing.toolingVersion !== toolingVersion) {
      report.diagnostics.push(
        diagnostic(
          'STYLE_PROJECT_TOOLING_VERSION',
          'warning',
          `Project tooling ${existing.toolingVersion} differs from installed tooling ${toolingVersion}`,
          { file: projectManifestName, help: 'Run moonstyle upgrade.' },
        ),
      );
    }

    const styleConfigFilename = path.join(root, 'style.config.json');
    if (fs.existsSync(styleConfigFilename)) validateStyleConfig(root);
    else queueWrite(plan, 'style.config.json', styleConfigTemplate(moon.name));

    const desired = desiredFiles(settings);
    const managedFiles = { ...existing?.managedFiles };
    for (const [relative, content] of desired) {
      const filename = path.join(root, relative);
      if (!fs.existsSync(filename)) {
        queueWrite(plan, relative, content);
        managedFiles[relative] = sha256(content);
      } else if (fs.statSync(filename).isFile() && fs.readFileSync(filename, 'utf8') === content) {
        managedFiles[relative] = sha256(content);
      } else if (existing?.managedFiles[relative] !== undefined) {
        report.diagnostics.push(
          diagnostic(
            'STYLE_PROJECT_MANAGED_MODIFIED',
            'warning',
            `${relative} differs from its managed hash and was preserved`,
            { file: relative, help: 'Run upgrade or merge scaffold changes manually.' },
          ),
        );
      } else if (relative !== settings.viteConfig && !settings.entrypoints.includes(relative)) {
        report.diagnostics.push(
          diagnostic(
            'STYLE_PROJECT_CUSTOM_FILE',
            'warning',
            `${relative} already exists and was preserved`,
            { file: relative, help: 'Compare it with the generated scaffold before managing it.' },
          ),
        );
      }
    }
    queueWrite(
      plan,
      projectManifestName,
      manifestContent(settings, managedFiles, existing?.toolingVersion ?? toolingVersion),
    );
    integrationDiagnostics(report, plan, settings);
    reportBackupCleanup(report, applyMutation(plan));
    fs.mkdirSync(path.join(root, 'src', 'generated'), { recursive: true });
    report.changedFiles.push(...plan.writes.keys());
  } catch (error) {
    addError(report, error);
  }
  return finishReport(report);
}

function safelyManageDesiredFiles(report, plan, settings, previousManaged) {
  const managedFiles = { ...previousManaged };
  for (const [relative, content] of desiredFiles(settings)) {
    const filename = path.join(plan.root, relative);
    const current = projectedContent(plan, relative);
    const recorded = previousManaged[relative];
    if (current === null) {
      queueWrite(plan, relative, content);
      managedFiles[relative] = sha256(content);
    } else if (recorded !== undefined) {
      const originalDigest = fileDigest(filename);
      if (originalDigest === recorded || current === content) {
        queueWrite(plan, relative, content);
        managedFiles[relative] = sha256(content);
      } else {
        report.diagnostics.push(
          diagnostic(
            'STYLE_PROJECT_MANAGED_MODIFIED',
            'warning',
            `${relative} differs from its last managed hash and was preserved`,
            { file: relative, help: 'Merge the current scaffold changes manually.' },
          ),
        );
      }
    } else if (current === content) {
      managedFiles[relative] = sha256(content);
    } else if (relative !== settings.viteConfig && !settings.entrypoints.includes(relative)) {
      report.diagnostics.push(
        diagnostic(
          'STYLE_PROJECT_CUSTOM_FILE',
          'warning',
          `${relative} is custom and was not replaced`,
          { file: relative, help: 'Merge the generated scaffold content manually if needed.' },
        ),
      );
    }
  }
  return managedFiles;
}

function planLegacyMigration(report, plan, settings) {
  const viteFilename = path.join(plan.root, settings.viteConfig);
  let viteSource = projectedContent(plan, settings.viteConfig);
  const pluginRelative = 'vite-plugin-lampclaw-style.mjs';
  const clientRelative = 'lampclaw-style-inspector-client.mjs';
  const pluginDigest = fileDigest(path.join(plan.root, pluginRelative));
  const clientDigest = fileDigest(path.join(plan.root, clientRelative));
  const hasLegacyImport = viteSource?.includes(legacyViteImport) ?? false;
  const hasPublicImport =
    (viteSource?.includes(publicViteImport) ?? false) ||
    (viteSource?.includes(migratedLegacyViteImport) ?? false);

  if (hasLegacyImport) {
    if (pluginDigest !== legacyFiles[pluginRelative]) {
      report.diagnostics.push(
        diagnostic(
          'STYLE_PROJECT_LEGACY_CONFLICT',
          'error',
          `${pluginRelative} was customized; the legacy Vite import was not changed`,
          { file: pluginRelative, help: `Import ${publicViteImport.split(' from ')[1]} manually.` },
        ),
      );
      return;
    }
    if (viteSource.split(legacyViteImport).length !== 2) {
      report.diagnostics.push(
        diagnostic(
          'STYLE_PROJECT_LEGACY_CONFLICT',
          'error',
          `${settings.viteConfig} contains more than one legacy tooling import`,
          { file: settings.viteConfig },
        ),
      );
      return;
    }
    viteSource = viteSource.replace(legacyViteImport, migratedLegacyViteImport);
    queueWrite(plan, settings.viteConfig, viteSource);
  }

  const publicIntegration = hasPublicImport || hasLegacyImport;
  if (pluginDigest !== null) {
    if (pluginDigest === legacyFiles[pluginRelative] && publicIntegration) {
      plan.deletes.add(pluginRelative);
    } else if (pluginDigest !== legacyFiles[pluginRelative]) {
      report.diagnostics.push(
        diagnostic(
          'STYLE_PROJECT_LEGACY_CONFLICT',
          'error',
          `${pluginRelative} was customized and was preserved`,
          { file: pluginRelative, help: 'Switch the Vite import manually, then remove the copy.' },
        ),
      );
    } else {
      report.diagnostics.push(
        diagnostic(
          'STYLE_PROJECT_LEGACY_CONFLICT',
          'error',
          `${pluginRelative} is still present without a recognized Vite import`,
          { file: pluginRelative, help: `Use ${publicViteImport}` },
        ),
      );
    }
  }
  if (clientDigest !== null) {
    if (
      clientDigest === legacyFiles[clientRelative] &&
      (plan.deletes.has(pluginRelative) || (pluginDigest === null && publicIntegration))
    ) {
      plan.deletes.add(clientRelative);
    } else if (clientDigest !== legacyFiles[clientRelative]) {
      report.diagnostics.push(
        diagnostic(
          'STYLE_PROJECT_LEGACY_CONFLICT',
          'error',
          `${clientRelative} was customized and was preserved`,
          { file: clientRelative },
        ),
      );
    }
  }
  if (!fs.existsSync(viteFilename) && (pluginDigest !== null || clientDigest !== null)) {
    report.diagnostics.push(
      diagnostic(
        'STYLE_PROJECT_LEGACY_CONFLICT',
        'error',
        'Legacy tooling copies exist but the configured Vite file is missing',
        { file: settings.viteConfig },
      ),
    );
  }
}

export function upgradeProject(options = {}) {
  const report = createReport('upgrade', options.dryRun ?? false);
  const root = path.resolve(options.root ?? process.cwd());
  const plan = mutation(root);
  try {
    if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) {
      throw new ProjectError('STYLE_PROJECT_ROOT', `Project root is not a directory: ${root}`);
    }
    const moon = moonProject(root);
    const hasManifest = fs.existsSync(path.join(root, projectManifestName));
    const previous = hasManifest ? loadProjectManifest(root) : null;
    if (previous !== null) rejectNewerProject(previous);
    const settings = previous ?? defaultSettings(root, moon.name);

    if (fs.existsSync(path.join(root, 'style.config.json'))) validateStyleConfig(root);
    else queueWrite(plan, 'style.config.json', styleConfigTemplate(moon.name));

    planLegacyMigration(report, plan, settings);
    const managedFiles = safelyManageDesiredFiles(
      report,
      plan,
      settings,
      previous?.managedFiles ?? {},
    );
    queueWrite(plan, projectManifestName, manifestContent(settings, managedFiles));
    integrationDiagnostics(report, plan, settings);
    finishReport(report);
    if (!report.passed) return report;

    reportBackupCleanup(report, applyMutation(plan, { dryRun: report.dryRun }));
    if (!report.dryRun) fs.mkdirSync(path.join(root, 'src', 'generated'), { recursive: true });
    report.changedFiles.push(...plan.writes.keys());
    report.removedFiles.push(...plan.deletes);
  } catch (error) {
    addError(report, error);
  }
  return finishReport(report);
}

function checkProjectPackage(report, root) {
  const filename = path.join(root, 'package.json');
  if (!fs.existsSync(filename)) {
    report.diagnostics.push(
      diagnostic('STYLE_PROJECT_NODE_PACKAGE', 'warning', 'package.json was not found', {
        help: 'Install @lampclaw/moonstyle-tooling from a pinned Git revision or local path.',
      }),
    );
    return;
  }
  try {
    const value = readJson(filename, 'STYLE_PROJECT_NODE_PACKAGE');
    const declared =
      value.name === '@lampclaw/moonstyle-tooling' ||
      ['dependencies', 'devDependencies', 'optionalDependencies'].some(
        (field) => value[field]?.['@lampclaw/moonstyle-tooling'] !== undefined,
      );
    if (!declared) {
      report.diagnostics.push(
        diagnostic(
          'STYLE_PROJECT_NODE_PACKAGE',
          'warning',
          '@lampclaw/moonstyle-tooling is not declared in package.json',
          {
            file: 'package.json',
            help: 'Add a pinned Git revision or local path dependency.',
          },
        ),
      );
    }
  } catch (error) {
    addError(report, error, 'STYLE_PROJECT_NODE_PACKAGE');
  }
}

function checkGeneratedOutputs(report, root, styleConfig) {
  for (const [kind, relative] of Object.entries(styleConfig.outputs)) {
    const filename = path.join(root, relative);
    if (!fs.existsSync(filename)) {
      report.diagnostics.push(
        diagnostic(
          'STYLE_PROJECT_OUTPUT_MISSING',
          'warning',
          `Generated ${kind} output is missing`,
          { file: relative, help: 'Run the style extractor or Vite once.' },
        ),
      );
    }
  }
  const bundleFilename = path.join(root, styleConfig.outputs.bundle);
  if (fs.existsSync(bundleFilename)) {
    try {
      const bundle = readJson(bundleFilename, 'STYLE_PROJECT_OUTPUT_SCHEMA');
      if (bundle.schemaVersion !== 13) {
        throw new ProjectError(
          'STYLE_PROJECT_OUTPUT_SCHEMA',
          'Generated style bundle schemaVersion must be 13; re-extract dependencies from source before the application',
          { file: styleConfig.outputs.bundle },
        );
      }
      if (bundle.mappingsPackage !== styleConfig.mappingsPackage) {
        throw new ProjectError(
          'STYLE_PROJECT_OUTPUT_SCHEMA',
          'Generated style bundle mappingsPackage differs from style.config.json',
          { file: styleConfig.outputs.bundle },
        );
      }
    } catch (error) {
      addError(report, error, 'STYLE_PROJECT_OUTPUT_SCHEMA');
    }
  }
}

async function strictChecks(report, root, manifest) {
  const tree = spawnSync('moon', ['tree', '--json'], { cwd: root, encoding: 'utf8' });
  try {
    if (tree.error || tree.status !== 0) throw new Error(tree.error?.message ?? tree.stderr);
    const graph = JSON.parse(tree.stdout);
    const module = moonProject(root);
    const sourceIndex = graph.modules?.findIndex((item) => item.name === module.name);
    const dependency = graph.edges?.find(
      (edge) => edge.from === sourceIndex && edge.name === 'lampclaw/moonstyle',
    );
    const resolved = dependency === undefined ? null : graph.modules[dependency.to];
    if (
      graph.status !== 'success' ||
      !resolved ||
      resolved.name !== 'lampclaw/moonstyle' ||
      !resolved.source?.kind
    ) {
      throw new Error('moon tree did not resolve the project dependency lampclaw/moonstyle');
    }
    if (resolved.source.kind === 'local') modernModule(resolved.source.path);
    report.diagnostics.push(
      diagnostic(
        'STYLE_PROJECT_RESOLVED_DEPENDENCY',
        'info',
        `lampclaw/moonstyle@${resolved.version}: ${resolved.source.kind}${resolved.source.path ? ` (${resolved.source.path})` : ''}`,
      ),
    );
  } catch (error) {
    report.diagnostics.push(
      diagnostic(
        'STYLE_PROJECT_STRICT_RESOLUTION',
        'error',
        error.message || 'moon tree --json failed',
        {
          help: 'Repair the resolved Moon dependency graph before retrying strict validation.',
        },
      ),
    );
    return;
  }
  const checked = spawnSync('moon', ['check', '--target', 'native'], {
    cwd: root,
    encoding: 'utf8',
  });
  if (checked.error !== undefined || checked.status !== 0) {
    report.diagnostics.push(
      diagnostic(
        'STYLE_PROJECT_STRICT_MOON',
        'error',
        (checked.error?.message ?? `${checked.stdout}\n${checked.stderr}`).trim() ||
          'moon check --target native failed',
        { help: 'Fix MoonBit native-target diagnostics before retrying.' },
      ),
    );
    return;
  }
  const extracted = await createExtractorRunner({
    extractorPackage: manifest.extractorPackage,
  })(root, {
    force: true,
    profile: 'release',
    check: true,
    mode: 'check',
    reasons: ['doctor'],
  });
  if (!extracted.ok) {
    const buildFailure = extracted.stage === 'build';
    report.diagnostics.push(
      diagnostic(
        buildFailure ? 'STYLE_PROJECT_STRICT_BUILD' : 'STYLE_PROJECT_STRICT_EXTRACT',
        'error',
        extracted.diagnostics.map((item) => `${item.code}: ${item.message}`).join('; ') ||
          'The release extractor --check failed',
        buildFailure
          ? { file: manifest.extractorPackage }
          : { help: 'Regenerate style artifacts, then rerun doctor --strict.' },
      ),
    );
  }
}

export async function doctorProject(options = {}) {
  const report = createReport('doctor');
  const root = path.resolve(options.root ?? process.cwd());
  let manifest;
  let styleConfig;
  try {
    if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) {
      throw new ProjectError('STYLE_PROJECT_ROOT', `Project root is not a directory: ${root}`);
    }
    const moon = moonProject(root);
    if (!moon.hasStyleDependency) {
      report.diagnostics.push(
        diagnostic(
          'STYLE_PROJECT_MOON_DEPENDENCY',
          'error',
          `${moon.filename} does not declare lampclaw/moonstyle`,
          { file: moon.filename },
        ),
      );
    }
    manifest = loadProjectManifest(root);
    if (compareVersions(manifest.toolingVersion, toolingVersion) > 0) {
      report.diagnostics.push(
        diagnostic(
          'STYLE_PROJECT_TOOLING_NEWER',
          'error',
          `Project tooling ${manifest.toolingVersion} is newer than installed tooling ${toolingVersion}`,
          {
            file: projectManifestName,
            help: 'Install the project tooling version before running doctor.',
          },
        ),
      );
    } else if (manifest.toolingVersion !== toolingVersion) {
      report.diagnostics.push(
        diagnostic(
          'STYLE_PROJECT_TOOLING_VERSION',
          'warning',
          `Project tooling ${manifest.toolingVersion} differs from installed tooling ${toolingVersion}`,
          { file: projectManifestName, help: 'Run moonstyle upgrade.' },
        ),
      );
    }
    styleConfig = validateStyleConfig(root);
    checkProjectPackage(report, root);

    const mainFile = `${manifest.extractorPackage}/main.mbt`;
    const packageFile = `${manifest.extractorPackage}/moon.pkg`;
    const mainSource = fs.existsSync(path.join(root, mainFile))
      ? fs.readFileSync(path.join(root, mainFile), 'utf8')
      : '';
    const packageSource = fs.existsSync(path.join(root, packageFile))
      ? fs.readFileSync(path.join(root, packageFile), 'utf8')
      : '';
    if (!mainSource.includes('@cli.run(')) {
      report.diagnostics.push(
        diagnostic('STYLE_PROJECT_EXTRACTOR', 'error', `${mainFile} does not call @cli.run`, {
          file: mainFile,
        }),
      );
    }
    if (
      !packageSource.includes(`"${manifest.stylesPackage}"`) ||
      !packageSource.includes('"lampclaw/moonstyle/extract/cli"') ||
      !packageSource.includes('supported_targets = "native"')
    ) {
      report.diagnostics.push(
        diagnostic(
          'STYLE_PROJECT_EXTRACTOR',
          'error',
          `${packageFile} does not match the configured native extractor packages`,
          { file: packageFile },
        ),
      );
    }

    const noWrites = mutation(root);
    integrationDiagnostics(report, noWrites, manifest, 'error');
    for (const [relative, expectedDigest] of Object.entries(manifest.managedFiles)) {
      const actualDigest = fileDigest(path.join(root, relative));
      if (actualDigest !== expectedDigest) {
        report.diagnostics.push(
          diagnostic(
            'STYLE_PROJECT_MANAGED_MODIFIED',
            'warning',
            `${relative} differs from its managed hash`,
            { file: relative, help: 'Run upgrade or merge scaffold changes manually.' },
          ),
        );
      }
    }
    for (const relative of Object.keys(legacyFiles)) {
      if (fs.existsSync(path.join(root, relative))) {
        report.diagnostics.push(
          diagnostic(
            'STYLE_PROJECT_LEGACY_COPY',
            'warning',
            `${relative} is a deprecated copied tooling file`,
            {
              file: relative,
              help: `Run upgrade; legacy copies are supported only before ${legacyCompatibilityEndsAt}.`,
            },
          ),
        );
      }
    }
    checkGeneratedOutputs(report, root, styleConfig);
  } catch (error) {
    addError(report, error);
  }
  finishReport(report);
  if (
    (options.strict ?? false) &&
    report.passed &&
    manifest !== undefined &&
    styleConfig !== undefined
  ) {
    await strictChecks(report, root, manifest);
  }
  return finishReport(report);
}

export function renderReport(report, { json = false } = {}) {
  if (json) return `${JSON.stringify(report, null, 2)}\n`;
  const lines = [
    `moonstyle ${report.command}: ${report.passed ? 'passed' : 'failed'}${report.dryRun ? ' (dry run)' : ''}`,
  ];
  for (const filename of report.changedFiles) lines.push(`changed ${filename}`);
  for (const filename of report.removedFiles) lines.push(`removed ${filename}`);
  for (const item of report.diagnostics) {
    lines.push(
      `${item.severity} ${item.code}${item.file === null ? '' : ` (${item.file})`}: ${item.message}`,
    );
    if (item.help !== null) lines.push(`  help: ${item.help}`);
  }
  return `${lines.join('\n')}\n`;
}
