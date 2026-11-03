///|
pub struct AnimationValue {
  value : @ir.StyleValue
  variables : Array[@values.VariableUse]
}

///|
pub trait AnimationInput {
  fn animation_input(Self) -> AnimationValue
}

///|
pub impl AnimationInput for AnimationName with fn animation_input(self) {
  { value: @ir.Animation(self.value), variables: self.variables, }
}

///|
pub impl AnimationInput for @values.CssWideKeyword with fn animation_input(self) {
  { value: @ir.Text(self.to_css()), variables: [], }
}

///|
pub struct AnimationNames {
  values : Array[AnimationName?]
}

///|
pub fn animation_names(values : Array[AnimationName?]) -> AnimationNames {
  { values: values.copy(), }
}

///|
pub impl AnimationInput for AnimationNames with fn animation_input(self) {
  let variables = []
  for value in self.values {
    if value is Some(value) {
      for variable in value.variables {
        variables.push(variable)
      }
    }
  }
  {
    value: @ir.AnimationList(
      self.values.map(value => value.map(value => value.value)),
    ),
    variables,
  }
}

///|
pub extend AnimationNames with AnimationInput::{animation_input}

///|
pub extend AnimationName with AnimationInput::{animation_input}

///|
pub fn AnimationNames::identity(self : AnimationNames) -> String {
  @ir.animation_list_identity(
    self.values.map(value => value.map(value => value.value)),
  )
}

///|
pub impl TimeInput for @values.TimeList with fn time_input(self) {
  expression_input(self.expression())
}
