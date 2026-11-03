///|
test "real consumer display and busy cursor values serialize" {
  assert_eq(Display::InlineFlex.to_css(), "inline-flex")
  assert_eq(Display::InlineBlock.to_css(), "inline-block")
  assert_eq(Cursor::Wait.to_css(), "wait")
}
