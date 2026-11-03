///|
pub(all) enum LayerAttachment {
  LayerScroll
  LayerFixed
  LayerLocal
} derive(Eq, Debug)

///|
pub(all) enum LayerBox {
  LayerBorderBox
  LayerPaddingBox
  LayerContentBox
} derive(Eq, Debug)

///|
pub struct LayerSize {
  expression : Expression
} derive(Eq, Debug)

///|
pub struct BackgroundLayer {
  image : Expression
  position : GradientPosition
  size : LayerSize
  repeat : RepeatStyle
  attachment : LayerAttachment
  origin : LayerBox
  clip : LayerBox
} derive(Eq, Debug)

///|
pub struct BackgroundLayers {
  layers : Array[BackgroundLayer]
} derive(Eq, Debug)

///|
pub fn layer_size(value : BackgroundSize) -> LayerSize {
  { expression: literal_expression(value.to_css(), "background-size"), }
}

///|
pub fn[X : LengthPercentageMathInput, Y : LengthPercentageMathInput] layer_dimensions(
  width : X,
  height : Y,
) -> LayerSize {
  {
    expression: group_expression(
      "background-size",
      "",
      [
        width.length_percentage_math().expression.constrain("nonnegative"),
        height.length_percentage_math().expression.constrain("nonnegative"),
      ],
      " ",
      "",
    ),
  }
}

///|
pub fn[I : ImageInput] background_layer(
  image : I,
  position~ : GradientPosition = {
    x: literal_expression("0%", "length-percentage"),
    y: literal_expression("0%", "length-percentage"),
  },
  size~ : LayerSize = {
    expression: literal_expression("auto", "background-size"),
  },
  repeat~ : RepeatStyle = Repeat,
  attachment~ : LayerAttachment = LayerScroll,
  origin~ : LayerBox = LayerPaddingBox,
  clip~ : LayerBox = LayerBorderBox,
) -> BackgroundLayer {
  {
    image: image.image_expression(),
    position,
    size,
    repeat,
    attachment,
    origin,
    clip,
  }
}

///|
pub fn background_layers(layers : Array[BackgroundLayer]) -> BackgroundLayers {
  { layers: layers.copy(), }
}

///|
fn LayerBox::css(self : LayerBox) -> String {
  match self {
    LayerBorderBox => "border-box"
    LayerPaddingBox => "padding-box"
    LayerContentBox => "content-box"
  }
}

///|
fn BackgroundLayer::longhand(
  self : BackgroundLayer,
  property : String,
) -> Expression {
  match property {
    "backgroundImage" => self.image
    "backgroundPositionX" => self.position.x
    "backgroundPositionY" => self.position.y
    "backgroundSize" => self.size.expression
    "backgroundRepeat" =>
      literal_expression(self.repeat.to_css(), "background-repeat")
    "backgroundAttachment" =>
      literal_expression(
        match self.attachment {
          LayerScroll => "scroll"
          LayerFixed => "fixed"
          LayerLocal => "local"
        },
        "background-attachment",
      )
    "backgroundOrigin" =>
      literal_expression(self.origin.css(), "background-origin")
    _ => literal_expression(self.clip.css(), "background-clip")
  }
}

///|
pub fn BackgroundLayers::longhands(
  self : BackgroundLayers,
) -> Array[(String, Expression)] {
  [
    "backgroundImage", "backgroundPositionX", "backgroundPositionY", "backgroundSize",
    "backgroundRepeat", "backgroundAttachment", "backgroundOrigin", "backgroundClip",
  ].map(property => {
    let values = self.layers.map(layer => layer.longhand(property))
    if values.is_empty() {
      values.push(
        invalid_expression(
          "STYLE_BACKGROUND_EMPTY", "A background layer list must not be empty",
        ),
      )
    }
    (
      property,
      group_expression(
        if property == "backgroundImage" {
          "image-list"
        } else {
          property
        },
        "",
        values,
        ", ",
        "",
      ),
    )
  })
}

///|
pub fn BackgroundLayers::property_expression(
  self : BackgroundLayers,
  property : String,
) -> Expression {
  for (name, expression) in self.longhands() {
    if name == property {
      return expression
    }
  }
  invalid_expression(
    "STYLE_BACKGROUND_PROPERTY", "Unsupported background longhand",
  )
}
