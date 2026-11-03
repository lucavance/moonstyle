///|
test "theme and paint preserve ordered grammar through the public facade" {
  let output = @extract.compile_registry(
    @moonstyle.registry("theme/grammar", [
      @moonstyle.rule("scheme").color_scheme(
        @moonstyle.color_scheme([SchemeDark, SchemeLight], only=true),
      ),
      @moonstyle.rule("normal").color_scheme(@moonstyle.normal_color_scheme()),
      @moonstyle.rule("repeat").color_scheme(
        @moonstyle.color_scheme([SchemeLight, SchemeLight]),
      ),
      @moonstyle.rule("scroll").scrollbar_color(
        @moonstyle.scrollbar_colors(
          thumb=@moonstyle.named_color("red"),
          track=@moonstyle.named_color("Canvas"),
        ),
      ),
      @moonstyle.rule("auto").scrollbar_color(@moonstyle.scrollbar_auto()),
      @moonstyle.rule("icon")
      .fill(@moonstyle.named_color("currentColor"))
      .stroke(@moonstyle.paint_none()),
    ]),
  )
  assert_true(output.diagnostics.is_empty(), msg=output.manifest)
  for
    expected in [
      "color-scheme:dark light only", "color-scheme:normal", "color-scheme:light light",
      "scrollbar-color:red canvas", "scrollbar-color:auto", "fill:currentcolor",
      "stroke:none",
    ] {
    assert_true(output.css.contains(expected), msg=output.css)
  }
  let invalid = @extract.compile_registry(
    @moonstyle.registry("theme/empty", [
      @moonstyle.rule("empty").color_scheme(@moonstyle.color_scheme([])),
    ]),
  )
  assert_true(
    invalid.diagnostics.any(item => item.code == "STYLE_COLOR_SCHEME"),
  )
}

///|
test "paint contracts preserve direct origins and exact composite identities" {
  let scope = @moonstyle.variable_scope("paint")
  let red = @moonstyle.named_color("red")
  let ink = scope.color_token("ink", red)
  let live = scope.color_slot("live", red)
  let other = @moonstyle.variable_scope("other").color_token("ink", red)
  let mixed = @moonstyle.paint(@moonstyle.color_mix(Srgb, ink, live))
  let colors = @moonstyle.scrollbar_colors(thumb=ink, track=live)
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "theme/contracts",
      [
        @moonstyle.rule("direct").fill(ink).stroke(live),
        @moonstyle.rule("literal").fill(red),
        @moonstyle.rule("foreign").fill(other),
        @moonstyle.rule("wrapped").fill(@moonstyle.paint(ink)),
        @moonstyle.rule("mixed")
        .fill(mixed)
        .stroke(live)
        .scrollbar_color(colors),
        @moonstyle.rule("reversed").scrollbar_color(
          @moonstyle.scrollbar_colors(thumb=live, track=ink),
        ),
      ],
      contracts=[
        @moonstyle.style_contract("direct")
        .allow_fill(tokens=[ink])
        .allow_stroke(slots=[live]),
        @moonstyle.style_contract("composite")
        .allow_fill(expressions=[mixed])
        .allow_stroke(slots=[live])
        .allow_scrollbar_color(expressions=[colors]),
      ],
      themes=[
        @moonstyle.theme("dark", [
          ink.with_value(@moonstyle.named_color("white")),
        ]),
      ],
    ),
  )
  assert_true(output.diagnostics.is_empty(), msg=output.manifest)
  assert_true(output.mappings.contains("DirectStyleInput for DirectStyle"))
  assert_false(output.mappings.contains("DirectStyleInput for LiteralStyle"))
  assert_false(output.mappings.contains("DirectStyleInput for ForeignStyle"))
  assert_false(output.mappings.contains("DirectStyleInput for WrappedStyle"))
  assert_true(output.mappings.contains("CompositeStyleInput for MixedStyle"))
  assert_false(
    output.mappings.contains("CompositeStyleInput for ReversedStyle"),
  )
  assert_true(output.css.contains("var(--paint-ink) var(--paint-live)"))
  assert_true(
    output.css.contains("color-mix(in srgb,var(--paint-ink),var(--paint-live))"),
  )
  match @extract.decode_bundle(output.manifest) {
    Ok(bundle) => assert_true(@extract.validate_bundle(bundle).is_empty())
    Err(_) => fail("theme/paint contract bundle must round trip")
  }
}

///|
test "mixed paint fallbacks authorize every origin and retain shared slots" {
  let scope = @moonstyle.variable_scope("paint-fallback")
  let red = @moonstyle.named_color("red")
  let ink = scope.color_token("ink", red)
  let live = scope.color_slot("live", red)
  let other = scope.color_slot("other", red)
  let none = @moonstyle.paint_none()
  let colors = @moonstyle.scrollbar_colors(thumb=live, track=live)
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "theme/fallbacks",
      [
        @moonstyle.rule("allowed").fill_fallbacks(
          @moonstyle.SvgPaintFallbacks::new()
          .add(red)
          .add(ink)
          .add(live)
          .add(none)
          .add(@moonstyle.CssWideKeyword::Inherit),
        ),
        @moonstyle.rule("forbidden").fill_fallbacks(
          @moonstyle.SvgPaintFallbacks::new().add(ink).add(other),
        ),
        @moonstyle.rule("scroll").scrollbar_color_fallbacks(
          @moonstyle.ScrollbarColorFallbacks::new()
          .add(@moonstyle.scrollbar_auto())
          .add(colors),
        ),
        @moonstyle.rule("scheme").color_scheme_fallbacks(
          @moonstyle.ColorSchemeFallbacks::new()
          .add(@moonstyle.normal_color_scheme())
          .add(@moonstyle.CssWideKeyword::RevertLayer),
        ),
        @moonstyle.rule("clear")
        .clear_fill()
        .clear_stroke()
        .clear_scrollbar_color()
        .clear_color_scheme(),
      ],
      contracts=[
        @moonstyle.style_contract("mixed").allow_fill(
          values=[red],
          tokens=[ink],
          slots=[live],
          expressions=[none],
          keywords=[@moonstyle.CssWideKeyword::Inherit],
        ),
      ],
    ),
  )
  assert_true(output.diagnostics.is_empty(), msg=output.manifest)
  assert_true(output.mappings.contains("MixedStyleInput for AllowedStyle"))
  assert_false(output.mappings.contains("MixedStyleInput for ForbiddenStyle"))
  assert_true(output.css.contains("fill:none;fill:inherit"))
  assert_true(
    output.css.contains(
      "scrollbar-color:auto;scrollbar-color:var(--paint-fallback-live) var(--paint-fallback-live)",
    ),
  )
  assert_true(
    output.css.contains("color-scheme:normal;color-scheme:revert-layer"),
  )
  // One live parameter per namespace, despite two references in the scroll pair.
  assert_eq(
    output.mappings.split("paint_fallback_live : @values.Color,").count(),
    3,
  )
}

///|
test "paint expressions validate defaults themes and nested dynamic boundaries" {
  let scope = @moonstyle.variable_scope("paint-errors")
  let bad = scope.color_token("bad", @moonstyle.named_color("not-a-color"))
  let ink = scope.color_token("ink", @moonstyle.named_color("black"))
  let live = scope.color_slot("live", @moonstyle.named_color("red"))
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "theme/errors",
      [
        @moonstyle.rule("bad").fill(@moonstyle.paint(bad)),
        @moonstyle.rule("theme").scrollbar_color(
          @moonstyle.scrollbar_colors(
            thumb=ink,
            track=@moonstyle.named_color("white"),
          ),
        ),
        @moonstyle.rule("animation").animation_name(
          @moonstyle.keyframes("dynamic", [
            @moonstyle.frame(From).stroke(@moonstyle.paint(live)),
          ]),
        ),
      ],
      themes=[
        @moonstyle.theme("bad", [
          ink.with_value(@moonstyle.named_color("invalid-color")),
        ]),
      ],
      recipes=[
        @moonstyle.recipe("dynamic", [
          @moonstyle.rule("base").scrollbar_color(
            @moonstyle.scrollbar_colors(thumb=live, track=ink),
          ),
        ]),
      ],
    ),
  )
  assert_true(output.diagnostics.any(item => item.code == "STYLE_COLOR_NAME"))
  assert_true(output.diagnostics.any(item => item.code.contains("KEYFRAME")))
  assert_true(output.diagnostics.any(item => item.code.contains("RECIPE")))
  let good = @extract.compile_registry(
    @moonstyle.registry("theme/animation", [
      @moonstyle.rule("animation").animation_name(
        @moonstyle.keyframes("paint", [
          @moonstyle.frame(From)
          .fill(ink)
          .stroke(@moonstyle.paint_none())
          .scrollbar_color(@moonstyle.scrollbar_auto()),
          @moonstyle.frame(To).fill(@moonstyle.named_color("white")),
        ]),
      ),
    ]),
  )
  assert_true(good.diagnostics.is_empty(), msg=good.manifest)
  assert_true(good.css.contains("@keyframes"))
}

///|
test "theme paint bundles reject the previous semantic baseline" {
  let output = @extract.compile_registry(
    @moonstyle.registry("theme/bundle", [
      @moonstyle.rule("fill").fill(@moonstyle.named_color("red")),
    ]),
  )
  let baseline = "sha256:00317ce76918cbdd5a9d04f532cba24f18ef556c75c65a91a34198a9561d09a1"
  let parsed = @json.parse(output.manifest)
  guard parsed is { "semantics": { "digest": String(digest), .. }, .. } else {
    fail("missing semantics")
  }
  match
    @extract.decode_bundle(
      output.manifest.replace_all(old=digest, new=baseline),
    ) {
    Err(errors) =>
      assert_true(
        errors.any(item => item.code == "STYLE_BUNDLE_SEMANTICS_MISMATCH"),
      )
    Ok(_) => fail("old semantic lock must be rejected before merging")
  }
}
