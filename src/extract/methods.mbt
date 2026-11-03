// Preserve the existing method surface explicitly with MoonBit 0.10.14.

///|
pub extend BundleContract with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BundleContract with Eq::{not_equal, equal}

///|
pub extend BundleContractV6 with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BundleContractV6 with Eq::{not_equal, equal}

///|
pub extend BundleDependency with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BundleDependency with Eq::{not_equal, equal}

///|
pub extend BundleGlobal with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BundleGlobal with Eq::{not_equal, equal}

///|
pub extend BundleMarker with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BundleMarker with Eq::{not_equal, equal}

///|
pub extend BundleNamespace with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BundleNamespace with Eq::{not_equal, equal}

///|
pub extend BundleRecipe with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BundleRecipe with Eq::{not_equal, equal}

///|
pub extend BundleRule with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BundleRule with Eq::{not_equal, equal}

///|
pub extend BundleViewTransitionClass with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend BundleViewTransitionClass with Eq::{not_equal, equal}

///|
pub extend CompiledBundle with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CompiledBundle with Eq::{not_equal, equal}
