///|
fn view_transition_block_json(block : @core.ViewTransitionBlock) -> Json {
  {
    "group": block.group,
    "declarations": block.declarations.map(declaration => {
      Json::array([
        Json(declaration.0),
        Json::array(declaration.1.map(value => Json(value))),
      ])
    }),
  }
}

///|
fn decode_view_transition_blocks(
  value : Json,
) -> Result[Array[@core.ViewTransitionBlock], @core.Diagnostic] {
  fn invalid() -> @core.Diagnostic {
    bundle_diagnostic(
      "STYLE_BUNDLE_VIEW_TRANSITION_STYLES", "View-transition styles require canonical groups and declaration value arrays",
    )
  }
  guard value is Array(items) else { return Err(invalid()) }
  let blocks : Array[@core.ViewTransitionBlock] = []
  for item in items {
    guard item is Object(object) &&
      exact_fields(object, ["group", "declarations"]) &&
      object.get("group") is Some(String(group)) &&
      object.get("declarations") is Some(Array(entries)) else {
      return Err(invalid())
    }
    let declarations : Array[(String, Array[String])] = []
    for entry in entries {
      guard entry is Array([String(property), Array(items)]) else {
        return Err(invalid())
      }
      let values : Array[String] = []
      for item in items {
        guard item is String(value) else { return Err(invalid()) }
        values.push(value)
      }
      declarations.push((property, values))
    }
    blocks.push({ group, declarations, })
  }
  if @core.valid_view_transition_blocks(blocks) {
    Ok(blocks)
  } else {
    Err(invalid())
  }
}

///|
// Reuse token/theme constraint validation without treating pseudo styles as
// ordinary exported style namespaces or generating atomic rules for them.
fn registry_with_transition_styles(registry : @ir.Registry) -> @ir.Registry {
  let namespaces : Array[@ir.Namespace] = []
  for definition in registry.view_transition_classes {
    for style in definition.styles {
      namespaces.push(
        @ir.style_namespace(
          definition.name + "." + style.group,
          style.declarations,
        ),
      )
    }
  }
  {
    ..registry,
    styles: registry.styles + [@ir.style_set("view-transitions", namespaces)],
  }
}
