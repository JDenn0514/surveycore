# ---------------------------------------------------------------------------
# R/06-variance-dispatch.R
# ---------------------------------------------------------------------------
# Public estimation API: .validate_estimation_input(), get_means(),
# get_totals(). surveycore-original code.
# ---------------------------------------------------------------------------

# ===========================================================================
# Section 4: Public estimation stubs (Phase 0)
# ===========================================================================

# Shared input validation for all get_*() estimation functions.
# Checks: design is a survey_base subclass, not twophase, variable exists,
# variable is numeric. Returns invisible(TRUE) on success.
#' @noRd
.validate_estimation_input <- function(design, var_name) {
  if (!S7::S7_inherits(design, survey_base)) {
    cli::cli_abort(
      c(
        "x" = "{.arg design} must be a surveycore design object.",
        "i" = "Got {.cls {class(design)[[1L]]}}."
      ),
      class = "surveycore_error_not_survey_design"
    )
  }
  if (S7::S7_inherits(design, survey_twophase)) {
    cli::cli_abort(
      c(
        "x" = "Two-phase designs are not yet supported in estimation functions.",
        "i" = "Support for {.cls survey_twophase} will be added in Phase 1."
      ),
      class = "surveycore_error_unsupported_class"
    )
  }
  if (!var_name %in% names(design@data)) {
    cli::cli_abort(
      c(
        "x" = "Variable {.field {var_name}} not found in the survey data.",
        "i" = "Available variables: {.field {names(design@data)}}."
      ),
      class = "surveycore_error_var_not_found"
    )
  }
  if (!is.numeric(design@data[[var_name]])) {
    cli::cli_abort(
      c(
        "x" = "Variable {.field {var_name}} must be numeric.",
        "i" = "Got {.cls {class(design@data[[var_name]])}}."
      ),
      class = "surveycore_error_var_not_numeric"
    )
  }
  invisible(TRUE)
}


#' Estimate Weighted Mean for a Survey Design
#'
#' Computes the weighted mean and its standard error for a single variable
#' using the appropriate variance estimator for the survey design type.
#'
#' @param design A survey design object. Supported classes: [survey_taylor]
#'   (created by [as_survey()]), [survey_replicate] (created by
#'   [as_survey_rep()]), and [survey_calibrated] (created by
#'   [as_survey_calibrated()]). Two-phase designs ([survey_twophase]) are
#'   not yet supported.
#' @param var <[`tidy-select`][tidyselect::language]> A single unquoted
#'   variable name to estimate the mean of.
#' @param na.rm Logical. If `TRUE` (default), missing values are excluded
#'   before computing the mean. Set to `FALSE` to propagate `NA`.
#'
#' @section Variance estimation by design type:
#' \describe{
#'   \item{`survey_taylor`}{Taylor series linearization.}
#'   \item{`survey_replicate`}{Replicate-weight variance estimator.}
#'   \item{`survey_calibrated`}{SRS-based (model-assisted) variance.
#'     Standard errors assume simple random sampling within the calibrated
#'     weights. This is consistent with common practice for raked
#'     non-probability samples but may understate uncertainty. Full
#'     bootstrap re-calibration variance will be available in Phase 2.5.}
#' }
#'
#' @return A named list with elements:
#'   \describe{
#'     \item{`variable`}{Character. Name of the estimated variable.}
#'     \item{`mean`}{Numeric. Weighted mean estimate.}
#'     \item{`se`}{Numeric. Standard error of the mean.}
#'   }
#'
#' @examples
#' # NHANES 2017-2018: estimated mean age of U.S. civilian population
#' d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
#'                strata = sdmvstra, nest = TRUE)
#' get_means(d, ridageyr)
#'
#' @family estimation
#' @export
get_means <- function(design, var, na.rm = TRUE) {
  var_name <- rlang::as_name(rlang::ensym(var))
  .validate_estimation_input(design, var_name)

  # survey_replicate → replicate variance
  # survey_srs       → classical SRS variance
  # survey_taylor and survey_calibrated → Taylor series variance
  result <- if (S7::S7_inherits(design, survey_replicate)) {
    .replicate_mean(design, var_name, na.rm = na.rm)
  } else if (S7::S7_inherits(design, survey_srs)) {
    .srs_mean(design, var_name, na.rm = na.rm)
  } else {
    .taylor_mean(design, var_name, na.rm = na.rm)
  }
  list(variable = var_name, mean = result$mean, se = result$se)
}


#' Estimate Weighted Total for a Survey Design
#'
#' Computes the weighted total and its standard error for a single variable
#' using the appropriate variance estimator for the survey design type.
#'
#' @param design A survey design object. Supported classes: [survey_taylor]
#'   (created by [as_survey()]), [survey_replicate] (created by
#'   [as_survey_rep()]), and [survey_calibrated] (created by
#'   [as_survey_calibrated()]). Two-phase designs ([survey_twophase]) are
#'   not yet supported.
#' @param var <[`tidy-select`][tidyselect::language]> A single unquoted
#'   variable name to estimate the total of.
#' @param na.rm Logical. If `TRUE` (default), missing values are excluded
#'   before computing the total. Set to `FALSE` to propagate `NA`.
#'
#' @section Variance estimation by design type:
#' \describe{
#'   \item{`survey_taylor`}{Taylor series linearization.}
#'   \item{`survey_replicate`}{Replicate-weight variance estimator.}
#'   \item{`survey_calibrated`}{SRS-based (model-assisted) variance.
#'     Standard errors assume simple random sampling within the calibrated
#'     weights. This is consistent with common practice for raked
#'     non-probability samples but may understate uncertainty. Full
#'     bootstrap re-calibration variance will be available in Phase 2.5.}
#' }
#'
#' @return A named list with elements:
#'   \describe{
#'     \item{`variable`}{Character. Name of the estimated variable.}
#'     \item{`total`}{Numeric. Weighted total estimate.}
#'     \item{`se`}{Numeric. Standard error of the total.}
#'   }
#'
#' @examples
#' # ACS PUMS Wyoming: estimated total population by age
#' d <- as_survey_rep(acs_pums_wy, weights = pwgtp,
#'                    repweights = pwgtp1:pwgtp80,
#'                    type = "successive-difference")
#' get_totals(d, agep)
#'
#' @family estimation
#' @export
get_totals <- function(design, var, na.rm = TRUE) {
  var_name <- rlang::as_name(rlang::ensym(var))
  .validate_estimation_input(design, var_name)

  # survey_replicate → replicate variance
  # survey_srs       → classical SRS variance
  # survey_taylor and survey_calibrated → Taylor series variance
  result <- if (S7::S7_inherits(design, survey_replicate)) {
    .replicate_total(design, var_name, na.rm = na.rm)
  } else if (S7::S7_inherits(design, survey_srs)) {
    .srs_total(design, var_name, na.rm = na.rm)
  } else {
    .taylor_total(design, var_name, na.rm = na.rm)
  }
  list(variable = var_name, total = result$total, se = result$se)
}
