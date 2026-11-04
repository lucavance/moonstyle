# MoonStyle authoring guide

**MoonStyle — Typed atomic CSS for MoonBit.**

为 MoonBit 提供类型安全的原子化 CSS。

MoonBit module: `lampclaw/moonstyle`.

MoonBit-native typed atomic CSS authoring, extraction, runtime composition, and
framework adapters. MoonBit is the only supported authoring language; Rabbita
is the only Tier-1 framework integration for source 0.3.0. The semantic core is
framework-neutral. JavaScript, TypeScript, TSX, JSX, React, and StyleX drop-in
authoring APIs are unsupported.
Atomic CSS remains supported, but the `@stylexjs/atoms` authoring form is not a
compatibility target.

Mooncakes provides `lampclaw/moonstyle@0.3.0`. A pinned Git commit or local path
dependency is also supported; see
[distribution](distribution.md). Source 0.3.0 provides a native CLI installed
with `moon install` from a reviewed source checkout. Ordinary development
requires no Node installation.
See the [distribution guide](distribution.md),
[documentation index](README.md),
[module map](architecture.md#modules-and-packages), and
[consumer quickstart](quickstart.md).

## Rules and runtime composition

Author styles through the root package and an immutable rule chain:

```moonbit
///|
let app_variables : @moonstyle.VariableScope = @moonstyle.variable_scope("app")

///|
let accent : @moonstyle.ColorToken = app_variables.color_token(
  "accent",
  @moonstyle.rgb(38, 110, 190),
)

///|
pub fn registry() -> @moonstyle.Registry {
  @moonstyle.registry("example/app", [
    @moonstyle.rule("button")
      .padding(@moonstyle.px(8))
      .background_color(accent)
      .color(@moonstyle.rgb(255, 255, 255))
      .opacity(0.85, when=@moonstyle.hover)
      .padding(@moonstyle.px(8), when=@moonstyle.max_width(@moonstyle.px(640))),
  ])
}
```

Use generated Clear methods to remove an earlier composed property without
emitting another CSS rule:

```moonbit
let reset = @moonstyle.rule("reset").clear_color()
let composed = @moonstyle.compose(@styles.base).when(disabled, @styles.reset)
```

Type-local lifts such as `px(8).as_length_percentage()`,
`px(1).as_line_width()`, and `rgb(1, 2, 3).as_outline_color()` retain the same
typed categories and aggregate extraction diagnostics. Feature-rich modules
may replace a long `registry` argument list with
`registry_builder(module).rules(rules).theme(theme).recipe(recipe).build()`;
both paths lower through `registry_sheets`.

Use `Token[T]` for themeable values and `DynamicSlot[T]` for runtime-bound
values. `VariableScope` and concrete aliases such as `ColorToken` and
`LengthSlot` remove repeated scope strings without changing those roles. The
registry discovers both automatically. Root value constructors are total and
extraction aggregates invalid authored values into diagnostics. Generated
accessors with dynamic slots return a `Result`; combine them with static,
conditional, optional, or nested styles through one immutable root-facade list:

```moonbit
let composed = @moonstyle.compose(@styles.card)
  .when(active, @styles.active)
  .add(@styles.meter(progress_value))

match @css.try_attrs(composed) {
  Ok(attrs) => render(attrs)
  Err(errors) => render_dynamic_errors(errors)
}
```

Alias `lampclaw/moonstyle/rabbita` as `@css`. `StyleList::add` also accepts arrays
and nested lists; use `style_list()` only for an empty composition. A single
static mapping uses `@css.attrs(@styles.title)`, a homogeneous static array uses
`attrs_many`, recoverable mixed inputs use `try_attrs`, and an explicitly
fail-fast view uses `attrs_or_abort`. `styles`, `attrs_list`, and
`attrs_checked` are deprecated migration shims.

## Recipes and component contracts

Use a recipe when a component repeats a closed set of static variants:

```moonbit
let badge = @moonstyle.recipe("badge", [
  @moonstyle.recipe_rule().display(@moonstyle.Display::Flex),
])
.variant(
  "size",
  [
    @moonstyle.variant_choice("small", [@moonstyle.recipe_rule().padding(@moonstyle.px(4))]),
    @moonstyle.variant_choice("large", [@moonstyle.recipe_rule().padding(@moonstyle.px(12))]),
  ],
  default=Some("small"),
)
```

Extraction emits a typed generated function; the resulting list composes with
ordinary mappings, checked accessors, options, arrays, and selector markers.
Recipes deliberately reject dynamic slots and `unsafe_raw`.

Publish an exact component override boundary with generated typed policies:

```moonbit
let component : @moonstyle.VariableScope = @moonstyle.variable_scope("button")
let text : @moonstyle.ColorToken = component.color_token(
  "text",
  @moonstyle.rgb(20, 24, 28),
)

let button = @moonstyle.style_contract("button")
  .allow_color(
    values=[@moonstyle.rgb(255, 255, 255)],
    tokens=[text],
  )
  .allow_background_color()

@moonstyle.registry("example/button", rules, contracts=[button])
```

Generated namespaces use distinct nominal types. Eligible mappings implement
the component's open `ButtonStyleInput` trait; mappings containing any other
property or `unsafe_raw` do not. Compose heterogeneous nominal mappings through
`StyleList::add`, because a MoonBit array has one element type.

With no arguments, an allow method admits any reviewed non-raw value. Non-empty
`values`, `tokens`, `slots`, or `expressions` form an exact union and preserve source identity.
Theme and SVG paint use `color_scheme`, `scrollbar_colors`, `paint_none` and
direct Color/Token/Slot inputs to `fill` and `stroke`. Rabbita's `svg_attrs`,
`try_svg_attrs`, `svg_attrs_or_abort` and `svg_attrs_applied` apply styles to
native SVG attributes. See [the executable examples](../src/theme_paint.mbt.md) for
exact contracts and the supported paint grammar. Paint servers, context paints,
and stroke width/dash APIs remain outside that grammar.

## Artifacts and supported values

See [daily CSS and typed registration](../src/daily_css.mbt.md) for common text
properties, variable-font axes, rendering hints and explicit Token/Slot
`@property` registration. Registration is optional and supports Color, Length
and Number with independent initial values.

Artifact schema v14 and property API schema v18 are independent: the former
describes mapping packages, structured component policies, recipes, selector
markers, view-transition classes, fixed-point `priority100` rules, and
extracted bundles, while the latter
controls the generated 392-property authoring, Clear, and contract surface. Extraction
atomically manages CSS, nominal mappings, their generated `moon.pkg`, and the
bundle.

Named pages use `.page(page_auto())` or `.page(page_name("Report"))`, with
case-sensitive exact contracts through `.allow_page(values=[page_name("Report")])`.
Named pages select a page; they do not author `@page` rules. Browser support is
separate from syntax acceptance and must be checked for the application's print
workflow. See [registered globals and named pages](#registered-globals-and-named-pages).

Typed CSS coverage is documented in
[tested examples](../src/css_coverage.mbt.md) and the
[regeneration guide](regeneration.md).
Typed math, gradient families, background layers, and advanced Grid are covered
by [executable examples](../src/expressions.mbt.md). The [consumer quickstart](quickstart.md)
also compiles the same exact expression contracts across an independent component
and Rabbita application. Re-extract outdated dependencies before their consumers;
see the [artifact contract](artifact-schema-v14.md).

Scalar profile `stable-scalar-v2` uses Length inputs for the six logical-size
methods and Percentage inputs for `font_width`, with typed fallbacks, Clear,
and exact contracts. The semantic lock is schema v4 under
`stylex-0.19.1-application-order+font-aliases-v1`; its local extension makes
`fontWidth` and `fontStretch` share a composition slot. `font_width` rejects
negative and non-finite values; the shared Percentage type still allows negative
values where other properties permit them. Logical-size methods preserve their
reviewed Length subset, excluding `anchor-size()`, `calc-size()` and `stretch()`.
The [data-source guide](data-sources.md) owns coverage totals and
grammar review rules; [current status](current-status.md) owns
toolchain and validation facts.

Relational selectors start with `define_marker`; named container queries use
the typed `container_*` helpers. Modern reviewed APIs include typed shadows,
filters, masking, anchor positioning, `@position-try`, and view-transition
identifiers. Generated property calls automatically retain the MoonBit
callsite for diagnostics.

## Development and framework support

`moonstyle init` configures the native extractor and VS Code tasks.
`moonstyle dev` serves the application, watches styles and assets, retains the
last successful site on failure, and reloads after a corrected save. JSON
diagnostics retain MoonBit source spans. Production builds fail on the same
diagnostic. Development uses debug extraction and watches relevant source inputs.
The extractor cache identity includes its executable, normalized configuration
and dependency bundle contents. Production uses release extraction; both profiles
must emit byte-identical generated artifacts.

Rabbita integration ships in this module and is covered by the
[support policy](api-stability.md). Luna integration is isolated in the
experimental sibling `packages/moonstyle-luna` workspace module so neither the
semantic core nor ordinary users acquire a Luna dependency. The Luna adapter
has no API-stability or release-support promise. See the
[tooling guide](../tooling/README.md) for configuration, profiles, and inspection.

## Registered globals and named pages

`position_try_rule` exposes 39 reviewed descriptors: position anchor/area,
physical and logical inset/margin/min/max sizing, and self-alignment.

```mbt nocheck
let fallback = @moonstyle.position_try_rule("tooltip")
  .position_anchor(@moonstyle.position_anchor(@moonstyle.anchor_name("trigger")))
  .inset_inline_start(@moonstyle.px(8))
  .max_inline_size(@moonstyle.percent(90))
  .align_self(@moonstyle.Alignment::AlignmentStart)
let registry = @moonstyle.registry_builder("app/styles")
  .position_try(fallback)
  .build()
```

Repeated setters replace the descriptor and move it to the end, preserving
shorthand/longhand cascade order. Logical descriptors remain logical in RTL and
vertical writing modes. Each definition emits one global `@position-try` block
without ancestor selectors or atomic specificity. Invalid names, duplicate
low-level descriptors and invalid values fail extraction; `anchor-name` is not
an allowed descriptor.

`define_view_transition_class` accepts `.group`, `.image_pair`, `.old`, and
`.new` rules:

```mbt nocheck
let transition = @moonstyle.define_view_transition_class("card")
  .group(@moonstyle.rule("group").animation_duration(@moonstyle.ms(250)))
  .old(@moonstyle.rule("outgoing").opacity(0.5))
  .new(@moonstyle.rule("incoming").opacity(1.0))
let registry = @moonstyle.registry_builder("app/styles")
  .view_transition_class(transition)
  .build()
```

Apply the generated `<name>_view_transition_class` value through the ordinary
`view_transition_class` property. The class identity stays stable when pseudo
styles change. Repeated group setters replace the complete group; empty groups
emit no block. Rules accept typed static declarations, fallbacks, expressions,
Tokens and keyframes, with dependencies collected automatically. Conditions,
dynamic slots (including nested ones), Clear and `unsafe_raw` fail extraction.
The application starts transitions through the browser API; custom properties
on pseudo-elements follow browser inheritance rules.

`PageValue` exposes `page_auto()` and `page_name("Report")`. Names preserve case
and accept unescaped custom identifiers; `auto`, CSS-wide keywords, `default`,
whitespace and malformed names produce `STYLE_PAGE_NAME`. Use CSS-wide keywords
as whole values instead. Named pages support conditions, `PageValueFallbacks`,
`clear_page()` and exact case-sensitive contracts. A generated Frame method
does not establish browser animation or pagination support.
