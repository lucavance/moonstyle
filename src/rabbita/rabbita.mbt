///|
pub fn[T : @runtime.StaticStyleInput] attrs(
  style : T,
  base~ : @html.Attrs = @html.Attrs::build(),
) -> @html.Attrs {
  attrs_applied(@runtime.props([style]), base~)
}

///|
pub fn[T : @runtime.StaticStyleInput] attrs_many(
  styles : Array[T],
  base~ : @html.Attrs = @html.Attrs::build(),
) -> @html.Attrs {
  attrs_applied(@runtime.props(styles), base~)
}

///|
pub fn[T : @runtime.StyleInput] try_attrs(
  styles : T,
  base~ : @html.Attrs = @html.Attrs::build(),
) -> Result[@html.Attrs, Array[@runtime.DynamicValueError]] {
  match @runtime.compose(styles).resolve() {
    Ok(applied) => Ok(attrs_applied(applied, base~))
    Err(errors) => Err(errors)
  }
}

///|
pub fn[T : @runtime.StyleInput] attrs_or_abort(
  styles : T,
  base~ : @html.Attrs = @html.Attrs::build(),
) -> @html.Attrs {
  @runtime.expect_dynamic(try_attrs(styles, base~))
}

///|
#deprecated("Use try_attrs(styles, base~)")
pub fn attrs_list(
  styles : @runtime.StyleList,
  base~ : @html.Attrs = @html.Attrs::build(),
) -> Result[@html.Attrs, Array[@runtime.DynamicValueError]] {
  try_attrs(styles, base~)
}

///|
#deprecated("Use try_attrs(@runtime.compose(base_styles).add(checked_styles), base~)")
pub fn attrs_checked(
  checked_styles : Array[@runtime.StyleResult],
  base_styles~ : Array[@runtime.CompiledStyle] = [],
  base~ : @html.Attrs = @html.Attrs::build(),
) -> Result[@html.Attrs, Array[@runtime.DynamicValueError]] {
  try_attrs(@runtime.compose(base_styles).add(checked_styles), base~)
}

///|
pub fn attrs_applied(
  applied : @runtime.AppliedStyle,
  base~ : @html.Attrs = @html.Attrs::build(),
) -> @html.Attrs {
  let result = base.class(applied.class_name)
  for entry in applied.inline_vars {
    ignore(result.style(entry.0, entry.1))
  }
  result
}

///|
pub fn apply_inline_vars(
  attrs : @html.Attrs,
  applied : @runtime.AppliedStyle,
) -> @html.Attrs {
  for entry in applied.inline_vars {
    ignore(attrs.style(entry.0, entry.1))
  }
  attrs
}
