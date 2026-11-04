import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'vite-plus/test';

const root = path.resolve(import.meta.dirname, '..');

test('same-named contracts preserve every implementation in generated consumers', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'style-contract-methods-'));
  const write = (filename, contents) => {
    const destination = path.join(directory, filename);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.writeFileSync(destination, contents);
  };
  const moon = (args) => {
    const result = spawnSync('moon', args, { cwd: directory, encoding: 'utf8' });
    assert.equal(result.status, 0, `${result.stdout}${result.stderr}`);
    assert.doesNotMatch(`${result.stdout}${result.stderr}`, /implicit_impl_as_method/);
    return result.stdout;
  };
  try {
    write(
      'moon.mod',
      'name = "local/contract-methods"\nversion = "0.0.0"\nimport { "lampclaw/moonstyle@0.2.0" }\n',
    );
    write('moon.work', `members = [".", ${JSON.stringify(root)}]\n`);
    write(
      'generator/moon.pkg',
      'import { "lampclaw/moonstyle", "lampclaw/moonstyle/extract" }\npkgtype(kind: "executable")\n',
    );
    write(
      'generator/main.mbt',
      `
fn dependency(bundle : @extract.CompiledBundle) -> @extract.DependencyBundle {
  match @extract.decode_bundle(bundle.manifest) {
    Ok(value) => value
    Err(errors) => abort(@extract.render_diagnostics_text(errors))
  }
}

fn main {
  let contract = @moonstyle.style_contract("button").allow_color()
  let rule = @moonstyle.rule("tone").color(@moonstyle.rgb(25, 50, 75))
  let first = @extract.compile_registry(
    @moonstyle.registry("fixture/first", [rule], contracts=[contract]),
    mappings_package="local/contract-methods/first",
  )
  let second = @extract.compile_registry(
    @moonstyle.registry("fixture/second", [rule], contracts=[contract]),
    mappings_package="local/contract-methods/second",
  )
  // Reverse input order to exercise the deterministic external-contract order.
  let dependencies = [dependency(second), dependency(first)]
  let local = @extract.compile_registry(
    @moonstyle.registry("fixture/local", [rule], contracts=[contract]),
    mappings_package="local/contract-methods/local",
    dependencies~,
  )
  let external = @extract.compile_registry(
    @moonstyle.registry("fixture/external", [rule]),
    mappings_package="local/contract-methods/external",
    dependencies~,
  )
  let output : Array[Json] = [first, second, local, external].map(bundle => {
    if !bundle.diagnostics.is_empty() {
      abort(@extract.render_diagnostics_text(bundle.diagnostics))
    }
    { "source": bundle.mappings, "manifest": bundle.mappings_manifest }
  })
  println(output.to_json().stringify())
}
`,
    );
    const bundles = JSON.parse(
      moon(['run', 'generator', '--target', 'js']).trim().split('\n').at(-1),
    );
    for (const [index, name] of ['first', 'second', 'local', 'external'].entries()) {
      write(`${name}/moon.pkg`, bundles[index].manifest);
      write(`${name}/styles.generated.mbt`, bundles[index].source);
    }
    write(
      'consumer/moon.pkg',
      `import {
  "local/contract-methods/first",
  "local/contract-methods/second",
  "local/contract-methods/local",
  "local/contract-methods/external",
}
`,
    );
    write(
      'consumer/consumer_wbtest.mbt',
      `
test "local and both external contracts compose the same mapping" {
  let expected = @local.button_styles(@local.tone).resolve()
  assert_eq(@first.button_styles(@local.tone).resolve(), expected)
  assert_eq(@second.button_styles(@local.tone).resolve(), expected)
  assert_eq(
    @local.tone.append_button_style(@local.empty_button_styles()).resolve(),
    expected,
  )
  assert_eq(
    @first.tone.append_button_style(@first.empty_button_styles()).resolve(),
    @first.button_styles(@first.tone).resolve(),
  )
}

test "both external contracts compose without a local contract" {
  let expected = @first.button_styles(@external.tone).resolve()
  assert_eq(@second.button_styles(@external.tone).resolve(), expected)
  assert_eq(
    @external.tone.append_button_style(@first.empty_button_styles()).resolve(),
    expected,
  )
}
`,
    );
    moon(['test', 'consumer', '--target', 'js']);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
