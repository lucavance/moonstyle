///|
test "props applies the last style for the same compiled property key" {
  let base = compiled([
    ("color-key", "color-red"),
    ("display-key", "display-grid"),
  ])
  let override_ = compiled([("color-key", "color-green")])
  let applied = props([base, override_])
  assert_eq(applied.class_name, "color-green display-grid")
  assert_true(applied.inline_vars == [])
}

///|
test "none has no effect and inline variables override left to right" {
  let dynamic_a = compiled([], inline_vars=[("--x-width", "30%")])
  let dynamic_b = compiled([], inline_vars=[("--x-width", "70%")])
  let applied = props([none, dynamic_a, dynamic_b])
  assert_eq(applied.class_name, "")
  assert_true(applied.inline_vars == [("--x-width", "70%")])
}
