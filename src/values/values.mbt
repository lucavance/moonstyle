///|
pub struct Length {
  css : String
} derive(Eq, Debug)

///|
pub struct Color {
  css : String
} derive(Eq, Debug)

///|
pub struct Time {
  css : String
} derive(Eq, Debug)

///|
pub struct Angle {
  css : String
} derive(Eq, Debug)

///|
pub(all) enum ValueCategory {
  LengthCategory
  ColorCategory
  NumberCategory
  PercentageCategory
  LengthPercentageCategory
  IntegerCategory
  TimeCategory
  AngleCategory
  ResolutionCategory
  UrlCategory
} derive(Eq, Debug)

///|
pub fn ValueCategory::name(self : ValueCategory) -> String {
  match self {
    LengthCategory => "length"
    ColorCategory => "color"
    NumberCategory => "number"
    PercentageCategory => "percentage"
    LengthPercentageCategory => "length-percentage"
    IntegerCategory => "integer"
    TimeCategory => "time"
    AngleCategory => "angle"
    ResolutionCategory => "resolution"
    UrlCategory => "url"
  }
}

///|
pub struct CssVar[T] {
  name : String
  default_css : String
  category : ValueCategory
  registration : PropertyRegistration?
  marker : T?
}

///|
pub(all) struct VarDefinition {
  name : String
  default_css : String
  category : ValueCategory
  registration : PropertyRegistration?
} derive(Eq, Debug)

///|
pub(all) struct VarOverride {
  name : String
  value_css : String
  category : ValueCategory
} derive(Eq, Debug)

///|
/// Distinguishes a theme token from a runtime-bound custom-property slot.
pub(all) enum VariableRole {
  TokenRole
  DynamicSlotRole
} derive(Eq, Debug)

///|
/// Erased variable metadata lowered to VariableSet before extraction.
pub(all) struct VariableUse {
  scope : String
  local_name : String
  definition : VarDefinition
  role : VariableRole
} derive(Eq, Debug)

///|
pub struct Token[T] {
  variable : CssVar[T]
  scope : String
  local_name : String
}

///|
pub struct DynamicSlot[T] {
  variable : CssVar[T]
  scope : String
  local_name : String
}

///|
pub struct VariableScope {
  scope : String
}

///|
pub type LengthToken = Token[Length]

///|
pub type ColorToken = Token[Color]

///|
pub type NumberToken = Token[Number]

///|
pub type PercentageToken = Token[Percentage]

///|
pub type LengthPercentageToken = Token[LengthPercentage]

///|
pub type IntegerToken = Token[Integer]

///|
pub type TimeToken = Token[Time]

///|
pub type AngleToken = Token[Angle]

///|
pub type ResolutionToken = Token[Resolution]

///|
pub type UrlToken = Token[Url]

///|
pub type LengthSlot = DynamicSlot[Length]

///|
pub type ColorSlot = DynamicSlot[Color]

///|
pub type NumberSlot = DynamicSlot[Number]

///|
pub type PercentageSlot = DynamicSlot[Percentage]

///|
pub type LengthPercentageSlot = DynamicSlot[LengthPercentage]

///|
pub type IntegerSlot = DynamicSlot[Integer]

///|
pub type TimeSlot = DynamicSlot[Time]

///|
pub type AngleSlot = DynamicSlot[Angle]

///|
pub type ResolutionSlot = DynamicSlot[Resolution]

///|
pub type UrlSlot = DynamicSlot[Url]

///|
pub(all) struct TokenOverride {
  variable : VariableUse
  override_ : VarOverride
} derive(Eq, Debug)

///|
/// The reviewed value categories that may be used by tokens and dynamic slots.
pub trait CssValue {
  fn css_value(Self) -> String
  fn value_category(Self) -> ValueCategory
}

///|
pub struct Percentage {
  css : String
} derive(Eq, Debug)

///|
pub struct LengthPercentage {
  css : String
} derive(Eq, Debug)

///|
pub struct Number {
  css : String
} derive(Eq, Debug)

///|
pub struct Integer {
  css : String
} derive(Eq, Debug)

///|
pub struct Resolution {
  css : String
} derive(Eq, Debug)

///|
pub struct Url {
  css : String
} derive(Eq, Debug)

///|
pub(all) enum LengthUnit {
  Px
  Rem
  Em
  Ch
  Vh
  Vw
  Vmin
  Vmax
  Svh
  Lvh
  Dvh
  Cm
  Mm
  Q
  In
  Pc
  Pt
  Ex
  Cap
  Ic
  Rex
  Rcap
  Rch
  Ric
  Lh
  Rlh
  Vi
  Vb
  Svw
  Svi
  Svb
  Svmin
  Svmax
  Lvw
  Lvi
  Lvb
  Lvmin
  Lvmax
  Dvw
  Dvi
  Dvb
  Dvmin
  Dvmax
  Cqw
  Cqh
  Cqi
  Cqb
  Cqmin
  Cqmax
} derive(Eq, Debug)

///|
pub struct Ratio {
  css : String
} derive(Eq, Debug)

///|
pub struct Position {
  css : String
} derive(Eq, Debug)

///|
pub struct BackgroundSize {
  css : String
} derive(Eq, Debug)

///|
pub(all) enum RepeatStyle {
  Repeat
  NoRepeat
  RepeatX
  RepeatY
  Space
  Round
} derive(Eq, Debug)

///|
pub struct TransformFunction {
  expression : Expression
} derive(Eq, Debug)

///|
pub struct TransformList {
  expression : Expression
} derive(Eq, Debug)

///|
pub struct TransformOrigin {
  css : String
} derive(Eq, Debug)

///|
pub struct EasingFunction {
  css : String
} derive(Eq, Debug)

///|
pub struct GridTrack {
  css : String
  expression : Expression
  kind : TrackKind
} derive(Eq, Debug)

///|
pub struct GridTrackList {
  css : String
  expression : Expression
  tracks : Array[GridTrack]
  subgrid : Bool
} derive(Eq, Debug)

///|
pub struct GridLine {
  css : String
} derive(Eq, Debug)

///|
pub(all) enum TouchActionPart {
  PanX
  PanY
  PinchZoom
} derive(Eq, Debug)

///|
pub struct TouchAction {
  css : String
} derive(Eq, Debug)

///|
pub(all) enum ContainPart {
  Size
  InlineSize
  Layout
  Style
  Paint
} derive(Eq, Debug)

///|
pub struct Contain {
  css : String
} derive(Eq, Debug)

///|
pub(all) enum FontVariantNumericPart {
  LiningNums
  OldstyleNums
  ProportionalNums
  TabularNums
  DiagonalFractions
  StackedFractions
  Ordinal
  SlashedZero
} derive(Eq, Debug)

///|
pub struct FontVariantNumeric {
  css : String
} derive(Eq, Debug)

///|
pub(all) enum LineWidthKeyword {
  LineWidthThin
  LineWidthMedium
  LineWidthThick
} derive(Eq, Debug)

///|
pub struct LineWidth {
  css : String
} derive(Eq, Debug)

///|
pub(all) enum LineStyle {
  LineStyleNone
  LineStyleHidden
  LineStyleDotted
  LineStyleDashed
  LineStyleSolid
  LineStyleDouble
  LineStyleGroove
  LineStyleRidge
  LineStyleInset
  LineStyleOutset
} derive(Eq, Debug)

///|
pub struct CornerRadius {
  expression : Expression
  horizontal : Expression
} derive(Eq, Debug)

///|
pub struct BorderSide {
  css : String
} derive(Eq, Debug)

///|
pub struct BorderWidths {
  css : String
} derive(Eq, Debug)

///|
pub struct BorderStyles {
  css : String
} derive(Eq, Debug)

///|
pub struct BorderColors {
  css : String
} derive(Eq, Debug)

///|
pub struct OutlineColor {
  css : String
} derive(Eq, Debug)

///|
pub(all) enum OutlineStyle {
  OutlineStyleNone
  OutlineStyleAuto
  OutlineStyleDotted
  OutlineStyleDashed
  OutlineStyleSolid
  OutlineStyleDouble
  OutlineStyleGroove
  OutlineStyleRidge
  OutlineStyleInset
  OutlineStyleOutset
} derive(Eq, Debug)

///|
pub struct Outline {
  css : String
} derive(Eq, Debug)

///|
pub(all) suberror ValueError {
  NonFinite(String)
  OutOfRange(String)
  EmptyUrl
  InvalidUrl
  EmptyValue(String)
  InvalidValue(String)
  InvalidCustomPropertyName(String)
} derive(Eq, Debug)

///|
pub(all) struct ValueIssue {
  code : String
  label : String
} derive(Eq, Debug)

///|
const VALUE_ISSUE_PREFIX : String = "__LAMPCLAW_VALUE_ISSUE__["

///|
const VALUE_ISSUE_SUFFIX : String = "]__"

///|
fn issue_css(code : String, label : String) -> String {
  VALUE_ISSUE_PREFIX + code + "|" + label + VALUE_ISSUE_SUFFIX
}

///|
fn error_css(error : ValueError) -> String {
  match error {
    NonFinite(label) => issue_css("STYLE_VALUE_NON_FINITE", label)
    OutOfRange(label) => issue_css("STYLE_VALUE_OUT_OF_RANGE", label)
    EmptyUrl => issue_css("STYLE_VALUE_EMPTY", "url")
    InvalidUrl => issue_css("STYLE_URL_INVALID", "url")
    EmptyValue(label) => issue_css("STYLE_VALUE_EMPTY", label)
    InvalidValue(label) => issue_css("STYLE_VALUE_INVALID", label)
    InvalidCustomPropertyName(label) => issue_css("STYLE_VARIABLE_NAME", label)
  }
}

///|
pub fn value_issues(css : String) -> Array[ValueIssue] {
  let issues : Array[ValueIssue] = []
  let segments = css.split(VALUE_ISSUE_PREFIX).to_array()
  for index = 1; index < segments.length(); index = index + 1 {
    let segment = segments[index].to_owned()
    match segment.find(VALUE_ISSUE_SUFFIX) {
      Some(end) => {
        let payload = segment[:end].to_owned()
        match payload.find("|") {
          Some(separator) =>
            issues.push({
              code: payload[:separator].to_owned(),
              label: payload[separator + 1:].to_owned(),
            })
          None => ()
        }
      }
      None => ()
    }
  }
  issues
}

///|
/// Adds constraints belonging to an individual property without narrowing the
/// shared value category. Negative percentages remain valid for other uses.
pub fn property_value_issues(
  property : String,
  css : String,
) -> Array[ValueIssue] {
  let issues = value_issues(css)
  if !issues.is_empty() {
    return issues
  }
  let value = css.trim().to_owned()
  if common_value_property(property) {
    if value.has_prefix("-") {
      issues.push({
        code: "STYLE_VALUE_OUT_OF_RANGE",
        label: property + " must be nonnegative",
      })
    }
    if !common_property_keyword_valid(property, value) {
      issues.push({
        code: "STYLE_VALUE_KEYWORD",
        label: "Invalid keyword for " + property,
      })
    }
    return issues
  }
  if property != "fontWidth" && property != "font-width" {
    return issues
  }
  if !value.has_suffix("%") {
    return issues
  }
  let percentage = @string.parse_double(value[:value.length() - 1]) catch {
    _ => {
      issues.push({
        code: "STYLE_VALUE_INVALID",
        label: "font-width percentage",
      })
      return issues
    }
  }
  if percentage.is_nan() || percentage.is_pos_inf() || percentage.is_neg_inf() {
    issues.push({
      code: "STYLE_VALUE_NON_FINITE",
      label: "font-width percentage",
    })
  } else if percentage < 0 {
    issues.push({
      code: "STYLE_VALUE_OUT_OF_RANGE",
      label: "font-width percentage",
    })
  }
  issues
}

///|
fn finite(value : Double, label : String) -> Double raise ValueError {
  if value.is_nan() || value.is_pos_inf() || value.is_neg_inf() {
    raise NonFinite(label)
  }
  value
}

///|
pub fn px(value : Int32) -> Length {
  { css: if value == 0 { "0" } else { value.to_string() + "px" }, }
}

///|
fn LengthUnit::suffix(self : LengthUnit) -> String {
  match self {
    Px => "px"
    Rem => "rem"
    Em => "em"
    Ch => "ch"
    Vh => "vh"
    Vw => "vw"
    Vmin => "vmin"
    Vmax => "vmax"
    Svh => "svh"
    Lvh => "lvh"
    Dvh => "dvh"
    Cm => "cm"
    Mm => "mm"
    Q => "Q"
    In => "in"
    Pc => "pc"
    Pt => "pt"
    Ex => "ex"
    Cap => "cap"
    Ic => "ic"
    Rex => "rex"
    Rcap => "rcap"
    Rch => "rch"
    Ric => "ric"
    Lh => "lh"
    Rlh => "rlh"
    Vi => "vi"
    Vb => "vb"
    Svw => "svw"
    Svi => "svi"
    Svb => "svb"
    Svmin => "svmin"
    Svmax => "svmax"
    Lvw => "lvw"
    Lvi => "lvi"
    Lvb => "lvb"
    Lvmin => "lvmin"
    Lvmax => "lvmax"
    Dvw => "dvw"
    Dvi => "dvi"
    Dvb => "dvb"
    Dvmin => "dvmin"
    Dvmax => "dvmax"
    Cqw => "cqw"
    Cqh => "cqh"
    Cqi => "cqi"
    Cqb => "cqb"
    Cqmin => "cqmin"
    Cqmax => "cqmax"
  }
}

///|
pub fn length(value : Double, unit : LengthUnit) -> Length raise ValueError {
  let value = finite(value, "length")
  { css: if value == 0.0 { "0" } else { value.to_string() + unit.suffix() }, }
}

///|
pub fn rem(value : Double) -> Length raise ValueError {
  length(value, Rem)
}

///|
pub fn em(value : Double) -> Length raise ValueError {
  length(value, Em)
}

///|
pub fn ch(value : Double) -> Length raise ValueError {
  length(value, Ch)
}

///|
pub fn vmin(value : Double) -> Length raise ValueError {
  length(value, Vmin)
}

///|
pub fn vmax(value : Double) -> Length raise ValueError {
  length(value, Vmax)
}

///|
pub fn svh(value : Double) -> Length raise ValueError {
  length(value, Svh)
}

///|
pub fn lvh(value : Double) -> Length raise ValueError {
  length(value, Lvh)
}

///|
pub fn dvh(value : Double) -> Length raise ValueError {
  length(value, Dvh)
}

///|
pub fn percent(value : Int32) -> Length {
  { css: value.to_string() + "%", }
}

///|
pub fn vh(value : Int32) -> Length {
  { css: if value == 0 { "0" } else { value.to_string() + "vh" }, }
}

///|
pub fn vw(value : Int32) -> Length {
  { css: if value == 0 { "0" } else { value.to_string() + "vw" }, }
}

///|
pub fn zero() -> Length {
  { css: "0", }
}

///|
pub fn auto() -> Length {
  { css: "auto", }
}

///|
pub fn rgb(red : Int32, green : Int32, blue : Int32) -> Color {
  {
    css: "rgb(" +
    red.to_string() +
    " " +
    green.to_string() +
    " " +
    blue.to_string() +
    ")",
  }
}

///|
pub fn rgba(
  red : Int32,
  green : Int32,
  blue : Int32,
  alpha : Double,
) -> Color raise ValueError {
  let alpha = finite(alpha, "alpha")
  if alpha < 0.0 || alpha > 1.0 {
    raise OutOfRange("alpha")
  }
  {
    css: "rgb(" +
    red.to_string() +
    " " +
    green.to_string() +
    " " +
    blue.to_string() +
    " / " +
    alpha.to_string() +
    ")",
  }
}

///|
pub fn transparent() -> Color {
  { css: "transparent", }
}

///|
fn valid_hex_digit(value : Int32) -> Bool {
  (value >= 48 && value <= 57) ||
  (value >= 65 && value <= 70) ||
  (value >= 97 && value <= 102)
}

///|
pub fn hex_color(value : String) -> Color raise ValueError {
  let value = value.trim().to_owned()
  let digits = if value.has_prefix("#") { value[1:].to_owned() } else { value }
  if digits.length() != 3 &&
    digits.length() != 4 &&
    digits.length() != 6 &&
    digits.length() != 8 {
    raise InvalidValue("hex-color")
  }
  for i = 0; i < digits.length(); i = i + 1 {
    if !valid_hex_digit(digits.unsafe_get(i).to_int()) {
      raise InvalidValue("hex-color")
    }
  }
  { css: "#" + digits, }
}

///|
pub fn hsl(
  hue : Double,
  saturation : Double,
  lightness : Double,
) -> Color raise ValueError {
  let hue = finite(hue, "hue")
  let saturation = finite(saturation, "saturation")
  let lightness = finite(lightness, "lightness")
  if saturation < 0.0 ||
    saturation > 100.0 ||
    lightness < 0.0 ||
    lightness > 100.0 {
    raise OutOfRange("hsl")
  }
  {
    css: "hsl(" +
    hue.to_string() +
    " " +
    saturation.to_string() +
    "% " +
    lightness.to_string() +
    "%)",
  }
}

///|
pub fn ms(value : Int32) -> Time {
  { css: value.to_string() + "ms", }
}

///|
pub fn seconds(value : Double) -> Time raise ValueError {
  { css: finite(value, "seconds").to_string() + "s", }
}

///|
pub fn deg(value : Double) -> Angle raise ValueError {
  { css: finite(value, "degrees").to_string() + "deg", }
}

///|
pub fn turn(value : Double) -> Angle raise ValueError {
  { css: finite(value, "turns").to_string() + "turn", }
}

///|
pub fn percentage(value : Double) -> Percentage raise ValueError {
  { css: finite(value, "percentage").to_string() + "%", }
}

///|
pub fn length_percentage_from_length(value : Length) -> LengthPercentage {
  { css: value.css, }
}

///|
pub fn length_percentage_from_percentage(
  value : Percentage,
) -> LengthPercentage {
  { css: value.css, }
}

///|
pub fn Length::as_length_percentage(self : Length) -> LengthPercentage {
  length_percentage_from_length(self)
}

///|
pub fn Percentage::as_length_percentage(self : Percentage) -> LengthPercentage {
  length_percentage_from_percentage(self)
}

///|
pub fn number(value : Double) -> Number raise ValueError {
  { css: finite(value, "number").to_string(), }
}

///|
pub fn integer(value : Int32) -> Integer {
  { css: value.to_string(), }
}

///|
pub fn dpi(value : Double) -> Resolution raise ValueError {
  let value = finite(value, "resolution")
  if value <= 0.0 {
    raise OutOfRange("resolution")
  }
  { css: value.to_string() + "dpi", }
}

///|
pub fn dppx(value : Double) -> Resolution raise ValueError {
  let value = finite(value, "resolution")
  if value <= 0.0 {
    raise OutOfRange("resolution")
  }
  { css: value.to_string() + "dppx", }
}

///|
pub fn url(value : String) -> Url raise ValueError {
  let value = value.trim().to_owned()
  if value.is_empty() {
    raise EmptyUrl
  }
  if value.contains("\"") ||
    value.contains("\\") ||
    value.contains("{") ||
    value.contains("}") ||
    value.contains("\n") ||
    value.contains("\r") {
    raise InvalidUrl
  }
  { css: "url(\"" + value + "\")", }
}

///|
pub fn ratio(width : Int32, height : Int32) -> Ratio raise ValueError {
  if width <= 0 || height <= 0 {
    raise OutOfRange("ratio")
  }
  { css: width.to_string() + " / " + height.to_string(), }
}

///|
pub fn ratio_auto() -> Ratio {
  { css: "auto", }
}

///|
pub fn position(x : LengthPercentage, y : LengthPercentage) -> Position {
  { css: x.css + " " + y.css, }
}

///|
pub fn position_center() -> Position {
  { css: "center", }
}

///|
pub fn background_cover() -> BackgroundSize {
  { css: "cover", }
}

///|
pub fn background_contain() -> BackgroundSize {
  { css: "contain", }
}

///|
pub fn background_size(
  width : LengthPercentage,
  height : LengthPercentage,
) -> BackgroundSize {
  { css: width.css + " " + height.css, }
}

///|
pub fn RepeatStyle::to_css(self : RepeatStyle) -> String {
  match self {
    Repeat => "repeat"
    NoRepeat => "no-repeat"
    RepeatX => "repeat-x"
    RepeatY => "repeat-y"
    Space => "space"
    Round => "round"
  }
}

///|
pub fn translate(
  x : LengthPercentage,
  y : LengthPercentage,
) -> TransformFunction {
  {
    expression: literal_expression(
      "translate(" + x.css + ", " + y.css + ")",
      "transform",
    ),
  }
}

///|
pub fn rotate_transform(value : Angle) -> TransformFunction {
  { expression: literal_expression("rotate(" + value.css + ")", "transform"), }
}

///|
pub fn scale_transform(
  x : Double,
  y~ : Double? = None,
) -> TransformFunction raise ValueError {
  let x = finite(x, "scale-x")
  let values = match y {
    Some(value) => x.to_string() + ", " + finite(value, "scale-y").to_string()
    None => x.to_string()
  }
  { expression: literal_expression("scale(" + values + ")", "transform"), }
}

///|
pub fn transform_list(
  functions : Array[TransformFunction],
) -> TransformList raise ValueError {
  if functions.is_empty() {
    raise EmptyValue("transform-list")
  }
  {
    expression: group_expression(
      "transform",
      "",
      functions.map(item => item.expression),
      " ",
      "",
    ),
  }
}

///|
pub fn transform_none() -> TransformList {
  { expression: literal_expression("none", "transform"), }
}

///|
pub fn transform_origin(
  position : Position,
  z~ : Length? = None,
) -> TransformOrigin {
  let suffix = match z {
    Some(value) => " " + value.css
    None => ""
  }
  { css: position.css + suffix, }
}

///|
pub fn ease() -> EasingFunction {
  { css: "ease", }
}

///|
pub fn linear_easing() -> EasingFunction {
  { css: "linear", }
}

///|
pub fn cubic_bezier(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> EasingFunction raise ValueError {
  let x1 = finite(x1, "x1")
  let y1 = finite(y1, "y1")
  let x2 = finite(x2, "x2")
  let y2 = finite(y2, "y2")
  if x1 < 0.0 || x1 > 1.0 || x2 < 0.0 || x2 > 1.0 {
    raise OutOfRange("cubic-bezier-x")
  }
  {
    css: "cubic-bezier(" +
    [x1, y1, x2, y2].map(value => value.to_string()).join(", ") +
    ")",
  }
}

///|
pub fn steps(
  count : Int32,
  at_start~ : Bool = false,
) -> EasingFunction raise ValueError {
  if count <= 0 {
    raise OutOfRange("steps")
  }
  {
    css: "steps(" +
    count.to_string() +
    ", " +
    (if at_start { "start" } else { "end" }) +
    ")",
  }
}

///|
pub fn fr(value : Double) -> GridTrack raise ValueError {
  let value = finite(value, "fr")
  if value < 0.0 {
    raise OutOfRange("fr")
  }
  make_track(
    literal_expression(value.to_string() + "fr", "grid-track"),
    Flexible,
  )
}

///|
pub fn[T : LengthPercentageMathInput] track_length(value : T) -> GridTrack {
  make_track(
    value.length_percentage_math().expression.constrain("nonnegative"),
    Fixed,
  )
}

///|
pub fn minmax(minimum : GridTrack, maximum : GridTrack) -> GridTrack {
  if !minimum.is_breadth() || !maximum.is_breadth() || minimum.kind == Flexible {
    return invalid_track(
      "minmax requires an inflexible minimum and track breadth maximum",
    )
  }
  make_track(
    group_expression(
      "grid-track",
      "minmax(",
      [minimum.expression, maximum.expression],
      ", ",
      ")",
    ),
    MinMax(minimum.is_fixed() || maximum.is_fixed()),
  )
}

///|
pub fn grid_tracks(tracks : Array[GridTrack]) -> GridTrackList raise ValueError {
  if tracks.is_empty() {
    raise EmptyValue("grid-tracks")
  }
  make_tracks(tracks)
}

///|
pub fn repeat_tracks(
  count : Int32,
  tracks : GridTrackList,
) -> GridTrack raise ValueError {
  if count <= 0 {
    raise OutOfRange("repeat-tracks")
  }
  make_repeat(count.to_string(), tracks, false)
}

///|
pub fn grid_auto() -> GridLine {
  { css: "auto", }
}

///|
pub fn grid_line(value : Int32) -> GridLine raise ValueError {
  if value == 0 {
    raise OutOfRange("grid-line")
  }
  { css: value.to_string(), }
}

///|
pub fn grid_span(value : Int32) -> GridLine raise ValueError {
  if value <= 0 {
    raise OutOfRange("grid-span")
  }
  { css: "span " + value.to_string(), }
}

///|
pub fn named_grid_line(value : String) -> GridLine raise ValueError {
  let value = value.trim().to_owned()
  if !valid_name_part(value) {
    raise InvalidValue("grid-line-name")
  }
  { css: value, }
}

///|
pub fn touch_auto() -> TouchAction {
  { css: "auto", }
}

///|
pub fn touch_none() -> TouchAction {
  { css: "none", }
}

///|
pub fn touch_action(
  parts : Array[TouchActionPart],
) -> TouchAction raise ValueError {
  if parts.is_empty() {
    raise EmptyValue("touch-action")
  }
  let values : Array[String] = []
  for part in parts {
    let value = match part {
      PanX => "pan-x"
      PanY => "pan-y"
      PinchZoom => "pinch-zoom"
    }
    if !values.contains(value) {
      values.push(value)
    }
  }
  { css: values.join(" "), }
}

///|
pub fn contain_none() -> Contain {
  { css: "none", }
}

///|
pub fn contain_strict() -> Contain {
  { css: "strict", }
}

///|
pub fn contain(parts : Array[ContainPart]) -> Contain raise ValueError {
  if parts.is_empty() {
    raise EmptyValue("contain")
  }
  let values : Array[String] = []
  for part in parts {
    let value = match part {
      Size => "size"
      InlineSize => "inline-size"
      Layout => "layout"
      Style => "style"
      Paint => "paint"
    }
    if !values.contains(value) {
      values.push(value)
    }
  }
  { css: values.join(" "), }
}

///|
pub fn font_variant_numeric_normal() -> FontVariantNumeric {
  { css: "normal", }
}

///|
pub fn font_variant_numeric(
  parts : Array[FontVariantNumericPart],
) -> FontVariantNumeric raise ValueError {
  if parts.is_empty() {
    raise EmptyValue("font-variant-numeric")
  }
  let values : Array[String] = []
  for part in parts {
    let value = match part {
      LiningNums => "lining-nums"
      OldstyleNums => "oldstyle-nums"
      ProportionalNums => "proportional-nums"
      TabularNums => "tabular-nums"
      DiagonalFractions => "diagonal-fractions"
      StackedFractions => "stacked-fractions"
      Ordinal => "ordinal"
      SlashedZero => "slashed-zero"
    }
    if !values.contains(value) {
      values.push(value)
    }
  }
  { css: values.join(" "), }
}

///|
fn non_negative_dimension_css(value : String) -> Bool {
  !value.is_empty() &&
  value != "auto" &&
  !value.has_prefix("-") &&
  !value.has_prefix("var(") &&
  value.unsafe_get(value.length() - 1).to_int() != 37
}

///|
pub fn line_width_from_length(value : Length) -> LineWidth raise ValueError {
  if !non_negative_dimension_css(value.css) {
    raise InvalidValue("line-width")
  }
  { css: value.css, }
}

///|
pub fn Length::as_line_width(self : Length) -> LineWidth {
  authored_line_width_from_length(self)
}

///|
pub fn line_width_keyword(value : LineWidthKeyword) -> LineWidth {
  {
    css: match value {
      LineWidthThin => "thin"
      LineWidthMedium => "medium"
      LineWidthThick => "thick"
    },
  }
}

///|
pub fn LineStyle::to_css(self : LineStyle) -> String {
  match self {
    LineStyleNone => "none"
    LineStyleHidden => "hidden"
    LineStyleDotted => "dotted"
    LineStyleDashed => "dashed"
    LineStyleSolid => "solid"
    LineStyleDouble => "double"
    LineStyleGroove => "groove"
    LineStyleRidge => "ridge"
    LineStyleInset => "inset"
    LineStyleOutset => "outset"
  }
}

///|
pub fn[T : BoxSizeValueInput] corner_radius(
  horizontal : T,
  vertical~ : LengthPercentage? = None,
) -> CornerRadius {
  let horizontal = radius_operand(horizontal.value_expression())
  let value : CornerRadius = { expression: horizontal, horizontal, }
  match vertical {
    Some(vertical) => value.vertical(vertical)
    None => value
  }
}

///|
pub fn border_side(
  width~ : LineWidth? = None,
  style~ : LineStyle? = None,
  color~ : Color? = None,
) -> BorderSide raise ValueError {
  let values : Array[String] = []
  match width {
    Some(value) => values.push(value.css)
    None => ()
  }
  match style {
    Some(value) => values.push(value.to_css())
    None => ()
  }
  match color {
    Some(value) => values.push(value.css)
    None => ()
  }
  if values.is_empty() {
    raise EmptyValue("border-side")
  }
  { css: values.join(" "), }
}

///|
pub fn border_widths(
  first : LineWidth,
  second~ : LineWidth? = None,
) -> BorderWidths {
  {
    css: match second {
      Some(value) => first.css + " " + value.css
      None => first.css
    },
  }
}

///|
pub fn border_styles(
  first : LineStyle,
  second~ : LineStyle? = None,
) -> BorderStyles {
  {
    css: match second {
      Some(value) => first.to_css() + " " + value.to_css()
      None => first.to_css()
    },
  }
}

///|
pub fn border_colors(first : Color, second~ : Color? = None) -> BorderColors {
  {
    css: match second {
      Some(value) => first.css + " " + value.css
      None => first.css
    },
  }
}

///|
pub fn outline_color_from_color(value : Color) -> OutlineColor {
  { css: value.css, }
}

///|
pub fn Color::as_outline_color(self : Color) -> OutlineColor {
  outline_color_from_color(self)
}

///|
pub fn outline_auto_color() -> OutlineColor {
  { css: "auto", }
}

///|
pub fn OutlineStyle::to_css(self : OutlineStyle) -> String {
  match self {
    OutlineStyleNone => "none"
    OutlineStyleAuto => "auto"
    OutlineStyleDotted => "dotted"
    OutlineStyleDashed => "dashed"
    OutlineStyleSolid => "solid"
    OutlineStyleDouble => "double"
    OutlineStyleGroove => "groove"
    OutlineStyleRidge => "ridge"
    OutlineStyleInset => "inset"
    OutlineStyleOutset => "outset"
  }
}

///|
pub fn outline(
  width~ : LineWidth? = None,
  style~ : OutlineStyle? = None,
  color~ : OutlineColor? = None,
) -> Outline raise ValueError {
  let values : Array[String] = []
  match width {
    Some(value) => values.push(value.css)
    None => ()
  }
  match style {
    Some(value) => values.push(value.to_css())
    None => ()
  }
  match color {
    Some(value) => values.push(value.css)
    None => ()
  }
  if values.is_empty() {
    raise EmptyValue("outline")
  }
  { css: values.join(" "), }
}

///|
fn valid_name_part(value : String) -> Bool {
  if value.is_empty() {
    return false
  }
  let mut has_letter = false
  for i = 0; i < value.length(); i = i + 1 {
    let code = value.unsafe_get(i).to_int()
    if code >= 97 && code <= 122 {
      has_letter = true
    } else if !(code >= 48 && code <= 57) && code != 45 {
      return false
    }
  }
  has_letter
}

///|
fn[T] scoped_var(
  scope : String,
  name : String,
  default_css : String,
  category : ValueCategory,
) -> CssVar[T] raise ValueError {
  let scope = scope.trim().to_owned()
  let name = name.trim().to_owned()
  if !valid_name_part(scope) || !valid_name_part(name) {
    raise InvalidCustomPropertyName(scope + ":" + name)
  }
  {
    name: "--" + scope + "-" + name,
    default_css,
    category,
    registration: None,
    marker: None,
  }
}

///|
pub fn length_var(
  scope : String,
  name : String,
  default : Length,
) -> CssVar[Length] raise ValueError {
  scoped_var(scope, name, default.css, LengthCategory)
}

///|
pub fn color_var(
  scope : String,
  name : String,
  default : Color,
) -> CssVar[Color] raise ValueError {
  scoped_var(scope, name, default.css, ColorCategory)
}

///|
pub fn number_var(
  scope : String,
  name : String,
  default : Number,
) -> CssVar[Number] raise ValueError {
  scoped_var(scope, name, default.css, NumberCategory)
}

///|
pub fn percentage_var(
  scope : String,
  name : String,
  default : Percentage,
) -> CssVar[Percentage] raise ValueError {
  scoped_var(scope, name, default.css, PercentageCategory)
}

///|
pub fn[T] CssVar::definition(self : CssVar[T]) -> VarDefinition {
  {
    name: self.name,
    default_css: self.default_css,
    category: self.category,
    registration: self.registration,
  }
}

///|
pub fn override_length(
  variable : CssVar[Length],
  value : Length,
) -> VarOverride {
  { name: variable.name, value_css: value.css, category: LengthCategory, }
}

///|
pub fn override_color(variable : CssVar[Color], value : Color) -> VarOverride {
  { name: variable.name, value_css: value.css, category: ColorCategory, }
}

///|
pub fn override_number(
  variable : CssVar[Number],
  value : Number,
) -> VarOverride {
  { name: variable.name, value_css: value.css, category: NumberCategory, }
}

///|
pub fn override_percentage(
  variable : CssVar[Percentage],
  value : Percentage,
) -> VarOverride {
  { name: variable.name, value_css: value.css, category: PercentageCategory, }
}

///|
pub fn Length::to_css(self : Length) -> String {
  self.css
}

///|
pub fn Color::to_css(self : Color) -> String {
  self.css
}

///|
pub fn Time::to_css(self : Time) -> String {
  self.css
}

///|
pub fn Angle::to_css(self : Angle) -> String {
  self.css
}

///|
pub fn Percentage::to_css(self : Percentage) -> String {
  self.css
}

///|
pub fn LengthPercentage::to_css(self : LengthPercentage) -> String {
  self.css
}

///|
pub fn Number::to_css(self : Number) -> String {
  self.css
}

///|
pub fn Integer::to_css(self : Integer) -> String {
  self.css
}

///|
pub fn Resolution::to_css(self : Resolution) -> String {
  self.css
}

///|
pub fn Url::to_css(self : Url) -> String {
  self.css
}

///|
pub fn Ratio::to_css(self : Ratio) -> String {
  self.css
}

///|
pub fn Position::to_css(self : Position) -> String {
  self.css
}

///|
pub fn BackgroundSize::to_css(self : BackgroundSize) -> String {
  self.css
}

///|
pub fn TransformList::to_css(self : TransformList) -> String {
  self.expression.to_css()
}

///|
pub fn TransformOrigin::to_css(self : TransformOrigin) -> String {
  self.css
}

///|
pub fn EasingFunction::to_css(self : EasingFunction) -> String {
  self.css
}

///|
pub fn GridTrackList::to_css(self : GridTrackList) -> String {
  self.css
}

///|
pub fn GridLine::to_css(self : GridLine) -> String {
  self.css
}

///|
pub fn TouchAction::to_css(self : TouchAction) -> String {
  self.css
}

///|
pub fn Contain::to_css(self : Contain) -> String {
  self.css
}

///|
pub fn FontVariantNumeric::to_css(self : FontVariantNumeric) -> String {
  self.css
}

///|
pub fn LineWidth::to_css(self : LineWidth) -> String {
  self.css
}

///|
pub fn CornerRadius::to_css(self : CornerRadius) -> String {
  self.expression.to_css()
}

///|
pub fn BorderSide::to_css(self : BorderSide) -> String {
  self.css
}

///|
pub fn BorderWidths::to_css(self : BorderWidths) -> String {
  self.css
}

///|
pub fn BorderStyles::to_css(self : BorderStyles) -> String {
  self.css
}

///|
pub fn BorderColors::to_css(self : BorderColors) -> String {
  self.css
}

///|
pub fn OutlineColor::to_css(self : OutlineColor) -> String {
  self.css
}

///|
pub fn Outline::to_css(self : Outline) -> String {
  self.css
}

///|
pub fn[T] CssVar::name(self : CssVar[T]) -> String {
  self.name
}

///|
pub fn[T] CssVar::default_css(self : CssVar[T]) -> String {
  self.default_css
}

///|
pub fn var_length(value : CssVar[Length]) -> Length {
  { css: "var(" + value.name + ")", }
}

///|
pub fn var_color(value : CssVar[Color]) -> Color {
  { css: "var(" + value.name + ")", }
}

///|
fn[T] authored_scoped_var(
  scope : String,
  name : String,
  default_css : String,
  category : ValueCategory,
) -> CssVar[T] {
  scoped_var(scope, name, default_css, category) catch {
    error =>
      {
        name: "--invalid-variable",
        default_css: error_css(error),
        category,
        registration: None,
        marker: None,
      }
  }
}

///|
fn[T] token(
  scope : String,
  name : String,
  default_css : String,
  category : ValueCategory,
) -> Token[T] {
  {
    variable: authored_scoped_var(scope, name, default_css, category),
    scope: scope.trim().to_owned(),
    local_name: name.trim().to_owned(),
  }
}

///|
fn[T] dynamic_slot(
  scope : String,
  name : String,
  default_css : String,
  category : ValueCategory,
) -> DynamicSlot[T] {
  {
    variable: authored_scoped_var(scope, name, default_css, category),
    scope: scope.trim().to_owned(),
    local_name: name.trim().to_owned(),
  }
}

///|
pub fn variable_scope(scope : String) -> VariableScope {
  { scope, }
}

///|
pub fn length_token(
  scope : String,
  name : String,
  default : Length,
) -> Token[Length] {
  token(scope, name, default.css, LengthCategory)
}

///|
pub fn color_token(
  scope : String,
  name : String,
  default : Color,
) -> Token[Color] {
  token(scope, name, default.css, ColorCategory)
}

///|
pub fn number_token(
  scope : String,
  name : String,
  default : Number,
) -> Token[Number] {
  token(scope, name, default.css, NumberCategory)
}

///|
pub fn percentage_token(
  scope : String,
  name : String,
  default : Percentage,
) -> Token[Percentage] {
  token(scope, name, default.css, PercentageCategory)
}

///|
pub fn length_percentage_token(
  scope : String,
  name : String,
  default : LengthPercentage,
) -> Token[LengthPercentage] {
  token(scope, name, default.css, LengthPercentageCategory)
}

///|
pub fn integer_token(
  scope : String,
  name : String,
  default : Integer,
) -> Token[Integer] {
  token(scope, name, default.css, IntegerCategory)
}

///|
pub fn time_token(scope : String, name : String, default : Time) -> Token[Time] {
  token(scope, name, default.css, TimeCategory)
}

///|
pub fn angle_token(
  scope : String,
  name : String,
  default : Angle,
) -> Token[Angle] {
  token(scope, name, default.css, AngleCategory)
}

///|
pub fn resolution_token(
  scope : String,
  name : String,
  default : Resolution,
) -> Token[Resolution] {
  token(scope, name, default.css, ResolutionCategory)
}

///|
pub fn url_token(scope : String, name : String, default : Url) -> Token[Url] {
  token(scope, name, default.css, UrlCategory)
}

///|
pub fn length_slot(
  scope : String,
  name : String,
  default : Length,
) -> DynamicSlot[Length] {
  dynamic_slot(scope, name, default.css, LengthCategory)
}

///|
pub fn color_slot(
  scope : String,
  name : String,
  default : Color,
) -> DynamicSlot[Color] {
  dynamic_slot(scope, name, default.css, ColorCategory)
}

///|
pub fn number_slot(
  scope : String,
  name : String,
  default : Number,
) -> DynamicSlot[Number] {
  dynamic_slot(scope, name, default.css, NumberCategory)
}

///|
pub fn percentage_slot(
  scope : String,
  name : String,
  default : Percentage,
) -> DynamicSlot[Percentage] {
  dynamic_slot(scope, name, default.css, PercentageCategory)
}

///|
pub fn length_percentage_slot(
  scope : String,
  name : String,
  default : LengthPercentage,
) -> DynamicSlot[LengthPercentage] {
  dynamic_slot(scope, name, default.css, LengthPercentageCategory)
}

///|
pub fn integer_slot(
  scope : String,
  name : String,
  default : Integer,
) -> DynamicSlot[Integer] {
  dynamic_slot(scope, name, default.css, IntegerCategory)
}

///|
pub fn time_slot(
  scope : String,
  name : String,
  default : Time,
) -> DynamicSlot[Time] {
  dynamic_slot(scope, name, default.css, TimeCategory)
}

///|
pub fn angle_slot(
  scope : String,
  name : String,
  default : Angle,
) -> DynamicSlot[Angle] {
  dynamic_slot(scope, name, default.css, AngleCategory)
}

///|
pub fn resolution_slot(
  scope : String,
  name : String,
  default : Resolution,
) -> DynamicSlot[Resolution] {
  dynamic_slot(scope, name, default.css, ResolutionCategory)
}

///|
pub fn url_slot(
  scope : String,
  name : String,
  default : Url,
) -> DynamicSlot[Url] {
  dynamic_slot(scope, name, default.css, UrlCategory)
}

///|
pub fn VariableScope::length_token(
  self : VariableScope,
  name : String,
  default : Length,
) -> LengthToken {
  length_token(self.scope, name, default)
}

///|
pub fn VariableScope::color_token(
  self : VariableScope,
  name : String,
  default : Color,
) -> ColorToken {
  color_token(self.scope, name, default)
}

///|
pub fn VariableScope::number_token(
  self : VariableScope,
  name : String,
  default : Number,
) -> NumberToken {
  number_token(self.scope, name, default)
}

///|
pub fn VariableScope::percentage_token(
  self : VariableScope,
  name : String,
  default : Percentage,
) -> PercentageToken {
  percentage_token(self.scope, name, default)
}

///|
pub fn VariableScope::length_percentage_token(
  self : VariableScope,
  name : String,
  default : LengthPercentage,
) -> LengthPercentageToken {
  length_percentage_token(self.scope, name, default)
}

///|
pub fn VariableScope::integer_token(
  self : VariableScope,
  name : String,
  default : Integer,
) -> IntegerToken {
  integer_token(self.scope, name, default)
}

///|
pub fn VariableScope::time_token(
  self : VariableScope,
  name : String,
  default : Time,
) -> TimeToken {
  time_token(self.scope, name, default)
}

///|
pub fn VariableScope::angle_token(
  self : VariableScope,
  name : String,
  default : Angle,
) -> AngleToken {
  angle_token(self.scope, name, default)
}

///|
pub fn VariableScope::resolution_token(
  self : VariableScope,
  name : String,
  default : Resolution,
) -> ResolutionToken {
  resolution_token(self.scope, name, default)
}

///|
pub fn VariableScope::url_token(
  self : VariableScope,
  name : String,
  default : Url,
) -> UrlToken {
  url_token(self.scope, name, default)
}

///|
pub fn VariableScope::length_slot(
  self : VariableScope,
  name : String,
  default : Length,
) -> LengthSlot {
  length_slot(self.scope, name, default)
}

///|
pub fn VariableScope::color_slot(
  self : VariableScope,
  name : String,
  default : Color,
) -> ColorSlot {
  color_slot(self.scope, name, default)
}

///|
pub fn VariableScope::number_slot(
  self : VariableScope,
  name : String,
  default : Number,
) -> NumberSlot {
  number_slot(self.scope, name, default)
}

///|
pub fn VariableScope::percentage_slot(
  self : VariableScope,
  name : String,
  default : Percentage,
) -> PercentageSlot {
  percentage_slot(self.scope, name, default)
}

///|
pub fn VariableScope::length_percentage_slot(
  self : VariableScope,
  name : String,
  default : LengthPercentage,
) -> LengthPercentageSlot {
  length_percentage_slot(self.scope, name, default)
}

///|
pub fn VariableScope::integer_slot(
  self : VariableScope,
  name : String,
  default : Integer,
) -> IntegerSlot {
  integer_slot(self.scope, name, default)
}

///|
pub fn VariableScope::time_slot(
  self : VariableScope,
  name : String,
  default : Time,
) -> TimeSlot {
  time_slot(self.scope, name, default)
}

///|
pub fn VariableScope::angle_slot(
  self : VariableScope,
  name : String,
  default : Angle,
) -> AngleSlot {
  angle_slot(self.scope, name, default)
}

///|
pub fn VariableScope::resolution_slot(
  self : VariableScope,
  name : String,
  default : Resolution,
) -> ResolutionSlot {
  resolution_slot(self.scope, name, default)
}

///|
pub fn VariableScope::url_slot(
  self : VariableScope,
  name : String,
  default : Url,
) -> UrlSlot {
  url_slot(self.scope, name, default)
}

///|
pub fn[T] Token::variable_use(self : Token[T]) -> VariableUse {
  {
    scope: self.scope,
    local_name: self.local_name,
    definition: self.variable.definition(),
    role: TokenRole,
  }
}

///|
pub fn[T] DynamicSlot::variable_use(self : DynamicSlot[T]) -> VariableUse {
  {
    scope: self.scope,
    local_name: self.local_name,
    definition: self.variable.definition(),
    role: DynamicSlotRole,
  }
}

///|
pub fn[T] Token::reference_css(self : Token[T]) -> String {
  "var(" + self.variable.name + ")"
}

///|
pub fn[T] DynamicSlot::variable_name(self : DynamicSlot[T]) -> String {
  self.variable.name
}

///|
pub fn[T] Token::definition(self : Token[T]) -> VarDefinition {
  self.variable.definition()
}

///|
pub fn[T] Token::definition_use(self : Token[T]) -> VariableUse {
  self.variable_use()
}

///|
pub fn[T : CssValue] Token::with_value(
  self : Token[T],
  value : T,
) -> TokenOverride {
  {
    variable: self.variable_use(),
    override_: {
      name: self.variable.name,
      value_css: value.css_value(),
      category: value.value_category(),
    },
  }
}

///|
pub impl CssValue for Length with fn css_value(self) {
  self.css
}

///|
pub impl CssValue for Length with fn value_category(_self) {
  LengthCategory
}

///|
pub impl CssValue for Color with fn css_value(self) {
  self.css
}

///|
pub impl CssValue for Color with fn value_category(_self) {
  ColorCategory
}

///|
pub impl CssValue for Number with fn css_value(self) {
  self.css
}

///|
pub impl CssValue for Number with fn value_category(_self) {
  NumberCategory
}

///|
pub impl CssValue for Percentage with fn css_value(self) {
  self.css
}

///|
pub impl CssValue for Percentage with fn value_category(_self) {
  PercentageCategory
}

///|
pub impl CssValue for LengthPercentage with fn css_value(self) {
  self.css
}

///|
pub impl CssValue for LengthPercentage with fn value_category(_self) {
  LengthPercentageCategory
}

///|
pub impl CssValue for Integer with fn css_value(self) {
  self.css
}

///|
pub impl CssValue for Integer with fn value_category(_self) {
  IntegerCategory
}

///|
pub impl CssValue for Time with fn css_value(self) {
  self.css
}

///|
pub impl CssValue for Time with fn value_category(_self) {
  TimeCategory
}

///|
pub impl CssValue for Angle with fn css_value(self) {
  self.css
}

///|
pub impl CssValue for Angle with fn value_category(_self) {
  AngleCategory
}

///|
pub impl CssValue for Resolution with fn css_value(self) {
  self.css
}

///|
pub impl CssValue for Resolution with fn value_category(_self) {
  ResolutionCategory
}

///|
pub impl CssValue for Url with fn css_value(self) {
  self.css
}

///|
pub impl CssValue for Url with fn value_category(_self) {
  UrlCategory
}

///|
pub fn authored_length(value : Double, unit : LengthUnit) -> Length {
  length(value, unit) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_rem(value : Double) -> Length {
  rem(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_em(value : Double) -> Length {
  em(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_ch(value : Double) -> Length {
  ch(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_vmin(value : Double) -> Length {
  vmin(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_vmax(value : Double) -> Length {
  vmax(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_svh(value : Double) -> Length {
  svh(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_lvh(value : Double) -> Length {
  lvh(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_dvh(value : Double) -> Length {
  dvh(value) catch {
    error => { css: error_css(error), }
  }
}

///|
fn invalid_rgb(red : Int32, green : Int32, blue : Int32) -> String? {
  if red < 0 || red > 255 || green < 0 || green > 255 || blue < 0 || blue > 255 {
    Some(issue_css("STYLE_VALUE_OUT_OF_RANGE", "rgb"))
  } else {
    None
  }
}

///|
pub fn authored_rgb(red : Int32, green : Int32, blue : Int32) -> Color {
  match invalid_rgb(red, green, blue) {
    Some(css) => { css, }
    None => rgb(red, green, blue)
  }
}

///|
pub fn authored_rgba(
  red : Int32,
  green : Int32,
  blue : Int32,
  alpha : Double,
) -> Color {
  match invalid_rgb(red, green, blue) {
    Some(css) => { css, }
    None =>
      rgba(red, green, blue, alpha) catch {
        error => { css: error_css(error), }
      }
  }
}

///|
pub fn authored_hex_color(value : String) -> Color {
  hex_color(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_hsl(
  hue : Double,
  saturation : Double,
  lightness : Double,
) -> Color {
  hsl(hue, saturation, lightness) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_seconds(value : Double) -> Time {
  seconds(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_deg(value : Double) -> Angle {
  deg(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_turn(value : Double) -> Angle {
  turn(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_percentage(value : Double) -> Percentage {
  percentage(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_number(value : Double) -> Number {
  number(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_dpi(value : Double) -> Resolution {
  dpi(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_dppx(value : Double) -> Resolution {
  dppx(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_url(value : String) -> Url {
  url(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_ratio(width : Int32, height : Int32) -> Ratio {
  ratio(width, height) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_scale_transform(
  x : Double,
  y~ : Double? = None,
) -> TransformFunction {
  scale_transform(x, y~) catch {
    error => { expression: literal_expression(error_css(error), "transform"), }
  }
}

///|
pub fn authored_transform_list(
  functions : Array[TransformFunction],
) -> TransformList {
  transform_list(functions) catch {
    error => { expression: literal_expression(error_css(error), "transform"), }
  }
}

///|
pub fn authored_cubic_bezier(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> EasingFunction {
  cubic_bezier(x1, y1, x2, y2) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_steps(
  count : Int32,
  at_start~ : Bool = false,
) -> EasingFunction {
  steps(count, at_start~) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_fr(value : Double) -> GridTrack {
  fr(value) catch {
    error =>
      make_track(literal_expression(error_css(error), "grid-track"), Flexible)
  }
}

///|
pub fn authored_grid_tracks(tracks : Array[GridTrack]) -> GridTrackList {
  grid_tracks(tracks) catch {
    error =>
      make_tracks([
        make_track(
          literal_expression(error_css(error), "grid-track"),
          Intrinsic,
        ),
      ])
  }
}

///|
pub fn authored_repeat_tracks(
  count : Int32,
  tracks : GridTrackList,
) -> GridTrack {
  repeat_tracks(count, tracks) catch {
    error =>
      make_track(literal_expression(error_css(error), "grid-track"), Intrinsic)
  }
}

///|
pub fn authored_grid_line(value : Int32) -> GridLine {
  grid_line(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_grid_span(value : Int32) -> GridLine {
  grid_span(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_named_grid_line(value : String) -> GridLine {
  named_grid_line(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_touch_action(parts : Array[TouchActionPart]) -> TouchAction {
  touch_action(parts) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_contain(parts : Array[ContainPart]) -> Contain {
  contain(parts) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_font_variant_numeric(
  parts : Array[FontVariantNumericPart],
) -> FontVariantNumeric {
  font_variant_numeric(parts) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_line_width_from_length(value : Length) -> LineWidth {
  line_width_from_length(value) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_corner_radius(
  horizontal : LengthPercentage,
  vertical~ : LengthPercentage? = None,
) -> CornerRadius {
  corner_radius(horizontal, vertical~)
}

///|
pub fn authored_border_side(
  width~ : LineWidth? = None,
  style~ : LineStyle? = None,
  color~ : Color? = None,
) -> BorderSide {
  border_side(width~, style~, color~) catch {
    error => { css: error_css(error), }
  }
}

///|
pub fn authored_outline(
  width~ : LineWidth? = None,
  style~ : OutlineStyle? = None,
  color~ : OutlineColor? = None,
) -> Outline {
  outline(width~, style~, color~) catch {
    error => { css: error_css(error), }
  }
}
