# R/07-utils.R
#
# Utility functions used across two or more source files.
# Single-use helpers live at the top of their respective source files.
# See .claude/rules/code-style.md Section 4 for placement rules.
#
# Note: .update_design_var_names() and .rename_metadata_keys() live in
# R/02-validators.R because they were first needed by the validator test
# infrastructure and are co-located with their associated validation logic.


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


# ── Exported constants ────────────────────────────────────────────────────────

#' Internal Domain Column Name Constant
#'
#' The name of the logical column added to `@data` by `filter()` (from
#' `surveytidy`) to mark domain membership. Exposed here so that sibling
#' packages (`surveytidy`, `surveyweights`) can reference it without
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
# Works for survey_taylor, survey_replicate, and survey_twophase.
# Used by conversion methods (05-methods-conversion.R), variance
# estimation (06-variance-estimation.R), and surveytidy verbs.
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
  } else {
    list() # nocov — defensive: all known types handled above
  }
}
