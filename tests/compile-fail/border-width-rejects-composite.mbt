///|
fn border_width_rejects_composite() raise @values.ValueError {
  let side = @values.border_side(style=Some(@values.LineStyleSolid))
  ignore(@properties.border_top_width(side))
}
