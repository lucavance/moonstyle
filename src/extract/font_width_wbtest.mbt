///|
fn font_width_variable_registry(
  property : String,
  default_css : String,
  override_css : String,
  keyframe~ : Bool = false,
) -> @ir.Registry {
  let variables = @ir.define_vars("fonts", [
    @values.VarDefinition::{
      name: "--fonts-width",
      default_css,
      category: PercentageCategory,
      registration: None,
    },
  ])
  let value = @ir.declaration(
    property,
    @ir.text("var(--fonts-width)"),
    keyframe_allowed=true,
    value_origin=Some(
      @ir.TokenOrigin(@ir.contract_variable("--fonts-width", "percentage")),
    ),
  )
  let declaration = if keyframe {
    @ir.declaration(
      "animationName",
      @ir.animation(@ir.keyframes("width", [@ir.keyframe_frame(From, [value])])),
    )
  } else {
    value
  }
  @ir.registry(
    "fixture/fonts",
    [@ir.style_set("styles", [@ir.style_namespace("label", [declaration])])],
    variable_sets=[variables],
    themes=[
      @ir.create_theme("narrow", variables, [
        @values.VarOverride::{
          name: "--fonts-width",
          value_css: override_css,
          category: PercentageCategory,
        },
      ]),
    ],
  )
}

///|
test "font-width registry checks defaults and theme overrides only for referenced properties" {
  for keyframe in [false, true] {
    let default_bundle = compile_registry(
      font_width_variable_registry("fontWidth", "-5%", "75%", keyframe~),
    )
    assert_eq(default_bundle.diagnostics[0].code, "STYLE_VALUE_OUT_OF_RANGE")
    let theme_bundle = compile_registry(
      font_width_variable_registry("fontWidth", "100%", "-25%", keyframe~),
    )
    assert_eq(theme_bundle.diagnostics[0].code, "STYLE_VALUE_OUT_OF_RANGE")
    assert_true(theme_bundle.diagnostics[0].message.contains("theme narrow"))
    let valid = compile_registry(
      font_width_variable_registry("fontWidth", "0%", "150%", keyframe~),
    )
    assert_true(valid.diagnostics.is_empty())
  }
  let unrelated = compile_registry(
    font_width_variable_registry("marginLeft", "-5%", "-25%"),
  )
  assert_true(unrelated.diagnostics.is_empty())
}

///|
test "font-width dynamic constraints survive shared slot parameter deduplication" {
  for properties in [["marginLeft", "fontWidth"], ["fontWidth", "marginLeft"]] {
    let declarations = properties.map(property => {
      @ir.declaration(
        property,
        @ir.dynamic("--fonts-width", "", category="percentage"),
      )
    })
    let bundle = compile_registry(
      @ir.registry("fixture/fonts", [
        @ir.style_set("styles", [@ir.style_namespace("shared", declarations)]),
      ]),
    )
    assert_true(bundle.diagnostics.is_empty())
    assert_eq(
      bundle.mappings.split("fonts_width : @values.Percentage").count(),
      2,
    )
    assert_eq(
      bundle.mappings
      .split(
        "@values.property_value_issues(\"fontWidth\", lampclaw_css_fonts_width)",
      )
      .count(),
      2,
    )
  }
}

///|
test "font-width exact contracts reject negative percentage literals" {
  let bundle = compile_registry(
    @ir.registry("fixture/fonts", [], contracts=[
      @ir.style_contract("label", [
        @ir.exact_contract_property("fontWidth", values=["-25%"]),
      ]),
    ]),
  )
  assert_eq(bundle.diagnostics[0].code, "STYLE_CONTRACT_VALUE_INVALID")
}
