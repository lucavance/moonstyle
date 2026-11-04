///|
test "budget uses paired distributions and rejects invalid samples" {
  let timings = paired([10.0, 10.0, 12.0, 10.0], [10.0, 11.0, 10.0, 10.0])
  assert_true(@support.flag(budget("small", timings), "met"))
  assert_false(@support.flag(budget("medium", timings), "met"))
  assert_true(@support.flag(budget("large", paired([30.0], [5.0])), "met"))
  assert_eq(numeric(summary([1.0, 3.0, 2.0, 4.0]), "medianMs"), 2.5)
  let rejected = try {
    ignore(paired([0.0], [1.0]))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "development budget requires formal output parity" {
  assert_true(
    @support.flag(dx_budget(100.0, 1000.0, 20.0, 5.0, 10.0, true), "met"),
  )
  assert_false(
    @support.flag(dx_budget(100.0, 1000.0, 20.0, 5.0, 10.0, false), "met"),
  )
  assert_false(
    @support.flag(dx_budget(800.0, 1000.0, 20.0, 5.0, 10.0, true), "met"),
  )
}
