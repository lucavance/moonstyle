///|
pub struct MarkerDefinition {
  name : String
}

///|
pub fn define_marker(name : String) -> MarkerDefinition {
  { name, }
}

///|
pub(open) trait MarkerInput {
  fn marker_reference(Self) -> @ir.SelectorMarkerRef
}

///|
pub impl MarkerInput for MarkerDefinition with fn marker_reference(self) {
  @ir.selector_marker_ref("", self.name, "")
}

///|
pub impl MarkerInput for @runtime.SelectorMarker with fn marker_reference(self) {
  @ir.selector_marker_ref(self.module_name(), self.name(), self.class_name())
}

///|
pub struct MarkerSelector {
  reference : @ir.SelectorMarkerRef
}

///|
pub impl MarkerInput for MarkerSelector with fn marker_reference(self) {
  self.reference
}

///|
fn[T : MarkerInput] marker_with_state(
  marker : T,
  state : @ir.SelectorState,
) -> MarkerSelector {
  let reference = marker.marker_reference()
  let states = reference.states.copy()
  states.push(state)
  {
    reference: {
      module_name: reference.module_name,
      name: reference.name,
      class_name: reference.class_name,
      states,
    },
  }
}

///|
pub fn[T : MarkerInput] selector_pseudo(
  marker : T,
  state : @ir.PseudoClass,
) -> MarkerSelector {
  marker_with_state(marker, @ir.SelectorPseudo(state))
}

///|
pub fn[T : MarkerInput] selector_attribute(
  marker : T,
  name : String,
) -> MarkerSelector {
  marker_with_state(marker, @ir.SelectorAttribute(name))
}

///|
pub fn[T : MarkerInput] selector_attribute_equals(
  marker : T,
  name : String,
  value : String,
) -> MarkerSelector {
  marker_with_state(marker, @ir.SelectorAttributeEquals(name, value))
}

///|
pub fn[T : MarkerInput] marker_ancestor(marker : T) -> When {
  when([@ir.relational(marker.marker_reference(), MarkerAncestor)])
}

///|
pub fn[T : MarkerInput] marker_descendant(marker : T) -> When {
  when([@ir.relational(marker.marker_reference(), MarkerDescendant)])
}

///|
pub fn[T : MarkerInput] marker_sibling_before(marker : T) -> When {
  when([@ir.relational(marker.marker_reference(), MarkerSiblingBefore)])
}

///|
pub fn[T : MarkerInput] marker_sibling_after(marker : T) -> When {
  when([@ir.relational(marker.marker_reference(), MarkerSiblingAfter)])
}

///|
pub fn[T : MarkerInput] marker_any_sibling(marker : T) -> When {
  when([@ir.relational(marker.marker_reference(), MarkerAnySibling)])
}

///|
pub fn MarkerDefinition::to_ir(self : MarkerDefinition) -> @ir.MarkerDefinition {
  { name: self.name, }
}

///|
pub(all) enum ContainerAxis {
  ContainerWidth
  ContainerHeight
  ContainerInlineSize
  ContainerBlockSize
} derive(Eq, Debug)

///|
pub(all) enum ContainerOperator {
  ContainerMin
  ContainerMax
  ContainerEqual
  ContainerLessThan
  ContainerGreaterThan
} derive(Eq, Debug)

///|
pub struct ContainerName {
  value : String
}

///|
pub fn container_name(value : String) -> ContainerName {
  { value, }
}

///|
pub struct ContainerFeature {
  axis : ContainerAxis
  operator : ContainerOperator
  value : @values.Length
}

///|
pub fn container_feature(
  axis : ContainerAxis,
  operator : ContainerOperator,
  value : @values.Length,
) -> ContainerFeature {
  { axis, operator, value, }
}

///|
fn ContainerAxis::to_name(self : ContainerAxis) -> String {
  match self {
    ContainerWidth => "width"
    ContainerHeight => "height"
    ContainerInlineSize => "inline-size"
    ContainerBlockSize => "block-size"
  }
}

///|
fn ContainerOperator::to_media_operator(
  self : ContainerOperator,
) -> @ir.MediaFeatureOperator {
  match self {
    ContainerMin => Min
    ContainerMax => Max
    ContainerEqual => Equal
    ContainerLessThan => LessThan
    ContainerGreaterThan => GreaterThan
  }
}

///|
pub fn container_query(
  features : Array[ContainerFeature],
  name~ : ContainerName? = None,
) -> When {
  when([
    @ir.container(
      @ir.container_query(
        features.map(feature => {
          @ir.media_feature(
            feature.axis.to_name(),
            feature.operator.to_media_operator(),
            feature.value.to_css(),
          )
        }),
        name=name.map(value => value.value),
      ),
    ),
  ])
}

///|
pub fn container_min_width(
  value : @values.Length,
  name~ : ContainerName? = None,
) -> When {
  container_query(
    [container_feature(ContainerWidth, ContainerMin, value)],
    name~,
  )
}

///|
pub fn container_max_width(
  value : @values.Length,
  name~ : ContainerName? = None,
) -> When {
  container_query(
    [container_feature(ContainerWidth, ContainerMax, value)],
    name~,
  )
}

///|
pub fn container_width_between(
  minimum : @values.Length,
  maximum : @values.Length,
  name~ : ContainerName? = None,
) -> When {
  container_query(
    [
      container_feature(ContainerWidth, ContainerMin, minimum),
      container_feature(ContainerWidth, ContainerMax, maximum),
    ],
    name~,
  )
}
