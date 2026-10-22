# Changelog: fix/freqs-calibration-se

**Branch:** `fix/freqs-calibration-se`
**Status:** Complete
**Date:** 2026-10-22

## Summary

`get_freqs()` standard errors on a calibrated `survey_taylor` design (one
with `@calibration` set) left out the GREG projection. `.taylor_freq_cell()`
built its influence matrix and passed it straight to `.svy_recvar()`, without
the `.maybe_apply_calibration()` call that `.taylor_mean_cell()` and
`.taylor_total_cell()` make. Point estimates were right; the SEs were the
uncalibrated linearization evaluated at the calibrated weights, so they did
not match `survey::svymean()` on the equivalent `survey::calibrate()` design.

`.taylor_freq_cell()` now projects its influence matrix through
`.maybe_apply_calibration()` before the variance step. Designs without
calibration are unchanged, because the helper returns its input when
`@calibration` is empty.

### Why no degrees-of-freedom reduction

`get_freqs()` uses no finite design df. Its CIs use the normal approximation
(`degf <- Inf`), which matches `survey::svymean()`'s `confint()`, and its
`.survey_result$df` is `Inf` to match (issue #271). There is no finite df for
`.get_calibration_df_reduction()` to reduce. `get_means()` is the only
estimator that reports a calibration-adjusted df, so this fix does not add
one to `get_freqs()`.

## Files Modified

- `R/analysis-freqs-helpers.R` — `.taylor_freq_cell()` calls
  `.maybe_apply_calibration()` on its influence matrix
- `tests/testthat/test-analysis-freqs.R` — two oracle blocks against a
  `survey::calibrate()` GREG design, with a shared fixture builder
- `changelog/fix-freqs-calibration-se.md` — this file

## Changes

- Apply the calibration projection to the `get_freqs()` Taylor influence
  matrix, so SEs on calibrated `survey_taylor` designs match
  `survey::svymean()`
- Add oracle tests for ungrouped (`svymean()`) and grouped (`svyby()`)
  frequencies on a calibrated design, with point estimates at 1e-10 and SEs at
  1e-8

## Verification

Fixture: `make_survey_data(seed = 42)` plus a 3-level factor `f`
(`set.seed(1)`), calibrated with `survey::calibrate(sv, ~x, pop)` on
`x = y2`, and rebuilt in surveycore with `as_caldata()` and
`as_survey(calibration = list(cd))`.

| | `fa` | `fb` | `fc` |
|---|--:|--:|--:|
| `get_freqs()` SE before the fix | 0.02139603 | 0.02195037 | 0.02422177 |
| `survey::SE(svymean(~f, cal))` | 0.02129428 | 0.02196812 | 0.02421877 |

Before the fix, both new oracle blocks failed on SE and passed on `pct`.
After it, both pass, and the full test suite passes.
