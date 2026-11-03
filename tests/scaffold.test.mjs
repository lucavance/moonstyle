import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createServer } from 'vite-plus';
import { test } from 'vite-plus/test';
import { scaffold } from '../tools/scaffold.mjs';
import { doctorProject } from '../tooling/project.mjs';
import plugin, { createExtractorRunner } from '../tooling/vite-plugin-moonstyle.mjs';

const root = path.resolve(import.meta.dirname, '..');
process.env.PLAYWRIGHT_BROWSERS_PATH ??= path.join(root, '.cache', 'playwright');
const { chromium } = await import('playwright');

// This cold consumer compiles both native profiles and exercises browser recovery.
test('project init creates a buildable path consumer without copied JavaScript tooling', async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'style-scaffold-'));
  try {
    fs.writeFileSync(
      path.join(directory, 'moon.mod'),
      'name = "local/scaffold-app"\nversion = "0.0.0"\nimport { "lampclaw/moonstyle@0.1.0" }\n',
    );
    fs.writeFileSync(
      path.join(directory, 'moon.work'),
      `members = [".", ${JSON.stringify(root)}]\n`,
    );
    fs.mkdirSync(path.join(directory, 'styles'));
    fs.writeFileSync(
      path.join(directory, 'styles', 'moon.pkg'),
      'import { "lampclaw/moonstyle" }\n',
    );
    fs.writeFileSync(
      path.join(directory, 'styles', 'styles.mbt'),
      [
        '///|',
        'let variables : @moonstyle.VariableScope = @moonstyle.variable_scope("scaffold")',
        '',
        '///|',
        'let width : @moonstyle.LengthToken = variables.length_token("width", @moonstyle.px(8))',
        '',
        '///|',
        'let root_contract : @moonstyle.StyleContract = @moonstyle.style_contract("root")',
        '  .allow_width(tokens=[width])',
        '',
        '///|',
        'pub fn registry() -> @moonstyle.Registry {',
        '  @moonstyle.registry("local/scaffold-app", [',
        '    @moonstyle.rule("root")',
        '      .width(width)',
        '      .padding(@moonstyle.px(4), when=@moonstyle.max_width(@moonstyle.px(640))),',
        '  ], contracts=[root_contract])',
        '}',
        '',
      ].join('\n'),
    );
    fs.mkdirSync(path.join(directory, 'consumer'));
    const consumerManifest = 'import { "lampclaw/moonstyle" @moonstyle }\n';
    fs.writeFileSync(path.join(directory, 'consumer', 'moon.pkg'), consumerManifest);
    fs.writeFileSync(
      path.join(directory, 'consumer', 'consumer.mbt'),
      [
        '///|',
        'fn compose() -> Result[@moonstyle.AppliedStyle, Array[@moonstyle.DynamicValueError]] {',
        '  @moonstyle.style_list().resolve()',
        '}',
        '',
      ].join('\n'),
    );
    assert.doesNotMatch(consumerManifest, /style\/(runtime|values)/);

    const initialized = scaffold(directory);
    assert.equal(initialized.passed, true);
    const extractorManifest = fs.readFileSync(
      path.join(directory, 'style_extractor', 'moon.pkg'),
      'utf8',
    );
    assert.match(extractorManifest, /local\/scaffold-app\/styles/);
    assert.doesNotMatch(extractorManifest, /__APP_MODULE__/);
    assert.equal(fs.existsSync(path.join(directory, 'style.config.json')), true);
    const styleConfig = JSON.parse(
      fs.readFileSync(path.join(directory, 'style.config.json'), 'utf8'),
    );
    assert.deepEqual(styleConfig, {
      schemaVersion: 1,
      mappingsPackage: 'local/scaffold-app/src/generated',
      outputs: {
        css: 'src/generated/styles.generated.css',
        mappings: 'src/generated/styles.generated.mbt',
        mappingsManifest: 'src/generated/moon.pkg',
        bundle: 'src/generated/styles.bundle.json',
      },
      dependencyRoots: [],
      cacheDirectory: '_build/style-cache',
    });
    assert.equal(fs.existsSync(path.join(directory, 'vite-plugin-moonstyle.mjs')), false);
    assert.equal(fs.existsSync(path.join(directory, 'moonstyle-inspector-client.mjs')), false);
    const projectManifest = JSON.parse(
      fs.readFileSync(path.join(directory, '.moonstyle.json'), 'utf8'),
    );
    assert.equal(projectManifest.schemaVersion, 1);
    assert.equal(projectManifest.toolingVersion, '0.1.0');
    assert.equal(projectManifest.stylesPackage, 'local/scaffold-app/styles');
    assert.equal(projectManifest.extractorPackage, 'style_extractor');
    assert.deepEqual(projectManifest.entrypoints, ['entry.mjs']);
    assert.match(projectManifest.managedFiles['style_extractor/main.mbt'], /^sha256:/);
    assert.equal(fs.existsSync(path.join(directory, '.vscode', 'tasks.json')), true);
    const editorTask = JSON.parse(
      fs.readFileSync(path.join(directory, '.vscode', 'tasks.json'), 'utf8'),
    ).tasks[0];
    assert.equal(editorTask.command, 'vp');
    assert.deepEqual(editorTask.args, ['dev']);
    assert.equal(editorTask.isBackground, true);
    assert.equal(
      editorTask.problemMatcher.background.beginsPattern,
      '^\\[moonstyle\\] check-start$',
    );
    assert.equal(editorTask.problemMatcher.background.endsPattern, '^\\[moonstyle\\] check-end$');
    const repeated = scaffold(directory);
    assert.equal(repeated.passed, true);
    assert.deepEqual(repeated.changedFiles, []);

    const extracted = spawnSync(
      'moon',
      [
        'run',
        'style_extractor',
        '--target',
        'native',
        '--release',
        '--',
        '--tooling-protocol',
        '1',
        '--no-cache',
        '--mappings-package',
        'local/scaffold-app/src/generated',
      ],
      { cwd: directory, encoding: 'utf8' },
    );
    assert.equal(extracted.status, 0, `${extracted.stdout}${extracted.stderr}`);
    const generatedManifest = fs.readFileSync(
      path.join(directory, 'src', 'generated', 'moon.pkg'),
      'utf8',
    );
    const generatedMappings = fs.readFileSync(
      path.join(directory, 'src', 'generated', 'styles.generated.mbt'),
      'utf8',
    );
    const generatedBundle = JSON.parse(
      fs.readFileSync(path.join(directory, 'src', 'generated', 'styles.bundle.json'), 'utf8'),
    );
    assert.match(generatedManifest, /Generated by lampclaw\/moonstyle\/extract schema v13/);
    assert.doesNotMatch(generatedManifest, /lampclaw\/moonstyle\/values/);
    assert.match(generatedMappings, /pub struct RootStyle/);
    assert.equal(generatedBundle.schemaVersion, 13);
    assert.equal(generatedBundle.mappingsPackage, 'local/scaffold-app/src/generated');
    assert.deepEqual(generatedBundle.contracts[0].properties, [
      {
        name: 'width',
        policy: 'exact',
        values: [],
        tokens: [{ variable: '--scaffold-width', category: 'length' }],
        slots: [],
        expressions: [],
      },
    ]);

    fs.writeFileSync(
      path.join(directory, 'consumer', 'moon.pkg'),
      [
        'import {',
        '  "lampclaw/moonstyle" @moonstyle,',
        '  "local/scaffold-app/src/generated" @styles,',
        '}',
        '',
      ].join('\n'),
    );
    fs.writeFileSync(
      path.join(directory, 'consumer', 'consumer.mbt'),
      [
        '///|',
        'fn compose() -> Result[@moonstyle.AppliedStyle, Array[@moonstyle.DynamicValueError]] {',
        '  @moonstyle.compose(@styles.root).resolve()',
        '}',
        '',
      ].join('\n'),
    );

    const checked = spawnSync('moon', ['check', '--target', 'native'], {
      cwd: directory,
      encoding: 'utf8',
    });
    assert.equal(checked.status, 0, `${checked.stdout}${checked.stderr}`);
    const strictDoctor = await doctorProject({ root: directory, strict: true });
    assert.equal(
      strictDoctor.passed,
      true,
      strictDoctor.diagnostics.map((item) => `${item.code}: ${item.message}`).join('\n'),
    );

    const incrementalRunner = createExtractorRunner({ extractorPackage: 'style_extractor' });
    const firstDebugExtraction = await incrementalRunner(directory, {
      force: true,
      profile: 'debug',
      devtools: true,
    });
    assert.equal(firstDebugExtraction.ok, true);
    assert.equal(firstDebugExtraction.profile, 'debug');
    assert.equal(firstDebugExtraction.executed, true);
    assert.equal(firstDebugExtraction.stage, 'complete');
    assert.equal(firstDebugExtraction.mode, 'generate');
    assert.equal(firstDebugExtraction.changedOutputs.length, 4);
    assert.equal(firstDebugExtraction.timings.totalMs > 0, true);
    assert.ok(firstDebugExtraction.debugManifest.rules.length > 0);
    assert.equal(
      fs.existsSync(path.join(directory, '_build', 'style-cache', 'vite-debug-manifest.json')),
      true,
    );
    assert.match(firstDebugExtraction.executable, /[/\\]debug[/\\]/);
    const secondDebugExtraction = await incrementalRunner(directory, {
      profile: 'debug',
      devtools: true,
    });
    assert.equal(secondDebugExtraction.ok, true);
    assert.equal(secondDebugExtraction.identity, firstDebugExtraction.identity);
    assert.equal(secondDebugExtraction.skipped, true);
    assert.equal(secondDebugExtraction.executed, false);
    assert.equal(secondDebugExtraction.cacheStatus, 'process-skip');
    assert.equal(
      secondDebugExtraction.changedOutputs.every((output) => !output.changed),
      true,
    );

    const instance = plugin();
    assert.equal(instance.name, 'moonstyle');
    instance.configResolved({ root: directory, command: 'build' });
    const watched = [];
    await instance.buildStart.call({
      addWatchFile: (filename) => watched.push(filename),
      error: (error) => {
        throw new Error(error.message);
      },
    });
    assert.ok(watched.includes(path.join(directory, 'style.config.json')));
    assert.ok(watched.includes(path.join(directory, 'moon.work')));
    assert.ok(watched.includes(path.join(root, 'src')));
    assert.ok(watched.includes(path.join(root, 'moon.mod')));
    assert.equal(watched.includes(path.join(root, '_build')), false);
    const virtualId = instance.resolveId('virtual:moonstyle.css');
    assert.equal(virtualId, '\0virtual:moonstyle.css');
    const watchedCss = [];
    assert.equal(
      instance.load.call({ addWatchFile: (filename) => watchedCss.push(filename) }, virtualId),
      fs.readFileSync(path.join(directory, 'src', 'generated', 'styles.generated.css'), 'utf8'),
    );
    assert.deepEqual(watchedCss, [
      path.join(directory, 'src', 'generated', 'styles.generated.css'),
    ]);

    const devInstance = plugin();
    devInstance.configResolved({ root: directory, command: 'serve', base: '/' });
    const inspectorId = devInstance.resolveId('virtual:moonstyle-inspector');
    assert.equal(inspectorId, '\0virtual:moonstyle-inspector');
    assert.match(devInstance.load(inspectorId), /mountMoonStyleInspector/);
    assert.match(devInstance.transformIndexHtml()[0].attrs.src, /virtual:moonstyle-inspector/);

    const styleFilename = path.join(directory, 'styles', 'styles.mbt');
    const validStyles = fs.readFileSync(styleFilename, 'utf8');
    const artifactFilenames = [
      path.join(directory, 'src', 'generated', 'styles.generated.css'),
      path.join(directory, 'src', 'generated', 'styles.generated.mbt'),
      path.join(directory, 'src', 'generated', 'moon.pkg'),
      path.join(directory, 'src', 'generated', 'styles.bundle.json'),
    ];
    const validArtifacts = artifactFilenames.map((filename) => fs.readFileSync(filename, 'utf8'));
    const websocketMessages = [];
    const server = {
      ws: {
        on() {},
        send(message) {
          websocketMessages.push(message);
        },
      },
    };
    instance.configureServer(server);

    fs.writeFileSync(styleFilename, `${validStyles}\nlet invalid_build : Int = "wrong"\n`);
    assert.deepEqual(await instance.handleHotUpdate({ file: styleFilename, server }), []);
    assert.deepEqual(
      artifactFilenames.map((filename) => fs.readFileSync(filename, 'utf8')),
      validArtifacts,
    );
    assert.equal(websocketMessages.at(-1).type, 'error');
    assert.match(websocketMessages.at(-1).err.message, /^MOON/);

    fs.writeFileSync(styleFilename, validStyles);
    assert.deepEqual(await instance.handleHotUpdate({ file: styleFilename, server }), []);
    assert.deepEqual(websocketMessages.at(-1), { type: 'full-reload' });

    fs.writeFileSync(styleFilename, validStyles.replace('.width(width)', '.unsafe_raw("", "red")'));

    assert.deepEqual(await instance.handleHotUpdate({ file: styleFilename, server }), []);
    assert.deepEqual(
      artifactFilenames.map((filename) => fs.readFileSync(filename, 'utf8')),
      validArtifacts,
    );
    assert.equal(websocketMessages.at(-1).type, 'error');
    assert.equal(websocketMessages.at(-1).err.message.startsWith('STYLE1001:'), true);
    assert.equal(websocketMessages.at(-1).err.id, styleFilename);
    assert.equal(websocketMessages.at(-1).err.loc.line > 0, true);

    const productionPlugin = plugin();
    productionPlugin.configResolved({ root: directory, command: 'build' });
    await assert.rejects(
      productionPlugin.buildStart.call({
        addWatchFile() {},
        error(error) {
          throw new Error(error.message);
        },
      }),
      /STYLE1001/,
    );

    fs.writeFileSync(styleFilename, validStyles);
    assert.deepEqual(await instance.handleHotUpdate({ file: styleFilename, server }), []);
    assert.deepEqual(websocketMessages.at(-1), { type: 'full-reload' });

    const cssModule = { id: virtualId };
    const authoredModule = { id: styleFilename };
    server.moduleGraph = {
      getModuleById(id) {
        return id === virtualId ? cssModule : null;
      },
    };
    fs.writeFileSync(styleFilename, validStyles.replace('@moonstyle.px(4)', '@moonstyle.px(5)'));
    assert.deepEqual(
      await instance.handleHotUpdate({ file: styleFilename, modules: [authoredModule], server }),
      [authoredModule, cssModule],
    );
    assert.notEqual(
      fs.readFileSync(path.join(directory, 'src', 'generated', 'styles.generated.css'), 'utf8'),
      validArtifacts[0],
    );

    fs.writeFileSync(styleFilename, validStyles);
    assert.deepEqual(
      await instance.handleHotUpdate({ file: styleFilename, modules: [authoredModule], server }),
      [authoredModule, cssModule],
    );
    assert.deepEqual(
      artifactFilenames.map((filename) => fs.readFileSync(filename, 'utf8')),
      validArtifacts,
    );
    const messagesBeforeNoop = websocketMessages.length;
    assert.equal(await instance.handleHotUpdate({ file: styleFilename, server }), undefined);
    assert.equal(websocketMessages.length, messagesBeforeNoop);

    fs.writeFileSync(
      path.join(directory, 'index.html'),
      `<!doctype html><html><body><main class="${firstDebugExtraction.debugManifest.rules[0].className}">ready</main><script type="module" src="/entry.mjs"></script></body></html>\n`,
    );
    fs.writeFileSync(
      path.join(directory, 'entry.mjs'),
      "import 'virtual:moonstyle.css';\nwindow.__styleReady = true;\n",
    );
    const viteServer = await createServer({
      root: directory,
      configFile: false,
      logLevel: 'silent',
      plugins: [plugin()],
      server: { host: '127.0.0.1', port: 0 },
    });
    let browser;
    try {
      await viteServer.listen();
      const address = viteServer.httpServer.address();
      assert.equal(typeof address, 'object');
      browser = await chromium.launch({ headless: true });
      const page = await browser.newPage();
      await page.goto(`http://127.0.0.1:${address.port}/`);
      await page.waitForFunction(() => globalThis.__styleReady === true);
      await page.locator('[data-moonstyle-inspector]').waitFor({ state: 'attached' });
      await page.locator('[data-moonstyle-inspector] .badge').click();
      await page.locator('[data-moonstyle-inspector] .pick').click();
      const mainBox = await page.locator('main').boundingBox();
      await page.mouse.click(mainBox.x + 2, mainBox.y + 2);
      assert.equal(await page.locator('[data-moonstyle-inspector] .rule').count(), 1);
      assert.match(
        await page.locator('[data-moonstyle-inspector] .source').textContent(),
        /styles\/styles\.mbt:/,
      );

      const cssModuleResponse = await page.request.get(
        `http://127.0.0.1:${address.port}/@id/__x00__virtual:moonstyle.css`,
      );
      const cssModuleSource = await cssModuleResponse.text();
      const encodedMap = cssModuleSource.match(
        /sourceMappingURL=data:application\/json;base64,([^ *]+)/,
      )?.[1];
      assert.ok(encodedMap);
      const sourceMap = JSON.parse(Buffer.from(encodedMap, 'base64').toString('utf8'));
      assert.ok(sourceMap.sources.some((source) => source.endsWith('/styles/styles.mbt')));
      assert.ok(sourceMap.sourcesContent.every((content) => content === ''));

      fs.writeFileSync(
        styleFilename,
        validStyles.replace('.width(width)', '.unsafe_raw("", "red")'),
      );
      await page.waitForFunction(
        () =>
          document
            .querySelector('vite-error-overlay')
            ?.shadowRoot?.textContent?.includes('STYLE1001') === true,
      );
      await page.waitForFunction(
        () => document.querySelector('[data-moonstyle-inspector]')?.dataset.status === 'stale',
      );
      assert.deepEqual(
        artifactFilenames.map((filename) => fs.readFileSync(filename, 'utf8')),
        validArtifacts,
      );

      fs.writeFileSync(styleFilename, validStyles);
      await page.waitForFunction(() => document.querySelector('vite-error-overlay') === null);
      await page.waitForFunction(() => globalThis.__styleReady === true);
      await page.waitForFunction(
        () => document.querySelector('[data-moonstyle-inspector]')?.dataset.status === 'ready',
      );
    } finally {
      await browser?.close();
      await viteServer.close();
    }
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
}, 300_000);
