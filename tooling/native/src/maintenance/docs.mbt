///|
fn unfenced(source : String) -> String {
  let lines = []
  let mut fence = ""
  let mut comment = false
  for raw in source.split("\n") {
    let line = raw.trim_start().to_owned()
    if line.contains("<!--") {
      comment = true
    }
    let hidden = comment
    if line.contains("-->") {
      comment = false
    }
    if hidden {
      continue
    }
    if fence != "" {
      if line.has_prefix(fence) {
        fence = ""
      }
      continue
    }
    if line.has_prefix("```") || line.has_prefix("~~~") {
      fence = line[0:3].to_owned()
      continue
    }
    lines.push(raw.to_owned())
  }
  lines.join("\n")
}

///|
fn slug(heading : String) -> String {
  let output = StringBuilder()
  for letter in heading.to_lower() {
    if letter == ' ' || letter == '\t' {
      output.write_char('-')
    } else if letter == '-' ||
      letter == '_' ||
      letter.to_int() >= 128 ||
      (letter >= 'a' && letter <= 'z') ||
      (letter >= '0' && letter <= '9') {
      output.write_char(letter)
    }
  }
  output.to_string()
}

///|
fn heading_anchors(source : String) -> Array[String] {
  let text = unfenced(source)
  let anchors = []
  for attribute in re"(?:id|name)=[\"']([^\"']+)[\"']".find(text[:]) {
    anchors.push(attribute.group(1).unwrap().to_owned())
  }
  let lines = text.split("\n").map(line => line.to_owned()).collect()
  for index, line in lines {
    let line = line.trim_start().to_owned()
    let heading = if re"^#{1,6}[[:space:]]+(.+)$".execute(line[:])
      is Some(found) {
      found.group(1).unwrap().to_owned()
    } else if index + 1 < lines.length() &&
      re"^[[:space:]]*(?:=+|-+)[[:space:]]*$".execute(lines[index + 1][:])
      is Some(_) {
      line
    } else {
      continue
    }
    let heading = re"\[([^\]]*)\]\([^)]*\)"
      .replace_by(heading[:], found => found.group(1).unwrap())
      .to_owned()
    let heading = re"<[^>]*>".replace_by(heading[:], _ => "").to_owned()
    let base = slug(heading)
    let mut anchor = base
    let mut count = 1
    while anchors.contains(anchor) {
      anchor = base + "-" + count.to_string()
      count += 1
    }
    anchors.push(anchor)
  }
  anchors
}

///|
fn link_targets(source : String) -> Array[String] {
  let source = unfenced(source)
  let source = re"`+[^`\n]*`+".replace_by(source[:], _ => "").to_owned()
  let targets = []
  for
    found in re"!?\[[^\]\n]*\]\([[:space:]]*(<[^>\n]+>|[^[:space:])]+)(?:[[:space:]]+[\"'][^\n]*?[\"'])?[[:space:]]*\)".find(
      source[:],
    ) {
    targets.push(found.group(1).unwrap().to_owned())
  }
  for line in source.split("\n") {
    if re"^[[:space:]]*\[[^\]\n]+\]:[[:space:]]*(<[^>\n]+>|[^[:space:]]+)".execute(
        line,
      )
      is Some(found) {
      targets.push(found.group(1).unwrap().to_owned())
    }
  }
  targets
}

///|
pub async fn docs(root : String) -> Unit {
  let issues = []
  for path in @support.files(root) {
    if !path.has_suffix(".md") || path.contains("/.generated/") {
      continue
    }
    let source = @support.read(path)
    let lower = source.to_lower()
    for
      stale in [
        "old-moonstyle", "current-beta-status.md", "adjacent reference checkout",
        "repository url is unconfigured", "completed phase plans", "planned mooncakes module name",
        "fababa",
      ] {
      if lower.contains(stale) {
        issues.push(path + " contains superseded wording: " + stale)
      }
    }
    for target in link_targets(source) {
      let target = if target.has_prefix("<") && target.has_suffix(">") {
        target[1:target.length() - 1].to_owned()
      } else {
        target
      }
      if target.contains(":") || target.has_prefix("//") {
        continue
      }
      let parts = target.split("#").map(part => part.to_owned()).collect()
      let destination = parts[0].split("?").next().unwrap().to_owned()
      let resolved = if destination == "" {
        path
      } else {
        @support.join(@support.parent(path), destination)
      }
      if !@fs.exists(resolved) {
        issues.push(path + " links to missing " + target)
      } else if parts.length() > 1 &&
        parts[1] != "" &&
        resolved.has_suffix(".md") &&
        !heading_anchors(@support.read(resolved)).contains(parts[1]) {
        issues.push(path + " links to missing anchor " + target)
      }
    }
  }
  let release = @support.json(root + "/release-status.json")
  let version = @support.text(release, "developmentVersion")
  let published = @support.text(release, "publishedLibraryVersion")
  for
    file in [
      "moon.mod", "validation/moon.mod", "packages/moonstyle-luna/moon.mod", "tooling/native/moon.mod",
    ] {
    let source = @support.read(root + "/" + file)
    if manifest_field(source, "version") != Some(version) {
      issues.push(file + " must use development version " + version)
    }
    if manifest_field(source, "repository") !=
      Some("https://github.com/lucavance/moonstyle") {
      issues.push(file + " has a stale repository")
    }
  }
  let require_text = async fn(file : String, text : String) -> Unit {
    if !@fs.exists(root + "/" + file) {
      issues.push("Missing documentation: " + file)
    } else if !@support.read(root + "/" + file).contains(text) {
      issues.push(file + " must include " + text)
    }
  }
  for
    file in [
      "README.md", "docs/authoring.md", "docs/current-status.md", "docs/distribution.md",
      "docs/release-policy.md",
    ] {
    require_text(file, "lampclaw/moonstyle@" + published)
  }
  for file in ["README.md", "docs/quickstart.md", "docs/ci-and-validation.md"] {
    require_text(file, "moon update")
  }
  for
    text in [
      "MoonStyle — Typed atomic CSS for MoonBit.", "为 MoonBit 提供类型安全的原子化 CSS。",
      "MoonBit is the only supported authoring language", "Rabbita is the only Tier-1 framework integration",
    ] {
    require_text("README.md", text)
  }
  for
    command in [
      "init", "doctor --strict", "upgrade --dry-run", "generate", "check", "watch",
    ] {
    require_text("tooling/README.md", "moonstyle " + command)
  }
  let metadata = @support.json(root + "/src/properties/property-metadata.json")
  let coverage = @support.json(root + "/src/properties/property-coverage.json")
  let artifact = @support.json(
    root + "/validation/src/generated/styles.bundle.json",
  )
  let lock = @support.json(root + "/src/core/application-order.lock.json")
  let property_count = @support.array(@support.get(metadata, "properties"))
    .length()
    .to_string()
  for
    (name, value) in [
      ("Reviewed typed properties", property_count),
      ("Artifact schema", "v14"),
      ("Property generator schema", "v18"),
      ("Application-order semantic lock", "v4"),
    ] {
    require_text("docs/current-status.md", "| " + name + " | " + value + " |")
  }
  for
    (name, value) in [
      ("Typed properties", property_count),
      (
        "WebRef properties",
        @support.array(@support.get(coverage, "properties"))
        .length()
        .to_string(),
      ),
      (
        "Unsupported grammar",
        @support.get(@support.get(coverage, "summary"), "unsupported-grammar").stringify(),
      ),
      (
        "Unsafe-only",
        @support.get(@support.get(coverage, "summary"), "unsafe-only").stringify(),
      ),
      (
        "Deprecated",
        @support.get(@support.get(coverage, "summary"), "deprecated").stringify(),
      ),
    ] {
    require_text("docs/data-sources.md", "| " + name + " | " + value + " |")
  }
  for name, version in @support.fields(@support.get(metadata, "sources")) {
    require_text(
      "docs/data-sources.md",
      "| `" + name + "` | " + @support.string(version) + " |",
    )
  }
  for field in @support.fields(artifact).keys() {
    require_text("docs/artifact-schema-v14.md", "\"" + field + "\"")
  }
  require_text(
    "docs/application-order-semantics.md",
    @support.text(@support.get(lock, "profile"), "name"),
  )
  require_text("packages/moonstyle-luna/README.md", "Status: experimental")
  guard issues.is_empty() else {
    @support.reject("STYLE_DOCS", issues.join("\n"))
  }
  println(
    "Documentation links, versions, schemas and distribution facts verified.",
  )
}

///|
test "documentation parsing ignores code examples and resolves repeated headings" {
  assert_eq(
    link_targets("[guide](docs/a.md)\n```\n[example](absent.md)\n```"),
    ["docs/a.md"],
  )
  assert_eq(
    heading_anchors("# Hello World\n# Hello World\n```\n# hidden\n```"),
    ["hello-world", "hello-world-1"],
  )
}
