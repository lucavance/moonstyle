///|
fn property_global(definition : @values.VarDefinition) -> GlobalRule {
  let syntax = match definition.category {
    ColorCategory => "<color>"
    LengthCategory => "<length>"
    NumberCategory => "<number>"
    _ => ""
  }
  let registration = definition.registration.unwrap()
  let css = "@property " +
    definition.name +
    "{syntax:\"" +
    syntax +
    "\";inherits:" +
    registration.inherits.to_string() +
    ";initial-value:" +
    variable_value_css(definition.category, definition.default_css) +
    "}"
  { kind: "property", name: definition.name, css, digest: sha256_digest(css), }
}

///|
/// The artifact stores canonical CSS rather than a second registration model.
/// Reconstruct it to reject unsupported syntax, descriptors and initial values.
pub fn valid_property_global(name : String, css : String) -> Bool {
  if !name.has_prefix("--") ||
    !valid_kebab_name(name[2:].to_owned()) ||
    !css.has_suffix("}") {
    return false
  }
  for
    (syntax, category) in [
      ("<color>", @values.ColorCategory),
      ("<length>", @values.LengthCategory),
      ("<number>", @values.NumberCategory),
    ] {
    for inherits in [false, true] {
      let prefix = "@property " +
        name +
        "{syntax:\"" +
        syntax +
        "\";inherits:" +
        inherits.to_string() +
        ";initial-value:"
      if css.has_prefix(prefix) {
        let definition : @values.VarDefinition = {
          name,
          category,
          registration: Some({ inherits, }),
          default_css: css[prefix.length():css.length() - 1].to_owned(),
        }
        return definition.registration_issue() is None &&
          property_global(definition).css == css
      }
    }
  }
  false
}
