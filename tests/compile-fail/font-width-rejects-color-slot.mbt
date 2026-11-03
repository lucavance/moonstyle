///|
fn font_width_rejects_color_slot() {
  let slot = @moonstyle.variable_scope("font").color_slot("width", @moonstyle.rgb(1, 2, 3))
  ignore(@moonstyle.rule("text").font_width(slot))
}
