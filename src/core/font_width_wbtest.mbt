///|
fn compile_font_width_fixture(
  declaration : @ir.Declaration,
) -> CompiledStyleSet {
  compile(@ir.style_set("font", [@ir.style_namespace("label", [declaration])]))
}

///|
test "font-width validates literals fallbacks and keyframe values before CSS emission" {
  let source = @ir.source_span("font.mbt", 4, 2, symbol="font_width")
  for value in [@ir.text("-1%"), @ir.fallbacks(["75%", "-25%"])] {
    let compiled = compile_font_width_fixture(
      @ir.declaration("fontWidth", value, source=Some(source)),
    )
    assert_eq(compiled.diagnostics.length(), 1)
    assert_eq(compiled.diagnostics[0].code, "STYLE_VALUE_OUT_OF_RANGE")
    assert_eq(compiled.diagnostics[0].source, Some(source))
    assert_true(compiled.rules.is_empty())
  }
  let animation = @ir.keyframes("invalid-width", [
    @ir.keyframe_frame(From, [
      @ir.declaration("fontWidth", @ir.text("-25%"), keyframe_allowed=true),
    ]),
  ])
  let compiled = compile_font_width_fixture(
    @ir.declaration("animationName", @ir.animation(animation)),
  )
  assert_eq(compiled.diagnostics[0].code, "STYLE_VALUE_OUT_OF_RANGE")
  assert_true(compiled.globals.is_empty())
}

///|
test "font-width property checks preserve the unsafe raw escape hatch" {
  let raw = compile_font_width_fixture(
    @ir.declaration("font-width", @ir.text("-25%"), unsafe_raw=true),
  )
  assert_true(raw.diagnostics.is_empty())
  assert_true(raw.rules[0].ltr.contains("font-width:-25%"))
  let other = compile_font_width_fixture(
    @ir.declaration("marginLeft", @ir.text("-25%")),
  )
  assert_true(other.diagnostics.is_empty())
}
