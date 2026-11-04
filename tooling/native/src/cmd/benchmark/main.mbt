///|
async fn main {
  let args = @env.args()[1:].to_owned()
  guard args.length() >= 1 else { fail("Expected repository root") }
  let root = @fs.realpath(args[0])
  if args.get(1) == Some("--dx") {
    @bench.dx(root)
  } else if args.get(1) == Some("--audit") {
    @bench.audit(root)
  } else {
    guard args.length() == 1 || (args.length() == 3 && args[1] == "--output") else {
      fail(
        "Usage: benchmark <root> [--output benchmarks/<file>.json|--dx|--audit]",
      )
    }
    @bench.measure(root, args.get(2))
  }
}
