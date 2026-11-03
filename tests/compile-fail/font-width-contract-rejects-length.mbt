///|
fn font_width_contract_rejects_length() {
  ignore(@moonstyle.style_contract("text").allow_font_width(values=[@moonstyle.px(100)]))
}
