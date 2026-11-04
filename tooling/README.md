# MoonStyle project tooling

The private source-distributed `@lampclaw/moonstyle-tooling` package owns the
`moonstyle` CLI and `@lampclaw/moonstyle-tooling/vite` export. Install tooling
packed from the same reviewed revision as the MoonBit module; the
[quickstart](../docs/quickstart.md) validates this in an independent consumer.
The package is not published to npm. JavaScript orchestrates native extraction
and never implements CSS normalization, hashing or composition semantics.

## Commands

Run these from a consumer's MoonBit module root:

| Command | Behavior |
| --- | --- |
| `vp exec moonstyle init` | Idempotent scaffold of owned config and extractor bridge |
| `vp exec moonstyle doctor` | Static integration and ownership checks |
| `vp exec moonstyle doctor --strict` | Also resolves the MoonBit dependency tree, runs native checks and release extractor `--check` |
| `vp exec moonstyle upgrade --dry-run` | Previews managed-file and recognized legacy-copy migration |
| `vp exec moonstyle upgrade` | Applies the safe transaction while protecting customized files |
| `vp exec moonstyle generate` | Generates the four formal artifacts with release extraction |
| `vp exec moonstyle check` | Compares deterministic output without replacing stale files |
| `vp exec moonstyle watch` | Watches project inputs and generates with debug extraction |

All commands accept `--root <directory>` and `--json`. Generate/check/watch also
accept `--verbose`, which cannot be combined with `--json`. Watch JSON output is
a versioned NDJSON event stream. Syntax errors exit 2; failed one-shot checks
exit 1. Run `vp exec moonstyle --help` for init path and entrypoint options.

## Configuration and ownership

`moon.mod` and `moon.work` describe the module and local source members.
Legacy/conflicting JSON manifests and missing style imports are diagnosed;
the tooling does not rewrite arbitrary dependency manifests.

User-owned `style.config.json` has these exact top-level keys:

```json
{
  "schemaVersion": 1,
  "mappingsPackage": "example/app/generated",
  "outputs": {
    "css": "generated/styles.generated.css",
    "mappings": "generated/styles.generated.mbt",
    "mappingsManifest": "generated/moon.pkg",
    "bundle": "generated/styles.bundle.json"
  },
  "dependencyRoots": [],
  "cacheDirectory": "_build/style-cache"
}
```

`.moonstyle.json` schema v1 separately records project paths, tooling version
and managed-file hashes. It does not replace style configuration. Init and
upgrade preserve arbitrary Vite/entry source and locally modified managed
files; exact recognized legacy copies can migrate automatically. Use the
[regeneration guide](../docs/regeneration.md) for dependency-first extraction.

Dependency roots are discovered recursively in stable order and passed to the
native extractor. Component authors commit all four outputs. Consumers do not
run dependency build scripts; re-extract dependencies leaf-first on an upgrade.
The [artifact contract](../docs/artifact-schema-v14.md) defines graph validation,
semantic digests and failure-before-replacement behavior.

## Vite and diagnostics

```js
import moonStyle from '@lampclaw/moonstyle-tooling/vite';

// Add alongside the application's other plugins.
moonStyle({ extractorPackage: 'style_extractor' });
```

Import `virtual:moonstyle.css` in the application entry. The plugin, standalone
commands and strict doctor share one framework-neutral extraction runner.
Standalone watch is an alternative to `vp dev`; avoid two writers of the same
formal outputs. The adapter passes `--tooling-protocol 1`; explicit mismatches
fail before output mutation. Missing protocol remains a deprecated legacy case.

Vite and standalone watch include source directories and manifests from the
nearest MoonBit workspace. A child application therefore observes edits to a
parent library with `source = "src"`; build directories and its own generated
outputs stay excluded. Compiler diagnostics keep the original source location.

Development compiles the native extractor with debug profile; production and
one-shot generation/checking use release. Both profiles must emit identical
formal bytes. Extraction may skip execution only when the executable,
normalized config and configured dependency bytes retain the same identity.
Native compilation uses `--build-only --output-json` to preserve structured
compiler diagnostics instead of scraping text.

Vite reports exact source spans through its overlay and the scaffold's VS Code
background problem matcher. A failed development save retains last-valid
artifacts; a corrected save resumes extraction and reloads. Production builds
and explicit validation fail closed. Semantic failures never become successful
checks merely because old CSS remains available.

## Development inspection

Serve mode enables the applied-style inspector and CSS source maps by default;
`moonStyle({ devtools: false })` opts out. The extractor's optional
`--debug-manifest-output` writes a versioned tooling sidecar under the ignored
cache directory. It is not a fifth distribution artifact.

The inspector uses a Shadow-DOM UI, final DOM class names and Source Map v3.
It adds no provenance fields to runtime values or application DOM attributes.
Standalone watch does not produce browser devtools artifacts. Production builds
must contain no debug client, source paths or debug manifest. A missing, stale
or corrupt cache safely falls back to extraction; formal artifacts remain
authoritative.

## Maintenance checks

From the framework checkout, `vp run check-docs`, `vp check`, and the tooling
CLI/Vite/scaffold test suites verify these boundaries. Run
`vp run check-consumer-snapshot` during development to verify the executable
quickstart, packed tooling, exact contracts and watch failure recovery.
Candidate validation uses the [clean-commit workflow](../docs/ci-and-validation.md).
