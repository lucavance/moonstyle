///|
test "generated URL bindings retain resource identity and reject invalid input" {
  let resource = @moonstyle.url("/v0.5/picture.svg?scale=0.5#v0.5")
  match @moonstyle.compose(upstreamDynamicResource(resource)).resolve() {
    Ok(applied) =>
      assert_eq(applied.inline_vars, [("--demo-resource", resource.to_css())])
    Err(_) => fail("valid resource URL must resolve")
  }
  match upstreamDynamicResource(@moonstyle.url("")) {
    Ok(_) => fail("invalid resource URL must not produce partial bindings")
    Err(errors) => {
      assert_eq(errors.length(), 1)
      assert_eq(errors[0].variable, "--demo-resource")
    }
  }
}

///|
test "generated length accessors retain dimensions for zero math operands" {
  match
    @moonstyle.compose(expressionPanel(@moonstyle.px(0), @moonstyle.deg(0.0))).resolve() {
    Err(_) => fail("zero length is a valid dynamic math operand")
    Ok(applied) =>
      assert_eq(applied.inline_vars, [
        ("--demo-expression-offset", "0px"),
        ("--demo-expression-angle", "0deg"),
      ])
  }
  match
    @moonstyle.compose(expressionGrid(@moonstyle.px(0).as_length_percentage())).resolve() {
    Err(_) => fail("length-percentage zero must remain dimensional")
    Ok(applied) =>
      assert_eq(applied.inline_vars, [("--demo-expression-track", "0px")])
  }
  match
    @moonstyle.compose(
      expressionGrid(@moonstyle.percentage(0.0).as_length_percentage()),
    ).resolve() {
    Err(_) => fail("percentage zero must retain its original unit")
    Ok(applied) =>
      assert_eq(applied.inline_vars, [("--demo-expression-track", "0%")])
  }
}

///|
test "nested expression accessors validate once and never return partial bindings" {
  match expressionPanel(@moonstyle.auto(), @moonstyle.deg(0.0 / 0.0)) {
    Ok(_) => fail("invalid operands must not return classes or variables")
    Err(errors) => {
      assert_eq(errors.length(), 2)
      assert_eq(errors.map(error => error.variable), [
        "--demo-expression-offset", "--demo-expression-angle",
      ])
    }
  }
  match expressionLimits(@moonstyle.percentage(-20.0)) {
    Ok(_) =>
      fail("font-width constraints must survive the permissive height use")
    Err(errors) => assert_eq(errors.length(), 1)
  }
  match expressionGrid(@moonstyle.px(-10).as_length_percentage()) {
    Ok(_) => fail("track sizes must reject negative runtime values")
    Err(errors) => assert_eq(errors.length(), 1)
  }
  match
    @moonstyle.compose(expressionPanel(@moonstyle.px(20), @moonstyle.deg(90.0))).resolve() {
    Err(_) => fail("valid nested inputs must resolve")
    Ok(applied) =>
      assert_eq(applied.inline_vars, [
        ("--demo-expression-offset", "20px"),
        ("--demo-expression-angle", "90deg"),
      ])
  }
}

///|
test "generated font width accessors enforce the percentage range" {
  for value in [-1.0, 0.0 / 0.0, 1.0 / 0.0] {
    match fontWidthDynamic(@moonstyle.percentage(value)) {
      Ok(_) => fail("invalid font width must not produce a mapping")
      Err(errors) => {
        assert_eq(errors.length(), 1)
        assert_eq(errors[0].variable, "--demo-font-width")
      }
    }
  }
  for value in [0.0, 75.0, 100.0, 200.0] {
    match
      @moonstyle.compose(fontWidthDynamic(@moonstyle.percentage(value))).resolve() {
      Err(_) => fail("valid font width must produce a mapping")
      Ok(applied) => assert_false(applied.class_name.is_empty())
    }
  }
}

///|
test "generated dynamic accessors aggregate at one checked boundary" {
  let invalid_length = @moonstyle.length(0.0 / 0.0, Px)
  let invalid_color = @moonstyle.rgb(999, 0, 0)
  match
    @moonstyle.compose(card)
    .add(meter(invalid_length))
    .add([multiDynamic(invalid_length, invalid_color, invalid_color)])
    .resolve() {
    Ok(_) => fail("invalid generated accessors must not compose")
    Err(errors) => {
      assert_eq(errors.length(), 4)
      assert_eq(errors.map(error => error.variable), [
        "--demo-progress", "--demo-progress", "--demo-dynamic-surface", "--demo-dynamic-text",
      ])
    }
  }
}

///|
test "dependency contracts accept eligible static and checked dynamic mappings" {
  let invalid_color = @moonstyle.rgb(999, 0, 0)
  match
    @contract_0.button_styles(@contract_0.badge)
    .add(active)
    .add(buttonTone(invalid_color))
    .resolve() {
    Ok(_) => fail("invalid contract input must not produce partial attributes")
    Err(errors) => {
      assert_eq(errors.length(), 1)
      assert_eq(errors[0].variable, "--component-button-text")
    }
  }
}

///|
test "generated recipes and selector markers compose through the ordinary runtime" {
  match
    @moonstyle.style_list()
    .add(demo_group_marker)
    .add(badge_recipe(size=BadgeRecipeSizeRoomy, muted=true))
    .add(markerChild)
    .resolve() {
    Err(_) => fail("static generated surfaces must resolve without errors")
    Ok(applied) => {
      assert_true(applied.class_name.contains(demo_group_marker.class_name()))
      assert_true(applied.class_name.split(" ").count() >= 7)
      assert_eq(applied.inline_vars, [])
    }
  }
}
