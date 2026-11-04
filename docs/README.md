# MoonStyle documentation

These guides describe source version 0.3.0, also published on Mooncakes.
Module manifests, generated interfaces,
reviewed metadata and versioned artifacts define the implemented contracts.

## Use MoonStyle

| Guide | Purpose |
| --- | --- |
| [Rabbita example](../validation/README.md) | Runnable application and browser fixtures included in the repository |
| [Quickstart](quickstart.md) | Executable component/app consumer with a Moon-installed native CLI |
| [Authoring](../docs/authoring.md) | Rules, composition, contracts, recipes and globals |
| [Typed expressions](../src/expressions.mbt.md) | Math, gradients, backgrounds and Grid |
| [Common values](../src/common_values.mbt.md) | Sizing, typography, corners, shadows and filters |
| [CSS coverage](../src/css_coverage.mbt.md) | Fallbacks, conditions, modern values and motion |
| [Theme and paint](../src/theme_paint.mbt.md) | Color schemes, scrollbars and SVG |
| [Daily CSS and registration](../src/daily_css.mbt.md) | Text, font axes, hints and opt-in typed custom properties |
| [Luna adapter](../packages/moonstyle-luna/README.md) | Experimental optional integration |
| [Project tooling](../tooling/README.md) | Native CLI, build/dev, diagnostics and inspection |
| [Distribution](distribution.md) | Mooncakes library, Git/local paths and native tooling |
| [Regeneration](regeneration.md) | Dependency-first artifact generation and cache rules |

## Understand the contracts

- [Architecture and module map](architecture.md)
- [API stability and support tiers](api-stability.md)
- [Application-order semantics](application-order-semantics.md)
- [StyleX compatibility matrix](stylex-compatibility.md)
- [Artifact schema v14](artifact-schema-v14.md)
- [Styling-system comparison](tailwindcss-vs-stylex.md)
- [Current API baseline](api-baseline-0.2.0.json)

## Maintain and release

- [0.3.0 release notes](releases/0.3.0.md)
- [Current status](current-status.md)
- [Pinned toolchain](../toolchain.json)
- [CSS data sources](data-sources.md)
- [Dependency license audit](dependency-license-audit.md)
- [Isolated StyleX oracle](../tools/stylex-oracle/README.md)
- [Synthetic dependency fixtures](../validation/tests/dependency-fixtures/README.md)
- [Repository validation consumer](../validation/README.md)
- [Release policy](release-policy.md)
- [CI and validation](ci-and-validation.md)
- [Development roadmap](roadmap.md)
