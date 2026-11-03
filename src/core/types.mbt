///|
pub struct AtomicRule {
  property : String
  class_name : String
  ltr : String
  rtl : String?
  priority100 : Int32
} derive(Eq, Debug)

///|
pub struct GlobalRule {
  kind : String
  name : String
  css : String
  digest : String
} derive(Eq, Debug)

///|
pub struct CompiledNamespace {
  name : String
  entries : Array[(String, String?)]
} derive(Eq, Debug)

///|
pub(all) enum DiagnosticSeverity {
  Error
  Warning
} derive(Eq, Debug)

///|
pub struct DiagnosticContext {
  module_name : String
  artifact_path : String?
  dependency_chain : Array[String]
} derive(Eq, Debug)

///|
pub fn diagnostic_context(
  module_name : String,
  artifact_path~ : String? = None,
  dependency_chain~ : Array[String] = [],
) -> DiagnosticContext {
  { module_name, artifact_path, dependency_chain, }
}

///|
pub struct Diagnostic {
  code : String
  severity : DiagnosticSeverity
  message : String
  source : @ir.SourceSpan?
  context : DiagnosticContext?
} derive(Eq, Debug)

///|
pub fn error_diagnostic(
  code : String,
  message : String,
  source~ : @ir.SourceSpan? = None,
  context~ : DiagnosticContext? = None,
) -> Diagnostic {
  { code, severity: Error, message, source, context, }
}

///|
pub fn warning_diagnostic(
  code : String,
  message : String,
  source~ : @ir.SourceSpan? = None,
  context~ : DiagnosticContext? = None,
) -> Diagnostic {
  { code, severity: Warning, message, source, context, }
}

///|
pub struct CompiledStyleSet {
  namespaces : Array[CompiledNamespace]
  rules : Array[AtomicRule]
  globals : Array[GlobalRule]
  diagnostics : Array[Diagnostic]
} derive(Eq, Debug)

///|
pub fn with_priority_specificity(rule : String, priority100 : Int32) -> String {
  let mut suffix = ""
  let mut levels = priority100 / (application_order_priority_scale * 1000) - 1
  while levels > 0 {
    suffix = suffix + ":not(#\\#)"
    levels = levels - 1
  }
  if suffix.is_empty() {
    return rule
  }
  match rule.rev_find("{") {
    Some(brace) => {
      let prelude = rule[:brace].to_owned()
      let start = match prelude.rev_find("{") {
        Some(index) => index + 1
        None => 0
      }
      prelude[:start].to_owned() +
      selector_specificity(prelude[start:].to_owned(), suffix) +
      rule[brace:].to_owned()
    }
    None => rule
  }
}

///|
fn selector_specificity(selector : String, suffix : String) -> String {
  let output = StringBuilder()
  let mut start = 0
  let mut insertion : Int32? = None
  let mut depth = 0
  let mut quote : UInt16? = None
  let mut escaped = false
  for i in 0..<selector.length() {
    let char = selector[i]
    if escaped {
      escaped = false
      continue
    }
    if char == '\\' {
      escaped = true
      continue
    }
    if quote is Some(value) {
      if char == value {
        quote = None
      }
      continue
    }
    if char == '\'' || char == '"' {
      quote = Some(char)
      continue
    }
    if char == '(' || char == '[' {
      depth += 1
    }
    if char == ')' || char == ']' {
      depth -= 1
    }
    if depth == 0 &&
      char == ':' &&
      i + 1 < selector.length() &&
      selector[i + 1] == ':' &&
      insertion is None {
      insertion = Some(i)
    }
    if depth == 0 && char == ',' {
      let at = insertion.unwrap_or(i)
      output.write_string(
        selector[start:at].to_owned() + suffix + selector[at:i].to_owned() + ",",
      )
      start = i + 1
      insertion = None
    }
  }
  let at = insertion.unwrap_or(selector.length())
  output.write_string(
    selector[start:at].to_owned() + suffix + selector[at:].to_owned(),
  )
  output.to_string()
}
