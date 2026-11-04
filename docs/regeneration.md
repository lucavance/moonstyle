# Regenerating distributed styles

A MoonStyle module distributes four generated files together: CSS, nominal
MoonBit mappings, the mappings package's `moon.pkg`, and a schema-versioned
bundle. Source registries and the pinned framework commit are their inputs.
Generated source is not a hand-maintained compatibility surface.

## Dependency-first workflow

1. Pin the same reviewed MoonStyle source and tooling versions throughout the
   component and application graph. Run `moonstyle doctor --strict` in each
   project to diagnose its managed files and extractor contract.
2. Generate leaf component modules from their source registries. Commit all
   four outputs together. Repeat toward the application, using each generated
   component bundle as a configured dependency input.
3. Generate the application after every component output is current. Use
   `moonstyle check` to compare all four outputs without replacing them.
4. Run component and application tests, including checked dynamic values,
   exact contracts and browser behavior. Record the source commits and generated
   input digests so component and application builds can be reproduced.

Dependency build scripts are never assumed to run inside a consumer build.
See the [executable quickstart](quickstart.md), [distribution guide](distribution.md),
and [artifact contract](artifact-schema-v14.md).

## Version and cache identity

The 0.2.0 source uses artifact schema v14, property generator schema v18,
semantic-lock schema v4 and extraction cache pack v4. These version numbers
describe different contracts. Matching package versions alone does not make
an incompatible bundle valid.

The active artifact reader checks the schema, semantic profile and digest,
mapping ownership, contracts, references and canonical ordering. Re-extract
incompatible dependency bundles from source. Compatibility conversion helpers
cannot infer missing value provenance, exact contracts or priority relations.
Editing a bundle's schema or semantic digest cannot upgrade it.

Extraction caches include the implementation/version marker and source-input
digests. A stale cache is a miss and must not validate stale formal outputs.
Use a fresh cache directory to diagnose reproducibility, then compare the
complete four-file result. Debug manifests are ignored tooling sidecars and
are excluded from distribution.

## CSS resources and quoted values

CSS normalization preserves URL tokens and quoted strings as opaque values.
Resource paths, query strings, punctuation, repeated characters and numbers
inside these values must survive extraction. Test real browser requests when
changing normalization, rather than checking only class names or bundle
digests. The browser example and semantic regression fixtures cover this
boundary under the pinned StyleX profile.
