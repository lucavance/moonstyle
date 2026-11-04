///|
pub let version = "0.3.0"

///|
pub fn supported_version(value : String) -> Bool {
  // The current release accepts published 0.1.x / 0.2.x ownership metadata
  // and exactly 0.3.0. A later patch must never be silently downgraded.
  value == version || re"^0\.[12]\.[0-9]+$".execute(value[:]) is Some(_)
}

///|
pub let output_kinds : Array[String] = [
  "css", "mappings", "mappingsManifest", "bundle",
]

///|
pub fn package_name(value : String) -> Bool {
  let parts = value.split("/").collect()
  !parts.is_empty() &&
  parts.all(part => {
    part != "." &&
    part != ".." &&
    re"^[A-Za-z0-9][A-Za-z0-9._\-]*$".execute(part) is Some(_)
  })
}

///|
pub fn configuration(source : String) -> String {
  // Strip comments while retaining quoted strings and line locations.
  let output = StringBuilder()
  let mut quoted = false
  let mut escaped = false
  let mut line_comment = false
  let mut block_comment = false
  let mut index = 0
  while index < source.length() {
    let unit = source[index]
    let next = if index + 1 < source.length() {
      source[index + 1]
    } else {
      '\u0000'
    }
    if line_comment {
      if unit == '\n' {
        line_comment = false
        output.write_char('\n')
      } else {
        output.write_char(' ')
      }
    } else if block_comment {
      if unit == '*' && next == '/' {
        block_comment = false
        output.write_string("  ")
        index += 1
      } else {
        output.write_char(if unit == '\n' { '\n' } else { ' ' })
      }
    } else if !quoted && unit == '/' && next == '/' {
      line_comment = true
      output.write_string("  ")
      index += 1
    } else if !quoted && unit == '/' && next == '*' {
      block_comment = true
      output.write_string("  ")
      index += 1
    } else {
      output.write_view(source[index:index + 1])
      if quoted && escaped {
        escaped = false
      } else if quoted && unit == '\\' {
        escaped = true
      } else if unit == '"' {
        quoted = !quoted
      }
    }
    index += 1
  }
  output.to_string()
}

///|
pub async fn module_info(root : String) -> Json {
  let modern = root + "/moon.mod"
  let legacy = root + "/moon.mod.json"
  let value = if @fs.exists(modern) {
    let fields : Map[String, Json] = Map([])
    for raw in configuration(@support.read(modern)).split("\n") {
      if re"^[[:space:]]*(name|source|version)[[:space:]]*=[[:space:]]*\"([^\"]*)\"[[:space:]]*$".execute(
          raw,
        )
        is Some(found) {
        fields[found.group(1).unwrap().to_owned()] = Json(
          found.group(2).unwrap().to_owned(),
        )
      }
    }
    Json::object(fields)
  } else if @fs.exists(legacy) {
    @support.json(legacy)
  } else {
    @support.reject("STYLE_PROJECT_ROOT", "No MoonBit module in " + root)
  }
  guard package_name(@support.text(value, "name")) else {
    @support.reject("STYLE_PROJECT_MODULE", "Invalid MoonBit module name")
  }
  value
}

///|
pub async fn style_config(root : String) -> Json {
  let config = @support.json(root + "/style.config.json")
  @support.exact(
    config,
    [
      "schemaVersion", "mappingsPackage", "outputs", "dependencyRoots", "cacheDirectory",
    ],
    "style.config.json",
  )
  guard @support.get(config, "schemaVersion") == Json(1) &&
    package_name(@support.text(config, "mappingsPackage")) else {
    @support.reject(
      "STYLE_CONFIG", "Expected config schema 1 and a valid mappings package",
    )
  }
  let outputs = @support.get(config, "outputs")
  @support.exact(outputs, output_kinds, "outputs")
  let seen : Map[String, Bool] = Map([])
  let normalized : Map[String, Json] = Map([])
  for kind in output_kinds {
    let path = @support.project_path(root, @support.text(outputs, kind))
    guard !seen.contains(path) else {
      @support.reject("STYLE_CONFIG", "Output paths must be distinct")
    }
    seen[path] = true
    normalized[kind] = Json(path)
  }
  let roots = []
  for directory in @support.array(@support.get(config, "dependencyRoots")) {
    let path = @support.project_path(root, @support.string(directory))
    guard !roots.contains(Json(path)) else {
      @support.reject("STYLE_CONFIG", "Dependency roots must be unique")
    }
    roots.push(Json(path))
  }
  let cache = @support.project_path(
    root,
    @support.text(config, "cacheDirectory"),
  )
  for path in normalized.values() {
    let path = @support.string(path)
    guard path != cache && !path.has_prefix(cache + "/") else {
      @support.reject(
        "STYLE_CONFIG", "Outputs must be outside the cache directory",
      )
    }
    for directory in roots {
      let directory = @support.string(directory)
      guard path != directory && !path.has_prefix(directory + "/") else {
        @support.reject(
          "STYLE_CONFIG", "Outputs must be outside dependency roots",
        )
      }
    }
  }
  {
    "schemaVersion": 1,
    "mappingsPackage": @support.get(config, "mappingsPackage"),
    "outputs": Json::object(normalized),
    "dependencyRoots": roots,
    "cacheDirectory": cache,
  }
}

///|
pub async fn manifest(root : String, allow_v1~ : Bool = false) -> Json {
  let value = @support.json(root + "/.moonstyle.json")
  let schema = @support.get(value, "schemaVersion")
  guard schema == Json(2) || (schema == Json(1) && allow_v1) else {
    @support.reject(
      "STYLE_PROJECT_SCHEMA", "Project metadata requires v2; run moonstyle upgrade --dry-run, then moonstyle upgrade",
    )
  }
  @support.exact(
    value,
    if schema == Json(1) {
      [
        "schemaVersion", "toolingVersion", "stylesPackage", "extractorPackage", "managedFiles",
        "viteConfig", "entrypoints",
      ]
    } else {
      [
        "schemaVersion", "toolingVersion", "stylesPackage", "extractorPackage", "managedFiles",
      ]
    },
    ".moonstyle.json",
  )
  let tooling = @support.text(value, "toolingVersion")
  guard supported_version(tooling) else {
    @support.reject(
      "STYLE_PROJECT_VERSION", "Project metadata is newer than this tool or has an invalid version",
    )
  }
  guard package_name(@support.text(value, "stylesPackage")) else {
    @support.reject("STYLE_PROJECT_SCHEMA", "Invalid styles package")
  }
  ignore(@support.project_path(root, @support.text(value, "extractorPackage")))
  for path, digest in @support.fields(@support.get(value, "managedFiles")) {
    ignore(@support.project_path(root, path))
    guard digest is String(hash) &&
      re"^sha256:[0-9a-f]{64}$".execute(hash[:]) is Some(_) else {
      @support.reject(
        "STYLE_PROJECT_SCHEMA",
        "Invalid managed file hash: " + path,
      )
    }
  }
  value
}

///|
pub async fn dependency_bundles(root : String, config : Json) -> Array[String] {
  let bundles = []
  for directory in @support.array(@support.get(config, "dependencyRoots")) {
    let directory = @support.project_path(root, @support.string(directory))
    let path = @support.join(root, directory)
    guard @fs.exists(path) && @fs.kind(path) == @fs.Directory else {
      @support.reject(
        "STYLE_DEPENDENCY",
        "Dependency root is not a directory: " + directory,
      )
    }
    for file in @support.files(path) {
      if file.has_suffix(".bundle.json") && !bundles.contains(file) {
        ignore(@support.project_path(root, file[root.length() + 1:].to_owned()))
        bundles.push(file)
      }
    }
  }
  bundles.sort_by((a, b) => a.lexical_compare(b))
  bundles
}

///|
pub async fn workspace_paths(root : String) -> Array[String] {
  let paths = [root]
  let mut directory = root
  while directory != "" {
    let work = directory + "/moon.work"
    if @fs.exists(work) {
      let source = configuration(@support.read(work))
      guard re"members[[:space:]]*=[[:space:]]*\[([^\]]*)\]".execute(source[:])
        is Some(found) else {
        @support.reject("STYLE_WORKSPACE", "Cannot read moon.work members")
      }
      let list = found.group(1).unwrap()
      for item in re"\"((?:[^\"\\]|\\.)*)\"".find(list) {
        let path = @support.join(
          directory,
          @support.string(@json.parse(item.content())),
        )
        if @fs.exists(path) {
          let real = @fs.realpath(path)
          if !paths.contains(real) {
            paths.push(real)
          }
        }
      }
      break
    }
    let parent = @support.parent(directory)
    if directory == parent {
      break
    }
    directory = parent
  }
  paths
}
