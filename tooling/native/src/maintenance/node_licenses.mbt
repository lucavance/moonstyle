///|
async fn installed(
  directory : String,
  seen : Map[String, Bool],
  packages : Map[String, Json],
  compiler~ : Bool = false,
) -> Unit {
  if !@fs.exists(directory) {
    @support.reject(
      "STYLE_LICENSE",
      "Install the isolated dependencies: " + directory,
    )
  }
  for name in @fs.readdir(directory, sort=true) {
    if name.has_prefix(".") {
      continue
    }
    let path = directory + "/" + name
    if @fs.kind(path) != @fs.Directory {
      continue
    }
    if name.has_prefix("@") {
      installed(path, seen, packages, compiler~)
      continue
    }
    let real = @fs.realpath(path)
    if seen.contains(real) {
      continue
    }
    seen[real] = true
    if !@fs.exists(path + "/package.json") {
      continue
    }
    let manifest = @support.json(path + "/package.json")
    let package_name = @support.text(manifest, "name")
    if !compiler &&
      (
        ["@babel/core", "@babel/parser", "@babel/traverse", "@babel/types"].contains(
          package_name,
        ) ||
        package_name.has_prefix("@stylexjs/")
      ) {
      @support.reject(
        "STYLE_LICENSE",
        "Compiler dependency escaped oracle isolation: " + package_name,
      )
    }
    let license = match @support.get(manifest, "license") {
      String(value) if value.trim() != "" => value
      Array(values) if !values.is_empty() =>
        values
        .map(value => {
          match value {
            String(value) => value
            _ => @support.text(value, "type")
          }
        })
        .join(" OR ")
      _ => {
        let files = @fs.readdir(path).filter(file => {
          re"^[Ll][Ii][Cc][Ee][Nn][SsCc][Ee](\.|$)".execute(file[:]) is Some(_)
        })
        guard files is [file, ..] else {
          @support.reject(
            "STYLE_LICENSE",
            "Unknown dependency license: " + package_name,
          )
        }
        "SEE " + file
      }
    }
    packages[package_name + "@" + @support.text(manifest, "version")] = Json(
      license,
    )
    if @fs.exists(path + "/node_modules") {
      installed(path + "/node_modules", seen, packages, compiler~)
    }
  }
}

///|
pub async fn node_licenses(root : String) -> Unit {
  guard !@fs.exists(root + "/package.json") && !@fs.exists(root + "/bun.lock") else {
    @support.reject(
      "STYLE_LICENSE", "Node package ownership must remain isolated under verification/ and tooling/vite/",
    )
  }
  let report : Map[String, Json] = Map([])
  for
    (name, directory, compiler) in [
      ("verification", "verification", false),
      ("stylexOracle", "tools/stylex-oracle", true),
    ] {
    let packages = Map([])
    installed(
      root + "/" + directory + "/node_modules",
      Map([]),
      packages,
      compiler~,
    )
    let manifest = @support.json(root + "/" + directory + "/package.json")
    for
      dependency, pin in @support.fields(
        @support.get(manifest, "devDependencies"),
      ) {
      let pin = @support.string(pin)
      if pin.has_prefix("workspace:") {
        continue
      }
      let installed = @support.json(
        root + "/" + directory + "/node_modules/" + dependency + "/package.json",
      )
      let version = @support.text(installed, "version")
      guard pin == version || pin.has_suffix("@" + version) else {
        @support.reject(
          "STYLE_LICENSE",
          "Installed package differs from pin: " + dependency,
        )
      }
    }
    report[name] = Json::object(packages)
  }
  @support.write(
    root + "/.generated/node-licenses.json",
    Json::object(report).stringify(indent=2) + "\n",
  )
  println(
    "Isolated verification and StyleX oracle dependency versions and licenses verified.",
  )
}
