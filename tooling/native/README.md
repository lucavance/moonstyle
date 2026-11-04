# MoonStyle native tools

This independent MoonBit module owns project configuration, native extraction
orchestration and the `moonstyle` executable. It is distributed from the same
reviewed Git revision as the library and does not add tooling dependencies to
the public `lampclaw/moonstyle` module.

Build and test from the repository root with:

```sh
moon -C tooling/native check --target native
moon -C tooling/native test --target native
```
