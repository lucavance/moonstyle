///|
fn fluent_mixed_fallback_categories() {
  ignore(@moonstyle.rule("box").color_fallbacks([
    @moonstyle.rgb(1, 2, 3),
    @moonstyle.px(4),
  ]))
}
