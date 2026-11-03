///|
fn contract_invalid_token_category() -> Unit {
  let variables : @moonstyle.VariableScope = @moonstyle.variable_scope("component")
  let spacing : @moonstyle.LengthToken = variables.length_token(
    "spacing",
    @moonstyle.px(8),
  )
  ignore(@moonstyle.style_contract("button").allow_color(tokens=[spacing]))
}
