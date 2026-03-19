# PR 3: Update `as_survey()` Multi-Column FPC

**Branch:** `feature/multi-stage-constructor`
**Merged:** 2026-03-13

## Summary

Updated `as_survey()` to accept multi-column FPC for multi-stage designs
(e.g., `fpc = c(fpc_stage1, fpc_stage2)`). Each column corresponds 1-to-1
with the ID stages specified in `ids`.

## Changes

### `R/core-constructors.R`
- Replaced `.resolve_single_col()` for FPC with `tidyselect::eval_select()`
  to allow multiple columns
- Added per-column validation loop: NA, nonpositive, ambiguous type,
  stage-aware cluster count vs. population size, fraction constancy checks
- Added error `surveycore_error_fpc_too_many_stages` when FPC has more
  columns than ID stages
- Added warning `surveycore_warning_fpc_partial_stages` when FPC has fewer
  columns than ID stages
- Added error `surveycore_error_fpc_smaller_than_n` when stage-j FPC pop
  size is smaller than observed cluster count within parent
- Added error `surveycore_error_fpc_not_constant` when stage-j FPC fraction
  varies within parent cluster
- `@variables$fpc` now stores a character vector (length >= 1) instead of
  character(1) for multi-stage designs; remains character(1) for single-stage
- Updated `@param fpc` roxygen documentation
- `as_survey_replicate()` and `as_survey_srs()` unchanged (still reject
  multi-column FPC)

### `tests/testthat/test-constructors.R`
- Added 9 new test blocks in "as_survey() multi-stage FPC" section
- Happy path: multi-column and single-column FPC storage
- Error paths: too many stages, NA, nonpositive, smaller-than-n,
  not-constant (all dual-pattern)
- Warning path: partial FPC stages
- `as_survey_replicate()` still rejects multi-column FPC

### `plans/error-messages.md`
- Added rows 88-91 for new error/warning classes
- Updated row 13b scope note (now only enforced for replicate/SRS)
- Updated coverage map

### `man/as_survey.Rd`
- Updated by `devtools::document()` to reflect new `@param fpc` docs
