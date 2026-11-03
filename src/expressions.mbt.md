# Typed expressions, images, and Grid

`MathExpr[T]` preserves its numeric category. Construct leaves with
`math_length`, `math_length_percentage`, `math_percentage`, `math_number`,
`math_angle`, `math_time`, or `math_resolution`. Each accepts a static value,
Token, DynamicSlot, or expression of that category.

Use the [authoring guide](../docs/authoring.md) for registries and composition, or the
[executable consumer](../docs/quickstart.md) for cross-package contracts.

```mbt check
///|
test {
  let gap = @moonstyle.variable_scope("docs").length_token(
    "gap",
    @moonstyle.px(8),
  )
  let width = @moonstyle.math_length(gap).add(
    @moonstyle.math_length(@moonstyle.px(100)),
  )
  let scaled = width
    .scale(@moonstyle.math_number(@moonstyle.number(2.0)))
    .divide(2.0)
  let bounded = @moonstyle.css_clamp(
    @moonstyle.math_length(@moonstyle.px(40)),
    scaled,
    @moonstyle.math_length(@moonstyle.px(300)),
  )
  let mixed = bounded
    .as_length_percentage()
    .add(
      @moonstyle.percentage_as_length(
        @moonstyle.math_percentage(@moonstyle.percentage(10.0)),
      ),
    )
  ignore(@moonstyle.rule("card").width(mixed))
  ignore(
    @moonstyle.rule("motion").transition_duration(
      @moonstyle.math_time(@moonstyle.ms(200)).divide(2.0),
    ),
  )
  assert_eq(
    @moonstyle.css_max([
      @moonstyle.math_number(@moonstyle.number(1.0)),
      @moonstyle.math_number(@moonstyle.number(2.0)),
    ]).to_css(),
    "max(1, 2)",
  )
  assert_eq(@moonstyle.math_resolution(@moonstyle.dpi(96.0)).to_css(), "96dpi")
}
```

Addition, subtraction, comparison, and clamp require matching dimensions.
Convert lengths and percentages explicitly before mixing them. Scaling takes
a number expression; division takes a finite, nonzero static `Double`.
Keywords such as `auto` are not numeric operands. The browser evaluates the
expression; runtime accessors only validate inputs and bind custom properties.
Length zero retains its dimension inside math (`0px`), typed variable defaults,
theme overrides and dynamic bindings. Ordinary standalone zero declarations
retain their canonical CSS form. Regenerate mappings when adopting this fix;
changing only emitted CSS would leave dynamic bindings inconsistent.

```mbt check
///|
test {
  let variables = @moonstyle.variable_scope("gradient")
  let color = variables.color_token("color", @moonstyle.rgb(30, 100, 180))
  let angle = variables.angle_slot("angle", @moonstyle.deg(90.0))
  let image = @moonstyle.linear_gradient(
    [
      @moonstyle.color_stop(color),
      @moonstyle.gradient_hint(
        @moonstyle.percentage(40.0).as_length_percentage(),
      ),
      @moonstyle.color_stop(@moonstyle.rgb(255, 255, 255)),
    ],
    direction=@moonstyle.gradient_angle(angle),
    repeating=true,
  )
  ignore(
    @moonstyle.rule("background").background_layers(
      @moonstyle.background_layers([
        @moonstyle.background_layer(image, repeat=NoRepeat),
        @moonstyle.background_layer(@moonstyle.url("/paper.png")),
      ]),
    ),
  )
}
```

Linear and radial stops use length/percentage expressions. Conic stops use
`conic_angle` or `conic_percentage`. Optional `position` and `end` describe a
double stop; `gradient_hint` and `conic_hint` belong between two color stops.
Gradients require at least two colors. Radial explicit radius/radii must match
`Circle`/`Ellipse`. All families support `repeating=true`; color interpolation
uses the browser default.

`background_images` accepts an ordered image list. `background_layers` also
assigns each image its own position, size, repetition, attachment, origin, and
clip. It lowers to eight ordinary longhands, including separate X/Y position
lists. Set background color separately. Existing URL and single-value methods
remain available.

```mbt check
///|
test {
  let minimum = @moonstyle.variable_scope("grid").length_percentage_slot(
    "minimum",
    @moonstyle.px(100).as_length_percentage(),
  )
  let tracks = @moonstyle.grid_tracks([
    @moonstyle.named_lines(["start"]),
    @moonstyle.auto_fit(
      @moonstyle.grid_tracks([
        @moonstyle.minmax(@moonstyle.track_length(minimum), @moonstyle.fr(1.0)),
      ]),
    ),
    @moonstyle.named_lines(["end"]),
  ])
  ignore(
    @moonstyle.rule("grid")
    .display(@moonstyle.Display::Grid)
    .grid_template_columns(tracks),
  )
  ignore(
    @moonstyle.rule("child").grid_template_columns(
      @moonstyle.subgrid(lines=[["start"], ["end"]]),
    ),
  )
}
```

Grid auto-repeat admits one repetition and requires fixed-size tracks.
`minmax` rejects a flexible minimum and nested track functions. `fit_content`,
`track_auto`, `track_min_content`, and `track_max_content` provide intrinsic
track sizing. Named lines, repeat, and subgrid belong to template tracks;
`grid_auto_rows` and `grid_auto_columns` reject them.
Line names are unescaped CSS identifiers: case, underscores, and non-ASCII
letters are preserved; leading digits and reserved keywords are rejected.
Put aliases for the same line in one `named_lines` call. Empty line-name groups
can reserve unnamed positions in a subgrid, such as `subgrid(lines=[[], ["middle"]])`.

Exact contracts take `expressions=[...]` alongside the existing `values`,
`tokens`, and `slots` channels. Expression identity retains operations and
literal/token/slot provenance. Allowing a token does not authorize expressions
around it, and reversing addition operands does not preserve exact identity.

```mbt check
///|
test {
  let value = @moonstyle.math_length(@moonstyle.px(100)).add(
    @moonstyle.math_length(@moonstyle.px(10)),
  )
  ignore(@moonstyle.style_contract("card").allow_width(expressions=[value]))
}
```

Defaults, theme overrides, and dynamic arguments receive all applicable leaf
constraints. Repeated dynamic slots become one parameter in first-use order.
Invalid static constructors report extraction diagnostics; invalid dynamic
arguments return `Err` before any partial style can be applied. Recipes and
keyframes continue to reject dynamic slots, including nested uses.
