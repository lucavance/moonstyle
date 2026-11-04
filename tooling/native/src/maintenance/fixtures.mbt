///|
pub async fn fixtures(root : String, write~ : Bool = false) -> Unit {
  let text = @support.command(
    "moon",
    [
      "-C", "validation", "run", "cmd/dependency_fixtures", "--target", "native",
      "--release",
    ],
    root,
  )
  let result = @json.parse(text.trim())
  let fixtures = @support.array(@support.get(result, "fixtures"))
  guard fixtures.length() == 2 else {
    @support.reject(
      "STYLE_FIXTURES", "Expected two validated component bundles",
    )
  }
  let output : Map[String, String] = Map([])
  for index, fixture in fixtures {
    output["validation/tests/dependency-fixtures/component-" +
    (if index == 0 { "a" } else { "b" }) +
    ".bundle.json"] = fixture.stringify(indent=2) + "\n"
  }
  output["validation/tests/component_a_generated/styles.generated.mbt"] = @support.text(
    result, "mappings",
  )
  output["validation/tests/component_a_generated/moon.pkg"] = @support.text(
    result, "mappingsManifest",
  )
  let source = @support.read(root + "/validation/examples/styles/styles.mbt")
  let digests = fixtures.map(fixture => {
    @support.quote(@support.text(fixture, "semanticDigest"))
  })
  let source = re"(\"fixture/component-[ab]\",[[:space:]]*)\"sha256:[0-9a-f]+\""
    .replace_by(source[:], found => {
      let prefix = found.group(1).unwrap().to_owned()
      (prefix + digests[if prefix.contains("component-a") { 0 } else { 1 }])[:]
    })
    .to_owned()
  output["validation/examples/styles/styles.mbt"] = source
  for file, content in output {
    if write {
      ignore(@support.changed_write(root + "/" + file, content))
    } else {
      let existing = @support.read(root + "/" + file)
      let same = if file.has_suffix(".json") {
        @json.parse(existing) == @json.parse(content)
      } else {
        existing == content
      }
      guard same else {
        @support.reject("STYLE_FIXTURES", "Synthetic fixture is stale: " + file)
      }
    }
  }
  println(
    "Synthetic dependency fixtures verified against the native extractor.",
  )
}
