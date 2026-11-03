///|
test "Rabbita recoverable path preserves every dynamic error" {
  let first = @runtime.dynamic_value_error("--first", "STYLE_FIRST", "length")
  let second = @runtime.dynamic_value_error("--second", "STYLE_SECOND", "color")
  let invalid : Array[@runtime.StyleResult] = [Err([first]), Err([second])]
  match try_attrs(invalid) {
    Ok(_) => fail("invalid dynamic styles must not produce partial attrs")
    Err(errors) => assert_eq(errors, [first, second])
  }
}
