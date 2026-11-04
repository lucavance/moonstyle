# Executable Git consumer quickstart

Check out a reviewed commit into `source/`. Use `moon.mod` imports and a
`moon.work` containing relative module paths. Install the tooling packed from
that same checkout into the application. This example uses Rabbita 0.17.0,
Vite+ 1.4.0, Bun 1.4.4, Node 26.12.1, and artifact schema v14.

Install the exact MoonBit environment from [toolchain.json](../toolchain.json),
then prepare the source checkout and registry:

```bash
git clone https://github.com/lucavance/moonstyle.git source
git -C source checkout --detach <reviewed-commit>
moon update
```

Replace `<reviewed-commit>` with the reviewed full commit SHA. `moon update`
initializes the registry index on a fresh machine before the first `.mbtx`
script; it does not select a different source commit. Keep the tooling and
library from that same checkout.

The marked files below are executed by `moon run tools/verify-consumer.mbtx`.
The runner creates an independent local Git remote, clones the exact candidate,
extracts and commits the component artifacts, then builds the application.
`__COMPONENT_DIGEST__` is replaced with the component's extracted semantic digest.
`__TOOLING_TARBALL__` is the package packed from `source/`. Neither placeholder
is a Moon dependency syntax.

<!-- consumer-file: moon.work -->
```moonbit
members = ["app", "components", "source"]
```

<!-- consumer-file: components/moon.mod -->
```moonbit
name = "consumer/components"
version = "0.0.0"
import { "lampclaw/moonstyle@0.2.0" }
preferred_target = "js"
```

<!-- consumer-file: components/styles/moon.pkg -->
```moonbit
import { "lampclaw/moonstyle" }
```

<!-- consumer-file: components/styles/styles.mbt -->
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
  "lampclaw/moonstyle@0.2.0",
  "consumer/components@0.0.0",
  "moonbit-community/rabbita@0.17.0",
}
preferred_target = "js"
```

<!-- consumer-file: app/.node-version -->
```text
26.12.1
```

<!-- consumer-file: app/styles/moon.pkg -->
```moonbit
import { "lampclaw/moonstyle", "consumer/components/styles" @component }
```

<!-- consumer-file: app/styles/styles.mbt -->
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

Create the following two renderer files **after the first component and app
generation**. Moon resolves every workspace package import before building the
native extractor, so an import of a generated package must wait until that
package exists. The executable quickstart enforces this bootstrap order.

<!-- consumer-file: app/main/moon.pkg -->
```moonbit
import {
  "lampclaw/moonstyle",
  "lampclaw/moonstyle/rabbita" @css,
  "consumer/app/src/generated" @styles,
  "consumer/components/src/generated" @component,
  "moonbit-community/rabbita",
  "moonbit-community/rabbita/html",
}
supported_targets = "js"
pkgtype(kind: "executable")
```

<!-- consumer-file: app/main/main.mbt -->
```moonbit
///|
fn main {
  let attrs = @css.attrs_or_abort(@component.card_styles(@styles.app(@moonstyle.px(20))))
  @rabbita.new(fn() { @rabbita.Val::constant(@html.div(attrs~, [@html.text("Independent consumer")])) }).mount("app")
}
```

<!-- consumer-file: app/package.json -->
```json
{
  "name": "independent-style-consumer",
  "private": true,
  "type": "module",
  "packageManager": "bun@1.4.4",
  "dependencies": {
    "@lampclaw/moonstyle-tooling": "file:__TOOLING_TARBALL__",
    "@rabbita/vite": "0.2.0",
    "vite": "npm:@voidzero-dev/vite-plus-core@1.4.0",
    "vite-plus": "1.4.0"
  }
}
```

<!-- consumer-file: app/vite.config.mjs -->
```javascript
import { defineConfig } from 'vite-plus';
import rabbita from '@rabbita/vite';
import moonStyle from '@lampclaw/moonstyle-tooling/vite';
export default defineConfig({ plugins: [moonStyle(), rabbita({ mainPkgDir: 'main' })] });
```

<!-- consumer-file: app/index.html -->
```html
<!doctype html><html><head><meta charset="utf-8"><title>Style consumer</title></head><body><div id="app"></div><script type="module" src="/entry.mjs"></script></body></html>
```

<!-- consumer-file: app/entry.mjs -->
```javascript
import 'virtual:moonstyle.css';
import '/main.js';
```

Run `moonstyle init`, then `generate` in the component module first. Commit
its generated mappings and bundle. Copy its bundle to the application's
`dependencies/` directory and add that directory to `style.config.json`'s
`dependencyRoots`. Initialize and generate the app, then run `doctor --strict`,
`check`, and `vp build`. `watch` is a separate foreground development loop.

For any outdated bundle, retain the component source and re-extract it with
tooling from the current reviewed revision before re-extracting the app. This
includes schema v13 dependencies and bundles with an old semantic digest. They are
rejected before any output changes. See the [regeneration guide](regeneration.md).
The CLI does not rewrite dependency manifests or guess Git dependency syntax.

Install the application's packages with `vp install`, which selects the
manifest's pinned Bun package manager and the validated Vite+ alias configuration.
The independent quickstart verifier exercises that package graph and bootstrap
order. See [project tooling](../tooling/README.md) for the consumer commands.
