///|
struct BundleDependency {
  module_name : String
  semantic_digest : String
} derive(Eq, Debug)

///|
struct BundleNamespace {
  name : String
  entries : Array[(String, String?)]
} derive(Eq, Debug)

///|
struct BundleContract {
  module_name : String
  name : String
  mappings_package : String
  trait_name : String
  properties : Array[@ir.ContractProperty]
} derive(Eq, Debug)

///|
struct BundleContractV6 {
  module_name : String
  name : String
  mappings_package : String
  trait_name : String
  properties : Array[String]
} derive(Eq, Debug)

///|
struct BundleRule {
  property : String
  class_name : String
  ltr : String
  rtl : String?
  priority100 : Int32
} derive(Eq, Debug)

///|
struct BundleGlobal {
  kind : String
  name : String
  css : String
  digest : String
} derive(Eq, Debug)

///|
struct BundleRecipe {
  module_name : String
  mappings_package : String
  recipe : @ir.Recipe
} derive(Eq, Debug)

///|
struct BundleMarker {
  module_name : String
  mappings_package : String
  name : String
  class_name : String
} derive(Eq, Debug)

///|
struct BundleViewTransitionClass {
  module_name : String
  mappings_package : String
  name : String
  css_name : String
  styles : Array[@core.ViewTransitionBlock]
} derive(Eq, Debug)

///|
pub struct DependencyBundle {
  module_name : String
  mappings_package : String
  semantic_digest : String
  direct_dependencies : Array[BundleDependency]
  dependency_closure : Array[BundleDependency]
  contracts : Array[BundleContract]
  namespaces : Array[BundleNamespace]
  rules : Array[BundleRule]
  globals : Array[BundleGlobal]
  recipes : Array[BundleRecipe]
  markers : Array[BundleMarker]
  view_transition_classes : Array[BundleViewTransitionClass]
}

///|
fn bundle_diagnostic(
  code : String,
  message : String,
  module_name~ : String = "",
  dependency_chain~ : Array[String] = [],
) -> @core.Diagnostic {
  let context = if module_name.is_empty() {
    None
  } else {
    Some(@core.diagnostic_context(module_name, dependency_chain~))
  }
  @core.error_diagnostic(code, message, context~)
}

///|
fn exact_fields(object : Map[String, Json], fields : Array[String]) -> Bool {
  if object.length() != fields.length() {
    return false
  }
  fields.every(field => object.contains(field))
}

///|
fn bundle_semantics_json() -> Json {
  {
    "profile": @core.application_order_profile,
    "digest": @core.application_order_digest,
  }
}

///|
fn decode_bundle_semantics(value : Json) -> Result[Unit, @core.Diagnostic] {
  guard value is Object(object) &&
    exact_fields(object, ["profile", "digest"]) &&
    object.get("profile") is Some(String(profile)) &&
    object.get("digest") is Some(String(digest)) else {
    return Err(
      bundle_diagnostic(
        "STYLE_BUNDLE_SEMANTICS", "Bundle semantics must contain exactly profile and digest",
      ),
    )
  }
  if profile != @core.application_order_profile ||
    digest != @core.application_order_digest {
    Err(
      bundle_diagnostic(
        "STYLE_BUNDLE_SEMANTICS_MISMATCH", "Bundle semantics do not match the active StyleX application-order profile",
      ),
    )
  } else {
    Ok(())
  }
}

///|
fn decode_dependencies(
  value : Json,
) -> Result[Array[BundleDependency], @core.Diagnostic] {
  guard value is Array(items) else {
    return Err(
      bundle_diagnostic(
        "STYLE_BUNDLE_TYPE", "Bundle dependencies must be an array",
      ),
    )
  }
  let output : Array[BundleDependency] = []
  for item in items {
    guard item is Object(object) &&
      exact_fields(object, ["module", "semanticDigest"]) &&
      object.get("module") is Some(String(module_name)) &&
      object.get("semanticDigest") is Some(String(digest)) else {
      return Err(
        bundle_diagnostic(
          "STYLE_BUNDLE_DEPENDENCY", "Bundle dependency has invalid or unknown fields",
        ),
      )
    }
    output.push({ module_name, semantic_digest: digest, })
  }
  Ok(output)
}

///|
fn decode_entry(value : Json) -> Result[(String, String?), @core.Diagnostic] {
  guard value is Array(entry) && entry.length() == 2 else {
    return Err(
      bundle_diagnostic(
        "STYLE_BUNDLE_NAMESPACE", "Namespace entry must be a two-item array",
      ),
    )
  }
  guard entry[0] is String(key) else {
    return Err(
      bundle_diagnostic(
        "STYLE_BUNDLE_NAMESPACE", "Namespace entry key must be a string",
      ),
    )
  }
  match entry[1] {
    String(class_name) => Ok((key, Some(class_name)))
    Null => Ok((key, None))
    _ =>
      Err(
        bundle_diagnostic(
          "STYLE_BUNDLE_NAMESPACE", "Namespace entry value must be a string or null",
        ),
      )
  }
}

///|
fn decode_namespaces(
  value : Json,
) -> Result[Array[BundleNamespace], @core.Diagnostic] {
  guard value is Array(items) else {
    return Err(
      bundle_diagnostic(
        "STYLE_BUNDLE_TYPE", "Bundle namespaces must be an array",
      ),
    )
  }
  let output : Array[BundleNamespace] = []
  for item in items {
    guard item is Object(object) &&
      exact_fields(object, ["name", "entries"]) &&
      object.get("name") is Some(String(name)) &&
      object.get("entries") is Some(Array(entries)) else {
      return Err(
        bundle_diagnostic(
          "STYLE_BUNDLE_NAMESPACE", "Namespace has invalid or unknown fields",
        ),
      )
    }
    let decoded : Array[(String, String?)] = []
    for entry in entries {
      match decode_entry(entry) {
        Ok(value) => decoded.push(value)
        Err(diagnostic) => return Err(diagnostic)
      }
    }
    output.push({ name, entries: decoded, })
  }
  Ok(output)
}

///|
fn decode_contract_variable(
  value : Json,
) -> Result[@ir.ContractVariable, @core.Diagnostic] {
  guard value is Object(object) &&
    exact_fields(object, ["variable", "category"]) &&
    object.get("variable") is Some(String(variable)) &&
    object.get("category") is Some(String(category)) else {
    return Err(
      bundle_diagnostic(
        "STYLE_BUNDLE_CONTRACT", "Contract value channel has invalid or unknown fields",
      ),
    )
  }
  Ok(@ir.contract_variable(variable, category))
}

///|
fn decode_contract_variables(
  value : Json,
) -> Result[Array[@ir.ContractVariable], @core.Diagnostic] {
  guard value is Array(items) else {
    return Err(
      bundle_diagnostic(
        "STYLE_BUNDLE_CONTRACT", "Contract value channels must be arrays",
      ),
    )
  }
  let output : Array[@ir.ContractVariable] = []
  for item in items {
    match decode_contract_variable(item) {
      Ok(value) => output.push(value)
      Err(diagnostic) => return Err(diagnostic)
    }
  }
  Ok(output)
}

///|
fn decode_contract_property(
  value : Json,
) -> Result[@ir.ContractProperty, @core.Diagnostic] {
  guard value is Object(object) &&
    object.get("name") is Some(String(name)) &&
    object.get("policy") is Some(String(policy)) else {
    return Err(
      bundle_diagnostic(
        "STYLE_BUNDLE_CONTRACT", "Contract property must declare a name and policy",
      ),
    )
  }
  if policy == "any" {
    if !exact_fields(object, ["name", "policy"]) {
      return Err(
        bundle_diagnostic(
          "STYLE_BUNDLE_CONTRACT", "Any-safe contract property has invalid or unknown fields",
        ),
      )
    }
    return Ok(@ir.any_contract_property(name))
  }
  guard policy == "exact" &&
    exact_fields(object, [
      "name", "policy", "values", "tokens", "slots", "expressions",
    ]) &&
    object.get("expressions") is Some(Array(expression_items)) &&
    object.get("values") is Some(Array(value_items)) &&
    object.get("tokens") is Some(token_value) &&
    object.get("slots") is Some(slot_value) else {
    return Err(
      bundle_diagnostic(
        "STYLE_BUNDLE_CONTRACT", "Exact contract property has invalid or unknown fields",
      ),
    )
  }
  let values : Array[String] = []
  let expressions : Array[String] = []
  for item in expression_items {
    guard item is String(identity) &&
      @values.valid_expression_identity(identity) else {
      return Err(
        bundle_diagnostic(
          "STYLE_BUNDLE_CONTRACT", "Invalid exact expression identity",
        ),
      )
    }
    expressions.push(identity)
  }
  for item in value_items {
    guard item is String(value) else {
      return Err(
        bundle_diagnostic(
          "STYLE_BUNDLE_CONTRACT", "Exact contract literal values must be strings",
        ),
      )
    }
    values.push(value)
  }
  let tokens = match decode_contract_variables(token_value) {
    Ok(values) => values
    Err(diagnostic) => return Err(diagnostic)
  }
  let slots = match decode_contract_variables(slot_value) {
    Ok(values) => values
    Err(diagnostic) => return Err(diagnostic)
  }
  Ok(@ir.exact_contract_property(name, values~, tokens~, slots~, expressions~))
}

///|
fn decode_contracts(
  value : Json,
) -> Result[Array[BundleContract], @core.Diagnostic] {
  guard value is Array(items) else {
    return Err(
      bundle_diagnostic(
        "STYLE_BUNDLE_TYPE", "Bundle contracts must be an array",
      ),
    )
  }
  let output : Array[BundleContract] = []
  for item in items {
    guard item is Object(object) &&
      exact_fields(object, [
        "module", "name", "mappingsPackage", "trait", "properties",
      ]) &&
      object.get("module") is Some(String(module_name)) &&
      object.get("name") is Some(String(name)) &&
      object.get("mappingsPackage") is Some(String(mappings_package)) &&
      object.get("trait") is Some(String(trait_name)) &&
      object.get("properties") is Some(Array(property_values)) else {
      return Err(
        bundle_diagnostic(
          "STYLE_BUNDLE_CONTRACT", "Bundle contract has invalid or unknown fields",
        ),
      )
    }
    let properties : Array[@ir.ContractProperty] = []
    for property in property_values {
      match decode_contract_property(property) {
        Ok(value) => properties.push(value)
        Err(diagnostic) => return Err(diagnostic)
      }
    }
    output.push({ module_name, name, mappings_package, trait_name, properties, })
  }
  Ok(output)
}

///|
fn decode_contracts_v6(
  value : Json,
) -> Result[Array[BundleContractV6], @core.Diagnostic] {
  guard value is Array(items) else {
    return Err(
      bundle_diagnostic(
        "STYLE_BUNDLE_TYPE", "Bundle contracts must be an array",
      ),
    )
  }
  let output : Array[BundleContractV6] = []
  for item in items {
    guard item is Object(object) &&
      exact_fields(object, [
        "module", "name", "mappingsPackage", "trait", "properties",
      ]) &&
      object.get("module") is Some(String(module_name)) &&
      object.get("name") is Some(String(name)) &&
      object.get("mappingsPackage") is Some(String(mappings_package)) &&
      object.get("trait") is Some(String(trait_name)) &&
      object.get("properties") is Some(Array(property_values)) else {
      return Err(
        bundle_diagnostic(
          "STYLE_BUNDLE_CONTRACT", "Schema v6 bundle contract has invalid or unknown fields",
        ),
      )
    }
    let properties : Array[String] = []
    for property in property_values {
      guard property is String(name) else {
        return Err(
          bundle_diagnostic(
            "STYLE_BUNDLE_CONTRACT", "Schema v6 contract properties must be strings",
          ),
        )
      }
      properties.push(name)
    }
    output.push({ module_name, name, mappings_package, trait_name, properties, })
  }
  Ok(output)
}

///|
fn decode_rules(value : Json) -> Result[Array[BundleRule], @core.Diagnostic] {
  guard value is Array(items) else {
    return Err(
      bundle_diagnostic("STYLE_BUNDLE_TYPE", "Bundle rules must be an array"),
    )
  }
  let output : Array[BundleRule] = []
  for item in items {
    guard item is Object(object) &&
      exact_fields(object, [
        "property", "className", "ltr", "rtl", "priority100",
      ]) &&
      object.get("property") is Some(String(property)) &&
      object.get("className") is Some(String(class_name)) &&
      object.get("ltr") is Some(String(ltr)) &&
      object.get("priority100") is Some(Number(priority100, ..)) &&
      priority100 > 0.0 &&
      priority100 == priority100.to_int().to_double() else {
      return Err(
        bundle_diagnostic(
          "STYLE_BUNDLE_RULE", "Rule has invalid or unknown fields",
        ),
      )
    }
    let rtl = match object.get("rtl") {
      Some(String(value)) => Some(value)
      Some(Null) => None
      _ =>
        return Err(
          bundle_diagnostic(
            "STYLE_BUNDLE_RULE", "Rule RTL field must be a string or null",
          ),
        )
    }
    output.push({
      property,
      class_name,
      ltr,
      rtl,
      priority100: priority100.to_int(),
    })
  }
  Ok(output)
}

///|
fn decode_legacy_rules(
  value : Json,
) -> Result[Array[BundleRule], @core.Diagnostic] {
  guard value is Array(items) else {
    return Err(
      bundle_diagnostic("STYLE_BUNDLE_TYPE", "Bundle rules must be an array"),
    )
  }
  let output : Array[BundleRule] = []
  for item in items {
    guard item is Object(object) &&
      exact_fields(object, ["property", "className", "ltr", "rtl", "priority"]) &&
      object.get("property") is Some(String(property)) &&
      object.get("className") is Some(String(class_name)) &&
      object.get("ltr") is Some(String(ltr)) &&
      object.get("priority") is Some(Number(priority, ..)) else {
      return Err(
        bundle_diagnostic(
          "STYLE_BUNDLE_RULE", "Legacy rule has invalid or unknown fields",
        ),
      )
    }
    let rtl = match object.get("rtl") {
      Some(String(value)) => Some(value)
      Some(Null) => None
      _ =>
        return Err(
          bundle_diagnostic(
            "STYLE_BUNDLE_RULE", "Rule RTL field must be a string or null",
          ),
        )
    }
    output.push({
      property,
      class_name,
      ltr,
      rtl,
      priority100: priority.to_int() * @core.application_order_priority_scale,
    })
  }
  Ok(output)
}

///|
fn decode_globals(
  value : Json,
) -> Result[Array[BundleGlobal], @core.Diagnostic] {
  guard value is Array(items) else {
    return Err(
      bundle_diagnostic("STYLE_BUNDLE_TYPE", "Bundle globals must be an array"),
    )
  }
  let output : Array[BundleGlobal] = []
  for item in items {
    guard item is Object(object) &&
      exact_fields(object, ["kind", "name", "css", "digest"]) &&
      object.get("kind") is Some(String(kind)) &&
      object.get("name") is Some(String(name)) &&
      object.get("css") is Some(String(css)) &&
      object.get("digest") is Some(String(digest)) else {
      return Err(
        bundle_diagnostic(
          "STYLE_BUNDLE_GLOBAL", "Global has invalid or unknown fields",
        ),
      )
    }
    output.push({ kind, name, css, digest, })
  }
  Ok(output)
}

///|
fn decode_string_array(
  value : Json,
  label : String,
) -> Result[Array[String], @core.Diagnostic] {
  guard value is Array(items) else {
    return Err(
      bundle_diagnostic("STYLE_BUNDLE_TYPE", label + " must be an array"),
    )
  }
  let output : Array[String] = []
  for item in items {
    guard item is String(value) else {
      return Err(
        bundle_diagnostic(
          "STYLE_BUNDLE_TYPE",
          label + " must contain only strings",
        ),
      )
    }
    output.push(value)
  }
  Ok(output)
}

///|
fn decode_recipe_choices(
  value : Json,
) -> Result[Array[@ir.RecipeVariantChoice], @core.Diagnostic] {
  guard value is Array(items) else {
    return Err(
      bundle_diagnostic(
        "STYLE_BUNDLE_RECIPE", "Recipe choices must be an array",
      ),
    )
  }
  let output : Array[@ir.RecipeVariantChoice] = []
  for item in items {
    guard item is Object(object) &&
      exact_fields(object, ["value", "rules"]) &&
      object.get("value") is Some(String(choice_value)) &&
      object.get("rules") is Some(rule_value) else {
      return Err(
        bundle_diagnostic(
          "STYLE_BUNDLE_RECIPE", "Recipe choice has invalid or unknown fields",
        ),
      )
    }
    let rules = match decode_string_array(rule_value, "Recipe choice rules") {
      Ok(value) => value
      Err(diagnostic) => return Err(diagnostic)
    }
    output.push({ value: choice_value, rules, })
  }
  Ok(output)
}

///|
fn decode_recipe_axes(
  value : Json,
) -> Result[Array[@ir.RecipeVariantAxis], @core.Diagnostic] {
  guard value is Array(items) else {
    return Err(
      bundle_diagnostic(
        "STYLE_BUNDLE_RECIPE", "Recipe variants must be an array",
      ),
    )
  }
  let output : Array[@ir.RecipeVariantAxis] = []
  for item in items {
    guard item is Object(object) &&
      exact_fields(object, ["name", "boolean", "default", "choices"]) &&
      object.get("name") is Some(String(name)) &&
      object.get("boolean") is Some(boolean_value) &&
      object.get("default") is Some(default_value) &&
      object.get("choices") is Some(choice_value) else {
      return Err(
        bundle_diagnostic(
          "STYLE_BUNDLE_RECIPE", "Recipe variant axis has invalid or unknown fields",
        ),
      )
    }
    let boolean = match boolean_value {
      True => true
      False => false
      _ =>
        return Err(
          bundle_diagnostic(
            "STYLE_BUNDLE_RECIPE", "Recipe boolean flag must be a boolean",
          ),
        )
    }
    let default_value = match default_value {
      String(value) => Some(value)
      Null => None
      _ =>
        return Err(
          bundle_diagnostic(
            "STYLE_BUNDLE_RECIPE", "Recipe default must be a string or null",
          ),
        )
    }
    let choices = match decode_recipe_choices(choice_value) {
      Ok(value) => value
      Err(diagnostic) => return Err(diagnostic)
    }
    output.push({ name, choices, default_value, boolean, })
  }
  Ok(output)
}

///|
fn decode_recipe_compounds(
  value : Json,
) -> Result[Array[@ir.RecipeCompound], @core.Diagnostic] {
  guard value is Array(items) else {
    return Err(
      bundle_diagnostic(
        "STYLE_BUNDLE_RECIPE", "Recipe compounds must be an array",
      ),
    )
  }
  let output : Array[@ir.RecipeCompound] = []
  for item in items {
    guard item is Object(object) &&
      exact_fields(object, ["matches", "rules"]) &&
      object.get("matches") is Some(Array(match_values)) &&
      object.get("rules") is Some(rule_value) else {
      return Err(
        bundle_diagnostic(
          "STYLE_BUNDLE_RECIPE", "Recipe compound has invalid or unknown fields",
        ),
      )
    }
    let matches : Array[@ir.RecipeVariantMatch] = []
    for match_value in match_values {
      guard match_value is Object(match_object) &&
        exact_fields(match_object, ["axis", "value"]) &&
        match_object.get("axis") is Some(String(axis)) &&
        match_object.get("value") is Some(String(selected_value)) else {
        return Err(
          bundle_diagnostic(
            "STYLE_BUNDLE_RECIPE", "Recipe compound match has invalid or unknown fields",
          ),
        )
      }
      matches.push({ axis, value: selected_value, })
    }
    let rules = match decode_string_array(rule_value, "Recipe compound rules") {
      Ok(value) => value
      Err(diagnostic) => return Err(diagnostic)
    }
    output.push({ matches, rules, })
  }
  Ok(output)
}

///|
fn decode_recipes(
  value : Json,
) -> Result[Array[BundleRecipe], @core.Diagnostic] {
  guard value is Array(items) else {
    return Err(
      bundle_diagnostic("STYLE_BUNDLE_TYPE", "Bundle recipes must be an array"),
    )
  }
  let output : Array[BundleRecipe] = []
  for item in items {
    guard item is Object(object) &&
      exact_fields(object, [
        "module", "mappingsPackage", "name", "base", "variants", "compounds", "contract",
      ]) &&
      object.get("module") is Some(String(module_name)) &&
      object.get("mappingsPackage") is Some(String(mappings_package)) &&
      object.get("name") is Some(String(name)) &&
      object.get("base") is Some(base_value) &&
      object.get("variants") is Some(variant_value) &&
      object.get("compounds") is Some(compound_value) &&
      object.get("contract") is Some(contract_value) else {
      return Err(
        bundle_diagnostic(
          "STYLE_BUNDLE_RECIPE", "Recipe has invalid or unknown fields",
        ),
      )
    }
    let base = match decode_string_array(base_value, "Recipe base") {
      Ok(value) => value
      Err(diagnostic) => return Err(diagnostic)
    }
    let variants = match decode_recipe_axes(variant_value) {
      Ok(value) => value
      Err(diagnostic) => return Err(diagnostic)
    }
    let compounds = match decode_recipe_compounds(compound_value) {
      Ok(value) => value
      Err(diagnostic) => return Err(diagnostic)
    }
    let contract = match contract_value {
      String(value) => Some(value)
      Null => None
      _ =>
        return Err(
          bundle_diagnostic(
            "STYLE_BUNDLE_RECIPE", "Recipe contract must be a string or null",
          ),
        )
    }
    output.push({
      module_name,
      mappings_package,
      recipe: { name, base, variants, compounds, contract, },
    })
  }
  Ok(output)
}

///|
fn decode_markers(
  value : Json,
) -> Result[Array[BundleMarker], @core.Diagnostic] {
  guard value is Array(items) else {
    return Err(
      bundle_diagnostic("STYLE_BUNDLE_TYPE", "Bundle markers must be an array"),
    )
  }
  let output : Array[BundleMarker] = []
  for item in items {
    guard item is Object(object) &&
      exact_fields(object, ["module", "mappingsPackage", "name", "className"]) &&
      object.get("module") is Some(String(module_name)) &&
      object.get("mappingsPackage") is Some(String(mappings_package)) &&
      object.get("name") is Some(String(name)) &&
      object.get("className") is Some(String(class_name)) else {
      return Err(
        bundle_diagnostic(
          "STYLE_BUNDLE_MARKER", "Marker has invalid or unknown fields",
        ),
      )
    }
    output.push({ module_name, mappings_package, name, class_name, })
  }
  Ok(output)
}

///|
fn decode_view_transition_classes(
  value : Json,
) -> Result[Array[BundleViewTransitionClass], @core.Diagnostic] {
  guard value is Array(items) else {
    return Err(
      bundle_diagnostic(
        "STYLE_BUNDLE_TYPE", "Bundle view-transition classes must be an array",
      ),
    )
  }
  let output : Array[BundleViewTransitionClass] = []
  for item in items {
    guard item is Object(object) &&
      exact_fields(object, [
        "module", "mappingsPackage", "name", "cssName", "styles",
      ]) &&
      object.get("module") is Some(String(module_name)) &&
      object.get("mappingsPackage") is Some(String(mappings_package)) &&
      object.get("name") is Some(String(name)) &&
      object.get("cssName") is Some(String(css_name)) &&
      object.get("styles") is Some(styles_value) else {
      return Err(
        bundle_diagnostic(
          "STYLE_BUNDLE_VIEW_TRANSITION", "View-transition class has invalid or unknown fields",
        ),
      )
    }
    let styles = match decode_view_transition_blocks(styles_value) {
      Ok(styles) => styles
      Err(diagnostic) => return Err(diagnostic)
    }
    output.push({ module_name, mappings_package, name, css_name, styles, })
  }
  Ok(output)
}

///|
fn dependency_json(value : BundleDependency) -> Json {
  { "module": value.module_name, "semanticDigest": value.semantic_digest }
}

///|
fn namespace_json_v3(value : BundleNamespace) -> Json {
  let entries : Array[Json] = value.entries.map(entry => {
    [
      Json(entry.0),
      match entry.1 {
        Some(class_name) => Json(class_name)
        None => Json::null()
      },
    ]
  })
  { "name": value.name, "entries": entries }
}

///|
fn contract_json(value : BundleContract) -> Json {
  {
    "module": value.module_name,
    "name": value.name,
    "mappingsPackage": value.mappings_package,
    "trait": value.trait_name,
    "properties": value.properties.map(contract_property_json),
  }
}

///|
fn contract_json_v6(value : BundleContractV6) -> Json {
  {
    "module": value.module_name,
    "name": value.name,
    "mappingsPackage": value.mappings_package,
    "trait": value.trait_name,
    "properties": value.properties,
  }
}

///|
fn rule_json_v3(value : BundleRule) -> Json {
  {
    "property": value.property,
    "className": value.class_name,
    "ltr": value.ltr,
    "rtl": match value.rtl {
      Some(rtl) => Json(rtl)
      None => Json::null()
    },
    "priority": value.priority100 / @core.application_order_priority_scale,
  }
}

///|
fn bundle_rule_json(value : BundleRule) -> Json {
  {
    "property": value.property,
    "className": value.class_name,
    "ltr": value.ltr,
    "rtl": match value.rtl {
      Some(rtl) => Json(rtl)
      None => Json::null()
    },
    "priority100": value.priority100,
  }
}

///|
fn global_json_v3(value : BundleGlobal) -> Json {
  {
    "kind": value.kind,
    "name": value.name,
    "css": value.css,
    "digest": value.digest,
  }
}

///|
fn recipe_choice_json(value : @ir.RecipeVariantChoice) -> Json {
  { "value": value.value, "rules": value.rules }
}

///|
fn recipe_axis_json(value : @ir.RecipeVariantAxis) -> Json {
  {
    "name": value.name,
    "boolean": value.boolean,
    "default": match value.default_value {
      Some(default_value) => Json(default_value)
      None => Json::null()
    },
    "choices": value.choices.map(recipe_choice_json),
  }
}

///|
fn recipe_match_json(value : @ir.RecipeVariantMatch) -> Json {
  { "axis": value.axis, "value": value.value }
}

///|
fn recipe_compound_json(value : @ir.RecipeCompound) -> Json {
  { "matches": value.matches.map(recipe_match_json), "rules": value.rules }
}

///|
fn recipe_json(value : BundleRecipe) -> Json {
  {
    "module": value.module_name,
    "mappingsPackage": value.mappings_package,
    "name": value.recipe.name,
    "base": value.recipe.base,
    "variants": value.recipe.variants.map(recipe_axis_json),
    "compounds": value.recipe.compounds.map(recipe_compound_json),
    "contract": match value.recipe.contract {
      Some(contract) => Json(contract)
      None => Json::null()
    },
  }
}

///|
fn marker_json(value : BundleMarker) -> Json {
  {
    "module": value.module_name,
    "mappingsPackage": value.mappings_package,
    "name": value.name,
    "className": value.class_name,
  }
}

///|
fn view_transition_class_json(value : BundleViewTransitionClass) -> Json {
  {
    "module": value.module_name,
    "mappingsPackage": value.mappings_package,
    "name": value.name,
    "cssName": value.css_name,
    "styles": value.styles.map(view_transition_block_json),
  }
}

///|
fn semantic_json(bundle : DependencyBundle) -> Json {
  {
    "schemaVersion": 14,
    "module": bundle.module_name,
    "mappingsPackage": bundle.mappings_package,
    "semantics": bundle_semantics_json(),
    "directDependencies": bundle.direct_dependencies.map(dependency_json),
    "dependencyClosure": bundle.dependency_closure.map(dependency_json),
    "contracts": bundle.contracts.map(contract_json),
    "namespaces": bundle.namespaces.map(namespace_json_v3),
    "rules": bundle.rules.map(bundle_rule_json),
    "globals": bundle.globals.map(global_json_v3),
    "recipes": bundle.recipes.map(recipe_json),
    "markers": bundle.markers.map(marker_json),
    "viewTransitionClasses": bundle.view_transition_classes.map(
      view_transition_class_json,
    ),
  }
}

///|
fn semantic_json_v8_bundle(bundle : DependencyBundle) -> Json {
  {
    "schemaVersion": 8,
    "module": bundle.module_name,
    "mappingsPackage": bundle.mappings_package,
    "semantics": bundle_semantics_json(),
    "directDependencies": bundle.direct_dependencies.map(dependency_json),
    "dependencyClosure": bundle.dependency_closure.map(dependency_json),
    "contracts": bundle.contracts.map(contract_json),
    "namespaces": bundle.namespaces.map(namespace_json_v3),
    "rules": bundle.rules.map(rule_json_v3),
    "globals": bundle.globals.map(global_json_v3),
    "recipes": bundle.recipes.map(recipe_json),
    "markers": bundle.markers.map(marker_json),
    "viewTransitionClasses": bundle.view_transition_classes.map(
      view_transition_class_json,
    ),
  }
}

///|
fn semantic_json_v7_bundle(bundle : DependencyBundle) -> Json {
  {
    "schemaVersion": 7,
    "module": bundle.module_name,
    "mappingsPackage": bundle.mappings_package,
    "semantics": bundle_semantics_json(),
    "directDependencies": bundle.direct_dependencies.map(dependency_json),
    "dependencyClosure": bundle.dependency_closure.map(dependency_json),
    "contracts": bundle.contracts.map(contract_json),
    "namespaces": bundle.namespaces.map(namespace_json_v3),
    "rules": bundle.rules.map(rule_json_v3),
    "globals": bundle.globals.map(global_json_v3),
  }
}

///|
fn semantic_json_v5(
  module_name : String,
  direct_dependencies : Array[BundleDependency],
  dependency_closure : Array[BundleDependency],
  namespaces : Array[BundleNamespace],
  rules : Array[BundleRule],
  globals : Array[BundleGlobal],
) -> Json {
  {
    "schemaVersion": 5,
    "module": module_name,
    "semantics": bundle_semantics_json(),
    "directDependencies": direct_dependencies.map(dependency_json),
    "dependencyClosure": dependency_closure.map(dependency_json),
    "namespaces": namespaces.map(namespace_json_v3),
    "rules": rules.map(rule_json_v3),
    "globals": globals.map(global_json_v3),
  }
}

///|
fn semantic_json_v6(
  module_name : String,
  mappings_package : String,
  direct_dependencies : Array[BundleDependency],
  dependency_closure : Array[BundleDependency],
  contracts : Array[BundleContractV6],
  namespaces : Array[BundleNamespace],
  rules : Array[BundleRule],
  globals : Array[BundleGlobal],
) -> Json {
  {
    "schemaVersion": 6,
    "module": module_name,
    "mappingsPackage": mappings_package,
    "semantics": bundle_semantics_json(),
    "directDependencies": direct_dependencies.map(dependency_json),
    "dependencyClosure": dependency_closure.map(dependency_json),
    "contracts": contracts.map(contract_json_v6),
    "namespaces": namespaces.map(namespace_json_v3),
    "rules": rules.map(rule_json_v3),
    "globals": globals.map(global_json_v3),
  }
}

///|
fn render_bundle_manifest_v5(
  module_name : String,
  semantic_digest : String,
  direct_dependencies : Array[BundleDependency],
  dependency_closure : Array[BundleDependency],
  namespaces : Array[BundleNamespace],
  rules : Array[BundleRule],
  globals : Array[BundleGlobal],
) -> String {
  let manifest : Json = {
    "schemaVersion": 5,
    "module": module_name,
    "semanticDigest": semantic_digest,
    "semantics": bundle_semantics_json(),
    "directDependencies": direct_dependencies.map(dependency_json),
    "dependencyClosure": dependency_closure.map(dependency_json),
    "namespaces": namespaces.map(namespace_json_v3),
    "rules": rules.map(rule_json_v3),
    "globals": globals.map(global_json_v3),
  }
  manifest.stringify() + "\n"
}

///|
fn render_bundle_manifest_v6(
  module_name : String,
  mappings_package : String,
  semantic_digest : String,
  direct_dependencies : Array[BundleDependency],
  dependency_closure : Array[BundleDependency],
  contracts : Array[BundleContractV6],
  namespaces : Array[BundleNamespace],
  rules : Array[BundleRule],
  globals : Array[BundleGlobal],
) -> String {
  let manifest : Json = {
    "schemaVersion": 6,
    "module": module_name,
    "mappingsPackage": mappings_package,
    "semanticDigest": semantic_digest,
    "semantics": bundle_semantics_json(),
    "directDependencies": direct_dependencies.map(dependency_json),
    "dependencyClosure": dependency_closure.map(dependency_json),
    "contracts": contracts.map(contract_json_v6),
    "namespaces": namespaces.map(namespace_json_v3),
    "rules": rules.map(rule_json_v3),
    "globals": globals.map(global_json_v3),
  }
  manifest.stringify() + "\n"
}

///|
fn render_bundle_manifest(bundle : DependencyBundle) -> String {
  let manifest : Json = {
    "schemaVersion": 14,
    "module": bundle.module_name,
    "mappingsPackage": bundle.mappings_package,
    "semanticDigest": bundle.semantic_digest,
    "semantics": bundle_semantics_json(),
    "directDependencies": bundle.direct_dependencies.map(dependency_json),
    "dependencyClosure": bundle.dependency_closure.map(dependency_json),
    "contracts": bundle.contracts.map(contract_json),
    "namespaces": bundle.namespaces.map(namespace_json_v3),
    "rules": bundle.rules.map(bundle_rule_json),
    "globals": bundle.globals.map(global_json_v3),
    "recipes": bundle.recipes.map(recipe_json),
    "markers": bundle.markers.map(marker_json),
    "viewTransitionClasses": bundle.view_transition_classes.map(
      view_transition_class_json,
    ),
  }
  manifest.stringify() + "\n"
}

///|
fn render_bundle_manifest_v8(bundle : DependencyBundle) -> String {
  let manifest : Json = {
    "schemaVersion": 8,
    "module": bundle.module_name,
    "mappingsPackage": bundle.mappings_package,
    "semanticDigest": bundle.semantic_digest,
    "semantics": bundle_semantics_json(),
    "directDependencies": bundle.direct_dependencies.map(dependency_json),
    "dependencyClosure": bundle.dependency_closure.map(dependency_json),
    "contracts": bundle.contracts.map(contract_json),
    "namespaces": bundle.namespaces.map(namespace_json_v3),
    "rules": bundle.rules.map(rule_json_v3),
    "globals": bundle.globals.map(global_json_v3),
    "recipes": bundle.recipes.map(recipe_json),
    "markers": bundle.markers.map(marker_json),
    "viewTransitionClasses": bundle.view_transition_classes.map(
      view_transition_class_json,
    ),
  }
  manifest.stringify() + "\n"
}

///|
fn render_bundle_manifest_v7(bundle : DependencyBundle) -> String {
  let manifest : Json = {
    "schemaVersion": 7,
    "module": bundle.module_name,
    "mappingsPackage": bundle.mappings_package,
    "semanticDigest": bundle.semantic_digest,
    "semantics": bundle_semantics_json(),
    "directDependencies": bundle.direct_dependencies.map(dependency_json),
    "dependencyClosure": bundle.dependency_closure.map(dependency_json),
    "contracts": bundle.contracts.map(contract_json),
    "namespaces": bundle.namespaces.map(namespace_json_v3),
    "rules": bundle.rules.map(rule_json_v3),
    "globals": bundle.globals.map(global_json_v3),
  }
  manifest.stringify() + "\n"
}

///|
pub fn decode_bundle(
  input : String,
) -> Result[DependencyBundle, Array[@core.Diagnostic]] {
  let value = @json.parse(input) catch {
    _ =>
      return Err([
        bundle_diagnostic(
          "STYLE_BUNDLE_JSON", "Dependency bundle is not valid JSON",
        ),
      ])
  }
  guard value is Object(object) &&
    exact_fields(object, [
      "schemaVersion", "module", "mappingsPackage", "semanticDigest", "semantics",
      "directDependencies", "dependencyClosure", "contracts", "namespaces", "rules",
      "globals", "recipes", "markers", "viewTransitionClasses",
    ]) &&
    object.get("schemaVersion") is Some(Number(version, ..)) &&
    object.get("module") is Some(String(module_name)) &&
    object.get("mappingsPackage") is Some(String(mappings_package)) &&
    object.get("semanticDigest") is Some(String(digest)) &&
    object.get("semantics") is Some(semantics_value) &&
    object.get("directDependencies") is Some(direct_dependency_value) &&
    object.get("dependencyClosure") is Some(dependency_closure_value) &&
    object.get("contracts") is Some(contract_value) &&
    object.get("namespaces") is Some(namespace_value) &&
    object.get("rules") is Some(rule_value) &&
    object.get("globals") is Some(global_value) &&
    object.get("recipes") is Some(recipe_value) &&
    object.get("markers") is Some(marker_value) &&
    object.get("viewTransitionClasses") is Some(view_transition_value) else {
    return Err([
      bundle_diagnostic(
        "STYLE_BUNDLE_SHAPE", "Dependency bundle has missing, invalid, or unknown top-level fields",
      ),
    ])
  }
  if version != 14.0 {
    return Err([
      bundle_diagnostic(
        "STYLE_BUNDLE_SCHEMA", "Dependency bundle schemaVersion must be 14; re-extract dependencies from source before the application",
      ),
    ])
  }
  match decode_bundle_semantics(semantics_value) {
    Ok(_) => ()
    Err(diagnostic) => return Err([diagnostic])
  }
  let direct_dependencies = match decode_dependencies(direct_dependency_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let dependency_closure = match decode_dependencies(dependency_closure_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let contracts = match decode_contracts(contract_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let namespaces = match decode_namespaces(namespace_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let rules = match decode_rules(rule_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let globals = match decode_globals(global_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let recipes = match decode_recipes(recipe_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let markers = match decode_markers(marker_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let view_transition_classes = match
    decode_view_transition_classes(view_transition_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  Ok({
    module_name,
    mappings_package,
    semantic_digest: digest,
    direct_dependencies,
    dependency_closure,
    contracts,
    namespaces,
    rules,
    globals,
    recipes,
    markers,
    view_transition_classes,
  })
}

///|
fn migration_diagnostic(message : String) -> @core.Diagnostic {
  bundle_diagnostic("STYLE_MIGRATION_REEXTRACT_REQUIRED", message)
}

///|
fn migrated_dependency_by_module(
  bundles : Array[DependencyBundle],
  module_name : String,
) -> DependencyBundle? {
  for bundle in bundles {
    if bundle.module_name == module_name {
      return Some(bundle)
    }
  }
  None
}

///|
pub fn migrate_v4_to_v5(
  input : String,
  migrated_dependencies : Array[DependencyBundle],
) -> Result[String, Array[@core.Diagnostic]] {
  let value = @json.parse(input) catch {
    _ =>
      return Err([
        bundle_diagnostic("STYLE_ARTIFACT_JSON", "Artifact is not valid JSON"),
      ])
  }
  guard value is Object(object) &&
    exact_fields(object, [
      "schemaVersion", "module", "semanticDigest", "directDependencies", "dependencyClosure",
      "namespaces", "rules", "globals",
    ]) &&
    object.get("schemaVersion") is Some(Number(version, ..)) &&
    version == 4.0 &&
    object.get("module") is Some(String(module_name)) &&
    object.get("semanticDigest") is Some(String(old_digest)) &&
    object.get("directDependencies") is Some(direct_value) &&
    object.get("dependencyClosure") is Some(closure_value) &&
    object.get("namespaces") is Some(namespace_value) &&
    object.get("rules") is Some(rule_value) &&
    object.get("globals") is Some(global_value) else {
    return Err([
      bundle_diagnostic(
        "STYLE_ARTIFACT_SCHEMA", "Explicit v4-to-v5 migration requires a complete artifact schema v4",
      ),
    ])
  }
  let old_direct = match decode_dependencies(direct_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let old_closure = match decode_dependencies(closure_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let namespaces = match decode_namespaces(namespace_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let rules = match decode_legacy_rules(rule_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let globals = match decode_globals(global_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let old_semantic : Json = {
    "schemaVersion": 4,
    "module": module_name,
    "directDependencies": old_direct.map(dependency_json),
    "dependencyClosure": old_closure.map(dependency_json),
    "namespaces": namespaces.map(namespace_json_v3),
    "rules": rules.map(rule_json_v3),
    "globals": globals.map(global_json_v3),
  }
  if old_digest != semantic_digest(old_semantic.stringify()) {
    return Err([
      bundle_diagnostic(
        "STYLE_ARTIFACT_DIGEST", "Schema v4 semantic digest does not match its canonical content",
      ),
    ])
  }

  for rule in rules {
    if rule.rtl is Some(_) ||
      !rule.ltr.has_prefix("." + rule.class_name + "{") ||
      rule.priority100 != @core.application_order_priority100(rule.property) ||
      !@core.application_order_migration_safe(rule.property) {
      return Err([
        migration_diagnostic(
          "Schema v4 rule " +
          rule.property +
          " lost application-order information and must be re-extracted",
        ),
      ])
    }
  }

  let migrated_namespaces : Array[BundleNamespace] = []
  for namespace_ in namespaces {
    let entries : Array[(String, String?)] = []
    for entry in namespace_.entries {
      match entry.1 {
        None =>
          return Err([
            migration_diagnostic(
              "Schema v4 tombstones cannot be assigned to the v5 conflict graph",
            ),
          ])
        Some(class_name) => {
          let matching = rules.filter(rule => rule.class_name == class_name)
          if matching.is_empty() && entry.0.has_prefix("theme|") {
            entries.push(entry)
            continue
          }
          if matching.length() != 1 ||
            entry.0.contains("|") ||
            entry.0 != matching[0].property {
            return Err([
              migration_diagnostic(
                "Schema v4 namespace entries are not unconditioned self-conflicts",
              ),
            ])
          }
          let operations = @core.application_order_entries(matching[0].property)
          if operations.length() != 1 || !operations[0].1 {
            return Err([
              migration_diagnostic(
                "Schema v4 property " +
                matching[0].property +
                " requires conflict-graph re-extraction",
              ),
            ])
          }
          entries.push((operations[0].0, Some(class_name)))
        }
      }
    }
    migrated_namespaces.push({ name: namespace_.name, entries, })
  }

  let provided_modules : Array[String] = []
  for dependency in migrated_dependencies {
    if provided_modules.contains(dependency.module_name) ||
      !validate_bundle(dependency).is_empty() {
      return Err([
        migration_diagnostic(
          "Migrated dependencies must be unique, valid schema v14 bundles",
        ),
      ])
    }
    provided_modules.push(dependency.module_name)
  }
  if migrated_dependencies.length() != old_closure.length() {
    return Err([
      migration_diagnostic(
        "Migrate the complete dependency closure bottom-up before migrating this bundle",
      ),
    ])
  }
  let dependency_closure : Array[BundleDependency] = []
  for old_dependency in old_closure {
    match
      migrated_dependency_by_module(
        migrated_dependencies,
        old_dependency.module_name,
      ) {
      Some(dependency) =>
        dependency_closure.push({
          module_name: dependency.module_name,
          semantic_digest: dependency.semantic_digest,
        })
      None =>
        return Err([
          migration_diagnostic(
            "Missing migrated dependency " + old_dependency.module_name,
          ),
        ])
    }
  }
  let direct_dependencies : Array[BundleDependency] = []
  for old_dependency in old_direct {
    match
      migrated_dependency_by_module(
        migrated_dependencies,
        old_dependency.module_name,
      ) {
      Some(dependency) =>
        direct_dependencies.push({
          module_name: dependency.module_name,
          semantic_digest: dependency.semantic_digest,
        })
      None =>
        return Err([
          migration_diagnostic(
            "Missing migrated direct dependency " + old_dependency.module_name,
          ),
        ])
    }
  }
  let migrated_semantic = semantic_json_v5(
    module_name, direct_dependencies, dependency_closure, migrated_namespaces, rules,
    globals,
  )
  Ok(
    render_bundle_manifest_v5(
      module_name,
      semantic_digest(migrated_semantic.stringify()),
      direct_dependencies,
      dependency_closure,
      migrated_namespaces,
      rules,
      globals,
    ),
  )
}

///|
pub fn migrate_v5_to_v6(
  input : String,
  mappings_package : String,
  migrated_dependencies : Array[DependencyBundle],
) -> Result[String, Array[@core.Diagnostic]] {
  let value = @json.parse(input) catch {
    _ =>
      return Err([
        bundle_diagnostic("STYLE_ARTIFACT_JSON", "Artifact is not valid JSON"),
      ])
  }
  guard value is Object(object) &&
    exact_fields(object, [
      "schemaVersion", "module", "semanticDigest", "semantics", "directDependencies",
      "dependencyClosure", "namespaces", "rules", "globals",
    ]) &&
    object.get("schemaVersion") is Some(Number(version, ..)) &&
    version == 5.0 &&
    object.get("module") is Some(String(module_name)) &&
    object.get("semanticDigest") is Some(String(old_digest)) &&
    object.get("semantics") is Some(semantics_value) &&
    object.get("directDependencies") is Some(direct_value) &&
    object.get("dependencyClosure") is Some(closure_value) &&
    object.get("namespaces") is Some(namespace_value) &&
    object.get("rules") is Some(rule_value) &&
    object.get("globals") is Some(global_value) else {
    return Err([
      bundle_diagnostic(
        "STYLE_ARTIFACT_SCHEMA", "Explicit v5-to-v6 migration requires a complete artifact schema v5",
      ),
    ])
  }
  if !mappings_package_valid(mappings_package) {
    return Err([
      bundle_diagnostic(
        "STYLE_MIGRATION_MAPPINGS_PACKAGE", "Schema v5-to-v6 migration requires the generated MoonBit mappings package name",
      ),
    ])
  }
  match decode_bundle_semantics(semantics_value) {
    Ok(_) => ()
    Err(diagnostic) => return Err([diagnostic])
  }
  let old_direct = match decode_dependencies(direct_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let old_closure = match decode_dependencies(closure_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let namespaces = match decode_namespaces(namespace_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let rules = match decode_legacy_rules(rule_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let globals = match decode_globals(global_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let old_semantic = semantic_json_v5(
    module_name, old_direct, old_closure, namespaces, rules, globals,
  )
  if old_digest != semantic_digest(old_semantic.stringify()) {
    return Err([
      bundle_diagnostic(
        "STYLE_ARTIFACT_DIGEST", "Schema v5 semantic digest does not match its canonical content",
      ),
    ])
  }

  let provided_modules : Array[String] = []
  for dependency in migrated_dependencies {
    if provided_modules.contains(dependency.module_name) ||
      !validate_bundle(dependency).is_empty() {
      return Err([
        migration_diagnostic(
          "Migrated dependencies must be unique, valid schema v14 bundles",
        ),
      ])
    }
    provided_modules.push(dependency.module_name)
  }
  if migrated_dependencies.length() != old_closure.length() {
    return Err([
      migration_diagnostic(
        "Migrate the complete dependency closure bottom-up before migrating this bundle",
      ),
    ])
  }
  let dependency_closure : Array[BundleDependency] = []
  for old_dependency in old_closure {
    match
      migrated_dependency_by_module(
        migrated_dependencies,
        old_dependency.module_name,
      ) {
      Some(dependency) =>
        dependency_closure.push({
          module_name: dependency.module_name,
          semantic_digest: dependency.semantic_digest,
        })
      None =>
        return Err([
          migration_diagnostic(
            "Missing migrated dependency " + old_dependency.module_name,
          ),
        ])
    }
  }
  let direct_dependencies : Array[BundleDependency] = []
  for old_dependency in old_direct {
    match
      migrated_dependency_by_module(
        migrated_dependencies,
        old_dependency.module_name,
      ) {
      Some(dependency) =>
        direct_dependencies.push({
          module_name: dependency.module_name,
          semantic_digest: dependency.semantic_digest,
        })
      None =>
        return Err([
          migration_diagnostic(
            "Missing migrated direct dependency " + old_dependency.module_name,
          ),
        ])
    }
  }
  let contracts : Array[BundleContractV6] = []
  let migrated_semantic = semantic_json_v6(
    module_name, mappings_package, direct_dependencies, dependency_closure, contracts,
    namespaces, rules, globals,
  )
  Ok(
    render_bundle_manifest_v6(
      module_name,
      mappings_package,
      semantic_digest(migrated_semantic.stringify()),
      direct_dependencies,
      dependency_closure,
      contracts,
      namespaces,
      rules,
      globals,
    ),
  )
}

///|
/// Migrates schema-v6 property-only contracts to schema v7. Every legacy
/// property becomes an explicit AnySafe policy; no value restriction is
/// invented during migration.
pub fn migrate_v6_to_v7(
  input : String,
  migrated_dependencies : Array[DependencyBundle],
) -> Result[String, Array[@core.Diagnostic]] {
  let value = @json.parse(input) catch {
    _ =>
      return Err([
        bundle_diagnostic("STYLE_ARTIFACT_JSON", "Artifact is not valid JSON"),
      ])
  }
  guard value is Object(object) &&
    exact_fields(object, [
      "schemaVersion", "module", "mappingsPackage", "semanticDigest", "semantics",
      "directDependencies", "dependencyClosure", "contracts", "namespaces", "rules",
      "globals",
    ]) &&
    object.get("schemaVersion") is Some(Number(version, ..)) &&
    version == 6.0 &&
    object.get("module") is Some(String(module_name)) &&
    object.get("mappingsPackage") is Some(String(mappings_package)) &&
    object.get("semanticDigest") is Some(String(old_digest)) &&
    object.get("semantics") is Some(semantics_value) &&
    object.get("directDependencies") is Some(direct_value) &&
    object.get("dependencyClosure") is Some(closure_value) &&
    object.get("contracts") is Some(contract_value) &&
    object.get("namespaces") is Some(namespace_value) &&
    object.get("rules") is Some(rule_value) &&
    object.get("globals") is Some(global_value) else {
    return Err([
      bundle_diagnostic(
        "STYLE_ARTIFACT_SCHEMA", "Explicit v6-to-v7 migration requires a complete artifact schema v6",
      ),
    ])
  }
  match decode_bundle_semantics(semantics_value) {
    Ok(_) => ()
    Err(diagnostic) => return Err([diagnostic])
  }
  let old_direct = match decode_dependencies(direct_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let old_closure = match decode_dependencies(closure_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let old_contracts = match decode_contracts_v6(contract_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let namespaces = match decode_namespaces(namespace_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let rules = match decode_legacy_rules(rule_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let globals = match decode_globals(global_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let old_semantic = semantic_json_v6(
    module_name, mappings_package, old_direct, old_closure, old_contracts, namespaces,
    rules, globals,
  )
  if old_digest != semantic_digest(old_semantic.stringify()) {
    return Err([
      bundle_diagnostic(
        "STYLE_ARTIFACT_DIGEST", "Schema v6 semantic digest does not match its canonical content",
      ),
    ])
  }

  let provided_modules : Array[String] = []
  for dependency in migrated_dependencies {
    if provided_modules.contains(dependency.module_name) ||
      !validate_bundle(dependency).is_empty() {
      return Err([
        migration_diagnostic(
          "Migrated dependencies must be unique, valid schema v14 bundles",
        ),
      ])
    }
    provided_modules.push(dependency.module_name)
  }
  if migrated_dependencies.length() != old_closure.length() {
    return Err([
      migration_diagnostic(
        "Migrate the complete dependency closure bottom-up before migrating this bundle",
      ),
    ])
  }
  let dependency_closure : Array[BundleDependency] = []
  for old_dependency in old_closure {
    match
      migrated_dependency_by_module(
        migrated_dependencies,
        old_dependency.module_name,
      ) {
      Some(dependency) =>
        dependency_closure.push({
          module_name: dependency.module_name,
          semantic_digest: dependency.semantic_digest,
        })
      None =>
        return Err([
          migration_diagnostic(
            "Missing migrated dependency " + old_dependency.module_name,
          ),
        ])
    }
  }
  let direct_dependencies : Array[BundleDependency] = []
  for old_dependency in old_direct {
    match
      migrated_dependency_by_module(
        migrated_dependencies,
        old_dependency.module_name,
      ) {
      Some(dependency) =>
        direct_dependencies.push({
          module_name: dependency.module_name,
          semantic_digest: dependency.semantic_digest,
        })
      None =>
        return Err([
          migration_diagnostic(
            "Missing migrated direct dependency " + old_dependency.module_name,
          ),
        ])
    }
  }
  let contracts : Array[BundleContract] = old_contracts.map(contract => {
    module_name: contract.module_name,
    name: contract.name,
    mappings_package: contract.mappings_package,
    trait_name: contract.trait_name,
    properties: contract.properties.map(@ir.any_contract_property),
  })
  let mut migrated : DependencyBundle = {
    module_name,
    mappings_package,
    semantic_digest: "",
    direct_dependencies,
    dependency_closure,
    contracts,
    namespaces,
    rules,
    globals,
    recipes: [],
    markers: [],
    view_transition_classes: [],
  }
  migrated = {
    ..migrated,
    semantic_digest: semantic_digest(
      semantic_json_v7_bundle(migrated).stringify(),
    ),
  }
  Ok(render_bundle_manifest_v7(migrated))
}

///|
/// Migrates the final legacy bundle shape to schema v8. Schema v7 predates
/// recipes, selector markers, and view-transition class records, so those
/// collections are initialized empty. Dependency identities are replaced
/// bottom-up with the supplied migrated v8 bundles.
pub fn migrate_v7_to_v8(
  input : String,
  migrated_dependencies : Array[DependencyBundle],
) -> Result[String, Array[@core.Diagnostic]] {
  let value = @json.parse(input) catch {
    _ =>
      return Err([
        bundle_diagnostic("STYLE_ARTIFACT_JSON", "Artifact is not valid JSON"),
      ])
  }
  guard value is Object(object) &&
    exact_fields(object, [
      "schemaVersion", "module", "mappingsPackage", "semanticDigest", "semantics",
      "directDependencies", "dependencyClosure", "contracts", "namespaces", "rules",
      "globals",
    ]) &&
    object.get("schemaVersion") is Some(Number(version, ..)) &&
    version == 7.0 &&
    object.get("module") is Some(String(module_name)) &&
    object.get("mappingsPackage") is Some(String(mappings_package)) &&
    object.get("semanticDigest") is Some(String(old_digest)) &&
    object.get("semantics") is Some(semantics_value) &&
    object.get("directDependencies") is Some(direct_value) &&
    object.get("dependencyClosure") is Some(closure_value) &&
    object.get("contracts") is Some(contract_value) &&
    object.get("namespaces") is Some(namespace_value) &&
    object.get("rules") is Some(rule_value) &&
    object.get("globals") is Some(global_value) else {
    return Err([
      bundle_diagnostic(
        "STYLE_ARTIFACT_SCHEMA", "Explicit v7-to-v8 migration requires a complete artifact schema v7",
      ),
    ])
  }
  match decode_bundle_semantics(semantics_value) {
    Ok(_) => ()
    Err(diagnostic) => return Err([diagnostic])
  }
  let old_direct = match decode_dependencies(direct_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let old_closure = match decode_dependencies(closure_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let contracts = match decode_contracts(contract_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let namespaces = match decode_namespaces(namespace_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let rules = match decode_legacy_rules(rule_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let globals = match decode_globals(global_value) {
    Ok(value) => value
    Err(diagnostic) => return Err([diagnostic])
  }
  let legacy : DependencyBundle = {
    module_name,
    mappings_package,
    semantic_digest: old_digest,
    direct_dependencies: old_direct,
    dependency_closure: old_closure,
    contracts,
    namespaces,
    rules,
    globals,
    recipes: [],
    markers: [],
    view_transition_classes: [],
  }
  if old_digest != semantic_digest(semantic_json_v7_bundle(legacy).stringify()) {
    return Err([
      bundle_diagnostic(
        "STYLE_ARTIFACT_DIGEST", "Schema v7 semantic digest does not match its canonical content",
      ),
    ])
  }
  let provided_modules : Array[String] = []
  for dependency in migrated_dependencies {
    if provided_modules.contains(dependency.module_name) ||
      !validate_bundle(dependency).is_empty() {
      return Err([
        migration_diagnostic(
          "Migrated dependencies must be unique, valid schema v14 bundles",
        ),
      ])
    }
    provided_modules.push(dependency.module_name)
  }
  if migrated_dependencies.length() != old_closure.length() {
    return Err([
      migration_diagnostic(
        "Migrate the complete dependency closure bottom-up before migrating this bundle",
      ),
    ])
  }
  let dependency_closure : Array[BundleDependency] = []
  for dependency in old_closure {
    match
      migrated_dependency_by_module(
        migrated_dependencies,
        dependency.module_name,
      ) {
      Some(migrated) =>
        dependency_closure.push({
          module_name: migrated.module_name,
          semantic_digest: migrated.semantic_digest,
        })
      None =>
        return Err([
          migration_diagnostic(
            "Missing migrated dependency " + dependency.module_name,
          ),
        ])
    }
  }
  let direct_dependencies : Array[BundleDependency] = []
  for dependency in old_direct {
    match
      migrated_dependency_by_module(
        migrated_dependencies,
        dependency.module_name,
      ) {
      Some(migrated) =>
        direct_dependencies.push({
          module_name: migrated.module_name,
          semantic_digest: migrated.semantic_digest,
        })
      None =>
        return Err([
          migration_diagnostic(
            "Missing migrated direct dependency " + dependency.module_name,
          ),
        ])
    }
  }
  let mut migrated : DependencyBundle = {
    ..legacy,
    semantic_digest: "",
    direct_dependencies,
    dependency_closure,
  }
  migrated = {
    ..migrated,
    semantic_digest: semantic_digest(
      semantic_json_v8_bundle(migrated).stringify(),
    ),
  }
  let validation_bundle = {
    ..migrated,
    semantic_digest: semantic_digest(semantic_json(migrated).stringify()),
  }
  let diagnostics = validate_bundle(validation_bundle)
  if !diagnostics.is_empty() {
    return Err(diagnostics)
  }
  Ok(render_bundle_manifest_v8(migrated))
}

///|
pub fn validate_bundle(bundle : DependencyBundle) -> Array[@core.Diagnostic] {
  let diagnostics : Array[@core.Diagnostic] = []
  if bundle.module_name.trim().is_empty() {
    diagnostics.push(
      bundle_diagnostic(
        "STYLE_BUNDLE_MODULE", "Bundle module name must not be empty",
      ),
    )
  }
  if !mappings_package_valid(bundle.mappings_package) {
    diagnostics.push(
      bundle_diagnostic(
        "STYLE_BUNDLE_MAPPINGS_PACKAGE",
        "Bundle mappingsPackage must be a non-reserved MoonBit package path",
        module_name=bundle.module_name,
      ),
    )
  }
  let expected = semantic_digest(semantic_json(bundle).stringify())
  if bundle.semantic_digest != expected {
    diagnostics.push(
      bundle_diagnostic(
        "STYLE_BUNDLE_DIGEST",
        "Bundle semantic digest does not match its canonical content: expected " +
        expected +
        " but received " +
        bundle.semantic_digest,
      ),
    )
  }
  let dependencies : Array[String] = []
  for dependency in bundle.dependency_closure {
    if dependency.module_name == bundle.module_name {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_SELF_DEPENDENCY",
          "Bundle dependency closure must not contain the bundle itself",
          module_name=bundle.module_name,
        ),
      )
    }
    if dependencies.contains(dependency.module_name) {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_DEPENDENCY_DUPLICATE",
          "Bundle dependency closure must be unique by module",
          module_name=bundle.module_name,
        ),
      )
    }
    dependencies.push(dependency.module_name)
  }
  let direct_dependencies : Array[String] = []
  for dependency in bundle.direct_dependencies {
    if dependency.module_name == bundle.module_name {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_SELF_DEPENDENCY",
          "Bundle must not directly depend on itself",
          module_name=bundle.module_name,
        ),
      )
    }
    if direct_dependencies.contains(dependency.module_name) {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_DIRECT_DEPENDENCY_DUPLICATE",
          "Bundle direct dependencies must be unique by module",
          module_name=bundle.module_name,
        ),
      )
    }
    direct_dependencies.push(dependency.module_name)
    if !bundle.dependency_closure.any(item => {
        item.module_name == dependency.module_name &&
        item.semantic_digest == dependency.semantic_digest
      }) {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_CLOSURE_INCOMPLETE",
          "Every direct dependency must occur in dependencyClosure with the same digest",
          module_name=bundle.module_name,
          dependency_chain=[bundle.module_name, dependency.module_name],
        ),
      )
    }
  }
  let contract_identities : Array[String] = []
  let contract_references : Array[String] = []
  let contract_reference_identities : Array[String] = []
  let mut previous_contract = ""
  for contract in bundle.contracts {
    let identity = contract.module_name + ":" + contract.name
    if !previous_contract.is_empty() && previous_contract.compare(identity) >= 0 {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_CONTRACT_ORDER",
          "Bundle contracts must be unique and sorted by module and name",
          module_name=bundle.module_name,
        ),
      )
    }
    previous_contract = identity
    if contract_identities.contains(identity) {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_CONTRACT_DUPLICATE",
          "Bundle contracts must be unique by module and name",
          module_name=bundle.module_name,
        ),
      )
    }
    contract_identities.push(identity)
    let reference = contract.mappings_package + ":" + contract.trait_name
    match contract_references.search_by(candidate => candidate == reference) {
      Some(index) if contract_reference_identities[index] != identity =>
        diagnostics.push(
          bundle_diagnostic(
            "STYLE_BUNDLE_CONTRACT_REFERENCE_COLLISION",
            "Different style contracts resolve to the same generated MoonBit trait: " +
            reference,
            module_name=bundle.module_name,
          ),
        )
      Some(_) => ()
      None => {
        contract_references.push(reference)
        contract_reference_identities.push(identity)
      }
    }
    let owner_visible = contract.module_name == bundle.module_name ||
      bundle.dependency_closure.any(dependency => {
        dependency.module_name == contract.module_name
      })
    if !owner_visible {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_CONTRACT_OWNER",
          "Bundle contract owner is not present in the dependency closure: " +
          contract.module_name,
          module_name=bundle.module_name,
        ),
      )
    }
    if !contract_name_valid(contract.name) ||
      !mappings_package_valid(contract.mappings_package) ||
      contract.trait_name !=
      contract_trait_name(
        @ir.style_contract(contract.name, contract.properties),
      ) {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_CONTRACT",
          "Bundle contract has an invalid name, mappings package, or generated trait",
          module_name=bundle.module_name,
        ),
      )
    }
    if contract.module_name == bundle.module_name &&
      contract.mappings_package != bundle.mappings_package {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_CONTRACT_PACKAGE",
          "Local contracts must use the bundle mappingsPackage",
          module_name=bundle.module_name,
        ),
      )
    }
    if contract.module_name != bundle.module_name &&
      contract.mappings_package == bundle.mappings_package {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_CONTRACT_PACKAGE_COLLISION",
          "An external contract may not share the consumer mappingsPackage",
          module_name=bundle.module_name,
        ),
      )
    }
    let seen_properties : Array[String] = []
    let mut previous_property = ""
    for property in contract.properties {
      if !previous_property.is_empty() &&
        previous_property.compare(property.name) >= 0 {
        diagnostics.push(
          bundle_diagnostic(
            "STYLE_BUNDLE_CONTRACT_PROPERTY_ORDER",
            "Contract properties must be unique and sorted canonically",
            module_name=bundle.module_name,
          ),
        )
      }
      previous_property = property.name
      if seen_properties.contains(property.name) {
        diagnostics.push(
          bundle_diagnostic(
            "STYLE_BUNDLE_CONTRACT_PROPERTY_DUPLICATE",
            "Contract properties must be unique",
            module_name=bundle.module_name,
          ),
        )
      }
      seen_properties.push(property.name)
      if !@core.application_order_properties().contains(property.name) {
        diagnostics.push(
          bundle_diagnostic(
            "STYLE_BUNDLE_CONTRACT_PROPERTY",
            "Contract contains an unknown property: " + property.name,
            module_name=bundle.module_name,
          ),
        )
      }
      match property.policy {
        AnySafe => ()
        Exact(values, tokens, slots, expressions) => {
          let mut previous_expression = ""
          for expression in expressions {
            if !@values.valid_expression_identity(expression) ||
              (
                !previous_expression.is_empty() &&
                previous_expression.compare(expression) >= 0
              ) {
              diagnostics.push(
                bundle_diagnostic(
                  "STYLE_BUNDLE_CONTRACT_EXPRESSION",
                  "Exact expressions must be valid, unique, and sorted",
                  module_name=bundle.module_name,
                ),
              )
            }
            previous_expression = expression
          }
          if values.is_empty() &&
            tokens.is_empty() &&
            slots.is_empty() &&
            expressions.is_empty() {
            diagnostics.push(
              bundle_diagnostic(
                "STYLE_BUNDLE_CONTRACT_POLICY_EMPTY",
                "Exact contract policy must admit at least one value channel",
                module_name=bundle.module_name,
              ),
            )
          }
          let mut previous_value = ""
          for value in values {
            let canonical = @core.canonical_css_value(value)
            if value != canonical ||
              (!previous_value.is_empty() && previous_value.compare(value) >= 0) {
              diagnostics.push(
                bundle_diagnostic(
                  "STYLE_BUNDLE_CONTRACT_VALUE_ORDER",
                  "Exact contract literal values must be canonical, unique, and sorted",
                  module_name=bundle.module_name,
                ),
              )
            }
            previous_value = value
          }
          let mut previous_token : @ir.ContractVariable? = None
          for token in tokens {
            match previous_token {
              Some(previous) if contract_variable_order(previous, token) >= 0 =>
                diagnostics.push(
                  bundle_diagnostic(
                    "STYLE_BUNDLE_CONTRACT_TOKEN_ORDER",
                    "Contract token identities must be unique and sorted canonically",
                    module_name=bundle.module_name,
                  ),
                )
              _ => ()
            }
            if !contract_variable_valid(token) {
              diagnostics.push(
                bundle_diagnostic(
                  "STYLE_BUNDLE_CONTRACT_TOKEN",
                  "Contract contains an invalid token identity",
                  module_name=bundle.module_name,
                ),
              )
            }
            previous_token = Some(token)
          }
          let mut previous_slot : @ir.ContractVariable? = None
          for slot in slots {
            match previous_slot {
              Some(previous) if contract_variable_order(previous, slot) >= 0 =>
                diagnostics.push(
                  bundle_diagnostic(
                    "STYLE_BUNDLE_CONTRACT_SLOT_ORDER",
                    "Contract dynamic-slot identities must be unique and sorted canonically",
                    module_name=bundle.module_name,
                  ),
                )
              _ => ()
            }
            if !contract_variable_valid(slot) {
              diagnostics.push(
                bundle_diagnostic(
                  "STYLE_BUNDLE_CONTRACT_SLOT",
                  "Contract contains an invalid dynamic-slot identity",
                  module_name=bundle.module_name,
                ),
              )
            }
            previous_slot = Some(slot)
          }
        }
      }
    }
  }
  let recipe_identities : Array[String] = []
  let mut previous_recipe = ""
  for record in bundle.recipes {
    let identity = record.module_name + ":" + record.recipe.name
    if !previous_recipe.is_empty() && previous_recipe.compare(identity) >= 0 {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_RECIPE_ORDER",
          "Bundle recipes must be unique and sorted by module and name",
          module_name=bundle.module_name,
        ),
      )
    }
    previous_recipe = identity
    if recipe_identities.contains(identity) {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_RECIPE_DUPLICATE",
          "Bundle recipes must be unique by module and name",
          module_name=bundle.module_name,
        ),
      )
    }
    recipe_identities.push(identity)
    let owner_visible = record.module_name == bundle.module_name ||
      bundle.dependency_closure.any(dependency => {
        dependency.module_name == record.module_name
      })
    if !owner_visible ||
      !contract_name_valid(record.recipe.name) ||
      !mappings_package_valid(record.mappings_package) {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_RECIPE",
          "Bundle recipe has an invalid owner, name, or mappings package",
          module_name=bundle.module_name,
        ),
      )
    }
    if (record.module_name == bundle.module_name) !=
      (record.mappings_package == bundle.mappings_package) {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_RECIPE_PACKAGE",
          "Recipe mappingsPackage must identify exactly its owning module",
          module_name=bundle.module_name,
        ),
      )
    }
    let axes : Array[String] = []
    for axis in record.recipe.variants {
      if !contract_name_valid(axis.name) || axes.contains(axis.name) {
        diagnostics.push(
          bundle_diagnostic(
            "STYLE_BUNDLE_RECIPE_AXIS",
            "Recipe axes must be unique lowercase MoonBit identifiers",
            module_name=bundle.module_name,
          ),
        )
      }
      axes.push(axis.name)
      let choices : Array[String] = []
      for choice in axis.choices {
        if choice.value.is_empty() || choices.contains(choice.value) {
          diagnostics.push(
            bundle_diagnostic(
              "STYLE_BUNDLE_RECIPE_CHOICE",
              "Recipe choices must be non-empty and unique within an axis",
              module_name=bundle.module_name,
            ),
          )
        }
        choices.push(choice.value)
      }
      if axis.boolean && choices != ["true", "false"] {
        diagnostics.push(
          bundle_diagnostic(
            "STYLE_BUNDLE_RECIPE_BOOLEAN_AXIS",
            "Boolean recipe axes must contain canonical true and false choices",
            module_name=bundle.module_name,
          ),
        )
      }
      match axis.default_value {
        Some(value) if !choices.contains(value) =>
          diagnostics.push(
            bundle_diagnostic(
              "STYLE_BUNDLE_RECIPE_DEFAULT",
              "Recipe default must name one of its choices",
              module_name=bundle.module_name,
            ),
          )
        _ => ()
      }
    }
    for compound in record.recipe.compounds {
      let matched_axes : Array[String] = []
      for selection in compound.matches {
        let axis_index = record.recipe.variants.search_by(axis => {
          axis.name == selection.axis
        })
        let valid = match axis_index {
          Some(index) =>
            record.recipe.variants[index].choices.any(choice => {
              choice.value == selection.value
            })
          None => false
        }
        if !valid || matched_axes.contains(selection.axis) {
          diagnostics.push(
            bundle_diagnostic(
              "STYLE_BUNDLE_RECIPE_COMPOUND",
              "Recipe compound selections must reference each known axis at most once",
              module_name=bundle.module_name,
            ),
          )
        }
        matched_axes.push(selection.axis)
      }
    }
    match record.recipe.contract {
      Some(contract) if !bundle.contracts.any(candidate => {
          candidate.module_name == record.module_name &&
          candidate.name == contract
        }) =>
        diagnostics.push(
          bundle_diagnostic(
            "STYLE_BUNDLE_RECIPE_CONTRACT",
            "Recipe references a contract outside its owning module",
            module_name=bundle.module_name,
          ),
        )
      _ => ()
    }
    let recipe_rules = recipe_rule_names(record.recipe)
    let seen_rules : Array[String] = []
    for rule in recipe_rules {
      let qualified = record.module_name + ":" + rule
      if seen_rules.contains(rule) ||
        !bundle.namespaces.any(namespace_ => {
          namespace_.name == rule || namespace_.name == qualified
        }) {
        diagnostics.push(
          bundle_diagnostic(
            "STYLE_BUNDLE_RECIPE_RULE",
            "Recipe rules must be unique and resolve to a bundled namespace",
            module_name=bundle.module_name,
          ),
        )
      }
      seen_rules.push(rule)
    }
  }
  let marker_identities : Array[String] = []
  let mut previous_marker = ""
  for marker in bundle.markers {
    let identity = marker.module_name + ":" + marker.name
    let owner_visible = marker.module_name == bundle.module_name ||
      bundle.dependency_closure.any(dependency => {
        dependency.module_name == marker.module_name
      })
    if (!previous_marker.is_empty() && previous_marker.compare(identity) >= 0) ||
      marker_identities.contains(identity) {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_MARKER_ORDER",
          "Bundle markers must be unique and sorted by module and name",
          module_name=bundle.module_name,
        ),
      )
    }
    previous_marker = identity
    marker_identities.push(identity)
    if !owner_visible ||
      !contract_name_valid(marker.name) ||
      !mappings_package_valid(marker.mappings_package) ||
      marker.class_name !=
      @core.selector_marker_class_name(marker.module_name, marker.name) ||
      (marker.module_name == bundle.module_name) !=
      (marker.mappings_package == bundle.mappings_package) {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_MARKER",
          "Bundle marker has an invalid owner, package, name, or stable class",
          module_name=bundle.module_name,
        ),
      )
    }
  }
  let view_transition_identities : Array[String] = []
  let mut previous_view_transition = ""
  for value in bundle.view_transition_classes {
    let identity = value.module_name + ":" + value.name
    let owner_visible = value.module_name == bundle.module_name ||
      bundle.dependency_closure.any(dependency => {
        dependency.module_name == value.module_name
      })
    if (
        !previous_view_transition.is_empty() &&
        previous_view_transition.compare(identity) >= 0
      ) ||
      view_transition_identities.contains(identity) {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_VIEW_TRANSITION_ORDER",
          "View-transition classes must be unique and sorted by module and name",
          module_name=bundle.module_name,
        ),
      )
    }
    previous_view_transition = identity
    view_transition_identities.push(identity)
    if !owner_visible ||
      !contract_name_valid(value.name) ||
      !mappings_package_valid(value.mappings_package) ||
      value.css_name !=
      @core.view_transition_class_name(value.module_name, value.name) ||
      (value.module_name == bundle.module_name) !=
      (value.mappings_package == bundle.mappings_package) {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_VIEW_TRANSITION",
          "View-transition class has an invalid owner, package, name, or stable CSS name",
          module_name=bundle.module_name,
        ),
      )
    }
    let expected_css = @core.render_view_transition_css(
      value.css_name,
      value.styles,
    )
    let associated = bundle.globals.filter(global => {
      global.kind == "view-transition" && global.name == value.css_name
    })
    if !@core.valid_view_transition_blocks(value.styles) ||
      (if expected_css.is_empty() {
        !associated.is_empty()
      } else {
        associated.length() != 1 ||
        associated[0].css != expected_css ||
        associated[0].digest != semantic_digest(expected_css)
      }) {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_VIEW_TRANSITION_STYLES",
          "View-transition styles must be canonical and match exactly one owned global rule",
          module_name=bundle.module_name,
        ),
      )
    }
  }
  let property_names : Array[String] = []
  for global in bundle.globals {
    if global.kind == "property" &&
      !@core.valid_property_global(global.name, global.css) {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_PROPERTY", "Property registration must use canonical reviewed syntax, inheritance and initial value",
        ),
      )
    }
    if global.kind == "property" {
      if property_names.contains(global.name) {
        diagnostics.push(
          bundle_diagnostic(
            "STYLE_BUNDLE_PROPERTY_DUPLICATE", "Property registration names must be unique within an artifact",
          ),
        )
      }
      property_names.push(global.name)
    }
    if global.kind == "view-transition" &&
      !bundle.view_transition_classes.any(value => {
        value.css_name == global.name && !value.styles.is_empty()
      }) {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_VIEW_TRANSITION_OWNER",
          "View-transition global has no matching owner record",
          module_name=bundle.module_name,
        ),
      )
    }
    if global.digest != semantic_digest(global.css) {
      diagnostics.push(
        bundle_diagnostic(
          "STYLE_BUNDLE_GLOBAL_DIGEST", "Global digest does not match its CSS",
        ),
      )
    }
  }
  diagnostics
}

///|
fn bundle_by_module(
  bundles : Array[DependencyBundle],
  module_name : String,
) -> DependencyBundle? {
  for bundle in bundles {
    if bundle.module_name == module_name {
      return Some(bundle)
    }
  }
  None
}

///|
fn same_rule(left : BundleRule, right : BundleRule) -> Bool {
  left.class_name == right.class_name &&
  left.property == right.property &&
  left.ltr == right.ltr &&
  left.rtl == right.rtl &&
  left.priority100 == right.priority100
}

///|
fn same_global(left : BundleGlobal, right : BundleGlobal) -> Bool {
  left.kind == right.kind &&
  left.name == right.name &&
  left.css == right.css &&
  left.digest == right.digest
}

///|
fn same_contract(left : BundleContract, right : BundleContract) -> Bool {
  left.module_name == right.module_name &&
  left.name == right.name &&
  left.mappings_package == right.mappings_package &&
  left.trait_name == right.trait_name &&
  left.properties == right.properties
}

///|
fn add_contracts(
  source : DependencyBundle,
  contracts : Array[BundleContract],
) -> @core.Diagnostic? {
  for contract in source.contracts {
    let existing = contracts.search_by(candidate => {
      candidate.module_name == contract.module_name &&
      candidate.name == contract.name
    })
    match existing {
      Some(index) if !same_contract(contracts[index], contract) =>
        return Some(
          bundle_diagnostic(
            "STYLE_BUNDLE_CONTRACT_COLLISION",
            "Style contract identity has different semantic content",
            module_name=source.module_name,
          ),
        )
      Some(_) => ()
      None => contracts.push(contract)
    }
  }
  None
}

///|
fn global_rank(kind : String) -> Int32 {
  match kind {
    "property" => 0
    "variables" => 1
    "theme" => 2
    "keyframes" => 3
    "position-try" => 4
    _ => 5
  }
}

///|
fn add_bundle_records(
  source : DependencyBundle,
  namespaces : Array[BundleNamespace],
  rules : Array[BundleRule],
  globals : Array[BundleGlobal],
) -> @core.Diagnostic? {
  for namespace_ in source.namespaces {
    namespaces.push({
      name: if namespace_.name.contains(":") {
        namespace_.name
      } else {
        source.module_name + ":" + namespace_.name
      },
      entries: namespace_.entries,
    })
  }
  for rule in source.rules {
    let mut existing : BundleRule? = None
    for candidate in rules {
      if candidate.class_name == rule.class_name {
        existing = Some(candidate)
      }
    }
    match existing {
      Some(candidate) if !same_rule(candidate, rule) =>
        return Some(
          bundle_diagnostic(
            "STYLE_BUNDLE_CLASS_COLLISION", "Class name collision has different semantic content",
          ),
        )
      Some(_) => ()
      None => rules.push(rule)
    }
  }
  for global in source.globals {
    let mut existing : BundleGlobal? = None
    for candidate in globals {
      if candidate.kind == global.kind && candidate.name == global.name {
        existing = Some(candidate)
      }
    }
    match existing {
      Some(candidate) if !same_global(candidate, global) =>
        return Some(
          bundle_diagnostic(
            "STYLE_BUNDLE_GLOBAL_COLLISION", "Global name collision has different semantic content",
          ),
        )
      Some(_) => ()
      None => globals.push(global)
    }
  }
  None
}

///|
fn add_bundle_ancestor(rule : String, ancestor : String) -> String {
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
fn render_bundle_rule(rule : BundleRule) -> String {
  let ltr = @core.with_priority_specificity(rule.ltr, rule.priority100)
  match rule.rtl {
    Some(rtl) =>
      add_bundle_ancestor(ltr, ":where(html:not([dir='rtl']))") +
      "\n" +
      add_bundle_ancestor(
        @core.with_priority_specificity(rtl, rule.priority100),
        ":where(html[dir='rtl'])",
      )
    None => ltr
  }
}

///|
pub fn merge_bundles(
  application : CompiledBundle,
  dependencies : Array[DependencyBundle],
) -> Result[CompiledBundle, Array[@core.Diagnostic]] {
  let local_bundle = match decode_bundle(application.manifest) {
    Ok(bundle) => bundle
    Err(diagnostics) => return Err(diagnostics)
  }
  let local_diagnostics = validate_bundle(local_bundle)
  let local_blocking = local_diagnostics.filter(diagnostic => {
    diagnostic.code != "STYLE_BUNDLE_CLOSURE_INCOMPLETE"
  })
  if !local_blocking.is_empty() {
    return Err(local_blocking)
  }
  let unique : Array[DependencyBundle] = []
  for dependency in dependencies {
    let diagnostics = validate_bundle(dependency)
    if !diagnostics.is_empty() {
      return Err(diagnostics)
    }
    match bundle_by_module(unique, dependency.module_name) {
      Some(existing) if existing.semantic_digest != dependency.semantic_digest =>
        return Err([
          bundle_diagnostic(
            "STYLE_BUNDLE_MODULE_CONFLICT", "Duplicate module names have different semantic digests",
          ),
        ])
      Some(_) => ()
      None => unique.push(dependency)
    }
  }
  if unique.length() != local_bundle.direct_dependencies.length() {
    return Err([
      bundle_diagnostic(
        "STYLE_BUNDLE_ROOT_SET",
        "Provided dependency bundles must exactly match the application's direct dependencies",
        module_name=local_bundle.module_name,
      ),
    ])
  }
  let ordered : Array[DependencyBundle] = []
  let roots = local_bundle.direct_dependencies.copy()
  roots.sort_by((left, right) => left.module_name.compare(right.module_name))
  for root in roots {
    match bundle_by_module(unique, root.module_name) {
      None =>
        return Err([
          bundle_diagnostic(
            "STYLE_BUNDLE_MISSING_DEPENDENCY",
            "Missing direct dependency " + root.module_name,
            module_name=local_bundle.module_name,
            dependency_chain=[local_bundle.module_name, root.module_name],
          ),
        ])
      Some(provided) =>
        if provided.semantic_digest != root.semantic_digest {
          return Err([
            bundle_diagnostic(
              "STYLE_BUNDLE_MODULE_CONFLICT",
              "Direct dependency digest does not match the provided module",
              module_name=local_bundle.module_name,
              dependency_chain=[local_bundle.module_name, root.module_name],
            ),
          ])
        } else {
          ordered.push(provided)
        }
    }
  }
  for provided in unique {
    if !local_bundle.direct_dependencies.any(root => {
        root.module_name == provided.module_name
      }) {
      return Err([
        bundle_diagnostic(
          "STYLE_BUNDLE_UNREACHABLE",
          "Provided dependency bundle is not a declared direct dependency: " +
          provided.module_name,
          module_name=local_bundle.module_name,
        ),
      ])
    }
  }
  let namespaces : Array[BundleNamespace] = []
  let rules : Array[BundleRule] = []
  let globals : Array[BundleGlobal] = []
  for dependency in ordered {
    match add_bundle_records(dependency, namespaces, rules, globals) {
      Some(diagnostic) => return Err([diagnostic])
      None => ()
    }
  }
  match add_bundle_records(local_bundle, namespaces, rules, globals) {
    Some(diagnostic) => return Err([diagnostic])
    None => ()
  }
  rules.sort_by((left, right) => {
    if left.priority100 != right.priority100 {
      left.priority100 - right.priority100
    } else {
      let class_order = left.class_name.compare(right.class_name)
      if class_order != 0 {
        class_order
      } else {
        left.ltr.compare(right.ltr)
      }
    }
  })
  globals.sort_by((left, right) => {
    let rank = global_rank(left.kind) - global_rank(right.kind)
    if rank != 0 {
      rank
    } else {
      let name_order = left.name.compare(right.name)
      if name_order != 0 {
        name_order
      } else {
        left.digest.compare(right.digest)
      }
    }
  })
  let final_dependencies : Array[BundleDependency] = []
  for bundle in ordered {
    for dependency in bundle.dependency_closure {
      if !final_dependencies.any(existing => {
          existing.module_name == dependency.module_name
        }) {
        final_dependencies.push(dependency)
      }
    }
    if !final_dependencies.any(existing => {
        existing.module_name == bundle.module_name
      }) {
      final_dependencies.push({
        module_name: bundle.module_name,
        semantic_digest: bundle.semantic_digest,
      })
    }
  }
  let contracts : Array[BundleContract] = []
  for bundle in ordered {
    match add_contracts(bundle, contracts) {
      Some(diagnostic) => return Err([diagnostic])
      None => ()
    }
  }
  match add_contracts(local_bundle, contracts) {
    Some(diagnostic) => return Err([diagnostic])
    None => ()
  }
  contracts.sort_by((left, right) => {
    let module_order = left.module_name.compare(right.module_name)
    if module_order != 0 {
      module_order
    } else {
      left.name.compare(right.name)
    }
  })
  let recipes : Array[BundleRecipe] = []
  let markers : Array[BundleMarker] = []
  let view_transition_classes : Array[BundleViewTransitionClass] = []
  for bundle in ordered {
    for recipe in bundle.recipes {
      if !recipes.contains(recipe) {
        recipes.push(recipe)
      }
    }
    for marker in bundle.markers {
      if !markers.contains(marker) {
        markers.push(marker)
      }
    }
    for value in bundle.view_transition_classes {
      if !view_transition_classes.contains(value) {
        view_transition_classes.push(value)
      }
    }
  }
  for recipe in local_bundle.recipes {
    if !recipes.contains(recipe) {
      recipes.push(recipe)
    }
  }
  for marker in local_bundle.markers {
    if !markers.contains(marker) {
      markers.push(marker)
    }
  }
  for value in local_bundle.view_transition_classes {
    if !view_transition_classes.contains(value) {
      view_transition_classes.push(value)
    }
  }
  recipes.sort_by((left, right) => {
    let module_order = left.module_name.compare(right.module_name)
    if module_order != 0 {
      module_order
    } else {
      left.recipe.name.compare(right.recipe.name)
    }
  })
  markers.sort_by((left, right) => {
    let module_order = left.module_name.compare(right.module_name)
    if module_order != 0 {
      module_order
    } else {
      left.name.compare(right.name)
    }
  })
  view_transition_classes.sort_by((left, right) => {
    let module_order = left.module_name.compare(right.module_name)
    if module_order != 0 {
      module_order
    } else {
      left.name.compare(right.name)
    }
  })
  let mut merged : DependencyBundle = {
    module_name: local_bundle.module_name,
    mappings_package: local_bundle.mappings_package,
    semantic_digest: "",
    direct_dependencies: local_bundle.direct_dependencies,
    dependency_closure: final_dependencies,
    contracts,
    namespaces,
    rules,
    globals,
    recipes,
    markers,
    view_transition_classes,
  }
  merged = {
    ..merged,
    semantic_digest: semantic_digest(semantic_json(merged).stringify()),
  }
  let merged_diagnostics = validate_bundle(merged)
  if !merged_diagnostics.is_empty() {
    return Err(merged_diagnostics)
  }
  let css_blocks = globals.map(global => global.css)
  let rule_css = rules.map(render_bundle_rule).join("\n")
  if !rule_css.is_empty() {
    css_blocks.push(rule_css)
  }
  Ok({
    schema_version: 14,
    module_name: merged.module_name,
    semantic_digest: merged.semantic_digest,
    css: "/* Generated by lampclaw/moonstyle/extract schema v14. Do not edit. */\n" +
    css_blocks.join("\n") +
    "\n",
    mappings: application.mappings,
    mappings_manifest: application.mappings_manifest,
    manifest: render_bundle_manifest(merged),
    diagnostics: [],
  })
}
