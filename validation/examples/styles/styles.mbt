///|
let demo_variables : @moonstyle.VariableScope = @moonstyle.variable_scope(
  "demo",
)

///|
let progress : @moonstyle.LengthSlot = demo_variables.length_slot(
  "progress",
  @moonstyle.percent(37),
)

///|
let font_width : @moonstyle.PercentageSlot = demo_variables.percentage_slot(
  "font-width",
  @moonstyle.percentage(100.0),
)

///|
let surface : @moonstyle.ColorToken = demo_variables.color_token(
  "surface",
  @moonstyle.rgb(243, 245, 247),
)

///|
let text_color : @moonstyle.ColorToken = demo_variables.color_token(
  "text",
  @moonstyle.rgb(23, 33, 43),
)

///|
let dynamic_surface : @moonstyle.ColorSlot = demo_variables.color_slot(
  "dynamic-surface",
  @moonstyle.rgb(243, 245, 247),
)

///|
let dynamic_text : @moonstyle.ColorSlot = demo_variables.color_slot(
  "dynamic-text",
  @moonstyle.rgb(23, 33, 43),
)

///|
let component_button_variables : @moonstyle.VariableScope = @moonstyle.variable_scope(
  "component-button",
)

///|
let component_button_surface : @moonstyle.ColorToken = component_button_variables.color_token(
  "surface",
  @moonstyle.rgb(226, 244, 232),
)

///|
let component_button_border : @moonstyle.ColorToken = component_button_variables.color_token(
  "border",
  @moonstyle.rgb(75, 150, 104),
)

///|
let component_button_text : @moonstyle.ColorSlot = component_button_variables.color_slot(
  "text",
  @moonstyle.rgb(23, 33, 43),
)

///|
let dark_theme : @moonstyle.Theme = @moonstyle.theme("dark", [
  surface.with_value(@moonstyle.rgb(34, 42, 49)),
  text_color.with_value(@moonstyle.rgb(236, 241, 245)),
])

///|
let fade_animation : @moonstyle.AnimationName = @moonstyle.keyframes("fade", [
  @moonstyle.frame(From).opacity(0.25),
  @moonstyle.frame(To).opacity(1.0),
])

///|
fn static_line_width(value : Int32) -> @moonstyle.LineWidth {
  @moonstyle.px(value).as_line_width()
}

///|
let card_border : @moonstyle.BorderSide = @moonstyle.border_side(
  width=Some(static_line_width(1)),
  style=Some(LineStyleSolid),
  color=Some(@moonstyle.rgb(202, 211, 220)),
)

///|
let card_corner_radius : @moonstyle.CornerRadius = @moonstyle.corner_radius(
  @moonstyle.px(8).as_length_percentage(),
)

///|
let composite_border_side : @moonstyle.BorderSide = @moonstyle.border_side(
  width=Some(static_line_width(2)),
  style=Some(LineStyleSolid),
  color=Some(@moonstyle.rgb(18, 52, 86)),
)

///|
let composite_corner_radius : @moonstyle.CornerRadius = @moonstyle.corner_radius(
  @moonstyle.px(4).as_length_percentage(),
  vertical=Some(@moonstyle.percentage(25.0).as_length_percentage()),
)

///|
let composite_outline : @moonstyle.Outline = @moonstyle.outline(
  width=Some(static_line_width(3)),
  style=Some(OutlineStyleDashed),
  color=Some(@moonstyle.rgb(68, 85, 102).as_outline_color()),
)

///|
let demo_group_marker : @moonstyle.MarkerDefinition = @moonstyle.define_marker(
  "demo_group",
)

///|
let badge_recipe : @moonstyle.Recipe = @moonstyle.recipe("badge_recipe", [
    @moonstyle.recipe_rule()
    .display(@moonstyle.Display::Flex)
    .gap(@moonstyle.px(4)),
  ])
  .variant(
    "size",
    [
      @moonstyle.variant_choice("compact", [
        @moonstyle.recipe_rule().padding(@moonstyle.px(4)),
      ]),
      @moonstyle.variant_choice("roomy", [
        @moonstyle.recipe_rule().padding(@moonstyle.px(10)),
      ]),
    ],
    default=Some("compact"),
  )
  .boolean_variant(
    "muted",
    [@moonstyle.recipe_rule().opacity(0.65)],
    default=Some(false),
  )
  .compound(
    [
      @moonstyle.variant_is("size", "roomy"),
      @moonstyle.boolean_variant_is("muted", true),
    ],
    [@moonstyle.recipe_rule().font_weight(600)],
  )

///|
let demo_position_try : @moonstyle.PositionTryRule = @moonstyle.position_try_rule(
    "demo-tooltip",
  )
  .position_area(@moonstyle.position_area(AreaCenter, AreaBottom))
  .max_width(@moonstyle.px(360))
  .margin_block_start(@moonstyle.px(8))
  .min_inline_size(@moonstyle.px(40))

///|
let demo_transition : @moonstyle.ViewTransitionClassDefinition = @moonstyle.define_view_transition_class(
    "demo_shared",
  )
  .group(
    @moonstyle.rule("group")
    .animation_duration(@moonstyle.ms(1000))
    .font_size_adjust(@moonstyle.number(0.545)),
  )
  .image_pair(@moonstyle.rule("pair").opacity(0.9))
  .old(
    @moonstyle.rule("old")
    .animation_duration(@moonstyle.ms(1000))
    .font_weight(400),
  )
  .new(
    @moonstyle.rule("new")
    .animation_duration(@moonstyle.ms(1000))
    .font_weight(700),
  )

///|
pub fn registry() -> @moonstyle.Registry {
  @moonstyle.registry_builder("lampclaw/moonstyle/examples")
  .rules([
    @moonstyle.rule("page")
    .min_height(@moonstyle.vh(100))
    .display(@moonstyle.Display::Grid)
    .place_items(@moonstyle.PlaceItems::Center)
    .padding(@moonstyle.px(24))
    .font_family("Inter, ui-sans-serif, system-ui, sans-serif")
    .background_color(surface)
    .background_color(
      @moonstyle.rgb(231, 238, 245),
      when=@moonstyle.max_width(@moonstyle.px(640)),
    )
    .color(text_color),
    @moonstyle.rule("card")
    .width(@moonstyle.percent(100))
    .max_width(@moonstyle.px(560))
    .padding(@moonstyle.px(28))
    .border(card_border)
    .border_top_left_radius(card_corner_radius)
    .border_top_right_radius(card_corner_radius)
    .border_bottom_left_radius(card_corner_radius)
    .border_bottom_right_radius(card_corner_radius)
    .box_shadow(
      @moonstyle.box_shadows([
        @moonstyle.shadow(
          @moonstyle.zero(),
          @moonstyle.px(18),
          blur=Some(@moonstyle.px(50)),
          color=Some(@moonstyle.rgba(30, 45, 60, 0.12)),
        ),
      ]),
    )
    .background_color(@moonstyle.rgb(255, 255, 255))
    .background_color(@moonstyle.rgb(248, 251, 253), when=@moonstyle.hover)
    .color(@moonstyle.rgb(23, 33, 43)),
    @moonstyle.rule("active")
    .background_color(component_button_surface)
    .border_color(component_button_border),
    @moonstyle.rule("buttonTone").color(component_button_text),
    @moonstyle.rule("borderCompositeSide").border(composite_border_side),
    @moonstyle.rule("borderCompositePairs")
    .border_block_width(
      @moonstyle.border_widths(
        static_line_width(1),
        second=Some(static_line_width(3)),
      ),
    )
    .border_block_style(
      @moonstyle.border_styles(LineStyleSolid, second=Some(LineStyleDotted)),
    )
    .border_block_color(
      @moonstyle.border_colors(
        @moonstyle.rgb(17, 34, 51),
        second=Some(@moonstyle.rgb(68, 85, 102)),
      ),
    )
    .border_inline_width(
      @moonstyle.border_widths(
        static_line_width(2),
        second=Some(static_line_width(4)),
      ),
    )
    .border_inline_style(
      @moonstyle.border_styles(LineStyleDashed, second=Some(LineStyleDouble)),
    )
    .border_inline_color(
      @moonstyle.border_colors(
        @moonstyle.rgb(119, 136, 153),
        second=Some(@moonstyle.rgb(170, 187, 204)),
      ),
    ),
    @moonstyle.rule("borderCompositeLonghands")
    .border_top_width(static_line_width(5))
    .border_top_style(@moonstyle.LineStyle::LineStyleDouble)
    .border_top_color(@moonstyle.rgb(12, 34, 56)),
    @moonstyle.rule("borderCompositeCorner").border_top_left_radius(
      composite_corner_radius,
    ),
    @moonstyle.rule("borderCompositeOutline").outline(composite_outline),
    @moonstyle.rule("title")
    .margin_top(@moonstyle.zero())
    .margin_bottom(@moonstyle.px(12))
    .font_size(@moonstyle.px(28))
    .font_weight(700)
    .line_height(1.2),
    @moonstyle.rule("copy")
    .margin_top(@moonstyle.zero())
    .margin_bottom(@moonstyle.px(22))
    .font_size(@moonstyle.px(15))
    .line_height(1.6)
    .color(@moonstyle.rgb(82, 96, 109)),
    @moonstyle.rule("meterTrack")
    .height(@moonstyle.px(12))
    .width(@moonstyle.percent(100))
    .overflow(@moonstyle.Overflow::Hidden)
    .margin_bottom(@moonstyle.px(20))
    .border_radius(@moonstyle.px(6))
    .background_color(@moonstyle.rgb(220, 227, 233)),
    @moonstyle.rule("meter")
    .width(progress)
    .height(@moonstyle.percent(100))
    .background_color(@moonstyle.rgb(33, 110, 78))
    .transition("width 180ms ease"),
    @moonstyle.rule("multiDynamic")
    .width(progress)
    .background_color(dynamic_surface)
    .color(dynamic_text),
    @moonstyle.rule("fontWidthDynamic").font_width(font_width),
    @moonstyle.rule("animated")
    .animation_name(fade_animation)
    .animation_duration(@moonstyle.ms(10000)),
    @moonstyle.rule("button")
    .padding_block(@moonstyle.px(10))
    .padding_inline(@moonstyle.px(16))
    .font_weight(650)
    .border_width(@moonstyle.px(1))
    .border_style(@moonstyle.BorderStyle::Solid)
    .border_color(@moonstyle.rgb(31, 95, 70))
    .border_radius(@moonstyle.px(6))
    .background_color(@moonstyle.rgb(33, 110, 78))
    .color(@moonstyle.rgb(255, 255, 255))
    .appearance("none")
    .cursor(@moonstyle.Cursor::Pointer),
    @moonstyle.rule("conflictMargin").margin(@moonstyle.px(8)),
    @moonstyle.rule("conflictMarginTop").margin_top(@moonstyle.px(16)),
    @moonstyle.rule("conflictConditionalMargin").margin(
      @moonstyle.px(8),
      when=@moonstyle.hover,
    ),
    @moonstyle.rule("conflictPadding").padding(@moonstyle.px(6)),
    @moonstyle.rule("conflictPaddingLeft").padding_left(@moonstyle.px(12)),
    @moonstyle.rule("conflictGap").gap(@moonstyle.px(4)),
    @moonstyle.rule("conflictRowGap").row_gap(@moonstyle.px(10)),
    @moonstyle.rule("rtlDirectional")
    .margin_inline_start(@moonstyle.px(11))
    .padding_inline_end(@moonstyle.px(13))
    .border_inline_start_width(@moonstyle.px(3))
    .border_inline_start_style(@moonstyle.BorderStyle::Solid)
    .border_inline_start_color(@moonstyle.rgb(210, 42, 58))
    .border_start_start_radius(@moonstyle.px(7)),
    @moonstyle.rule("conflictLogicalMargin").margin_inline_start(
      @moonstyle.px(18),
    ),
    @moonstyle.rule("conflictPhysicalMargin").margin_left(@moonstyle.px(24)),
    @moonstyle.rule("scalarBlockSize").block_size(@moonstyle.px(40)),
    @moonstyle.rule("scalarHeight").height(@moonstyle.px(70)),
    @moonstyle.rule("scalarInlineSize").inline_size(@moonstyle.px(45)),
    @moonstyle.rule("scalarWidth").width(@moonstyle.px(75)),
    @moonstyle.rule("scalarScrollMargin").scroll_margin(@moonstyle.px(8)),
    @moonstyle.rule("scalarScrollMarginTop").scroll_margin_top(
      @moonstyle.px(20),
    ),
    @moonstyle.rule("scalarOverscroll").overscroll_behavior(
      @moonstyle.OverscrollBehaviorValue::OverscrollBehaviorValueAuto,
    ),
    @moonstyle.rule("scalarOverscrollBlock").overscroll_behavior_block(
      @moonstyle.OverscrollBehaviorBlockValue::OverscrollBehaviorBlockValueContain,
    ),
    @moonstyle.rule("scalarTransition").transition("opacity 90ms linear"),
    @moonstyle.rule("scalarTransitionDuration").transition_duration(
      @moonstyle.ms(240),
    ),
    @moonstyle.rule("scalarSvg")
    .cx(@moonstyle.px(18).as_length_percentage())
    .cy(@moonstyle.px(22).as_length_percentage())
    .fill_opacity(0.4)
    .fill_rule(@moonstyle.FillRuleValue::FillRuleValueEvenodd)
    .stroke_linecap(@moonstyle.StrokeLinecapValue::StrokeLinecapValueRound),
    @moonstyle.rule("clearBase").color(@moonstyle.rgb(255, 0, 0)),
    @moonstyle.rule("clearColor").clear_color(),
    @moonstyle.rule("markerChild").color(
      @moonstyle.rgb(33, 110, 78),
      when=@moonstyle.marker_ancestor(
        @moonstyle.selector_attribute_equals(
          demo_group_marker, "aria-expanded", "true",
        ),
      ),
    ),
  ])
  .rules(expression_rules())
  .rules(coverage_rules())
  .rules(upstream_rules())
  .theme(dark_theme)
  .recipe(badge_recipe)
  .marker(demo_group_marker)
  .position_try(demo_position_try)
  .view_transition_class(demo_transition)
  .dependency(
    @moonstyle.dependency_ref(
      "fixture/component-a", "sha256:766a10ad2443fc3ade680eed97c6145e6a17b7824aede5b4879b86d949b911f5",
    ),
  )
  .dependency(
    @moonstyle.dependency_ref(
      "fixture/component-b", "sha256:374fc083d9feb987de96c663afb0e30289bdd6fa7709f7e395030e9fffe0942e",
    ),
  )
  .build()
}
