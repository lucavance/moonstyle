// Preserve the existing method surface explicitly with MoonBit 0.10.14.

///|
pub extend AtomicRule with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AtomicRule with Eq::{not_equal, equal}

///|
pub extend CompiledNamespace with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CompiledNamespace with Eq::{not_equal, equal}

///|
pub extend CompiledStyleSet with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CompiledStyleSet with Eq::{not_equal, equal}

///|
pub extend Diagnostic with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Diagnostic with Eq::{not_equal, equal}

///|
pub extend DiagnosticContext with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DiagnosticContext with Eq::{not_equal, equal}

///|
pub extend DiagnosticSeverity with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DiagnosticSeverity with Eq::{not_equal, equal}

///|
pub extend GlobalRule with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend GlobalRule with Eq::{not_equal, equal}
