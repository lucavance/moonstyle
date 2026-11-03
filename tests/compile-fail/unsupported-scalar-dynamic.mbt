///|
fn unsupported_scalar_dynamic() raise @values.ValueError {
  let size = @values.length_var("demo", "block-size", @values.px(10))
  ignore(@properties.dynamic_block_size(size))
}
