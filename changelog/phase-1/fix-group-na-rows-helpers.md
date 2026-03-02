# fix(analysis): extract shared NA-safe group helpers into analysis-helpers.R

**Date**: 2026-03-02
**Branch**: fix/group-na-rows-helpers
**Phase**: Phase 1

## Changes

- Add `.build_group_combos()` to `analysis-helpers.R`: centralises building
  unique group-value combinations, with `na.rm` support and a stable sort that
  places NA-containing rows after non-NA rows
- Add `.match_group_combo()` to `analysis-helpers.R`: centralises NA-safe group
  row matching (when the combo value is `NA`, matches rows where the column is
  also `NA`), replacing the inline `!is.na(gv_col) & (gv_col == cv)` pattern
  scattered across all six analysis functions
- Extend `.apply_group_labels()` to resolve haven tagged-NA values to their
  corresponding label strings; plain-NA label entries are excluded from factor
  levels, tagged-NA entries are included
- Add `na.rm` parameter to `.validate_shared_args()` with `isTRUE`/`isFALSE`
  guard; throws `surveycore_error_na_rm_not_logical` for non-logical values
- Add `make_na_group_design()` and `make_all_na_group_design()` fixtures to
  `helper-test-data.R` for NA group variable tests across all six analysis
  functions
- Add 200+ new test lines covering `.validate_shared_args()` na.rm validation,
  `.build_group_combos()` na.rm + sorting + multi-column + empty-input cases,
  and `.match_group_combo()` NA and non-NA matching behaviour

## Files Modified

- `R/analysis-helpers.R` — add `.build_group_combos()`, `.match_group_combo()`;
  extend `.apply_group_labels()` with tagged-NA label resolution; add `na.rm`
  parameter and validation to `.validate_shared_args()`
- `tests/testthat/test-analysis-helpers.R` — Category 10 (na.rm validation),
  Category 11 (.build_group_combos), Category 12 (.match_group_combo) tests
- `tests/testthat/helper-test-data.R` — `make_na_group_design()` and
  `make_all_na_group_design()` fixtures
- `tests/testthat/_snaps/analysis-helpers.md` — snapshot for na.rm = NA error
- `plans/error-messages.md` — row 81: `surveycore_error_na_rm_not_logical`
