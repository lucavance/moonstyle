///|
fn compiled_strings(entries : Array[(String, String)]) -> CompiledStyle {
  compiled(entries)
}

///|
test "props applies the last class for each compiled property" {
  let base = compiled_strings([
    ("color", "red-class"),
    ("display", "grid-class"),
  ])
  let override_ = compiled_strings([("color", "green-class")])
  let applied = props([base, override_])
  assert_eq(applied.class_name, "green-class grid-class")
}

///|
test "dynamic variables merge from left to right" {
  let first = compiled([], inline_vars=[("--progress", "37%")])
  let second = compiled([], inline_vars=[("--progress", "76%")])
  assert_true(
    props([none, first, second]).inline_vars == [("--progress", "76%")],
  )
}

///|
test "conditional compiled styles compose without branching arrays" {
  let active = compiled_strings([("color", "active-class")])
  assert_eq(props([active.when(true)]).class_name, "active-class")
  assert_eq(props([active.when(false)]).class_name, "")
}

///|
test "dynamic value errors preserve variable context" {
  let error = dynamic_value_error(
    "--demo-progress", "STYLE_VALUE_NON_FINITE", "length",
  )
  assert_eq(error.variable, "--demo-progress")
  assert_eq(error.code, "STYLE_VALUE_NON_FINITE")
  assert_eq(error.label, "length")
}

///|
test "checked styles aggregate errors in input order" {
  let first = dynamic_value_error("--first", "STYLE_FIRST", "length")
  let second = dynamic_value_error("--second", "STYLE_SECOND", "color")
  match
    props_checked([
      Err([first]),
      Ok(compiled_strings([("color", "ignored-class")])),
      Err([second]),
    ]) {
    Ok(_) => fail("invalid checked styles must not produce partial output")
    Err(errors) => assert_eq(errors, [first, second])
  }
}

///|
test "checked styles preserve base and checked application order" {
  let base = compiled_strings([
    ("color", "base-color"),
    ("display", "base-display"),
  ])
  let dynamic = compiled_strings([("color", "dynamic-color")])
  let final_override = compiled_strings([("display", "final-display")])
  match props_checked([Ok(dynamic), Ok(final_override)], base_styles=[base]) {
    Ok(applied) => assert_eq(applied.class_name, "dynamic-color final-display")
    Err(_) => fail("valid checked styles must compose")
  }
}

///|
test "checked styles merge inline variables after base styles" {
  let base = compiled([], inline_vars=[("--progress", "25%")])
  let dynamic = compiled([], inline_vars=[("--progress", "75%")])
  match props_checked([Ok(dynamic)], base_styles=[base]) {
    Ok(applied) => assert_true(applied.inline_vars == [("--progress", "75%")])
    Err(_) => fail("valid checked variables must compose")
  }
}

///|
test "checked conditions suppress disabled results" {
  let error = dynamic_value_error("--progress", "STYLE_INVALID", "length")
  match props_checked([checked_when(Err([error]), false)]) {
    Ok(applied) => assert_eq(applied.class_name, "")
    Err(_) => fail("disabled checked styles must not report errors")
  }
  match checked_when(Err([error]), true) {
    Ok(_) => fail("enabled checked styles must preserve errors")
    Err(errors) => assert_eq(errors, [error])
  }
}

///|
test "style lists preserve mixed input order" {
  let base = compiled_strings([
    ("color", "base-color"),
    ("display", "base-display"),
  ])
  let dynamic : StyleResult = Ok(compiled_strings([("color", "dynamic-color")]))
  let final_override = compiled_strings([("display", "final-display")])
  match compose(base).add(dynamic).add(final_override).resolve() {
    Ok(applied) => assert_eq(applied.class_name, "dynamic-color final-display")
    Err(_) => fail("valid mixed inputs must compose")
  }
}

///|
test "style lists flatten arrays options and nested lists" {
  let optional : CompiledStyle? = Some(
    compiled_strings([("display", "optional-display")]),
  )
  let absent : CompiledStyle? = None
  let nested = compose(compiled_strings([("color", "nested-color")])).add([
    compiled_strings([("margin", "nested-margin")]),
  ])
  match
    style_list()
    .add([[compiled_strings([("display", "first-display")])]])
    .add(optional)
    .add(absent)
    .add(nested)
    .resolve() {
    Ok(applied) =>
      assert_eq(
        applied.class_name,
        "optional-display nested-color nested-margin",
      )
    Err(_) => fail("supported recursive inputs must compose")
  }
}

///|
test "style list conditions omit disabled values and errors" {
  let disabled_error : StyleResult = Err([
    dynamic_value_error("--disabled", "STYLE_DISABLED", "length"),
  ])
  let enabled = compiled_strings([("color", "enabled-color")])
  match
    style_list()
    .when(false, disabled_error)
    .when(false, compiled_strings([("display", "disabled-display")]))
    .when(true, enabled)
    .resolve() {
    Ok(applied) => assert_eq(applied.class_name, "enabled-color")
    Err(_) => fail("disabled checked inputs must not report errors")
  }
}

///|
test "style lists aggregate nested errors in source order" {
  let first = dynamic_value_error("--first", "STYLE_FIRST", "length")
  let second = dynamic_value_error("--second", "STYLE_SECOND", "color")
  let third = dynamic_value_error("--third", "STYLE_THIRD", "number")
  let first_result : StyleResult = Err([first])
  let second_result : StyleResult = Err([second])
  let third_result : StyleResult = Err([third])
  let valid_result : StyleResult = Ok(compiled_strings([("color", "ignored")]))
  let nested = style_list().add(second_result).add(valid_result)
  match
    compose(compiled_strings([("display", "ignored-base")]))
    .add(first_result)
    .add(nested)
    .add([third_result])
    .resolve() {
    Ok(_) => fail("invalid nested inputs must not return partial output")
    Err(errors) => assert_eq(errors, [first, second, third])
  }
}

///|
test "style lists are immutable and reusable" {
  let base = compose(compiled_strings([("color", "base-color")]))
  let derived = base.add(compiled_strings([("color", "derived-color")]))
  match base.resolve() {
    Ok(applied) => assert_eq(applied.class_name, "base-color")
    Err(_) => fail("base list must remain valid")
  }
  match derived.resolve() {
    Ok(applied) => assert_eq(applied.class_name, "derived-color")
    Err(_) => fail("derived list must remain valid")
  }
}

///|
test "style lists preserve inline variable order" {
  let first = compiled([], inline_vars=[("--progress", "25%")])
  let second : StyleResult = Ok(
    compiled([], inline_vars=[("--progress", "75%")]),
  )
  match compose(first).add(second).resolve() {
    Ok(applied) => assert_true(applied.inline_vars == [("--progress", "75%")])
    Err(_) => fail("valid inline variables must compose")
  }
}

///|
test "expect_dynamic returns successful values" {
  assert_eq(expect_dynamic(Ok(42)), 42)
}

///|
test "panic expect_dynamic reports invalid values" {
  let error = dynamic_value_error("--progress", "STYLE_INVALID", "length")
  let _ : Int32 = expect_dynamic(Err([error]))
}

///|
test "length variable bindings preserve zero dimensions without changing percentages" {
  let length = @values.length_var("zero", "length", @values.px(0))
  assert_eq(bind_length(length, @values.px(0)), ("--zero-length", "0px"))
  assert_eq(bind_length(length, @values.percent(0)), ("--zero-length", "0%"))
  assert_eq(bind_length(length, @values.px(-2)), ("--zero-length", "-2px"))
}

///|
test "typed dynamic bindings preserve categories and later values" {
  let progress = @values.length_var("demo", "progress", @values.percent(0)) catch {
    _ => abort("test variable is valid")
  }
  let first = bind_length(progress, @values.percent(25))
  let second = bind_length(progress, @values.percent(75))
  assert_true(
    props([
      compiled_v3([], inline_vars=[first]),
      compiled_v3([], inline_vars=[second]),
    ]).inline_vars ==
    [("--demo-progress", "75%")],
  )
}

///|
test "compiled_v5 preserves nullable application-order entries" {
  let shorthand = compiled_v5([
    ("shorthand", Some("shorthand-class")),
    ("longhand", None),
  ])
  let longhand = compiled_v5([("longhand", Some("longhand-class"))])
  assert_eq(props([longhand, shorthand]).class_name, "shorthand-class")
  assert_eq(
    props([shorthand, longhand]).class_name,
    "shorthand-class longhand-class",
  )
}

///|
// StyleX #1731/#1820: optional inputs and clear entries must not stringify
// nulls, and markers must remain usable across generic StyleInput boundaries.
test "optional checked styles and markers distinguish absence from explicit clear" {
  let base = compiled_v5([("color", Some("base-color"))])
  let absent : StyleResult? = None
  let clear : StyleResult? = Some(Ok(compiled_v5([("color", None)])))
  let marker = selector_marker("upstream/runtime", "group", "group-marker")
  let marked = compose(base).add(marker).add(absent)
  match marked.resolve() {
    Ok(applied) => assert_eq(applied.class_name, "base-color group-marker")
    Err(_) => fail("absent checked styles must preserve the base")
  }
  match marked.add(clear).resolve() {
    Ok(applied) => assert_eq(applied.class_name, "group-marker")
    Err(_) => fail("explicit clear must remove only its conflict slot")
  }
  assert_eq(props([marker]).class_name, "group-marker")
}

///|
test "explicit clear styles compose conditionally in application order" {
  let base = compiled_v5([("color", Some("base-color"))])
  let clear = compiled_v5([("color", None)])
  match compose(base).when(true, clear).resolve() {
    Ok(applied) => assert_eq(applied.class_name, "")
    Err(_) => fail("static clear composition must not fail")
  }
  match compose(base).when(false, clear).resolve() {
    Ok(applied) => assert_eq(applied.class_name, "base-color")
    Err(_) => fail("disabled clear composition must not fail")
  }
  assert_eq(props([clear, base]).class_name, "base-color")
}

///|
test "compiled_v5 flattens and deduplicates condition class tokens" {
  let conditional = compiled_v5([("color", Some("base-color hover-color"))])
  let repeated = compiled_v5([("other", Some("hover-color"))])
  assert_eq(props([conditional, repeated]).class_name, "base-color hover-color")
}

///|
test "a later base declaration replaces earlier conditional variants" {
  let interactive = compiled_strings([
    ("backgroundColor", "base-class"),
    ("backgroundColor|pseudo::hover", "hover-class"),
  ])
  let active = compiled_strings([("backgroundColor", "active-class")])
  assert_eq(props([interactive]).class_name, "base-class hover-class")
  assert_eq(props([interactive, active]).class_name, "active-class")
}

///|
test "shorthand slots compose with longhands in both application orders" {
  let margin = compiled_strings([
    ("marginTop", "margin-top-8"),
    ("marginRight", "margin-right-8"),
    ("marginBottom", "margin-bottom-8"),
    ("marginLeft", "margin-left-8"),
  ])
  let top = compiled_strings([("marginTop", "margin-top-16")])
  assert_eq(
    props([margin, top]).class_name,
    "margin-top-16 margin-right-8 margin-bottom-8 margin-left-8",
  )
  assert_eq(
    props([top, margin]).class_name,
    "margin-top-8 margin-right-8 margin-bottom-8 margin-left-8",
  )
}

///|
test "a later base shorthand clears conditional variants for every slot" {
  let conditional = compiled_strings([
    ("marginTop|pseudo::hover", "hover-top"),
    ("marginRight|pseudo::hover", "hover-right"),
    ("marginBottom|pseudo::hover", "hover-bottom"),
    ("marginLeft|pseudo::hover", "hover-left"),
  ])
  let base = compiled_strings([
    ("marginTop", "base-top"),
    ("marginRight", "base-right"),
    ("marginBottom", "base-bottom"),
    ("marginLeft", "base-left"),
  ])
  assert_eq(
    props([conditional, base]).class_name,
    "base-top base-right base-bottom base-left",
  )
}

///|
test "directional tombstones compose logical and physical styles in both orders" {
  let logical = compiled_v2([
    ("marginInlineStart", Some("logical-start")),
    ("marginLeft", None),
    ("marginRight", None),
  ])
  let physical = compiled_v2([
    ("marginLeft", Some("physical-left")),
    ("marginInlineStart", None),
    ("marginInlineEnd", None),
  ])
  assert_eq(props([logical, physical]).class_name, "physical-left")
  assert_eq(props([physical, logical]).class_name, "logical-start")
}

///|
test "directional tombstones preserve both sides in the same coordinate system" {
  let physical = compiled_v2([
    ("paddingLeft", Some("physical-left")),
    ("paddingInlineStart", None),
    ("paddingInlineEnd", None),
    ("paddingRight", Some("physical-right")),
    ("paddingInlineStart", None),
    ("paddingInlineEnd", None),
  ])
  let logical = compiled_v2([
    ("paddingInlineStart", Some("logical-start")),
    ("paddingLeft", None),
    ("paddingRight", None),
    ("paddingInlineEnd", Some("logical-end")),
    ("paddingLeft", None),
    ("paddingRight", None),
  ])
  assert_eq(props([physical]).class_name, "physical-left physical-right")
  assert_eq(props([logical]).class_name, "logical-start logical-end")
}
