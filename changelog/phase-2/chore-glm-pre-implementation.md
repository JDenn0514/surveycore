# chore/glm-pre-implementation — Phase 2 Error Table + Test Helper Infrastructure

**Branch:** `chore/glm-pre-implementation`
**Date:** 2026-03-08

## Summary

Pre-implementation infrastructure for Phase 2 (survey GLM). No R source files
changed. Sets up the error table and test helpers required before any Phase 2
production code is written.

## Changes

### `plans/error-messages.md`

Added 6 missing Phase 2 error/warning classes (P2-16 through P2-21):

| Row | Class | Condition |
|-----|-------|-----------|
| 82 | `surveycore_error_formula_conflict` | Both `formula` and `response`/`predictors` supplied |
| 83 | `surveycore_error_empty_domain` | Active domain contains zero in-domain rows |
| 84 | `surveycore_warning_exponentiate_nonlog` | `exponentiate = TRUE` with non-log link |
| 85 | `surveycore_warning_nonpositive_weights` | Weight column contains zero or negative values |
| 86 | `surveycore_error_cbind_response_unsupported` | `cbind()` on LHS of formula |
| 87 | `surveycore_error_na_in_data` | `na.action = na.fail` with NA in response/predictor |

All 21 Phase 2 classes (P2-1 through P2-21) are now present: 19 new entries
(rows 65–87, plus rows 82–87 added here) + 2 reused from Phase 1
(`surveycore_error_unsupported_class` row 64, `surveycore_error_invalid_conf_level` row 45a).

Updated the Phase 2 row range header and coverage map.

### `tests/testthat/helper-test-data.R`

Added two invariant checker functions for Phase 2:

- **`test_glm_fit_invariants(fit)`** — asserts all 6 structural invariants on
  a `survey_glm_fit` object: correct S7 class, `p > 0` coefficients, `vcov`
  is `p × p`, `degf > 0`, `converged` is logical, `formula` inherits
  `"formula"`. Per spec §9.3a.

- **`test_glm_tidy_invariants(result)`** — asserts all 10 structural invariants
  on a `survey_glm_tidy` (clean()) result: class hierarchy, 10 required columns,
  `reference_row` logical no-NA, `label` character no-NA, `meta()` non-NULL
  with all 15 required keys, `group_names` is `character(0)`, `n_observations`
  positive integer, `n_weighted` positive numeric, `degf` positive numeric,
  `$variables` named list with all 7 sub-keys per entry. Per spec §9.3.
