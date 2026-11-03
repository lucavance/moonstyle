///|
let expression_offset : @moonstyle.LengthSlot = demo_variables.length_slot(
  "expression-offset",
  @moonstyle.px(20),
)

///|
let expression_angle : @moonstyle.AngleSlot = demo_variables.angle_slot(
  "expression-angle",
  @moonstyle.deg(90.0),
)

///|
let expression_track : @moonstyle.LengthPercentageSlot = demo_variables.length_percentage_slot(
  "expression-track",
  @moonstyle.px(80).as_length_percentage(),
)

///|
fn expression_rules() -> Array[@moonstyle.Rule] {
  let stops = [
    @moonstyle.color_stop(surface),
    @moonstyle.color_stop(@moonstyle.rgb(40, 100, 180)),
  ]
  let image = @moonstyle.linear_gradient(
    stops,
    direction=@moonstyle.gradient_angle(expression_angle),
  )
  let radial = @moonstyle.radial_gradient(
    stops,
    shape=Circle,
    size=@moonstyle.radial_radius(@moonstyle.px(30)),
  )
  let conic = @moonstyle.conic_gradient(
    [
      @moonstyle.conic_stop(surface),
      @moonstyle.conic_stop(@moonstyle.rgb(40, 100, 180)),
    ],
    angle=Some(@moonstyle.math_angle(expression_angle)),
  )
  [
    @moonstyle.rule("expressionPanel")
    .width(
      @moonstyle.math_length(expression_offset).add(
        @moonstyle.math_length(@moonstyle.px(100)),
      ),
    )
    .height(@moonstyle.px(48))
    .background_layers(
      @moonstyle.background_layers([
        @moonstyle.background_layer(
          image,
          size=@moonstyle.layer_size(@moonstyle.background_cover()),
          repeat=NoRepeat,
        ),
        @moonstyle.background_layer(radial),
        @moonstyle.background_layer(conic),
      ]),
    ),
    @moonstyle.rule("expressionGrid")
    .display(@moonstyle.Display::Grid)
    .width(@moonstyle.px(240))
    .grid_template_columns(
      @moonstyle.grid_tracks([
        @moonstyle.named_lines(["start"]),
        @moonstyle.auto_fit(
          @moonstyle.grid_tracks([
            @moonstyle.minmax(
              @moonstyle.track_length(expression_track),
              @moonstyle.fr(1.0),
            ),
          ]),
        ),
        @moonstyle.named_lines(["end"]),
      ]),
    )
    .grid_auto_rows(
      @moonstyle.grid_tracks([
        @moonstyle.track_length(@moonstyle.px(20).as_length_percentage()),
      ]),
    ),
    @moonstyle.rule("expressionSubgrid")
    .display(@moonstyle.Display::Grid)
    .grid_column(@moonstyle.grid_span(2))
    .grid_template_columns(@moonstyle.subgrid()),
    @moonstyle.rule("expressionLimits")
    .height(
      @moonstyle.percentage_as_length(@moonstyle.math_percentage(font_width)),
    )
    .font_width(
      @moonstyle.math_percentage(font_width).add(
        @moonstyle.math_percentage(@moonstyle.percentage(0.0)),
      ),
    ),
  ]
}
