///|
pub fn apply_inline_vars(
  attrs : @html.Attrs,
  applied : @css.AppliedStyle,
) -> @html.Attrs {
  for entry in applied.inline_vars {
    ignore(attrs.style(entry.0, entry.1))
  }
  attrs
}
