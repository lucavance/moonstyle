///|
pub struct When {
  conditions : Array[@ir.Condition]
}

///|
pub(all) enum PreferredColorScheme {
  ColorSchemeLight
  ColorSchemeDark
} derive(Eq, Debug)

///|
pub(all) enum MotionPreference {
  MotionReduce
  MotionNoPreference
} derive(Eq, Debug)

///|
pub(all) enum ViewportOrientation {
  OrientationPortrait
  OrientationLandscape
} derive(Eq, Debug)

///|
pub fn when(conditions : Array[@ir.Condition]) -> When {
  { conditions: conditions.copy(), }
}

///|
pub fn When::to_conditions(self : When) -> Array[@ir.Condition] {
  self.conditions.copy()
}

///|
pub fn when_all(values : Array[When]) -> When {
  let conditions : Array[@ir.Condition] = []
  for value in values {
    for condition in value.conditions {
      conditions.push(condition)
    }
  }
  { conditions, }
}

///|
pub fn When::and_when(self : When, other : When) -> When {
  when_all([self, other])
}

///|
pub let always : When = when([])

///|
pub let hover : When = when([@ir.pseudo(Hover)])

///|
pub let focus : When = when([@ir.pseudo(Focus)])

///|
pub let focus_visible : When = when([@ir.pseudo(FocusVisible)])

///|
pub let focus_within : When = when([@ir.pseudo(FocusWithin)])

///|
pub let active : When = when([@ir.pseudo(Active)])

///|
pub let disabled : When = when([@ir.pseudo(Disabled)])

///|
pub let enabled : When = when([@ir.pseudo(Enabled)])

///|
pub let checked : When = when([@ir.pseudo(Checked)])

///|
pub let required : When = when([@ir.pseudo(Required)])

///|
pub let optional : When = when([@ir.pseudo(Optional)])

///|
pub let read_only : When = when([@ir.pseudo(ReadOnly)])

///|
pub let read_write : When = when([@ir.pseudo(ReadWrite)])

///|
pub let placeholder_shown : When = when([@ir.pseudo(PlaceholderShown)])

///|
pub let first_child : When = when([@ir.pseudo(FirstChild)])

///|
pub let last_child : When = when([@ir.pseudo(LastChild)])

///|
pub let only_child : When = when([@ir.pseudo(OnlyChild)])

///|
pub let empty : When = when([@ir.pseudo(Empty)])

///|
pub let link : When = when([@ir.pseudo(Link)])

///|
pub let visited : When = when([@ir.pseudo(Visited)])

///|
pub let before : When = when([@ir.pseudo_element(Before)])

///|
pub let after : When = when([@ir.pseudo_element(After)])

///|
pub let placeholder : When = when([@ir.pseudo_element(Placeholder)])

///|
pub let selection : When = when([@ir.pseudo_element(Selection)])

///|
pub let marker : When = when([@ir.pseudo_element(Marker)])

///|
pub let first_letter : When = when([@ir.pseudo_element(FirstLetter)])

///|
pub let first_line : When = when([@ir.pseudo_element(FirstLine)])

///|
pub fn media(query : @ir.MediaQuery) -> When {
  when([@ir.media(query)])
}

///|
pub fn min_width(value : @values.Length) -> When {
  media(@ir.media_query([@ir.media_feature("width", Min, value.to_css())]))
}

///|
pub fn max_width(value : @values.Length) -> When {
  media(@ir.media_query([@ir.media_feature("width", Max, value.to_css())]))
}

///|
pub fn width_between(
  minimum : @values.Length,
  maximum : @values.Length,
) -> When {
  media(
    @ir.media_query([
      @ir.media_feature("width", Min, minimum.to_css()),
      @ir.media_feature("width", Max, maximum.to_css()),
    ]),
  )
}

///|
fn PreferredColorScheme::to_css(self : PreferredColorScheme) -> String {
  match self {
    ColorSchemeLight => "light"
    ColorSchemeDark => "dark"
  }
}

///|
pub fn prefers_color_scheme(value : PreferredColorScheme) -> When {
  media(
    @ir.media_query([
      @ir.media_feature("prefers-color-scheme", Equal, value.to_css()),
    ]),
  )
}

///|
fn MotionPreference::to_css(self : MotionPreference) -> String {
  match self {
    MotionReduce => "reduce"
    MotionNoPreference => "no-preference"
  }
}

///|
pub fn prefers_reduced_motion(value : MotionPreference) -> When {
  media(
    @ir.media_query([
      @ir.media_feature("prefers-reduced-motion", Equal, value.to_css()),
    ]),
  )
}

///|
fn ViewportOrientation::to_css(self : ViewportOrientation) -> String {
  match self {
    OrientationPortrait => "portrait"
    OrientationLandscape => "landscape"
  }
}

///|
pub fn orientation(value : ViewportOrientation) -> When {
  media(
    @ir.media_query([@ir.media_feature("orientation", Equal, value.to_css())]),
  )
}

///|
pub fn supports(condition : @ir.SupportsCondition) -> When {
  when([@ir.supports(condition)])
}

///|
pub fn supports_property(property : String, value : String) -> When {
  supports(@ir.supports_declaration(property, value))
}

///|
pub fn layer(name : String) -> When {
  when([@ir.layer(name)])
}

///|
pub fn unsafe_pseudo(value : String) -> When {
  when([@ir.unsafe_pseudo(value)])
}

///|
pub fn unsafe_pseudo_element(value : String) -> When {
  when([@ir.unsafe_pseudo_element(value)])
}

///|
pub fn unsafe_at_rule(value : String) -> When {
  when([@ir.unsafe_at_rule(value)])
}

///|
pub(all) struct PropertyInput {
  css : String
  dynamic : Bool
  variable : @values.VariableUse?
  value_origin : @ir.DeclarationValueOrigin
  expression : @values.Expression?
}

///|
pub trait LengthInput {
  fn length_input(Self) -> PropertyInput
}

///|
pub trait ColorInput {
  fn color_input(Self) -> PropertyInput
}

///|
pub trait NumberInput {
  fn number_input(Self) -> PropertyInput
}

///|
pub trait PercentageInput {
  fn percentage_input(Self) -> PropertyInput
}

///|
pub trait LengthPercentageInput {
  fn length_percentage_input(Self) -> PropertyInput
}

///|
pub trait IntegerInput {
  fn integer_input(Self) -> PropertyInput
}

///|
pub trait TimeInput {
  fn time_input(Self) -> PropertyInput
}

///|
pub trait AngleInput {
  fn angle_input(Self) -> PropertyInput
}

///|
pub trait ResolutionInput {
  fn resolution_input(Self) -> PropertyInput
}

///|
pub trait UrlInput {
  fn url_input(Self) -> PropertyInput
}

///|
fn static_input(css : String) -> PropertyInput {
  {
    css,
    dynamic: false,
    variable: None,
    value_origin: @ir.LiteralOrigin([css]),
    expression: None,
  }
}

///|
fn contract_variable(value : @values.VariableUse) -> @ir.ContractVariable {
  @ir.contract_variable(value.definition.name, value.definition.category.name())
}

///|
fn[T] contract_token(value : @values.Token[T]) -> @ir.ContractVariable {
  contract_variable(value.variable_use())
}

///|
fn[T] contract_slot(value : @values.DynamicSlot[T]) -> @ir.ContractVariable {
  contract_variable(value.variable_use())
}

///|
fn[T] token_input(value : @values.Token[T]) -> PropertyInput {
  let variable = value.variable_use()
  {
    css: value.reference_css(),
    dynamic: false,
    variable: Some(variable),
    value_origin: @ir.TokenOrigin(contract_variable(variable)),
    expression: None,
  }
}

///|
fn[T] slot_input(value : @values.DynamicSlot[T]) -> PropertyInput {
  let variable = value.variable_use()
  {
    css: value.variable_name(),
    dynamic: true,
    variable: Some(variable),
    value_origin: @ir.DynamicSlotOrigin(contract_variable(variable)),
    expression: None,
  }
}

///|
pub impl LengthInput for @values.Length with fn length_input(self) {
  static_input(self.to_css())
}

///|
pub impl LengthInput for @values.Token[@values.Length] with fn length_input(
  self,
) {
  token_input(self)
}

///|
pub impl LengthInput for @values.DynamicSlot[@values.Length] with fn length_input(
  self,
) {
  slot_input(self)
}

///|
pub impl ColorInput for @values.Color with fn color_input(self) {
  static_input(self.to_css())
}

///|
pub impl ColorInput for @values.Token[@values.Color] with fn color_input(self) {
  token_input(self)
}

///|
pub impl ColorInput for @values.DynamicSlot[@values.Color] with fn color_input(
  self,
) {
  slot_input(self)
}

///|
pub impl NumberInput for @values.Number with fn number_input(self) {
  static_input(self.to_css())
}

///|
pub impl NumberInput for @values.Token[@values.Number] with fn number_input(
  self,
) {
  token_input(self)
}

///|
pub impl NumberInput for @values.DynamicSlot[@values.Number] with fn number_input(
  self,
) {
  slot_input(self)
}

///|
pub impl PercentageInput for @values.Percentage with fn percentage_input(self) {
  static_input(self.to_css())
}

///|
pub impl PercentageInput for @values.Token[@values.Percentage] with fn percentage_input(
  self,
) {
  token_input(self)
}

///|
pub impl PercentageInput for @values.DynamicSlot[@values.Percentage] with fn percentage_input(
  self,
) {
  slot_input(self)
}

///|
pub impl LengthPercentageInput for @values.LengthPercentage with fn length_percentage_input(
  self,
) {
  static_input(self.to_css())
}

///|
pub impl LengthPercentageInput for @values.Token[@values.LengthPercentage] with fn length_percentage_input(
  self,
) {
  token_input(self)
}

///|
pub impl LengthPercentageInput for @values.DynamicSlot[@values.LengthPercentage] with fn length_percentage_input(
  self,
) {
  slot_input(self)
}

///|
pub impl IntegerInput for @values.Integer with fn integer_input(self) {
  static_input(self.to_css())
}

///|
pub impl IntegerInput for @values.Token[@values.Integer] with fn integer_input(
  self,
) {
  token_input(self)
}

///|
pub impl IntegerInput for @values.DynamicSlot[@values.Integer] with fn integer_input(
  self,
) {
  slot_input(self)
}

///|
pub impl TimeInput for @values.Time with fn time_input(self) {
  static_input(self.to_css())
}

///|
pub impl TimeInput for @values.Token[@values.Time] with fn time_input(self) {
  token_input(self)
}

///|
pub impl TimeInput for @values.DynamicSlot[@values.Time] with fn time_input(
  self,
) {
  slot_input(self)
}

///|
pub impl AngleInput for @values.Angle with fn angle_input(self) {
  static_input(self.to_css())
}

///|
pub impl AngleInput for @values.Token[@values.Angle] with fn angle_input(self) {
  token_input(self)
}

///|
pub impl AngleInput for @values.DynamicSlot[@values.Angle] with fn angle_input(
  self,
) {
  slot_input(self)
}

///|
pub impl ResolutionInput for @values.Resolution with fn resolution_input(self) {
  static_input(self.to_css())
}

///|
pub impl ResolutionInput for @values.Token[@values.Resolution] with fn resolution_input(
  self,
) {
  token_input(self)
}

///|
pub impl ResolutionInput for @values.DynamicSlot[@values.Resolution] with fn resolution_input(
  self,
) {
  slot_input(self)
}

///|
pub impl UrlInput for @values.Url with fn url_input(self) {
  static_input(self.to_css())
}

///|
pub impl UrlInput for @values.Token[@values.Url] with fn url_input(self) {
  token_input(self)
}

///|
pub impl UrlInput for @values.DynamicSlot[@values.Url] with fn url_input(self) {
  slot_input(self)
}

///|
pub struct Rule {
  name : String
  declarations : Array[@ir.Declaration]
  variables : Array[@values.VariableUse]
}

///|
/// Resolves an explicitly supplied span first, then falls back to the compiler
/// callsite captured by `#callsite`. Keeping this in the builder means normal
/// MoonBit authoring receives actionable diagnostics without macros or a
/// separate source transform.
fn resolve_source_span(
  source : @ir.SourceSpan?,
  location : SourceLoc,
  symbol : String,
) -> @ir.SourceSpan? {
  match source {
    Some(value) => Some(value)
    None => {
      let value = @json.parse(location.to_json_string()) catch {
        _ => return None
      }
      guard value is Object(object) &&
        object.get("filename") is Some(String(file)) &&
        object.get("start_line") is Some(Number(start_line, ..)) &&
        object.get("start_column") is Some(Number(start_column, ..)) &&
        object.get("end_line") is Some(Number(end_line, ..)) &&
        object.get("end_column") is Some(Number(end_column, ..)) else {
        return None
      }
      Some(
        @ir.source_span(
          file,
          start_line.to_int(),
          start_column.to_int(),
          end_line=end_line.to_int(),
          end_column=end_column.to_int(),
          symbol~,
        ),
      )
    }
  }
}

///|
pub struct StyleContract {
  name : String
  properties : Array[@ir.ContractProperty]
}

///|
pub fn style_contract(name : String) -> StyleContract {
  { name, properties: [], }
}

///|
fn StyleContract::allow_property(
  self : StyleContract,
  property : String,
  values~ : Array[String] = [],
  tokens~ : Array[@ir.ContractVariable] = [],
  slots~ : Array[@ir.ContractVariable] = [],
  expressions~ : Array[String] = [],
) -> StyleContract {
  let properties = self.properties.copy()
  if values.is_empty() &&
    tokens.is_empty() &&
    slots.is_empty() &&
    expressions.is_empty() {
    properties.push(@ir.any_contract_property(property))
  } else {
    properties.push(
      @ir.exact_contract_property(
        property,
        values~,
        tokens~,
        slots~,
        expressions~,
      ),
    )
  }
  { name: self.name, properties, }
}

///|
pub fn StyleContract::to_ir(self : StyleContract) -> @ir.StyleContract {
  @ir.style_contract(self.name, self.properties)
}

///|
pub fn rule(name : String) -> Rule {
  { name, declarations: [], variables: [], }
}

///|
fn Rule::append_declaration(
  self : Rule,
  declaration : @ir.Declaration,
  variable~ : @values.VariableUse? = None,
) -> Rule {
  let declarations = self.declarations.copy()
  declarations.push(declaration)
  let variables = self.variables.copy()
  for condition in declaration.conditions {
    if condition is @ir.ContainerStyle(query) {
      for variable in query.variables() {
        variables.push(variable)
      }
    }
  }
  match variable {
    Some(value) => variables.push(value)
    None => ()
  }
  { name: self.name, declarations, variables, }
}

///|
fn Rule::append_input(
  self : Rule,
  property : String,
  input : PropertyInput,
  when_ : When,
  source : @ir.SourceSpan?,
  suffix : String,
  keyframe_allowed : Bool,
) -> Rule {
  let invalid_default = if property == "fontWidth" || property == "font-width" {
    match input.variable {
      Some(variable) =>
        if @values.property_value_issues(
            property,
            variable.definition.default_css,
          ).is_empty() {
          None
        } else {
          Some(variable.definition.default_css)
        }
      _ => None
    }
  } else {
    None
  }
  let value = if input.expression is Some(expression) {
    @ir.Expression(expression)
  } else if invalid_default is Some(css) {
    // Keep invalid defaults visible to the ordinary declaration diagnostics,
    // including when a rule is compiled without a registry.
    @ir.text(css)
  } else if input.dynamic {
    let category = match input.variable {
      Some(variable) => variable.definition.category.name()
      None => "string"
    }
    @ir.dynamic(input.css, suffix, category~)
  } else {
    @ir.text(input.css)
  }
  let next = self.append_declaration(
    @ir.declaration(
      property,
      value,
      conditions=when_.to_conditions(),
      source~,
      keyframe_allowed~,
      value_origin=Some(input.value_origin),
    ),
    variable=input.variable,
  )
  if input.expression is Some(expression) {
    for use_ in expression.variables() {
      next.variables.push(use_.variable)
    }
  }
  next
}

///|
fn Rule::append_fallbacks(
  self : Rule,
  property : String,
  values : Array[String],
  when_ : When,
  source : @ir.SourceSpan?,
) -> Rule {
  self.append_declaration(
    @ir.declaration(
      property,
      @ir.fallbacks(values),
      conditions=when_.to_conditions(),
      source~,
      keyframe_allowed=true,
      value_origin=Some(@ir.LiteralOrigin(values.copy())),
    ),
  )
}

///|
fn Rule::append_clear(
  self : Rule,
  property : String,
  source : @ir.SourceSpan?,
) -> Rule {
  self.append_declaration(
    @ir.declaration(
      property,
      @ir.clear_value(),
      source~,
      value_origin=Some(@ir.ClearOrigin),
    ),
  )
}

///|
fn[T : AnimationInput] Rule::append_animation(
  self : Rule,
  property : String,
  animation : T,
  when_ : When,
  source : @ir.SourceSpan?,
) -> Rule {
  let animation = animation.animation_input()
  let next = self.append_declaration(
    @ir.declaration(
      property,
      animation.value,
      conditions=when_.to_conditions(),
      source~,
    ),
  )
  let variables = next.variables.copy()
  for variable in animation.variables {
    variables.push(variable)
  }
  { name: next.name, declarations: next.declarations, variables, }
}

///|
#callsite(autofill(location))
pub fn Rule::unsafe_raw(
  self : Rule,
  property : String,
  value : String,
  when~ : When = always,
  source~ : @ir.SourceSpan? = None,
  location~ : SourceLoc,
) -> Rule {
  let source = resolve_source_span(source, location, property)
  self.append_declaration(
    @ir.declaration(
      property,
      @ir.text(value),
      conditions=when.to_conditions(),
      source~,
      unsafe_raw=true,
    ),
  )
}

///|
pub fn Rule::to_namespace(self : Rule) -> @ir.Namespace {
  @ir.style_namespace(self.name, self.declarations)
}

///|
pub fn Rule::variable_uses(self : Rule) -> Array[@values.VariableUse] {
  self.variables.copy()
}

///|
pub struct Frame {
  step : @ir.KeyframeStep
  rule : Rule
}

///|
pub fn frame(step : @ir.KeyframeStep) -> Frame {
  { step, rule: rule("keyframe"), }
}

///|
pub struct AnimationName {
  value : @ir.AnimationName
  variables : Array[@values.VariableUse]
}

///|
pub fn keyframes(name_hint : String, frames : Array[Frame]) -> AnimationName {
  let lowered : Array[@ir.KeyframeFrame] = []
  let variables : Array[@values.VariableUse] = []
  for value in frames {
    lowered.push(@ir.keyframe_frame(value.step, value.rule.declarations))
    for variable in value.rule.variables {
      variables.push(variable)
    }
  }
  { value: @ir.keyframes(name_hint, lowered), variables, }
}

///|
fn Frame::with_rule(self : Frame, next : Rule) -> Frame {
  { step: self.step, rule: next, }
}

///|
pub fn AnimationName::to_ir(self : AnimationName) -> @ir.AnimationName {
  self.value
}

///|
pub fn AnimationName::variable_uses(
  self : AnimationName,
) -> Array[@values.VariableUse] {
  self.variables.copy()
}

///|
pub struct Theme {
  name : String
  variables : Array[@values.VariableUse]
  overrides : Array[@values.VarOverride]
}

///|
pub fn theme(name : String, values : Array[@values.TokenOverride]) -> Theme {
  {
    name,
    variables: values.map(value => value.variable),
    overrides: values.map(value => value.override_),
  }
}

///|
pub fn Theme::name(self : Theme) -> String {
  self.name
}

///|
pub fn Theme::variable_uses(self : Theme) -> Array[@values.VariableUse] {
  self.variables.copy()
}

///|
pub fn Theme::overrides(self : Theme) -> Array[@values.VarOverride] {
  self.overrides.copy()
}
