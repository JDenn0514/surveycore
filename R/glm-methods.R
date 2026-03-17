# R/glm-methods.R
#
# Phase 2: S3 methods on survey_glm_fit
#
# All methods are registered in R/zzz.R via registerS3method() in .onLoad().
# S3 dispatch does not work for S7 objects via UseMethod(); dynamic
# registration is required (same pattern as surveytidy dplyr verbs).
#
# Methods in this file (20 + getCall + print.survey_glm_summary):
#   print, summary, coef, vcov, predict, fitted, residuals, confint,
#   formula, terms, model.matrix, model.frame, deviance, df.residual,
#   nobs, hatvalues, logLik, AIC, BIC, update, getCall
#
# Spec: plans/spec-phase-2.md §V


# ── Internal helper: .glm_design_type_label() ─────────────────────────────────
#
# Returns the display label for the design type in print/summary output.
#
# @param fit A survey_glm_fit object.
# @return Character string for display, e.g. "Taylor series".
#' @noRd
.glm_design_type_label <- function(fit) {
  d <- fit@design
  if (S7::S7_inherits(d, survey_taylor))           "Taylor series"
  else if (S7::S7_inherits(d, survey_replicate))   "Replicate weights"
  else if (S7::S7_inherits(d, survey_twophase))    "Two-phase"
  else if (S7::S7_inherits(d, survey_nonprob))  "Calibrated"
  else "Unknown"
}

# ── Internal helper: .glm_design_type_string() ────────────────────────────────
#
# Returns the short design_type string matching Phase 1 .build_meta().
#
# @param design A survey_base object.
# @return One of "taylor", "replicate", "twophase", "calibrated".
#' @noRd
.glm_design_type_string <- function(design) {
  if (S7::S7_inherits(design, survey_taylor))           "taylor"
  else if (S7::S7_inherits(design, survey_replicate))   "replicate"
  else if (S7::S7_inherits(design, survey_twophase))    "twophase"
  else if (S7::S7_inherits(design, survey_nonprob))  "calibrated"
  else "unknown"
}

# ── Internal helper: .glm_check_fit_ ──────────────────────────────────────────
#
# Throw surveycore_error_predict_no_fit if fit_ is NULL.
#
# @param object A survey_glm_fit.
#' @noRd
.glm_check_fit_ <- function(object, fn_name = "predict") {
  if (is.null(object@fit_)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "The internal {.field fit_} slot is NULL. ",
          "This can happen after serialization."
        ),
        "v" = "Refit the model to restore prediction support."
      ),
      class = "surveycore_error_predict_no_fit"
    )
  }
}


# ===========================================================================
# 5.1  print.survey_glm_fit
# ===========================================================================

#' @noRd
print.survey_glm_fit <- function(x, digits = 4, ...) {
  fam_name <- x@family$family
  lnk_name <- x@family$link
  dgf      <- format(round(x@degf))
  dtype    <- .glm_design_type_label(x)

  cat("Survey-weighted GLM\n\n")
  cat(sprintf("Family:  %s (%s link)\n", fam_name, lnk_name))
  cat(sprintf("Formula: %s\n",
              deparse(x@formula, width.cutoff = 500L)))
  cat(sprintf("Design:  %s\n\n", dtype))

  cat("Coefficients:\n")
  coef_fmt <- format(round(x@coefficients, digits), nsmall = digits)
  print(coef_fmt, quote = FALSE)

  cat(sprintf("\nDegrees of freedom: %s (design-based)\n", dgf))

  invisible(x)
}


# ===========================================================================
# 5.2  summary.survey_glm_fit + survey_glm_summary + print.survey_glm_summary
# ===========================================================================

#' @noRd
summary.survey_glm_fit <- function(object, ...) {
  .glm_check_fit_(object, "summary")

  p  <- length(object@coefficients)
  se <- sqrt(diag(object@vcov))

  df_design_resid <- max(1, object@degf - (p - 1L))
  tval <- object@coefficients / se
  pval <- 2 * stats::pt(-abs(tval), df = df_design_resid)

  coef_mat <- cbind(
    "Estimate"   = object@coefficients,
    "Std. Error" = se,
    "t value"    = tval,
    "Pr(>|t|)"   = pval
  )
  rownames(coef_mat) <- names(object@coefficients)

  # Dispersion: from the underlying glm summary (correct for all families)
  disp <- summary(object@fit_)$dispersion

  # Deviance residuals (5-number summary): fivenum of deviance residuals from fit_
  dev_res_5 <- stats::fivenum(
    stats::residuals(object@fit_, type = "deviance")
  )
  names(dev_res_5) <- c("Min", "1Q", "Median", "3Q", "Max")

  # AIC from the underlying glm fit
  aic_val <- stats::AIC(object@fit_)

  structure(
    list(
      coefficients      = coef_mat,
      deviance          = object@deviance,
      null_deviance     = object@null_deviance,
      df_residual       = object@df_residual,
      df_null           = object@df_null,
      dispersion        = disp,
      family            = object@family,
      call              = object@call,
      design_type       = .glm_design_type_string(object@design),
      degf              = object@degf,
      deviance_residuals = dev_res_5,  # for print.survey_glm_summary
      aic               = aic_val      # for print.survey_glm_summary
    ),
    class = "survey_glm_summary"
  )
}


#' @noRd
print.survey_glm_summary <- function(x, digits = 4, signif.stars = TRUE, ...) {
  cat("Survey-weighted GLM\n\n")

  if (!is.null(x$call)) {
    cat("Call:\n")
    cat(deparse(x$call, width.cutoff = 500L), "\n\n")
  }

  cat("Deviance Residuals:\n")
  dev_fmt <- format(round(x$deviance_residuals, 4L), nsmall = 4L, width = 8L)
  print(dev_fmt, quote = FALSE)
  cat("\n")

  cat("Coefficients:\n")
  cmat <- x$coefficients
  if (signif.stars) {
    stars <- stats::symnum(
      cmat[, "Pr(>|t|)"],
      corr      = FALSE,
      na        = FALSE,
      cutpoints = c(0, 0.001, 0.01, 0.05, 0.1, 1),
      symbols   = c("***", "**", "*", ".", " ")
    )
    cmat_print <- cbind(
      format(round(cmat, digits), nsmall = digits),
      " " = format(stars)
    )
  } else {
    cmat_print <- format(round(cmat, digits), nsmall = digits)
  }
  print(cmat_print, quote = FALSE)

  if (signif.stars) {
    cat("---\n")
    cat(
      "Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1\n\n"
    )
  } else {
    cat("\n")
  }

  fam_name <- x$family$family
  cat(sprintf(
    "(Dispersion parameter for %s family taken to be %s)\n\n",
    fam_name,
    format(x$dispersion, digits = max(4L, digits))
  ))

  cat(sprintf(
    "    Null deviance: %s on %d degrees of freedom\n",
    format(x$null_deviance, digits = max(4L, digits)),
    as.integer(x$df_null)
  ))
  cat(sprintf(
    "Residual deviance: %s on %d degrees of freedom\n",
    format(x$deviance, digits = max(4L, digits)),
    as.integer(x$df_residual)
  ))
  cat(sprintf("AIC: %s\n\n", format(x$aic, digits = max(4L, digits))))
  cat(sprintf("Design df: %d (%s)\n",
              as.integer(round(x$degf)), x$design_type))

  invisible(x)
}


# ===========================================================================
# 5.3  coef.survey_glm_fit
# ===========================================================================

#' @noRd
coef.survey_glm_fit <- function(object, ...) {
  object@coefficients
}


# ===========================================================================
# 5.4  vcov.survey_glm_fit
# ===========================================================================

#' @noRd
vcov.survey_glm_fit <- function(object, ...) {
  object@vcov
}


# ===========================================================================
# 5.5  predict.survey_glm_fit
# ===========================================================================

#' @noRd
predict.survey_glm_fit <- function(object, new_data = NULL, type = "response",
                                    se_fit = FALSE, na_action = stats::na.pass,
                                    ...) {
  .glm_check_fit_(object, "predict")

  result <- stats::predict.glm(
    object@fit_,
    newdata   = new_data,
    type      = type,
    se.fit    = se_fit,
    na.action = na_action,
    ...
  )

  # When se_fit = TRUE, rename components to snake_case per spec §5.5
  if (se_fit && is.list(result)) {
    names(result)[names(result) == "se.fit"]         <- "se_fit"
    names(result)[names(result) == "residual.scale"] <- "residual_scale"
  }

  result
}


# ===========================================================================
# 5.6  fitted.survey_glm_fit
# ===========================================================================

#' @noRd
fitted.survey_glm_fit <- function(object, ...) {
  object@fitted_values
}


# ===========================================================================
# 5.7  residuals.survey_glm_fit
# ===========================================================================

#' @noRd
residuals.survey_glm_fit <- function(object, type = "response", ...) {
  if (type == "working") {
    return(object@residuals)
  }

  .glm_check_fit_(object, "residuals")

  if (type == "response") {
    y <- stats::model.response(stats::model.frame(object@fit_))
    return(as.numeric(y - object@fitted_values))
  }

  # "pearson", "deviance", "partial" — delegate to fit_
  stats::residuals(object@fit_, type = type, ...)
}


# ===========================================================================
# 5.8  confint.survey_glm_fit
# ===========================================================================

#' @noRd
confint.survey_glm_fit <- function(object, parm, level = 0.95, ...) {
  if (!is.numeric(level) || length(level) != 1L ||
      is.na(level) || level <= 0 || level >= 1) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg conf_level} must be a single number strictly between 0 and 1.",
          " Got {.val {level}}."
        )
      ),
      class = "surveycore_error_invalid_conf_level"
    )
  }

  parm_arg <- if (missing(parm)) NULL else parm

  se <- sqrt(diag(object@vcov))
  ci <- .glm_confint(
    estimates   = object@coefficients,
    se          = se,
    degf_design = object@degf,
    n_coef      = length(object@coefficients),
    level       = level,
    parm        = parm_arg
  )

  # Rename columns from "lower"/"upper" to standard R convention, e.g. "2.5 %"
  pct_lo <- paste0(100 * (1 - level) / 2, " %")
  pct_hi <- paste0(100 * (1 + level) / 2, " %")
  colnames(ci) <- c(pct_lo, pct_hi)
  ci
}


# ===========================================================================
# 5.9  formula.survey_glm_fit
# ===========================================================================

#' @noRd
formula.survey_glm_fit <- function(x, ...) {
  x@formula
}


# ===========================================================================
# 5.10  terms.survey_glm_fit
# ===========================================================================

#' @noRd
terms.survey_glm_fit <- function(x, ...) {
  .glm_check_fit_(x, "terms")
  stats::terms(x@fit_, ...)
}


# ===========================================================================
# 5.11  model.matrix.survey_glm_fit
# ===========================================================================

#' @noRd
model.matrix.survey_glm_fit <- function(object, ...) {
  .glm_check_fit_(object, "model.matrix")
  stats::model.matrix(object@fit_, ...)
}


# ===========================================================================
# 5.12  model.frame.survey_glm_fit
# ===========================================================================

#' @noRd
model.frame.survey_glm_fit <- function(formula, ...) {
  # First argument is named `formula` per base R model.frame generic convention.
  .glm_check_fit_(formula, "model.frame")
  stats::model.frame(formula@fit_, ...)
}


# ===========================================================================
# 5.13  deviance.survey_glm_fit
# ===========================================================================

#' @noRd
deviance.survey_glm_fit <- function(object, ...) {
  object@deviance
}


# ===========================================================================
# 5.14  df.residual.survey_glm_fit
# ===========================================================================

#' @noRd
df.residual.survey_glm_fit <- function(object, ...) {
  object@df_residual
}


# ===========================================================================
# 5.15  nobs.survey_glm_fit
# ===========================================================================

#' @noRd
nobs.survey_glm_fit <- function(object, ...) {
  length(object@fitted_values)
}


# ===========================================================================
# 5.16  hatvalues.survey_glm_fit
# ===========================================================================

#' @noRd
hatvalues.survey_glm_fit <- function(model, ...) {
  .glm_check_fit_(model, "hatvalues")
  stats::hatvalues(model@fit_, ...)
}


# ===========================================================================
# 5.17  logLik.survey_glm_fit
# ===========================================================================

#' @noRd
logLik.survey_glm_fit <- function(object, ...) {
  .glm_check_fit_(object, "logLik")
  stats::logLik(object@fit_, ...)
}


# ===========================================================================
# 5.18  AIC.survey_glm_fit / BIC.survey_glm_fit
# ===========================================================================

#' @noRd
AIC.survey_glm_fit <- function(object, ..., k = 2) {
  .glm_check_fit_(object, "AIC")
  stats::AIC(object@fit_, ..., k = k)
}

#' @noRd
BIC.survey_glm_fit <- function(object, ...) {
  .glm_check_fit_(object, "BIC")
  stats::BIC(object@fit_, ...)
}


# ===========================================================================
# 5.19  update.survey_glm_fit / getCall.survey_glm_fit
# ===========================================================================

#' @noRd
getCall.survey_glm_fit <- function(x, ...) {
  x@call
}

#' @noRd
update.survey_glm_fit <- function(object, formula., ...) {
  # Replicate update.default() logic but eval in the frame that called update(),
  # not in update.default()'s parent.frame() (which would be our frame here).
  # stats::update.default() cannot be called directly because its parent.frame()
  # would be this function's frame, not the user's frame where 'design' lives.
  call <- getCall.survey_glm_fit(object)
  if (is.null(call)) {
    cli::cli_abort(
      c("x" = "Cannot update: {.arg object@call} is NULL."),
      class = "surveycore_error_predict_no_fit"
    )
  }
  extras <- match.call(expand.dots = FALSE)$...
  if (!missing(formula.)) {
    call[[2L]] <- stats::update.formula(stats::formula(object), formula.)
  }
  if (length(extras)) {
    existing <- !is.na(match(names(extras), names(call)))
    for (a in names(extras)[existing]) call[[a]] <- extras[[a]]
    if (any(!existing)) {
      call <- c(as.list(call), extras[!existing])
      call <- as.call(call)
    }
  }
  eval(call, parent.frame())
}
