# Dependency License Audit

The audit covers licenses in both JavaScript dependency graphs and the MoonBit
dependencies. Toolchain versions come from [toolchain.json](../toolchain.json);
package manifests and frozen lockfiles define the installed graph. Run the
commands below to validate that concrete installation.

The Babel compiler and StyleX remain isolated in a separately installed
private oracle package with its own frozen lockfile. The table records the
current pins. The release audit checks this inventory against the installed
graphs. A successful report applies only to the graph it measured.

| Dependency | Use | License |
| --- | --- | --- |
| `moonbit-community/rabbita@0.17.0` | MoonBit runtime adapter | Apache-2.0 |
| `mizchi/luna@0.25.2` | Experimental optional Luna adapter | MIT |
| `moonbitlang/moonback@0.8.9` | Rabbita indirect backend dependency | Apache-2.0 |
| `moonbitlang/async@0.22.5` | Async runtime and MoonBit automation | Apache-2.0 |
| `mizchi/signals@0.6.6` | Luna reactive dependency | MIT |
| `moonbitlang/parser@0.4.6` | Luna indirect parser dependency | Apache-2.0 |
| `moonbitlang/lexer@0.4.4` | Parser and Luna indirect lexer dependency | Apache-2.0 |
| `moonbitlang/moon_config@0.4.5` | Parser indirect configuration dependency | Apache-2.0 |
| `mizchi/js_web@0.13.1` | Luna web bindings | MIT |
| `mizchi/npm_typed@0.1.18` | Luna typed npm bindings | MIT |
| `moonbit-community/prettyprinter@0.4.11` | Parser manifest compatibility | Apache-2.0 |
| `moonbitlang/regexp@0.3.6` | Luna manifest compatibility | Apache-2.0 |
| `moonbitlang/x@0.5.6` | Filesystem, crypto, and encoding | Apache-2.0 |
| `@rabbita/vite@0.2.0` | Demo build adapter | Apache-2.0 |
| `playwright-core@1.64.1` | Browser validation | Apache-2.0 |
| `@babel/core@8.0.9` | Isolated oracle differential tests | MIT |
| `@mdn/browser-compat-data@8.1.7` | Generated property metadata | CC0-1.0 |
| `@stylexjs/babel-plugin@0.19.1` | Isolated oracle differential tests | MIT |
| `@stylexjs/shared@0.19.1` | Isolated oracle priorities | MIT |
| `browserslist@4.29.5` | Audited transitive override | MIT |
| `@stylexjs/stylex@0.19.1` | Isolated oracle differential tests | MIT |
| `@webref/css@8.7.8` | Generated property metadata | MIT |
| `css-tree@3.2.1` | Grammar AST analysis | MIT |
| `postcss@8.5.32` | Audited transitive override | MIT |
| `nanoid@3.3.20` | PostCSS indirect dependency | MIT |
| `source-map-js@1.2.2` | Audited security override | BSD-3-Clause |
| `vite-plus@1.4.0` | JavaScript toolchain | MIT |
| `@voidzero-dev/vite-plus-core@1.4.0` | Vite alias and override | MIT |
| `yuku-parser@0.19.0` / `yuku-core@0.19.0` | Vite core parser and native bindings | MIT |

The project license and StyleX-derived notice are packaged as `LICENSE` and
`NOTICE` in the repository root, shared by the public MoonBit module and tooling
package, and independently in `packages/moonstyle-luna`. The Luna copies match
the root files so packaging either module retains the upstream notices without
depending on a sibling checkout. `NOTICE` records the StyleX release and source
commit, the ported hashing implementation and its algorithm credits, and the
boundary between upstream-derived semantics and MoonStyle-specific work.

The exact-pinned data versions and generated-data policy are recorded
in [data sources](data-sources.md). The automated `vp run release-audit` command also checks
canonical repository metadata, installed dependency licenses, explicit
maintainer-controlled publication, candidate performance evidence, and active documentation contracts.
Default validation audits the root installation without requiring an oracle
installation. Strict `vp run validate-ci` requires the oracle installation,
audits licenses in both dependency graphs, and runs their security audits.
`vp run audit-dependencies` runs the root security audit.
`vp run audit-oracle` runs the separate oracle security audit after an explicit
`vp run install-oracle`; it fails clearly if that installation is missing.
An absent oracle cannot silently exempt its graph from strict CI.
Vite+'s test tooling retains `@babel/code-frame`, `@babel/runtime`, and
`@babel/helper-validator-identifier` in the root transitive graph; compiler
isolation does not mean that every Babel-prefixed helper package is removed.

Official package metadata declares MIT for
[Vite+ 1.4.0](https://registry.npmjs.org/vite-plus/1.4.0) and
[Vite+ core 1.4.0](https://registry.npmjs.org/@voidzero-dev%2Fvite-plus-core/1.4.0).
The toolchain bundles Vitest 5.0.5, Oxfmt 0.74.0, and Oxlint 1.89.0.
Both lockfiles pin source-map-js 1.2.2 to address the indexed-source-map
event-loop denial of service described in
[GHSA-68fv-2mgg-jv7q](https://github.com/advisories/GHSA-68fv-2mgg-jv7q).
Every installed package must provide license metadata or a license file; missing
metadata is an audit failure.
