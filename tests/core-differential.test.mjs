import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { test } from 'vite-plus/test';

const root = path.resolve(import.meta.dirname, '..');
const lock = JSON.parse(
  fs.readFileSync(path.join(root, 'src/core/application-order.lock.json'), 'utf8'),
);

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

test('font alias runtime composition follows the reviewed local conflict policy', () => {
  const moonbit = compileWithMoonBit();
  const stretch = moonbit.get('font-stretch-condensed').className;
  const width = moonbit.get('font-width-expanded').className;
  const font = moonbit.get('font-shorthand-inherit').className;
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

test('MoonBit relational priorities follow the committed condition fixtures', () => {
  const moonbit = compileWithMoonBit();
  for (const fixture of lock.conditionFixtures.relational.filter((candidate) =>
    ['pseudo', 'functional'].includes(candidate.stateKind),
  )) {
    assert.equal(
      moonbit.get(`condition-relation-${fixture.relation}-${fixture.selector.slice(1)}`)
        ?.priority100,
      fixture.priority100,
      `${fixture.relation}(${fixture.selector})`,
    );
  }
});
