///|
test "compound and named conditions retain distinct rules across dependency merging" {
  let conditions = [
    @ir.media(
      @ir.media_query([
        @ir.media_feature("prefers-reduced-motion", Equal, "reduce"),
        @ir.media_feature("pointer", Equal, "coarse"),
      ]),
    ),
    @ir.media(@ir.media_query([], media_type=Some(Print))),
    @ir.supports(
      @ir.supports_all([
        @ir.supports_declaration("display", "grid"),
        @ir.supports_declaration("position", "sticky"),
      ]),
    ),
    @ir.container(
      @ir.container_query(
        [@ir.media_feature("width", Min, "400px")],
        name=Some("sidebar"),
      ),
    ),
  ]
  for condition in conditions {
    let dependency = fn(module_name, color) raise {
      let compiled = compile_registry(
        @ir.registry(module_name, [
          @ir.style_set("styles", [
            @ir.style_namespace("first", [
              @ir.declaration("color", @ir.text(color), conditions=[condition]),
            ]),
            @ir.style_namespace("duplicate", [
              @ir.declaration("color", @ir.text(color), conditions=[condition]),
            ]),
          ]),
        ]),
      )
      assert_eq(compiled.diagnostics, [])
      match decode_bundle(compiled.manifest) {
        Ok(bundle) => {
          assert_eq(validate_bundle(bundle), [])
          assert_eq(bundle.rules.length(), 1)
          bundle
        }
        Err(errors) => fail(render_diagnostics_text(errors))
      }
    }
    let left = dependency("upstream/left", "red")
    let right = dependency("upstream/right", "blue")
    let application = application_with([left, right])
    let merged = match merge_bundles(application, [left, right]) {
      Ok(bundle) => bundle
      Err(errors) => fail(render_diagnostics_text(errors))
    }
    match merge_bundles(application, [right, left]) {
      Ok(reverse) => assert_eq(merged, reverse)
      Err(errors) => fail(render_diagnostics_text(errors))
    }
    assert_eq(merged.css.split("color:red").count(), 2)
    assert_eq(merged.css.split("color:blue").count(), 2)
    match decode_bundle(merged.manifest) {
      Ok(bundle) => {
        assert_eq(validate_bundle(bundle), [])
        assert_eq(bundle.rules.length(), 2)
        assert_true(bundle.rules.contains(left.rules[0]))
        assert_true(bundle.rules.contains(right.rules[0]))
      }
      Err(errors) => fail(render_diagnostics_text(errors))
    }
  }
}

///|
test "a self-consistent cache from the previous normalizer is rejected" {
  let bundle = compile_registry(
    @ir.registry("upstream/cache", [
      @ir.style_set("styles", [
        @ir.style_namespace("image", [
          @ir.declaration("backgroundImage", @ir.text("url(\"0.5x.png\")")),
        ]),
      ]),
    ]),
  )
  assert_eq(bundle.diagnostics, [])
  let key = extraction_cache_key(bundle)
  let metadata = render_cache_metadata(bundle)
  assert_true(
    validate_cache_lookup(
      key,
      metadata,
      bundle.css,
      bundle.mappings,
      bundle.mappings_manifest,
      bundle.manifest,
    ),
  )
  let pack = render_cache_pack(bundle)
  assert_eq(render_cache_pack(bundle), pack)
  match decode_cache_entry(bundle, pack) {
    Some(outputs) => {
      assert_eq(outputs.css, bundle.css)
      assert_eq(outputs.mappings, bundle.mappings)
      assert_eq(outputs.manifest, bundle.manifest)
    }
    None => fail("current cache must round trip")
  }
  let previous_configuration = content_digest(
    cache_generator_configuration.replace_all(
      old="|css-value-normalization-v2",
      new="",
    ),
  )
  assert_false(
    previous_configuration == content_digest(cache_generator_configuration),
  )
  guard @json.parse(metadata) is Object(fields) else {
    fail("metadata must be an object")
  }
  fields.set("generatorConfigurationDigest", Json(previous_configuration))
  // Re-sign the old configuration: rejection must not rely on a broken checksum.
  fields.set(
    "integrity",
    Json(
      cache_metadata_integrity(
        bundle.schema_version,
        cache_tool_version,
        key,
        bundle.semantic_digest,
        @core.application_order_digest,
        previous_configuration,
        content_digest(bundle.css),
        content_digest(bundle.mappings),
        content_digest(bundle.mappings_manifest),
        content_digest(bundle.manifest),
      ),
    ),
  )
  let previous_metadata = Json::object(fields).stringify()
  assert_false(
    validate_cache_lookup(
      key,
      previous_metadata,
      bundle.css,
      bundle.mappings,
      bundle.mappings_manifest,
      bundle.manifest,
    ),
  )
  let previous_pack : Json = {
    "cacheSchemaVersion": 4,
    "metadata": previous_metadata,
    "css": bundle.css,
    "mappings": bundle.mappings,
    "mappingsManifest": bundle.mappings_manifest,
    "manifest": bundle.manifest,
  }
  assert_true(decode_cache_entry(bundle, previous_pack.stringify()) is None)
}
