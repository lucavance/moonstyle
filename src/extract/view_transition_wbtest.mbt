///|
fn transition_fixture(module_name : String, opacity : String) -> CompiledBundle {
  compile_registry(
    @ir.registry(module_name, [], view_transition_classes=[
      {
        name: "card",
        styles: [
          {
            group: "old",
            declarations: [@ir.declaration("opacity", @ir.text(opacity))],
          },
        ],
      },
    ]),
  )
}

///|
fn transition_decode(bundle : CompiledBundle) -> DependencyBundle raise {
  assert_eq(bundle.diagnostics, [])
  match decode_bundle(bundle.manifest) {
    Ok(value) => {
      assert_eq(validate_bundle(value), [])
      value
    }
    Err(errors) => fail(render_diagnostics_text(errors))
  }
}

///|
fn transition_resign(bundle : DependencyBundle) -> DependencyBundle {
  {
    ..bundle,
    semantic_digest: semantic_digest(semantic_json(bundle).stringify()),
  }
}

///|
test "view transition ownership survives deterministic dependency merging" {
  let left = transition_decode(transition_fixture("transition/left", "0.5"))
  let right = transition_decode(transition_fixture("transition/right", "0.75"))
  let application = application_with([left, right])
  let merged = match merge_bundles(application, [left, right]) {
    Ok(bundle) => bundle
    Err(errors) => fail(render_diagnostics_text(errors))
  }
  match merge_bundles(application, [right, left]) {
    Ok(bundle) => {
      assert_eq(bundle.css, merged.css)
      assert_eq(bundle.manifest, merged.manifest)
    }
    Err(errors) => fail(render_diagnostics_text(errors))
  }
  let decoded = transition_decode(merged)
  assert_eq(decoded.view_transition_classes.length(), 2)
  assert_true(
    decoded.view_transition_classes[0].css_name !=
    decoded.view_transition_classes[1].css_name,
  )
  assert_eq(merged.css.split("::view-transition-old").count(), 3)
  // Reusing a dependency through a second package must not duplicate its global.
  let middle_source = compile_registry(
    @ir.registry("transition/middle", [], direct_dependencies=[
      @ir.dependency_ref(left.module_name, left.semantic_digest),
    ]),
  )
  let middle = transition_decode(
    match merge_bundles(middle_source, [left]) {
      Ok(bundle) => bundle
      Err(errors) => fail(render_diagnostics_text(errors))
    },
  )
  let diamond = match
    merge_bundles(application_with([left, middle]), [left, middle]) {
    Ok(bundle) => bundle
    Err(errors) => fail(render_diagnostics_text(errors))
  }
  assert_eq(diamond.css.split("::view-transition-old").count(), 2)
}

///|
test "view transition artifacts reject tampering even after recomputing bundle digest" {
  let original = transition_decode(
    transition_fixture("transition/fixture", "0.5"),
  )
  let transition = original.view_transition_classes[0]
  let malformed : Array[DependencyBundle] = [
    { ..original, globals: [], },
    { ..original, view_transition_classes: [], },
    {
      ..original,
      view_transition_classes: [{ ..transition, module_name: "foreign/owner", }],
    },
    {
      ..original,
      view_transition_classes: [{ ..transition, css_name: "other", }],
    },
    {
      ..original,
      view_transition_classes: [
        {
          ..transition,
          styles: [{ group: "old", declarations: [("opacity", [".9"])], }],
        },
      ],
    },
    { ..original, view_transition_classes: [{ ..transition, styles: [], }], },
    { ..original, globals: original.globals + original.globals, },
  ]
  for value in malformed {
    let errors = validate_bundle(transition_resign(value))
    assert_true(
      errors.any(error => error.code.has_prefix("STYLE_BUNDLE_VIEW_TRANSITION")),
      msg=render_diagnostics_text(errors),
    )
  }
}

///|
test "view transition decoder rejects unknown groups malformed blocks and legacy schema" {
  let output = transition_fixture("transition/shape", "0.5")
  for
    manifest in [
      output.manifest.replace_all(
        old="\"group\":\"old\"",
        new="\"group\":\"unknown\"",
      ),
      output.manifest.replace_all(
        old="\"declarations\":[[\"opacity\",[\".5\"]]]",
        new="\"declarations\":[[\"opacity\",[]]]",
      ),
      output.manifest.replace_all(
        old="\"group\":\"old\"",
        new="\"extra\":true,\"group\":\"old\"",
      ),
      output.manifest.replace_all(
        old="\"schemaVersion\":13",
        new="\"schemaVersion\":12",
      ),
    ] {
    assert_true(manifest != output.manifest)
    match decode_bundle(manifest) {
      Err(_) => ()
      Ok(_) => fail("invalid transition artifact must not decode")
    }
  }
}

///|
test "view transition low level definitions reject repeated groups and unsupported properties" {
  let old : @ir.ViewTransitionStyle = {
    group: "old",
    declarations: [@ir.declaration("opacity", @ir.text("0.5"))],
  }
  for
    (styles, code) in [
      ([old, old], "STYLE_VIEW_TRANSITION_GROUP"),
      ([{ ..old, group: "unknown", }], "STYLE_VIEW_TRANSITION_GROUP"),
      (
        [{ ..old, declarations: [@ir.declaration("madeUp", @ir.text("red"))], }],
        "STYLE_VIEW_TRANSITION_PROPERTY",
      ),
    ] {
    let output = compile_registry(
      @ir.registry("transition/invalid", [], view_transition_classes=[
        { name: "card", styles, },
      ]),
    )
    assert_true(output.diagnostics.any(error => error.code == code))
    assert_false(output.css.contains("::view-transition"))
  }
}
