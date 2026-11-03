///|
test "Luna attrs preserve classes and inline dynamic variables" {
  let style = @runtime.compiled_v5([("color", Some("xcolor"))], inline_vars=[
    ("--progress", "42%"),
  ])
  let applied = @runtime.props([style])
  let node = @luna.div(attrs=attrs_applied(applied), [@luna.text("MoonBit")])
  let html = @luna.render(node)
  assert_true(html.contains("class=\"xcolor\""))
  assert_true(html.contains("style=\"--progress:42%\""))
}
