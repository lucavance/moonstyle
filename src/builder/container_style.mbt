///|
pub struct ContainerStyleQuery {
  condition : @ir.ContainerStyleCondition
}

///|
pub fn[T : @values.CssValue] container_style_equals(
  token : @values.Token[T],
  value : T,
) -> ContainerStyleQuery {
  { condition: @ir.StyleEquals(token.variable_use(), value.css_value()), }
}

///|
pub fn[T : @values.CssValue] container_style_slot_equals(
  slot : @values.DynamicSlot[T],
  value : T,
) -> ContainerStyleQuery {
  { condition: @ir.StyleEquals(slot.variable_use(), value.css_value()), }
}

///|
pub fn container_style_not(query : ContainerStyleQuery) -> ContainerStyleQuery {
  { condition: @ir.StyleNot(query.condition), }
}

///|
pub fn container_style_all(
  queries : Array[ContainerStyleQuery],
) -> ContainerStyleQuery {
  { condition: @ir.StyleAll(queries.map(query => query.condition)), }
}

///|
pub fn container_style_any(
  queries : Array[ContainerStyleQuery],
) -> ContainerStyleQuery {
  { condition: @ir.StyleAny(queries.map(query => query.condition)), }
}

///|
pub fn container_style_query(query : ContainerStyleQuery) -> When {
  when([@ir.container_style_condition(query.condition)])
}

///|
pub fn ContainerStyleQuery::to_when(self : ContainerStyleQuery) -> When {
  container_style_query(self)
}
