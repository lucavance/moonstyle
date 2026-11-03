# CI and validation

All example sources and acceptance fixtures are included in this repository.
The browser example lives in `validation/`; the independent component and
application are generated from the complete code blocks in
[the executable quickstart](quickstart.md). The checks use public dependencies
and the pinned environment in [toolchain.json](../toolchain.json).

## Run the included example

Use the versions recorded in [current status](current-status.md). From the
repository root:

```bash
moon update
vp install --frozen-lockfile
vp dev
```

Open the local URL printed by Vite. The [example guide](../validation/README.md)
maps its style registries, view, extractor and component fixtures to source
files. `vp build` creates its production output under `validation/dist/`.

## Development validation

```bash
vp run install-browsers
vp run validate
```

This checks project configuration, generated artifacts and interfaces, the API
baseline, documentation, dependency security and licenses, JavaScript tooling,
four-backend MoonBit behavior, browser behavior, performance budgets and the
production example build. Browser binaries must be installed first. Development
mode may skip Firefox in restricted execution environments; strict CI requires
all three engines.

Independent consumer validation copies the current development source into a
temporary Git repository, packs the tooling, and builds the quickstart's
component and application. It checks cross-module contracts, generated outputs,
source pins and recovery after an invalid edit. The `snapshot` field
in `.generated/consumer.json` distinguishes this from clean-commit validation.

## Clean-commit CI

Initialize the registry with `moon update` after installing the pinned MoonBit
toolchain, before the first `.mbtx` script. Install the strict test dependencies
and run:

```bash
vp run install-oracle
vp run install-browsers-ci
vp run validate-ci
```

The [CI workflow](../.github/workflows/ci.yml) runs on Ubuntu 26.04 for main
and release branch pushes, pull requests targeting main, and manual dispatch.
The repository-owned MoonBit setup action verifies the installer checksum and
installs the pinned compiler and core together. Vite+ and Node versions and
workflow actions are pinned too.

Strict validation requires Chromium, Firefox and WebKit, the isolated StyleX
oracle, both dependency security audits and the license audit. It consumes the
actual clean source commit through a temporary local Git remote and packs the
tooling from that revision. The component and application still come from the
quickstart included in this repository. A dirty checkout fails this final
consumer check; use `vp run validate` while editing.

## Reports and reproducibility

The browser report is `.generated/e2e-results.json`; strict mode requires all
three engines to pass. Independent consumption writes
`.generated/consumer.json` with the tested revision, snapshot mode and checks.
Generated reports and build outputs are ignored by Git. Hosted CI retains
browser evidence as workflow artifacts and checks that validation leaves the
candidate unchanged.

`vp run benchmark-candidate` measures the two tracked performance reports;
the release audit checks their fixture fingerprints and every frozen budget.
For release decisions, use the complete validation result and hosted CI for
the same commit. See [release policy](release-policy.md).
