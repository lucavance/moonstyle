///|
test "SVG recoverable composition preserves every dynamic error" {
  let first = @runtime.dynamic_value_error("--first", "STYLE_FIRST", "color")
  let second = @runtime.dynamic_value_error("--second", "STYLE_SECOND", "color")
  let valid : @runtime.StyleResult = Ok(
    @runtime.compiled_v5([("fill", Some("paint-class"))]),
  )
  let invalid : Array[@runtime.StyleResult] = [
    valid,
    Err([first]),
    Err([second]),
  ]
  match try_svg_attrs(invalid) {
    Ok(_) => fail("invalid values cannot produce partial SVG attrs")
    Err(errors) => assert_eq(errors, [first, second])
  }
}
