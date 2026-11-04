# Application-order semantics

The implementation freezes style composition against StyleX 0.19.1 using
`stylex-0.19.1-application-order+font-aliases-v1`. The upstream oracle uses
these exact options:

```json
{
  "dev": false,
  "enableLegacyValueFlipping": false,
  "enableLogicalStylesPolyfill": false,
  "runtimeInjection": false,
  "styleResolution": "application-order",
  "useLayers": false
}
```

`node tools/stylex-oracle/generate-application-order.mjs` compiles one representative declaration
for every one of the 392 typed IR properties. It records the property priority,
live composition slot, conflict tombstones, and normalized LTR/RTL rule in
`src/core/application-order.lock.json`. The complete semantic content
is addressed by the lock's `semanticsDigest`. Lock schema v4 uses
`priorityScale: 100` and `priority100`, and covers a container fixture plus all
five relation kinds across every typed pseudo state, attribute fallback, and
compound fallback. It records a supplemental `font`
shorthand observation and explicitly separates `localExtensions` from the raw
upstream `properties` and `supplementalProperties` records.

The local `font-aliases-v1` extension maps the `fontWidth` composition slot to
`fontStretch`. Both typed spellings therefore replace and clear each other in
application order, and clearing the font shorthand clears their shared slot.
Each declaration keeps its original CSS property, hash, and upstream priority.
This alias is a documented local semantic extension rather than an upstream
StyleX parity claim. The supplemental record does not add a typed font
shorthand authoring API.

The refresh task also generates `application_order.generated.mbt`. Ordinary
`moon run tools/build-styles.mbtx` validates the committed lock's schema, profile, options,
input digest, and semantic digest, then renders the table without running
Babel. Production compilation consumes only that MoonBit table. A missing lock
or stale input digest fails before the table is replaced and instructs the
maintainer to install and refresh the oracle explicitly.

The Babel compiler and the three StyleX packages are exact-pinned development
dependencies of the independently installed `tools/stylex-oracle` package.
It has its own frozen `bun.lock` and is not part of the root workspace. Refresh and live
differential testing require `vp -C tools/stylex-oracle install --frozen-lockfile` first. They fail clearly
when those dependencies are absent; normal generation does not install them.
The release contract records the published StyleX 0.19.1 tag and source commit
`1fcb9a51cbecad2c82255e0f4b45cc072fa1a95a` as provenance. Before live tests,
`node tools/stylex-oracle/generate-application-order.mjs --check-release` checks exact manifest and installed versions,
lockfile identities and integrity hashes, and the committed profile and digests.
The oracle regression fixtures cover quoted
`content`, pixel `defineConsts` ordering, generated max-width boundaries, and
stable class identifiers after debug metadata changes. Upstream `main` fixes
that are not in 0.19.1, plus atoms, unplugin, DevTools, and JS/TS authoring,
remain outside this MoonBit-only compatibility surface.
These release fixtures characterize the maintenance oracle. The MoonBit core
preserves its canonical condition serialization and CSS-ready raw values; the
fixtures do not add the upstream `defineConsts` authoring API or media-query
range rewriting to the public surface.

The published-release baseline changes only through a reviewed update of the
oracle package pins, release contract, semantic lock, and regression fixtures.
Upstream checkout state and unpublished changes do not select the oracle version.

Normalization treats URL payloads and quoted strings as opaque values. Numeric
normalization cannot rewrite resource paths or quoted content. These regression
expectations preserve the oracle profile, priorities and conflict slots; see
[regeneration](regeneration.md#css-resources-and-quoted-values).

## Composition model

- A declaration emits one CSS rule for its original property. Shorthands are
  not expanded into separately hashed longhand rules.
- Each compiled style writes its live class to the oracle slot and writes null
  tombstones to the oracle conflict slots. Base and conditional classes for one
  property share the same live slot as a space-separated class value.
- `runtime.props` applies entries from left to right. A later style replaces the
  complete class value or tombstone for the same base slot. Conditions affect
  selectors and priority, not conflict-key identity.
- Logical declarations remain logical CSS. Direction and writing mode are
  resolved by the browser because both logical polyfills are disabled in the
  selected profile.
- Unknown `unsafe_raw` properties use a self slot. They serialize, but do not
  receive typed conflict-graph compatibility guarantees.

The property table also freezes StyleX condition priority data. Typed and unsafe
conditions keep the repository's canonical condition serialization, while rule
ordering uses the pinned pseudo-class, pseudo-element, and at-rule priorities.
Rendered CSS adds the same priority-level specificity padding used by StyleX so
a conditional shorthand cannot bypass a higher-priority base longhand.

All internal and artifact priorities are integers scaled by 100. Ordinary
priorities are multiplied directly; relational states preserve StyleX's
fractional ranks. For a base `color` priority of `300000`, `:hover` produces
`301130`, `301630`, `302130`, `303130`, and `304130` for ancestor, descendant,
any-sibling, sibling-before, and sibling-after respectively. Attribute and
compound marker states use the pinned `304000` fallback, and `@container`
adds `30000` rather than the media offset `20000`.

## Review and verification

The lock is intentionally JSON so a reviewer can inspect each property without
reading generated MoonBit match arms. Every slot includes `slotProperties`,
which names known live owners of that slot and makes tombstone edges readable.

The default application-order tests validate the committed lock, local alias,
and generated MoonBit entries without importing Babel. `vp -C tools/stylex-oracle test run --config vite.config.mjs`
recompiles all 392 properties, the supplemental font shorthand, and the
condition fixtures. It compares raw upstream priorities,
slots, and normalized rules, then checks the versioned local alias separately
from upstream parity. Conflict tests cover both application orders, conditional
classes, aliases, and Clear. MoonBit tests cover the
same runtime shape on all four backends. Browser tests cover shorthand and
longhand order, logical and physical order, LTR, RTL, and `vertical-rl` writing
mode in Chromium, Firefox in normal CI, and WebKit.

Strict `moon run tools/validate-ci.mbtx` requires those live oracle tests. Default
`moon run tools/validate.mbtx` covers the committed semantic baseline without requiring the
oracle installation. Explicit refresh compiles and verifies all observations
before replacing the lock and table; it does not silently alter the baseline
as part of validation.

This is behavioral compatibility for the supported surface. It is not a promise
that every future StyleX class identifier, unsupported property, or extension
will match.

Review input updates through the [data maintenance workflow](data-sources.md).
The [current status](current-status.md) records the active contracts and
validation commands.
