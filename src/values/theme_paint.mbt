///|
pub(all) enum ColorSchemeName {
  SchemeLight
  SchemeDark
} derive(Eq, Debug)

///|
pub extend ColorSchemeName with Eq::{equal, not_equal}

///|
pub extend ColorSchemeName with @debug.Debug::{to_repr}

///|
pub struct ColorScheme {
  expression : Expression
} derive(Eq, Debug)

///|
/// Declares supported schemes in preference order. Empty lists are diagnosed
/// during extraction; repeated schemes are valid CSS and retain their order.
pub fn color_scheme(
  names : Array[ColorSchemeName],
  only~ : Bool = false,
) -> ColorScheme {
  {
    expression: if names.is_empty() {
      invalid_expression(
        "STYLE_COLOR_SCHEME", "A color scheme needs at least one supported name; use normal_color_scheme() for normal",
      )
    } else {
      literal_expression(
        names
        .map(name => {
          match name {
            SchemeLight => "light"
            SchemeDark => "dark"
          }
        })
        .join(" ") +
        (if only { " only" } else { "" }),
        "color-scheme",
      )
    },
  }
}

///|
pub fn normal_color_scheme() -> ColorScheme {
  { expression: literal_expression("normal", "color-scheme"), }
}

///|
pub fn ColorScheme::expression(self : ColorScheme) -> Expression {
  self.expression
}

///|
pub fn ColorScheme::to_css(self : ColorScheme) -> String {
  self.expression.to_css()
}

///|
pub struct ScrollbarColor {
  expression : Expression
} derive(Eq, Debug)

///|
/// The first color paints the thumb, the second the track. Both retain nested
/// color Token/Slot references and color expression identities.
pub fn[A : GradientColorInput, B : GradientColorInput] scrollbar_colors(
  thumb~ : A,
  track~ : B,
) -> ScrollbarColor {
  {
    expression: group_expression(
      "scrollbar-color",
      "",
      [thumb.gradient_color(), track.gradient_color()],
      " ",
      "",
    ),
  }
}

///|
pub fn scrollbar_auto() -> ScrollbarColor {
  { expression: literal_expression("auto", "scrollbar-color"), }
}

///|
pub fn ScrollbarColor::expression(self : ScrollbarColor) -> Expression {
  self.expression
}

///|
pub fn ScrollbarColor::to_css(self : ScrollbarColor) -> String {
  self.expression.to_css()
}

///|
/// The reviewed SVG paint subset: a color expression or none. Resource paints
/// and context paints require a separate reviewed API.
pub struct SvgPaint {
  expression : Expression
} derive(Eq, Debug)

///|
pub fn[C : GradientColorInput] paint(color : C) -> SvgPaint {
  { expression: { ..color.gradient_color(), category: "svg-paint", }, }
}

///|
pub fn paint_none() -> SvgPaint {
  { expression: literal_expression("none", "svg-paint"), }
}

///|
pub fn SvgPaint::expression(self : SvgPaint) -> Expression {
  self.expression
}

///|
pub fn SvgPaint::to_css(self : SvgPaint) -> String {
  self.expression.to_css()
}

///|
pub extend ColorScheme with Eq::{equal, not_equal}

///|
pub extend ColorScheme with @debug.Debug::{to_repr}

///|
pub extend ScrollbarColor with Eq::{equal, not_equal}

///|
pub extend ScrollbarColor with @debug.Debug::{to_repr}

///|
pub extend SvgPaint with Eq::{equal, not_equal}

///|
pub extend SvgPaint with @debug.Debug::{to_repr}
