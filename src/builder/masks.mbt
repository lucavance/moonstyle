///|
#callsite(autofill(location))
pub fn Rule::mask_layers(
  self : Rule,
  layers : @values.MaskLayers,
  when~ : When = always,
  source~ : @ir.SourceSpan? = None,
  location~ : SourceLoc,
) -> Rule {
  let source = resolve_source_span(source, location, "maskLayers")
  let mut next = self
  for (property, expression) in layers.longhands() {
    next = next.append_input(
      property,
      expression_input(expression),
      when,
      source,
      "",
      true,
    )
  }
  next
}

///|
#callsite(autofill(location))
pub fn Frame::mask_layers(
  self : Frame,
  layers : @values.MaskLayers,
  when~ : When = always,
  source~ : @ir.SourceSpan? = None,
  location~ : SourceLoc,
) -> Frame {
  let source = resolve_source_span(source, location, "maskLayers")
  self.with_rule(self.rule.mask_layers(layers, when~, source~))
}

///|
pub fn StyleContract::allow_mask_layers(
  self : StyleContract,
  layers : Array[@values.MaskLayers],
) -> StyleContract {
  let mut next = self
  for
    property in [
      "maskImage", "maskPosition", "maskSize", "maskRepeat", "maskOrigin", "maskClip",
      "maskMode", "maskComposite",
    ] {
    next = next.allow_property(
      property,
      expressions=layers.map(value => {
        value.longhands().filter(pair => pair.0 == property)[0].1.identity()
      }),
    )
  }
  next
}
