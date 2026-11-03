///|
// StyleX #1903 and #1897: unitless numbers must survive both emission paths.
test "unitless typography and animation numbers retain their dimensions" {
  let animation = @moonstyle.keyframes("numbers", [
    @moonstyle.frame(From)
    .font_size_adjust(@moonstyle.number(0.545))
    .font_weight(400)
    .line_height(1.2)
    .z_index(@moonstyle.integer(1))
    .animation_iteration_count(@moonstyle.number(2.0)),
    @moonstyle.frame(To)
    .font_size_adjust(@moonstyle.number(0.6))
    .font_weight(700)
    .line_height(1.5)
    .z_index(@moonstyle.integer(2)),
  ])
  let output = @extract.compile_registry(
    @moonstyle.registry("upstream/unitless", [
      @moonstyle.rule("text")
      .font_size_adjust(@moonstyle.number(0.545))
      .animation_name(animation),
    ]),
  )
  assert_true(output.diagnostics.is_empty(), msg=output.manifest)
  assert_true(output.css.contains("{font-size-adjust:.545}"))
  assert_true(
    output.css.contains(
      "from{font-size-adjust:.545;font-weight:400;line-height:1.2;z-index:1;animation-iteration-count:2}",
    ),
  )
  assert_true(
    output.css.contains(
      "to{font-size-adjust:.6;font-weight:700;line-height:1.5;z-index:2}",
    ),
  )
}

///|
// StyleX #1742, #1759 and #1907: retain both axes and implicit vertical radii.
test "asymmetric border radii retain every horizontal and vertical value" {
  let fixtures = [
    ([1, 2], None, "1px 2px"),
    ([1, 2, 3], None, "1px 2px 3px"),
    ([1, 2, 3, 4], None, "1px 2px 3px 4px"),
    ([5], Some([1, 2, 3, 4]), "5px / 1px 2px 3px 4px"),
    ([5, 6, 7, 8], Some([1, 2, 3, 4]), "5px 6px 7px 8px / 1px 2px 3px 4px"),
  ]
  for (horizontal, vertical, expected) in fixtures {
    let radii = @moonstyle.border_radii(
      horizontal.map(value => @moonstyle.math_length_percentage(lp(value))),
      vertical?=vertical.map(values => {
        values.map(value => @moonstyle.math_length_percentage(lp(value)))
      }),
    )
    let output = @extract.compile_registry(
      @moonstyle.registry("upstream/radii", [
        @moonstyle.rule("radius").border_radius(radii),
      ]),
    )
    assert_true(output.diagnostics.is_empty(), msg=output.manifest)
    assert_true(
      output.css.contains("{border-radius:" + expected + "}"),
      msg=output.css,
    )
  }
}

///|
test "intrinsic sizes typography and elliptical radii compile through the public facade" {
  let radii = @moonstyle.border_radii(
    [
      @moonstyle.math_length_percentage(lp(4)),
      @moonstyle.math_length_percentage(lp(8)),
    ],
    vertical=[@moonstyle.math_length_percentage(lp(12))],
  )
  let output = @extract.compile_registry(
    @moonstyle.registry("common/values", [
      @moonstyle.rule("intrinsic")
      .width(@moonstyle.box_size_keyword(SizeMinContent))
      .max_inline_size(@moonstyle.box_size_keyword(SizeNone))
      .min_block_size(@moonstyle.box_size_keyword(SizeAuto))
      .height(@moonstyle.fit_content_size(@moonstyle.percentage(80.0)))
      .flex_basis(@moonstyle.basis_content())
      .font_size(@moonstyle.font_size_keyword(FontXXXLarge))
      .line_height(@moonstyle.percentage(150.0))
      .border_radius(radii)
      .border_start_start_radius(
        @moonstyle.corner_radius(@moonstyle.percentage(10.0)).vertical(
          @moonstyle.px(20),
        ),
      ),
      @moonstyle.rule("normal").line_height(@moonstyle.line_height_normal()),
      @moonstyle.rule("length").line_height(@moonstyle.px(24)),
    ]),
  )
  assert_true(output.diagnostics.is_empty(), msg=output.manifest)
  for
    expected in [
      "min-content", "fit-content(80%)", "xxx-large", "150%", "4px 8px / 12px", "10% 20px",
    ] {
    assert_true(output.css.contains(expected), msg=expected)
  }
}

///|
test "common value keyword ranges reject invalid properties but preserve valid math" {
  let bad = @extract.compile_registry(
    @moonstyle.registry("common/invalid", [
      @moonstyle.rule("maxauto").max_width(@moonstyle.auto()),
      @moonstyle.rule("preferrednone").width(
        @moonstyle.box_size_keyword(SizeNone),
      ),
      @moonstyle.rule("fontauto").font_size(@moonstyle.auto()),
      @moonstyle.rule("lineauto").line_height(@moonstyle.auto()),
      @moonstyle.rule("height").height(@moonstyle.px(-1)),
      @moonstyle.rule("line").line_height(-1.0),
      @moonstyle.rule("radius").border_radius(@moonstyle.px(-1)),
      @moonstyle.rule("empty").border_radius(@moonstyle.border_radii([])),
    ]),
  )
  assert_true(bad.diagnostics.length() >= 8)
  let math = @moonstyle.math_length(@moonstyle.px(-16)).add(
    @moonstyle.math_length(@moonstyle.px(100)),
  )
  let good = @extract.compile_registry(
    @moonstyle.registry("common/math", [
      @moonstyle.rule("size")
      .width(math)
      .border_radius(math)
      .filter(@moonstyle.filters([@moonstyle.blur_filter(math)])),
      @moonstyle.rule("negative").margin_left(@moonstyle.px(-1)),
    ]),
  )
  assert_true(good.diagnostics.is_empty())
  let operand = @moonstyle.variable_scope("arithmetic").length_slot(
    "operand",
    @moonstyle.px(-16),
  )
  let computed = @moonstyle.math_length(operand).add(
    @moonstyle.math_length(@moonstyle.px(100)),
  )
  let dynamic_math = @extract.compile_registry(
    @moonstyle.registry("common/dynamic-math", [
      @moonstyle.rule("size")
      .width(computed)
      .filter(@moonstyle.filters([@moonstyle.blur_filter(computed)])),
    ]),
  )
  assert_true(dynamic_math.diagnostics.is_empty())
  assert_false(dynamic_math.mappings.contains("\"nonnegative\""))
  assert_false(dynamic_math.mappings.contains("\"property:width\""))
}

///|
test "composite effects retain variable order identities and every shared slot constraint" {
  let scope = @moonstyle.variable_scope("effects")
  let offset = scope.length_slot("offset", @moonstyle.px(2))
  let radius = scope.length_slot("radius", @moonstyle.px(4))
  let tint = scope.color_token("tint", @moonstyle.rgb(10, 20, 30))
  let amount = scope.number_slot("amount", @moonstyle.number(0.5))
  let shadows = @moonstyle.box_shadows([
    @moonstyle.shadow(offset, @moonstyle.zero())
    .spread(@moonstyle.px(-2))
    .color(tint),
    @moonstyle.shadow(radius, offset).blur(radius).color(tint).inset(),
  ])
  let filters = @moonstyle.filters([
    @moonstyle.brightness_filter(amount),
    @moonstyle.blur_filter(radius),
    @moonstyle.grayscale_filter(@moonstyle.percentage(150.0)),
  ])
  let contract = @moonstyle.style_contract("effects")
    .allow_box_shadow(expressions=[shadows])
    .allow_filter(expressions=[filters])
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "common/effects",
      [
        @moonstyle.rule("allowed").box_shadow(shadows).filter(filters),
        @moonstyle.rule("reversed").filter(
          @moonstyle.filters([
            @moonstyle.blur_filter(radius),
            @moonstyle.brightness_filter(amount),
          ]),
        ),
      ],
      contracts=[contract],
    ),
  )
  assert_true(output.diagnostics.is_empty())
  assert_true(output.css.contains("0 0 -2px"))
  assert_true(output.css.contains("--effects-tint"))
  assert_true(output.mappings.contains("EffectsStyleInput for AllowedStyle"))
  assert_false(output.mappings.contains("EffectsStyleInput for ReversedStyle"))
  assert_true(output.mappings.contains("\"math:length\""))
  assert_true(output.mappings.contains("\"nonnegative\""))
  // One parameter in each of the two accessors, even with repeated uses.
  assert_eq(
    output.mappings.split("effects_radius : @values.Length,").count(),
    3,
  )
  match @extract.decode_bundle(output.manifest) {
    Ok(bundle) => assert_true(@extract.validate_bundle(bundle).is_empty())
    Err(_) => fail("composite contract must round trip")
  }
}

///|
test "effect defaults themes and text shadows use CSS grammar constraints" {
  let scope = @moonstyle.variable_scope("effect-theme")
  let radius = scope.length_token("blur", @moonstyle.px(2))
  let bad = @extract.compile_registry(
    @moonstyle.registry(
      "common/effect-errors",
      [
        @moonstyle.rule("blur").filter(
          @moonstyle.filters([@moonstyle.blur_filter(@moonstyle.px(-1))]),
        ),
        @moonstyle.rule("percent").filter(
          @moonstyle.filters([@moonstyle.blur_filter(@moonstyle.percent(10))]),
        ),
        @moonstyle.rule("inset").text_shadow(
          @moonstyle.text_shadows([
            @moonstyle.shadow(@moonstyle.zero(), @moonstyle.zero()).inset(),
          ]),
        ),
        @moonstyle.rule("spread").text_shadow(
          @moonstyle.text_shadows([
            @moonstyle.shadow(@moonstyle.zero(), @moonstyle.zero()).spread(
              @moonstyle.px(1),
            ),
          ]),
        ),
        @moonstyle.rule("theme").box_shadow(
          @moonstyle.box_shadows([
            @moonstyle.shadow(@moonstyle.zero(), @moonstyle.zero()).blur(radius),
          ]),
        ),
      ],
      themes=[
        @moonstyle.theme("negative", [radius.with_value(@moonstyle.px(-1))]),
      ],
    ),
  )
  assert_true(bad.diagnostics.length() >= 5)
  assert_true(bad.diagnostics.any(item => item.code == "STYLE_TEXT_SHADOW"))
  assert_true(
    bad.diagnostics.any(item => item.message.contains("in theme negative")),
  )
}

///|
test "radius tokens and slots keep constraints through mixed fallbacks" {
  let scope = @moonstyle.variable_scope("radii")
  let horizontal = scope.length_slot("h", @moonstyle.px(4))
  let vertical = scope.percentage_token("v", @moonstyle.percentage(30.0))
  let corner = @moonstyle.corner_radius(horizontal).vertical(vertical)
  let output = @extract.compile_registry(
    @moonstyle.registry("common/radii", [
      @moonstyle.rule("radius")
      .border_top_left_radius(corner)
      .border_radius_fallbacks(
        @moonstyle.BorderRadiiFallbacks::new()
        .add(@moonstyle.px(4))
        .add(@moonstyle.single_radius(horizontal)),
      ),
    ]),
  )
  assert_true(output.diagnostics.is_empty())
  assert_true(output.mappings.contains("\"nonnegative\""))
  assert_true(output.css.contains("var(--radii-h) var(--radii-v)"))
}
