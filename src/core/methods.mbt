// Expose trait methods on their owning public types.

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
