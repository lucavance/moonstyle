///|
test "low level paint declarations preserve nested variables and scheme restrictions" {
  let scope = @values.variable_scope("low-paint")
  let slot = scope.color_slot("live", @values.named_color("red"))
  let color = @values.paint(slot)
  let declaration = fill(color).to_declaration()
  guard declaration.value is Expression(expression) else {
    fail("paint must preserve its expression")
  }
  assert_eq(expression.variables().length(), 1)
  assert_true(expression.is_dynamic())
  let fallback = stroke_fallbacks([@values.paint_none(), color]).to_declaration()
  guard fallback.value is ExpressionFallbacks(values) else {
    fail("paint fallbacks must preserve their expressions")
  }
  assert_eq(values[1].variables().length(), 1)
  assert_false(
    color_scheme(@values.normal_color_scheme()).to_declaration().keyframe_allowed,
  )
  assert_false(
    color_scheme_fallbacks([@values.normal_color_scheme()]).to_declaration().keyframe_allowed,
  )
}
