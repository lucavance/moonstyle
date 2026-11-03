///|
pub struct Image {
  expression : Expression
} derive(Eq, Debug)

///|
pub struct GradientStop[T] {
  expression : Expression
  hint : Bool
  marker : T?
} derive(Eq, Debug)

///|
pub struct ConicPosition {
  expression : Expression
} derive(Eq, Debug)

///|
pub struct GradientPosition {
  x : Expression
  y : Expression
} derive(Eq, Debug)

///|
pub struct GradientDirection {
  expression : Expression
} derive(Eq, Debug)

///|
pub(all) enum GradientSide {
  ToTop
  ToBottom
  ToLeft
  ToRight
  ToTopLeft
  ToTopRight
  ToBottomLeft
  ToBottomRight
} derive(Eq, Debug)

///|
pub(all) enum RadialShape {
  Circle
  Ellipse
} derive(Eq, Debug)

///|
pub(all) enum RadialExtent {
  ClosestSide
  FarthestSide
  ClosestCorner
  FarthestCorner
} derive(Eq, Debug)

///|
pub struct RadialSize {
  expression : Expression
  shape : RadialShape?
} derive(Eq, Debug)

///|
pub trait GradientColorInput {
  fn gradient_color(Self) -> Expression
}

///|
pub impl GradientColorInput for Color with fn gradient_color(self) {
  literal_expression(self.to_css(), "color")
}

///|
pub impl GradientColorInput for Token[Color] with fn gradient_color(self) {
  reference_expression(self.variable_use())
}

///|
pub impl GradientColorInput for DynamicSlot[Color] with fn gradient_color(self) {
  reference_expression(self.variable_use())
}

///|
pub trait ImageInput {
  fn image_expression(Self) -> Expression
}

///|
pub impl ImageInput for Image with fn image_expression(self) {
  self.expression
}

///|
pub impl ImageInput for Url with fn image_expression(self) {
  literal_expression(self.to_css(), "image")
}

///|
pub impl ImageInput for Token[Url] with fn image_expression(self) {
  reference_expression(self.variable_use())
}

///|
pub impl ImageInput for DynamicSlot[Url] with fn image_expression(self) {
  reference_expression(self.variable_use())
}

///|
pub fn Image::expression(self : Image) -> Expression {
  self.expression
}

///|
pub fn Image::to_css(self : Image) -> String {
  self.expression.to_css()
}

///|
pub fn[I : ImageInput] image(value : I) -> Image {
  { expression: value.image_expression(), }
}

///|
pub fn image_none() -> Image {
  { expression: literal_expression("none", "image"), }
}

///|
pub fn background_images(values : Array[Image]) -> Image {
  if values.is_empty() {
    return {
      expression: invalid_expression(
        "STYLE_IMAGE_EMPTY", "An image list must not be empty",
      ),
    }
  }
  {
    expression: group_expression(
      "image-list",
      "",
      values.map(value => value.expression),
      ", ",
      "",
    ),
  }
}

///|
pub fn[C : GradientColorInput] color_stop(
  color : C,
  position~ : MathExpr[LengthPercentage]? = None,
  end~ : MathExpr[LengthPercentage]? = None,
) -> GradientStop[LengthPercentage] {
  let values = [color.gradient_color()]
  if position is Some(value) {
    values.push(value.expression)
  }
  if end is Some(value) {
    if position is None {
      values.push(
        invalid_expression(
          "STYLE_GRADIENT_STOP", "A double stop requires its first position",
        ),
      )
    }
    values.push(value.expression)
  }
  {
    expression: group_expression("gradient-stop", "", values, " ", ""),
    hint: false,
    marker: None,
  }
}

///|
pub fn[P : LengthPercentageMathInput] gradient_hint(
  position : P,
) -> GradientStop[LengthPercentage] {
  {
    expression: position.length_percentage_math().expression,
    hint: true,
    marker: None,
  }
}

///|
pub fn[A : AngleMathInput] conic_angle(value : A) -> ConicPosition {
  { expression: value.angle_math().expression, }
}

///|
pub fn[P : PercentageMathInput] conic_percentage(value : P) -> ConicPosition {
  { expression: value.percentage_math().expression, }
}

///|
pub fn[C : GradientColorInput] conic_stop(
  color : C,
  position~ : ConicPosition? = None,
  end~ : ConicPosition? = None,
) -> GradientStop[ConicPosition] {
  let values = [color.gradient_color()]
  if position is Some(value) {
    values.push(value.expression)
  }
  if end is Some(value) {
    if position is None {
      values.push(
        invalid_expression(
          "STYLE_GRADIENT_STOP", "A double stop requires its first position",
        ),
      )
    }
    values.push(value.expression)
  }
  {
    expression: group_expression("conic-stop", "", values, " ", ""),
    hint: false,
    marker: None,
  }
}

///|
pub fn conic_hint(value : ConicPosition) -> GradientStop[ConicPosition] {
  { expression: value.expression, hint: true, marker: None, }
}

///|
pub fn[X : LengthPercentageMathInput, Y : LengthPercentageMathInput] gradient_position(
  x : X,
  y : Y,
) -> GradientPosition {
  {
    x: x.length_percentage_math().expression,
    y: y.length_percentage_math().expression,
  }
}

///|
pub fn gradient_center() -> GradientPosition {
  {
    x: literal_expression("50%", "length-percentage"),
    y: literal_expression("50%", "length-percentage"),
  }
}

///|
fn GradientPosition::expression(self : GradientPosition) -> Expression {
  group_expression("position", "", [self.x, self.y], " ", "")
}

///|
pub fn gradient_to(side : GradientSide) -> GradientDirection {
  let css = match side {
    ToTop => "top"
    ToBottom => "bottom"
    ToLeft => "left"
    ToRight => "right"
    ToTopLeft => "top left"
    ToTopRight => "top right"
    ToBottomLeft => "bottom left"
    ToBottomRight => "bottom right"
  }
  { expression: literal_expression("to " + css, "gradient-direction"), }
}

///|
pub fn[A : AngleMathInput] gradient_angle(value : A) -> GradientDirection {
  { expression: value.angle_math().expression, }
}

///|
fn[T] gradient(
  name : String,
  header : Expression,
  stops : Array[GradientStop[T]],
  repeating : Bool,
) -> Image {
  let values = [header]
  let mut colors = 0
  let mut last_hint = true
  for stop in stops {
    if stop.hint && last_hint {
      values.push(
        invalid_expression(
          "STYLE_GRADIENT_HINT", "Hints must occur singly between color stops",
        ),
      )
    }
    if !stop.hint {
      colors += 1
    }
    last_hint = stop.hint
    values.push(stop.expression)
  }
  if colors < 2 || last_hint {
    values.push(
      invalid_expression(
        "STYLE_GRADIENT_STOPS", "A gradient requires at least two colors and must end with a color stop",
      ),
    )
  }
  let prefix = if repeating { "repeating-" } else { "" }
  {
    expression: group_expression(
      "image",
      prefix + name + "-gradient(",
      values,
      ", ",
      ")",
    ),
  }
}

///|
pub fn linear_gradient(
  stops : Array[GradientStop[LengthPercentage]],
  direction~ : GradientDirection = gradient_to(ToBottom),
  repeating~ : Bool = false,
  interpolation? : ColorInterpolation,
) -> Image {
  let header = match interpolation {
    Some(value) =>
      group_expression(
        "gradient-header",
        "",
        [direction.expression, literal_expression(value.css, "interpolation")],
        " ",
        "",
      )
    None => direction.expression
  }
  gradient("linear", header, stops, repeating)
}

///|
pub fn radial_extent(extent : RadialExtent) -> RadialSize {
  let css = match extent {
    ClosestSide => "closest-side"
    FarthestSide => "farthest-side"
    ClosestCorner => "closest-corner"
    FarthestCorner => "farthest-corner"
  }
  { expression: literal_expression(css, "radial-size"), shape: None, }
}

///|
pub fn[L : LengthMathInput] radial_radius(value : L) -> RadialSize {
  {
    expression: value.length_math().expression.constrain("nonnegative"),
    shape: Some(Circle),
  }
}

///|
pub fn[X : LengthPercentageMathInput, Y : LengthPercentageMathInput] radial_radii(
  x : X,
  y : Y,
) -> RadialSize {
  {
    expression: group_expression(
      "radial-size",
      "",
      [
        x.length_percentage_math().expression.constrain("nonnegative"),
        y.length_percentage_math().expression.constrain("nonnegative"),
      ],
      " ",
      "",
    ),
    shape: Some(Ellipse),
  }
}

///|
pub fn radial_gradient(
  stops : Array[GradientStop[LengthPercentage]],
  shape~ : RadialShape = Ellipse,
  size~ : RadialSize = radial_extent(FarthestCorner),
  center~ : GradientPosition = gradient_center(),
  repeating~ : Bool = false,
  interpolation? : ColorInterpolation,
) -> Image {
  let shape_css = match shape {
    Circle => "circle"
    Ellipse => "ellipse"
  }
  let values = [
    literal_expression(shape_css, "radial-shape"),
    size.expression,
    literal_expression("at", "keyword"),
    center.expression(),
  ]
  if size.shape is Some(required) && required != shape {
    values.push(
      invalid_expression(
        "STYLE_GRADIENT_RADIAL_SIZE", "Explicit radial size must agree with its shape",
      ),
    )
  }
  if interpolation is Some(value) {
    values.push(literal_expression(value.css, "interpolation"))
  }
  gradient(
    "radial",
    group_expression("radial-header", "", values, " ", ""),
    stops,
    repeating,
  )
}

///|
pub fn conic_gradient(
  stops : Array[GradientStop[ConicPosition]],
  angle~ : MathExpr[Angle]? = None,
  center~ : GradientPosition = gradient_center(),
  repeating~ : Bool = false,
  interpolation? : ColorInterpolation,
) -> Image {
  let values = []
  if angle is Some(value) {
    values.push(literal_expression("from", "keyword"))
    values.push(value.expression)
  }
  values.push(literal_expression("at", "keyword"))
  values.push(center.expression())
  if interpolation is Some(value) {
    values.push(literal_expression(value.css, "interpolation"))
  }
  gradient(
    "conic",
    group_expression("conic-header", "", values, " ", ""),
    stops,
    repeating,
  )
}
