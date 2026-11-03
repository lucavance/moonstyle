import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import * as stylex from '@stylexjs/stylex';
import { describe, expect, test } from 'vite-plus/test';
import {
  APPLICATION_ORDER_OPTIONS,
  APPLICATION_ORDER_PRIORITY_SCALE,
  effectiveApplicationOrderRecords,
  renderApplicationOrderMoonbit,
} from '../../application-order.mjs';
import {
  evaluateApplicationOrderOracle,
  generateApplicationOrder,
} from '../generate-application-order.mjs';
import { compileStylexSource } from '../stylex-compiler.mjs';

const root = path.resolve(import.meta.dirname, '../../..');
const lock = JSON.parse(
  fs.readFileSync(path.join(root, 'src/core/application-order.lock.json'), 'utf8'),
);
const oracleRecords = [...lock.properties, ...lock.supplementalProperties];
const effectiveRecords = effectiveApplicationOrderRecords(lock);

function priority100(value) {
  return Math.round(value * APPLICATION_ORDER_PRIORITY_SCALE);
}

function compileOracle() {
  const namespaces = oracleRecords
    .map(
      (property, index) =>
        `  p${String(index).padStart(3, '0')}: { ${JSON.stringify(property.property)}: 'inherit' }`,
    )
    .join(',\n');
  const source = [
    "import * as stylex from '@stylexjs/stylex';",
    'export const applicationOrderOracle = stylex.create({',
    namespaces,
    '});',
    '',
  ].join('\n');
  const compiled = compileStylexSource(source, APPLICATION_ORDER_OPTIONS);
  const styles = evaluateApplicationOrderOracle(compiled.code);
  return { compiled, styles };
}

function namespaceName(index) {
  return `p${String(index).padStart(3, '0')}`;
}

function classTokens(value) {
  return (value ?? '').split(/\s+/).filter(Boolean).sort();
}

function modeledProps(records, classes) {
  const slots = new Map();
  records.forEach((record, index) => {
    for (const entry of record.entries) {
      slots.set(entry.slot, entry.role === 'class' ? classes[index] : null);
    }
  });
  return [...new Set([...slots.values()].filter(Boolean))].sort((left, right) =>
    left.localeCompare(right),
  );
}

function compileMoonBitOracle() {
  const result = spawnSync(
    'moon',
    ['run', 'src/tests/core_fixtures', '--target', 'js', '--release'],
    {
      cwd: root,
      encoding: 'utf8',
    },
  );
  expect(result.status, `${result.stdout}${result.stderr}`).toBe(0);
  return new Map(
    result.stdout
      .trim()
      .split('\n')
      .filter((line) => line.startsWith('application-order/'))
      .map((line) => {
        const [name, className, rulePriority100, ltr, rtl, entries] = line.split('\t');
        return [
          name.slice('application-order/'.length),
          { className, priority100: Number(rulePriority100), ltr, rtl, entries },
        ];
      }),
  );
}

describe('StyleX 0.19.1 application-order oracle and local font alias policy', () => {
  test('refresh reproduces the committed semantic lock and generated native table', async () => {
    const generated = await generateApplicationOrder({ write: false });
    expect(generated).toEqual(lock);
    expect(renderApplicationOrderMoonbit(generated)).toBe(
      fs.readFileSync(path.join(root, 'src/core/application_order.generated.mbt'), 'utf8'),
    );
  });
  test('preserves raw Babel records and emits the reviewed effective native entries', () => {
    const { compiled, styles } = compileOracle();
    const moonbit = compileMoonBitOracle();
    const rules = new Map(
      compiled.rules.map(([className, css, priority]) => [
        className,
        { css, priority100: priority100(priority) },
      ]),
    );
    const classes = [];
    for (const [index, record] of oracleRecords.entries()) {
      const entries = Object.entries(styles[namespaceName(index)]).filter(
        ([key]) => !key.startsWith('$$'),
      );
      const live = entries.filter(([, value]) => value !== null);
      expect(live).toHaveLength(1);
      const className = live[0][1];
      const rule = rules.get(className);
      classes.push(className);
      expect(
        entries.map(([slot, value]) => ({
          slot,
          role: value === null ? 'tombstone' : 'class',
        })),
      ).toEqual(record.entries.map(({ slot, role }) => ({ slot, role })));
      expect(rule.priority100).toBe(record.priority100);
      expect({
        ltr: rule.css.ltr.replaceAll(className, '<CLASS>'),
        rtl: rule.css.rtl?.replaceAll(className, '<CLASS>') ?? null,
      }).toEqual(record.css);
      expect(moonbit.get(record.property)).toEqual({
        className,
        priority100: record.priority100,
        ltr: rule.css.ltr,
        rtl: rule.css.rtl ?? '-',
        entries: effectiveRecords[index].entries
          .map((entry) => `${entry.slot}=${entry.role === 'class' ? className : 'null'}`)
          .join(','),
      });
    }
    expect(moonbit.size).toBe(lock.properties.length + lock.supplementalProperties.length);

    let conflictEdges = 0;
    for (let left = 0; left < lock.properties.length; left += 1) {
      const leftSlots = new Set(lock.properties[left].entries.map((entry) => entry.slot));
      for (let right = left + 1; right < lock.properties.length; right += 1) {
        if (!lock.properties[right].entries.some((entry) => leftSlots.has(entry.slot))) {
          continue;
        }
        conflictEdges += 1;
        for (const order of [
          [left, right],
          [right, left],
        ]) {
          const expected = classTokens(
            stylex.props(styles[namespaceName(order[0])], styles[namespaceName(order[1])])
              .className,
          );
          expect(
            modeledProps(
              order.map((index) => lock.properties[index]),
              order.map((index) => classes[index]),
            ),
          ).toEqual(expected);
        }
      }
    }
    expect(conflictEdges).toBe(481);
  });

  test('locks container and relational condition priorities at fixed-point precision', () => {
    const relationMethods = {
      ancestor: 'ancestor',
      descendant: 'descendant',
      'any-sibling': 'anySibling',
      'sibling-before': 'siblingBefore',
      'sibling-after': 'siblingAfter',
    };
    const relational = lock.conditionFixtures.relational;
    const namespaces = relational.map((fixture, index) => {
      const method = relationMethods[fixture.relation];
      return `  r${String(index).padStart(3, '0')}: { color: { [stylex.when.${method}(${JSON.stringify(
        fixture.selector,
      )})]: 'inherit' } }`;
    });
    namespaces.push("  containerPriority: { color: { '@container (min-width: 1px)': 'inherit' } }");
    const compiled = compileStylexSource(
      [
        "import * as stylex from '@stylexjs/stylex';",
        'export const applicationOrderOracle = stylex.create({',
        namespaces.join(',\n'),
        '});',
      ].join('\n'),
      APPLICATION_ORDER_OPTIONS,
    );
    const styles = evaluateApplicationOrderOracle(compiled.code);
    const rules = new Map(
      compiled.rules.map(([className, css, priority]) => [
        className,
        { css, priority100: priority100(priority) },
      ]),
    );
    relational.forEach((fixture, index) => {
      const namespace = styles[`r${String(index).padStart(3, '0')}`];
      const className = Object.entries(namespace).find(
        ([slot, value]) => !slot.startsWith('$$') && value !== null,
      )?.[1];
      const rule = rules.get(className);
      expect(rule?.priority100).toBe(fixture.priority100);
      expect(rule?.css.ltr.replaceAll(className, '<CLASS>')).toBe(fixture.css);
    });
    const containerClass = Object.entries(styles.containerPriority).find(
      ([slot, value]) => !slot.startsWith('$$') && value !== null,
    )?.[1];
    const containerRule = rules.get(containerClass);
    expect(containerRule?.priority100).toBe(330000);
    expect(lock.conditionFixtures.container.priority100).toBe(330000);
    expect(
      relational
        .filter((fixture) => fixture.selector === ':hover')
        .map((fixture) => fixture.priority100),
    ).toEqual([301130, 301630, 302130, 303130, 304130]);
    expect(
      relational
        .filter((fixture) => fixture.stateKind !== 'pseudo')
        .every((fixture) => fixture.priority100 === 304000),
    ).toBe(true);
  });
});
