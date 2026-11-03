///|
fn invalid() -> @moonstyle.ColorExpr {
  @moonstyle.color_mix(Srgb, @moonstyle.named_color("red"), @moonstyle.named_color("blue"),
    first_weight=@moonstyle.px(10))
}
