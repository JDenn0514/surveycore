# R/05-methods-conversion.R
#
# Conversion functions between surveycore S7 objects and the survey/srvyr
# package design objects.
#
# Step 11 (feature/conversion-to-survey):   as_svydesign(), as_tbl_svy()
# Step 12 (feature/conversion-from-survey): from_svydesign(), from_tbl_svy()
#
# Both directions require the external package to be installed.
# Errors use surveycore_error_pkg_not_installed when the package is absent.


# ── Internal helpers ──────────────────────────────────────────────────────────

# Build a one-sided formula from a character vector of column names.
# Returns NULL when vars is NULL or length-0.
# Examples:
#   c("psu", "ssu") → ~ psu + ssu
#   "strata"        → ~ strata
#   NULL            → NULL
#' @noRd
.to_formula <- function(vars) {
  if (is.null(vars) || length(vars) == 0L) return(NULL)
  stats::reformulate(vars)
}


# ── as_svydesign ──────────────────────────────────────────────────────────────

#' Convert a surveycore Design Object to a survey Package Design
#'
#' Converts a `survey_taylor`, `survey_replicate`, or `survey_twophase` object
#' to the corresponding `survey` package object: `svydesign`, `svrepdesign`,
#' or `twophase`. Useful for accessing `survey` package estimation functions
#' or for round-trip testing.
#'
#' Metadata (variable labels, value labels) is NOT carried over — the `survey`
#' package has no metadata system.
#'
#' @param x A `survey_taylor`, `survey_replicate`, or `survey_twophase` object.
#' @return A `survey::svydesign`, `survey::svrepdesign`, or `survey::twophase`
#'   object.
#'
#' @examples
#' df <- data.frame(
#'   id  = 1:20,
#'   wt  = runif(20, 0.5, 2),
#'   st  = rep(c("A", "B"), 10),
#'   y   = rnorm(20)
#' )
#' d <- as_survey(df, weights = wt, strata = st)
#' if (requireNamespace("survey", quietly = TRUE)) {
#'   sv <- as_svydesign(d)
#'   survey::svymean(~y, sv)
#' }
#'
#' @seealso `from_svydesign()` to convert back from a `survey` design
#'   (implemented in step 12)
#' @family conversion
#' @export
as_svydesign <- function(x) {
  if (!requireNamespace("survey", quietly = TRUE)) {
    # nocov start
    cli::cli_abort(
      c(
        "x" = "{.pkg survey} must be installed to use {.fn as_svydesign}.",
        "v" = "Install it with {.code install.packages(\"survey\")}."
      ),
      class = "surveycore_error_pkg_not_installed"
    )
    # nocov end
  }

  if (S7::S7_inherits(x, survey_taylor)) {
    .as_svydesign_taylor(x)
  } else if (S7::S7_inherits(x, survey_replicate)) {
    .as_svydesign_replicate(x)
  } else if (S7::S7_inherits(x, survey_twophase)) {
    .as_svydesign_twophase(x)
  } else {
    cli::cli_abort(
      c(
        "x" = "{.arg x} must be a survey design object.",
        "i" = "Got {.cls {class(x)[[1L]]}}."
      ),
      class = "surveycore_error_not_survey_object"
    )
  }
}


# survey_taylor → survey::svydesign
#' @noRd
.as_svydesign_taylor <- function(x) {
  ids_var     <- x@variables$ids
  strata_var  <- x@variables$strata
  weights_var <- x@variables$weights
  fpc_var     <- x@variables$fpc

  ids_formula <- if (!is.null(ids_var) && length(ids_var) > 0L) {
    .to_formula(ids_var)
  } else {
    ~1
  }

  survey::svydesign(
    ids     = ids_formula,
    strata  = .to_formula(strata_var),
    weights = .to_formula(weights_var),
    fpc     = .to_formula(fpc_var),
    data    = x@data,
    nest    = isTRUE(x@variables$nest)
  )
}


# survey_replicate → survey::svrepdesign
#' @noRd
.as_svydesign_replicate <- function(x) {
  wts_var  <- x@variables$weights
  rep_vars <- x@variables$repweights
  fpc_var  <- x@variables$fpc
  fpctype  <- if (!is.null(x@variables$fpctype)) x@variables$fpctype else "fraction"

  # BRR and Fay do not use a separate scale factor — survey::svrepdesign()
  # warns if scale is passed for those types.
  scale_arg <- if (isTRUE(x@variables$type %in% c("BRR", "Fay"))) {
    NULL
  } else {
    x@variables$scale
  }

  survey::svrepdesign(
    weights    = x@data[[wts_var]],
    repweights = x@data[, rep_vars, drop = FALSE],
    type       = x@variables$type,
    scale      = scale_arg,
    rscales    = x@variables$rscales,
    mse        = isTRUE(x@variables$mse),
    fpc        = if (!is.null(fpc_var)) x@data[[fpc_var]] else NULL,
    fpctype    = fpctype,
    data       = x@data
  )
}


# survey_twophase → survey::twophase
#' @noRd
.as_svydesign_twophase <- function(x) {
  p1         <- x@variables$phase1
  p2         <- x@variables$phase2
  subset_var <- x@variables$subset
  method     <- if (!is.null(x@variables$method)) x@variables$method else "full"

  # Phase 1 formulas
  p1_id      <- if (!is.null(p1$ids) && length(p1$ids) > 0L) {
    .to_formula(p1$ids)
  } else {
    ~1
  }
  p1_strata  <- .to_formula(p1$strata)
  p1_weights <- .to_formula(p1$weights)
  p1_fpc     <- .to_formula(p1$fpc)

  # Phase 2 formulas (usually NULL or ~1 for simple cases)
  p2_id     <- if (!is.null(p2) && !is.null(p2$ids) && length(p2$ids) > 0L) {
    .to_formula(p2$ids)
  } else {
    ~1
  }
  p2_strata <- if (!is.null(p2)) .to_formula(p2$strata) else NULL
  p2_fpc    <- if (!is.null(p2)) .to_formula(p2$fpc)    else NULL

  # method="full" derives phase 2 weights from the phase 1 design and rejects
  # an explicit weights argument.  For "simple" and "approx" we pass phase 1
  # weights so survey can compute the probability-weighted estimates.
  weights_arg <- if (method == "full") NULL else list(p1_weights, NULL)

  survey::twophase(
    id      = list(p1_id,     p2_id),
    strata  = list(p1_strata, p2_strata),
    weights = weights_arg,
    fpc     = list(p1_fpc,    p2_fpc),
    data    = x@data,
    subset  = .to_formula(subset_var),
    method  = method
  )
}


# ── as_tbl_svy ────────────────────────────────────────────────────────────────

#' Convert a surveycore Design Object to an srvyr tbl_svy
#'
#' Converts a surveycore design object to an `srvyr` `tbl_svy` by first
#' converting to a `survey` design via [as_svydesign()] and then wrapping
#' with `srvyr::as_survey()`. Requires both `survey` and `srvyr`.
#'
#' Metadata (variable labels, value labels) is NOT carried over.
#'
#' @param x A `survey_taylor`, `survey_replicate`, or `survey_twophase` object.
#' @return A `srvyr::tbl_svy` object.
#'
#' @examples
#' df <- data.frame(y = rnorm(20), w = runif(20, 0.5, 2))
#' d  <- as_survey(df, weights = w)
#' if (requireNamespace("survey", quietly = TRUE) &&
#'     requireNamespace("srvyr",  quietly = TRUE)) {
#'   ts <- as_tbl_svy(d)
#' }
#'
#' @seealso `from_tbl_svy()` to convert back from a `tbl_svy` object
#'   (implemented in step 12)
#' @family conversion
#' @export
as_tbl_svy <- function(x) {
  if (!requireNamespace("survey", quietly = TRUE)) {
    # nocov start
    cli::cli_abort(
      c(
        "x" = "{.pkg survey} must be installed to use {.fn as_tbl_svy}.",
        "v" = "Install it with {.code install.packages(\"survey\")}."
      ),
      class = "surveycore_error_pkg_not_installed"
    )
    # nocov end
  }
  if (!requireNamespace("srvyr", quietly = TRUE)) {
    # nocov start
    cli::cli_abort(
      c(
        "x" = "{.pkg srvyr} must be installed to use {.fn as_tbl_svy}.",
        "v" = "Install it with {.code install.packages(\"srvyr\")}."
      ),
      class = "surveycore_error_pkg_not_installed"
    )
    # nocov end
  }

  if (!S7::S7_inherits(x, survey_base)) {
    cli::cli_abort(
      c(
        "x" = "{.arg x} must be a survey design object.",
        "i" = "Got {.cls {class(x)[[1L]]}}."
      ),
      class = "surveycore_error_not_survey_object"
    )
  }

  srvyr::as_survey(as_svydesign(x))
}
