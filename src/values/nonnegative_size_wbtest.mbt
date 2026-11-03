///|
test "size ranges do not narrow the shared length category" {
  for property in ["width", "fontSize", "font-size"] {
    assert_true(property_value_issues(property, "0").is_empty())
    assert_true(property_value_issues(property, "16px").is_empty())
    assert_eq(
      property_value_issues(property, "-1px")[0].code,
      "STYLE_VALUE_OUT_OF_RANGE",
    )
  }
  assert_true(property_value_issues("marginLeft", "-16px").is_empty())
  assert_true(property_value_issues("width", "calc(100% - 16px)").is_empty())
}
