# Changelog: `get_effective_n()`

**Branch:** `feature/effective-n`
**PR:** TBD
**Date:** 2026-05-05

---

## Summary

Implements `get_effective_n()`, a new exported analysis function that computes
the effective sample size of a survey design using either:

- `method = "kish"` — Kish (1965) weight-only approximation:
  `n_eff = (Σw)² / Σw²`. No reference variable required.
- `method = "deff"` — design-effect-based effective N for a specified numeric
  variable: `n_eff = n / DEFF`, where `DEFF = Var_design / Var_SRS`.

Supports all five design classes (`survey_taylor`, `survey_replicate`,
`survey_twophase`, `survey_nonprob`, `survey_collection`) and the standard
`group` argument for subgroup estimates.

## Files changed

- `R/analysis-effective-n.R` — new; `.kish_effective_n()`,
  `.get_analysis_weights()`, `get_effective_n()`, `print.survey_effective_n()`
- `R/analysis-helpers.R` — added `EFFECTIVE_N_META_KEYS` constant
- `tests/testthat/test-effective-n.R` — new; 190 tests (all pass)
- `tests/testthat/_snaps/effective-n.md` — new snapshot file
- `plans/error-messages.md` — added EN-1 through EN-4 rows
- `NEWS.md` — added 0.8.4.9000 entry
- `DESCRIPTION` — version bumped 0.8.3 → 0.8.4.9000
- `_pkgdown.yml` — added `get_effective_n` to Estimation section

## Design decisions

- `EFFECTIVE_N_META_KEYS = c(FAMILY_META_KEYS, "method")` — same pattern as
  `CORR_META_KEYS` since the method field distinguishes two formula variants.
- Print method co-located in `analysis-effective-n.R` (not `methods-print.R`),
  following the precedent of `analysis-t-test.R` and `glm-anova.R`.
- Kish on twophase designs restricts computation to Phase 2 rows (via subset
  indicator intersection with domain mask).
- DEFF method delegates to `get_means(variance = "deff")` exactly; the deff
  computation follows surveycore's unweighted SRS formula which may differ from
  `survey::svymean(deff=TRUE)`.
- EN-1 reuses `surveycore_error_unsupported_class` (from
  `.check_unsupported_class()`), consistent with all other `get_*()` functions.
