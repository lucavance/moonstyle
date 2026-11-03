///|
fn invalid() -> @moonstyle.ContainerStyleQuery {
  let token = @moonstyle.variable_scope("query").number_token("mode", @moonstyle.number(1.0))
  @moonstyle.container_style_equals(token, @moonstyle.px(10))
}
