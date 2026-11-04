# CSS coverage examples (0.2.0)

Import `lampclaw/moonstyle` as `@moonstyle`. Extraction aggregates invalid authored
values and emits no partial artifacts. Generic property methods require
qualified enum constructors, such as `@moonstyle.Display::Grid`.

CSS-wide keywords are whole values. A fallback builder emits repeated
declarations in order; the browser chooses the last supported value.

```mbt check
///|
test "whole values and ordered mixed fallbacks" {
  let output = @extract.compile_registry(
    @moonstyle.registry("docs/fallback", [
      @moonstyle.rule("card")
      .display(@moonstyle.Display::Grid)
      .color(@moonstyle.CssWideKeyword::Inherit)
      .width_fallbacks(
        @moonstyle.BoxSizeFallbacks::new()
        .add(@moonstyle.px(20))
        .add(@moonstyle.env_length(SafeAreaLeft)),
      ),
    ]),
  )
  assert_true(output.diagnostics.is_empty())
}
```

Colors, gradients, image sets and transforms retain nested token/slot
identities. Exact contracts must admit the expression itself; admitting a token
does not admit every expression that contains it.

```mbt check
///|
test "modern colors and exact transform expressions" {
  let token = @moonstyle.variable_scope("docs").color_token(
    "accent",
    @moonstyle.named_color("blue"),
  )
  let image = @moonstyle.linear_gradient(
    [
      @moonstyle.color_stop(
        @moonstyle.color_mix(Oklab, token, @moonstyle.named_color("white")),
      ),
      @moonstyle.color_stop(@moonstyle.oklch(0.7, 0.1, @moonstyle.deg(30.0))),
    ],
    interpolation=@moonstyle.color_interpolation(Oklab),
  )
  let transform = @moonstyle.transform_list([
    @moonstyle.translate_z(@moonstyle.px(10)),
    @moonstyle.rotate_y(@moonstyle.deg(15.0)),
  ])
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "docs/images",
      [
        @moonstyle.rule("card")
        .background_image(
          @moonstyle.image_set([
            @moonstyle.image_candidate(image, resolution=@moonstyle.dppx(1.0)),
          ]),
        )
        .transform(transform),
      ],
      contracts=[
        @moonstyle.style_contract("card").allow_transform(expressions=[
          transform,
        ]),
      ],
    ),
  )
  assert_true(output.diagnostics.is_empty())
}
```

Comma lists represent one CSS declaration and follow native CSS list matching.
They differ from ordered fallback declarations. Animation names retain every
keyframe dependency; repeated keyframes are emitted once.

```mbt check
///|
test "multiple animations and complete mask layers" {
  let fade = @moonstyle.keyframes("fade", [
    @moonstyle.frame(From).opacity(0.0),
    @moonstyle.frame(To).opacity(1.0),
  ])
  let output = @extract.compile_registry(
    @moonstyle.registry("docs/lists", [
      @moonstyle.rule("card")
      .animation_name(@moonstyle.animation_names([Some(fade), None]))
      .animation_duration(
        @moonstyle.TimeList::new()
        .add(@moonstyle.seconds(1.0))
        .add(@moonstyle.seconds(2.0)),
      )
      .mask_layers(
        @moonstyle.mask_layers([
          @moonstyle.mask_layer(
            @moonstyle.url("/mask.svg"),
            mode=Alpha,
            clip=NoClip,
          ),
        ]),
      ),
    ]),
  )
  assert_true(output.diagnostics.is_empty())
}
```

Paths share validated SVG path data. Container style queries compare custom
properties on an ancestor container; combine typed conditions with `and_when`.
The literal equality operand has the same type as the token or slot.

```mbt check
///|
test "paths counters and container style queries" {
  let mode = @moonstyle.variable_scope("docs").number_token(
    "mode",
    @moonstyle.number(1.0),
  )
  let chapter = @moonstyle.counter_name("chapter")
  let output = @extract.compile_registry(
    @moonstyle.registry("docs/advanced", [
      @moonstyle.rule("card")
      .offset_path(@moonstyle.motion_path(@moonstyle.path_data("M0 0 L100 0")))
      .counter_increment(
        @moonstyle.counter_changes([@moonstyle.counter_change(chapter, 1)]),
      )
      .content(@moonstyle.counter_content(chapter), when=@moonstyle.before)
      .color(
        @moonstyle.named_color("green"),
        when=@moonstyle.container_style_equals(mode, @moonstyle.number(1.0))
          .to_when()
          .and_when(@moonstyle.container_min_width(@moonstyle.px(200))),
      ),
    ]),
  )
  assert_true(output.diagnostics.is_empty())
}
```

Use `@supports` or ordered fallbacks for optional browser features. For example,
apply `animation_timeline` under `supports_property("animation-timeline",
"scroll()")`, with a safe base animation state. The framework emits native CSS;
it does not polyfill timelines, paths, colors or queries.

See [reviewed coverage](../docs/data-sources.md#reviewed-surface), the
[generated coverage matrix](properties/property-coverage.json), and the
[regeneration guide](../docs/regeneration.md).

## Registered globals and named pages

Position fallbacks and view-transition pseudo styles are registered globals.
Named pages are an ordinary typed property selecting a page; they do not
define `@page` rules. Browser support and actual pagination remain separate
from successful extraction.

```mbt check
///|
test "registered globals and named page selection" {
  let transition = @moonstyle.define_view_transition_class("card")
    .group(@moonstyle.rule("group").animation_duration(@moonstyle.ms(250)))
    .old(@moonstyle.rule("outgoing").opacity(0.5))
    .new(@moonstyle.rule("incoming").opacity(1.0))
  let fallback = @moonstyle.position_try_rule("tooltip")
    .max_inline_size(@moonstyle.percent(90))
    .align_self(@moonstyle.Alignment::AlignmentStart)
  let registry = @moonstyle.registry_builder("docs/globals")
    .rules([@moonstyle.rule("report").page(@moonstyle.page_name("Report"))])
    .position_try(fallback)
    .view_transition_class(transition)
    .build()
  let output = @extract.compile_registry(registry)
  assert_true(output.diagnostics.is_empty())
}
```

The [authoring guide](../docs/authoring.md#registered-globals-and-named-pages) describes
descriptor restrictions, group replacement, dependencies and exact page policies.
