# MoonStyle

**MoonStyle — Typed atomic CSS for MoonBit.**

为 MoonBit 提供类型安全的原子化 CSS。

MoonStyle extracts typed MoonBit style registries into deterministic atomic CSS
and nominal MoonBit mappings. Applications compose mappings with last-applied-wins
conflict rules and bind checked dynamic values through CSS custom properties.

MoonBit is the only supported authoring language. The library, property generator,
project CLI and development server are implemented in MoonBit. The default
generation, checks, build and development workflow requires MoonBit and a native
C toolchain, with no Node installation. Browser applications compile to JavaScript
using Moon's JS backend. Browser DOM access uses small JavaScript FFI bindings.

Rabbita is the only Tier-1 framework integration. The optional
[Luna adapter](packages/moonstyle-luna/README.md) is experimental.
The semantic core and runtime remain framework-neutral.

## Try the included application

Install the MoonBit compiler/core recorded in [toolchain.json](toolchain.json), then:

```bash
moon update
moon run tools/dev.mbtx
```

Open the printed local address. Successful edits rebuild and reload the page;
failed edits retain the last successful site and display diagnostics.
Alt/Option+Shift+S opens the applied-style inspector. Build a static site with:

```bash
moon run tools/build-demo.mbtx
moon run tools/validate.mbtx
```

Production output is `validation/dist/`. It contains `index.html`, `app.js` and
`styles.css`, without the inspector or development source maps.
Fresh installations need `moon update` before the first `.mbtx` script;
standalone scripts pin `moonbitlang/async` to 0.22.5.

## Author and apply styles

Import `lampclaw/moonstyle` as `@moonstyle` in a style package:

```moonbit
pub fn registry() -> @moonstyle.Registry {
  @moonstyle.registry("example/styles", [
    @moonstyle.rule("card")
      .padding(@moonstyle.px(12))
      .color(@moonstyle.rgb(24, 32, 40))
      .opacity(0.8, when=@moonstyle.hover),
  ])
}
```

Extraction emits CSS, typed mappings, their `moon.pkg`, and a versioned bundle.
Import the mappings as `@styles` and `lampclaw/moonstyle/rabbita` as `@css`:

```moonbit
let attrs = @css.attrs(@styles.card)
let composed = @moonstyle.compose(@styles.card)
  .when(active, @styles.active)
  .add(@styles.meter(progress))
```

The [executable quickstart](docs/quickstart.md) supplies complete component and
application packages, including exact contracts and checked dynamic values.
The [authoring guide](docs/authoring.md) covers typed values, composition, recipes,
themes and registered globals. [Tested value examples](src/expressions.mbt.md),
[effects](src/common_values.mbt.md), [CSS coverage](src/css_coverage.mbt.md) and
[theme/SVG paint](src/theme_paint.mbt.md) are included in the source tree.

## Distribution and verification

The source and published Mooncakes library version is **0.3.0**:
[`lampclaw/moonstyle@0.3.0`](https://mooncakes.io/docs/lampclaw/moonstyle).
Install the CLI from the matching reviewed source revision:

```bash
moon install ./tooling/native/src/cmd/moonstyle
moonstyle --help
```

The root module contains the library under `src/`. `validation/` holds the
included Rabbita app and fixtures. `tooling/native/` owns native tools;
`tooling/browser/` owns the MoonBit inspector client. All examples and acceptance
fixtures are in this repository.

[Extended verification](verification/README.md) installs isolated Node dependencies
for Playwright, css-tree and the live StyleX oracle. The optional
[`@lampclaw/moonstyle-tooling/vite`](tooling/vite/README.md) export calls the native CLI.
Strict CI requires these checks in addition to the native validation job.
See [0.3.0 release notes](docs/releases/0.3.0.md),
[CI and validation](docs/ci-and-validation.md), [current status](docs/current-status.md),
[distribution](docs/distribution.md) and [documentation index](docs/README.md).

StyleX is a pinned test-only semantic oracle; JavaScript authoring and
`@stylexjs/atoms` are outside the compatibility target. See the
[compatibility matrix](docs/stylex-compatibility.md) and
[styling-system comparison](docs/tailwindcss-vs-stylex.md).

## License and provenance

MoonStyle is MIT licensed and adapts selected [StyleX](https://github.com/meta/stylex)
atomic CSS semantics to MoonBit. Derived code retains the upstream Meta copyright
and MIT permission notice. See [LICENSE](LICENSE), [NOTICE](NOTICE),
[data sources](docs/data-sources.md) and [dependency licenses](docs/dependency-license-audit.md).
