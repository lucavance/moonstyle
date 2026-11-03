///|
test "priority specificity precedes pseudo-elements and covers every selector branch" {
  let suffix = ":not(#\\#)"
  assert_eq(
    with_priority_specificity(".x::before{content:\"a\"}", 200000),
    ".x" + suffix + "::before{content:\"a\"}",
  )
  assert_eq(
    with_priority_specificity(
      "@media (width > 1px){.x:hover::after{color:red}}", 200000,
    ),
    "@media (width > 1px){.x:hover" + suffix + "::after{color:red}}",
  )
  assert_eq(
    with_priority_specificity(
      ".x:is(:hover,:focus),.x[data-note='::,']::before{color:red}", 200000,
    ),
    ".x:is(:hover,:focus)" +
    suffix +
    ",.x[data-note='::,']" +
    suffix +
    "::before{color:red}",
  )
}
