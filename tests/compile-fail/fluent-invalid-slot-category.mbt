///|
fn fluent_invalid_slot_category() {
  let variables : @moonstyle.VariableScope = @moonstyle.variable_scope("demo")
  let accent : @moonstyle.ColorSlot = variables.color_slot(
    "accent", @moonstyle.rgb(1, 2, 3),
  )
  ignore(@moonstyle.rule("box").width(accent))
}
