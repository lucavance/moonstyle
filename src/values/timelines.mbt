///|
pub struct TimelineName {
  css : String
}

///|
pub struct TimelineNames {
  css : String
}

///|
pub struct TimelineScope {
  css : String
}

///|
pub struct AnimationTimeline {
  expression : Expression
}

///|
pub struct AnimationTimelines {
  expression : Expression
}

///|
pub struct TimelineRange {
  expression : Expression
}

///|
pub fn TimelineNames::to_css(self : TimelineNames) -> String {
  self.css
}

///|
pub fn TimelineScope::to_css(self : TimelineScope) -> String {
  self.css
}

///|
pub fn AnimationTimelines::to_css(self : AnimationTimelines) -> String {
  self.expression.to_css()
}

///|
pub fn AnimationTimelines::expression(self : AnimationTimelines) -> Expression {
  self.expression
}

///|
pub fn TimelineRange::to_css(self : TimelineRange) -> String {
  self.expression.to_css()
}

///|
pub fn TimelineRange::expression(self : TimelineRange) -> Expression {
  self.expression
}

///|
pub fn timeline_name(value : String) -> TimelineName {
  if value.has_prefix("--") && value.length() > 2 && valid_grid_name(value) {
    { css: value, }
  } else {
    {
      css: issue_css(
        "STYLE_TIMELINE_NAME", "Timeline names must be dashed identifiers starting with --",
      ),
    }
  }
}

///|
pub fn timeline_names(values : Array[TimelineName]) -> TimelineNames {
  {
    css: if values.is_empty() {
      issue_css("STYLE_TIMELINE_EMPTY", "Timeline names must not be empty")
    } else {
      values.map(value => value.css).join(", ")
    },
  }
}

///|
pub fn timeline_names_none() -> TimelineNames {
  { css: "none", }
}

///|
pub fn timeline_scope(values : Array[TimelineName]) -> TimelineScope {
  { css: timeline_names(values).css, }
}

///|
pub fn timeline_scope_none() -> TimelineScope {
  { css: "none", }
}

///|
pub fn timeline_scope_all() -> TimelineScope {
  { css: "all", }
}

///|
pub fn named_timeline(name : TimelineName) -> AnimationTimeline {
  { expression: literal_expression(name.css, "timeline"), }
}

///|
pub fn timeline_auto() -> AnimationTimeline {
  { expression: literal_expression("auto", "timeline"), }
}

///|
pub fn timeline_none() -> AnimationTimeline {
  { expression: literal_expression("none", "timeline"), }
}

///|
pub(all) enum TimelineAxis {
  BlockAxis
  InlineAxis
  XAxis
  YAxis
} derive(Eq, Debug)

///|
pub extend TimelineAxis with Eq::{equal, not_equal}

///|
pub extend TimelineAxis with @debug.Debug::{to_repr}

///|
pub fn TimelineAxis::to_css(self : TimelineAxis) -> String {
  match self {
    BlockAxis => "block"
    InlineAxis => "inline"
    XAxis => "x"
    YAxis => "y"
  }
}

///|
pub(all) enum TimelineScroller {
  NearestScroller
  RootScroller
  SelfScroller
} derive(Eq, Debug)

///|
pub extend TimelineScroller with Eq::{equal, not_equal}

///|
pub extend TimelineScroller with @debug.Debug::{to_repr}

///|
pub fn scroll_timeline(
  axis~ : TimelineAxis = BlockAxis,
  scroller~ : TimelineScroller = NearestScroller,
) -> AnimationTimeline {
  let scroller = match scroller {
    NearestScroller => "nearest"
    RootScroller => "root"
    SelfScroller => "self"
  }
  {
    expression: literal_expression(
      "scroll(" + scroller + " " + axis.to_css() + ")",
      "timeline",
    ),
  }
}

///|
pub fn view_timeline(
  axis~ : TimelineAxis = BlockAxis,
  inset? : MathExpr[LengthPercentage],
  end_inset? : MathExpr[LengthPercentage],
) -> AnimationTimeline {
  let values = [literal_expression(axis.to_css(), "axis")]
  if inset is Some(value) {
    values.push(value.expression)
  }
  if end_inset is Some(value) {
    if inset is None {
      values.push(literal_expression("auto", "keyword"))
    }
    values.push(value.expression)
  }
  { expression: group_expression("timeline", "view(", values, " ", ")"), }
}

///|
pub fn animation_timelines(
  values : Array[AnimationTimeline],
) -> AnimationTimelines {
  let items = values.map(value => value.expression)
  if items.is_empty() {
    items.push(
      invalid_expression(
        "STYLE_TIMELINE_EMPTY", "Animation timelines must not be empty",
      ),
    )
  }
  { expression: group_expression("timeline-list", "", items, ", ", ""), }
}

///|
pub(all) enum TimelineRangeName {
  Cover
  ContainRange
  Entry
  Exit
  EntryCrossing
  ExitCrossing
} derive(Eq, Debug)

///|
pub extend TimelineRangeName with Eq::{equal, not_equal}

///|
pub extend TimelineRangeName with @debug.Debug::{to_repr}

///|
pub fn timeline_range(
  name : TimelineRangeName,
  offset? : MathExpr[LengthPercentage],
) -> TimelineRange {
  let name = match name {
    Cover => "cover"
    ContainRange => "contain"
    Entry => "entry"
    Exit => "exit"
    EntryCrossing => "entry-crossing"
    ExitCrossing => "exit-crossing"
  }
  let values = [literal_expression(name, "range-name")]
  if offset is Some(value) {
    values.push(value.expression)
  }
  { expression: group_expression("timeline-range", "", values, " ", ""), }
}

///|
pub fn timeline_range_normal() -> TimelineRange {
  { expression: literal_expression("normal", "timeline-range"), }
}

///|
pub fn[T : LengthPercentageMathInput] timeline_range_offset(
  value : T,
) -> TimelineRange {
  { expression: value.length_percentage_math().expression, }
}

///|
pub fn timeline_ranges(values : Array[TimelineRange]) -> TimelineRange {
  let items = values.map(value => value.expression)
  if items.is_empty() {
    items.push(
      invalid_expression(
        "STYLE_TIMELINE_EMPTY", "Timeline ranges must not be empty",
      ),
    )
  }
  { expression: group_expression("timeline-range-list", "", items, ", ", ""), }
}
