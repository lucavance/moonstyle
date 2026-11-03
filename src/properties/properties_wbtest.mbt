///|
test "property functions hide raw property names from common authoring" {
  let declaration = width(@values.px(8)).to_declaration()
  assert_eq(declaration.property, "width")
  assert_true(declaration.value == @ir.Text("8px"))
}

///|
test "conditional property functions retain typed conditions" {
  let declaration = color(@values.rgb(1, 2, 3), conditions=[@ir.pseudo(Hover)]).to_declaration()
  assert_true(declaration.conditions == [@ir.Pseudo(Hover)])
}

///|
test "generated fallbacks preserve typed values and author order" {
  let declaration = color_fallbacks(
    [@values.rgb(1, 2, 3), @values.transparent()],
    conditions=[@ir.pseudo(Hover)],
  ).to_declaration()
  assert_true(declaration.value == @ir.Fallbacks(["rgb(1 2 3)", "transparent"]))
  assert_true(declaration.conditions == [@ir.Pseudo(Hover)])
}

///|
test "stable scalar expansion preserves conservative value categories" {
  let block = block_size(@values.px(12)).to_declaration()
  assert_eq(block.property, "blockSize")
  assert_true(block.value == @ir.Text("12px"))
  let transition = transition_duration(@values.ms(180)).to_declaration()
  assert_eq(transition.property, "transitionDuration")
  assert_true(transition.value == @ir.Text("180ms"))
  let snap = scroll_snap_stop(ScrollSnapStopValueAlways).to_declaration()
  assert_eq(snap.property, "scrollSnapStop")
  assert_true(snap.value == @ir.Text("always"))
  let fill = fill_opacity(0.5).to_declaration()
  assert_eq(fill.property, "fillOpacity")
  assert_true(fill.value == @ir.Text("0.5"))
}

///|
test "border composite expansion preserves reviewed structured values" {
  let width = @values.line_width_from_length(@values.px(2)) catch {
    _ => fail("valid border width rejected")
  }
  let side = @values.border_side(
    width=Some(width),
    style=Some(@values.LineStyleSolid),
    color=Some(@values.hex_color("123")),
  ) catch {
    _ => fail("valid border side rejected")
  }
  let border = border(side).to_declaration()
  assert_eq(border.property, "border")
  assert_true(border.value == @ir.Text("2px solid #123"))
  let top = border_top_width(width).to_declaration()
  assert_eq(top.property, "borderTopWidth")
  assert_true(top.value == @ir.Text("2px"))
  let radius = @values.corner_radius(
    @values.length_percentage_from_length(@values.px(4)),
  )
  let corner = border_top_left_radius(radius).to_declaration()
  assert_eq(corner.property, "borderTopLeftRadius")
  assert_true(corner.value == @ir.Text("4px"))
}
