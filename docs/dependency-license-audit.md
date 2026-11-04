# Dependency license audit

Native library use, generation and development require no Node graph.
MoonBit dependencies and frozen standards-data licenses are checked by
`moon run tools/release-audit.mbtx`. Extended verification separately checks
installed licenses and exact direct pins in `verification/` and
`tools/stylex-oracle/`. Their independent manifests and lockfiles define the
graphs; [toolchain.json](../toolchain.json) pins the host tools.

The table is a reviewed dependency inventory, not an exhaustive transitive
list. `.generated/node-licenses.json` records the concrete installed graphs.

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

The root, Luna module, native tooling, browser client and optional Vite package
each include matching `LICENSE` and `NOTICE` files. MIT attribution preserves
Meta's notice alongside MoonStyle contributors. `NOTICE` identifies StyleX,
its source revision, ported hashing credits and the boundary of derived work.
See [data sources](data-sources.md) for generation inputs and their licenses.

```sh
moon run tools/release-audit.mbtx
moon run tools/maint.mbtx -- licenses-node
vp -C verification exec bun audit --json
vp -C tools/stylex-oracle exec bun audit --json
```

Both Node installations are mandatory for extended CI. An absent oracle
cannot exempt its graph from license/security checks. Babel compiler and
StyleX packages are forbidden in the verification graph; Babel runtime and
diagnostic helpers used by Vite+ are allowed there. Packages without license
metadata must supply a license file or the audit fails.

The frozen graphs pin `source-map-js` 1.2.2 through an override. Dependency
updates require review of lockfile changes, licenses, security results and
the complete [validation workflow](ci-and-validation.md).
