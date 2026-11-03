# Artifact schema v13

This is the complete current dependency and application bundle contract.
The [native encoder/decoder](../src/extract/bundle.mbt) and
[public extraction interface](../src/extract/pkg.generated.mbti)
implement it. The active reader rejects every other schema; compatibility
conversion helpers do not make old bundles valid dependencies.

## Distribution outputs

Extraction transactionally manages four deterministic files:

| Output | Purpose |
| --- | --- |
| CSS | Ordered, deduplicated atomic and global rules |
| MoonBit mappings | Nominal static mappings, checked dynamic accessors, contracts and recipe functions |
| Generated `moon.pkg` | Exact imports for runtime, values and external contract owners |
| Bundle JSON | Portable semantic records and content-addressed dependency graph |

Paths are configured by the consumer and are not bundle fields. Timestamps,
absolute source paths, random values and machine-specific data do not belong
in the bundle. Development provenance belongs in a separate cache sidecar.
An extraction error prevents replacement of the formal output set; ordinary
write/rename failures use staged, rollback-capable replacement.

## Canonical envelope

The complete top-level field set, in encoder order, is:

```json
{
  "schemaVersion": 13,
  "module": "example/app",
  "mappingsPackage": "example/app/generated",
  "semanticDigest": "sha256:<lowercase-hex>",
  "semantics": {
    "profile": "stylex-0.19.1-application-order+font-aliases-v1",
    "digest": "sha256:<current-lock-digest>"
  },
  "directDependencies": [],
  "dependencyClosure": [],
  "contracts": [],
  "namespaces": [],
  "rules": [],
  "globals": [],
  "recipes": [],
  "markers": [],
  "viewTransitionClasses": []
}
```

`mappingsPackage` is the importable MoonBit package owning local mappings and
generated traits. `semanticDigest` is SHA-256 over the canonical compact UTF-8
JSON representation with only that field omitted. Each hash uses the
`sha256:` prefix. `semantics` must match the committed application-order profile
and digest. Property schema and data-source changes can change that digest
without changing artifact schema v13.

`directDependencies` preserves declared root order as `{module, semanticDigest}`
records. `dependencyClosure` is the deterministic dependency-first transitive
closure excluding the current module. Consumers supply exactly the declared
direct roots and their complete closure. Graph gaps, cycles, duplicate owners,
unreachable extras and dependency-digest drift are rejected.

## Namespaces, rules and globals

Namespaces contain exactly `name` and ordered `entries`. Each entry is
`[opaqueSlot, classStringOrNull]`. A string selects the complete class value
for that slot; `null` is a conflict tombstone. A class string can contain base
and conditional classes. Merged dependency namespaces use owner-qualified
names. Slots are application-order identities, not author-facing CSS names;
consume generated nominal mappings rather than parsing them.

Atomic rules contain `property`, `className`, `ltr`, `rtl`, and `priority100`.
`rtl` is either CSS text or `null`. Priorities are positive integers scaled by
100, preserving relational condition fractions without floating-point JSON.
Rules retain their original CSS property, including shorthands. Rendering sorts
by fixed-point priority and stable selector tie-breaks; specificity padding
uses that same priority contract. See [application order](application-order-semantics.md).

Globals contain `kind`, `name`, `css`, and `digest`; the digest covers the CSS.
They carry variable definitions, themes, keyframes, position fallbacks and
view-transition pseudo styles. Identical shared records deduplicate. Class,
global, owner/package, contract and stable-identifier collisions fail validation.
Cascade-sensitive namespace entries, declarations, fallbacks, recipe rule
lists and dependency order must never be sorted as unordered sets.

## Component contracts and expression identity

Each record in `contracts` contains `module`, `name`, `mappingsPackage`, `trait`,
and `properties`. Each property carries a structured `policy`: either
`{name, policy: "any"}`, admitting any
reviewed non-raw value, or `policy: "exact"` with all four arrays `values`,
`tokens`, `slots`, and `expressions`. Exact policies must admit at least one
member. Empty arrays remain present. Properties, literals and identity sets
use canonical, unique ordering.

Literal values use canonical CSS text. Token and Slot records contain
`variable` and `category`; their roles remain distinct. A literal equal to a
Token default does not become that Token. Every fallback member must be
admitted, and conditions do not weaken the policy. Clear is eligible only if
the contract admits its property. `unsafe_raw` never qualifies.

Expressions are sorted unique strings encoding canonical JSON trees of
`[category, node]`. Nodes preserve literal text, Token/Slot category and variable
identity, ordered groups, delimiters, operations, and validation constraints.
Operand order is significant; algebraic equivalence does not grant eligibility.
Defaults remain in variable definitions rather than reference identities.
Direct paint/size inputs retain literal/Token/Slot provenance; wrapping them
in a composite expression requires an exact expression grant.

Contract owners must be visible in the bundle graph, local packages must agree
with `mappingsPackage`, and generated package/trait references cannot collide.
Consumers generate imports from this metadata, never infer permissions from
CSS text. Checked dynamic accessors still validate admitted runtime channels
and return every failure without partial output.

## Recipes and stable identities

Recipes contain `module`, `mappingsPackage`, `name`, `base`, `variants`,
`compounds`, and nullable `contract`. Variant axes carry `name`, `boolean`,
nullable `default`, and `choices`; each choice has `value` and ordered `rules`.
Compounds contain axis/value `matches` and ordered `rules`. References must
resolve to visible namespaces and any declared local contract. Axis and style
order govern base → selected axes → compound composition. Static/token-backed
recipes generate typed functions returning ordinary runtime lists; dynamic
slots and raw declarations are rejected.

Markers contain `module`, `mappingsPackage`, `name`, and `className`.
View-transition records contain `module`, `mappingsPackage`, `name`, `cssName`,
and `styles`. Both identifiers are derived from module/name and validated, not
accepted as arbitrary strings. Public identities use canonical owner/name
ordering. Changing view-transition pseudo styles preserves the class identity
while changing the semantic digest.

`styles` uses fixed group order `group`, `image-pair`, `old`, `new`; empty groups
are omitted and identifier-only definitions use `[]`. Each group contains
`group` and ordered `declarations`, whose entries are
`[cssProperty, [fallbackValue, ...]]` with canonical strings. Only reviewed
static typed declarations are accepted. Conditions, dynamic slots, Clear and
raw declarations are rejected, including nested dynamic references.

Every styled transition owns exactly one global of kind `view-transition`
named by `cssName`. Its CSS is reconstructed from the canonical blocks and
must match the global text and digest. Orphan globals, unknown/duplicate groups,
foreign owners, forged class names and conflicting definitions fail. Referenced
Tokens and keyframes retain their normal global dependency records.

## Cache, validation and upgrade

Cache pack v4 binds the artifact/semantic versions, generator configuration,
extractor identity, normalized project config, dependency bytes, and digests
of all four outputs. Missing, stale or corrupt packs miss safely and regenerate.
Cache validity never permits a mismatched dependency schema or semantic profile.
Tooling protocol v1 is independent of both the bundle and property schemas.

The active property generator is schema v17. Current coverage is maintained in
[data sources](data-sources.md). Property and data-source inputs participate in
the semantic digest; matching schema versions alone do not establish compatibility.
Generator identity includes transition styles, properties, named pages,
typed length zero and value-profile inputs.
Use the implementation's fingerprint rather than reconstructing it by hand.

Re-extract source dependencies leaf-first, update downstream content-addressed
references, then generate the application's CSS, mappings, manifest and bundle.
Readers reject old or invalid content before writing formal outputs. Never
relabel a schema or substitute a digest manually. The
[regeneration guide](regeneration.md) documents conversion limits.
