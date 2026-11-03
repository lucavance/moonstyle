///|
priv struct DebugOrigin {
  module_name : String
  export_name : String?
  namespace_name : String?
  source : @ir.SourceSpan?
} derive(Eq)

///|
priv struct DebugRuleOrigin {
  class_name : String
  origin : DebugOrigin
}

///|
priv struct DebugGlobalOrigin {
  kind : String
  name : String
  digest : String
  origin : DebugOrigin
}

///|
fn debug_source_json(source : @ir.SourceSpan?) -> Json {
  match source {
    Some(span) =>
      {
        "file": span.file,
        "line": span.line,
        "column": span.column,
        "endLine": span.end_line,
        "endColumn": span.end_column,
        "symbol": if span.symbol.is_empty() {
          null
        } else {
          Json(span.symbol)
        },
      }
    None => Json::null()
  }
}

///|
fn debug_origin_json(origin : DebugOrigin) -> Json {
  {
    "module": origin.module_name,
    "exportName": match origin.export_name {
      Some(value) => Json(value)
      None => Json::null()
    },
    "namespace": match origin.namespace_name {
      Some(value) => Json(value)
      None => Json::null()
    },
    "source": debug_source_json(origin.source),
  }
}

///|
fn debug_origin_order(left : DebugOrigin, right : DebugOrigin) -> Int32 {
  let module_order = left.module_name.compare(right.module_name)
  if module_order != 0 {
    return module_order
  }
  let export_order = left.export_name
    .unwrap_or("")
    .compare(right.export_name.unwrap_or(""))
  if export_order != 0 {
    return export_order
  }
  let namespace_order = left.namespace_name
    .unwrap_or("")
    .compare(right.namespace_name.unwrap_or(""))
  if namespace_order != 0 {
    return namespace_order
  }
  let file_order = left.source
    .map_or("", source => source.file)
    .compare(right.source.map_or("", source => source.file))
  if file_order != 0 {
    return file_order
  }
  let line_order = left.source.map_or(0, source => source.line) -
    right.source.map_or(0, source => source.line)
  if line_order != 0 {
    return line_order
  }
  let column_order = left.source.map_or(0, source => source.column) -
    right.source.map_or(0, source => source.column)
  if column_order != 0 {
    return column_order
  }
  left.source
  .map_or("", source => source.symbol)
  .compare(right.source.map_or("", source => source.symbol))
}

///|
fn same_debug_origin(left : DebugOrigin, right : DebugOrigin) -> Bool {
  left == right
}

///|
fn add_debug_rule_origin(
  origins : Array[DebugRuleOrigin],
  class_name : String,
  origin : DebugOrigin,
) -> Unit {
  if !origins.any(entry => {
      entry.class_name == class_name && same_debug_origin(entry.origin, origin)
    }) {
    origins.push({ class_name, origin, })
  }
}

///|
fn add_debug_global_origin(
  origins : Array[DebugGlobalOrigin],
  kind : String,
  name : String,
  digest : String,
  origin : DebugOrigin,
) -> Unit {
  if !origins.any(entry => {
      entry.kind == kind &&
      entry.name == name &&
      entry.digest == digest &&
      same_debug_origin(entry.origin, origin)
    }) {
    origins.push({ kind, name, digest, origin, })
  }
}

///|
fn local_debug_origins(
  registry : @ir.Registry,
) -> (Array[DebugRuleOrigin], Array[DebugGlobalOrigin]) {
  let rule_origins : Array[DebugRuleOrigin] = []
  let global_origins : Array[DebugGlobalOrigin] = []
  for style_set in resolved_registry_styles(registry) {
    for namespace_ in style_set.namespaces {
      for declaration in namespace_.declarations {
        let compiled = @core.compile(
          @ir.style_set(style_set.export_name, [
            @ir.style_namespace(namespace_.name, [declaration]),
          ]),
        )
        let origin : DebugOrigin = {
          module_name: registry.module_name,
          export_name: Some(style_set.export_name),
          namespace_name: Some(namespace_.name),
          source: declaration.source,
        }
        for rule in compiled.rules {
          add_debug_rule_origin(rule_origins, rule.class_name, origin)
        }
        for global in compiled.globals {
          add_debug_global_origin(
            global_origins,
            global.kind,
            global.name,
            global.digest,
            origin,
          )
        }
      }
    }
  }
  (rule_origins, global_origins)
}

///|
fn split_debug_namespace(
  root_module : String,
  value : String,
) -> (String, String) {
  match value.find(":") {
    Some(index) => (value[:index].to_owned(), value[index + 1:].to_owned())
    None => (root_module, value)
  }
}

///|
fn add_namespace_fallback_origins(
  bundle : DependencyBundle,
  origins : Array[DebugRuleOrigin],
) -> Unit {
  for namespace_ in bundle.namespaces {
    let (module_name, namespace_name) = split_debug_namespace(
      bundle.module_name,
      namespace_.name,
    )
    for entry in namespace_.entries {
      match entry.1 {
        Some(class_names) =>
          for class_name_view in class_names.split(" ") {
            let class_name = class_name_view.to_owned()
            if !class_name.is_empty() &&
              !origins.any(candidate => {
                candidate.class_name == class_name &&
                candidate.origin.module_name == module_name &&
                candidate.origin.namespace_name == Some(namespace_name)
              }) {
              add_debug_rule_origin(origins, class_name, {
                module_name,
                export_name: None,
                namespace_name: Some(namespace_name),
                source: None,
              })
            }
          }
        None => ()
      }
    }
  }
}

///|
fn debug_origins_for_rule(
  origins : Array[DebugRuleOrigin],
  class_name : String,
) -> Array[Json] {
  let selected = origins
    .filter(entry => entry.class_name == class_name)
    .map(entry => entry.origin)
  selected.sort_by(debug_origin_order)
  selected.map(debug_origin_json)
}

///|
fn debug_origins_for_global(
  origins : Array[DebugGlobalOrigin],
  global : BundleGlobal,
) -> Array[Json] {
  let selected = origins
    .filter(entry => {
      entry.kind == global.kind &&
      entry.name == global.name &&
      entry.digest == global.digest
    })
    .map(entry => entry.origin)
  selected.sort_by(debug_origin_order)
  selected.map(debug_origin_json)
}

///|
fn debug_rule_json(
  rule : BundleRule,
  order : Int32,
  origins : Array[DebugRuleOrigin],
) -> Json {
  {
    "className": rule.class_name,
    "property": rule.property,
    "ltr": rule.ltr,
    "rtl": match rule.rtl {
      Some(value) => Json(value)
      None => Json::null()
    },
    "css": render_bundle_rule(rule),
    "priority100": rule.priority100,
    "order": order,
    "origins": debug_origins_for_rule(origins, rule.class_name),
  }
}

///|
fn debug_global_json(
  global : BundleGlobal,
  order : Int32,
  origins : Array[DebugGlobalOrigin],
) -> Json {
  {
    "kind": global.kind,
    "name": global.name,
    "css": global.css,
    "digest": global.digest,
    "order": order,
    "origins": debug_origins_for_global(origins, global),
  }
}

///|
#internal(experimental, "Developer tooling metadata; not a supported authoring API.")
pub fn render_debug_manifest(
  registry : @ir.Registry,
  bundle : CompiledBundle,
) -> Result[String, Array[@core.Diagnostic]] {
  let decoded = match decode_bundle(bundle.manifest) {
    Ok(value) => value
    Err(diagnostics) => return Err(diagnostics)
  }
  let (rule_origins, global_origins) = local_debug_origins(registry)
  add_namespace_fallback_origins(decoded, rule_origins)
  let rules : Array[Json] = []
  for index = 0; index < decoded.rules.length(); index = index + 1 {
    rules.push(debug_rule_json(decoded.rules[index], index, rule_origins))
  }
  let globals : Array[Json] = []
  for index = 0; index < decoded.globals.length(); index = index + 1 {
    globals.push(
      debug_global_json(decoded.globals[index], index, global_origins),
    )
  }
  let manifest : Json = {
    "schemaVersion": 1,
    "module": bundle.module_name,
    "semanticDigest": bundle.semantic_digest,
    "cssDigest": content_digest(bundle.css),
    "rules": rules,
    "globals": globals,
  }
  Ok(manifest.stringify() + "\n")
}

///|
fn debug_optional_string(value : Json?) -> Bool {
  match value {
    Some(String(_)) | Some(Null) => true
    _ => false
  }
}

///|
fn valid_debug_source(value : Json) -> Bool {
  match value {
    Null => true
    Object(object) =>
      exact_fields(object, [
        "file", "line", "column", "endLine", "endColumn", "symbol",
      ]) &&
      object.get("file") is Some(String(_)) &&
      object.get("line") is Some(Number(_, ..)) &&
      object.get("column") is Some(Number(_, ..)) &&
      object.get("endLine") is Some(Number(_, ..)) &&
      object.get("endColumn") is Some(Number(_, ..)) &&
      debug_optional_string(object.get("symbol"))
    _ => false
  }
}

///|
fn valid_debug_origins(value : Json) -> Bool {
  guard value is Array(origins) else { return false }
  origins.every(origin => {
    guard origin is Object(object) &&
      exact_fields(object, ["module", "exportName", "namespace", "source"]) &&
      object.get("module") is Some(String(_)) &&
      debug_optional_string(object.get("exportName")) &&
      debug_optional_string(object.get("namespace")) &&
      object.get("source") is Some(source) else {
      return false
    }
    valid_debug_source(source)
  })
}

///|
fn valid_debug_rules(value : Json) -> Bool {
  guard value is Array(rules) else { return false }
  for index = 0; index < rules.length(); index = index + 1 {
    guard rules[index] is Object(object) &&
      exact_fields(object, [
        "className", "property", "ltr", "rtl", "css", "priority100", "order", "origins",
      ]) &&
      object.get("className") is Some(String(_)) &&
      object.get("property") is Some(String(_)) &&
      object.get("ltr") is Some(String(_)) &&
      debug_optional_string(object.get("rtl")) &&
      object.get("css") is Some(String(_)) &&
      object.get("priority100") is Some(Number(_, ..)) &&
      object.get("order") is Some(Number(order, ..)) &&
      order == index.to_double() &&
      object.get("origins") is Some(origins) &&
      valid_debug_origins(origins) else {
      return false
    }
  }
  true
}

///|
fn valid_debug_globals(value : Json) -> Bool {
  guard value is Array(globals) else { return false }
  for index = 0; index < globals.length(); index = index + 1 {
    guard globals[index] is Object(object) &&
      exact_fields(object, ["kind", "name", "css", "digest", "order", "origins"]) &&
      object.get("kind") is Some(String(_)) &&
      object.get("name") is Some(String(_)) &&
      object.get("css") is Some(String(_)) &&
      object.get("digest") is Some(String(_)) &&
      object.get("order") is Some(Number(order, ..)) &&
      order == index.to_double() &&
      object.get("origins") is Some(origins) &&
      valid_debug_origins(origins) else {
      return false
    }
  }
  true
}

///|
#internal(experimental, "Developer tooling metadata; not a supported authoring API.")
pub fn validate_debug_manifest(
  input : String,
  semantic_digest : String,
  css : String,
) -> Bool {
  let value = @json.parse(input) catch { _ => return false }
  guard value is Object(object) &&
    exact_fields(object, [
      "schemaVersion", "module", "semanticDigest", "cssDigest", "rules", "globals",
    ]) &&
    object.get("schemaVersion") is Some(Number(version, ..)) &&
    version == 1.0 &&
    object.get("module") is Some(String(_)) &&
    object.get("semanticDigest") is Some(String(actual_semantic_digest)) &&
    actual_semantic_digest == semantic_digest &&
    object.get("cssDigest") is Some(String(css_digest)) &&
    css_digest == content_digest(css) &&
    object.get("rules") is Some(rules) &&
    object.get("globals") is Some(globals) else {
    return false
  }
  valid_debug_rules(rules) && valid_debug_globals(globals)
}

///|
#internal(experimental, "Developer tooling metadata; not a supported authoring API.")
pub fn validate_debug_manifest_outputs(
  input : String,
  css : String,
  bundle_manifest : String,
) -> Bool {
  match decode_bundle(bundle_manifest) {
    Ok(bundle) => validate_debug_manifest(input, bundle.semantic_digest, css)
    Err(_) => false
  }
}
