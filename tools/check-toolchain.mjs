import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');

function readJson(filename) {
  return JSON.parse(fs.readFileSync(filename, 'utf8'));
}

function manifestField(source, name) {
  return source.match(new RegExp(`^${name} = "([^"]+)"$`, 'm'))?.[1] ?? null;
}

function commandOutput(command, args) {
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8' });
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(' ')} failed: ${result.stderr || result.stdout}`);
  }
  return `${result.stdout}${result.stderr}`.trim();
}

function osRelease() {
  const fields = Object.fromEntries(
    fs
      .readFileSync('/etc/os-release', 'utf8')
      .split('\n')
      .filter((line) => line.includes('='))
      .map((line) => {
        const separator = line.indexOf('=');
        return [line.slice(0, separator), line.slice(separator + 1).replace(/^"|"$/g, '')];
      }),
  );
  return { os: fields.ID ?? 'unknown', osVersion: fields.VERSION_ID ?? 'unknown' };
}

export function expectedToolchain(directory = root) {
  return readJson(path.join(directory, 'toolchain.json'));
}

export function inspectToolchain(directory = root) {
  const moonItems = JSON.parse(commandOutput('moon', ['version', '--all', '--json'])).items;
  const moon = moonItems.find((item) => item.name === 'moon')?.version ?? '';
  const moonCompiler = moonItems.find((item) => item.name === 'moonc')?.version ?? '';
  const moonHome = process.env.MOON_HOME || path.join(os.homedir(), '.moon');
  const coreManifest = fs.readFileSync(path.join(moonHome, 'lib/core/moon.mod'), 'utf8');
  const vitePlus = commandOutput('vp', ['--version']);
  const packageManifest = readJson(path.join(directory, 'node_modules/playwright/package.json'));
  const release = osRelease();

  return {
    schemaVersion: 1,
    release: { ...release, architecture: os.arch() },
    tools: {
      moonCli: moon.match(/^(\S+)/)?.[1] ?? moon,
      moonRevision: moon.match(/\(([0-9a-f]+)\s/)?.[1] ?? null,
      moonCompiler: moonCompiler.replace(/^v/, '').split(' ')[0],
      moonCore: manifestField(coreManifest, 'version'),
      vitePlus: vitePlus.match(/^vp v(\S+)/m)?.[1] ?? null,
      bun: commandOutput('bun', ['--version']).split('\n')[0],
      node: process.version.replace(/^v/, ''),
      playwright: packageManifest.version,
    },
  };
}

export function toolchainIssues(expected, actual, { requireRelease = false } = {}) {
  const issues = [];
  if (expected?.schemaVersion !== 1 || actual?.schemaVersion !== 1) {
    issues.push('toolchain contract must use schema version 1');
  }
  for (const [name, expectedValue] of Object.entries(expected?.tools ?? {})) {
    if (actual?.tools?.[name] !== expectedValue) {
      issues.push(`${name}: expected ${expectedValue}, got ${actual?.tools?.[name] ?? 'missing'}`);
    }
  }
  if (requireRelease) {
    for (const [name, expectedValue] of Object.entries(expected?.release ?? {})) {
      if (actual?.release?.[name] !== expectedValue) {
        issues.push(
          `release ${name}: expected ${expectedValue}, got ${actual?.release?.[name] ?? 'missing'}`,
        );
      }
    }
  }
  return issues;
}

export function checkToolchain({ directory = root, requireRelease = false } = {}) {
  const expected = expectedToolchain(directory);
  const actual = inspectToolchain(directory);
  const issues = toolchainIssues(expected, actual, { requireRelease });
  return { expected, actual, requireRelease, issues, passed: issues.length === 0 };
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(import.meta.filename)) {
  try {
    const report = checkToolchain({ requireRelease: process.argv.includes('--release') });
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
    if (!report.passed) process.exitCode = 1;
  } catch (error) {
    process.stderr.write(`${error.stack ?? error}\n`);
    process.exitCode = 1;
  }
}
