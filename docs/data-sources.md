# CSS data sources

Native generation consumes the committed [standards snapshot](../tools/data/css-inputs.json).
Its inputs are pinned in the isolated [verification manifest](../verification/package.json):

| Dataset | Version | Role |
| --- | --- | --- |
| `@webref/css` | 8.7.8 | Standards definitions and CSS grammars |
| `@mdn/browser-compat-data` | 8.1.7 | Compatibility annotations |
| `css-tree` | 3.2.1 | Snapshot export and independent grammar validation |

Generated MoonBit sources are committed; consuming the library does not require
dataset downloads, Babel, or network access for generation.

## Reviewed surface

`src/properties/property-api.json` schema v18 is the classification
layer. The generator derives IR spellings from WebRef `styleDeclaration`, rejects
non-standard/deprecated sources or atomic properties, and generates declarations,
fluent Rule/Frame methods, source-aware Clear methods, root value exports,
exact contract methods, metadata and exhaustive coverage.

| Coverage | Count |
| --- | --- |
| WebRef properties | 822 |
| Typed properties | 392 |
| Unsupported grammar | 190 |
| Unsafe-only | 233 |
| Deprecated | 7 |

The typed surface covers primitives, keyword enums, composites, themes, paint,
and named page selection. Scalar profile `stable-scalar-v2` contains 54 primitives, 60 keyword enums,
nine property references and six reviewed logical-size adapters.

The logical-size methods retain Length inputs although WebRef uses `<box-size>`.
Their adapter checks normalized property/named-type ASTs and records a
`grammarReviewDigest`; drift requires review. It excludes `anchor-size()`,
`calc-size()` and `stretch()` rather than widening the parser automatically.
`font-width` uses Percentage with finite, non-negative constraints across
literals, defaults, theme overrides and dynamic values. `text-decoration-inset`
is a reviewed scalar entry with `<length-percentage>{1,2} | auto` grammar.

The `stable-border-composite-v1` profile resolves property/type/function references
into content-addressed grammar closures. Its typed subset excludes `hairline`,
slash-separated single-corner radii and `image-1D`. Full shorthand radius lists
have their own reviewed API. Other modern opaque adapters keep their separate
review boundary. A standards grammar or browser annotation alone does not create
a safe MoonBit API.

`daily-css-v1` adds six common property adapters. Each freezes the reviewed
WebRef top-level syntax AST digest and records excluded grammar in metadata;
regeneration fails if that syntax changes. Named definitions still require review
when updating the pinned dataset. Tests also check representative values against
css-tree's independent property grammar. Static font-axis tags require four
printable ASCII characters and finite numbers; empty axes and hint lists fail
extraction. This profile does not expand the scalar or border allowlists.

## Generation and oracle isolation

```bash
moon run tools/build-styles.mbtx
moon run tools/check-generated.mbtx
```

Ordinary generation validates the committed semantic lock's schema, profile,
options, input digest and semantic digest, then renders its MoonBit table.
It does not execute Babel or refresh upstream observations. A stale/missing
lock fails with explicit maintenance instructions.

The test-only oracle is published StyleX 0.19.1 at recorded source commit
`1fcb9a51cbecad2c82255e0f4b45cc072fa1a95a`. Semantic-lock schema v4 separates raw
upstream observations from `font-aliases-v1` under
`stylex-0.19.1-application-order+font-aliases-v1`. This local extension makes
font-width/stretch share a conflict slot. It is not an upstream parity claim.
See [application order](application-order-semantics.md) and the
[isolated oracle guide](../tools/stylex-oracle/README.md).

## Updating inputs

1. Update exact pins in `verification/package.json` and its frozen lockfile.
   Install with `vp -C verification install --frozen-lockfile`, then run
   `node verification/data/export.mjs` to refresh the snapshot. Review upstream
   source hashes, grammar ASTs, licenses and classification changes.
2. Run `moon run tools/generate-properties.mbtx`. Review policy and grammar
   digests before updating `tools/data/reviewed-grammars.json`; inspect generated
   APIs, metadata and coverage. Generation rejects unreviewed drift before writes.
   `node verification/data/export.mjs --check` independently verifies the snapshot.
3. Install `tools/stylex-oracle` with its frozen lockfile, then run
   `node tools/stylex-oracle/generate-application-order.mjs`.
   Review lock and table changes. The separate `--check-release` command is read-only.
4. Re-extract leaf component bundles, update dependency references and run
   `moon run tools/build-styles.mbtx`. Synthetic fixtures use
   `moon run tools/refresh-fixtures.mbtx -- --write`; follow their
   [maintenance guide](../validation/tests/dependency-fixtures/README.md).
5. Run deterministic generation checks, compile-fail and cross-backend tests,
   live oracle verification, dependency/license audits, and candidate validation.
   Update current documentation and retain reports identifying the tested source.

Data-source versions participate in semantic identity. Bundles can become stale
even when emitted CSS/classes retain their behavior. Never substitute a new
digest into an incompatible bundle. Follow [regeneration](regeneration.md)
and validate the complete component/application graph.
