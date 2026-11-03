///|
test "position fallback accepts every reviewed descriptor through the facade" {
  let fallback = @moonstyle.position_try_rule("all")
    .position_anchor(
      @moonstyle.position_anchor(@moonstyle.anchor_name("target")),
    )
    .position_area(@moonstyle.position_area(AreaCenter, AreaBottom))
    .top(@moonstyle.px(1))
    .right(@moonstyle.px(2))
    .bottom(@moonstyle.px(3))
    .left(@moonstyle.px(4))
    .inset(@moonstyle.px(5))
    .inset_block(@moonstyle.px(6))
    .inset_block_start(@moonstyle.px(7))
    .inset_block_end(@moonstyle.px(8))
    .inset_inline(@moonstyle.px(9))
    .inset_inline_start(@moonstyle.px(10))
    .inset_inline_end(@moonstyle.px(11))
    .margin(@moonstyle.px(12))
    .margin_top(@moonstyle.px(13))
    .margin_right(@moonstyle.px(14))
    .margin_bottom(@moonstyle.px(15))
    .margin_left(@moonstyle.px(16))
    .margin_block(@moonstyle.px(17))
    .margin_block_start(@moonstyle.px(18))
    .margin_block_end(@moonstyle.px(19))
    .margin_inline(@moonstyle.px(20))
    .margin_inline_start(@moonstyle.px(21))
    .margin_inline_end(@moonstyle.px(22))
    .width(@moonstyle.px(23))
    .height(@moonstyle.px(24))
    .min_width(@moonstyle.px(25))
    .min_height(@moonstyle.px(26))
    .max_width(@moonstyle.px(27))
    .max_height(@moonstyle.px(28))
    .block_size(@moonstyle.px(29))
    .inline_size(@moonstyle.px(30))
    .min_block_size(@moonstyle.px(31))
    .min_inline_size(@moonstyle.px(32))
    .max_block_size(@moonstyle.px(33))
    .max_inline_size(@moonstyle.percent(90))
    .align_self(AlignmentStart)
    .justify_self(AlignmentEnd)
    .place_self(AlignmentCenter)
  assert_eq(fallback.to_ir().descriptors.length(), 39)
  let output = @extract.compile_registry(
    @moonstyle.registry_builder("position/all").position_try(fallback).build(),
  )
  assert_eq(output.diagnostics, [])
  assert_eq(
    output.css.split("\n").to_array()[1],
    "@position-try --all{position-anchor:--target;position-area:center bottom;top:1px;right:2px;bottom:3px;left:4px;inset:5px;inset-block:6px;inset-block-start:7px;inset-block-end:8px;inset-inline:9px;inset-inline-start:10px;inset-inline-end:11px;margin:12px;margin-top:13px;margin-right:14px;margin-bottom:15px;margin-left:16px;margin-block:17px;margin-block-start:18px;margin-block-end:19px;margin-inline:20px;margin-inline-start:21px;margin-inline-end:22px;width:23px;height:24px;min-width:25px;min-height:26px;max-width:27px;max-height:28px;block-size:29px;inline-size:30px;min-block-size:31px;min-inline-size:32px;max-block-size:33px;max-inline-size:90%;align-self:start;justify-self:end;place-self:center}",
  )
}

///|
test "position fallback replacement preserves cascade order and immutability" {
  let original = @moonstyle.position_try_rule("order").margin_top(
    @moonstyle.px(1),
  )
  let next = original
    .margin(@moonstyle.px(2))
    .margin_top(@moonstyle.px(3))
    .inset_inline_start(@moonstyle.px(4))
    .inset(@moonstyle.auto())
    .inset_inline_start(@moonstyle.px(0))
  let output = @extract.compile_registry(
    @moonstyle.registry("position/order", [], position_tries=[next]),
  )
  assert_eq(output.diagnostics, [])
  assert_true(
    output.css.contains(
      "@position-try --order{margin:2px;margin-top:3px;inset:auto;inset-inline-start:0}",
    ),
  )
  assert_eq(original.to_ir().descriptors.length(), 1)
  assert_eq(original.to_ir().descriptors[0].value, "1px")
}

///|
test "invalid authored position fallback values fail extraction" {
  let output = @extract.compile_registry(
    @moonstyle.registry("position/invalid", [], position_tries=[
      @moonstyle.position_try_rule("invalid").position_anchor(
        @moonstyle.position_anchor(@moonstyle.anchor_name("bad;name")),
      ),
    ]),
  )
  assert_true(
    output.diagnostics.any(diagnostic => {
      diagnostic.code == "STYLE_POSITION_TRY_DESCRIPTOR"
    }),
  )
  assert_false(output.css.contains("@position-try"))
}
