# R/zzz.R
#
# Package load hook. S7 requires methods_register() to be called in .onLoad()
# so that methods on external generics (print, summary, etc.) are registered
# correctly when the package is loaded from an installed library.
# See: vignette("packages", package = "S7")
#
# Phase 2 additions: register all 20 S3 methods + getCall for survey_glm_fit.
# CRITICAL: S7 namespaced class names ("surveycore::survey_glm_fit") must be
# used as the class string — not bare "survey_glm_fit". The class() of an S7
# object returns namespaced names; bare names never match.
# See: MEMORY.md §Phase 0.5 / surveytidy dplyr Dispatch Pattern

# nocov start
.onLoad <- function(libname, pkgname) {
  S7::methods_register()

  # Phase 2: survey_glm_fit S3 methods
  registerS3method("print",    "surveycore::survey_glm_fit",
                   print.survey_glm_fit,        envir = asNamespace("base"))
  registerS3method("summary",  "surveycore::survey_glm_fit",
                   summary.survey_glm_fit,       envir = asNamespace("base"))
  registerS3method("coef",     "surveycore::survey_glm_fit",
                   coef.survey_glm_fit,          envir = asNamespace("stats"))
  registerS3method("vcov",     "surveycore::survey_glm_fit",
                   vcov.survey_glm_fit,          envir = asNamespace("stats"))
  registerS3method("predict",  "surveycore::survey_glm_fit",
                   predict.survey_glm_fit,       envir = asNamespace("stats"))
  registerS3method("fitted",   "surveycore::survey_glm_fit",
                   fitted.survey_glm_fit,        envir = asNamespace("stats"))
  registerS3method("residuals","surveycore::survey_glm_fit",
                   residuals.survey_glm_fit,     envir = asNamespace("stats"))
  registerS3method("confint",  "surveycore::survey_glm_fit",
                   confint.survey_glm_fit,       envir = asNamespace("stats"))
  registerS3method("formula",  "surveycore::survey_glm_fit",
                   formula.survey_glm_fit,       envir = asNamespace("stats"))
  registerS3method("terms",    "surveycore::survey_glm_fit",
                   terms.survey_glm_fit,         envir = asNamespace("stats"))
  registerS3method("model.matrix", "surveycore::survey_glm_fit",
                   model.matrix.survey_glm_fit,  envir = asNamespace("stats"))
  registerS3method("model.frame",  "surveycore::survey_glm_fit",
                   model.frame.survey_glm_fit,   envir = asNamespace("stats"))
  registerS3method("deviance",     "surveycore::survey_glm_fit",
                   deviance.survey_glm_fit,      envir = asNamespace("stats"))
  registerS3method("df.residual",  "surveycore::survey_glm_fit",
                   df.residual.survey_glm_fit,   envir = asNamespace("stats"))
  registerS3method("nobs",         "surveycore::survey_glm_fit",
                   nobs.survey_glm_fit,          envir = asNamespace("stats"))
  registerS3method("hatvalues",    "surveycore::survey_glm_fit",
                   hatvalues.survey_glm_fit,     envir = asNamespace("stats"))
  registerS3method("logLik",       "surveycore::survey_glm_fit",
                   logLik.survey_glm_fit,        envir = asNamespace("stats"))
  registerS3method("AIC",          "surveycore::survey_glm_fit",
                   AIC.survey_glm_fit,           envir = asNamespace("stats"))
  registerS3method("BIC",          "surveycore::survey_glm_fit",
                   BIC.survey_glm_fit,           envir = asNamespace("stats"))
  registerS3method("update",       "surveycore::survey_glm_fit",
                   update.survey_glm_fit,        envir = asNamespace("stats"))
  registerS3method("getCall",      "surveycore::survey_glm_fit",
                   getCall.survey_glm_fit,       envir = asNamespace("stats"))

  # Phase 2: broom compatibility (conditional)
  if (requireNamespace("broom", quietly = TRUE)) {
    registerS3method("tidy", "surveycore::survey_glm_fit",
                     tidy.survey_glm_fit,
                     envir = asNamespace("broom"))
  }
}
# nocov end
