# MoonStyle project tools

`lampclaw/moonstyle-tooling` is an independent MoonBit module under `native/`.
Its executable coordinates native extraction, configuration and web builds.
It does not add tooling dependencies to the public `lampclaw/moonstyle` module.

## Install and run

From a reviewed source checkout, run `moon update` and:

```bash
moon install ./tooling/native/src/cmd/moonstyle
moonstyle --version
```

Use the CLI from the same reviewed revision as the library. It requires MoonBit
and a native C toolchain. Node and Vite are optional. Repository-local commands
can use `moon run tools/moonstyle.mbtx -- <command> --root <project>`.

| Command | Behavior |
| --- | --- |
| `moonstyle init` | Create extractor bridge, configuration and VS Code tasks |
| `moonstyle doctor` | Validate metadata, ownership, inputs and outputs |
| `moonstyle doctor --strict` | Also check native compilation and artifact freshness |
| `moonstyle upgrade --dry-run` | Preview a complete managed-file transaction |
| `moonstyle upgrade` | Apply updates while protecting customized files |
| `moonstyle generate` | Generate four formal outputs with release extraction |
| `moonstyle check` | Compare deterministic output without replacing files |
| `moonstyle watch` | Serialize debug extraction after source changes |
| `moonstyle build` | Compile a JS application and emit a static site |
| `moonstyle dev` | Serve, watch, rebuild and reload after successful changes |

All commands accept `--root`. One-shot commands support `--json`; watch emits
versioned NDJSON. Generate/check/watch support `--verbose`, exclusive with
`--json`. Dev prints its address and build status; its HTTP status endpoint is
`/__moonstyle/status`. Syntax errors exit 2 and failed one-shot checks exit 1.
Cancellation stops watchers and child processes.

## Paths and ownership

`init --styles-package <package> --extractor-package <path>` overrides defaults.
The default styles package is `<module>/styles`; the extractor is
`<source>/style_extractor`. `source = "src"` in `moon.mod` is respected.
`.moonstyle.json` schema v2 records styles/extractor paths and managed-file hashes.
`upgrade` accepts v1 metadata, releases Vite/entry files from management and
preserves their contents. Edited managed files fail before any replacement.

User-owned `style.config.json` has exactly these keys:

```json
{
  "schemaVersion": 1,
  "mappingsPackage": "example/app/generated",
  "outputs": {
    "css": "src/generated/styles.generated.css",
    "mappings": "src/generated/styles.generated.mbt",
    "mappingsManifest": "src/generated/moon.pkg",
    "bundle": "src/generated/styles.bundle.json"
  },
  "dependencyRoots": [],
  "cacheDirectory": "_build/style-cache"
}
```

Paths remain inside the module, including through symlinks. Outputs are distinct
and outside dependency roots/cache. Dependency bundles are discovered recursively
in stable order. Components distribute all four outputs and re-extract leaf-first.
See [regeneration](../docs/regeneration.md) and [artifact schema](../docs/artifact-schema-v14.md).

## Build and development

`build --main-package src/demo --out-dir dist` compiles a MoonBit executable with
Moon's JS backend. Its `index.html` template needs `<!-- moonstyle-assets -->`
at the stylesheet/script insertion point. A minimal template is supplied if absent.
The output consists of `index.html`, `app.js` and `styles.css`. Host these files
with any static web server. This command does not bundle arbitrary npm modules
and copies binary assets from `public/` without changing their contents.
Generated names are reserved; removed owned assets are cleaned on the next build.

`dev --main-package src/demo --port 5173 --host 127.0.0.1` serves a site under the
configured ignored cache directory. It watches source, dependency bundles,
manifests, workspace members, `index.html` and `public/` assets. Successful builds atomically install
a new site and trigger full-page reload. Failed builds keep the last good site
and report diagnostics. Avoid concurrent writers of the same formal outputs.

The development-only inspector uses Shadow DOM and final class names. It shows
rules, computed values, origins and source links. Alt/Option+Shift+S toggles it;
Pick element selects a node. CSS Source Map v3 preserves authored coordinates
without embedding source text. The browser client is written in MoonBit with
small DOM FFI bindings; the installed CLI embeds its MoonBit source and compiles
it using `moon` on first development startup. Production contains no debug client,
manifest or source map. The debug sidecar is not a fifth distribution artifact.

Release extraction is used by generate/check/build; watch/dev use debug builds.
Both profiles must emit identical formal bytes. Cache identity includes the
executable, normalized configuration and dependency bytes. Corrupt caches safely
fall back to extraction. Native compilation reads `--output-json` diagnostics.

The [optional Vite adapter](vite/README.md) delegates to this CLI.
[Native validation](../docs/ci-and-validation.md) exercises installed consumers,
failure recovery, generated outputs and the published library API baseline.
