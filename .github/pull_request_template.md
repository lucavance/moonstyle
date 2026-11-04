## Candidate self-review

- [ ] The change preserves or explicitly updates the public API baseline.
- [ ] Artifact schema v14, property schema v18, cache pack v4, project manifest v2, generated files, and documentation agree.
- [ ] MoonBit remains the only authoring language; no JavaScript, TypeScript, TSX, JSX, or React API was introduced.
- [ ] Native validation passes with Node unavailable; `moon run tools/validate-ci.mbtx` passes on Ubuntu 26.04 with Chromium, Firefox, and WebKit and no skips.
- [ ] Both candidate benchmark reports pass their frozen budgets.
- [ ] Published Mooncakes and source versions are distinguished; native CLI installation agrees with the library revision. Publication and tagging remain explicit maintainer operations.
- [ ] The exact candidate commit and rollback boundary are clear.
- [ ] Examples and acceptance fixtures are included in the repository and reproduce from the documented commands.
