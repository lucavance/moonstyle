///|
test "fluent rules lower into canonical declarations" {
  let namespace_ = rule("component")
    .display(Display::Grid)
    .font_weight(700)
    .border_style(BorderStyle::Solid)
    .cursor(Cursor::Pointer)
    .transition("width 100ms linear")
    .unsafe_raw("custom-property", "custom-value")
    .to_namespace()
  assert_eq(namespace_.declarations.map(declaration => declaration.property), [
    "display", "fontWeight", "borderStyle", "cursor", "transition", "custom-property",
  ])
  assert_true(namespace_.declarations[5].unsafe_raw)
}

///|
test "fluent declarations preserve application-order self descriptions" {
  let declaration = rule("spacing").margin(px(8)).to_namespace().declarations[0]
  assert_eq(declaration.property, "margin")
  assert_true(declaration.atomic_properties.is_empty())
  assert_false(declaration.unsafe_raw)
}

///|
test "fluent clear methods lower to source-aware clear declarations" {
  let namespace_ = rule("reset").clear_color().clear_margin().to_namespace()
  assert_eq(namespace_.declarations.map(value => value.property), [
    "color", "margin",
  ])
  assert_true(namespace_.declarations.every(value => value.value is Clear))
  assert_true(
    namespace_.declarations.every(value => value.value_origin is ClearOrigin),
  )
  assert_true(
    namespace_.declarations.every(value => value.conditions.is_empty()),
  )
  guard namespace_.declarations[0].source is Some(source) else {
    fail("generated clear methods must capture their MoonBit callsite")
  }
  assert_true(source.file.has_suffix("style_wbtest.mbt"))
  assert_eq(source.symbol, "color")
}

///|
test "fluent declarations capture MoonBit callsites and preserve overrides" {
  let declaration = rule("callsite").color(rgb(10, 20, 30)).to_namespace().declarations[0]
  guard declaration.source is Some(source) else {
    fail("generated property methods must capture their MoonBit callsite")
  }
  assert_true(source.file.has_suffix("style_wbtest.mbt"))
  assert_true(source.line > 0)
  assert_true(source.column >= 0)
  assert_true(source.end_line >= source.line)
  assert_true(source.end_column >= 0)
  assert_eq(source.symbol, "color")

  let explicit = source_span(
    "authored.mbt",
    7,
    3,
    end_line=8,
    end_column=9,
    symbol="manual",
  )
  let overridden = rule("override")
    .color(rgb(10, 20, 30), source=Some(explicit))
    .to_namespace().declarations[0]
  assert_eq(overridden.source, Some(explicit))
}

///|
test "style contracts use the generated exact-property authoring surface" {
  let button = style_contract("button")
    .allow_color()
    .allow_background_color()
    .allow_border_color()
  let authored = registry(
    "fixture/styles",
    [rule("active").color(rgb(10, 20, 30))],
    contracts=[button],
  )
  assert_eq(authored.contracts.length(), 1)
  assert_eq(authored.contracts[0].name, "button")
  assert_eq(authored.contracts[0].properties.map(property => property.name), [
    "color", "backgroundColor", "borderColor",
  ])
  assert_true(
    authored.contracts[0].properties.every(property => {
      property.policy is AnySafe
    }),
  )
}

///|
test "exact contract APIs preserve literal token and slot provenance" {
  let scope : VariableScope = variable_scope("component")
  let text : ColorToken = scope.color_token("text", rgb(20, 24, 28))
  let runtime_text : ColorSlot = scope.color_slot(
    "runtime-text",
    rgb(20, 24, 28),
  )
  let contract = style_contract("button").allow_color(
    values=[rgb(255, 255, 255)],
    tokens=[text],
    slots=[runtime_text],
  )
  match contract.to_ir().properties[0].policy {
    Exact(values, tokens, slots, _) => {
      assert_eq(values, ["rgb(255 255 255)"])
      assert_eq(tokens, [@ir.contract_variable("--component-text", "color")])
      assert_eq(slots, [
        @ir.contract_variable("--component-runtime-text", "color"),
      ])
    }
    AnySafe => fail("non-empty exact policy inputs must not lower as AnySafe")
  }
  let authored = rule("origins")
    .color(rgb(255, 255, 255))
    .background_color(text)
    .border_color(runtime_text)
    .to_namespace()
  assert_true(authored.declarations[0].value_origin is LiteralOrigin(_))
  assert_true(authored.declarations[1].value_origin is TokenOrigin(_))
  assert_true(authored.declarations[2].value_origin is DynamicSlotOrigin(_))
}

///|
test "fluent keyframes feed animation declarations" {
  let animation = keyframes("fade", [
    frame(From).opacity(0.0),
    frame(To).opacity(1.0),
  ])
  let declaration = rule("animated").animation_name(animation).to_namespace().declarations[0]
  assert_eq(declaration.property, "animationName")
}

///|
test "registry discovers tokens and dynamic slots" {
  let variables : VariableScope = variable_scope("demo")
  let surface : ColorToken = variables.color_token(
    "surface",
    rgb(255, 255, 255),
  )
  let progress : LengthSlot = variables.length_slot("progress", percent(0))
  let dark = theme("dark", [surface.with_value(rgb(20, 24, 28))])
  let authored = registry(
    "fixture/styles",
    [rule("card").background_color(surface), rule("meter").width(progress)],
    themes=[dark],
  )
  assert_eq(authored.variable_sets.length(), 1)
  assert_eq(authored.variable_sets[0].definitions.length(), 2)
  assert_eq(authored.themes.length(), 1)
}

///|
test "registry builder preserves registry_sheets lowering and source order" {
  let scope : VariableScope = variable_scope("builder")
  let surface : ColorToken = scope.color_token("surface", rgb(255, 255, 255))
  let contract = style_contract("card").allow_color()
  let dark = theme("dark", [surface.with_value(rgb(20, 24, 28))])
  let badge = recipe("badge", [recipe_rule().display(Display::Flex)])
  let group = define_marker("group")
  let tooltip = position_try_rule("tooltip").max_width(px(360))
  let transition = define_view_transition_class("shared")
  let dependency = dependency_ref("fixture/dependency", "sha256:dependency")
  let first = rule("first").color(surface)
  let second = rule("second").display(Display::Grid)
  let extra = rule("extra").clear_color()

  let built = registry_builder("fixture/builder")
    .rules([first])
    .rules([second])
    .rules([extra], export_name="extras")
    .contract(contract)
    .theme(dark)
    .recipe(badge)
    .marker(group)
    .position_try(tooltip)
    .view_transition_class(transition)
    .dependency(dependency)
    .extra_token(surface.definition_use())
    .build()
  let expected = registry_sheets(
    "fixture/builder",
    [sheet("styles", [first, second]), sheet("extras", [extra])],
    contracts=[contract],
    themes=[dark],
    recipes=[badge],
    markers=[group],
    position_tries=[tooltip],
    view_transition_classes=[transition],
    dependencies=[dependency],
    extra_tokens=[surface.definition_use()],
  )
  assert_eq(built, expected)
}

///|
test "recipes lower named variants boolean variants and compounds" {
  let button_contract = style_contract("button_contract")
    .allow_display()
    .allow_padding()
    .allow_opacity()
  let button = recipe("button", [recipe_rule().display(Display::Flex)])
    .variant(
      "size",
      [
        variant_choice("small", [recipe_rule().padding(px(4))]),
        variant_choice("large", [recipe_rule().padding(px(12))]),
      ],
      default=Some("small"),
    )
    .boolean_variant(
      "disabled",
      [recipe_rule().opacity(0.5)],
      default=Some(false),
    )
    .compound(
      [variant_is("size", "large"), boolean_variant_is("disabled", true)],
      [recipe_rule().opacity(0.4)],
    )
    .for_contract(button_contract)
  let authored = registry("fixture/recipes", [], contracts=[button_contract], recipes=[
    button,
  ])
  assert_eq(authored.recipes.length(), 1)
  assert_eq(authored.recipes[0].variants.map(axis => axis.name), [
    "size", "disabled",
  ])
  assert_eq(authored.styles[1].namespaces.length(), 5)
  assert_eq(authored.recipes[0].contract, Some("button_contract"))
}

///|
test "condition shortcuts lower to the existing condition IR" {
  assert_eq(max_width(px(640)).to_conditions(), [
    @ir.media(@ir.media_query([@ir.media_feature("width", Max, "640px")])),
  ])
  assert_eq(width_between(rem(40.0), rem(80.0)).to_conditions(), [
    @ir.media(
      @ir.media_query([
        @ir.media_feature("width", Min, "40rem"),
        @ir.media_feature("width", Max, "80rem"),
      ]),
    ),
  ])
  assert_eq(prefers_color_scheme(ColorSchemeDark).to_conditions(), [
    @ir.media(
      @ir.media_query([@ir.media_feature("prefers-color-scheme", Equal, "dark")]),
    ),
  ])
  assert_eq(prefers_reduced_motion(MotionReduce).to_conditions(), [
    @ir.media(
      @ir.media_query([
        @ir.media_feature("prefers-reduced-motion", Equal, "reduce"),
      ]),
    ),
  ])
  assert_eq(orientation(OrientationLandscape).to_conditions(), [
    @ir.media(
      @ir.media_query([@ir.media_feature("orientation", Equal, "landscape")]),
    ),
  ])
  assert_eq(supports_property("display", "grid").to_conditions(), [
    @ir.supports(@ir.supports_declaration("display", "grid")),
  ])
}

///|
test "and_when preserves immutable left-to-right condition order" {
  let responsive_hover = hover.and_when(min_width(rem(40.0)))
  assert_eq(responsive_hover.to_conditions(), [
    @ir.pseudo(Hover),
    @ir.media(@ir.media_query([@ir.media_feature("width", Min, "40rem")])),
  ])
  assert_eq(hover.to_conditions(), [@ir.pseudo(Hover)])
}

///|
test "typed markers and container queries lower without raw selectors" {
  let group = define_marker("group")
  let authored = registry(
    "fixture/selectors",
    [
      rule("child").color(
        rgb(20, 30, 40),
        when=marker_ancestor(selector_pseudo(group, Hover)),
      ),
      rule("responsive").display(
        Display::Grid,
        when=container_width_between(
          px(320),
          px(720),
          name=Some(container_name("card")),
        ),
      ),
    ],
    markers=[group],
  )
  assert_eq(authored.markers, [@ir.MarkerDefinition::{ name: "group", }])
  assert_true(
    authored.styles[0].namespaces[0].declarations[0].conditions[0]
    is Relational(_, MarkerAncestor),
  )
  assert_true(
    authored.styles[0].namespaces[1].declarations[0].conditions[0]
    is Container(_),
  )
}

///|
test "modern CSS values keep fluent authoring structured" {
  let area = position_area(AreaCenter, AreaBottom)
  let fallbacks = position_try_fallbacks([
    position_try_named("tooltip-wide"),
    position_try_area(area),
    position_try_tactic(TryFlipBlock),
  ])
  let modern = rule("modern")
    .box_shadow(
      box_shadows([
        shadow(zero(), px(4), blur=Some(px(12)), color=Some(rgb(1, 2, 3))),
      ]),
    )
    .filter(filters([blur_filter(px(2)), brightness_filter(number(1.1))]))
    .backdrop_filter(filters([grayscale_filter(percentage(20.0))]))
    .text_shadow(text_shadows([shadow(zero(), px(1), blur=Some(px(2)))]))
    .grid_template_areas(grid_template_areas([["header"], ["content"]]))
    .container_name(container_names(["card"]))
    .mask_image(mask_images([mask_image_url(url("mask.svg"))]))
    .mask_position(positions([position_center()]))
    .mask_repeat(repeat_styles([NoRepeat]))
    .mask_size(background_sizes([background_cover()]))
    .clip_path(
      clip_path_circle(length_percentage_from_percentage(percentage(50.0))),
    )
    .content(content_text("MoonBit"))
    .anchor_name(anchor_names([anchor_name("tooltip")]))
    .position_anchor(position_anchor(anchor_name("tooltip")))
    .position_area(area)
    .position_try(position_try_value(fallbacks, order=Some(TryOrderMostWidth)))
    .position_try_fallbacks(fallbacks)
    .position_try_order(PositionTryOrder::TryOrderMostWidth)
    .view_transition_name(view_transition_name("card"))
    .view_transition_class(view_transition_class("shared"))
  assert_eq(modern.to_namespace().declarations.length(), 20)

  let authored = registry(
    "fixture/modern",
    [modern],
    position_tries=[
      position_try_rule("tooltip-wide").position_area(area).max_width(px(360)),
    ],
    view_transition_classes=[define_view_transition_class("shared")],
  )
  assert_eq(authored.position_tries.length(), 1)
  assert_eq(authored.view_transition_classes.length(), 1)
}

///|
test "total authoring aggregates invalid values before CSS emission" {
  let authored = registry("fixture/styles", [
    rule("bad-color").color(rgb(300, -1, 4)),
    rule("bad-url").background_image(url("")),
    rule("bad-ratio").aspect_ratio(ratio(16, 0)),
  ])
  let compiled = @core.compile(authored.styles[0])
  assert_eq(compiled.rules.length(), 0)
  assert_eq(compiled.diagnostics.map(diagnostic => diagnostic.code), [
    "STYLE_VALUE_OUT_OF_RANGE", "STYLE_VALUE_EMPTY", "STYLE_VALUE_OUT_OF_RANGE",
  ])
}
