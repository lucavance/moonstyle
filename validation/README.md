# Included Rabbita application

This MoonBit module contains the complete application used for browser validation.
From the repository root, initialize the registry and start the native server:

```bash
moon update
moon run tools/dev.mbtx
```

Open the printed address. Edit `examples/styles/` to inspect regenerated CSS,
successful reloads and diagnostics after an invalid edit. Alt/Option+Shift+S opens
the inspector. Node, Vite and a package-manager installation are not required.

| Source | Purpose |
| --- | --- |
| [examples/styles](examples/styles/) | Typed registries, themes, expressions and recipes |
| [src/demo](src/demo/) | Rabbita view and dynamic interactions |
| [cmd/style_extract](cmd/style_extract/) | Native extractor bridge |
| [style.config.json](style.config.json) | Four output paths and dependency roots |
| [src/generated](src/generated/) | Generated CSS, nominal mappings and schema-v14 bundle |
| [tests/dependency-fixtures](tests/dependency-fixtures/) | Synthetic component bundle graph |

```bash
moon run tools/build-demo.mbtx
moon run tools/validate.mbtx
```

The production site is `validation/dist/`. Static styles are extracted before
compiling the application; no runtime stylesheet injection is used.
[Extended verification](../verification/README.md) runs the production site and
development inspector in three browser engines. See [CI](../docs/ci-and-validation.md)
and the [independent quickstart](../docs/quickstart.md).
