///|
fn value_type(kind : String, enums : Array[Json]) -> String raise {
  if kind.has_prefix("enum:") {
    let name = kind[5:].to_owned()
    guard enums.any(item => @support.get(item, "name") == Json::string(name)) else {
      fail("unknown enum " + name)
    }
    return name
  }
  match kind {
    "animation-name" => "@ir.AnimationName"
    "int" => "Int"
    "double" => "Double"
    "string" => "String"
    _ => "@values." + variant(kind)
  }
}

///|
fn expression(kind : String) -> String {
  match kind {
    "animation-name" | "string" => "value"
    "int" | "double" => "value.to_string()"
    _ => "value.to_css()"
  }
}

///|
fn common_family(name : String) -> String? {
  if [
      "width", "height", "min-width", "max-width", "min-height", "max-height", "inline-size",
      "block-size", "min-inline-size", "max-inline-size", "min-block-size", "max-block-size",
    ].contains(name) {
    return Some("BoxSize")
  }
  if name == "flex-basis" {
    return Some("FlexBasis")
  }
  if name == "font-size" {
    return Some("FontSize")
  }
  if name == "line-height" {
    return Some("LineHeight")
  }
  if name == "border-radius" {
    return Some("BorderRadii")
  }
  if name.has_prefix("border-") && name.has_suffix("-radius") {
    return Some("CornerRadius")
  }
  None
}

///|
fn input(kind : String) -> (String, String)? {
  if primitive(kind) || kind == "grid-track-list" {
    Some(
      (variant(kind) + "Input", kind.replace_all(old="-", new="_") + "_input"),
    )
  } else {
    None
  }
}

///|
fn render_enum(definition : Json) -> String raise {
  let name = @support.text(definition, "name")
  let values = @support.fields(@support.get(definition, "values"))
  guard !values.is_empty() else { fail("empty enum " + name) }
  let lines = ["///|", "pub(all) enum \{name} {"]
  for key in values.keys() {
    lines.push("  " + key)
  }
  lines.append([
    "} derive(Eq, Debug)",
    "",
    "///|",
    "pub extend \{name} with Eq::{equal, not_equal}",
    "",
    "///|",
    "pub extend \{name} with @moonbitlang/core/debug.Debug::{to_repr}",
    "",
    "///|",
    "pub fn \{name}::to_css(self : \{name}) -> String {",
    "  match self {",
  ])
  for key, value in values {
    lines.push("    " + key + " => " + value.stringify())
  }
  lines.append(["  }", "}"])
  lines.join("\n")
}

///|
fn render_property(
  property : Json,
  ir : String,
  enums : Array[Json],
) -> String raise {
  let name = @support.text(property, "cssName").replace_all(old="-", new="_")
  let kind = @support.text(property, "valueType")
  let type_ = value_type(kind, enums)
  let family = @support.text(property, "family")
  let family_type = variant(family) + "Declaration"
  let wrap = family + "_declaration"
  let helper = if kind == "animation-name" {
    "animation_declaration"
  } else {
    "declaration"
  }
  let value = expression(kind)
  let key = @support.quote(ir)
  let conditional = @support.flag(property, "conditions")
  let blocks = []
  if conditional {
    blocks.push(
      [
        "///|",
        "pub fn \{name}(",
        "  value : \{type_},",
        "  conditions? : Array[@ir.Condition] = [],",
        ") -> \{family_type} {",
        "  \{wrap}(\{helper}(\{key}, \{value}, conditions))",
        "}",
      ].join("\n"),
    )
  } else {
    blocks.push(
      "///|\npub fn \{name}(value : \{type_}) -> \{family_type} {\n  \{wrap}(\{helper}(\{key}, \{value}, []))\n}",
    )
  }
  if kind != "animation-name" &&
    @support.get(property, "fallbacks") != Json::boolean(false) {
    let parameters = ["  values : Array[\{type_}],"]
    if conditional {
      parameters.push("  conditions? : Array[@ir.Condition] = [],")
    }
    let conditions = if conditional { "conditions" } else { "[]" }
    blocks.push(
      [
        "///|",
        "pub fn \{name}_fallbacks(",
        parameters.join("\n"),
        ") -> \{family_type} {",
        "  \{wrap}(fallback_declaration(\{key}, values.map(value => \{value}), \{conditions}))",
        "}",
      ].join("\n"),
    )
  }
  let dynamic = @support.get(property, "dynamic")
  if dynamic != Json::null() && dynamic != Json::boolean(false) {
    let suffix = match @support.get(dynamic, "suffix") {
      String(value) => value
      _ => ""
    }
    blocks.push(
      [
        "///|",
        "pub fn dynamic_\{name}(",
        "  variable : @values.CssVar[\{type_}],",
        ") -> \{family_type} {",
        "  \{wrap}(@ir.declaration(\{key}, @ir.dynamic(variable.name(), \{@support.quote(suffix)}, category=\{@support.quote(kind)})))",
        "}",
      ].join("\n"),
    )
  }
  blocks.join("\n\n")
}

///|
fn builder_method(
  receiver : String,
  name : String,
  generic : String,
  parameter : String,
  body : String,
  ir : String,
) -> String {
  [
    "///|",
    "#callsite(autofill(location))",
    "pub fn\{generic} \{receiver}::\{name}(",
    "  self : \{receiver},",
    parameter,
    "  when? : When = always,",
    "  source? : @ir.SourceSpan? = None,",
    "  location~ : SourceLoc,",
    ") -> \{receiver} {",
    "  let source = resolve_source_span(source, location, \{@support.quote(ir)})",
    "  " + body,
    "}",
  ].join("\n")
}

///|
fn render_builder(
  property : Json,
  ir : String,
  enums : Array[Json],
) -> String raise {
  let css = @support.text(property, "cssName")
  let name = css.replace_all(old="-", new="_")
  let key = @support.quote(ir)
  let kind = @support.text(property, "valueType")
  let clear = [
    "///|",
    "#callsite(autofill(location))",
    "pub fn Rule::clear_\{name}(",
    "  self : Rule,",
    "  source? : @ir.SourceSpan? = None,",
    "  location~ : SourceLoc,",
    ") -> Rule {",
    "  let source = resolve_source_span(source, location, \{key})",
    "  self.append_clear(\{key}, source)",
    "}",
  ].join("\n")
  if kind == "animation-name" {
    return builder_method(
        "Rule",
        name,
        "[T : AnimationInput]",
        "  value : T,",
        "self.append_animation(\{key}, value, when, source)",
        ir,
      ) +
      "\n\n" +
      clear
  }
  let input = match common_family(css) {
    Some(family) => Some((family + "Input", "property_input"))
    None =>
      if css == "background-image" {
        Some(("ImageInput", "image_input"))
      } else {
        input(kind)
      }
  }
  let type_ = (if kind.has_prefix("enum:") { "@properties." } else { "" }) +
    value_type(kind, enums)
  let (generic, parameter_type) = match input {
    Some((trait_, _)) => ("[T : " + trait_ + "]", "T")
    None => ("", type_)
  }
  let suffix = match @support.get(@support.get(property, "dynamic"), "suffix") {
    String(value) => value
    _ => ""
  }
  let body = match input {
    Some((_, input_method)) =>
      "self.append_input(\{key}, value.\{input_method}(), when, source, \{@support.quote(suffix)}, true)"
    None => "self.append_text(\{key}, \{expression(kind)}, when, source, true)"
  }
  let blocks = [
    builder_method(
      "Rule",
      name,
      generic,
      "  value : \{parameter_type},",
      body,
      ir,
    ),
  ]
  let fallbacks = @support.get(property, "fallbacks") != Json::boolean(false)
  if fallbacks {
    let body = if kind == "grid-track-list" {
      "self.append_expression_fallbacks(\{key}, values.map(value => value.expression()), when, source)"
    } else {
      "self.append_fallbacks(\{key}, values.map(value => \{expression(kind)}), when, source)"
    }
    blocks.push(
      builder_method(
        "Rule",
        name + "_fallbacks",
        "",
        "  values : Array[\{type_}],",
        body,
        ir,
      ),
    )
  }
  blocks.push(
    builder_method(
      "Frame",
      name,
      generic,
      "  value : \{parameter_type},",
      "self.with_rule(self.rule.\{name}(value, when=when, source=source))",
      ir,
    ),
  )
  if fallbacks {
    blocks.push(
      builder_method(
        "Frame",
        name + "_fallbacks",
        "",
        "  values : Array[\{type_}],",
        "self.with_rule(self.rule.\{name}_fallbacks(values, when=when, source=source))",
        ir,
      ),
    )
  }
  blocks.push(clear)
  blocks.join("\n\n")
}

///|
fn render_contract(
  property : Json,
  ir : String,
  enums : Array[Json],
) -> String raise {
  let css = @support.text(property, "cssName")
  let name = css.replace_all(old="-", new="_")
  let kind = @support.text(property, "valueType")
  let key = @support.quote(ir)
  if kind == "animation-name" {
    return "///|\npub fn StyleContract::allow_\{name}(self : StyleContract, keywords? : Array[@values.CssWideKeyword] = [], lists? : Array[AnimationNames] = []) -> StyleContract {\n  self.allow_property(\{key}, values=keywords.map(value => value.to_css()), expressions=lists.map(value => value.identity()))\n}"
  }
  let value = value_type(kind, enums)
  let type_ = (if kind.has_prefix("enum:") { "@properties." } else { "" }) +
    value
  let parameters = ["  values? : Array[\{type_}] = [],"]
  let arguments = ["    values=values.map(value => \{expression(kind)}),"]
  if common_family(css) is Some(family) {
    let family = if family == "CornerRadius" || family == "BorderRadii" {
      "BoxSize"
    } else {
      family
    }
    let contract_method = match family {
      "BoxSize" => "box_size"
      "FlexBasis" => "flex_basis"
      "FontSize" => "font_size"
      _ => "line_height"
    }
    parameters.push(
      "  expressions? : Array[&@values.\{family}ContractExpression] = [],",
    )
    arguments.push(
      "    expressions=expressions.map(value => value.\{contract_method}_contract_expression()),",
    )
  } else if [
      "length", "length-percentage", "percentage", "number", "angle", "time", "resolution",
    ].contains(kind) {
    parameters.push(
      if kind == "length" {
        "  expressions? : Array[&@values.LengthContractExpression] = [],"
      } else {
        "  expressions? : Array[@values.MathExpr[\{value}]] = [],"
      },
    )
    arguments.push(
      if kind == "length" {
        "    expressions=expressions.map(value => value.contract_expression()),"
      } else {
        "    expressions=expressions.map(value => value.expression().identity()),"
      },
    )
  }
  if input(kind) is Some(_) && kind != "grid-track-list" {
    let category = value.replace_all(old="@values.", new="")
    parameters.append([
      "  tokens? : Array[@values.\{category}Token] = [],",
      "  slots? : Array[@values.\{category}Slot] = [],",
    ])
    arguments.append([
      "    tokens=tokens.map(value => contract_token(value)),", "    slots=slots.map(value => contract_slot(value)),",
    ])
  }
  if kind == "grid-track-list" || css == "background-image" {
    let expression_type = if kind == "grid-track-list" {
      "GridTrackList"
    } else {
      "Image"
    }
    parameters.push("  expressions? : Array[@values.\{expression_type}] = [],")
    arguments.push(
      "    expressions=expressions.map(value => value.expression().identity()),",
    )
  }
  if [
      "background-position-x", "background-position-y", "background-size", "background-repeat",
      "background-attachment", "background-origin", "background-clip",
    ].contains(css) {
    parameters.push("  expressions? : Array[@values.BackgroundLayers] = [],")
    arguments.push(
      "    expressions=expressions.map(value => value.property_expression(\{key}).identity()),",
    )
  }
  [
    "///|",
    "pub fn StyleContract::allow_\{name}(",
    "  self : StyleContract,",
    parameters.join("\n"),
    ") -> StyleContract {",
    "  self.allow_property(",
    "    \{key},",
    arguments.join("\n"),
    "  )",
    "}",
  ].join("\n")
}
