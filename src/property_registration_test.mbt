///|
test "property registration is explicit ordered and survives themes and artifacts" {
  let scope = @moonstyle.variable_scope("motion")
  let ordinary = scope.length_token("ordinary", @moonstyle.rem(1.0))
  let length = scope
    .length_token("distance", @moonstyle.px(0))
    .registered(inherits=false)
  let color = scope
    .color_token("ink", @moonstyle.named_color("red"))
    .registered()
  let number = scope
    .number_slot("progress", @moonstyle.number(0.0))
    .registered(inherits=false)
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "registration/valid",
      [
        @moonstyle.rule("box")
        .width(length)
        .height(ordinary)
        .color(color)
        .font_size_adjust(number),
      ],
      themes=[
        @moonstyle.theme("dark", [
          color.with_value(@moonstyle.named_color("white")),
        ]),
      ],
    ),
  )
  assert_eq(output.diagnostics, [])
  for
    expected in [
      "@property --motion-distance{syntax:\"<length>\";inherits:false;initial-value:0px}",
      "@property --motion-ink{syntax:\"<color>\";inherits:true;initial-value:red}",
      "@property --motion-progress{syntax:\"<number>\";inherits:false;initial-value:0}",
      "--motion-ordinary:1rem", "--motion-ink:white",
    ] {
    assert_true(output.css.contains(expected), msg=output.css)
  }
  assert_false(output.css.contains("@property --motion-ordinary"))
  assert_true(output.css.split("\n").to_array()[1].has_prefix("@property "))
  match @extract.decode_bundle(output.manifest) {
    Ok(bundle) => {
      assert_eq(@extract.validate_bundle(bundle), [])
      assert_eq(output.css.split("@property ").count(), 4)
    }
    Err(errors) => fail(@extract.render_diagnostics_text(errors))
  }
}

///|
test "property registration rejects dependent initial values and conflicting definitions" {
  let scope = @moonstyle.variable_scope("registration")
  let relative = scope
    .length_token("relative", @moonstyle.rem(1.0))
    .registered()
  let viewport = scope
    .length_token("viewport", @moonstyle.length(1.0, Vw))
    .registered()
  let contextual = scope
    .color_token("context", @moonstyle.named_color("currentColor"))
    .registered()
  for
    rule in [
      @moonstyle.rule("relative").width(relative),
      @moonstyle.rule("viewport").width(viewport),
      @moonstyle.rule("contextual").color(contextual),
    ] {
    let output = @extract.compile_registry(
      @moonstyle.registry("registration/invalid", [rule]),
    )
    assert_true(
      output.diagnostics.any(item => item.code == "STYLE_PROPERTY_INITIAL_VALUE"),
    )
    assert_false(output.css.contains("@property "))
  }
  let original = scope.length_token("duplicate", @moonstyle.px(1))
  let output = @extract.compile_registry(
    @moonstyle.registry("registration/conflict", [
      @moonstyle.rule("a").width(original.registered()),
      @moonstyle.rule("b").width(original.registered(inherits=false)),
    ]),
  )
  assert_false(output.diagnostics.is_empty())
}
