# docs(glm): register survey_glm_fit S3 methods with @exportS3Method

**Date**: 2026-08-25
**Branch**: fix/158-roxygen2-s3-exports
**Phase**: Post-Phase-2 Audit Remediation (issue #158)

## Changes

- Add `@exportS3Method` to all 23 S3 methods on `survey_glm_fit` and
  `survey_glm_summary` in `R/glm-methods.R` (print, summary, coef, vcov,
  predict, fitted, residuals, confint, formula, terms, model.matrix,
  model.frame, deviance, df.residual, nobs, hatvalues, logLik, AIC, BIC,
  update, getCall, plot, and print.survey_glm_summary), replacing the
  placeholder `@noRd` tag
- Regenerate `NAMESPACE` so each method resolves to an explicit
  `S3method()` directive instead of relying only on the runtime
  `registerS3method()` calls in `R/zzz.R`
- Resolves the 23 `roxygen2 8.1.0` "needs @export or @exportS3Method tag"
  warnings from `devtools::document()`; no behavior change — the runtime
  dispatch for the S7 `survey_glm_fit` class still goes through
  `registerS3method()` in `.onLoad()`

## Files Modified

- `R/glm-methods.R` — swap `@noRd` for `@exportS3Method` on the 23 flagged
  S3 methods
- `NAMESPACE` — regenerated with 23 new `S3method()` directives
