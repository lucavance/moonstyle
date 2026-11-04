///|
fn pseudo_class_css(value : @ir.PseudoClass) -> String {
  match value {
    Hover => ":hover"
    Focus => ":focus"
    FocusVisible => ":focus-visible"
    FocusWithin => ":focus-within"
    Active => ":active"
    Disabled => ":disabled"
    Enabled => ":enabled"
    Checked => ":checked"
    Required => ":required"
    Optional => ":optional"
    ReadOnly => ":read-only"
    ReadWrite => ":read-write"
    PlaceholderShown => ":placeholder-shown"
    FirstChild => ":first-child"
    LastChild => ":last-child"
    OnlyChild => ":only-child"
    Empty => ":empty"
    Link => ":link"
    Visited => ":visited"
    Valid => ":valid"
    Invalid => ":invalid"
    InRange => ":in-range"
    OutOfRange => ":out-of-range"
    Indeterminate => ":indeterminate"
    Target => ":target"
    Autofill => ":autofill"
    NthChild(a, b) => ":nth-child(" + anb_css(a, b) + ")"
    NthLastChild(a, b) => ":nth-last-child(" + anb_css(a, b) + ")"
    NthOfType(a, b) => ":nth-of-type(" + anb_css(a, b) + ")"
    NthLastOfType(a, b) => ":nth-last-of-type(" + anb_css(a, b) + ")"
    Is(states) => ":is(" + states.map(selector_state_css).join(",") + ")"
    Not(states) => ":not(" + states.map(selector_state_css).join(",") + ")"
    Where(states) => ":where(" + states.map(selector_state_css).join(",") + ")"
    MatchAttribute(value) => attribute_selector_css(value)
  }
}

///|
fn pseudo_element_css(value : @ir.PseudoElement) -> String {
  match value {
    Before => "::before"
    After => "::after"
    Placeholder => "::placeholder"
    Selection => "::selection"
    Marker => "::marker"
    FirstLetter => "::first-letter"
    FirstLine => "::first-line"
    Backdrop => "::backdrop"
    FileSelectorButton => "::file-selector-button"
  }
}

///|
fn media_type_css(value : @ir.MediaType) -> String {
  match value {
    All => "all"
    Screen => "screen"
    Print => "print"
    Speech => "speech"
  }
}

///|
fn media_feature_css(feature : @ir.MediaFeature) -> String {
  let name = feature.name.trim().to_owned()
  let value = feature.value.trim().to_owned()
  match feature.operator {
    Min => "(min-" + name + ":" + value + ")"
    Max => "(max-" + name + ":" + value + ")"
    Equal => "(" + name + ":" + value + ")"
    LessThan => "(" + name + " < " + value + ")"
    GreaterThan => "(" + name + " > " + value + ")"
  }
}

///|
fn media_query_css(query : @ir.MediaQuery) -> String {
  let clauses = query.features.map(media_feature_css)
  let body = match query.media_type {
    Some(media_type) => {
      let prefix = media_type_css(media_type)
      if clauses.is_empty() {
        prefix
      } else {
        prefix + " and " + clauses.join(" and ")
      }
    }
    None => clauses.join(" and ")
  }
  if query.negated {
    "not " + body
  } else {
    body
  }
}

///|
fn supports_condition_css(condition : @ir.SupportsCondition) -> String {
  match condition {
    Declaration(property, value) =>
      "(" + property.trim().to_owned() + ":" + value.trim().to_owned() + ")"
    Not(child) => "not " + supports_condition_css(child)
    All(children) => children.map(supports_condition_css).join(" and ")
    Any(children) => children.map(supports_condition_css).join(" or ")
  }
}

///|
fn container_query_css(query : @ir.ContainerQuery) -> String {
  let body = query.features.map(media_feature_css).join(" and ")
  match query.name {
    Some(name) => name.trim().to_owned() + " " + body
    None => body
  }
}

///|
fn selector_state_css(state : @ir.SelectorState) -> String {
  match state {
    SelectorPseudo(value) => pseudo_class_css(value)
    SelectorAttribute(name) => "[" + name.trim().to_owned() + "]"
    SelectorAttributeEquals(name, value) =>
      "[" + name.trim().to_owned() + "='" + value.trim().to_owned() + "']"
    SelectorAttributeMatch(value) => attribute_selector_css(value)
  }
}

///|
fn marker_selector_css(marker : @ir.SelectorMarkerRef) -> String {
  ":where(." +
  marker.class_name +
  marker.states.map(selector_state_css).join("") +
  ")"
}

///|
fn marker_relation_key(relation : @ir.MarkerRelation) -> String {
  match relation {
    MarkerAncestor => "ancestor"
    MarkerDescendant => "descendant"
    MarkerSiblingBefore => "sibling-before"
    MarkerSiblingAfter => "sibling-after"
    MarkerAnySibling => "any-sibling"
  }
}

///|
fn relational_selector_css(
  base : String,
  marker : @ir.SelectorMarkerRef,
  relation : @ir.MarkerRelation,
) -> String {
  let marker_selector = marker_selector_css(marker)
  match relation {
    MarkerAncestor => marker_selector + " " + base
    MarkerDescendant => base + ":has(" + marker_selector + ")"
    MarkerSiblingBefore => marker_selector + " ~ " + base
    MarkerSiblingAfter => base + ":has(~ " + marker_selector + ")"
    MarkerAnySibling =>
      marker_selector +
      " ~ " +
      base +
      "," +
      base +
      ":has(~ " +
      marker_selector +
      ")"
  }
}

///|
fn balanced_delimiters(value : String) -> Bool {
  let mut parentheses = 0
  let mut brackets = 0
  for i = 0; i < value.length(); i = i + 1 {
    let code = value.unsafe_get(i).to_int()
    if code == 40 {
      parentheses = parentheses + 1
    } else if code == 41 {
      parentheses = parentheses - 1
      if parentheses < 0 {
        return false
      }
    } else if code == 91 {
      brackets = brackets + 1
    } else if code == 93 {
      brackets = brackets - 1
      if brackets < 0 {
        return false
      }
    }
  }
  parentheses == 0 && brackets == 0
}

///|
fn invalid_condition_text(value : String) -> Bool {
  let trimmed = value.trim().to_owned()
  trimmed.is_empty() ||
  trimmed.contains("{") ||
  trimmed.contains("}") ||
  trimmed.contains(";") ||
  trimmed.contains("/*") ||
  trimmed.contains("*/") ||
  !balanced_delimiters(trimmed)
}

///|
fn valid_kebab_name(value : String) -> Bool {
  let trimmed = value.trim().to_owned()
  if trimmed.is_empty() {
    return false
  }
  let mut has_letter = false
  for i = 0; i < trimmed.length(); i = i + 1 {
    let code = trimmed.unsafe_get(i).to_int()
    if code >= 97 && code <= 122 {
      has_letter = true
    } else if !(code >= 48 && code <= 57) && code != 45 {
      return false
    }
  }
  has_letter
}

///|
fn invalid_supports_condition(condition : @ir.SupportsCondition) -> Bool {
  match condition {
    Declaration(property, value) =>
      !valid_kebab_name(property) || invalid_condition_text(value)
    Not(child) => invalid_supports_condition(child)
    All(children) | Any(children) =>
      children.is_empty() || children.any(invalid_supports_condition)
  }
}

///|
fn sorted_condition_strings(
  conditions : Array[@ir.Condition],
) -> (
  Array[String],
  Array[String],
  Array[(@ir.SelectorMarkerRef, @ir.MarkerRelation)],
) {
  let pseudos : Array[String] = []
  let pseudo_elements : Array[String] = []
  let at_rules : Array[String] = []
  let relations : Array[(@ir.SelectorMarkerRef, @ir.MarkerRelation)] = []
  for condition in conditions {
    match condition {
      Pseudo(value) => pseudos.push(pseudo_class_css(value))
      PseudoElement(value) => pseudo_elements.push(pseudo_element_css(value))
      UnsafePseudo(value) => pseudos.push(value.trim().to_owned())
      UnsafePseudoElement(value) =>
        pseudo_elements.push(value.trim().to_owned())
      UnsafeAtRule(value) => at_rules.push(value.trim().to_owned())
      Media(query) => at_rules.push("@media " + media_query_css(query))
      Supports(condition) =>
        at_rules.push("@supports " + supports_condition_css(condition))
      Container(query) =>
        at_rules.push("@container " + container_query_css(query))
      ContainerStyle(condition) =>
        at_rules.push(
          "@container style(" + container_style_css(condition) + ")",
        )
      Relational(marker, relation) => relations.push((marker, relation))
      Layer(name) => at_rules.push("@layer " + name.trim().to_owned())
    }
  }
  pseudos.sort()
  for pseudo_element in pseudo_elements {
    pseudos.push(pseudo_element)
  }
  (pseudos, at_rules, relations)
}

///|
fn normalized_values(value : @ir.StyleValue) -> Array[String] {
  match value {
    Text(value) => [canonical_css_value(value)]
    Fallbacks(values) => values.map(canonical_css_value)
    Dynamic(variable, _, _) => [canonical_css_value("var(" + variable + ")")]
    Expression(value) => [canonical_css_value(value.to_css())]
    ExpressionFallbacks(values) =>
      values.map(value => canonical_css_value(value.to_css()))
    Animation(value) => [animation_name_css(value)]
    AnimationList(values) =>
      [
        values
        .map(value => {
          match value {
            Some(value) => animation_name_css(value)
            None => "none"
          }
        })
        .join(","),
      ]
    Clear => []
  }
}

///|
fn relational_condition_priority100(
  marker : @ir.SelectorMarkerRef,
  relation : @ir.MarkerRelation,
) -> Int32 {
  let base = application_order_relational_priority100(
    marker_relation_key(relation),
  )
  if marker.states.is_empty() {
    return base
  }
  if marker.states.length() == 1 {
    match marker.states[0] {
      SelectorPseudo(value) =>
        if value
          is (NthChild(_, _)
          | NthLastChild(_, _)
          | NthOfType(_, _)
          | NthLastOfType(_, _)
          | Is(_)
          | Not(_)
          | Where(_)
          | MatchAttribute(_)) {
          return application_order_relational_fallback_priority100
        } else {
          return base +
            application_order_pseudo_priority100(pseudo_class_css(value)) /
            application_order_priority_scale
        }
      SelectorAttribute(_)
      | SelectorAttributeEquals(_, _)
      | SelectorAttributeMatch(_) =>
        return application_order_relational_fallback_priority100
    }
  }
  application_order_relational_fallback_priority100
}

///|
fn condition_priority100(conditions : Array[@ir.Condition]) -> Int32 {
  let mut priority100 = 0
  for condition in conditions {
    match condition {
      Pseudo(value) =>
        priority100 = priority100 +
          application_order_pseudo_priority100(pseudo_class_css(value))
      UnsafePseudo(value) =>
        priority100 = priority100 +
          application_order_pseudo_priority100(value.trim().to_owned())
      PseudoElement(_) | UnsafePseudoElement(_) =>
        priority100 = priority100 + application_order_pseudo_element_priority100
      Media(_) =>
        priority100 = priority100 +
          application_order_at_rule_priority100("@media")
      Supports(_) =>
        priority100 = priority100 +
          application_order_at_rule_priority100("@supports")
      Container(_) =>
        priority100 = priority100 +
          application_order_at_rule_priority100("@container")
      ContainerStyle(_) =>
        priority100 = priority100 +
          application_order_at_rule_priority100("@container")
      Relational(marker, relation) =>
        priority100 = priority100 +
          relational_condition_priority100(marker, relation)
      Layer(_) =>
        priority100 = priority100 + 3000 * application_order_priority_scale
      UnsafeAtRule(value) =>
        priority100 = priority100 +
          application_order_at_rule_priority100(value.trim().to_owned())
    }
  }
  priority100
}

///|
fn sha256_digest(value : String) -> String {
  "sha256:" +
  @crypto.bytes_to_hex_string(@crypto.sha256(@encoding.encode(UTF8, value)))
}

///|
fn keyframe_step_order(step : @ir.KeyframeStep) -> Int32 {
  match step {
    From => 0
    Percent(value) => value
    To => 100
  }
}

///|
fn keyframe_step_css(step : @ir.KeyframeStep) -> String {
  match step {
    From => "from"
    To => "to"
    Percent(value) => value.to_string() + "%"
  }
}

///|
fn keyframe_declaration_css(declaration : @ir.KeyframeDeclaration) -> String {
  declaration.values
  .map(value => dashify(declaration.property) + ":" + canonical_css_value(value))
  .join(";")
}

///|
fn keyframe_frame_css(frame : @ir.KeyframeFrame) -> String {
  keyframe_step_css(frame.step) +
  "{" +
  frame.declarations.map(keyframe_declaration_css).join(";") +
  "}"
}

///|
fn canonical_keyframes(value : @ir.AnimationName) -> String {
  let frames = value.keyframes.frames.copy()
  frames.sort_by((left, right) => {
    keyframe_step_order(left.step) - keyframe_step_order(right.step)
  })
  let unique : Array[@ir.KeyframeFrame] = []
  for frame in frames {
    let css = keyframe_frame_css(frame)
    if !unique.any(existing => keyframe_frame_css(existing) == css) {
      unique.push(frame)
    }
  }
  unique.map(keyframe_frame_css).join("")
}

///|
fn animation_name_css(value : @ir.AnimationName) -> String {
  "k" + hash(canonical_keyframes(value))
}

///|
fn animation_global(value : @ir.AnimationName) -> GlobalRule {
  let name = animation_name_css(value)
  let css = "@keyframes " + name + "{" + canonical_keyframes(value) + "}"
  { kind: "keyframes", name, css, digest: sha256_digest(css), }
}

///|
fn validate_animation(
  value : @ir.AnimationName,
  outer_source : @ir.SourceSpan?,
) -> Diagnostic? {
  if value.keyframes.name_hint.trim().is_empty() {
    return Some({
      code: "STYLE_KEYFRAMES_NAME",
      severity: Error,
      message: "Keyframes name hint must not be empty",
      source: outer_source,
      context: None,
    })
  }
  if value.keyframes.frames.is_empty() {
    return Some({
      code: "STYLE_KEYFRAMES_EMPTY",
      severity: Error,
      message: "Keyframes must contain at least one step",
      source: outer_source,
      context: None,
    })
  }
  let selectors : Array[(Int32, String)] = []
  for frame in value.keyframes.frames {
    let order = keyframe_step_order(frame.step)
    match frame.step {
      Percent(percent) if percent < 0 || percent > 100 =>
        return Some({
          code: "STYLE_KEYFRAME_PERCENT",
          severity: Error,
          message: "Keyframe percentage must be between 0 and 100",
          source: outer_source,
          context: None,
        })
      _ => ()
    }
    if frame.declarations.is_empty() {
      return Some({
        code: "STYLE_KEYFRAME_EMPTY",
        severity: Error,
        message: "Keyframe step must contain at least one declaration",
        source: outer_source,
        context: None,
      })
    }
    let frame_css = keyframe_frame_css(frame)
    let mut existing_selector : String? = None
    for existing in selectors {
      if existing.0 == order {
        existing_selector = Some(existing.1)
      }
    }
    match existing_selector {
      Some(existing) if existing != frame_css =>
        return Some({
          code: "STYLE_KEYFRAME_DUPLICATE",
          severity: Error,
          message: "Duplicate keyframe selectors must have identical declarations",
          source: outer_source,
          context: None,
        })
      Some(_) => ()
      None => selectors.push((order, frame_css))
    }
    for declaration in frame.declarations {
      let source = match declaration.source {
        Some(source) => Some(source)
        None => outer_source
      }
      if !declaration.conditions.is_empty() {
        return Some({
          code: "STYLE_KEYFRAME_CONDITION",
          severity: Error,
          message: "Keyframe declarations cannot contain conditions",
          source,
          context: None,
        })
      }
      if declaration.dynamic {
        return Some({
          code: "STYLE_KEYFRAME_DYNAMIC",
          severity: Error,
          message: "Keyframe declarations cannot contain dynamic or nested values",
          source,
          context: None,
        })
      }
      if !declaration.keyframe_allowed ||
        declaration.property == "colorScheme" ||
        declaration.property == "color-scheme" {
        return Some({
          code: "STYLE_KEYFRAME_PROPERTY",
          severity: Error,
          message: "Property is not approved for use in keyframes",
          source,
          context: None,
        })
      }
      if declaration.values.is_empty() {
        return Some({
          code: "STYLE_KEYFRAME_VALUE",
          severity: Error,
          message: "Keyframe declaration value must not be empty",
          source,
          context: None,
        })
      }
    }
  }
  None
}

///|
fn serialize_rule(
  generated_class : String,
  property : String,
  values : Array[String],
  pseudos : Array[String],
  at_rules : Array[String],
  relations : Array[(@ir.SelectorMarkerRef, @ir.MarkerRelation)],
) -> String {
  let declarations = values
    .map(value => dashify(property) + ":" + value)
    .join(";")
  let mut selector = "." + generated_class + pseudos.join("")
  for relation in relations {
    selector = relational_selector_css(selector, relation.0, relation.1)
  }
  let mut rule = selector + "{" + declarations + "}"
  for at_rule in at_rules {
    rule = at_rule + "{" + rule + "}"
  }
  rule
}

///|
fn compile_atomic_declaration(
  declaration : @ir.Declaration,
  property : String,
) -> AtomicRule {
  let emitted_property = if declaration.unsafe_raw {
    property
  } else {
    application_order_emitted_property(property)
  }
  let values = normalized_values(declaration.value)
  let (pseudos, at_rules, relations) = sorted_condition_strings(
    declaration.conditions,
  )
  let modifier_hash = if pseudos.is_empty() &&
    at_rules.is_empty() &&
    relations.is_empty() {
    "null"
  } else {
    pseudos.join("") +
    at_rules.join("") +
    relations
    .map(relation => {
      marker_selector_css(relation.0) + marker_relation_key(relation.1)
    })
    .join("")
  }
  let generated_class = class_name(
    dashify(emitted_property) + values.join(", ") + modifier_hash,
  )
  {
    property,
    class_name: generated_class,
    ltr: serialize_rule(
      generated_class, emitted_property, values, pseudos, at_rules, relations,
    ),
    rtl: None,
    priority100: (if declaration.unsafe_raw {
      if property.has_prefix("--") {
        application_order_priority_scale
      } else {
        3000 * application_order_priority_scale
      }
    } else {
      application_order_priority100(property)
    }) +
    condition_priority100(declaration.conditions),
  }
}

///|
fn compare_rules(left : AtomicRule, right : AtomicRule) -> Int32 {
  if left.priority100 != right.priority100 {
    left.priority100 - right.priority100
  } else {
    left.ltr.compare(right.ltr)
  }
}

///|
fn authored_value_diagnostics(
  declaration : @ir.Declaration,
  namespace_name : String,
) -> Array[Diagnostic] {
  let issues : Array[@values.ValueIssue] = []
  let collect = fn(property : String, css : String) {
    let value_issues = if declaration.unsafe_raw {
      @values.value_issues(css)
    } else {
      @values.property_value_issues(property, css)
    }
    for issue in value_issues {
      issues.push(issue)
    }
  }
  match declaration.value {
    Text(value) => collect(declaration.property, value)
    Fallbacks(values) =>
      for value in values {
        collect(declaration.property, value)
      }
    Dynamic(_, _, _) => ()
    Expression(value) =>
      for issue in value.issues(declaration.property) {
        issues.push(issue)
      }
    ExpressionFallbacks(values) =>
      for value in values {
        for issue in value.issues(declaration.property) {
          issues.push(issue)
        }
      }
    Animation(_) | AnimationList(_) =>
      for animation in declaration.value.animations() {
        for frame in animation.keyframes.frames {
          for value in frame.declarations {
            for expression in value.expressions {
              for issue in expression.issues(value.property) {
                issues.push(issue)
              }
            }
            for css in value.values {
              collect(value.property, css)
            }
          }
        }
      }
    Clear => ()
  }
  issues.map(issue => {
    error_diagnostic(
      issue.code,
      "Invalid authored value at " +
      namespace_name +
      "." +
      declaration.property +
      ": " +
      issue.label,
      source=declaration.source,
    )
  })
}

///|
fn css_value_diagnostics(css : String, location : String) -> Array[Diagnostic] {
  @values.value_issues(css).map(issue => {
    error_diagnostic(
      issue.code,
      "Invalid authored value at " + location + ": " + issue.label,
    )
  })
}

///|
fn validate_declaration(declaration : @ir.Declaration) -> Diagnostic? {
  if declaration.property.trim().is_empty() {
    return Some({
      code: "STYLE1001",
      severity: Error,
      message: "CSS property name must not be empty",
      source: declaration.source,
      context: None,
    })
  }
  match declaration.value {
    Text(value) =>
      if value.trim().is_empty() {
        return Some({
          code: "STYLE1002",
          severity: Error,
          message: "CSS property value must not be empty",
          source: declaration.source,
          context: None,
        })
      }
    Fallbacks(values) =>
      if values.is_empty() {
        return Some({
          code: "STYLE_FALLBACK_EMPTY",
          severity: Error,
          message: "CSS fallback list must not be empty",
          source: declaration.source,
          context: None,
        })
      }
    Dynamic(_, _, _) => ()
    Expression(_) => ()
    ExpressionFallbacks(values) =>
      if values.is_empty() {
        return Some(
          error_diagnostic(
            "STYLE_FALLBACK_EMPTY",
            "CSS fallback list must not be empty",
            source=declaration.source,
          ),
        )
      }
    Animation(value) =>
      match validate_animation(value, declaration.source) {
        Some(diagnostic) => return Some(diagnostic)
        None => ()
      }
    AnimationList(values) => {
      if values.is_empty() {
        return Some(
          error_diagnostic(
            "STYLE_ANIMATION_LIST_EMPTY",
            "Animation names must not be empty",
            source=declaration.source,
          ),
        )
      }
      for value in declaration.value.animations() {
        if validate_animation(value, declaration.source) is Some(error) {
          return Some(error)
        }
      }
    }
    Clear =>
      if !declaration.conditions.is_empty() {
        return Some({
          code: "STYLE_CLEAR_CONDITION",
          severity: Error,
          message: "Clear declarations cannot contain CSS conditions; condition the compiled style during composition",
          source: declaration.source,
          context: None,
        })
      }
  }
  if !declaration.atomic_properties.is_empty() {
    return Some({
      code: "STYLE_LEGACY_ATOMIC_PROPERTIES",
      severity: Error,
      message: "atomic_properties uses pre-v5 expansion semantics; re-extract the declaration",
      source: declaration.source,
      context: None,
    })
  }
  let mut pseudo_element_count = 0
  let mut relational_count = 0
  for condition in declaration.conditions {
    match condition {
      Pseudo(value) =>
        if invalid_pseudo_class(value) {
          return Some({
            code: "STYLE_SELECTOR_STATE",
            severity: Error,
            message: "Functional state selector or attribute is invalid",
            source: declaration.source,
            context: None,
          })
        }
      PseudoElement(_) => {
        pseudo_element_count = pseudo_element_count + 1
        if pseudo_element_count > 1 {
          return Some({
            code: "STYLE1012",
            severity: Error,
            message: "A declaration may contain at most one pseudo-element",
            source: declaration.source,
            context: None,
          })
        }
      }
      UnsafePseudo(value) =>
        if !value.has_prefix(":") ||
          value.has_prefix("::") ||
          invalid_condition_text(value) {
          return Some({
            code: "STYLE1004",
            severity: Error,
            message: "Unsafe pseudo-class syntax is invalid",
            source: declaration.source,
            context: None,
          })
        }
      UnsafePseudoElement(value) => {
        pseudo_element_count = pseudo_element_count + 1
        if pseudo_element_count > 1 {
          return Some({
            code: "STYLE1012",
            severity: Error,
            message: "A declaration may contain at most one pseudo-element",
            source: declaration.source,
            context: None,
          })
        }
        if !value.has_prefix("::") || invalid_condition_text(value) {
          return Some({
            code: "STYLE1006",
            severity: Error,
            message: "Unsafe pseudo-element syntax is invalid",
            source: declaration.source,
            context: None,
          })
        }
      }
      UnsafeAtRule(value) =>
        if !value.has_prefix("@") || invalid_condition_text(value) {
          return Some({
            code: "STYLE1005",
            severity: Error,
            message: "Unsafe at-rule syntax is invalid",
            source: declaration.source,
            context: None,
          })
        }
      Media(query) =>
        if query.features.is_empty() && query.media_type is None {
          return Some({
            code: "STYLE1007",
            severity: Error,
            message: "Media query must contain a media type or feature",
            source: declaration.source,
            context: None,
          })
        } else {
          for feature in query.features {
            if !valid_kebab_name(feature.name) ||
              invalid_condition_text(feature.value) {
              return Some({
                code: "STYLE1007",
                severity: Error,
                message: "Media feature name or value is invalid",
                source: declaration.source,
                context: None,
              })
            }
          }
        }
      Supports(condition) =>
        if invalid_supports_condition(condition) {
          return Some({
            code: "STYLE1008",
            severity: Error,
            message: "Supports condition is invalid",
            source: declaration.source,
            context: None,
          })
        }
      Container(query) => {
        let invalid_name = match query.name {
          Some(name) => !valid_kebab_name(name)
          None => false
        }
        if query.features.is_empty() || invalid_name {
          return Some({
            code: "STYLE_CONTAINER_QUERY",
            severity: Error,
            message: "Container query must contain a valid name and at least one size feature",
            source: declaration.source,
            context: None,
          })
        }
        for feature in query.features {
          if !["width", "height", "inline-size", "block-size"].contains(
              feature.name,
            ) ||
            invalid_condition_text(feature.value) {
            return Some({
              code: "STYLE_CONTAINER_QUERY",
              severity: Error,
              message: "Container query size feature is invalid",
              source: declaration.source,
              context: None,
            })
          }
        }
      }
      ContainerStyle(condition) =>
        if invalid_container_style_condition(condition) {
          return Some({
            code: "STYLE_CONTAINER_STYLE",
            severity: Error,
            message: "Container style queries require valid custom-property declarations and non-empty boolean groups",
            source: declaration.source,
            context: None,
          })
        }
      Relational(marker, _) => {
        relational_count = relational_count + 1
        if relational_count > 1 ||
          marker.module_name.is_empty() ||
          marker.name.is_empty() ||
          !marker.class_name.has_prefix("m") {
          return Some({
            code: "STYLE_SELECTOR_MARKER",
            severity: Error,
            message: "A declaration may contain one resolved selector-marker relation",
            source: declaration.source,
            context: None,
          })
        }
        for state in marker.states {
          match state {
            SelectorPseudo(value) =>
              if invalid_pseudo_class(value) {
                return Some({
                  code: "STYLE_SELECTOR_MARKER_STATE",
                  severity: Error,
                  message: "Selector-marker state is invalid",
                  source: declaration.source,
                  context: None,
                })
              }
            SelectorAttributeMatch(value) =>
              if invalid_attribute_selector(value) {
                return Some({
                  code: "STYLE_SELECTOR_MARKER_STATE",
                  severity: Error,
                  message: "Selector-marker attribute is invalid",
                  source: declaration.source,
                  context: None,
                })
              }
            SelectorAttribute(name) =>
              if !valid_kebab_name(name) {
                return Some({
                  code: "STYLE_SELECTOR_MARKER_STATE",
                  severity: Error,
                  message: "Selector-marker attribute name is invalid",
                  source: declaration.source,
                  context: None,
                })
              }
            SelectorAttributeEquals(name, value) =>
              if !valid_kebab_name(name) ||
                invalid_condition_text(value) ||
                value.contains("'") ||
                value.contains("\\") {
                return Some({
                  code: "STYLE_SELECTOR_MARKER_STATE",
                  severity: Error,
                  message: "Selector-marker attribute equality is invalid",
                  source: declaration.source,
                  context: None,
                })
              }
          }
        }
      }
      Layer(name) =>
        if !valid_kebab_name(name) {
          return Some({
            code: "STYLE1009",
            severity: Error,
            message: "Layer name must not be empty",
            source: declaration.source,
            context: None,
          })
        }
    }
  }
  None
}

///|
pub fn sort_and_dedupe(rules : Array[AtomicRule]) -> Array[AtomicRule] {
  let unique : Array[AtomicRule] = []
  for rule in rules {
    if !unique.any(existing => existing.class_name == rule.class_name) {
      unique.push(rule)
    }
  }
  unique.sort_by(compare_rules)
  unique
}

///|
pub fn sort_and_dedupe_globals(
  globals : Array[GlobalRule],
) -> Array[GlobalRule] {
  let unique : Array[GlobalRule] = []
  for global in globals {
    if !unique.any(existing => {
        existing.kind == global.kind &&
        existing.name == global.name &&
        existing.digest == global.digest
      }) {
      unique.push(global)
    }
  }
  unique.sort_by((left, right) => {
    let kind_rank = fn(kind : String) {
      match kind {
        "property" => 0
        "variables" => 1
        "theme" => 2
        "keyframes" => 3
        "position-try" => 4
        _ => 5
      }
    }
    let kind_order = kind_rank(left.kind) - kind_rank(right.kind)
    if kind_order != 0 {
      kind_order
    } else {
      let name_order = left.name.compare(right.name)
      if name_order != 0 {
        name_order
      } else {
        left.css.compare(right.css)
      }
    }
  })
  unique
}

///|
fn validate_variable_set(variable_set : @ir.VariableSet) -> Diagnostic? {
  let scope = variable_set.scope.trim().to_owned()
  if !valid_kebab_name(scope) {
    return Some(
      error_diagnostic(
        "STYLE_VARIABLE_SCOPE", "Variable scope must be a non-empty kebab-case identifier",
      ),
    )
  }
  if variable_set.definitions.is_empty() {
    return Some(
      error_diagnostic(
        "STYLE_VARIABLE_SET_EMPTY", "Variable set must contain at least one definition",
      ),
    )
  }
  let names : Array[String] = []
  let prefix = "--" + scope + "-"
  for definition in variable_set.definitions {
    if !definition.name.has_prefix(prefix) ||
      definition.name.length() == prefix.length() {
      return Some(
        error_diagnostic(
          "STYLE_VARIABLE_NAME", "Variable name must use the declared scope",
        ),
      )
    }
    if names.contains(definition.name) {
      return Some(
        error_diagnostic(
          "STYLE_VARIABLE_DUPLICATE", "Variable names must be unique within a set",
        ),
      )
    }
    if definition.default_css.trim().is_empty() {
      return Some(
        error_diagnostic(
          "STYLE_VARIABLE_DEFAULT", "Variable default value must not be empty",
        ),
      )
    }
    names.push(definition.name)
  }
  None
}

///|
fn variable_value_css(
  category : @values.ValueCategory,
  value : String,
) -> String {
  let css = canonical_css_value(value)
  // Custom properties can be consumed by math in another module. Preserve
  // their declared dimension even when this registry has no local math use.
  if css == "0" &&
    (category == LengthCategory || category == LengthPercentageCategory) {
    "0px"
  } else {
    css
  }
}

///|
fn variable_set_css(variable_set : @ir.VariableSet) -> String {
  let definitions = variable_set.definitions.copy()
  definitions.sort_by((left, right) => left.name.compare(right.name))
  ":root{" +
  definitions
  .map(definition => {
    definition.name +
    ":" +
    variable_value_css(definition.category, definition.default_css)
  })
  .join(";") +
  "}"
}

///|
fn variable_global(
  module_name : String,
  variable_set : @ir.VariableSet,
) -> GlobalRule {
  let css = variable_set_css(variable_set)
  let name = "v" + hash(module_name + ":" + variable_set.scope + ":" + css)
  { kind: "variables", name, css, digest: sha256_digest(css), }
}

///|
pub fn theme_class_name(module_name : String, theme : @ir.Theme) -> String {
  let overrides = theme.overrides.copy()
  overrides.sort_by((left, right) => left.name.compare(right.name))
  let canonical = overrides
    .map(item => {
      item.name + ":" + variable_value_css(item.category, item.value_css)
    })
    .join(";")
  "t" +
  hash(
    module_name + ":" + theme.base.scope + ":" + theme.name + ":" + canonical,
  )
}

///|
fn validate_theme(
  theme : @ir.Theme,
  variable_sets : Array[@ir.VariableSet],
) -> Diagnostic? {
  if !valid_kebab_name(theme.name) {
    return Some(
      error_diagnostic(
        "STYLE_THEME_NAME", "Theme name must be a non-empty kebab-case identifier",
      ),
    )
  }
  if !variable_sets.contains(theme.base) {
    return Some(
      error_diagnostic(
        "STYLE_THEME_BASE", "Theme base variable set must be registered",
      ),
    )
  }
  if theme.overrides.is_empty() {
    return Some(
      error_diagnostic(
        "STYLE_THEME_EMPTY", "Theme must override at least one variable",
      ),
    )
  }
  let names : Array[String] = []
  for item in theme.overrides {
    if names.contains(item.name) {
      return Some(
        error_diagnostic(
          "STYLE_THEME_DUPLICATE", "Theme overrides must not contain duplicate variables",
        ),
      )
    }
    names.push(item.name)
    let mut definition : @values.VarDefinition? = None
    for candidate in theme.base.definitions {
      if candidate.name == item.name {
        definition = Some(candidate)
      }
    }
    match definition {
      None =>
        return Some(
          error_diagnostic(
            "STYLE_THEME_UNKNOWN_VARIABLE", "Theme override refers to an unknown variable",
          ),
        )
      Some(definition) if definition.category != item.category =>
        return Some(
          error_diagnostic(
            "STYLE_THEME_CATEGORY", "Theme override category does not match its variable",
          ),
        )
      Some(_) => ()
    }
  }
  None
}

///|
fn theme_global(module_name : String, theme : @ir.Theme) -> GlobalRule {
  let name = theme_class_name(module_name, theme)
  let overrides = theme.overrides.copy()
  overrides.sort_by((left, right) => left.name.compare(right.name))
  let css = "." +
    name +
    "{" +
    overrides
    .map(item => {
      item.name + ":" + variable_value_css(item.category, item.value_css)
    })
    .join(";") +
    "}"
  { kind: "theme", name, css, digest: sha256_digest(css), }
}

///|
pub fn compile_position_tries(
  module_name : String,
  definitions : Array[@ir.PositionTryDefinition],
) -> (Array[GlobalRule], Array[Diagnostic]) {
  let globals : Array[GlobalRule] = []
  let diagnostics : Array[Diagnostic] = []
  let names : Array[String] = []
  let allowed = [
    "position-anchor", "position-area", "top", "right", "bottom", "left", "inset",
    "inset-block", "inset-block-start", "inset-block-end", "inset-inline", "inset-inline-start",
    "inset-inline-end", "margin", "margin-top", "margin-right", "margin-bottom",
    "margin-left", "margin-block", "margin-block-start", "margin-block-end", "margin-inline",
    "margin-inline-start", "margin-inline-end", "width", "height", "min-width", "min-height",
    "max-width", "max-height", "block-size", "inline-size", "min-block-size", "min-inline-size",
    "max-block-size", "max-inline-size", "align-self", "justify-self", "place-self",
  ]
  for definition in definitions {
    let local_name = if definition.name.has_prefix("--") {
      definition.name[2:].to_owned()
    } else {
      ""
    }
    if !valid_kebab_name(local_name) ||
      names.contains(definition.name) ||
      definition.descriptors.is_empty() {
      diagnostics.push(
        error_diagnostic(
          "STYLE_POSITION_TRY_NAME",
          "Position-try names must be unique dashed identifiers with at least one descriptor",
          context=Some(diagnostic_context(module_name)),
        ),
      )
      continue
    }
    names.push(definition.name)
    let descriptor_names : Array[String] = []
    let invalid = definition.descriptors.any(descriptor => {
      let duplicate = descriptor_names.contains(descriptor.name)
      descriptor_names.push(descriptor.name)
      duplicate ||
      !allowed.contains(descriptor.name) ||
      descriptor.value.trim().is_empty() ||
      [";", "{", "}", "!", "/*", "*/"].any(part => {
        descriptor.value.contains(part)
      }) ||
      !css_value_diagnostics(
        descriptor.value,
        definition.name + "." + descriptor.name,
      ).is_empty()
    })
    if invalid {
      diagnostics.push(
        error_diagnostic(
          "STYLE_POSITION_TRY_DESCRIPTOR",
          "Position-try contains a duplicate, unsupported, or invalid descriptor",
          context=Some(diagnostic_context(module_name)),
        ),
      )
      continue
    }
    let css = "@position-try " +
      definition.name +
      "{" +
      definition.descriptors
      .map(descriptor => {
        descriptor.name + ":" + canonical_css_value(descriptor.value)
      })
      .join(";") +
      "}"
    globals.push({
      kind: "position-try",
      name: definition.name,
      css,
      digest: sha256_digest(css),
    })
  }
  (sort_and_dedupe_globals(globals), diagnostics)
}

///|
pub fn compile_registry_globals(
  module_name : String,
  variable_sets : Array[@ir.VariableSet],
  themes : Array[@ir.Theme],
) -> (Array[GlobalRule], Array[Diagnostic]) {
  let globals : Array[GlobalRule] = []
  let diagnostics : Array[Diagnostic] = []
  let registrations : Map[String, String] = Map([])
  for variable_set in variable_sets {
    let value_diagnostics : Array[Diagnostic] = []
    for definition in variable_set.definitions {
      for
        diagnostic in css_value_diagnostics(
          definition.default_css,
          variable_set.scope + "." + definition.name,
        ) {
        value_diagnostics.push(diagnostic)
      }
      if definition.registration_issue() is Some(issue) {
        value_diagnostics.push(error_diagnostic(issue.code, issue.label))
      }
      if definition.registration is Some(_) &&
        (
          !definition.name.has_prefix("--") ||
          !valid_kebab_name(definition.name[2:].to_owned())
        ) {
        value_diagnostics.push(
          error_diagnostic(
            "STYLE_PROPERTY_NAME", "Registered property names must be scoped kebab-case identifiers",
          ),
        )
      }
    }
    if value_diagnostics.is_empty() {
      match validate_variable_set(variable_set) {
        Some(diagnostic) => diagnostics.push(diagnostic)
        None => {
          for definition in variable_set.definitions {
            if definition.registration is Some(_) {
              let global = property_global(definition)
              let css = global.css
              match registrations.get(definition.name) {
                Some(existing) if existing != css =>
                  diagnostics.push(
                    error_diagnostic(
                      "STYLE_PROPERTY_CONFLICT",
                      "Conflicting registration for " + definition.name,
                    ),
                  )
                _ => {
                  registrations[definition.name] = css
                  globals.push(global)
                }
              }
            }
          }
          globals.push(variable_global(module_name, variable_set))
        }
      }
    } else {
      for diagnostic in value_diagnostics {
        diagnostics.push(diagnostic)
      }
    }
  }
  for theme in themes {
    let value_diagnostics : Array[Diagnostic] = []
    for override_ in theme.overrides {
      for
        diagnostic in css_value_diagnostics(
          override_.value_css,
          theme.name + "." + override_.name,
        ) {
        value_diagnostics.push(diagnostic)
      }
    }
    if value_diagnostics.is_empty() {
      match validate_theme(theme, variable_sets) {
        Some(diagnostic) => diagnostics.push(diagnostic)
        None => globals.push(theme_global(module_name, theme))
      }
    } else {
      for diagnostic in value_diagnostics {
        diagnostics.push(diagnostic)
      }
    }
  }
  (sort_and_dedupe_globals(globals), diagnostics)
}

///|
pub fn compile(style_set : @ir.StyleSet) -> CompiledStyleSet {
  let namespaces : Array[CompiledNamespace] = []
  let rules : Array[AtomicRule] = []
  let globals : Array[GlobalRule] = []
  let diagnostics : Array[Diagnostic] = []
  for style_namespace in style_set.namespaces {
    let entries : Array[(String, String?)] = []
    let entry_properties : Array[String] = []
    for declaration in style_namespace.declarations {
      let value_diagnostics = authored_value_diagnostics(
        declaration,
        style_namespace.name,
      )
      if !value_diagnostics.is_empty() {
        for diagnostic in value_diagnostics {
          diagnostics.push(diagnostic)
        }
        continue
      }
      match validate_declaration(declaration) {
        Some(diagnostic) => {
          diagnostics.push(diagnostic)
          continue
        }
        None => ()
      }
      let property = declaration.property
      let semantic_entries = if declaration.unsafe_raw {
        [(property, true)]
      } else {
        application_order_entries(property)
      }
      if declaration.value is Clear {
        for semantic_entry in semantic_entries {
          match entries.search_by(entry => entry.0 == semantic_entry.0) {
            Some(index) => {
              entries[index] = (semantic_entry.0, None)
              entry_properties[index] = property
            }
            None => {
              entries.push((semantic_entry.0, None))
              entry_properties.push(property)
            }
          }
        }
        continue
      }
      let rule = compile_atomic_declaration(declaration, property)
      for semantic_entry in semantic_entries {
        let value = if semantic_entry.1 { Some(rule.class_name) } else { None }
        match entries.search_by(entry => entry.0 == semantic_entry.0) {
          Some(index) => {
            let combined = match (entries[index].1, value) {
              (Some(existing), Some(next)) =>
                if entry_properties[index] == property {
                  Some(
                    if existing.split(" ").contains(next) {
                      existing
                    } else {
                      existing + " " + next
                    },
                  )
                } else {
                  value
                }
              _ => value
            }
            entries[index] = (semantic_entry.0, combined)
            entry_properties[index] = property
          }
          None => {
            entries.push((semantic_entry.0, value))
            entry_properties.push(property)
          }
        }
      }
      rules.push(rule)
      for value in declaration.value.animations() {
        globals.push(animation_global(value))
      }
    }
    namespaces.push({ name: style_namespace.name, entries, })
  }
  {
    namespaces,
    rules: sort_and_dedupe(rules),
    globals: sort_and_dedupe_globals(globals),
    diagnostics,
  }
}

///|
fn add_ancestor_selector(rule : String, ancestor : String) -> String {
  if !rule.has_prefix("@") {
    return ancestor + " " + rule
  }
  match rule.rev_find("@") {
    Some(last_at_rule) => {
      let suffix = rule[last_at_rule:].to_owned()
      match suffix.find("{") {
        Some(relative_brace) => {
          let brace = last_at_rule + relative_brace
          rule[:brace + 1].to_owned() +
          ancestor +
          " " +
          rule[brace + 1:].to_owned()
        }
        None => ancestor + " " + rule
      }
    }
    None => ancestor + " " + rule
  }
}

///|
pub fn render_rules(rules : Array[AtomicRule]) -> String {
  rules
  .map(rule => {
    let ltr = with_priority_specificity(rule.ltr, rule.priority100)
    match rule.rtl {
      Some(rtl) =>
        add_ancestor_selector(ltr, ":where(html:not([dir='rtl']))") +
        "\n" +
        add_ancestor_selector(
          with_priority_specificity(rtl, rule.priority100),
          ":where(html[dir='rtl'])",
        )
      None => ltr
    }
  })
  .join("\n")
}

///|
pub fn render_css(compiled : CompiledStyleSet) -> String {
  let blocks = compiled.globals.map(global => global.css)
  let rules = render_rules(compiled.rules)
  if !rules.is_empty() {
    blocks.push(rules)
  }
  blocks.join("\n")
}
