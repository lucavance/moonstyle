///|
pub struct AnimationIterations {
  css : String
}

///|
pub fn AnimationIterations::to_css(self : AnimationIterations) -> String {
  self.css
}

///|
pub fn animation_iterations(values : Array[Number?]) -> AnimationIterations {
  if values.is_empty() {
    return {
      css: issue_css(
        "STYLE_ANIMATION_LIST_EMPTY", "Animation iterations must not be empty",
      ),
    }
  }
  {
    css: values
    .map(value => {
      match value {
        None => "infinite"
        Some(value) =>
          if value.to_css().has_prefix("-") {
            issue_css(
              "STYLE_VALUE_OUT_OF_RANGE", "Animation iterations must be nonnegative",
            )
          } else {
            value.to_css()
          }
      }
    })
    .join(", "),
  }
}

///|
pub struct TimeList {
  values : Array[Expression]
}

///|
pub fn TimeList::new() -> TimeList {
  { values: [], }
}

///|
pub fn[T : TimeMathInput] TimeList::add(self : TimeList, value : T) -> TimeList {
  { values: [..self.values, value.time_math().expression], }
}

///|
pub fn TimeList::expression(self : TimeList) -> Expression {
  declaration_list(self.values, "time-list")
}

///|
pub fn TimeList::to_css(self : TimeList) -> String {
  self.expression().to_css()
}

///|
/// Supporting bridge for typed comma lists; lists are one CSS value, not fallbacks.
pub fn declaration_list(
  values : Array[Expression],
  category : String,
) -> Expression {
  let values = values.copy()
  if values.is_empty() {
    values.push(
      invalid_expression(
        "STYLE_CSS_LIST_EMPTY", "CSS comma lists must not be empty",
      ),
    )
  }
  group_expression(category, "", values, ", ", "")
}
