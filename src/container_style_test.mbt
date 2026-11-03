///|
test "container style equality uses the same zero units as typed custom properties" {
  let scope = @moonstyle.variable_scope("zero-query")
  let length = scope.length_token("length", @moonstyle.px(0))
  let mixed = scope.length_percentage_slot("mixed", lp(0))
  let output = @extract.compile_registry(
    @moonstyle.registry("zero/query", [
      @moonstyle.rule("match").color(
        @moonstyle.rgb(0, 128, 0),
        when=@moonstyle.container_style_all([
          @moonstyle.container_style_equals(length, @moonstyle.px(0)),
          @moonstyle.container_style_slot_equals(mixed, lp(0)),
        ]).to_when(),
      ),
    ]),
  )
  assert_true(output.diagnostics.is_empty(), msg=output.manifest)
  assert_true(
    output.css.contains(":root{--zero-query-mixed:0px;--zero-query-length:0px}"),
    msg=output.css,
  )
  assert_true(
    output.css.contains(
      "@container style((--zero-query-length:0px) and (--zero-query-mixed:0px))",
    ),
  )
}

///|
test "typed container style queries retain variable definitions and boolean grouping" {
  let scope = @moonstyle.variable_scope("query")
  let color = scope.color_token("accent", @moonstyle.rgb(1, 2, 3))
  let size = scope.length_slot("size", @moonstyle.px(10))
  let condition = @moonstyle.container_style_all([
    @moonstyle.container_style_equals(color, @moonstyle.rgb(1, 2, 3)),
    @moonstyle.container_style_slot_equals(size, @moonstyle.px(10)),
  ])
  let output = @extract.compile_registry(
    @moonstyle.registry("coverage/container-style", [
      @moonstyle.rule("typed").color(
        @moonstyle.rgb(255, 0, 0),
        when=condition
          .to_when()
          .and_when(@moonstyle.container_min_width(@moonstyle.px(20))),
      ),
      @moonstyle.rule("any").color(
        @moonstyle.rgb(0, 0, 255),
        when=@moonstyle.container_style_any([
          condition,
          @moonstyle.container_style_not(
            @moonstyle.container_style_equals(color, @moonstyle.rgb(0, 0, 0)),
          ),
        ]).to_when(),
      ),
    ]),
  )
  assert_true(output.diagnostics.is_empty())
  assert_true(
    output.css.contains(
      "@container style((--query-accent:rgb(1 2 3)) and (--query-size:10px))",
    ),
  )
  assert_true(output.css.contains("not (--query-accent:rgb(0 0 0))"))
  assert_true(output.css.contains("--query-accent:rgb(1 2 3)"))
  assert_true(output.css.contains("@container (min-width:20px)"))
}

///|
test "empty container style boolean groups are diagnosed" {
  let invalid = @extract.compile_registry(
    @moonstyle.registry("coverage/container-style-invalid", [
      @moonstyle.rule("empty").color(
        @moonstyle.rgb(0, 0, 0),
        when=@moonstyle.container_style_all([]).to_when(),
      ),
    ]),
  )
  assert_true(
    invalid.diagnostics.any(item => item.code == "STYLE_CONTAINER_STYLE"),
  )
}

///|
test "container style slots cannot bypass the static recipe boundary" {
  let slot = @moonstyle.variable_scope("query").length_slot(
    "size",
    @moonstyle.px(10),
  )
  let output = @extract.compile_registry(
    @moonstyle.registry("coverage/query-recipe", [], recipes=[
      @moonstyle.recipe("invalid", [
        @moonstyle.recipe_rule().color(
          @moonstyle.rgb(1, 2, 3),
          when=@moonstyle.container_style_slot_equals(slot, @moonstyle.px(10)).to_when(),
        ),
      ]),
    ]),
  )
  assert_true(
    output.diagnostics.any(item => item.code == "STYLE_RECIPE_NON_STATIC"),
  )
}
