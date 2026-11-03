///|
fn min_width_query(value : String) -> @ir.MediaQuery {
  @ir.media_query([@ir.media_feature("width", Min, value)])
}

///|
test "typed declarations compile through the public core package" {
  let style = @ir.style_set("styles", [
    @ir.style_namespace("box", [
      @ir.declaration("color", @ir.text("red")),
      @ir.declaration("width", @ir.text("100%")),
    ]),
  ])
  let compiled = compile(style)
  assert_eq(compiled.rules.length(), 2)
  assert_true(compiled.namespaces[0].entries[0] == ("kMwMTN", Some("x1e2nbdu")))
  assert_true(render_css(compiled).contains("{width:100%}"))
}

///|
test "clear declarations emit only application-order tombstones" {
  let clear_color = @ir.declaration("color", @ir.clear_value())
  let cleared = compile(
    @ir.style_set("styles", [@ir.style_namespace("reset", [clear_color])]),
  )
  assert_true(cleared.namespaces[0].entries == [("kMwMTN", None)])
  assert_true(cleared.rules.is_empty())
  assert_eq(render_css(cleared), "")

  let value_then_clear = compile(
    @ir.style_set("styles", [
      @ir.style_namespace("reset", [
        @ir.declaration("color", @ir.text("red")),
        clear_color,
      ]),
    ]),
  )
  assert_true(value_then_clear.namespaces[0].entries == [("kMwMTN", None)])
  assert_eq(value_then_clear.rules.length(), 1)

  let clear_then_value = compile(
    @ir.style_set("styles", [
      @ir.style_namespace("restored", [
        clear_color,
        @ir.declaration("color", @ir.text("red")),
      ]),
    ]),
  )
  assert_true(
    clear_then_value.namespaces[0].entries == [("kMwMTN", Some("x1e2nbdu"))],
  )
}

///|
test "clear shorthands clear every application-order conflict slot" {
  let compiled = compile(
    @ir.style_set("styles", [
      @ir.style_namespace("reset", [
        @ir.declaration("margin", @ir.clear_value()),
      ]),
    ]),
  )
  assert_eq(compiled.namespaces[0].entries.map(entry => entry.0), [
    "kogj98", "kUOVxO", "keTefX", "koQZXg", "k71WvV", "km5ZXQ", "kqGvvJ", "keoZOQ",
    "k1K539",
  ])
  assert_true(compiled.namespaces[0].entries.every(entry => entry.1 is None))
  assert_true(compiled.rules.is_empty())
}

///|
test "font width aliases replace and clear one another without changing CSS hashes" {
  let stretch = @ir.declaration("fontStretch", @ir.text("condensed"))
  let width = @ir.declaration("fontWidth", @ir.text("expanded"))
  let clear_stretch = @ir.declaration("fontStretch", @ir.clear_value())
  let clear_width = @ir.declaration("fontWidth", @ir.clear_value())
  let fixtures : Array[(Array[@ir.Declaration], String?)] = [
    ([stretch, width], Some("x1dv9x8a")),
    ([width, stretch], Some("xwz2t7")),
    ([stretch, clear_width], None),
    ([width, clear_stretch], None),
    ([clear_stretch, width], Some("x1dv9x8a")),
    ([clear_width, stretch], Some("xwz2t7")),
  ]
  for fixture in fixtures {
    let compiled = compile(
      @ir.style_set("font-alias", [@ir.style_namespace("fixture", fixture.0)]),
    )
    assert_true(compiled.diagnostics.is_empty())
    assert_true(compiled.namespaces[0].entries == [("kQqvRs", fixture.1)])
  }
  let both = compile(
    @ir.style_set("font-alias", [
      @ir.style_namespace("fixture", [stretch, width]),
    ]),
  )
  assert_true(
    both.rules.any(rule => rule.ltr == ".xwz2t7{font-stretch:condensed}"),
  )
  assert_true(
    both.rules.any(rule => rule.ltr == ".x1dv9x8a{font-width:expanded}"),
  )
  assert_false(application_order_migration_safe("fontWidth"))
}

///|
test "the internal font shorthand clears both aliases while raw font stays serialization only" {
  assert_eq(application_order_properties().length(), 386)
  assert_false(application_order_properties().contains("font"))
  assert_false(application_order_migration_safe("font"))
  for property in ["fontStretch", "fontWidth"] {
    let longhand = @ir.declaration(property, @ir.text("condensed"))
    let shorthand = @ir.declaration("font", @ir.text("inherit"))
    let last = compile(
      @ir.style_set("internal-font", [
        @ir.style_namespace("fixture", [longhand, shorthand]),
      ]),
    )
    assert_true(last.diagnostics.is_empty())
    assert_true(last.namespaces[0].entries.contains(("kQqvRs", None)))
    assert_true(
      last.namespaces[0].entries.contains(("kVVagm", Some("xln7xf2"))),
    )
    assert_true(
      last.rules.any(rule => {
        rule.property == "font" && rule.priority100 == 100000
      }),
    )
    let restored = compile(
      @ir.style_set("internal-font", [
        @ir.style_namespace("fixture", [shorthand, longhand]),
      ]),
    )
    assert_true(
      restored.namespaces[0].entries.any(entry => {
        entry.0 == "kQqvRs" && entry.1 is Some(_)
      }),
    )
  }
  let raw = compile(
    @ir.style_set("raw-font", [
      @ir.style_namespace("fixture", [
        @ir.declaration("font", @ir.text("inherit"), unsafe_raw=true),
      ]),
    ]),
  )
  assert_true(raw.diagnostics.is_empty())
  assert_true(raw.namespaces[0].entries == [("font", Some("xln7xf2"))])
  assert_eq(raw.rules[0].priority100, 300000)
}

///|
test "clear declarations reject CSS conditions" {
  let compiled = compile(
    @ir.style_set("styles", [
      @ir.style_namespace("invalid", [
        @ir.declaration("color", @ir.clear_value(), conditions=[
          @ir.pseudo(Hover),
        ]),
      ]),
    ]),
  )
  assert_eq(compiled.diagnostics.length(), 1)
  assert_eq(compiled.diagnostics[0].code, "STYLE_CLEAR_CONDITION")
  assert_true(compiled.namespaces[0].entries.is_empty())
  assert_true(compiled.rules.is_empty())
}

///|
test "base and conditional classes share one application-order slot" {
  let style = @ir.style_set("styles", [
    @ir.style_namespace("box", [
      @ir.declaration("color", @ir.text("red")),
      @ir.declaration("color", @ir.text("blue"), conditions=[@ir.pseudo(Hover)]),
    ]),
  ])
  let entries = compile(style).namespaces[0].entries
  assert_eq(entries.length(), 1)
  assert_true(entries[0] == ("kMwMTN", Some("x1e2nbdu x17z2mba")))
}

///|
test "conditional shorthands participate in application order through base slots" {
  let top = @ir.declaration("marginTop", @ir.text("16px"))
  let hover_margin = @ir.declaration("margin", @ir.text("8px"), conditions=[
    @ir.pseudo(Hover),
  ])
  let shorthand_last = compile(
      @ir.style_set("styles", [
        @ir.style_namespace("fixture", [top, hover_margin]),
      ]),
    ).namespaces[0].entries
  assert_true(shorthand_last.search_by(entry => entry.0 == "kogj98") is Some(_))
  let top_slot = shorthand_last.search_by(entry => entry.0 == "keoZOQ")
  assert_true(top_slot is Some(index) && shorthand_last[index].1 is None)

  let longhand_last = compile(
      @ir.style_set("styles", [
        @ir.style_namespace("fixture", [hover_margin, top]),
      ]),
    ).namespaces[0].entries
  let live_top = longhand_last.search_by(entry => entry.0 == "keoZOQ")
  assert_true(
    live_top is Some(index) && longhand_last[index].1 == Some("xw7yly9"),
  )
}

///|
test "application-order shorthands retain one rule and emit conflict tombstones" {
  let declaration = @ir.declaration("margin", @ir.text("8px"))
  let compiled = compile(
    @ir.style_set("styles", [@ir.style_namespace("box", [declaration])]),
  )
  assert_eq(compiled.namespaces[0].entries.map(entry => entry.0), [
    "kogj98", "kUOVxO", "keTefX", "koQZXg", "k71WvV", "km5ZXQ", "kqGvvJ", "keoZOQ",
    "k1K539",
  ])
  assert_eq(compiled.rules.length(), 1)
  assert_eq(compiled.rules[0].priority100, 100000)
  assert_true(compiled.rules[0].ltr.contains("{margin:8px}"))
  assert_true(compiled.namespaces[0].entries[0].1 is Some(_))
  assert_true(
    compiled.namespaces[0].entries[1:]
    .to_owned()
    .every(entry => entry.1 is None),
  )
}

///|
test "logical properties remain logical and emit application-order tombstones" {
  let declaration = @ir.declaration("marginInlineStart", @ir.text("8px"))
  let compiled = compile(
    @ir.style_set("styles", [@ir.style_namespace("box", [declaration])]),
  )
  let rule = compiled.rules[0]
  assert_eq(rule.class_name, "x13fj5qh")
  assert_eq(rule.priority100, 300000)
  assert_eq(rule.ltr, ".x13fj5qh{margin-inline-start:8px}")
  assert_true(rule.rtl is None)
  assert_true(
    compiled.namespaces[0].entries ==
    [("keTefX", Some("x13fj5qh")), ("koQZXg", None), ("km5ZXQ", None)],
  )
  assert_eq(
    render_css(compiled),
    ".x13fj5qh:not(#\\#):not(#\\#){margin-inline-start:8px}",
  )
}

///|
test "logical properties remain direct inside nested conditions" {
  let declaration = @ir.declaration("paddingInlineEnd", @ir.text("12px"), conditions=[
    @ir.pseudo(Hover),
    @ir.media(min_width_query("40rem")),
  ])
  let css = render_css(
    compile(
      @ir.style_set("styles", [@ir.style_namespace("box", [declaration])]),
    ),
  )
  assert_true(css.contains("@media (min-width:40rem){."))
  assert_true(css.contains("{padding-inline-end:12px}"))
  assert_false(css.contains("html[dir="))
}

///|
test "structured conditions render canonical nested CSS" {
  let declaration = @ir.declaration("color", @ir.text("red"), conditions=[
    @ir.pseudo_element(Before),
    @ir.media(min_width_query("40rem")),
    @ir.supports(@ir.supports_declaration("display", "grid")),
    @ir.layer("components"),
  ])
  let compiled = compile(
    @ir.style_set("styles", [@ir.style_namespace("badge", [declaration])]),
  )
  let rule = compiled.rules[0]
  assert_true(rule.ltr.contains("." + rule.class_name + "::before{color:red}"))
  assert_false(rule.ltr.contains("." + rule.class_name + "." + rule.class_name))
  assert_true(rule.ltr.contains("@media (min-width:40rem)"))
  assert_true(rule.ltr.contains("@supports (display:grid)"))
  assert_true(rule.ltr.contains("@layer components"))
}

///|
test "condition priorities match the pinned StyleX profile" {
  let conditions = [
    ([@ir.pseudo(Hover)], 313000),
    ([@ir.pseudo(Focus)], 315000),
    ([@ir.pseudo(FocusVisible)], 304000),
    ([@ir.pseudo_element(Before)], 800000),
    ([@ir.media(min_width_query("40rem"))], 320000),
    ([@ir.supports(@ir.supports_declaration("display", "grid"))], 303000),
    (
      [
        @ir.container(
          @ir.container_query([@ir.media_feature("width", Min, "40rem")]),
        ),
      ],
      330000,
    ),
  ]
  for fixture in conditions {
    let compiled = compile(
      @ir.style_set("styles", [
        @ir.style_namespace("condition", [
          @ir.declaration("color", @ir.text("red"), conditions=fixture.0),
        ]),
      ]),
    )
    assert_eq(compiled.rules[0].priority100, fixture.1)
  }
}

///|
test "relational priorities match StyleX 0.19 fixed-point ordering" {
  let relations : Array[(@ir.MarkerRelation, Int32)] = [
    (MarkerAncestor, 301130),
    (MarkerDescendant, 301630),
    (MarkerAnySibling, 302130),
    (MarkerSiblingBefore, 303130),
    (MarkerSiblingAfter, 304130),
  ]
  for fixture in relations {
    let marker = @ir.selector_marker_ref(
      "fixture/relations",
      "group",
      "mgroup",
      states=[@ir.SelectorPseudo(Hover)],
    )
    let compiled = compile(
      @ir.style_set("styles", [
        @ir.style_namespace("relation", [
          @ir.declaration("color", @ir.text("red"), conditions=[
            @ir.relational(marker, fixture.0),
          ]),
        ]),
      ]),
    )
    assert_eq(compiled.rules[0].priority100, fixture.1)
  }
}

///|
test "relational attribute, compound, and stateless priorities are explicit" {
  let fixtures = [
    (
      @ir.selector_marker_ref("fixture/relations", "attribute", "mattribute", states=[
        @ir.SelectorAttributeEquals("aria-expanded", "true"),
      ]),
      304000,
    ),
    (
      @ir.selector_marker_ref("fixture/relations", "compound", "mcompound", states=[
        @ir.SelectorPseudo(Hover),
        @ir.SelectorPseudo(Active),
      ]),
      304000,
    ),
    (
      @ir.selector_marker_ref("fixture/relations", "stateless", "mstateless"),
      301000,
    ),
  ]
  for fixture in fixtures {
    let compiled = compile(
      @ir.style_set("styles", [
        @ir.style_namespace("relation", [
          @ir.declaration("color", @ir.text("red"), conditions=[
            @ir.relational(fixture.0, MarkerAncestor),
          ]),
        ]),
      ]),
    )
    assert_eq(compiled.rules[0].priority100, fixture.1)
  }
}

///|
test "condition keys match canonical selector order and preserve nesting" {
  let declaration = @ir.declaration("color", @ir.text("red"), conditions=[
    @ir.pseudo(Hover),
    @ir.layer("components"),
    @ir.pseudo_element(Before),
    @ir.pseudo(Focus),
    @ir.media(min_width_query("40rem")),
  ])
  let compiled = compile(
    @ir.style_set("styles", [@ir.style_namespace("badge", [declaration])]),
  )
  assert_eq(compiled.namespaces[0].entries[0].0, "kMwMTN")
  assert_true(compiled.rules[0].ltr.contains(":focus:hover::before"))
  assert_true(
    compiled.rules[0].ltr.has_prefix(
      "@media (min-width:40rem){@layer components{",
    ),
  )
}

///|
test "invalid structured conditions produce stable diagnostics" {
  let invalid = [
    (@ir.unsafe_pseudo_element(":before"), "STYLE1006"),
    (@ir.media(@ir.media_query([])), "STYLE1007"),
    (@ir.supports(@ir.supports_all([])), "STYLE1008"),
    (@ir.layer(""), "STYLE1009"),
  ]
  for fixture in invalid {
    let compiled = compile(
      @ir.style_set("styles", [
        @ir.style_namespace("invalid", [
          @ir.declaration("color", @ir.text("red"), conditions=[fixture.0]),
        ]),
      ]),
    )
    assert_eq(compiled.diagnostics[0].code, fixture.1)
  }
}

///|
test "typed condition variants serialize canonically" {
  let pseudo_classes : Array[(@ir.PseudoClass, String)] = [
    (Hover, ":hover"),
    (Focus, ":focus"),
    (FocusVisible, ":focus-visible"),
    (FocusWithin, ":focus-within"),
    (Active, ":active"),
    (Disabled, ":disabled"),
    (Enabled, ":enabled"),
    (Checked, ":checked"),
    (Required, ":required"),
    (Optional, ":optional"),
    (ReadOnly, ":read-only"),
    (ReadWrite, ":read-write"),
    (PlaceholderShown, ":placeholder-shown"),
    (FirstChild, ":first-child"),
    (LastChild, ":last-child"),
    (OnlyChild, ":only-child"),
    (Empty, ":empty"),
    (Link, ":link"),
    (Visited, ":visited"),
  ]
  for fixture in pseudo_classes {
    let compiled = compile(
      @ir.style_set("styles", [
        @ir.style_namespace("typed", [
          @ir.declaration("color", @ir.text("red"), conditions=[
            @ir.pseudo(fixture.0),
          ]),
        ]),
      ]),
    )
    assert_true(compiled.rules[0].ltr.contains(fixture.1 + "{color:red}"))
  }
  let pseudo_elements : Array[(@ir.PseudoElement, String)] = [
    (Before, "::before"),
    (After, "::after"),
    (Placeholder, "::placeholder"),
    (Selection, "::selection"),
    (Marker, "::marker"),
    (FirstLetter, "::first-letter"),
    (FirstLine, "::first-line"),
  ]
  for fixture in pseudo_elements {
    let compiled = compile(
      @ir.style_set("styles", [
        @ir.style_namespace("typed", [
          @ir.declaration("color", @ir.text("red"), conditions=[
            @ir.pseudo_element(fixture.0),
          ]),
        ]),
      ]),
    )
    assert_true(compiled.rules[0].ltr.contains(fixture.1 + "{color:red}"))
  }
}

///|
// StyleX #1888: media types are not parenthesized feature expressions.
test "responsive media types retain print negation and speech semantics" {
  let fixtures : Array[(@ir.MediaType, Bool, String)] = [
    (Screen, false, "screen"),
    (Print, false, "print"),
    (Print, true, "not print"),
    (Speech, false, "speech"),
  ]
  for (media_type, negated, expected) in fixtures {
    for features in [[], [@ir.media_feature("width", Min, "640px")]] {
      let query = @ir.media_query(
        features,
        negated~,
        media_type=Some(media_type),
      )
      let compiled = compile(
        @ir.style_set("styles", [
          @ir.style_namespace("responsive", [
            @ir.declaration("color", @ir.text("red"), conditions=[
              @ir.media(query),
            ]),
          ]),
        ]),
      )
      assert_true(compiled.diagnostics.is_empty())
      assert_eq(compiled.rules.length(), 1)
      let suffix = if features.is_empty() {
        ""
      } else {
        " and (min-width:640px)"
      }
      assert_true(
        render_css(compiled).has_prefix("@media " + expected + suffix + "{."),
        msg=render_css(compiled),
      )
    }
  }
}

///|
test "typed media and supports composition use stable canonical syntax" {
  let query = @ir.media_query(
    [
      @ir.media_feature("width", Min, "40rem"),
      @ir.media_feature("resolution", GreaterThan, "2dppx"),
    ],
    negated=true,
    media_type=Some(Screen),
  )
  let supports = @ir.supports_any([
    @ir.supports_declaration("display", "grid"),
    @ir.supports_not(@ir.supports_declaration("display", "flex")),
  ])
  let compiled = compile(
    @ir.style_set("styles", [
      @ir.style_namespace("typed", [
        @ir.declaration("color", @ir.text("red"), conditions=[
          @ir.media(query),
          @ir.supports(supports),
        ]),
      ]),
    ]),
  )
  assert_true(
    compiled.rules[0].ltr.contains(
      "@media not screen and (min-width:40rem) and (resolution > 2dppx)",
    ),
  )
  assert_true(
    compiled.rules[0].ltr.contains(
      "@supports (display:grid) or not (display:flex)",
    ),
  )
}

///|
test "unsafe conditions reject delimiters that could escape their wrapper" {
  let invalid = [
    @ir.unsafe_pseudo(":hover; color:red"),
    @ir.unsafe_pseudo_element("::before{}"),
    @ir.unsafe_at_rule("@media (width > 1px) /* open"),
    @ir.unsafe_at_rule("@media (width > 1px"),
  ]
  for condition in invalid {
    let compiled = compile(
      @ir.style_set("styles", [
        @ir.style_namespace("invalid", [
          @ir.declaration("color", @ir.text("red"), conditions=[condition]),
        ]),
      ]),
    )
    assert_eq(compiled.rules.length(), 0)
    assert_eq(compiled.diagnostics.length(), 1)
  }
}

///|
test "ordered fallbacks share one atomic rule and reject empty lists" {
  let declaration = @ir.declaration(
    "color",
    @ir.fallbacks(["rgb(1 2 3)", "color(display-p3 1 0 0)"]),
    conditions=[@ir.pseudo(Hover)],
  )
  let compiled = compile(
    @ir.style_set("styles", [@ir.style_namespace("button", [declaration])]),
  )
  assert_eq(compiled.rules.length(), 1)
  assert_true(
    compiled.rules[0].ltr.contains(
      ":hover{color:rgb(1 2 3);color:color(display-p3 1 0 0)}",
    ),
  )
  let invalid = compile(
    @ir.style_set("styles", [
      @ir.style_namespace("invalid", [
        @ir.declaration("color", @ir.fallbacks([])),
      ]),
    ]),
  )
  assert_eq(invalid.diagnostics[0].code, "STYLE_FALLBACK_EMPTY")
}

///|
fn fade_animation() -> @ir.AnimationName {
  @ir.keyframes("fade", [
    @ir.keyframe_frame(From, [
      @ir.declaration("opacity", @ir.text("0"), keyframe_allowed=true),
    ]),
    @ir.keyframe_frame(To, [
      @ir.declaration("opacity", @ir.text("1"), keyframe_allowed=true),
    ]),
  ])
}

///|
test "keyframes produce deterministic global rules and animation names" {
  let animation = fade_animation()
  let declaration = @ir.declaration("animationName", @ir.animation(animation))
  let first = compile(
    @ir.style_set("styles", [@ir.style_namespace("box", [declaration])]),
  )
  let second = compile(
    @ir.style_set("styles", [@ir.style_namespace("box", [declaration])]),
  )
  assert_true(first == second)
  assert_eq(first.globals.length(), 1)
  assert_true(first.globals[0].css.has_prefix("@keyframes k"))
  assert_true(first.globals[0].css.contains("from{opacity:0}to{opacity:1}"))
  assert_true(first.globals[0].digest.has_prefix("sha256:"))
  assert_true(first.rules[0].ltr.contains("animation-name:k"))
  assert_true(render_css(first).has_prefix("@keyframes "))
}

///|
test "invalid keyframes fail with stable diagnostics" {
  let invalid = [
    (@ir.keyframes("empty", []), "STYLE_KEYFRAMES_EMPTY"),
    (
      @ir.keyframes("percent", [
        @ir.keyframe_frame(Percent(101), [
          @ir.declaration("opacity", @ir.text("1"), keyframe_allowed=true),
        ]),
      ]),
      "STYLE_KEYFRAME_PERCENT",
    ),
    (
      @ir.keyframes("condition", [
        @ir.keyframe_frame(From, [
          @ir.declaration(
            "opacity",
            @ir.text("0"),
            conditions=[@ir.pseudo(Hover)],
            keyframe_allowed=true,
          ),
        ]),
      ]),
      "STYLE_KEYFRAME_CONDITION",
    ),
    (
      @ir.keyframes("scheme", [
        @ir.keyframe_frame(From, [
          @ir.declaration(
            "colorScheme",
            @ir.text("dark"),
            keyframe_allowed=true,
          ),
        ]),
      ]),
      "STYLE_KEYFRAME_PROPERTY",
    ),
    (
      @ir.keyframes("scheme-css-name", [
        @ir.keyframe_frame(From, [
          @ir.declaration(
            "color-scheme",
            @ir.text("dark"),
            keyframe_allowed=true,
          ),
        ]),
      ]),
      "STYLE_KEYFRAME_PROPERTY",
    ),
    (
      @ir.keyframes("unsafe", [
        @ir.keyframe_frame(From, [@ir.declaration("custom", @ir.text("value"))]),
      ]),
      "STYLE_KEYFRAME_PROPERTY",
    ),
  ]
  for fixture in invalid {
    let compiled = compile(
      @ir.style_set("styles", [
        @ir.style_namespace("invalid", [
          @ir.declaration("animationName", @ir.animation(fixture.0)),
        ]),
      ]),
    )
    assert_eq(compiled.rules.length(), 0)
    assert_eq(compiled.globals.length(), 0)
    assert_eq(compiled.diagnostics[0].code, fixture.1)
  }
}

///|
test "legacy atomic expansion and multiple pseudo-elements are diagnosed" {
  let invalid = [
    (
      @ir.declaration("margin", @ir.text("8px"), atomic_properties=[""]),
      "STYLE_LEGACY_ATOMIC_PROPERTIES",
    ),
    (
      @ir.declaration("margin", @ir.text("8px"), atomic_properties=[
        "marginTop", "marginTop",
      ]),
      "STYLE_LEGACY_ATOMIC_PROPERTIES",
    ),
    (
      @ir.declaration("color", @ir.text("red"), conditions=[
        @ir.pseudo_element(Before),
        @ir.pseudo_element(After),
      ]),
      "STYLE1012",
    ),
  ]
  for fixture in invalid {
    let compiled = compile(
      @ir.style_set("styles", [@ir.style_namespace("invalid", [fixture.0])]),
    )
    assert_eq(compiled.rules.length(), 0)
    assert_eq(compiled.diagnostics[0].code, fixture.1)
  }
}

///|
test "unsafe declarations retain self-slot conflict semantics" {
  let declaration = @ir.declaration("margin", @ir.text("8px"), unsafe_raw=true)
  let compiled = compile(
    @ir.style_set("styles", [@ir.style_namespace("unsafe", [declaration])]),
  )
  assert_true(compiled.namespaces[0].entries == [("margin", Some("xkib98w"))])
}

///|
test "MurmurHash2 and class names match StyleX 0.19" {
  assert_eq(hash("<>colorrednull"), "1e2nbdu")
  assert_eq(class_name("colorrednull"), "x1e2nbdu")
  assert_eq(class_name("displaygridnull"), "xrvj5dj")
  assert_eq(class_name("width100%null"), "xh8yej3")
}

///|
test "property and value normalization matches the selected StyleX subset" {
  assert_eq(dashify("backgroundColor"), "background-color")
  assert_eq(dashify("WebkitLineClamp"), "-webkit-line-clamp")
  assert_eq(dashify("--custom"), "--custom")
  assert_eq(
    canonical_css_value(" rgba(30, 45, 60, 0.12) "),
    "rgba(30,45,60,.12)",
  )
  assert_eq(
    canonical_css_value("Inter, ui-sans-serif, system-ui"),
    "Inter,ui-sans-serif,system-ui",
  )
}

///|
test "atomic compilation is stable, sorted, and deduplicated" {
  let color = @ir.declaration("color", @ir.text("red"))
  let width = @ir.declaration("width", @ir.text("100%"))
  let margin = @ir.declaration("margin", @ir.text("0 0 12px"))
  let compiled = compile(
    @ir.style_set("styles", [
      @ir.style_namespace("a", [color, width, margin]),
      @ir.style_namespace("b", [color]),
    ]),
  )
  assert_true(compiled.namespaces[0].entries[0] == ("kMwMTN", Some("x1e2nbdu")))
  assert_eq(compiled.rules.length(), 3)
  assert_eq(compiled.rules[0].priority100, 100000)
  assert_eq(compiled.rules[1].ltr, ".x1e2nbdu{color:red}")
  assert_eq(compiled.rules[2].priority100, 400000)
  assert_eq(
    render_css(compiled),
    ".xjgi5au{margin:0 0 12px}\n.x1e2nbdu:not(#\\#):not(#\\#){color:red}\n.xh8yej3:not(#\\#):not(#\\#):not(#\\#){width:100%}",
  )
}

///|
test "dynamic variable references retain legacy normalization" {
  let compiled = compile(
    @ir.style_set("styles", [
      @ir.style_namespace("meter", [
        @ir.declaration("width", @ir.dynamic(" --progress ", "%")),
      ]),
    ]),
  )
  assert_true(compiled.rules[0].ltr.contains("width:var(--progress)"))
}

///|
test "invalid declarations retain source-aware diagnostics" {
  let source = @ir.source_span("components/button.mbt", 12, 7, symbol="button")
  let invalid = @ir.declaration("", @ir.text("red"), source=Some(source))
  let compiled = compile(
    @ir.style_set("styles", [@ir.style_namespace("button", [invalid])]),
  )
  assert_eq(compiled.rules.length(), 0)
  assert_eq(compiled.diagnostics.length(), 1)
  assert_eq(compiled.diagnostics[0].code, "STYLE1001")
  assert_true(compiled.diagnostics[0].source == Some(source))
}

///|
fn color_variable(
  name : String,
  color : @values.Color,
) -> @values.CssVar[@values.Color] {
  @values.color_var("theme", name, color) catch {
    _ => abort("test variable is valid")
  }
}

///|
test "variable and theme globals validate, sort, and hash deterministically" {
  let surface = color_variable("surface", @values.rgb(255, 255, 255))
  let text = color_variable("text", @values.rgb(20, 30, 40))
  let variables = @ir.define_vars("theme", [
    surface.definition(),
    text.definition(),
  ])
  let dark = @ir.create_theme("dark", variables, [
    @values.override_color(surface, @values.rgb(20, 30, 40)),
    @values.override_color(text, @values.rgb(240, 245, 250)),
  ])
  let (first, diagnostics) = compile_registry_globals(
    "example/module",
    [variables],
    [dark],
  )
  let (second, _) = compile_registry_globals("example/module", [variables], [
    dark,
  ])
  assert_true(diagnostics.is_empty())
  assert_true(first == second)
  assert_eq(first.map(global => global.kind), ["variables", "theme"])
  assert_true(first[0].css.contains("--theme-surface:"))
  assert_true(first[1].css.has_prefix(".t"))
  assert_true(first.every(global => global.digest.has_prefix("sha256:")))

  let (_, empty_diagnostics) = compile_registry_globals(
    "example/module",
    [@ir.define_vars("theme", [])],
    [],
  )
  assert_eq(empty_diagnostics[0].code, "STYLE_VARIABLE_SET_EMPTY")
  let duplicate = @ir.define_vars("theme", [
    surface.definition(),
    surface.definition(),
  ])
  let (_, duplicate_diagnostics) = compile_registry_globals(
    "example/module",
    [duplicate],
    [],
  )
  assert_eq(duplicate_diagnostics[0].code, "STYLE_VARIABLE_DUPLICATE")
  let invalid_theme = @ir.create_theme("invalid", variables, [
    {
      name: "--theme-missing",
      value_css: "1",
      category: @values.NumberCategory,
    },
  ])
  let (_, theme_diagnostics) = compile_registry_globals(
    "example/module",
    [variables],
    [invalid_theme],
  )
  assert_eq(theme_diagnostics[0].code, "STYLE_THEME_UNKNOWN_VARIABLE")
}
