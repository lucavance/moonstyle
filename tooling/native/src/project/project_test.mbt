///|
test "configuration strips comments without changing quoted module names" {
  assert_true(@project.supported_version("0.2.0"))
  assert_true(@project.supported_version("0.3.0"))
  assert_false(@project.supported_version("0.3.1"))
  assert_false(@project.supported_version("0.4.0"))
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
  let owned = @support.copy(@support.get(Json::object(fields), "managedFiles"))
  for path in ["vite.config.mjs", "entry.mjs"] {
    @support.write(root + "/" + path, "// retained application file\n")
    owned[path] = Json(@support.hash("// retained application file\n"))
  }
  fields["managedFiles"] = Json::object(owned)
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
  for path in ["vite.config.mjs", "entry.mjs"] {
    assert_false(
      @support.fields(@support.get(@project.manifest(root), "managedFiles")).contains(
        path,
      ),
    )
    assert_eq(
      @support.read(root + "/" + path),
      "// retained application file\n",
    )
  }
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
async test "invalid configuration cannot select overlapping or external outputs" {
  let root = @fs.tmpdir(prefix="moonstyle-config-test-")
  defer @fs.rmdir(root, recursive=true)
  @support.write(
    root + "/moon.mod",
    "name = \"local/config-app\"\nsource = \"src\"\n",
  )
  ignore(@project.initialize(root))
  let valid = @project.style_config(root)
  let variants = []
  let duplicate = @support.copy(valid)
  let outputs = @support.copy(@support.get(valid, "outputs"))
  outputs["css"] = @support.get(Json::object(outputs), "mappings")
  duplicate["outputs"] = Json::object(outputs)
  variants.push(Json::object(duplicate))
  let external = @support.copy(valid)
  let outputs = @support.copy(@support.get(valid, "outputs"))
  outputs["css"] = Json("../outside.css")
  external["outputs"] = Json::object(outputs)
  variants.push(Json::object(external))
  for
    (key, value) in [
      ("cacheDirectory", Json("src/generated")),
      ("dependencyRoots", Json(["src"])),
      ("unknownOption", Json(true)),
    ] {
    let fields = @support.copy(valid)
    fields[key] = value
    variants.push(Json::object(fields))
  }
  for value in variants {
    @support.write(root + "/style.config.json", value.stringify())
    let rejected = try {
      ignore(@project.style_config(root))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
    assert_false(@fs.exists(root + "/src/generated"))
  }
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

///|
async test "binary transaction preserves bytes and removes owned files" {
  let root = @fs.tmpdir(prefix="moonstyle-binary-test-")
  defer @fs.rmdir(root, recursive=true)
  @support.write(root + "/obsolete", "old asset")
  ignore(
    @project.transact_data(root, { "image.bin": b"\x00\xff\x80\x7f" }, remove=[
      "obsolete",
    ]),
  )
  assert_eq(@fs.read_file(root + "/image.bin").binary(), b"\x00\xff\x80\x7f")
  assert_false(@fs.exists(root + "/obsolete"))
}
