///|
fn content_type(path : String) -> String {
  if path.has_suffix(".html") {
    "text/html; charset=utf-8"
  } else if path.has_suffix(".js") {
    "text/javascript; charset=utf-8"
  } else if path.has_suffix(".css") {
    "text/css; charset=utf-8"
  } else if path.has_suffix(".json") || path.has_suffix(".map") {
    "application/json; charset=utf-8"
  } else if path.has_suffix(".svg") {
    "image/svg+xml"
  } else if path.has_suffix(".png") {
    "image/png"
  } else if path.has_suffix(".jpg") || path.has_suffix(".jpeg") {
    "image/jpeg"
  } else if path.has_suffix(".webp") {
    "image/webp"
  } else if path.has_suffix(".woff2") {
    "font/woff2"
  } else {
    "application/octet-stream"
  }
}

///|
pub fn request_path(path : String) -> String? {
  let path = path.split("?").next().unwrap_or("")
  if path.contains("%") ||
    path.contains("\\") ||
    !path.has_prefix("/") ||
    path.split("/").any(part => part == ".." || part.has_prefix(".")) {
    return None
  }
  let relative = path[1:].to_owned()
  Some(if relative == "" { "index.html" } else { relative })
}

///|
pub async fn serve(
  root : String,
  main_package~ : String = "src/demo",
  port~ : Int32 = 5173,
  host~ : String = "127.0.0.1",
) -> Unit {
  guard port >= 0 && port <= 65535 else {
    @support.reject("STYLE_USAGE", "Port must be between 0 and 65535")
  }
  let mut config = @project.style_config(root)
  let mut cache = @support.text(config, "cacheDirectory")
  let mut output = cache + "/site"
  let mut revision = 0
  let mut state = "rebuilding"
  let mut diagnostics : Array[Json] = []
  let mut manifest = Json::null()
  let refresh = async fn() -> Unit {
    state = "rebuilding"
    let mut next_config = config
    let mut next_cache = cache
    let report = try {
      next_config = @project.style_config(root)
      next_cache = @support.text(next_config, "cacheDirectory")
      build(root, main_package~, out_dir=next_cache + "/site", development=true)
    } catch {
      error =>
        if @async.is_being_cancelled() {
          raise error
        } else {
          @project.failed_report("build", error)
        }
    }
    diagnostics = @support.array(@support.get(report, "diagnostics"))
    if @support.flag(report, "passed") {
      config = next_config
      cache = next_cache
      output = cache + "/site"
      revision += 1
      state = "ready"
      manifest = debug_manifest(root, cache) catch { _ => Json::null() }
      @stdio.stdout.write(
        "[moonstyle] build-ready " + revision.to_string() + "\n",
      )
    } else {
      state = "stale"
      @stdio.stdout.write(@project.render(report) + "\n")
    }
  }
  let server = @http.Server(@socket.Addr::resolve(host, port~), reuse_addr=true)
  defer server.close()
  @stdio.stdout.write(
    "[moonstyle] dev-ready http://" + server.addr.to_string() + "\n",
  )
  let serve_request = async fn(
    request : @http.Request,
    _body,
    connection : @http.ServerConnection,
  ) -> Unit {
    let respond = async fn(code : Int32, mime : String, text : String) -> Unit {
      connection.send_response(
        code,
        if code == 200 {
          "OK"
        } else {
          "Not Found"
        },
        extra_headers=Map([
          (@http.CaseInsensitiveString("Content-Type"), mime),
          (@http.CaseInsensitiveString("Cache-Control"), "no-store"),
          (@http.CaseInsensitiveString("X-Content-Type-Options"), "nosniff"),
        ]),
      )
      if request.meth != @http.Head {
        connection.write_string(text)
      }
      connection.end_response()
    }
    if request.meth != @http.Get && request.meth != @http.Head {
      respond(405, "text/plain", "Method not allowed")
      return
    }
    if request.path == "/__moonstyle/status" {
      let status : Json = {
        "schemaVersion": 1,
        "revision": revision,
        "state": state,
        "diagnostics": diagnostics,
      }
      respond(200, "application/json", status.stringify())
      return
    }
    if request.path == "/__moonstyle/manifest" {
      respond(200, "application/json", manifest.stringify())
      return
    }
    guard request_path(request.path) is Some(relative) else {
      respond(404, "text/plain", "Not found")
      return
    }
    let relative_path = @support.project_path(root, output + "/" + relative) catch {
      _ => {
        respond(404, "text/plain", "Not found")
        return
      }
    }
    let path = root + "/" + relative_path
    if !@fs.exists(path) || @fs.kind(path) != @fs.Regular {
      respond(404, "text/plain", "Not found")
      return
    }
    connection.send_response(
      200,
      "OK",
      extra_headers=Map([
        (@http.CaseInsensitiveString("Content-Type"), content_type(relative)),
        (@http.CaseInsensitiveString("Cache-Control"), "no-store"),
        (@http.CaseInsensitiveString("X-Content-Type-Options"), "nosniff"),
      ]),
    )
    if request.meth != @http.Head {
      connection.write(@fs.read_file(path))
    }
    connection.end_response()
  }
  @async.with_task_group(async fn(group) {
    group.spawn_bg(async fn() {
      server.run_forever(serve_request, allow_failure=true)
    })
    let watchers : Array[@fs.Watcher] = []
    let mut roots : Array[String] = []
    defer (for watcher in watchers {
      watcher.close()
    })
    let sync_watchers = async fn() -> Unit {
      let next = @project.watch_roots(root) catch {
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
      for path in next {
        watchers.push(
          @fs.Watcher(
            path,
            debounce_timeout=60,
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
    while true {
      let identity = try {
        let template = root + "/index.html"
        let public_directory = root + "/public"
        let public_files = if @fs.exists(public_directory) {
          @support.files(public_directory)
        } else {
          []
        }
        let public_parts = []
        for file in public_files {
          public_parts.push(file + ":" + @support.file_hash(file))
        }
        @project.input_identity(root, config) +
        (if @fs.exists(template) { @support.file_hash(template) } else { "" }) +
        @support.hash(public_parts.join("\n"))
      } catch {
        error =>
          if @async.is_being_cancelled() {
            raise error
          } else {
            "unavailable"
          }
      }
      if identity != last_identity {
        last_identity = identity
        refresh()
        sync_watchers()
        continue
      }
      let waits = watchers.map(watcher => async fn() { watcher.wait_any() })
      ignore(@async.any(waits[:]))
    }
  })
}
