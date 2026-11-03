# MoonStyle

**MoonStyle — Typed atomic CSS for MoonBit.**

为 MoonBit 提供类型安全的原子化 CSS。

MoonStyle compiles typed MoonBit style registries into deterministic atomic CSS
and nominal MoonBit mappings. Applications compose those mappings with
last-applied-wins conflict rules and bind checked dynamic values through CSS
custom properties. Ordinary static styles are extracted at build time.

MoonBit is the only supported authoring language. The product ships as a normal
MoonBit module with an explicit native extractor. JavaScript tools orchestrate
builds and tests; they do not implement CSS semantics or provide a JavaScript
authoring API. StyleX is a pinned test-only semantic oracle; its API shape and
`@stylexjs/atoms` authoring form are outside the compatibility target.

Rabbita is the only Tier-1 framework integration for 0.1.0. The optional
[Luna adapter](packages/moonstyle-luna/README.md) is experimental and carries no
compatibility promise. The semantic core and runtime remain framework-neutral.

## Start here

- [Runnable Rabbita example](validation/README.md): a complete application,
  style registries, extractor and browser fixtures included in this repository.
- [Executable consumer quickstart](docs/quickstart.md): a component and Rabbita app
  consuming a pinned source checkout and packed tooling.
- [Authoring guide](docs/authoring.md): rules, typed values, composition,
  recipes, component contracts, and registered globals.
- [Project tooling](tooling/README.md): CLI, Vite integration, diagnostics, and
  development inspection.
- [Documentation index](docs/README.md): architecture, contracts, maintenance,
  release gates and validation.
- [Regeneration](docs/regeneration.md): dependency-first extraction and artifact validation.

## Author and apply styles

Import `lampclaw/moonstyle` as `@moonstyle` in your style package:

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

The native extractor emits CSS, generated mappings, their `moon.pkg`, and a
versioned bundle. Import the mappings as `@styles` and
`lampclaw/moonstyle/rabbita` as `@css` in the view:

```moonbit
let attrs = @css.attrs(@styles.card)
```

Compose generated styles, conditions, and checked dynamic accessors with one
immutable list:

```moonbit
let composed = @moonstyle.compose(@styles.card)
  .when(active, @styles.active)
  .add(@styles.meter(progress))

match @css.try_attrs(composed) {
  Ok(attrs) => render(attrs)
  Err(errors) => render_dynamic_errors(errors)
}
```

The [quickstart](docs/quickstart.md) supplies complete compilable packages.
[Tested value examples](src/expressions.mbt.md) cover typed math,
gradients, background layers, and Grid. Additional examples cover
[common values and effects](src/common_values.mbt.md),
[CSS coverage](src/css_coverage.mbt.md), and
[themes and SVG paint](src/theme_paint.mbt.md).

## Current delivery

The public MoonBit library is available on
[Mooncakes](https://mooncakes.io/docs/lampclaw/moonstyle) as
`lampclaw/moonstyle@0.1.0`. Consumers can also use local paths or exact Git
commits. The private `@lampclaw/moonstyle-tooling` package supplies the CLI and
Vite adapter and is installed from packed source. Source is hosted at
[lucavance/moonstyle](https://github.com/lucavance/moonstyle).

The [current status](docs/current-status.md) records implemented capabilities,
schema versions and validation commands. All example sources and acceptance
fixtures are included in this repository. See [distribution](docs/distribution.md) and
[release policy](docs/release-policy.md).

Typed declarations, nominal component contracts, and explicit composition are
the main reasons to use MoonStyle in a MoonBit application. Utility classes
can suit a project that prefers preset design scales and existing tooling.
MoonStyle requires registries, extraction, and generated artifacts; it does not
ship a complete preset design system or merge arbitrary utility strings.
See the [styling-system comparison](docs/tailwindcss-vs-stylex.md) for these
tradeoffs and the limits of StyleX compatibility.

## Repository development

The root `moon.mod` declares `lampclaw/moonstyle`, with library source in
`src/`. The `validation/` submodule contains the Rabbita application, extractor
bridge and fixtures. Luna remains an independent optional module under
`packages/moonstyle-luna/`. The private validation Node workspace consumes
the root tooling package through `workspace:*`.

The pinned environment is defined in [toolchain.json](toolchain.json).
From that environment:

```bash
moon update
vp install --frozen-lockfile
vp dev
```

Run `moon update` after installing the pinned MoonBit toolchain, before the
first `.mbtx` script. It initializes the registry index on a fresh machine;
standalone scripts pin `moonbitlang/async` to 0.22.5.

```bash
vp run check-docs
vp check
vp run install-browsers
vp run validate
```

`validate` includes independent consumption of a development snapshot.
`vp run validate-ci` verifies the actual clean commit and also requires the
separately installed oracle and all three browsers. Follow
[CI and validation](docs/ci-and-validation.md) for the candidate gates and
[data maintenance](docs/data-sources.md) for reviewed generation updates.

## License and provenance

MoonStyle is MIT licensed and adapts selected StyleX atomic CSS semantics to
MoonBit. The hashing implementation and derived semantic behavior retain the
upstream Meta copyright and MIT permission notice. See [LICENSE](LICENSE) and
[NOTICE](NOTICE) for attribution and the pinned reference release. Each
independently packaged MoonBit module carries both files.
