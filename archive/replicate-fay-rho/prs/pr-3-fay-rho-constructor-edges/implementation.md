# Implementation — PR 3: fay-rho-constructor-edges

**Branch**: `test/fay-rho-constructor-edges`
**Base**: `b4c0a8870fb628f4f8824506f6c8c69c0828d395` (tree `9afc8f1f`); the
worktree opened on `d4d1db2` and was reset to the base before any edit.
**Head commit**: `2e24a81beaef398379f212a2b18d773efffadf73`

## Write surface

- Modified: `tests/testthat/test-constructors.R` (12 new `test_that()`
  blocks, inserted after the block "as_survey_replicate() warns and does not
  check rho = \"a\" for type = \"BRR\"").
- Created: none. Deleted: none.
- `R/core-constructors.R`: not touched. No test exposed a PR 1 defect.

## Summary

- Accepted `rho` values on fixture FT, Fay: `0` (scale `1 / 20`, type
  `"Fay"`), `0L` (stored identical to the double `0`), `c(a = 0.3)`
  (stored unnamed, value 0.3) and `0.999` (scale `1 / (20 * (1 - 0.999)^2)`).
- Fay with `scale = 99` raises no warning and stores the Fay scale.
- Fay keeps `rscales = rep(2, 20)` with the Fay scale, and builds with
  `mse = FALSE`.
- An inline four-row frame with one replicate column, `rho = 0.5`, stores
  scale 4.
- Order of checks, Fay with no `rho`: `df[0, ]` raises
  `surveycore_error_empty_data`, `df[1, ]` raises
  `surveycore_error_single_row`, and `rscales = rep(1, 3)` raises
  `surveycore_error_rscales_length`. `update_design(weights = wt2)` keeps
  `rho` 0.3.

## Tasks

- [x] 1. Accepted values `0`, `0L`, `c(a = 0.3)`, `0.999`
- [x] 2. Supplied `scale = 99` discarded with no warning
- [x] 3. `rscales` kept; `mse = FALSE` accepted
- [x] 4. One replicate column, scale 4
- [x] 5. Empty, single-row and `rscales`-length errors before the
  missing-`rho` error
- [x] 6. `update_design()` keeps `rho`
- [x] 7. All blocks pass against the PR 1 code; no source change

## HOLDs

None.

## Notes for tester

- Every numeric `expect_equal()` carries an explicit tolerance: 1e-10 for a
  stored `rho`, 1e-8 for a stored scale.
- The order-of-check blocks assert the class only (`expect_error(class =)`),
  with no snapshot, so this PR adds no `_snaps/` entry.
- The new blocks add no `test_invariants()` call; the file already calls it
  for `as_survey_replicate()`.
- The new blocks are air-clean. The pre-existing air hunks in the file are
  not reformatted.
