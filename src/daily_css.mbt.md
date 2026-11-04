# Daily CSS and typed property registration

These APIs are available in MoonStyle 0.2.0. Use the root
`lampclaw/moonstyle` facade, imported as `@moonstyle`.

## Text, font axes and rendering hints

```mbt check
///|
test "common text and font properties" {
  let _ = @moonstyle.rule("label")
    .isolation(@moonstyle.Isolation::IsolationIsolate)
    .white_space(@moonstyle.WhiteSpace::WhiteSpacePreWrap)
    .text_wrap(@moonstyle.TextWrap::TextWrapBalance)
    .vertical_align(
      @moonstyle.vertical_align_offset(@moonstyle.px(-2).as_length_percentage()),
    )
    .will_change(@moonstyle.will_change([ChangeTransform, ChangeOpacity]))
    .font_variation_settings(
      @moonstyle.font_variations([
        @moonstyle.font_axis("wght", 650.0),
        @moonstyle.font_axis("wdth", 95.5),
      ]),
    )
}
```

Use `vertical_align(AlignMiddle)` for keywords, `will_change_auto()` for auto,
and `normal_font_variations()` for normal. Hint lists contain reviewed enum
values. Font tags preserve case and axis order, contain exactly four printable
ASCII characters and are escaped as CSS strings. Axis values must be finite.
Empty lists are errors. Negative vertical offsets are legal. Offsets and font
axes are static values in this profile.

All six properties support ordered fallbacks, CSS-wide whole values, typed
conditions, exact component contracts and Rule-only Clear methods. Compound
whitespace/wrapping grammars remain outside this subset; see
[the compatibility matrix](../docs/stylex-compatibility.md).

## Explicit CSS property registration

```mbt check
///|
test "register a length and theme color" {
  let variables = @moonstyle.variable_scope("card")
  let distance = variables
    .length_token("distance", @moonstyle.px(12))
    .registered(inherits=false)
  let accent = variables
    .color_token("accent", @moonstyle.named_color("blue"))
    .registered()
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "docs/registered",
      [@moonstyle.rule("card").width(distance).color(accent)],
      themes=[
        @moonstyle.theme("dark", [
          accent.with_value(@moonstyle.named_color("white")),
        ]),
      ],
    ),
  )
  assert_true(output.diagnostics.is_empty())
  assert_true(output.css.contains("@property --card-distance"))
}
```

Call `registered` before sharing a Token or DynamicSlot with styles, expressions
or themes. The immutable result opts into `<color>`, `<length>` or `<number>`
registration; other categories fail type checking. `inherits` defaults to true.
Choose false when descendant elements should use the registered initial value
instead of inheriting a parent's custom-property value. This also means a theme
on an ancestor will not affect a non-inheriting variable on descendants.

Initial values accept literal colors without contextual/system colors, absolute
lengths (`px`, `cm`, `mm`, `q`, `in`, `pc`, `pt`, or zero), and finite numbers.
Font/viewport/container units, percentages, `currentColor`, variable references
and derived defaults are rejected by this profile. Later typed theme overrides
and runtime Slot values retain their ordinary property validation rules.
Registration is separate from MoonBit type safety and remains opt-in: ordinary
Tokens/Slots emit no `@property` rule.

The extractor orders registrations before variable definitions and deduplicates
identical registrations. Conflicting definitions fail extraction or dependency
merging. Upgrade consumers with tooling from the same source revision and
re-extract component dependencies before applications for artifact v14.

The [repository browser example](../validation/examples/styles/daily.mbt) and
[browser tests](../tests/e2e.mjs) exercise inheritance, invalid assignments and
length interpolation in Chromium, Firefox and WebKit.
