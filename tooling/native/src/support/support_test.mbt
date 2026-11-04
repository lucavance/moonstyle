///|
test "paths reject lexical escape after normalization" {
  inspect(@support.normalize("a/../b/./c"), content="b/c")
  inspect(@support.normalize("../../outside"), content="../../outside")
  inspect(
    @support.join("/project", "styles/../output"),
    content="/project/output",
  )
  inspect(@support.parent("/project/file"), content="/project")
}

///|
test "canonical grammar JSON is stable across map orders" {
  let left : Json = { "z": 2, "a": [true, "x"] }
  let right : Json = { "a": [true, "x"], "z": 2 }
  assert_eq(@support.canonical(left), @support.canonical(right))
  inspect(
    @support.hash("abc"),
    content="sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}
