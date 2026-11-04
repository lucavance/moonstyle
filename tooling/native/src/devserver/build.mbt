///|
async fn client(root : String, cache : String) -> String {
  let identity = @support.hash(
    browser_source +
    @support.command("moon", ["version", "--all", "--json"], root),
  )
  let path = root +
    "/" +
    cache +
    "/browser-" +
    identity[7:23].to_owned() +
    ".js"
  if @fs.exists(path) {
    return @support.read(path)
  }
  let temporary = @fs.tmpdir(prefix="moonstyle-browser-")
  defer @fs.rmdir(temporary, recursive=true)
  @support.write(
    temporary + "/moon.mod",
    "name = \"local/moonstyle-dev-client\"\npreferred_target = \"js\"\n",
  )
  @support.write(
    temporary + "/moon.pkg",
    "import { \"moonbitlang/core/json\" }\noptions(\"is-main\": true)\nsupported_targets = \"js\"\n",
  )
  @support.write(temporary + "/main.mbt", browser_source)
  let (paths, diagnostics) = @project.build(temporary, ".", target="js")
  guard !diagnostics.any(item => @support.get(item, "severity") == Json("error")) &&
    paths is [artifact] else {
    @support.reject("STYLE_DEV_CLIENT", Json::array(diagnostics).stringify())
  }
  let source = @support.read(artifact)
  @support.write(path, source)
  source
}

///|
pub async fn build(
  root : String,
  main_package~ : String = "src/demo",
  out_dir~ : String = "dist",
  development~ : Bool = false,
) -> Json {
  let output = @support.project_path(root, out_dir)
  let main_package = @support.project_path(root, main_package)
  guard output != "public" &&
    !output.has_prefix("public/") &&
    output != main_package &&
    !main_package.has_prefix(output + "/") else {
    @support.reject(
      "STYLE_BUILD_PATH", "Build output must be separate from public assets and the main package",
    )
  }
  let config = @project.style_config(root)
  let extraction = @project.extract(
    root,
    debug=development,
    profile=if development { "debug" } else { "release" },
  )
  if !@support.flag(extraction, "passed") {
    return extraction
  }
  let (artifacts, diagnostics) = @project.build(
    root,
    main_package,
    target="js",
    release=!development,
  )
  if diagnostics.any(item => @support.get(item, "severity") == Json("error")) {
    return @project.report("build", diagnostics)
  }
  let scripts = artifacts.filter(path => path.has_suffix(".js"))
  guard scripts is [script] else {
    @support.reject(
      "STYLE_BUILD", "Expected one JavaScript application artifact",
    )
  }
  let index_path = root + "/index.html"
  let template = if @fs.exists(index_path) {
    @support.read(index_path)
  } else {
    "<!doctype html>\n<html><head><meta charset=\"utf-8\"><title>MoonStyle</title><!-- moonstyle-assets --></head><body><div id=\"app\"></div></body></html>\n"
  }
  guard template.contains("<!-- moonstyle-assets -->") else {
    @support.reject(
      "STYLE_BUILD_HTML", "Add <!-- moonstyle-assets --> to index.html at the stylesheet/script insertion point",
    )
  }
  let prefix = output + "/"
  let writes : Map[String, Bytes] = Map([])
  writes[prefix + "app.js"] = @fs.read_file(script).binary()
  let css = @support.read(
    root + "/" + @support.text(@support.get(config, "outputs"), "css"),
  )
  writes[prefix + "styles.css"] = @utf8.encode(
    css +
    (if development {
      "\n/*# sourceMappingURL=styles.css.map */\n"
    } else {
      ""
    }),
  )
  let assets = "<link rel=\"stylesheet\" href=\"./styles.css\">\n<script type=\"module\" src=\"./app.js\"></script>" +
    (if development {
      "\n<script type=\"module\" src=\"./dev-client.js\"></script>"
    } else {
      ""
    })
  writes[prefix + "index.html"] = @utf8.encode(
    template.replace_all(old="<!-- moonstyle-assets -->", new=assets),
  )
  if development {
    let cache = @support.text(config, "cacheDirectory")
    writes[prefix + "dev-client.js"] = @utf8.encode(client(root, cache))
    writes[prefix + "styles.css.map"] = @utf8.encode(
      source_map(css, debug_manifest(root, cache)).stringify(),
    )
  }
  let public_directory = root + "/public"
  if @fs.exists(public_directory) {
    for file in @support.files(public_directory) {
      let name = file[public_directory.length() + 1:].to_owned()
      guard ![
        "index.html", "app.js", "styles.css", "styles.css.map", "dev-client.js",
      ].contains(name) else {
        @support.reject(
          "STYLE_BUILD_ASSET",
          "Public asset collides with a generated file: " + name,
        )
      }
      writes[prefix + name] = @fs.read_file(file).binary()
    }
  }
  let ownership_path = @support.text(config, "cacheDirectory") +
    "/web-output-" +
    @support.hash(output)[7:23].to_owned() +
    ".json"
  let previous = @support.json(root + "/" + ownership_path) catch {
    _ => Json::null()
  }
  let remove = if development {
    []
  } else {
    [prefix + "dev-client.js", prefix + "styles.css.map"]
  }
  if previous is Object(entries) {
    for file, digest in entries {
      if file.has_prefix(prefix) &&
        !writes.contains(file) &&
        !remove.contains(file) {
        ignore(@support.project_path(root, file))
        if @fs.exists(root + "/" + file) &&
          Json(@support.file_hash(root + "/" + file)) == digest {
          remove.push(file)
        }
      }
    }
  }
  let ownership : Map[String, Json] = Map([])
  for file, bytes in writes {
    ownership[file] = Json(@support.hash_bytes(bytes))
  }
  writes[ownership_path] = @utf8.encode(Json::object(ownership).stringify())
  let changed = @project.transact_data(root, writes, remove~)
  @project.report("build", diagnostics, changed~)
}
