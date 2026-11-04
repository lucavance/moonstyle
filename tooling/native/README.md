# MoonStyle native tools

This independent MoonBit module owns generation, maintenance, project commands,
native build/dev and performance validation. It adds no tooling dependencies
to the public library. Install from the repository root:

```sh
moon install ./tooling/native/src/cmd/moonstyle
moon run tools/validate.mbtx
```

See the [CLI guide](../README.md), [architecture](../../docs/architecture.md)
and [validation workflow](../../docs/ci-and-validation.md). The browser client
is authored in the sibling `tooling/browser` module and embedded as MoonBit
source for first-use compilation by the installed CLI.
