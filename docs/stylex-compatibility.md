# StyleX compatibility

Reviewed on 2026-11-03 against the published
[StyleX 0.19.1 release](https://github.com/meta/stylex/releases/tag/0.19.1),
commit `1fcb9a51cbecad2c82255e0f4b45cc072fa1a95a`. The isolated oracle pins this
release. Upstream main changes are reviewed separately and do not silently
change the compiler baseline, semantic lock or CSS data dependencies.

## API families and evidence

These rows map concepts to executable MoonBit behavior. An available entry
point does not imply support for every upstream option or CSS grammar.

| StyleX family | MoonStyle behavior | Scope and repository evidence |
| --- | --- | --- |
| `create` | `rule`, `sheet`, `registry` | Native extraction; [property tests](../tools/check-codegen.mbtx), [Rabbita example](../validation/examples/styles/styles.mbt) |
| `props` | `compose`, checked dynamic mappings | Application-order composition; [runtime tests](../src/runtime/runtime_wbtest.mbt) |
| `attrs` | Rabbita `attrs` / `try_attrs` | Rabbita is Tier-1; [adapter tests](../src/rabbita/rabbita_wbtest.mbt) |
| `defineVars` | `VariableScope`, typed Token/Slot | Literal defaults; [expression tests](../src/expressions_test.mbt); conditional and derived defaults remain planned |
| `createTheme` | `theme`, `Token::with_value` | Typed literal overrides; [theme tests](../src/theme_paint_test.mbt); conditional/derived overrides remain planned |
| `when.*` | Typed pseudo, media, supports, container and marker conditions | Reviewed selectors; [condition regressions](../src/upstream_regressions_test.mbt); arbitrary selector parity is not claimed |
| `keyframes` | Typed `frame` / `keyframes` | [Animation and value examples](../src/common_values.mbt.md) |
| `viewTransitionClass` | Stable identifiers and four pseudo style groups | [View-transition tests](../src/view_transition_test.mbt) |
| `positionTry` | `position_try_rule` | 39 reviewed descriptors; [tests](../src/position_try_test.mbt) |
| `firstThatWorks` | Ordered typed fallback builders | [Fallback and identity tests](../src/theme_paint_test.mbt) |
| `types.*` | Explicit `Token::registered` / `DynamicSlot::registered` | Partial: Color, Length, Number; [registration tests](../src/property_registration_test.mbt), [cross-module checks](../src/extract/property_registration_wbtest.mbt) |
| `defineConsts` | Ordinary MoonBit constants and functions | Native language alternative; no JavaScript evaluator |
| `env.*` | Explicit MoonBit parameters / build inputs | Native language alternative; no implicit JavaScript build environment |
| `@stylexjs/atoms` | Outside the authoring target | MoonBit Rule/IR remains the single extraction path |

Eleven API families have corresponding entry points, two use native language
alternatives, and one is outside scope. This is a classification of 14 families,
not a project completion percentage. For example, registration implements three
of the thirteen syntax categories currently listed in the
[StyleX types reference](https://stylexjs.com/docs/api/javascript/types).

## CSS and resolution boundaries

The generated metadata covers **392 of 822 WebRef properties (47.7%)**.
The remaining classifications are 190 unsupported grammars, 233 unsafe-only
properties and seven deprecated properties. This measures property names,
not the fraction of all valid CSS values or browser support.

The `daily-css-v1` profile adds `isolation`, `vertical-align`, `white-space`,
`text-wrap`, `will-change` and `font-variation-settings`. Its metadata explicitly
records excluded syntax. Vertical offsets and font axes are static;
will-change accepts reviewed hints; compound whitespace/wrapping grammars are
not exposed wholesale. Data versions stay fixed independently of StyleX.

The semantic lock tests 392 typed property representatives and one supplemental
font shorthand using **application-order**. Upstream's
[default configuration](https://stylexjs.com/docs/api/configuration/babel-plugin)
is property-specificity; MoonStyle deliberately keeps application-order.
Per-declaration named layers exist, while a global layer-order configuration
and layer-prefix policy remain unimplemented. React, JSX/TSX, Babel plugins
and atoms are not MoonBit authoring APIs.

## Upstream main review

| Area | Decision and executable evidence |
| --- | --- |
| URL and quoted payload normalization | Regression coverage already preserves URL paths, query strings, fragments and content; [tests](../src/upstream_regressions_test.mbt) and browser resource requests |
| Unitless values and dimensional zero inside functions | Existing normalization and math tests cover both; [common values](../src/common_values_test.mbt), [expressions](../src/expressions_test.mbt) |
| Reused conditions and conditional priority | Existing reused/inline condition equivalence and native priority tests; [regressions](../src/upstream_regressions_test.mbt) |
| Application-order and extraction performance reports | Retain the existing 100 / 6,000 / 10,000-rule budgets; profile before changing deduplication, sorting or cache thresholds |
| New APIs and framework-specific integrations | Review against MoonBit usage and the support policy before adopting; no automatic API replication |

The official [1.0 roadmap](https://github.com/meta/stylex/issues/1356) identifies
convenience, theme and tooling directions but supplies no release date. A
roadmap checkbox or bug report alone does not establish released behavior.
Adoption priorities and acceptance criteria are in the [roadmap](roadmap.md).

## Following upstream

For each published release, compare release notes, API docs and relevant source
changes; classify each as adopt, adapt, defer or outside scope. Add regression
tests for applicable fixes, then explicitly refresh the oracle and dependency
artifacts. Run source, consumer, browser, audit and performance gates together.
Review main fixes between releases without presenting them as a new release.
Update this matrix and the status guide when implementation boundaries change.
