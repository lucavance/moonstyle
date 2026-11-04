///|
test "registered color defaults accept reviewed literal constructors and reject context" {
  let colors = [
    named_color("rebeccapurple"),
    transparent(),
    hex_color("#1234"),
    rgb(1, 2, 3),
    rgba(1, 2, 3, 0.5),
    hsl(120.0, 50.0, 25.0),
    hwb(deg(120.0), percentage(10.0), percentage(20.0)),
    lab(50.0, 10.0, 20.0),
    lch(50.0, 20.0, deg(30.0)),
    oklab(0.5, 0.1, 0.2),
    oklch(0.5, 0.2, deg(30.0)),
    color_space(DisplayP3, 0.1, 0.2, 0.3),
  ]
  for color in colors {
    let token = color_token("color", "test", color).registered()
    assert_eq(token.definition().registration_issue(), None, msg=color.to_css())
  }
  for
    css in [
      "currentcolor", "canvas", "#xyz", "rgb(from red r g b)", "rgb(var(--r) 0 0)",
      "red}body{color:red", "rgb(1 2)", "rgb(1,,2,3)", "hsl(1 2 3)", "rgb(1_0 2 3)",
      "hsl(5% 2% 3%)",
    ] {
    let definition : VarDefinition = {
      name: "--color-test",
      default_css: css,
      category: ColorCategory,
      registration: Some({ inherits: true, }),
    }
    assert_true(definition.registration_issue() is Some(_), msg=css)
  }
}

///|
test "registration accepts finite CSS numeric tokens without language-specific notation" {
  for css in ["1_0", "0x10", "NaN", "Infinity", "1;inherits:true", "1e999"] {
    let definition : VarDefinition = {
      name: "--number-test",
      default_css: css,
      category: NumberCategory,
      registration: Some({ inherits: true, }),
    }
    assert_true(definition.registration_issue() is Some(_), msg=css)
  }
  for css in ["0", "-2", ".5", "1e2", "2.5e-2"] {
    let definition : VarDefinition = {
      name: "--number-test",
      default_css: css,
      category: NumberCategory,
      registration: Some({ inherits: true, }),
    }
    assert_eq(definition.registration_issue(), None, msg=css)
  }
}
