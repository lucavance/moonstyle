import path from 'node:path';
import { initProject, renderReport } from '../tooling/project.mjs';

const repositoryRoot = path.resolve(import.meta.dirname, '..');

export function scaffold(targetDirectory) {
  const root = path.resolve(repositoryRoot, targetDirectory);
  const report = initProject({ root });
  if (!report.passed) {
    throw new Error(renderReport(report).trim());
  }
  return report;
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(import.meta.filename)) {
  const target = process.argv[2];
  if (!target) {
    console.error('Usage: vp run scaffold -- <target-directory>');
    process.exitCode = 2;
  } else {
    console.warn(
      'warning: vp run scaffold is deprecated; use vp exec moonstyle init --root <directory>',
    );
    try {
      const report = scaffold(target);
      process.stdout.write(renderReport(report));
    } catch (error) {
      console.error(error.stack ?? error);
      process.exitCode = 1;
    }
  }
}
