# Module architecture

## Modules and packages

The public root module uses `source = "src"`. The [workspace](../moon.work)
contains five MoonBit modules; tools do not become library dependencies.

| Module | Responsibility |
| --- | --- |
| `lampclaw/moonstyle` | Typed authoring, semantic core, extraction, runtime and Tier-1 Rabbita adapter |
| `lampclaw/moonstyle-validation` | Runnable Rabbita example, component fixtures and acceptance tests |
| `lampclaw/moonstyle-luna` | Independent experimental Luna adapter |
| `lampclaw/moonstyle-tooling` | Native CLI, generation, maintenance, development server and performance tools |
| `lampclaw/moonstyle-devtools` | MoonBit development inspector with DOM FFI |

The [native tooling guide](../tooling/README.md) documents installation and
commands. Node dependencies are confined to [extended verification](../verification/README.md)
and the independently installed [StyleX oracle](../tools/stylex-oracle/README.md).
The [optional Vite adapter](../tooling/vite/README.md) invokes the native CLI.

## Semantic boundaries

MoonBit is the only supported authoring language. Rabbita is the only Tier-1
framework integration. Luna remains experimental. The backend-neutral `core`,
`ir`, `values`, `properties` and `builder` packages have no DOM, Node, Vite or
framework dependency. The public facade owns immutable `Rule`/`Frame` chains,
Tokens, DynamicSlots, themes, recipes, contracts and composition helpers.

`core` owns normalization, property conflicts, deterministic hashing, RTL,
fixed-point priorities and atomic rules. `runtime` owns opaque compiled
styles, recursive `StyleList` inputs and checked dynamic errors. Framework
adapters convert checked runtime values to native view attributes.
`unsafe_raw` is the explicit property-name escape hatch and offers no typed
conflict or value guarantees.

## Extraction

```text
typed MoonBit registry
  -> native extractor importing explicit registries
  -> normalize, validate and merge dependency artifacts
  -> one atomic transaction: CSS + nominal mappings + moon.pkg + bundle JSON
```

Artifact schema v14 includes exact value-source contracts, recipes, selector
markers, view-transition classes, typed globals and semantic dependency digests.
Mapping namespaces have distinct nominal types. A generated namespace implements
an open component contract only when every declaration satisfies its policy.
Dependency bundles are discovered deterministically and validated before output
replacement. Re-extract component leaves before applications; the
[artifact contract](artifact-schema-v14.md) defines the distribution boundary.

The validation consumer authors styles in `validation/examples/styles`, runs
`validation/cmd/style_extract`, commits outputs in `validation/src/generated`,
and renders the application in `validation/src/demo`. Synthetic fixtures have
a separate [maintenance guide](../validation/tests/dependency-fixtures/README.md).

## Project tools and browser output

`moon install` builds the native `moonstyle` CLI. `.moonstyle.json` schema v2
records managed-file digests and selected packages; schema v1 is accepted only
by `upgrade`. `style.config.json` schema v1 selects distinct output paths,
dependency roots and cache location. Path and ownership checks precede mutation.
Extraction uses tooling protocol v1 and structured compiler diagnostics.

`generate` and `check` use release extraction. `watch` and `dev` use debug
extraction and serialize rebuilds; formal bytes must match release output.
Cache identity includes executable, normalized configuration and dependency
contents. Corrupt entries fall back to extraction. Cache use remains adaptive
for small workloads rather than forcing an expensive cache path.

`build` compiles the application through Moon's JS backend and writes HTML,
JavaScript, CSS and `public/` assets. `dev` adds native HTTP/file watching,
full-page reload, a MoonBit inspector and CSS Source Map v3. Failed compilation
retains the last successful site. Production excludes inspector, debug manifest
and source map. Browser JavaScript is compiler output, not a Node runtime
requirement. Arbitrary npm dependency bundling belongs to optional host tooling.

## Generation and verification

Property API schema v18 defines 392 reviewed properties. Native generation
consumes a committed, content-addressed standards snapshot and reviewed grammar
policies. The isolated css-tree exporter refreshes that snapshot explicitly;
ordinary generation needs no Node installation. See [data sources](data-sources.md).

Application-order lock schema v4 freezes StyleX 0.19.1 observations and the
separate local `font-aliases-v1` extension. Native generation validates and
renders this lock without executing Babel. Live oracle refresh and differential
tests run only in the separate extended graph; see [application order](application-order-semantics.md).

Native validation covers generation, package boundaries, rejected programs,
installed consumers, performance evidence and native/Wasm/Wasm GC tests.
Extended verification adds JS execution, independent standards validation,
StyleX comparison and three browsers. [CI and validation](ci-and-validation.md)
defines both required release jobs. Public archive boundaries exclude tooling,
validation, Node graphs and private workspace modules.
