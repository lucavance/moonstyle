# Distribution

## Published library

Mooncakes provides `lampclaw/moonstyle@0.3.0`, including typed authoring,
composition/runtime, native extraction and the Rabbita adapter:

```moonbit
import { "lampclaw/moonstyle@0.3.0" }
```

Release 0.3.0 provides native project tooling while preserving the public
library API checked against the published 0.2.0 baseline. The optional Luna
module remains experimental and source-distributed.

## Reviewed Git source

```bash
git clone https://github.com/lucavance/moonstyle.git source
git -C source checkout --detach <reviewed-full-commit>
moon update
moon install ./source/tooling/native/src/cmd/moonstyle
```

Use the same reviewed revision for the CLI and library. In the consumer workspace,
list `source` and your application in `moon.work`. A module with source-version
imports such as `lampclaw/moonstyle@0.3.0` then resolves to that local workspace
member. Git source includes the native CLI and examples in addition to the
published library.
The [executable quickstart](quickstart.md) validates the complete setup.

The root `moon.mod` owns `lampclaw/moonstyle`, with library packages under `src/`.
`moon package --list` must exclude validation, tools and optional modules from
the public archive. Git consumers keep the complete checkout for source tooling.

## Project tools and artifacts

The CLI is the independent MoonBit executable in `tooling/native/`. Consumers
install it using `moon install`, or run its source through `moon`.
There is no default Node package or package-manager install step.
The optional [`@lampclaw/moonstyle-tooling/vite`](../tooling/vite/README.md) adapter
is a private Git/path package that calls the installed native CLI.

```bash
moonstyle init
moonstyle generate
moonstyle doctor --strict
moonstyle check
moonstyle build --main-package src/demo
moonstyle dev --main-package src/demo
```

`.moonstyle.json` schema v2 records managed hashes and extractor/styles paths.
`upgrade --dry-run` previews migration from schema v1 without modifying Vite/entry
source. The user owns `style.config.json`. See [project tools](../tooling/README.md).

Component distribution includes CSS, nominal mappings, their `moon.pkg`, and the
schema-v14 bundle. Commit these four outputs together. Consumers discover bundles
from configured dependency roots; they do not run dependency build scripts.
Re-extract dependencies leaf-first after incompatible changes. See
[regeneration](regeneration.md), [artifact schema](artifact-schema-v14.md) and
[release policy](release-policy.md).
