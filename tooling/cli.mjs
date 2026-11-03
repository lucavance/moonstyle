#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import {
  renderExtractionReport,
  renderWatchEvent,
  runProjectExtraction,
  watchProject,
} from './project-commands.mjs';
import { doctorProject, initProject, renderReport, upgradeProject } from './project.mjs';

const usage = `Usage: moonstyle <command> [options]

Commands:
  init       Create the project-owned style configuration and extractor bridge
  doctor     Validate the static project integration
  upgrade    Safely migrate managed files and exact legacy tooling copies
  generate   Generate the four formal style artifacts with the release extractor
  check      Verify that the four formal style artifacts are current
  watch      Regenerate formal style artifacts on relevant project changes

Common options:
  --root <directory>  MoonBit module root (default: current directory)
  --json              Emit a stable JSON report

generate/check/watch options:
  --verbose           Show resolved inputs, outputs, identity, and timings

watch --json emits versioned NDJSON events while the command is running.

init options:
  --styles-package <name>
  --extractor-package <path>
  --vite-config <path>
  --entry <path>      Repeat for multiple entrypoints

doctor options:
  --strict            Run native Moon checks and release extractor --check

upgrade options:
  --dry-run           Report the transaction without writing files
`;

class UsageError extends Error {}

function optionValue(args, index, option) {
  const argument = args[index];
  if (argument === option) {
    if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
      throw new UsageError(`${option} requires a value`);
    }
    return { value: args[index + 1], next: index + 2 };
  }
  if (argument.startsWith(`${option}=`)) {
    const value = argument.slice(option.length + 1);
    if (value === '') throw new UsageError(`${option} requires a value`);
    return { value, next: index + 1 };
  }
  return null;
}

function parse(command, args) {
  const options = {};
  const entrypoints = [];
  const allowedValues = new Map([
    ['--root', 'root'],
    ...(command === 'init'
      ? [
          ['--styles-package', 'stylesPackage'],
          ['--extractor-package', 'extractorPackage'],
          ['--vite-config', 'viteConfig'],
          ['--entry', 'entrypoints'],
        ]
      : []),
  ]);
  for (let index = 0; index < args.length;) {
    const argument = args[index];
    if (argument === '--json') {
      if (options.json) throw new UsageError('--json may only be specified once');
      options.json = true;
      index += 1;
      continue;
    }
    if (['generate', 'check', 'watch'].includes(command) && argument === '--verbose') {
      if (options.verbose) throw new UsageError('--verbose may only be specified once');
      options.verbose = true;
      index += 1;
      continue;
    }
    if (command === 'doctor' && argument === '--strict') {
      if (options.strict) throw new UsageError('--strict may only be specified once');
      options.strict = true;
      index += 1;
      continue;
    }
    if (command === 'upgrade' && argument === '--dry-run') {
      if (options.dryRun) throw new UsageError('--dry-run may only be specified once');
      options.dryRun = true;
      index += 1;
      continue;
    }
    let matched = false;
    for (const [flag, key] of allowedValues) {
      const parsed = optionValue(args, index, flag);
      if (parsed === null) continue;
      if (key === 'entrypoints') entrypoints.push(parsed.value);
      else {
        if (options[key] !== undefined) throw new UsageError(`${flag} may only be specified once`);
        options[key] = parsed.value;
      }
      index = parsed.next;
      matched = true;
      break;
    }
    if (!matched) throw new UsageError(`Unknown option for ${command}: ${argument}`);
  }
  if (entrypoints.length > 0) options.entrypoints = entrypoints;
  if (options.json && options.verbose) {
    throw new UsageError('--json and --verbose cannot be combined');
  }
  if (options.root !== undefined) options.root = path.resolve(options.root);
  return options;
}

export async function runCli(args = process.argv.slice(2)) {
  const [command, ...rest] = args;
  if (command === undefined || command === '--help' || command === '-h') {
    process.stdout.write(usage);
    return 0;
  }
  if (!['init', 'doctor', 'upgrade', 'generate', 'check', 'watch'].includes(command)) {
    process.stderr.write(`Unknown command: ${command}\n\n${usage}`);
    return 2;
  }
  if (rest.length === 1 && ['--help', '-h'].includes(rest[0])) {
    process.stdout.write(usage);
    return 0;
  }
  let options;
  try {
    options = parse(command, rest);
  } catch (error) {
    process.stderr.write(`${error.message}\n\n${usage}`);
    return 2;
  }
  if (command === 'watch') {
    return watchProject(options, {
      emit(event) {
        process.stdout.write(
          renderWatchEvent(event, {
            json: options.json ?? false,
            verbose: options.verbose ?? false,
          }),
        );
      },
    });
  }
  if (command === 'generate' || command === 'check') {
    const report = await runProjectExtraction(command, options);
    const output = renderExtractionReport(report, {
      json: options.json ?? false,
      verbose: options.verbose ?? false,
    });
    (options.json || report.passed ? process.stdout : process.stderr).write(output);
    return report.passed ? 0 : 1;
  }
  const report =
    command === 'init'
      ? initProject(options)
      : command === 'upgrade'
        ? upgradeProject(options)
        : await doctorProject(options);
  const output = renderReport(report, { json: options.json ?? false });
  (options.json || report.passed ? process.stdout : process.stderr).write(output);
  return report.passed ? 0 : 1;
}

if (process.argv[1] && fs.realpathSync(process.argv[1]) === fs.realpathSync(import.meta.filename)) {
  process.exitCode = await runCli();
}
