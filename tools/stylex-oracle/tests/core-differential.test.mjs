import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { test } from 'vite-plus/test';
import { isDeepStrictEqual } from 'node:util';
import {
  APPLICATION_ORDER_OPTIONS,
  APPLICATION_ORDER_PRIORITY_SCALE,
} from '../../application-order.mjs';
import { compileStylexSource } from '../stylex-compiler.mjs';

const root = path.resolve(import.meta.dirname, '../../..');
const applicationOrderLock = JSON.parse(
  fs.readFileSync(path.join(root, 'src/core/application-order.lock.json'), 'utf8'),
);

const fixtures = [
  ['page-auto', 'page', 'auto'],
  ['page-custom-ident', 'page', 'MoonStyleReport'],
  ['color-red', 'color', 'red'],
  ['background-white', 'backgroundColor', '#ffffff'],
  ['display-grid', 'display', 'grid'],
  ['width-percent', 'width', '100%'],
  ['height-px', 'height', '12px'],
  ['min-height-viewport', 'minHeight', '100vh'],
  ['margin-four', 'margin', '0 0 12px'],
  ['padding-one', 'padding', '24px'],
  ['border-color', 'borderColor', '#cad3dc'],
  ['border-radius', 'borderRadius', '8px'],
  ['border-style', 'borderStyle', 'solid'],
  ['border-width', 'borderWidth', '1px'],
  ['font-family', 'fontFamily', 'Inter, ui-sans-serif, system-ui, sans-serif'],
  ['font-size', 'fontSize', '16px'],
  ['font-weight', 'fontWeight', '700'],
  ['font-stretch-condensed', 'fontStretch', 'condensed'],
  ['font-width-expanded', 'fontWidth', 'expanded'],
  ['font-width-percentage', 'fontWidth', '75%'],
  ['font-shorthand-inherit', 'font', 'inherit'],
  ['line-height', 'lineHeight', '1.2'],
  ['box-shadow', 'boxShadow', '0 18px 50px rgba(30, 45, 60, 0.12)'],
  ['opacity', 'opacity', '0.5'],
  ['overflow', 'overflow', 'hidden'],
  ['cursor', 'cursor', 'pointer'],
  ['math-calc', 'width', 'calc(40px + 2rem)'],
  ['math-clamp', 'width', 'clamp(10px, 25%, 100px)'],
  ['gradient-linear', 'backgroundImage', 'linear-gradient(90deg, red 10%, blue)'],
  ['gradient-radial', 'backgroundImage', 'radial-gradient(circle at 50% 50%, red, blue)'],
  ['gradient-conic', 'backgroundImage', 'conic-gradient(from 90deg at 50% 50%, red, blue)'],
  ['grid-auto-fit', 'gridTemplateColumns', '[start] repeat(auto-fit, minmax(100px, 1fr)) [end]'],
  ['grid-subgrid', 'gridTemplateColumns', 'subgrid [start] [end]'],
];

const directionalFixtures = [
  ['margin-inline-start', 'marginInlineStart', '8px'],
  ['margin-inline-end', 'marginInlineEnd', '8px'],
  ['padding-inline-start', 'paddingInlineStart', '8px'],
  ['padding-inline-end', 'paddingInlineEnd', '8px'],
  ['border-inline-start-color', 'borderInlineStartColor', 'red'],
  ['border-inline-end-color', 'borderInlineEndColor', 'red'],
  ['border-inline-start-width', 'borderInlineStartWidth', '1px'],
  ['border-inline-end-width', 'borderInlineEndWidth', '1px'],
  ['border-inline-start-style', 'borderInlineStartStyle', 'solid'],
  ['border-inline-end-style', 'borderInlineEndStyle', 'solid'],
  ['border-start-start-radius', 'borderStartStartRadius', '4px'],
  ['border-start-end-radius', 'borderStartEndRadius', '4px'],
  ['border-end-start-radius', 'borderEndStartRadius', '4px'],
  ['border-end-end-radius', 'borderEndEndRadius', '4px'],
];

const borderCompositeFixtures = [
  ['border-composite', 'border', '2px solid #123'],
  ['border-block-composite', 'borderBlock', 'thin dotted #123'],
  ['border-inline-colors', 'borderInlineColor', '#123 transparent'],
  ['border-top-left-radius-composite', 'borderTopLeftRadius', '4px 25%'],
  ['outline-composite', 'outline', 'thin auto #123'],
];

const directionalShorthandFixtures = [
  ['shorthand-margin', 'margin', '8px'],
  ['shorthand-padding', 'padding', '8px'],
  ['shorthand-border-color', 'borderColor', 'red'],
  ['shorthand-border-width', 'borderWidth', '1px'],
  ['shorthand-border-style', 'borderStyle', 'solid'],
  ['shorthand-border-radius', 'borderRadius', '4px'],
];

function compileWithMoonBit() {
  const result = spawnSync(
    'moon',
    ['run', 'src/tests/core_fixtures', '--target', 'js', '--release'],
    {
      cwd: root,
      encoding: 'utf8',
    },
  );
  assert.equal(result.status, 0, `${result.stdout}${result.stderr}`);
  return new Map(
    result.stdout
      .trim()
      .split('\n')
      .map((line) => {
        const [name, className, priority100, ltr, rtl] = line.split('\t');
        return [name, { className, priority100: Number(priority100), ltr, rtl }];
      }),
  );
}

function compileWithStyleX(property, value, options = {}) {
  const source = [
    "import * as stylex from '@stylexjs/stylex';",
    `export const styles = stylex.create({ fixture: { ${JSON.stringify(property)}: ${JSON.stringify(value)} } });`,
  ].join('\n');
  const compiled = compileStylexSource(source, {
    ...APPLICATION_ORDER_OPTIONS,
    ...options,
  });
  assert.equal(compiled.rules.length, 1);
  const [className, injectable, priority] = compiled.rules[0];
  return {
    className,
    priority100: Math.round(priority * APPLICATION_ORDER_PRIORITY_SCALE),
    ltr: injectable.ltr,
    rtl: injectable.rtl ?? '-',
  };
}

function compileClearWithStyleX(property) {
  const source = [
    "import * as stylex from '@stylexjs/stylex';",
    `export const styles = stylex.create({ fixture: { ${JSON.stringify(property)}: null } });`,
  ].join('\n');
  const compiled = compileStylexSource(source, APPLICATION_ORDER_OPTIONS);
  assert.deepEqual(compiled.rules, []);
  assert.equal(compiled.css, '');
  return [...compiled.code.matchAll(/^\s+([\da-zA-Z]+): null,?$/gm)]
    .map((match) => `${match[1]}=null`)
    .join(',');
}

test('MoonBit semantic core matches StyleX 0.19 basic atomic fixtures', () => {
  const moonbit = compileWithMoonBit();
  assert.equal(
    moonbit.size,
    fixtures.length +
      directionalFixtures.length +
      borderCompositeFixtures.length +
      directionalShorthandFixtures.length +
      applicationOrderLock.conditionFixtures.relational.filter((fixture) =>
        ['pseudo', 'functional'].includes(fixture.stateKind),
      ).length +
      6 +
      applicationOrderLock.properties.length +
      applicationOrderLock.supplementalProperties.length +
      12 +
      2,
  );
  const mismatches = [];
  for (const [name, property, value] of fixtures) {
    const actual = moonbit.get(name);
    const expected = compileWithStyleX(property, value);
    if (!actual || !isDeepStrictEqual(actual, expected)) {
      mismatches.push(`${name}: ${JSON.stringify({ actual, expected })}`);
    }
  }
  const matched = fixtures.length - mismatches.length;
  assert.ok(
    matched / fixtures.length >= 0.95,
    `StyleX compatibility ${matched}/${fixtures.length}; mismatches: ${mismatches.join(', ')}`,
  );
});

test('font aliases preserve oracle CSS hashes and apply the local runtime conflict policy', () => {
  const moonbit = compileWithMoonBit();
  for (const [name, property, value] of fixtures.filter(([name]) =>
    /^(font-stretch-|font-width-|font-shorthand-)/.test(name),
  )) {
    assert.deepEqual(moonbit.get(name), compileWithStyleX(property, value), name);
  }
  const stretch = compileWithStyleX('fontStretch', 'condensed').className;
  const width = compileWithStyleX('fontWidth', 'expanded').className;
  const font = compileWithStyleX('font', 'inherit').className;
  const expected = {
    'stretch-width': [width],
    'width-stretch': [stretch],
    'stretch-clear-width': [],
    'width-clear-stretch': [],
    'clear-stretch-width': [width],
    'clear-width-stretch': [stretch],
    'width-font': [font],
    'stretch-font': [font],
    'font-width': [font, width],
    'font-stretch': [font, stretch],
    'width-clear-font': [],
    'stretch-clear-font': [],
  };
  for (const [name, classes] of Object.entries(expected)) {
    const actual = moonbit.get(`font-alias/${name}`);
    assert.ok(actual, name);
    const compare = (left, right) => left.localeCompare(right);
    assert.deepEqual(
      actual.className.split(/\s+/).filter(Boolean).sort(compare),
      classes.sort(compare),
      name,
    );
  }
});

test('math gradients and grid values preserve the StyleX application-order profile', () => {
  const moonbit = compileWithMoonBit();
  for (const [name, property, value] of fixtures.filter(([name]) =>
    /^(math-|gradient-|grid-)/.test(name),
  )) {
    const actual = moonbit.get(name);
    const expected = compileWithStyleX(property, value);
    assert.equal(actual.priority100, expected.priority100, name);
    assert.equal(
      actual.ltr.replaceAll(actual.className, 'CLASS'),
      expected.ltr.replaceAll(expected.className, 'CLASS'),
      name,
    );
    assert.equal(actual.rtl, expected.rtl, name);
  }
});

test('MoonBit clear mappings match StyleX 0.19 null declarations', () => {
  const moonbit = compileWithMoonBit();
  for (const [name, property] of [
    ['clear-color', 'color'],
    ['clear-margin', 'margin'],
  ]) {
    const actual = moonbit.get(name);
    assert.deepEqual(
      actual,
      {
        className: '-',
        priority100: 0,
        ltr: compileClearWithStyleX(property),
        rtl: '-',
      },
      name,
    );
  }
});

test('MoonBit border composite rules match the selected StyleX 0.19 profile', () => {
  const moonbit = compileWithMoonBit();
  for (const [name, property, value] of borderCompositeFixtures) {
    assert.deepEqual(moonbit.get(name), compileWithStyleX(property, value), name);
  }
});

function normalizePhase3Css(css, kind) {
  if (kind === 'keyframes') {
    return css.replace(/@keyframes [^{]+/, '@keyframes NAME').replaceAll(';}', '}');
  }
  return css.replace(/\.[\da-z-]+(?=[:{])/i, '.CLASS');
}

test('MoonBit adopted condition, fallback, and keyframe semantics match StyleX 0.19', () => {
  const moonbit = compileWithMoonBit();
  const stylexSources = {
    condition:
      "import * as stylex from '@stylexjs/stylex'; export const styles=stylex.create({x:{':hover':{color:'red'}}});",
    fallback:
      "import * as stylex from '@stylexjs/stylex'; export const styles=stylex.create({x:{color:['red','blue']}});",
    keyframes:
      "import * as stylex from '@stylexjs/stylex'; export const fade=stylex.keyframes({from:{opacity:0},to:{opacity:1}});",
  };
  for (const [kind, source] of Object.entries(stylexSources)) {
    const expected = compileStylexSource(source, APPLICATION_ORDER_OPTIONS).css;
    const actual = moonbit.get(`phase3-${kind}`)?.ltr;
    assert.equal(normalizePhase3Css(actual, kind), normalizePhase3Css(expected, kind), kind);
  }
});

test('MoonBit logical rules match the selected StyleX 0.19 application-order profile', () => {
  const moonbit = compileWithMoonBit();
  const mismatches = [];
  for (const [name, property, value] of directionalFixtures) {
    const actual = moonbit.get(name);
    const expected = compileWithStyleX(property, value);
    if (!actual || !isDeepStrictEqual(actual, expected)) {
      mismatches.push(`${name}: ${JSON.stringify({ actual, expected })}`);
    }
  }
  assert.deepEqual(mismatches, []);
});

test('MoonBit shorthands match the selected StyleX 0.19 application-order profile', () => {
  const moonbit = compileWithMoonBit();
  for (const [name, property, value] of directionalShorthandFixtures) {
    const source = [
      "import * as stylex from '@stylexjs/stylex';",
      `export const styles = stylex.create({ fixture: { ${JSON.stringify(property)}: ${JSON.stringify(value)} } });`,
    ].join('\n');
    const expected = compileStylexSource(source, APPLICATION_ORDER_OPTIONS).rules.map(
      ([className, injectable, priority]) => ({
        className,
        priority100: Math.round(priority * APPLICATION_ORDER_PRIORITY_SCALE),
        ltr: injectable.ltr,
        rtl: injectable.rtl ?? '-',
      }),
    );
    const actual = [moonbit.get(name)];
    const byClassName = (left, right) => left.className.localeCompare(right.className);
    assert.deepEqual(actual.sort(byClassName), expected.sort(byClassName), name);
  }
});

test('MoonBit relational and container priorities match StyleX 0.19', () => {
  const moonbit = compileWithMoonBit();
  for (const fixture of applicationOrderLock.conditionFixtures.relational.filter((candidate) =>
    ['pseudo', 'functional'].includes(candidate.stateKind),
  )) {
    assert.equal(
      moonbit.get(`condition-relation-${fixture.relation}-${fixture.selector.slice(1)}`)
        ?.priority100,
      fixture.priority100,
      `${fixture.relation}(${fixture.selector})`,
    );
  }
  const relations = [
    ['ancestor', 'ancestor'],
    ['descendant', 'descendant'],
    ['any-sibling', 'anySibling'],
    ['sibling-before', 'siblingBefore'],
    ['sibling-after', 'siblingAfter'],
  ];
  for (const [name, method] of relations) {
    const source = [
      "import * as stylex from '@stylexjs/stylex';",
      `export const styles = stylex.create({ fixture: { color: { [stylex.when.${method}(':hover')]: 'red' } } });`,
    ].join('\n');
    const compiled = compileStylexSource(source, APPLICATION_ORDER_OPTIONS);
    assert.equal(compiled.rules.length, 1);
    assert.equal(
      moonbit.get(`condition-relation-${name}-hover`)?.priority100,
      Math.round(compiled.rules[0][2] * APPLICATION_ORDER_PRIORITY_SCALE),
      name,
    );
  }
  for (const [name, selector] of [
    ['attribute', '[aria-expanded="true"]'],
    ['compound', ':hover:active'],
  ]) {
    const source = [
      "import * as stylex from '@stylexjs/stylex';",
      `export const styles = stylex.create({ fixture: { color: { [stylex.when.ancestor(${JSON.stringify(
        selector,
      )})]: 'red' } } });`,
    ].join('\n');
    const compiled = compileStylexSource(source, APPLICATION_ORDER_OPTIONS);
    assert.equal(
      moonbit.get(`condition-relation-ancestor-${name}`)?.priority100,
      Math.round(compiled.rules[0][2] * APPLICATION_ORDER_PRIORITY_SCALE),
      name,
    );
  }
  const container = compileStylexSource(
    "import * as stylex from '@stylexjs/stylex'; export const styles=stylex.create({fixture:{color:{'@container (min-width: 1px)':'red'}}});",
    APPLICATION_ORDER_OPTIONS,
  );
  assert.equal(
    moonbit.get('condition-container')?.priority100,
    Math.round(container.rules[0][2] * APPLICATION_ORDER_PRIORITY_SCALE),
  );
});
