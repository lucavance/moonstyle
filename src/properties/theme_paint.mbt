///|
fn theme_paint_declaration(
  property : String,
  value : @values.Expression,
  conditions : Array[@ir.Condition],
) -> @ir.Declaration {
  @ir.declaration(
    property,
    @ir.Expression(value),
    conditions~,
    keyframe_allowed=property != "colorScheme",
  )
}

///|
fn theme_paint_fallback_declaration(
  property : String,
  values : Array[@values.Expression],
  conditions : Array[@ir.Condition],
) -> @ir.Declaration {
  @ir.declaration(
    property,
    @ir.ExpressionFallbacks(values),
    conditions~,
    keyframe_allowed=property != "colorScheme",
  )
}
