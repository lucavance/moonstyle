///|
pub struct CounterName {
  css : String
}

///|
pub struct CounterChange {
  css : String
}

///|
pub struct CounterChanges {
  css : String
}

///|
pub fn CounterChanges::to_css(self : CounterChanges) -> String {
  self.css
}

///|
pub fn counter_name(value : String) -> CounterName {
  if valid_custom_ident(value) && value.to_lower() != "none" {
    { css: value, }
  } else {
    {
      css: issue_css(
        "STYLE_COUNTER_NAME", "Counter names must be custom identifiers",
      ),
    }
  }
}

///|
/// The integer is explicit: reset/set usually use zero; increment usually uses one.
pub fn counter_change(name : CounterName, value : Int32) -> CounterChange {
  { css: name.css + " " + value.to_string(), }
}

///|
pub fn counter_changes(values : Array[CounterChange]) -> CounterChanges {
  {
    css: if values.is_empty() {
      issue_css(
        "STYLE_COUNTER_EMPTY", "Counter changes must not be empty; use counters_none()",
      )
    } else {
      values.map(value => value.css).join(" ")
    },
  }
}

///|
pub fn counters_none() -> CounterChanges {
  { css: "none", }
}

///|
pub(all) enum CounterStyle {
  Decimal
  DecimalLeadingZero
  LowerAlpha
  UpperAlpha
  LowerRoman
  UpperRoman
} derive(Eq, Debug)

///|
pub extend CounterStyle with Eq::{equal, not_equal}

///|
pub extend CounterStyle with @debug.Debug::{to_repr}

///|
fn CounterStyle::css(self : CounterStyle) -> String {
  match self {
    Decimal => "decimal"
    DecimalLeadingZero => "decimal-leading-zero"
    LowerAlpha => "lower-alpha"
    UpperAlpha => "upper-alpha"
    LowerRoman => "lower-roman"
    UpperRoman => "upper-roman"
  }
}

///|
pub fn counter_content(
  name : CounterName,
  style~ : CounterStyle = Decimal,
) -> ContentValue {
  { css: "counter(" + name.css + ", " + style.css() + ")", }
}

///|
pub fn counters_content(
  name : CounterName,
  separator : String,
  style~ : CounterStyle = Decimal,
) -> ContentValue {
  {
    css: "counters(" +
    name.css +
    ", " +
    quoted_css_string(separator, "counter separator") +
    ", " +
    style.css() +
    ")",
  }
}

///|
pub fn content_sequence(values : Array[ContentValue]) -> ContentValue {
  if values.is_empty() || values.any(value => value.css == "none") {
    {
      css: issue_css(
        "STYLE_CONTENT_SEQUENCE", "Content requires text or counter items; none must stand alone",
      ),
    }
  } else {
    { css: values.map(value => value.css).join(" "), }
  }
}
