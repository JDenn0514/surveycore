# R/utils.R
#
# Utility functions used across two or more source files.
# Single-use helpers live at the top of their respective source files.
# See .claude/rules/code-style.md Section 4 for placement rules.
#
# Note: .update_design_var_names() and .rename_metadata_keys() live in
# R/02-validators.R because they were first needed by the validator test
# infrastructure and are co-located with their associated validation logic.


# ── .glm_confint() ────────────────────────────────────────────────────────────
#
# Shared CI helper for survey_glm_fit. Called by both confint.survey_glm_fit()
# (in glm-methods.R) and clean() (in glm-clean.R). Single implementation
# guarantees numerical identity between the two callers.
#
# Formula: estimate ± qt((1 + level) / 2, df = degf_design - (n_coef - 1)) * se
#
# @param estimates   Named numeric vector of coefficient estimates.
# @param se          Numeric vector of standard errors (same length).
# @param degf_design Design degrees of freedom (model@degf). Finite value.
# @param n_coef      Total number of coefficients p = length(estimates).
# @param level       Confidence level in (0, 1). Validated upstream.
# @param parm        Character or integer index to subset; NULL = all.
# @return Two-column numeric matrix with columns "lower" and "upper".
#' @noRd
.glm_confint <- function(estimates, se, degf_design, n_coef, level,
                          parm = NULL) {
  if (!is.null(parm)) {
    estimates <- estimates[parm]
    se        <- se[parm]
  }
  df_res <- max(1, degf_design - (n_coef - 1L))
  half_w <- stats::qt((1 + level) / 2, df = df_res) * se
  matrix(
    c(estimates - half_w, estimates + half_w),
    ncol      = 2L,
    dimnames  = list(names(estimates), c("lower", "upper"))
  )
}


# ── Exported accessor ─────────────────────────────────────────────────────────

#' Access the Data Component of a Survey Design Object
#'
#' Returns the underlying data frame stored in a survey design object.
#' This is a thin accessor for `x@data` that provides a stable public name
#' independent of the S7 property structure.
#'
#' @param x A `survey_taylor`, `survey_replicate`, or `survey_twophase` object.
#' @return A `data.frame` with all variables, including design variables.
#' @examples
#' d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
#'                strata = sdmvstra, nest = TRUE)
#' head(survey_data(d))
#' @family constructors
#' @export
survey_data <- function(x) {
  if (!S7::S7_inherits(x, survey_base)) {
    cli::cli_abort(
      c(
        "x" = "{.arg x} must be a survey design object.",
        "i" = "Got {.cls {class(x)[[1L]]}}."
      ),
      class = "surveycore_error_not_survey_object"
    )
  }
  x@data
}


#' Extract the Weighting History from a Survey Object
#'
#' Returns the list of weighting operations recorded on a survey design object.
#' Each entry is appended by surveywts after a calibration or nonresponse
#' adjustment step. Returns an empty list when no history has been recorded.
#'
#' @param x A survey design object (any class inheriting from `survey_base`).
#' @return A `list` of history entries, or `list()` if no history is present.
#'
#' @examples
#' d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
#'                strata = sdmvstra, nest = TRUE)
#' survey_weighting_history(d)   # list() — no weighting history
#'
#' @family metadata
#' @export
survey_weighting_history <- function(x) {
  if (!S7::S7_inherits(x, survey_base)) {
    cli::cli_abort(
      c(
        "x" = "{.arg x} must be a survey design object.",
        "i" = "Got {.cls {class(x)[[1L]]}}."
      ),
      class = "surveycore_error_not_survey_object"
    )
  }
  x@metadata@weighting_history
}


# ── Exported constants ────────────────────────────────────────────────────────

#' Internal Domain Column Name Constant
#'
#' The name of the logical column added to `@data` by `filter()` (from
#' `surveytidy`) to mark domain membership. Exposed here so that sibling
#' packages (`surveytidy`, `surveywts`) can reference it without
#' using `:::`.
#'
#' @keywords internal
#' @export
SURVEYCORE_DOMAIN_COL <- "..surveycore_domain.."


# ── Internal constants ────────────────────────────────────────────────────────

# Name of the synthetic weight column added to @data when the user supplies
# neither weights nor probs (SRS fallback) or when probs are converted to
# weights internally. Using a named constant prevents typos and makes a
# sentinel rename safe.
.SURVEYCORE_WT_COL <- "..surveycore_wt.."


# ── Internal tidy-select resolvers ───────────────────────────────────────────

# Resolve a tidy-select quosure against a data frame.
# Returns a character vector of selected column names, or NULL when expr is a
# NULL quosure. Count validation is left to callers — error classes differ by
# argument (weights, strata, fpc, etc.).
# Used by constructors and by surveytidy dplyr verbs.
#
# @param expr  A quosure (from rlang::enquo()). NULL quosure → returns NULL.
# @param data  A data.frame to evaluate the selection against.
# @return Character vector of column names, or NULL.
#' @noRd
.resolve_tidy_select <- function(expr, data) {
  if (rlang::quo_is_null(expr)) return(NULL)
  names(tidyselect::eval_select(expr, data))
}

# Resolve a tidy-select quosure that must select EXACTLY ONE column.
# Returns the single column name on success, or NULL if expr is a NULL
# quosure (i.e., the argument was omitted / defaulted to NULL).
#
# Fires typed errors when 0 or > 1 columns are selected, so callers can
# pass argument-specific error classes rather than inlining the 12-line
# boilerplate for every single-column argument.
#
# @param expr        A quosure (from rlang::enquo()).
# @param data        A data.frame to evaluate the selection against.
# @param arg_nm      Character(1). Argument name shown in error messages.
# @param required    Logical(1). If TRUE, a NULL quosure → abort (missing).
#                    If FALSE (default), a NULL quosure → return NULL.
# @param class_none  Error class when 0 columns selected.
# @param class_multi Error class when > 1 column selected.
# @return Character(1) column name, or NULL.
#' @noRd
.resolve_single_col <- function(
  expr,
  data,
  arg_nm,
  required    = FALSE,
  class_none  = "surveycore_error_design_var_missing",
  class_multi = "surveycore_error_design_var_missing",
  call        = rlang::caller_call()
) {
  if (rlang::quo_is_null(expr)) {
    if (required) {
      cli::cli_abort(
        c("x" = "{.arg {arg_nm}} is required but was not provided."),
        class = class_none,
        call  = call
      )
    }
    return(NULL)
  }

  cols <- tidyselect::eval_select(expr, data)

  if (length(cols) == 0L) {
    cli::cli_abort(
      c("x" = "{.arg {arg_nm}} matched no columns in {.arg data}"),
      class = class_none,
      call  = call
    )
  }

  if (length(cols) > 1L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg {arg_nm}} must select exactly one column, ",
          "not {length(cols)}"
        )
      ),
      class = class_multi,
      call  = call
    )
  }

  names(cols)
}


# ── Internal design-variable helpers ─────────────────────────────────────────

# Return a flat character vector of all design-variable column names.
# NULL entries are dropped by c(). Unique names are returned.
# Works for all five survey types: survey_taylor, survey_replicate,
# survey_twophase, survey_calibrated, and survey_srs.
# Used by conversion methods (05-methods-conversion.R), variance
# estimation (06-variance-dispatch.R), and surveytidy verbs.
# Exported (with @export) so surveytidy can call surveycore::.get_design_vars_flat()
# without needing :::. The . prefix is intentional — this is not part of
# the public user-facing API.
#' @keywords internal
#' @export
.get_design_vars_flat <- function(design) {
  if (S7::S7_inherits(design, survey_taylor)) {
    unique(c(
      design@variables$ids,
      design@variables$weights,
      design@variables$strata,
      design@variables$fpc
    ))
  } else if (S7::S7_inherits(design, survey_replicate)) {
    unique(c(
      design@variables$weights,
      design@variables$repweights
    ))
  } else if (S7::S7_inherits(design, survey_twophase)) {
    p1      <- design@variables$phase1
    p2      <- design@variables$phase2
    p2_cols <- if (!is.null(p2)) {
      unlist(p2[!vapply(p2, is.null, logical(1L))], use.names = FALSE)
    } else {
      character(0L) # nocov — p2 is always a list (as_survey_twophase() and .from_svydesign_twophase() both initialize it)
    }
    unique(c(
      p1$ids, p1$weights, p1$strata, p1$fpc,
      p2_cols,
      design@variables$subset
    ))
  } else if (S7::S7_inherits(design, survey_calibrated)) {
    unique(c(design@variables$weights))
  } else if (S7::S7_inherits(design, survey_srs)) {
    unique(c(design@variables$weights, design@variables$fpc))
  } else {
    character(0L) # nocov — defensive: all known types handled above
  }
}

# Return a named list mapping slot names to column name(s).
# Slots whose value is NULL are omitted from the result.
# unlist()ing the result gives all design variable names.
# Used by surveytidy dplyr verbs (rename, select) for slot-level granularity
# and by conversion methods to identify which role each column plays.
#' @noRd
.get_design_vars <- function(design) {
  if (S7::S7_inherits(design, survey_taylor)) {
    Filter(
      Negate(is.null),
      list(
        ids     = design@variables$ids,
        weights = design@variables$weights,
        strata  = design@variables$strata,
        fpc     = design@variables$fpc
      )
    )
  } else if (S7::S7_inherits(design, survey_replicate)) {
    Filter(
      Negate(is.null),
      list(
        weights    = design@variables$weights,
        repweights = design@variables$repweights
      )
    )
  } else if (S7::S7_inherits(design, survey_twophase)) {
    p1  <- design@variables$phase1
    p2  <- design@variables$phase2
    raw <- list(
      ids     = p1$ids,
      weights = p1$weights,
      strata  = p1$strata,
      fpc     = p1$fpc,
      ids2    = if (!is.null(p2)) p2$ids    else NULL,
      strata2 = if (!is.null(p2)) p2$strata else NULL,
      probs2  = if (!is.null(p2)) p2$probs  else NULL,
      fpc2    = if (!is.null(p2)) p2$fpc    else NULL,
      subset  = design@variables$subset
    )
    Filter(Negate(is.null), raw)
  } else if (S7::S7_inherits(design, survey_calibrated)) {
    Filter(
      Negate(is.null),
      list(weights = design@variables$weights)
    )
  } else if (S7::S7_inherits(design, survey_srs)) {
    Filter(
      Negate(is.null),
      list(
        weights = design@variables$weights,
        fpc     = design@variables$fpc
      )
    )
  } else {
    list() # nocov — defensive: all known types handled above
  }
}


# ── Internal: weighting history promotion ────────────────────────────────────

# Promote a weighting_history attribute from a data frame to a metadata object.
# Called by constructors that accept a raw data frame (as_survey_srs,
# as_survey, as_survey_repweights). Returns the metadata object unchanged when the
# attribute is absent or is not a non-empty list.
#
# @param data     A data.frame (may or may not have "weighting_history" attr).
# @param metadata A survey_metadata object (already populated by
#                 .extract_haven_metadata()).
# @return The survey_metadata object, with @weighting_history set if present.
#' @noRd
.promote_weighting_history <- function(data, metadata) {
  history <- attr(data, "weighting_history", exact = TRUE)
  if (is.list(history) && length(history) > 0L) {
    metadata@weighting_history <- history
  }
  metadata
}
