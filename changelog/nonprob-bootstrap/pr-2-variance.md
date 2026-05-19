# feat(analysis): bootstrap variance dispatch for survey_nonprob

**Date**: 2026-05-19
**Branch**: feature/nonprob-bootstrap-variance
**Plan**: nonprob-bootstrap-variance (PR 2)

## Changes

- Add bootstrap variance dispatch in all `get_*()` estimation functions:
  when a `survey_nonprob` object has `repweights` populated, route to the
  existing replicate-weight variance engine (`.svy_rep_var()`). When no
  repweights, emit `surveycore_warning_nonprob_srs_fallback` and fall
  through to the SRS approximation path. Affected functions:
  `get_means()`, `get_freqs()`, `get_totals()`, `get_corr()`,
  `get_covariance()`, `get_ratios()`, `get_quantiles()`.
- Fix `.degf()` to return `Inf` for all `survey_nonprob` objects
  (previously returned `nrow(data) - 1`). Fix `.degf_woodruff()` with
  the same branch. This causes CI for `survey_nonprob` estimates to use
  the normal approximation regardless of sample size.
- Add `.nonprob_rep_na_warn()` helper in `analysis-helpers.R`. For
  `survey_nonprob` objects only, emits
  `surveycore_warning_domain_replicates_na` when more than 5% of
  bootstrap replicates produce `NA` for a domain. Returns `TRUE` (all-NA
  sentinel) when `na_frac == 1.0` to allow callers to short-circuit.
  Non-`survey_nonprob` designs return `NULL` immediately.
- Fix NA return shape in `.replicate_freq_cell()`: the NA-path return
  now uses key `pct` (consistent with the success path) instead of `p`.
- Add `is_replicate` flag extension in `get_ratios()` to include
  `survey_nonprob` with repweights.
- Add 52 new tests in `test-nonprob-bootstrap-variance.R` covering:
  `.degf() = Inf` (with and without repweights), SRS-fallback warning
  fires at estimation time not construction time, no SRS-fallback when
  repweights present (all six estimation functions), bitwise identity
  with equivalent `survey_replicate` object, manual oracle
  `se² ≈ (1/R) Σ(θᵣ − θ)²` at 1e-8 tolerance, domain filter routing,
  normal CI approximation for quantiles, `domain_replicates_na` warning
  for >5% NA replicates, and NPS-gating unit test for
  `.nonprob_rep_na_warn()`.

## Files Modified

- `R/analysis-helpers.R` — add `.nonprob_rep_na_warn()`; fix `.degf()`
  with explicit `survey_nonprob → Inf` branch.
- `R/analysis-quantiles-helpers.R` — fix `.degf_woodruff()` with
  `survey_nonprob → Inf` branch.
- `R/analysis-means-helpers.R` — add `survey_nonprob` dispatch branch
  (replicate path or SRS fallback).
- `R/analysis-freqs-helpers.R` — add `survey_nonprob` dispatch branch;
  fix NA return shape in `.replicate_freq_cell()`.
- `R/analysis-totals-helpers.R` — add `survey_nonprob` dispatch branch.
- `R/analysis-variance-helpers.R` — add `survey_nonprob` dispatch branch.
- `R/analysis-corr-helpers.R` — add `survey_nonprob` dispatch branch.
- `R/analysis-covariance-helpers.R` — add `survey_nonprob` dispatch
  branch.
- `R/analysis-ratios.R` — extend `is_replicate` flag to include
  `survey_nonprob` with repweights.
- `R/variance-replicate.R` — add `.nonprob_rep_na_warn()` call in
  `.vcov_pair_replicate()`.
- `tests/testthat/test-nonprob-bootstrap-variance.R` — new file; 52
  tests (9 sections).
- `tests/testthat/test-analysis-helpers.R` — update `.degf()` tests for
  `survey_nonprob` to expect `Inf`.
- `tests/testthat/test-glm-numerical.R` — update `.degf()` oracle test
  to expect `Inf`.
- `plans/impl-nonprob-bootstrap-variance-pr2.md` — implementation notes.
