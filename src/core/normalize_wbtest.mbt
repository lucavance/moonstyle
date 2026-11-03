///|
test "CSS normalization preserves URL payloads and quoted text" {
  let cases = [
    ("url(0.5x.png)", "url(0.5x.png)"),
    ("url(\"0.5x.png\")", "url(\"0.5x.png\")"),
    ("URL(/img/v0.5/logo.png)", "URL(/img/v0.5/logo.png)"),
    (
      "Url(https://cdn.example/v0.5/hero.png?scale=0.5#v0.5)", "Url(https://cdn.example/v0.5/hero.png?scale=0.5#v0.5)",
    ),
    ("url(  '0.5 x.png'  )", "url(  '0.5 x.png'  )"),
    ("url(data:image/svg+xml,a,  0.5)", "url(data:image/svg+xml,a,  0.5)"),
    ("url(a\\)0.5.png) 0.5em", "url(a\\)0.5.png) .5em"),
    ("url(\"a)0.5.png\") 0.5em", "url(\"a)0.5.png\") .5em"),
    ("url(\"a\\\"0.5.png\") 0.5em", "url(\"a\\\"0.5.png\") .5em"),
    (
      "image-set(url(0.5x.png) 1x, URL(1x.png) 2x)", "image-set(url(0.5x.png) 1x,URL(1x.png) 2x)",
    ),
    ("url(0s-0px-0.5.svg) 0px 0.5em", "url(0s-0px-0.5.svg) 0px .5em"),
    ("URL(/cursors/0.5.cur), pointer", "URL(/cursors/0.5.cur),pointer"),
    ("\"version 0.5,  0.25\"", "\"version 0.5,  0.25\""),
    ("'a\\'0.5' 0.5", "'a\\'0.5' .5"),
    ("\"url(0.5)\" 0.5", "\"url(0.5)\" .5"),
  ]
  for (input, expected) in cases {
    assert_eq(canonical_css_value(input), expected, msg=input)
    assert_eq(canonical_css_value(expected), expected, msg=input)
  }
}

///|
test "opaque CSS spans do not disable ordinary numeric normalization" {
  for
    (input, expected) in [
      (" rgba(30, 45, 60, 0.12) ", "rgba(30,45,60,.12)"),
      ("calc(0px + 0.5em)", "calc(0px + .5em)"),
      ("10.5px -0.5em 0.5%", "10.5px -.5em .5%"),
      ("myurl(0.5) --url(0.5)", "myurl(.5) --url(.5)"),
      ("éurl(0.5)", "éurl(.5)"),
      ("url(0.5.png) url(0.5.svg)", "url(0.5.png) url(0.5.svg)"),
    ] {
    assert_eq(canonical_css_value(input), expected, msg=input)
    assert_eq(canonical_css_value(expected), expected, msg=input)
  }
}
