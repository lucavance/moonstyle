# StyleX Semantic Oracle

This private maintenance package owns the Babel compiler and the live StyleX
reference used to verify MoonBit semantics. It is not a root workspace member
and is not part of ordinary development or production builds. Its independent `bun.lock` pins
the oracle graph; the repository root retains its own lockfile.
Vite+'s root test graph may include Babel runtime and diagnostic helpers;
the compiler and StyleX packages belong to this isolated package.

The package pins Babel core 8.0.9 and `@stylexjs/babel-plugin`,
`@stylexjs/shared`, and `@stylexjs/stylex` 0.19.1. It uses the repository's
[pinned Bun and Node environment](../../toolchain.json). The current profile is
`stylex-0.19.1-application-order+font-aliases-v1` with semantic-lock schema v4.
The release contract records the published tag `0.19.1` and source commit
`1fcb9a51cbecad2c82255e0f4b45cc072fa1a95a`. It checks the package manifest,
installed versions, frozen lockfile identities and integrity hashes, and the
committed semantic profile and digests before live tests run. The commit is
recorded provenance; validation uses the frozen package graph without requiring
an adjacent upstream checkout or a network request. Changes that exist only on
upstream `main` remain outside this compatibility baseline until a published release is adopted.

## Commands

Run the public tasks from the repository root:

```bash
vp run install-oracle
vp run check-stylex-release
vp run test-oracle
vp run audit-oracle
```

Installation uses this package's frozen lockfile. Testing compares the live
pinned StyleX compiler and runtime with the committed observations and native
MoonBit behavior. The security audit checks this separate installed graph.
Missing or incompatible dependencies fail clearly with an installation
instruction; tasks do not install packages implicitly.

Refresh the upstream observations only as a reviewed maintenance operation:

```bash
vp run refresh-oracle
vp run generate
```

Refresh compiles the fixtures and verifies the exact oracle versions before
replacing `src/core/application-order.lock.json` and its generated
MoonBit table. Review any semantic diff. Normal generation validates the
committed lock and renders the table without importing Babel or StyleX.
Refresh validates the compiler contract first and can repair a missing or stale
semantic lock. The read-only release check requires a valid committed lock.

The release-specific fixtures characterize quoted `content`, pixel min-width
and max-width `defineConsts` ordering, generated max-width boundaries, and
stable class identifiers between development and production. They characterize
the maintenance oracle; the supported MoonBit surface is defined by the
application-order contract below. Atoms, JS/TS/JSX authoring, upstream unplugin,
and StyleX DevTools are outside the product scope. The post-release mixed
responsive/print parser fix remains outside this oracle until a published release
is adopted. MoonStyle's own typed media serialization has separate regression
coverage; this does not adopt the upstream query simplifier or change the lock.
Tests assert the supported MoonStyle behavior without treating unreleased
upstream output as the reference baseline. Follow
[current status](../../docs/current-status.md) for the active contracts.

URL/string normalization and fallback/condition fixtures have independent
MoonStyle correctness expectations. Resource identifiers remain opaque; known
incorrect output from the published compiler is not copied into them.

## Validation Boundary

Default tests and `vp run validate` use only root dependencies. They validate
the committed lock, local font alias, generated entries, and native artifacts.
`vp run validate-ci` requires this package's live differential tests and
security/license audits of both installed dependency graphs. Workflows install
this package explicitly before strict validation; a missing package never
silently skips the oracle gate.

The [application-order contract](../../docs/application-order-semantics.md)
defines the supported fixture surface and local extension. The
[data maintenance guide](../../docs/data-sources.md) describes reviewed updates.
