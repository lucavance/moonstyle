# API Stability

Source version is 0.3.0; the published library is `lampclaw/moonstyle@0.2.0`.
The current public library interfaces match that published baseline.

The public module is `lampclaw/moonstyle`. Pin the library version or a reviewed
source commit, keep tooling aligned, and regenerate component and application
artifacts together; see
[regeneration](regeneration.md).

MoonBit is the only supported authoring language. JavaScript, TypeScript, TSX,
JSX, React, and drop-in StyleX APIs are not compatibility surfaces. MoonBit's
JavaScript and Wasm targets and JavaScript-based build/test tools remain
supported implementation paths, not authoring APIs.
The `@stylexjs/atoms` authoring syntax is likewise outside the compatibility
surface. Atomic CSS and StyleX application-order behavior remain supported
semantics; they do not imply an atoms-shaped MoonBit API.

Rabbita is the only Tier-1 framework integration for source 0.3.0. Its adapter behavior
is part of the compatibility and release boundary. The separate Luna module is
experimental: its checked-in interface snapshot detects accidental changes but
does not create a deprecation window, migration promise, or supported
application target.

The current implemented artifact boundary is schema v14. Typed math expressions,
gradients, background layers, extended Grid, exact expression contracts, typed conditions,
ordered fallbacks, keyframes, semantic digests, typed themes, multi-value
dynamic mappings, exact component contracts, recipes, selector markers,
container queries, fixed-point conditional priorities, modern registered
globals, and cross-module merge APIs are implemented. Compatibility conversion helpers are explicit low-level utilities. They cannot
infer missing contracts, value provenance or relational priorities. Active
dependencies must satisfy the current reader and be re-extracted from source
when their artifact or semantic identity differs.

All dependencies older than the current artifact or semantic identity must be
re-extracted, dependency-first. Typed expression APIs are documented in
[tested examples](../src/expressions.mbt.md). See the
[regeneration guide](regeneration.md) and
[CSS coverage examples](../src/css_coverage.mbt.md).

View-transition styles use [artifact v14](artifact-schema-v14.md). The four
group setters define pseudo styles, while identifier-only definitions retain
stable CSS names with no pseudo styles.

- Before `1.0.0`, minor versions may change public MoonBit authoring APIs when
  the release notes include a migration path. Patch versions do not make
  intentional source-breaking changes.
- Removal of a public API requires deprecation for at least one minor
  release.
- Raw property names are accepted only by root `unsafe_raw`. The escape hatch
  guarantees serialization only; conflict parsing, RTL interpretation, value
  validation, and type guarantees are explicitly unsupported.
- `core` application-order behavior is frozen for all 392 typed properties by
  the StyleX 0.19.1 semantic lock with the versioned local font-alias extension. Unsupported properties and extensions
  remain outside that compatibility statement.
- `runtime.CompiledStyle` is opaque authoring data. Generated code constructs
  application-order values through `runtime.compiled_v5`; `runtime.compiled`,
  `runtime.compiled_v2`, and `runtime.compiled_v3` remain compatibility
  constructors. The constructor name records the mapping encoding where it was
  introduced, not the active bundle schema. Application code should use
  generated nominal values.
- Artifact schema v14 is version checked. An incompatible artifact change must
  use a new schema version even before stable release.
- Reviewed property API and generated property metadata use schema v18. This is
  an internal generation contract and is versioned independently from bundles.
- Scalar profile `stable-scalar-v2` preserves the six logical-size Length
  signatures and includes `font_width` with the Percentage category.
  Its finite, non-negative requirement applies to
  literal values, Tokens, and DynamicSlots without introducing a raw-string API.
- Extractor debug manifest schema v1 and its `experimental`-alerted render and
  validation helpers are tooling-only. They support the native development server and inspector,
  are not re-exported by `lampclaw/moonstyle`, and carry no authoring compatibility
  promise. The sidecar is never a fifth distribution artifact.
- `.moonstyle.json` schema v2 is the native CLI ownership contract. `upgrade`
  accepts v1 metadata, preserves user edits and releases Vite/entry files from
  management. Normal commands require v2. The CLI uses extractor tooling
  protocol v1; incompatible explicit protocol versions fail before mutation.
- The supported authoring entry point is the root `lampclaw/moonstyle` package:
  immutable `Rule`/`Frame` chains, generated `Rule::clear_*` methods, typed
  condition shortcuts, `Token[T]`, `DynamicSlot[T]`, `VariableScope`, concrete
  Token/Slot aliases, `Theme`, `RegistryBuilder`, and the application-facing
  runtime composition facade.
- `registered(inherits=...)` is opt-in for Color, Length and Number Tokens/Slots.
  Existing unregistered variables keep their behavior. Initial values must be
  static colors, absolute lengths or finite numbers; relative defaults and
  derived/conditional theme values are outside this registration profile.
  Artifact v14 adds canonical `property` globals; re-extract v13 dependencies.
  Low-level `VarDefinition` construction now supplies `registration: None`
  for ordinary variables. Application authoring through Token/Slot constructors
  needs no change.
  The `properties`, `values`, `builder`, and `ir` packages support generated or
  internal implementation paths; consumers should not assemble declaration
  capability arrays from them.
- Root value constructors are total. Invalid authored values become aggregated,
  stable extraction diagnostics and are never emitted as CSS. Generated dynamic
  accessors return `Result[NamespaceStyle, Array[DynamicValueError]]`; callers
  must handle failure explicitly. Root `StyleList` recursively accepts static,
  checked, optional, array, and nested-list inputs while preserving order.
  `compose(input)` starts a non-empty composition. `StyleList::resolve`,
  `runtime.props_checked`, and Rabbita `try_attrs` never produce partial output;
  `attrs_or_abort` and `expect_dynamic` are explicit abort policies rather than
  the default path. `styles`, `attrs_list`, and `attrs_checked` are deprecated
  migration shims.
- CSS-wide keywords are accepted as whole property values. Typed `*Fallbacks`
  builders preserve literal, Token, Slot, and expression provenance; legacy
  homogeneous Array adapters are deprecated. Comma-separated animation,
  transition, mask and timeline lists remain single CSS declarations.
- Container style conditions compare typed token/slot custom properties on an
  ancestor container. Query references preserve defaults but do not create
  runtime accessor parameters on the querying element. Bind a dynamic value on
  the ancestor through an ordinary slot-backed style. Recipe conditions cannot
  reference dynamic slots.
- A generated `Rule::clear_*` declaration is an unconditional static conflict
  tombstone. It emits no CSS and clears every application-order entry owned by
  the reviewed property; runtime conditions belong on `StyleList::when`.
  `Frame`, `unsafe_raw`, and unreviewed properties do not expose Clear. Exact
  contracts accept Clear only when they admit the property itself.
- `RegistryBuilder` is an additive immutable facade over `registry_sheets`.
  Existing registry functions and free value-conversion functions remain
  supported alongside the builder and type-local `as_*` conversion methods.
- Generated MoonBit source is tied to its artifact schema and runtime
  constructor. Every namespace has a distinct nominal type. Heterogeneous
  mappings therefore compose through `StyleList::add`, not a single array
  literal. Regenerate mappings and their managed `moon.pkg` when upgrading the
  module; generated source text itself is not a stable hand-authored API.
- Exact component contracts are open generated traits. No-argument allow
  methods admit any reviewed non-raw value; non-empty typed `values`, `tokens`,
  `slots`, and `expressions` define an exact union. A mapping implements a contract only when
  every declaration preserves an admitted property and value-source identity,
  and no declaration uses `unsafe_raw`. The artifact binds each trait and policy
  to its owner module and `mappingsPackage`; handwritten implementations are
  outside the supported artifact contract.
- Semantic hashes are stable only within the same artifact schema and canonical
  normalization contract. A hash algorithm or canonicalization change requires
  an artifact schema revision.
- Recipes generate typed axes but return the existing immutable runtime list.
  Their declaration set is static/token-only, and their base, selected axes,
  and compounds compose in that fixed order. Generated recipe source is tied to
  the owning v14 artifact and is regenerated on upgrade.
- Selector markers and view-transition class definitions are opaque generated
  identities. Their stable CSS names are validated against module/name content;
  handcrafted substitutes are outside the supported artifact contract.
- StyleX application-order compatibility covers the 392-property semantic lock
  and its conflict edges. Lock schema v4 separates upstream oracle observations
  from `font-aliases-v1`, which makes `fontWidth` and `fontStretch` share a
  conflict slot and makes font shorthand clearing cover both spellings. It does not cover unsupported StyleX extensions or
  implementation details outside the selected profile.
- Oracle installation is a maintenance interface, separate from the product
  runtime and extraction API. Root generation and default validation consume
  the committed semantic lock without Babel. The independent frozen oracle
  package provides explicit install, read-only release checking, refresh,
  differential tests and security audits; see its [guide](../tools/stylex-oracle/README.md).
  The release check is
  read-only and rejects compiler or committed semantic drift. Live refresh
  requires an explicit installation and reviewed semantic changes; strict CI requires its
  differential tests and both dependency audits. This isolation does not
  change the semantic profile, public MoonBit APIs, active artifact and
  property schemas, or tooling protocol v1.
- `rabbita` is the Tier-1 adapter and follows its own minor compatibility
  boundary while preserving the opaque runtime style contract. `attrs` accepts
  one static mapping, `attrs_many` accepts a homogeneous static array, and
  `try_attrs` accepts any recursive style input. Checked Rabbita attributes
  validate before mutating optional base attributes. The native development
  server retains the last valid site and reports structured source spans;
  production extraction remains fail-closed. The
  separate `moonstyle-luna` module applies the same fail-closed runtime rule today,
  but its experimental API may change or be removed without the normal
  pre-1.0 deprecation period.

The compile-fail suite covers fluent unknown properties, mismatched static and
dynamic value categories, the Token/DynamicSlot theme boundary, opaque value
construction, generated enum values, fallbacks, and legacy low-level
restrictions. Border composite fixtures additionally reject raw strings, plain
lengths, legacy border enums, and cross-composite values.
The unified composition fixtures also reject primitive values that do not
implement `StyleInput`, unknown contract property methods, and mappings that do
not implement the exact component trait. Contract compile-fail fixtures also
reject mismatched literal/Token categories and exact animation arguments.
They also reject Clear in keyframes and invalid type-local value lifts.

Public API replacements must follow the deprecation policy and include a
migration note and compile-fail coverage. No compatibility shim may
silently reinterpret an older artifact as schema v14.
