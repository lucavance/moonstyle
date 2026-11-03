///|
fn mixed_fallback_categories() {
  ignore(@properties.color_fallbacks([
    @values.rgb(1, 2, 3),
    @values.px(4),
  ]))
}
