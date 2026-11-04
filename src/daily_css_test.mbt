///|
test "daily CSS properties preserve typed values fallback order frames and contracts" {
  let align = @moonstyle.vertical_align_offset(
    @moonstyle.length_percentage_from_length(@moonstyle.px(-2)),
  )
  let hints = @moonstyle.will_change([ChangeTransform, ChangeOpacity])
  let axes = @moonstyle.font_variations([
    @moonstyle.font_axis("wght", 650.0),
    @moonstyle.font_axis("wdth", 95.5),
  ])
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "daily/values",
      [
        @moonstyle.rule("label")
        .isolation(@moonstyle.Isolation::IsolationIsolate)
        .white_space(@moonstyle.WhiteSpace::WhiteSpacePreWrap)
        .text_wrap(@moonstyle.TextWrap::TextWrapBalance)
        .vertical_align(align)
        .will_change(hints)
        .font_variation_settings(axes),
        @moonstyle.rule("fallback").text_wrap_fallbacks(
          @moonstyle.TextWrapFallbacks::new()
          .add(@moonstyle.TextWrap::TextWrapWrap)
          .add(@moonstyle.TextWrap::TextWrapPretty),
        ),
        @moonstyle.rule("animate").animation_name(
          @moonstyle.keyframes("font", [
            @moonstyle.frame(From).font_variation_settings(
              @moonstyle.normal_font_variations(),
            ),
            @moonstyle.frame(To).font_variation_settings(axes),
          ]),
        ),
        @moonstyle.rule("clear")
        .clear_isolation()
        .clear_white_space()
        .clear_text_wrap()
        .clear_vertical_align()
        .clear_will_change()
        .clear_font_variation_settings(),
      ],
      contracts=[
        @moonstyle.style_contract("label")
        .allow_isolation(values=[IsolationIsolate])
        .allow_white_space(values=[WhiteSpacePreWrap])
        .allow_text_wrap(values=[TextWrapBalance])
        .allow_vertical_align(values=[align])
        .allow_will_change(values=[hints])
        .allow_font_variation_settings(values=[axes]),
      ],
    ),
  )
  assert_eq(output.diagnostics, [])
  for
    css in [
      "isolation:isolate", "white-space:pre-wrap", "text-wrap:balance", "vertical-align:-2px",
      "will-change:transform,opacity", "font-variation-settings:\"wght\" 650,\"wdth\" 95.5",
      "text-wrap:wrap;text-wrap:pretty", "from{font-variation-settings:normal}",
    ] {
    assert_true(output.css.contains(css), msg=output.css)
  }
  assert_true(output.mappings.contains("LabelStyleInput for LabelStyle"))
  assert_false(output.mappings.contains("LabelStyleInput for FallbackStyle"))
  match @extract.decode_bundle(output.manifest) {
    Ok(bundle) => assert_eq(@extract.validate_bundle(bundle), [])
    Err(errors) => fail(@extract.render_diagnostics_text(errors))
  }
}

///|
test "daily structured values reject empty lists invalid tags and nonfinite axes" {
  let output = @extract.compile_registry(
    @moonstyle.registry("daily/invalid", [
      @moonstyle.rule("emptyHints").will_change(@moonstyle.will_change([])),
      @moonstyle.rule("emptyAxes").font_variation_settings(
        @moonstyle.font_variations([]),
      ),
      @moonstyle.rule("badTag").font_variation_settings(
        @moonstyle.font_variations([@moonstyle.font_axis("abc", 1.0)]),
      ),
      @moonstyle.rule("badNumber").font_variation_settings(
        @moonstyle.font_variations([@moonstyle.font_axis("wght", 1.0 / 0.0)]),
      ),
    ]),
  )
  for
    code in [
      "STYLE_WILL_CHANGE", "STYLE_FONT_VARIATIONS", "STYLE_FONT_AXIS", "STYLE_VALUE_NON_FINITE",
    ] {
    assert_true(
      output.diagnostics.any(item => item.code == code),
      msg=output.manifest,
    )
  }
  assert_false(output.css.contains("will-change:"))
  assert_false(output.css.contains("font-variation-settings:"))
}

///|
test "font axes preserve case order and escape printable tags" {
  let axes = @moonstyle.font_variations([
    @moonstyle.font_axis("wght", 1.0),
    @moonstyle.font_axis("WGHT", 2.0),
    @moonstyle.font_axis("A\"\\B", 3.0),
  ])
  assert_eq(axes.to_css(), "\"wght\" 1, \"WGHT\" 2, \"A\\\"\\\\B\" 3")
  for tag in ["a\ncd", "汉abc", "abcde", ""] {
    let output = @extract.compile_registry(
      @moonstyle.registry("daily/tags", [
        @moonstyle.rule("invalid").font_variation_settings(
          @moonstyle.font_variations([@moonstyle.font_axis(tag, 1.0)]),
        ),
      ]),
    )
    assert_true(output.diagnostics.any(item => item.code == "STYLE_FONT_AXIS"))
  }
}
