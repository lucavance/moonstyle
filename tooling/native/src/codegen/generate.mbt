///|
fn[T] fail(message : String) -> T raise @support.ToolError {
  @support.reject("STYLE_GENERATION", message)
}

///|
fn keyword_enum(name : String, keywords : Array[Json]) -> Json raise {
  guard !keywords.is_empty() else { fail("empty keyword group: " + name) }
  let values = Map([])
  for keyword in keywords {
    let keyword = @support.string(keyword)
    values[name + variant(keyword)] = Json::string(keyword)
  }
  { "name": name, "values": Json::object(values) }
}

///|
fn scalar_summary(config : Json, properties : Array[Json]) -> Json raise {
  guard @support.text(config, "profile") == "stable-scalar-v2" else {
    fail("unknown scalar profile")
  }
  @support.exact(
    @support.get(config, "families"),
    ["layout", "typography", "visual", "interaction", "motion"],
    "scalar families",
  )
  let families : Map[String, Json] = Map([])
  let strategies : Map[String, Json] = Map([])
  for name in ["layout", "typography", "visual", "interaction", "motion"] {
    let entries = properties.filter(item => {
      @support.get(item, "family") == Json::string(name)
    })
    let actual : Json = Json::array(
      entries.map(item => @support.get(item, "cssName")),
    )
    guard actual == @support.get(@support.get(config, "families"), name) else {
      fail("scalar allowlist changed: " + name)
    }
    families[name] = Json(entries.length())
  }
  for
    name in [
      "primitive", "keyword-enum", "property-reference", "reviewed-scalar",
    ] {
    strategies[name] = Json(
      properties
      .filter(item => @support.get(item, "valueStrategy") == Json::string(name))
      .length(),
    )
  }
  let summary : Json = {
    "total": properties.length(),
    "strategies": Json::object(strategies),
    "families": Json::object(families),
  }
  let expected : Json = {
    "total": 129,
    "strategies": {
      "primitive": 54,
      "keyword-enum": 60,
      "property-reference": 9,
      "reviewed-scalar": 6,
    },
    "families": {
      "layout": 63,
      "typography": 28,
      "visual": 23,
      "interaction": 8,
      "motion": 7,
    },
  }
  guard summary == expected else {
    fail("scalar profile drift: " + summary.stringify())
  }
  summary
}

///|
fn borders(
  config : Json,
  definitions : Array[Json],
  types : Map[String, Json],
  functions : Map[String, Json],
  base : Array[Json],
) -> (Array[Json], Json) raise {
  guard @support.text(config, "profile") == "stable-border-composite-v1" else {
    fail("unknown border profile")
  }
  let expected : Json = {
    "border-side": [
      "border", "border-block", "border-block-end", "border-block-start", "border-bottom",
      "border-inline", "border-inline-end", "border-inline-start", "border-left",
      "border-right", "border-top",
    ],
    "border-colors": ["border-block-color", "border-inline-color"],
    "border-styles": ["border-block-style", "border-inline-style"],
    "border-widths": ["border-block-width", "border-inline-width"],
    "color": [
      "border-block-end-color", "border-block-start-color", "border-bottom-color",
      "border-left-color", "border-right-color", "border-top-color",
    ],
    "line-style": [
      "border-block-end-style", "border-block-start-style", "border-bottom-style",
      "border-left-style", "border-right-style", "border-top-style",
    ],
    "line-width": [
      "border-block-end-width", "border-block-start-width", "border-bottom-width",
      "border-left-width", "border-right-width", "border-top-width",
    ],
    "corner-radius": [
      "border-bottom-left-radius", "border-bottom-right-radius", "border-top-left-radius",
      "border-top-right-radius",
    ],
    "outline": ["outline"],
  }
  let samples : Json = {
    "border-side": "1px solid #000",
    "border-colors": "#000 transparent",
    "border-styles": "solid dotted",
    "border-widths": "1px thin",
    "color": "#000",
    "line-style": "solid",
    "line-width": "1px",
    "corner-radius": "1px 2px",
    "outline": "1px auto #000",
  }
  let excluded : Json = {
    "border-side": ["hairline"],
    "border-colors": ["image-1D"],
    "border-styles": [],
    "border-widths": ["hairline"],
    "color": ["image-1D"],
    "line-style": [],
    "line-width": ["hairline"],
    "corner-radius": ["slash-separated-border-radius-syntax"],
    "outline": ["hairline", "image-1D"],
  }
  let configured : Map[String, String] = Map([])
  let counts : Map[String, Json] = Map([])
  for group in @support.array(@support.get(config, "groups")) {
    let adapter = @support.text(group, "adapter")
    guard !counts.contains(adapter) &&
      @support.get(expected, adapter) != Json::null() &&
      @support.get(group, "cssNames") == @support.get(expected, adapter) &&
      @support.text(group, "valueType") == adapter else {
      fail("border adapter allowlist drift: " + adapter)
    }
    let entries = @support.array(@support.get(group, "cssNames"))
    counts[adapter] = Json(entries.length())
    for entry in entries {
      let name = @support.string(entry)
      guard !configured.contains(name) else {
        fail("duplicate border property: " + name)
      }
      configured[name] = adapter
    }
  }
  guard configured.length() == 40 && counts.length() == 9 else {
    fail("incomplete border profile")
  }
  let result : Array[Json] = []
  let by_name = names(definitions)
  for definition in definitions {
    let name = @support.text(definition, "name")
    guard configured.get(name) is Some(adapter) else { continue }
    let status = @support.get(definition, "status")
    guard @support.flag(status, "standard_track") &&
      @support.get(status, "deprecated") == Json::boolean(false) &&
      @support.get(status, "experimental") == Json::boolean(false) &&
      !base.any(item => @support.get(item, "cssName") == Json::string(name)) &&
      match_sample(definition, @support.text(samples, adapter)) else {
      fail("border sample or status changed: " + name)
    }
    let closure = grammar_closure(
      @support.get(definition, "ast"),
      types,
      by_name,
      functions,
    )
    result.push({
      "cssName": name,
      "family": "visual",
      "valueType": adapter,
      "valueStrategy": "reviewed-composite",
      "valueAdapter": adapter,
      "valueCoverage": "stable-intersection",
      "grammarClosureDigest": @support.get(closure, "digest"),
      "grammarReferences": @support.get(closure, "references"),
      "excludedSyntax": @support.get(excluded, adapter),
      "atomicProperties": border_atomic(name, adapter),
    })
  }
  guard result.length() == 40 else { fail("missing WebRef border definitions") }
  (
    result,
    {
      "total": 40,
      "adapters": Json::object(counts),
      "families": { "visual": 40 },
    },
  )
}

///|
fn ast_digest(ast : Json) -> Json {
  if ast is Null {
    Json::null()
  } else {
    Json::string(@support.hash(@support.canonical(ast)))
  }
}

///|
fn metadata(
  property : Json,
  definition : Json,
  definitions : Map[String, Json],
  reviews : Json,
) -> Json raise {
  let css = @support.text(property, "cssName")
  let status = @support.get(definition, "status")
  guard @support.flag(status, "standard_track") &&
    !@support.flag(status, "deprecated") else {
    fail("property is not standards-track: " + css)
  }
  let kind = @support.text(property, "valueType")
  let fields : Map[String, Json] = Map([
    ("cssName", Json::string(css)),
    ("functionName", Json::string(css.replace_all(old="-", new="_"))),
    ("irName", Json::string(ir_name(definition))),
    ("valueType", Json::string(kind)),
    ("family", @support.get(property, "family")),
  ])
  if @support.get(reviews, css)
    is { "digest": digest, "excludedSyntax": excluded, .. } {
    // Logical sizes use a transitive review below; daily CSS reviews cover the root AST.
    if @support.get(property, "scalarAdapter") is Null {
      guard digest == ast_digest(@support.get(definition, "ast")) else {
        fail("daily CSS grammar changed: " + css)
      }
      fields["authoredValueProfile"] = Json::string("daily-css-v1")
      fields["grammarReviewDigest"] = digest
      fields["excludedSyntax"] = excluded
    }
  }
  for
    key in [
      "valueStrategy", "valueCoverage", "referenceProperty", "valueConstraints",
      "scalarAdapter", "valueAdapter", "grammarReviewDigest", "grammarClosureDigest",
      "grammarReferences", "excludedSyntax",
    ] {
    let value = @support.get(property, key)
    if !(value is Null) {
      fields[key] = value
    }
  }
  if common_family(css) is Some(family) {
    fields["authoredValueProfile"] = Json::string("common-values-v1")
    fields["authoredValueType"] = Json::string(family)
    fields["excludedSyntax"] = if family == "BoxSize" || family == "FlexBasis" {
      ["stretch", "stretch()", "contain", "calc-size()", "anchor-size()"]
    } else {
      []
    }
  }
  let ast = @support.get(definition, "ast")
  let reason = grammar_reason(ast)
  let adapted = !(@support.get(property, "scalarAdapter") is Null) ||
    !(@support.get(property, "valueAdapter") is Null)
  fields["grammarTier"] = Json::string(
    if adapted || reason is Some(_) {
      "tier-b"
    } else {
      "tier-a"
    },
  )
  fields["fallbacks"] = Json::boolean(
    kind != "animation-name" &&
    @support.get(property, "fallbacks") != Json::boolean(false),
  )
  fields["conditions"] = Json::boolean(@support.flag(property, "conditions"))
  fields["dynamic"] = @support.get(property, "dynamic")
  let atoms = match @support.get(property, "atomicProperties") {
    Array(items) => items
    _ => [Json::string(css)]
  }
  let atomic_entries = atoms.map(item => {
    let name = @support.string(item)
    guard definitions.get(name) is Some(target) &&
      @support.flag(@support.get(target, "status"), "standard_track") &&
      !@support.flag(@support.get(target, "status"), "deprecated") else {
      fail("invalid atomic property: " + name)
    }
    ({ "cssName": name, "irName": ir_name(target) } : Json)
  })
  guard unique(atoms.map(@support.string)).length() == atoms.length() else {
    fail("duplicate atomic property: " + css)
  }
  fields["atomicProperties"] = Json::array(atomic_entries)
  fields["conflicts"] = Json::array(
    atomic_entries.map(item => @support.get(item, "irName")),
  )
  fields["syntax"] = @support.get(definition, "syntax")
  fields["syntaxAstDigest"] = ast_digest(ast)
  fields["grammarReason"] = Json::string(
    match
      (
        @support.get(property, "scalarAdapter"),
        @support.get(property, "valueAdapter"),
        reason,
      ) {
      (String(adapter), _, _) => "reviewed-scalar:" + adapter
      (_, String(_), _) => "reviewed-composite:stable-intersection"
      (_, _, None) => "supported-definition-syntax"
      (_, _, Some(reason)) => "reviewed-adapter:" + reason
    },
  )
  fields["specification"] = @support.get(definition, "href")
  fields["standardTrack"] = @support.get(status, "standard_track")
  fields["experimental"] = @support.get(status, "experimental")
  fields["deprecated"] = @support.get(status, "deprecated")
  Json::object(fields)
}

///|
pub async fn generate(root : String) -> Unit {
  let snapshot = @support.json(root + "/tools/data/css-inputs.json")
  let payload = @support.get(snapshot, "payload")
  guard @support.get(payload, "schemaVersion") == Json(1) else {
    fail("CSS snapshot schema must be 1")
  }
  guard @support.text(snapshot, "digest") ==
    @support.hash(@support.canonical(payload)) else {
    fail(
      "CSS input snapshot digest mismatch: " +
      @support.hash(@support.canonical(payload)),
    )
  }
  let source_info = @support.fields(@support.get(payload, "sources"))
  let sources : Map[String, Json] = Map([])
  let pins : Map[String, String] = Map([
    ("@webref/css", "8.7.8"),
    ("@mdn/browser-compat-data", "8.1.7"),
    ("css-tree", "3.2.1"),
  ])
  for name, version in pins {
    guard @support.text(source_info[name], "version") == version else {
      fail("unreviewed CSS data version: " + name)
    }
    sources[name] = Json::string(version)
  }
  let config = @support.json(root + "/src/properties/property-api.json")
  guard @support.get(config, "schemaVersion") == Json(18) else {
    fail("property API schema must be 18")
  }
  let coverage = @support.json(root + "/src/properties/css-coverage-api.json")
  let reviews = @support.json(root + "/tools/data/reviewed-grammars.json")
  let base = @support.array(@support.get(config, "properties")).copy()
  let enums = @support.array(@support.get(config, "enums")).copy()
  for group in @support.array(@support.get(config, "propertyGroups")) {
    let css_names = @support.array(@support.get(group, "cssNames"))
    guard !css_names.is_empty() else { fail("empty property group") }
    let type_name = @support.get(group, "typeName")
    if @support.get(group, "keywords") is Array(keywords) {
      enums.push(keyword_enum(@support.string(type_name), keywords))
    }
    for css in css_names {
      let kind = match @support.get(group, "valueType") {
        Null => Json::string("enum:" + @support.string(type_name))
        value => value
      }
      base.push({
        "cssName": css,
        "family": @support.get(group, "family"),
        "valueType": kind,
        "conditions": @support.get(group, "conditions"),
        "dynamic": @support.get(group, "dynamic"),
      })
    }
  }
  guard base.length() == 196 else {
    fail("expected 196 reviewed base properties")
  }
  let definitions = @support.array(@support.get(payload, "properties"))
  let types = names(@support.array(@support.get(payload, "types")))
  let functions = names(@support.array(@support.get(payload, "functions")))
  let scalars = derive_scalars(definitions, types, base, reviews)
  let scalar = scalar_summary(@support.get(config, "scalarExpansion"), scalars)
  for property in scalars {
    if @support.get(property, "keywords") is Array(keywords) {
      enums.push(keyword_enum(@support.text(property, "typeName"), keywords))
    }
  }
  let configured = base + scalars
  let (border, border_summary) = borders(
    @support.get(config, "borderCompositeExpansion"),
    definitions,
    types,
    functions,
    configured,
  )
  configured.append(border)
  configured.append(@support.array(@support.get(coverage, "properties")))
  let by_name = names(definitions)
  let entries = []
  let properties = []
  let builders = []
  let contracts = []
  let identifiers : Map[String, Bool] = Map([])
  for definition in enums {
    for
      name in [@support.text(definition, "name")] +
      @support.fields(@support.get(definition, "values")).keys().collect() {
      guard !identifiers.contains(name) else {
        fail("duplicate enum identifier: " + name)
      }
      identifiers[name] = true
    }
  }
  let seen : Map[String, Bool] = Map([])
  for property in configured {
    let css = @support.text(property, "cssName")
    guard by_name.get(css) is Some(definition) && !seen.contains(css) else {
      fail("missing or duplicate property: " + css)
    }
    seen[css] = true
    let property = @support.copy(property)
    let replacement = @support.get(@support.get(coverage, "overrides"), css)
    if !(replacement is Null) {
      property["valueType"] = replacement
    }
    let property = Json::object(property)
    let ir = ir_name(definition)
    guard !identifiers.contains(ir) else {
      fail("duplicate IR property: " + ir)
    }
    identifiers[ir] = true
    properties.push(render_property(property, ir, enums))
    builders.push(render_builder(property, ir, enums))
    contracts.push(render_contract(property, ir, enums))
    entries.push(metadata(property, definition, by_name, reviews))
  }
  let coverage_entries = []
  let counts : Map[String, Json] = Map([])
  for definition in definitions {
    let css = @support.text(definition, "name")
    let ast = @support.get(definition, "ast")
    let status = @support.get(definition, "status")
    let mut typed = None
    for item in entries {
      if @support.get(item, "cssName") == Json::string(css) {
        typed = Some(item)
        break
      }
    }
    let (classification, tier, reason) = if typed is Some(entry) {
      (
        "typed",
        @support.text(entry, "grammarTier"),
        @support.text(entry, "grammarReason"),
      )
    } else {
      let (classification, reason) = if @support.flag(status, "deprecated") {
        ("deprecated", "deprecated-in-browser-compat-data")
      } else if @support.flag(status, "standard_track") {
        ("unsupported-grammar", "not-yet-mapped-to-a-safe-value-type")
      } else if status is Null {
        ("unsafe-only", "missing-browser-compat-data")
      } else {
        ("unsafe-only", "not-on-the-standards-track")
      }
      (
        classification,
        "tier-c",
        match grammar_reason(ast) {
          None => reason + ":missing-reviewed-capability-family"
          Some(reason) => reason
        },
      )
    }
    let count = match counts.get(classification) {
      Some(Number(value, ..)) => value.to_int()
      _ => 0
    }
    counts[classification] = Json(count + 1)
    coverage_entries.push(
      (
        {
          "cssName": css,
          "syntax": @support.get(definition, "syntax"),
          "syntaxAstDigest": ast_digest(ast),
          "grammarTier": tier,
          "classification": classification,
          "reason": reason,
        } : Json),
    )
  }
  let header = "// Generated by tools/generate-properties.mbtx from @webref/css 8.7.8 and @mdn/browser-compat-data 8.1.7. Do not edit."
  let helper =
    #|///|
    #|fn declaration(
    #|  property : String,
    #|  value : String,
    #|  conditions : Array[@ir.Condition],
    #|) -> @ir.Declaration {
    #|  @ir.declaration(property, @ir.text(value), conditions~, keyframe_allowed=true)
    #|}
    #|
    #|///|
    #|fn animation_declaration(
    #|  property : String,
    #|  value : @ir.AnimationName,
    #|  conditions : Array[@ir.Condition],
    #|) -> @ir.Declaration {
    #|  @ir.declaration(property, @ir.animation(value), conditions~)
    #|}
    #|
    #|///|
    #|fn fallback_declaration(
    #|  property : String,
    #|  values : Array[String],
    #|  conditions : Array[@ir.Condition],
    #|) -> @ir.Declaration {
    #|  @ir.declaration(property, @ir.fallbacks(values), conditions~, keyframe_allowed=true)
    #|}
  let scalar_fields : Map[String, Json] = {
    "profile": Json::string("stable-scalar-v2"),
  }
  for key, value in @support.fields(scalar) {
    scalar_fields[key] = value
  }
  let border_fields : Map[String, Json] = {
    "profile": Json::string("stable-border-composite-v1"),
  }
  for key, value in @support.fields(border_summary) {
    border_fields[key] = value
  }
  let document : Json = {
    "schemaVersion": 18,
    "sources": Json::object(sources),
    "scalarExpansion": Json::object(scalar_fields),
    "borderCompositeExpansion": Json::object(border_fields),
    "properties": entries,
  }
  ignore(
    @support.changed_write(
      root + "/src/properties/properties.mbt",
      [
        header,
        "",
        enums.map(render_enum).join("\n\n"),
        "",
        helper,
        "",
        properties.join("\n\n"),
        "",
      ].join("\n"),
    ),
  )
  ignore(
    @support.changed_write(
      root + "/src/builder/rules.generated.mbt",
      [
        header.replace_all(
          old="Do not edit.",
          new="Fluent authoring API; do not edit.",
        ),
        "",
        builders.join("\n\n"),
        "",
        contracts.join("\n\n"),
        "",
      ].join("\n"),
    ),
  )
  ignore(
    @support.changed_write(
      root + "/src/property-facade.generated.mbt",
      [
        header.replace_all(
          old="Do not edit.",
          new="Root authoring facade; do not edit.",
        ),
        "",
        "///|",
        "pub using @properties {",
        enums
        .map(item => "  type " + @support.text(item, "name") + ",")
        .join("\n"),
        "}",
        "",
      ].join("\n"),
    ),
  )
  @support.write(
    root + "/src/properties/property-metadata.json",
    document.stringify(indent=2) + "\n",
  )
  let coverage_document : Json = {
    "schemaVersion": 1,
    "sources": Json::object(sources),
    "summary": Json::object(counts),
    "properties": coverage_entries,
  }
  @support.write(
    root + "/src/properties/property-coverage.json",
    coverage_document.stringify(indent=2) + "\n",
  )
  for
    script in [
      "generate-css-inputs", "generate-common-values", "generate-theme-paint",
    ] {
    ignore(@support.command("moon", ["run", "tools/" + script + ".mbtx"], root))
  }
  ignore(@support.command("moon", ["fmt"], root))
  println(
    "Generated \{entries.length()} typed properties from the reviewed CSS snapshot.",
  )
}
