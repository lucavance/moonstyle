# Extended host verification

This private directory owns the optional Node/Vite graph. It is excluded from
the public library archive and ordinary native development. The independently
installed [StyleX oracle](../tools/stylex-oracle/README.md) owns Babel and StyleX.

```sh
vp -C verification install --frozen-lockfile
vp -C tools/stylex-oracle install --frozen-lockfile
node verification/install-browsers.mjs --with-deps
moon run tools/validate-ci.mbtx
```

The extended gate verifies frozen standards export with css-tree, JS-backend
execution, the optional Vite adapter, artifact contracts, the live oracle,
security and installed-license audits, and three-browser application/inspector
behavior. Missing required tools or engines fail CI.

`data/export.mjs` is the host boundary for upstream npm datasets and css-tree.
It serializes source records, grammar ASTs, licenses, exact versions and
content hashes. Property review, classification, API rendering and repository
generation are implemented in MoonBit. `--check` never refreshes the snapshot.

The remaining JavaScript tests exercise Node- or browser-specific libraries;
native tooling and semantic rules are tested through MoonBit and installed
consumer acceptance. See [CI and validation](../docs/ci-and-validation.md).
