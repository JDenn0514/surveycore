# Changelog: feature/phase1-corr

**Branch:** `feature/phase1-corr`
**Status:** Complete
**Date:** 2026-02-25

## Summary

Implements `get_corr()` — survey-weighted Pearson correlation for all five
design classes (`survey_taylor`, `survey_replicate`, `survey_srs`,
`survey_calibrated`, `survey_twophase`).

## Files Added

- `R/12-analysis-corr.R` — `get_corr()` function with helpers
  `.corr_vcov_pair()` and `.corr_pair_result()`
- `tests/testthat/test-analysis-corr.R` — 208 tests covering all 12
  per-function categories plus function-specific edge cases

## Files Modified

- `R/06-variance-taylor.R` — Added `.vcov_pair_taylor()` (3-column influence
  matrix → 3×3 meta-vcov via `.svy_recvar()`)
- `R/06-variance-replicate.R` — Added `.vcov_pair_replicate()` (per-replicate
  (Var(X), Cov(X,Y), Var(Y)) → 3×3 meta-vcov)
- `R/06-variance-srs.R` — Added `.vcov_pair_srs()` (SRS structure via
  `.svy_recvar()`) and `.vcov_pair_calibrated()` (HT linearization)
- `R/06-variance-twophase.R` — Added `.vcov_pair_twophase()` (polarization
  identity applied to `.twophasevar()` scalar calls)
- `_pkgdown.yml` — Added `get_corr` to analysis reference section
- `VENDORED.md` — Documented `.vcov_pair_*()` provenance from
  `survey/R/surveysummary.R`

## Key Decisions

### Variance-Covariance Approach

`get_corr()` uses the design-based variance-covariance approach:
`r = Cov(X,Y) / sqrt(Var(X) * Var(Y))`. SE is derived via the delta method
applied to the 3×3 meta-vcov of `(Var(X), Cov(X,Y), Var(Y))`.

### Oracle Alignment

The oracle is `survey::svyvar()`. The `vcov()` of `svyvar()` returns a 4×4
matrix (all entries of the 2×2 var-cov matrix). The correct comparison is
`vcov(sv)[c(1,2,4), c(1,2,4)]` (unique 3×3 sub-matrix) with the 3-element
gradient `g = c(-r/(2*a), 1/sqrt(a*c), -r/(2*c))`.

### Fisher Z CI

CI bounds use Fisher Z transform (guaranteeing (-1, 1) bounds):
`ci = tanh(atanh(r) ± z_crit * se_r)`.

### Two-Phase Meta-VCov

Uses polarization identity: `Cov(T_a, T_b) = (Var(T_a+T_b) - Var(T_a) - Var(T_b)) / 2`,
calling `.twophasevar()` six times per pair to build the 3×3 sigma without
modifying the existing scalar `.twophasevar()` function.

### Wide Format

Wide format always shows the full symmetric correlation matrix (both triangles),
with diagonal NA by default. The `redundant` and `diagonal` arguments only
affect long format output.
