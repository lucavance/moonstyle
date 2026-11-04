# Executable native Git consumer quickstart

This complete component and Rabbita application consume source 0.3.0 from a
reviewed commit. The workflow uses MoonBit, a native C toolchain and Git.
Node and Vite are not required. Mooncakes also provides the 0.3.0 library;
the imports below intentionally resolve to the checked-out workspace source
so the CLI and library are verified from the same revision.

Install the compiler/core pinned in [toolchain.json](../toolchain.json), then:

```bash
git clone https://github.com/lucavance/moonstyle.git source
git -C source checkout --detach <reviewed-full-commit>
moon update
moon install ./source/tooling/native/src/cmd/moonstyle --bin ./bin
```

Use the same source revision for CLI and library. The marked files are executed
by `moon run tools/verify-consumer.mbtx`. That runner clones the exact candidate
through an independent local Git remote. `__COMPONENT_DIGEST__` is replaced with
the extracted component digest before generating the application.

Create the following files. Defer `app/src/demo/` until the first component and
app generation, so Moon can resolve imports of generated mapping packages.

<!-- consumer-file: moon.work -->
```moonbit
members = ["app", "components", "source"]
```

<!-- consumer-file: components/moon.mod -->
```moonbit
name = "consumer/components"
version = "0.0.0"
import { "lampclaw/moonstyle@0.3.0" }
preferred_target = "js"
source = "src"
```

<!-- consumer-file: components/src/styles/moon.pkg -->
```moonbit
import { "lampclaw/moonstyle" }
```

<!-- consumer-file: components/src/styles/styles.mbt -->
```moonbit
///|
pub fn width() -> @moonstyle.MathExpr[@moonstyle.Length] {
  let slot = @moonstyle.variable_scope("consumer").length_slot("offset", @moonstyle.px(10))
  @moonstyle.math_length(slot).add(@moonstyle.math_length(@moonstyle.px(100)))
}

///|
pub fn picture() -> @moonstyle.Image {
  let token = @moonstyle.variable_scope("consumer").color_token("color", @moonstyle.rgb(20, 100, 200))
  @moonstyle.linear_gradient([
    @moonstyle.color_stop(@moonstyle.color_mix(Oklab, token, @moonstyle.named_color("white"))),
    @moonstyle.color_stop(@moonstyle.rgb(255, 255, 255)),
  ], interpolation=@moonstyle.color_interpolation(Oklab))
}

///|
pub fn transform() -> @moonstyle.TransformList {
  @moonstyle.transform_list([@moonstyle.translate_z(@moonstyle.px(10)), @moonstyle.rotate_y(@moonstyle.deg(15.0))])
}

///|
pub fn tracks() -> @moonstyle.GridTrackList {
  @moonstyle.grid_tracks([@moonstyle.auto_fit(@moonstyle.grid_tracks([
    @moonstyle.minmax(@moonstyle.track_length(@moonstyle.px(40).as_length_percentage()), @moonstyle.fr(1.0)),
  ]))])
}

///|
pub fn registry() -> @moonstyle.Registry {
  @moonstyle.registry("consumer/components", [@moonstyle.rule("base").width(width())],
    contracts=[@moonstyle.style_contract("card")
      .allow_width(expressions=[width()])
      .allow_background_image(expressions=[picture()])
      .allow_transform(expressions=[transform()])
      .allow_grid_template_columns(expressions=[tracks()])])
}
```

<!-- consumer-file: app/moon.mod -->
```moonbit
name = "consumer/app"
version = "0.0.0"
import {
  "lampclaw/moonstyle@0.3.0",
  "consumer/components@0.0.0",
  "moonbit-community/rabbita@0.17.0",
}
preferred_target = "js"
source = "src"
```

<!-- consumer-file: app/src/styles/moon.pkg -->
```moonbit
import { "lampclaw/moonstyle", "consumer/components/styles" @component }
```

<!-- consumer-file: app/src/styles/styles.mbt -->
```moonbit
///|
pub fn registry() -> @moonstyle.Registry {
  @moonstyle.registry("consumer/app", [@moonstyle.rule("app")
      .width(@component.width())
      .background_image(@component.picture())
      .transform(@component.transform())
      .grid_template_columns(@component.tracks())],
    dependencies=[@moonstyle.dependency_ref("consumer/components", "__COMPONENT_DIGEST__")])
}
```

<!-- consumer-file: app/src/demo/moon.pkg -->
```moonbit
import {
  "lampclaw/moonstyle",
  "lampclaw/moonstyle/rabbita" @css,
  "consumer/app/generated" @styles,
  "consumer/components/generated" @component,
  "moonbit-community/rabbita",
  "moonbit-community/rabbita/html",
}
supported_targets = "js"
options("is-main": true)
```

<!-- consumer-file: app/src/demo/main.mbt -->
```moonbit
///|
fn main {
  let attrs = @css.attrs_or_abort(@component.card_styles(@styles.app(@moonstyle.px(20))))
  @rabbita.new(fn() { @rabbita.Val::constant(@html.div(attrs~, [@html.text("Independent consumer")])) }).mount("app")
}
```

<!-- consumer-file: app/index.html -->
```html
<!doctype html><html><head><meta charset="utf-8"><title>Style consumer</title><!-- moonstyle-assets --></head><body><div id="app"></div></body></html>
```

Generate the component first:

```bash
./bin/moonstyle init --root components
./bin/moonstyle generate --root components
```

Commit `components/src/generated/` with component source. Copy the generated
`styles.bundle.json` to `app/dependencies/component.bundle.json` and replace
`__COMPONENT_DIGEST__` in the app registry with its `semanticDigest` field.
Initialize the app and set `"dependencyRoots": ["dependencies"]` in its
`style.config.json`, then generate before creating `app/src/demo/`:

```bash
./bin/moonstyle init --root app
./bin/moonstyle generate --root app
```

After creating the renderer files, validate and build:

```bash
./bin/moonstyle doctor --strict --root components
./bin/moonstyle doctor --strict --root app
./bin/moonstyle check --root app
./bin/moonstyle build --root app
./bin/moonstyle dev --root app
```

The static site is `app/dist/`. Development serves the printed local URL and
reloads only after successful rebuilds. `watch` provides extraction-only NDJSON
events when a browser server is unnecessary. Re-extract outdated component
bundles leaf-first; editing schema/digest fields cannot upgrade them.
See [regeneration](regeneration.md) and [project tools](../tooling/README.md).
