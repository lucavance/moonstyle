// Preserve the existing method surface explicitly with MoonBit 0.10.14.

///|
pub extend AppliedStyle with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AppliedStyle with Eq::{not_equal, equal}

///|
pub extend CompiledStyle with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CompiledStyle with Eq::{not_equal, equal}
