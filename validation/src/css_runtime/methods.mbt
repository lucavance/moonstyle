// Expose trait methods on their owning public types.

///|
pub extend AppliedStyle with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AppliedStyle with Eq::{not_equal, equal}

///|
pub extend CompiledStyle with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CompiledStyle with Eq::{not_equal, equal}
