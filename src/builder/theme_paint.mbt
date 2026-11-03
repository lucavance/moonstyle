///|
pub impl SvgPaintInput for @values.Color with fn property_input(self) {
  static_input(self.to_css())
}

///|
pub impl SvgPaintInput for @values.Token[@values.Color] with fn property_input(
  self,
) {
  token_input(self)
}

///|
pub impl SvgPaintInput for @values.DynamicSlot[@values.Color] with fn property_input(
  self,
) {
  slot_input(self)
}

///|
pub impl SvgPaintInput for @values.ColorExpr with fn property_input(self) {
  expression_input(@values.paint(self).expression())
}
