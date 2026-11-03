///|
fn expression_input(expression : @values.Expression) -> PropertyInput {
  {
    css: expression.to_css(),
    dynamic: expression.is_dynamic(),
    variable: None,
    expression: Some(expression),
    value_origin: @ir.ExpressionOrigin(expression.identity()),
  }
}

///|
#warnings("-unused_trait_bound")
pub impl[T : @values.LengthMathDimension] LengthInput for @values.MathExpr[T] with fn length_input(
  self,
) {
  expression_input(self.expression())
}

///|
pub trait GridTrackListInput {
  fn grid_track_list_input(Self) -> PropertyInput
}

///|
pub impl GridTrackListInput for @values.GridTrackList with fn grid_track_list_input(
  self,
) {
  expression_input(self.expression())
}

///|
fn Rule::append_expression_fallbacks(
  self : Rule,
  property : String,
  values : Array[@values.Expression],
  when_ : When,
  source : @ir.SourceSpan?,
  origins? : Array[@ir.DeclarationValueOrigin],
) -> Rule {
  let next = self.append_declaration(
    @ir.declaration(
      property,
      @ir.ExpressionFallbacks(values),
      conditions=when_.to_conditions(),
      source~,
      keyframe_allowed=true,
      value_origin=origins.map(values => @ir.MixedFallbackOrigin(values)),
    ),
  )
  for value in values {
    for use_ in value.variables() {
      next.variables.push(use_.variable)
    }
  }
  next
}

///|
pub trait ImageInput {
  fn image_input(Self) -> PropertyInput
}

///|
pub impl ImageInput for @values.Url with fn image_input(self) {
  static_input(self.to_css())
}

///|
pub impl ImageInput for @values.Token[@values.Url] with fn image_input(self) {
  token_input(self)
}

///|
pub impl ImageInput for @values.DynamicSlot[@values.Url] with fn image_input(
  self,
) {
  slot_input(self)
}

///|
pub impl ImageInput for @values.Image with fn image_input(self) {
  expression_input(self.expression())
}

///|
#callsite(autofill(location))
pub fn Rule::background_layers(
  self : Rule,
  layers : @values.BackgroundLayers,
  when~ : When = always,
  source~ : @ir.SourceSpan? = None,
  location~ : SourceLoc,
) -> Rule {
  let source = resolve_source_span(source, location, "backgroundLayers")
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
pub fn Frame::background_layers(
  self : Frame,
  layers : @values.BackgroundLayers,
  when~ : When = always,
  source~ : @ir.SourceSpan? = None,
  location~ : SourceLoc,
) -> Frame {
  let source = resolve_source_span(source, location, "backgroundLayers")
  self.with_rule(self.rule.background_layers(layers, when~, source~))
}

///|
pub fn StyleContract::allow_background_layers(
  self : StyleContract,
  layers : Array[@values.BackgroundLayers],
) -> StyleContract {
  let mut next = self
  for
    property in [
      "backgroundImage", "backgroundPositionX", "backgroundPositionY", "backgroundSize",
      "backgroundRepeat", "backgroundAttachment", "backgroundOrigin", "backgroundClip",
    ] {
    next = next.allow_property(
      property,
      expressions=layers.map(value => {
        value.property_expression(property).identity()
      }),
    )
  }
  next
}

///|
pub impl ColorInput for @values.ColorExpr with fn color_input(self) {
  expression_input(self.expression())
}

///|
pub impl MaskImageListInput for @values.Image with fn property_input(self) {
  expression_input(self.expression())
}

///|
pub impl ClipPathInput for @values.BasicShape with fn property_input(self) {
  expression_input(self.expression())
}

///|
pub impl OffsetRotateInput for @values.Angle with fn property_input(self) {
  expression_input(@values.offset_rotation(self).expression())
}

///|
pub impl AnimationIterationsInput for @values.Number with fn property_input(
  self,
) {
  static_input(@values.animation_iterations([Some(self)]).to_css())
}
