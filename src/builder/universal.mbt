///|
fn Rule::append_property_fallbacks(
  self : Rule,
  property : String,
  inputs : Array[PropertyInput],
  when_ : When,
  source : @ir.SourceSpan?,
) -> Rule {
  if inputs.every(input => input.variable is None && input.expression is None) {
    self.append_fallbacks(
      property,
      inputs.map(input => input.css),
      when_,
      source,
    )
  } else {
    self.append_expression_fallbacks(
      property,
      inputs.map(input => {
        match input.expression {
          Some(value) => value
          None => @values.declaration_expression(input.css, input.variable)
        }
      }),
      when_,
      source,
      origins=inputs.map(input => input.value_origin),
    )
  }
}
