// Expose trait methods on their owning public types.

///|
pub extend ContainerAxis with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ContainerAxis with Eq::{not_equal, equal}

///|
pub extend ContainerOperator with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ContainerOperator with Eq::{not_equal, equal}

///|
pub extend MarkerDefinition with MarkerInput::{marker_reference}

///|
pub extend MarkerSelector with MarkerInput::{marker_reference}

///|
pub extend MotionPreference with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MotionPreference with Eq::{not_equal, equal}

///|
pub extend PreferredColorScheme with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PreferredColorScheme with Eq::{not_equal, equal}

///|
pub extend ViewportOrientation with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ViewportOrientation with Eq::{not_equal, equal}
