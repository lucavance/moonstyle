///|
test "URL payloads survive literals images frames variables themes and extraction" {
  let resource = @moonstyle.url("/v0.5/picture.png?scale=0.5#v0.5")
  let alternate = @moonstyle.url("/v0.5/alternate.png")
  let scope = @moonstyle.variable_scope("resource")
  let token = scope.url_token("picture", resource)
  let slot = scope.url_slot("live", resource)
  let animation = @moonstyle.keyframes("resource", [
    @moonstyle.frame(From).background_image(resource),
    @moonstyle.frame(To).background_image(alternate),
  ])
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "upstream/resources",
      [
        @moonstyle.rule("literal").background_image(resource),
        @moonstyle.rule("images").background_image(
          @moonstyle.image_set([
            @moonstyle.image_candidate(resource),
            @moonstyle.image_candidate(
              alternate,
              resolution=@moonstyle.dppx(2.0),
            ),
          ]),
        ),
        @moonstyle.rule("fallback").background_image_fallbacks(
          @moonstyle.ImageFallbacks::new().add(resource).add(alternate),
        ),
        @moonstyle.rule("token").background_image(token),
        @moonstyle.rule("live").background_image(slot),
        @moonstyle.rule("animation").animation_name(animation),
        @moonstyle.rule("text").content(@moonstyle.content_text("version 0.5")),
      ],
      themes=[@moonstyle.theme("alternate", [token.with_value(alternate)])],
    ),
  )
  assert_eq(output.diagnostics, [])
  for
    expected in [
      resource.to_css(),
      "--resource-picture:" + resource.to_css(),
      "--resource-live:" + resource.to_css(),
      "--resource-picture:" + alternate.to_css(),
      "background-image:" +
      resource.to_css() +
      ";background-image:" +
      alternate.to_css(),
      "from{background-image:" + resource.to_css(),
      "to{background-image:" + alternate.to_css(),
      "content:\"version 0.5\"",
      "image-set(",
    ] {
    assert_true(
      output.css.contains(expected),
      msg=expected + " in " + output.css,
    )
  }
  assert_false(output.css.contains("/v.5/"))
  match @extract.decode_bundle(output.manifest) {
    Ok(bundle) => assert_eq(@extract.validate_bundle(bundle), [])
    Err(errors) => fail(@extract.render_diagnostics_text(errors))
  }
}

///|
test "exact contracts distinguish resource and string identities containing zero" {
  let original = @moonstyle.url("0.5x.png")
  let changed = @moonstyle.url(".5x.png")
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "upstream/identity",
      [
        @moonstyle.rule("allowed").background_image(original),
        @moonstyle.rule("different").background_image(changed),
        @moonstyle.rule("fallback").background_image_fallbacks(
          @moonstyle.ImageFallbacks::new().add(original).add(changed),
        ),
        @moonstyle.rule("textAllowed").content(@moonstyle.content_text("0.5")),
        @moonstyle.rule("textDifferent").content(@moonstyle.content_text(".5")),
      ],
      contracts=[
        @moonstyle.style_contract("resource").allow_background_image(values=[
          original,
        ]),
        @moonstyle.style_contract("text").allow_content(values=[
          @moonstyle.content_text("0.5"),
        ]),
      ],
    ),
  )
  assert_eq(output.diagnostics, [])
  assert_true(output.mappings.contains("ResourceStyleInput for AllowedStyle"))
  assert_false(
    output.mappings.contains("ResourceStyleInput for DifferentStyle"),
  )
  assert_false(output.mappings.contains("ResourceStyleInput for FallbackStyle"))
  assert_true(output.mappings.contains("TextStyleInput for TextAllowedStyle"))
  assert_false(
    output.mappings.contains("TextStyleInput for TextDifferentStyle"),
  )
  match @extract.decode_bundle(output.manifest) {
    Ok(bundle) => {
      assert_eq(@extract.validate_bundle(bundle), [])
      // Three image declarations and two string values must remain distinct.
      assert_eq(bundle.rules.length(), 5)
    }
    Err(errors) => fail(@extract.render_diagnostics_text(errors))
  }
}

///|
test "every fallback position validates authored URLs before emission" {
  for invalid_index in 0..<3 {
    let mut fallbacks = @moonstyle.ImageFallbacks::new()
    for index in 0..<3 {
      fallbacks = fallbacks.add(
        @moonstyle.url(if index == invalid_index { "" } else { "/0.5x.png" }),
      )
    }
    let output = @extract.compile_registry(
      @moonstyle.registry("upstream/invalid-fallback", [
        @moonstyle.rule("image").background_image_fallbacks(fallbacks),
      ]),
    )
    assert_true(output.diagnostics.any(item => item.source is Some(_)))
    assert_false(output.css.contains("background-image:"))
  }
}

///|
test "reused typed conditions have the same priorities and classes as inline conditions" {
  let condition = fn() {
    @moonstyle.media(
      @moonstyle.media_query(
        [
          @moonstyle.media_feature("width", Min, "600px"),
          @moonstyle.media_feature("pointer", Equal, "coarse"),
        ],
        media_type=Some(Screen),
      ),
    )
    .and_when(@moonstyle.supports_property("display", "grid"))
    .and_when(
      @moonstyle.container_min_width(
        @moonstyle.px(400),
        name=Some(@moonstyle.container_name("sidebar")),
      ),
    )
  }
  let shared = condition()
  let compile = fn(when) {
    @extract.compile_registry(
      @moonstyle.registry("upstream/conditions", [
        @moonstyle.rule("first").color(@moonstyle.named_color("red"), when~),
        @moonstyle.rule("second").color(@moonstyle.named_color("blue"), when~),
      ]),
    )
  }
  let reused = compile(shared)
  let inline = compile(condition())
  assert_eq(reused.diagnostics, [])
  assert_eq(inline.diagnostics, [])
  assert_eq(reused.css, inline.css)
  match
    (
      @extract.decode_bundle(reused.manifest),
      @extract.decode_bundle(inline.manifest),
    ) {
    (Ok(a), Ok(b)) => {
      assert_eq(a.rules, b.rules)
      assert_eq(a.rules.length(), 2)
      assert_eq(@extract.validate_bundle(a), [])
    }
    _ => fail("typed condition bundles must decode")
  }
}
