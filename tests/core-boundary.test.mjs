import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'vite-plus/test';

const root = path.resolve(import.meta.dirname, '..');
const styleModule = root;

test('canonical core interface is isolated in the source module', () => {
  const packageConfig = fs.readFileSync(path.join(styleModule, 'src', 'core', 'moon.pkg'), 'utf8');
  const publicInterface = fs.readFileSync(
    path.join(styleModule, 'src', 'core', 'pkg.generated.mbti'),
    'utf8',
  );
  assert.doesNotMatch(packageConfig, /lampclaw\/moonstyle-validation\//);
  assert.doesNotMatch(publicInterface, /lampclaw\/moonstyle-validation\//);
  assert.match(publicInterface, /package "lampclaw\/moonstyle\/core"/);
  assert.match(publicInterface, /pub struct AtomicRule/);
});

test('the root source and package archive exclude private workspace modules', () => {
  for (const relative of ['examples', 'cmd', 'demo', 'templates', 'tools']) {
    assert.equal(fs.existsSync(path.join(styleModule, 'src', relative)), false, relative);
  }
  const manifest = fs.readFileSync(path.join(styleModule, 'moon.mod'), 'utf8');
  assert.doesNotMatch(manifest, /mooncakes/i);
  assert.match(manifest, /^name = "lampclaw\/moonstyle"$/m);
  assert.match(manifest, /^source = "src"$/m);
  assert.doesNotMatch(manifest, /lampclaw\/moonstyle-validation/);
  const packaged = spawnSync('moon', ['package', '--list'], { cwd: root, encoding: 'utf8' });
  assert.equal(packaged.status, 0, `${packaged.stdout}${packaged.stderr}`);
  const packageListing = `${packaged.stdout}${packaged.stderr}`;
  for (const name of ['moon.mod', 'LICENSE', 'NOTICE', 'src/moon.pkg']) {
    assert.ok(packageListing.split('\n').includes(name), name);
  }
  assert.doesNotMatch(packageListing, /^(?:validation|packages|tooling|tools|node_modules)\//m);
  assert.equal(fs.existsSync(path.join(root, 'moon.mod')), true);
  assert.equal(fs.existsSync(path.join(root, 'moon.work')), true);
});

test('an isolated workspace consumes the module through a local path dependency', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'style-path-consumer-'));
  try {
    fs.writeFileSync(
      path.join(directory, 'moon.mod'),
      'name = "local/style-core-consumer"\nversion = "0.0.0"\nimport { "lampclaw/moonstyle@0.2.0" }\n',
    );
    fs.writeFileSync(
      path.join(directory, 'moon.work'),
      `members = [".", ${JSON.stringify(styleModule)}]\n`,
    );
    fs.writeFileSync(
      path.join(directory, 'moon.pkg'),
      [
        'import {',
        '  "lampclaw/moonstyle" @moonstyle,',
        '  "lampclaw/moonstyle/core" @core,',
        '  "lampclaw/moonstyle/extract" @extract,',
        '}',
        '',
      ].join('\n'),
    );
    fs.writeFileSync(
      path.join(directory, 'consumer.mbt'),
      [
        '///|',
        'pub fn class_name() -> String {',
        '  let authored = @moonstyle.registry("local/style-core-consumer", [',
        '    @moonstyle.rule("box").unsafe_raw("color", "red"),',
        '  ])',
        '  let compiled : @core.CompiledStyleSet = @core.compile(authored.styles[0])',
        '  compiled.rules[0].class_name',
        '}',
        '',
        '///|',
        'pub fn capability_css() -> String {',
        '  @extract.compile_registry(',
        '    @moonstyle.registry_builder("consumer/capabilities")',
        '    .rules([@moonstyle.rule("report").page(@moonstyle.page_name("Report"))])',
        '    .position_try(@moonstyle.position_try_rule("fallback").max_inline_size(@moonstyle.px(100)))',
        '    .view_transition_class(@moonstyle.define_view_transition_class("card")',
        '      .group(@moonstyle.rule("group").opacity(0.5))',
        '      .image_pair(@moonstyle.rule("pair").opacity(0.8))',
        '      .old(@moonstyle.rule("old").opacity(0.0))',
        '      .new(@moonstyle.rule("new").opacity(1.0)))',
        '    .build(),',
        '  ).css',
        '}',
        '',
      ].join('\n'),
    );
    const result = spawnSync('moon', ['check', '--target', 'all'], {
      cwd: directory,
      encoding: 'utf8',
    });
    assert.equal(result.status, 0, `${result.stdout}${result.stderr}`);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
