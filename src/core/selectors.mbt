///|
fn anb_css(a : Int32, b : Int32) -> String {
  if a == 0 {
    return b.to_string()
  }
  let coefficient = if a == 1 {
    ""
  } else if a == -1 {
    "-"
  } else {
    a.to_string()
  }
  coefficient +
  "n" +
  (if b > 0 { "+" + b.to_string() } else if b < 0 { b.to_string() } else { "" })
}

///|
fn attribute_selector_css(value : @ir.AttributeSelector) -> String {
  let operator = match value.operator {
    Present => return "[" + value.name + "]"
    Equals => "="
    IncludesWord => "~="
    DashPrefix => "|="
    Prefix => "^="
    Suffix => "$="
    Substring => "*="
  }
  let flag = match value.case_mode {
    DefaultCase => ""
    Insensitive => " i"
    Sensitive => " s"
  }
  let escaped = value.value
    .replace_all(old="\\", new="\\\\")
    .replace_all(old="\"", new="\\\"")
  "[" + value.name + operator + "\"" + escaped + "\"" + flag + "]"
}

///|
fn invalid_attribute_selector(value : @ir.AttributeSelector) -> Bool {
  !valid_kebab_name(value.name) ||
  value.name != value.name.trim().to_owned() ||
  value.value.contains("\n") ||
  value.value.contains("\r") ||
  value.value.contains("\u0000") ||
  (
    value.operator == @ir.Present &&
    (value.value != "" || value.case_mode != @ir.DefaultCase)
  )
}

///|
fn invalid_selector_state(state : @ir.SelectorState) -> Bool {
  match state {
    SelectorPseudo(value) => invalid_pseudo_class(value)
    SelectorAttribute(name) => !valid_kebab_name(name)
    SelectorAttributeEquals(name, value) =>
      !valid_kebab_name(name) ||
      invalid_condition_text(value) ||
      value.contains("'") ||
      value.contains("\\")
    SelectorAttributeMatch(value) => invalid_attribute_selector(value)
  }
}

///|
fn invalid_pseudo_class(value : @ir.PseudoClass) -> Bool {
  match value {
    Is(states) | Not(states) | Where(states) =>
      states.is_empty() || states.any(invalid_selector_state)
    MatchAttribute(value) => invalid_attribute_selector(value)
    _ => false
  }
}
