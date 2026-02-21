# R/02-validators.R
#
# Layer 2 validator helpers for the surveycore package.
#
# These functions are called by constructors (Layer 3) and update_design()
# to validate input BEFORE creating S7 objects. All return invisible(TRUE)
# on success; call cli_abort() or cli_warn() on failure.
#
# The 3-layer validator architecture (per phase-0-implementation-plan-v2.md):
#   Layer 1 — S7 class validators    (R/00-s7-classes.R)
#   Layer 2 — these helpers          (R/02-validators.R)  <-- this file
#   Layer 3 — constructor validation (R/03-constructors.R)
#
# No logic from one layer is duplicated in another.
# Error classes match plans/error-messages.md exactly.
# All functions are internal (not exported), prefixed with `.`.

#' Internal Validator Helpers
#'
#' Layer 2 reusable validation helpers called by constructors and
#' `update_design()` to validate input before creating S7 objects.
#' Return `invisible(TRUE)` on success; call [cli::cli_abort()] or
#' [cli::cli_warn()] on failure.
#'
#' @name validators
#' @keywords internal
#' @noRd
NULL


# ── .validate_weights ──────────────────────────────────────────────────────────

# Validates that `weights_var` column exists in `data`, is numeric, and has
# all non-NA values strictly positive (with the all-zero/all-missing case
# caught first for a more actionable error).
#' @noRd
.validate_weights <- function(weights_var, data) {
  # Existence check
  if (!weights_var %in% names(data)) {
    cli::cli_abort(
      c(
        "x" = "Weight column {.field {weights_var}} not found in {.arg data}.",
        "i" = "Available columns: {.field {names(data)}}."
      ),
      class = "surveycore_error_design_var_missing"
    )
  }

  wt_col <- data[[weights_var]]

  # Numeric check
  if (!is.numeric(wt_col)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Weight column {.field {weights_var}} must be numeric, ",
          "not {.cls {class(wt_col)}}."
        )
      ),
      class = "surveycore_error_weights_not_numeric"
    )
  }

  # All zero or all missing → no valid weights at all
  non_na <- wt_col[!is.na(wt_col)]
  if (length(non_na) == 0L || all(non_na == 0)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "All values in {.arg weights} ({.field {weights_var}}) are zero ",
          "or missing \u2014 no valid weights."
        )
      ),
      class = "surveycore_error_weights_all_zero"
    )
  }

  # Non-positive check (some bad weights mixed with good ones)
  n_bad <- sum(non_na <= 0)
  if (n_bad > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Weight column {.field {weights_var}} has {n_bad} non-positive ",
          "value(s). All non-NA weights must be > 0."
        )
      ),
      class = "surveycore_error_weights_nonpositive"
    )
  }

  invisible(TRUE)
}


# ── .validate_design_vars ──────────────────────────────────────────────────────

# Validates that all column names in `vars` exist in `data` and are atomic
# (not list-columns). Pass `vars = NULL` or `vars = character(0)` to no-op.
#' @noRd
.validate_design_vars <- function(vars, data) {
  if (is.null(vars) || length(vars) == 0L) return(invisible(TRUE))

  # Existence check
  missing_vars <- setdiff(vars, names(data))
  if (length(missing_vars) > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Design variable(s) not found in {.arg data}: ",
          "{.field {missing_vars}}."
        )
      ),
      class = "surveycore_error_design_var_missing"
    )
  }

  # Atomic check (not list-columns)
  for (v in vars) {
    if (!is.atomic(data[[v]])) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Design variable {.field {v}} is a list-column. ",
            "Design variables must be atomic vectors."
          )
        ),
        class = "surveycore_error_design_var_list"
      )
    }
  }

  invisible(TRUE)
}


# ── .validate_fpc ─────────────────────────────────────────────────────────────

# Validates that `fpc_var` column exists in `data` and contains no NA values.
# Pass `fpc_var = NULL` to no-op.
#' @noRd
.validate_fpc <- function(fpc_var, data) {
  if (is.null(fpc_var)) return(invisible(TRUE))

  # Existence check
  if (!fpc_var %in% names(data)) {
    cli::cli_abort(
      c(
        "x" = "FPC column {.field {fpc_var}} not found in {.arg data}.",
        "i" = "Available columns: {.field {names(data)}}."
      ),
      class = "surveycore_error_design_var_missing"
    )
  }

  fpc_col <- data[[fpc_var]]
  n_na    <- sum(is.na(fpc_col))

  if (n_na > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg fpc} column {.field {fpc_var}} contains {n_na} ",
          "NA value(s). FPC must be fully observed."
        ),
        "v" = paste0(
          "Remove rows with missing FPC or set {.arg fpc = NULL} to ",
          "omit the correction."
        )
      ),
      class = "surveycore_error_fpc_na"
    )
  }

  invisible(TRUE)
}


# ── .validate_repweights ───────────────────────────────────────────────────────

# Validates that all columns in `repweights_vars` exist in `data` and are
# numeric. Pass `repweights_vars = NULL` or `repweights_vars = character(0)`
# to no-op.
#' @noRd
.validate_repweights <- function(repweights_vars, data) {
  if (is.null(repweights_vars) || length(repweights_vars) == 0L) {
    return(invisible(TRUE))
  }

  # Existence check
  missing_vars <- setdiff(repweights_vars, names(data))
  if (length(missing_vars) > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Replicate weight column(s) not found in {.arg data}: ",
          "{.field {missing_vars}}."
        )
      ),
      class = "surveycore_error_design_var_missing"
    )
  }

  # Numeric check (first non-numeric column triggers the error)
  for (rw in repweights_vars) {
    rw_col <- data[[rw]]
    if (!is.numeric(rw_col)) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Replicate weight column {.field {rw}} must be numeric, ",
            "not {.cls {class(rw_col)}}."
          )
        ),
        class = "surveycore_error_repweights_not_numeric"
      )
    }
  }

  invisible(TRUE)
}


# ── .validate_psu_strata ───────────────────────────────────────────────────────

# Issues a warning if any PSU (first stage of `ids`) appears in more than one
# stratum. Pass `ids = NULL` or `strata = NULL` to no-op. This check is skipped
# when `nest = TRUE` (caller responsibility — this function does not take nest).
#' @noRd
.validate_psu_strata <- function(ids, strata, data) {
  if (is.null(ids) || length(ids) == 0L || is.null(strata)) {
    return(invisible(TRUE))
  }

  psu_col    <- as.character(data[[ids[[1L]]]])
  strata_col <- as.character(data[[strata]])

  psu_n_strata      <- tapply(strata_col, psu_col, function(s) length(unique(s)))
  multi_strata_psus <- names(psu_n_strata)[psu_n_strata > 1L]

  if (length(multi_strata_psus) > 0L) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "Some PSUs appear in more than one stratum: ",
          "{.val {head(multi_strata_psus, 5L)}}. ",
          "If PSUs are nested within strata, set {.code nest = TRUE}."
        )
      ),
      class = "surveycore_warning_psu_multi_strata"
    )
  }

  invisible(TRUE)
}


# ── .validate_rscales ──────────────────────────────────────────────────────────

# Validates that `rscales` has exactly `n_rep` elements, matching the number
# of replicate weight columns. Pass `rscales = NULL` to no-op.
#' @noRd
.validate_rscales <- function(rscales, n_rep) {
  if (is.null(rscales)) return(invisible(TRUE))

  if (length(rscales) != n_rep) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Length of {.arg rscales} ({length(rscales)}) must equal ",
          "number of replicate weights ({n_rep})."
        )
      ),
      class = "surveycore_error_rscales_length"
    )
  }

  invisible(TRUE)
}


# ── .update_design_var_names ───────────────────────────────────────────────────

# Updates design variable name references in a `@variables` list according to
# `rename_map`. Returns the updated list. Intended for use by rename methods,
# which reconstruct the survey object atomically (new data + new variables in
# a single constructor call) to avoid intermediate S7 validator failures.
#
# `variables`:  the `@variables` list from a survey design object.
# `rename_map`: named character vector where names are old column names and
#               values are the corresponding new names (e.g., c(old_wt = "weight")).
#' @noRd
.update_design_var_names <- function(variables, rename_map) {
  vars <- variables

  # Update scalar design variables (weights, strata, fpc)
  for (slot in c("weights", "strata", "fpc")) {
    if (!is.null(vars[[slot]]) && vars[[slot]] %in% names(rename_map)) {
      vars[[slot]] <- rename_map[[vars[[slot]]]]
    }
  }

  # Update ids (character vector, may have multiple stages)
  if (!is.null(vars$ids)) {
    matched           <- vars$ids %in% names(rename_map)
    vars$ids[matched] <- rename_map[vars$ids[matched]]
  }

  # Update replicate weight column names (survey_replicate only)
  if (!is.null(vars$repweights)) {
    matched                  <- vars$repweights %in% names(rename_map)
    vars$repweights[matched] <- rename_map[vars$repweights[matched]]
  }

  vars
}


# ── .rename_metadata_keys ──────────────────────────────────────────────────────

# Renames keys (variable names) in all metadata list properties to stay in
# sync after a column rename. Called alongside .update_design_var_names().
#
# `rename_map`: same named character vector as .update_design_var_names().
#' @noRd
.rename_metadata_keys <- function(metadata, rename_map) {
  # Renames matched keys in a named list; leaves others unchanged.
  .rename_list_keys <- function(lst, map) {
    if (length(lst) == 0L || is.null(names(lst))) return(lst)
    matched         <- names(lst) %in% names(map)
    names(lst)[matched] <- map[names(lst)[matched]]
    lst
  }

  metadata@variable_labels   <- .rename_list_keys(metadata@variable_labels, rename_map)
  metadata@value_labels      <- .rename_list_keys(metadata@value_labels, rename_map)
  metadata@question_prefaces <- .rename_list_keys(metadata@question_prefaces, rename_map)
  metadata@notes             <- .rename_list_keys(metadata@notes, rename_map)
  metadata@transformations   <- .rename_list_keys(metadata@transformations, rename_map)

  metadata
}


# ── .delete_metadata_col ───────────────────────────────────────────────────────

# Deletes per-column metadata for `col` from every @metadata slot.
# Used by surveytidy's select() when a column is dropped from a survey design.
# Leaves @metadata@weighting_history untouched — that slot is design-level, not
# per-column.
#
# `design`: a survey_base subclass object.
# `col`:    character(1) — the column name to purge from all metadata slots.
#' @noRd
.delete_metadata_col <- function(design, col) {
  md <- design@metadata
  md@variable_labels[[col]]   <- NULL
  md@value_labels[[col]]      <- NULL
  md@question_prefaces[[col]] <- NULL
  md@notes[[col]]             <- NULL
  md@transformations[[col]]   <- NULL
  design@metadata <- md
  design
}
