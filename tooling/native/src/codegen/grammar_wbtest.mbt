///|
test "unsupported and unbounded grammar stays outside the safe tier" {
  assert_eq(
    grammar_reason(
      ({ "type": "Group", "combinator": "&&", "terms": [] } : Json),
    ),
    Some("unsupported-combinator-and"),
  )
  assert_eq(
    grammar_reason(
      (
        {
          "type": "Multiplier",
          "min": 1,
          "max": 0,
          "comma": false,
          "term": { "type": "Keyword", "name": "x" },
        } : Json),
    ),
    Some("unsupported-unbounded-repetition"),
  )
  assert_eq(
    grammar_reason(({ "type": "Type", "name": "length", "opts": null } : Json)),
    None,
  )
}

///|
test "closure traversal rejects cyclic grammar references" {
  let ast : Json = { "type": "Type", "name": "cycle", "opts": null }
  let types = {
    "cycle": ({ "name": "cycle", "syntax": "<cycle>", "ast": ast } : Json),
  }
  let rejected = try {
    ignore(grammar_closure(ast, types, Map([]), Map([])))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "border shorthand ordering preserves logical conflicts" {
  assert_eq(border_atomic("border", "border-side"), [
    "border-top-width", "border-top-style", "border-top-color", "border-inline-end-width",
    "border-inline-end-style", "border-inline-end-color", "border-bottom-width",
    "border-bottom-style", "border-bottom-color", "border-inline-start-width", "border-inline-start-style",
    "border-inline-start-color",
  ])
  assert_eq(border_atomic("border-inline-color", "border-colors"), [
    "border-inline-start-color", "border-inline-end-color",
  ])
}
