///|
fn abort_diagnostics(diagnostics : Array[@core.Diagnostic]) -> Unit {
  let rendered = if @env.args().contains("--diagnostics=json") {
    @extract.render_diagnostics_json(diagnostics)
  } else {
    @extract.render_diagnostics_text(diagnostics)
  }
  println(rendered.trim())
  @sys.exit(1)
}

///|
fn validate_args(args : Array[String]) -> Unit {
  let pair_options = [
    "--dependency-bundle", "--css-output", "--mappings-output", "--bundle-output",
    "--mappings-manifest-output", "--mappings-package", "--cache-dir", "--dependency-root",
    "--debug-manifest-output", "--tooling-protocol",
  ]
  let singleton_options = [
    "--css-output", "--mappings-output", "--bundle-output", "--mappings-manifest-output",
    "--mappings-package", "--cache-dir", "--debug-manifest-output", "--tooling-protocol",
  ]
  let seen : Array[String] = []
  let mut index = 0
  while index < args.length() {
    let argument = args[index]
    if pair_options.contains(argument) {
      if index + 1 >= args.length() || args[index + 1].has_prefix("--") {
        abort_diagnostics([
          @core.error_diagnostic(
            "STYLE_CLI_ARGUMENT",
            argument + " requires a value",
          ),
        ])
      }
      if singleton_options.contains(argument) && seen.contains(argument) {
        abort_diagnostics([
          @core.error_diagnostic(
            "STYLE_CLI_DUPLICATE_ARGUMENT",
            argument + " may only be specified once",
          ),
        ])
      }
      seen.push(argument)
      index = index + 2
    } else if argument == "--no-cache" ||
      argument == "--check" ||
      argument == "--diagnostics=text" ||
      argument == "--diagnostics=json" {
      if seen.contains(argument) {
        abort_diagnostics([
          @core.error_diagnostic(
            "STYLE_CLI_DUPLICATE_ARGUMENT",
            argument + " may only be specified once",
          ),
        ])
      }
      seen.push(argument)
      index = index + 1
    } else {
      abort_diagnostics([
        @core.error_diagnostic(
          "STYLE_CLI_UNKNOWN_ARGUMENT",
          "Unknown argument: " + argument,
        ),
      ])
    }
  }
  if seen.contains("--diagnostics=text") && seen.contains("--diagnostics=json") {
    abort_diagnostics([
      @core.error_diagnostic(
        "STYLE_CLI_DUPLICATE_ARGUMENT", "--diagnostics may only be specified once",
      ),
    ])
  }
  if seen.contains("--check") && seen.contains("--debug-manifest-output") {
    abort_diagnostics([
      @core.error_diagnostic(
        "STYLE_CLI_ARGUMENT", "--debug-manifest-output cannot be combined with --check",
      ),
    ])
  }
}

///|
fn dependency_paths(args : Array[String]) -> Array[String] {
  let paths : Array[String] = []
  let mut index = 0
  while index < args.length() {
    if args[index] == "--dependency-bundle" {
      if index + 1 >= args.length() {
        abort_diagnostics([
          @core.error_diagnostic(
            "STYLE_BUNDLE_ARGUMENT", "--dependency-bundle requires a file path",
          ),
        ])
      }
      paths.push(args[index + 1])
      index = index + 2
    } else if args[index] == "--dependency-root" {
      for path in discover_dependency_bundles(args[index + 1]) {
        if !paths.contains(path) {
          paths.push(path)
        }
      }
      index = index + 2
    } else {
      index = index + 1
    }
  }
  paths
}

///|
fn collect_dependency_bundles(
  directory : String,
  output : Array[String],
) -> Unit {
  let entries = @fs.read_dir(directory).to_owned() catch {
    _ => {
      abort_diagnostics([
        @core.error_diagnostic(
          "STYLE_DEPENDENCY_ROOT",
          "Unable to read dependency root: " + directory,
        ),
      ])
      []
    }
  }
  entries.sort()
  for entry in entries {
    let path = if directory.has_suffix("/") {
      directory + entry
    } else {
      directory + "/" + entry
    }
    let is_directory = @fs.is_dir(path) catch { _ => false }
    if is_directory {
      collect_dependency_bundles(path, output)
    } else if path.has_suffix(".bundle.json") {
      output.push(path)
    }
  }
}

///|
fn discover_dependency_bundles(root : String) -> Array[String] {
  if !@fs.path_exists(root) {
    abort_diagnostics([
      @core.error_diagnostic(
        "STYLE_DEPENDENCY_ROOT",
        "Dependency root does not exist: " + root,
      ),
    ])
  }
  let output : Array[String] = []
  collect_dependency_bundles(root, output)
  output
}

///|
fn option_value(args : Array[String], option : String) -> String? {
  let mut index = 0
  while index < args.length() {
    if args[index] == option {
      if index + 1 >= args.length() {
        abort_diagnostics([
          @core.error_diagnostic(
            "STYLE_CACHE_ARGUMENT",
            option + " requires a directory path",
          ),
        ])
      }
      return Some(args[index + 1])
    }
    index = index + 1
  }
  None
}

///|
fn validate_tooling_protocol(args : Array[String]) -> Unit {
  match option_value(args, "--tooling-protocol") {
    Some("1") => ()
    Some(version) =>
      abort_diagnostics([
        @core.error_diagnostic(
          "STYLE_TOOLING_PROTOCOL",
          "Unsupported tooling protocol " +
          version +
          "; this extractor requires protocol 1",
        ),
      ])
    None => {
      let warning = @core.warning_diagnostic(
        "STYLE_TOOLING_PROTOCOL_LEGACY", "No tooling protocol was provided; copied 0.1.x integrations are deprecated and may be removed in 0.2.0",
      )
      let rendered = if args.contains("--diagnostics=json") {
        @extract.render_diagnostics_json([warning])
      } else {
        @extract.render_diagnostics_text([warning])
      }
      println(rendered.trim())
    }
  }
}

///|
fn load_dependencies(args : Array[String]) -> Array[@extract.DependencyBundle] {
  let dependencies : Array[@extract.DependencyBundle] = []
  for path in dependency_paths(args) {
    let input = @fs.read_file_to_string(path) catch {
      _ => {
        abort_diagnostics([
          @core.error_diagnostic(
            "STYLE_BUNDLE_READ",
            "Unable to read dependency bundle: " + path,
          ),
        ])
        ""
      }
    }
    match @extract.decode_bundle(input) {
      Ok(bundle) => {
        let diagnostics = @extract.validate_bundle(bundle)
        if !diagnostics.is_empty() {
          abort_diagnostics(diagnostics)
        }
        dependencies.push(bundle)
      }
      Err(diagnostics) => abort_diagnostics(diagnostics)
    }
  }
  dependencies
}

///|
fn output_artifacts(
  args : Array[String],
  css : String,
  mappings : String,
  mappings_manifest : String,
  manifest : String,
) -> Array[Artifact] {
  let css_output = option_value(args, "--css-output").unwrap_or(
    "src/generated/styles.generated.css",
  )
  let mappings_output = option_value(args, "--mappings-output").unwrap_or(
    "src/generated/styles.generated.mbt",
  )
  let bundle_output = option_value(args, "--bundle-output").unwrap_or(
    "src/generated/styles.bundle.json",
  )
  let mappings_manifest_output = option_value(
    args, "--mappings-manifest-output",
  ).unwrap_or("src/generated/moon.pkg")
  [
    {
      target: css_output,
      temporary: css_output + ".tmp",
      backup: css_output + ".bak",
      content: css,
    },
    {
      target: mappings_output,
      temporary: mappings_output + ".tmp",
      backup: mappings_output + ".bak",
      content: mappings,
    },
    {
      target: mappings_manifest_output,
      temporary: mappings_manifest_output + ".tmp",
      backup: mappings_manifest_output + ".bak",
      content: mappings_manifest,
    },
    {
      target: bundle_output,
      temporary: bundle_output + ".tmp",
      backup: bundle_output + ".bak",
      content: manifest,
    },
  ]
}

///|
fn check_artifacts(artifacts : Array[Artifact]) -> Array[@core.Diagnostic] {
  let diagnostics : Array[@core.Diagnostic] = []
  for artifact in artifacts {
    if !@fs.path_exists(artifact.target) {
      diagnostics.push(
        @core.error_diagnostic(
          "STYLE_OUTPUT_MISSING",
          "Generated style artifact is missing",
          context=Some(
            @core.diagnostic_context(
              "lampclaw/moonstyle/extract",
              artifact_path=Some(artifact.target),
            ),
          ),
        ),
      )
    } else {
      let current = @fs.read_file_to_string(artifact.target) catch { _ => "" }
      if current != artifact.content {
        diagnostics.push(
          @core.error_diagnostic(
            "STYLE_OUTPUT_STALE",
            "Generated style artifact differs from deterministic extraction output",
            context=Some(
              @core.diagnostic_context(
                "lampclaw/moonstyle/extract",
                artifact_path=Some(artifact.target),
              ),
            ),
          ),
        )
      }
    }
  }
  diagnostics
}

///|
fn cache_artifact(
  directory : String,
  key : String,
  content : String,
) -> Artifact {
  let target = directory + "/" + key[7:].to_owned() + ".cache.json"
  { target, temporary: target + ".tmp", backup: target + ".bak", content, }
}

///|
fn valid_debug_cache_identity(identity : String) -> Bool {
  if identity.length() != 64 {
    return false
  }
  for index = 0; index < identity.length(); index = index + 1 {
    let code = identity.unsafe_get(index).to_int()
    if !(code >= 48 && code <= 57) && !(code >= 97 && code <= 102) {
      return false
    }
  }
  true
}

///|
fn debug_cache_artifact(
  directory : String,
  identity : String,
  content : String,
) -> Artifact {
  let target = directory + "/debug-" + identity + ".json"
  { target, temporary: target + ".tmp", backup: target + ".bak", content, }
}

///|
fn debug_output_artifact(target : String, content : String) -> Artifact {
  { target, temporary: target + ".tmp", backup: target + ".bak", content, }
}

///|
fn emit_cache_warning(message : String, artifact_path : String) -> Unit {
  let context = @core.diagnostic_context(
    "lampclaw/moonstyle/extract",
    artifact_path=Some(artifact_path),
  )
  let diagnostic = @core.warning_diagnostic(
    "STYLE_CACHE_CORRUPT",
    message,
    context=Some(context),
  )
  println(@extract.render_diagnostics_text([diagnostic]).trim())
}

///|
fn read_cache(
  bundle : @extract.CompiledBundle,
  artifact : Artifact,
) -> (String, String, String, String)? {
  if !@fs.path_exists(artifact.target) {
    return None
  }
  let content = @fs.read_file_to_string(artifact.target) catch {
    _ => return None
  }
  match @extract.decode_cache_entry(bundle, content) {
    Some(outputs) =>
      Some(
        (
          outputs.css,
          outputs.mappings,
          outputs.mappings_manifest,
          outputs.manifest,
        ),
      )
    None => {
      emit_cache_warning(
        "Cache entry failed structural or digest validation",
        artifact.target,
      )
      None
    }
  }
}

///|
fn cache_pointer(directory : String, hint : String, key : String) -> Artifact {
  let target = directory + "/lookup-" + hint + ".txt"
  {
    target,
    temporary: target + ".tmp",
    backup: target + ".bak",
    content: key + "\n",
  }
}

///|
fn read_cache_lookup(
  directory : String,
  hint : String,
) -> (String, String, String, String)? {
  let pointer = cache_pointer(directory, hint, "")
  if !@fs.path_exists(pointer.target) {
    return None
  }
  let key = @fs.read_file_to_string(pointer.target) catch { _ => return None }
  let trimmed_key = key.trim().to_owned()
  if !trimmed_key.has_prefix("sha256:") {
    emit_cache_warning("Cache lookup pointer is invalid", pointer.target)
    return None
  }
  let artifact = cache_artifact(directory, trimmed_key, "")
  if !@fs.path_exists(artifact.target) {
    emit_cache_warning("Cache lookup entry is missing", artifact.target)
    return None
  }
  let content = @fs.read_file_to_string(artifact.target) catch {
    _ => return None
  }
  match @extract.decode_cache_lookup(trimmed_key, content) {
    Some(outputs) =>
      Some(
        (
          outputs.css,
          outputs.mappings,
          outputs.mappings_manifest,
          outputs.manifest,
        ),
      )
    None => {
      emit_cache_warning(
        "Cache lookup failed structural, semantic, or digest validation",
        artifact.target,
      )
      None
    }
  }
}

///|
fn read_debug_cache(
  directory : String,
  identity : String,
  css : String,
  manifest : String,
) -> String? {
  if !valid_debug_cache_identity(identity) {
    emit_cache_warning("Debug cache identity is invalid", directory)
    return None
  }
  let artifact = debug_cache_artifact(directory, identity, "")
  if !@fs.path_exists(artifact.target) {
    return None
  }
  let content = @fs.read_file_to_string(artifact.target) catch {
    _ => return None
  }
  if @extract.validate_debug_manifest_outputs(content, css, manifest) {
    Some(content)
  } else {
    emit_cache_warning(
      "Debug cache entry failed schema or digest validation",
      artifact.target,
    )
    None
  }
}

///|
pub fn run(registry : @ir.Registry) -> Unit {
  let raw_args = @env.args()
  let args : Array[String] = []
  for index = 1; index < raw_args.length(); index = index + 1 {
    args.push(raw_args[index])
  }
  validate_args(args)
  validate_tooling_protocol(args)
  let mappings_package = match option_value(args, "--mappings-package") {
    Some(value) if !value.trim().is_empty() => value
    _ => {
      abort_diagnostics([
        @core.error_diagnostic(
          "STYLE_MAPPINGS_PACKAGE_ARGUMENT", "--mappings-package requires a non-empty MoonBit package name",
        ),
      ])
      ""
    }
  }
  let cache_enabled = !args.contains("--no-cache")
  let check_only = args.contains("--check")
  let debug_output = option_value(args, "--debug-manifest-output")
  let cache_directory = option_value(args, "--cache-dir").unwrap_or(
    "_build/style-cache",
  )
  if cache_enabled && !check_only && !create_directories(cache_directory) {
    abort_diagnostics([
      @core.error_diagnostic(
        "STYLE_CACHE_DIRECTORY",
        "Unable to create cache directory: " + cache_directory,
      ),
    ])
  }
  let cache_identity = @env.get_env_var("MOONSTYLE_CACHE_IDENTITY")
  if cache_enabled {
    match cache_identity {
      Some(identity) =>
        match read_cache_lookup(cache_directory, identity) {
          Some((css, mappings, mappings_manifest, manifest)) => {
            let debug_content = match debug_output {
              Some(_) =>
                read_debug_cache(cache_directory, identity, css, manifest)
              None => None
            }
            if debug_output is None || debug_content is Some(_) {
              let artifacts = output_artifacts(
                args, css, mappings, mappings_manifest, manifest,
              )
              match (debug_output, debug_content) {
                (Some(target), Some(content)) =>
                  artifacts.push(debug_output_artifact(target, content))
                _ => ()
              }
              if check_only {
                let diagnostics = check_artifacts(artifacts)
                if !diagnostics.is_empty() {
                  abort_diagnostics(diagnostics)
                }
                println(
                  "Verified lampclaw/moonstyle artifact schema v14 (outputs current)",
                )
                return
              }
              let changed = write_artifacts_if_changed(artifacts)
              println(
                "Cache hit for lampclaw/moonstyle artifact schema v14" +
                (if changed { "" } else { " (outputs unchanged)" }),
              )
              return
            }
          }
          None => ()
        }
      None => ()
    }
  }
  let dependencies = load_dependencies(args)
  let local_bundle = @extract.compile_registry(
    registry,
    mappings_package~,
    dependencies~,
  )
  if !local_bundle.diagnostics.is_empty() {
    abort_diagnostics(local_bundle.diagnostics)
  }
  let bundle = if dependencies.is_empty() {
    local_bundle
  } else {
    match @extract.merge_bundles(local_bundle, dependencies) {
      Ok(bundle) => bundle
      Err(diagnostics) => {
        abort_diagnostics(diagnostics)
        local_bundle
      }
    }
  }
  let key = @extract.extraction_cache_key(bundle)
  let cached = if cache_enabled {
    read_cache(bundle, cache_artifact(cache_directory, key, ""))
  } else {
    None
  }
  let (css, mappings, mappings_manifest, manifest, cache_hit) = match cached {
    Some((css, mappings, mappings_manifest, manifest)) =>
      (css, mappings, mappings_manifest, manifest, true)
    None =>
      (
        bundle.css,
        bundle.mappings,
        bundle.mappings_manifest,
        bundle.manifest,
        false,
      )
  }
  let debug_manifest = match debug_output {
    Some(_) =>
      match @extract.render_debug_manifest(registry, bundle) {
        Ok(content) => Some(content)
        Err(diagnostics) => {
          abort_diagnostics(diagnostics)
          None
        }
      }
    None => None
  }
  let outputs_changed = write_artifacts_if_changed(
    if check_only {
      let artifacts = output_artifacts(
        args, css, mappings, mappings_manifest, manifest,
      )
      let diagnostics = check_artifacts(artifacts)
      if !diagnostics.is_empty() {
        abort_diagnostics(diagnostics)
      }
      println(
        "Verified lampclaw/moonstyle artifact schema v" +
        bundle.schema_version.to_string() +
        " for " +
        bundle.module_name +
        " (outputs current)",
      )
      return
    } else {
      let artifacts = output_artifacts(
        args, css, mappings, mappings_manifest, manifest,
      )
      match (debug_output, debug_manifest) {
        (Some(target), Some(content)) =>
          artifacts.push(debug_output_artifact(target, content))
        _ => ()
      }
      artifacts
    },
  )
  let cache_eligible = @extract.cache_eligible(bundle) ||
    @env.get_env_var("MOONSTYLE_CACHE_FORCE") == Some("1")
  if cache_enabled && cache_eligible && !cache_hit {
    ignore(
      write_artifacts_if_changed([
        cache_artifact(cache_directory, key, @extract.render_cache_pack(bundle)),
      ]),
    )
  }
  if cache_enabled && cache_eligible {
    match (cache_identity, debug_manifest) {
      (Some(identity), Some(content)) if valid_debug_cache_identity(identity) =>
        ignore(
          write_artifacts_if_changed([
            debug_cache_artifact(cache_directory, identity, content),
          ]),
        )
      _ => ()
    }
  }
  if cache_enabled && cache_eligible {
    match cache_identity {
      Some(identity) =>
        ignore(
          write_artifacts_if_changed([
            cache_pointer(cache_directory, identity, key),
          ]),
        )
      None => ()
    }
  }
  println(
    (if cache_hit {
      "Cache hit for"
    } else if cache_eligible {
      "Generated"
    } else {
      "Generated without cache for"
    }) +
    " lampclaw/moonstyle artifact schema v" +
    bundle.schema_version.to_string() +
    " for " +
    bundle.module_name +
    (if outputs_changed { "" } else { " (outputs unchanged)" }),
  )
}
