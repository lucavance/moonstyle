# Runnable Rabbita example

`lampclaw/moonstyle-validation` is the repository's example and test module.
The public library module is `lampclaw/moonstyle` at the repository root, with
source in `src/`. This consumer supplies the Rabbita browser example, an
explicit native extractor, generated mappings, and component-contract fixtures.

Run shared commands from the repository root:

```bash
moon update
vp install --frozen-lockfile
vp dev
```

Open the local URL printed by Vite. The example demonstrates conditional
composition, themes, checked dynamic values, typed expressions and component
overrides. Change a style registry to see Vite regenerate the CSS. An invalid
edit reports a diagnostic; fixing the source resumes generation.

## Source map

| Source | Role |
| --- | --- |
| [styles.mbt](examples/styles/styles.mbt) | Rules, themes, dynamic slots and composition fixtures |
| [expressions.mbt](examples/styles/expressions.mbt) | Typed math, images and Grid |
| [coverage.mbt](examples/styles/coverage.mbt) | Conditions and additional CSS values |
| [main.mbt](src/demo/main.mbt) | Runnable Rabbita application |
| [Extractor](cmd/style_extract/main.mbt) | Native extraction entry point |
| [style.config.json](style.config.json) | Generated outputs, dependencies and cache configuration |
| [Component fixtures](tests/dependency-fixtures/README.md) | Cross-component bundles and regeneration inputs |

The validation Node workspace consumes the root tooling package through
`workspace:*`. Its `style.config.json` selects the four generated outputs under
`src/generated/`; edit source registries under `examples/styles/` and regenerate
the outputs together. Synthetic dependency fixtures have their own
[maintenance guide](tests/dependency-fixtures/README.md).

## Build and verify

```bash
vp build
vp run install-browsers
vp run validate
```

The production output is `validation/dist/`. The validation suite checks the
example and creates a separate component/application pair from the complete
source examples in the [quickstart](../docs/quickstart.md).

Use `vp run validate` for development and `vp run validate-ci` for the clean
committed source. See the [documentation index](../docs/README.md),
[architecture](../docs/architecture.md), and
[CI and validation](../docs/ci-and-validation.md) for the supported library
integration and full verification requirements.
