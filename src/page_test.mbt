///|
test "named pages preserve identifiers and reject reserved or malformed names" {
  for name in ["Report", "report", "none", "章节", "--report", "_Report2"] {
    let value = @moonstyle.page_name(name)
    assert_eq(value.to_css(), name)
    let output = @extract.compile_registry(
      @moonstyle.registry("pages/valid", [@moonstyle.rule("page").page(value)]),
    )
    assert_eq(output.diagnostics, [])
    assert_true(output.css.contains("page:" + name), msg=output.css)
  }
  for
    name in [
      "", "auto", "AUTO", "initial", "Inherit", "unset", "revert", "revert-layer",
      "default", " Report", "Report ", "two words", "1page", "-", "-1page", "page; color:red",
      "page{}", "page/*x*/", "page\\31",
    ] {
    let output = @extract.compile_registry(
      @moonstyle.registry("pages/invalid", [
        @moonstyle.rule("page").page(@moonstyle.page_name(name)),
      ]),
    )
    assert_true(
      output.diagnostics.any(item => {
        item.code == "STYLE_PAGE_NAME" && item.source is Some(_)
      }),
      msg=name + ": " + @extract.render_diagnostics_text(output.diagnostics),
    )
  }
}

///|
test "page supports conditions fallbacks CSS-wide keywords and clear tombstones" {
  let output = @extract.compile_registry(
    @moonstyle.registry("pages/rules", [
      @moonstyle.rule("auto").page(@moonstyle.page_auto()),
      @moonstyle.rule("conditional").page(
        @moonstyle.page_name("Report"),
        when=@moonstyle.hover,
      ),
      @moonstyle.rule("fallback").page_fallbacks(
        @moonstyle.PageValueFallbacks::new()
        .add(@moonstyle.page_auto())
        .add(@moonstyle.page_name("Report"))
        .add(@moonstyle.CssWideKeyword::Inherit),
      ),
      @moonstyle.rule("revert").page(@moonstyle.CssWideKeyword::RevertLayer),
      @moonstyle.rule("clear").clear_page(),
    ]),
  )
  assert_eq(output.diagnostics, [])
  assert_true(output.css.contains("page:auto"), msg=output.css)
  assert_true(
    output.css
    .split("\n")
    .any(line => line.contains(":hover") && line.contains("{page:Report}")),
    msg=output.css,
  )
  assert_true(
    output.css.contains("page:auto;page:Report;page:inherit"),
    msg=output.css,
  )
  assert_true(output.css.contains("page:revert-layer"), msg=output.css)
  match @extract.decode_bundle(output.manifest) {
    Ok(bundle) => assert_eq(@extract.validate_bundle(bundle), [])
    Err(errors) => fail(@extract.render_diagnostics_text(errors))
  }
  let parsed = @json.parse(output.manifest)
  guard parsed is { "namespaces": Array(namespaces), .. } else {
    fail("Missing namespaces")
  }
  assert_true(
    namespaces.any(item => {
      item
      is {
        "name": String("clear"),
        "entries": Array([Array([String(_), Null])]),
        ..
      }
    }),
  )
}

///|
test "page contracts distinguish exact case-sensitive names and all fallback values" {
  let report = @moonstyle.page_name("Report")
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "pages/contracts",
      [
        @moonstyle.rule("allowed").page(report),
        @moonstyle.rule("different").page(@moonstyle.page_name("report")),
        @moonstyle.rule("auto").page(@moonstyle.page_auto()),
        @moonstyle.rule("inherited").page(@moonstyle.CssWideKeyword::Inherit),
        @moonstyle.rule("fallback").page_fallbacks(
          @moonstyle.PageValueFallbacks::new()
          .add(report)
          .add(@moonstyle.page_auto()),
        ),
      ],
      contracts=[
        @moonstyle.style_contract("report").allow_page(values=[report], keywords=[
          @moonstyle.CssWideKeyword::Inherit,
        ]),
      ],
    ),
  )
  assert_eq(output.diagnostics, [])
  assert_true(output.mappings.contains("ReportStyleInput for AllowedStyle"))
  assert_true(output.mappings.contains("ReportStyleInput for InheritedStyle"))
  for name in ["Different", "Auto", "Fallback"] {
    assert_false(
      output.mappings.contains("ReportStyleInput for " + name + "Style"),
    )
  }
}
