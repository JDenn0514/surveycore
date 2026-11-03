# R/methods-compat.R
#
# S7 methods that enable IDE compatibility features.
#
# These methods make survey design objects behave like data frames for the
# purposes of column name autocomplete in RStudio and Positron. When a
# survey object is the left-hand side of a pipe, IDEs call names() to
# discover column names and offer them as completions in tidy-select
# arguments of analysis functions like get_means(), get_freqs(), etc.
#
# Class defined in R/core-classes.R

# names() for survey design objects
#
# Returns the column names of the underlying data frame, enabling IDE
# column name completion in analysis functions. IDEs inspect the first
# argument of a pipe chain via names() to build the completion list for
# tidy-select arguments in downstream calls like get_means() or get_freqs().
#
# @param x A survey design object.
# @return A character vector of column names from x@data.
# Class defined in R/core-classes.R
S7::method(names, survey_base) <- function(x) names(x@data)


# dim() for survey design objects
#
# Returns the row count and the column count of the underlying data frame.
# Only dim() is generic: base R defines nrow(x) as dim(x)[1L] and ncol(x)
# as dim(x)[2L], while NROW() and NCOL() read dim() first and fall back to
# length(x) only when dim(x) is NULL. This one method therefore fixes five
# functions (issue #203), which before it returned NULL, NULL, NULL, 1L
# and 1L on every design class.
#
# Both numbers describe the STORED frame.
#
# The row count is the unweighted sample row count of the stored frame. It
# is not a population estimate, and it is not the number of rows in the
# active domain: per CLAUDE.md "Domain estimation vs physical subsetting" a
# filter keeps every row and marks domain membership, so a filtered design
# reports its full stored count and only a physical subset changes it. That
# is correct, not a defect — the stored frame is what variance estimation
# reads, and print() already reports both numbers as
# "Domain: {n_domain} of {n_total} rows".
#
# The column count is the width of the stored frame. It includes the weight
# column, the cluster and stratum id columns, fpc, the domain flag when
# present, and every replicate-weight column, so it is not a count of
# analysis variables and it is not comparable across design classes. It
# also ignores @variables$visible_vars: print() shows fewer columns when
# that key is set, and this method reports the frame.
#
# @param x A survey design object.
# @return An integer vector of length 2 - c(nrow(x@data), ncol(x@data)).
# Class defined in R/core-classes.R
S7::method(dim, survey_base) <- function(x) dim(x@data)


# dim() for survey_collection
#
# Raises. survey_collection is NOT a child of survey_base: its class
# definition declares no parent and it holds @surveys, a list of designs,
# rather than a @data frame. The method above therefore cannot reach it,
# and dim() on a collection would otherwise stay NULL. Registered here,
# beside that method, because it exists only because that method's reach
# stops short of this class.
#
# A collection holds several surveys, each with its own row count and
# column count, so there is no single pair to return. length() and names()
# answer the two container-shaped questions - the member count and the
# member names - and both stay registered in R/methods-print.R.
#
# nrow(), ncol(), NROW() and NCOL() raise the same error, which is the
# intent.
#
# @param x A survey collection.
# @return Nothing. Always raises surveycore_error_collection_no_dim.
# Class defined in R/core-classes.R
S7::method(dim, survey_collection) <- function(x) {
  n <- length(x@surveys)
  first_name <- names(x@surveys)[[1L]]
  cli::cli_abort(
    c(
      "x" = "A {.cls survey_collection} has no single set of dimensions.",
      "i" = paste0(
        "It holds {n} survey{?s}, each with its own row and column ",
        "counts."
      ),
      "v" = paste0(
        "Extract one member with {.code [[} and ask that survey instead, ",
        "e.g. the member named {.val {first_name}}."
      )
    ),
    class = "surveycore_error_collection_no_dim"
  )
}


# ── broom tidy / glance for survey_variance ──────────────────────────────────
#
# These S3 shims are registered in zzz.R under the broom generics. They
# provide minimal compatibility so `broom::tidy()` and `broom::glance()`
# work on `get_variance()` results without invoking broom's default
# data.frame fallbacks. No new semantics — tidy() returns the result as a
# plain tibble; glance() returns a 1-row summary.

# @keywords internal
# @noRd
tidy.survey_variance <- function(x, ...) {
  tibble::as_tibble(x)
}

# @keywords internal
# @noRd
glance.survey_variance <- function(x, ...) {
  tibble::tibble(
    n_rows = nrow(x),
    n_vars = length(unique(x$name))
  )
}


# ── broom tidy / glance for survey_covariance ────────────────────────────────
#
# Same minimal shim pattern as `survey_variance`. Registered in zzz.R under
# the broom generics. tidy() returns the result as a plain tibble; glance()
# returns a 1-row summary with row count and pair count (n_pairs = nrow(x)).

# @keywords internal
# @noRd
tidy.survey_covariance <- function(x, ...) {
  tibble::as_tibble(x)
}

# @keywords internal
# @noRd
glance.survey_covariance <- function(x, ...) {
  tibble::tibble(
    n_rows = nrow(x),
    n_pairs = nrow(x)
  )
}
