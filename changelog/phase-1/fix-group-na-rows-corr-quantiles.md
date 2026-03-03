# fix(analysis): extend get_corr() and get_quantiles() to include NA group rows when na.rm = FALSE

**Date**: 2026-03-03
**Branch**: fix/group-na-rows-corr-quantiles
**Phase**: Phase 1

## Changes

- Replace Pattern B combo-building block in `get_corr()` (which used
  `Reduce(\`|\`, ...)` to filter NAs before `unique()`) with
  `.build_group_combos(domain_data, na.rm)`: when `na.rm = FALSE`, NA-valued
  group combinations are included; NA combos sort after all non-NA combos
- Replace inline `!is.na(gv_col) & (gv_col == cv)` group-matching loop in
  `get_corr()` with `data_cols` / `.match_group_combo(data_cols, combo_row)`
- Apply identical Pattern A replacement (with `complete.cases`) to
  `get_quantiles()`: replace `complete.cases` pre-filter with
  `.build_group_combos(domain_data, na.rm)`; replace inline loop with
  `.match_group_combo()`
- Widen single-level group warning condition from `== 1L` to `< 2L` in both
  functions so an all-NA group variable (0 non-NA levels) also fires
  `surveycore_warning_single_level`
- Update `@param na.rm` documentation in both functions with the full unified
  description (group-row inclusion behaviour now documented)
- Add Test Blocks 1–8 plus oracle tests for all 5 design classes for both
  `get_corr()` and `get_quantiles()`
- Mark PR 4 checkbox complete in `plans/impl-group-na-rows.md`

## Files Modified

- `R/analysis-corr.R` — replace Pattern B group combo-building and matching
  blocks with shared helpers; widen warning condition; update `@param na.rm`
- `R/analysis-quantiles.R` — replace Pattern A group combo-building and
  matching blocks with shared helpers; widen warning condition; update
  `@param na.rm`
- `man/get_corr.Rd` — regenerated after `@param na.rm` update
- `man/get_quantiles.Rd` — regenerated after `@param na.rm` update
- `tests/testthat/test-analysis-corr.R` — Test Blocks 1–8 (default exclusion,
  NA group row inclusion, ordering, estimates, multi-group, all-NA group, label
  propagation, group_by integration) plus oracle tests for all 5 design classes
- `tests/testthat/test-analysis-quantiles.R` — same test structure as corr
- `tests/testthat/_snaps/analysis-corr.md` — snapshot for na.rm = NA error
- `tests/testthat/_snaps/analysis-quantiles.md` — snapshot for na.rm = NA error
- `plans/impl-group-na-rows.md` — PR 4 checkbox marked complete
