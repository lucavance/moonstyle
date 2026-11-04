///|
fn object(value : Json) -> Map[String, Json] raise {
  guard value is Object(fields) else { fail("expected object") }
  fields
}

///|
fn main raise {
  let variables = @moonstyle.variable_scope("component-button")
  let contract = @moonstyle.style_contract("button")
    .allow_color(slots=[
      variables.color_slot("text", @moonstyle.rgb(23, 33, 43)),
    ])
    .allow_border_color(tokens=[
      variables.color_token("border", @moonstyle.rgb(75, 150, 104)),
    ])
    .allow_background_color(values=[@moonstyle.rgb(210, 235, 220)], tokens=[
      variables.color_token("surface", @moonstyle.rgb(226, 244, 232)),
    ])
  let registry = @moonstyle.registry(
    "fixture/component-a",
    [@moonstyle.rule("badge").background_color(@moonstyle.rgb(210, 235, 220))],
    contracts=[contract],
  )
  let compiled = @extract.compile_registry(
    registry,
    mappings_package="lampclaw/moonstyle-validation/tests/component_a_generated",
  )
  guard compiled.diagnostics.is_empty() else {
    abort(@extract.render_diagnostics_text(compiled.diagnostics))
  }
  let native = @json.parse(compiled.manifest)
  guard native
    is { "rules": Array([{ "className": String(class_name), .. }]), .. } else {
    fail("expected one native rule")
  }
  let renamed = object(
    @json.parse(compiled.manifest.replace_all(old=class_name, new="dep-a")),
  )
  ignore(renamed.remove("semanticDigest"))
  let first_digest = @extract.content_digest(Json::object(renamed).stringify())
  renamed["semanticDigest"] = Json(first_digest)
  let first = Json::object(renamed)
  // The second fixture intentionally exercises one conflicting synthetic rule.
  let fields = object(first).copy()
  fields["module"] = Json("fixture/component-b")
  fields["mappingsPackage"] = Json(
    "lampclaw/moonstyle-validation/tests/component_b_generated",
  )
  let dependency : Json = {
    "module": "fixture/component-a",
    "semanticDigest": first_digest,
  }
  fields["directDependencies"] = [dependency]
  fields["dependencyClosure"] = [dependency]
  let entries = @core.application_order_entries("borderStyle").map(entry => {
    Json::array([
      Json(entry.0),
      if entry.1 {
        Json("dep-b")
      } else {
        Json::null()
      },
    ])
  })
  fields["namespaces"] = [{ "name": "badge", "entries": entries }]
  fields["rules"] = [
    {
      "property": "borderStyle",
      "className": "dep-b",
      "ltr": ".dep-b{border-style:solid;border-width:3px;border-color:rgb(30 110 75)}",
      "rtl": null,
      "priority100": @core.application_order_priority100("borderStyle"),
    },
  ]
  ignore(fields.remove("semanticDigest"))
  fields["semanticDigest"] = Json(
    @extract.content_digest(Json::object(fields).stringify()),
  )
  let second = Json::object(fields)
  for fixture in [first, second] {
    match @extract.decode_bundle(fixture.stringify()) {
      Err(errors) => abort(@extract.render_diagnostics_text(errors))
      Ok(bundle) => {
        let errors = @extract.validate_bundle(bundle)
        if !errors.is_empty() {
          abort(@extract.render_diagnostics_text(errors))
        }
      }
    }
  }
  let output : Json = {
    "fixtures": [first, second],
    "mappings": compiled.mappings
    .replace_all(old=class_name, new="dep-a")
    .replace_all(old=compiled.semantic_digest, new=first_digest),
    "mappingsManifest": compiled.mappings_manifest,
  }
  println(output.stringify())
}
