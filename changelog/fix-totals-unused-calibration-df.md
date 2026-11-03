# Changelog: fix/totals-unused-calibration-df

**Branch:** `fix/totals-unused-calibration-df`
**Status:** Complete
**Date:** 2026-10-22

## Summary

`.taylor_total_cell()` computed a calibration-adjusted degrees of freedom
for every cell on a calibrated `survey_taylor` design. It subtracted
`.get_calibration_df_reduction()` from the cell's design df, warned with
`surveycore_warning_zero_df_after_calibration` when the result fell to zero
or below, and returned it as `df`. No caller read that `df`. `get_totals()`
and `get_ratios()`, the two callers that reach this helper on a Taylor
design, build their CIs with `degf <- Inf`, the normal approximation that
matches `survey::svytotal()` and `survey::svyratio()`. So the warning told
the user that "CIs and p-values may be invalid" about a df that played no
part in either.

The df computation, the warning and the `df` element are removed from
`.taylor_total_cell()`. Standard errors, point estimates and CIs are
unchanged. The calibration projection of the influence matrix stays.

### Why remove the df rather than use it

This matches `get_freqs()`, which also keeps `Inf` (see
`changelog/fix-freqs-calibration-se.md`), and keeps totals and ratios
agreeing with `survey`. `get_means()` is still the only estimator that
reports a calibration-adjusted df, and it keeps the warning; CAL-14 in
`plans/error-messages.md` already names only `get_means()` and the variance
helpers, so the table needs no change.

## Files Modified

- `R/analysis-totals-helpers.R` — `.taylor_total_cell()` no longer computes,
  warns about or returns a calibration-adjusted df
- `tests/testthat/test-analysis-totals.R` — one block: no zero-df warning
  when the calibration rank exceeds the design df, no `df` column, and
  normal-quantile CIs
- `tests/testthat/test-analysis-ratios.R` — one block: no zero-df warning
  on the same fixture
- `changelog/fix-totals-unused-calibration-df.md` — this file

## Changes

- Remove the unused calibration df computation and its zero-df warning from
  the Taylor totals cell helper, which `get_totals()` and `get_ratios()`
  share
- Add regression tests for both callers

## Verification

Fixture: a 40-row SRS design (design df 39) calibrated on a 40-column
identity model matrix (rank 40). Before the fix, `get_totals()` and
`get_ratios()` both warned "Calibration reduces design df (39) to -1." and
both new blocks failed. After it, neither warns, and the full test suite
passes.
