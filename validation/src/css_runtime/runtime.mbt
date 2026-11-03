///|
pub(all) struct CompiledStyle {
  entries : Array[(String, String)]
  inline_vars : Array[(String, String)]
} derive(Eq, Debug)

///|
pub(all) struct AppliedStyle {
  class_name : String
  inline_vars : Array[(String, String)]
} derive(Eq, Debug)

///|
pub fn compiled(
  entries : Array[(String, String)],
  inline_vars~ : Array[(String, String)] = [],
) -> CompiledStyle {
  { entries, inline_vars, }
}

///|
pub let none : CompiledStyle = compiled([])

///|
fn replace_or_push(
  entries : Array[(String, String)],
  key : String,
  value : String,
) -> Unit {
  for i = 0; i < entries.length(); i = i + 1 {
    if entries[i].0 == key {
      entries[i] = (key, value)
      return
    }
  }
  entries.push((key, value))
}

///|
pub fn props(styles : Array[CompiledStyle]) -> AppliedStyle {
  let merged : Array[(String, String)] = []
  let inline_vars : Array[(String, String)] = []
  for style in styles {
    for entry in style.entries {
      let key = entry.0
      let value = entry.1
      if !key.has_prefix("$$") {
        replace_or_push(merged, key, value)
      }
    }
    for entry in style.inline_vars {
      replace_or_push(inline_vars, entry.0, entry.1)
    }
  }
  let classes : Array[String] = []
  for entry in merged {
    let class_name = entry.1
    if !classes.contains(class_name) {
      classes.push(class_name)
    }
  }
  { class_name: classes.join(" "), inline_vars, }
}
