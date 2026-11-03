///|
test "math distinguishes zero lengths percentages and numeric factors" {
  let zero_length = math_length(px(0))
  assert_eq(zero_length.add(math_length(px(1))).to_css(), "calc(0px + 1px)")
  assert_eq(
    css_min([zero_length, math_length(px(1))]).to_css(),
    "min(0px, 1px)",
  )
  assert_eq(
    css_clamp(zero_length, math_length(px(1)), math_length(px(2))).to_css(),
    "clamp(0px, 1px, 2px)",
  )
  assert_eq(
    zero_length.scale(math_number(number(0.0))).to_css(),
    "calc(0px * 0)",
  )
  assert_eq(
    math_length_percentage(px(0).as_length_percentage())
    .add(math_length_percentage(percentage(0.0).as_length_percentage()))
    .to_css(),
    "calc(0px + 0%)",
  )
  assert_eq(
    math_number(number(0.0)).add(math_number(number(1.0))).to_css(),
    "calc(0 + 1)",
  )
  assert_eq(px(0).to_css(), "0")
  assert_eq(zero_length.to_css(), "0")
  assert_eq(translate_z(px(0)).to_css(), "translateZ(0)")
}

///|
test "typed values serialize deterministic CSS" {
  let degrees = deg(45.0) catch { _ => fail("valid angle rejected") }
  let ratio = percentage(12.5) catch { _ => fail("valid percentage rejected") }
  let scalar = number(1.25) catch { _ => fail("valid number rejected") }
  let density = dppx(2.0) catch { _ => fail("valid resolution rejected") }
  let image = url("/asset.png") catch { _ => fail("valid URL rejected") }
  assert_eq(px(8).to_css(), "8px")
  assert_eq(percent(37).to_css(), "37%")
  assert_eq(rgb(10, 20, 30).to_css(), "rgb(10 20 30)")
  assert_eq(ms(180).to_css(), "180ms")
  assert_eq(degrees.to_css(), "45deg")
  assert_eq(ratio.to_css(), "12.5%")
  assert_eq(scalar.to_css(), "1.25")
  assert_eq(integer(3).to_css(), "3")
  assert_eq(density.to_css(), "2dppx")
  assert_eq(image.to_css(), "url(\"/asset.png\")")
  assert_eq(px(0).to_css(), "0")
}

///|
test "structured values validate and serialize compound CSS" {
  assert_eq(rem(1.5).to_css(), "1.5rem")
  assert_eq(dvh(100.0).to_css(), "100dvh")
  assert_eq(hex_color("#1a2B3c").to_css(), "#1a2B3c")
  assert_eq(hsl(210.0, 50.0, 40.0).to_css(), "hsl(210 50% 40%)")
  assert_eq(ratio(16, 9).to_css(), "16 / 9")
  let center = position_center()
  assert_eq(transform_origin(center).to_css(), "center")
  let half = length_percentage_from_percentage(percentage(50.0))
  let transform = transform_list([
    translate(half, half),
    rotate_transform(deg(45.0)),
    scale_transform(1.25),
  ])
  assert_eq(transform.to_css(), "translate(50%, 50%) rotate(45deg) scale(1.25)")
  assert_eq(
    cubic_bezier(0.4, 0.0, 0.2, 1.0).to_css(),
    "cubic-bezier(0.4, 0, 0.2, 1)",
  )
  let tracks = grid_tracks([fr(1.0), minmax(track_length(half), fr(2.0))])
  assert_eq(tracks.to_css(), "1fr minmax(50%, 2fr)")
  assert_eq(
    touch_action([PanX, PanY, PinchZoom]).to_css(),
    "pan-x pan-y pinch-zoom",
  )
  assert_eq(contain([Layout, Paint]).to_css(), "layout paint")
  assert_eq(
    font_variant_numeric([TabularNums, SlashedZero]).to_css(),
    "tabular-nums slashed-zero",
  )
}

///|
test "type-local category lifts preserve existing conversion semantics" {
  assert_eq(px(8).as_length_percentage().to_css(), "8px")
  assert_eq(percentage(25.0).as_length_percentage().to_css(), "25%")
  assert_eq(px(2).as_line_width().to_css(), "2px")
  assert_eq(rgb(1, 2, 3).as_outline_color().to_css(), "rgb(1 2 3)")
  let issues = value_issues(px(-1).as_line_width().to_css())
  assert_eq(issues.length(), 1)
  assert_eq(issues[0].code, "STYLE_VALUE_INVALID")
}

///|
test "validated value constructors reject invalid input" {
  try number(@double.not_a_number) catch {
    NonFinite(_) => ()
    _ => fail("expected non-finite number error")
  } noraise {
    _ => fail("NaN must be rejected")
  }
  try dppx(0.0) catch {
    OutOfRange(_) => ()
    _ => fail("expected resolution range error")
  } noraise {
    _ => fail("zero resolution must be rejected")
  }
  try url("") catch {
    EmptyUrl => ()
    _ => fail("expected empty URL error")
  } noraise {
    _ => fail("empty URL must be rejected")
  }
  try length_var("Invalid Scope", "value", px(1)) catch {
    InvalidCustomPropertyName(_) => ()
    _ => fail("expected custom property name error")
  } noraise {
    _ => fail("invalid variable name must be rejected")
  }
}

///|
test "border composite values serialize the stable grammar intersection" {
  let thin = line_width_keyword(LineWidthThin)
  let thick = line_width_from_length(px(3)) catch {
    _ => fail("valid line width rejected")
  }
  assert_eq(thin.to_css(), "thin")
  assert_eq(
    [LineWidthThin, LineWidthMedium, LineWidthThick]
    .map(line_width_keyword)
    .map(value => value.to_css()),
    ["thin", "medium", "thick"],
  )
  assert_eq(
    [
      LineStyleNone,
      LineStyleHidden,
      LineStyleDotted,
      LineStyleDashed,
      LineStyleSolid,
      LineStyleDouble,
      LineStyleGroove,
      LineStyleRidge,
      LineStyleInset,
      LineStyleOutset,
    ].map(value => value.to_css()),
    [
      "none", "hidden", "dotted", "dashed", "solid", "double", "groove", "ridge",
      "inset", "outset",
    ],
  )
  assert_eq(
    [
      OutlineStyleNone,
      OutlineStyleAuto,
      OutlineStyleDotted,
      OutlineStyleDashed,
      OutlineStyleSolid,
      OutlineStyleDouble,
      OutlineStyleGroove,
      OutlineStyleRidge,
      OutlineStyleInset,
      OutlineStyleOutset,
    ].map(value => value.to_css()),
    [
      "none", "auto", "dotted", "dashed", "solid", "double", "groove", "ridge", "inset",
      "outset",
    ],
  )
  assert_eq(thick.to_css(), "3px")
  assert_eq(
    border_side(
      width=Some(thick),
      style=Some(LineStyleSolid),
      color=Some(hex_color("123")),
    ).to_css(),
    "3px solid #123",
  )
  assert_eq(border_widths(thin, second=Some(thick)).to_css(), "thin 3px")
  assert_eq(
    border_styles(LineStyleDotted, second=Some(LineStyleDouble)).to_css(),
    "dotted double",
  )
  assert_eq(
    border_colors(transparent(), second=Some(rgb(1, 2, 3))).to_css(),
    "transparent rgb(1 2 3)",
  )
  let horizontal = length_percentage_from_length(px(4))
  let vertical = length_percentage_from_percentage(percentage(25.0))
  assert_eq(
    corner_radius(horizontal, vertical=Some(vertical)).to_css(),
    "4px 25%",
  )
  assert_eq(
    outline(
      width=Some(thin),
      style=Some(OutlineStyleAuto),
      color=Some(outline_auto_color()),
    ).to_css(),
    "thin auto auto",
  )
  assert_eq(outline_color_from_color(hex_color("abc")).to_css(), "#abc")
}

///|
test "border composite values reject values outside the stable intersection" {
  try line_width_from_length(auto()) catch {
    InvalidValue("line-width") => ()
    _ => fail("expected invalid line width")
  } noraise {
    _ => fail("auto line width must be rejected")
  }
  try line_width_from_length(percent(10)) catch {
    InvalidValue("line-width") => ()
    _ => fail("expected invalid line width")
  } noraise {
    _ => fail("percentage line width must be rejected")
  }
  try line_width_from_length(px(-1)) catch {
    InvalidValue("line-width") => ()
    _ => fail("expected invalid line width")
  } noraise {
    _ => fail("negative line width must be rejected")
  }
  let negative = length_percentage_from_length(px(-1))
  assert_false(
    corner_radius(negative)
    .expression()
    .issues("borderTopLeftRadius")
    .is_empty(),
  )
  try border_side() catch {
    EmptyValue("border-side") => ()
    _ => fail("expected empty border side")
  } noraise {
    _ => fail("empty border side must be rejected")
  }
  try outline() catch {
    EmptyValue("outline") => ()
    _ => fail("expected empty outline")
  } noraise {
    _ => fail("empty outline must be rejected")
  }
}

///|
test "typed variables retain their value category" {
  let variable : CssVar[Length] = length_var("demo", "progress", percent(0)) catch {
    _ => fail("valid variable rejected")
  }
  assert_eq(variable.name(), "--demo-progress")
  assert_eq(variable.default_css(), "0%")
  assert_eq(var_length(variable).to_css(), "var(--demo-progress)")
}

///|
test "variable scopes expose concrete token and slot aliases" {
  let scalar = number(1.25) catch { _ => fail("valid number rejected") }
  let ratio = percentage(25.0) catch { _ => fail("valid percentage rejected") }
  let angle = deg(45.0) catch { _ => fail("valid angle rejected") }
  let density = dppx(2.0) catch { _ => fail("valid resolution rejected") }
  let image = url("/asset.png") catch { _ => fail("valid URL rejected") }
  let length_percentage = length_percentage_from_length(px(8))
  let scope : VariableScope = variable_scope("aliases")
  let length_token_ : LengthToken = scope.length_token("length-token", px(8))
  let color_token_ : ColorToken = scope.color_token("color-token", rgb(1, 2, 3))
  let number_token_ : NumberToken = scope.number_token("number-token", scalar)
  let percentage_token_ : PercentageToken = scope.percentage_token(
    "percentage-token", ratio,
  )
  let length_percentage_token_ : LengthPercentageToken = scope.length_percentage_token(
    "length-percentage-token", length_percentage,
  )
  let integer_token_ : IntegerToken = scope.integer_token(
    "integer-token",
    integer(2),
  )
  let time_token_ : TimeToken = scope.time_token("time-token", ms(100))
  let angle_token_ : AngleToken = scope.angle_token("angle-token", angle)
  let resolution_token_ : ResolutionToken = scope.resolution_token(
    "resolution-token", density,
  )
  let url_token_ : UrlToken = scope.url_token("url-token", image)
  assert_eq(
    [
      length_token_.reference_css(),
      color_token_.reference_css(),
      number_token_.reference_css(),
      percentage_token_.reference_css(),
      length_percentage_token_.reference_css(),
      integer_token_.reference_css(),
      time_token_.reference_css(),
      angle_token_.reference_css(),
      resolution_token_.reference_css(),
      url_token_.reference_css(),
    ],
    [
      "var(--aliases-length-token)", "var(--aliases-color-token)", "var(--aliases-number-token)",
      "var(--aliases-percentage-token)", "var(--aliases-length-percentage-token)",
      "var(--aliases-integer-token)", "var(--aliases-time-token)", "var(--aliases-angle-token)",
      "var(--aliases-resolution-token)", "var(--aliases-url-token)",
    ],
  )
  let length_slot_ : LengthSlot = scope.length_slot("length-slot", px(8))
  let color_slot_ : ColorSlot = scope.color_slot("color-slot", rgb(1, 2, 3))
  let number_slot_ : NumberSlot = scope.number_slot("number-slot", scalar)
  let percentage_slot_ : PercentageSlot = scope.percentage_slot(
    "percentage-slot", ratio,
  )
  let length_percentage_slot_ : LengthPercentageSlot = scope.length_percentage_slot(
    "length-percentage-slot", length_percentage,
  )
  let integer_slot_ : IntegerSlot = scope.integer_slot(
    "integer-slot",
    integer(2),
  )
  let time_slot_ : TimeSlot = scope.time_slot("time-slot", ms(100))
  let angle_slot_ : AngleSlot = scope.angle_slot("angle-slot", angle)
  let resolution_slot_ : ResolutionSlot = scope.resolution_slot(
    "resolution-slot", density,
  )
  let url_slot_ : UrlSlot = scope.url_slot("url-slot", image)
  assert_eq(
    [
      length_slot_.variable_name(),
      color_slot_.variable_name(),
      number_slot_.variable_name(),
      percentage_slot_.variable_name(),
      length_percentage_slot_.variable_name(),
      integer_slot_.variable_name(),
      time_slot_.variable_name(),
      angle_slot_.variable_name(),
      resolution_slot_.variable_name(),
      url_slot_.variable_name(),
    ],
    [
      "--aliases-length-slot", "--aliases-color-slot", "--aliases-number-slot", "--aliases-percentage-slot",
      "--aliases-length-percentage-slot", "--aliases-integer-slot", "--aliases-time-slot",
      "--aliases-angle-slot", "--aliases-resolution-slot", "--aliases-url-slot",
    ],
  )
}
