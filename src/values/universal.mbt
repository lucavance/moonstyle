///|
pub(all) enum CssWideKeyword {
  Initial
  Inherit
  Unset
  Revert
  RevertLayer
} derive(Eq, Debug)

///|
pub extend CssWideKeyword with Eq::{equal, not_equal}

///|
pub extend CssWideKeyword with @debug.Debug::{to_repr}

///|
pub fn CssWideKeyword::to_css(self : CssWideKeyword) -> String {
  match self {
    Initial => "initial"
    Inherit => "inherit"
    Unset => "unset"
    Revert => "revert"
    RevertLayer => "revert-layer"
  }
}

///|
fn length_suffixes() -> Array[String] {
  let units : Array[LengthUnit] = [
    Px,
    Rem,
    Em,
    Ch,
    Vh,
    Vw,
    Vmin,
    Vmax,
    Svh,
    Lvh,
    Dvh,
    Cm,
    Mm,
    Q,
    In,
    Pc,
    Pt,
    Ex,
    Cap,
    Ic,
    Rex,
    Rcap,
    Rch,
    Ric,
    Lh,
    Rlh,
    Vi,
    Vb,
    Svw,
    Svi,
    Svb,
    Svmin,
    Svmax,
    Lvw,
    Lvi,
    Lvb,
    Lvmin,
    Lvmax,
    Dvw,
    Dvi,
    Dvb,
    Dvmin,
    Dvmax,
    Cqw,
    Cqh,
    Cqi,
    Cqb,
    Cqmin,
    Cqmax,
  ]
  units.map(unit => unit.suffix())
}

///|
pub(all) enum EnvironmentLength {
  SafeAreaTop
  SafeAreaRight
  SafeAreaBottom
  SafeAreaLeft
  SafeAreaMaxTop
  SafeAreaMaxRight
  SafeAreaMaxBottom
  SafeAreaMaxLeft
  ViewportSegmentWidth(Int32, Int32)
  ViewportSegmentHeight(Int32, Int32)
  ViewportSegmentTop(Int32, Int32)
  ViewportSegmentRight(Int32, Int32)
  ViewportSegmentBottom(Int32, Int32)
  ViewportSegmentLeft(Int32, Int32)
} derive(Eq, Debug)

///|
pub extend EnvironmentLength with Eq::{equal, not_equal}

///|
pub extend EnvironmentLength with @debug.Debug::{to_repr}

///|
fn segment_env(name : String, x : Int32, y : Int32) -> String {
  if x < 0 || y < 0 {
    issue_css("STYLE_ENV_INDEX", "Viewport segment indices must be nonnegative")
  } else {
    "viewport-segment-" + name + " " + x.to_string() + " " + y.to_string()
  }
}

///|
fn EnvironmentLength::name(self : EnvironmentLength) -> String {
  match self {
    SafeAreaTop => "safe-area-inset-top"
    SafeAreaRight => "safe-area-inset-right"
    SafeAreaBottom => "safe-area-inset-bottom"
    SafeAreaLeft => "safe-area-inset-left"
    SafeAreaMaxTop => "safe-area-max-inset-top"
    SafeAreaMaxRight => "safe-area-max-inset-right"
    SafeAreaMaxBottom => "safe-area-max-inset-bottom"
    SafeAreaMaxLeft => "safe-area-max-inset-left"
    ViewportSegmentWidth(x, y) => segment_env("width", x, y)
    ViewportSegmentHeight(x, y) => segment_env("height", x, y)
    ViewportSegmentTop(x, y) => segment_env("top", x, y)
    ViewportSegmentRight(x, y) => segment_env("right", x, y)
    ViewportSegmentBottom(x, y) => segment_env("bottom", x, y)
    ViewportSegmentLeft(x, y) => segment_env("left", x, y)
  }
}

///|
pub fn env_length(
  name : EnvironmentLength,
  fallback? : MathExpr[Length],
) -> MathExpr[Length] {
  math_expression(
    match fallback {
      Some(value) =>
        group_expression(
          "length",
          "env(" + name.name() + ", ",
          [value.expression],
          "",
          ")",
        )
      None => literal_expression("env(" + name.name() + ")", "length")
    },
  )
}

///|
/// Supporting builder bridge; public authoring uses the typed input traits.
pub fn declaration_expression(
  css : String,
  variable : VariableUse?,
) -> Expression {
  match variable {
    Some(value) => reference_expression(value)
    None => literal_expression(css, "declaration")
  }
}
