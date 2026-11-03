# Implementation — PR 2: fay-rho-constructor-conditions

**Branch**: `test/fay-rho-constructor-conditions`
**Base**: `6801065` (develop after #301), tree `a11fe29`
**Head**: `46d58f1`
**HOLDs**: none

## Write surface

Modified:

- `R/core-constructors.R` (roxygen `@references` only)
- `R/core-classes.R` (roxygen only)
- `man/as_survey_replicate.Rd` (generated)
- `man/survey_replicate.Rd` (generated)
- `tests/testthat/test-constructors.R`
- `tests/testthat/_snaps/constructors.md`

Created or deleted: none.

## Summary

- The Judkins (1990) reference in `as_survey_replicate()` and
  `survey_replicate` now cites the *Journal of Official Statistics*
  6(3), 223--239.
- The `survey_replicate` `@param variables` key list ends with `rho`, and
  `@section Design variables` has a `rho` item after `mse`.
- Seven new test blocks in `test-constructors.R`, after the FR-3 snapshot
  block, all on fixture FT (`seed = 259L`, 20 replicate columns): the `rho`
  key for all nine types, the positional call, explicit `rho = NULL`, the
  three FR-2 snapshots, the 14 invalid values, no warning for the eight
  other types, and BRR with `rho = "a"`.
- Three new snapshot entries under one block title. They show
  `<character>: 0.5`, `<numeric>: a value of length 0`, and
  `<numeric>: 0.1, 0.2, 0.3, 0.4, 0.5`.
- No PR 1 defect found: every new test passed against the PR 1 code, so
  `R/core-constructors.R` has no code change.

## Tasks

- [x] 1. `rho` key tests (eight types `NULL`, Fay present)
- [x] 2. Positional call `"Fay", 0.3` (rho tolerance 1e-10, scale 1e-8)
- [x] 3. Explicit `rho = NULL` raises `surveycore_error_fay_rho_missing`
- [x] 4. `rho = "0.5"` class + snapshot; `numeric(0)` and six-value snapshots
- [x] 5. 14 invalid values raise `surveycore_error_fay_rho_invalid`
- [x] 6. `expect_no_warning()` for the eight other types with no `rho`
- [x] 7. BRR with `rho = "a"`: the warning, no error; stored `rho` is `NULL`
- [x] 8. Roxygen edits; `devtools::document()` run
- [x] 9. Verified against the PR 1 code; no defect

## Notes for tester

- The `numeric(0)` snapshot reaches the `"a value of length 0"` branch of
  `rho_txt` in `R/core-constructors.R` (about line 902).
- Every numeric `expect_equal()` in the new blocks has an explicit
  `tolerance =`.
- `air format` on a copy of the test file changed no line in the new
  region. `R/core-classes.R` and `R/core-constructors.R` pass
  `air format --check`.
- Some new block titles are longer than 80 characters, as are existing
  titles in the same file. `air` does not wrap strings.
