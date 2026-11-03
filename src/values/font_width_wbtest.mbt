///|
test "font-width accepts finite nonnegative percentages without narrowing Percentage" {
  for css in ["0%", "75%", "100%", "250%", "-0%", "normal", "var(--font-width)"] {
    assert_true(property_value_issues("fontWidth", css).is_empty())
  }
  let negative = percentage(-25.0)
  assert_eq(negative.to_css(), "-25%")
  assert_true(value_issues(negative.to_css()).is_empty())
  assert_true(property_value_issues("marginLeft", negative.to_css()).is_empty())
  for property in ["fontWidth", "font-width"] {
    let issues = property_value_issues(property, negative.to_css())
    assert_eq(issues.length(), 1)
    assert_eq(issues[0].code, "STYLE_VALUE_OUT_OF_RANGE")
  }
}

///|
test "font-width rejects nonfinite authored percentages and invalid numeric CSS" {
  for number in [0.0 / 0.0, 1.0 / 0.0, -1.0 / 0.0] {
    let issues = property_value_issues(
      "fontWidth",
      authored_percentage(number).to_css(),
    )
    assert_eq(issues.length(), 1)
    assert_eq(issues[0].code, "STYLE_VALUE_NON_FINITE")
  }
  for css in ["NaN%", "Infinity%", "-Infinity%", "1e999%", "invalid%"] {
    assert_false(property_value_issues("fontWidth", css).is_empty())
  }
}
