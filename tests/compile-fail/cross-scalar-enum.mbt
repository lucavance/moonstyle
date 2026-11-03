///|
fn cross_scalar_enum() {
  let value : @properties.ScrollSnapStopValue = ScrollSnapStopValueNormal
  ignore(@properties.scrollbar_width(value))
}
