# fix(analysis): output pct as proportion (0–1) and add decimals argument

**Date**: 2026-02-27
**Branch**: fix/pct-proportion-decimals-arg
**Phase**: Phase 1

## Changes

- Fix `get_freqs()` to output `pct` as a proportion (0–1) instead of a
  percentage (0–100); `se` and `se_srs` are now on the same proportion scale
- Add `decimals` argument to all six analysis functions (`get_freqs`,
  `get_means`, `get_totals`, `get_corr`, `get_quantiles`, `get_ratios`) that
  rounds all numeric output columns to the specified number of decimal places
- Add `.apply_decimals()` shared helper to `R/analysis-helpers.R`
- Add `decimals` validation to `.validate_shared_args()` (new error class
  `surveycore_error_invalid_decimals`)
- Update all `sum(pct) == 100` test assertions to `sum(pct) == 1` and remove
  `* 100` scaling from numerical oracle tests
- Add `decimals` tests to all six analysis test files and to
  `test-analysis-helpers.R`

## Files Modified

- `R/analysis-freqs-helpers.R` — remove `* 100` from `pct`, `se`, `se_srs`
  in all four cell estimators (`.taylor_freq_cell`, `.replicate_freq_cell`,
  `.srs_freq_cell`, `.twophase_freq_cell`)
- `R/analysis-freqs.R` — add `decimals` arg; update docstring (pct 0–1, sums to 1)
- `R/analysis-means.R` — add `decimals` arg
- `R/analysis-totals.R` — add `decimals` arg
- `R/analysis-corr.R` — add `decimals` arg
- `R/analysis-quantiles.R` — add `decimals` arg
- `R/analysis-ratios.R` — add `decimals` arg
- `R/analysis-helpers.R` — add `.apply_decimals()`; add `decimals` validation
  to `.validate_shared_args()`
- `man/get_freqs.Rd` — regenerated with updated docstring
- `man/get_means.Rd` — regenerated with `decimals` param
- `man/get_totals.Rd` — regenerated with `decimals` param
- `man/get_corr.Rd` — regenerated with `decimals` param
- `man/get_quantiles.Rd` — regenerated with `decimals` param
- `man/get_ratios.Rd` — regenerated with `decimals` param
- `plans/error-messages.md` — add row 45b for `surveycore_error_invalid_decimals`
- `tests/testthat/test-analysis-freqs.R` — update pct sum assertions; update
  oracle tests; add `decimals` tests
- `tests/testthat/test-analysis-means.R` — add `decimals` tests
- `tests/testthat/test-analysis-totals.R` — add `decimals` tests
- `tests/testthat/test-analysis-corr.R` — add `decimals` tests
- `tests/testthat/test-analysis-quantiles.R` — add `decimals` tests
- `tests/testthat/test-analysis-ratios.R` — add `decimals` tests
- `tests/testthat/test-analysis-helpers.R` — add `.apply_decimals()` unit tests
  and `.validate_shared_args()` decimals validation tests
- `tests/testthat/_snaps/analysis-freqs.md` — new snapshot for `decimals = -1`
- `tests/testthat/_snaps/analysis-helpers.md` — new snapshot for `decimals = -1`
