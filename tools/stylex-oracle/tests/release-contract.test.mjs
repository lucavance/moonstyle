import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, test } from 'vite-plus/test';
import {
  BABEL_VERSION,
  ORACLE_PACKAGE_VERSIONS,
  STYLEX_RELEASE_COMMIT,
  STYLEX_RELEASE_TAG,
  STYLEX_RELEASE_VERSION,
  assertOracleReleaseContract,
  oracleReleaseContractIssues,
} from '../release-contract.mjs';
import { compileStylexSource } from '../stylex-compiler.mjs';

const root = path.resolve(import.meta.dirname, '../../..');
const oracleRoot = path.join(root, 'tools', 'stylex-oracle');
const manifest = JSON.parse(fs.readFileSync(path.join(oracleRoot, 'package.json'), 'utf8'));
const lockText = fs.readFileSync(path.join(oracleRoot, 'bun.lock'), 'utf8');
const moduleResolution = {
  rootDir: '/virtual/moonstyle',
  type: 'commonJS',
};

function compile(source, options = {}) {
  return compileStylexSource(source, {
    ...options,
    unstable_moduleResolution: moduleResolution,
  });
}

describe(`StyleX ${STYLEX_RELEASE_TAG} release contract`, () => {
  test('pins the published release, Babel compiler, and provenance', () => {
    expect(STYLEX_RELEASE_VERSION).toBe('0.19.1');
    expect(STYLEX_RELEASE_COMMIT).toBe('1fcb9a51cbecad2c82255e0f4b45cc072fa1a95a');
    expect(BABEL_VERSION).toBe('8.0.9');
    expect(oracleReleaseContractIssues({ manifest, lockText })).toEqual([]);
    expect(assertOracleReleaseContract({ manifest, lockText })).toEqual({
      stylexVersion: STYLEX_RELEASE_VERSION,
      releaseTag: STYLEX_RELEASE_TAG,
      releaseCommit: STYLEX_RELEASE_COMMIT,
      babelVersion: BABEL_VERSION,
    });
    for (const [name, version] of Object.entries(ORACLE_PACKAGE_VERSIONS)) {
      expect(manifest.devDependencies[name]).toBe(version);
    }
  });

  test('escapes quoted content values in generated CSS', () => {
    const compiled = compile(`
      import * as stylex from '@stylexjs/stylex';
      export const styles = stylex.create({
        quote: { content: 'He said "hello"' },
      });
    `);
    expect(compiled.rules).toHaveLength(1);
    expect(compiled.rules[0][1].ltr).toMatch(/^\.x[\w-]+\{content:"He said \\"hello\\""\}$/);
  });

  test('orders pixel max-width defineConsts breakpoints from wide to narrow', () => {
    const compiled = compile(`
      import * as stylex from '@stylexjs/stylex';
      export const breakpoints = stylex.defineConsts({
        small: '@media (max-width: 500px)',
        large: '@media (max-width: 1000px)',
      });
      export const styles = stylex.create({
        small: { color: { [breakpoints.small]: 'blue' } },
        large: { color: { [breakpoints.large]: 'red' } },
      });
    `);
    const mediaRules = compiled.css.split('\n').filter((css) => css.includes('{color:'));
    expect(mediaRules).toHaveLength(2);
    expect(mediaRules[0]).toContain('@media (max-width: 1000px)');
    expect(mediaRules[1]).toContain('@media (max-width: 500px)');
  });

  test('orders pixel min-width defineConsts breakpoints from narrow to wide', () => {
    const compiled = compile(`
      import * as stylex from '@stylexjs/stylex';
      export const breakpoints = stylex.defineConsts({
        large: '@media (min-width: 1500px)',
        small: '@media (min-width: 1000px)',
      });
      export const styles = stylex.create({
        large: { color: { [breakpoints.large]: 'red' } },
        small: { color: { [breakpoints.small]: 'blue' } },
      });
    `);
    const mediaRules = compiled.css.split('\n').filter((css) => css.includes('{color:'));
    expect(mediaRules).toHaveLength(2);
    expect(mediaRules[0]).toContain('@media (min-width: 1000px)');
    expect(mediaRules[1]).toContain('@media (min-width: 1500px)');
  });

  test('keeps generated max-width boundaries below the next integer pixel', () => {
    const compiled = compile(`
      import * as stylex from '@stylexjs/stylex';
      export const styles = stylex.create({
        a: {
          color: {
            default: 'blue',
            '@media (min-width: 400px)': 'red',
            '@media (min-width: 600px)': 'green',
          },
        },
      });
    `);
    const generated = compiled.css.split('\n').find((css) => css.includes('min-width: 400px'));
    expect(generated).toContain('max-width: 599.98px');
    expect(generated).not.toContain('max-width: 599.99px');
  });

  test('keeps debug metadata from changing stable class identifiers', () => {
    const source = `
      import * as stylex from '@stylexjs/stylex';
      export const styles = stylex.create({ card: { color: 'red' } });
    `;
    const production = compile(source);
    const development = compile(source, { dev: true, enableDebugClassNames: true });
    expect(development.rules.map(([className]) => className)).toEqual(
      production.rules.map(([className]) => className),
    );
    expect(development.rules.every(([className]) => !className.includes('color-'))).toBe(true);
  });
});
