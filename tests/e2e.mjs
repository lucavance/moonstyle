import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import net from 'node:net';
import path from 'node:path';
import { afterAll, beforeAll, test } from 'vite-plus/test';
import { REQUIRED_BROWSERS, waitForHttpServer } from '../tools/browser-contract.mjs';

const root = path.resolve(import.meta.dirname, '..');
process.env.PLAYWRIGHT_BROWSERS_PATH ??= path.join(root, '.cache', 'playwright');
const { chromium, firefox, webkit } = await import('playwright');
const requireAllBrowsers = process.env.STYLE_REQUIRE_ALL_BROWSERS === '1';
const browserReportPath = process.env.STYLE_E2E_REPORT
  ? path.resolve(root, process.env.STYLE_E2E_REPORT)
  : null;
let origin;
let preview;

function freePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.unref();
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      server.close(() => resolve(address.port));
    });
  });
}

function verifyDist() {
  const assetsDir = path.join(root, 'validation', 'dist', 'assets');
  const assets = fs.readdirSync(assetsDir);
  const cssFiles = assets.filter((name) => name.endsWith('.css'));
  const jsFiles = assets.filter((name) => name.endsWith('.js'));
  assert.ok(cssFiles.length > 0, 'production build must contain a CSS asset');
  const css = cssFiles
    .map((name) => fs.readFileSync(path.join(assetsDir, name), 'utf8'))
    .join('\n');
  const js = jsFiles.map((name) => fs.readFileSync(path.join(assetsDir, name), 'utf8')).join('\n');
  assert.match(css, /--demo-progress/);
  assert.match(css, /@media(?:\(max-width:640px\)| \(width<=640px\))/);
  assert.match(css, /@keyframes k[\da-z]+/);
  assert.match(css, /\.dep-a(?::not|\{)/);
  assert.match(css, /\.dep-b(?::not|\{)/);
  assert.doesNotMatch(js, /stylex\.create|stylex-inject/);
  assert.doesNotMatch(js, /MoonStyle Inspector|moonstyle:debug-update/);
  assert.doesNotMatch(css, /sourceMappingURL|examples\/styles\/styles\.mbt/);
}

beforeAll(async () => {
  const dependencyBundles = [
    path.join(root, 'tests', 'dependency-fixtures', 'component-a.bundle.json'),
    path.join(root, 'tests', 'dependency-fixtures', 'component-b.bundle.json'),
  ];
  const build = spawnSync('vp', ['build'], {
    cwd: root,
    encoding: 'utf8',
    env: {
      ...process.env,
      STYLE_DEPENDENCY_BUNDLES: dependencyBundles.join(path.delimiter),
    },
  });
  assert.equal(build.status, 0, `${build.stdout}${build.stderr}`);
  verifyDist();

  const port = await freePort();
  origin = `http://127.0.0.1:${port}`;
  preview = spawn(
    'vp',
    ['preview', '--host', '127.0.0.1', '--port', String(port), '--strictPort'],
    {
      cwd: root,
      stdio: ['ignore', 'pipe', 'pipe'],
    },
  );
  await waitForHttpServer(preview, origin, { name: 'VitePlus preview', timeoutMs: 20_000 });
}, 120_000);

afterAll(async () => {
  if (preview && preview.exitCode === null) preview.kill('SIGTERM');
  const restore = spawnSync(process.execPath, ['tools/build-styles.mjs'], {
    cwd: root,
    encoding: 'utf8',
    env: { ...process.env, STYLE_DEPENDENCY_BUNDLES: '' },
  });
  assert.equal(restore.status, 0, `${restore.stdout}${restore.stderr}`);
  writeBrowserReport();
});

const browserMatrix = /** @type {const} */ ([
  ['chromium', chromium],
  ['firefox', firefox],
  ['webkit', webkit],
]);
const browserResults = REQUIRED_BROWSERS.map((name) => ({ name, status: 'pending' }));

function writeBrowserReport() {
  if (!browserReportPath) return;
  fs.mkdirSync(path.dirname(browserReportPath), { recursive: true });
  fs.writeFileSync(
    browserReportPath,
    `${JSON.stringify(
      {
        schemaVersion: 1,
        recordedAt: new Date().toISOString(),
        required: requireAllBrowsers,
        results: browserResults,
      },
      null,
      2,
    )}\n`,
  );
}

writeBrowserReport();

for (const [browserName, browserType] of browserMatrix) {
  const blockedByCodexSandbox =
    browserName === 'firefox' && process.env.CODEX_CI && !requireAllBrowsers;
  const browserTest = blockedByCodexSandbox ? test.skip : test;
  const sandboxNote = blockedByCodexSandbox
    ? ' (Codex sandbox does not provide Firefox user namespaces)'
    : '';
  if (blockedByCodexSandbox) {
    const result = browserResults.find((entry) => entry.name === browserName);
    result.status = 'skipped';
    result.reason = 'Codex sandbox does not provide Firefox user namespaces';
    writeBrowserReport();
  }
  browserTest(
    `production styles work without runtime static rule injection [${browserName}]${sandboxNote}`,
    async () => {
      const browserResult = browserResults.find((entry) => entry.name === browserName);
      let browser;
      try {
        browser = await browserType.launch({
          ...(browserName === 'chromium' && process.env.STYLE_E2E_CHROMIUM_EXECUTABLE
            ? { executablePath: process.env.STYLE_E2E_CHROMIUM_EXECUTABLE }
            : {}),
          headless: true,
          timeout: 20_000,
        });
        const page = await browser.newPage({ viewport: { width: 1024, height: 800 } });
        const consoleErrors = [];
        page.on('console', (message) => {
          if (message.type() === 'error') consoleErrors.push(message.text());
        });
        page.on('pageerror', (error) => consoleErrors.push(error.message));

        await page.goto(origin, { waitUntil: 'networkidle' });
        await page.locator('#validation-card').waitFor();

        const coverageBundle = JSON.parse(
          fs.readFileSync(path.join(root, 'validation/src/generated/styles.bundle.json'), 'utf8'),
        );
        const dailyClasses = Object.fromEntries(
          coverageBundle.namespaces
            .filter((namespace) => namespace.name.split(':').at(-1).startsWith('daily'))
            .map((namespace) => [
              namespace.name.split(':').at(-1),
              namespace.entries
                .map((entry) => entry[1])
                .filter((value) => typeof value === 'string')
                .join(' '),
            ]),
        );
        const daily = await page.evaluate(async (classes) => {
          const host = document.createElement('div');
          host.style.cssText =
            'position:absolute;left:-10000px;--daily-distance:72px;--daily-ink:blue;--daily-weight:.75;--daily-ordinary:37px';
          const label = document.createElement('span');
          label.className = classes.dailyText;
          const registered = document.createElement('div');
          registered.className = classes.dailyRegistered;
          const ordinary = document.createElement('div');
          ordinary.className = classes.dailyOrdinary;
          host.append(label, registered, ordinary);
          document.body.append(host);
          const style = getComputedStyle(label);
          const initial = getComputedStyle(registered);
          const result = {
            isolation: style.isolation,
            whiteSpace: style.whiteSpace,
            textWrap: style.textWrap,
            verticalAlign: style.verticalAlign,
            willChange: style.willChange,
            fontVariations: style.fontVariationSettings
              .split(',')
              .map((axis) => axis.trim())
              .sort(),
            width: initial.width,
            color: initial.color,
            weight: initial.getPropertyValue('--daily-weight').trim(),
            ordinaryWidth: getComputedStyle(ordinary).width,
          };
          registered.style.setProperty('--daily-distance', 'invalid-length');
          result.invalidWidth = getComputedStyle(registered).width;
          registered.style.removeProperty('--daily-distance');
          const animation = registered.animate(
            { '--daily-distance': ['12px', '28px'] },
            { duration: 1000, fill: 'both' },
          );
          animation.pause();
          await animation.ready;
          animation.currentTime = 500;
          result.interpolatedWidth = getComputedStyle(registered).width;
          animation.cancel();
          host.remove();
          return result;
        }, dailyClasses);
        assert.deepEqual(daily, {
          isolation: 'isolate',
          whiteSpace: 'pre-wrap',
          textWrap: 'balance',
          verticalAlign: '-2px',
          willChange: 'transform, opacity',
          fontVariations: ['"wdth" 95.5', '"wght" 650'],
          width: '12px',
          color: 'rgb(0, 0, 255)',
          weight: '0.25',
          ordinaryWidth: '37px',
          invalidWidth: '12px',
          interpolatedWidth: '20px',
        });
        browserResult.dailyCss = 'passed';
        browserResult.propertyRegistration = {
          inheritance: 'passed',
          invalidValue: 'passed',
          interpolation: 'passed',
        };
        const resourceClasses = Object.fromEntries(
          coverageBundle.namespaces
            .filter((namespace) => namespace.name.split(':').at(-1).startsWith('upstream'))
            .map((namespace) => [
              namespace.name.split(':').at(-1),
              namespace.entries
                .map((entry) => entry[1])
                .filter((value) => typeof value === 'string')
                .join(' '),
            ]),
        );
        const resourceResponse = page.waitForResponse((response) => {
          const url = new URL(response.url());
          return url.pathname === '/__upstream__/v0.5/picture.svg' && url.search === '?scale=0.5';
        });
        const resourceValues = await page.evaluate((classes) => {
          const image = document.createElement('div');
          image.className = classes.upstreamResource;
          image.style.cssText = 'position:absolute;left:-10000px;top:0';
          const text = document.createElement('div');
          text.className = classes.upstreamContent;
          document.body.append(image, text);
          return {
            image: getComputedStyle(image).backgroundImage,
            content: getComputedStyle(text, '::before').content,
          };
        }, resourceClasses);
        assert.equal((await resourceResponse).status(), 200);
        assert.ok(resourceValues.image.includes('/__upstream__/v0.5/picture.svg?scale=0.5'));
        assert.equal(resourceValues.content, '"version 0.5"');
        browserResult.resourcePayloads = { request: 'passed', content: 'passed' };
        const coverageClasses = Object.fromEntries(
          coverageBundle.namespaces
            .filter((namespace) => namespace.name.split(':').at(-1).startsWith('coverage'))
            .map((namespace) => [
              namespace.name.split(':').at(-1),
              namespace.entries
                .map((entry) => entry[1])
                .filter((value) => typeof value === 'string')
                .join(' '),
            ]),
        );
        const coverage = await page.evaluate(async (classes) => {
          const host = document.createElement('div');
          host.style.cssText =
            'position:absolute;left:-10000px;top:0;width:200px;container-type:inline-size';
          document.body.append(host);
          const make = (name, parent = host) => {
            const element = document.createElement('div');
            element.className = classes[name];
            element.textContent = name;
            parent.append(element);
            return element;
          };
          const color = make('coverageColor');
          const reference = make('reference');
          const mixSupported = CSS.supports('color', 'color-mix(in srgb, red, blue)');
          reference.style.color = mixSupported ? 'color-mix(in srgb, red, blue)' : 'blue';
          const colorPixels = (css) => {
            const canvas = document.createElement('canvas');
            canvas.width = canvas.height = 1;
            const context = canvas.getContext('2d');
            context.fillStyle = css;
            context.fillRect(0, 0, 1, 1);
            return [...context.getImageData(0, 0, 1, 1).data];
          };
          const transform = make('coverageTransform');
          const matrix = new DOMMatrix(getComputedStyle(transform).transform);
          const shape = make('coverageShape');
          const mask = make('coverageMask');
          const image = make('coverageImageSet');
          const animation = make('coverageAnimation');
          const counter = make('coverageCounter');
          const env = make('coverageEnv');
          const motion = make('coverageMotion');
          motion.style.cssText = 'position:absolute;width:10px;height:10px;left:0;top:0';
          const states = document.createElement('section');
          states.style.color = 'red';
          host.append(states);
          const odd = make('coverageState', states);
          const even = make('coverageState', states);
          const queryParent = document.createElement('section');
          queryParent.style.setProperty('--coverage-mode', '1');
          host.append(queryParent);
          const query = make('coverageContainerStyle', queryParent);
          const queryInitial = getComputedStyle(query).color;
          queryParent.style.setProperty('--coverage-mode', '2');
          const queryChanged = getComputedStyle(query).color;
          const scroller = document.createElement('section');
          scroller.style.cssText = 'height:100px;width:100px;overflow:auto';
          host.append(scroller);
          const scrollEffect = make('coverageScrollEffect', scroller);
          const filler = document.createElement('div');
          filler.style.height = '1000px';
          scroller.append(filler);
          const frame = () =>
            new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
          await frame();
          const opacityBefore = Number(getComputedStyle(scrollEffect).opacity);
          scroller.scrollTop = 500;
          await frame();
          const opacityAfter = Number(getComputedStyle(scrollEffect).opacity);
          const result = {
            color: colorPixels(getComputedStyle(color).color),
            expectedColor: colorPixels(getComputedStyle(reference).color),
            matrix: { x: matrix.m11, z: matrix.m43 },
            clip: getComputedStyle(shape).clipPath,
            maskMode: getComputedStyle(mask).maskMode,
            maskImage: getComputedStyle(mask).maskImage,
            image: getComputedStyle(image).backgroundImage,
            animationNames: getComputedStyle(animation)
              .animationName.split(',')
              .map((value) => value.trim()),
            animationDurations: getComputedStyle(animation).animationDuration,
            counter: getComputedStyle(counter).counterIncrement,
            content: getComputedStyle(counter, '::before').content,
            envWidth: getComputedStyle(env).width,
            containerUnitHeight: getComputedStyle(env).height,
            motionPath: getComputedStyle(motion).offsetPath,
            odd: getComputedStyle(odd).color,
            even: getComputedStyle(even).color,
            queryInitial,
            queryChanged,
            opacityBefore,
            opacityAfter,
            support: {
              colorMix: mixSupported,
              imageSet: CSS.supports(
                'background-image',
                'image-set(linear-gradient(black, white) 1x)',
              ),
              clipPath: CSS.supports('clip-path', 'path("M0 0 L100 0 L100 100 Z")'),
              mask: CSS.supports('mask-image', 'linear-gradient(black, white)'),
              motionPath: CSS.supports('offset-path', 'path("M0 0 L100 0")'),
              scrollTimeline: CSS.supports('animation-timeline', 'scroll()'),
              containerStyle: queryInitial === 'rgb(0, 128, 0)',
            },
          };
          host.remove();
          return result;
        }, coverageClasses);
        assert.ok(
          coverage.color.every(
            (channel, index) => Math.abs(channel - coverage.expectedColor[index]) <= 1,
          ),
        );
        assert.ok(Math.abs(coverage.matrix.x - Math.sqrt(3)) < 0.001);
        assert.equal(coverage.matrix.z, 10);
        assert.equal(coverage.clip.startsWith('path('), coverage.support.clipPath);
        assert.equal(coverage.maskImage.includes('gradient('), coverage.support.mask);
        if (coverage.support.mask) assert.equal(coverage.maskMode, 'alpha');
        assert.equal(coverage.image.includes('image-set('), coverage.support.imageSet);
        assert.equal(coverage.animationNames.length, 2);
        assert.notEqual(coverage.animationNames[0], coverage.animationNames[1]);
        assert.equal(coverage.animationDurations, '10s, 20s');
        assert.equal(coverage.counter, 'section 1');
        assert.ok(coverage.content.includes('counter(section)'));
        assert.equal(coverage.envWidth, '0px');
        assert.equal(coverage.containerUnitHeight, '2px');
        assert.equal(coverage.motionPath.startsWith('path('), coverage.support.motionPath);
        assert.equal(coverage.odd, 'rgb(0, 128, 0)');
        assert.equal(coverage.even, 'rgb(255, 0, 0)');
        assert.equal(coverage.queryChanged, 'rgb(0, 0, 255)');
        if (!coverage.support.containerStyle) assert.equal(coverage.queryInitial, 'rgb(0, 0, 255)');
        if (coverage.support.scrollTimeline)
          assert.ok(coverage.opacityAfter > coverage.opacityBefore + 0.1, JSON.stringify(coverage));
        else assert.ok(Math.abs(coverage.opacityAfter - 0.2) < 0.01);
        browserResult.cssCoverage = coverage.support;

        const modern = await page.evaluate(
          async (transitionClass) => {
            const support = {
              positionTry: CSS.supports('position-try-fallbacks', '--demo-tooltip'),
              viewTransitions:
                CSS.supports('view-transition-class', transitionClass) &&
                typeof document.startViewTransition === 'function',
            };
            const result = { support, fallback: null, transition: null };
            if (support.positionTry) {
              const anchor = document.createElement('div');
              anchor.style.cssText =
                'position:fixed;left:120px;top:0;width:80px;height:20px;anchor-name:--coverage-anchor';
              const target = document.createElement('div');
              target.style.cssText =
                'position:fixed;position-anchor:--coverage-anchor;position-area:top;width:40px;height:30px;position-try-fallbacks:--demo-tooltip';
              document.body.append(anchor, target);
              await new Promise((resolve) =>
                requestAnimationFrame(() => requestAnimationFrame(resolve)),
              );
              const rect = target.getBoundingClientRect();
              result.fallback = {
                top: rect.top,
                width: rect.width,
                anchorBottom: anchor.getBoundingClientRect().bottom,
              };
              anchor.remove();
              target.remove();
            }
            if (support.viewTransitions) {
              const target = document.createElement('div');
              target.style.cssText = `position:fixed;left:20px;top:20px;width:40px;height:40px;background:red;view-transition-name:coverage-card;view-transition-class:${transitionClass}`;
              document.body.append(target);
              const transition = document.startViewTransition(() => {
                target.style.background = 'blue';
              });
              try {
                await transition.ready;
                const style = (group) =>
                  getComputedStyle(
                    document.documentElement,
                    `::view-transition-${group}(coverage-card)`,
                  );
                result.transition = {
                  groupAdjust: style('group').fontSizeAdjust,
                  pairOpacity: style('image-pair').opacity,
                  oldWeight: style('old').fontWeight,
                  newWeight: style('new').fontWeight,
                };
              } finally {
                transition.skipTransition();
                await transition.finished;
                target.remove();
              }
            }
            return result;
          },
          coverageBundle.viewTransitionClasses.find((value) => value.name === 'demo_shared')
            .cssName,
        );
        if (browserName === 'chromium') {
          assert.equal(modern.support.positionTry, true);
          assert.equal(modern.support.viewTransitions, true);
        }
        if (modern.support.positionTry) {
          assert.ok(
            Math.abs(modern.fallback.top - modern.fallback.anchorBottom - 8) < 1,
            JSON.stringify(modern),
          );
          assert.equal(modern.fallback.width, 40);
        }
        if (modern.support.viewTransitions) {
          assert.deepEqual(modern.transition, {
            groupAdjust: '0.545',
            pairOpacity: '0.9',
            oldWeight: '400',
            newWeight: '700',
          });
        }
        browserResult.modernCss = modern.support;

        await page.emulateMedia({ media: 'print' });
        const printedPages = await page.evaluate((classes) => {
          const supported = CSS.supports('page', 'auto') && CSS.supports('page', 'MoonStyleReport');
          const expected = ['auto', 'MoonStyleReport'];
          const referenceValues = [];
          const values = ['coveragePageAuto', 'coveragePageNamed'].map((name, index) => {
            const element = document.createElement('section');
            element.className = classes[name];
            document.body.append(element);
            const value = getComputedStyle(element).getPropertyValue('page');
            const reference = document.createElement('section');
            reference.style.setProperty('page', expected[index]);
            document.body.append(reference);
            referenceValues.push(getComputedStyle(reference).getPropertyValue('page'));
            reference.remove();
            element.remove();
            return value;
          });
          return { supported, values, referenceValues };
        }, coverageClasses);
        if (browserName === 'chromium') assert.equal(printedPages.supported, true);
        assert.deepEqual(printedPages.values, printedPages.referenceValues);
        if (browserName !== 'webkit') {
          assert.deepEqual(printedPages.values, ['auto', 'MoonStyleReport']);
        } else {
          assert.ok(
            printedPages.values.every(
              (value, index) => value === '' || value === ['auto', 'MoonStyleReport'][index],
            ),
          );
        }
        browserResult.modernCss.namedPages = printedPages.supported;
        browserResult.namedPages = printedPages;
        await page.emulateMedia({ media: 'screen' });

        const expressionLayout = () =>
          page.evaluate(() => {
            const panel = document.querySelector('#expression-panel');
            const grid = document.querySelector('#expression-grid');
            const style = getComputedStyle(panel);
            return {
              width: panel.getBoundingClientRect().width,
              images: style.backgroundImage,
              repeat: style.backgroundRepeat,
              gridWidth: grid.children[0].getBoundingClientRect().width,
              subgridWidth: document
                .querySelector('#expression-subgrid')
                .children[0].getBoundingClientRect().width,
            };
          });
        const initialExpression = await expressionLayout();
        assert.equal(initialExpression.width, 120);
        assert.equal(initialExpression.gridWidth, 80);
        assert.equal(initialExpression.subgridWidth, 80);
        assert.match(initialExpression.images, /linear-gradient\(90deg/);
        assert.match(initialExpression.images, /radial-gradient/);
        assert.match(initialExpression.images, /conic-gradient/);
        assert.match(initialExpression.images, /rgb\(243, 245, 247\)/);
        assert.equal(initialExpression.repeat, 'no-repeat, repeat, repeat');
        const initialExpressionPixels = await page.locator('#expression-panel').screenshot();

        assert.deepEqual(
          await page.locator('#rabbita-adapter-fixtures > div').evaluateAll((elements) =>
            elements.map((element) => ({
              id: element.id,
              className: element.className,
              meter: element.style.getPropertyValue('--meter'),
            })),
          ),
          [
            { id: 'rabbita-adapter-static', className: 'base-color', meter: '25%' },
            { id: 'rabbita-adapter-many', className: 'active-color', meter: '25%' },
            { id: 'rabbita-adapter-mixed', className: 'active-color', meter: '25%' },
            { id: 'rabbita-adapter-checked', className: 'active-color', meter: '' },
          ],
        );

        // StyleX #1711: preserve case-sensitive multi-word custom property names
        // through checked composition, the Rabbita adapter, and DOM application.
        assert.deepEqual(
          await page.locator('#rabbita-adapter-mixed').evaluate((element) => ({
            lower: element.style.getPropertyValue('--backgroundColor'),
            upper: element.style.getPropertyValue('--BackgroundColor'),
            kebab: element.style.getPropertyValue('--background-color'),
          })),
          { lower: 'red', upper: 'blue', kebab: '' },
        );

        // Exercise the generated zero binding in real CSS math. The fixture
        // lives under a hidden parent; move a clone out for layout measurement.
        assert.deepEqual(
          await page.locator('#rabbita-adapter-zero').evaluate((element) => {
            const clone = /** @type {HTMLElement} */ (element.cloneNode(true));
            clone.style.position = 'absolute';
            clone.style.visibility = 'hidden';
            document.body.append(clone);
            const result = {
              offset: clone.style.getPropertyValue('--demo-expression-offset'),
              width: clone.getBoundingClientRect().width,
            };
            clone.remove();
            return result;
          }),
          { offset: '0px', width: 100 },
        );

        const keyframeState = await page.locator('#keyframe-animation').evaluate((element) => ({
          name: getComputedStyle(element).animationName,
          duration: getComputedStyle(element).animationDuration,
          animations: element.getAnimations().length,
        }));
        assert.match(keyframeState.name, /^k[\da-z]+$/);
        assert.equal(keyframeState.duration, '10s');
        assert.equal(keyframeState.animations, 1);
        assert.deepEqual(
          await page.locator('#cross-module').evaluate((element) => {
            const style = getComputedStyle(element);
            return {
              hidden: element.hidden,
              background: style.backgroundColor,
              border: [style.borderTopStyle, style.borderTopWidth, style.borderTopColor],
            };
          }),
          {
            hidden: true,
            background: 'rgb(210, 235, 220)',
            border: ['solid', '3px', 'rgb(30, 110, 75)'],
          },
        );
        assert.deepEqual(
          await page.locator('#multi-dynamic').evaluate((element) => ({
            progress: element.style.getPropertyValue('--demo-progress'),
            surface: element.style.getPropertyValue('--demo-dynamic-surface'),
            text: element.style.getPropertyValue('--demo-dynamic-text'),
          })),
          {
            progress: '37%',
            surface: 'rgb(220 230 238)',
            text: 'rgb(30 40 50)',
          },
        );
        assert.deepEqual(
          await page.locator('#rejected-dynamic-base').evaluate((element) => ({
            className: element.className,
            progress: element.style.getPropertyValue('--demo-progress'),
          })),
          {
            className: 'retained-base',
            progress: '',
          },
        );

        const initialStyleCount = await page.locator('style').count();
        const computedBorder = (selector) =>
          page.locator(selector).evaluate((element) => {
            element.hidden = false;
            const style = getComputedStyle(element);
            return {
              widths: [
                style.borderTopWidth,
                style.borderRightWidth,
                style.borderBottomWidth,
                style.borderLeftWidth,
              ],
              styles: [
                style.borderTopStyle,
                style.borderRightStyle,
                style.borderBottomStyle,
                style.borderLeftStyle,
              ],
              colors: [
                style.borderTopColor,
                style.borderRightColor,
                style.borderBottomColor,
                style.borderLeftColor,
              ],
            };
          });
        assert.deepEqual(await computedBorder('#border-composite-side'), {
          widths: ['2px', '2px', '2px', '2px'],
          styles: ['solid', 'solid', 'solid', 'solid'],
          colors: ['rgb(18, 52, 86)', 'rgb(18, 52, 86)', 'rgb(18, 52, 86)', 'rgb(18, 52, 86)'],
        });
        assert.deepEqual(await computedBorder('#border-composite-pairs'), {
          widths: ['1px', '4px', '3px', '2px'],
          styles: ['solid', 'double', 'dotted', 'dashed'],
          colors: [
            'rgb(17, 34, 51)',
            'rgb(170, 187, 204)',
            'rgb(68, 85, 102)',
            'rgb(119, 136, 153)',
          ],
        });
        assert.deepEqual(await computedBorder('#border-composite-longhands'), {
          widths: ['5px', '0px', '0px', '0px'],
          styles: ['double', 'none', 'none', 'none'],
          colors: ['rgb(12, 34, 56)', 'rgb(23, 33, 43)', 'rgb(23, 33, 43)', 'rgb(23, 33, 43)'],
        });
        assert.equal(
          await page.locator('#border-composite-corner').evaluate((element) => {
            element.hidden = false;
            return getComputedStyle(element).borderTopLeftRadius;
          }),
          '4px 25%',
        );
        assert.deepEqual(
          await page.locator('#border-composite-outline').evaluate((element) => {
            element.hidden = false;
            const style = getComputedStyle(element);
            return [style.outlineWidth, style.outlineStyle, style.outlineColor];
          }),
          ['3px', 'dashed', 'rgb(68, 85, 102)'],
        );
        assert.equal(
          await page
            .locator('#validation-card')
            .evaluate((element) => getComputedStyle(element).backgroundColor),
          'rgb(255, 255, 255)',
        );
        await page.locator('#validation-card').hover();
        assert.equal(
          await page
            .locator('#validation-card')
            .evaluate((element) => getComputedStyle(element).backgroundColor),
          'rgb(248, 251, 253)',
        );

        assert.equal(
          await page
            .locator('#validation-page')
            .evaluate((element) => getComputedStyle(element).backgroundColor),
          'rgb(243, 245, 247)',
        );
        assert.deepEqual(
          await page.locator('#explicit-clear').evaluate((element) => {
            element.hidden = false;
            return {
              hasClass: element.className.length > 0,
              color: getComputedStyle(element).color,
            };
          }),
          {
            hasClass: true,
            color: 'rgb(255, 0, 0)',
          },
        );
        await page.setViewportSize({ width: 600, height: 800 });
        assert.equal(
          await page
            .locator('#validation-page')
            .evaluate((element) => getComputedStyle(element).backgroundColor),
          'rgb(231, 238, 245)',
        );

        const initialMeterWidth = await page
          .locator('#meter')
          .evaluate((element) => element.getBoundingClientRect().width);
        assert.equal(
          await page
            .locator('#meter')
            .evaluate((element) => element.style.getPropertyValue('--demo-progress')),
          '37%',
        );
        await page.locator('#toggle').click();
        await page.waitForFunction(
          () =>
            document.querySelector('#meter')?.style.getPropertyValue('--demo-progress') === '76%',
        );
        await page.waitForFunction(
          () => document.querySelector('#explicit-clear')?.className === '',
        );
        const updatedExpression = await expressionLayout();
        assert.equal(updatedExpression.width, 180);
        assert.equal(updatedExpression.gridWidth, 120);
        assert.equal(updatedExpression.subgridWidth, 120);
        assert.match(updatedExpression.images, /linear-gradient\((?:180deg|rgb)/);
        assert.match(updatedExpression.images, /rgb\(34, 42, 49\)/);
        assert.notDeepEqual(
          await page.locator('#expression-panel').screenshot(),
          initialExpressionPixels,
        );
        assert.equal(
          await page
            .locator('#explicit-clear')
            .evaluate((element) => getComputedStyle(element).color),
          'rgb(23, 33, 43)',
        );
        assert.deepEqual(
          await page.locator('#multi-dynamic').evaluate((element) => ({
            progress: element.style.getPropertyValue('--demo-progress'),
            surface: element.style.getPropertyValue('--demo-dynamic-surface'),
            text: element.style.getPropertyValue('--demo-dynamic-text'),
          })),
          {
            progress: '76%',
            surface: 'rgb(48 62 72)',
            text: 'rgb(245 248 250)',
          },
        );
        await page.waitForFunction(() => {
          const meter = document.querySelector('#meter');
          const track = document.querySelector('#meter-track');
          return (
            meter &&
            track &&
            meter.getBoundingClientRect().width / track.getBoundingClientRect().width > 0.7
          );
        });
        assert.deepEqual(
          await page.locator('#validation-card').evaluate((element) => {
            const card = getComputedStyle(element);
            const title = getComputedStyle(element.querySelector('h1'));
            return {
              background: card.backgroundColor,
              foreground: card.color,
              title: title.color,
            };
          }),
          {
            background: 'rgb(226, 244, 232)',
            foreground: 'rgb(23, 33, 43)',
            title: 'rgb(23, 33, 43)',
          },
        );
        await page.setViewportSize({ width: 1024, height: 800 });
        assert.equal(
          await page
            .locator('#validation-page')
            .evaluate((element) => getComputedStyle(element).backgroundColor),
          'rgb(34, 42, 49)',
        );
        const activeMeterWidth = await page
          .locator('#meter')
          .evaluate((element) => element.getBoundingClientRect().width);
        assert.ok(activeMeterWidth > initialMeterWidth * 1.8);
        assert.equal(await page.locator('style').count(), initialStyleCount);
        assert.equal(await page.locator('style[data-stylex]').count(), 0);
        assert.deepEqual(
          await page.locator('#conflict-longhand-last').evaluate((element) => {
            const style = getComputedStyle(element);
            return {
              margin: [style.marginTop, style.marginRight, style.marginBottom, style.marginLeft],
              padding: [
                style.paddingTop,
                style.paddingRight,
                style.paddingBottom,
                style.paddingLeft,
              ],
              gap: [style.rowGap, style.columnGap],
            };
          }),
          {
            margin: ['16px', '8px', '8px', '8px'],
            padding: ['6px', '6px', '6px', '12px'],
            gap: ['10px', '4px'],
          },
        );
        assert.deepEqual(
          await page.locator('#conflict-shorthand-last').evaluate((element) => {
            const style = getComputedStyle(element);
            return {
              margin: [style.marginTop, style.marginRight, style.marginBottom, style.marginLeft],
              padding: [
                style.paddingTop,
                style.paddingRight,
                style.paddingBottom,
                style.paddingLeft,
              ],
              gap: [style.rowGap, style.columnGap],
            };
          }),
          {
            margin: ['8px', '8px', '8px', '8px'],
            padding: ['6px', '6px', '6px', '6px'],
            gap: ['4px', '4px'],
          },
        );
        const scalarSize = async (selector, writingMode) =>
          page.locator(selector).evaluate((element, mode) => {
            element.hidden = false;
            Object.assign(element.style, {
              position: 'fixed',
              visibility: 'hidden',
              writingMode: mode,
            });
            const style = getComputedStyle(element);
            return {
              width: style.width,
              height: style.height,
              blockSize: style.blockSize,
              inlineSize: style.inlineSize,
            };
          }, writingMode);
        assert.deepEqual(await scalarSize('#scalar-logical-last', 'horizontal-tb'), {
          width: '45px',
          height: '40px',
          blockSize: '40px',
          inlineSize: '45px',
        });
        assert.deepEqual(await scalarSize('#scalar-physical-last', 'horizontal-tb'), {
          width: '75px',
          height: '70px',
          blockSize: '70px',
          inlineSize: '75px',
        });
        assert.deepEqual(await scalarSize('#scalar-logical-last', 'vertical-rl'), {
          width: '45px',
          height: '40px',
          blockSize: '45px',
          inlineSize: '40px',
        });
        assert.deepEqual(await scalarSize('#scalar-physical-last', 'vertical-rl'), {
          width: '75px',
          height: '70px',
          blockSize: '75px',
          inlineSize: '70px',
        });

        const scrollMargins = async (selector) =>
          page.locator(selector).evaluate((element) => {
            const style = getComputedStyle(element);
            return [
              style.scrollMarginTop,
              style.scrollMarginRight,
              style.scrollMarginBottom,
              style.scrollMarginLeft,
            ];
          });
        assert.deepEqual(await scrollMargins('#scalar-scroll-longhand-last'), [
          '20px',
          '8px',
          '8px',
          '8px',
        ]);
        assert.deepEqual(await scrollMargins('#scalar-scroll-shorthand-last'), [
          '8px',
          '8px',
          '8px',
          '8px',
        ]);

        const overscroll = async (selector, writingMode) =>
          page.locator(selector).evaluate((element, mode) => {
            element.style.writingMode = mode;
            const style = getComputedStyle(element);
            return {
              block: style.getPropertyValue('overscroll-behavior-block'),
              x: style.overscrollBehaviorX,
              y: style.overscrollBehaviorY,
            };
          }, writingMode);
        for (const selector of [
          '#scalar-overscroll-axis-last',
          '#scalar-overscroll-shorthand-last',
        ]) {
          assert.deepEqual(await overscroll(selector, 'horizontal-tb'), {
            block: 'contain',
            x: 'auto',
            y: 'contain',
          });
          assert.deepEqual(await overscroll(selector, 'vertical-rl'), {
            block: 'contain',
            x: 'contain',
            y: 'auto',
          });
        }

        assert.equal(
          await page
            .locator('#scalar-transition-longhand-last')
            .evaluate((element) => getComputedStyle(element).transitionDuration),
          '0.24s',
        );
        assert.equal(
          await page
            .locator('#scalar-transition-shorthand-last')
            .evaluate((element) => getComputedStyle(element).transitionDuration),
          '0.09s',
        );

        const svgClass = await page.locator('#scalar-svg').getAttribute('class');
        await page.evaluate((className) => {
          const namespace = 'http://www.w3.org/2000/svg';
          const svg = document.createElementNS(namespace, 'svg');
          const circle = document.createElementNS(namespace, 'circle');
          circle.id = 'scalar-svg-circle';
          circle.setAttribute('class', className ?? '');
          circle.setAttribute('r', '5');
          svg.append(circle);
          document.body.append(svg);
        }, svgClass);
        assert.deepEqual(
          await page.locator('#scalar-svg-circle').evaluate((element) => {
            const style = getComputedStyle(element);
            return {
              cx: style.getPropertyValue('cx'),
              cy: style.getPropertyValue('cy'),
              fillOpacity: style.fillOpacity,
              fillRule: style.fillRule,
              strokeLinecap: style.strokeLinecap,
            };
          }),
          {
            cx: '18px',
            cy: '22px',
            fillOpacity: '0.4',
            fillRule: 'evenodd',
            strokeLinecap: 'round',
          },
        );
        const conditionalMargins = async (selector) =>
          page.locator(selector).evaluate((element) => {
            const style = getComputedStyle(element);
            return [style.marginTop, style.marginRight, style.marginBottom, style.marginLeft];
          });
        const conditionalShorthand = page.locator('#conditional-shorthand-last');
        await conditionalShorthand.evaluate((element) => {
          element.hidden = false;
          Object.assign(element.style, {
            display: 'block',
            height: '100px',
            left: '100px',
            position: 'fixed',
            top: '100px',
            width: '100px',
            zIndex: '2147483647',
          });
        });
        assert.deepEqual(await conditionalMargins('#conditional-shorthand-last'), [
          '0px',
          '0px',
          '0px',
          '0px',
        ]);
        await conditionalShorthand.hover({ force: true });
        assert.deepEqual(await conditionalMargins('#conditional-shorthand-last'), [
          '8px',
          '8px',
          '8px',
          '8px',
        ]);
        const conditionalLonghand = page.locator('#conditional-longhand-last');
        await conditionalLonghand.evaluate((element) => {
          element.hidden = false;
          Object.assign(element.style, {
            display: 'block',
            height: '100px',
            left: '250px',
            position: 'fixed',
            top: '100px',
            width: '100px',
            zIndex: '2147483647',
          });
        });
        assert.deepEqual(await conditionalMargins('#conditional-longhand-last'), [
          '16px',
          '0px',
          '0px',
          '0px',
        ]);
        await conditionalLonghand.hover({ force: true });
        assert.deepEqual(await conditionalMargins('#conditional-longhand-last'), [
          '16px',
          '8px',
          '8px',
          '8px',
        ]);
        const directionalStyles = async (selector) =>
          page.locator(selector).evaluate((element) => {
            const style = getComputedStyle(element);
            return {
              margin: [style.marginLeft, style.marginRight],
              padding: [style.paddingLeft, style.paddingRight],
              borderWidth: [style.borderLeftWidth, style.borderRightWidth],
              borderColor: [style.borderLeftColor, style.borderRightColor],
              radius: [style.borderTopLeftRadius, style.borderTopRightRadius],
            };
          });
        assert.deepEqual(await directionalStyles('#rtl-directional'), {
          margin: ['11px', '0px'],
          padding: ['0px', '13px'],
          borderWidth: ['3px', '0px'],
          borderColor: ['rgb(210, 42, 58)', 'rgb(23, 33, 43)'],
          radius: ['7px', '0px'],
        });
        assert.deepEqual((await directionalStyles('#conflict-logical-last')).margin, [
          '18px',
          '0px',
        ]);
        assert.deepEqual((await directionalStyles('#conflict-physical-last')).margin, [
          '24px',
          '0px',
        ]);

        const verticalStyles = async () =>
          page.locator('#rtl-directional').evaluate((element) => {
            element.style.writingMode = 'vertical-rl';
            const style = getComputedStyle(element);
            return {
              margin: [style.marginTop, style.marginRight, style.marginBottom, style.marginLeft],
              padding: [
                style.paddingTop,
                style.paddingRight,
                style.paddingBottom,
                style.paddingLeft,
              ],
              borderWidth: [
                style.borderTopWidth,
                style.borderRightWidth,
                style.borderBottomWidth,
                style.borderLeftWidth,
              ],
              radius: [
                style.borderTopLeftRadius,
                style.borderTopRightRadius,
                style.borderBottomRightRadius,
                style.borderBottomLeftRadius,
              ],
            };
          });
        assert.deepEqual(await verticalStyles(), {
          margin: ['11px', '0px', '0px', '0px'],
          padding: ['0px', '0px', '13px', '0px'],
          borderWidth: ['3px', '0px', '0px', '0px'],
          radius: ['0px', '7px', '0px', '0px'],
        });
        await page
          .locator('#rtl-directional')
          .evaluate((element) => element.style.removeProperty('writing-mode'));

        await page.evaluate(() => document.documentElement.setAttribute('dir', 'rtl'));
        assert.deepEqual(await directionalStyles('#rtl-directional'), {
          margin: ['0px', '11px'],
          padding: ['13px', '0px'],
          borderWidth: ['0px', '3px'],
          borderColor: ['rgb(23, 33, 43)', 'rgb(210, 42, 58)'],
          radius: ['0px', '7px'],
        });
        assert.deepEqual((await directionalStyles('#conflict-logical-last')).margin, [
          '0px',
          '18px',
        ]);
        assert.deepEqual((await directionalStyles('#conflict-physical-last')).margin, [
          '24px',
          '0px',
        ]);
        assert.deepEqual(await verticalStyles(), {
          margin: ['0px', '0px', '11px', '0px'],
          padding: ['13px', '0px', '0px', '0px'],
          borderWidth: ['0px', '0px', '3px', '0px'],
          radius: ['0px', '0px', '7px', '0px'],
        });
        await page.evaluate(() => document.documentElement.removeAttribute('dir'));
        assert.deepEqual(consoleErrors, []);

        if (process.env.UPDATE_EVIDENCE === '1') {
          fs.mkdirSync(path.join(root, 'docs', 'evidence'), { recursive: true });
          await page.screenshot({
            path: path.join(root, 'docs', 'evidence', 'hybrid-pipeline-mobile.png'),
            fullPage: true,
          });
          await page.setViewportSize({ width: 1024, height: 800 });
          await page.screenshot({
            path: path.join(root, 'docs', 'evidence', 'hybrid-pipeline-desktop.png'),
            fullPage: true,
          });
        }

        await page.close();
        browserResult.status = 'passed';
        delete browserResult.error;
      } catch (error) {
        browserResult.status = 'failed';
        browserResult.error = error.message;
        throw error;
      } finally {
        await browser?.close();
        writeBrowserReport();
      }
    },
  );
}
