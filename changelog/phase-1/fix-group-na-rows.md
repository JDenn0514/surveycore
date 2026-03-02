# Changelog: NA Group Rows in Analysis Functions

**Feature branch series:** `fix/group-na-rows-*`
**PRs:** #33 (helpers), #TBD (freqs), #TBD (means/totals), #TBD (corr/quantiles), #TBD (ratios)

## Summary

Extends the `na.rm` argument in all six analysis functions to include rows
where a **grouping variable** is `NA` in the output when `na.rm = FALSE`.
Previously, observations where any group variable was `NA` were silently
dropped regardless of `na.rm`. Now:

- `na.rm = TRUE` (default): NA group rows are excluded (no change to existing
  behavior).
- `na.rm = FALSE`: observations where a group variable is `NA` are collected
  into their own group row in the output, appearing after all non-`NA` group
  rows.

## Changes

### Shared infrastructure (PR #33)

- Added `.build_group_combos(domain_data, na.rm)` to `R/analysis-helpers.R`:
  replaces three divergent patterns (Pattern A, B, C) across six functions.
  When `na.rm = FALSE`, includes NA-valued combinations; sorts NA combos last.
- Added `.match_group_combo(data_cols, combo_row)` to `R/analysis-helpers.R`:
  replaces inline `!is.na(gv_col) & (gv_col == cv)` loop. Handles NA matching
  correctly via `is.na()`.
- Added `make_na_group_design()`, `make_all_na_group_design()`, and
  `get_na_group_rows()` to `tests/testthat/helper-test-data.R` for shared
  test fixtures.
- Added `surveycore_error_na_rm_not_logical` to `.validate_shared_args()`:
  rejects `na.rm = NA` or any non-logical value with a clear error.

### `get_freqs()` (this PR)

- Replaced Pattern A (complete.cases pre-filter) with `.build_group_combos()`.
- Replaced inline group matching loop with `.match_group_combo()`.
- Widened single-level group warning condition from `== 1L` to `< 2L` so
  all-NA group vars (0 non-NA levels) also trigger the warning.
- Added `na.rm = na.rm` to `.validate_shared_args()` call so `na.rm = NA`
  is caught before any computation.
- Updated `@param na.rm` documentation with the extended description.

### `get_means()` and `get_totals()` (PRs TBD)

See changelog update in those PRs.

### `get_corr()` and `get_quantiles()` (PRs TBD)

See changelog update in those PRs.

### `get_ratios()` (PR TBD)

See changelog update in that PR.

## Error/Warning Classes

- **New**: `surveycore_error_na_rm_not_logical` — fires when `na.rm` is not
  `TRUE` or `FALSE`.
- **Widened**: `surveycore_warning_single_level` — now fires when a group
  variable has fewer than 2 non-NA unique values (previously: exactly 1).
