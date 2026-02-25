# R/09-meta.R
#
# The meta() generic for accessing structured metadata from survey result
# objects, and the print method for survey_result.


# ── meta() generic ────────────────────────────────────────────────────────────

#' Extract Metadata from a Survey Result
#'
#' Retrieves the structured metadata list attached to a survey result object
#' returned by any `get_*()` analysis function.
#'
#' This is the **only** supported way to access result metadata — do not use
#' `attr(result, ".meta")` directly.
#'
#' @param x A `survey_result` object returned by any `get_*()` function.
#' @param ... Currently unused. Reserved for future extensions.
#'
#' @return A named list. Common fields present on every result:
#' \describe{
#'   \item{`design_type`}{Character(1). Design class: `"taylor"`,
#'     `"replicate"`, `"twophase"`, `"srs"`, or `"calibrated"`.}
#'   \item{`conf_level`}{Numeric(1). Confidence level used (e.g. `0.95`).}
#'   \item{`call`}{Language. Matched call to the `get_*()` function.}
#'   \item{`group_names`}{Character vector. Grouping variable names;
#'     `character(0)` if none.}
#'   \item{`group_labels`}{Named list. Group variable → label; `NULL` values
#'     for unlabeled group variables.}
#'   \item{`n_respondents`}{Integer(1). Total rows in the design, regardless
#'     of groups, domain status, or weights.}
#'   \item{`value_labels`}{Named list. One key per focal variable; value is a
#'     named vector of label → raw value mappings, or `NULL` for
#'     numeric/unlabelled variables.}
#' }
#' Additional function-specific fields are described in the Phase 1
#' specification.
#'
#' @examples
#' # Construct a minimal survey_result to illustrate meta():
#' result <- structure(
#'   tibble::tibble(mean = 42.0, se = 1.5, n = 100L),
#'   .meta = list(
#'     design_type   = "taylor",
#'     conf_level    = 0.95,
#'     call          = quote(get_means(d, x)),
#'     group_names   = character(0),
#'     group_labels  = list(),
#'     n_respondents = 100L,
#'     variable      = "x",
#'     variable_label   = NULL,
#'     question_preface = NULL,
#'     value_labels     = list(x = NULL)
#'   ),
#'   class = c("survey_means", "survey_result", "tbl_df", "tbl", "data.frame")
#' )
#' meta(result)$design_type    # "taylor"
#' meta(result)$n_respondents  # 100L
#' meta(result)$conf_level     # 0.95
#'
#' @family analysis
#' @export
meta <- function(x, ...) UseMethod("meta")

#' @rdname meta
#' @export
meta.survey_result <- function(x, ...) attr(x, ".meta")


# ── print.survey_result ───────────────────────────────────────────────────────

#' Print a Survey Result Object
#'
#' Prints a labelled header showing the specific result class and dimensions,
#' then delegates to the tibble print method for the tabular content.
#'
#' @param x A `survey_result` object.
#' @param ... Passed to the tibble print method.
#'
#' @return `x`, invisibly.
#'
#' @examples
#' result <- structure(
#'   tibble::tibble(mean = 42.0, se = 1.5, n = 100L),
#'   .meta = list(
#'     design_type = "taylor", conf_level = 0.95,
#'     call = quote(get_means(d, x)), group_names = character(0),
#'     group_labels = list(), n_respondents = 100L,
#'     variable = "x", variable_label = NULL,
#'     question_preface = NULL, value_labels = list(x = NULL)
#'   ),
#'   class = c("survey_means", "survey_result", "tbl_df", "tbl", "data.frame")
#' )
#' print(result)
#'
#' @method print survey_result
#' @export
print.survey_result <- function(x, ...) {
  cls  <- class(x)[1L]
  dims <- paste(nrow(x), "\u00d7", ncol(x))
  cat(sprintf("# A <%s> [%s]\n", cls, dims))
  NextMethod()
  invisible(x)
}
