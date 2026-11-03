///|
test "CSS-wide values and typed mixed fallbacks remain whole declarations" {
  let output = @extract.compile_registry(
    @moonstyle.registry("coverage/keywords", [
      @moonstyle.rule("wide")
      .display(@moonstyle.CssWideKeyword::RevertLayer)
      .color(@moonstyle.CssWideKeyword::Inherit),
      @moonstyle.rule("fallback").width_fallbacks(
        @moonstyle.BoxSizeFallbacks::new()
        .add(@moonstyle.px(20))
        .add(@moonstyle.CssWideKeyword::Initial)
        .add(
          @moonstyle.env_length(
            SafeAreaLeft,
            fallback=@moonstyle.math_length(@moonstyle.px(4)),
          ),
        ),
      ),
      @moonstyle.rule("clear").clear_width(),
    ]),
  )
  assert_true(output.diagnostics.is_empty())
  assert_true(output.css.contains("display:revert-layer"))
  assert_true(output.css.contains("color:inherit"))
  assert_true(output.css.contains("width:initial"))
  assert_true(output.css.contains("env(safe-area-inset-left,4px)"))
}

///|
test "mixed fallback contracts check every literal token slot and expression" {
  let scope = @moonstyle.variable_scope("fallback")
  let token = scope.length_token("token", @moonstyle.px(10))
  let other = scope.length_token("other", @moonstyle.px(10))
  let slot = scope.length_slot("slot", @moonstyle.px(20))
  let env = @moonstyle.env_length(SafeAreaLeft)
  let exact = @moonstyle.style_contract("mixed").allow_width(
    values=[@moonstyle.px(5)],
    tokens=[token],
    slots=[slot],
    expressions=[env],
  )
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "coverage/fallback-contract",
      [
        @moonstyle.rule("allowed").width_fallbacks(
          @moonstyle.BoxSizeFallbacks::new()
          .add(@moonstyle.px(5))
          .add(token)
          .add(slot)
          .add(env),
        ),
        @moonstyle.rule("wrongToken").width_fallbacks(
          @moonstyle.BoxSizeFallbacks::new().add(@moonstyle.px(5)).add(other),
        ),
        @moonstyle.rule("wrongExpression").width_fallbacks(
          @moonstyle.BoxSizeFallbacks::new()
          .add(token)
          .add(
            @moonstyle.math_length(token).add(
              @moonstyle.math_length(@moonstyle.px(1)),
            ),
          ),
        ),
      ],
      contracts=[exact],
    ),
  )
  assert_true(output.diagnostics.is_empty())
  assert_true(
    output.mappings.contains("MixedStyleInput for AllowedStyle"),
    msg=output.mappings,
  )
  assert_false(output.mappings.contains("MixedStyleInput for WrongTokenStyle"))
  assert_false(
    output.mappings.contains("MixedStyleInput for WrongExpressionStyle"),
  )
}

///|
test "extended units and environment indices receive typed validation" {
  let units : Array[@moonstyle.LengthUnit] = [
    Cm,
    Mm,
    Q,
    In,
    Pc,
    Pt,
    Ex,
    Cap,
    Ic,
    Rex,
    Rcap,
    Rch,
    Ric,
    Lh,
    Rlh,
    Vi,
    Vb,
    Svw,
    Svi,
    Svb,
    Svmin,
    Svmax,
    Lvw,
    Lvi,
    Lvb,
    Lvmin,
    Lvmax,
    Dvw,
    Dvi,
    Dvb,
    Dvmin,
    Dvmax,
    Cqw,
    Cqh,
    Cqi,
    Cqb,
    Cqmin,
    Cqmax,
  ]
  let rules = [
    for i, unit in units => {
      @moonstyle.rule("unit" + i.to_string()).width(
        @moonstyle.math_length(@moonstyle.length(2.0, unit)),
      )
    }
  ]
  let output = @extract.compile_registry(
    @moonstyle.registry("coverage/units", rules),
  )
  assert_true(output.diagnostics.is_empty())
  let invalid = @extract.compile_registry(
    @moonstyle.registry("coverage/env", [
      @moonstyle.rule("bad").width(
        @moonstyle.env_length(ViewportSegmentWidth(-1, 0)),
      ),
    ]),
  )
  assert_true(invalid.diagnostics.any(item => item.code == "STYLE_ENV_INDEX"))
}

///|
test "functional selectors and escaped attributes are validated before output" {
  let output = @extract.compile_registry(
    @moonstyle.registry("coverage/selectors", [
      @moonstyle.rule("states").color(
        @moonstyle.rgb(1, 2, 3),
        when=@moonstyle.pseudo(NthChild(2, 1)),
      ),
      @moonstyle.rule("attributes").color(
        @moonstyle.rgb(1, 2, 3),
        when=@moonstyle.attribute(
          "data-mode",
          operator=Equals,
          value="a\"b",
          case_mode=Insensitive,
        ),
      ),
      @moonstyle.rule("choices").color(
        @moonstyle.rgb(1, 2, 3),
        when=@moonstyle.is_state([
          @moonstyle.pseudo_state(Valid),
          @moonstyle.attribute_state("required"),
        ]),
      ),
      @moonstyle.rule("file").color(
        @moonstyle.rgb(1, 2, 3),
        when=@moonstyle.pseudo_element(FileSelectorButton),
      ),
    ]),
  )
  assert_true(output.diagnostics.is_empty())
  assert_true(output.css.contains(":nth-child(2n+1)"))
  assert_true(output.css.contains("[data-mode=\"a\\\"b\" i]"))
  assert_true(output.css.contains(":is(:valid,[required])"))
  assert_true(output.css.contains("::file-selector-button"))
  let invalid = @extract.compile_registry(
    @moonstyle.registry("coverage/invalid", [
      @moonstyle.rule("empty").color(
        @moonstyle.rgb(0, 0, 0),
        when=@moonstyle.not_state([]),
      ),
    ]),
  )
  assert_true(
    invalid.diagnostics.any(item => item.code == "STYLE_SELECTOR_STATE"),
  )
}

///|
test "modern colors keep token identities through mixtures gradients and image sets" {
  let scope = @moonstyle.variable_scope("palette")
  let accent = scope.color_token(
    "accent",
    @moonstyle.oklch(0.7, 0.2, @moonstyle.deg(30.0)),
  )
  let tint = @moonstyle.color_mix(
    Oklch,
    accent,
    @moonstyle.named_color("white"),
    first_weight=@moonstyle.percentage(70.0),
    hue=Longer,
  )
  let gradient = @moonstyle.linear_gradient(
    [
      @moonstyle.color_stop(tint),
      @moonstyle.color_stop(@moonstyle.named_color("transparent")),
    ],
    interpolation=@moonstyle.color_interpolation(Oklab),
  )
  let image = @moonstyle.image_set([
    @moonstyle.image_candidate(gradient, resolution=@moonstyle.dppx(1.0)),
    @moonstyle.image_candidate(
      @moonstyle.url("/picture.webp"),
      resolution=@moonstyle.dppx(2.0),
      mime="image/webp",
    ),
  ])
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "coverage/color",
      [
        @moonstyle.rule("mixed")
        .color(tint)
        .background_image(image)
        .mask_image(image),
        @moonstyle.rule("plain").color(accent),
      ],
      contracts=[
        @moonstyle.style_contract("tint").allow_color(expressions=[tint]),
        @moonstyle.style_contract("token").allow_color(tokens=[accent]),
      ],
    ),
  )
  assert_true(output.diagnostics.is_empty())
  assert_true(
    output.css.contains(
      "color-mix(in oklch longer hue,var(--palette-accent) 70%,white)",
    ),
  )
  assert_true(output.css.contains("in oklab"))
  assert_true(output.css.contains("image-set("))
  assert_true(output.css.contains("--palette-accent:oklch("))
  // Extra properties prevent this rule from matching either one-property contract.
  let exact = @extract.compile_registry(
    @moonstyle.registry(
      "coverage/exact-color",
      [
        @moonstyle.rule("mix").color(tint),
        @moonstyle.rule("token").color(accent),
      ],
      contracts=[
        @moonstyle.style_contract("tint").allow_color(expressions=[tint]),
        @moonstyle.style_contract("tokenOnly").allow_color(tokens=[accent]),
      ],
    ),
  )
  assert_true(exact.mappings.contains("TintStyleInput for MixStyle"))
  assert_false(exact.mappings.contains("TokenOnlyStyleInput for MixStyle"))
  assert_false(exact.mappings.contains("TintStyleInput for TokenStyle"))
}

///|
test "modern color and image diagnostics aggregate" {
  let nested = @moonstyle.image_set([
    @moonstyle.image_candidate(@moonstyle.url("/a.png")),
  ])
  let bad = @extract.compile_registry(
    @moonstyle.registry("coverage/invalid-colors", [
      @moonstyle.rule("name").color(@moonstyle.named_color("not-a-color")),
      @moonstyle.rule("space").color(@moonstyle.color_space(Lab, 1.0, 0.0, 0.0)),
      @moonstyle.rule("mix").color(
        @moonstyle.color_mix(
          Srgb,
          @moonstyle.rgb(0, 0, 0),
          @moonstyle.rgb(255, 255, 255),
          first_weight=@moonstyle.percentage(-1.0),
          hue=Shorter,
        ),
      ),
      @moonstyle.rule("nested").background_image(
        @moonstyle.image_set([
          @moonstyle.image_candidate(nested, resolution=@moonstyle.dppx(0.0)),
        ]),
      ),
      @moonstyle.rule("empty").mask_image(@moonstyle.image_set([])),
    ]),
  )
  for
    code in [
      "STYLE_COLOR_NAME", "STYLE_COLOR_SPACE", "STYLE_COLOR_HUE", "STYLE_COLOR_MIX_WEIGHT",
      "STYLE_IMAGE_SET_NESTED", "STYLE_IMAGE_SET_RESOLUTION", "STYLE_IMAGE_SET_EMPTY",
    ] {
    assert_true(bad.diagnostics.any(item => item.code == code), msg=code)
  }
}

///|
test "3D transforms retain function order dynamic operands and exact contracts" {
  let depth = @moonstyle.variable_scope("transform").length_slot(
    "depth",
    @moonstyle.px(12),
  )
  let transform = @moonstyle.transform_list([
    @moonstyle.translate3d(
      @moonstyle.px(10).as_length_percentage(),
      @moonstyle.px(20).as_length_percentage(),
      depth,
    ),
    @moonstyle.rotate_y(@moonstyle.deg(30.0)),
    @moonstyle.scale_z(@moonstyle.number(2.0)),
  ])
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "coverage/3d",
      [@moonstyle.rule("ordered").transform(transform)],
      contracts=[
        @moonstyle.style_contract("transform").allow_transform(expressions=[
          transform,
        ]),
      ],
    ),
  )
  assert_true(output.diagnostics.is_empty())
  assert_true(
    output.css.contains(
      "translate3d(10px,20px,var(--transform-depth)) rotateY(30deg) scaleZ(2)",
    ),
  )
  assert_true(output.mappings.contains("transform_depth : @values.Length"))
  assert_true(output.mappings.contains("TransformStyleInput for OrderedStyle"))
  let invalid = @extract.compile_registry(
    @moonstyle.registry("coverage/3d-invalid", [
      @moonstyle.rule("bad").transform(
        @moonstyle.transform_list([
          @moonstyle.matrix([]),
          @moonstyle.perspective_transform(@moonstyle.px(-1)),
        ]),
      ),
    ]),
  )
  assert_true(
    invalid.diagnostics.any(item => item.code == "STYLE_TRANSFORM_MATRIX"),
  )
  assert_true(
    invalid.diagnostics.any(item => item.code == "STYLE_VALUE_OUT_OF_RANGE"),
  )
}

///|
test "shared SVG path data validates curves arcs compact numbers and command counts" {
  let valid = [
    "M0 0L10-20z", "M.5.6 C1 2 3 4 5 6 S7 8 9 10", "m0 0 a10 20 30 0110 20", "M1e2 0 H20 V30 Q1 2 3 4 T5 6 Z",
  ]
  for data in valid {
    let path = @moonstyle.path_data(data)
    let output = @extract.compile_registry(
      @moonstyle.registry("coverage/path", [
        @moonstyle.rule("path")
        .clip_path(@moonstyle.path_shape(path))
        .offset_path(@moonstyle.motion_path(path)),
      ]),
    )
    assert_true(output.diagnostics.is_empty(), msg=data)
  }
  for
    data in [
      "", "L0 0", "M0", "M0 0 L", "M0 0,", "M0 0 A-1 2 0 0 0 3 4", "M0 0 A1 2 0 2 0 3 4",
      "M1e999 0", "M0 0 Z 1 2",
    ] {
    let invalid = @extract.compile_registry(
      @moonstyle.registry("coverage/path-invalid", [
        @moonstyle.rule("bad").offset_path(
          @moonstyle.motion_path(@moonstyle.path_data(data)),
        ),
      ]),
    )
    assert_true(
      invalid.diagnostics.any(item => item.code == "STYLE_PATH_DATA"),
      msg=data,
    )
  }
}

///|
test "mask layers lower complete aligned comma lists with expression provenance" {
  let mask = @moonstyle.mask_layers([
    @moonstyle.mask_layer(
      @moonstyle.linear_gradient([
        @moonstyle.color_stop(@moonstyle.named_color("black")),
        @moonstyle.color_stop(@moonstyle.named_color("transparent")),
      ]),
      mode=Alpha,
      composite=MaskIntersect,
    ),
    @moonstyle.mask_layer(
      @moonstyle.url("/mask.svg"),
      origin=MaskContentBox,
      clip=NoClip,
      repeat=NoRepeat,
    ),
  ])
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "coverage/masks",
      [@moonstyle.rule("masks").mask_layers(mask)],
      contracts=[@moonstyle.style_contract("mask").allow_mask_layers([mask])],
    ),
  )
  assert_true(output.diagnostics.is_empty())
  for
    css in [
      "mask-mode:alpha,match-source", "mask-composite:intersect,add", "mask-origin:border-box,content-box",
      "mask-clip:border-box,no-clip",
    ] {
    assert_true(output.css.contains(css), msg=css)
  }
  assert_true(output.mappings.contains("MaskStyleInput for MasksStyle"))
}

///|
test "layer and reference box grammar errors remain extraction diagnostics" {
  let shape = @moonstyle.circle_shape(
    @moonstyle.percentage(40.0).as_length_percentage(),
  )
  let output = @extract.compile_registry(
    @moonstyle.registry("coverage/grammar-errors", [
      @moonstyle.rule("duplicate").clip_path(
        shape.in_box(BorderBox).in_box(ContentBox),
      ),
      @moonstyle.rule("margin").offset_path(
        @moonstyle.motion_shape(shape.in_box(MarginBox)),
      ),
      @moonstyle.rule("empty").offset_path(
        @moonstyle.motion_none().in_box(BorderBox),
      ),
      @moonstyle.rule("images").mask_layers(
        @moonstyle.mask_layers([
          @moonstyle.mask_layer(
            @moonstyle.background_images([
              @moonstyle.image(@moonstyle.url("/a")),
              @moonstyle.image(@moonstyle.url("/b")),
            ]),
          ),
        ]),
      ),
    ]),
  )
  for
    code in [
      "STYLE_SHAPE_BOX", "STYLE_MOTION_BOX", "STYLE_MOTION_PATH", "STYLE_MASK_IMAGE",
    ] {
    assert_true(output.diagnostics.any(item => item.code == code), msg=code)
  }
}

///|
test "animation comma lists emit each keyframe once and retain list identities" {
  let first = @moonstyle.keyframes("first", [
    @moonstyle.frame(From).opacity(0.0),
    @moonstyle.frame(To).opacity(1.0),
  ])
  let second = @moonstyle.keyframes("second", [
    @moonstyle.frame(From).width(@moonstyle.px(0)),
    @moonstyle.frame(To).width(@moonstyle.px(100)),
  ])
  let names = @moonstyle.animation_names([
    Some(first),
    None,
    Some(second),
    Some(first),
  ])
  let output = @extract.compile_registry(
    @moonstyle.registry(
      "coverage/animations",
      [
        @moonstyle.rule("multi")
        .animation_name(names)
        .animation_duration(
          @moonstyle.TimeList::new()
          .add(@moonstyle.seconds(1.0))
          .add(@moonstyle.seconds(2.0)),
        )
        .animation_direction(
          @moonstyle.AnimationDirectionList::new([
            @moonstyle.AnimationDirection::AnimationDirectionNormal,
            @moonstyle.AnimationDirection::AnimationDirectionReverse,
          ]),
        ),
      ],
      contracts=[
        @moonstyle.style_contract("names").allow_animation_name(lists=[names]),
      ],
    ),
  )
  assert_true(output.diagnostics.is_empty())
  assert_eq(output.css.split("@keyframes ").count(), 3)
  assert_true(output.css.contains(",none,k"))
  assert_true(output.css.contains("animation-duration:1s,2s"))
  assert_true(output.css.contains("animation-direction:normal,reverse"))
  match @extract.decode_bundle(output.manifest) {
    Ok(bundle) => assert_true(@extract.validate_bundle(bundle).is_empty())
    Err(_) => fail("Animation list bundle must round trip")
  }
}

///|
test "counters timelines and motion paths compile without unsafe raw declarations" {
  let count = @moonstyle.counter_name("chapter")
  let changes = @moonstyle.counter_changes([@moonstyle.counter_change(count, 1)])
  let timeline = @moonstyle.timeline_name("--reading")
  let output = @extract.compile_registry(
    @moonstyle.registry("coverage/advanced", [
      @moonstyle.rule("counter")
      .counter_reset(
        @moonstyle.counter_changes([@moonstyle.counter_change(count, 0)]),
      )
      .counter_increment(changes)
      .counter_set(changes)
      .content(
        @moonstyle.content_sequence([
          @moonstyle.content_text("Chapter "),
          @moonstyle.counter_content(count, style=UpperRoman),
        ]),
        when=@moonstyle.before,
      ),
      @moonstyle.rule("timeline")
      .scroll_timeline_name(@moonstyle.timeline_names([timeline]))
      .view_timeline_name(@moonstyle.timeline_names([timeline]))
      .timeline_scope(@moonstyle.timeline_scope([timeline]))
      .animation_timeline(
        @moonstyle.animation_timelines([
          @moonstyle.named_timeline(timeline),
          @moonstyle.scroll_timeline(axis=YAxis),
        ]),
      )
      .animation_range_start(@moonstyle.timeline_range(Entry))
      .animation_range_end(@moonstyle.timeline_range(Exit)),
      @moonstyle.rule("motion")
      .offset_path(@moonstyle.ray_path(@moonstyle.deg(90.0), contain=true))
      .offset_position(@moonstyle.offset_position_normal())
      .offset_anchor(@moonstyle.offset_anchor_auto())
      .offset_rotate(
        @moonstyle.offset_rotation(@moonstyle.deg(20.0), reverse=true),
      ),
    ]),
  )
  assert_true(output.diagnostics.is_empty())
  for
    css in [
      "counter-increment:chapter 1", "counter(chapter,upper-roman)", "scroll-timeline-name:--reading",
      "animation-timeline:--reading,scroll(nearest y)", "offset-path:ray(90deg closest-side contain)",
      "offset-rotate:reverse 20deg",
    ] {
    assert_true(output.css.contains(css), msg=css)
  }
}
