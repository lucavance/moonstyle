# Distribution

## Mooncakes library

The public MoonBit module is available on
[Mooncakes](https://mooncakes.io/docs/lampclaw/moonstyle) as
`lampclaw/moonstyle@0.1.0`. It includes the typed authoring API, runtime,
Rabbita adapter and native extractor. Add the module to the consumer's
`moon.mod`:

```moonbit
name = "example/app"
version = "0.0.0"
import { "lampclaw/moonstyle@0.1.0" }
```

Run `moon update` to resolve the registry dependency. Registry consumption
does not require a MoonStyle source checkout in `moon.work`.

The CLI and Vite adapter are provided by the private
`@lampclaw/moonstyle-tooling` Node package, packed from a reviewed Git checkout.
Use the source revision corresponding to the library version and record its
full commit SHA and package digest. The tooling package is not published to
npm. The optional Luna module remains experimental and is not published to
Mooncakes. See the [tooling guide](../tooling/README.md) and
[regeneration guide](regeneration.md).

## Git and local paths

Git and local-path consumers use the repository root, whose library source
is in `src/`. The root also contains the tooling package, so both can be
consumed from the same reviewed source revision.

The canonical source repository is
[lucavance/moonstyle](https://github.com/lucavance/moonstyle), recorded in all
three MoonBit module manifests and the private tooling manifest. Git consumers
pin a reviewed full commit SHA with successful validation and hosted CI;
branch names and tags are not immutable source identities.

For a local checkout:

Consumer `moon.mod`:

```moonbit
name = "example/app"
version = "0.0.0"
import { "lampclaw/moonstyle@0.1.0" }
```

Consumer `moon.work`:

```moonbit
members = [".", "../moonstyle"]
```

For Git consumption, clone a reviewed commit and expose the checkout root
as a member of the consuming `moon.work`:

```bash
git clone https://github.com/lucavance/moonstyle.git ../moonstyle
git -C ../moonstyle checkout --detach <reviewed-commit>
moon update
```

Replace `<reviewed-commit>` with the reviewed full SHA. Run `moon update` after
installing the pinned toolchain to initialize the registry before any `.mbtx`
script. A Git import syntax is not required.
Do not track a branch name for production builds. The [executable quickstart](quickstart.md)
and `tools/verify-consumer.mbtx` validate this flow with a temporary local remote,
including a component/app pair and tooling packed from the same revision.

The repository root is the public MoonBit module and private tooling package.
The `validation/` submodule is the repository's application consumer. The
bootstrap contract test creates an isolated module with a path dependency on
the checkout root, while a packed consumer verifies the
`@lampclaw/moonstyle-tooling/vite` export and the complete `moonstyle`
generate/check/watch loop. The CLI
emits the same exact `style.config.json` schema used by the repository:
generated package, four output paths, dependency roots, and cache directory.
The package-owned asynchronous Vite plugin delegates recursive root discovery
and all CSS semantics to the native extractor, consumes structured diagnostics,
and drives the VS Code problem matcher; it has no separate JavaScript authoring
or configuration model.

Initialize or audit a consumer with:

```bash
vp exec moonstyle init
vp exec moonstyle doctor --strict
vp exec moonstyle generate
vp exec moonstyle check
vp exec moonstyle watch
```

`.moonstyle.json` schema v1 records project paths and managed hashes.
`upgrade --dry-run` previews safe changes. Existing arbitrary Vite/entry source
is preserved; only exact legacy copied files and imports migrate automatically.
The one-shot commands use release extraction. Standalone watch uses debug
extraction and is intended as an alternative to the Vite development process,
not as a concurrent writer of the same formal outputs. The
[tooling guide](../tooling/README.md) documents the complete command surface and
configuration ownership; [release policy](release-policy.md) defines readiness.
