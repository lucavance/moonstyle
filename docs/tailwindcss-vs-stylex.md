# Styling-system tradeoffs for MoonBit

MoonStyle follows the structured compiler and composition model associated with
StyleX. It delivers that model as a normal MoonBit module with explicit native
extraction; a compiler plugin is not required. See
[architecture](architecture.md) for the implemented package boundaries.

## Utility classes and typed declarations

| Need | Tailwind CSS and optional helpers | MoonStyle |
| --- | --- | --- |
| Authoring | Complete class-name strings in markup | Typed property/value declarations in MoonBit registries |
| Conditional styles | Language conditionals; optional class-name helper | `compose`, `when`, `add` |
| Overrides | Component conventions or a utility-aware merge helper | Compiled application-order slots and conflict tombstones |
| Variants | Component props; optional CVA or tailwind-variants | Typed recipe axes, defaults, boolean variants and compounds |
| Type checking | MoonBit sees ordinary strings | Property/value categories and nominal component contracts |
| Design scales | Preset utilities and theme scales | Typed Tokens/themes; applications define or integrate scales |
| Build | Discover complete utility names in source | Compile explicit registries; commit mappings/CSS/component bundles |
| Runtime | Ordinary utilities apply directly as CSS | Compose compiled classes and bind validated custom properties |

Tailwind does not require `clsx`, `cn`, a merging library or a variant library.
They address distinct needs and a helper named `cn` has no universal behavior.
Class-token order alone does not define general last-applied-wins behavior.
Source detection needs complete finite names rather than arbitrary expressions
such as `"bg-" + color`.

MoonStyle handles class composition, checked dynamic inputs and variants with a
shared typed model. Exact generated component traits constrain what callers
may override across package boundaries. This does not merge arbitrary Tailwind
strings or promise equivalence to utility-merging algorithms. A later base
declaration can replace an earlier conditional declaration for the same slot;
see [application order](application-order-semantics.md).

Registries, native extraction and regenerated artifacts add concepts and upgrade
work. MoonStyle 0.2.0 does not supply a complete
preset design scale, and currently supports Rabbita as its only Tier-1 framework.
Luna is experimental; React authoring is outside the product boundary. Recipes
cover single-style variants rather than a first-class multi-part slot recipe.
Typed APIs deliberately expose reviewed subsets; `unsafe_raw` guarantees only
serialization, without value validation or typed conflict/RTL guarantees.

Responsive styling, state selectors, themes and atomic CSS are shared
capabilities. Removing helper dependencies alone proves neither smaller output
nor faster execution; comparisons require equivalent workloads and measurements.

## Relationship to StyleX

StyleX is the pinned test-only oracle for the documented semantic subset.
MoonStyle adopts atomic extraction, application-order composition and selected
condition priorities. It adds a MoonBit-native value model, exact nominal
component policies and source-distributed bundles. It does not expose JS/TS/JSX,
React or drop-in `@stylexjs/stylex`/atoms authoring APIs.

The core preserves native logical CSS and a documented local font alias. Public
names, general class hashes, unsupported properties, upstream parser transforms,
DevTools and bundler plugins are not blanket compatibility commitments.
[API stability](api-stability.md) defines the supported boundary;
[oracle maintenance](../tools/stylex-oracle/README.md) defines verification.

The practical choice depends on the application: utility syntax, existing scales
and components can reduce adoption work, while typed declarations and exact
cross-package override contracts address MoonBit compiler and library needs.
The [quickstart](quickstart.md) demonstrates the actual MoonStyle workflow, and
the [research backlog](roadmap.md) records possible future authoring extensions.
