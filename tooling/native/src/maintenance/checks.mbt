///|
pub fn manifest_field(source : String, name : String) -> String? {
  for line in source.split("\n") {
    let parts = line.split("=").map(part => part.trim().to_owned()).collect()
    if parts is [key, value] &&
      key == name &&
      value.has_prefix("\"") &&
      value.has_suffix("\"") {
      return Some(value[1:value.length() - 1].to_owned())
    }
  }
  None
}

///|
async fn snapshots(root : String, suffix : String) -> Map[String, String] {
  let result = Map([])
  for path in @support.files(root) {
    if path.has_suffix(suffix) {
      result[path[root.length() + 1:].to_owned()] = @support.hash(
        @support.read(path),
      )
    }
  }
  result
}

///|
pub async fn interfaces(root : String) -> Unit {
  let before = snapshots(root, "pkg.generated.mbti")
  ignore(@support.command("moon", ["info"], root))
  ignore(
    @support.command(
      "moon",
      ["-C", "tooling/native", "info", "--target", "native"],
      root,
    ),
  )
  let after = snapshots(root, "pkg.generated.mbti")
  guard before == after else {
    @support.reject(
      "STYLE_INTERFACES", "Public interfaces changed; review refreshed pkg.generated.mbti files",
    )
  }
  let native = root +
    "/_build/native/debug/check/lampclaw/moonstyle/extract/cli/cli.mbti"
  guard @fs.exists(native) &&
    @support.read(native) ==
    @support.read(root + "/src/extract/cli/pkg.generated.mbti") else {
    @support.reject("STYLE_INTERFACES", "Native extractor interface is stale")
  }
  println("Verified \{after.length()} interface snapshots.")
}

///|
pub async fn api_baseline(root : String, write~ : Bool = false) -> Unit {
  let modules : Map[String, Json] = Map([])
  for
    (name, directory) in [
      ("lampclaw/moonstyle", "src"),
      ("lampclaw/moonstyle-luna", "packages/moonstyle-luna"),
    ] {
    let files : Map[String, Json] = Map([])
    for
      filename, digest in snapshots(
        root + "/" + directory,
        "pkg.generated.mbti",
      ) {
      if !filename.has_prefix("tests/") {
        files[filename] = Json::string(digest)
      }
    }
    modules[name] = Json::object(files)
  }
  let version = if write {
    manifest_field(@support.read(root + "/moon.mod"), "version").unwrap()
  } else {
    "0.2.0"
  }
  let document : Json = {
    "schemaVersion": 2,
    "version": version,
    "modules": Json::object(modules),
  }
  let path = root + "/docs/api-baseline-" + version + ".json"
  if write {
    @support.write(path, document.stringify(indent=2) + "\n")
  } else {
    guard @support.json(path) == document else {
      @support.reject(
        "STYLE_API", "Public API differs from the published 0.2.0 baseline",
      )
    }
  }
}

///|
pub async fn toolchain(root : String) -> Unit {
  let expected = @support.get(@support.json(root + "/toolchain.json"), "tools")
  let actual = @json.parse(
    @support.command("moon", ["version", "--all", "--json"], root),
  )
  let items = @support.array(@support.get(actual, "items"))
  for (name, key) in [("moon", "moonCli"), ("moonc", "moonCompiler")] {
    let versions = items.filter(item => {
      @support.get(item, "name") == Json::string(name)
    })
    guard versions is [item] else {
      @support.reject("STYLE_TOOLCHAIN", "Missing version: " + name)
    }
    let version = @support.text(item, "version")
    let wanted = @support.text(expected, key)
    guard version.has_prefix(wanted) || version.has_prefix("v" + wanted) else {
      @support.reject(
        "STYLE_TOOLCHAIN",
        key + ": expected " + wanted + ", got " + version,
      )
    }
    if name == "moon" {
      guard version.contains(@support.text(expected, "moonRevision")) else {
        @support.reject("STYLE_TOOLCHAIN", "Moon revision differs")
      }
    }
  }
  let moon_home = @env.get_env_var("MOON_HOME").unwrap_or(
    @env.get_env_var("HOME").unwrap_or("") + "/.moon",
  )
  guard manifest_field(
      @support.read(moon_home + "/lib/core/moon.mod"),
      "version",
    ) ==
    Some(@support.text(expected, "moonCore")) else {
    @support.reject("STYLE_TOOLCHAIN", "Moon core version differs")
  }
  println("Native MoonBit toolchain matches toolchain.json.")
}

///|
pub async fn licenses(root : String) -> Unit {
  for prefix in ["", "packages/moonstyle-luna/"] {
    let license = @support.read(root + "/" + prefix + "LICENSE")
    let notice = @support.read(root + "/" + prefix + "NOTICE")
    guard license.contains("Copyright (c) Meta Platforms, Inc. and affiliates.") &&
      license.contains("MoonStyle contributors") &&
      license.contains("MIT License") &&
      license.contains("Permission is hereby granted") &&
      notice.contains("Upstream project: https://github.com/meta/stylex") else {
      @support.reject(
        "STYLE_LICENSE",
        "Missing MIT or StyleX attribution: " + prefix,
      )
    }
    if prefix != "" {
      guard license == @support.read(root + "/LICENSE") &&
        notice == @support.read(root + "/NOTICE") else {
        @support.reject("STYLE_LICENSE", "Luna attribution differs")
      }
    }
  }
  for
    manifest in [
      "moon.mod", "validation/moon.mod", "packages/moonstyle-luna/moon.mod", "tooling/native/moon.mod",
    ] {
    let content = @support.read(root + "/" + manifest)
    for entry in re"\"([^\"]+)@([0-9][^\"]*)\"".find(content[:]) {
      let name = entry.group(1).unwrap().to_owned()
      if name.has_prefix("lampclaw/") {
        continue
      }
      let dependency = root + "/.mooncakes/" + name + "/moon.mod"
      let json_dependency = dependency + ".json"
      guard @fs.exists(dependency) || @fs.exists(json_dependency) else {
        @support.reject("STYLE_LICENSE", "Missing dependency manifest: " + name)
      }
      let source = @support.read(
        if @fs.exists(dependency) {
          dependency
        } else {
          json_dependency
        },
      )
      let license = if source.trim_start().has_prefix("{") {
        @support.get(@json.parse(source), "license")
      } else {
        Json(manifest_field(source, "license").unwrap_or(""))
      }
      guard license is String(value) && value != "" else {
        @support.reject(
          "STYLE_LICENSE",
          "Unknown MoonBit dependency license: " + name,
        )
      }
    }
  }
  let snapshot = @support.get(
    @support.json(root + "/tools/data/css-inputs.json"),
    "payload",
  )
  for name, metadata in @support.fields(@support.get(snapshot, "sources")) {
    guard ["MIT", "CC0-1.0"].contains(@support.text(metadata, "license")) else {
      @support.reject("STYLE_LICENSE", "Unreviewed data license: " + name)
    }
  }
  println("MoonBit dependency licenses and upstream attributions verified.")
}

///|
pub async fn worktree(root : String) -> Unit {
  let status = @support.command(
    "git",
    ["status", "--porcelain=v1", "--untracked-files=all"],
    root,
  )
  guard status.trim().is_empty() else {
    @support.reject(
      "STYLE_WORKTREE",
      "Validation changed the worktree:\n" + status,
    )
  }
}

///|
pub async fn generated(root : String) -> Unit {
  let paths = [
    "src/properties/properties.mbt", "src/builder/rules.generated.mbt", "src/property-facade.generated.mbt",
    "src/properties/property-metadata.json", "src/properties/property-coverage.json",
    "src/core/application_order.generated.mbt", "src/core/application-order.lock.json",
    "src/values/common_inputs.generated.mbt", "src/builder/common_inputs.generated.mbt",
    "src/common_inputs.generated.mbt", "src/values/math_inputs.generated.mbt", "src/builder/math_inputs.generated.mbt",
    "src/math.generated.mbt", "src/builder/css_inputs.generated.mbt", "src/css_inputs.generated.mbt",
    "validation/src/generated/styles.generated.css", "validation/src/generated/styles.generated.mbt",
    "validation/src/generated/moon.pkg", "validation/src/generated/styles.bundle.json",
  ]
  let before = Map([])
  for path in paths {
    before[path] = @support.hash(@support.read(root + "/" + path))
  }
  @codegen.generate(root)
  application_order(root)
  ignore(
    @support.command("moon", ["run", "tools/generate-expressions.mbtx"], root),
  )
  // The build-styles launcher uses the native CLI once it is available.
  if @fs.exists(root + "/tools/build-styles.mbtx") {
    ignore(
      @support.command(
        "moon",
        ["run", "tools/build-styles.mbtx", "--styles-only"],
        root,
      ),
    )
  }
  for path in paths {
    guard before[path] == @support.hash(@support.read(root + "/" + path)) else {
      @support.reject("STYLE_GENERATED", "Generated output changed: " + path)
    }
  }
}
