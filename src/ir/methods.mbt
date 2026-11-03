// Preserve the existing method surface explicitly with MoonBit 0.10.14.

///|
pub extend AnimationName with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AnimationName with Eq::{not_equal, equal}

///|
pub extend Condition with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Condition with Eq::{not_equal, equal}

///|
pub extend ContainerQuery with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ContainerQuery with Eq::{not_equal, equal}

///|
pub extend ContractProperty with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ContractProperty with Eq::{not_equal, equal}

///|
pub extend ContractValuePolicy with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ContractValuePolicy with Eq::{not_equal, equal}

///|
pub extend ContractVariable with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ContractVariable with Eq::{not_equal, equal}

///|
pub extend Declaration with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Declaration with Eq::{not_equal, equal}

///|
pub extend DeclarationValueOrigin with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DeclarationValueOrigin with Eq::{not_equal, equal}

///|
pub extend DependencyRef with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DependencyRef with Eq::{not_equal, equal}

///|
pub extend KeyframeDeclaration with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend KeyframeDeclaration with Eq::{not_equal, equal}

///|
pub extend KeyframeFrame with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend KeyframeFrame with Eq::{not_equal, equal}

///|
pub extend KeyframeStep with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend KeyframeStep with Eq::{not_equal, equal}

///|
pub extend Keyframes with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Keyframes with Eq::{not_equal, equal}

///|
pub extend MarkerDefinition with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MarkerDefinition with Eq::{not_equal, equal}

///|
pub extend MarkerRelation with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MarkerRelation with Eq::{not_equal, equal}

///|
pub extend MediaFeature with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MediaFeature with Eq::{not_equal, equal}

///|
pub extend MediaFeatureOperator with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MediaFeatureOperator with Eq::{not_equal, equal}

///|
pub extend MediaQuery with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MediaQuery with Eq::{not_equal, equal}

///|
pub extend MediaType with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MediaType with Eq::{not_equal, equal}

///|
pub extend Namespace with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Namespace with Eq::{not_equal, equal}

///|
pub extend PositionTryDefinition with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PositionTryDefinition with Eq::{not_equal, equal}

///|
pub extend PositionTryDescriptor with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PositionTryDescriptor with Eq::{not_equal, equal}

///|
pub extend PseudoClass with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PseudoClass with Eq::{not_equal, equal}

///|
pub extend PseudoElement with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PseudoElement with Eq::{not_equal, equal}

///|
pub extend Recipe with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Recipe with Eq::{not_equal, equal}

///|
pub extend RecipeCompound with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend RecipeCompound with Eq::{not_equal, equal}

///|
pub extend RecipeVariantAxis with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend RecipeVariantAxis with Eq::{not_equal, equal}

///|
pub extend RecipeVariantChoice with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend RecipeVariantChoice with Eq::{not_equal, equal}

///|
pub extend RecipeVariantMatch with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend RecipeVariantMatch with Eq::{not_equal, equal}

///|
pub extend Registry with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Registry with Eq::{not_equal, equal}

///|
pub extend SelectorMarkerRef with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SelectorMarkerRef with Eq::{not_equal, equal}

///|
pub extend SelectorState with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SelectorState with Eq::{not_equal, equal}

///|
pub extend SourceSpan with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SourceSpan with Eq::{not_equal, equal}

///|
pub extend StyleContract with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend StyleContract with Eq::{not_equal, equal}

///|
pub extend StyleSet with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend StyleSet with Eq::{not_equal, equal}

///|
pub extend StyleValue with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend StyleValue with Eq::{not_equal, equal}

///|
pub extend SupportsCondition with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SupportsCondition with Eq::{not_equal, equal}

///|
pub extend Theme with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Theme with Eq::{not_equal, equal}

///|
pub extend VariableSet with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend VariableSet with Eq::{not_equal, equal}

///|
pub extend ViewTransitionClassDefinition with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend ViewTransitionClassDefinition with Eq::{not_equal, equal}

///|
pub extend ViewTransitionStyle with Eq::{not_equal, equal}

///|
pub extend ViewTransitionStyle with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AttributeOperator with Eq::{equal, not_equal}

///|
pub extend AttributeOperator with @debug.Debug::{to_repr}

///|
pub extend AttributeCase with Eq::{equal, not_equal}

///|
pub extend AttributeCase with @debug.Debug::{to_repr}

///|
pub extend AttributeSelector with Eq::{equal, not_equal}

///|
pub extend AttributeSelector with @debug.Debug::{to_repr}
