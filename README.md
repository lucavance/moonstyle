# MoonStyle

MoonStyle — Typed atomic CSS for MoonBit.
为 MoonBit 提供类型安全的原子化 CSS。

MoonBit is the authoring language. This is a source-distributed 0.1.0 candidate;
no registry publication is implied.

The repository root declares `lampclaw/moonstyle`, with source under `src/`.
The separate `validation/` module is reserved for application integration.

Typed CSS values and expressions are available in `lampclaw/moonstyle/values`.

The IR and reviewed property metadata describe typed declarations.

The semantic core compiles deterministic atomic CSS and composition slots.

The runtime composes styles and validates dynamic bindings.

The native extraction package produces and validates distributable artifacts.

The root package now exposes fluent rules, recipes and exact contracts.

Rabbita is the supported framework adapter; the independent Luna module is experimental.

The private tooling package provides the CLI and Vite integration.

Use the exact environment in `toolchain.json`. Run `moon update`, then
`vp install --frozen-lockfile` and `vp run check-toolchain`.
Run `vp run moon-test` for the library packages available in this revision.

Source: https://github.com/lucavance/moonstyle

The project adapts selected StyleX semantics under MIT; retain LICENSE and NOTICE.
