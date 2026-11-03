///|
let cache_tool_version = "0.1.0"

///|
let cache_generator_configuration = "artifact-v13|view-transition-styles-v1|stylex-0.19.1-application-order+font-aliases-v1|base-conflict-slots-v1|priority-specificity-v3|property-api-v17|page-values-v1|typed-expressions-v1|typed-length-zero-v1|css-value-normalization-v2|css-coverage-v1|gradients-grid-v1|explicit-clear-v1|fluent-authoring-v3|component-contracts-v1|contract-value-policy-v2|recipes-v1|source-callsite-v1|scalar-expansion-v2|border-composite-v1|cache-policy-v4|common-values-v1|composite-effects-v1|theme-paint-v1|css-tree-3.2.1|webref-8.7.8|bcd-8.1.7"

///|
pub fn cache_eligible(bundle : CompiledBundle) -> Bool {
  let decoded = match decode_bundle(bundle.manifest) {
    Ok(value) => value
    Err(_) => return false
  }
  let work_units = decoded.namespaces.length() +
    decoded.rules.length() +
    decoded.globals.length()
  let output_bytes = bundle.css.length() +
    bundle.mappings.length() +
    bundle.mappings_manifest.length() +
    bundle.manifest.length()
  work_units >= 500 || output_bytes >= 131072
}

///|
fn extraction_cache_key_parts(
  schema_version : Int32,
  module_name : String,
  semantic_digest : String,
  dependencies : Array[BundleDependency],
) -> String {
  let dependency_identities = dependencies.map(dependency => {
    dependency.module_name + "=" + dependency.semantic_digest
  })
  content_digest(
    "schema=" +
    schema_version.to_string() +
    "\ntool=" +
    cache_tool_version +
    "\nconfiguration=" +
    content_digest(cache_generator_configuration) +
    "\nmodule=" +
    module_name +
    "\nsemantic=" +
    semantic_digest +
    "\nsemantics=" +
    @core.application_order_digest +
    "\ndependencies=" +
    dependency_identities.join(",") +
    "\n",
  )
}

///|
pub fn extraction_cache_key(bundle : CompiledBundle) -> String {
  let dependencies = match decode_bundle(bundle.manifest) {
    Ok(decoded) => decoded.dependency_closure
    Err(_) => []
  }
  extraction_cache_key_parts(
    bundle.schema_version,
    bundle.module_name,
    bundle.semantic_digest,
    dependencies,
  )
}

///|
fn cache_metadata_integrity(
  schema_version : Int32,
  tool_version : String,
  cache_key : String,
  semantic_digest : String,
  semantics_digest : String,
  configuration_digest : String,
  css_digest : String,
  mappings_digest : String,
  mappings_manifest_digest : String,
  manifest_digest : String,
) -> String {
  content_digest(
    "schema=" +
    schema_version.to_string() +
    "\ntool=" +
    tool_version +
    "\ncache=" +
    cache_key +
    "\nsemantic=" +
    semantic_digest +
    "\nsemantics=" +
    semantics_digest +
    "\nconfiguration=" +
    configuration_digest +
    "\ncss=" +
    css_digest +
    "\nmappings=" +
    mappings_digest +
    "\nmappingsManifest=" +
    mappings_manifest_digest +
    "\nmanifest=" +
    manifest_digest +
    "\n",
  )
}

///|
pub fn render_cache_metadata(bundle : CompiledBundle) -> String {
  let cache_key = extraction_cache_key(bundle)
  let configuration_digest = content_digest(cache_generator_configuration)
  let css_digest = content_digest(bundle.css)
  let mappings_digest = content_digest(bundle.mappings)
  let mappings_manifest_digest = content_digest(bundle.mappings_manifest)
  let manifest_digest = content_digest(bundle.manifest)
  let metadata : Json = {
    "schemaVersion": bundle.schema_version,
    "toolVersion": cache_tool_version,
    "cacheKey": cache_key,
    "semanticDigest": bundle.semantic_digest,
    "semanticsDigest": @core.application_order_digest,
    "generatorConfigurationDigest": configuration_digest,
    "integrity": cache_metadata_integrity(
      bundle.schema_version,
      cache_tool_version,
      cache_key,
      bundle.semantic_digest,
      @core.application_order_digest,
      configuration_digest,
      css_digest,
      mappings_digest,
      mappings_manifest_digest,
      manifest_digest,
    ),
    "outputs": {
      "css": css_digest,
      "mappings": mappings_digest,
      "mappingsManifest": mappings_manifest_digest,
      "manifest": manifest_digest,
    },
  }
  metadata.stringify() + "\n"
}

///|
pub struct CachedOutputs {
  css : String
  mappings : String
  mappings_manifest : String
  manifest : String
}

///|
pub fn render_cache_pack(bundle : CompiledBundle) -> String {
  let pack : Json = {
    "cacheSchemaVersion": 4,
    "metadata": render_cache_metadata(bundle),
    "css": bundle.css,
    "mappings": bundle.mappings,
    "mappingsManifest": bundle.mappings_manifest,
    "manifest": bundle.manifest,
  }
  pack.stringify() + "\n"
}

///|
fn decode_cache_pack_fields(
  input : String,
) -> (String, String, String, String, String)? {
  let value = @json.parse(input) catch { _ => return None }
  guard value is Object(object) &&
    object.length() == 6 &&
    object.get("cacheSchemaVersion") is Some(Number(version, ..)) &&
    version == 4.0 &&
    object.get("metadata") is Some(String(metadata)) &&
    object.get("css") is Some(String(css)) &&
    object.get("mappings") is Some(String(mappings)) &&
    object.get("mappingsManifest") is Some(String(mappings_manifest)) &&
    object.get("manifest") is Some(String(manifest)) else {
    return None
  }
  Some((metadata, css, mappings, mappings_manifest, manifest))
}

///|
pub fn decode_cache_entry(
  bundle : CompiledBundle,
  input : String,
) -> CachedOutputs? {
  guard decode_cache_pack_fields(input)
    is Some((metadata, css, mappings, mappings_manifest, manifest)) else {
    return None
  }
  if validate_cache_entry(
      bundle, metadata, css, mappings, mappings_manifest, manifest,
    ) {
    Some({ css, mappings, mappings_manifest, manifest, })
  } else {
    None
  }
}

///|
pub fn decode_cache_lookup(
  cache_key : String,
  input : String,
) -> CachedOutputs? {
  guard decode_cache_pack_fields(input)
    is Some((metadata, css, mappings, mappings_manifest, manifest)) else {
    return None
  }
  if validate_cache_lookup(
      cache_key, metadata, css, mappings, mappings_manifest, manifest,
    ) {
    Some({ css, mappings, mappings_manifest, manifest, })
  } else {
    None
  }
}

///|
fn validate_cache_metadata(
  expected_schema_version : Int32,
  expected_semantic_digest : String?,
  expected_cache_key : String,
  metadata : String,
  css : String,
  mappings : String,
  mappings_manifest : String,
  manifest : String,
) -> Bool {
  let value = @json.parse(metadata) catch { _ => return false }
  guard value is Object(object) &&
    object.length() == 8 &&
    object.get("schemaVersion") is Some(Number(metadata_schema_version, ..)) &&
    object.get("toolVersion") is Some(String(tool_version)) &&
    object.get("cacheKey") is Some(String(metadata_cache_key)) &&
    object.get("semanticDigest") is Some(String(metadata_semantic_digest)) &&
    object.get("semanticsDigest") is Some(String(metadata_semantics_digest)) &&
    object.get("generatorConfigurationDigest")
    is Some(String(configuration_digest)) &&
    object.get("integrity") is Some(String(integrity)) &&
    object.get("outputs") is Some(Object(outputs)) &&
    outputs.length() == 4 &&
    outputs.get("css") is Some(String(css_digest)) &&
    outputs.get("mappings") is Some(String(mappings_digest)) &&
    outputs.get("mappingsManifest") is Some(String(mappings_manifest_digest)) &&
    outputs.get("manifest") is Some(String(manifest_digest)) else {
    return false
  }
  let semantic_digest_matches = match expected_semantic_digest {
    Some(expected) => metadata_semantic_digest == expected
    None => true
  }
  metadata_schema_version == expected_schema_version.to_double() &&
  tool_version == cache_tool_version &&
  metadata_cache_key == expected_cache_key &&
  semantic_digest_matches &&
  metadata_semantics_digest == @core.application_order_digest &&
  configuration_digest == content_digest(cache_generator_configuration) &&
  integrity ==
  cache_metadata_integrity(
    expected_schema_version, tool_version, metadata_cache_key, metadata_semantic_digest,
    metadata_semantics_digest, configuration_digest, css_digest, mappings_digest,
    mappings_manifest_digest, manifest_digest,
  ) &&
  css_digest == content_digest(css) &&
  mappings_digest == content_digest(mappings) &&
  mappings_manifest_digest == content_digest(mappings_manifest) &&
  manifest_digest == content_digest(manifest)
}

///|
pub fn validate_cache_entry(
  bundle : CompiledBundle,
  metadata : String,
  css : String,
  mappings : String,
  mappings_manifest : String,
  manifest : String,
) -> Bool {
  validate_cache_metadata(
    bundle.schema_version,
    Some(bundle.semantic_digest),
    extraction_cache_key(bundle),
    metadata,
    css,
    mappings,
    mappings_manifest,
    manifest,
  )
}

///|
pub fn validate_cache_lookup(
  cache_key : String,
  metadata : String,
  css : String,
  mappings : String,
  mappings_manifest : String,
  manifest : String,
) -> Bool {
  validate_cache_metadata(
    13,
    None,
    cache_key,
    metadata,
    css,
    mappings,
    mappings_manifest,
    manifest,
  )
}
