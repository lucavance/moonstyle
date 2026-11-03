///|
fn container_style_css(condition : @ir.ContainerStyleCondition) -> String {
  match condition {
    StyleEquals(variable, value) =>
      variable.definition.name +
      ":" +
      variable_value_css(variable.definition.category, value)
    StyleNot(child) => "not (" + container_style_css(child) + ")"
    StyleAll(children) =>
      children
      .map(child => "(" + container_style_css(child) + ")")
      .join(" and ")
    StyleAny(children) =>
      children.map(child => "(" + container_style_css(child) + ")").join(" or ")
  }
}

///|
fn invalid_container_style_condition(
  condition : @ir.ContainerStyleCondition,
) -> Bool {
  match condition {
    StyleEquals(variable, value) => {
      let property = variable.definition.name
      !property.has_prefix("--") ||
      property.length() <= 2 ||
      !valid_kebab_name(property[2:].to_owned()) ||
      invalid_condition_text(value) ||
      !@values.value_issues(value).is_empty()
    }
    StyleNot(child) => invalid_container_style_condition(child)
    StyleAll(children) | StyleAny(children) =>
      children.is_empty() || children.any(invalid_container_style_condition)
  }
}
