///|
test "position fallback rejects non-descriptors duplicates and CSS injection" {
  let cases : Array[Array[@ir.PositionTryDescriptor]] = [
    [{ name: "anchor-name", value: "--anchor", }],
    [{ name: "color", value: "red", }],
    [{ name: "inset", value: "0", }, { name: "inset", value: "1px", }],
    [{ name: "margin", value: "0;}body{color:red", }],
  ]
  for descriptors in cases {
    let (globals, diagnostics) = compile_position_tries("position/invalid", [
      { name: "--invalid", descriptors, },
    ])
    assert_eq(globals, [])
    assert_eq(diagnostics.map(diagnostic => diagnostic.code), [
      "STYLE_POSITION_TRY_DESCRIPTOR",
    ])
  }
}
