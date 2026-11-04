# Module Architecture

## Design Goals

- Deterministic styling across files and modules.
- Static CSS for ordinary production styles.
- Strongly typed common CSS properties and values.
- Predictable last-applied-wins composition.
- A backend-neutral semantic core.
- Native extraction without Babel or JavaScript CSS semantics.
- Committed, versioned artifacts for library distribution.
- MoonBit-only authoring with framework-neutral MoonBit runtime values.

## Modules and packages

The [workspace](../moon.work) contains three MoonBit modules. JavaScript tooling
and the isolated oracle have separate package manifests and installation graphs.

| Module or package | Responsibility and interface |
| --- | --- |
| `lampclaw/moonstyle` | Public authoring/composition facade: [guide](../docs/authoring.md), [interface](../src/pkg.generated.mbti) |
| `lampclaw/moonstyle/runtime` | Opaque styles, recursive inputs, strict dynamic errors: [interface](../src/runtime/pkg.generated.mbti) |
| `lampclaw/moonstyle/rabbita` | Tier-1 HTML/SVG attributes; `attrs` takes one static mapping, `attrs_many` a homogeneous array, `try_attrs` recursive inputs: [interface](../src/rabbita/pkg.generated.mbti) |
| `lampclaw/moonstyle/core` | Normalization, conflicts, RTL, hashing, priorities, atomic CSS: [interface](../src/core/pkg.generated.mbti) |
| `lampclaw/moonstyle/extract` | Nominal mappings, contracts, artifact validation/merge/rendering, compatibility conversion helpers: [interface](../src/extract/pkg.generated.mbti) |
| `lampclaw/moonstyle/extract/cli` | Native command runner, four-file output transactions, diagnostics and cache: [interface](../src/extract/cli/pkg.generated.mbti) |
| `lampclaw/moonstyle/builder` | Fluent declaration builders used by the public facade: [interface](../src/builder/pkg.generated.mbti) |
| `lampclaw/moonstyle/values` | Typed CSS values and expression provenance: [interface](../src/values/pkg.generated.mbti) |
| `lampclaw/moonstyle/properties` | Generated reviewed declarations and metadata: [interface](../src/properties/pkg.generated.mbti), [generation policy](data-sources.md) |
| `lampclaw/moonstyle/ir` | Shared registry and declaration representation: [interface](../src/ir/pkg.generated.mbti) |
| `lampclaw/moonstyle-luna` | Optional experimental sibling module; its static adapter takes arrays: [guide](../packages/moonstyle-luna/README.md), [interface](../packages/moonstyle-luna/pkg.generated.mbti) |
| `lampclaw/moonstyle-validation` | Repository validation consumer, demo and fixtures: [guide](../validation/README.md), [manifest](../validation/moon.mod) |
| `@lampclaw/moonstyle-tooling` | Private source-distributed CLI and Vite adapter: [guide](../tooling/README.md), [manifest](../package.json) |
| `tools/stylex-oracle` | Independently installed test-only Babel/StyleX graph: [guide](../tools/stylex-oracle/README.md) |

The repository root is the public module, with `source = "src"`. The validation
consumer is the separate `validation/` module; Luna remains under
`packages/moonstyle-luna/`. The root Node package owns the shared tooling, and
the private validation Node workspace uses it through `workspace:*`.

Inside `validation/`, `examples/styles` authors registries and
`cmd/style_extract` is the thin extractor main. `src/generated` contains
committed mappings; `src/css_manifest`, `src/css_runtime`, and `src/css_rabbita`
bridge the library into test/demo code, and `src/demo` hosts the Rabbita app.
`tests/component_a_generated` and its companion fixtures exercise cross-package
contracts; the [fixture guide](../validation/tests/dependency-fixtures/README.md)
distinguishes synthetic inputs from actual compiler output. The library's
`tests/core_fixtures` package supplies shared core-test inputs.

`core` must not depend on Node, Vite, browser DOM APIs, or Rabbita. `rabbita`
depends only on the runtime contract. Applications normally import only the
root package for authoring and composition, plus their view adapter. Generated
mapping packages import `runtime`, `values` when needed, and exact external
contract packages; extractor, generated, and test code may use the lower-level
packages directly.
`unsafe_raw` is a method on `Rule` and remains the only root escape hatch for an
unclassified property name.

MoonBit is the only authoring language. JavaScript, TypeScript, TSX, JSX, React,
and drop-in StyleX APIs are outside the architecture. JavaScript tools may
invoke extraction, bundle browser assets, and run differential or E2E tests.
Rabbita is the only Tier-1 framework integration for 0.2.0.
Luna is an experimental, independently versioned adapter outside the
core module; it has no compatibility promise or supported-application
release gate. Other MoonBit frameworks may implement the same opaque runtime
contract without changing `core`, but they remain experimental until promoted
through a separate support decision.

`core` owns `AtomicRule`, `CompiledNamespace`, and `CompiledStyleSet`; public
interfaces and distributed artifacts refer to their owning library packages.

The implemented 0.2.0 boundary uses artifact schema v14 for mapping package
identity, exact literal/Token/Slot component policies, recipes, selector
markers, view-transition classes and their canonical pseudo styles, fixed-point conditional priority, global
rules, semantic digests, and dependency metadata. Property API schema v18
generates the 392-property authoring and policy surface, including source-aware
`Rule::clear_*` methods. The native extractor validates and deterministically
merges configured component bundles before rendering application artifacts.

## Extraction

Applications provide a thin main package that imports explicit registries:

```text
typed MoonBit registries
  -> lampclaw/moonstyle/core
  -> lampclaw/moonstyle/extract
  -> generated CSS
  -> generated nominal MoonBit mappings
  -> generated mapping-package moon.pkg
  -> schema-versioned bundle JSON
```

The repository example main is `validation/cmd/style_extract`. JavaScript build tools may invoke this
command and load the resulting CSS, but do not normalize, hash, prioritize, or
serialize CSS themselves.

Repository generation consumes the committed application-order semantic lock
and validates its schema, profile, options, input digest, and semantic digest
before rendering the generated MoonBit table. It does not execute Babel. A
missing or stale lock fails with the explicit oracle refresh commands rather
than refreshing the upstream observations during an ordinary build.

The application-level `style.config.json` has exact versioned keys for the
generated mappings package, four output paths, dependency roots, and cache
directory. JavaScript orchestration discovers bundle files recursively in
stable order and passes explicit paths to the native CLI. The CLI independently
supports recursive `--dependency-root` discovery and `--check`; checking
compares all four deterministic outputs without replacing them.

Project orchestration is source-distributed through the private
`@lampclaw/moonstyle-tooling` Git/path package. Its `moonstyle` CLI owns
bootstrap, static/strict diagnosis, hash-gated upgrades, release generation,
non-replacing checks, and standalone debug watching; its Vite export owns the
plugin and inspector runtime. Both surfaces share one framework-neutral
extraction runner. `.moonstyle.json` schema v1 records
project paths and managed-file hashes but does not replace the user-owned
`style.config.json`. The Vite adapter sends tooling protocol v1 to the native
extractor. Missing protocol remains deprecated through the 0.2.x compatibility window; an
explicit mismatch fails before formal output mutation.

Component libraries commit all four artifacts. A consuming application
explicitly imports dependency bundles and merges them through `extract`.
Dependency module build scripts are never assumed to run in a consumer build.

A component may declare an any-safe or exact value policy with `StyleContract`.
Extraction generates an open nominal trait and contract-specific immutable
style list in the owner's mapping package. A consumer mapping implements that
trait only when all authored declarations match the property and value-source
policies and none use `unsafe_raw`. The active artifact carries the owner package,
generated trait, and complete policy closure so Git/path consumers can generate
deterministic imports. It also validates recipe rule references,
stable marker/view-transition identifiers, owners, packages, canonical order,
and collisions.

## Generated authoring surfaces

Every reviewed property exposes an unconditional Clear operation on `Rule`.
Clear lowers through the same IR and compiler as an ordinary declaration, but
writes nullable application-order tombstones without emitting CSS. A shorthand
clears every slot in its conflict closure. Conditional clearing is runtime
composition of the compiled mapping through `StyleList::when`; keyframes, raw
properties, and unreviewed properties do not create a second Clear path.

`RegistryBuilder` is an immutable convenience facade for feature-rich modules.
It collects the same rules, contracts, themes, recipes, markers, global
records, dependencies, and extra Tokens as `registry_sheets`, then delegates to
that function at `build`. Registry discovery, diagnostics, ordering, and
artifact generation therefore retain one implementation.

Recipes are declarative metadata plus generated style namespaces. Extraction
validates that every recipe declaration is safe static or token-backed, then
generates typed axes and an ordered runtime list. No runtime variant-to-CSS
compiler exists.

Selector markers are generated stable classes. A marker can be applied as an
ordinary static style and can be referenced by typed relational conditions.
Relational CSS uses `:where(...)` for the marker side and `:has(...)` only for
the descendant/sibling directions that require it. Container conditions have a
separate typed query AST and canonical renderer.

Named `@position-try` rules are global records. View-transition class
definitions generate typed values for the reviewed `view-transition-class`
property. Both participate in artifact hashing rather than being injected at
runtime.

## Composition

Each compiled declaration emits a rule for its original property and writes
its class and conflict tombstones to the slots recorded by the semantic lock.
Applying styles from left to right replaces the complete value in each affected
slot. Base and conditional classes share their base slot, while selectors and
fixed-point priorities govern the emitted rules. Shorthands retain their CSS
property rather than being expanded into separately hashed longhand rules.

Logical properties remain logical CSS because both StyleX logical polyfills
are disabled. The browser resolves direction and writing mode. Scalar profile
`stable-scalar-v2` preserves the existing six logical-size Length signatures
through an explicitly reviewed grammar subset; it does not expose the complete
`box-size`, `anchor-size()`, or `calc-size()` grammar. Raw declarations retain
the documented serialization-only boundary.

Dynamic declarations compile to a static rule referencing a typed CSS custom
property. `Token[T]` represents a themeable static custom-property reference;
`DynamicSlot[T]` represents a value that generated mappings bind at runtime.
`VariableScope` and concrete Token/Slot aliases are authoring conveniences over
those same role- and category-preserving types.
Generated dynamic accessors validate every supplied value and return all
`DynamicValueError` records in a `Result` whose success value is the namespace's
nominal mapping type. An immutable `StyleList` recursively
flattens static styles, checked results, optional values, arrays, and reusable
lists in source order; false conditions omit their complete input. Resolution
aggregates every dynamic failure before invoking the existing left-to-right
merge, and the Rabbita adapter does not mutate attributes on failure. Runtime
work is limited to merging and applying validated custom-property values; no
ordinary static rules are injected.

## Compatibility

StyleX compatibility is measured at semantic, CSS, and identifier levels.
StyleX 0.19.1 is the test-only oracle for the documented fixture subset.
Its Babel compiler and StyleX dependencies live in the private
`tools/stylex-oracle` package with an independent frozen lockfile. The package
is not a root workspace member, so the root installation and default validation remain
independent of it. `vp run install-oracle` installs it explicitly;
`vp run check-stylex-release`, `vp run refresh-oracle`, `vp run test-oracle`,
and `vp run audit-oracle` are maintenance tasks. Strict CI requires the live oracle tests and both dependency
audits after an explicit installation by the workflow. Oracle tasks fail
clearly when dependencies are absent, before semantic output mutation.
The release preflight verifies exact installed versions, the frozen lockfile
identities and integrity hashes, and the committed profile and digests. Refresh
checks the compiler contract while allowing a stale semantic lock to be repaired.
Vite+'s root test graph retains Babel runtime and diagnostic helpers; the
compiler and upstream semantic implementation remain isolated.
Semantic-lock schema v4 records raw upstream observations separately from the
local `fontWidth` to `fontStretch` slot alias in
`stylex-0.19.1-application-order+font-aliases-v1`. This extension also makes
font shorthand clearing cover both spellings; it is a documented local
semantic extension, not an upstream StyleX parity claim.
Identifier parity outside that subset is not a product commitment.
Atomic CSS is a retained semantic, while the `@stylexjs/atoms` authoring syntax
is explicitly outside the MoonBit compatibility target.

## Data And Artifacts

Property generation uses the exact versions in `data-sources.md`. Generated
sources are committed. Artifact structure is defined by
[artifact schema v14](artifact-schema-v14.md); incompatible changes increment `schemaVersion`.

Development inspection is a separate tooling plane. The extractor may write a
versioned debug manifest under the ignored cache directory, and Vite may use it
for a serve-only Inspector and source map. That sidecar is never a distributed
artifact, cannot add fields to runtime values or Rabbita DOM attributes, and is
absent from production builds.

## Maintenance invariants

One typed Rule/IR path owns CSS semantics; authoring conveniences do not create
another compiler. Raw property names are available only through `unsafe_raw`.
All cascade-sensitive arrays preserve semantic order. Core behavior stays
deterministic across JS, Wasm, Wasm GC, and native.

Generated sources, committed component artifacts, and `pkg.generated.mbti`
snapshots must be reproducible. A consumer never runs dependency build scripts.
Diagnostics use stable codes, severity, messages, and optional source spans.
Errors never replace previously valid formal artifacts; production extraction
and explicit checking fail closed. Last-valid development output is a tooling
recovery feature, not a successful validation result.

For a contract change, update semantic/compile-fail/artifact/browser coverage as
appropriate, regenerate sources and interfaces, document migration, then run
the [candidate validation](ci-and-validation.md). A plan alone does not activate
a schema. Current release requirements belong to [release policy](release-policy.md);
future research belongs to the [backlog](roadmap.md).

The normal MoonBit module, explicit native extractor and framework-neutral
runtime are the integration contract. Compiler integration is optional and
is not a release dependency.
