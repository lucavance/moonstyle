///|
/// Stage the full transaction before installing any file; restore backups on failure.
pub async fn transact(
  root : String,
  writes : Map[String, String],
  dry_run~ : Bool = false,
) -> Array[String] {
  let bytes = Map([])
  for path, value in writes {
    bytes[path] = @utf8.encode(value)
  }
  transact_data(root, bytes, dry_run~)
}

///|
pub async fn transact_data(
  root : String,
  writes : Map[String, Bytes],
  dry_run~ : Bool = false,
  remove~ : Array[String] = [],
) -> Array[String] {
  let changed = []
  for path, content in writes {
    ignore(@support.project_path(root, path))
    let target = root + "/" + path
    if !@fs.exists(target) || @fs.read_file(target).binary() != content {
      changed.push(path)
    }
  }
  for path in remove {
    ignore(@support.project_path(root, path))
    guard !writes.contains(path) else {
      @support.reject(
        "STYLE_TRANSACTION", "Cannot write and remove the same file",
      )
    }
    if @fs.exists(root + "/" + path) && !changed.contains(path) {
      changed.push(path)
    }
  }
  changed.sort_by((a, b) => a.lexical_compare(b))
  if dry_run || changed.is_empty() {
    return changed
  }
  let lock_path = root + "/.moonstyle.lock"
  let lock = @fs.open(lock_path, mode=@fs.WriteOnly, create_mode=@fs.CreateNew)
  defer lock.close()
  defer @fs.remove(lock_path)
  let nonce = ".moonstyle-" + @env.now().to_string()
  let staged = []
  let backed_up = []
  let installed = []
  {
    errdefer @async.protect_from_cancel(async fn() {
      for target in installed.rev() {
        if @fs.exists(target) {
          @fs.remove(target)
        }
      }
      for target in backed_up.rev() {
        if @fs.exists(target + nonce + ".bak") {
          @fs.rename(target + nonce + ".bak", target, replace=true)
        }
      }
      for target in staged {
        if @fs.exists(target + nonce + ".tmp") {
          @fs.remove(target + nonce + ".tmp")
        }
      }
    })
    for path in changed {
      let target = root + "/" + path
      if writes.get(path) is Some(content) {
        @fs.mkdir(@support.parent(target), recursive=true, allow_exist=true)
        @fs.write_file(target + nonce + ".tmp", content)
        staged.push(target)
      }
    }
    for path in changed {
      ignore(@support.project_path(root, path))
      let target = root + "/" + path
      if @fs.exists(target) {
        @fs.rename(target, target + nonce + ".bak")
        backed_up.push(target)
      }
      if writes.contains(path) {
        @fs.rename(target + nonce + ".tmp", target)
        installed.push(target)
      }
    }
  }
  for target in backed_up {
    @fs.remove(target + nonce + ".bak")
  }
  changed
}

///|
fn desired_files(extractor : String, styles : String) -> Map[String, String] {
  Map([
    (
      extractor + "/main.mbt",
      "///|\nfn main {\n  @cli.run(@styles.registry())\n}\n",
    ),
    (
      extractor + "/moon.pkg",
      "import {\n  " +
      @support.quote(styles) +
      (if styles.has_suffix("/styles") { "" } else { " @styles" }) +
      ",\n  \"lampclaw/moonstyle/extract/cli\",\n}\n\npkgtype(kind: \"executable\")\n\nsupported_targets = \"native\"\n",
    ),
    (
      ".vscode/tasks.json", "{\n  \"version\": \"2.0.0\",\n  \"tasks\": [\n    { \"label\": \"MoonStyle: generate\", \"type\": \"shell\", \"command\": \"moonstyle generate\", \"problemMatcher\": [] },\n    { \"label\": \"MoonStyle: check\", \"type\": \"shell\", \"command\": \"moonstyle check\", \"problemMatcher\": [] },\n    { \"label\": \"MoonStyle: watch\", \"type\": \"shell\", \"command\": \"moonstyle watch\", \"problemMatcher\": [] }\n  ]\n}\n",
    ),
  ])
}

///|
pub async fn initialize(
  root : String,
  styles~ : String? = None,
  extractor~ : String? = None,
  upgrade~ : Bool = false,
  dry_run~ : Bool = false,
) -> Json {
  let module_ = module_info(root)
  let source = match @support.get(module_, "source") {
    String(path) if path != "" && path != "." =>
      @support.project_path(root, path) + "/"
    _ => ""
  }
  let exists = @fs.exists(root + "/.moonstyle.json")
  let previous = if exists {
    manifest(root, allow_v1=upgrade)
  } else {
    Json::null()
  }
  let styles = styles.unwrap_or(
    match @support.get(previous, "stylesPackage") {
      String(value) => value
      _ => @support.text(module_, "name") + "/styles"
    },
  )
  let extractor = @support.project_path(
    root,
    extractor.unwrap_or(
      match @support.get(previous, "extractorPackage") {
        String(value) => value
        _ => source + "style_extractor"
      },
    ),
  )
  guard package_name(styles) else {
    @support.reject("STYLE_PROJECT_USAGE", "Invalid --styles-package")
  }
  if exists {
    guard @support.text(previous, "stylesPackage") == styles &&
      @support.text(previous, "extractorPackage") == extractor else {
      @support.reject(
        "STYLE_PROJECT_CONFLICT", "Explicit settings differ from project metadata",
      )
    }
  }
  let managed = if exists {
    @support.copy(@support.get(previous, "managedFiles"))
  } else {
    Map([])
  }
  if @support.get(previous, "schemaVersion") == Json(1) {
    if @support.get(previous, "viteConfig") is String(path) {
      ignore(managed.remove(path))
    }
    if @support.get(previous, "entrypoints") is Array(entries) {
      for entry in entries {
        if entry is String(path) {
          ignore(managed.remove(path))
        }
      }
    }
  }
  let writes : Map[String, String] = Map([])
  let diagnostics = []
  for path, desired in desired_files(extractor, styles) {
    ignore(@support.project_path(root, path))
    let file = root + "/" + path
    let current = if @fs.exists(file) {
      Some(@support.read(file))
    } else {
      None
    }
    let owned = match (managed.get(path), current) {
      (Some(String(digest)), Some(content)) => @support.hash(content) == digest
      (Some(_), None) => true
      _ => false
    }
    if current is None || owned || current == Some(desired) {
      writes[path] = desired
      managed[path] = Json(@support.hash(desired))
    } else if managed.contains(path) {
      @support.reject(
        "STYLE_PROJECT_MODIFIED",
        "Managed file was edited; preserved: " + path,
      )
    } else {
      diagnostics.push(
        diagnostic(
          "STYLE_PROJECT_UNMANAGED",
          "Existing file remains user-owned: " + path,
          severity="warning",
          file=Json(path),
        ),
      )
    }
  }
  if !@fs.exists(root + "/style.config.json") {
    let config : Json = {
      "schemaVersion": 1,
      "mappingsPackage": @support.text(module_, "name") + "/generated",
      "outputs": {
        "css": source + "generated/styles.generated.css",
        "mappings": source + "generated/styles.generated.mbt",
        "mappingsManifest": source + "generated/moon.pkg",
        "bundle": source + "generated/styles.bundle.json",
      },
      "dependencyRoots": [],
      "cacheDirectory": "_build/style-cache",
    }
    writes["style.config.json"] = config.stringify(indent=2) + "\n"
  } else {
    ignore(style_config(root))
  }
  let next : Json = {
    "schemaVersion": 2,
    "toolingVersion": version,
    "stylesPackage": styles,
    "extractorPackage": extractor,
    "managedFiles": Json::object(managed),
  }
  writes[".moonstyle.json"] = next.stringify(indent=2) + "\n"
  let changed = transact(root, writes, dry_run~)
  report(
    if upgrade {
      "upgrade"
    } else {
      "init"
    },
    diagnostics,
    changed~,
    dry_run~,
  )
}
