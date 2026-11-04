///|
fn number(value : Json, key : String) -> Int32 {
  match @support.get(value, key) {
    Number(value, ..) => value.to_int()
    _ => 0
  }
}

///|
fn vlq(value : Int32) -> String {
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let mut remaining = if value < 0 { (-value << 1) | 1 } else { value << 1 }
  let output = StringBuilder()
  while true {
    let digit = remaining & 31
    remaining = remaining >> 5
    let digit = if remaining > 0 { digit | 32 } else { digit }
    output.write_view(alphabet[digit:digit + 1])
    if remaining == 0 {
      break
    }
  }
  output.to_string()
}

///|
pub async fn debug_manifest(root : String, cache : String) -> Json {
  let manifest = @support.json(root + "/" + cache + "/debug-manifest.json")
  let roots = @project.workspace_paths(root)
  for key in ["rules", "globals"] {
    for entry in @support.array(@support.get(manifest, key)) {
      for origin in @support.array(@support.get(entry, "origins")) {
        if @support.get(origin, "source") is Object(source) {
          let file = @support.text(Json::object(source), "file")
          for directory in roots {
            let relative = @support.project_path(directory, file) catch {
              _ => continue
            }
            let absolute = directory + "/" + relative
            if @fs.exists(absolute) && @fs.kind(absolute) == @fs.Regular {
              source["absoluteFile"] = Json(absolute)
              break
            }
          }
        }
      }
    }
  }
  manifest
}

///|
pub fn source_map(css : String, manifest : Json) -> Json raise {
  let sources : Array[String] = []
  let starts = [0]
  for index = 0; index < css.length(); index = index + 1 {
    if css[index] == '\n' {
      starts.push(index + 1)
    }
  }
  let lines : Array[Array[(Int32, Int32, Int32, Int32)]] = Array::makei(
    starts.length(),
    _ => [],
  )
  let mut cursor = 0
  for
    entry in @support.array(@support.get(manifest, "globals")) +
    @support.array(@support.get(manifest, "rules")) {
    let fragment = @support.text(entry, "css")
    guard fragment != "" && css[cursor:].find(fragment[:]) is Some(relative) else {
      continue
    }
    let offset = cursor + relative
    cursor = offset + fragment.length()
    let origins = @support.array(@support.get(entry, "origins"))
    let same_module = origins.filter(origin => {
      @support.get(origin, "module") == @support.get(manifest, "module")
    })
    let mut source = Json::null()
    for origin in same_module + origins {
      let candidate = @support.get(origin, "source")
      if @support.get(candidate, "absoluteFile") is String(_) {
        source = candidate
        break
      }
    }
    guard @support.get(source, "absoluteFile") is String(file) else { continue }
    let source_index = match sources.search(file) {
      Some(index) => index
      None => {
        sources.push(file)
        sources.length() - 1
      }
    }
    let offsets = [offset]
    for index = 0; index < fragment.length() - 1; index = index + 1 {
      if fragment[index] == '\n' {
        offsets.push(offset + index + 1)
      }
    }
    for offset in offsets {
      let mut line = starts.length() - 1
      while starts[line] > offset {
        line -= 1
      }
      lines[line].push(
        (
          offset - starts[line],
          source_index,
          number(source, "line") - 1,
          number(source, "column") - 1,
        ),
      )
    }
  }
  let mut previous_source = 0
  let mut previous_line = 0
  let mut previous_column = 0
  let mappings = lines
    .map(line => {
      line.sort_by((a, b) => a.0.compare(b.0))
      let mut previous_generated = 0
      line
      .map(segment => {
        let encoded = [
            segment.0 - previous_generated,
            segment.1 - previous_source,
            segment.2 - previous_line,
            segment.3 - previous_column,
          ]
          .map(vlq)
          .join("")
        previous_generated = segment.0
        previous_source = segment.1
        previous_line = segment.2
        previous_column = segment.3
        encoded
      })
      .join(",")
    })
    .join(";")
  {
    "version": 3,
    "file": "styles.css",
    "sources": sources,
    "sourcesContent": sources.map(_ => ""),
    "names": [],
    "mappings": mappings,
  }
}
