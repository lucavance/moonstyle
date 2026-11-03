///|
pub(all) enum MaskBox {
  MaskBorderBox
  MaskPaddingBox
  MaskContentBox
  MaskFillBox
  MaskStrokeBox
  MaskViewBox
} derive(Eq, Debug)

///|
pub extend MaskBox with Eq::{equal, not_equal}

///|
pub extend MaskBox with @debug.Debug::{to_repr}

///|
pub fn MaskBox::to_css(self : MaskBox) -> String {
  match self {
    MaskBorderBox => "border-box"
    MaskPaddingBox => "padding-box"
    MaskContentBox => "content-box"
    MaskFillBox => "fill-box"
    MaskStrokeBox => "stroke-box"
    MaskViewBox => "view-box"
  }
}

///|
pub(all) enum MaskClip {
  ClipBox(MaskBox)
  NoClip
} derive(Eq, Debug)

///|
pub extend MaskClip with Eq::{equal, not_equal}

///|
pub extend MaskClip with @debug.Debug::{to_repr}

///|
pub fn MaskClip::to_css(self : MaskClip) -> String {
  match self {
    ClipBox(box) => box.to_css()
    NoClip => "no-clip"
  }
}

///|
pub(all) enum MaskMode {
  MatchSource
  Alpha
  Luminance
} derive(Eq, Debug)

///|
pub extend MaskMode with Eq::{equal, not_equal}

///|
pub extend MaskMode with @debug.Debug::{to_repr}

///|
pub fn MaskMode::to_css(self : MaskMode) -> String {
  match self {
    MatchSource => "match-source"
    Alpha => "alpha"
    Luminance => "luminance"
  }
}

///|
pub(all) enum MaskComposite {
  MaskAdd
  MaskSubtract
  MaskIntersect
  MaskExclude
} derive(Eq, Debug)

///|
pub extend MaskComposite with Eq::{equal, not_equal}

///|
pub extend MaskComposite with @debug.Debug::{to_repr}

///|
pub fn MaskComposite::to_css(self : MaskComposite) -> String {
  match self {
    MaskAdd => "add"
    MaskSubtract => "subtract"
    MaskIntersect => "intersect"
    MaskExclude => "exclude"
  }
}

///|
pub struct MaskLayer {
  image : Expression
  position : GradientPosition
  size : LayerSize
  repeat : RepeatStyle
  origin : MaskBox
  clip : MaskClip
  mode : MaskMode
  composite : MaskComposite
}

///|
pub fn[I : ImageInput] mask_layer(
  image : I,
  position~ : GradientPosition = {
    x: literal_expression("0%", "length-percentage"),
    y: literal_expression("0%", "length-percentage"),
  },
  size~ : LayerSize = {
    expression: literal_expression("auto", "background-size"),
  },
  repeat~ : RepeatStyle = Repeat,
  origin~ : MaskBox = MaskBorderBox,
  clip~ : MaskClip = ClipBox(MaskBorderBox),
  mode~ : MaskMode = MatchSource,
  composite~ : MaskComposite = MaskAdd,
) -> MaskLayer {
  let expression = image.image_expression()
  {
    image: if expression.category == "image-list" {
      invalid_expression(
        "STYLE_MASK_IMAGE", "A mask layer requires one image; use separate mask layers",
      )
    } else {
      expression
    },
    position,
    size,
    repeat,
    origin,
    clip,
    mode,
    composite,
  }
}

///|
pub struct MaskLayers {
  layers : Array[MaskLayer]
}

///|
pub fn mask_layers(layers : Array[MaskLayer]) -> MaskLayers {
  { layers: layers.copy(), }
}

///|
fn MaskLayer::longhand(self : MaskLayer, property : String) -> Expression {
  match property {
    "maskImage" => self.image
    "maskPosition" => self.position.expression()
    "maskSize" => self.size.expression
    "maskRepeat" => literal_expression(self.repeat.to_css(), "mask-repeat")
    "maskOrigin" => literal_expression(self.origin.to_css(), "mask-origin")
    "maskClip" => literal_expression(self.clip.to_css(), "mask-clip")
    "maskMode" => literal_expression(self.mode.to_css(), "mask-mode")
    _ => literal_expression(self.composite.to_css(), "mask-composite")
  }
}

///|
pub fn MaskLayers::longhands(self : MaskLayers) -> Array[(String, Expression)] {
  [
    "maskImage", "maskPosition", "maskSize", "maskRepeat", "maskOrigin", "maskClip",
    "maskMode", "maskComposite",
  ].map(property => {
    let values = self.layers.map(layer => layer.longhand(property))
    if values.is_empty() {
      values.push(
        invalid_expression("STYLE_MASK_EMPTY", "Mask layers must not be empty"),
      )
    }
    (property, group_expression(property, "", values, ", ", ""))
  })
}
