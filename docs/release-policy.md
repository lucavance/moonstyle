# Release policy

MoonStyle 0.1.0 is distributed through Mooncakes, exact Git commits and local paths.
The library, validation workspace, optional Luna module and private tooling
share version 0.1.0. Artifact, metadata and tooling schemas have independent
versions; see [API stability](api-stability.md).

A source-version tag identifies a reviewed commit. Consumers should resolve
and pin its full commit identity. Tagging and publication require an explicit
maintainer action; repository validation never performs them.

Before tagging, require a clean tree, reproducible generated artifacts and
interfaces, the API baseline, documentation checks, four-backend library tests,
Chromium/Firefox/WebKit, the isolated StyleX oracle, both dependency audits,
performance budgets, license review, and independent consumption of the
actual clean commit through `vp run validate-ci`.

Release approval also requires maintainer review and successful hosted CI for
the same commit. The application, component fixtures and executable quickstart
used by these checks are included in this repository. CI builds the Rabbita
example and creates an independent component/application pair from the
quickstart, consuming the exact tested commit and packed tooling. See
[CI and validation](ci-and-validation.md) for setup, checks and reports.

The Mooncakes module is `lampclaw/moonstyle@0.1.0`. Registry publication records
the library version; a published package does not replace validation of a changed
source commit.
The tooling package is
private, is not published to npm, and supports Git/path installation.
Package publication is a separate maintainer operation. See
[distribution](distribution.md) and [regeneration](regeneration.md).
