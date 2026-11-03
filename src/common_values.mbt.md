# Common values and composite variables

Use the root authoring facade for intrinsic sizes, typography, corner radii,
shadows and filters. These values share the expression and variable provenance
model described in [typed expressions](expressions.mbt.md).

```mbt check
///|
test "intrinsic size and line height" {
  let _ = @moonstyle.rule("card")
    .width(@moonstyle.box_size_keyword(SizeFitContent))
    .font_size(@moonstyle.font_size_keyword(FontLarge))
    .line_height(@moonstyle.line_height_normal())
    .border_start_start_radius(
      @moonstyle.corner_radius(@moonstyle.px(8)).vertical(
        @moonstyle.percentage(20.0),
      ),
    )
}

///|
test "theme color and dynamic blur inside a shadow" {
  let scope = @moonstyle.variable_scope("card")
  let tint = scope.color_token("shadow", @moonstyle.rgb(20, 30, 40))
  let blur = scope.length_slot("blur", @moonstyle.px(8))
  let _ = @moonstyle.rule("card").box_shadow(
    @moonstyle.box_shadows([
      @moonstyle.shadow(@moonstyle.zero(), @moonstyle.px(2))
      .blur(blur)
      .color(tint),
    ]),
  )
}
```

Size keywords and fit-content calculations retain their reviewed categories.
The six logical-size methods keep a conservative Length subset; their grammar
does not automatically expand with WebRef. Composite corners preserve ordered
horizontal/vertical radii. The browser expands omitted vertical values.

Shadow/filter expressions preserve Token and Slot identities. Reusing a Slot
produces one generated runtime argument, with the union of constraints from
its uses. Literal negative blur/radii fail extraction, while negative shadow
offsets/spread and dimension-correct intermediate math remain legal. CSS checks
the final arithmetic range; the extractor does not reject every negative operand.

Defaults, themes and runtime values use the same applicable leaf validators.
Invalid dynamic inputs aggregate errors and produce no partial style. Grant
the complete composite through a contract's `expressions` channel rather than
assuming that a Token grant admits every expression containing it. See
[API stability](../docs/api-stability.md) and [regeneration](../docs/regeneration.md).
