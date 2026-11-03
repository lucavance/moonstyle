///|
fn lp(value : Int32) -> @moonstyle.LengthPercentage {
  @moonstyle.length_percentage_from_length(@moonstyle.px(value))
}

///|
// StyleX #1750: later functions and nested math must keep dimensional zeros.
test "multiple transform functions preserve zero units inside nested math" {
  let zero_length = @moonstyle.math_length(@moonstyle.px(0))
  let offset = zero_length.add(@moonstyle.math_length(@moonstyle.px(1)))
  let transform = @moonstyle.transform_list([
    @moonstyle.rotate_transform(@moonstyle.deg(30.0)),
    @moonstyle.translate_x(offset.as_length_percentage()),
    @moonstyle.translate_z(@moonstyle.css_max([zero_length, offset])),
  ])
  let output = @extract.compile_registry(
    @moonstyle.registry("upstream/function-units", [
      @moonstyle.rule("box").transform(transform),
    ]),
  )
  assert_true(output.diagnostics.is_empty(), msg=output.manifest)
  assert_true(
    output.css.contains(
      "{transform:rotate(30deg) translateX(calc(0px + 1px)) translateZ(max(0px,calc(0px + 1px)))}",
    ),
    msg=output.css,
  )
}

///|
test "zero length tokens and theme overrides remain dimensional across registries" {
  let scope = @moonstyle.variable_scope("zero")
  let length = scope.length_token("length", @moonstyle.px(0))
  let mixed = scope.length_percentage_token("mixed", lp(0))
  let number = scope.number_token("number", @moonstyle.number(0.0))
  // The provider does not need to know that another module will use its tokens
  // in math. Bare typed properties must keep token defaults dimensional too.
  let provider = @extract.compile_registry(
    @moonstyle.registry(
      "zero/provider",
      [
        @moonstyle.rule("base")
        .width(length)
        .height(mixed)
        .font_size_adjust(number),
      ],
      themes=[
        @moonstyle.theme("reset", [
          length.with_value(@moonstyle.zero()),
          mixed.with_value(lp(0)),
          number.with_value(@moonstyle.number(0.0)),
        ]),
      ],
    ),
  )
  assert_true(provider.diagnostics.is_empty(), msg=provider.manifest)
  // Once in :root and once in the reset theme; number zero stays unitless.
  assert_eq(provider.css.split("--zero-length:0px").count(), 3)
  assert_eq(provider.css.split("--zero-mixed:0px").count(), 3)
  assert_eq(provider.css.split("--zero-number:0}").count(), 3)
  match @extract.decode_bundle(provider.manifest) {
    Ok(bundle) => assert_true(@extract.validate_bundle(bundle).is_empty())
    Err(_) => fail("dimensional variable globals must round trip")
  }
  let consumer = @extract.compile_registry(
    @moonstyle.registry("zero/consumer", [
      @moonstyle.rule("math").width(
        @moonstyle.math_length(length).add(
          @moonstyle.math_length(@moonstyle.px(1)),
        ),
      ),
    ]),
  )
  assert_true(consumer.diagnostics.is_empty(), msg=consumer.manifest)
  assert_true(consumer.css.contains("calc(var(--zero-length) + 1px)"))
}

///|
test "math retains dimensions structure and literal identity" {
  let width = @moonstyle.math_length(@moonstyle.px(40)).add(
    @moonstyle.math_length(@moonstyle.rem(2.0)),
  )
  assert_eq(width.to_css(), "calc(40px + 2rem)")
  assert_eq(width.divide(2.0).to_css(), "calc(calc(40px + 2rem) / 2)")
  let mixed = width
    .as_length_percentage()
    .add(
      @moonstyle.percentage_as_length(
        @moonstyle.math_percentage(@moonstyle.percentage(25.0)),
      ),
    )
  let output = @extract.compile_registry(
    @moonstyle.registry("test/math", [
      @moonstyle.rule("math")
      .width(mixed)
      .height(
        @moonstyle.css_clamp(
          @moonstyle.math_length(@moonstyle.px(10)),
          width,
          @moonstyle.math_length(@moonstyle.px(100)),
        ),
      ),
    ]),
  )
  assert_true(output.diagnostics.is_empty())
  assert_true(output.css.contains("25%"))
  assert_false(
    width.expression().identity() ==
    @moonstyle.math_length(@moonstyle.px(72)).expression().identity(),
  )
}

///|
test "nested variables retain all roles and stable deduplicated parameter order" {
  let scope = @moonstyle.variable_scope("expression")
  let x = scope.length_slot("x", @moonstyle.px(8))
  let y = scope.length_slot("y", @moonstyle.px(16))
  let gap = scope.length_token("gap", @moonstyle.px(4))
  let value = @moonstyle.math_length(x)
    .add(@moonstyle.math_length(gap))
    .add(@moonstyle.math_length(y))
    .add(@moonstyle.math_length(x))
  let output = @extract.compile_registry(
    @moonstyle.registry("test/math", [@moonstyle.rule("nested").width(value)]),
  )
  assert_true(output.diagnostics.is_empty())
  assert_true(output.mappings.contains("expression_x : @values.Length,"))
  assert_true(output.mappings.contains("expression_y : @values.Length,"))
  assert_eq(output.mappings.split("expression_x : @values.Length,").count(), 2)
  assert_false(output.mappings.contains("expression_gap : @values.Length,"))
  assert_true(output.mappings.contains("expression_value_issues"))
  assert_true(output.css.contains("--expression-gap:4px"))
}

///|
test "math grid and gradient errors aggregate before extraction output is usable" {
  let empty : Array[@moonstyle.MathExpr[@moonstyle.Length]] = []
  let bad = @extract.compile_registry(
    @moonstyle.registry("test/invalid", [
      @moonstyle.rule("keywords").width(
        @moonstyle.math_length(@moonstyle.auto()),
      ),
      @moonstyle.rule("zero").width(
        @moonstyle.math_length(@moonstyle.px(10)).divide(0.0),
      ),
      @moonstyle.rule("empty").height(@moonstyle.css_min(empty)),
      @moonstyle.rule("grid").grid_template_columns(
        @moonstyle.grid_tracks([
          @moonstyle.minmax(@moonstyle.fr(1.0), @moonstyle.fr(2.0)),
        ]),
      ),
      @moonstyle.rule("auto").grid_auto_columns(@moonstyle.subgrid()),
      @moonstyle.rule("repeat").grid_template_columns(
        @moonstyle.grid_tracks([
          @moonstyle.auto_fit(@moonstyle.grid_tracks([@moonstyle.fr(1.0)])),
        ]),
      ),
      @moonstyle.rule("gradient").background_image(
        @moonstyle.linear_gradient([
          @moonstyle.gradient_hint(lp(1)),
          @moonstyle.color_stop(@moonstyle.rgb(0, 0, 0)),
        ]),
      ),
      @moonstyle.rule("layers").background_layers(
        @moonstyle.background_layers([]),
      ),
    ]),
  )
  for
    code in [
      "STYLE_MATH_VALUE", "STYLE_MATH_DIVISOR", "STYLE_MATH_EMPTY", "STYLE_GRID_TRACK",
      "STYLE_GRID_AUTO_TRACK", "STYLE_GRADIENT_HINT", "STYLE_GRADIENT_STOPS", "STYLE_BACKGROUND_EMPTY",
    ] {
    assert_true(
      bad.diagnostics.any(diagnostic => diagnostic.code == code),
      msg=code,
    )
  }
}

///|
test "property constraints survive expression composition and theme overrides" {
  let scope = @moonstyle.variable_scope("constraint")
  let width = scope.percentage_token("width", @moonstyle.percentage(100.0))
  let expression = @moonstyle.math_percentage(width).add(
    @moonstyle.math_percentage(@moonstyle.percentage(10.0)),
  )
  let bad = @extract.compile_registry(
    @moonstyle.registry(
      "test/constraints",
      [
        @moonstyle.rule("font").font_width(expression),
        @moonstyle.rule("perspective").perspective(
          @moonstyle.percentage_as_length(
            @moonstyle.math_percentage(@moonstyle.percentage(20.0)),
          ),
        ),
      ],
      themes=[
        @moonstyle.theme("invalid", [
          width.with_value(@moonstyle.percentage(-20.0)),
        ]),
      ],
    ),
  )
  assert_true(
    bad.diagnostics.any(item => item.code == "STYLE_VALUE_OUT_OF_RANGE"),
  )
  assert_true(bad.diagnostics.any(item => item.code == "STYLE_MATH_DIMENSION"))
  let keyword = scope.length_token("keyword", @moonstyle.px(10))
  let invalid = @extract.compile_registry(
    @moonstyle.registry(
      "test/constraints",
      [@moonstyle.rule("math").width(@moonstyle.math_length(keyword))],
      themes=[
        @moonstyle.theme("keyword", [keyword.with_value(@moonstyle.auto())]),
      ],
    ),
  )
  assert_true(invalid.diagnostics.any(item => item.code == "STYLE_MATH_VALUE"))
}

///|
test "gradient families retain nested color angle and stop variables" {
  let scope = @moonstyle.variable_scope("gradient")
  let red = scope.color_token("red", @moonstyle.rgb(255, 0, 0))
  let angle = scope.angle_slot("angle", @moonstyle.deg(90.0))
  let stop = scope.length_percentage_slot("stop", lp(20))
  let stops = [
    @moonstyle.color_stop(
      red,
      position=Some(@moonstyle.math_length_percentage(stop)),
    ),
    @moonstyle.gradient_hint(lp(50)),
    @moonstyle.color_stop(@moonstyle.rgb(0, 0, 255)),
  ]
  let linear = @moonstyle.linear_gradient(
    stops,
    direction=@moonstyle.gradient_angle(angle),
    repeating=true,
  )
  let radial = @moonstyle.radial_gradient(
    stops,
    shape=Circle,
    size=@moonstyle.radial_radius(@moonstyle.math_length(@moonstyle.px(40))),
  )
  let conic = @moonstyle.conic_gradient(
    [
      @moonstyle.conic_stop(red),
      @moonstyle.conic_stop(
        @moonstyle.rgb(0, 0, 255),
        position=Some(@moonstyle.conic_percentage(@moonstyle.percentage(100.0))),
      ),
    ],
    angle=Some(@moonstyle.math_angle(angle)),
  )
  let result = @extract.compile_registry(
    @moonstyle.registry("test/gradient", [
      @moonstyle.rule("images").background_image(
        @moonstyle.background_images([linear, radial, conic]),
      ),
    ]),
  )
  assert_true(result.diagnostics.is_empty())
  for
    expected in [
      "repeating-linear-gradient(", "radial-gradient(", "conic-gradient(", "var(--gradient-red)",
    ] {
    assert_true(result.css.contains(expected))
  }
  assert_eq(result.mappings.split("gradient_angle : @values.Angle,").count(), 2)
  assert_true(
    result.mappings.contains("gradient_stop : @values.LengthPercentage,"),
  )
}

///|
test "grid fixed size rules named lines and template grammar" {
  let track = @moonstyle.minmax(
    @moonstyle.track_length(lp(100)),
    @moonstyle.fr(1.0),
  )
  let valid = @extract.compile_registry(
    @moonstyle.registry("test/grid", [
      @moonstyle.rule("grid").grid_template_columns(
        @moonstyle.grid_tracks([
          @moonstyle.named_lines(["start"]),
          @moonstyle.auto_fit(@moonstyle.grid_tracks([track])),
          @moonstyle.named_lines(["end"]),
        ]),
      ),
      @moonstyle.rule("sub").grid_template_rows(
        @moonstyle.subgrid(lines=[["start"], ["end"]]),
      ),
      @moonstyle.rule("intrinsic").grid_auto_rows(
        @moonstyle.grid_tracks([
          @moonstyle.track_auto(),
          @moonstyle.fit_content(lp(80)),
        ]),
      ),
    ]),
  )
  assert_true(valid.diagnostics.is_empty())
  assert_true(valid.css.contains("auto-fit"))
  assert_true(valid.css.contains("subgrid"))
  let invalid = @extract.compile_registry(
    @moonstyle.registry("test/grid", [
      @moonstyle.rule("double").grid_template_columns(
        @moonstyle.grid_tracks([
          @moonstyle.auto_fit(@moonstyle.grid_tracks([track])),
          @moonstyle.auto_fill(@moonstyle.grid_tracks([track])),
        ]),
      ),
      @moonstyle.rule("nested").grid_template_rows(
        @moonstyle.grid_tracks([
          @moonstyle.repeat_tracks(
            2,
            @moonstyle.grid_tracks([
              @moonstyle.repeat_tracks(3, @moonstyle.grid_tracks([track])),
            ]),
          ),
        ]),
      ),
    ]),
  )
  assert_true(
    invalid.diagnostics.any(item => item.code == "STYLE_GRID_AUTO_REPEAT"),
  )
  assert_true(invalid.diagnostics.any(item => item.code == "STYLE_GRID_TRACK"))
}

///|
test "grid line identifiers preserve case and reject invalid grammar" {
  let valid = @extract.compile_registry(
    @moonstyle.registry("test/grid-names", [
      @moonstyle.rule("names").grid_template_columns(
        @moonstyle.grid_tracks([
          @moonstyle.named_lines(["Main_start", "列", "--custom"]),
          @moonstyle.track_length(lp(20)),
        ]),
      ),
      @moonstyle.rule("unnamed").grid_template_columns(
        @moonstyle.subgrid(lines=[[], ["middle"]]),
      ),
    ]),
  )
  assert_true(valid.diagnostics.is_empty())
  assert_true(valid.css.contains("[Main_start 列 --custom]"))
  assert_true(valid.css.contains("subgrid [] [middle]"))
  for name in ["1name", "-1name", "Auto", "SPAN", "Inherit", "two names", ""] {
    let invalid = @extract.compile_registry(
      @moonstyle.registry("test/grid-names", [
        @moonstyle.rule("invalid").grid_template_columns(
          @moonstyle.grid_tracks([
            @moonstyle.named_lines([name]),
            @moonstyle.track_length(lp(20)),
          ]),
        ),
      ]),
    )
    assert_true(
      invalid.diagnostics.any(item => item.code == "STYLE_GRID_TRACK"),
      msg=name,
    )
  }
  let adjacent = @extract.compile_registry(
    @moonstyle.registry("test/grid-names", [
      @moonstyle.rule("adjacent").grid_template_columns(
        @moonstyle.grid_tracks([
          @moonstyle.named_lines(["a"]),
          @moonstyle.named_lines(["b"]),
          @moonstyle.track_length(lp(20)),
        ]),
      ),
    ]),
  )
  assert_true(adjacent.diagnostics.any(item => item.code == "STYLE_GRID_TRACK"))
}

///|
test "nested dynamic slots remain forbidden in recipes and keyframes" {
  let slot = @moonstyle.variable_scope("dynamic").length_slot(
    "x",
    @moonstyle.px(10),
  )
  let expression = @moonstyle.math_length(slot).add(
    @moonstyle.math_length(@moonstyle.px(1)),
  )
  let animation = @moonstyle.keyframes("invalid", [
    @moonstyle.frame(From)
    .width(expression)
    .filter(@moonstyle.filters([@moonstyle.blur_filter(slot)])),
  ])
  let compiled = @extract.compile_registry(
    @moonstyle.registry(
      "test/dynamic",
      [@moonstyle.rule("animated").animation_name(animation)],
      recipes=[
        @moonstyle.recipe("invalid", [
          @moonstyle.rule("base")
          .width(expression)
          .box_shadow(
            @moonstyle.box_shadows([@moonstyle.shadow(slot, @moonstyle.zero())]),
          ),
        ]),
      ],
    ),
  )
  assert_true(compiled.diagnostics.any(item => item.code.contains("KEYFRAME")))
  assert_true(compiled.diagnostics.any(item => item.code.contains("RECIPE")))
}

///|
test "expression contracts round trip exact operation and provenance identities" {
  let token = @moonstyle.variable_scope("contract").length_token(
    "x",
    @moonstyle.px(10),
  )
  let allowed = @moonstyle.math_length(token).add(
    @moonstyle.math_length(@moonstyle.px(5)),
  )
  let reversed = @moonstyle.math_length(@moonstyle.px(5)).add(
    @moonstyle.math_length(token),
  )
  let contract = @moonstyle.style_contract("size").allow_width(expressions=[
    allowed,
  ])
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "test/contract",
      [
        @moonstyle.rule("allowed").width(allowed),
        @moonstyle.rule("reversed").width(reversed),
        @moonstyle.rule("plain").width(token),
      ],
      contracts=[contract],
    ),
  )
  assert_true(output.diagnostics.is_empty())
  assert_true(output.mappings.contains("SizeStyleInput for AllowedStyle"))
  assert_false(output.mappings.contains("SizeStyleInput for ReversedStyle"))
  assert_false(output.mappings.contains("SizeStyleInput for PlainStyle"))
  assert_eq(output.schema_version, 13)
  match @extract.decode_bundle(output.manifest) {
    Ok(bundle) => assert_true(@extract.validate_bundle(bundle).is_empty())
    Err(_) => fail("v13 exact expressions must round trip")
  }
  match
    @extract.decode_bundle(
      output.manifest.replace_all(
        old="\"schemaVersion\":13",
        new="\"schemaVersion\":9",
      ),
    ) {
    Err(errors) =>
      assert_true(errors.any(item => item.code == "STYLE_BUNDLE_SCHEMA"))
    Ok(_) => fail("v9 must be re-extracted")
  }
}

///|
test "same-name variables cannot change category role or default inside expressions" {
  let scope = @moonstyle.variable_scope("collision")
  let slot = scope.length_slot("x", @moonstyle.px(1))
  let token = scope.length_token("x", @moonstyle.px(1))
  let output = @extract.compile_registry(
    @moonstyle.registry("test/conflict", [
      @moonstyle.rule("conflict").width(
        @moonstyle.math_length(slot).add(@moonstyle.math_length(token)),
      ),
    ]),
  )
  assert_true(
    output.diagnostics.any(item => item.code == "STYLE_VARIABLE_DUPLICATE"),
  )
  let first = @moonstyle.variable_scope("first-second").length_slot(
    "third",
    @moonstyle.px(1),
  )
  let second = @moonstyle.variable_scope("first").length_token(
    "second-third",
    @moonstyle.px(2),
  )
  let collision = @extract.compile_registry(
    @moonstyle.registry("test/conflict", [
      @moonstyle.rule("collision").width(
        @moonstyle.math_length(first).add(@moonstyle.math_length(second)),
      ),
    ]),
  )
  assert_true(
    collision.diagnostics.any(item => item.code == "STYLE_VARIABLE_DUPLICATE"),
  )
}

///|
test "grid fallback variables keep bindings constraints and dynamic bans" {
  let slot = @moonstyle.variable_scope("fallback").length_percentage_slot(
    "size",
    lp(20),
  )
  let tracks = @moonstyle.grid_tracks([@moonstyle.track_length(slot)])
  let rule = @moonstyle.rule("fallback").grid_template_columns_fallbacks(
    @moonstyle.GridTrackListFallbacks::new()
    .add(@moonstyle.grid_tracks([@moonstyle.fr(1.0)]))
    .add(tracks),
  )
  let output = @extract.compile_registry(
    @moonstyle.registry("test/fallback", [rule]),
  )
  assert_true(output.diagnostics.is_empty())
  assert_true(
    output.mappings.contains("fallback_size : @values.LengthPercentage"),
  )
  let forbidden = @extract.compile_registry(
    @moonstyle.registry("test/fallback", [], recipes=[
      @moonstyle.recipe("bad", [rule]),
    ]),
  )
  assert_true(forbidden.diagnostics.any(item => item.code.contains("RECIPE")))
  let legacy = @moonstyle.grid_tracks([@moonstyle.fr(1.0), @moonstyle.fr(2.0)])
  let contract = @moonstyle.style_contract("legacy").allow_grid_template_columns(values=[
      legacy,
    ],
  )
  let old = @extract.compile_registry(
    @moonstyle.registry(
      "test/legacy",
      [@moonstyle.rule("legacy").grid_template_columns(legacy)],
      contracts=[contract],
    ),
  )
  assert_true(old.mappings.contains("LegacyStyleInput for LegacyStyle"))
}

///|
test "background layer contracts admit the exact longhands and reject changed layers" {
  let red = @moonstyle.linear_gradient([
    @moonstyle.color_stop(@moonstyle.rgb(255, 0, 0)),
    @moonstyle.color_stop(@moonstyle.rgb(255, 255, 255)),
  ])
  let layers = @moonstyle.background_layers([
    @moonstyle.background_layer(red, repeat=NoRepeat),
  ])
  let changed = @moonstyle.background_layers([
    @moonstyle.background_layer(red, repeat=Repeat),
  ])
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "test/layers",
      [
        @moonstyle.rule("exact").background_layers(layers),
        @moonstyle.rule("changed").background_layers(changed),
      ],
      contracts=[
        @moonstyle.style_contract("layers").allow_background_layers([layers]),
      ],
    ),
  )
  assert_true(output.diagnostics.is_empty())
  assert_true(output.mappings.contains("LayersStyleInput for ExactStyle"))
  assert_false(output.mappings.contains("LayersStyleInput for ChangedStyle"))
  let altered = output.manifest.replace_all(old="no-repeat", new="repeat")
  match @extract.decode_bundle(altered) {
    Err(_) => ()
    Ok(bundle) =>
      assert_true(
        @extract.validate_bundle(bundle).any(item => {
          item.code.contains("DIGEST")
        }),
      )
  }
}
