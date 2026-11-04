///|
pub fn relevant(path : String, root : String, config : Json) -> Bool {
  let path = @support.normalize(path)
  for
    name in [
      "/.git/", "/.mooncakes/", "/node_modules/", "/_build/", "/dist/", "/.cache/",
    ] {
    if path.contains(name) {
      return false
    }
  }
  if !(config is Null) {
    if @support.get(config, "outputs") is Object(outputs) {
      for value in outputs.values() {
        if value is String(relative) && path == @support.join(root, relative) {
          return false
        }
      }
    }
    if @support.get(config, "cacheDirectory") is String(cache) &&
      (
        path == @support.join(root, cache) ||
        path.has_prefix(@support.join(root, cache) + "/")
      ) {
      return false
    }
  }
  let name = path.split("/").collect().last().unwrap_or("")
  path.has_suffix(".mbt") ||
  path.has_suffix(".mbti") ||
  path.has_suffix(".bundle.json") ||
  [
    "moon.mod", "moon.mod.json", "moon.pkg", "moon.pkg.json", "moon.work", ".moonstyle.json",
    "style.config.json",
  ].contains(name.to_owned())
}

///|
pub async fn watch_roots(root : String) -> Array[String] {
  let paths = workspace_paths(root)
  let roots = []
  for path in paths {
    if !paths.any(other => path != other && path.has_prefix(other + "/")) {
      roots.push(path)
    }
  }
  roots
}

///|
pub async fn input_identity(root : String, config : Json) -> String {
  let paths = workspace_paths(root)
  let parts = []
  let seen : Map[String, Bool] = Map([])
  for directory in paths {
    for file in @support.files(directory) {
      if relevant(file, root, config) && !seen.contains(file) {
        seen[file] = true
        parts.push(file + ":" + @support.file_hash(file))
      }
    }
  }
  parts.sort_by((a, b) => a.lexical_compare(b))
  @support.hash(parts.join("\n"))
}

///|
pub async fn watch(root : String, emit : async (Json) -> Unit) -> Unit {
  let mut sequence = 0
  defer @async.protect_from_cancel(async fn() {
    emit(
      (
        {
          "schemaVersion": 1,
          "event": "watch-stop",
          "command": "watch",
          "toolingVersion": version,
          "sequence": sequence,
          "signal": "cancelled",
          "passed": true,
        } : Json),
    )
  })
  emit(
    (
      {
        "schemaVersion": 1,
        "event": "watch-start",
        "command": "watch",
        "toolingVersion": version,
        "root": root,
      } : Json),
  )
  let mut config = style_config(root) catch { _ => Json::null() }
  let mut roots : Array[String] = []
  let watchers : Array[@fs.Watcher] = []
  defer (for watcher in watchers {
    watcher.close()
  })
  let sync_watchers = async fn() -> Unit {
    let next = watch_roots(root) catch {
      error =>
        if @async.is_being_cancelled() {
          raise error
        } else if roots.is_empty() {
          [root]
        } else {
          roots
        }
    }
    if roots == next {
      return
    }
    for watcher in watchers {
      watcher.close()
    }
    watchers.clear()
    for directory in next {
      watchers.push(
        @fs.Watcher(
          directory,
          debounce_timeout=50,
          max_debounce_delay=250,
          report_child_event=true,
          ignored_paths=path => {
            [
              "/.git", "/.mooncakes", "/node_modules", "/_build", "/dist", "/.cache",
            ].any(part => path.contains(part))
          },
        ),
      )
    }
    roots = next
  }
  sync_watchers()
  let mut last_identity = ""
  let mut initial = true
  while true {
    let identity = input_identity(root, config) catch {
      error =>
        if @async.is_being_cancelled() {
          raise error
        } else {
          "unavailable"
        }
    }
    if initial || identity != last_identity {
      last_identity = identity
      let outcome = extract(root, profile="debug") catch {
        error =>
          if @async.is_being_cancelled() {
            raise error
          } else {
            failed_report("watch", error)
          }
      }
      let fields = @support.copy(outcome)
      fields["command"] = Json("watch")
      fields["event"] = Json("watch-cycle")
      sequence += 1
      fields["sequence"] = Json(sequence)
      emit(Json::object(fields))
      config = style_config(root) catch { _ => config }
      // Retain the pre-build identity so edits made during compilation trigger
      // another cycle. Generated outputs are already excluded by relevant().
      initial = false
      sync_watchers()
      continue
    }
    let waits = watchers.map(watcher => async fn() { watcher.wait_any() })
    ignore(@async.any(waits[:]))
  }
}
