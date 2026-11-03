import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, test } from 'vite-plus/test';
import {
  APPLICATION_ORDER_PROFILE,
  APPLICATION_ORDER_LOCAL_EXTENSIONS,
  effectiveApplicationOrderRecords,
  validateApplicationOrderLock,
} from '../tools/application-order.mjs';

const root = path.resolve(import.meta.dirname, '..');
const metadata = JSON.parse(
  fs.readFileSync(path.join(root, 'src/properties/property-metadata.json'), 'utf8'),
);
const lock = JSON.parse(
  fs.readFileSync(path.join(root, 'src/core/application-order.lock.json'), 'utf8'),
);
const oracleRecords = [...lock.properties, ...lock.supplementalProperties];
const effectiveRecords = effectiveApplicationOrderRecords(lock);

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
        const [name, className, priority100, ltr, rtl, entries] = line.split('\t');
        return [
          name.slice('application-order/'.length),
          { className, priority100: Number(priority100), ltr, rtl, entries },
        ];
      }),
  );
}

describe('committed application-order semantics and local font alias policy', () => {
  test('is content addressed and covers the complete typed property surface', () => {
    expect(validateApplicationOrderLock(lock, metadata)).toBe(lock);
    expect(lock.profile.name).toBe(APPLICATION_ORDER_PROFILE);
    expect(lock.properties).toHaveLength(386);
    expect(lock.supplementalProperties.map((record) => record.property)).toEqual(['font']);
    expect(lock.localExtensions).toEqual(APPLICATION_ORDER_LOCAL_EXTENSIONS);
  });

  test('native compilation matches every committed rule and effective conflict entry', () => {
    const moonbit = compileMoonBitOracle();
    for (const [index, record] of oracleRecords.entries()) {
      const actual = moonbit.get(record.property);
      expect(actual, record.property).toBeDefined();
      expect(actual.priority100, record.property).toBe(record.priority100);
      expect(actual.ltr.replaceAll(actual.className, '<CLASS>'), record.property).toBe(
        record.css.ltr,
      );
      expect(actual.rtl === '-' ? null : actual.rtl.replaceAll(actual.className, '<CLASS>')).toBe(
        record.css.rtl,
      );
      expect(actual.entries, record.property).toBe(
        effectiveRecords[index].entries
          .map((entry) => `${entry.slot}=${entry.role === 'class' ? actual.className : 'null'}`)
          .join(','),
      );
    }
    expect(moonbit.size).toBe(387);
  });

  test('declares only the reviewed font alias divergence from the raw upstream lock', () => {
    const raw = new Map(oracleRecords.map((record) => [record.property, record]));
    const effective = new Map(effectiveRecords.map((record) => [record.property, record]));
    const stretchSlot = raw.get('fontStretch').entries[0].slot;
    expect(stretchSlot).toBe('kQqvRs');
    expect(raw.get('fontWidth').entries[0].slot).toBe('kv6f4V');
    expect(effective.get('fontWidth').entries).toEqual([
      { slot: stretchSlot, role: 'class', slotProperties: ['fontStretch', 'fontWidth'] },
    ]);
    for (const record of effectiveRecords) {
      const original = raw.get(record.property);
      expect(record.css).toEqual(original.css);
      expect(record.priority100).toBe(original.priority100);
      if (record.property !== 'fontWidth') {
        expect(record.entries.map(({ slot, role }) => ({ slot, role }))).toEqual(
          original.entries.map(({ slot, role }) => ({ slot, role })),
        );
      }
    }
    expect(effective.get('font').entries).toContainEqual({
      slot: stretchSlot,
      role: 'tombstone',
      slotProperties: ['fontStretch', 'fontWidth'],
    });
    expect(effective.get('font').priority100).toBe(100000);
    const typed = effectiveRecords.slice(0, lock.properties.length);
    let conflictEdges = 0;
    for (const [index, left] of typed.entries()) {
      const leftSlots = new Set(left.entries.map((entry) => entry.slot));
      conflictEdges += typed
        .slice(index + 1)
        .filter((right) => right.entries.some((entry) => leftSlots.has(entry.slot))).length;
    }
    expect(conflictEdges).toBe(482);
  });

  test('locks the reviewed border composite conflict relationships', () => {
    const byProperty = new Map(lock.properties.map((property) => [property.property, property]));
    for (const [left, right] of [
      ['border', 'borderTopColor'],
      ['borderBlock', 'borderBlockStartWidth'],
      ['borderInlineColor', 'borderInlineEndColor'],
      ['borderTopLeftRadius', 'borderStartStartRadius'],
      ['outline', 'outlineStyle'],
    ]) {
      const leftSlots = new Set(byProperty.get(left).entries.map((entry) => entry.slot));
      expect(byProperty.get(right).entries.some((entry) => leftSlots.has(entry.slot))).toBe(true);
    }
  });

  test('locks container and relational condition priorities at fixed-point precision', () => {
    const relational = lock.conditionFixtures.relational;
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
