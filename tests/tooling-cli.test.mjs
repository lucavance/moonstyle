import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { stripVTControlCharacters } from 'node:util';
import { test } from 'vite-plus/test';
import {
  doctorProject,
  initProject,
  moonProject,
  projectManifestName,
  upgradeProject,
} from '../tooling/project.mjs';

const root = path.resolve(import.meta.dirname, '..');
const cli = path.join(root, 'tooling', 'cli.mjs');
const sha256 = (content) => createHash('sha256').update(content).digest('hex');

test('modern Moon preflight rejects legacy ambiguity and missing imports before writes', () => {
  const directory = temporaryProject();
  try {
    fs.writeFileSync(path.join(directory, 'moon.mod.json'), '{"name":"legacy/app"}');
    assert.equal(
      initProject({ root: directory }).diagnostics[0].code,
      'STYLE_PROJECT_MOON_CONFLICT',
    );
    assert.equal(fs.existsSync(path.join(directory, projectManifestName)), false);
    fs.unlinkSync(path.join(directory, 'moon.mod'));
    assert.equal(
      upgradeProject({ root: directory }).diagnostics[0].code,
      'STYLE_PROJECT_MOON_LEGACY',
    );
    fs.unlinkSync(path.join(directory, 'moon.mod.json'));
    fs.writeFileSync(
      path.join(directory, 'moon.mod'),
      'name = "modern/app"\n// import { "lampclaw/moonstyle@0.1.0" }\n',
    );
    assert.equal(
      initProject({ root: directory }).diagnostics[0].code,
      'STYLE_PROJECT_MOON_DEPENDENCY',
    );
    assert.equal(fs.existsSync(path.join(directory, 'style.config.json')), false);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('modern Moon resolves nearest ancestor workspace and relative paths containing spaces', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'style workspace '));
  const member = path.join(directory, 'apps', 'my app');
  try {
    fs.mkdirSync(member, { recursive: true });
    fs.writeFileSync(
      path.join(member, 'moon.mod'),
      'name = "modern/app"\nimport { "lampclaw/moonstyle@0.1.0" }\n',
    );
    fs.writeFileSync(path.join(directory, 'moon.work'), 'members = ["apps/my app"]\n');
    assert.deepEqual(moonProject(member).workspace.members, [member]);
    fs.writeFileSync(path.join(directory, 'apps', 'moon.work'), 'members = ["missing"]\n');
    assert.throws(() => moonProject(member), /No moon.mod.*missing/);
    assert.equal(initProject({ root: member }).passed, false);
    assert.equal(fs.existsSync(path.join(member, projectManifestName)), false);
    fs.writeFileSync(path.join(directory, 'apps', 'moon.work'), 'members = ["my app"]\n');
    assert.equal(moonProject(member).workspace.filename, path.join(directory, 'apps', 'moon.work'));
    fs.unlinkSync(path.join(directory, 'apps', 'moon.work'));
    fs.unlinkSync(path.join(directory, 'moon.work'));
    assert.equal(moonProject(member).workspace, null);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

function temporaryProject(name = 'local/tooling-app') {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'lampclaw-tooling-'));
  fs.writeFileSync(
    path.join(directory, 'moon.mod'),
    `name = ${JSON.stringify(name)}\nversion = "0.0.0"\nimport { "lampclaw/moonstyle@0.1.0" }\n`,
  );
  fs.writeFileSync(path.join(directory, 'moon.work'), `members = [".", ${JSON.stringify(root)}]\n`);
  fs.mkdirSync(path.join(directory, 'styles'));
  fs.writeFileSync(path.join(directory, 'styles', 'moon.pkg'), 'import { "lampclaw/moonstyle" }\n');
  fs.writeFileSync(
    path.join(directory, 'styles', 'styles.mbt'),
    [
      '///|',
      'pub fn registry() -> @moonstyle.Registry {',
      `  @moonstyle.registry(${JSON.stringify(name)}, [])`,
      '}',
      '',
    ].join('\n'),
  );
  return directory;
}

function runCli(arguments_, cwd = root) {
  return spawnSync(process.execPath, [cli, ...arguments_], { cwd, encoding: 'utf8' });
}

function jsonEventStream(child) {
  let buffer = '';
  let stderr = '';
  const events = [];
  const waiters = [];
  const settle = (event) => {
    for (let index = waiters.length - 1; index >= 0; index -= 1) {
      const waiter = waiters[index];
      if (!waiter.predicate(event)) continue;
      waiters.splice(index, 1);
      clearTimeout(waiter.timer);
      waiter.resolve(event);
    }
  };
  child.stdout.setEncoding('utf8');
  child.stdout.on('data', (chunk) => {
    buffer += chunk;
    for (;;) {
      const newline = buffer.indexOf('\n');
      if (newline < 0) break;
      const line = buffer.slice(0, newline).trim();
      buffer = buffer.slice(newline + 1);
      if (line === '') continue;
      const event = JSON.parse(line);
      events.push(event);
      settle(event);
    }
  });
  child.stderr.setEncoding('utf8');
  child.stderr.on('data', (chunk) => {
    stderr += chunk;
  });
  child.on('exit', (code, signal) => {
    for (const waiter of waiters.splice(0)) {
      clearTimeout(waiter.timer);
      waiter.reject(
        new Error(
          `watch exited before the expected event (code ${code}, signal ${signal}): ${stderr}`,
        ),
      );
    }
  });
  return {
    events,
    stderr: () => stderr,
    waitFor(predicate, timeoutMs = 30_000) {
      const existing = events.find(predicate);
      if (existing !== undefined) return Promise.resolve(existing);
      return new Promise((resolve, reject) => {
        const waiter = { predicate, resolve, reject, timer: null };
        waiter.timer = setTimeout(() => {
          const index = waiters.indexOf(waiter);
          if (index >= 0) waiters.splice(index, 1);
          reject(new Error(`Timed out waiting for watch event: ${stderr}`));
        }, timeoutMs);
        waiters.push(waiter);
      });
    },
  };
}

function legacyPluginSource() {
  return fs.readFileSync(
    path.join(root, 'tests', 'fixtures', 'protocol-v0-vite-plugin.mjs'),
    'utf8',
  );
}

test('watch follows a parent module source directory and recovers from its compiler errors', async () => {
  const parent = fs.mkdtempSync(path.join(os.tmpdir(), 'moonstyle-parent-'));
  const directory = path.join(parent, 'validation');
  fs.renameSync(temporaryProject('local/parent-app'), directory);
  let child;
  try {
    fs.unlinkSync(path.join(directory, 'moon.work'));
    fs.writeFileSync(
      path.join(parent, 'moon.work'),
      `members = [".", "validation", ${JSON.stringify(root)}]\n`,
    );
    fs.writeFileSync(
      path.join(parent, 'moon.mod'),
      'name = "local/parent-theme"\nversion = "0.0.0"\nsource = "src"\nimport { "lampclaw/moonstyle@0.1.0" }\n',
    );
    fs.mkdirSync(path.join(parent, 'src'));
    fs.writeFileSync(path.join(parent, 'src/moon.pkg'), 'import { "lampclaw/moonstyle" }\n');
    const theme = path.join(parent, 'src/theme.mbt');
    const original = '///|\npub fn paint() -> @moonstyle.Color { @moonstyle.rgb(1, 2, 3) }\n';
    fs.writeFileSync(theme, original);
    const manifest = path.join(directory, 'moon.mod');
    fs.writeFileSync(
      manifest,
      fs.readFileSync(manifest, 'utf8').replace('import {', 'import { "local/parent-theme@0.0.0",'),
    );
    fs.writeFileSync(
      path.join(directory, 'styles/moon.pkg'),
      'import { "lampclaw/moonstyle", "local/parent-theme" @theme }\n',
    );
    fs.writeFileSync(
      path.join(directory, 'styles/styles.mbt'),
      '///|\npub fn registry() -> @moonstyle.Registry { @moonstyle.registry("local/parent-app", [@moonstyle.rule("box").color(@theme.paint())]) }\n',
    );
    assert.equal(initProject({ root: directory }).passed, true);
    child = spawn(process.execPath, [cli, 'watch', '--root', directory, '--json'], {
      cwd: directory,
    });
    const stream = jsonEventStream(child);
    const initial = await stream.waitFor((event) => event.event === 'watch-cycle' && event.passed);
    const css = path.join(directory, 'src/generated/styles.generated.css');
    const before = fs.readFileSync(css, 'utf8');
    const changed = original.replace('rgb(1, 2, 3)', 'rgb(50, 60, 70)');
    fs.writeFileSync(theme, changed);
    const updated = await stream.waitFor(
      (event) => event.event === 'watch-cycle' && event.sequence > initial.sequence && event.passed,
    );
    assert.notEqual(fs.readFileSync(css, 'utf8'), before);
    const valid = fs.readFileSync(css, 'utf8');
    fs.writeFileSync(theme, changed.replace('rgb(50, 60, 70)', 'rgb("invalid", 60, 70)'));
    const failure = await stream.waitFor(
      (event) =>
        event.event === 'watch-cycle' && event.sequence > updated.sequence && !event.passed,
    );
    assert.ok(
      failure.diagnostics.some(
        (diagnostic) => diagnostic.file?.endsWith('src/theme.mbt') && diagnostic.line > 0,
      ),
    );
    assert.equal(fs.readFileSync(css, 'utf8'), valid);
    fs.writeFileSync(theme, changed);
    await stream.waitFor(
      (event) => event.event === 'watch-cycle' && event.sequence > failure.sequence && event.passed,
    );
    assert.equal(fs.readFileSync(css, 'utf8'), valid);
    const exited = new Promise((resolve) => child.once('exit', (code) => resolve(code)));
    child.kill('SIGINT');
    assert.equal(await exited, 0);
    child = null;
    // Stopping while the initial extraction is running must not recreate
    // parent watchers when that extraction eventually finishes.
    child = spawn(process.execPath, [cli, 'watch', '--root', directory, '--json'], {
      cwd: directory,
    });
    const stopping = jsonEventStream(child);
    await stopping.waitFor((event) => event.event === 'watch-start');
    const stopped = new Promise((resolve, reject) => {
      const timer = setTimeout(
        () => reject(new Error('watch did not stop during extraction')),
        30_000,
      );
      child.once('exit', (code) => {
        clearTimeout(timer);
        resolve(code);
      });
    });
    child.kill('SIGINT');
    assert.equal(await stopped, 0);
    child = null;
  } finally {
    child?.kill('SIGKILL');
    fs.rmSync(parent, { recursive: true, force: true });
  }
});

test('init is idempotent, preserves custom integration files, and reports stable CLI JSON', async () => {
  const directory = temporaryProject();
  try {
    const customVite = 'export default { plugins: [] };\n';
    const customEntry = "console.log('application');\n";
    fs.writeFileSync(path.join(directory, 'vite.config.mjs'), customVite);
    fs.writeFileSync(path.join(directory, 'entry.mjs'), customEntry);

    const result = runCli(['init', '--root', directory, '--json']);
    assert.equal(result.status, 0, result.stderr);
    const report = JSON.parse(result.stdout);
    assert.equal(report.schemaVersion, 1);
    assert.equal(report.command, 'init');
    assert.equal(report.toolingVersion, '0.1.0');
    assert.equal(report.passed, true);
    assert.deepEqual(
      report.diagnostics.map((item) => item.code),
      ['STYLE_PROJECT_VITE_INTEGRATION', 'STYLE_PROJECT_ENTRY_INTEGRATION'],
    );
    assert.equal(fs.readFileSync(path.join(directory, 'vite.config.mjs'), 'utf8'), customVite);
    assert.equal(fs.readFileSync(path.join(directory, 'entry.mjs'), 'utf8'), customEntry);

    const manifest = JSON.parse(fs.readFileSync(path.join(directory, projectManifestName), 'utf8'));
    assert.deepEqual(Object.keys(manifest), [
      'schemaVersion',
      'toolingVersion',
      'stylesPackage',
      'extractorPackage',
      'viteConfig',
      'entrypoints',
      'managedFiles',
    ]);
    assert.equal(manifest.managedFiles['vite.config.mjs'], undefined);
    assert.equal(manifest.managedFiles['entry.mjs'], undefined);

    const repeated = initProject({ root: directory });
    assert.equal(repeated.passed, true);
    assert.deepEqual(repeated.changedFiles, []);

    const unhealthy = await doctorProject({ root: directory });
    assert.equal(unhealthy.passed, false);
    assert.ok(unhealthy.diagnostics.some((item) => item.code === 'STYLE_PROJECT_VITE_INTEGRATION'));

    fs.writeFileSync(
      path.join(directory, 'vite.config.mjs'),
      [
        "import moonStyle from '@lampclaw/moonstyle-tooling/vite';",
        'export default { plugins: [moonStyle()] };',
        '',
      ].join('\n'),
    );
    fs.writeFileSync(
      path.join(directory, 'entry.mjs'),
      "import 'virtual:moonstyle.css';\nconsole.log('application');\n",
    );
    const healthy = await doctorProject({ root: directory });
    assert.equal(healthy.passed, true);
    assert.ok(healthy.diagnostics.some((item) => item.code === 'STYLE_PROJECT_NODE_PACKAGE'));

    fs.appendFileSync(path.join(directory, '.vscode', 'tasks.json'), '\n');
    const customized = await doctorProject({ root: directory });
    assert.equal(customized.passed, true);
    assert.ok(
      customized.diagnostics.some((item) => item.code === 'STYLE_PROJECT_MANAGED_MODIFIED'),
    );

    const usageFailure = runCli(['doctor', '--root', directory, '--unknown']);
    assert.equal(usageFailure.status, 2);
    assert.match(usageFailure.stderr, /Unknown option/);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('init derives moon.mod projects and honors contained custom paths', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'lampclaw-legacy-manifest-'));
  try {
    fs.writeFileSync(
      path.join(directory, 'moon.mod'),
      [
        'name = "local/legacy-manifest"',
        'version = "0.0.0"',
        'import { "lampclaw/moonstyle@0.1.0" }',
        '',
      ].join('\n'),
    );
    const report = initProject({
      root: directory,
      stylesPackage: 'local/legacy-manifest/theme',
      extractorPackage: 'tools/style_extractor',
      viteConfig: 'config/vite.config.mjs',
      entrypoints: ['web/main.mjs', 'web/admin.mjs'],
    });
    assert.equal(report.passed, true);
    const manifest = JSON.parse(fs.readFileSync(path.join(directory, projectManifestName), 'utf8'));
    assert.equal(manifest.stylesPackage, 'local/legacy-manifest/theme');
    assert.equal(manifest.extractorPackage, 'tools/style_extractor');
    assert.equal(manifest.viteConfig, 'config/vite.config.mjs');
    assert.deepEqual(manifest.entrypoints, ['web/main.mjs', 'web/admin.mjs']);
    assert.match(
      fs.readFileSync(path.join(directory, 'tools', 'style_extractor', 'moon.pkg'), 'utf8'),
      /"local\/legacy-manifest\/theme"/,
    );
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('generate writes formal outputs and check detects stale artifacts without replacing them', async () => {
  const directory = temporaryProject('local/command-app');
  try {
    assert.equal(initProject({ root: directory }).passed, true);

    const generated = runCli(['generate', '--root', directory, '--json']);
    assert.equal(generated.status, 0, `${generated.stdout}${generated.stderr}`);
    const generatedReport = JSON.parse(generated.stdout);
    assert.equal(generatedReport.schemaVersion, 1);
    assert.equal(generatedReport.command, 'generate');
    assert.equal(generatedReport.passed, true);
    assert.equal(generatedReport.extraction.profile, 'release');
    assert.equal(generatedReport.extraction.stage, 'complete');
    assert.equal(generatedReport.extraction.executed, true);
    assert.deepEqual(
      generatedReport.extraction.outputs.map((output) => output.kind),
      ['css', 'mappings', 'mappingsManifest', 'bundle'],
    );
    assert.equal(generatedReport.extraction.timingsMs.totalMs > 0, true);
    for (const output of generatedReport.extraction.outputs) {
      assert.equal(fs.existsSync(path.join(directory, output.path)), true, output.path);
    }

    const repeated = runCli(['generate', '--root', directory, '--json']);
    assert.equal(repeated.status, 0, repeated.stderr);
    assert.deepEqual(JSON.parse(repeated.stdout).changedFiles, []);

    const checked = runCli(['check', '--root', directory, '--json']);
    assert.equal(checked.status, 0, checked.stderr);
    const checkedReport = JSON.parse(checked.stdout);
    assert.equal(checkedReport.command, 'check');
    assert.equal(checkedReport.extraction.cacheStatus, 'verification');
    assert.deepEqual(checkedReport.changedFiles, []);

    const cssFilename = path.join(directory, 'src', 'generated', 'styles.generated.css');
    const staleCss = `${fs.readFileSync(cssFilename, 'utf8')}/* project drift */\n`;
    fs.writeFileSync(cssFilename, staleCss);
    const stale = runCli(['check', '--root', directory, '--json']);
    assert.equal(stale.status, 1, stale.stderr);
    const staleReport = JSON.parse(stale.stdout);
    assert.equal(staleReport.passed, false);
    assert.ok(staleReport.diagnostics.some((diagnostic) => diagnostic.severity === 'error'));
    assert.equal(fs.readFileSync(cssFilename, 'utf8'), staleCss);

    const repaired = runCli(['generate', '--root', directory, '--json']);
    assert.equal(repaired.status, 0, repaired.stderr);
    assert.ok(
      JSON.parse(repaired.stdout).changedFiles.includes('src/generated/styles.generated.css'),
    );
    assert.doesNotMatch(fs.readFileSync(cssFilename, 'utf8'), /project drift/);

    const incompatible = runCli(['generate', '--root', directory, '--json', '--verbose']);
    assert.equal(incompatible.status, 2);
    assert.match(incompatible.stderr, /cannot be combined/);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('watch emits NDJSON cycles, retains valid outputs on failure, and recovers', async () => {
  const directory = temporaryProject('local/watch-app');
  let child;
  try {
    assert.equal(initProject({ root: directory }).passed, true);
    const generated = runCli(['generate', '--root', directory, '--json']);
    assert.equal(generated.status, 0, `${generated.stdout}${generated.stderr}`);

    child = spawn(process.execPath, [cli, 'watch', '--root', directory, '--json'], {
      cwd: directory,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    const stream = jsonEventStream(child);
    const started = await stream.waitFor((event) => event.event === 'watch-start');
    assert.equal(started.resolved.extractorPackage, 'style_extractor');
    const initial = await stream.waitFor(
      (event) => event.event === 'watch-cycle' && event.sequence === 1,
    );
    assert.equal(initial.passed, true);
    assert.equal(initial.extraction.profile, 'debug');
    assert.deepEqual(initial.extraction.reasons, ['initial']);

    const stylesFilename = path.join(directory, 'styles', 'styles.mbt');
    const original = fs.readFileSync(stylesFilename, 'utf8');
    const styled = original.replace(
      '@moonstyle.registry("local/watch-app", [])',
      '@moonstyle.registry("local/watch-app", [@moonstyle.rule("root").width(@moonstyle.px(4))])',
    );
    assert.notEqual(styled, original);
    fs.writeFileSync(stylesFilename, styled);
    const changed = await stream.waitFor(
      (event) =>
        event.event === 'watch-cycle' &&
        event.sequence > initial.sequence &&
        event.extraction.reasons.includes('source-change'),
    );
    assert.equal(changed.passed, true);
    assert.ok(changed.changedFiles.includes('src/generated/styles.generated.css'));

    const artifactFiles = changed.extraction.outputs.map((output) =>
      path.join(directory, output.path),
    );
    const validArtifacts = artifactFiles.map((filename) => fs.readFileSync(filename, 'utf8'));
    fs.writeFileSync(stylesFilename, `${styled}\nlet invalid_watch : Int = "wrong"\n`);
    const failed = await stream.waitFor(
      (event) =>
        event.event === 'watch-cycle' && event.sequence > changed.sequence && !event.passed,
    );
    assert.equal(failed.extraction.stage, 'build');
    assert.deepEqual(
      artifactFiles.map((filename) => fs.readFileSync(filename, 'utf8')),
      validArtifacts,
    );

    fs.writeFileSync(stylesFilename, styled);
    const recovered = await stream.waitFor(
      (event) => event.event === 'watch-cycle' && event.sequence > failed.sequence && event.passed,
    );
    assert.ok(recovered.extraction.reasons.includes('source-change'));

    const dependencyDirectory = path.join(directory, 'dependencies');
    fs.mkdirSync(dependencyDirectory);
    const dependencyFilename = path.join(dependencyDirectory, 'component-a.bundle.json');
    fs.copyFileSync(
      path.join(root, 'validation', 'tests', 'dependency-fixtures', 'component-a.bundle.json'),
      dependencyFilename,
    );
    const dependencyBundle = JSON.parse(fs.readFileSync(dependencyFilename, 'utf8'));
    const withDependency = styled.replace(
      '@moonstyle.registry("local/watch-app", [@moonstyle.rule("root").width(@moonstyle.px(4))])',
      `@moonstyle.registry("local/watch-app", [@moonstyle.rule("root").width(@moonstyle.px(4))], dependencies=[@moonstyle.dependency_ref(${JSON.stringify(dependencyBundle.module)}, ${JSON.stringify(dependencyBundle.semanticDigest)})])`,
    );
    assert.notEqual(withDependency, styled);
    const configFilename = path.join(directory, 'style.config.json');
    const config = JSON.parse(fs.readFileSync(configFilename, 'utf8'));
    config.dependencyRoots = ['dependencies'];
    config.cacheDirectory = '_build/style-cache-watch';
    fs.writeFileSync(stylesFilename, withDependency);
    fs.writeFileSync(configFilename, `${JSON.stringify(config, null, 2)}\n`);
    const reconfigured = await stream.waitFor(
      (event) =>
        event.event === 'watch-cycle' &&
        event.sequence > recovered.sequence &&
        event.extraction.reasons.includes('config-change'),
    );
    assert.equal(reconfigured.passed, true, JSON.stringify(reconfigured.diagnostics, null, 2));
    assert.deepEqual(reconfigured.extraction.resolved.dependencyBundles, [
      'dependencies/component-a.bundle.json',
    ]);

    const configuredArtifacts = artifactFiles.map((filename) => fs.readFileSync(filename, 'utf8'));
    const touchedAt = new Date(Date.now() + 2_000);
    fs.utimesSync(dependencyFilename, touchedAt, touchedAt);
    const dependencyChanged = await stream.waitFor(
      (event) =>
        event.event === 'watch-cycle' &&
        event.sequence > reconfigured.sequence &&
        event.extraction.reasons.includes('dependency-change'),
    );
    assert.equal(dependencyChanged.passed, false);
    assert.ok(
      dependencyChanged.diagnostics.some((diagnostic) => diagnostic.code === 'STYLE_TOOLCHAIN'),
    );
    assert.deepEqual(
      artifactFiles.map((filename) => fs.readFileSync(filename, 'utf8')),
      configuredArtifacts,
    );

    const exited = new Promise((resolve) =>
      child.once('exit', (code, signal) => resolve({ code, signal })),
    );
    child.kill('SIGINT');
    const stopped = await stream.waitFor((event) => event.event === 'watch-stop');
    assert.equal(stopped.signal, 'SIGINT');
    assert.deepEqual(await exited, { code: 0, signal: null });
    assert.equal(stream.stderr(), '');
    child = null;
  } finally {
    child?.kill('SIGKILL');
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('project manifest rejects escaping paths and unknown schema keys before mutation', async () => {
  const directory = temporaryProject('local/schema-app');
  const outside = fs.mkdtempSync(path.join(os.tmpdir(), 'lampclaw-outside-'));
  try {
    const missingManifest = runCli(['doctor', '--root', directory, '--json']);
    assert.equal(missingManifest.status, 1);
    assert.equal(missingManifest.stderr, '');
    assert.equal(JSON.parse(missingManifest.stdout).diagnostics[0].code, 'STYLE_PROJECT_MANIFEST');

    const escaping = initProject({ root: directory, entrypoints: ['../outside.mjs'] });
    assert.equal(escaping.passed, false);
    assert.ok(escaping.diagnostics.some((item) => item.code === 'STYLE_PROJECT_PATH'));
    assert.equal(fs.existsSync(path.join(directory, projectManifestName)), false);

    const linked = path.join(directory, 'linked');
    fs.symlinkSync(outside, linked, 'dir');
    const symlinkEscape = initProject({ root: directory, extractorPackage: 'linked/extractor' });
    assert.equal(symlinkEscape.passed, false);
    assert.ok(symlinkEscape.diagnostics.some((item) => item.code === 'STYLE_PROJECT_PATH'));
    assert.equal(fs.existsSync(path.join(outside, 'extractor')), false);
    fs.unlinkSync(linked);

    assert.equal(initProject({ root: directory }).passed, true);
    const filename = path.join(directory, projectManifestName);
    const manifest = JSON.parse(fs.readFileSync(filename, 'utf8'));
    fs.writeFileSync(
      filename,
      `${JSON.stringify({ ...manifest, toolingVersion: '9.9.9' }, null, 2)}\n`,
    );
    const downgrade = upgradeProject({ root: directory });
    assert.equal(downgrade.passed, false);
    assert.ok(downgrade.diagnostics.some((item) => item.code === 'STYLE_PROJECT_TOOLING_NEWER'));
    assert.equal(JSON.parse(fs.readFileSync(filename, 'utf8')).toolingVersion, '9.9.9');

    fs.writeFileSync(filename, `${JSON.stringify({ ...manifest, extra: true }, null, 2)}\n`);
    const diagnosed = await doctorProject({ root: directory });
    assert.equal(diagnosed.passed, false);
    assert.ok(diagnosed.diagnostics.some((item) => item.code === 'STYLE_PROJECT_SCHEMA'));
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
    fs.rmSync(outside, { recursive: true, force: true });
  }
});

test('upgrade dry-run and transaction migrate only exact legacy tooling copies', () => {
  const directory = temporaryProject('local/legacy-app');
  try {
    const initialized = initProject({ root: directory });
    assert.equal(initialized.passed, true);
    fs.rmSync(path.join(directory, projectManifestName));
    const oldPlugin = legacyPluginSource();
    assert.equal(
      sha256(oldPlugin),
      '776e2b2cd1934a36636ee4d7e39fbb38480bed949376473a6c2d6a01bf4b38a4',
    );
    fs.writeFileSync(path.join(directory, 'vite-plugin-lampclaw-style.mjs'), oldPlugin);
    fs.copyFileSync(
      path.join(root, 'tests', 'fixtures', 'protocol-v0-inspector-client.mjs'),
      path.join(directory, 'lampclaw-style-inspector-client.mjs'),
    );
    const viteFilename = path.join(directory, 'vite.config.mjs');
    fs.writeFileSync(
      viteFilename,
      fs
        .readFileSync(viteFilename, 'utf8')
        .replace(
          "import moonStyle from '@lampclaw/moonstyle-tooling/vite';",
          "import lampclawStyle from './vite-plugin-lampclaw-style.mjs';",
        )
        .replaceAll('moonStyle(', 'lampclawStyle('),
    );

    const before = fs.readFileSync(viteFilename, 'utf8');
    const dryRun = upgradeProject({ root: directory, dryRun: true });
    assert.equal(dryRun.passed, true);
    assert.equal(dryRun.dryRun, true);
    assert.ok(dryRun.changedFiles.includes(projectManifestName));
    assert.deepEqual(dryRun.removedFiles, [
      'lampclaw-style-inspector-client.mjs',
      'vite-plugin-lampclaw-style.mjs',
    ]);
    assert.equal(fs.readFileSync(viteFilename, 'utf8'), before);
    assert.equal(fs.existsSync(path.join(directory, projectManifestName)), false);

    const upgraded = upgradeProject({ root: directory });
    assert.equal(upgraded.passed, true);
    assert.match(fs.readFileSync(viteFilename, 'utf8'), /plugins: \[lampclawStyle\(/);
    assert.match(
      fs.readFileSync(viteFilename, 'utf8'),
      /from '@lampclaw\/moonstyle-tooling\/vite'/,
    );
    assert.equal(fs.existsSync(path.join(directory, 'vite-plugin-lampclaw-style.mjs')), false);
    assert.equal(fs.existsSync(path.join(directory, 'lampclaw-style-inspector-client.mjs')), false);
    assert.equal(fs.existsSync(path.join(directory, projectManifestName)), true);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('upgrade preserves a customized legacy plugin and aborts the whole transaction', () => {
  const directory = temporaryProject('local/custom-legacy-app');
  try {
    assert.equal(initProject({ root: directory }).passed, true);
    fs.rmSync(path.join(directory, projectManifestName));
    fs.writeFileSync(
      path.join(directory, 'vite-plugin-lampclaw-style.mjs'),
      `${legacyPluginSource()}\n// project customization\n`,
    );
    const viteFilename = path.join(directory, 'vite.config.mjs');
    const legacyVite = fs
      .readFileSync(viteFilename, 'utf8')
      .replace(
        "import moonStyle from '@lampclaw/moonstyle-tooling/vite';",
        "import lampclawStyle from './vite-plugin-lampclaw-style.mjs';",
      )
      .replaceAll('moonStyle(', 'lampclawStyle(');
    fs.writeFileSync(viteFilename, legacyVite);

    const upgraded = upgradeProject({ root: directory });
    assert.equal(upgraded.passed, false);
    assert.deepEqual(upgraded.changedFiles, []);
    assert.ok(upgraded.diagnostics.some((item) => item.code === 'STYLE_PROJECT_LEGACY_CONFLICT'));
    assert.equal(fs.readFileSync(viteFilename, 'utf8'), legacyVite);
    assert.equal(fs.existsSync(path.join(directory, projectManifestName)), false);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('packed Git/path tooling exposes Vite and the complete CLI extraction loop', async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'lampclaw-package-'));
  let watched;
  try {
    const packed = spawnSync(
      'npm',
      ['pack', '--json', '--ignore-scripts', '--pack-destination', directory],
      { cwd: root, encoding: 'utf8' },
    );
    assert.equal(packed.status, 0, `${packed.stdout}${packed.stderr}`);
    const [{ filename }] = JSON.parse(packed.stdout);
    const tarball = path.join(directory, filename);
    const consumer = path.join(directory, 'consumer');
    fs.mkdirSync(consumer);
    fs.writeFileSync(
      path.join(consumer, 'package.json'),
      `${JSON.stringify(
        {
          name: 'tooling-packed-consumer',
          private: true,
          type: 'module',
          dependencies: { '@lampclaw/moonstyle-tooling': `file:${tarball}` },
        },
        null,
        2,
      )}\n`,
    );
    const installed = spawnSync(
      'npm',
      ['install', '--ignore-scripts', '--legacy-peer-deps', '--no-package-lock'],
      { cwd: consumer, encoding: 'utf8' },
    );
    assert.equal(installed.status, 0, `${installed.stdout}${installed.stderr}`);
    const imported = spawnSync(
      process.execPath,
      [
        '--input-type=module',
        '--eval',
        "import plugin, { toolingProtocolVersion } from '@lampclaw/moonstyle-tooling/vite'; console.log(plugin().name, toolingProtocolVersion);",
      ],
      { cwd: consumer, encoding: 'utf8' },
    );
    assert.equal(imported.status, 0, `${imported.stdout}${imported.stderr}`);
    assert.equal(stripVTControlCharacters(imported.stdout).trim(), 'moonstyle 1');
    const executable = spawnSync(
      path.join(consumer, 'node_modules', '.bin', 'moonstyle'),
      ['--help'],
      { cwd: consumer, encoding: 'utf8' },
    );
    assert.equal(executable.status, 0, `${executable.stdout}${executable.stderr}`);
    assert.match(executable.stdout, /moonstyle <command>/);

    const project = path.join(directory, 'packed-project');
    fs.mkdirSync(project);
    fs.writeFileSync(
      path.join(project, 'moon.mod'),
      'name = "local/packed-project"\nversion = "0.0.0"\nimport { "lampclaw/moonstyle@0.1.0" }\n',
    );
    fs.writeFileSync(path.join(project, 'moon.work'), `members = [".", ${JSON.stringify(root)}]\n`);
    fs.mkdirSync(path.join(project, 'styles'));
    fs.writeFileSync(path.join(project, 'styles', 'moon.pkg'), 'import { "lampclaw/moonstyle" }\n');
    fs.writeFileSync(
      path.join(project, 'styles', 'styles.mbt'),
      [
        '///|',
        'pub fn registry() -> @moonstyle.Registry {',
        '  @moonstyle.registry("local/packed-project", [])',
        '}',
        '',
      ].join('\n'),
    );
    const packedCli = path.join(consumer, 'node_modules', '.bin', 'moonstyle');
    const initialized = spawnSync(packedCli, ['init', '--root', project, '--json'], {
      cwd: consumer,
      encoding: 'utf8',
    });
    assert.equal(initialized.status, 0, `${initialized.stdout}${initialized.stderr}`);
    assert.equal(JSON.parse(initialized.stdout).passed, true);
    assert.equal(fs.existsSync(path.join(project, '.vscode', 'tasks.json')), true);
    assert.match(
      fs.readFileSync(path.join(project, 'style_extractor', 'moon.pkg'), 'utf8'),
      /"local\/packed-project\/styles"/,
    );
    assert.equal(fs.existsSync(path.join(project, projectManifestName)), true);

    const generated = spawnSync(packedCli, ['generate', '--root', project, '--json'], {
      cwd: consumer,
      encoding: 'utf8',
    });
    assert.equal(generated.status, 0, `${generated.stdout}${generated.stderr}`);
    assert.equal(JSON.parse(generated.stdout).extraction.outputs.length, 4);
    const checked = spawnSync(packedCli, ['check', '--root', project, '--json'], {
      cwd: consumer,
      encoding: 'utf8',
    });
    assert.equal(checked.status, 0, `${checked.stdout}${checked.stderr}`);

    watched = spawn(packedCli, ['watch', '--root', project, '--json'], {
      cwd: consumer,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    const stream = jsonEventStream(watched);
    await stream.waitFor(
      (event) => event.event === 'watch-cycle' && event.sequence === 1 && event.passed,
    );
    const exited = new Promise((resolve) => watched.once('exit', (code) => resolve(code)));
    watched.kill('SIGINT');
    await stream.waitFor((event) => event.event === 'watch-stop');
    assert.equal(await exited, 0);
    watched = null;
  } finally {
    watched?.kill('SIGKILL');
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
