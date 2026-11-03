///|
/// The `auto` keyword or a case-sensitive CSS named page.
pub struct PageValue {
  css : String
} derive(Eq, Debug)

///|
pub extend PageValue with Eq::{equal, not_equal}

///|
pub extend PageValue with @debug.Debug::{to_repr}

///|
pub fn PageValue::to_css(self : PageValue) -> String {
  self.css
}

///|
pub fn page_auto() -> PageValue {
  { css: "auto", }
}

///|
/// Names retain their case. CSS-wide keywords and `auto` are not page names.
/// Invalid names produce extraction diagnostics.
///
/// ```mbt check
/// test {
///   assert_eq(@values.page_name("Report").to_css(), "Report")
///   assert_eq(@values.page_auto().to_css(), "auto")
/// }
/// ```
pub fn page_name(value : String) -> PageValue {
  if valid_custom_ident(value) && value.to_lower() != "auto" {
    { css: value, }
  } else {
    {
      css: issue_css(
        "STYLE_PAGE_NAME", "Page names must be custom identifiers other than auto",
      ),
    }
  }
}
