///|
pub fn class_name(applied : @runtime.AppliedStyle) -> String {
  applied.class_name
}

///|
pub fn inline_style(applied : @runtime.AppliedStyle) -> String {
  applied.inline_vars.map(entry => entry.0 + ":" + entry.1).join(";")
}

///|
pub fn attrs_applied(
  applied : @runtime.AppliedStyle,
  base~ : Array[(String, @luna_core.Attr[Unit, String])] = [],
) -> Array[(String, @luna_core.Attr[Unit, String])] {
  let output = base.copy()
  if !applied.class_name.is_empty() {
    output.push(("class", @luna.attr(applied.class_name)))
  }
  let style = inline_style(applied)
  if !style.is_empty() {
    output.push(("style", @luna.attr(style)))
  }
  output
}

///|
pub fn[T : @runtime.StaticStyleInput] attrs(
  styles : Array[T],
  base~ : Array[(String, @luna_core.Attr[Unit, String])] = [],
) -> Array[(String, @luna_core.Attr[Unit, String])] {
  attrs_applied(@runtime.props(styles), base~)
}

///|
pub fn attrs_list(
  styles : @runtime.StyleList,
  base~ : Array[(String, @luna_core.Attr[Unit, String])] = [],
) -> Result[
  Array[(String, @luna_core.Attr[Unit, String])],
  Array[@runtime.DynamicValueError],
] {
  match styles.resolve() {
    Ok(applied) => Ok(attrs_applied(applied, base~))
    Err(errors) => Err(errors)
  }
}
