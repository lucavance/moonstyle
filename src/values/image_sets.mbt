///|
pub struct ImageCandidate {
  expression : Expression
}

///|
pub fn[I : ImageInput] image_candidate(
  value : I,
  resolution? : Resolution,
  mime? : String,
) -> ImageCandidate {
  let expression = value.image_expression()
  let values = [expression]
  if expression.to_css().contains("image-set(") {
    values.push(
      invalid_expression(
        "STYLE_IMAGE_SET_NESTED", "Image set candidates cannot contain image-set()",
      ),
    )
  }
  // Image lists and none are not <image> candidates.
  if expression.category == "image-list" || expression.to_css() == "none" {
    values.push(
      invalid_expression(
        "STYLE_IMAGE_SET_CANDIDATE", "An image set candidate must be a single image",
      ),
    )
  }
  if resolution is Some(value) {
    let css = value.to_css()
    let valid = match numeric_part(css, "resolution") {
      Some(number) => number > 0.0
      None => false
    }
    values.push(
      if valid {
        literal_expression(css, "resolution")
      } else {
        invalid_expression(
          "STYLE_IMAGE_SET_RESOLUTION", "Image resolution must be positive and finite",
        )
      },
    )
  }
  if mime is Some(value) {
    if !value.has_prefix("image/") || value.length() <= 6 || value.contains(" ") {
      values.push(
        invalid_expression(
          "STYLE_IMAGE_SET_MIME", "Image MIME type must start with image/",
        ),
      )
    } else {
      values.push(
        literal_expression(
          "type(" + quoted_css_string(value, "image MIME type") + ")",
          "mime",
        ),
      )
    }
  }
  { expression: group_expression("image-candidate", "", values, " ", ""), }
}

///|
pub fn image_set(candidates : Array[ImageCandidate]) -> Image {
  let values = candidates.map(value => value.expression)
  if values.is_empty() {
    values.push(
      invalid_expression(
        "STYLE_IMAGE_SET_EMPTY", "An image set requires at least one candidate",
      ),
    )
  }
  { expression: group_expression("image", "image-set(", values, ", ", ")"), }
}
