///|
fn fluent_slot_theme_override() {
  let variables : @moonstyle.VariableScope = @moonstyle.variable_scope("demo")
  let accent : @moonstyle.ColorSlot = variables.color_slot(
    "accent", @moonstyle.rgb(1, 2, 3),
  )
  ignore(accent.with_value(@moonstyle.rgb(4, 5, 6)))
}
