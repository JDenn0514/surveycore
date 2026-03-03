# fix(analysis): extend get_means() and get_totals() to include NA group rows when na.rm = FALSE

**Date**: 2026-03-03
**Branch**: fix/group-na-rows-means-totals
**Phase**: Phase 1

## Changes

- Replace bare `unique(domain_data)` combo-building block in `get_means()` and
  `get_totals()` with `.build_group_combos(domain_data, na.rm)`: when
  `na.rm = FALSE`, NA-valued group combinations are included; NA combos sort
  after all non-NA combos
- Replace inline `!is.na(gv_col) & (gv_col == cv)` group-matching loop in both
  functions with `.match_group_combo(data_cols, combo_row)`: correctly matches
  rows where the group variable is `NA`
- Widen single-level group warning condition from `== 1L` to `< 2L` in both
  functions so an all-NA group variable (0 non-NA levels) also fires
  `surveycore_warning_single_level`
- Pass `na.rm = na.rm` to `.validate_shared_args()` in both functions so
  `na.rm = NA` (or any non-logical) is caught before computation
- Update `@param na.rm` documentation in both functions with the full unified
  description (group-row inclusion behaviour now documented)
- Add Test Blocks 1–8 plus oracle tests for all 5 design classes for both
  `get_means()` and `get_totals()`

## Files Modified

- `R/analysis-means.R` — replace group combo-building and matching blocks with
  shared helpers; widen warning condition; pass `na.rm` to validation; update
  `@param na.rm` docs
- `R/analysis-totals.R` — identical changes to `analysis-means.R`
- `man/get_means.Rd` — regenerated after `@param na.rm` update
- `man/get_totals.Rd` — regenerated after `@param na.rm` update
- `tests/testthat/test-analysis-means.R` — Test Blocks 1–8 (default exclusion,
  NA group row inclusion, ordering, estimates, multi-group, all-NA group, label
  propagation, group_by integration) plus oracle tests for all 5 design classes
- `tests/testthat/test-analysis-totals.R` — same test structure as means
- `tests/testthat/_snaps/analysis-means.md` — snapshot for na.rm = NA error
- `tests/testthat/_snaps/analysis-totals.md` — snapshot for na.rm = NA error
- `plans/impl-group-na-rows.md` — PR 3 checkbox marked complete
