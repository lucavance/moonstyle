///|
pub struct CompiledStyle {
  entries : Array[(String, String?)]
  inline_vars : Array[(String, String)]
}

///|
/// A generated marker is both a style input (it applies its stable marker
/// class) and a typed selector identity consumable by relational conditions.
pub struct SelectorMarker {
  module_name : String
  name : String
  class_name : String
  compiled : CompiledStyle
}

///|
pub fn selector_marker(
  module_name : String,
  name : String,
  class_name : String,
) -> SelectorMarker {
  {
    module_name,
    name,
    class_name,
    compiled: {
      entries: [("marker|" + module_name + "|" + name, Some(class_name))],
      inline_vars: [],
    },
  }
}

///|
pub fn SelectorMarker::module_name(self : SelectorMarker) -> String {
  self.module_name
}

///|
pub fn SelectorMarker::name(self : SelectorMarker) -> String {
  self.name
}

///|
pub fn SelectorMarker::class_name(self : SelectorMarker) -> String {
  self.class_name
}

///|
pub(all) struct AppliedStyle {
  class_name : String
  inline_vars : Array[(String, String)]
} derive(Eq, Debug)

///|
pub(all) struct DynamicValueError {
  variable : String
  code : String
  label : String
} derive(Eq, Debug)

///|
pub type StyleResult = Result[CompiledStyle, Array[DynamicValueError]]

///|
pub struct StyleList {
  styles : Array[CompiledStyle]
  errors : Array[DynamicValueError]
}

///|
pub(open) trait StyleInput {
  fn append_to(Self, StyleList) -> StyleList
}

///|
pub(open) trait StaticStyleInput {
  fn to_compiled(Self) -> CompiledStyle
}

///|
pub fn style_list() -> StyleList {
  { styles: [], errors: [], }
}

///|
pub fn[T : StyleInput] compose(initial : T) -> StyleList {
  initial.append_to(style_list())
}

///|
#deprecated("Use compose(input) for a non-empty composition or style_list() for an empty composition", skip_current_package=true)
pub fn[T : StyleInput] styles(initial : Array[T]) -> StyleList {
  compose(initial)
}

///|
fn StyleList::append_style(
  self : StyleList,
  style : CompiledStyle,
) -> StyleList {
  let next_styles = self.styles.copy()
  next_styles.push(style)
  { styles: next_styles, errors: self.errors.copy(), }
}

///|
fn StyleList::append_errors(
  self : StyleList,
  errors : Array[DynamicValueError],
) -> StyleList {
  let next_errors = self.errors.copy()
  for error in errors {
    next_errors.push(error)
  }
  { styles: self.styles.copy(), errors: next_errors, }
}

///|
fn StyleList::append_list(self : StyleList, other : StyleList) -> StyleList {
  let next_styles = self.styles.copy()
  for style in other.styles {
    next_styles.push(style)
  }
  let next_errors = self.errors.copy()
  for error in other.errors {
    next_errors.push(error)
  }
  { styles: next_styles, errors: next_errors, }
}

///|
pub impl StyleInput for CompiledStyle with fn append_to(self, list) {
  list.append_style(self)
}

///|
pub impl StaticStyleInput for CompiledStyle with fn to_compiled(self) {
  self
}

///|
pub impl StyleInput for SelectorMarker with fn append_to(self, list) {
  list.append_style(self.compiled)
}

///|
pub impl StaticStyleInput for SelectorMarker with fn to_compiled(self) {
  self.compiled
}

///|
pub impl[T : StyleInput] StyleInput for Result[T, Array[DynamicValueError]] with fn append_to(
  self,
  list,
) {
  match self {
    Ok(input) => input.append_to(list)
    Err(errors) => list.append_errors(errors)
  }
}

///|
pub impl StyleInput for StyleList with fn append_to(self, list) {
  list.append_list(self)
}

///|
pub impl[T : StyleInput] StyleInput for Array[T] with fn append_to(self, list) {
  let mut result = list
  for input in self {
    result = input.append_to(result)
  }
  result
}

///|
pub impl[T : StyleInput] StyleInput for T? with fn append_to(self, list) {
  match self {
    Some(input) => input.append_to(list)
    None => list
  }
}

///|
pub fn[T : StyleInput] StyleList::add(self : StyleList, input : T) -> StyleList {
  input.append_to(self)
}

///|
pub fn[T : StyleInput] StyleList::when(
  self : StyleList,
  enabled : Bool,
  input : T,
) -> StyleList {
  if enabled {
    input.append_to(self)
  } else {
    self
  }
}

///|
pub fn dynamic_value_error(
  variable : String,
  code : String,
  label : String,
) -> DynamicValueError {
  { variable, code, label, }
}

///|
pub let none : CompiledStyle = { entries: [], inline_vars: [], }

///|
pub fn CompiledStyle::when(
  self : CompiledStyle,
  enabled : Bool,
) -> CompiledStyle {
  if enabled {
    self
  } else {
    none
  }
}

///|
pub fn checked_when(style : StyleResult, enabled : Bool) -> StyleResult {
  if enabled {
    style
  } else {
    Ok(none)
  }
}

///|
pub fn compiled(
  entries : Array[(String, String)],
  inline_vars~ : Array[(String, String)] = [],
) -> CompiledStyle {
  { entries: entries.map(entry => (entry.0, Some(entry.1))), inline_vars, }
}

///|
pub fn compiled_v2(
  entries : Array[(String, String?)],
  inline_vars~ : Array[(String, String)] = [],
) -> CompiledStyle {
  { entries, inline_vars, }
}

///|
pub fn compiled_v3(
  entries : Array[(String, String?)],
  inline_vars~ : Array[(String, String)] = [],
) -> CompiledStyle {
  { entries, inline_vars, }
}

///|
pub fn compiled_v5(
  entries : Array[(String, String?)],
  inline_vars~ : Array[(String, String)] = [],
) -> CompiledStyle {
  { entries, inline_vars, }
}

///|
pub fn bind_length(
  variable : @values.CssVar[@values.Length],
  value : @values.Length,
) -> (String, String) {
  let css = value.to_css()
  (variable.name(), if css == "0" { "0px" } else { css })
}

///|
pub fn bind_color(
  variable : @values.CssVar[@values.Color],
  value : @values.Color,
) -> (String, String) {
  (variable.name(), value.to_css())
}

///|
pub fn bind_number(
  variable : @values.CssVar[@values.Number],
  value : @values.Number,
) -> (String, String) {
  (variable.name(), value.to_css())
}

///|
pub fn bind_percentage(
  variable : @values.CssVar[@values.Percentage],
  value : @values.Percentage,
) -> (String, String) {
  (variable.name(), value.to_css())
}

///|
fn merge_compiled_entry(
  entries : Array[(String, String?)],
  key : String,
  value : String?,
) -> Unit {
  match entries.search_by(entry => entry.0 == key) {
    Some(index) => entries[index] = (key, value)
    None => entries.push((key, value))
  }
}

///|
fn merge_inline_var(
  entries : Array[(String, String)],
  key : String,
  value : String,
) -> Unit {
  match entries.search_by(entry => entry.0 == key) {
    Some(index) => entries[index] = (key, value)
    None => entries.push((key, value))
  }
}

///|
pub fn[T : StaticStyleInput] props(styles : Array[T]) -> AppliedStyle {
  props_compiled(styles.map(style => style.to_compiled()))
}

///|
fn props_compiled(styles : Array[CompiledStyle]) -> AppliedStyle {
  let merged : Array[(String, String?)] = []
  let inline_vars : Array[(String, String)] = []
  for style in styles {
    for entry in style.entries {
      if !entry.0.contains("|") {
        let conditional_prefix = entry.0 + "|"
        merged.retain(existing => !existing.0.has_prefix(conditional_prefix))
      }
    }
    for entry in style.entries {
      merge_compiled_entry(merged, entry.0, entry.1)
    }
    for entry in style.inline_vars {
      merge_inline_var(inline_vars, entry.0, entry.1)
    }
  }
  let classes : Array[String] = []
  for entry in merged {
    match entry.1 {
      Some(class_names) =>
        for class_name_view in class_names.split(" ") {
          let class_name = class_name_view.to_owned()
          if !class_name.is_empty() && !classes.contains(class_name) {
            classes.push(class_name)
          }
        }
      None => ()
    }
  }
  { class_name: classes.join(" "), inline_vars, }
}

///|
pub fn StyleList::resolve(
  self : StyleList,
) -> Result[AppliedStyle, Array[DynamicValueError]] {
  if self.errors.is_empty() {
    Ok(props_compiled(self.styles))
  } else {
    Err(self.errors.copy())
  }
}

///|
pub fn props_checked(
  checked_styles : Array[StyleResult],
  base_styles~ : Array[CompiledStyle] = [],
) -> Result[AppliedStyle, Array[DynamicValueError]] {
  compose(base_styles).add(checked_styles).resolve()
}

///|
fn dynamic_error_message(errors : Array[DynamicValueError]) -> String {
  let details = errors.map(error => {
    error.variable + ": " + error.code + " (" + error.label + ")"
  })
  "Invalid dynamic style values: " + details.join(", ")
}

///|
pub fn[T] expect_dynamic(result : Result[T, Array[DynamicValueError]]) -> T {
  match result {
    Ok(value) => value
    Err(errors) => abort(dynamic_error_message(errors))
  }
}
