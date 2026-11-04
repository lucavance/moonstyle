# MoonStyle 0.2.0 status

MoonStyle provides typed atomic CSS authored in MoonBit. The Mooncakes module
includes the library, native extractor and Rabbita adapter. The source repository
also includes project tooling, generated mappings and a Rabbita browser example.

## Implemented contracts

| Contract | Current value |
| --- | --- |
| Library, optional Luna module, private tooling | 0.2.0 |
| Reviewed typed properties | 392 |
| Artifact schema | v14 |
| Property generator schema | v18 |
| Application-order semantic lock | v4 |
| Extraction cache pack | v4 |
| Tooling protocol / project ownership manifest | v1 / v1 |

The authoring API includes fluent rules, typed expressions, themes, dynamic
slots, exact component contracts, recipes, registered globals, and recursive
checked composition. Ordinary static CSS is extracted at build time. Runtime
work merges classes and validates custom-property bindings.

The `daily-css-v1` profile adds isolation, vertical alignment, white-space,
text wrapping, will-change hints and variable-font axes. Color, Length and
Number Tokens/Slots can explicitly opt into CSS `@property` registration.
The [compatibility matrix](stylex-compatibility.md) records supported subsets;
[tested examples](../src/daily_css.mbt.md) demonstrate the authoring API.

Core and runtime support JS, Wasm, Wasm GC, and native. Rabbita is the only
Tier-1 framework integration. The optional Luna module is experimental.
See [architecture](architecture.md), [authoring](../docs/authoring.md),
[tooling](../tooling/README.md), and [API stability](api-stability.md).

## Pinned environment

The authoritative [toolchain contract](../toolchain.json) selects:

| Tool | Version |
| --- | --- |
| Moon CLI | 0.1.20261029 |
| Moon revision | ee2274c |
| Moon compiler | 0.10.19+97801ee1b |
| Moon core | 0.10.19+97801ee1b |
| Vite+ | 1.4.0 |
| Bun | 1.4.4 |
| Node | 26.12.1 |
| Playwright | 1.64.1 |
| Release platform | Ubuntu 26.04 x64 |

CSS inputs and coverage are defined in [data sources](data-sources.md).
Module manifests pin MoonBit dependencies. StyleX 0.19.1 is an isolated,
test-only oracle under `stylex-0.19.1-application-order+font-aliases-v1`.
Standalone `.mbtx` scripts pin `moonbitlang/async` to 0.22.5. Initialize the
registry with `moon update` before running them on a fresh installation.

## Validation and delivery

`vp run validate` validates source and an independent development-snapshot
consumer. `vp run validate-ci` additionally requires the installed oracle,
three browsers, both dependency audits, and consumption of the actual clean
Git commit. Generated reports in `.generated/` identify the source they test.
`vp run benchmark-candidate` creates two measured performance reports; the
release audit enforces their budgets and matching fixture fingerprints.

Mooncakes provides `lampclaw/moonstyle@0.2.0`. Git and local-path consumers use
a reviewed source commit from
[lucavance/moonstyle](https://github.com/lucavance/moonstyle). The private
`@lampclaw/moonstyle-tooling` package is installed from packed source and is
not published to npm.

The [Rabbita example](../validation/README.md), component fixtures, tested value
examples and executable quickstart are included in the repository. Independent
consumer validation creates its component and application from the quickstart
and consumes tooling packed from the tested source revision. Hosted validation
records the exact source commit in
[Candidate CI](https://github.com/lucavance/moonstyle/actions/workflows/ci.yml).
See [release policy](release-policy.md) and [CI and validation](ci-and-validation.md).
