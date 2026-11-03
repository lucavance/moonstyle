///|
pub using @runtime {
  type AppliedStyle,
  type CompiledStyle,
  type DynamicValueError,
  type SelectorMarker,
  type StyleList,
  type StyleResult,
  trait StaticStyleInput,
  trait StyleInput,
  checked_when,
  compose,
  expect_dynamic,
  none,
  props,
  props_checked,
  style_list,
}

///|
#deprecated("Use compose(input) for a non-empty composition or style_list() for an empty composition")
pub fn[T : @runtime.StyleInput] styles(
  initial : Array[T],
) -> @runtime.StyleList {
  @runtime.compose(initial)
}

///|
pub using @ir {
  type Condition,
  type DependencyRef,
  type KeyframeStep,
  type MediaFeature,
  type MediaFeatureOperator,
  type MediaQuery,
  type MediaType,
  type PseudoClass,
  type PseudoElement,
  type Registry,
  type SourceSpan,
  type SupportsCondition,
}

///|
pub using @builder {
  type AnimationName,
  type ContainerAxis,
  type ContainerFeature,
  type ContainerName,
  type ContainerOperator,
  type Frame,
  type MotionPreference,
  type MarkerDefinition,
  trait MarkerInput,
  type MarkerSelector,
  type PreferredColorScheme,
  type PositionTryRule,
  type Recipe,
  type Rule,
  type StyleContract,
  type Theme,
  type ViewportOrientation,
  type ViewTransitionClassDefinition,
  type VariantChoice,
  type VariantSelection,
  type When,
  active,
  after,
  always,
  before,
  boolean_variant_is,
  container_feature,
  container_max_width,
  container_min_width,
  container_name,
  container_query,
  container_width_between,
  checked,
  disabled,
  define_marker,
  define_view_transition_class,
  empty,
  enabled,
  first_child,
  first_letter,
  first_line,
  focus,
  focus_visible,
  focus_within,
  frame,
  hover,
  keyframes,
  last_child,
  layer,
  link,
  marker,
  marker_ancestor,
  marker_any_sibling,
  marker_descendant,
  marker_sibling_after,
  marker_sibling_before,
  max_width,
  media,
  min_width,
  only_child,
  optional,
  orientation,
  placeholder,
  placeholder_shown,
  position_try_rule,
  prefers_color_scheme,
  prefers_reduced_motion,
  read_only,
  read_write,
  recipe,
  recipe_rule,
  required,
  rule,
  selection,
  selector_attribute,
  selector_attribute_equals,
  selector_pseudo,
  style_contract,
  supports,
  supports_property,
  theme,
  unsafe_at_rule,
  unsafe_pseudo,
  unsafe_pseudo_element,
  visited,
  variant_choice,
  variant_is,
  when,
  when_all,
  width_between,
}

///|
pub using @values {
  type Angle,
  type AngleSlot,
  type AngleToken,
  type BackgroundSize,
  type BackgroundSizeList,
  type BoxShadowList,
  type BorderColors,
  type BorderSide,
  type BorderStyles,
  type BorderWidths,
  type Color,
  type ColorSlot,
  type ColorToken,
  type Contain,
  type ContainPart,
  type ContainerNames,
  type ContentValue,
  type CornerRadius,
  type DynamicSlot,
  type EasingFunction,
  type FilterFunction,
  type FilterList,
  type FontVariantNumeric,
  type FontVariantNumericPart,
  type GridLine,
  type GridTrack,
  type GridTrackList,
  type GridTemplateAreas,
  type Integer,
  type IntegerSlot,
  type IntegerToken,
  type Length,
  type LengthPercentage,
  type LengthPercentageSlot,
  type LengthPercentageToken,
  type LengthSlot,
  type LengthToken,
  type LengthUnit,
  type LineStyle,
  type LineWidth,
  type LineWidthKeyword,
  type MaskImage,
  type MaskImageList,
  type Number,
  type NumberSlot,
  type NumberToken,
  type Outline,
  type OutlineColor,
  type OutlineStyle,
  type PageValue,
  page_auto,
  page_name,
  type Percentage,
  type PercentageSlot,
  type PercentageToken,
  type Position,
  type PositionAnchor,
  type PositionArea,
  type PositionAreaHorizontal,
  type PositionAreaVertical,
  type PositionList,
  type PositionTryFallback,
  type PositionTryFallbacks,
  type PositionTryOrder,
  type PositionTryTactic,
  type PositionTryValue,
  type Ratio,
  type RepeatStyle,
  type RepeatStyleList,
  type Resolution,
  type ResolutionSlot,
  type ResolutionToken,
  type Time,
  type TimeSlot,
  type TimeToken,
  type TextShadowList,
  type Token,
  type TokenOverride,
  type TouchAction,
  type TouchActionPart,
  type TransformFunction,
  type TransformList,
  type TransformOrigin,
  type Url,
  type UrlSlot,
  type UrlToken,
  type VariableScope,
  type VariableUse,
  type ViewTransitionClass,
  type ViewTransitionName,
  type AnchorName,
  type AnchorNames,
  type ClipPath,
  type Shadow,
  angle_slot,
  angle_token,
  auto,
  background_contain,
  background_cover,
  background_size,
  border_colors,
  border_styles,
  border_widths,
  color_slot,
  color_token,
  contain_none,
  contain_strict,
  ease,
  font_variant_numeric_normal,
  grid_auto,
  integer,
  integer_slot,
  integer_token,
  length_percentage_from_length,
  length_percentage_from_percentage,
  length_percentage_slot,
  length_percentage_token,
  length_slot,
  length_token,
  line_width_keyword,
  linear_easing,
  minmax,
  ms,
  number_slot,
  number_token,
  outline_auto_color,
  outline_color_from_color,
  percent,
  percentage_slot,
  percentage_token,
  position,
  position_center,
  px,
  ratio_auto,
  resolution_slot,
  resolution_token,
  rotate_transform,
  time_slot,
  time_token,
  touch_auto,
  touch_none,
  track_length,
  transform_none,
  transform_origin,
  transparent,
  translate,
  url_slot,
  url_token,
  variable_scope,
  vh,
  vw,
  zero,
}

///|
pub fn length(value : Double, unit : LengthUnit) -> Length {
  @values.authored_length(value, unit)
}

///|
pub fn rem(value : Double) -> Length {
  @values.authored_rem(value)
}

///|
pub fn em(value : Double) -> Length {
  @values.authored_em(value)
}

///|
pub fn ch(value : Double) -> Length {
  @values.authored_ch(value)
}

///|
pub fn vmin(value : Double) -> Length {
  @values.authored_vmin(value)
}

///|
pub fn vmax(value : Double) -> Length {
  @values.authored_vmax(value)
}

///|
pub fn svh(value : Double) -> Length {
  @values.authored_svh(value)
}

///|
pub fn lvh(value : Double) -> Length {
  @values.authored_lvh(value)
}

///|
pub fn dvh(value : Double) -> Length {
  @values.authored_dvh(value)
}

///|
pub fn rgb(red : Int32, green : Int32, blue : Int32) -> Color {
  @values.authored_rgb(red, green, blue)
}

///|
pub fn rgba(red : Int32, green : Int32, blue : Int32, alpha : Double) -> Color {
  @values.authored_rgba(red, green, blue, alpha)
}

///|
pub fn hex_color(value : String) -> Color {
  @values.authored_hex_color(value)
}

///|
pub fn hsl(hue : Double, saturation : Double, lightness : Double) -> Color {
  @values.authored_hsl(hue, saturation, lightness)
}

///|
pub fn seconds(value : Double) -> Time {
  @values.authored_seconds(value)
}

///|
pub fn deg(value : Double) -> Angle {
  @values.authored_deg(value)
}

///|
pub fn turn(value : Double) -> Angle {
  @values.authored_turn(value)
}

///|
pub fn percentage(value : Double) -> Percentage {
  @values.authored_percentage(value)
}

///|
pub fn number(value : Double) -> Number {
  @values.authored_number(value)
}

///|
pub fn dpi(value : Double) -> Resolution {
  @values.authored_dpi(value)
}

///|
pub fn dppx(value : Double) -> Resolution {
  @values.authored_dppx(value)
}

///|
pub fn url(value : String) -> Url {
  @values.authored_url(value)
}

///|
pub fn ratio(width : Int32, height : Int32) -> Ratio {
  @values.authored_ratio(width, height)
}

///|
pub fn scale_transform(x : Double, y~ : Double? = None) -> TransformFunction {
  @values.authored_scale_transform(x, y~)
}

///|
pub fn transform_list(functions : Array[TransformFunction]) -> TransformList {
  @values.authored_transform_list(functions)
}

///|
pub fn cubic_bezier(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> EasingFunction {
  @values.authored_cubic_bezier(x1, y1, x2, y2)
}

///|
pub fn steps(count : Int32, at_start~ : Bool = false) -> EasingFunction {
  @values.authored_steps(count, at_start~)
}

///|
pub fn fr(value : Double) -> GridTrack {
  @values.authored_fr(value)
}

///|
pub fn grid_tracks(tracks : Array[GridTrack]) -> GridTrackList {
  @values.authored_grid_tracks(tracks)
}

///|
pub fn repeat_tracks(count : Int32, tracks : GridTrackList) -> GridTrack {
  @values.authored_repeat_tracks(count, tracks)
}

///|
pub fn grid_line(value : Int32) -> GridLine {
  @values.authored_grid_line(value)
}

///|
pub fn grid_span(value : Int32) -> GridLine {
  @values.authored_grid_span(value)
}

///|
pub fn named_grid_line(value : String) -> GridLine {
  @values.authored_named_grid_line(value)
}

///|
pub fn touch_action(parts : Array[TouchActionPart]) -> TouchAction {
  @values.authored_touch_action(parts)
}

///|
pub fn contain(parts : Array[ContainPart]) -> Contain {
  @values.authored_contain(parts)
}

///|
pub fn font_variant_numeric(
  parts : Array[FontVariantNumericPart],
) -> FontVariantNumeric {
  @values.authored_font_variant_numeric(parts)
}

///|
pub fn line_width_from_length(value : Length) -> LineWidth {
  @values.authored_line_width_from_length(value)
}

///|
pub fn border_side(
  width~ : LineWidth? = None,
  style~ : LineStyle? = None,
  color~ : Color? = None,
) -> BorderSide {
  @values.authored_border_side(width~, style~, color~)
}

///|
pub fn outline(
  width~ : LineWidth? = None,
  style~ : OutlineStyle? = None,
  color~ : OutlineColor? = None,
) -> Outline {
  @values.authored_outline(width~, style~, color~)
}

///|
pub fn filters(values : Array[FilterFunction]) -> FilterList {
  @values.authored_filter_list(values)
}

///|
pub fn box_shadows(values : Array[Shadow]) -> BoxShadowList {
  @values.authored_box_shadows(values)
}

///|
pub fn text_shadows(values : Array[Shadow]) -> TextShadowList {
  @values.authored_text_shadows(values)
}

///|
pub fn grid_template_areas(rows : Array[Array[String]]) -> GridTemplateAreas {
  @values.authored_grid_template_areas(rows)
}

///|
pub fn container_names(values : Array[String]) -> ContainerNames {
  @values.authored_container_names(values)
}

///|
pub fn mask_image_url(value : Url) -> MaskImage {
  @values.authored_mask_image_url(value)
}

///|
pub fn mask_images(values : Array[MaskImage]) -> MaskImageList {
  @values.authored_mask_images(values)
}

///|
pub fn positions(values : Array[Position]) -> PositionList {
  @values.authored_positions(values)
}

///|
pub fn repeat_styles(values : Array[RepeatStyle]) -> RepeatStyleList {
  @values.authored_repeat_styles(values)
}

///|
pub fn background_sizes(values : Array[BackgroundSize]) -> BackgroundSizeList {
  @values.authored_background_sizes(values)
}

///|
pub fn clip_path_circle(
  radius : LengthPercentage,
  center~ : Position? = None,
) -> ClipPath {
  @values.authored_clip_path_circle(radius, center~)
}

///|
pub fn clip_path_url(value : Url) -> ClipPath {
  @values.authored_clip_path_url(value)
}

///|
pub fn content_text(value : String) -> ContentValue {
  @values.authored_content_text(value)
}

///|
pub fn content_none() -> ContentValue {
  @values.authored_content_none()
}

///|
pub fn anchor_name(value : String) -> AnchorName {
  @values.authored_anchor_name(value)
}

///|
pub fn anchor_names(values : Array[AnchorName]) -> AnchorNames {
  @values.authored_anchor_names(values)
}

///|
pub fn position_anchor(value : AnchorName) -> PositionAnchor {
  @values.authored_position_anchor(value)
}

///|
pub fn position_area(
  horizontal : PositionAreaHorizontal,
  vertical : PositionAreaVertical,
) -> PositionArea {
  @values.authored_position_area(horizontal, vertical)
}

///|
pub fn position_try_named(value : String) -> PositionTryFallback {
  @values.authored_position_try_named(value)
}

///|
pub fn position_try_area(value : PositionArea) -> PositionTryFallback {
  @values.authored_position_try_area(value)
}

///|
pub fn position_try_tactic(value : PositionTryTactic) -> PositionTryFallback {
  @values.authored_position_try_tactic(value)
}

///|
pub fn position_try_fallbacks(
  values : Array[PositionTryFallback],
) -> PositionTryFallbacks {
  @values.authored_position_try_fallbacks(values)
}

///|
pub fn position_try_value(
  fallbacks : PositionTryFallbacks,
  order~ : PositionTryOrder? = None,
) -> PositionTryValue {
  @values.authored_position_try_value(fallbacks, order~)
}

///|
pub fn view_transition_name(value : String) -> ViewTransitionName {
  @values.authored_view_transition_name(value)
}

///|
pub fn view_transition_class(value : String) -> ViewTransitionClass {
  @values.authored_view_transition_class(value)
}

///|
pub fn media_feature(
  name : String,
  operator : MediaFeatureOperator,
  value : String,
) -> MediaFeature {
  @ir.media_feature(name, operator, value)
}

///|
pub fn media_query(
  features : Array[MediaFeature],
  negated~ : Bool = false,
  media_type~ : MediaType? = None,
) -> MediaQuery {
  @ir.media_query(features, negated~, media_type~)
}

///|
pub fn supports_declaration(
  property : String,
  value : String,
) -> SupportsCondition {
  @ir.supports_declaration(property, value)
}

///|
pub fn supports_not(condition : SupportsCondition) -> SupportsCondition {
  @ir.supports_not(condition)
}

///|
pub fn supports_all(conditions : Array[SupportsCondition]) -> SupportsCondition {
  @ir.supports_all(conditions)
}

///|
pub fn supports_any(conditions : Array[SupportsCondition]) -> SupportsCondition {
  @ir.supports_any(conditions)
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
  @ir.source_span(file, line, column, end_line~, end_column~, symbol~)
}

///|
pub fn dependency_ref(
  module_name : String,
  semantic_digest : String,
) -> DependencyRef {
  @ir.dependency_ref(module_name, semantic_digest)
}

///|
pub struct StyleSheet {
  export_name : String
  rules : Array[Rule]
}

///|
pub fn sheet(export_name : String, rules : Array[Rule]) -> StyleSheet {
  { export_name, rules: rules.copy(), }
}

///|
pub struct RegistryBuilder {
  module_name : String
  sheets : Array[StyleSheet]
  contracts : Array[StyleContract]
  themes : Array[Theme]
  recipes : Array[Recipe]
  markers : Array[MarkerDefinition]
  position_tries : Array[PositionTryRule]
  view_transition_classes : Array[ViewTransitionClassDefinition]
  dependencies : Array[DependencyRef]
  extra_tokens : Array[@values.VariableUse]
}

///|
pub fn registry_builder(module_name : String) -> RegistryBuilder {
  {
    module_name,
    sheets: [],
    contracts: [],
    themes: [],
    recipes: [],
    markers: [],
    position_tries: [],
    view_transition_classes: [],
    dependencies: [],
    extra_tokens: [],
  }
}

///|
pub fn RegistryBuilder::rules(
  self : RegistryBuilder,
  rules : Array[Rule],
  export_name~ : String = "styles",
) -> RegistryBuilder {
  let sheets = self.sheets.copy()
  match sheets.search_by(value => value.export_name == export_name) {
    Some(index) => {
      let merged = sheets[index].rules.copy()
      for rule in rules {
        merged.push(rule)
      }
      sheets[index] = sheet(export_name, merged)
    }
    None => sheets.push(sheet(export_name, rules))
  }
  { ..self, sheets, }
}

///|
pub fn RegistryBuilder::contract(
  self : RegistryBuilder,
  value : StyleContract,
) -> RegistryBuilder {
  let contracts = self.contracts.copy()
  contracts.push(value)
  { ..self, contracts, }
}

///|
pub fn RegistryBuilder::theme(
  self : RegistryBuilder,
  value : Theme,
) -> RegistryBuilder {
  let themes = self.themes.copy()
  themes.push(value)
  { ..self, themes, }
}

///|
pub fn RegistryBuilder::recipe(
  self : RegistryBuilder,
  value : Recipe,
) -> RegistryBuilder {
  let recipes = self.recipes.copy()
  recipes.push(value)
  { ..self, recipes, }
}

///|
pub fn RegistryBuilder::marker(
  self : RegistryBuilder,
  value : MarkerDefinition,
) -> RegistryBuilder {
  let markers = self.markers.copy()
  markers.push(value)
  { ..self, markers, }
}

///|
pub fn RegistryBuilder::position_try(
  self : RegistryBuilder,
  value : PositionTryRule,
) -> RegistryBuilder {
  let position_tries = self.position_tries.copy()
  position_tries.push(value)
  { ..self, position_tries, }
}

///|
pub fn RegistryBuilder::view_transition_class(
  self : RegistryBuilder,
  value : ViewTransitionClassDefinition,
) -> RegistryBuilder {
  let view_transition_classes = self.view_transition_classes.copy()
  view_transition_classes.push(value)
  { ..self, view_transition_classes, }
}

///|
pub fn RegistryBuilder::dependency(
  self : RegistryBuilder,
  value : DependencyRef,
) -> RegistryBuilder {
  let dependencies = self.dependencies.copy()
  dependencies.push(value)
  { ..self, dependencies, }
}

///|
pub fn RegistryBuilder::extra_token(
  self : RegistryBuilder,
  value : @values.VariableUse,
) -> RegistryBuilder {
  let extra_tokens = self.extra_tokens.copy()
  extra_tokens.push(value)
  { ..self, extra_tokens, }
}

///|
pub fn RegistryBuilder::build(self : RegistryBuilder) -> Registry {
  registry_sheets(
    self.module_name,
    self.sheets,
    contracts=self.contracts,
    themes=self.themes,
    recipes=self.recipes,
    markers=self.markers,
    position_tries=self.position_tries,
    view_transition_classes=self.view_transition_classes,
    dependencies=self.dependencies,
    extra_tokens=self.extra_tokens,
  )
}

///|
fn add_variable_use(
  variables : Array[@values.VariableUse],
  candidate : @values.VariableUse,
) -> Unit {
  match
    variables.search_by(value => {
      value.definition.name == candidate.definition.name &&
      value.scope == candidate.scope &&
      value.local_name == candidate.local_name &&
      value.role == candidate.role &&
      value.definition.default_css == candidate.definition.default_css &&
      value.definition.category == candidate.definition.category
    }) {
    Some(_) => ()
    None => variables.push(candidate)
  }
}

///|
fn collect_variables(
  sheets : Array[StyleSheet],
  themes : Array[Theme],
  extra_tokens : Array[@values.VariableUse],
) -> Array[@values.VariableUse] {
  let variables : Array[@values.VariableUse] = []
  for style_sheet in sheets {
    for authored_rule in style_sheet.rules {
      for variable in authored_rule.variable_uses() {
        add_variable_use(variables, variable)
      }
    }
  }
  for authored_theme in themes {
    for variable in authored_theme.variable_uses() {
      add_variable_use(variables, variable)
    }
  }
  for variable in extra_tokens {
    add_variable_use(variables, variable)
  }
  variables
}

///|
fn lower_variable_sets(
  variables : Array[@values.VariableUse],
) -> Array[@ir.VariableSet] {
  let scopes : Array[String] = []
  let owners : Map[String, String] = Map([])
  for variable in variables {
    if !owners.contains(variable.definition.name) {
      owners[variable.definition.name] = variable.scope
    }
    if !scopes.contains(variable.scope) {
      scopes.push(variable.scope)
    }
  }
  scopes.map(scope => {
    @ir.define_vars(
      scope,
      variables
      // Colliding scope/name pairs must reach the same duplicate check.
      .filter(variable => owners.get(variable.definition.name) == Some(scope))
      .map(variable => variable.definition),
    )
  })
}

///|
fn lower_themes(
  themes : Array[Theme],
  variable_sets : Array[@ir.VariableSet],
) -> Array[@ir.Theme] {
  themes.map(authored_theme => {
    let uses = authored_theme.variable_uses()
    let scope = if uses.is_empty() { "invalid-theme" } else { uses[0].scope }
    let base = match variable_sets.search_by(value => value.scope == scope) {
      Some(index) => variable_sets[index]
      None => @ir.define_vars(scope, [])
    }
    @ir.create_theme(authored_theme.name(), base, authored_theme.overrides())
  })
}

///|
pub fn registry_sheets(
  module_name : String,
  sheets : Array[StyleSheet],
  contracts~ : Array[StyleContract] = [],
  themes~ : Array[Theme] = [],
  recipes~ : Array[Recipe] = [],
  markers~ : Array[MarkerDefinition] = [],
  position_tries~ : Array[PositionTryRule] = [],
  view_transition_classes~ : Array[ViewTransitionClassDefinition] = [],
  dependencies~ : Array[DependencyRef] = [],
  extra_tokens~ : Array[@values.VariableUse] = [],
) -> Registry {
  let recipe_rules : Array[Rule] = []
  for authored_recipe in recipes {
    for authored_rule in authored_recipe.rules() {
      recipe_rules.push(authored_rule)
    }
  }
  let all_sheets = sheets.copy()
  if !recipe_rules.is_empty() {
    all_sheets.push(sheet("recipes", recipe_rules))
  }
  let variables = collect_variables(all_sheets, themes, extra_tokens)
  for transition in view_transition_classes {
    for variable in transition.variable_uses() {
      add_variable_use(variables, variable)
    }
  }
  let variable_sets = lower_variable_sets(variables)
  @ir.registry(
    module_name,
    all_sheets.map(style_sheet => {
      @ir.style_set(
        style_sheet.export_name,
        style_sheet.rules.map(authored_rule => authored_rule.to_namespace()),
      )
    }),
    contracts=contracts.map(contract => contract.to_ir()),
    variable_sets~,
    themes=lower_themes(themes, variable_sets),
    recipes=recipes.map(authored_recipe => authored_recipe.to_ir()),
    markers=markers.map(authored_marker => authored_marker.to_ir()),
    position_tries=position_tries.map(authored_try => authored_try.to_ir()),
    view_transition_classes=view_transition_classes.map(value => value.to_ir()),
    direct_dependencies=dependencies,
  )
}

///|
pub fn registry(
  module_name : String,
  rules : Array[Rule],
  export_name~ : String = "styles",
  contracts~ : Array[StyleContract] = [],
  themes~ : Array[Theme] = [],
  recipes~ : Array[Recipe] = [],
  markers~ : Array[MarkerDefinition] = [],
  position_tries~ : Array[PositionTryRule] = [],
  view_transition_classes~ : Array[ViewTransitionClassDefinition] = [],
  dependencies~ : Array[DependencyRef] = [],
  extra_tokens~ : Array[@values.VariableUse] = [],
) -> Registry {
  registry_sheets(
    module_name,
    [sheet(export_name, rules)],
    contracts~,
    themes~,
    recipes~,
    markers~,
    position_tries~,
    view_transition_classes~,
    dependencies~,
    extra_tokens~,
  )
}
