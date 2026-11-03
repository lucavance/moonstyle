///|
fn invalid() -> @moonstyle.Rule {
  @moonstyle.rule("image").background_image_fallbacks(
    @moonstyle.ImageFallbacks::new()
    .add(@moonstyle.url("/0.5x.png"))
    .add(@moonstyle.px(5)),
  )
}
