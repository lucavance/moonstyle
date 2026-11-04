///|
fn daily_rules() -> Array[@moonstyle.Rule] {
  let variables = @moonstyle.variable_scope("daily")
  let distance = variables
    .length_token("distance", @moonstyle.px(12))
    .registered(inherits=false)
  let ink = variables
    .color_token("ink", @moonstyle.named_color("red"))
    .registered()
  let weight = variables
    .number_token("weight", @moonstyle.number(0.25))
    .registered(inherits=false)
  let ordinary = variables.length_token("ordinary", @moonstyle.px(8))
  [
    @moonstyle.rule("dailyText")
    .isolation(@moonstyle.Isolation::IsolationIsolate)
    .white_space(@moonstyle.WhiteSpace::WhiteSpacePreWrap)
    .text_wrap(@moonstyle.TextWrap::TextWrapBalance)
    .vertical_align(
      @moonstyle.vertical_align_offset(@moonstyle.px(-2).as_length_percentage()),
    )
    .will_change(@moonstyle.will_change([ChangeTransform, ChangeOpacity]))
    .font_variation_settings(
      @moonstyle.font_variations([
        @moonstyle.font_axis("wght", 650.0),
        @moonstyle.font_axis("wdth", 95.5),
      ]),
    ),
    @moonstyle.rule("dailyRegistered")
    .width(distance)
    .color(ink)
    .font_size_adjust(weight),
    @moonstyle.rule("dailyOrdinary").width(ordinary),
  ]
}
