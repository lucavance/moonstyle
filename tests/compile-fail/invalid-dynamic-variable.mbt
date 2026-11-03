///|
fn invalid_dynamic_variable() raise @values.ValueError {
  let color_variable : @values.CssVar[@values.Color] = @values.color_var(
    "demo",
    "accent",
    @values.rgb(1, 2, 3),
  )
  ignore(@properties.dynamic_width(color_variable))
}
