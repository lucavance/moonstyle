///|
pub(all) enum BoxSizeKeyword {
  SizeAuto
  SizeNone
  SizeMinContent
  SizeMaxContent
  SizeFitContent
} derive(Eq, Debug)

///|
pub fn box_size_keyword(value : BoxSizeKeyword) -> BoxSize {
  {
    expression: literal_expression(
      match value {
        SizeAuto => "auto"
        SizeNone => "none"
        SizeMinContent => "min-content"
        SizeMaxContent => "max-content"
        SizeFitContent => "fit-content"
      },
      "box-size",
    ),
  }
}

///|
/// Intrinsic box sizing is distinct from the Grid `fit_content` constructor.
pub fn[T : BoxSizeValueInput] fit_content_size(limit : T) -> BoxSize {
  {
    expression: group_expression(
      "box-size",
      "fit-content(",
      [radius_operand(limit.value_expression())],
      "",
      ")",
    ),
  }
}

///|
pub fn basis_content() -> FlexBasis {
  { expression: literal_expression("content", "flex-basis"), }
}

///|
pub impl FlexBasisValueInput for BoxSize with fn flex_basis_value_expression(
  self,
) {
  self.expression
}

///|
pub(all) enum FontSizeKeyword {
  FontXXSmall
  FontXSmall
  FontSmall
  FontMedium
  FontLarge
  FontXLarge
  FontXXLarge
  FontXXXLarge
  FontSmaller
  FontLarger
} derive(Eq, Debug)

///|
pub fn font_size_keyword(value : FontSizeKeyword) -> FontSize {
  {
    expression: literal_expression(
      match value {
        FontXXSmall => "xx-small"
        FontXSmall => "x-small"
        FontSmall => "small"
        FontMedium => "medium"
        FontLarge => "large"
        FontXLarge => "x-large"
        FontXXLarge => "xx-large"
        FontXXXLarge => "xxx-large"
        FontSmaller => "smaller"
        FontLarger => "larger"
      },
      "font-size",
    ),
  }
}

///|
pub fn line_height_normal() -> LineHeight {
  { expression: literal_expression("normal", "line-height"), }
}

///|
// Range constraints apply to an authored atom, not to all operands of calc.
// CSS evaluates math ranges after arithmetic; negative intermediate operands
// are legal and cannot be evaluated here without layout information.
fn atom_nonnegative(value : Expression) -> Expression {
  fn computation(node : ValueNode) -> Bool {
    match node {
      Group(_, _, _, _) => true
      Constrained(_, child) => computation(child)
      _ => false
    }
  }
  if computation(value.node) {
    value
  } else {
    value.constrain("nonnegative")
  }
}

///|
fn radius_operand(value : Expression) -> Expression {
  if value.category == "box-size" {
    return literal_expression(
      issue_css("STYLE_MATH_DIMENSION", "Expected a length or percentage"),
      "invalid",
    )
  }
  match value.node {
    Group(_, _, _, _) => atom_nonnegative(value)
    _ => atom_nonnegative(value.constrain("math:length-percentage"))
  }
}

///|
pub struct BorderRadii {
  expression : Expression
} derive(Eq, Debug)

///|
/// Builds the CSS horizontal / vertical radius lists, each with 1–4 entries.
pub fn border_radii(
  horizontal : Array[MathExpr[LengthPercentage]],
  vertical? : Array[MathExpr[LengthPercentage]],
) -> BorderRadii {
  fn list(values : Array[MathExpr[LengthPercentage]]) -> Expression {
    if values.is_empty() || values.length() > 4 {
      literal_expression(
        issue_css(
          "STYLE_RADIUS_COUNT", "A radius list requires one to four values",
        ),
        "border-radii",
      )
    } else {
      group_expression(
        "border-radii",
        "",
        values.map(value => radius_operand(value.expression)),
        " ",
        "",
      )
    }
  }
  let horizontal = list(horizontal)
  {
    expression: match vertical {
      Some(values) =>
        group_expression(
          "border-radii",
          "",
          [horizontal, list(values)],
          " / ",
          "",
        )
      None => horizontal
    },
  }
}

///|
pub fn[T : BoxSizeValueInput] single_radius(value : T) -> BorderRadii {
  { expression: radius_operand(value.value_expression()), }
}

///|
pub fn BorderRadii::expression(self : BorderRadii) -> Expression {
  self.expression
}

///|
pub fn BorderRadii::to_css(self : BorderRadii) -> String {
  self.expression.to_css()
}

///|
pub fn[T : BoxSizeValueInput] CornerRadius::vertical(
  self : CornerRadius,
  value : T,
) -> CornerRadius {
  {
    expression: group_expression(
      "corner-radius",
      "",
      [self.horizontal, radius_operand(value.value_expression())],
      " ",
      "",
    ),
    horizontal: self.horizontal,
  }
}

///|
pub fn CornerRadius::expression(self : CornerRadius) -> Expression {
  self.expression
}

///|
pub impl BoxSizeContractExpression for CornerRadius with fn box_size_contract_expression(
  self,
) {
  self.expression.identity()
}

///|
pub impl BoxSizeContractExpression for BorderRadii with fn box_size_contract_expression(
  self,
) {
  self.expression.identity()
}

///|
pub impl FlexBasisContractExpression for BoxSize with fn flex_basis_contract_expression(
  self,
) {
  self.expression.identity()
}

///|
fn common_value_property(property : String) -> Bool {
  [
    "width", "height", "minWidth", "maxWidth", "minHeight", "maxHeight", "min-width",
    "max-width", "min-height", "max-height", "inlineSize", "blockSize", "minInlineSize",
    "maxInlineSize", "minBlockSize", "maxBlockSize", "inline-size", "block-size",
    "min-inline-size", "max-inline-size", "min-block-size", "max-block-size", "flexBasis",
    "flex-basis", "fontSize", "font-size", "lineHeight", "line-height", "borderRadius",
    "border-radius", "borderStartStartRadius", "borderStartEndRadius", "borderEndStartRadius",
    "borderEndEndRadius", "borderTopLeftRadius", "borderTopRightRadius", "borderBottomLeftRadius",
    "borderBottomRightRadius",
  ].contains(property)
}

///|
fn common_property_keyword_valid(property : String, value : String) -> Bool {
  let maximum = [
    "maxWidth", "maxHeight", "maxInlineSize", "maxBlockSize", "max-width", "max-height",
    "max-inline-size", "max-block-size",
  ].contains(property)
  let font = property == "fontSize" || property == "font-size"
  let line = property == "lineHeight" || property == "line-height"
  let radius = property.contains("Radius") || property.contains("radius")
  let basis = property == "flexBasis" || property == "flex-basis"
  if value == "auto" {
    return !maximum && !font && !line && !radius
  }
  if value == "none" {
    return maximum
  }
  if value == "content" {
    return basis
  }
  if ["min-content", "max-content", "fit-content"].contains(value) {
    return !font && !line && !radius
  }
  if value == "normal" {
    return line
  }
  if [
      "xx-small", "x-small", "small", "medium", "large", "x-large", "xx-large", "xxx-large",
      "smaller", "larger",
    ].contains(value) {
    return font
  }
  true
}
