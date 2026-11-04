///|
test "CLI rejects ambiguous and command-specific options" {
  for
    args in [
      ["check", "--root"],
      ["check", "--root=x", "--root", "y"],
      ["check", "--json", "--verbose"],
      ["doctor", "--dry-run"],
      ["generate", "--json=true"],
    ] {
    let rejected = try {
      ignore(@cli.parse(args))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let (command, options) = @cli.parse(["upgrade", "--dry-run", "--root=project"])
  assert_eq(command, "upgrade")
  assert_eq(options["--root"], "project")
}
