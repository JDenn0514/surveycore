# Changelog: feature/glm-clean

**PR 4 of Phase 2 — `clean()` + `broom::tidy()` shim**
**Branch:** `feature/glm-clean`
**Date:** 2026-03-09

## Summary

Implements `clean()`, the tidy output function for `survey_glm_fit` objects,
and a `broom::tidy.survey_glm_fit()` compatibility shim.

## New exports

- `clean()` — Converts a `survey_glm_fit` into a `survey_glm_tidy` result
  tibble with one row per model coefficient (plus optional reference rows for
  factor predictors), design-based standard errors, confidence intervals, and
  structured metadata via `meta()`.

## New files

- `R/glm-clean.R` — `clean()`, `.build_glm_meta()`, `tidy.survey_glm_fit()` shim,
  and internal helpers (`.glm_term_type()`, `.glm_find_level()`,
  `.glm_var_label_for()`, `.glm_value_label_for()`, `.glm_n_obs_for()`,
  `.glm_interaction_label()`)

## Changed files

- `R/zzz.R` — Added conditional broom shim registration in `.onLoad()`
- `DESCRIPTION` — Added `broom (>= 1.0.0)` to `Suggests`
- `tests/testthat/test-glm.R` — Added clean() test items 2–6, 5a–5d, §9.4
  edge cases for clean(), and error path tests
- `tests/testthat/test-glm-methods.R` — Added item 17: `print(clean(fit))`
  snapshot
- `plans/impl-phase-2.md` — PR 4 marked `[x]` complete

## Key behaviors

- `clean()` returns `c("survey_glm_tidy", "survey_result", "tbl_df", "tbl",
  "data.frame")` with columns: `term`, `variable`, `var_label`, `label`,
  `reference_row`, `estimate`, `std_error`, `p_value`, `conf_low`, `conf_high`
  (always); `statistic` (when `statistic = TRUE`); `n_obs` (when `n = TRUE`)
- Reference rows for unordered factor predictors use
  `setdiff(levels(mf[[v]]), colnames(stats::contrasts(mf[[v]])))` — no
  fragile string prefix removal
- CIs via `.glm_confint()` — guaranteed numerical identity with
  `confint.survey_glm_fit()` for the same `conf_level`
- `exponentiate = TRUE` exponentiates estimate/CI; leaves `std_error` on log
  scale; fires `surveycore_warning_exponentiate_nonlog` for non-log links
- `.meta` carries 15 required keys; `$variables` has one entry per predictor
  with 7 sub-keys (including variable labels, factor levels, value labels)
- `broom::tidy(fit)` delegates to `clean(fit, ...)` registered conditionally
  on broom being installed

## Test coverage

All new tests pass. Full suite: FAIL 0 | PASS 6528.
`devtools::check()`: 0 errors, 0 warnings, 2 pre-approved notes.
