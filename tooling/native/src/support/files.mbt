///|
pub fn normalize(path : String) -> String {
  let parts : Array[String] = []
  let absolute = path.has_prefix("/")
  for part in path.replace_all(old="\\", new="/").split("/") {
    let part = part.to_owned()
    if part == "" || part == "." {
      continue
    }
    if part == ".." && !parts.is_empty() && parts.last().unwrap() != ".." {
      ignore(parts.pop())
    } else if part != ".." || !absolute {
      parts.push(part)
    }
  }
  (if absolute { "/" } else { "" }) + parts.join("/")
}

///|
pub fn join(root : String, relative : String) -> String {
  normalize(
    if relative.has_prefix("/") {
      relative
    } else {
      root + "/" + relative
    },
  )
}

///|
pub fn parent(path : String) -> String {
  let parts = path.split("/").map(part => part.to_owned()).collect()
  ignore(parts.pop())
  let value = parts.join("/")
  if value == "" && path.has_prefix("/") {
    "/"
  } else {
    value
  }
}

///|
pub async fn read(path : String) -> String {
  @fs.read_file(path).text()
}

///|
pub async fn file_hash(path : String) -> String {
  "sha256:" +
  @crypto.bytes_to_hex_string(@crypto.sha256(@fs.read_file(path).binary()))
}

///|
pub async fn json(path : String) -> Json {
  @json.parse(read(path))
}

///|
pub async fn write(path : String, content : String) -> Unit {
  @fs.mkdir(parent(path), recursive=true, allow_exist=true)
  @fs.write_file(path, content)
}

///|
pub async fn changed_write(path : String, content : String) -> Bool {
  if @fs.exists(path) && read(path) == content {
    return false
  }
  write(path, content)
  true
}

///|
pub async fn project_path(root : String, value : String) -> String {
  guard value.trim().to_owned() == value &&
    value != "" &&
    !value.has_prefix("/") &&
    !value.contains("\u0000") &&
    !(value.length() >= 2 && value[1] == ':') else {
    reject("STYLE_PROJECT_PATH", "Expected a project-relative path: " + value)
  }
  let relative = normalize(value)
  guard relative != "" && relative != ".." && !relative.has_prefix("../") else {
    reject("STYLE_PROJECT_PATH", "Path escapes the project: " + value)
  }
  let real_root = @fs.realpath(root)
  let mut ancestor = join(root, relative)
  while !@fs.exists(ancestor) {
    ancestor = parent(ancestor)
  }
  let real = @fs.realpath(ancestor)
  guard real == real_root || real.has_prefix(real_root + "/") else {
    reject("STYLE_PROJECT_PATH", "Symbolic link escapes the project: " + value)
  }
  relative
}

///|
pub async fn files(root : String) -> Array[String] {
  let output : Array[String] = []
  for name in @fs.readdir(root, include_hidden=true, sort=true) {
    if [".git", ".mooncakes", "_build", "node_modules", ".cache", "dist"].contains(
        name,
      ) {
      continue
    }
    let path = join(root, name)
    match @fs.kind(path, follow_symlink=false) {
      Directory => output.append(files(path))
      Regular => output.push(path)
      _ => ()
    }
  }
  output
}

///|
pub async fn command(
  program : String,
  args : Array[String],
  root : String,
) -> String {
  let result = @shell.Cmd(program, args, cwd=root).output()
  guard result.exit_code() == 0 else {
    reject(
      "STYLE_TOOLCHAIN",
      program + " failed:\n" + result.stdout() + result.stderr(),
    )
  }
  result.stdout()
}
