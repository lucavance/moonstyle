# MoonStyle Luna adapter

MoonBit module: `lampclaw/moonstyle-luna`.

Status: experimental; not a Tier-1 framework integration for 0.1.0.

Optional Luna `0.25.2` adapter for `lampclaw/moonstyle`. The core styling module
does not depend on Luna; applications opt into this sibling module only when
needed. This package has no pre-1.0 compatibility or migration promise and is
not a supported application target for the candidate release decision. Rabbita
remains the only Tier-1 integration.

The adapter accepts generated styles and checked lists. Its `attrs` takes an
array of static inputs. Import `lampclaw/moonstyle-luna` as `@style_luna`:

```moonbit
let node = @luna.div(
  attrs=@style_luna.attrs([@styles.card]),
  [@luna.text("MoonBit")],
)

match @style_luna.attrs_list(
  @moonstyle.compose(@styles.card).add(@styles.meter(progress)),
) {
  Ok(attrs) => @luna.div(attrs=attrs, [@luna.text("ready")])
  Err(errors) => render_errors(errors)
}
```

`attrs_applied` is available when the application already resolved an
`AppliedStyle`. Classes are emitted as Luna's `class` attribute and typed
runtime variables as one `style` attribute. Failure never returns partial
attributes.

The [module manifest](moon.mod) explicitly constrains the dependency graph for
both standalone consumers and this workspace:

| Dependency | Version |
| --- | --- |
| `lampclaw/moonstyle` | 0.1.0 |
| `mizchi/luna` | 0.25.2 |
| `mizchi/signals` | 0.6.6 |
| `mizchi/js_web` | 0.13.1 |
| `mizchi/npm_typed` | 0.1.18 |
| `moonbitlang/parser` | 0.4.6 |
| `moonbitlang/lexer` | 0.4.4 |
| `moonbitlang/moon_config` | 0.4.5 |
| `moonbit-community/prettyprinter` | 0.4.11 |
| `moonbitlang/regexp` | 0.3.6 |

The explicit parser/configuration constraints avoid older dependency manifests
unsupported by the pinned toolchain. See [current status](../../docs/current-status.md)
and the [pinned toolchain](../../toolchain.json).

This workspace module pins `mizchi/luna@0.25.2` for reproducible local/Git
consumption. Its JavaScript-target smoke test and license audit protect
repository integrity without promoting the adapter to a stable surface. It is
not published to Mooncakes. The [interface snapshot](pkg.generated.mbti)
defines the exported functions. Verify with
`moon -C packages/moonstyle-luna test . --target js` from the repository root.
