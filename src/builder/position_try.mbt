///|
pub struct PositionTryRule {
  name : String
  descriptors : Array[@ir.PositionTryDescriptor]
}

///|
/// Define a named fallback using CSS positioning descriptors.
///
/// ```mbt check
/// test {
///   let fallback = @builder.position_try_rule("tooltip")
///     .inset_inline_start(@values.px(8))
///     .max_inline_size(@values.percent(90))
///   assert_eq(fallback.to_ir().descriptors.length(), 2)
/// }
/// ```
pub fn position_try_rule(name : String) -> PositionTryRule {
  {
    name: if name.has_prefix("--") {
      name
    } else {
      "--" + name
    },
    descriptors: [],
  }
}

///|
fn PositionTryRule::descriptor(
  self : PositionTryRule,
  name : String,
  value : String,
) -> PositionTryRule {
  // Move replacements to the end: intervening shorthands must not win over
  // the last authored longhand (and vice versa).
  let descriptors = self.descriptors.filter(descriptor => {
    descriptor.name != name
  })
  descriptors.push({ name, value, })
  { ..self, descriptors, }
}

///|
pub fn PositionTryRule::position_area(
  self : PositionTryRule,
  value : @values.PositionArea,
) -> PositionTryRule {
  self.descriptor("position-area", value.to_css())
}

///|
pub fn PositionTryRule::top(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("top", value.to_css())
}

///|
pub fn PositionTryRule::right(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("right", value.to_css())
}

///|
pub fn PositionTryRule::bottom(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("bottom", value.to_css())
}

///|
pub fn PositionTryRule::left(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("left", value.to_css())
}

///|
pub fn PositionTryRule::width(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("width", value.to_css())
}

///|
pub fn PositionTryRule::height(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("height", value.to_css())
}

///|
pub fn PositionTryRule::max_width(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("max-width", value.to_css())
}

///|
pub fn PositionTryRule::max_height(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("max-height", value.to_css())
}

///|
pub fn PositionTryRule::to_ir(
  self : PositionTryRule,
) -> @ir.PositionTryDefinition {
  { name: self.name, descriptors: self.descriptors.copy(), }
}

///|
pub fn PositionTryRule::position_anchor(
  self : PositionTryRule,
  value : @values.PositionAnchor,
) -> PositionTryRule {
  self.descriptor("position-anchor", value.to_css())
}

///|
pub fn PositionTryRule::inset(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("inset", value.to_css())
}

///|
pub fn PositionTryRule::inset_block(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("inset-block", value.to_css())
}

///|
pub fn PositionTryRule::inset_block_start(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("inset-block-start", value.to_css())
}

///|
pub fn PositionTryRule::inset_block_end(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("inset-block-end", value.to_css())
}

///|
pub fn PositionTryRule::inset_inline(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("inset-inline", value.to_css())
}

///|
pub fn PositionTryRule::inset_inline_start(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("inset-inline-start", value.to_css())
}

///|
pub fn PositionTryRule::inset_inline_end(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("inset-inline-end", value.to_css())
}

///|
pub fn PositionTryRule::margin(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("margin", value.to_css())
}

///|
pub fn PositionTryRule::margin_top(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("margin-top", value.to_css())
}

///|
pub fn PositionTryRule::margin_right(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("margin-right", value.to_css())
}

///|
pub fn PositionTryRule::margin_bottom(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("margin-bottom", value.to_css())
}

///|
pub fn PositionTryRule::margin_left(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("margin-left", value.to_css())
}

///|
pub fn PositionTryRule::margin_block(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("margin-block", value.to_css())
}

///|
pub fn PositionTryRule::margin_block_start(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("margin-block-start", value.to_css())
}

///|
pub fn PositionTryRule::margin_block_end(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("margin-block-end", value.to_css())
}

///|
pub fn PositionTryRule::margin_inline(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("margin-inline", value.to_css())
}

///|
pub fn PositionTryRule::margin_inline_start(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("margin-inline-start", value.to_css())
}

///|
pub fn PositionTryRule::margin_inline_end(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("margin-inline-end", value.to_css())
}

///|
pub fn PositionTryRule::min_width(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("min-width", value.to_css())
}

///|
pub fn PositionTryRule::min_height(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("min-height", value.to_css())
}

///|
pub fn PositionTryRule::block_size(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("block-size", value.to_css())
}

///|
pub fn PositionTryRule::inline_size(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("inline-size", value.to_css())
}

///|
pub fn PositionTryRule::min_block_size(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("min-block-size", value.to_css())
}

///|
pub fn PositionTryRule::min_inline_size(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("min-inline-size", value.to_css())
}

///|
pub fn PositionTryRule::max_block_size(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("max-block-size", value.to_css())
}

///|
pub fn PositionTryRule::max_inline_size(
  self : PositionTryRule,
  value : @values.Length,
) -> PositionTryRule {
  self.descriptor("max-inline-size", value.to_css())
}

///|
pub fn PositionTryRule::align_self(
  self : PositionTryRule,
  value : @properties.Alignment,
) -> PositionTryRule {
  self.descriptor("align-self", value.to_css())
}

///|
pub fn PositionTryRule::justify_self(
  self : PositionTryRule,
  value : @properties.Alignment,
) -> PositionTryRule {
  self.descriptor("justify-self", value.to_css())
}

///|
pub fn PositionTryRule::place_self(
  self : PositionTryRule,
  value : @properties.Alignment,
) -> PositionTryRule {
  self.descriptor("place-self", value.to_css())
}
