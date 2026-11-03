///|
pub(all) enum ColorSpace {
  Srgb
  SrgbLinear
  DisplayP3
  A98Rgb
  ProphotoRgb
  Rec2020
  XyzD50
  XyzD65
  Lab
  Oklab
  Lch
  Oklch
  Hsl
  Hwb
} derive(Eq, Debug)

///|
pub extend ColorSpace with Eq::{equal, not_equal}

///|
pub extend ColorSpace with @debug.Debug::{to_repr}

///|
pub fn ColorSpace::to_css(self : ColorSpace) -> String {
  match self {
    Srgb => "srgb"
    SrgbLinear => "srgb-linear"
    DisplayP3 => "display-p3"
    A98Rgb => "a98-rgb"
    ProphotoRgb => "prophoto-rgb"
    Rec2020 => "rec2020"
    XyzD50 => "xyz-d50"
    XyzD65 => "xyz-d65"
    Lab => "lab"
    Oklab => "oklab"
    Lch => "lch"
    Oklch => "oklch"
    Hsl => "hsl"
    Hwb => "hwb"
  }
}

///|
pub(all) enum HueInterpolation {
  Shorter
  Longer
  Increasing
  Decreasing
} derive(Eq, Debug)

///|
pub extend HueInterpolation with Eq::{equal, not_equal}

///|
pub extend HueInterpolation with @debug.Debug::{to_repr}

///|
pub struct ColorInterpolation {
  css : String
}

///|
pub fn color_interpolation(
  space : ColorSpace,
  hue? : HueInterpolation,
) -> ColorInterpolation {
  let suffix = match hue {
    None => ""
    Some(value) => {
      if !(space is (Lch | Oklch | Hsl | Hwb)) {
        return {
          css: issue_css(
            "STYLE_COLOR_HUE", "Hue interpolation requires a polar color space",
          ),
        }
      }
      " " +
      (match value {
        Shorter => "shorter"
        Longer => "longer"
        Increasing => "increasing"
        Decreasing => "decreasing"
      }) +
      " hue"
    }
  }
  { css: "in " + space.to_css() + suffix, }
}

///|
fn color_number(value : Double) -> String {
  finite(value, "color channel").to_string() catch {
    error => error_css(error)
  }
}

///|
fn absolute_color(
  name : String,
  channels : Array[String],
  alpha : Double,
) -> Color {
  let opacity = if alpha < 0.0 || alpha > 1.0 {
    issue_css(
      "STYLE_VALUE_OUT_OF_RANGE", "Color alpha must be between zero and one",
    )
  } else {
    color_number(alpha)
  }
  { css: name + "(" + channels.join(" ") + " / " + opacity + ")", }
}

///|
pub fn hwb(
  hue : Angle,
  whiteness : Percentage,
  blackness : Percentage,
  alpha~ : Double = 1.0,
) -> Color {
  absolute_color(
    "hwb",
    [hue.to_css(), whiteness.to_css(), blackness.to_css()],
    alpha,
  )
}

///|
pub fn lab(
  lightness : Double,
  a : Double,
  b : Double,
  alpha~ : Double = 1.0,
) -> Color {
  absolute_color(
    "lab",
    [color_number(lightness), color_number(a), color_number(b)],
    alpha,
  )
}

///|
pub fn lch(
  lightness : Double,
  chroma : Double,
  hue : Angle,
  alpha~ : Double = 1.0,
) -> Color {
  absolute_color(
    "lch",
    [color_number(lightness), color_number(chroma), hue.to_css()],
    alpha,
  )
}

///|
pub fn oklab(
  lightness : Double,
  a : Double,
  b : Double,
  alpha~ : Double = 1.0,
) -> Color {
  absolute_color(
    "oklab",
    [color_number(lightness), color_number(a), color_number(b)],
    alpha,
  )
}

///|
pub fn oklch(
  lightness : Double,
  chroma : Double,
  hue : Angle,
  alpha~ : Double = 1.0,
) -> Color {
  absolute_color(
    "oklch",
    [color_number(lightness), color_number(chroma), hue.to_css()],
    alpha,
  )
}

///|
pub fn color_space(
  space : ColorSpace,
  first : Double,
  second : Double,
  third : Double,
  alpha~ : Double = 1.0,
) -> Color {
  if space is (Lab | Oklab | Lch | Oklch | Hsl | Hwb) {
    return {
      css: issue_css(
        "STYLE_COLOR_SPACE", "color() requires a predefined RGB or XYZ space",
      ),
    }
  }
  absolute_color(
    "color",
    [
      space.to_css(),
      color_number(first),
      color_number(second),
      color_number(third),
    ],
    alpha,
  )
}

///|
/// Accepts the standard named colors, currentColor, transparent and CSS system colors.
pub fn named_color(name : String) -> Color {
  let names = "aliceblue antiquewhite aqua aquamarine azure beige bisque black blanchedalmond blue blueviolet brown burlywood cadetblue chartreuse chocolate coral cornflowerblue cornsilk crimson cyan darkblue darkcyan darkgoldenrod darkgray darkgreen darkgrey darkkhaki darkmagenta darkolivegreen darkorange darkorchid darkred darksalmon darkseagreen darkslateblue darkslategray darkslategrey darkturquoise darkviolet deeppink deepskyblue dimgray dimgrey dodgerblue firebrick floralwhite forestgreen fuchsia gainsboro ghostwhite gold goldenrod gray green greenyellow grey honeydew hotpink indianred indigo ivory khaki lavender lavenderblush lawngreen lemonchiffon lightblue lightcoral lightcyan lightgoldenrodyellow lightgray lightgreen lightgrey lightpink lightsalmon lightseagreen lightskyblue lightslategray lightslategrey lightsteelblue lightyellow lime limegreen linen magenta maroon mediumaquamarine mediumblue mediumorchid mediumpurple mediumseagreen mediumslateblue mediumspringgreen mediumturquoise mediumvioletred midnightblue mintcream mistyrose moccasin navajowhite navy oldlace olive olivedrab orange orangered orchid palegoldenrod palegreen paleturquoise palevioletred papayawhip peachpuff peru pink plum powderblue purple rebeccapurple red rosybrown royalblue saddlebrown salmon sandybrown seagreen seashell sienna silver skyblue slateblue slategray slategrey snow springgreen steelblue tan teal thistle tomato turquoise violet wheat white whitesmoke yellow yellowgreen transparent currentcolor accentcolor accentcolortext activetext buttonborder buttonface buttontext canvas canvastext field fieldtext graytext highlight highlighttext linktext mark marktext selecteditem selecteditemtext visitedtext"
  let normalized = name.to_lower()
  if names.split(" ").any(value => value == normalized) {
    { css: normalized, }
  } else {
    { css: issue_css("STYLE_COLOR_NAME", "Unknown CSS named or system color"), }
  }
}

///|
pub struct ColorExpr {
  expression : Expression
}

///|
pub fn ColorExpr::expression(self : ColorExpr) -> Expression {
  self.expression
}

///|
pub fn ColorExpr::to_css(self : ColorExpr) -> String {
  self.expression.to_css()
}

///|
pub impl GradientColorInput for ColorExpr with fn gradient_color(self) {
  self.expression
}

///|
pub extend ColorExpr with GradientColorInput::{gradient_color}

///|
pub fn[C : GradientColorInput] color_expression(value : C) -> ColorExpr {
  { expression: value.gradient_color(), }
}

///|
pub fn[A : GradientColorInput, B : GradientColorInput] color_mix(
  space : ColorSpace,
  first : A,
  second : B,
  first_weight? : Percentage,
  second_weight? : Percentage,
  hue? : HueInterpolation,
) -> ColorExpr {
  let interpolation = color_interpolation(space, hue?)
  let left = [first.gradient_color()]
  let right = [second.gradient_color()]
  if first_weight is Some(value) {
    left.push(
      literal_expression(value.to_css(), "percentage").constrain(
        "mix-percentage",
      ),
    )
  }
  if second_weight is Some(value) {
    right.push(
      literal_expression(value.to_css(), "percentage").constrain(
        "mix-percentage",
      ),
    )
  }
  let values = [
    literal_expression(interpolation.css, "interpolation"),
    group_expression("color", "", left, " ", ""),
    group_expression("color", "", right, " ", ""),
  ]
  if first_weight is Some(a) &&
    second_weight is Some(b) &&
    numeric_part(a.to_css(), "percentage") == Some(0.0) &&
    numeric_part(b.to_css(), "percentage") == Some(0.0) {
    values.push(
      invalid_expression(
        "STYLE_COLOR_MIX_WEIGHT", "Color mix weights must not both be zero",
      ),
    )
  }
  { expression: group_expression("color", "color-mix(", values, ", ", ")"), }
}
