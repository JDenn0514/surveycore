# Impact — svydesign-replicate-bridge

## Estimated scope
- Files touched: 3 — `R/methods-conversion.R`, `tests/testthat/test-conversion.R`,
  `tests/testthat/_snaps/conversion.md` (the snapshot file only if a new typed
  condition ships, which it does)
- Exported functions added/changed: none added. Behaviour changes in
  `from_svydesign()` and `as_svydesign()`, both already exported.
- New dependencies: none. `survey` stays in `Suggests`.
- CRAN-relevant: yes — this is the last release blocker on the open-issue
  list. No DESCRIPTION change, no export change, no new vignette.

## Smallness test (criteria: pipeline-simplified/SKILL.md §Smallness criteria)
- Result: full-required
- Rationale: `pipeline-simplified` excludes any change expected to alter
  numerical output, and mechanism 2 of #197 moves standard errors by about 35%
  on affected designs.
