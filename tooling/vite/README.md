# Optional Vite adapter

The private `@lampclaw/moonstyle-tooling` package exports `./vite`. It is an
optional host adapter for applications that already use Vite. Normal MoonStyle
development uses [native build/dev](../README.md) without Node.

Install the native `moonstyle` CLI from the same reviewed source revision and
make it available on PATH, or pass an absolute `executable` path:

```js
import moonStyle from '@lampclaw/moonstyle-tooling/vite';
export default { plugins: [moonStyle()] };
```

Import `virtual:moonstyle.css` from the application's Vite entry. Extraction,
configuration checks and output transactions run in the native executable.
The adapter loads generated CSS, watches workspace inputs, serializes extraction
and requests a full reload after success. Failure sends Vite diagnostics and
preserves the last valid generated files. It does not provide the native
development inspector or implement CSS normalization/hash/priority semantics.

Its workspace installation and integration tests live in
[extended verification](../../verification/README.md).
