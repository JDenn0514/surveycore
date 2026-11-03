# Changelog: fix/joint-vcov-means-ratios

**Branch:** `feature/joint-vcov-means-ratios`
**Status:** Complete
**Date:** 2026-10-22
**Issue:** #200

## Summary

Closes #200. Part 3 of the arc, after `changelog/feat-totals-categorical-x.md`
(#199) and `changelog/fix-joint-vcov-freqs-totals.md`.

`get_means()` and `get_ratios()` now store the joint covariance matrix of
their estimates, on the same route as `get_freqs()` and `get_totals()`: each
Taylor and replicate cell helper returns its influence column or its
per-replicate estimates, and `.joint_vcov()` reduces them once. `vcov()` on a
grouped mean or ratio previously returned `NA_real_` off the diagonal (and,
before part 2, structural zeros); it now returns the matrix that
`survey::vcov(survey::svyby(..., covmat = TRUE))` returns, with the
cross-group covariance the shared PSUs create. On the test fixtures the
largest cross-group correlation was 0.08 to 0.13 for grouped means and 0.18
for grouped ratios.

The ratio's Taylor linearization is `z / total_x` with `z = y - ratio * x`, so
the delta-method cell divides the influence column of `z`'s total by the
signed `total_x`; the standard error divides by `abs(total_x)`, and a
covariance needs the sign. Calibrated Taylor means carry the calibration
projection into the matrix, as they do into the standard error.

`get_quantiles()`, `get_corr()`, `get_covariance()` and `get_diffs()` still
return `NA_real_` off the diagonal with `surveycore_warning_vcov_incomplete`,
as do all four functions on two-phase designs and on `survey_nonprob` designs
without replicate weights.

## Files Modified

- `R/analysis-means-helpers.R` — the Taylor and replicate mean cells return a `joint` element.
- `R/analysis-ratios-helpers.R` — the replicate ratio cell returns its per-replicate ratios; the delta-method cell returns `z`'s joint element divided by `total_x`.
- `R/analysis-means.R`, `R/analysis-ratios.R` — collect the per-cell elements and store the matrix; `@return` documents it.
- `R/analysis-methods-coef-vcov.R` — `vcov()` documentation lists the four functions that store a matrix; the example shows grouped means.
- `man/vcov.survey_result.Rd`, `man/get_means.Rd`, `man/get_ratios.Rd` — regenerated.
- `tests/testthat/test-analysis-methods-coef-vcov.R` — 11 new blocks; four fallback blocks moved from grouped means to grouped quantiles, or drop the stored matrix explicitly.

## Changes

- `vcov()` on `get_means()` and `get_ratios()` results returns the full joint covariance matrix on Taylor and replicate designs.

## Tests

Oracle blocks against `survey::svyby(covmat = TRUE)` on NHANES (Taylor) and ACS PUMS (successive-difference replicate): grouped means against `svymean()`, grouped ratios against `svyratio()`, each unfiltered and on a filtered design, plus grouped means on a calibrated Taylor design against `survey::calibrate()`, compared as full matrices to 1e-8. 10 of the 11 new blocks fail on the code before this change; the 11th guards the two-phase fallback, which already held.
