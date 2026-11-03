///|
/// Applies a static style to SVG attributes using the ordinary runtime ABI.
pub fn[T : @runtime.StaticStyleInput] svg_attrs(
  style : T,
  base~ : @svg.Attrs = @svg.Attrs::build(),
) -> @svg.Attrs {
  svg_attrs_applied(@runtime.props([style]), base~)
}

///|
/// Resolves all dynamic values before modifying the supplied attributes.
pub fn[T : @runtime.StyleInput] try_svg_attrs(
  styles : T,
  base~ : @svg.Attrs = @svg.Attrs::build(),
) -> Result[@svg.Attrs, Array[@runtime.DynamicValueError]] {
  match @runtime.compose(styles).resolve() {
    Ok(applied) => Ok(svg_attrs_applied(applied, base~))
    Err(errors) => Err(errors)
  }
}

///|
pub fn[T : @runtime.StyleInput] svg_attrs_or_abort(
  styles : T,
  base~ : @svg.Attrs = @svg.Attrs::build(),
) -> @svg.Attrs {
  @runtime.expect_dynamic(try_svg_attrs(styles, base~))
}

///|
pub fn svg_attrs_applied(
  applied : @runtime.AppliedStyle,
  base~ : @svg.Attrs = @svg.Attrs::build(),
) -> @svg.Attrs {
  let result = base.class(applied.class_name)
  for entry in applied.inline_vars {
    ignore(result.style(entry.0, entry.1))
  }
  result
}
