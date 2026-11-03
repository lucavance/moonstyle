# Theme controls and SVG paint

`color_scheme` preserves list order and duplicates; `only=true` appends `only`.
Use `normal_color_scheme()` for `normal`; empty lists are diagnosed and custom
identifiers are outside the profile. Color schemes have no keyframe method.
Scrollbar pairs preserve thumb/track order; `scrollbar_auto()` selects automatic
colors. See [authoring](../docs/authoring.md) for registration and runtime composition.

```mbt check
///|
test "theme controls and exact paint contracts" {
  let scope = @moonstyle.variable_scope("preview")
  let brand = scope.color_token("brand", @moonstyle.rgb(24, 61, 49))
  let track = scope.color_token("track", @moonstyle.rgb(245, 245, 240))
  let tint = scope.color_slot("tint", @moonstyle.rgb(255, 0, 0))
  let scroll = @moonstyle.scrollbar_colors(thumb=brand, track~)
  let _ = @moonstyle.rule("preview")
    .color_scheme(@moonstyle.color_scheme([SchemeLight, SchemeDark]))
    .scrollbar_color(scroll)
    .fill(tint)
    .stroke(@moonstyle.paint_none())
  let _ = @moonstyle.style_contract("paint")
    .allow_fill(tokens=[brand], slots=[tint])
    .allow_stroke(expressions=[@moonstyle.paint_none()])
    .allow_scrollbar_color(expressions=[scroll])
}

///|
test "paint fallbacks retain each source" {
  let _ = @moonstyle.rule("icon").fill_fallbacks(
    @moonstyle.SvgPaintFallbacks::new()
    .add(@moonstyle.named_color("currentColor"))
    .add(@moonstyle.paint_none()),
  )
}
```

Direct fill/stroke Color, Token and Slot inputs preserve their source roles.
`paint(color)` wraps a color; `paint_none()` emits `none`, and `currentColor`
remains an ordinary named color. Wrapped paints, mixed colors and scrollbar
pairs require exact expression grants. Paint servers, context paints and stroke
width/dash APIs are outside the reviewed profile. Static/token-backed paint and
scrollbar values can appear in keyframes; dynamic Slots remain forbidden there
and in recipes.

Rabbita's `svg_attrs`, `try_svg_attrs`, `svg_attrs_or_abort` and
`svg_attrs_applied` accept native SVG base attributes and use the same
class/variable runtime contract as HTML. Use Rabbita SVG element constructors
to preserve the namespace. Repeated ColorSlot uses share one accessor argument,
and failure returns no partial attributes. See the
[adapter interface](rabbita/pkg.generated.mbti) and
[regeneration guide](../docs/regeneration.md).
