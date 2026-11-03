///|
fn coverage_rules() -> Array[@moonstyle.Rule] {
  let count = @moonstyle.counter_name("section")
  let timeline = @moonstyle.timeline_name("--reading")
  let first = @moonstyle.keyframes("coverage-fade", [
    @moonstyle.frame(From).opacity(0.2),
    @moonstyle.frame(To).opacity(0.8),
  ])
  let second = @moonstyle.keyframes("coverage-size", [
    @moonstyle.frame(From).width(@moonstyle.px(10)),
    @moonstyle.frame(To).width(@moonstyle.px(20)),
  ])
  let gradient = @moonstyle.linear_gradient(
    [
      @moonstyle.color_stop(@moonstyle.named_color("black")),
      @moonstyle.color_stop(@moonstyle.named_color("white")),
    ],
    interpolation=@moonstyle.color_interpolation(Oklab),
  )
  [
    @moonstyle.rule("coveragePageAuto").page(@moonstyle.page_auto()),
    @moonstyle.rule("coveragePageNamed").page(
      @moonstyle.page_name("MoonStyleReport"),
    ),
    @moonstyle.rule("coverageColor").color_fallbacks(
      @moonstyle.ColorFallbacks::new()
      .add(@moonstyle.rgb(0, 0, 255))
      .add(
        @moonstyle.color_mix(
          Srgb,
          @moonstyle.named_color("red"),
          @moonstyle.named_color("blue"),
        ),
      ),
    ),
    @moonstyle.rule("coverageTransform").transform(
      @moonstyle.transform_list([
        @moonstyle.translate_z(@moonstyle.px(10)),
        @moonstyle.rotate_y(@moonstyle.deg(30.0)),
        @moonstyle.scale_x(@moonstyle.number(2.0)),
      ]),
    ),
    @moonstyle.rule("coverageShape").clip_path(
      @moonstyle.path_shape(@moonstyle.path_data("M0 0 L100 0 L100 100 Z")),
    ),
    @moonstyle.rule("coverageMask").mask_layers(
      @moonstyle.mask_layers([
        @moonstyle.mask_layer(gradient, mode=Alpha, repeat=NoRepeat),
      ]),
    ),
    @moonstyle.rule("coverageAnimation")
    .animation_name(@moonstyle.animation_names([Some(first), Some(second)]))
    .animation_duration(
      @moonstyle.TimeList::new()
      .add(@moonstyle.seconds(10.0))
      .add(@moonstyle.seconds(20.0)),
    )
    .animation_play_state(
      @moonstyle.AnimationPlayStateList::new([
        @moonstyle.AnimationPlayState::AnimationPlayStatePaused,
      ]),
    ),
    @moonstyle.rule("coverageCounter")
    .counter_reset(
      @moonstyle.counter_changes([@moonstyle.counter_change(count, 0)]),
    )
    .counter_increment(
      @moonstyle.counter_changes([@moonstyle.counter_change(count, 1)]),
    )
    .content(
      @moonstyle.content_sequence([
        @moonstyle.content_text("Section "),
        @moonstyle.counter_content(count),
      ]),
      when=@moonstyle.before,
    ),
    @moonstyle.rule("coverageTimeline")
    .scroll_timeline_name(@moonstyle.timeline_names([timeline]))
    .animation_timeline_fallbacks(
      @moonstyle.AnimationTimelinesFallbacks::new()
      .add(@moonstyle.animation_timelines([@moonstyle.timeline_auto()]))
      .add(
        @moonstyle.animation_timelines([@moonstyle.scroll_timeline(axis=YAxis)]),
      ),
    ),
    @moonstyle.rule("coverageMotion")
    .offset_path_fallbacks(
      @moonstyle.MotionPathFallbacks::new()
      .add(@moonstyle.motion_none())
      .add(@moonstyle.motion_path(@moonstyle.path_data("M0 0 L100 0"))),
    )
    .offset_distance(@moonstyle.percentage(50.0).as_length_percentage()),
    @moonstyle.rule("coverageEnv")
    .width(
      @moonstyle.env_length(
        SafeAreaLeft,
        fallback=@moonstyle.math_length(@moonstyle.px(24)),
      ),
    )
    .height(@moonstyle.length(1.0, Cqi)),
    @moonstyle.rule("coverageState").color(
      @moonstyle.named_color("green"),
      when=@moonstyle.pseudo(NthChild(2, 1)),
    ),
    @moonstyle.rule("coverageImageSet").background_image_fallbacks(
      @moonstyle.ImageFallbacks::new()
      .add(@moonstyle.image_none())
      .add(
        @moonstyle.image_set([
          @moonstyle.image_candidate(gradient, resolution=@moonstyle.dppx(1.0)),
        ]),
      ),
    ),
    @moonstyle.rule("coverageScrollEffect")
    .animation_name(first)
    .animation_duration(@moonstyle.seconds(1.0))
    .animation_fill_mode(@moonstyle.AnimationFillMode::AnimationFillModeBoth)
    .animation_play_state(
      @moonstyle.AnimationPlayState::AnimationPlayStatePaused,
    )
    .animation_play_state(
      @moonstyle.AnimationPlayState::AnimationPlayStateRunning,
      when=@moonstyle.supports_property("animation-timeline", "scroll()"),
    )
    .animation_timeline(
      @moonstyle.animation_timelines([@moonstyle.scroll_timeline()]),
      when=@moonstyle.supports_property("animation-timeline", "scroll()"),
    ),
    @moonstyle.rule("coverageContainerStyle")
    .color(@moonstyle.named_color("blue"))
    .color(
      @moonstyle.named_color("green"),
      when=@moonstyle.container_style_equals(
        @moonstyle.variable_scope("coverage").number_token(
          "mode",
          @moonstyle.number(1.0),
        ),
        @moonstyle.number(1.0),
      ).to_when(),
    ),
  ]
}
