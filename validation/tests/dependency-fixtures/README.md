# Synthetic dependency fixtures

The two JSON bundles are deliberately hand-authored test inputs. Their fixed
`dep-a` and `dep-b` classes make cross-module merging and browser assertions
readable. Component B intentionally puts three border declarations in one
`borderStyle` record; it is not presented as native compiler output.

When refreshing the semantic identity, retain CSS/class records
only after checking their slots, tombstones, and priorities against the pinned
oracle. The fixture semantic identity, canonical bundle digests, and component
B's references to component A are then refreshed together.

Run `moon run tools/refresh-fixtures.mbtx -- --write` to refresh, or omit
`--write` to verify. The script also validates both bundles with the current
native decoder. It reconstructs component A's exact background and contract
through `compile_registry`, verifies that its manifest differs only in the
intentional `dep-a` class name and resulting digest, and uses the native mapping
output to refresh `tests/component_a_generated`. No library fixture API is
added. An oracle mismatch requires review and stops the refresh.

`moon run tools/check-generated.mbtx` runs this verification after building the generated
application artifacts. JSON fixtures are compared as parsed data so formatting
does not affect the check; native-generated MoonBit mappings and their package
manifest must match byte for byte.

After a semantic identity change, update the explicit dependency references in
`examples/styles/styles.mbt` using the digests printed by the script, then
regenerate the application. The CLI watch fixture reads module/digest identities
from the committed bundle dynamically. It needs no separately copied digest.
See [data maintenance](../../../docs/data-sources.md#updating-inputs) for the full
property/oracle/component/application sequence and
[artifact v14](../../../docs/artifact-schema-v14.md) for current validation rules.
