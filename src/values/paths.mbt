///|
/// A validated SVG path-data string, shared by clipping and motion paths.
pub struct PathData {
  data : String
}

///|
fn path_space(c : UInt16) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn path_digit(c : UInt16) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn path_arity(c : UInt16) -> Int32 {
  match c {
    'M' | 'm' | 'L' | 'l' | 'T' | 't' => 2
    'H' | 'h' | 'V' | 'v' => 1
    'C' | 'c' => 6
    'S' | 's' | 'Q' | 'q' => 4
    'A' | 'a' => 7
    'Z' | 'z' => 0
    _ => -1
  }
}

///|
fn path_number_end(text : String, start : Int32) -> Int32? {
  let mut i = start
  if i < text.length() && (text[i] == '+' || text[i] == '-') {
    i += 1
  }
  let mut digits = 0
  while i < text.length() && path_digit(text[i]) {
    digits += 1
    i += 1
  }
  if i < text.length() && text[i] == '.' {
    i += 1
    while i < text.length() && path_digit(text[i]) {
      digits += 1
      i += 1
    }
  }
  if digits == 0 {
    return None
  }
  if i < text.length() && (text[i] == 'e' || text[i] == 'E') {
    i += 1
    if i < text.length() && (text[i] == '+' || text[i] == '-') {
      i += 1
    }
    let exponent = i
    while i < text.length() && path_digit(text[i]) {
      i += 1
    }
    if i == exponent {
      return None
    }
  }
  Some(i)
}

///|
fn valid_path_data(text : String) -> Bool {
  let mut i = 0
  let mut first = true
  let mut command : UInt16 = ' '
  let mut count = 0
  let mut arity = -1
  while i < text.length() {
    while i < text.length() && path_space(text[i]) {
      i += 1
    }
    if i == text.length() {
      break
    }
    let next_arity = path_arity(text[i])
    if next_arity >= 0 {
      if first && text[i] != 'M' && text[i] != 'm' {
        return false
      }
      if arity > 0 && (count == 0 || count % arity != 0) {
        return false
      }
      command = text[i]
      arity = next_arity
      count = 0
      first = false
      i += 1
      continue
    }
    if first || arity <= 0 {
      return false
    }
    if text[i] == ',' {
      if count == 0 {
        return false
      }
      i += 1
      while i < text.length() && path_space(text[i]) {
        i += 1
      }
      if i == text.length() || text[i] == ',' || path_arity(text[i]) >= 0 {
        return false
      }
    }
    let is_arc = command == 'A' || command == 'a'
    let parameter = count % arity
    let end = if is_arc && (parameter == 3 || parameter == 4) {
      if text[i] != '0' && text[i] != '1' {
        return false
      }
      i + 1
    } else {
      match path_number_end(text, i) {
        Some(end) => end
        None => return false
      }
    }
    let number = @string.parse_double(text[i:end]) catch { _ => return false }
    if number.is_nan() || number.is_pos_inf() || number.is_neg_inf() {
      return false
    }
    if is_arc && parameter < 2 && number < 0.0 {
      return false
    }
    i = end
    count += 1
  }
  !first && (arity == 0 || (count > 0 && count % arity == 0))
}

///|
pub fn path_data(value : String) -> PathData {
  let data = value.trim().to_owned()
  if valid_path_data(data) {
    { data, }
  } else {
    {
      data: issue_css(
        "STYLE_PATH_DATA", "Invalid SVG path command, parameter count, number or arc flag",
      ),
    }
  }
}

///|
pub fn PathData::to_string(self : PathData) -> String {
  self.data
}

///|
pub(all) enum FillRule {
  Nonzero
  Evenodd
} derive(Eq, Debug)

///|
pub extend FillRule with Eq::{equal, not_equal}

///|
pub extend FillRule with @debug.Debug::{to_repr}

///|
fn FillRule::css(self : FillRule) -> String {
  match self {
    Nonzero => "nonzero"
    Evenodd => "evenodd"
  }
}

///|
pub(all) enum GeometryBox {
  BorderBox
  PaddingBox
  ContentBox
  MarginBox
  FillBox
  StrokeBox
  ViewBox
} derive(Eq, Debug)

///|
pub extend GeometryBox with Eq::{equal, not_equal}

///|
pub extend GeometryBox with @debug.Debug::{to_repr}

///|
pub fn GeometryBox::to_css(self : GeometryBox) -> String {
  match self {
    BorderBox => "border-box"
    PaddingBox => "padding-box"
    ContentBox => "content-box"
    MarginBox => "margin-box"
    FillBox => "fill-box"
    StrokeBox => "stroke-box"
    ViewBox => "view-box"
  }
}

///|
pub struct BasicShape {
  expression : Expression
}

///|
pub fn BasicShape::expression(self : BasicShape) -> Expression {
  self.expression
}

///|
pub fn BasicShape::to_css(self : BasicShape) -> String {
  self.expression.to_css()
}

///|
pub fn BasicShape::in_box(self : BasicShape, box : GeometryBox) -> BasicShape {
  if self.expression.category == "shape-with-box" ||
    self.expression.category == "geometry-box" {
    return {
      expression: invalid_expression(
        "STYLE_SHAPE_BOX", "A shape accepts only one geometry box",
      ),
    }
  }
  {
    expression: group_expression(
      "shape-with-box",
      "",
      [self.expression, literal_expression(box.to_css(), "geometry-box")],
      " ",
      "",
    ),
  }
}

///|
pub fn geometry_box(box : GeometryBox) -> BasicShape {
  { expression: literal_expression(box.to_css(), "geometry-box"), }
}

///|
pub fn[X : LengthPercentageMathInput, Y : LengthPercentageMathInput] ellipse_shape(
  x : X,
  y : Y,
  center~ : GradientPosition = gradient_center(),
) -> BasicShape {
  {
    expression: group_expression(
      "shape",
      "ellipse(",
      [
        x.length_percentage_math().expression.constrain("nonnegative"),
        y.length_percentage_math().expression.constrain("nonnegative"),
        literal_expression("at", "keyword"),
        center.expression(),
      ],
      " ",
      ")",
    ),
  }
}

///|
pub fn[R : LengthPercentageMathInput] circle_shape(
  radius : R,
  center~ : GradientPosition = gradient_center(),
) -> BasicShape {
  {
    expression: group_expression(
      "shape",
      "circle(",
      [
        radius.length_percentage_math().expression.constrain("nonnegative"),
        literal_expression("at", "keyword"),
        center.expression(),
      ],
      " ",
      ")",
    ),
  }
}

///|
pub fn inset_shape(
  offsets : Array[MathExpr[LengthPercentage]],
  radius? : MathExpr[LengthPercentage],
) -> BasicShape {
  let values = offsets.map(value => value.expression)
  if offsets.is_empty() || offsets.length() > 4 {
    values.push(
      invalid_expression(
        "STYLE_SHAPE_INSET", "Inset requires one to four offsets",
      ),
    )
  }
  if radius is Some(value) {
    values.push(literal_expression("round", "keyword"))
    values.push(value.expression.constrain("nonnegative"))
  }
  { expression: group_expression("shape", "inset(", values, " ", ")"), }
}

///|
pub fn polygon_shape(
  points : Array[GradientPosition],
  fill~ : FillRule = Nonzero,
) -> BasicShape {
  let values = [literal_expression(fill.css(), "fill-rule")]
  for point in points {
    values.push(point.expression())
  }
  if points.length() < 3 {
    values.push(
      invalid_expression(
        "STYLE_SHAPE_POLYGON", "Polygon requires at least three points",
      ),
    )
  }
  { expression: group_expression("shape", "polygon(", values, ", ", ")"), }
}

///|
pub fn path_shape(path : PathData, fill~ : FillRule = Nonzero) -> BasicShape {
  {
    expression: literal_expression(
      "path(" + fill.css() + ", " + quoted_css_string(path.data, "path") + ")",
      "shape",
    ),
  }
}
