# Changelog: fix/joint-vcov-freqs-totals

**Branch:** `feature/joint-vcov`
**Status:** Complete
**Date:** 2026-10-22
**Issue:** #200

## Summary

Refs #200. Part 2 of the arc; `get_means()` and `get_ratios()` follow.

`vcov()` on a surveycore result put `se^2` on the diagonal and structural
zeros off it, and warned with `surveycore_warning_vcov_diagonal_only`. The
zeros were wrong. Two complementary proportions have covariance `-var`
exactly, so `vcov()` reported 0 where the true correlation is -1. On the test
fixtures, the largest correlation `vcov()` set to zero was 0.77 for a
three-level `get_freqs()`, 0.70 between groups of a grouped `get_freqs()`, and
0.36 to 0.47 between groups of a grouped `get_totals()`. A contrast computed
from that matrix, or a matrix passed to
`surveywts::calibrate_to_estimate(vcov_estimate =)`, gave the wrong answer.
The warning also claimed the zeros matched `survey::vcov.svyby()`, which holds
only for `svyby()`'s default `covmat = FALSE`.

`get_freqs()` and `get_totals()` now compute the full covariance matrix of
their estimates when the result is built, on Taylor and replicate designs
(including a `survey_nonprob` design with replicate weights), and store it in
the `.vcov` attribute, which `vcov()` reads. Each cell helper returns its
influence column (Taylor) or its per-replicate estimates (replicate) alongside
its scalar SE, and one reduction over the stacked columns gives every
covariance: between levels, between groups, and across a filtered domain.
That is the same matrix as `survey::vcov()` on `svymean()`, `svytotal()` and
`svyby(covmat = TRUE)`, to within 4e-14 relative on the test fixtures. The
published SEs do not change; the stored diagonal equals `se^2`.

`vcov()` no longer returns a structural zero anywhere. A result with no stored
matrix — `get_means()`, `get_ratios()`, `get_quantiles()`, `get_corr()`,
`get_covariance()` and `get_diffs()`; `get_freqs()` and `get_totals()` on a
two-phase design or on a `survey_nonprob` design without replicate weights —
gets `NA_real_` off the diagonal and `surveycore_warning_vcov_incomplete`.
`surveycore_warning_vcov_diagonal_only` is retired. An `NA` entry makes a
downstream consumer such as surveywts refuse the matrix; a zero passed all
four of its checks.

## Files Modified

- `R/analysis-helpers.R` — new `.joint_infl()`, `.joint_rep()`, `.joint_na()`, `.joint_vcov()` and `.attach_joint_vcov()`.
- `R/variance-replicate.R` — new `.svy_rep_vcov()`, the matrix form of `.svy_rep_var()` with per-column NA handling; `.vcov_pair_replicate()` now calls it.
- `R/analysis-freqs-helpers.R`, `R/analysis-totals-helpers.R` — the Taylor and replicate cell helpers return a `joint` element.
- `R/analysis-freqs.R`, `R/analysis-totals.R` — collect the per-cell `joint` elements and store the matrix; `@return` documents it.
- `R/analysis-methods-coef-vcov.R` — `vcov.survey_result()` reads the stored matrix by coefficient name, else returns `NA_real_` off the diagonal with `surveycore_warning_vcov_incomplete`.
- `plans/error-messages.md` — SCR-W1 widened; SCR-W2 retired.
- `man/vcov.survey_result.Rd`, `man/SE.survey_result.Rd`, `man/get_freqs.Rd`, `man/get_totals.Rd` — regenerated.
- `tests/testthat/test-analysis-methods-coef-vcov.R` — 23 new blocks and 4 rewritten ones.

## Changes

- `vcov()` on `get_freqs()` and `get_totals()` results returns the full joint covariance matrix.
- `vcov()` never returns a structural zero: results without a joint matrix get `NA_real_` off the diagonal and `surveycore_warning_vcov_incomplete`.
- `surveycore_warning_vcov_diagonal_only` is retired.
- `vcov()` works without an `se` column when a matrix is stored, and after the result's rows are subset or reordered.

## Tests

Oracle blocks against `survey` on NHANES (Taylor) and ACS PUMS (successive-difference replicate): `get_freqs()` against `svymean()`, `get_totals()` on a factor against `svytotal()`, grouped results against `svyby(covmat = TRUE)`, each unfiltered and on a filtered design, compared as full matrices to 1e-8. Further blocks cover the complementary-proportion case (off-diagonal `-var`), the four `surveywts::calibrate_to_estimate()` validator properties (no `NA`, k × k, symmetric to 1e-8, `chol()` succeeds), and the fallback paths. 22 of the 23 new blocks fail on the code before this change; the 23rd guards that the diagonal equals `se^2`, which already held.
