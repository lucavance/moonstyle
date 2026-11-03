///|
fn fixtures() -> Array[(String, String, String)] {
  [
    ("page-auto", "page", "auto"),
    ("page-custom-ident", "page", "MoonStyleReport"),
    ("color-red", "color", "red"),
    ("background-white", "backgroundColor", "#ffffff"),
    ("display-grid", "display", "grid"),
    ("width-percent", "width", "100%"),
    ("height-px", "height", "12px"),
    ("min-height-viewport", "minHeight", "100vh"),
    ("margin-four", "margin", "0 0 12px"),
    ("padding-one", "padding", "24px"),
    ("border-color", "borderColor", "#cad3dc"),
    ("border-radius", "borderRadius", "8px"),
    ("border-style", "borderStyle", "solid"),
    ("border-width", "borderWidth", "1px"),
    ("font-family", "fontFamily", "Inter, ui-sans-serif, system-ui, sans-serif"),
    ("font-size", "fontSize", "16px"),
    ("font-weight", "fontWeight", "700"),
    ("font-stretch-condensed", "fontStretch", "condensed"),
    ("font-width-expanded", "fontWidth", "expanded"),
    ("font-width-percentage", "fontWidth", "75%"),
    ("font-shorthand-inherit", "font", "inherit"),
    ("line-height", "lineHeight", "1.2"),
    ("box-shadow", "boxShadow", "0 18px 50px rgba(30, 45, 60, 0.12)"),
    ("opacity", "opacity", "0.5"),
    ("overflow", "overflow", "hidden"),
    ("cursor", "cursor", "pointer"),
    ("math-calc", "width", "calc(40px + 2rem)"),
    ("math-clamp", "width", "clamp(10px, 25%, 100px)"),
    (
      "gradient-linear", "backgroundImage", "linear-gradient(90deg, red 10%, blue)",
    ),
    (
      "gradient-radial", "backgroundImage", "radial-gradient(circle at 50% 50%, red, blue)",
    ),
    (
      "gradient-conic", "backgroundImage", "conic-gradient(from 90deg at 50% 50%, red, blue)",
    ),
    (
      "grid-auto-fit", "gridTemplateColumns", "[start] repeat(auto-fit, minmax(100px, 1fr)) [end]",
    ),
    ("grid-subgrid", "gridTemplateColumns", "subgrid [start] [end]"),
  ]
}

///|
fn directional_fixtures() -> Array[(String, String, String)] {
  [
    ("margin-inline-start", "marginInlineStart", "8px"),
    ("margin-inline-end", "marginInlineEnd", "8px"),
    ("padding-inline-start", "paddingInlineStart", "8px"),
    ("padding-inline-end", "paddingInlineEnd", "8px"),
    ("border-inline-start-color", "borderInlineStartColor", "red"),
    ("border-inline-end-color", "borderInlineEndColor", "red"),
    ("border-inline-start-width", "borderInlineStartWidth", "1px"),
    ("border-inline-end-width", "borderInlineEndWidth", "1px"),
    ("border-inline-start-style", "borderInlineStartStyle", "solid"),
    ("border-inline-end-style", "borderInlineEndStyle", "solid"),
    ("border-start-start-radius", "borderStartStartRadius", "4px"),
    ("border-start-end-radius", "borderStartEndRadius", "4px"),
    ("border-end-start-radius", "borderEndStartRadius", "4px"),
    ("border-end-end-radius", "borderEndEndRadius", "4px"),
  ]
}

///|
fn border_composite_fixtures() -> Array[(String, String, String)] {
  [
    ("border-composite", "border", "2px solid #123"),
    ("border-block-composite", "borderBlock", "thin dotted #123"),
    ("border-inline-colors", "borderInlineColor", "#123 transparent"),
    ("border-top-left-radius-composite", "borderTopLeftRadius", "4px 25%"),
    ("outline-composite", "outline", "thin auto #123"),
  ]
}

///|
fn relational_pseudo_fixtures() -> Array[(String, @ir.PseudoClass)] {
  [
    ("hover", Hover),
    ("focus", Focus),
    ("focus-visible", FocusVisible),
    ("focus-within", FocusWithin),
    ("active", Active),
    ("disabled", Disabled),
    ("enabled", Enabled),
    ("checked", Checked),
    ("required", Required),
    ("optional", Optional),
    ("read-only", ReadOnly),
    ("read-write", ReadWrite),
    ("placeholder-shown", PlaceholderShown),
    ("first-child", FirstChild),
    ("last-child", LastChild),
    ("only-child", OnlyChild),
    ("empty", Empty),
    ("link", Link),
    ("visited", Visited),
    ("valid", Valid),
    ("invalid", Invalid),
    ("in-range", InRange),
    ("out-of-range", OutOfRange),
    ("indeterminate", Indeterminate),
    ("target", Target),
    ("autofill", Autofill),
    ("nth-child(2n+1)", NthChild(2, 1)),
    ("nth-last-child(2n)", NthLastChild(2, 0)),
    ("nth-of-type(3n)", NthOfType(3, 0)),
    ("nth-last-of-type(3n+1)", NthLastOfType(3, 1)),
    ("is(:hover,:focus)", Is([SelectorPseudo(Hover), SelectorPseudo(Focus)])),
    ("not(:disabled)", Not([SelectorPseudo(Disabled)])),
    ("where(:checked)", Where([SelectorPseudo(Checked)])),
  ]
}

///|
fn shorthand_fixtures() -> Array[(String, String, String, Array[String])] {
  [
    (
      "shorthand-margin",
      "margin",
      "8px",
      ["marginTop", "marginInlineEnd", "marginBottom", "marginInlineStart"],
    ),
    (
      "shorthand-padding",
      "padding",
      "8px",
      ["paddingTop", "paddingInlineEnd", "paddingBottom", "paddingInlineStart"],
    ),
    (
      "shorthand-border-color",
      "borderColor",
      "red",
      [
        "borderTopColor", "borderInlineEndColor", "borderBottomColor", "borderInlineStartColor",
      ],
    ),
    (
      "shorthand-border-width",
      "borderWidth",
      "1px",
      [
        "borderTopWidth", "borderInlineEndWidth", "borderBottomWidth", "borderInlineStartWidth",
      ],
    ),
    (
      "shorthand-border-style",
      "borderStyle",
      "solid",
      [
        "borderTopStyle", "borderInlineEndStyle", "borderBottomStyle", "borderInlineStartStyle",
      ],
    ),
    (
      "shorthand-border-radius",
      "borderRadius",
      "4px",
      [
        "borderStartStartRadius", "borderStartEndRadius", "borderEndEndRadius", "borderEndStartRadius",
      ],
    ),
  ]
}

///|
fn print_fixture(name : String, rule : @core.AtomicRule) -> Unit {
  let rtl = match rule.rtl {
    Some(value) => value
    None => "-"
  }
  println(
    name +
    "\t" +
    rule.class_name +
    "\t" +
    rule.priority100.to_string() +
    "\t" +
    rule.ltr +
    "\t" +
    rtl,
  )
}

///|
fn print_clear_fixture(name : String, property : String) -> Unit {
  let compiled = @core.compile(
    @ir.style_set("clear", [
      @ir.style_namespace("fixture", [
        @ir.declaration(property, @ir.clear_value()),
      ]),
    ]),
  )
  let entries = compiled.namespaces[0].entries
    .map(entry => {
      entry.0 +
      "=" +
      (match entry.1 {
        Some(value) => value
        None => "null"
      })
    })
    .join(",")
  println(name + "\t-\t0\t" + entries + "\t-")
}

///|
fn font_alias_fixtures() -> Unit {
  let declarations = [
    @ir.declaration("fontStretch", @ir.text("condensed")),
    @ir.declaration("fontWidth", @ir.text("expanded")),
    @ir.declaration("fontStretch", @ir.clear_value()),
    @ir.declaration("fontWidth", @ir.clear_value()),
    @ir.declaration("font", @ir.text("inherit")),
    @ir.declaration("font", @ir.clear_value()),
  ]
  let styles = declarations.map(declaration => {
    let compiled = @core.compile(
      @ir.style_set("font-alias", [
        @ir.style_namespace("fixture", [declaration]),
      ]),
    )
    @runtime.compiled_v5(compiled.namespaces[0].entries)
  })
  for
    fixture in [
      ("stretch-width", 0, 1),
      ("width-stretch", 1, 0),
      ("stretch-clear-width", 0, 3),
      ("width-clear-stretch", 1, 2),
      ("clear-stretch-width", 2, 1),
      ("clear-width-stretch", 3, 0),
      ("width-font", 1, 4),
      ("stretch-font", 0, 4),
      ("font-width", 4, 1),
      ("font-stretch", 4, 0),
      ("width-clear-font", 1, 5),
      ("stretch-clear-font", 0, 5),
    ] {
    let applied = @runtime.props([styles[fixture.1], styles[fixture.2]])
    println("font-alias/" + fixture.0 + "\t" + applied.class_name + "\t0\t-\t-")
  }
}

///|
fn main {
  for fixture in fixtures() {
    let compiled = @core.compile(
      @ir.style_set("fixtures", [
        @ir.style_namespace("fixture", [
          @ir.declaration(fixture.1, @ir.text(fixture.2)),
        ]),
      ]),
    )
    print_fixture(fixture.0, compiled.rules[0])
  }
  for fixture in directional_fixtures() {
    let compiled = @core.compile(
      @ir.style_set("fixtures", [
        @ir.style_namespace("fixture", [
          @ir.declaration(fixture.1, @ir.text(fixture.2)),
        ]),
      ]),
    )
    print_fixture(fixture.0, compiled.rules[0])
  }
  for fixture in border_composite_fixtures() {
    let compiled = @core.compile(
      @ir.style_set("fixtures", [
        @ir.style_namespace("fixture", [
          @ir.declaration(fixture.1, @ir.text(fixture.2)),
        ]),
      ]),
    )
    print_fixture(fixture.0, compiled.rules[0])
  }
  for fixture in shorthand_fixtures() {
    let compiled = @core.compile(
      @ir.style_set("fixtures", [
        @ir.style_namespace("fixture", [
          @ir.declaration(fixture.1, @ir.text(fixture.2)),
        ]),
      ]),
    )
    print_fixture(fixture.0, compiled.rules[0])
  }
  let conditional = @core.compile(
    @ir.style_set("fixtures", [
      @ir.style_namespace("fixture", [
        @ir.declaration("color", @ir.text("red"), conditions=[@ir.pseudo(Hover)]),
      ]),
    ]),
  )
  print_fixture("phase3-condition", conditional.rules[0])
  let relations : Array[(String, @ir.MarkerRelation)] = [
    ("ancestor", MarkerAncestor),
    ("descendant", MarkerDescendant),
    ("any-sibling", MarkerAnySibling),
    ("sibling-before", MarkerSiblingBefore),
    ("sibling-after", MarkerSiblingAfter),
  ]
  for relation in relations {
    for pseudo in relational_pseudo_fixtures() {
      let marker = @ir.selector_marker_ref(
        "fixture/relations",
        "group",
        "mgroup",
        states=[@ir.SelectorPseudo(pseudo.1)],
      )
      let compiled = @core.compile(
        @ir.style_set("fixtures", [
          @ir.style_namespace("fixture", [
            @ir.declaration("color", @ir.text("red"), conditions=[
              @ir.relational(marker, relation.1),
            ]),
          ]),
        ]),
      )
      print_fixture(
        "condition-relation-" + relation.0 + "-" + pseudo.0,
        compiled.rules[0],
      )
    }
  }
  for
    marker_fixture in [
      (
        "attribute",
        @ir.selector_marker_ref(
          "fixture/relations",
          "attribute",
          "mattribute",
          states=[@ir.SelectorAttributeEquals("aria-expanded", "true")],
        ),
      ),
      (
        "compound",
        @ir.selector_marker_ref("fixture/relations", "compound", "mcompound", states=[
          @ir.SelectorPseudo(Hover),
          @ir.SelectorPseudo(Active),
        ]),
      ),
    ] {
    let compiled = @core.compile(
      @ir.style_set("fixtures", [
        @ir.style_namespace("fixture", [
          @ir.declaration("color", @ir.text("red"), conditions=[
            @ir.relational(marker_fixture.1, MarkerAncestor),
          ]),
        ]),
      ]),
    )
    print_fixture(
      "condition-relation-ancestor-" + marker_fixture.0,
      compiled.rules[0],
    )
  }
  let container = @core.compile(
    @ir.style_set("fixtures", [
      @ir.style_namespace("fixture", [
        @ir.declaration("color", @ir.text("red"), conditions=[
          @ir.container(
            @ir.container_query([@ir.media_feature("width", Min, "1px")]),
          ),
        ]),
      ]),
    ]),
  )
  print_fixture("condition-container", container.rules[0])
  let fallback = @core.compile(
    @ir.style_set("fixtures", [
      @ir.style_namespace("fixture", [
        @ir.declaration("color", @ir.fallbacks(["red", "blue"])),
      ]),
    ]),
  )
  print_fixture("phase3-fallback", fallback.rules[0])
  let animation = @ir.keyframes("fade", [
    @ir.keyframe_frame(From, [
      @ir.declaration("opacity", @ir.text("0"), keyframe_allowed=true),
    ]),
    @ir.keyframe_frame(To, [
      @ir.declaration("opacity", @ir.text("1"), keyframe_allowed=true),
    ]),
  ])
  let keyframes = @core.compile(
      @ir.style_set("fixtures", [
        @ir.style_namespace("fixture", [
          @ir.declaration("animationName", @ir.animation(animation)),
        ]),
      ]),
    ).globals[0]
  println(
    "phase3-keyframes\t" + keyframes.name + "\t0\t" + keyframes.css + "\t-",
  )
  print_clear_fixture("clear-color", "color")
  print_clear_fixture("clear-margin", "margin")
  font_alias_fixtures()
  let oracle_properties = @core.application_order_properties()
  oracle_properties.push("font")
  for property in oracle_properties {
    let compiled = @core.compile(
      @ir.style_set("application-order", [
        @ir.style_namespace("fixture", [
          @ir.declaration(property, @ir.text("inherit")),
        ]),
      ]),
    )
    let rule = compiled.rules[0]
    let entries = compiled.namespaces[0].entries
      .map(entry => {
        entry.0 +
        "=" +
        (match entry.1 {
          Some(value) => value
          None => "null"
        })
      })
      .join(",")
    println(
      "application-order/" +
      property +
      "\t" +
      rule.class_name +
      "\t" +
      rule.priority100.to_string() +
      "\t" +
      rule.ltr +
      "\t-\t" +
      entries,
    )
  }
}
