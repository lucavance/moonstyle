///|
pub fn StyleValue::animations(self : StyleValue) -> Array[AnimationName] {
  match self {
    Animation(value) => [value]
    AnimationList(values) => values.filter_map(value => value)
    _ => []
  }
}

///|
pub fn animation_list_identity(values : Array[AnimationName?]) -> String {
  let items : Array[Json] = values.map(value => {
    match value {
      None => Json::string("none")
      Some(value) =>
        Json::array(
          value.keyframes.frames.map(frame => {
            let step = match frame.step {
              From => "0%"
              To => "100%"
              Percent(value) => value.to_string() + "%"
            }
            Json::array([
              Json::string(step),
              Json::array(
                frame.declarations.map(value => {
                  Json::array([
                    Json::string(value.property),
                    Json::array(value.values.map(Json::string)),
                    Json::array(
                      value.expressions.map(value => {
                        Json::string(value.identity())
                      }),
                    ),
                  ])
                }),
              ),
            ])
          }),
        )
    }
  })
  @values.declaration_expression(Json::array(items).stringify(), None).identity()
}
