///|
fn primitive(name : String) -> Bool {
  [
    "length", "percentage", "length-percentage", "color", "number", "integer", "time",
    "angle", "resolution", "url",
  ].contains(name)
}

///|
fn grammar_reason(ast : Json) -> String? raise {
  match ast {
    {
      "type": String("Group"),
      "combinator": String(combinator),
      "terms": Array(terms),
      ..
    } => {
      if combinator == "&&" {
        return Some("unsupported-combinator-and")
      }
      if !["|", " ", "||"].contains(combinator) {
        return Some("unsupported-combinator-" + combinator)
      }
      for term in terms {
        if grammar_reason(term) is Some(reason) {
          return Some(reason)
        }
      }
      None
    }
    { "type": String("Type"), "name": String(name), .. } =>
      if !primitive(name) {
        Some("unsupported-type-" + name)
      } else {
        let opts = @support.get(ast, "opts")
        if opts is Null {
          None
        } else {
          grammar_reason(opts)
        }
      }
    { "type": String("Keyword" | "Range" | "Property"), .. } => None
    {
      "type": String("Multiplier"),
      "min": Number(min, ..),
      "max": Number(max, ..),
      "term": term,
      ..
    } => {
      let comma = @support.flag(ast, "comma")
      if !((!comma && min == 0 && max == 1) || (comma && max == 0) || max > 0) {
        Some("unsupported-unbounded-repetition")
      } else {
        grammar_reason(term)
      }
    }
    { "type": String("Function"), "name": String(name), .. } =>
      Some("unsupported-function-" + name)
    { "type": String("Token" | "Comma"), .. } =>
      Some("unsupported-token-sequence")
    Null => Some("definition-syntax-parse-error")
    _ => Some("unsupported-node-" + @support.text(ast, "type"))
  }
}

///|
fn collect(ast : Json, kind : String, output : Array[Json]) -> Unit {
  if @support.get(ast, "type") == Json::string(kind) {
    output.push(ast)
  }
  match ast {
    Object(fields) =>
      for value in fields.values() {
        collect(value, kind, output)
      }
    Array(items) =>
      for value in items {
        collect(value, kind, output)
      }
    _ => ()
  }
}

///|
fn nodes(ast : Json, kind : String) -> Array[Json] {
  let output = []
  collect(ast, kind, output)
  output
}

///|
fn unique(values : Array[String]) -> Array[String] {
  let output = []
  for value in values {
    if !output.contains(value) {
      output.push(value)
    }
  }
  output
}

///|
fn names(items : Array[Json]) -> Map[String, Json] raise {
  let result = Map([])
  for item in items {
    result[@support.text(item, "name")] = item
  }
  result
}

///|
fn family(name : String) -> String {
  if [
      "offset-distance", "offset-rotate", "scroll-timeline-axis", "transform-box",
      "transition-duration", "view-timeline-axis", "view-timeline-inset",
    ].contains(name) {
    return "motion"
  }
  if [
      "overflow-anchor", "overscroll-behavior", "overscroll-behavior-block", "overscroll-behavior-inline",
      "scroll-snap-align", "scroll-snap-stop", "scroll-snap-type", "scrollbar-width",
    ].contains(name) {
    return "interaction"
  }
  if ["font-", "math-", "ruby-", "text-"].any(prefix => name.has_prefix(prefix)) ||
    [
      "baseline-shift", "hanging-punctuation", "hyphenate-limit-chars", "line-break",
      "orphans", "speak", "widows",
    ].contains(name) {
    return "typography"
  }
  if ["border-image-", "fill-", "flood-", "stop-", "stroke-"].any(prefix => {
      name.has_prefix(prefix)
    }) ||
    [
      "box-decoration-break", "clip-rule", "color-interpolation-filters", "forced-color-adjust",
      "image-orientation", "lighting-color", "mask-type", "outline-offset", "paint-order",
      "print-color-adjust", "shape-rendering", "vector-effect",
    ].contains(name) {
    return "visual"
  }
  "layout"
}

///|
fn variant(name : String) -> String {
  name
  .split("-")
  .map(part => {
    let word = part.to_owned()
    if word.is_empty() {
      ""
    } else {
      word[0:1].to_owned().to_upper() + word[1:].to_owned()
    }
  })
  .join("")
}

///|
fn ir_name(definition : Json) -> String raise {
  let fields = @support.get(definition, "styleDeclaration")
  if fields is Array(items) {
    for item in items {
      let name = @support.string(item)
      if !name.contains("-") {
        return name
      }
    }
  }
  @support.text(definition, "name")
}

///|
fn match_sample(definition : Json, sample : String) -> Bool {
  @support.get(@support.get(definition, "matches"), sample) is True
}

///|
fn derive_scalars(
  definitions : Array[Json],
  types : Map[String, Json],
  base : Array[Json],
  reviews : Json,
) -> Array[Json] raise {
  let base_names : Map[String, Json] = Map([])
  for property in base {
    base_names[@support.text(property, "cssName")] = property
  }
  let result : Array[Json] = []
  for definition in definitions {
    let name = @support.text(definition, "name")
    let status = @support.get(definition, "status")
    if base_names.contains(name) ||
      !@support.flag(status, "standard_track") ||
      @support.get(status, "deprecated") != Json::boolean(false) ||
      @support.get(status, "experimental") != Json::boolean(false) ||
      name.has_prefix("-") ||
      name == "all" {
      continue
    }
    if [
        "block-size", "inline-size", "max-block-size", "max-inline-size", "min-block-size",
        "min-inline-size",
      ].contains(name) {
      let review = @support.get(reviews, name)
      let document : Json = {
        "root": @support.get(definition, "ast"),
        "definitions": [
          {
            "key": "type:box-size",
            "ast": @support.get(types["box-size"], "ast"),
          },
        ],
      }
      // The historical closure identity preserves root/definitions field order.
      let serialized = "{\"root\":" +
        @support.canonical(@support.get(document, "root")) +
        ",\"definitions\":[{\"key\":\"type:box-size\",\"ast\":" +
        @support.canonical(@support.get(types["box-size"], "ast")) +
        "}]}"
      guard @support.hash(serialized) == @support.text(review, "digest") &&
        match_sample(definition, "1px") &&
        match_sample(definition, "1%") else {
        fail(name + " logical-size grammar changed")
      }
      result.push({
        "cssName": name,
        "family": "layout",
        "valueType": "length",
        "valueStrategy": "reviewed-scalar",
        "valueCoverage": "conservative-scalar",
        "scalarAdapter": "logical-size-length",
        "grammarReviewDigest": @support.get(review, "digest"),
        "grammarReferences": ["type:box-size"],
        "excludedSyntax": @support.get(review, "excludedSyntax"),
      })
      continue
    }
    let ast = @support.get(definition, "ast")
    if grammar_reason(ast) is Some(_) {
      continue
    }
    let references = nodes(ast, "Property")
    if !references.is_empty() {
      guard ast
        is {
          "type": String("Group"),
          "combinator": String(" "),
          "terms": Array([reference]),
          ..
        } &&
        @support.get(reference, "type") == Json::string("Property") else {
        continue
      }
      let target_name = @support.text(reference, "name")
      guard base_names.get(target_name) is Some(target) else { continue }
      result.push({
        "cssName": name,
        "family": @support.get(target, "family"),
        "valueType": @support.get(target, "valueType"),
        "valueStrategy": "property-reference",
        "valueCoverage": "conservative-scalar",
        "referenceProperty": target_name,
      })
      continue
    }
    let primitives = unique(
      nodes(ast, "Type")
      .map(node => @support.text(node, "name"))
      .filter(primitive),
    )
    let samples : Map[String, String] = Map([
      ("length", "1px"),
      ("percentage", "1%"),
      ("length-percentage", "1px"),
      ("color", "red"),
      ("number", "1.5"),
      ("integer", "2"),
      ("time", "1s"),
      ("angle", "1deg"),
      ("resolution", "1dpi"),
      ("url", "url(\"x\")"),
    ])
    if primitives is [kind] && match_sample(definition, samples[kind]) {
      let property : Json = {
        "cssName": name,
        "family": family(name),
        "valueType": kind,
        "valueStrategy": "primitive",
        "valueCoverage": "conservative-scalar",
      }
      let fields = @support.copy(property)
      if name == "font-width" {
        fields["valueConstraints"] = { "minimum": 0, "finite": true }
      }
      result.push(Json::object(fields))
      continue
    }
    let keywords = unique(
      nodes(ast, "Keyword").map(node => @support.text(node, "name")),
    ).filter(keyword => match_sample(definition, keyword))
    if keywords.length() < 2 {
      continue
    }
    let type_name = variant(name) + "Value"
    result.push({
      "cssName": name,
      "family": family(name),
      "valueType": "enum:" + type_name,
      "valueStrategy": "keyword-enum",
      "valueCoverage": "conservative-scalar",
      "typeName": type_name,
      "keywords": keywords,
    })
  }
  result
}

///|
fn closure_visit(
  ast : Json,
  types : Map[String, Json],
  properties : Map[String, Json],
  functions : Map[String, Json],
  definitions : Map[String, Json],
  references : Array[String],
  stack : Array[String],
) -> Unit raise {
  let kind = @support.get(ast, "type")
  if kind == Json::string("Type") || kind == Json::string("Property") {
    let name = @support.text(ast, "name")
    if kind == Json::string("Property") || !(primitive(name) || name == "flex") {
      let category = if kind == Json::string("Property") {
        "property"
      } else if types.contains(name) {
        "type"
      } else if functions.contains(name) {
        "function"
      } else {
        "type"
      }
      let key = category + ":" + name
      guard !stack.contains(key) else {
        fail("definition syntax reference cycle: " + key)
      }
      if !references.contains(key) {
        references.push(key)
      }
      if !definitions.contains(key) {
        let source = (if category == "property" {
          properties
        } else if category == "function" {
          functions
        } else {
          types
        }).get(name)
        guard source is Some(source) else { fail("Missing definition " + key) }
        let tree = @support.get(source, "ast")
        guard !(tree is Null) else { fail("Unparseable definition " + key) }
        definitions[key] = {
          "key": key,
          "syntax": @support.get(source, "syntax"),
          "ast": tree,
        }
        let next = stack.copy()
        next.push(key)
        closure_visit(
          tree, types, properties, functions, definitions, references, next,
        )
      }
    }
  }
  match ast {
    Object(fields) =>
      for value in fields.values() {
        closure_visit(
          value, types, properties, functions, definitions, references, stack,
        )
      }
    Array(items) =>
      for value in items {
        closure_visit(
          value, types, properties, functions, definitions, references, stack,
        )
      }
    _ => ()
  }
}

///|
fn grammar_closure(
  ast : Json,
  types : Map[String, Json],
  properties : Map[String, Json],
  functions : Map[String, Json],
) -> Json raise {
  let definitions = Map([])
  let references = []
  closure_visit(ast, types, properties, functions, definitions, references, [])
  let keys = definitions.keys().collect()
  keys.sort_by((a, b) => a[:].lexical_compare(b[:]))
  references.sort_by((a, b) => a[:].lexical_compare(b[:]))
  let rendered = keys.map(key => {
    let value = definitions[key]
    "{\"key\":" +
    @support.quote(key) +
    ",\"syntax\":" +
    @support.get(value, "syntax").stringify() +
    ",\"ast\":" +
    @support.canonical(@support.get(value, "ast")) +
    "}"
  })
  let document = "{\"root\":" +
    @support.canonical(ast) +
    ",\"definitions\":[" +
    rendered.join(",") +
    "]}"
  { "digest": @support.hash(document), "references": references }
}

///|
fn border_atomic(name : String, adapter : String) -> Array[String] {
  let prefixes = if name == "border" {
    ["border-top", "border-inline-end", "border-bottom", "border-inline-start"]
  } else if name == "border-block" {
    ["border-block-start", "border-block-end"]
  } else if name == "border-inline" {
    ["border-inline-start", "border-inline-end"]
  } else {
    [name]
  }
  if adapter == "outline" {
    return ["outline-width", "outline-style", "outline-color"]
  }
  if adapter == "border-side" {
    let result = []
    for prefix in prefixes {
      for suffix in ["width", "style", "color"] {
        result.push(prefix + "-" + suffix)
      }
    }
    return result
  }
  let suffix = match adapter {
    "border-colors" => "color"
    "border-styles" => "style"
    "border-widths" => "width"
    _ => ""
  }
  if suffix != "" {
    let axis = if name.has_prefix("border-block-") { "block" } else { "inline" }
    return [
      "border-" + axis + "-start-" + suffix,
      "border-" + axis + "-end-" + suffix,
    ]
  }
  [name]
}
