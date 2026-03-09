# Changelog: feature/glm-methods

**Branch:** `feature/glm-methods`
**Phase:** 2
**PR:** 3 of 6

## Summary

Implements all 20 S3 methods on `survey_glm_fit` objects plus the
`survey_glm_summary` S3 class and its print method.

## New files

- `R/glm-methods.R` — all 20 S3 methods + `survey_glm_summary` +
  `print.survey_glm_summary()` + `getCall.survey_glm_fit()`
- `tests/testthat/test-glm-methods.R` — 90 test cases covering items
  1–16, 18–36 from spec §9.2

## Modified files

- `R/zzz.R` — `.onLoad()` updated to register all 20 S3 methods +
  `getCall` for `survey_glm_fit` via `registerS3method()` with the
  correct `"surveycore::survey_glm_fit"` class string

## Methods implemented

`print`, `summary`, `coef`, `vcov`, `predict`, `fitted`, `residuals`,
`confint`, `formula`, `terms`, `model.matrix`, `model.frame`,
`deviance`, `df.residual`, `nobs`, `hatvalues`, `logLik`, `AIC`,
`BIC`, `update`, `getCall`

## Key implementation notes

- All methods registered via `registerS3method()` in `.onLoad()` using
  `"surveycore::survey_glm_fit"` (namespaced class name required for
  S7 objects — bare `"survey_glm_fit"` does not match S7 dispatch)
- `summary.survey_glm_fit()` computes design-based t-tests and p-values
  using `model@degf - (p - 1)` df; uses `fivenum(residuals(fit_, type="deviance"))`
  for the deviance residuals block per spec §5.2.2
- `update.survey_glm_fit()` replicates `stats::update.default()` logic
  but evaluates the modified call in `parent.frame()` of our function
  (the user's frame), avoiding the frame-chain issue that would arise
  from delegating to `stats::update.default()`
- `confint.survey_glm_fit()` uses `.glm_confint()` from `R/utils.R`
  (shared with `clean()` in PR 4); column names match base R convention
  (e.g. `"2.5 %"` and `"97.5 %"`)
- `predict.survey_glm_fit()` uses snake_case argument names (`new_data`,
  `se_fit`, `na_action`) and renames `$se.fit` → `$se_fit` and
  `$residual.scale` → `$residual_scale` for `se_fit = TRUE` output

## Test results

```
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 6197 ]  (full suite)
devtools::check(): 0 errors, 0 warnings, 2 notes (pre-approved)
```
