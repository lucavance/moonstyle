///|
pub struct GridTemplateAreas {
  css : String
} derive(Eq, Debug)

///|
pub struct ContainerNames {
  css : String
} derive(Eq, Debug)

///|
pub struct MaskImage {
  css : String
} derive(Eq, Debug)

///|
pub struct MaskImageList {
  css : String
} derive(Eq, Debug)

///|
pub struct PositionList {
  css : String
} derive(Eq, Debug)

///|
pub struct RepeatStyleList {
  css : String
} derive(Eq, Debug)

///|
pub struct BackgroundSizeList {
  css : String
} derive(Eq, Debug)

///|
pub struct ClipPath {
  css : String
} derive(Eq, Debug)

///|
pub struct ContentValue {
  css : String
} derive(Eq, Debug)

///|
pub struct AnchorName {
  css : String
} derive(Eq, Debug)

///|
pub struct AnchorNames {
  css : String
} derive(Eq, Debug)

///|
pub struct PositionAnchor {
  css : String
} derive(Eq, Debug)

///|
pub(all) enum PositionAreaHorizontal {
  AreaLeft
  AreaCenter
  AreaRight
  AreaInlineStart
  AreaInlineEnd
} derive(Eq, Debug)

///|
pub(all) enum PositionAreaVertical {
  AreaTop
  AreaCenterVertical
  AreaBottom
  AreaBlockStart
  AreaBlockEnd
} derive(Eq, Debug)

///|
pub struct PositionArea {
  css : String
} derive(Eq, Debug)

///|
pub(all) enum PositionTryTactic {
  TryFlipBlock
  TryFlipInline
  TryFlipStart
} derive(Eq, Debug)

///|
pub struct PositionTryFallback {
  css : String
} derive(Eq, Debug)

///|
pub struct PositionTryFallbacks {
  css : String
} derive(Eq, Debug)

///|
pub(all) enum PositionTryOrder {
  TryOrderNormal
  TryOrderMostWidth
  TryOrderMostHeight
  TryOrderMostBlockSize
  TryOrderMostInlineSize
} derive(Eq, Debug)

///|
pub struct PositionTryValue {
  css : String
} derive(Eq, Debug)

///|
pub struct ViewTransitionName {
  css : String
} derive(Eq, Debug)

///|
pub struct ViewTransitionClass {
  css : String
} derive(Eq, Debug)

///|
fn modern_invalid(label : String) -> String {
  error_css(EmptyValue(label))
}

///|
fn modern_ident(value : String, label : String) -> String {
  let value = value.trim().to_owned()
  if valid_name_part(value) {
    value
  } else {
    modern_invalid(label)
  }
}

///|
fn modern_dashed_ident(value : String, label : String) -> String {
  let value = value.trim().to_owned()
  let identifier = if value.has_prefix("--") {
    value[2:].to_owned()
  } else {
    value
  }
  if valid_name_part(identifier) {
    "--" + identifier
  } else {
    modern_invalid(label)
  }
}

///|
fn quoted_css_string(value : String, label : String) -> String {
  if value.contains("\u0000") {
    modern_invalid(label)
  } else {
    "\"" +
    value
    .replace_all(old="\\", new="\\\\")
    .replace_all(old="\"", new="\\\"")
    .replace_all(old="\n", new="\\a ")
    .replace_all(old="\r", new="\\d ")
    .replace_all(old="\u000c", new="\\c ") +
    "\""
  }
}

///|
pub fn authored_grid_template_areas(
  rows : Array[Array[String]],
) -> GridTemplateAreas {
  if rows.is_empty() || rows[0].is_empty() {
    return { css: modern_invalid("grid-template-areas"), }
  }
  let columns = rows[0].length()
  let rendered : Array[String] = []
  for row in rows {
    if row.length() != columns ||
      row.any(cell => cell != "." && !valid_name_part(cell)) {
      return { css: modern_invalid("grid-template-areas"), }
    }
    rendered.push(quoted_css_string(row.join(" "), "grid-template-areas"))
  }
  { css: rendered.join(" "), }
}

///|
pub fn authored_container_names(values : Array[String]) -> ContainerNames {
  if values.is_empty() {
    { css: modern_invalid("container-name"), }
  } else {
    {
      css: values.map(value => modern_ident(value, "container-name")).join(" "),
    }
  }
}

///|
pub fn authored_mask_image_url(value : Url) -> MaskImage {
  { css: value.to_css(), }
}

///|
pub fn authored_mask_images(values : Array[MaskImage]) -> MaskImageList {
  if values.is_empty() {
    { css: modern_invalid("mask-image"), }
  } else {
    { css: values.map(value => value.css).join(", "), }
  }
}

///|
pub fn authored_positions(values : Array[Position]) -> PositionList {
  if values.is_empty() {
    { css: modern_invalid("position-list"), }
  } else {
    { css: values.map(value => value.to_css()).join(", "), }
  }
}

///|
pub fn authored_repeat_styles(values : Array[RepeatStyle]) -> RepeatStyleList {
  if values.is_empty() {
    { css: modern_invalid("repeat-style-list"), }
  } else {
    { css: values.map(RepeatStyle::to_css).join(", "), }
  }
}

///|
pub fn authored_background_sizes(
  values : Array[BackgroundSize],
) -> BackgroundSizeList {
  if values.is_empty() {
    { css: modern_invalid("background-size-list"), }
  } else {
    { css: values.map(value => value.to_css()).join(", "), }
  }
}

///|
pub fn authored_clip_path_circle(
  radius : LengthPercentage,
  center~ : Position? = None,
) -> ClipPath {
  let center_css = match center {
    Some(value) => " at " + value.to_css()
    None => ""
  }
  { css: "circle(" + radius.to_css() + center_css + ")", }
}

///|
pub fn authored_clip_path_url(value : Url) -> ClipPath {
  { css: value.to_css(), }
}

///|
pub fn authored_content_text(value : String) -> ContentValue {
  { css: quoted_css_string(value, "content"), }
}

///|
pub fn authored_content_none() -> ContentValue {
  { css: "none", }
}

///|
pub fn authored_anchor_name(value : String) -> AnchorName {
  { css: modern_dashed_ident(value, "anchor-name"), }
}

///|
pub fn authored_anchor_names(values : Array[AnchorName]) -> AnchorNames {
  if values.is_empty() {
    { css: modern_invalid("anchor-name"), }
  } else {
    { css: values.map(value => value.css).join(", "), }
  }
}

///|
pub fn authored_position_anchor(value : AnchorName) -> PositionAnchor {
  { css: value.css, }
}

///|
fn PositionAreaHorizontal::to_css(self : PositionAreaHorizontal) -> String {
  match self {
    AreaLeft => "left"
    AreaCenter => "center"
    AreaRight => "right"
    AreaInlineStart => "inline-start"
    AreaInlineEnd => "inline-end"
  }
}

///|
fn PositionAreaVertical::to_css(self : PositionAreaVertical) -> String {
  match self {
    AreaTop => "top"
    AreaCenterVertical => "center"
    AreaBottom => "bottom"
    AreaBlockStart => "block-start"
    AreaBlockEnd => "block-end"
  }
}

///|
pub fn authored_position_area(
  horizontal : PositionAreaHorizontal,
  vertical : PositionAreaVertical,
) -> PositionArea {
  { css: horizontal.to_css() + " " + vertical.to_css(), }
}

///|
fn PositionTryTactic::to_css(self : PositionTryTactic) -> String {
  match self {
    TryFlipBlock => "flip-block"
    TryFlipInline => "flip-inline"
    TryFlipStart => "flip-start"
  }
}

///|
pub fn authored_position_try_named(value : String) -> PositionTryFallback {
  { css: modern_dashed_ident(value, "position-try-fallback"), }
}

///|
pub fn authored_position_try_area(value : PositionArea) -> PositionTryFallback {
  { css: value.css, }
}

///|
pub fn authored_position_try_tactic(
  value : PositionTryTactic,
) -> PositionTryFallback {
  { css: value.to_css(), }
}

///|
pub fn authored_position_try_fallbacks(
  values : Array[PositionTryFallback],
) -> PositionTryFallbacks {
  if values.is_empty() {
    { css: modern_invalid("position-try-fallbacks"), }
  } else {
    { css: values.map(value => value.css).join(", "), }
  }
}

///|
pub fn PositionTryOrder::to_css(self : PositionTryOrder) -> String {
  match self {
    TryOrderNormal => "normal"
    TryOrderMostWidth => "most-width"
    TryOrderMostHeight => "most-height"
    TryOrderMostBlockSize => "most-block-size"
    TryOrderMostInlineSize => "most-inline-size"
  }
}

///|
pub fn authored_position_try_value(
  fallbacks : PositionTryFallbacks,
  order~ : PositionTryOrder? = None,
) -> PositionTryValue {
  {
    css: match order {
      Some(value) => value.to_css() + " " + fallbacks.css
      None => fallbacks.css
    },
  }
}

///|
pub fn authored_view_transition_name(value : String) -> ViewTransitionName {
  { css: modern_ident(value, "view-transition-name"), }
}

///|
pub fn authored_view_transition_class(value : String) -> ViewTransitionClass {
  { css: modern_ident(value, "view-transition-class"), }
}

///|
pub fn FilterList::to_css(self : FilterList) -> String {
  self.expression.to_css()
}

///|
pub fn BoxShadowList::to_css(self : BoxShadowList) -> String {
  self.expression.to_css()
}

///|
pub fn TextShadowList::to_css(self : TextShadowList) -> String {
  self.expression.to_css()
}

///|
pub fn GridTemplateAreas::to_css(self : GridTemplateAreas) -> String {
  self.css
}

///|
pub fn ContainerNames::to_css(self : ContainerNames) -> String {
  self.css
}

///|
pub fn MaskImageList::to_css(self : MaskImageList) -> String {
  self.css
}

///|
pub fn PositionList::to_css(self : PositionList) -> String {
  self.css
}

///|
pub fn RepeatStyleList::to_css(self : RepeatStyleList) -> String {
  self.css
}

///|
pub fn BackgroundSizeList::to_css(self : BackgroundSizeList) -> String {
  self.css
}

///|
pub fn ClipPath::to_css(self : ClipPath) -> String {
  self.css
}

///|
pub fn ContentValue::to_css(self : ContentValue) -> String {
  self.css
}

///|
pub fn AnchorNames::to_css(self : AnchorNames) -> String {
  self.css
}

///|
pub fn PositionAnchor::to_css(self : PositionAnchor) -> String {
  self.css
}

///|
pub fn PositionArea::to_css(self : PositionArea) -> String {
  self.css
}

///|
pub fn PositionTryFallbacks::to_css(self : PositionTryFallbacks) -> String {
  self.css
}

///|
pub fn PositionTryValue::to_css(self : PositionTryValue) -> String {
  self.css
}

///|
pub fn ViewTransitionName::to_css(self : ViewTransitionName) -> String {
  self.css
}

///|
pub fn ViewTransitionClass::to_css(self : ViewTransitionClass) -> String {
  self.css
}
