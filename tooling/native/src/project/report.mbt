///|
pub fn diagnostic(
  code : String,
  message : String,
  severity~ : String = "error",
  file~ : Json = Json::null(),
) -> Json {
  {
    "code": code,
    "severity": severity,
    "file": file,
    "line": null,
    "column": null,
    "endLine": null,
    "endColumn": null,
    "symbol": null,
    "module": null,
    "artifactPath": null,
    "dependencyChain": [],
    "message": message,
    "help": null,
  }
}

///|
pub fn report(
  command : String,
  diagnostics : Array[Json],
  changed~ : Array[String] = [],
  dry_run~ : Bool = false,
  extraction~ : Json = Json::null(),
) -> Json {
  {
    "schemaVersion": 1,
    "command": command,
    "toolingVersion": version,
    "passed": !diagnostics.any(item => {
      @support.get(item, "severity") == Json("error")
    }),
    "dryRun": dry_run,
    "changedFiles": changed,
    "removedFiles": [],
    "diagnostics": diagnostics,
    "extraction": extraction,
  }
}

///|
pub fn failed_report(command : String, error : Error) -> Json {
  let (code, message) = match error {
    @support.ToolError(code, message) => (code, message)
    _ => ("STYLE_PROJECT", error.to_string())
  }
  report(command, [diagnostic(code, message)])
}

///|
pub fn render(
  value : Json,
  json~ : Bool = false,
  verbose~ : Bool = false,
) -> String raise {
  if json {
    return value.stringify(indent=2)
  }
  let command = @support.text(value, "command")
  let lines = [
    "moonstyle " +
    command +
    ": " +
    (if @support.flag(value, "passed") { "passed" } else { "failed" }),
  ]
  for file in @support.array(@support.get(value, "changedFiles")) {
    lines.push("changed " + @support.string(file))
  }
  for item in @support.array(@support.get(value, "diagnostics")) {
    let location = match @support.get(item, "file") {
      String(file) => " (" + file + ")"
      _ => ""
    }
    lines.push(
      @support.text(item, "severity") +
      " " +
      @support.text(item, "code") +
      location +
      ": " +
      @support.text(item, "message"),
    )
  }
  let extraction = @support.get(value, "extraction")
  if !(extraction is Null) {
    lines.push(
      "profile " +
      @support.text(extraction, "profile") +
      " · cache " +
      @support.text(extraction, "cacheStatus") +
      " · " +
      @support.get(@support.get(extraction, "timingsMs"), "totalMs").stringify() +
      " ms",
    )
    if verbose {
      lines.push(@support.get(extraction, "resolved").stringify(indent=2))
    }
  }
  lines.join("\n")
}

///|
pub fn build_records(
  stdout : String,
  stderr : String,
) -> (Array[String], Array[Json]) {
  let artifacts = []
  let diagnostics = []
  for line in (stdout + "\n" + stderr).split("\n") {
    let value = @json.parse(line.trim()) catch { _ => Json::null() }
    if @support.get(value, "artifacts_path") is Array(paths) {
      for path in paths {
        if path is String(path) {
          artifacts.push(path)
        }
      }
    }
    if @support.get(value, "$message_type") == Json("diagnostic") {
      let severity = if @support.get(value, "level") == Json("warning") {
        "warning"
      } else {
        "error"
      }
      let fields = match
        diagnostic(
          "MOON" + @support.get(value, "error_code").stringify(),
          match @support.get(value, "message") {
            String(message) => message
            _ => "Moon build failed"
          },
          severity~,
        ) {
        Object(fields) => fields
        _ => abort("diagnostic must be an object")
      }
      if @support.get(value, "loc") is String(location) &&
        re"^([0-9]+):([0-9]+)-([0-9]+):([0-9]+)$".execute(location[:])
        is Some(found) {
        fields["file"] = @support.get(value, "path")
        for index, key in ["line", "column", "endLine", "endColumn"] {
          fields[key] = @json.parse(found.group(index + 1).unwrap()) catch {
            _ => Json::null()
          }
        }
      }
      diagnostics.push(Json::object(fields))
    }
  }
  (artifacts, diagnostics)
}
