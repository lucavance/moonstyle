///|
/// A structured authored value. Nodes are private; consumers can inspect its
/// stable identity and variable uses without manufacturing untyped CSS.
pub struct Expression {
  node : ValueNode
  category : String
} derive(Eq, Debug)

///|
enum ValueNode {
  Literal(String)
  Reference(VariableUse)
  Group(String, Array[ValueNode], String, String)
  Constrained(String, ValueNode)
} derive(Eq, Debug)

///|
pub struct MathExpr[T] {
  expression : Expression
  marker : T?
} derive(Eq, Debug)

///|
pub trait LengthMathDimension {}

///|
pub impl LengthMathDimension for Length

///|
pub impl LengthMathDimension for LengthPercentage

///|
pub trait LengthContractExpression {
  fn contract_expression(Self) -> String
}

///|
#warnings("-unused_trait_bound")
pub impl[T : LengthMathDimension] LengthContractExpression for MathExpr[T] with fn contract_expression(
  self,
) {
  self.expression.identity()
}

///|
pub extend ValueNode with Eq::{equal, not_equal}

///|
pub extend ValueNode with @debug.Debug::{to_repr}

///|
pub(all) struct ExpressionVariable {
  variable : VariableUse
  constraints : Array[String]
} derive(Eq, Debug)

///|
fn literal_expression(css : String, category : String) -> Expression {
  { node: Literal(css), category, }
}

///|
fn reference_expression(variable : VariableUse) -> Expression {
  { node: Reference(variable), category: variable.definition.category.name(), }
}

///|
fn group_expression(
  category : String,
  open : String,
  values : Array[Expression],
  separator : String,
  close : String,
) -> Expression {
  {
    node: Group(open, values.map(value => value.node), separator, close),
    category,
  }
}

///|
fn Expression::constrain(self : Expression, constraint : String) -> Expression {
  { ..self, node: Constrained(constraint, self.node), }
}

///|
fn ValueNode::css(self : ValueNode, in_math~ : Bool = false) -> String {
  match self {
    Literal(css) => css
    Reference(value) => "var(" + value.definition.name + ")"
    Group(open, values, separator, close) => {
      let in_math = in_math ||
        ["calc(", "min(", "max(", "clamp("].contains(open)
      open + values.map(value => value.css(in_math~)).join(separator) + close
    }
    Constrained(constraint, value) => {
      let css = value.css(in_math~)
      // A bare zero is valid as a length declaration, but CSS math interprets
      // it as a number. Keep the dimension of typed length operands.
      if in_math &&
        css == "0" &&
        (constraint == "math:length" || constraint == "math:length-percentage") {
        "0px"
      } else {
        css
      }
    }
  }
}

///|
fn ValueNode::identity(self : ValueNode) -> Json {
  match self {
    Literal(css) => ["literal", css]
    Reference(value) =>
      [
        if value.role == TokenRole {
          "token"
        } else {
          "slot"
        },
        value.definition.name,
        value.definition.category.name(),
      ]
    Group(open, values, separator, close) =>
      [
        "group",
        open,
        Json::array(values.map(value => value.identity())),
        separator,
        close,
      ]
    Constrained(constraint, value) =>
      ["constraint", constraint, value.identity()]
  }
}

///|
pub fn Expression::to_css(self : Expression) -> String {
  self.node.css()
}

///|
pub fn Expression::identity(self : Expression) -> String {
  let value : Json = [self.category, self.node.identity()]
  value.stringify()
}

///|
pub fn Expression::value_category(self : Expression) -> String {
  self.category
}

///|
fn ValueNode::collect_variables(
  self : ValueNode,
  constraints : Array[String],
  output : Array[ExpressionVariable],
) -> Unit {
  match self {
    Literal(_) => ()
    Reference(variable) =>
      output.push({ variable, constraints: constraints.copy(), })
    Group(_, values, _, _) =>
      for value in values {
        value.collect_variables(constraints, output)
      }
    Constrained(constraint, value) => {
      let next = constraints.copy()
      if !next.contains(constraint) {
        next.push(constraint)
      }
      value.collect_variables(next, output)
    }
  }
}

///|
pub fn Expression::variables(self : Expression) -> Array[ExpressionVariable] {
  let output = []
  self.node.collect_variables([], output)
  output
}

///|
pub fn Expression::is_dynamic(self : Expression) -> Bool {
  self.variables().any(use_ => use_.variable.role == DynamicSlotRole)
}

///|
fn numeric_part(css : String, category : String) -> Double? {
  let units = match category {
    "length" => length_suffixes()
    "length-percentage" => [..length_suffixes(), "%"]
    "percentage" => ["%"]
    "angle" => ["deg", "turn", "rad", "grad"]
    "time" => ["ms", "s"]
    "resolution" => ["dppx", "dpi", "dpcm"]
    "number" => [""]
    _ => []
  }
  for unit in units {
    if css.has_suffix(unit) {
      let number = @string.parse_double(css[:css.length() - unit.length()]) catch {
        _ => continue
      }
      if !number.is_nan() && !number.is_pos_inf() && !number.is_neg_inf() {
        return Some(number)
      }
    }
  }
  // Unitless zero is an existing Length representation.
  if css == "0" && (category == "length" || category == "length-percentage") {
    Some(0.0)
  } else {
    None
  }
}

///|
/// The same leaf constraints are used for literals, defaults, theme overrides,
/// and runtime arguments. All errors are returned before any bindings are made.
pub fn expression_value_issues(
  constraints : Array[String],
  css : String,
) -> Array[ValueIssue] {
  let issues = value_issues(css)
  if !issues.is_empty() {
    return issues
  }
  for constraint in constraints {
    if constraint.has_prefix("math:") {
      let category = constraint[5:].to_owned()
      if numeric_part(css, category) is None {
        issues.push({
          code: "STYLE_MATH_VALUE",
          label: "Expected a finite numeric " + category + " operand",
        })
      }
    } else if constraint.has_prefix("property:") {
      for issue in property_value_issues(constraint[9:].to_owned(), css) {
        issues.push(issue)
      }
    } else if constraint == "nonnegative" {
      if css.has_prefix("-") {
        issues.push({
          code: "STYLE_VALUE_OUT_OF_RANGE",
          label: "Expected a nonnegative value",
        })
      }
    } else if constraint == "mix-percentage" {
      if numeric_part(css, "percentage") is Some(value) &&
        value >= 0.0 &&
        value <= 100.0 {
        ()
      } else {
        issues.push({
          code: "STYLE_COLOR_MIX_WEIGHT",
          label: "Mix percentages must be between zero and 100",
        })
      }
    } else if constraint == "fontWidth" {
      for issue in property_value_issues("fontWidth", css) {
        issues.push(issue)
      }
    } else if constraint == "no-percentage" && css.has_suffix("%") {
      issues.push({
        code: "STYLE_MATH_DIMENSION",
        label: "This property does not accept percentages",
      })
    }
  }
  let unique : Array[ValueIssue] = []
  for issue in issues {
    if !unique.any(previous => previous.code == issue.code) {
      unique.push(issue)
    }
  }
  unique
}

///|
fn ValueNode::issues(
  self : ValueNode,
  constraints : Array[String],
  output : Array[ValueIssue],
) -> Unit {
  match self {
    Literal(css) =>
      for issue in expression_value_issues(constraints, css) {
        output.push(issue)
      }
    Reference(variable) =>
      for
        issue in expression_value_issues(
          constraints,
          variable.definition.default_css,
        ) {
        output.push(issue)
      }
    Group(_, values, _, _) =>
      for value in values {
        value.issues(constraints, output)
      }
    Constrained(constraint, value) => {
      let next = constraints.copy()
      if !next.contains(constraint) {
        next.push(constraint)
      }
      value.issues(next, output)
    }
  }
}

///|
pub fn Expression::issues(
  self : Expression,
  property : String,
) -> Array[ValueIssue] {
  let output = []
  let constraints = self.property_constraints(property)
  self.node.issues(constraints, output)
  if self.category == "grid-template-track-list" &&
    ["gridAutoColumns", "gridAutoRows", "grid-auto-columns", "grid-auto-rows"].contains(
      property,
    ) {
    output.push({
      code: "STYLE_GRID_AUTO_TRACK",
      label: "Auto tracks cannot contain named lines, repeat, or subgrid",
    })
  }
  output
}

///|
pub fn Expression::property_constraints(
  self : Expression,
  property : String,
) -> Array[String] {
  let output = []
  if common_value_property(property) {
    match self.node {
      Group(_, _, _, _) => ()
      _ => output.push("property:" + property)
    }
  }
  if property == "fontWidth" || property == "font-width" {
    output.push("fontWidth")
  }
  if (self.category == "length" || self.category == "length-percentage") &&
    [
      "perspective", "borderSpacing", "border-spacing", "outlineOffset", "outline-offset",
      "columnWidth", "column-width", "overflowClipMargin", "overflow-clip-margin",
    ].contains(property) {
    output.push("no-percentage")
  }
  output
}

///|
pub fn[T] MathExpr::expression(self : MathExpr[T]) -> Expression {
  self.expression
}

///|
pub fn[T] MathExpr::to_css(self : MathExpr[T]) -> String {
  self.expression.to_css()
}

///|
fn[T] math_expression(expression : Expression) -> MathExpr[T] {
  { expression, marker: None, }
}

///|
pub fn[T] MathExpr::add(self : MathExpr[T], other : MathExpr[T]) -> MathExpr[T] {
  math_expression(
    group_expression(
      self.expression.category,
      "calc(",
      [self.expression, other.expression],
      " + ",
      ")",
    ),
  )
}

///|
pub fn[T] MathExpr::subtract(
  self : MathExpr[T],
  other : MathExpr[T],
) -> MathExpr[T] {
  math_expression(
    group_expression(
      self.expression.category,
      "calc(",
      [self.expression, other.expression],
      " - ",
      ")",
    ),
  )
}

///|
pub fn[T] MathExpr::scale(
  self : MathExpr[T],
  factor : MathExpr[Number],
) -> MathExpr[T] {
  math_expression(
    group_expression(
      self.expression.category,
      "calc(",
      [self.expression, factor.expression],
      " * ",
      ")",
    ),
  )
}

///|
/// Division is deliberately limited to a finite, nonzero static denominator.
pub fn[T] MathExpr::divide(self : MathExpr[T], divisor : Double) -> MathExpr[T] {
  let css = if divisor == 0.0 ||
    divisor.is_nan() ||
    divisor.is_pos_inf() ||
    divisor.is_neg_inf() {
    issue_css("STYLE_MATH_DIVISOR", "Division requires a finite nonzero number")
  } else {
    divisor.to_string()
  }
  math_expression(
    group_expression(
      self.expression.category,
      "calc(",
      [self.expression, literal_expression(css, "number")],
      " / ",
      ")",
    ),
  )
}

///|
fn[T] math_comparison(
  name : String,
  values : Array[MathExpr[T]],
) -> MathExpr[T] {
  if values.is_empty() {
    return math_expression(
      literal_expression(
        issue_css("STYLE_MATH_EMPTY", name + " requires operands"),
        "invalid",
      ),
    )
  }
  math_expression(
    group_expression(
      values[0].expression.category,
      name + "(",
      values.map(value => value.expression),
      ", ",
      ")",
    ),
  )
}

///|
pub fn[T] css_min(values : Array[MathExpr[T]]) -> MathExpr[T] {
  math_comparison("min", values)
}

///|
pub fn[T] css_max(values : Array[MathExpr[T]]) -> MathExpr[T] {
  math_comparison("max", values)
}

///|
pub fn[T] css_clamp(
  minimum : MathExpr[T],
  preferred : MathExpr[T],
  maximum : MathExpr[T],
) -> MathExpr[T] {
  math_comparison("clamp", [minimum, preferred, maximum])
}

///|
pub fn MathExpr::as_length_percentage(
  self : MathExpr[Length],
) -> MathExpr[LengthPercentage] {
  math_expression({ ..self.expression, category: "length-percentage", })
}

///|
pub fn percentage_as_length(
  value : MathExpr[Percentage],
) -> MathExpr[LengthPercentage] {
  math_expression({ ..value.expression, category: "length-percentage", })
}

///|
fn valid_identity_node(node : Json) -> Bool {
  match node {
    ["literal", String(_)] => true
    ["token" | "slot", String(name), String(category)] =>
      name.has_prefix("--") &&
      [
        "length", "length-percentage", "percentage", "number", "integer", "color",
        "angle", "time", "resolution", "url",
      ].contains(category)
    ["constraint", String(_), value] => valid_identity_node(value)
    ["group", String(_), Array(values), String(_), String(_)] =>
      values.every(valid_identity_node)
    _ => false
  }
}

///|
pub fn valid_expression_identity(identity : String) -> Bool {
  if !value_issues(identity).is_empty() {
    return false
  }
  let parsed = @json.parse(identity) catch { _ => return false }
  if parsed.stringify() != identity {
    return false
  }
  match parsed {
    [String(_), value] => valid_identity_node(value)
    _ => false
  }
}
