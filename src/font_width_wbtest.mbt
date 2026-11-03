///|
test "font-width typed authoring rejects invalid token and slot defaults outside registries" {
  let scope = variable_scope("fonts")
  let invalid_token = scope.percentage_token("token", percentage(-20.0))
  let invalid_slot = scope.percentage_slot("slot", percentage(-30.0))
  let invalid_finite = scope.percentage_token("finite", percentage(1.0 / 0.0))
  let authored = registry("fixture/fonts", [
    rule("literal").font_width(percentage(-10.0)),
    rule("fallback").font_width_fallbacks(
      PercentageFallbacks::new().add(percentage(75.0)).add(percentage(-5.0)),
    ),
    rule("token").font_width(invalid_token),
    rule("slot").font_width(invalid_slot),
    rule("finite").font_width(invalid_finite),
  ])
  let compiled = @core.compile(authored.styles[0])
  assert_eq(compiled.diagnostics.length(), 5)
  assert_eq(
    compiled.diagnostics
    .filter(value => value.code == "STYLE_VALUE_OUT_OF_RANGE")
    .length(),
    4,
  )
  assert_eq(
    compiled.diagnostics
    .filter(value => value.code == "STYLE_VALUE_NON_FINITE")
    .length(),
    1,
  )
  assert_true(compiled.rules.is_empty())
  assert_true(compiled.diagnostics.every(value => value.source is Some(_)))
}

///|
test "font-width typed tokens slots and keyframes accept zero and positive defaults" {
  let scope = variable_scope("fonts")
  let token = scope.percentage_token("token", percentage(0.0))
  let slot = scope.percentage_slot("slot", percentage(125.0))
  let animation = keyframes("width", [
    frame(From).font_width(percentage(75.0)),
    frame(To).font_width(token),
  ])
  let authored = registry("fixture/fonts", [
    rule("token").font_width(token),
    rule("slot").font_width(slot),
    rule("animated").animation_name(animation),
  ])
  let compiled = @core.compile(authored.styles[0])
  assert_true(compiled.diagnostics.is_empty())
  assert_true(compiled.globals[0].css.contains("font-width:75%"))
}
