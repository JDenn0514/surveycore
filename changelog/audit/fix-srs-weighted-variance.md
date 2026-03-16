# fix(variance): use Taylor linearization for SRS weighted variance

**Date**: 2026-03-16
**Branch**: fix/srs-weighted-variance
**Phase**: Audit remediation

## Changes

- Replace unweighted sample variance `s^2` formula with Taylor (HT) linearization
  via `.build_cluster_matrices()` + `.svy_recvar()` in all SRS variance functions
- `.srs_mean()` and `.srs_total()` in `R/variance-srs.R` now use the same
  HT linearization as `survey::svydesign(ids = ~1)`, correct for any weight structure
- `.srs_mean_cell()` in `R/analysis-means-helpers.R` uses full-length influence
  vectors with domain masking through `.build_cluster_matrices()` + `.svy_recvar()`
- `.srs_total_cell()` in `R/analysis-totals-helpers.R` uses the same approach
- `.srs_freq_cell()` in `R/analysis-freqs-helpers.R` now delegates to
  `.taylor_freq_cell()` which already uses `.build_cluster_matrices()` + `.svy_recvar()`
- Added 10 new oracle tests comparing non-proportional weight SRS estimates
  against `survey` package at tolerance 1e-10 (point) and 1e-8 (SE)
- Updated 5 existing tests that were asserting the old (incorrect) unweighted
  s^2 behavior

## Files Modified

- `R/variance-srs.R` -- rewrote `.srs_mean()` and `.srs_total()` to use Taylor linearization
- `R/analysis-means-helpers.R` -- rewrote `.srs_mean_cell()` to use Taylor linearization
- `R/analysis-totals-helpers.R` -- rewrote `.srs_total_cell()` to use Taylor linearization
- `R/analysis-freqs-helpers.R` -- simplified `.srs_freq_cell()` to delegate to `.taylor_freq_cell()`
- `tests/testthat/test-variance-srs.R` -- added 10 non-proportional weight oracle tests; updated 2 tests
- `tests/testthat/test-analysis-freqs.R` -- added 1 non-proportional weight oracle test; updated 1 test
- `tests/testthat/test-analysis-means.R` -- updated 1 domain-vs-filter SE comparison test
- `tests/testthat/test-analysis-totals.R` -- updated 1 domain-vs-filter SE comparison test
