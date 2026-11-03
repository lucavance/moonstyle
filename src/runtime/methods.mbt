// Preserve the existing method surface explicitly with MoonBit 0.10.14.

///|
pub extend AppliedStyle with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AppliedStyle with Eq::{not_equal, equal}

///|
pub extend CompiledStyle with StaticStyleInput::{to_compiled}

///|
pub extend CompiledStyle with StyleInput::{append_to}

///|
pub extend DynamicValueError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DynamicValueError with Eq::{not_equal, equal}

///|
pub extend SelectorMarker with StaticStyleInput::{to_compiled}

///|
pub extend SelectorMarker with StyleInput::{append_to}

///|
pub extend StyleList with StyleInput::{append_to}
