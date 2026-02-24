# fix(constructors): tighten as_survey_twophase() NA and method validation

**Date**: 2026-02-24
**Branch**: feature/twophase-constructor-na
**Phase**: Phase 0.75

## Changes

- Change Warning 23b (NA in `subset` column) from a `cli_warn()` to a hard `cli_abort()` with class `surveycore_error_subset_na`; the phase 2 membership indicator must be fully observed for all phase 1 units
- Remove Warning 25 (`method = "full"` with no Phase 2 design info) entirely from `as_survey_twophase()`; this check is deferred to estimation time in PR 3
- Rename the `phase2_ind` column produced by `make_survey_data(design = "twophase")` to `subset` throughout all test files and the test data generator
- Update `make_all_designs()` to use `method = "approx"` and remove `suppressWarnings()` wrapper (no longer needed)
- Update `plans/error-messages.md`: replace row 23b (warning) with the new hard error; remove row 25

## Files Modified

- `R/03-constructors.R` — replace `cli_warn` with `cli_abort` for NA subset check; remove Warning 25 block
- `tests/testthat/helper-test-data.R` — rename `phase2_ind` → `subset` in `make_survey_data()`; update `make_all_designs()` to use `method = "approx"` without `suppressWarnings()`
- `tests/testthat/test-constructors.R` — rename all `phase2_ind` references to `subset`; replace Row 23b warning test with dual-pattern error test; delete Row 25 test blocks; update degenerate-with-NA test
- `tests/testthat/test-conversion.R` — rename `phase2_ind` → `subset`; remove stale `suppressWarnings()` wrappers
- `tests/testthat/test-methods-print.R` — rename `phase2_ind` → `subset`; remove `suppressWarnings()` wrapper
- `tests/testthat/test-update-design.R` — rename `phase2_ind` → `subset`; remove `suppressWarnings()` wrapper
- `tests/testthat/test-utils.R` — rename `phase2_ind` → `subset` including string literal in `expect_true()`
- `tests/testthat/test-variance-dispatch.R` — update "not yet implemented" blocks to use `subset = subset, method = "approx"`
- `tests/testthat/_snaps/constructors.md` — remove stale snapshots; add new error snapshot for Row 23b
- `tests/testthat/_snaps/methods-print.md` — regenerate two-phase print/summary snapshots with updated column name
- `plans/error-messages.md` — row 23b changed from WARN to ERROR (`surveycore_error_subset_na`); row 25 removed; Coverage Map updated
- `plans/implementation-plan-phase-0.75.md` — mark PR 2 complete
