///|
pub fn attribute_state(
  name : String,
  operator~ : @ir.AttributeOperator = @ir.Present,
  value~ : String = "",
  case_mode~ : @ir.AttributeCase = @ir.DefaultCase,
) -> @ir.SelectorState {
  @ir.SelectorAttributeMatch({ name, operator, value, case_mode, })
}

///|
pub fn pseudo_state(value : @ir.PseudoClass) -> @ir.SelectorState {
  @ir.SelectorPseudo(value)
}

///|
pub fn attribute(
  name : String,
  operator~ : @ir.AttributeOperator = @ir.Present,
  value~ : String = "",
  case_mode~ : @ir.AttributeCase = @ir.DefaultCase,
) -> When {
  when([@ir.Pseudo(@ir.MatchAttribute({ name, operator, value, case_mode, }))])
}

///|
pub fn[T : MarkerInput] selector_state(
  marker : T,
  state : @ir.SelectorState,
) -> MarkerSelector {
  marker_with_state(marker, state)
}

///|
pub fn is_state(states : Array[@ir.SelectorState]) -> When {
  when([@ir.Pseudo(@ir.Is(states.copy()))])
}

///|
pub fn not_state(states : Array[@ir.SelectorState]) -> When {
  when([@ir.Pseudo(@ir.Not(states.copy()))])
}

///|
pub fn where_state(states : Array[@ir.SelectorState]) -> When {
  when([@ir.Pseudo(@ir.Where(states.copy()))])
}

///|
pub fn pseudo(value : @ir.PseudoClass) -> When {
  when([@ir.Pseudo(value)])
}

///|
pub fn pseudo_element(value : @ir.PseudoElement) -> When {
  when([@ir.PseudoElement(value)])
}
