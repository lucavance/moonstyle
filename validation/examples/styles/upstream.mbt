///|
fn upstream_rules() -> Array[@moonstyle.Rule] {
  let resource = @moonstyle.url("/__upstream__/v0.5/picture.svg?scale=0.5")
  let dynamic = demo_variables.url_slot("resource", resource)
  [
    @moonstyle.rule("upstreamResource")
    .background_image(resource)
    .width(@moonstyle.px(16))
    .height(@moonstyle.px(16)),
    @moonstyle.rule("upstreamContent").content(
      @moonstyle.content_text("version 0.5"),
      when=@moonstyle.before,
    ),
    @moonstyle.rule("upstreamDynamicResource").background_image(dynamic),
  ]
}
