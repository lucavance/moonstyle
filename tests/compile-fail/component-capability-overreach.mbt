///|
fn accepts_layout(declarations : Array[@moonstyle.LayoutDeclaration]) -> Unit {
  ignore(declarations)
}

///|
fn component_capability_overreach() {
  accepts_layout([@properties.color(@values.rgb(1, 2, 3))])
}
