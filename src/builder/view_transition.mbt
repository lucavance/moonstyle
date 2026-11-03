///|
pub struct ViewTransitionClassDefinition {
  name : String
  styles : Array[(String, Rule)]
}

///|
/// Define optional styles for the four view-transition pseudo-elements.
///
/// ```mbt check
/// test {
///   let transition = @builder.define_view_transition_class("card")
///     .old(@builder.rule("outgoing").opacity(0.5))
///     .new(@builder.rule("incoming").opacity(1.0))
///   assert_eq(transition.to_ir().styles.length(), 2)
/// }
/// ```
pub fn define_view_transition_class(
  name : String,
) -> ViewTransitionClassDefinition {
  { name, styles: [], }
}

///|
fn ViewTransitionClassDefinition::with_style(
  self : ViewTransitionClassDefinition,
  group : String,
  rule : Rule,
) -> ViewTransitionClassDefinition {
  let styles = self.styles.filter(style => style.0 != group)
  styles.push((group, rule))
  { ..self, styles, }
}

///|
pub fn ViewTransitionClassDefinition::group(
  self : ViewTransitionClassDefinition,
  rule : Rule,
) -> ViewTransitionClassDefinition {
  self.with_style("group", rule)
}

///|
pub fn ViewTransitionClassDefinition::image_pair(
  self : ViewTransitionClassDefinition,
  rule : Rule,
) -> ViewTransitionClassDefinition {
  self.with_style("image-pair", rule)
}

///|
pub fn ViewTransitionClassDefinition::old(
  self : ViewTransitionClassDefinition,
  rule : Rule,
) -> ViewTransitionClassDefinition {
  self.with_style("old", rule)
}

///|
pub fn ViewTransitionClassDefinition::new(
  self : ViewTransitionClassDefinition,
  rule : Rule,
) -> ViewTransitionClassDefinition {
  self.with_style("new", rule)
}

///|
pub fn ViewTransitionClassDefinition::variable_uses(
  self : ViewTransitionClassDefinition,
) -> Array[@values.VariableUse] {
  let variables : Array[@values.VariableUse] = []
  for (_, rule) in self.styles {
    for variable in rule.variable_uses() {
      variables.push(variable)
    }
  }
  variables
}

///|
pub fn ViewTransitionClassDefinition::to_ir(
  self : ViewTransitionClassDefinition,
) -> @ir.ViewTransitionClassDefinition {
  {
    name: self.name,
    styles: self.styles.map(style => {
      group: style.0,
      declarations: style.1.declarations.copy(),
    }),
  }
}
