///|
/// Common keyword alignments. Numeric offsets use vertical_align_offset.
pub(all) enum VerticalAlignKeyword {
  AlignBaseline
  AlignSub
  AlignSuper
  AlignTextTop
  AlignTextBottom
  AlignMiddle
  AlignTop
  AlignBottom
} derive(Eq, Debug)

///|
pub struct VerticalAlign {
  css : String
} derive(Eq, Debug)

///|
pub fn vertical_align(keyword : VerticalAlignKeyword) -> VerticalAlign {
  {
    css: match keyword {
      AlignBaseline => "baseline"
      AlignSub => "sub"
      AlignSuper => "super"
      AlignTextTop => "text-top"
      AlignTextBottom => "text-bottom"
      AlignMiddle => "middle"
      AlignTop => "top"
      AlignBottom => "bottom"
    },
  }
}

///|
/// A static length or percentage offset; negative offsets are valid.
pub fn vertical_align_offset(value : LengthPercentage) -> VerticalAlign {
  { css: value.to_css(), }
}

///|
pub fn VerticalAlign::to_css(self : VerticalAlign) -> String {
  self.css
}

///|
/// Reviewed hints; this API does not accept arbitrary property-name strings.
pub(all) enum WillChangeFeature {
  ChangeScrollPosition
  ChangeContents
  ChangeTransform
  ChangeOpacity
  ChangeFilter
  ChangeBackgroundColor
  ChangeColor
  ChangeWidth
  ChangeHeight
  ChangeLeft
  ChangeTop
} derive(Eq, Debug)

///|
pub struct WillChange {
  css : String
} derive(Eq, Debug)

///|
pub fn will_change(features : Array[WillChangeFeature]) -> WillChange {
  {
    css: if features.is_empty() {
      issue_css(
        "STYLE_WILL_CHANGE", "Will-change needs a hint; use will_change_auto() for auto",
      )
    } else {
      features
      .map(feature => {
        match feature {
          ChangeScrollPosition => "scroll-position"
          ChangeContents => "contents"
          ChangeTransform => "transform"
          ChangeOpacity => "opacity"
          ChangeFilter => "filter"
          ChangeBackgroundColor => "background-color"
          ChangeColor => "color"
          ChangeWidth => "width"
          ChangeHeight => "height"
          ChangeLeft => "left"
          ChangeTop => "top"
        }
      })
      .join(", ")
    },
  }
}

///|
pub fn will_change_auto() -> WillChange {
  { css: "auto", }
}

///|
pub fn WillChange::to_css(self : WillChange) -> String {
  self.css
}

///|
pub struct FontVariationAxis {
  css : String
}

///|
pub struct FontVariationSettings {
  css : String
} derive(Eq, Debug)

///|
/// OpenType tags contain exactly four printable ASCII characters. Case and
/// axis order are preserved; the supplied number must be finite.
pub fn font_axis(tag : String, value : Double) -> FontVariationAxis {
  let valid_tag = tag.length() == 4 &&
    tag.iter().all(ch => ch >= ' ' && ch <= '~')
  {
    css: if valid_tag {
      quoted_css_string(tag, "font axis") +
      " " +
      authored_number(value).to_css()
    } else {
      issue_css(
        "STYLE_FONT_AXIS", "Font axis tags need exactly four printable ASCII characters",
      )
    },
  }
}

///|
pub fn font_variations(
  axes : Array[FontVariationAxis],
) -> FontVariationSettings {
  {
    css: if axes.is_empty() {
      issue_css(
        "STYLE_FONT_VARIATIONS", "Font variations need an axis; use normal_font_variations() for normal",
      )
    } else {
      axes.map(axis => axis.css).join(", ")
    },
  }
}

///|
pub fn normal_font_variations() -> FontVariationSettings {
  { css: "normal", }
}

///|
pub fn FontVariationSettings::to_css(self : FontVariationSettings) -> String {
  self.css
}

///|
pub extend VerticalAlignKeyword with Eq::{equal, not_equal}

///|
pub extend VerticalAlignKeyword with @debug.Debug::{to_repr}

///|
pub extend WillChangeFeature with Eq::{equal, not_equal}

///|
pub extend WillChangeFeature with @debug.Debug::{to_repr}

///|
pub extend VerticalAlign with Eq::{equal, not_equal}

///|
pub extend VerticalAlign with @debug.Debug::{to_repr}

///|
pub extend WillChange with Eq::{equal, not_equal}

///|
pub extend WillChange with @debug.Debug::{to_repr}

///|
pub extend FontVariationSettings with Eq::{equal, not_equal}

///|
pub extend FontVariationSettings with @debug.Debug::{to_repr}
