///|
test "view transition groups emit typed global CSS and collect token animations" {
  let scope = @moonstyle.variable_scope("transition")
  let ink = scope.color_token("ink", @moonstyle.named_color("red"))
  let zero = scope.length_token("zero", @moonstyle.px(0))
  let animation = @moonstyle.keyframes("fade", [
    @moonstyle.frame(From).opacity(0.0).width(zero),
    @moonstyle.frame(To).opacity(1.0).width(@moonstyle.px(10)),
  ])
  let original = @moonstyle.define_view_transition_class("card")
  let definition = original
    .new(@moonstyle.rule("incoming").animation_name(animation).color(ink))
    .old(@moonstyle.rule("outgoing").animation_name(animation).opacity(0.5))
    .image_pair(@moonstyle.rule("pair").z_index(@moonstyle.integer(2)))
    .group(
      @moonstyle.rule("group")
      .font_size_adjust(@moonstyle.number(0.545))
      .font_weight(400)
      .line_height(1.2)
      .width(
        @moonstyle.math_length(@moonstyle.px(0)).add(
          @moonstyle.math_length(@moonstyle.px(1)),
        ),
      ),
    )
  let output = @extract.compile_registry(
    @moonstyle.registry_builder("transition/full")
    .view_transition_class(definition)
    .build(),
  )
  assert_eq(output.diagnostics, [])
  assert_eq(output.css.split("@keyframes ").count(), 2)
  assert_true(output.css.contains("--transition-zero:0px"), msg=output.css)
  assert_true(output.css.contains("--transition-ink:red"), msg=output.css)
  assert_true(
    output.css.contains(
      "{font-size-adjust:.545;font-weight:400;line-height:1.2;width:calc(0px + 1px)}",
    ),
    msg=output.css,
  )
  assert_true(output.css.contains("{z-index:2}"), msg=output.css)
  for group in ["group", "image-pair", "old", "new"] {
    assert_eq(
      output.css.split("::view-transition-" + group + "(*.vt").count(),
      2,
    )
  }
  assert_true(output.manifest.contains("\"namespaces\":[]"))
  assert_true(output.manifest.contains("\"rules\":[]"))
  assert_true(output.mappings.contains("card_view_transition_class"))
  assert_eq(original.to_ir().styles, [])
  match @extract.decode_bundle(output.manifest) {
    Ok(bundle) => assert_eq(@extract.validate_bundle(bundle), [])
    Err(errors) => fail(@extract.render_diagnostics_text(errors))
  }
}

///|
test "view transition group replacement fallbacks and identifier compatibility" {
  let original = @moonstyle.define_view_transition_class("card")
  let definition = original
    .old(@moonstyle.rule("discarded").opacity(0.25))
    .old(
      @moonstyle.rule("outgoing").color_fallbacks(
        @moonstyle.ColorFallbacks::new()
        .add(@moonstyle.named_color("red"))
        .add(@moonstyle.named_color("blue")),
      ),
    )
    .new(@moonstyle.rule("empty"))
  let output = @extract.compile_registry(
    @moonstyle.registry("transition/fallbacks", [], view_transition_classes=[
      definition,
    ]),
  )
  let identifier = @extract.compile_registry(
    @moonstyle.registry("transition/fallbacks", [], view_transition_classes=[
      original,
    ]),
  )
  assert_eq(output.diagnostics, [])
  assert_true(output.css.contains("{color:red;color:blue}"), msg=output.css)
  assert_false(output.css.contains("opacity"))
  assert_false(output.css.contains("::view-transition-new"))
  assert_false(identifier.css.contains("::view-transition"))
  // Mapping identities remain independent of pseudo styles.
  let mapping = output.mappings
    .split("\n")
    .filter(line => line.has_prefix("pub let card_view_transition_class"))
    .to_array()
  let original_mapping = identifier.mappings
    .split("\n")
    .filter(line => line.has_prefix("pub let card_view_transition_class"))
    .to_array()
  assert_eq(mapping, original_mapping)
}

///|
test "view transitions reject runtime values conditions clear and raw declarations" {
  let slot = @moonstyle.variable_scope("transition").length_slot(
    "live",
    @moonstyle.px(2),
  )
  let cases = [
    (
      @moonstyle.rule("nested").animation_name(
        @moonstyle.keyframes("invalid", [@moonstyle.frame(From).width(slot)]),
      ),
      "STYLE_KEYFRAME_DYNAMIC",
    ),
    (@moonstyle.rule("dynamic").width(slot), "STYLE_VIEW_TRANSITION_DYNAMIC"),
    (
      @moonstyle.rule("expression").width(@moonstyle.math_length(slot)),
      "STYLE_VIEW_TRANSITION_DYNAMIC",
    ),
    (@moonstyle.rule("clear").clear_color(), "STYLE_VIEW_TRANSITION_CLEAR"),
    (
      @moonstyle.rule("raw").unsafe_raw("color", "red"),
      "STYLE_VIEW_TRANSITION_PROPERTY",
    ),
    (
      @moonstyle.rule("condition").opacity(0.5, when=@moonstyle.hover),
      "STYLE_VIEW_TRANSITION_CONDITION",
    ),
  ]
  for (rule, code) in cases {
    let output = @extract.compile_registry(
      @moonstyle.registry("transition/invalid", [], view_transition_classes=[
        @moonstyle.define_view_transition_class("card").old(rule),
      ]),
    )
    assert_true(
      output.diagnostics.any(item => item.code == code && item.source is Some(_)),
      msg=@extract.render_diagnostics_text(output.diagnostics),
    )
    assert_false(output.css.contains("::view-transition"))
  }
}

///|
test "view transition expressions retain theme validation" {
  let scope = @moonstyle.variable_scope("transition")
  let size = scope.length_token("size", @moonstyle.px(10))
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "transition/themes",
      [],
      themes=[
        @moonstyle.theme("negative", [size.with_value(@moonstyle.px(-1))]),
      ],
      view_transition_classes=[
        @moonstyle.define_view_transition_class("card").group(
          @moonstyle.rule("sized").width(size),
        ),
      ],
    ),
  )
  assert_true(
    output.diagnostics.any(item => item.code == "STYLE_VALUE_OUT_OF_RANGE"),
    msg=@extract.render_diagnostics_text(output.diagnostics),
  )
}
