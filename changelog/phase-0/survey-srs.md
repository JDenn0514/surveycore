# feat(classes): add survey_srs class, constructor, print, and variance estimation

**Date**: 2026-02-23
**Branch**: feature/survey-srs
**Phase**: Phase 0 (Prereq PR 1)

## Changes

- Add `survey_srs` S7 class for equal-probability simple random sample designs
- Add `as_survey_srs()` constructor with `weights`, `probs`, and `fpc` arguments
- Update `as_survey()` to dispatch to `survey_srs` when `ids` and `strata` are both NULL (with `surveycore_warning_as_survey_srs_fallback` warning)
- Add `print` and `summary` methods for `survey_srs` (with `design_info`, `weights_info`, `metadata_info`, `full` flags)
- Add `.srs_mean()` and `.srs_total()` internal estimators using the classical `(1 - f) × s²/n` formula
- Update `get_means()` and `get_totals()` dispatch to route `survey_srs` objects through the new SRS estimators
- Add rows 55–60 to `plans/error-messages.md` (new error/warning classes for `as_survey_srs()`)
- Update `test_invariants()` to check the `fpc_type` key for `survey_srs` designs
- Update `make_all_designs()` to use `as_survey_srs()` directly for the `srs` entry

## Files Modified

- `R/00-s7-classes.R` — add `survey_srs` class definition and validator
- `R/03-constructors.R` — add `as_survey_srs()`; update `as_survey()` SRS dispatch
- `R/04-methods-print.R` — add `print` and `summary` methods for `survey_srs`
- `R/06-variance-estimation.R` — add `.srs_mean()`, `.srs_total()`; update dispatch in stubs
- `tests/testthat/test-s7-classes.R` — new validator tests for `survey_srs`
- `tests/testthat/test-constructors.R` — new constructor tests for `as_survey_srs()`
- `tests/testthat/test-methods-print.R` — new print/summary snapshot tests
- `tests/testthat/test-variance-estimation.R` — oracle and edge-case tests for SRS variance
- `tests/testthat/helper-test-data.R` — update `test_invariants()` and `make_all_designs()`
- `tests/testthat/_snaps/constructors.md` — new error snapshots for `as_survey_srs()`
- `tests/testthat/_snaps/methods-print.md` — new print snapshots for `survey_srs`
- `plans/error-messages.md` — add rows 55–60; update coverage map
- `plans/survey-srs-formal-specification.md` — spec document (minor updates)
- `plans/survey-srs-implementation-plan.md` — implementation plan
- `CLAUDE.md` — update phase table: Prereq PR 1 → ✅ Complete
- `man/` — updated Rd files from `devtools::document()`
- `NAMESPACE` — updated from `devtools::document()`
