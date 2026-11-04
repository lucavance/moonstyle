///|
test "configuration strips comments without changing quoted module names" {
  inspect(
    @project.configuration(
      "// name = \"fake/module\"\nname = \"actual/module\" // trailing\n/* block */",
    ),
    content="                       \nname = \"actual/module\"            \n           ",
  )
  assert_false(@project.package_name("app/../escape"))
  assert_true(@project.package_name("owner/app/styles"))
}

///|
async test "path validation rejects symlink escape" {
  let root = @fs.tmpdir(prefix="moonstyle-path-test-")
  let outside = @fs.tmpdir(prefix="moonstyle-outside-test-")
  defer @fs.rmdir(root, recursive=true)
  defer @fs.rmdir(outside, recursive=true)
  @fs.symlink(target=outside, root + "/link")
  let rejected = try {
    ignore(@support.project_path(root, "link/file"))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
async test "upgrade dry run and edited managed files preserve user contents" {
  let root = @fs.tmpdir(prefix="moonstyle-upgrade-test-")
  defer @fs.rmdir(root, recursive=true)
  @support.write(root + "/moon.mod", "name = \"local/app\"\n")
  let initial = @project.initialize(root)
  assert_true(@support.flag(initial, "passed"))
  let source = @support.read(root + "/.moonstyle.json")
  let fields = @support.copy(@json.parse(source))
  fields["schemaVersion"] = Json(1)
  fields["toolingVersion"] = Json("0.2.0")
  fields["viteConfig"] = Json("vite.config.mjs")
  fields["entrypoints"] = ["entry.mjs"]
  @support.write(
    root + "/.moonstyle.json",
    Json::object(fields).stringify(indent=2) + "\n",
  )
  let before = @support.read(root + "/.moonstyle.json")
  let preview = @project.initialize(root, upgrade=true, dry_run=true)
  assert_true(@support.flag(preview, "passed"))
  assert_eq(@support.read(root + "/.moonstyle.json"), before)
  ignore(@project.initialize(root, upgrade=true))
  assert_eq(@support.get(@project.manifest(root), "schemaVersion"), Json(2))
  @support.write(root + "/style_extractor/main.mbt", "// user edit\n")
  let rejected = try {
    ignore(@project.initialize(root, upgrade=true))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(@support.read(root + "/style_extractor/main.mbt"), "// user edit\n")
}

///|
async test "failed multi-file transaction restores installed files" {
  let root = @fs.tmpdir(prefix="moonstyle-transaction-test-")
  defer @fs.rmdir(root, recursive=true)
  @support.write(root + "/a", "original")
  // A parent which is a file causes staging to fail before replacement.
  @support.write(root + "/z", "blocker")
  let rejected = try {
    ignore(
      @project.transact(root, { "a": "replacement", "z/child": "cannot write" }),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(@support.read(root + "/a"), "original")
  assert_false(@fs.exists(root + "/.moonstyle.lock"))
  assert_eq(@fs.readdir(root, include_hidden=true, sort=true), ["a", "z"])
}
