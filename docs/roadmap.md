# Research backlog

The current functional scope is implemented. Delivery gates are tracked in
[current status](current-status.md) and [CI and validation](ci-and-validation.md).
This backlog assigns no delivery date.

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
This backlog does not change the current release gates.
