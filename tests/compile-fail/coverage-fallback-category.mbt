///|
fn invalid() -> @moonstyle.Rule {
  @moonstyle.rule("invalid").color_fallbacks(
    @moonstyle.ColorFallbacks::new().add(@moonstyle.px(10)),
  )
}
