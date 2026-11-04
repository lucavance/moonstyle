///|
pub async fn build(
  root : String,
  package_ : String,
  target~ : String = "native",
  release~ : Bool = true,
) -> (Array[String], Array[Json]) {
  let args = [
      "run", package_, "--target", target, "--build-only", "--output-json",
    ] +
    (if release { ["--release"] } else { [] })
  let result = @shell.Cmd("moon", args, cwd=root).output()
  let (artifacts, diagnostics) = build_records(result.stdout(), result.stderr())
  if result.exit_code() != 0 {
    if !diagnostics.any(item => @support.get(item, "severity") == Json("error")) {
      diagnostics.push(
        diagnostic("MOON_BUILD", result.stdout() + result.stderr()),
      )
    }
  }
  (artifacts, diagnostics)
}

///|
pub async fn extract(
  root : String,
  check~ : Bool = false,
  debug~ : Bool = false,
  profile~ : String = "release",
) -> Json {
  let command = if check { "check" } else { "generate" }
  let start = @async.now()
  ignore(module_info(root))
  let manifest = manifest(root)
  let config = style_config(root)
  let bundles = dependency_bundles(root, config)
  let outputs = @support.get(config, "outputs")
  let before : Map[String, String?] = Map([])
  for kind in output_kinds {
    let path = root + "/" + @support.text(outputs, kind)
    before[kind] = if @fs.exists(path) {
      Some(@support.hash(@support.read(path)))
    } else {
      None
    }
  }
  let build_start = @async.now()
  let (artifacts, diagnostics) = build(
    root,
    @support.text(manifest, "extractorPackage"),
    release=profile == "release",
  )
  let built_at = @async.now()
  if diagnostics.any(item => @support.get(item, "severity") == Json("error")) {
    return report(command, diagnostics)
  }
  guard artifacts is [executable] else {
    @support.reject(
      "STYLE_TOOLCHAIN", "Expected exactly one native extractor artifact",
    )
  }
  let identity_parts = [
    @support.file_hash(executable),
    @support.canonical(config),
  ]
  for file in bundles {
    identity_parts.append([file, @support.file_hash(file)])
  }
  let identity = @support.hash(identity_parts.join("\n"))
  let args = [
    "--tooling-protocol",
    "1",
    "--diagnostics=json",
    "--mappings-package",
    @support.text(config, "mappingsPackage"),
    "--cache-dir",
    @support.text(config, "cacheDirectory"),
  ]
  for
    (kind, flag) in [
      ("css", "--css-output"),
      ("mappings", "--mappings-output"),
      ("mappingsManifest", "--mappings-manifest-output"),
      ("bundle", "--bundle-output"),
    ] {
    args.append([flag, @support.text(outputs, kind)])
  }
  for bundle in bundles {
    args.append(["--dependency-bundle", bundle])
  }
  if !check {
    for kind in output_kinds {
      @fs.mkdir(
        @support.parent(root + "/" + @support.text(outputs, kind)),
        recursive=true,
        allow_exist=true,
      )
    }
  }
  if check {
    args.push("--check")
  }
  if debug && !check {
    args.append([
      "--debug-manifest-output",
      @support.text(config, "cacheDirectory") + "/debug-manifest.json",
    ])
  }
  let result = @shell.Cmd(executable, args, cwd=root, env={
    "MOONSTYLE_CACHE_IDENTITY": identity,
  }).output()
  if result.exit_code() != 0 {
    let parsed = @json.parse(result.stdout().trim()) catch { _ => Json::null() }
    if parsed is Array(items) &&
      items.all(item => {
        @support.get(item, "severity") is String(_) &&
        @support.get(item, "message") is String(_)
      }) {
      diagnostics.append(items)
    } else {
      diagnostics.push(
        diagnostic("STYLE_EXTRACTOR", result.stdout() + result.stderr()),
      )
    }
  }
  let changed = []
  let output_details = []
  for kind in output_kinds {
    let relative = @support.text(outputs, kind)
    let path = root + "/" + relative
    let after = if @fs.exists(path) {
      Some(@support.hash(@support.read(path)))
    } else {
      None
    }
    let different = !check && after != before[kind]
    if different {
      changed.push(relative)
    }
    output_details.push(
      ({ "kind": kind, "path": relative, "changed": different } : Json),
    )
  }
  let finish = @async.now()
  let details : Json = {
    "mode": command,
    "profile": profile,
    "stage": "extract",
    "executed": true,
    "skipped": false,
    "cacheStatus": if result.stdout().contains("Cache hit") {
      "hit"
    } else if result.stdout().contains("without cache") {
      "disabled"
    } else {
      "miss"
    },
    "reasons": ["manual"],
    "identity": identity,
    "resolved": {
      "root": root,
      "workspaceRoots": workspace_paths(root),
      "extractorPackage": @support.get(manifest, "extractorPackage"),
      "mappingsPackage": @support.get(config, "mappingsPackage"),
      "cacheDirectory": @support.get(config, "cacheDirectory"),
      "dependencyBundles": bundles.map(path => {
        path[root.length() + 1:].to_owned()
      }),
      "outputs": outputs,
    },
    "outputs": output_details,
    "timingsMs": {
      "buildMs": (built_at - build_start).to_int(),
      "extractMs": (finish - built_at).to_int(),
      "totalMs": (finish - start).to_int(),
    },
  }
  report(command, diagnostics, changed~, extraction=details)
}

///|
pub async fn doctor(root : String, strict~ : Bool = false) -> Json {
  let manifest = manifest(root)
  ignore(module_info(root))
  let config = style_config(root)
  ignore(dependency_bundles(root, config))
  let diagnostics = []
  for path, digest in @support.fields(@support.get(manifest, "managedFiles")) {
    let target = root + "/" + path
    if !@fs.exists(target) ||
      Json(@support.hash(@support.read(target))) != digest {
      diagnostics.push(
        diagnostic(
          "STYLE_PROJECT_MODIFIED",
          "Managed file differs: " + path,
          file=Json(path),
        ),
      )
    }
  }
  let extractor = @support.text(manifest, "extractorPackage")
  for suffix in ["/main.mbt", "/moon.pkg"] {
    if !@fs.exists(root + "/" + extractor + suffix) {
      diagnostics.push(
        diagnostic(
          "STYLE_PROJECT_EXTRACTOR",
          "Missing extractor file: " + extractor + suffix,
        ),
      )
    }
  }
  for kind in output_kinds {
    let path = @support.text(@support.get(config, "outputs"), kind)
    if !@fs.exists(root + "/" + path) {
      diagnostics.push(
        diagnostic(
          "STYLE_PROJECT_OUTPUT",
          "Output has not been generated: " + path,
          severity=if strict { "error" } else { "warning" },
        ),
      )
    }
  }
  let bundle = root +
    "/" +
    @support.text(@support.get(config, "outputs"), "bundle")
  if @fs.exists(bundle) &&
    @support.get(@support.json(bundle), "schemaVersion") != Json(14) {
    diagnostics.push(
      diagnostic("STYLE_PROJECT_OUTPUT_SCHEMA", "Expected artifact schema v14"),
    )
  }
  if strict && diagnostics.is_empty() {
    let checked = @shell.Cmd(
      "moon",
      ["check", "--target", "native", "--output-json"],
      cwd=root,
    ).output()
    let (_, errors) = build_records(checked.stdout(), checked.stderr())
    diagnostics.append(errors)
    if checked.exit_code() != 0 && errors.is_empty() {
      diagnostics.push(
        diagnostic("MOON_CHECK", checked.stdout() + checked.stderr()),
      )
    }
    if !diagnostics.any(item => @support.get(item, "severity") == Json("error")) {
      let extracted = extract(root, check=true)
      diagnostics.append(@support.array(@support.get(extracted, "diagnostics")))
    }
  }
  report("doctor", diagnostics)
}
