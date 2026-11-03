///|
pub struct FilterFunction {
  expression : Expression
} derive(Eq, Debug)

///|
pub struct FilterList {
  expression : Expression
} derive(Eq, Debug)

///|
pub struct Shadow {
  x : Expression
  y : Expression
  blur_value : Expression?
  spread_value : Expression?
  color_value : Expression?
  inset_value : Bool
} derive(Eq, Debug)

///|
pub struct BoxShadowList {
  expression : Expression
} derive(Eq, Debug)

///|
pub struct TextShadowList {
  expression : Expression
} derive(Eq, Debug)

///|
fn effect_length(value : Expression, nonnegative : Bool) -> Expression {
  let value = match value.node {
    Group(_, _, _, _) => value.constrain("no-percentage")
    _ => value.constrain("math:length")
  }
  if nonnegative {
    atom_nonnegative(value)
  } else {
    value
  }
}

///|
pub fn[T : LengthMathInput] blur_filter(value : T) -> FilterFunction {
  {
    expression: group_expression(
      "filter",
      "blur(",
      [effect_length(value.length_math().expression(), true)],
      "",
      ")",
    ),
  }
}

///|
pub trait FilterAmountInput {
  fn filter_amount(Self) -> Expression
}

///|
pub trait FilterAmountDimension {}

///|
fn amount_filter(name : String, value : Expression) -> FilterFunction {
  {
    expression: group_expression(
      "filter",
      name + "(",
      [atom_nonnegative(value)],
      "",
      ")",
    ),
  }
}

///|
pub fn[T : FilterAmountInput] brightness_filter(value : T) -> FilterFunction {
  amount_filter("brightness", value.filter_amount())
}

///|
pub fn[T : FilterAmountInput] contrast_filter(value : T) -> FilterFunction {
  amount_filter("contrast", value.filter_amount())
}

///|
pub fn[T : FilterAmountInput] grayscale_filter(value : T) -> FilterFunction {
  amount_filter("grayscale", value.filter_amount())
}

///|
pub fn[T : AngleMathInput] hue_rotate_filter(value : T) -> FilterFunction {
  {
    expression: group_expression(
      "filter",
      "hue-rotate(",
      [value.angle_math().expression()],
      "",
      ")",
    ),
  }
}

///|
pub fn authored_filter_list(values : Array[FilterFunction]) -> FilterList {
  {
    expression: if values.is_empty() {
      literal_expression(modern_invalid("filter"), "filter-list")
    } else {
      group_expression(
        "filter-list",
        "",
        values.map(value => value.expression),
        " ",
        "",
      )
    },
  }
}

///|
pub fn[X : LengthMathInput, Y : LengthMathInput] shadow(
  x : X,
  y : Y,
  blur~ : Length? = None,
  spread~ : Length? = None,
  color~ : Color? = None,
  inset~ : Bool = false,
) -> Shadow {
  let result : Shadow = {
    x: effect_length(x.length_math().expression(), false),
    y: effect_length(y.length_math().expression(), false),
    blur_value: None,
    spread_value: None,
    color_value: None,
    inset_value: inset,
  }
  let result = match blur {
    Some(value) => result.blur(value)
    None => result
  }
  let result = match spread {
    Some(value) => result.spread(value)
    None => result
  }
  match color {
    Some(value) => result.color(value)
    None => result
  }
}

///|
pub fn[T : LengthMathInput] Shadow::blur(self : Shadow, value : T) -> Shadow {
  {
    ..self,
    blur_value: Some(effect_length(value.length_math().expression(), true)),
  }
}

///|
pub fn[T : LengthMathInput] Shadow::spread(self : Shadow, value : T) -> Shadow {
  {
    ..self,
    spread_value: Some(effect_length(value.length_math().expression(), false)),
  }
}

///|
pub fn[T : GradientColorInput] Shadow::color(
  self : Shadow,
  value : T,
) -> Shadow {
  { ..self, color_value: Some(value.gradient_color()), }
}

///|
pub fn Shadow::inset(self : Shadow) -> Shadow {
  { ..self, inset_value: true, }
}

///|
pub fn Shadow::expression(self : Shadow) -> Expression {
  let parts = []
  if self.inset_value {
    parts.push(literal_expression("inset", "keyword"))
  }
  parts.push(self.x)
  parts.push(self.y)
  match self.blur_value {
    Some(value) => parts.push(value)
    None =>
      if self.spread_value is Some(_) {
        parts.push(literal_expression("0", "length"))
      }
  }
  match self.spread_value {
    Some(value) => parts.push(value)
    None => ()
  }
  match self.color_value {
    Some(value) => parts.push(value)
    None => ()
  }
  group_expression("shadow", "", parts, " ", "")
}

///|
pub fn authored_box_shadows(values : Array[Shadow]) -> BoxShadowList {
  {
    expression: if values.is_empty() {
      literal_expression(modern_invalid("box-shadow"), "box-shadow-list")
    } else {
      group_expression(
        "box-shadow-list",
        "",
        values.map(value => value.expression()),
        ", ",
        "",
      )
    },
  }
}

///|
pub fn authored_text_shadows(values : Array[Shadow]) -> TextShadowList {
  {
    expression: if values.is_empty() ||
      values.any(value => value.inset_value || value.spread_value is Some(_)) {
      literal_expression(
        issue_css(
          "STYLE_TEXT_SHADOW", "Text shadows cannot contain inset or spread and require a shadow",
        ),
        "text-shadow-list",
      )
    } else {
      group_expression(
        "text-shadow-list",
        "",
        values.map(value => value.expression()),
        ", ",
        "",
      )
    },
  }
}

///|
pub fn FilterList::expression(self : FilterList) -> Expression {
  self.expression
}

///|
pub fn BoxShadowList::expression(self : BoxShadowList) -> Expression {
  self.expression
}

///|
pub fn TextShadowList::expression(self : TextShadowList) -> Expression {
  self.expression
}
