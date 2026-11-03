///|
pub(all) struct CompiledBundle {
  schema_version : Int32
  module_name : String
  semantic_digest : String
  css : String
  mappings : String
  mappings_manifest : String
  manifest : String
  diagnostics : Array[@core.Diagnostic]
} derive(Eq, Debug)

///|
priv struct MappingContract {
  method_name : String
  trait_reference : String
  properties : Array[@ir.ContractProperty]
}

///|
fn contract_variable_order(
  left : @ir.ContractVariable,
  right : @ir.ContractVariable,
) -> Int32 {
  let variable_order = left.variable.compare(right.variable)
  if variable_order != 0 {
    variable_order
  } else {
    left.category.compare(right.category)
  }
}

///|
fn canonical_contract_property(
  property : @ir.ContractProperty,
) -> @ir.ContractProperty {
  match property.policy {
    AnySafe => @ir.any_contract_property(property.name)
    Exact(values, tokens, slots, expressions) => {
      let values = values.map(@core.canonical_css_value)
      values.sort_by((left, right) => left.compare(right))
      let tokens = tokens.copy()
      tokens.sort_by(contract_variable_order)
      let slots = slots.copy()
      slots.sort_by(contract_variable_order)
      let expressions = expressions.copy()
      expressions.sort()
      @ir.exact_contract_property(
        property.name,
        values~,
        tokens~,
        slots~,
        expressions~,
      )
    }
  }
}

///|
fn canonical_contract_properties(
  properties : Array[@ir.ContractProperty],
) -> Array[@ir.ContractProperty] {
  let properties = properties.map(canonical_contract_property)
  properties.sort_by((left, right) => left.name.compare(right.name))
  properties
}

///|
fn same_contract_variable(
  left : @ir.ContractVariable,
  right : @ir.ContractVariable,
) -> Bool {
  left.variable == right.variable && left.category == right.category
}

///|
fn contract_property_accepts(
  property : @ir.ContractProperty,
  declaration : @ir.Declaration,
) -> Bool {
  if property.name != declaration.property || declaration.unsafe_raw {
    return false
  }
  match property.policy {
    AnySafe =>
      match declaration.value_origin {
        UnsafeOrigin => false
        _ => true
      }
    Exact(values, tokens, slots, expressions) =>
      match declaration.value_origin {
        LiteralOrigin(literals) =>
          !literals.is_empty() &&
          literals.every(literal => {
            values.contains(@core.canonical_css_value(literal))
          })
        TokenOrigin(token) =>
          tokens.any(candidate => same_contract_variable(candidate, token))
        DynamicSlotOrigin(slot) =>
          slots.any(candidate => same_contract_variable(candidate, slot))
        ClearOrigin => true
        ExpressionOrigin(identity) =>
          expressions.contains(identity) ||
          legacy_grid_literal_matches(values, declaration)
        ExpressionFallbackOrigin(identities) =>
          (
            !identities.is_empty() &&
            identities.every(identity => expressions.contains(identity))
          ) ||
          legacy_grid_literal_matches(values, declaration)
        MixedFallbackOrigin(origins) =>
          !origins.is_empty() &&
          origins.every(origin => {
            contract_property_accepts(property, {
              ..declaration,
              value_origin: origin,
            })
          })
        AnimationOrigin | UnsafeOrigin => false
      }
  }
}

///|
fn severity_name(severity : @core.DiagnosticSeverity) -> String {
  match severity {
    Error => "error"
    Warning => "warning"
  }
}

///|
fn source_prefix(source : @ir.SourceSpan?) -> String {
  match source {
    Some(span) =>
      span.file +
      ":" +
      span.line.to_string() +
      ":" +
      span.column.to_string() +
      ": "
    None => ""
  }
}

///|
fn diagnostic_order(left : @core.Diagnostic, right : @core.Diagnostic) -> Int32 {
  let severity = match (left.severity, right.severity) {
    (Error, Warning) => -1
    (Warning, Error) => 1
    _ => 0
  }
  if severity != 0 {
    return severity
  }
  let left_module = left.context.map_or("", context => context.module_name)
  let right_module = right.context.map_or("", context => context.module_name)
  let module_order = left_module.compare(right_module)
  if module_order != 0 {
    return module_order
  }
  let left_path = left.context.map_or("", context => {
    context.artifact_path.unwrap_or("")
  })
  let right_path = right.context.map_or("", context => {
    context.artifact_path.unwrap_or("")
  })
  let path_order = left_path.compare(right_path)
  if path_order != 0 {
    return path_order
  }
  let left_line = left.source.map_or(0, source => source.line)
  let right_line = right.source.map_or(0, source => source.line)
  if left_line != right_line {
    return left_line - right_line
  }
  let left_column = left.source.map_or(0, source => source.column)
  let right_column = right.source.map_or(0, source => source.column)
  if left_column != right_column {
    return left_column - right_column
  }
  let code_order = left.code.compare(right.code)
  if code_order != 0 {
    code_order
  } else {
    left.message.compare(right.message)
  }
}

///|
fn sorted_diagnostics(
  diagnostics : Array[@core.Diagnostic],
) -> Array[@core.Diagnostic] {
  let sorted = diagnostics.copy()
  sorted.sort_by(diagnostic_order)
  sorted
}

///|
pub fn render_diagnostics_text(diagnostics : Array[@core.Diagnostic]) -> String {
  if diagnostics.is_empty() {
    return ""
  }
  sorted_diagnostics(diagnostics)
  .map(diagnostic => {
    let symbol = match diagnostic.source {
      Some(span) if !span.symbol.is_empty() => " [" + span.symbol + "]"
      _ => ""
    }
    source_prefix(diagnostic.source) +
    severity_name(diagnostic.severity) +
    " " +
    diagnostic.code +
    ": " +
    diagnostic.message +
    symbol
  })
  .join("\n") +
  "\n"
}

///|
fn diagnostic_json(diagnostic : @core.Diagnostic) -> Json {
  let empty_chain : Array[String] = []
  let (module_name, artifact_path, dependency_chain) = match
    diagnostic.context {
    Some(context) =>
      (
        if context.module_name.is_empty() {
          Json::null()
        } else {
          Json(context.module_name)
        },
        match context.artifact_path {
          Some(path) => Json(path)
          None => Json::null()
        },
        Json(context.dependency_chain),
      )
    None => (Json::null(), Json::null(), Json(empty_chain))
  }
  match diagnostic.source {
    Some(span) =>
      {
        "code": diagnostic.code,
        "severity": severity_name(diagnostic.severity),
        "message": diagnostic.message,
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
        "module": module_name,
        "artifactPath": artifact_path,
        "dependencyChain": dependency_chain,
      }
    None =>
      {
        "code": diagnostic.code,
        "severity": severity_name(diagnostic.severity),
        "message": diagnostic.message,
        "file": null,
        "line": null,
        "column": null,
        "endLine": null,
        "endColumn": null,
        "symbol": null,
        "module": module_name,
        "artifactPath": artifact_path,
        "dependencyChain": dependency_chain,
      }
  }
}

///|
pub fn render_diagnostics_json(diagnostics : Array[@core.Diagnostic]) -> String {
  Json(sorted_diagnostics(diagnostics).map(diagnostic_json)).stringify() + "\n"
}

///|
fn artifact_diagnostic(code : String, message : String) -> @core.Diagnostic {
  @core.error_diagnostic(code, message)
}

///|
pub fn migrate_v2(input : String) -> Result[String, Array[@core.Diagnostic]] {
  let value = @json.parse(input) catch {
    _ =>
      return Err([
        artifact_diagnostic("STYLE_ARTIFACT_JSON", "Artifact is not valid JSON"),
      ])
  }
  match value {
    Object(
      {
        "schemaVersion": Number(version, ..),
        "module": String(module_name),
        "namespaces": namespaces,
        "rules": rules,
        ..
      }
    ) if version == 2.0 => {
      let semantic_manifest : Json = {
        "schemaVersion": 3,
        "module": module_name,
        "dependencies": [],
        "namespaces": namespaces,
        "rules": rules,
        "globals": [],
      }
      let digest = semantic_digest(semantic_manifest.stringify())
      let manifest : Json = {
        "schemaVersion": 3,
        "module": module_name,
        "semanticDigest": digest,
        "dependencies": [],
        "namespaces": namespaces,
        "rules": rules,
        "globals": [],
      }
      Ok(manifest.stringify() + "\n")
    }
    _ =>
      Err([
        artifact_diagnostic(
          "STYLE_ARTIFACT_SCHEMA", "Explicit migration requires artifact schema v2",
        ),
      ])
  }
}

///|
pub fn migrate_v3_to_v4(
  input : String,
  direct_modules : Array[String],
) -> Result[String, Array[@core.Diagnostic]] {
  let value = @json.parse(input) catch {
    _ =>
      return Err([
        artifact_diagnostic("STYLE_ARTIFACT_JSON", "Artifact is not valid JSON"),
      ])
  }
  guard value is Object(object) &&
    object.get("schemaVersion") is Some(Number(version, ..)) &&
    version == 3.0 &&
    object.get("module") is Some(String(module_name)) &&
    object.get("dependencies") is Some(Array(dependencies)) &&
    object.get("namespaces") is Some(namespaces) &&
    object.get("rules") is Some(rules) &&
    object.get("globals") is Some(globals) else {
    return Err([
      artifact_diagnostic(
        "STYLE_ARTIFACT_SCHEMA", "Explicit v3-to-v4 migration requires a complete artifact schema v3",
      ),
    ])
  }
  let direct : Array[Json] = []
  let seen : Array[String] = []
  for module_ in direct_modules {
    if seen.contains(module_) {
      return Err([
        artifact_diagnostic(
          "STYLE_ARTIFACT_DIRECT_DEPENDENCY", "Direct dependency module names must be unique",
        ),
      ])
    }
    seen.push(module_)
    let matches = dependencies.filter(item => {
      match item {
        Object(dependency) =>
          dependency.get("module") is Some(String(name)) && name == module_
        _ => false
      }
    })
    if matches.length() != 1 {
      return Err([
        artifact_diagnostic(
          "STYLE_ARTIFACT_DIRECT_DEPENDENCY",
          "Direct dependency is absent or duplicated in the v3 dependency list: " +
          module_,
        ),
      ])
    }
    direct.push(matches[0])
  }
  let semantic_manifest : Json = {
    "schemaVersion": 4,
    "module": module_name,
    "directDependencies": direct,
    "dependencyClosure": dependencies,
    "namespaces": namespaces,
    "rules": rules,
    "globals": globals,
  }
  let digest = semantic_digest(semantic_manifest.stringify())
  let manifest : Json = {
    "schemaVersion": 4,
    "module": module_name,
    "semanticDigest": digest,
    "directDependencies": direct,
    "dependencyClosure": dependencies,
    "namespaces": namespaces,
    "rules": rules,
    "globals": globals,
  }
  Ok(manifest.stringify() + "\n")
}

///|
fn moon_string(value : String) -> String {
  let output = StringBuilder(size_hint=value.length() + 2)
  output.write_char('"')
  for i = 0; i < value.length(); i = i + 1 {
    let code = value.unsafe_get(i).to_int()
    if code == 34 || code == 92 {
      output.write_char('\\')
      output.write_char(code.unsafe_to_char())
    } else if code == 10 {
      output.write_string("\\n")
    } else if code == 13 {
      output.write_string("\\r")
    } else if code == 9 {
      output.write_string("\\t")
    } else {
      output.write_char(code.unsafe_to_char())
    }
  }
  output.write_char('"')
  output.to_string()
}

///|
fn render_entries(
  entries : Array[(String, String?)],
  indent : String,
) -> String {
  if entries.is_empty() {
    return "[]"
  }
  let lines = entries.map(entry => {
    let value = match entry.1 {
      Some(class_name) => "Some(" + moon_string(class_name) + ")"
      None => "None"
    }
    indent + "  (" + moon_string(entry.0) + ", " + value + "),"
  })
  "[\n" + lines.join("\n") + "\n" + indent + "]"
}

///|
fn dynamic_declarations(namespace_ : @ir.Namespace) -> Array[@ir.Declaration] {
  let output = []
  for declaration in namespace_.declarations {
    match declaration.value {
      Dynamic(_, _, _) => output.push(declaration)
      Expression(_) | ExpressionFallbacks(_) =>
        for value in declaration_expressions(declaration) {
          for use_ in value.variables() {
            if use_.variable.role == DynamicSlotRole {
              output.push({
                ..declaration,
                value: @ir.Dynamic(
                  use_.variable.definition.name,
                  "",
                  use_.variable.definition.category.name(),
                ),
              })
            }
          }
        }
      _ => ()
    }
  }
  output
}

///|
fn dynamic_variable(declaration : @ir.Declaration) -> String {
  match declaration.value {
    Dynamic(variable, _, _) => variable
    _ => ""
  }
}

///|
fn dynamic_parameter_name(variable : String) -> String {
  let trimmed = if variable.has_prefix("--") {
    variable[2:].to_owned()
  } else {
    variable
  }
  trimmed.replace_all(old="-", new="_")
}

///|
fn dynamic_moon_type(category : String) -> String {
  match category {
    "length" => "@values.Length"
    "color" => "@values.Color"
    "number" => "@values.Number"
    "integer" => "@values.Integer"
    "percentage" => "@values.Percentage"
    "length-percentage" => "@values.LengthPercentage"
    "time" => "@values.Time"
    "angle" => "@values.Angle"
    "resolution" => "@values.Resolution"
    "url" => "@values.Url"
    _ => "String"
  }
}

///|
fn generated_pascal_name(value : String) -> String {
  let output = StringBuilder(size_hint=value.length() + 8)
  let mut capitalize = true
  let mut wrote = false
  for index = 0; index < value.length(); index = index + 1 {
    let code = value.unsafe_get(index).to_int()
    let lower = code >= 97 && code <= 122
    let upper = code >= 65 && code <= 90
    let digit = code >= 48 && code <= 57
    if lower || upper || digit {
      if !wrote && digit {
        output.write_string("Style")
      }
      if capitalize && lower {
        output.write_char((code - 32).unsafe_to_char())
      } else {
        output.write_char(code.unsafe_to_char())
      }
      wrote = true
      capitalize = false
    } else {
      capitalize = true
    }
  }
  if wrote {
    output.to_string()
  } else {
    "Generated"
  }
}

///|
fn generated_style_type(name : String) -> String {
  generated_pascal_name(name) + "Style"
}

///|
fn contract_trait_name(contract : @ir.StyleContract) -> String {
  generated_pascal_name(contract.name) + "StyleInput"
}

///|
fn contract_list_name(contract : @ir.StyleContract) -> String {
  generated_pascal_name(contract.name) + "StyleList"
}

///|
fn namespace_accepts_contract(
  namespace_ : @ir.Namespace,
  contract : MappingContract,
) -> Bool {
  if namespace_.declarations.any(declaration => declaration.unsafe_raw) {
    return false
  }
  namespace_.declarations.every(declaration => {
    contract.properties.any(property => {
      contract_property_accepts(property, declaration)
    })
  })
}

///|
fn render_style_type(
  type_name : String,
  contracts : Array[MappingContract],
) -> String {
  let promoted_methods : Array[String] = []
  let implementations = contracts.map(contract => {
    // Contracts from different packages may use the same method name. Keep
    // every trait implementation, but attach a regular method only once.
    let extension = if promoted_methods.contains(contract.method_name) {
      ""
    } else {
      promoted_methods.push(contract.method_name)
      "\n\n///|\npub extend " +
      type_name +
      " with " +
      contract.trait_reference +
      "::{" +
      contract.method_name +
      "}"
    }
    "///|\npub impl " +
    contract.trait_reference +
    " for " +
    type_name +
    extension
  })
  "///|\npub struct " +
  type_name +
  " {\n  compiled : @runtime.CompiledStyle\n}\n\n" +
  "///|\npub impl @runtime.StaticStyleInput for " +
  type_name +
  " with fn to_compiled(self) {\n  self.compiled\n}\n\n" +
  "///|\npub impl @runtime.StyleInput for " +
  type_name +
  " with fn append_to(self, list) {\n  list.add(self.compiled)\n}" +
  "\n\n///|\npub extend " +
  type_name +
  " with @runtime.StaticStyleInput::{to_compiled}\n\n///|\npub extend " +
  type_name +
  " with @runtime.StyleInput::{append_to}" +
  (if implementations.is_empty() {
    ""
  } else {
    "\n\n" + implementations.join("\n\n")
  })
}

///|
fn render_contract(contract : @ir.StyleContract) -> String {
  let pascal = generated_pascal_name(contract.name)
  let trait_name = contract_trait_name(contract)
  let list_name = contract_list_name(contract)
  let list_constructor = contract.name + "_styles"
  let empty_constructor = "empty_" + contract.name + "_styles"
  "///|\npub struct " +
  list_name +
  " {\n  inner : @runtime.StyleList\n}\n\n" +
  "///|\npub(open) trait " +
  trait_name +
  " : @runtime.StyleInput {\n  fn append_" +
  contract.name +
  "_style(Self, " +
  list_name +
  ") -> " +
  list_name +
  " = _\n}\n\n" +
  "///|\nimpl " +
  trait_name +
  " with fn append_" +
  contract.name +
  "_style(self, list) {\n  " +
  list_name +
  "::{ inner: list.inner.add(self) }\n}\n\n" +
  "///|\npub fn[T : " +
  trait_name +
  "] " +
  list_constructor +
  "(first : T) -> " +
  list_name +
  " {\n  " +
  list_name +
  "::{ inner: @runtime.style_list().add(first) }\n}\n\n" +
  "///|\npub fn " +
  empty_constructor +
  "() -> " +
  list_name +
  " {\n  " +
  list_name +
  "::{ inner: @runtime.style_list() }\n}\n\n" +
  "///|\npub fn[T : " +
  trait_name +
  "] " +
  list_name +
  "::add(self : " +
  list_name +
  ", input : T) -> " +
  list_name +
  " {\n  { inner: self.inner.add(input) }\n}\n\n" +
  "///|\npub fn[T : " +
  trait_name +
  "] " +
  list_name +
  "::when(self : " +
  list_name +
  ", enabled : Bool, input : T) -> " +
  list_name +
  " {\n  { inner: self.inner.when(enabled, input) }\n}\n\n" +
  "///|\npub fn " +
  list_name +
  "::to_style_list(self : " +
  list_name +
  ") -> @runtime.StyleList {\n  self.inner\n}\n\n" +
  "///|\npub fn " +
  list_name +
  "::resolve(self : " +
  list_name +
  ") -> Result[@runtime.AppliedStyle, Array[@runtime.DynamicValueError]] {\n  self.inner.resolve()\n}\n\n" +
  "///|\npub impl @runtime.StyleInput for " +
  list_name +
  " with fn append_to(self, list) {\n  list.add(self.inner)\n}\n\n" +
  "///|\npub extend " +
  list_name +
  " with @runtime.StyleInput::{append_to}\n\n" +
  "///|\npub impl " +
  trait_name +
  " for " +
  list_name +
  "\n\n" +
  "///|\npub extend " +
  list_name +
  " with " +
  trait_name +
  "::{append_" +
  contract.name +
  "_style}\n\n" +
  "///|\npub impl[T : " +
  trait_name +
  "] " +
  trait_name +
  " for Array[T]\n\n" +
  "///|\npub impl[T : " +
  trait_name +
  "] " +
  trait_name +
  " for T?\n\n" +
  "///|\npub impl[T : " +
  trait_name +
  "] " +
  trait_name +
  " for Result[T, Array[@runtime.DynamicValueError]]\n\n" +
  "///|\npub let " +
  contract.name +
  "_contract_properties : Array[String] = [" +
  contract.properties.map(property => moon_string(property.name)).join(", ") +
  "]\n\n" +
  "///|\npub let " +
  contract.name +
  "_contract_name : String = " +
  moon_string(pascal)
}

///|
fn render_namespace(
  namespace_ : @ir.Namespace,
  compiled : @core.CompiledNamespace,
  contracts : Array[MappingContract],
) -> String {
  let type_name = generated_style_type(namespace_.name)
  let accepted = contracts.filter(contract => {
    namespace_accepts_contract(namespace_, contract)
  })
  let type_block = render_style_type(type_name, accepted)
  let all_dynamics = dynamic_declarations(namespace_)
  let dynamics : Array[@ir.Declaration] = []
  for declaration in all_dynamics {
    if !dynamics.any(existing => {
        dynamic_variable(existing) == dynamic_variable(declaration)
      }) {
      dynamics.push(declaration)
    }
  }
  if dynamics.is_empty() {
    return type_block +
      "\n\n///|\npub let " +
      namespace_.name +
      " : " +
      type_name +
      " = " +
      type_name +
      "::{ compiled: @runtime.compiled_v5(\n" +
      render_entries(compiled.entries, "") +
      "\n) }"
  }
  let parameters = dynamics.map(declaration => {
    match declaration.value {
      Dynamic(variable, _, category) =>
        "  " +
        dynamic_parameter_name(variable) +
        " : " +
        dynamic_moon_type(category) +
        ","
      _ => ""
    }
  })
  let value_bindings = dynamics.map(declaration => {
    match declaration.value {
      Dynamic(variable, _, category) => {
        let parameter = dynamic_parameter_name(variable)
        let css = if category == "length" || category == "length-percentage" {
          "match " +
          parameter +
          ".to_css() {\n    \"0\" => \"0px\"\n    css => css\n  }"
        } else {
          parameter + (if category == "string" { "" } else { ".to_css()" })
        }
        "  let lampclaw_css_" + parameter + " = " + css
      }
      _ => ""
    }
  })
  let value_checks = dynamics.map(declaration => {
    match declaration.value {
      Dynamic(variable, _, _) => {
        let parameter = dynamic_parameter_name(variable)
        // Parameters are deduplicated by slot, but every use still contributes
        // its constraints. A permissive property must not hide font-width.
        let font_width_use = all_dynamics.search_by(use_ => {
          !use_.unsafe_raw &&
          (use_.property == "fontWidth" || use_.property == "font-width") &&
          dynamic_variable(use_) == variable
        })
        let (checker, suffix) = match font_width_use {
          Some(index) => {
            let suffix = match all_dynamics[index].value {
              Dynamic(_, suffix, _) => suffix
              _ => ""
            }
            (
              "@values.property_value_issues(\"fontWidth\", lampclaw_css_", suffix,
            )
          }
          None => ("@values.value_issues(lampclaw_css_", "")
        }
        let constraints : Array[String] = []
        // A slot may be shared with a property such as margin that permits
        // negative values. Every direct use contributes its range constraint.
        if namespace_.declarations.any(use_ => {
            !use_.unsafe_raw &&
            ["width", "fontSize", "font-size"].contains(use_.property) &&
            use_.value is Dynamic(_, _, _) &&
            dynamic_variable(use_) == variable
          }) {
          constraints.push("nonnegative")
        }
        for authored in namespace_.declarations {
          for expression in declaration_expressions(authored) {
            for use_ in expression.variables() {
              if use_.variable.definition.name == variable {
                for constraint in use_.constraints {
                  if !constraints.contains(constraint) {
                    constraints.push(constraint)
                  }
                }
                for
                  constraint in expression.property_constraints(
                    authored.property,
                  ) {
                  if !constraints.contains(constraint) {
                    constraints.push(constraint)
                  }
                }
                if authored.property == "fontWidth" ||
                  authored.property == "font-width" {
                  if !constraints.contains("fontWidth") {
                    constraints.push("fontWidth")
                  }
                }
              }
            }
          }
        }
        if !constraints.is_empty() &&
          font_width_use is Some(_) &&
          !constraints.contains("fontWidth") {
          constraints.push("fontWidth")
        }
        let checker = if constraints.is_empty() {
          checker
        } else {
          "@values.expression_value_issues([" +
          constraints.map(moon_string).join(", ") +
          "], lampclaw_css_"
        }
        "  for issue in " +
        checker +
        parameter +
        (if suffix.is_empty() { "" } else { " + " + moon_string(suffix) }) +
        ") {\n" +
        "    errors.push(@runtime.dynamic_value_error(" +
        moon_string(variable) +
        ", issue.code, issue.label))\n" +
        "  }"
      }
      _ => ""
    }
  })
  let inline_vars = dynamics.map(declaration => {
    match declaration.value {
      Dynamic(variable, suffix, _) =>
        "    (" +
        moon_string(variable) +
        ", lampclaw_css_" +
        dynamic_parameter_name(variable) +
        " + " +
        moon_string(suffix) +
        "),"
      _ => ""
    }
  })
  type_block +
  "\n\n///|\npub fn " +
  namespace_.name +
  "(\n" +
  parameters.join("\n") +
  "\n) -> Result[" +
  type_name +
  ", Array[@runtime.DynamicValueError]] {\n" +
  value_bindings.join("\n") +
  "\n  let errors : Array[@runtime.DynamicValueError] = []\n" +
  value_checks.join("\n") +
  "\n  if !errors.is_empty() {\n" +
  "    return Err(errors)\n" +
  "  }\n" +
  "  Ok(" +
  type_name +
  "::{ compiled: @runtime.compiled_v5(\n" +
  render_entries(compiled.entries, "  ") +
  ",\n    inline_vars=[\n" +
  inline_vars.join("\n") +
  "\n    ],\n  ) })\n}"
}

///|
fn recipe_axis_type(
  recipe : @ir.Recipe,
  axis : @ir.RecipeVariantAxis,
) -> String {
  generated_pascal_name(recipe.name) + generated_pascal_name(axis.name)
}

///|
fn recipe_choice_constructor(
  recipe : @ir.Recipe,
  axis : @ir.RecipeVariantAxis,
  value : String,
) -> String {
  recipe_axis_type(recipe, axis) + generated_pascal_name(value)
}

///|
fn render_recipe_rule_additions(
  rules : Array[String],
  indent : String,
) -> String {
  rules
  .map(rule_name => indent + "output = output.add(" + rule_name + ")")
  .join("\n")
}

///|
fn render_recipe_axis_enum(
  recipe : @ir.Recipe,
  axis : @ir.RecipeVariantAxis,
) -> String {
  if axis.boolean {
    return ""
  }
  let constructors = axis.choices.map(choice => {
    "  " + recipe_choice_constructor(recipe, axis, choice.value)
  })
  "///|\npub(all) enum " +
  recipe_axis_type(recipe, axis) +
  " {\n" +
  constructors.join("\n") +
  "\n} derive(Eq, Debug)\n\n///|\npub extend " +
  recipe_axis_type(recipe, axis) +
  " with Eq::{equal, not_equal}\n\n///|\npub extend " +
  recipe_axis_type(recipe, axis) +
  " with @debug.Debug::{to_repr}"
}

///|
fn render_recipe_parameter(
  recipe : @ir.Recipe,
  axis : @ir.RecipeVariantAxis,
) -> String {
  if axis.boolean {
    match axis.default_value {
      Some(value) => "  " + axis.name + "? : Bool = " + value + ","
      None => "  " + axis.name + "? : Bool? = None,"
    }
  } else {
    let type_name = recipe_axis_type(recipe, axis)
    match axis.default_value {
      Some(value) =>
        "  " +
        axis.name +
        "? : " +
        type_name +
        " = " +
        recipe_choice_constructor(recipe, axis, value) +
        ","
      None => "  " + axis.name + "? : " + type_name + "? = None,"
    }
  }
}

///|
fn render_recipe_axis_application(
  recipe : @ir.Recipe,
  axis : @ir.RecipeVariantAxis,
) -> String {
  let arms : Array[String] = []
  for choice in axis.choices {
    let base_pattern = if axis.boolean {
      choice.value
    } else {
      recipe_choice_constructor(recipe, axis, choice.value)
    }
    let pattern = match axis.default_value {
      Some(_) => base_pattern
      None => "Some(" + base_pattern + ")"
    }
    let rendered_additions = render_recipe_rule_additions(
      choice.rules,
      "      ",
    )
    let additions = if rendered_additions.is_empty() {
      "      ()"
    } else {
      rendered_additions
    }
    arms.push("    " + pattern + " => {\n" + additions + "\n    }")
  }
  match axis.default_value {
    Some(_) => "  match " + axis.name + " {\n" + arms.join("\n") + "\n  }"
    None => {
      arms.push("    None => ()")
      "  match " + axis.name + " {\n" + arms.join("\n") + "\n  }"
    }
  }
}

///|
fn recipe_match_expression(
  recipe : @ir.Recipe,
  selection : @ir.RecipeVariantMatch,
) -> String {
  let axis = recipe.variants
    .search_by(candidate => candidate.name == selection.axis)
    .map(index => recipe.variants[index])
  match axis {
    None => "false"
    Some(axis) => {
      let expected = if axis.boolean {
        selection.value
      } else {
        recipe_choice_constructor(recipe, axis, selection.value)
      }
      match axis.default_value {
        Some(_) => axis.name + " == " + expected
        None => axis.name + " == Some(" + expected + ")"
      }
    }
  }
}

///|
fn render_recipe(recipe : @ir.Recipe) -> String {
  let blocks : Array[String] = []
  for axis in recipe.variants {
    let rendered = render_recipe_axis_enum(recipe, axis)
    if !rendered.is_empty() {
      blocks.push(rendered)
    }
  }
  let parameters = recipe.variants.map(axis => {
    render_recipe_parameter(recipe, axis)
  })
  let return_type = match recipe.contract {
    Some(name) => generated_pascal_name(name) + "StyleList"
    None => "@runtime.StyleList"
  }
  let initial_output = match recipe.contract {
    Some(name) => "empty_" + name + "_styles()"
    None => "@runtime.style_list()"
  }
  let body : Array[String] = [
    "  let mut output = " + initial_output,
    render_recipe_rule_additions(recipe.base, "  "),
  ]
  for axis in recipe.variants {
    body.push(render_recipe_axis_application(recipe, axis))
  }
  for compound in recipe.compounds {
    let expression = compound.matches
      .map(selection => recipe_match_expression(recipe, selection))
      .join(" && ")
    body.push(
      "  if " +
      (if expression.is_empty() { "true" } else { expression }) +
      " {\n" +
      render_recipe_rule_additions(compound.rules, "    ") +
      "\n  }",
    )
  }
  body.push("  output")
  blocks.push(
    "///|\npub fn " +
    recipe.name +
    "(\n" +
    parameters.join("\n") +
    "\n) -> " +
    return_type +
    " {\n" +
    body.filter(line => !line.is_empty()).join("\n") +
    "\n}",
  )
  blocks.join("\n\n")
}

///|
fn render_marker(module_name : String, marker : @ir.MarkerDefinition) -> String {
  let class_name = @core.selector_marker_class_name(module_name, marker.name)
  "///|\npub let " +
  marker.name +
  "_marker : @runtime.SelectorMarker = @runtime.selector_marker(" +
  moon_string(module_name) +
  ", " +
  moon_string(marker.name) +
  ", " +
  moon_string(class_name) +
  ")"
}

///|
fn render_view_transition_class(
  module_name : String,
  value : @ir.ViewTransitionClassDefinition,
) -> String {
  let css_name = @core.view_transition_class_name(module_name, value.name)
  "///|\npub let " +
  value.name +
  "_view_transition_class : @values.ViewTransitionClass = " +
  "@values.authored_view_transition_class(" +
  moon_string(css_name) +
  ")"
}

///|
fn render_mappings(
  registry : @ir.Registry,
  compiled_sets : Array[@core.CompiledStyleSet],
  semantic_digest : String,
  contracts : Array[MappingContract],
) -> String {
  let blocks : Array[String] = []
  for contract in registry.contracts {
    blocks.push(render_contract(contract))
  }
  for set_index, style_set in registry.styles {
    let compiled = compiled_sets[set_index]
    for index, namespace_ in style_set.namespaces {
      blocks.push(
        render_namespace(namespace_, compiled.namespaces[index], contracts),
      )
    }
  }
  for recipe in registry.recipes {
    blocks.push(render_recipe(recipe))
  }
  for marker in registry.markers {
    blocks.push(render_marker(registry.module_name, marker))
  }
  for value in registry.view_transition_classes {
    blocks.push(render_view_transition_class(registry.module_name, value))
  }
  for theme in registry.themes {
    let symbol = theme.name.replace_all(old="-", new="_")
    let class_name = @core.theme_class_name(registry.module_name, theme)
    blocks.push(
      "///|\npub let " +
      symbol +
      " : @runtime.CompiledStyle = @runtime.compiled_v5([\n  (" +
      moon_string("theme|" + theme.base.scope) +
      ", Some(" +
      moon_string(class_name) +
      ")),\n])",
    )
  }
  blocks.push(
    "///|\npub let bundle_ref : @moonstyle.DependencyRef = @moonstyle.dependency_ref(" +
    moon_string(registry.module_name) +
    ", " +
    moon_string(semantic_digest) +
    ")",
  )
  "// Generated by lampclaw/moonstyle/extract schema v13. Do not edit.\n\n" +
  blocks.join("\n\n") +
  "\n"
}

///|
fn mapping_contracts(
  registry : @ir.Registry,
  mappings_package : String,
  dependencies : Array[DependencyBundle],
) -> (Array[MappingContract], Array[(String, String)]) {
  let external_packages : Array[String] = []
  let external_contracts : Array[BundleContract] = []
  for dependency in dependencies {
    for contract in dependency.contracts {
      if contract.mappings_package != mappings_package &&
        !external_contracts.any(existing => {
          existing.module_name == contract.module_name &&
          existing.name == contract.name
        }) {
        external_contracts.push(contract)
        if !external_packages.contains(contract.mappings_package) {
          external_packages.push(contract.mappings_package)
        }
      }
    }
  }
  external_packages.sort_by((left, right) => left.compare(right))
  external_contracts.sort_by((left, right) => {
    let module_order = left.module_name.compare(right.module_name)
    if module_order != 0 {
      module_order
    } else {
      left.name.compare(right.name)
    }
  })
  let imports : Array[(String, String)] = []
  for index, package_name in external_packages {
    imports.push((package_name, "contract_" + index.to_string()))
  }
  let contracts : Array[MappingContract] = registry.contracts.map(contract => {
    method_name: "append_" + contract.name + "_style",
    trait_reference: contract_trait_name(contract),
    properties: canonical_contract_properties(contract.properties),
  })
  for contract in external_contracts {
    let import_index = imports
      .search_by(entry => entry.0 == contract.mappings_package)
      .unwrap()
    contracts.push({
      method_name: "append_" + contract.name + "_style",
      trait_reference: "@" + imports[import_index].1 + "." + contract.trait_name,
      properties: contract.properties.copy(),
    })
  }
  (contracts, imports)
}

///|
fn render_mappings_manifest(
  imports : Array[(String, String)],
  include_values : Bool,
  include_debug : Bool,
) -> String {
  let lines : Array[String] = [
    "  \"lampclaw/moonstyle\",", "  \"lampclaw/moonstyle/runtime\",",
  ]
  if include_values {
    lines.push("  \"lampclaw/moonstyle/values\",")
  }
  if include_debug {
    lines.push("  \"moonbitlang/core/debug\",")
  }
  for entry in imports {
    lines.push("  " + moon_string(entry.0) + " @" + entry.1 + ",")
  }
  "// Generated by lampclaw/moonstyle/extract schema v13. Do not edit.\n" +
  "import {\n" +
  lines.join("\n") +
  "\n}\n\nformatter(ignore: [ \"styles.generated.mbt\" ])\n"
}

///|
fn rule_json(rule : @core.AtomicRule) -> Json {
  {
    "property": rule.property,
    "className": rule.class_name,
    "ltr": rule.ltr,
    "rtl": match rule.rtl {
      Some(value) => value
      None => null
    },
    "priority100": rule.priority100,
  }
}

///|
fn global_json(global : @core.GlobalRule) -> Json {
  {
    "kind": global.kind,
    "name": global.name,
    "css": global.css,
    "digest": global.digest,
  }
}

///|
pub fn content_digest(value : String) -> String {
  "sha256:" +
  @crypto.bytes_to_hex_string(@crypto.sha256(@encoding.encode(UTF8, value)))
}

///|
fn semantic_digest(value : String) -> String {
  content_digest(value)
}

///|
fn compiled_entry_value_json(value : String?) -> Json {
  match value {
    Some(class_name) => Json(class_name)
    None => null
  }
}

///|
fn namespace_json(namespace_ : @core.CompiledNamespace) -> Json {
  let entries : Array[Json] = namespace_.entries.map(entry => {
    [Json(entry.0), compiled_entry_value_json(entry.1)]
  })
  { "name": namespace_.name, "entries": entries }
}

///|
fn registry_dependency_json(value : @ir.DependencyRef) -> Json {
  { "module": value.module_name(), "semanticDigest": value.semantic_digest() }
}

///|
fn semantics_json() -> Json {
  {
    "profile": @core.application_order_profile,
    "digest": @core.application_order_digest,
  }
}

///|
fn contract_variable_json(value : @ir.ContractVariable) -> Json {
  { "variable": value.variable, "category": value.category }
}

///|
fn contract_property_json(property : @ir.ContractProperty) -> Json {
  match property.policy {
    AnySafe => { "name": property.name, "policy": "any" }
    Exact(values, tokens, slots, expressions) =>
      {
        "name": property.name,
        "policy": "exact",
        "values": values,
        "tokens": tokens.map(contract_variable_json),
        "slots": slots.map(contract_variable_json),
        "expressions": expressions,
      }
  }
}

///|
fn registry_contract_json(
  module_name : String,
  mappings_package : String,
  contract : @ir.StyleContract,
) -> Json {
  let properties = canonical_contract_properties(contract.properties)
  {
    "module": module_name,
    "name": contract.name,
    "mappingsPackage": mappings_package,
    "trait": contract_trait_name(contract),
    "properties": properties.map(contract_property_json),
  }
}

///|
fn registry_recipe_choice_json(value : @ir.RecipeVariantChoice) -> Json {
  { "value": value.value, "rules": value.rules }
}

///|
fn registry_recipe_axis_json(value : @ir.RecipeVariantAxis) -> Json {
  {
    "name": value.name,
    "boolean": value.boolean,
    "default": match value.default_value {
      Some(default_value) => Json(default_value)
      None => null
    },
    "choices": value.choices.map(registry_recipe_choice_json),
  }
}

///|
fn registry_recipe_match_json(value : @ir.RecipeVariantMatch) -> Json {
  { "axis": value.axis, "value": value.value }
}

///|
fn registry_recipe_compound_json(value : @ir.RecipeCompound) -> Json {
  {
    "matches": value.matches.map(registry_recipe_match_json),
    "rules": value.rules,
  }
}

///|
fn registry_recipe_json(
  module_name : String,
  mappings_package : String,
  value : @ir.Recipe,
) -> Json {
  {
    "module": module_name,
    "mappingsPackage": mappings_package,
    "name": value.name,
    "base": value.base,
    "variants": value.variants.map(registry_recipe_axis_json),
    "compounds": value.compounds.map(registry_recipe_compound_json),
    "contract": match value.contract {
      Some(contract) => Json(contract)
      None => null
    },
  }
}

///|
fn registry_marker_json(
  module_name : String,
  mappings_package : String,
  value : @ir.MarkerDefinition,
) -> Json {
  {
    "module": module_name,
    "mappingsPackage": mappings_package,
    "name": value.name,
    "className": @core.selector_marker_class_name(module_name, value.name),
  }
}

///|
fn registry_view_transition_class_json(
  module_name : String,
  mappings_package : String,
  value : @core.CompiledViewTransitionClass,
) -> Json {
  {
    "module": module_name,
    "mappingsPackage": mappings_package,
    "name": value.name,
    "cssName": @core.view_transition_class_name(module_name, value.name),
    "styles": value.blocks.map(view_transition_block_json),
  }
}

///|
fn render_manifest(
  registry : @ir.Registry,
  mappings_package : String,
  compiled_sets : Array[@core.CompiledStyleSet],
  rules : Array[@core.AtomicRule],
  globals : Array[@core.GlobalRule],
  view_transitions : Array[@core.CompiledViewTransitionClass],
) -> (String, String) {
  let namespaces : Array[Json] = []
  for compiled in compiled_sets {
    for namespace_ in compiled.namespaces {
      namespaces.push(namespace_json(namespace_))
    }
  }
  let sorted_contracts = registry.contracts.copy()
  sorted_contracts.sort_by((left, right) => left.name.compare(right.name))
  let contract_values = sorted_contracts.map(contract => {
    registry_contract_json(registry.module_name, mappings_package, contract)
  })
  let sorted_recipes = registry.recipes.copy()
  sorted_recipes.sort_by((left, right) => left.name.compare(right.name))
  let recipe_values = sorted_recipes.map(recipe => {
    registry_recipe_json(registry.module_name, mappings_package, recipe)
  })
  let sorted_markers = registry.markers.copy()
  sorted_markers.sort_by((left, right) => left.name.compare(right.name))
  let marker_values = sorted_markers.map(marker => {
    registry_marker_json(registry.module_name, mappings_package, marker)
  })
  let sorted_view_transition_classes = view_transitions.copy()
  sorted_view_transition_classes.sort_by((left, right) => {
    left.name.compare(right.name)
  })
  let view_transition_class_values = sorted_view_transition_classes.map(value => {
    registry_view_transition_class_json(
      registry.module_name,
      mappings_package,
      value,
    )
  })
  let semantic_manifest : Json = {
    "schemaVersion": 13,
    "module": registry.module_name,
    "mappingsPackage": mappings_package,
    "semantics": semantics_json(),
    "directDependencies": registry.direct_dependencies.map(
      registry_dependency_json,
    ),
    "dependencyClosure": [],
    "contracts": contract_values,
    "namespaces": namespaces,
    "rules": rules.map(rule_json),
    "globals": globals.map(global_json),
    "recipes": recipe_values,
    "markers": marker_values,
    "viewTransitionClasses": view_transition_class_values,
  }
  let digest = semantic_digest(semantic_manifest.stringify())
  let manifest : Json = {
    "schemaVersion": 13,
    "module": registry.module_name,
    "mappingsPackage": mappings_package,
    "semanticDigest": digest,
    "semantics": semantics_json(),
    "directDependencies": registry.direct_dependencies.map(
      registry_dependency_json,
    ),
    "dependencyClosure": [],
    "contracts": contract_values,
    "namespaces": namespaces,
    "rules": rules.map(rule_json),
    "globals": globals.map(global_json),
    "recipes": recipe_values,
    "markers": marker_values,
    "viewTransitionClasses": view_transition_class_values,
  }
  (manifest.stringify() + "\n", digest)
}

///|
fn contract_name_valid(name : String) -> Bool {
  if name.is_empty() {
    return false
  }
  for index = 0; index < name.length(); index = index + 1 {
    let code = name.unsafe_get(index).to_int()
    let lower = code >= 97 && code <= 122
    let digit = code >= 48 && code <= 57
    if (if index == 0 { !lower } else { !(lower || digit || code == 95) }) {
      return false
    }
  }
  true
}

///|
fn mappings_package_valid(name : String) -> Bool {
  if name.is_empty() ||
    name != name.trim().to_owned() ||
    name.has_prefix("/") ||
    name.has_suffix("/") ||
    name.contains("//") ||
    [
      "lampclaw/moonstyle", "lampclaw/moonstyle/runtime", "lampclaw/moonstyle/values",
    ].contains(name) {
    return false
  }
  for index = 0; index < name.length(); index = index + 1 {
    let code = name.unsafe_get(index).to_int()
    let lower = code >= 97 && code <= 122
    let upper = code >= 65 && code <= 90
    let digit = code >= 48 && code <= 57
    if !(lower ||
      upper ||
      digit ||
      code == 45 ||
      code == 46 ||
      code == 47 ||
      code == 95) {
      return false
    }
  }
  true
}

///|
fn contract_variable_valid(value : @ir.ContractVariable) -> Bool {
  value.variable.has_prefix("--") &&
  value.variable.length() > 2 &&
  [
    "length", "color", "number", "percentage", "length-percentage", "integer", "time",
    "angle", "resolution", "url",
  ].contains(value.category)
}

///|
fn contract_variable_identity(value : @ir.ContractVariable) -> String {
  value.variable + "|" + value.category
}

///|
fn contract_diagnostics(registry : @ir.Registry) -> Array[@core.Diagnostic] {
  let diagnostics : Array[@core.Diagnostic] = []
  let names : Array[String] = []
  let generated_types : Array[String] = []
  let generated_symbols : Array[String] = []
  for contract in registry.contracts {
    if !contract_name_valid(contract.name) {
      diagnostics.push(
        @core.error_diagnostic(
          "STYLE_CONTRACT_NAME",
          "Style contract names must start with a lowercase ASCII letter and contain only lowercase letters, digits, or underscores",
          context=Some(@core.diagnostic_context(registry.module_name)),
        ),
      )
    }
    if names.contains(contract.name) {
      diagnostics.push(
        @core.error_diagnostic(
          "STYLE_CONTRACT_NAME_DUPLICATE",
          "Duplicate style contract name: " + contract.name,
          context=Some(@core.diagnostic_context(registry.module_name)),
        ),
      )
    }
    names.push(contract.name)
    let generated_type = contract_list_name(contract)
    if generated_types.contains(generated_type) {
      diagnostics.push(
        @core.error_diagnostic(
          "STYLE_CONTRACT_NAME_COLLISION",
          "Style contract names generate the same public type: " +
          generated_type,
          context=Some(@core.diagnostic_context(registry.module_name)),
        ),
      )
    }
    generated_types.push(generated_type)
    generated_symbols.push(contract.name + "_styles")
    generated_symbols.push("empty_" + contract.name + "_styles")
    generated_symbols.push(contract.name + "_contract_properties")
    generated_symbols.push(contract.name + "_contract_name")
    let properties : Array[String] = []
    for property in contract.properties {
      if properties.contains(property.name) {
        diagnostics.push(
          @core.error_diagnostic(
            "STYLE_CONTRACT_PROPERTY_DUPLICATE",
            "Style contract " +
            contract.name +
            " repeats property " +
            property.name,
            context=Some(@core.diagnostic_context(registry.module_name)),
          ),
        )
      }
      properties.push(property.name)
      if !@core.application_order_properties().contains(property.name) {
        diagnostics.push(
          @core.error_diagnostic(
            "STYLE_CONTRACT_PROPERTY_UNKNOWN",
            "Style contract " +
            contract.name +
            " contains unknown property " +
            property.name,
            context=Some(@core.diagnostic_context(registry.module_name)),
          ),
        )
      }
      match property.policy {
        AnySafe => ()
        Exact(values, tokens, slots, expressions) => {
          let seen_expressions : Array[String] = []
          for expression in expressions {
            if !@values.valid_expression_identity(expression) ||
              seen_expressions.contains(expression) {
              diagnostics.push(
                @core.error_diagnostic(
                  "STYLE_CONTRACT_EXPRESSION_INVALID",
                  "Exact expressions must be valid and unique",
                  context=Some(@core.diagnostic_context(registry.module_name)),
                ),
              )
            }
            seen_expressions.push(expression)
          }
          if values.is_empty() &&
            tokens.is_empty() &&
            slots.is_empty() &&
            expressions.is_empty() {
            diagnostics.push(
              @core.error_diagnostic(
                "STYLE_CONTRACT_POLICY_EMPTY",
                "Exact contract policy for " +
                property.name +
                " must admit at least one value channel",
                context=Some(@core.diagnostic_context(registry.module_name)),
              ),
            )
          }
          let seen_values : Array[String] = []
          for value in values {
            let canonical = @core.canonical_css_value(value)
            if canonical.is_empty() ||
              !@values.property_value_issues(property.name, value).is_empty() {
              diagnostics.push(
                @core.error_diagnostic(
                  "STYLE_CONTRACT_VALUE_INVALID",
                  "Exact contract policy for " +
                  property.name +
                  " contains an invalid literal value",
                  context=Some(@core.diagnostic_context(registry.module_name)),
                ),
              )
            }
            if seen_values.contains(canonical) {
              diagnostics.push(
                @core.error_diagnostic(
                  "STYLE_CONTRACT_VALUE_DUPLICATE",
                  "Exact contract policy for " +
                  property.name +
                  " repeats a canonical literal value",
                  context=Some(@core.diagnostic_context(registry.module_name)),
                ),
              )
            }
            seen_values.push(canonical)
          }
          let seen_tokens : Array[String] = []
          for token in tokens {
            let identity = contract_variable_identity(token)
            if !contract_variable_valid(token) {
              diagnostics.push(
                @core.error_diagnostic(
                  "STYLE_CONTRACT_TOKEN_INVALID",
                  "Exact contract policy for " +
                  property.name +
                  " contains an invalid token identity",
                  context=Some(@core.diagnostic_context(registry.module_name)),
                ),
              )
            }
            if seen_tokens.contains(identity) {
              diagnostics.push(
                @core.error_diagnostic(
                  "STYLE_CONTRACT_TOKEN_DUPLICATE",
                  "Exact contract policy for " +
                  property.name +
                  " repeats a token identity",
                  context=Some(@core.diagnostic_context(registry.module_name)),
                ),
              )
            }
            seen_tokens.push(identity)
          }
          let seen_slots : Array[String] = []
          for slot in slots {
            let identity = contract_variable_identity(slot)
            if !contract_variable_valid(slot) {
              diagnostics.push(
                @core.error_diagnostic(
                  "STYLE_CONTRACT_SLOT_INVALID",
                  "Exact contract policy for " +
                  property.name +
                  " contains an invalid dynamic-slot identity",
                  context=Some(@core.diagnostic_context(registry.module_name)),
                ),
              )
            }
            if seen_slots.contains(identity) {
              diagnostics.push(
                @core.error_diagnostic(
                  "STYLE_CONTRACT_SLOT_DUPLICATE",
                  "Exact contract policy for " +
                  property.name +
                  " repeats a dynamic-slot identity",
                  context=Some(@core.diagnostic_context(registry.module_name)),
                ),
              )
            }
            seen_slots.push(identity)
          }
        }
      }
    }
  }
  let style_types : Array[String] = []
  for style_set in registry.styles {
    for namespace_ in style_set.namespaces {
      let type_name = generated_style_type(namespace_.name)
      if style_types.contains(type_name) || generated_types.contains(type_name) {
        diagnostics.push(
          @core.error_diagnostic(
            "STYLE_GENERATED_TYPE_COLLISION",
            "Generated style types collide at " + type_name,
            context=Some(@core.diagnostic_context(registry.module_name)),
          ),
        )
      }
      style_types.push(type_name)
      if generated_symbols.contains(namespace_.name) {
        diagnostics.push(
          @core.error_diagnostic(
            "STYLE_CONTRACT_SYMBOL_COLLISION",
            "Generated contract symbol collides with style namespace " +
            namespace_.name,
            context=Some(@core.diagnostic_context(registry.module_name)),
          ),
        )
      }
    }
  }
  diagnostics
}

///|
fn registry_namespace(registry : @ir.Registry, name : String) -> @ir.Namespace? {
  for style_set in registry.styles {
    for namespace_ in style_set.namespaces {
      if namespace_.name == name {
        return Some(namespace_)
      }
    }
  }
  None
}

///|
fn recipe_rule_names(recipe : @ir.Recipe) -> Array[String] {
  let names = recipe.base.copy()
  for axis in recipe.variants {
    for choice in axis.choices {
      for name in choice.rules {
        names.push(name)
      }
    }
  }
  for compound in recipe.compounds {
    for name in compound.rules {
      names.push(name)
    }
  }
  names
}

///|
fn recipe_diagnostics(registry : @ir.Registry) -> Array[@core.Diagnostic] {
  let diagnostics : Array[@core.Diagnostic] = []
  let recipe_names : Array[String] = []
  let generated_types : Array[String] = []
  for recipe in registry.recipes {
    if !contract_name_valid(recipe.name) {
      diagnostics.push(
        @core.error_diagnostic(
          "STYLE_RECIPE_NAME",
          "Recipe names must be valid lowercase MoonBit value identifiers",
          context=Some(@core.diagnostic_context(registry.module_name)),
        ),
      )
    }
    if recipe_names.contains(recipe.name) {
      diagnostics.push(
        @core.error_diagnostic(
          "STYLE_RECIPE_NAME_DUPLICATE",
          "Duplicate recipe name: " + recipe.name,
          context=Some(@core.diagnostic_context(registry.module_name)),
        ),
      )
    }
    recipe_names.push(recipe.name)
    let axes : Array[String] = []
    for axis in recipe.variants {
      if !contract_name_valid(axis.name) || axes.contains(axis.name) {
        diagnostics.push(
          @core.error_diagnostic(
            "STYLE_RECIPE_AXIS",
            "Recipe variant axes must be unique lowercase MoonBit value identifiers",
            context=Some(@core.diagnostic_context(registry.module_name)),
          ),
        )
      }
      axes.push(axis.name)
      let values : Array[String] = []
      for choice in axis.choices {
        if choice.value.is_empty() || values.contains(choice.value) {
          diagnostics.push(
            @core.error_diagnostic(
              "STYLE_RECIPE_CHOICE",
              "Recipe variant choices must be non-empty and unique within an axis",
              context=Some(@core.diagnostic_context(registry.module_name)),
            ),
          )
        }
        values.push(choice.value)
      }
      if axis.boolean && values != ["true", "false"] {
        diagnostics.push(
          @core.error_diagnostic(
            "STYLE_RECIPE_BOOLEAN_AXIS",
            "Boolean recipe axes must contain canonical true and false choices",
            context=Some(@core.diagnostic_context(registry.module_name)),
          ),
        )
      }
      match axis.default_value {
        Some(value) if !values.contains(value) =>
          diagnostics.push(
            @core.error_diagnostic(
              "STYLE_RECIPE_DEFAULT",
              "Recipe variant default must name one of its choices",
              context=Some(@core.diagnostic_context(registry.module_name)),
            ),
          )
        _ => ()
      }
      if !axis.boolean {
        let generated_type = recipe_axis_type(recipe, axis)
        if generated_types.contains(generated_type) {
          diagnostics.push(
            @core.error_diagnostic(
              "STYLE_RECIPE_TYPE_COLLISION",
              "Recipe axes generate the same public enum type: " +
              generated_type,
              context=Some(@core.diagnostic_context(registry.module_name)),
            ),
          )
        }
        generated_types.push(generated_type)
      }
    }
    for compound in recipe.compounds {
      let matched_axes : Array[String] = []
      for selection in compound.matches {
        let axis_index = recipe.variants.search_by(axis => {
          axis.name == selection.axis
        })
        let valid = match axis_index {
          Some(index) =>
            recipe.variants[index].choices.any(choice => {
              choice.value == selection.value
            })
          None => false
        }
        if !valid || matched_axes.contains(selection.axis) {
          diagnostics.push(
            @core.error_diagnostic(
              "STYLE_RECIPE_COMPOUND",
              "Compound variants must select each known axis at most once with a known value",
              context=Some(@core.diagnostic_context(registry.module_name)),
            ),
          )
        }
        matched_axes.push(selection.axis)
      }
    }
    let contract = match recipe.contract {
      Some(name) =>
        registry.contracts
        .search_by(candidate => candidate.name == name)
        .map(index => registry.contracts[index])
      None => None
    }
    if recipe.contract is Some(_) && contract is None {
      diagnostics.push(
        @core.error_diagnostic(
          "STYLE_RECIPE_CONTRACT",
          "Recipe references an unknown local style contract",
          context=Some(@core.diagnostic_context(registry.module_name)),
        ),
      )
    }
    let seen_rules : Array[String] = []
    for name in recipe_rule_names(recipe) {
      if seen_rules.contains(name) {
        diagnostics.push(
          @core.error_diagnostic(
            "STYLE_RECIPE_RULE_DUPLICATE",
            "Recipe repeats generated rule namespace " + name,
            context=Some(@core.diagnostic_context(registry.module_name)),
          ),
        )
      }
      seen_rules.push(name)
      match registry_namespace(registry, name) {
        None =>
          diagnostics.push(
            @core.error_diagnostic(
              "STYLE_RECIPE_RULE_MISSING",
              "Recipe references missing rule namespace " + name,
              context=Some(@core.diagnostic_context(registry.module_name)),
            ),
          )
        Some(namespace_) =>
          for declaration in namespace_.declarations {
            let nested_dynamic = declaration_expressions(declaration).any(value => {
              value.is_dynamic()
            })
            let query_dynamic = declaration.conditions.any(condition => {
              condition is ContainerStyle(query) &&
              query
              .variables()
              .any(variable => variable.role == DynamicSlotRole)
            })
            if declaration.unsafe_raw ||
              declaration.value is Dynamic(_, _, _) ||
              nested_dynamic ||
              query_dynamic {
              diagnostics.push(
                @core.error_diagnostic(
                  "STYLE_RECIPE_NON_STATIC",
                  "Recipes accept only safe static or token-backed declarations",
                  source=declaration.source,
                  context=Some(@core.diagnostic_context(registry.module_name)),
                ),
              )
            }
            match contract {
              Some(contract) if !contract.properties.any(property => {
                  contract_property_accepts(property, declaration)
                }) =>
                diagnostics.push(
                  @core.error_diagnostic(
                    "STYLE_RECIPE_CONTRACT_VALUE",
                    "Recipe rule is not admitted by its declared style contract",
                    source=declaration.source,
                    context=Some(@core.diagnostic_context(registry.module_name)),
                  ),
                )
              _ => ()
            }
          }
      }
    }
  }
  diagnostics
}

///|
fn marker_diagnostics(registry : @ir.Registry) -> Array[@core.Diagnostic] {
  let diagnostics : Array[@core.Diagnostic] = []
  let names : Array[String] = []
  for marker in registry.markers {
    if !contract_name_valid(marker.name) {
      diagnostics.push(
        @core.error_diagnostic(
          "STYLE_MARKER_NAME",
          "Selector marker names must be valid lowercase MoonBit value identifiers",
          context=Some(@core.diagnostic_context(registry.module_name)),
        ),
      )
    }
    if names.contains(marker.name) {
      diagnostics.push(
        @core.error_diagnostic(
          "STYLE_MARKER_NAME_DUPLICATE",
          "Duplicate selector marker name: " + marker.name,
          context=Some(@core.diagnostic_context(registry.module_name)),
        ),
      )
    }
    names.push(marker.name)
  }
  for style_set in registry.styles {
    for namespace_ in style_set.namespaces {
      if names.any(name => name + "_marker" == namespace_.name) {
        diagnostics.push(
          @core.error_diagnostic(
            "STYLE_MARKER_SYMBOL_COLLISION",
            "Generated selector marker symbol collides with a style namespace",
            context=Some(@core.diagnostic_context(registry.module_name)),
          ),
        )
      }
      for declaration in namespace_.declarations {
        for condition in declaration.conditions {
          match condition {
            Relational(reference, _) if reference.module_name.is_empty() &&
              !names.contains(reference.name) =>
              diagnostics.push(
                @core.error_diagnostic(
                  "STYLE_MARKER_REFERENCE",
                  "Relational selector references an undeclared local marker " +
                  reference.name,
                  source=declaration.source,
                  context=Some(@core.diagnostic_context(registry.module_name)),
                ),
              )
            _ => ()
          }
        }
      }
    }
  }
  diagnostics
}

///|
fn view_transition_diagnostics(
  registry : @ir.Registry,
) -> Array[@core.Diagnostic] {
  let diagnostics : Array[@core.Diagnostic] = []
  let names : Array[String] = []
  for value in registry.view_transition_classes {
    if !contract_name_valid(value.name) || names.contains(value.name) {
      diagnostics.push(
        @core.error_diagnostic(
          "STYLE_VIEW_TRANSITION_CLASS",
          "View-transition class definitions must have unique lowercase MoonBit identifiers",
          context=Some(@core.diagnostic_context(registry.module_name)),
        ),
      )
    }
    names.push(value.name)
  }
  diagnostics
}

///|
fn resolve_marker_reference(
  registry : @ir.Registry,
  reference : @ir.SelectorMarkerRef,
) -> @ir.SelectorMarkerRef {
  let module_name = if reference.module_name.is_empty() {
    registry.module_name
  } else {
    reference.module_name
  }
  let class_name = if reference.class_name.is_empty() {
    @core.selector_marker_class_name(module_name, reference.name)
  } else {
    reference.class_name
  }
  { ..reference, module_name, class_name, }
}

///|
fn resolved_registry_styles(registry : @ir.Registry) -> Array[@ir.StyleSet] {
  registry.styles.map(style_set => {
    @ir.style_set(
      style_set.export_name,
      style_set.namespaces.map(namespace_ => {
        @ir.style_namespace(
          namespace_.name,
          namespace_.declarations.map(declaration => {
            ..declaration,
            conditions: declaration.conditions.map(condition => {
              match condition {
                Relational(reference, relation) =>
                  @ir.relational(
                    resolve_marker_reference(registry, reference),
                    relation,
                  )
                _ => condition
              }
            }),
          }),
        )
      }),
    )
  })
}

///|
fn font_width_reference(css : String) -> String? {
  let value = css.trim().to_owned()
  if !value.has_prefix("var(") {
    return None
  }
  let body = value[4:].to_owned()
  let end = match (body.find(","), body.find(")")) {
    (Some(comma), Some(close)) => if comma < close { comma } else { close }
    (None, Some(close)) => close
    _ => return None
  }
  let name = body[:end].trim().to_owned()
  if name.has_prefix("--") {
    Some(name)
  } else {
    None
  }
}

///|
fn font_width_variable_diagnostics(
  registry : @ir.Registry,
) -> Array[@core.Diagnostic] {
  let references : Array[(String, @ir.SourceSpan?)] = []
  let collect = fn(variable : String, source : @ir.SourceSpan?) {
    if !references.any(existing => existing.0 == variable) {
      references.push((variable, source))
    }
  }
  for style_set in registry.styles {
    for namespace_ in style_set.namespaces {
      for declaration in namespace_.declarations {
        if declaration.unsafe_raw {
          continue
        }
        if declaration.property == "fontWidth" ||
          declaration.property == "font-width" {
          match declaration.value_origin {
            TokenOrigin(variable) | DynamicSlotOrigin(variable) =>
              collect(variable.variable, declaration.source)
            _ => ()
          }
          match declaration.value {
            Dynamic(variable, _, _) => collect(variable, declaration.source)
            Text(css) =>
              if font_width_reference(css) is Some(variable) {
                collect(variable, declaration.source)
              }
            Fallbacks(values) =>
              for css in values {
                if font_width_reference(css) is Some(variable) {
                  collect(variable, declaration.source)
                }
              }
            _ => ()
          }
        }
        for animation in declaration.value.animations() {
          for frame in animation.keyframes.frames {
            for value in frame.declarations {
              if value.property == "fontWidth" || value.property == "font-width" {
                for css in value.values {
                  if font_width_reference(css) is Some(variable) {
                    collect(variable, value.source)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  let diagnostics : Array[@core.Diagnostic] = []
  let check = fn(variable : String, css : String, location : String) {
    if references.search_by(reference => reference.0 == variable) is Some(index) {
      for issue in @values.property_value_issues("fontWidth", css) {
        diagnostics.push(
          @core.error_diagnostic(
            issue.code,
            "Invalid font-width value for " +
            variable +
            " at " +
            location +
            ": " +
            issue.label,
            source=references[index].1,
            context=Some(@core.diagnostic_context(registry.module_name)),
          ),
        )
      }
    }
  }
  for variable_set in registry.variable_sets {
    for definition in variable_set.definitions {
      check(definition.name, definition.default_css, "default")
    }
  }
  for theme in registry.themes {
    for override_ in theme.overrides {
      check(override_.name, override_.value_css, "theme " + theme.name)
    }
  }
  diagnostics
}

///|
pub fn compile_registry(
  registry : @ir.Registry,
  mappings_package~ : String = "",
  dependencies~ : Array[DependencyBundle] = [],
) -> CompiledBundle {
  let resolved_mappings_package = if mappings_package.is_empty() {
    registry.module_name + "/generated"
  } else {
    mappings_package
  }
  let (visible_contracts, contract_imports) = mapping_contracts(
    registry, resolved_mappings_package, dependencies,
  )
  let include_values = !registry.view_transition_classes.is_empty() ||
    registry.styles.any(style_set => {
      style_set.namespaces.any(namespace_ => {
        !dynamic_declarations(namespace_).is_empty()
      })
    })
  let compiled_sets = resolved_registry_styles(registry).map(@core.compile)
  let all_rules : Array[@core.AtomicRule] = []
  let all_globals : Array[@core.GlobalRule] = []
  let diagnostics : Array[@core.Diagnostic] = []
  if !mappings_package_valid(resolved_mappings_package) {
    diagnostics.push(
      @core.error_diagnostic(
        "STYLE_MAPPINGS_PACKAGE",
        "Generated mappings package must be a non-reserved MoonBit package path",
        context=Some(@core.diagnostic_context(registry.module_name)),
      ),
    )
  }
  for diagnostic in contract_diagnostics(registry) {
    diagnostics.push(diagnostic)
  }
  for diagnostic in recipe_diagnostics(registry) {
    diagnostics.push(diagnostic)
  }
  for diagnostic in marker_diagnostics(registry) {
    diagnostics.push(diagnostic)
  }
  for diagnostic in view_transition_diagnostics(registry) {
    diagnostics.push(diagnostic)
  }
  let validation_registry = registry_with_transition_styles(registry)
  for diagnostic in font_width_variable_diagnostics(validation_registry) {
    diagnostics.push(diagnostic)
  }
  for diagnostic in expression_variable_diagnostics(validation_registry) {
    diagnostics.push(diagnostic)
  }
  for compiled in compiled_sets {
    for diagnostic in compiled.diagnostics {
      diagnostics.push(diagnostic)
    }
    for rule in compiled.rules {
      all_rules.push(rule)
    }
    for global in compiled.globals {
      all_globals.push(global)
    }
  }
  let (registry_globals, registry_diagnostics) = @core.compile_registry_globals(
    registry.module_name,
    registry.variable_sets,
    registry.themes,
  )
  for global in registry_globals {
    all_globals.push(global)
  }
  for diagnostic in registry_diagnostics {
    diagnostics.push(diagnostic)
  }
  let (position_try_globals, position_try_diagnostics) = @core.compile_position_tries(
    registry.module_name,
    registry.position_tries,
  )
  for global in position_try_globals {
    all_globals.push(global)
  }
  for diagnostic in position_try_diagnostics {
    diagnostics.push(diagnostic)
  }
  let view_transitions = registry.view_transition_classes.map(definition => {
    @core.compile_view_transition_class(registry.module_name, definition)
  })
  for transition in view_transitions {
    for global in transition.globals {
      all_globals.push(global)
    }
    for diagnostic in transition.diagnostics {
      diagnostics.push(diagnostic)
    }
  }
  let rules = @core.sort_and_dedupe(all_rules)
  let globals = @core.sort_and_dedupe_globals(all_globals)
  let css_blocks = globals.map(global => global.css)
  let atomic_css = @core.render_rules(rules)
  if !atomic_css.is_empty() {
    css_blocks.push(atomic_css)
  }
  let css_body = css_blocks.join("\n")
  let (manifest, digest) = render_manifest(
    registry, resolved_mappings_package, compiled_sets, rules, globals, view_transitions,
  )
  {
    schema_version: 13,
    module_name: registry.module_name,
    semantic_digest: digest,
    css: "/* Generated by lampclaw/moonstyle/extract schema v13. Do not edit. */\n" +
    css_body +
    "\n",
    mappings: render_mappings(
      registry, compiled_sets, digest, visible_contracts,
    ),
    mappings_manifest: render_mappings_manifest(
      contract_imports,
      include_values,
      registry.recipes.any(recipe => recipe.variants.any(axis => !axis.boolean)),
    ),
    manifest,
    diagnostics,
  }
}
