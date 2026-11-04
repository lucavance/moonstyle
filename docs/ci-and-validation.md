# CI and validation

All example sources and acceptance fixtures are in the repository. Install the
compiler/core pinned in [toolchain.json](../toolchain.json), then initialize the
registry before the first script:

```bash
moon update
moon run tools/validate.mbtx
```

## Native validation

The default command requires MoonBit, a native C toolchain, Git and gzip.
It does not execute Node, Bun or Vite. It checks the pinned MoonBit environment,
regeneration, ownership, interfaces, the published 0.2.0 API baseline, Markdown
links and version facts, module packaging, dependency licenses and performance
evidence. It runs native, Wasm and Wasm GC library tests, compiles JS integrations,
checks rejected authoring programs, tests independent component contracts, installs
the CLI and exercises production builds, HTTP, watching and failure recovery.
A second generation must preserve tracked output bytes.

`moon run tools/verify-consumer.mbtx --snapshot` additionally checks an independent
development snapshot. Without `--snapshot` it requires a clean commit, creates
an independent Git remote, clones the exact revision, installs the CLI from that
clone, and executes the [quickstart](quickstart.md). The report
`.generated/consumer.json` records revision, tree and snapshot status.

## Extended verification

Node-dependent checks are installed separately and remain required for release CI:

```bash
vp -C verification install --frozen-lockfile
vp -C tools/stylex-oracle install --frozen-lockfile
node verification/install-browsers.mjs --with-deps
moon run tools/validate-ci.mbtx
```

This adds JS-backend execution, the live pinned StyleX/Babel oracle, independent
css-tree/standards snapshot checks, the optional Vite integration, security audits
for both Node graphs, installed dependency license checks, development performance
budgets, and Chromium/Firefox/WebKit production and inspector tests. Missing
dependencies or browsers fail strict validation. Browser evidence is recorded in
`.generated/e2e-results.json`; every required engine must pass.

## Hosted CI and performance

The [workflow](../.github/workflows/ci.yml) has separate native and extended jobs
on Ubuntu 26.04 x64. The native job runs with a restricted PATH that excludes
Node/Bun/Vite. The extended job installs the exact Node, Bun, Vite+ and Playwright
versions in `toolchain.json`. Actions and the MoonBit installer checksum are pinned.
Both jobs verify the worktree remains unchanged.

Record two reviewed measurements with:

```bash
moon run tools/benchmark.mbtx -- --output benchmarks/0.3.0-candidate-1.json
moon run tools/benchmark.mbtx -- --output benchmarks/0.3.0-candidate-2.json
moon run tools/dx-benchmark.mbtx
moon run tools/release-audit.mbtx
```

Native report schema v5 retains the frozen 100/6,000/10,000-rule workloads,
balanced/alternating sampling and cache budgets. The audit recomputes summaries
from samples and matches candidate schemas, semantic digest and artifact sizes.
DX checks debug/release formal parity, cold-build ratio, warm build time and
inspector overhead. Use complete validation results for the exact candidate commit.
