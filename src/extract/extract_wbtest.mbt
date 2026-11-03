///|
test "registry extraction is deterministic and deduplicates rules" {
  let shared = @ir.declaration("color", @ir.text("red"))
  let registry = @ir.registry("example/module", [
    @ir.style_set("styles", [
      @ir.style_namespace("first", [shared]),
      @ir.style_namespace("second", [shared]),
    ]),
  ])
  let first = compile_registry(registry)
  let second = compile_registry(registry)
  assert_true(first == second)
  assert_eq(first.schema_version, 13)
  assert_eq(first.css.split(".x1e2nbdu").count(), 2)
  assert_true(first.manifest.contains("\"schemaVersion\":13"))
  assert_true(
    first.manifest.contains("\"mappingsPackage\":\"example/module/generated\""),
  )
  assert_true(first.manifest.contains("\"contracts\":[]"))
  assert_true(
    first.manifest.contains(
      "\"profile\":\"stylex-0.19.1-application-order+font-aliases-v1\"",
    ),
  )
  assert_true(first.manifest.contains("\"semanticDigest\":\"sha256:"))
  assert_true(first.manifest.contains("\"directDependencies\":[]"))
  assert_true(first.manifest.contains("\"dependencyClosure\":[]"))
  assert_true(first.manifest.contains("\"globals\":[]"))
  assert_true(first.diagnostics.is_empty())
  assert_false(first.manifest.contains("diagnostics"))
}

///|
test "recipe mappings generate typed variants in deterministic cascade order" {
  let contract = @ir.style_contract("button_contract", [
    @ir.any_contract_property("display"),
    @ir.any_contract_property("padding"),
    @ir.any_contract_property("opacity"),
  ])
  let recipe : @ir.Recipe = {
    name: "button",
    base: ["button__base_0"],
    variants: [
      {
        name: "size",
        choices: [
          { value: "small", rules: ["button__size__small_0"], },
          { value: "large", rules: ["button__size__large_0"], },
        ],
        default_value: Some("small"),
        boolean: false,
      },
      {
        name: "disabled",
        choices: [
          { value: "true", rules: ["button__disabled__true_0"], },
          { value: "false", rules: [], },
        ],
        default_value: Some("false"),
        boolean: true,
      },
    ],
    compounds: [
      {
        matches: [
          { axis: "size", value: "large", },
          { axis: "disabled", value: "true", },
        ],
        rules: ["button__compound__0_0"],
      },
    ],
    contract: Some("button_contract"),
  }
  let registry = @ir.registry(
    "fixture/recipes",
    [
      @ir.style_set("styles", []),
      @ir.style_set("recipes", [
        @ir.style_namespace("button__base_0", [
          @ir.declaration("display", @ir.text("flex")),
        ]),
        @ir.style_namespace("button__size__small_0", [
          @ir.declaration("padding", @ir.text("4px")),
        ]),
        @ir.style_namespace("button__size__large_0", [
          @ir.declaration("padding", @ir.text("12px")),
        ]),
        @ir.style_namespace("button__disabled__true_0", [
          @ir.declaration("opacity", @ir.text("0.5")),
        ]),
        @ir.style_namespace("button__compound__0_0", [
          @ir.declaration("opacity", @ir.text("0.4")),
        ]),
      ]),
    ],
    contracts=[contract],
    recipes=[recipe],
  )
  let bundle = compile_registry(registry)
  assert_eq(bundle.diagnostics, [])
  assert_true(bundle.mappings.contains("pub(all) enum ButtonSize"))
  assert_true(bundle.mappings.contains("pub fn button("))
  assert_true(bundle.mappings.contains("disabled? : Bool = false"))
  assert_true(bundle.mappings.contains("-> ButtonContractStyleList"))
  let base = bundle.mappings
    .find("output = output.add(button__base_0)")
    .unwrap()
  let axis = bundle.mappings.find("match size").unwrap()
  let compound = bundle.mappings.find("if size == ButtonSizeLarge").unwrap()
  assert_true(base < axis && axis < compound)
}

///|
test "recipes and exact contracts accept static clear declarations" {
  let contract = @ir.style_contract("exact", [
    @ir.exact_contract_property("color", values=["red"]),
  ])
  let recipe : @ir.Recipe = {
    name: "clear_recipe",
    base: ["clear_recipe__base_0"],
    variants: [],
    compounds: [],
    contract: Some("exact"),
  }
  let bundle = compile_registry(
    @ir.registry(
      "fixture/clear-recipe",
      [
        @ir.style_set("recipes", [
          @ir.style_namespace("clear_recipe__base_0", [
            @ir.declaration("color", @ir.clear_value()),
          ]),
        ]),
      ],
      contracts=[contract],
      recipes=[recipe],
    ),
  )
  assert_true(bundle.diagnostics.is_empty())
  assert_true(bundle.css.trim().has_suffix("Do not edit. */"))
  assert_true(bundle.mappings.contains("(\"kMwMTN\", None)"))
  assert_true(
    bundle.mappings.contains("ExactStyleInput for ClearRecipeBase0Style"),
  )
}

///|
test "recipes reject dynamic slots and unsafe declarations" {
  let recipe : @ir.Recipe = {
    name: "unsafe_recipe",
    base: ["dynamic", "raw"],
    variants: [],
    compounds: [],
    contract: None,
  }
  let bundle = compile_registry(
    @ir.registry(
      "fixture/unsafe-recipe",
      [
        @ir.style_set("recipes", [
          @ir.style_namespace("dynamic", [
            @ir.declaration(
              "width",
              @ir.dynamic("--recipe-width", "0px", category="length"),
            ),
          ]),
          @ir.style_namespace("raw", [
            @ir.declaration("unknown", @ir.text("value"), unsafe_raw=true),
          ]),
        ]),
      ],
      recipes=[recipe],
    ),
  )
  assert_eq(
    bundle.diagnostics
    .filter(diagnostic => diagnostic.code == "STYLE_RECIPE_NON_STATIC")
    .length(),
    2,
  )
}

///|
test "selector markers and named container queries emit stable zero-specificity CSS" {
  let marker : @ir.MarkerDefinition = { name: "group", }
  let marker_ref = @ir.selector_marker_ref("", "group", "", states=[
    @ir.SelectorPseudo(Hover),
  ])
  let registry = @ir.registry(
    "fixture/selectors",
    [
      @ir.style_set("styles", [
        @ir.style_namespace("base", [@ir.declaration("color", @ir.text("red"))]),
        @ir.style_namespace("child", [
          @ir.declaration("color", @ir.text("red"), conditions=[
            @ir.relational(marker_ref, MarkerAncestor),
          ]),
        ]),
        @ir.style_namespace("responsive", [
          @ir.declaration("display", @ir.text("grid"), conditions=[
            @ir.container(
              @ir.container_query(
                [
                  @ir.media_feature("width", Min, "320px"),
                  @ir.media_feature("width", Max, "720px"),
                ],
                name=Some("card"),
              ),
            ),
          ]),
        ]),
      ]),
    ],
    markers=[marker],
  )
  let bundle = compile_registry(registry)
  assert_eq(bundle.diagnostics, [])
  let class_name = @core.selector_marker_class_name(
    "fixture/selectors", "group",
  )
  assert_true(bundle.css.contains(":where(." + class_name + ":hover) .x"))
  let decoded = decode_bundle(bundle.manifest).unwrap()
  let color_rules = decoded.rules.filter(rule => rule.property == "color")
  assert_eq(color_rules.length(), 2)
  assert_true(color_rules[0].class_name != color_rules[1].class_name)
  assert_true(
    bundle.css.contains(
      "@container card (min-width:320px) and (max-width:720px)",
    ),
  )
  assert_true(bundle.mappings.contains("pub let group_marker"))
  assert_true(bundle.manifest.contains("\"markers\":[{"))
  assert_true(bundle.manifest.contains("\"className\":\"" + class_name + "\""))
}

///|
test "artifact v8 validates stable marker identities" {
  let bundle = compile_registry(
    @ir.registry("fixture/marker-validation", [], markers=[{ name: "group", }]),
  )
  let class_name = @core.selector_marker_class_name(
    "fixture/marker-validation", "group",
  )
  let tampered = bundle.manifest.replace_all(
    old="\"className\":\"" + class_name + "\"",
    new="\"className\":\"mforged\"",
  )
  match decode_bundle(tampered) {
    Err(_) => fail("semantic tampering must remain structurally decodable")
    Ok(decoded) => {
      let codes = validate_bundle(decoded).map(diagnostic => diagnostic.code)
      assert_true(codes.contains("STYLE_BUNDLE_DIGEST"))
      assert_true(codes.contains("STYLE_BUNDLE_MARKER"))
    }
  }
}

///|
test "position-try globals and view-transition classes are artifact semantics" {
  let position_try : @ir.PositionTryDefinition = {
    name: "--tooltip-wide",
    descriptors: [
      { name: "position-area", value: "center bottom", },
      { name: "max-width", value: "360px", },
    ],
  }
  let transition : @ir.ViewTransitionClassDefinition = {
    name: "shared",
    styles: [],
  }
  let bundle = compile_registry(
    @ir.registry("fixture/modern", [], position_tries=[position_try], view_transition_classes=[
      transition,
    ]),
  )
  assert_eq(bundle.diagnostics, [])
  // StyleX #1850/#1854: exactly one global block, with no duplicated
  // descriptors, ancestor selectors, or atomic specificity wrappers.
  assert_eq(
    bundle.css,
    "/* Generated by lampclaw/moonstyle/extract schema v13. Do not edit. */\n@position-try --tooltip-wide{position-area:center bottom;max-width:360px}\n",
  )
  assert_true(bundle.manifest.contains("\"kind\":\"position-try\""))
  let css_name = @core.view_transition_class_name("fixture/modern", "shared")
  assert_true(bundle.manifest.contains("\"viewTransitionClasses\":[{"))
  assert_true(bundle.manifest.contains("\"cssName\":\"" + css_name + "\""))
  assert_true(bundle.mappings.contains("pub let shared_view_transition_class"))
}

///|
test "diagnostics are source-aware and render deterministically" {
  let invalid = @ir.declaration(
    "",
    @ir.text("red"),
    source=Some(@ir.source_span("styles.mbt", 12, 7, symbol="button")),
  )
  let registry = @ir.registry("example/module", [
    @ir.style_set("styles", [@ir.style_namespace("button", [invalid])]),
  ])
  let bundle = compile_registry(registry)
  assert_eq(bundle.diagnostics.length(), 1)
  assert_eq(
    render_diagnostics_text(bundle.diagnostics),
    "styles.mbt:12:7: error STYLE1001: CSS property name must not be empty [button]\n",
  )
  assert_eq(
    render_diagnostics_json(bundle.diagnostics),
    "[{\"code\":\"STYLE1001\",\"severity\":\"error\",\"message\":\"CSS property name must not be empty\",\"file\":\"styles.mbt\",\"line\":12,\"column\":7,\"endLine\":12,\"endColumn\":7,\"symbol\":\"button\",\"module\":null,\"artifactPath\":null,\"dependencyChain\":[]}]\n",
  )
}

///|
test "schema v13 preserves shorthand identity and application-order mappings" {
  let expanded = @ir.declaration("gap", @ir.text("8px"))
  let bundle = compile_registry(
    @ir.registry("example/module", [
      @ir.style_set("styles", [@ir.style_namespace("grid", [expanded])]),
    ]),
  )
  assert_eq(bundle.schema_version, 13)
  assert_true(bundle.manifest.contains("[\"kOIVth\""))
  assert_true(bundle.manifest.contains("[\"khm7nJ\",null]"))
  assert_true(bundle.manifest.contains("[\"k1C7PZ\",null]"))
  assert_true(bundle.css.contains("gap:8px"))
}

///|
test "schema v13 preserves logical CSS and nullable conflict entries" {
  let directional = @ir.declaration("marginInlineStart", @ir.text("8px"))
  let bundle = compile_registry(
    @ir.registry("example/module", [
      @ir.style_set("styles", [@ir.style_namespace("box", [directional])]),
    ]),
  )
  assert_true(bundle.manifest.contains("[\"koQZXg\",null]"))
  assert_true(bundle.manifest.contains("\"rtl\":null"))
  assert_true(bundle.mappings.contains("@runtime.compiled_v5"))
  assert_true(bundle.mappings.contains("pub let bundle_ref"))
  assert_true(bundle.mappings.contains("(\"koQZXg\", None)"))
  assert_true(bundle.css.contains("margin-inline-start:8px"))
  assert_false(bundle.css.contains("html[dir="))
}

///|
test "dynamic mappings validate values and return structured errors" {
  let dynamic_width = @ir.declaration(
    "width",
    @ir.dynamic("--demo-progress", "", category="length"),
  )
  let bundle = compile_registry(
    @ir.registry("example/module", [
      @ir.style_set("styles", [@ir.style_namespace("meter", [dynamic_width])]),
    ]),
  )
  assert_true(
    bundle.mappings.contains(
      "Result[MeterStyle, Array[@runtime.DynamicValueError]]",
    ),
  )
  assert_true(
    bundle.mappings.contains(
      "@values.expression_value_issues([\"nonnegative\"]",
    ),
  )
  assert_true(bundle.mappings.contains("\"--demo-progress\""))
  assert_true(bundle.mappings.contains("return Err(errors)"))
}

///|
test "local contracts generate nominal mappings and exact-property capabilities" {
  let contract = @ir.style_contract("button", [
    @ir.any_contract_property("color"),
    @ir.any_contract_property("backgroundColor"),
    @ir.any_contract_property("borderColor"),
  ])
  let dynamic_color = @ir.declaration(
    "color",
    @ir.dynamic("--button-tone", "", category="color"),
  )
  let registry = @ir.registry(
    "component/button",
    [
      @ir.style_set("styles", [
        @ir.style_namespace("allowed", [
          @ir.declaration("color", @ir.text("red")),
        ]),
        @ir.style_namespace("dynamicAllowed", [dynamic_color]),
        @ir.style_namespace("rejected", [
          @ir.declaration("width", @ir.text("10px")),
        ]),
        @ir.style_namespace("unsafe", [
          @ir.declaration("color", @ir.text("red"), unsafe_raw=true),
        ]),
      ]),
    ],
    contracts=[contract],
  )
  let bundle = compile_registry(
    registry,
    mappings_package="component/button/generated",
  )
  assert_true(bundle.diagnostics.is_empty())
  assert_true(bundle.mappings.contains("pub(open) trait ButtonStyleInput"))
  assert_true(bundle.mappings.contains("pub struct ButtonStyleList"))
  assert_true(
    bundle.mappings.contains("pub fn[T : ButtonStyleInput] button_styles"),
  )
  assert_true(
    bundle.mappings.contains("pub impl ButtonStyleInput for AllowedStyle"),
  )
  assert_true(
    bundle.mappings.contains(
      "pub impl ButtonStyleInput for DynamicAllowedStyle",
    ),
  )
  assert_false(bundle.mappings.contains("ButtonStyleInput for RejectedStyle"))
  assert_false(bundle.mappings.contains("ButtonStyleInput for UnsafeStyle"))
  assert_true(
    bundle.mappings.contains(
      "Result[DynamicAllowedStyle, Array[@runtime.DynamicValueError]]",
    ),
  )
  assert_true(
    bundle.manifest.contains(
      "\"properties\":[{\"name\":\"color\",\"policy\":\"any\"},{\"name\":\"borderColor\",\"policy\":\"any\"},{\"name\":\"backgroundColor\",\"policy\":\"any\"}]",
    ),
  )
  assert_true(
    bundle.mappings_manifest.contains(
      "// Generated by lampclaw/moonstyle/extract schema v13. Do not edit.",
    ),
  )
  let noncanonical = bundle.manifest.replace_all(
    old="\"properties\":[{\"name\":\"color\",\"policy\":\"any\"},{\"name\":\"borderColor\",\"policy\":\"any\"},{\"name\":\"backgroundColor\",\"policy\":\"any\"}]",
    new="\"properties\":[{\"name\":\"backgroundColor\",\"policy\":\"any\"},{\"name\":\"borderColor\",\"policy\":\"any\"},{\"name\":\"color\",\"policy\":\"any\"}]",
  )
  match decode_bundle(noncanonical) {
    Err(_) => fail("property order is a validation concern")
    Ok(decoded) => {
      let codes = validate_bundle(decoded).map(diagnostic => diagnostic.code)
      assert_true(codes.contains("STYLE_BUNDLE_DIGEST"))
      assert_true(codes.contains("STYLE_BUNDLE_CONTRACT_PROPERTY_ORDER"))
    }
  }
}

///|
test "exact contract policies distinguish literals tokens and runtime slots" {
  let approved_token = @ir.contract_variable("--component-surface", "color")
  let approved_slot = @ir.contract_variable("--component-tone", "color")
  let contract = @ir.style_contract("exact", [
    @ir.exact_contract_property("color", values=[" red ", "blue"], slots=[
      approved_slot,
    ]),
    @ir.exact_contract_property("backgroundColor", tokens=[approved_token]),
  ])
  let token_declaration = @ir.declaration(
    "backgroundColor",
    @ir.text("var(--component-surface)"),
    value_origin=Some(@ir.TokenOrigin(approved_token)),
  )
  let registry = @ir.registry(
    "component/exact",
    [
      @ir.style_set("styles", [
        @ir.style_namespace("allowed_literal", [
          @ir.declaration("color", @ir.text("red")),
        ]),
        @ir.style_namespace("allowed_clear", [
          @ir.declaration("color", @ir.clear_value()),
        ]),
        @ir.style_namespace("allowed_fallback", [
          @ir.declaration("color", @ir.fallbacks(["red", "blue"])),
        ]),
        @ir.style_namespace("rejected_fallback", [
          @ir.declaration("color", @ir.fallbacks(["red", "green"])),
        ]),
        @ir.style_namespace("allowed_condition", [
          @ir.declaration("color", @ir.text("red"), conditions=[
            @ir.pseudo(Hover),
          ]),
        ]),
        @ir.style_namespace("allowed_slot", [
          @ir.declaration(
            "color",
            @ir.dynamic("--component-tone", "", category="color"),
          ),
        ]),
        @ir.style_namespace("rejected_slot", [
          @ir.declaration(
            "color",
            @ir.dynamic("--component-other", "", category="color"),
          ),
        ]),
        @ir.style_namespace("allowed_token", [token_declaration]),
        @ir.style_namespace("rejected_token_literal", [
          @ir.declaration("backgroundColor", @ir.text("white")),
        ]),
        @ir.style_namespace("rejected_unsafe", [
          @ir.declaration("color", @ir.text("red"), unsafe_raw=true),
        ]),
      ]),
    ],
    contracts=[contract],
  )
  let bundle = compile_registry(registry)
  assert_true(bundle.diagnostics.is_empty())
  for
    accepted in [
      "AllowedLiteralStyle", "AllowedFallbackStyle", "AllowedConditionStyle", "AllowedSlotStyle",
      "AllowedTokenStyle", "AllowedClearStyle",
    ] {
    assert_true(bundle.mappings.contains("ExactStyleInput for " + accepted))
  }
  for
    rejected in [
      "RejectedFallbackStyle", "RejectedSlotStyle", "RejectedTokenLiteralStyle",
      "RejectedUnsafeStyle",
    ] {
    assert_false(bundle.mappings.contains("ExactStyleInput for " + rejected))
  }
  assert_true(
    bundle.manifest.contains(
      "{\"name\":\"backgroundColor\",\"policy\":\"exact\",\"values\":[],\"tokens\":[{\"variable\":\"--component-surface\",\"category\":\"color\"}],\"slots\":[],\"expressions\":[]}",
    ),
  )
  assert_true(
    bundle.manifest.contains(
      "{\"name\":\"color\",\"policy\":\"exact\",\"values\":[\"red\",\"blue\"],\"tokens\":[],\"slots\":[{\"variable\":\"--component-tone\",\"category\":\"color\"}],\"expressions\":[]}",
    ),
  )
  let unknown_policy = bundle.manifest.replace_all(
    old="\"policy\":\"exact\"",
    new="\"policy\":\"unknown\"",
  )
  match decode_bundle(unknown_policy) {
    Ok(_) => fail("unknown contract policies must not decode")
    Err(diagnostics) => assert_eq(diagnostics[0].code, "STYLE_BUNDLE_CONTRACT")
  }
  let noncanonical_values = bundle.manifest.replace_all(
    old="\"values\":[\"red\",\"blue\"]",
    new="\"values\":[\"blue\",\"red\"]",
  )
  match decode_bundle(noncanonical_values) {
    Err(_) => fail("literal order is a validation concern")
    Ok(decoded) => {
      let codes = validate_bundle(decoded).map(diagnostic => diagnostic.code)
      assert_true(codes.contains("STYLE_BUNDLE_DIGEST"))
      assert_true(codes.contains("STYLE_BUNDLE_CONTRACT_VALUE_ORDER"))
    }
  }
}

///|
test "contract diagnostics reject ambiguous generated APIs" {
  let registry = @ir.registry("component/invalid", [], contracts=[
    @ir.style_contract("Bad", [
      @ir.any_contract_property("color"),
      @ir.any_contract_property("unknownProperty"),
      @ir.any_contract_property("color"),
    ]),
    @ir.style_contract("foo_bar", [@ir.any_contract_property("color")]),
    @ir.style_contract("foo__bar", [@ir.any_contract_property("color")]),
    @ir.style_contract("policy", [
      @ir.exact_contract_property("color", values=["red", " red "]),
      @ir.exact_contract_property("width"),
    ]),
  ])
  let codes = compile_registry(registry).diagnostics.map(diagnostic => {
    diagnostic.code
  })
  assert_true(codes.contains("STYLE_CONTRACT_NAME"))
  assert_true(codes.contains("STYLE_CONTRACT_PROPERTY_UNKNOWN"))
  assert_true(codes.contains("STYLE_CONTRACT_PROPERTY_DUPLICATE"))
  assert_true(codes.contains("STYLE_CONTRACT_NAME_COLLISION"))
  assert_true(codes.contains("STYLE_CONTRACT_VALUE_DUPLICATE"))
  assert_true(codes.contains("STYLE_CONTRACT_POLICY_EMPTY"))
}

///|
test "schema v2 migration is explicit and preserves semantic fields" {
  let v2 = "{\"schemaVersion\":2,\"module\":\"example/module\",\"namespaces\":[{\"name\":\"button\",\"entries\":[[\"color\",\"x1\"]]}],\"rules\":[{\"property\":\"color\",\"className\":\"x1\",\"ltr\":\".x1{color:red}\",\"rtl\":null,\"priority\":3000}]}"
  match migrate_v2(v2) {
    Ok(migrated) => {
      assert_true(migrated.contains("\"schemaVersion\":3"))
      assert_true(migrated.contains("\"semanticDigest\":\"sha256:"))
      assert_true(migrated.contains("\"dependencies\":[]"))
      assert_true(migrated.contains("\"globals\":[]"))
      assert_true(migrated.contains("[\"color\",\"x1\"]"))
    }
    Err(_) => fail("valid schema v2 artifact must migrate")
  }
  match migrate_v2("{\"schemaVersion\":3}") {
    Ok(_) => fail("schema v3 must not pass the v2 migration entrypoint")
    Err(diagnostics) => assert_eq(diagnostics[0].code, "STYLE_ARTIFACT_SCHEMA")
  }
}

///|
test "variable and theme globals emit CSS, artifacts, and mappings" {
  let surface = @values.color_var(
    "theme",
    "surface",
    @values.rgb(255, 255, 255),
  ) catch {
    _ => abort("test variable is valid")
  }
  let variables = @ir.define_vars("theme", [surface.definition()])
  let dark = @ir.create_theme("dark-mode", variables, [
    @values.override_color(surface, @values.rgb(20, 30, 40)),
  ])
  let bundle = compile_registry(
    @ir.registry("example/module", [], variable_sets=[variables], themes=[dark]),
  )
  assert_true(bundle.diagnostics.is_empty())
  assert_true(bundle.css.contains("--theme-surface:rgb(255 255 255)"))
  assert_true(bundle.css.contains(".t"))
  assert_true(bundle.manifest.contains("\"kind\":\"variables\""))
  assert_true(bundle.manifest.contains("\"kind\":\"theme\""))
  assert_true(bundle.mappings.contains("pub let dark_mode"))
  assert_true(bundle.mappings.contains("\"theme|theme\""))
}

///|
test "schema v3 migration requires explicit direct dependency roots" {
  let v3 = "{\"schemaVersion\":3,\"module\":\"app/module\",\"semanticDigest\":\"sha256:legacy\",\"dependencies\":[{\"module\":\"lib/a\",\"semanticDigest\":\"sha256:a\"},{\"module\":\"lib/b\",\"semanticDigest\":\"sha256:b\"}],\"namespaces\":[],\"rules\":[],\"globals\":[]}"
  match migrate_v3_to_v4(v3, ["lib/b"]) {
    Ok(migrated) => {
      assert_true(migrated.contains("\"schemaVersion\":4"))
      assert_true(
        migrated.contains(
          "\"directDependencies\":[{\"module\":\"lib/b\",\"semanticDigest\":\"sha256:b\"}]",
        ),
      )
      assert_true(migrated.contains("\"dependencyClosure\":["))
    }
    Err(_) => fail("complete schema v3 artifact must migrate")
  }
  match migrate_v3_to_v4(v3, ["lib/missing"]) {
    Ok(_) => fail("unknown direct dependency must fail migration")
    Err(diagnostics) =>
      assert_eq(diagnostics[0].code, "STYLE_ARTIFACT_DIRECT_DEPENDENCY")
  }
  match decode_bundle(v3) {
    Ok(_) => fail("schema v5 reader must reject schema v3")
    Err(diagnostics) => assert_eq(diagnostics[0].code, "STYLE_BUNDLE_SHAPE")
  }
}

///|
fn schema_v4_fixture(
  module_name : String,
  direct_dependencies~ : Array[BundleDependency] = [],
  dependency_closure~ : Array[BundleDependency] = [],
  namespaces~ : Array[BundleNamespace] = [],
  rules~ : Array[BundleRule] = [],
) -> (String, String) {
  let semantic : Json = {
    "schemaVersion": 4,
    "module": module_name,
    "directDependencies": direct_dependencies.map(dependency_json),
    "dependencyClosure": dependency_closure.map(dependency_json),
    "namespaces": namespaces.map(namespace_json_v3),
    "rules": rules.map(rule_json_v3),
    "globals": [],
  }
  let digest = semantic_digest(semantic.stringify())
  let manifest : Json = {
    "schemaVersion": 4,
    "module": module_name,
    "semanticDigest": digest,
    "directDependencies": direct_dependencies.map(dependency_json),
    "dependencyClosure": dependency_closure.map(dependency_json),
    "namespaces": namespaces.map(namespace_json_v3),
    "rules": rules.map(rule_json_v3),
    "globals": [],
  }
  (manifest.stringify() + "\n", digest)
}

///|
test "schema v4 migration rewrites provable self-conflicts and rejects lossy rules" {
  let color_rule : BundleRule = {
    property: "color",
    class_name: "xcolor",
    ltr: ".xcolor{color:red}",
    rtl: None,
    priority100: 300000,
  }
  let safe = schema_v4_fixture(
    "lib/safe",
    namespaces=[{ name: "safe", entries: [("color", Some("xcolor"))], }],
    rules=[color_rule],
  )
  match migrate_v4_to_v5(safe.0, []) {
    Ok(migrated) => {
      assert_true(migrated.contains("\"schemaVersion\":5"))
      assert_true(migrated.contains("[\"kMwMTN\",\"xcolor\"]"))
      assert_true(
        migrated.contains(
          "\"profile\":\"stylex-0.19.1-application-order+font-aliases-v1\"",
        ),
      )
    }
    Err(_) => fail("unconditioned self-conflict must migrate")
  }
  let shorthand = schema_v4_fixture(
    "lib/shorthand",
    namespaces=[{ name: "unsafe", entries: [("margin", Some("xmargin"))], }],
    rules=[
      {
        property: "margin",
        class_name: "xmargin",
        ltr: ".xmargin{margin:8px}",
        rtl: None,
        priority100: 100000,
      },
    ],
  )
  match migrate_v4_to_v5(shorthand.0, []) {
    Ok(_) => fail("shorthand migration must require re-extraction")
    Err(diagnostics) =>
      assert_eq(diagnostics[0].code, "STYLE_MIGRATION_REEXTRACT_REQUIRED")
  }
}

///|
test "schema v4 dependency migration is explicitly bottom-up" {
  let leaf_v4 = schema_v4_fixture("lib/leaf")
  let leaf_v5 = match migrate_v4_to_v5(leaf_v4.0, []) {
    Ok(value) => value
    Err(_) => abort("leaf v4-to-v5 migration must succeed")
  }
  let leaf_v6 = migrate_v5_to_v6(leaf_v5, "lib/leaf/generated", []).unwrap()
  let leaf_v8 = match migrate_v6_to_v7(leaf_v6, []) {
    Ok(value) =>
      match migrate_v7_to_v8(value, []) {
        Ok(migrated) => migrated
        Err(_) => abort("leaf v7-to-v8 migration must succeed")
      }
    Err(_) => abort("leaf v6-to-v7 migration must succeed")
  }
  assert_true(decode_bundle(leaf_v8) is Err(_))
  let leaf_v9 = dependency_fixture("lib/leaf")
  let old_ref : BundleDependency = {
    module_name: "lib/leaf",
    semantic_digest: leaf_v4.1,
  }
  let root_v4 = schema_v4_fixture("app/root", direct_dependencies=[old_ref], dependency_closure=[
    old_ref,
  ])
  match migrate_v4_to_v5(root_v4.0, []) {
    Ok(_) => fail("root migration without its migrated closure must fail")
    Err(diagnostics) =>
      assert_eq(diagnostics[0].code, "STYLE_MIGRATION_REEXTRACT_REQUIRED")
  }
  match migrate_v4_to_v5(root_v4.0, [leaf_v9]) {
    Ok(migrated) => {
      assert_true(migrated.contains(leaf_v9.semantic_digest))
      match migrate_v5_to_v6(migrated, "app/root/generated", [leaf_v9]) {
        Ok(root_v6) => {
          assert_true(root_v6.contains("\"schemaVersion\":6"))
          assert_true(root_v6.contains("\"contracts\":[]"))
          let root_v7 = migrate_v6_to_v7(root_v6, [leaf_v9]).unwrap()
          assert_true(root_v7.contains("\"schemaVersion\":7"))
          let root_v8 = migrate_v7_to_v8(root_v7, [leaf_v9]).unwrap()
          assert_true(root_v8.contains("\"schemaVersion\":8"))
          assert_true(decode_bundle(root_v8) is Err(_))
        }
        Err(_) => fail("root v5-to-v6 migration must succeed")
      }
    }
    Err(_) => fail("bottom-up dependency migration must succeed")
  }
}

///|
test "schema v5 migration validates mappings packages and canonical digests" {
  let leaf_v4 = schema_v4_fixture("lib/leaf")
  let leaf_v5 = migrate_v4_to_v5(leaf_v4.0, []).unwrap()
  match migrate_v5_to_v6(leaf_v5, "", []) {
    Ok(_) => fail("v5 migration without a mappings package must fail")
    Err(diagnostics) =>
      assert_eq(diagnostics[0].code, "STYLE_MIGRATION_MAPPINGS_PACKAGE")
  }
  let corrupt = leaf_v5.replace_all(
    old="\"semanticDigest\":\"sha256:",
    new="\"semanticDigest\":\"sha256:corrupt",
  )
  match migrate_v5_to_v6(corrupt, "lib/leaf/generated", []) {
    Ok(_) => fail("v5 migration with a corrupt digest must fail")
    Err(diagnostics) => assert_eq(diagnostics[0].code, "STYLE_ARTIFACT_DIGEST")
  }
}

///|
test "schema v6 migration makes every legacy property explicitly any-safe" {
  let contracts : Array[BundleContractV6] = [
    {
      module_name: "component/button",
      name: "button",
      mappings_package: "component/button/generated",
      trait_name: "ButtonStyleInput",
      properties: ["color", "backgroundColor"],
    },
  ]
  let dependencies : Array[BundleDependency] = []
  let namespaces : Array[BundleNamespace] = []
  let rules : Array[BundleRule] = []
  let globals : Array[BundleGlobal] = []
  let semantic = semantic_json_v6(
    "component/button", "component/button/generated", dependencies, dependencies,
    contracts, namespaces, rules, globals,
  )
  let input = render_bundle_manifest_v6(
    "component/button",
    "component/button/generated",
    semantic_digest(semantic.stringify()),
    dependencies,
    dependencies,
    contracts,
    namespaces,
    rules,
    globals,
  )
  let migrated = migrate_v6_to_v7(input, []).unwrap()
  let migrated = migrate_v7_to_v8(migrated, []).unwrap()
  assert_true(migrated.contains("\"policy\":\"any\""))
  assert_true(decode_bundle(migrated) is Err(_))
}

///|
fn dependency_fixture(
  module_name : String,
  dependencies~ : Array[DependencyBundle] = [],
  rules~ : Array[BundleRule] = [],
  globals~ : Array[BundleGlobal] = [],
  namespaces~ : Array[BundleNamespace] = [],
) -> DependencyBundle {
  let closure : Array[BundleDependency] = []
  let combined_namespaces : Array[BundleNamespace] = []
  let combined_rules : Array[BundleRule] = []
  let combined_globals : Array[BundleGlobal] = []
  for dependency in dependencies {
    for transitive in dependency.dependency_closure {
      if !closure.any(item => item.module_name == transitive.module_name) {
        closure.push(transitive)
      }
    }
    if !closure.any(item => item.module_name == dependency.module_name) {
      closure.push({
        module_name: dependency.module_name,
        semantic_digest: dependency.semantic_digest,
      })
    }
    for namespace_ in dependency.namespaces {
      combined_namespaces.push({
        name: if namespace_.name.contains(":") {
          namespace_.name
        } else {
          dependency.module_name + ":" + namespace_.name
        },
        entries: namespace_.entries,
      })
    }
    for rule in dependency.rules {
      if !combined_rules.any(item => item.class_name == rule.class_name) {
        combined_rules.push(rule)
      }
    }
    for global in dependency.globals {
      if !combined_globals.any(item => {
          item.kind == global.kind && item.name == global.name
        }) {
        combined_globals.push(global)
      }
    }
  }
  for namespace_ in namespaces {
    combined_namespaces.push(namespace_)
  }
  combined_rules.append(rules)
  combined_globals.append(globals)
  let mut bundle : DependencyBundle = {
    module_name,
    mappings_package: module_name + "/generated",
    semantic_digest: "",
    direct_dependencies: dependencies.map(dependency => {
      module_name: dependency.module_name,
      semantic_digest: dependency.semantic_digest,
    }),
    dependency_closure: closure,
    contracts: [],
    namespaces: combined_namespaces,
    rules: combined_rules,
    globals: combined_globals,
    recipes: [],
    markers: [],
    view_transition_classes: [],
  }
  bundle = {
    ..bundle,
    semantic_digest: semantic_digest(semantic_json(bundle).stringify()),
  }
  bundle
}

///|
fn empty_application() -> CompiledBundle {
  compile_registry(@ir.registry("app/module", []))
}

///|
fn application_with(dependencies : Array[DependencyBundle]) -> CompiledBundle {
  compile_registry(
    @ir.registry(
      "app/module",
      [],
      direct_dependencies=dependencies.map(dependency => {
        @ir.dependency_ref(dependency.module_name, dependency.semantic_digest)
      }),
    ),
  )
}

///|
test "cross-package contracts generate deterministic imports and nominal implementations" {
  let mut component = dependency_fixture("component/button")
  component = {
    ..component,
    mappings_package: "component/button/generated",
    semantic_digest: "",
    contracts: [
      {
        module_name: "component/button",
        name: "button",
        mappings_package: "component/button/generated",
        trait_name: "ButtonStyleInput",
        properties: [
          @ir.exact_contract_property("color", values=["red"]),
          @ir.any_contract_property("backgroundColor"),
        ],
      },
    ],
  }
  component = {
    ..component,
    semantic_digest: semantic_digest(semantic_json(component).stringify()),
  }
  assert_true(validate_bundle(component).is_empty())
  let registry = @ir.registry(
    "application/root",
    [
      @ir.style_set("styles", [
        @ir.style_namespace("allowed", [
          @ir.declaration("color", @ir.text("red")),
        ]),
        @ir.style_namespace("rejected", [
          @ir.declaration("width", @ir.text("10px")),
        ]),
        @ir.style_namespace("rejected_value", [
          @ir.declaration("color", @ir.text("blue")),
        ]),
      ]),
    ],
    direct_dependencies=[
      @ir.dependency_ref(component.module_name, component.semantic_digest),
    ],
  )
  let application = compile_registry(
    registry,
    mappings_package="application/root/generated",
    dependencies=[component],
  )
  assert_true(
    application.mappings_manifest.contains(
      "\"component/button/generated\" @contract_0",
    ),
  )
  assert_true(
    application.mappings.contains(
      "pub impl @contract_0.ButtonStyleInput for AllowedStyle",
    ),
  )
  assert_false(
    application.mappings.contains(
      "@contract_0.ButtonStyleInput for RejectedStyle",
    ),
  )
  assert_false(
    application.mappings.contains(
      "@contract_0.ButtonStyleInput for RejectedValueStyle",
    ),
  )
  match merge_bundles(application, [component]) {
    Ok(merged) => {
      assert_eq(merged.schema_version, 13)
      assert_true(
        merged.manifest.contains(
          "\"module\":\"component/button\",\"name\":\"button\"",
        ),
      )
    }
    Err(_) => fail("valid cross-package contract must merge")
  }
}

///|
test "bundle decoder rejects malformed fields, schema, and digests" {
  let valid = empty_application()
  match decode_bundle(valid.manifest) {
    Ok(bundle) => assert_true(validate_bundle(bundle).is_empty())
    Err(_) => fail("generated bundle must decode")
  }
  let legacy_v8 = valid.manifest.replace_all(
    old="\"schemaVersion\":13",
    new="\"schemaVersion\":8",
  )
  match decode_bundle(legacy_v8) {
    Ok(_) => fail("schema v8 must be re-extracted instead of decoded")
    Err(diagnostics) => assert_eq(diagnostics[0].code, "STYLE_BUNDLE_SCHEMA")
  }
  let with_rule = compile_registry(
    @ir.registry("fixture/fixed-point", [
      @ir.style_set("styles", [
        @ir.style_namespace("color", [@ir.declaration("color", @ir.text("red"))]),
      ]),
    ]),
  )
  for
    malformed_rule in [
      with_rule.manifest.replace_all(
        old="\"priority100\":300000",
        new="\"priority100\":300000.5",
      ),
      with_rule.manifest.replace_all(
        old="\"priority100\":300000",
        new="\"priority\":3000",
      ),
    ] {
    match decode_bundle(malformed_rule) {
      Ok(_) => fail("schema v13 rule priority must be a fixed-point integer")
      Err(diagnostics) => assert_eq(diagnostics[0].code, "STYLE_BUNDLE_RULE")
    }
  }
  let malformed = [
    ("not-json", "STYLE_BUNDLE_JSON"),
    ("{\"schemaVersion\":2}", "STYLE_BUNDLE_SHAPE"),
    (
      "{\"schemaVersion\":3,\"module\":\"x\",\"semanticDigest\":\"sha256:x\",\"dependencies\":[],\"namespaces\":[],\"rules\":[],\"globals\":[],\"unknown\":true}",
      "STYLE_BUNDLE_SHAPE",
    ),
  ]
  for fixture in malformed {
    match decode_bundle(fixture.0) {
      Ok(_) => fail("malformed bundle unexpectedly decoded")
      Err(diagnostics) => assert_eq(diagnostics[0].code, fixture.1)
    }
  }
  let bad_digest = valid.manifest.replace_all(
    old=valid.semantic_digest,
    new="sha256:0000000000000000000000000000000000000000000000000000000000000000",
  )
  match decode_bundle(bad_digest) {
    Err(_) => fail("digest mismatch is a validation error, not a decode error")
    Ok(bundle) =>
      assert_eq(validate_bundle(bundle)[0].code, "STYLE_BUNDLE_DIGEST")
  }
  let bad_semantics = valid.manifest.replace_all(
    old=@core.application_order_digest,
    new="sha256:0000000000000000000000000000000000000000000000000000000000000000",
  )
  match decode_bundle(bad_semantics) {
    Ok(_) => fail("a foreign semantics profile must not decode")
    Err(diagnostics) =>
      assert_eq(diagnostics[0].code, "STYLE_BUNDLE_SEMANTICS_MISMATCH")
  }
}

///|
test "dependency graphs merge deterministically for every input permutation" {
  let leaf = dependency_fixture(
    "lib/leaf",
    namespaces=[
      {
        name: "leaf",
        entries: [("color", Some("xleaf")), ("marginLeft", None)],
      },
    ],
    rules=[
      {
        property: "color",
        class_name: "xleaf",
        ltr: ".xleaf{color:red}",
        rtl: None,
        priority100: 300000,
      },
    ],
  )
  let left = dependency_fixture("lib/left", dependencies=[leaf], rules=[
    {
      property: "display",
      class_name: "xleft",
      ltr: ".xleft{display:grid}",
      rtl: None,
      priority100: 300000,
    },
  ])
  let right = dependency_fixture("lib/right", dependencies=[leaf])
  let permutations = [[left, right], [right, left]]
  let outputs : Array[CompiledBundle] = []
  for permutation in permutations {
    match merge_bundles(application_with([left, right]), permutation) {
      Ok(bundle) => outputs.push(bundle)
      Err(_) => fail("valid dependency graph failed to merge")
    }
  }
  assert_true(outputs.every(bundle => bundle == outputs[0]))
  assert_true(outputs[0].manifest.contains("lib/leaf:leaf"))
  assert_true(outputs[0].manifest.contains("[\"marginLeft\",null]"))
  assert_true(
    outputs[0].manifest.contains(
      "\"dependencyClosure\":[{\"module\":\"lib/leaf\"",
    ),
  )
}

///|
test "bundle merge rejects graph gaps, cycles, and semantic collisions" {
  let missing = dependency_fixture("lib/missing")
  let needs_missing = dependency_fixture("lib/consumer", dependencies=[missing])
  match merge_bundles(application_with([missing]), [needs_missing]) {
    Ok(_) => fail("missing transitive dependency must fail")
    Err(diagnostics) =>
      assert_eq(diagnostics[0].code, "STYLE_BUNDLE_MISSING_DEPENDENCY")
  }
  let mut first = dependency_fixture("lib/first")
  let mut second = dependency_fixture("lib/second")
  first = dependency_fixture("lib/first", dependencies=[second])
  second = dependency_fixture("lib/second", dependencies=[first])
  first = dependency_fixture("lib/first", dependencies=[second])
  match merge_bundles(application_with([first, second]), [first, second]) {
    Ok(_) => fail("dependency cycle must fail")
    Err(diagnostics) =>
      assert_eq(diagnostics[0].code, "STYLE_BUNDLE_SELF_DEPENDENCY")
  }
  let rule_a : BundleRule = {
    property: "color",
    class_name: "xsame",
    ltr: ".xsame{color:red}",
    rtl: None,
    priority100: 300000,
  }
  let rule_b : BundleRule = { ..rule_a, ltr: ".xsame{color:blue}", }
  let collision_a = dependency_fixture("lib/a", rules=[rule_a])
  let collision_b = dependency_fixture("lib/b", rules=[rule_b])
  match
    merge_bundles(application_with([collision_a, collision_b]), [
      collision_a, collision_b,
    ]) {
    Ok(_) => fail("class collision must fail")
    Err(diagnostics) =>
      assert_eq(diagnostics[0].code, "STYLE_BUNDLE_CLASS_COLLISION")
  }
}

///|
test "cache metadata validates semantic identity and every output digest" {
  let bundle = empty_application()
  assert_false(cache_eligible(bundle))
  let metadata = render_cache_metadata(bundle)
  assert_true(metadata.contains("\"semanticsDigest\":"))
  let key = extraction_cache_key(bundle)
  assert_true(
    validate_cache_entry(
      bundle,
      metadata,
      bundle.css,
      bundle.mappings,
      bundle.mappings_manifest,
      bundle.manifest,
    ),
  )
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
  assert_false(
    validate_cache_entry(
      bundle,
      metadata,
      bundle.css + "corrupt",
      bundle.mappings,
      bundle.mappings_manifest,
      bundle.manifest,
    ),
  )
  assert_false(
    validate_cache_entry(
      bundle,
      metadata,
      bundle.css,
      bundle.mappings,
      bundle.mappings_manifest + "corrupt",
      bundle.manifest,
    ),
  )
  let pack = render_cache_pack(bundle)
  assert_true(pack.contains("\"cacheSchemaVersion\":4"))
  match decode_cache_entry(bundle, pack) {
    Some(outputs) =>
      assert_eq(outputs.mappings_manifest, bundle.mappings_manifest)
    None => fail("valid cache pack v4 must decode")
  }
  assert_false(
    validate_cache_lookup(
      "sha256:wrong",
      metadata,
      bundle.css,
      bundle.mappings,
      bundle.mappings_manifest,
      bundle.manifest,
    ),
  )
  assert_false(
    validate_cache_lookup(
      key,
      metadata.replace_all(
        old="\"schemaVersion\":13",
        new="\"schemaVersion\":8",
      ),
      bundle.css,
      bundle.mappings,
      bundle.mappings_manifest,
      bundle.manifest,
    ),
  )
  assert_false(
    validate_cache_lookup(
      key,
      metadata,
      bundle.css,
      bundle.mappings,
      bundle.mappings_manifest,
      bundle.manifest + "corrupt",
    ),
  )
  assert_false(
    validate_cache_lookup(
      key,
      metadata.replace_all(old=bundle.semantic_digest, new="sha256:corrupt"),
      bundle.css,
      bundle.mappings,
      bundle.mappings_manifest,
      bundle.manifest,
    ),
  )
  let rules : Array[BundleRule] = Array::makei(500, index => {
    let suffix = index.to_string()
    {
      property: "color",
      class_name: "x" + suffix,
      ltr: ".x" + suffix + "{color:red}",
      rtl: None,
      priority100: 300000,
    }
  })
  let large = dependency_fixture("lib/large", rules~)
  match merge_bundles(application_with([large]), [large]) {
    Ok(compiled) => assert_true(cache_eligible(compiled))
    Err(_) => fail("large cache fixture must compile")
  }
}

///|
test "debug manifest is deterministic, source-aware, and independently validated" {
  let shared = @ir.declaration(
    "color",
    @ir.text("red"),
    source=Some(
      @ir.source_span(
        "styles/button.mbt",
        12,
        7,
        end_line=12,
        end_column=31,
        symbol="button",
      ),
    ),
  )
  let registry = @ir.registry("fixture/debug", [
    @ir.style_set("styles", [
      @ir.style_namespace("button", [shared]),
      @ir.style_namespace("link", [
        shared.with_source(
          @ir.source_span(
            "styles/link.mbt",
            4,
            3,
            end_line=4,
            end_column=20,
            symbol="link",
          ),
        ),
      ]),
    ]),
  ])
  let bundle = compile_registry(registry)
  let first = match render_debug_manifest(registry, bundle) {
    Ok(value) => value
    Err(_) => {
      fail("valid registry must render debug metadata")
      ""
    }
  }
  let second = match render_debug_manifest(registry, bundle) {
    Ok(value) => value
    Err(_) => ""
  }
  assert_eq(first, second)
  assert_true(first.contains("\"schemaVersion\":1"))
  assert_true(first.contains("\"cssDigest\":\"sha256:"))
  assert_true(first.contains("\"className\":\"x1e2nbdu\""))
  assert_true(first.contains("\"file\":\"styles/button.mbt\""))
  assert_true(first.contains("\"file\":\"styles/link.mbt\""))
  assert_true(
    validate_debug_manifest(first, bundle.semantic_digest, bundle.css),
  )
  assert_true(
    validate_debug_manifest_outputs(first, bundle.css, bundle.manifest),
  )
  assert_false(
    validate_debug_manifest_outputs(
      first.replace_all(old="\"order\":0", new="\"order\":9"),
      bundle.css,
      bundle.manifest,
    ),
  )
  assert_false(
    validate_debug_manifest_outputs(
      first,
      bundle.css + "corrupt",
      bundle.manifest,
    ),
  )
}
