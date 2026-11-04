# Development roadmap

Prioritize MoonBit users' daily work: ease of use, correctness and reliable
builds. The [compatibility matrix](stylex-compatibility.md) separates upstream
concepts from implemented subsets. These milestones assign no release date.

## 0.2.0 delivered capabilities

- Maintain a source-backed compatibility matrix and review relevant upstream
  main fixes without changing the pinned 0.19.1 release oracle implicitly.
- Add six reviewed CSS properties: isolation, vertical alignment, white-space,
  text wrapping, will-change hints and variable-font axes. Preserve ordered
  fallbacks, Clear, typed conditions and exact component contracts.
- Provide explicit Color/Length/Number Token and Slot registration with
  inheritance control, independent initial values, canonical artifact records
  and cross-module collision checks. Keep unregistered variables unchanged.
- Exercise authoring, invalid input, artifact regeneration and consumption in
  repository examples and tests. Browser acceptance covers computed values,
  registration inheritance, invalid-value fallback and interpolation.
- Align interfaces, API baseline, artifact v14, property metadata v18, source
  versions and measured release reports. Apply the existing validation gates
  to each release; [current status](current-status.md) records implemented and
  published versions.

## Next: themes and measured build quality

Conditional defaults and overrides are the first theme priority: typed
media/supports/container branches with explicit deterministic ordering. Follow
with derived Token defaults and theme expressions, preserving variable identity
and checking categories, missing dependencies and cycles. Neither capability is
implemented by literal `with_value` or CSS `@property` registration.

Acceptance requires a shared component/application theme example, tests for
nested conditions and dependency cycles, leaf-first regeneration, four backends
and three browsers. Design the IR and artifact migration together before
adding a parallel authoring path or widening `CssValue` to arbitrary strings.

Profile deduplication, sorting and invalidation before optimization. Existing
performance gates already measure 100, 6,000 and 10,000-rule workloads. Add theme
and dependency-fanout workloads to distinguish extraction CPU time from process
startup and cache lookup. Change data structures or thresholds only with
equivalent-output tests and paired measurements showing an improvement.

## Later evaluation

Evaluate unused-token elimination and explicit global layer ordering after the
theme dependency graph is reliable. Both need cross-module and dynamic-value
evidence; per-declaration layers already exist. Additional CSS grammars and
registration categories need reviewed value types and browser acceptance.
React, JSX/TSX and atoms remain outside the authoring target. Rabbita remains
Tier-1; Luna remains experimental until a separate support decision.

## Related styling systems

Research topics:

| Reference | Areas to evaluate |
| --- | --- |
| StyleX | Composition, cross-component overrides, typed style props |
| Panda CSS | Design tokens, multi-part slot recipes, layout helpers |
| vanilla-extract, Sprinkles, Recipes | Reusable typed style modules and optional authoring extensions |

Compare each idea against concrete MoonBit tasks: a token-based button with
size/intent/disabled variants, a multi-part card, or a theme shared across
component packages. Determine whether existing values, recipes, contracts, and
ordinary MoonBit helpers already solve the problem.

Any proposal must record the actual gap, user benefit, a MoonBit API sketch,
effects on extraction/runtime/package boundaries, maintenance cost, and
schema or migration implications. Output-size or performance claims require
equivalent workloads and measurements. Recommend adopt, adapt, defer, or reject.

An accepted proposal needs separate scope, acceptance criteria, and tests. It
must preserve MoonBit-only authoring, the single Rule/IR extraction path,
framework-neutral core/runtime, and the [support policy](api-stability.md).
This roadmap does not relax the current release gates.
