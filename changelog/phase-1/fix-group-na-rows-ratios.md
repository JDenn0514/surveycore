# fix(analysis): extend get_ratios() to include NA group rows when na.rm = FALSE

**Date**: 2026-03-03
**Branch**: fix/group-na-rows-ratios
**Phase**: Phase 1

## Changes

- Replace Pattern A (complete.cases pre-filter) combo-building block in
  `get_ratios()` with `.build_group_combos(domain_data, na.rm)`: when
  `na.rm = FALSE`, NA-valued group combinations are included; NA combos sort
  after all non-NA combos
- Replace inline `!is.na(gv_col) & (gv_col == cv)` group-matching loop in
  `get_ratios()` with `data_cols` / `.match_group_combo(data_cols, combo_row)`
- Widen single-level group warning condition from `== 1L` to `< 2L` so an
  all-NA group variable (0 non-NA levels) also fires
  `surveycore_warning_single_level`
- Pass `na.rm = na.rm` to `.validate_shared_args()` so `na.rm = NA` (or any
  non-logical) is caught before any computation
- Update `@param na.rm` documentation with the full unified description
  (group-row inclusion behaviour now documented)
- Add Test Blocks 1–8c plus oracle tests for all 5 design classes for
  `get_ratios()`
- Mark PR 5 checkbox complete in `plans/impl-group-na-rows.md`

## Files Modified

- `R/analysis-ratios.R` — replace Pattern A group combo-building and matching
  blocks with shared helpers; widen warning condition; pass `na.rm` to
  validation; update `@param na.rm` docs
- `man/get_ratios.Rd` — regenerated after `@param na.rm` update
- `tests/testthat/test-analysis-ratios.R` — Test Blocks 1–8c (default
  exclusion, NA group row inclusion, ordering, estimates, multi-group, all-NA
  group, label propagation, group_by integration, na.rm = NA error) plus oracle
  tests for all 5 design classes (single-group and multi-group)
- `tests/testthat/_snaps/analysis-ratios.md` — snapshot for na.rm = NA error
- `plans/impl-group-na-rows.md` — PR 5 checkbox marked complete
