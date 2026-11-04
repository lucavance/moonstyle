///|
fn registered_dependency(
  module_name : String,
  initial : String,
) -> DependencyBundle raise {
  let output = compile_registry(
    @ir.registry(module_name, [], variable_sets=[
      @ir.define_vars("shared", [
        {
          name: "--shared-distance",
          default_css: initial,
          category: LengthCategory,
          registration: Some({ inherits: false, }),
        },
      ]),
    ]),
  )
  assert_eq(output.diagnostics, [])
  decode_bundle(output.manifest).unwrap()
}

///|
test "registered dependencies deduplicate and conflicting registrations fail independent of root order" {
  let left = registered_dependency("registration/left", "12px")
  let right = registered_dependency("registration/right", "12px")
  for roots in [[left, right], [right, left]] {
    match merge_bundles(application_with(roots), roots) {
      Ok(output) =>
        assert_eq(output.css.split("@property --shared-distance").count(), 2)
      Err(errors) => fail(render_diagnostics_text(errors))
    }
  }
  let conflict = registered_dependency("registration/conflict", "24px")
  for roots in [[left, conflict], [conflict, left]] {
    match merge_bundles(application_with(roots), roots) {
      Ok(_) => fail("conflicting registrations must not merge")
      Err(errors) =>
        assert_true(
          errors.any(item => item.code == "STYLE_BUNDLE_GLOBAL_COLLISION"),
        )
    }
  }
}

///|
test "property artifacts reject malformed registrations even when all hashes are recomputed" {
  for
    css in [
      "@property --shared-distance{syntax:\"<length>\";inherits:false;initial-value:1rem}",
      "@property --shared-distance{syntax:\"<time>\";inherits:false;initial-value:1s}",
      "@property --other{syntax:\"<length>\";inherits:false;initial-value:12px}",
      "@property --shared-distance{syntax:\"<color>\";inherits:false;initial-value:#xyz}",
      "@property --shared-distance{syntax:\"<color>\";inherits:false;initial-value:rgb(var(--x) 0 0)}",
      "@property --shared-distance{syntax:\"<number>\";inherits:false;initial-value:NaN}",
    ] {
    let dependency = dependency_fixture("registration/tampered", globals=[
      {
        kind: "property",
        name: "--shared-distance",
        css,
        digest: semantic_digest(css),
      },
    ])
    assert_true(
      validate_bundle(dependency).any(item => {
        item.code == "STYLE_BUNDLE_PROPERTY"
      }),
      msg=css,
    )
  }
  let valid = registered_dependency("registration/schema", "12px")
  let old = render_bundle_manifest(valid).replace_all(
    old="\"schemaVersion\":14",
    new="\"schemaVersion\":13",
  )
  match decode_bundle(old) {
    Ok(_) => fail("schema 13 cannot represent the registration contract")
    Err(errors) => assert_eq(errors[0].code, "STYLE_BUNDLE_SCHEMA")
  }
}

///|
test "duplicate registration records and invalid low-level names cannot be distributed" {
  let css = "@property --shared-distance{syntax:\"<length>\";inherits:false;initial-value:12px}"
  let global : BundleGlobal = {
    kind: "property",
    name: "--shared-distance",
    css,
    digest: semantic_digest(css),
  }
  let duplicate = dependency_fixture("registration/duplicate", globals=[
    global, global,
  ])
  assert_true(
    validate_bundle(duplicate).any(item => {
      item.code == "STYLE_BUNDLE_PROPERTY_DUPLICATE"
    }),
  )
  let output = compile_registry(
    @ir.registry("registration/invalid-name", [], variable_sets=[
      @ir.define_vars("shared", [
        {
          name: "--shared-distance;",
          default_css: "12px",
          category: LengthCategory,
          registration: Some({ inherits: true, }),
        },
      ]),
    ]),
  )
  assert_true(
    output.diagnostics.any(item => item.code == "STYLE_PROPERTY_NAME"),
  )
  assert_false(output.css.contains("@property "))
}
