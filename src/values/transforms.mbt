///|
pub fn TransformList::expression(self : TransformList) -> Expression {
  self.expression
}

///|
pub fn TransformFunction::to_css(self : TransformFunction) -> String {
  self.expression.to_css()
}

///|
fn transform_function(
  name : String,
  operands : Array[Expression],
) -> TransformFunction {
  {
    expression: group_expression("transform", name + "(", operands, ", ", ")"),
  }
}

///|
pub fn[
  X : LengthPercentageMathInput,
  Y : LengthPercentageMathInput,
  Z : LengthMathInput,
] translate3d(
  x : X,
  y : Y,
  z : Z,
) -> TransformFunction {
  transform_function("translate3d", [
    x.length_percentage_math().expression,
    y.length_percentage_math().expression,
    z.length_math().expression.constrain("no-percentage"),
  ])
}

///|
pub fn[T : LengthPercentageMathInput] translate_x(
  value : T,
) -> TransformFunction {
  transform_function("translateX", [value.length_percentage_math().expression])
}

///|
pub fn[T : LengthPercentageMathInput] translate_y(
  value : T,
) -> TransformFunction {
  transform_function("translateY", [value.length_percentage_math().expression])
}

///|
pub fn[T : LengthMathInput] translate_z(value : T) -> TransformFunction {
  transform_function("translateZ", [
    value.length_math().expression.constrain("no-percentage"),
  ])
}

///|
pub fn[T : AngleMathInput] rotate_x(value : T) -> TransformFunction {
  transform_function("rotateX", [value.angle_math().expression])
}

///|
pub fn[T : AngleMathInput] rotate_y(value : T) -> TransformFunction {
  transform_function("rotateY", [value.angle_math().expression])
}

///|
pub fn[T : AngleMathInput] rotate_z(value : T) -> TransformFunction {
  transform_function("rotateZ", [value.angle_math().expression])
}

///|
pub fn[
  X : NumberMathInput,
  Y : NumberMathInput,
  Z : NumberMathInput,
  A : AngleMathInput,
] rotate3d(
  x : X,
  y : Y,
  z : Z,
  angle : A,
) -> TransformFunction {
  transform_function("rotate3d", [
    x.number_math().expression,
    y.number_math().expression,
    z.number_math().expression,
    angle.angle_math().expression,
  ])
}

///|
pub fn[X : NumberMathInput, Y : NumberMathInput, Z : NumberMathInput] scale3d(
  x : X,
  y : Y,
  z : Z,
) -> TransformFunction {
  transform_function("scale3d", [
    x.number_math().expression,
    y.number_math().expression,
    z.number_math().expression,
  ])
}

///|
pub fn[T : NumberMathInput] scale_x(value : T) -> TransformFunction {
  transform_function("scaleX", [value.number_math().expression])
}

///|
pub fn[T : NumberMathInput] scale_y(value : T) -> TransformFunction {
  transform_function("scaleY", [value.number_math().expression])
}

///|
pub fn[T : NumberMathInput] scale_z(value : T) -> TransformFunction {
  transform_function("scaleZ", [value.number_math().expression])
}

///|
pub fn[X : AngleMathInput, Y : AngleMathInput] skew(
  x : X,
  y : Y,
) -> TransformFunction {
  transform_function("skew", [
    x.angle_math().expression,
    y.angle_math().expression,
  ])
}

///|
pub fn[T : AngleMathInput] skew_x(value : T) -> TransformFunction {
  transform_function("skewX", [value.angle_math().expression])
}

///|
pub fn[T : AngleMathInput] skew_y(value : T) -> TransformFunction {
  transform_function("skewY", [value.angle_math().expression])
}

///|
pub fn[T : LengthMathInput] perspective_transform(
  value : T,
) -> TransformFunction {
  transform_function("perspective", [
    value.length_math().expression
    .constrain("nonnegative")
    .constrain("no-percentage"),
  ])
}

///|
pub fn matrix(values : Array[Number]) -> TransformFunction {
  if values.length() != 6 {
    return {
      expression: invalid_expression(
        "STYLE_TRANSFORM_MATRIX", "matrix() requires six numbers",
      ),
    }
  }
  transform_function(
    "matrix",
    values.map(value => {
      literal_expression(value.to_css(), "number").constrain("math:number")
    }),
  )
}

///|
pub fn matrix3d(values : Array[Number]) -> TransformFunction {
  if values.length() != 16 {
    return {
      expression: invalid_expression(
        "STYLE_TRANSFORM_MATRIX", "matrix3d() requires sixteen numbers",
      ),
    }
  }
  transform_function(
    "matrix3d",
    values.map(value => {
      literal_expression(value.to_css(), "number").constrain("math:number")
    }),
  )
}
