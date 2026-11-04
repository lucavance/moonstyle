# Release policy

The published Mooncakes module is `lampclaw/moonstyle@0.2.0`. Current source
version 0.3.0 prepares native tooling and has not been published. The root
library, validation consumer, Luna adapter and source tooling share the source
version; artifact, metadata and protocol schemas have independent versions.
See [API stability](api-stability.md) and [release status](../release-status.json).

A release tag identifies a reviewed commit. Pin its full commit identity for
source consumption. Tagging, pushing and publication require explicit maintainer
action; validation never performs them.

Before tagging, require a clean tree, reproducible generated outputs and
interfaces, the published API baseline, documentation checks, package/license
audits, native/Wasm/Wasm GC/JS tests, compile-fail contracts, two passing native
performance reports, development performance budgets, the isolated live StyleX
oracle, both Node security audits and Chromium/Firefox/WebKit acceptance.

`moon run tools/validate-ci.mbtx` runs the native and extended gates. Final
acceptance consumes the actual clean Git revision and tree through an
independent clone, installs its CLI with `moon install`, and executes the
repository quickstart. A `--snapshot` development report cannot replace this
final commit check. All required application and component examples are in
the repository; see [CI and validation](ci-and-validation.md).

Release approval requires maintainer review and successful hosted native and
extended CI for the same commit. Native validation must pass with Node/Bun/Vite
unavailable. Extended tools remain required release checks even though ordinary
library use and development do not need them.

The native CLI is installed from reviewed Git source. The optional Vite adapter
is private and source-distributed. Mooncakes publication is a separate operation
after release approval. See [distribution](distribution.md) and
[regeneration](regeneration.md).
