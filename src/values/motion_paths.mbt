///|
pub struct MotionPath {
  expression : Expression
}

///|
pub struct OffsetPosition {
  expression : Expression
}

///|
pub struct OffsetAnchor {
  expression : Expression
}

///|
pub struct OffsetRotate {
  expression : Expression
}

///|
pub fn MotionPath::expression(self : MotionPath) -> Expression {
  self.expression
}

///|
pub fn MotionPath::to_css(self : MotionPath) -> String {
  self.expression.to_css()
}

///|
pub fn OffsetPosition::expression(self : OffsetPosition) -> Expression {
  self.expression
}

///|
pub fn OffsetPosition::to_css(self : OffsetPosition) -> String {
  self.expression.to_css()
}

///|
pub fn OffsetAnchor::expression(self : OffsetAnchor) -> Expression {
  self.expression
}

///|
pub fn OffsetAnchor::to_css(self : OffsetAnchor) -> String {
  self.expression.to_css()
}

///|
pub fn OffsetRotate::expression(self : OffsetRotate) -> Expression {
  self.expression
}

///|
pub fn OffsetRotate::to_css(self : OffsetRotate) -> String {
  self.expression.to_css()
}

///|
pub fn motion_path(path : PathData) -> MotionPath {
  {
    expression: literal_expression(
      "path(" + quoted_css_string(path.data, "motion path") + ")",
      "motion-path",
    ),
  }
}

///|
pub fn motion_shape(shape : BasicShape) -> MotionPath {
  if (
      shape.expression.category == "geometry-box" &&
      shape.to_css() == "margin-box"
    ) ||
    (
      shape.expression.category == "shape-with-box" &&
      shape.to_css().has_suffix(" margin-box")
    ) {
    return {
      expression: invalid_expression(
        "STYLE_MOTION_BOX", "Motion paths do not accept margin-box",
      ),
    }
  }
  { expression: shape.expression, }
}

///|
pub fn motion_url(value : Url) -> MotionPath {
  { expression: literal_expression(value.to_css(), "motion-path"), }
}

///|
pub fn motion_none() -> MotionPath {
  { expression: literal_expression("none", "motion-path"), }
}

///|
pub fn MotionPath::in_box(self : MotionPath, box : GeometryBox) -> MotionPath {
  if box == MarginBox ||
    self.expression.category == "motion-path-with-box" ||
    self.expression.category == "shape-with-box" ||
    self.expression.category == "geometry-box" {
    return {
      expression: invalid_expression(
        "STYLE_MOTION_BOX", "Motion paths accept one coordinate box excluding margin-box",
      ),
    }
  }
  if self.to_css() == "none" {
    return {
      expression: invalid_expression(
        "STYLE_MOTION_PATH", "none cannot be combined with a coordinate box",
      ),
    }
  }
  {
    expression: group_expression(
      "motion-path-with-box",
      "",
      [self.expression, literal_expression(box.to_css(), "geometry-box")],
      " ",
      "",
    ),
  }
}

///|
pub(all) enum RaySize {
  RayClosestSide
  RayClosestCorner
  RayFarthestSide
  RayFarthestCorner
  RaySides
} derive(Eq, Debug)

///|
pub extend RaySize with Eq::{equal, not_equal}

///|
pub extend RaySize with @debug.Debug::{to_repr}

///|
pub fn[A : AngleMathInput] ray_path(
  angle : A,
  size~ : RaySize = RayClosestSide,
  contain~ : Bool = false,
  center? : GradientPosition,
) -> MotionPath {
  let size = match size {
    RayClosestSide => "closest-side"
    RayClosestCorner => "closest-corner"
    RayFarthestSide => "farthest-side"
    RayFarthestCorner => "farthest-corner"
    RaySides => "sides"
  }
  let values = [
    angle.angle_math().expression,
    literal_expression(size, "ray-size"),
  ]
  if contain {
    values.push(literal_expression("contain", "keyword"))
  }
  if center is Some(value) {
    values.push(literal_expression("at", "keyword"))
    values.push(value.expression())
  }
  { expression: group_expression("motion-path", "ray(", values, " ", ")"), }
}

///|
pub fn offset_position(value : GradientPosition) -> OffsetPosition {
  { expression: value.expression(), }
}

///|
pub fn offset_position_auto() -> OffsetPosition {
  { expression: literal_expression("auto", "offset-position"), }
}

///|
pub fn offset_position_normal() -> OffsetPosition {
  { expression: literal_expression("normal", "offset-position"), }
}

///|
pub fn offset_anchor(value : GradientPosition) -> OffsetAnchor {
  { expression: value.expression(), }
}

///|
pub fn offset_anchor_auto() -> OffsetAnchor {
  { expression: literal_expression("auto", "offset-anchor"), }
}

///|
pub fn[A : AngleMathInput] offset_rotation(
  angle : A,
  automatic~ : Bool = false,
  reverse~ : Bool = false,
) -> OffsetRotate {
  let prefix = if reverse {
    "reverse "
  } else if automatic {
    "auto "
  } else {
    ""
  }
  {
    expression: group_expression(
      "offset-rotate",
      prefix,
      [angle.angle_math().expression],
      "",
      "",
    ),
  }
}
