///|
fn border_style_requires_line_style() {
  let legacy : @properties.BorderStyle = Solid
  ignore(@properties.border_top_style(legacy))
}
