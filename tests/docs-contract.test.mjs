import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'vite-plus/test';
import { docsContractIssues } from '../tools/docs-contract.mjs';

const root = path.resolve(import.meta.dirname, '..');

function fixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'moonstyle-docs-'));
  t.onTestFinished(() => fs.rmSync(directory, { recursive: true, force: true }));
  const ignored = new Set([
    '.git',
    '.cache',
    '.generated',
    '.mooncakes',
    '_build',
    'dist',
    'node_modules',
  ]);
  fs.cpSync(root, directory, {
    recursive: true,
    filter: (source) =>
      !path
        .relative(root, source)
        .split(path.sep)
        .some((part) => ignored.has(part)),
  });
  return directory;
}

function updateJson(directory, filename, update) {
  const absolute = path.join(directory, filename);
  const value = JSON.parse(fs.readFileSync(absolute, 'utf8'));
  update(value);
  fs.writeFileSync(absolute, JSON.stringify(value));
}

test('active documentation matches implemented contracts and local links resolve', () => {
  assert.deepEqual(docsContractIssues(), []);
});

test('published library facts remain distinct from development consumption', (t) => {
  const directory = fixture(t);
  const release = JSON.parse(fs.readFileSync(path.join(directory, 'release-status.json'), 'utf8'));
  const earlierPublishedVersion = '0.0.1';
  updateJson(directory, 'release-status.json', (value) => {
    value.publishedLibraryVersion = earlierPublishedVersion;
  });
  for (const filename of [
    'README.md',
    'docs/authoring.md',
    'docs/current-status.md',
    'docs/distribution.md',
    'docs/release-policy.md',
  ]) {
    const absolute = path.join(directory, filename);
    fs.writeFileSync(
      absolute,
      fs
        .readFileSync(absolute, 'utf8')
        .replaceAll(
          `\`lampclaw/moonstyle@${release.publishedLibraryVersion}\``,
          `\`lampclaw/moonstyle@${earlierPublishedVersion}\``,
        ),
    );
  }
  assert.deepEqual(docsContractIssues(directory), []);
  fs.appendFileSync(
    path.join(directory, 'docs/quickstart.md'),
    `\nUse \`lampclaw/moonstyle@${earlierPublishedVersion}\`.\n`,
  );
  assert.ok(
    docsContractIssues(directory).some((issue) =>
      issue.startsWith('docs/quickstart.md has stale lampclaw/moonstyle@'),
    ),
  );
  updateJson(directory, 'release-status.json', (value) => {
    value.developmentVersion = '9.9.9';
  });
  assert.ok(
    docsContractIssues(directory).some((issue) =>
      issue.includes('release-status.json must distinguish'),
    ),
  );
});

test('missing active documents, local targets and anchors are actionable failures', (t) => {
  const directory = fixture(t);
  fs.unlinkSync(path.join(directory, 'docs/roadmap.md'));
  fs.appendFileSync(
    path.join(directory, 'docs/README.md'),
    [
      '\n[removed](missing-guide.md)',
      '[section](architecture.md#removed-section)',
      '[malformed](bad%ZZ.md)',
    ].join('\n'),
  );
  const issues = docsContractIssues(directory);
  assert.ok(issues.includes('Missing active documentation: docs/roadmap.md'));
  assert.ok(issues.some((issue) => issue.includes('links to missing docs/missing-guide.md')));
  assert.ok(
    issues.some((issue) => issue.includes('missing anchor architecture.md#removed-section')),
  );
  assert.ok(issues.some((issue) => issue.includes('invalid link: bad%ZZ.md')));
});

test('anchors support code, Unicode, duplicates, references and fenced examples', (t) => {
  const directory = fixture(t);
  fs.writeFileSync(
    path.join(directory, 'docs/anchors.md'),
    [
      '# `Config` & 中文?',
      '[self](#config--中文)',
      '# Repeat',
      '# Repeat',
      '# Repeat-1',
      '[duplicate](#repeat-1-1)',
      'Setext',
      '------',
      '[setext](#setext)',
      '<a id="custom-anchor"></a>',
      '[explicit](#custom-anchor)',
      '[referenced][repeat]',
      '[repeat]: #repeat-1',
      '```markdown',
      '# Ignore this heading',
      '[example](missing-example.md)',
      '```',
      '[angle](<space guide.md#spaced>)',
    ].join('\n'),
  );
  fs.writeFileSync(path.join(directory, 'docs/space guide.md'), '# Spaced\n');
  assert.deepEqual(docsContractIssues(directory), []);
  fs.appendFileSync(
    path.join(directory, 'docs/anchors.md'),
    '\n[fenced heading](#ignore-this-heading)\n',
  );
  assert.ok(
    docsContractIssues(directory).some((issue) =>
      issue.includes('missing anchor #ignore-this-heading'),
    ),
  );
});

test('current facts follow the toolchain, module manifests and generated metadata', (t) => {
  const directory = fixture(t);
  const quickstart = path.join(directory, 'docs/quickstart.md');
  fs.writeFileSync(
    quickstart,
    fs
      .readFileSync(quickstart, 'utf8')
      .replace('"@rabbita/vite": "0.2.0"', '"@rabbita/vite": "9.9.9"'),
  );
  updateJson(directory, 'toolchain.json', (value) => {
    value.tools.node = '99.0.0';
  });
  const manifest = path.join(directory, 'packages/moonstyle-luna/moon.mod');
  fs.writeFileSync(
    manifest,
    fs
      .readFileSync(manifest, 'utf8')
      .replace(/moonbitlang\/parser@[^"\s]+/, 'moonbitlang/parser@9.9.9'),
  );
  updateJson(directory, 'src/properties/property-metadata.json', (value) => {
    value.properties.pop();
  });
  const issues = docsContractIssues(directory);
  assert.ok(issues.some((issue) => issue.includes('record Node as 99.0.0')));
  assert.ok(issues.some((issue) => issue.includes('record `moonbitlang/parser` as 9.9.9')));
  assert.ok(issues.some((issue) => issue.includes('stale typed property count')));
  assert.ok(
    issues.some((issue) => issue.includes('app/package.json has stale @rabbita/vite@9.9.9')),
  );
});

test('documentation rejects superseded project records and stale current facts', (t) => {
  const directory = fixture(t);
  fs.mkdirSync(path.join(directory, 'docs/evidence'), { recursive: true });
  fs.writeFileSync(
    path.join(directory, 'docs/evidence/superseded.md'),
    '# Superseded project record\n',
  );
  assert.ok(
    docsContractIssues(directory).some((issue) => issue.includes('superseded project history')),
  );
  fs.appendFileSync(path.join(directory, 'docs/authoring.md'), '\n385 typed properties\n');
  assert.ok(
    docsContractIssues(directory).some((issue) =>
      issue.startsWith('docs/authoring.md has stale typed property count'),
    ),
  );
});

test('documentation rejects obsolete module naming and local review narratives', (t) => {
  const directory = fixture(t);
  const filename = path.join(directory, 'docs/review.md');
  for (const source of [
    '# Integration\nImport lampclaw/style-validation/examples/styles.\n',
    '# Distribution\nThe planned Mooncakes module name is configured.\n',
    '# Semantics\nThe upstream review on 2026-01-01 updated the adjacent reference checkout.\n',
  ]) {
    fs.writeFileSync(filename, source);
    assert.ok(
      docsContractIssues(directory).includes('docs/review.md contains superseded project history'),
    );
  }
});

test('packaged attribution uses the project name and retains upstream notices', (t) => {
  const directory = fixture(t);
  const license = path.join(directory, 'LICENSE');
  fs.writeFileSync(
    license,
    fs
      .readFileSync(license, 'utf8')
      .replace('MoonStyle contributors', 'example contributors')
      .replace('Copyright (c) Meta Platforms, Inc. and affiliates.\n', ''),
  );
  const issues = docsContractIssues(directory);
  assert.ok(issues.includes('LICENSE must name MoonStyle contributors'));
  assert.ok(issues.includes('LICENSE must retain the upstream copyright'));
  assert.ok(issues.includes('packages/moonstyle-luna/LICENSE must match the root LICENSE'));
  fs.unlinkSync(license);
  assert.ok(docsContractIssues(directory).includes('Missing packaged attribution: LICENSE'));
});

test('repository metadata and distribution guides agree on the hosted source', (t) => {
  const directory = fixture(t);
  const manifest = path.join(directory, 'moon.mod');
  fs.writeFileSync(manifest, fs.readFileSync(manifest, 'utf8').replace(/^repository = .*\n/m, ''));
  updateJson(directory, 'package.json', (value) => {
    value.repository = 'https://github.com/example/other';
  });
  const guide = path.join(directory, 'docs/authoring.md');
  fs.writeFileSync(
    guide,
    fs.readFileSync(guide, 'utf8').replaceAll('https://github.com/lucavance/moonstyle', ''),
  );
  const issues = docsContractIssues(directory);
  assert.ok(issues.some((issue) => issue.startsWith('lampclaw/moonstyle repository')));
  assert.ok(issues.some((issue) => issue.startsWith('package.json repository')));
  assert.ok(issues.includes('docs/authoring.md must include the canonical source repository'));
});

test('documentation rejects stale repository setup and missing bootstrap instructions', (t) => {
  const directory = fixture(t);
  fs.appendFileSync(
    path.join(directory, 'README.md'),
    '\nA hosted repository URL has\nnot been configured.\n',
  );
  const quickstart = path.join(directory, 'docs/quickstart.md');
  fs.writeFileSync(
    quickstart,
    fs.readFileSync(quickstart, 'utf8').replaceAll('moon update', 'moon check'),
  );
  const issues = docsContractIssues(directory);
  assert.ok(issues.includes('README.md contains stale unconfigured repository wording'));
  assert.ok(issues.includes('docs/quickstart.md must document MoonBit registry initialization'));
});
