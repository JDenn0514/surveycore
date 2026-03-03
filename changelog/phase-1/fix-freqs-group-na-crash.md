# fix(analysis): fix get_freqs() crash when group variable has NA values

**Date**: 2026-03-02
**Branch**: fix/freqs-group-na-crash
**Phase**: Phase 1

## Changes

- Fix `get_freqs()` throwing `! missing value where TRUE/FALSE needed` when the
  `group` variable contains `NA` values (e.g., Nationscape `cand_favorability_biden`)
- Filter `NA` rows from `group_combos` using `complete.cases()` before building
  group combinations, matching the pattern already used in `get_means()`,
  `get_totals()`, `get_quantiles()`, `get_ratios()`, and `get_corr()`
- Replace bare `==` in the group matching loop with an NA-safe guard
  (`!is.na(gv_col) & (gv_col == cv)`), consistent with all other analysis functions
- Add two regression tests covering the crash case and verifying that pcts sum
  to 1 within each non-NA group

## Files Modified

- `R/analysis-freqs.R` — add `complete.cases()` filter when building `group_combos`;
  use NA-safe matching in the group loop
- `tests/testthat/test-analysis-freqs.R` — two new tests for group variable with NAs
