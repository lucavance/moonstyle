///|
pub async fn boundaries(root : String) -> Unit {
  let manifest = @support.read(root + "/moon.mod")
  guard manifest_field(manifest, "name") == Some("lampclaw/moonstyle") &&
    manifest_field(manifest, "source") == Some("src") &&
    !manifest.contains("lampclaw/moonstyle-validation") else {
    @support.reject(
      "STYLE_BOUNDARY", "The library must be the independent root source module",
    )
  }
  for file in ["package.json", "bun.lock"] {
    guard !@fs.exists(root + "/" + file) else {
      @support.reject(
        "STYLE_BOUNDARY",
        "Node dependencies must remain isolated: " + file,
      )
    }
  }
  for directory in ["examples", "cmd", "demo", "templates", "tools"] {
    guard !@fs.exists(root + "/src/" + directory) else {
      @support.reject(
        "STYLE_BOUNDARY",
        "Private tooling is inside the library source: " + directory,
      )
    }
  }
  for directory in ["core", "ir", "values", "properties", "builder"] {
    for file in @support.files(root + "/src/" + directory) {
      if !file.has_suffix(".mbt") &&
        !file.has_suffix(".mbti") &&
        !file.has_suffix("moon.pkg") {
        continue
      }
      let source = @support.read(file)
      for
        forbidden in [
          "lampclaw/moonstyle-validation", "extern \"js\"", "moonbit-community/rabbita",
          "moonbitlang/async",
        ] {
        guard !source.contains(forbidden) else {
          @support.reject(
            "STYLE_BOUNDARY",
            "Semantic package depends on a host: " + file + ": " + forbidden,
          )
        }
      }
    }
  }
  let packaged = @shell.Cmd("moon", ["package", "--list"], cwd=root).output()
  packaged.check()
  let listing = packaged.stdout() + "\n" + packaged.stderr()
  let paths = listing.split("\n").map(path => path.trim().to_owned()).collect()
  for file in ["moon.mod", "LICENSE", "NOTICE", "src/moon.pkg"] {
    guard paths.contains(file) else {
      @support.reject("STYLE_BOUNDARY", "Missing public archive file: " + file)
    }
  }
  for path in paths {
    for
      prefix in [
        "validation/", "packages/", "tooling/", "tools/", "verification/", "node_modules/",
      ] {
      guard !path.has_prefix(prefix) else {
        @support.reject(
          "STYLE_BOUNDARY",
          "Private workspace content leaked into the library archive: " + path,
        )
      }
    }
  }
  println("Library boundaries and publication archive verified.")
}
