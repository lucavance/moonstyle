///|
pub(all) enum PseudoClass {
  Hover
  Focus
  FocusVisible
  FocusWithin
  Active
  Disabled
  Enabled
  Checked
  Required
  Optional
  ReadOnly
  ReadWrite
  PlaceholderShown
  FirstChild
  LastChild
  OnlyChild
  Empty
  Link
  Visited
  Valid
  Invalid
  InRange
  OutOfRange
  Indeterminate
  Target
  Autofill
  NthChild(Int32, Int32)
  NthLastChild(Int32, Int32)
  NthOfType(Int32, Int32)
  NthLastOfType(Int32, Int32)
  Is(Array[SelectorState])
  Not(Array[SelectorState])
  Where(Array[SelectorState])
  MatchAttribute(AttributeSelector)
} derive(Eq, Debug)

///|
pub(all) enum PseudoElement {
  Before
  After
  Placeholder
  Selection
  Marker
  FirstLetter
  FirstLine
  Backdrop
  FileSelectorButton
} derive(Eq, Debug)

///|
pub(all) enum MediaType {
  All
  Screen
  Print
  Speech
} derive(Eq, Debug)

///|
pub(all) enum MediaFeatureOperator {
  Min
  Max
  Equal
  LessThan
  GreaterThan
} derive(Eq, Debug)

///|
pub(all) struct MediaFeature {
  name : String
  operator : MediaFeatureOperator
  value : String
} derive(Eq, Debug)

///|
pub(all) struct MediaQuery {
  negated : Bool
  media_type : MediaType?
  features : Array[MediaFeature]
} derive(Eq, Debug)

///|
pub(all) enum SupportsCondition {
  Declaration(String, String)
  Not(SupportsCondition)
  All(Array[SupportsCondition])
  Any(Array[SupportsCondition])
} derive(Eq, Debug)

///|
pub(all) struct ContainerQuery {
  name : String?
  features : Array[MediaFeature]
} derive(Eq, Debug)

///|
pub(all) enum SelectorState {
  SelectorPseudo(PseudoClass)
  SelectorAttribute(String)
  SelectorAttributeEquals(String, String)
  SelectorAttributeMatch(AttributeSelector)
} derive(Eq, Debug)

///|
pub(all) enum AttributeOperator {
  Present
  Equals
  IncludesWord
  DashPrefix
  Prefix
  Suffix
  Substring
} derive(Eq, Debug)

///|
pub(all) enum AttributeCase {
  DefaultCase
  Insensitive
  Sensitive
} derive(Eq, Debug)

///|
pub(all) struct AttributeSelector {
  name : String
  operator : AttributeOperator
  value : String
  case_mode : AttributeCase
} derive(Eq, Debug)

///|
pub(all) struct SelectorMarkerRef {
  module_name : String
  name : String
  class_name : String
  states : Array[SelectorState]
} derive(Eq, Debug)

///|
pub(all) enum MarkerRelation {
  MarkerAncestor
  MarkerDescendant
  MarkerSiblingBefore
  MarkerSiblingAfter
  MarkerAnySibling
} derive(Eq, Debug)

///|
pub(all) enum Condition {
  Pseudo(PseudoClass)
  PseudoElement(PseudoElement)
  UnsafePseudo(String)
  UnsafePseudoElement(String)
  UnsafeAtRule(String)
  Media(MediaQuery)
  Supports(SupportsCondition)
  Container(ContainerQuery)
  ContainerStyle(ContainerStyleCondition)
  Relational(SelectorMarkerRef, MarkerRelation)
  Layer(String)
} derive(Eq, Debug)

///|
pub(all) enum KeyframeStep {
  From
  To
  Percent(Int32)
} derive(Eq, Debug)

///|
pub(all) struct KeyframeDeclaration {
  expressions : Array[@values.Expression]
  property : String
  values : Array[String]
  conditions : Array[Condition]
  dynamic : Bool
  keyframe_allowed : Bool
  source : SourceSpan?
} derive(Eq, Debug)

///|
pub(all) struct KeyframeFrame {
  step : KeyframeStep
  declarations : Array[KeyframeDeclaration]
} derive(Eq, Debug)

///|
pub(all) struct Keyframes {
  name_hint : String
  frames : Array[KeyframeFrame]
} derive(Eq, Debug)

///|
pub(all) struct AnimationName {
  keyframes : Keyframes
} derive(Eq, Debug)

///|
pub(all) enum StyleValue {
  Text(String)
  Fallbacks(Array[String])
  Dynamic(String, String, String)
  Expression(@values.Expression)
  ExpressionFallbacks(Array[@values.Expression])
  Animation(AnimationName)
  AnimationList(Array[AnimationName?])
  Clear
} derive(Eq, Debug)

///|
/// Canonical identity for a token or dynamic slot admitted by a component
/// contract. The custom-property name is the cross-package identity; category
/// prevents a value channel from being reused through an incompatible type.
pub(all) struct ContractVariable {
  variable : String
  category : String
} derive(Eq, Debug)

///|
pub(all) enum ContractValuePolicy {
  AnySafe
  Exact(
    Array[String],
    Array[ContractVariable],
    Array[ContractVariable],
    Array[String]
  )
} derive(Eq, Debug)

///|
pub(all) struct ContractProperty {
  name : String
  policy : ContractValuePolicy
} derive(Eq, Debug)

///|
/// Records how a declaration obtained its value. Contract checks use this
/// provenance so a literal equal to a token default cannot impersonate that
/// token, and a runtime slot remains a typed channel rather than a literal.
pub(all) enum DeclarationValueOrigin {
  LiteralOrigin(Array[String])
  TokenOrigin(ContractVariable)
  DynamicSlotOrigin(ContractVariable)
  ExpressionOrigin(String)
  ExpressionFallbackOrigin(Array[String])
  MixedFallbackOrigin(Array[DeclarationValueOrigin])
  AnimationOrigin
  ClearOrigin
  UnsafeOrigin
} derive(Eq, Debug)

///|
pub(all) struct SourceSpan {
  file : String
  line : Int32
  column : Int32
  end_line : Int32
  end_column : Int32
  symbol : String
} derive(Eq, Debug)

///|
pub(all) struct Declaration {
  property : String
  atomic_properties : Array[String]
  unsafe_raw : Bool
  value : StyleValue
  value_origin : DeclarationValueOrigin
  conditions : Array[Condition]
  source : SourceSpan?
  keyframe_allowed : Bool
} derive(Eq, Debug)

///|
pub(all) struct Namespace {
  name : String
  declarations : Array[Declaration]
} derive(Eq, Debug)

///|
pub(all) struct StyleSet {
  export_name : String
  namespaces : Array[Namespace]
} derive(Eq, Debug)

///|
pub(all) struct StyleContract {
  name : String
  properties : Array[ContractProperty]
} derive(Eq, Debug)

///|
pub(all) struct VariableSet {
  scope : String
  definitions : Array[@values.VarDefinition]
} derive(Eq, Debug)

///|
pub(all) struct Theme {
  name : String
  base : VariableSet
  overrides : Array[@values.VarOverride]
} derive(Eq, Debug)

///|
pub(all) struct RecipeVariantChoice {
  value : String
  rules : Array[String]
} derive(Eq, Debug)

///|
pub(all) struct RecipeVariantAxis {
  name : String
  choices : Array[RecipeVariantChoice]
  default_value : String?
  boolean : Bool
} derive(Eq, Debug)

///|
pub(all) struct RecipeVariantMatch {
  axis : String
  value : String
} derive(Eq, Debug)

///|
pub(all) struct RecipeCompound {
  matches : Array[RecipeVariantMatch]
  rules : Array[String]
} derive(Eq, Debug)

///|
pub(all) struct Recipe {
  name : String
  base : Array[String]
  variants : Array[RecipeVariantAxis]
  compounds : Array[RecipeCompound]
  contract : String?
} derive(Eq, Debug)

///|
pub(all) struct MarkerDefinition {
  name : String
} derive(Eq, Debug)

///|
pub(all) struct PositionTryDescriptor {
  name : String
  value : String
} derive(Eq, Debug)

///|
pub(all) struct PositionTryDefinition {
  name : String
  descriptors : Array[PositionTryDescriptor]
} derive(Eq, Debug)

///|
pub(all) struct ViewTransitionClassDefinition {
  name : String
  styles : Array[ViewTransitionStyle]
} derive(Eq, Debug)

///|
pub(all) struct ViewTransitionStyle {
  group : String
  declarations : Array[Declaration]
} derive(Eq, Debug)

///|
pub struct DependencyRef {
  module_name : String
  semantic_digest : String
} derive(Eq, Debug)

///|
pub fn dependency_ref(
  module_name : String,
  semantic_digest : String,
) -> DependencyRef {
  { module_name, semantic_digest, }
}

///|
pub fn DependencyRef::module_name(self : DependencyRef) -> String {
  self.module_name
}

///|
pub fn DependencyRef::semantic_digest(self : DependencyRef) -> String {
  self.semantic_digest
}

///|
pub(all) struct Registry {
  module_name : String
  styles : Array[StyleSet]
  contracts : Array[StyleContract]
  variable_sets : Array[VariableSet]
  themes : Array[Theme]
  recipes : Array[Recipe]
  markers : Array[MarkerDefinition]
  position_tries : Array[PositionTryDefinition]
  view_transition_classes : Array[ViewTransitionClassDefinition]
  direct_dependencies : Array[DependencyRef]
} derive(Eq, Debug)

///|
pub fn text(value : String) -> StyleValue {
  Text(value)
}

///|
pub fn fallbacks(values : Array[String]) -> StyleValue {
  Fallbacks(values)
}

///|
pub fn dynamic(
  variable : String,
  suffix : String,
  category~ : String = "string",
) -> StyleValue {
  Dynamic(variable, suffix, category)
}

///|
pub fn animation(value : AnimationName) -> StyleValue {
  Animation(value)
}

///|
pub fn clear_value() -> StyleValue {
  Clear
}

///|
pub fn declaration(
  property : String,
  value : StyleValue,
  conditions~ : Array[Condition] = [],
  source~ : SourceSpan? = None,
  atomic_properties~ : Array[String] = [],
  keyframe_allowed~ : Bool = false,
  unsafe_raw~ : Bool = false,
  value_origin~ : DeclarationValueOrigin? = None,
) -> Declaration {
  let value_origin = if unsafe_raw {
    UnsafeOrigin
  } else {
    match value_origin {
      Some(origin) => origin
      None =>
        match value {
          Text(value) => LiteralOrigin([value])
          Fallbacks(values) => LiteralOrigin(values.copy())
          Dynamic(variable, _, category) =>
            DynamicSlotOrigin({ variable, category, })
          Expression(value) => ExpressionOrigin(value.identity())
          ExpressionFallbacks(values) =>
            ExpressionFallbackOrigin(values.map(value => value.identity()))
          Animation(_) => AnimationOrigin
          AnimationList(values) =>
            ExpressionOrigin(animation_list_identity(values))
          Clear => ClearOrigin
        }
    }
  }
  {
    property,
    atomic_properties,
    unsafe_raw,
    value,
    value_origin,
    conditions,
    source,
    keyframe_allowed,
  }
}

///|
pub fn source_span(
  file : String,
  line : Int32,
  column : Int32,
  end_line~ : Int32 = line,
  end_column~ : Int32 = column,
  symbol~ : String = "",
) -> SourceSpan {
  { file, line, column, end_line, end_column, symbol, }
}

///|
pub fn Declaration::with_source(
  self : Declaration,
  source : SourceSpan,
) -> Declaration {
  { ..self, source: Some(source), }
}

///|
fn Declaration::to_keyframe_declaration(
  self : Declaration,
) -> KeyframeDeclaration {
  let (values, dynamic) = match self.value {
    Text(value) => ([value], false)
    Fallbacks(values) => (values, false)
    Dynamic(_, _, _) | Animation(_) | AnimationList(_) => ([], true)
    Expression(value) => ([value.to_css()], value.is_dynamic())
    ExpressionFallbacks(values) =>
      (
        values.map(value => value.to_css()),
        values.any(value => value.is_dynamic()),
      )
    Clear => ([], false)
  }
  {
    property: self.property,
    expressions: match self.value {
      Expression(value) => [value]
      ExpressionFallbacks(values) => values
      _ => []
    },
    values,
    conditions: self.conditions,
    dynamic,
    keyframe_allowed: self.keyframe_allowed,
    source: self.source,
  }
}

///|
pub fn keyframe_frame(
  step : KeyframeStep,
  declarations : Array[Declaration],
) -> KeyframeFrame {
  {
    step,
    declarations: declarations.map(Declaration::to_keyframe_declaration),
  }
}

///|
pub fn keyframes(
  name_hint : String,
  frames : Array[KeyframeFrame],
) -> AnimationName {
  { keyframes: { name_hint, frames, }, }
}

///|
pub fn pseudo(value : PseudoClass) -> Condition {
  Pseudo(value)
}

///|
pub fn pseudo_element(value : PseudoElement) -> Condition {
  PseudoElement(value)
}

///|
pub fn unsafe_pseudo(value : String) -> Condition {
  UnsafePseudo(value)
}

///|
pub fn unsafe_pseudo_element(value : String) -> Condition {
  UnsafePseudoElement(value)
}

///|
pub fn unsafe_at_rule(value : String) -> Condition {
  UnsafeAtRule(value)
}

///|
pub fn media_feature(
  name : String,
  operator : MediaFeatureOperator,
  value : String,
) -> MediaFeature {
  { name, operator, value, }
}

///|
pub fn media_query(
  features : Array[MediaFeature],
  negated~ : Bool = false,
  media_type~ : MediaType? = None,
) -> MediaQuery {
  { negated, media_type, features, }
}

///|
pub fn media(query : MediaQuery) -> Condition {
  Media(query)
}

///|
pub fn container_query(
  features : Array[MediaFeature],
  name~ : String? = None,
) -> ContainerQuery {
  { name, features, }
}

///|
pub fn container(query : ContainerQuery) -> Condition {
  Container(query)
}

///|
pub fn container_style_condition(
  condition : ContainerStyleCondition,
) -> Condition {
  ContainerStyle(condition)
}

///|
pub fn selector_marker_ref(
  module_name : String,
  name : String,
  class_name : String,
  states~ : Array[SelectorState] = [],
) -> SelectorMarkerRef {
  { module_name, name, class_name, states, }
}

///|
pub fn relational(
  marker : SelectorMarkerRef,
  relation : MarkerRelation,
) -> Condition {
  Relational(marker, relation)
}

///|
pub fn supports_declaration(
  property : String,
  value : String,
) -> SupportsCondition {
  Declaration(property, value)
}

///|
pub fn supports_not(condition : SupportsCondition) -> SupportsCondition {
  Not(condition)
}

///|
pub fn supports_all(conditions : Array[SupportsCondition]) -> SupportsCondition {
  All(conditions)
}

///|
pub fn supports_any(conditions : Array[SupportsCondition]) -> SupportsCondition {
  Any(conditions)
}

///|
pub fn supports(condition : SupportsCondition) -> Condition {
  Supports(condition)
}

///|
pub fn layer(name : String) -> Condition {
  Layer(name)
}

///|
pub fn style_namespace(
  name : String,
  declarations : Array[Declaration],
) -> Namespace {
  { name, declarations, }
}

///|
pub fn style_set(
  export_name : String,
  namespaces : Array[Namespace],
) -> StyleSet {
  { export_name, namespaces, }
}

///|
pub fn style_contract(
  name : String,
  properties : Array[ContractProperty],
) -> StyleContract {
  { name, properties: properties.copy(), }
}

///|
pub fn contract_variable(
  variable : String,
  category : String,
) -> ContractVariable {
  { variable, category, }
}

///|
pub fn any_contract_property(name : String) -> ContractProperty {
  { name, policy: AnySafe, }
}

///|
pub fn exact_contract_property(
  name : String,
  values~ : Array[String] = [],
  tokens~ : Array[ContractVariable] = [],
  slots~ : Array[ContractVariable] = [],
  expressions~ : Array[String] = [],
) -> ContractProperty {
  {
    name,
    policy: Exact(
      values.copy(),
      tokens.copy(),
      slots.copy(),
      expressions.copy(),
    ),
  }
}

///|
pub fn define_vars(
  scope : String,
  definitions : Array[@values.VarDefinition],
) -> VariableSet {
  { scope, definitions, }
}

///|
pub fn create_theme(
  name : String,
  base : VariableSet,
  overrides : Array[@values.VarOverride],
) -> Theme {
  { name, base, overrides, }
}

///|
pub fn registry(
  module_name : String,
  styles : Array[StyleSet],
  contracts~ : Array[StyleContract] = [],
  variable_sets~ : Array[VariableSet] = [],
  themes~ : Array[Theme] = [],
  recipes~ : Array[Recipe] = [],
  markers~ : Array[MarkerDefinition] = [],
  position_tries~ : Array[PositionTryDefinition] = [],
  view_transition_classes~ : Array[ViewTransitionClassDefinition] = [],
  direct_dependencies~ : Array[DependencyRef] = [],
) -> Registry {
  {
    module_name,
    styles,
    contracts,
    variable_sets,
    themes,
    recipes,
    markers,
    position_tries,
    view_transition_classes,
    direct_dependencies,
  }
}
