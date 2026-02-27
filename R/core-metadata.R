# R/01-metadata-system.R
#
# Metadata extraction and setting functions for survey design objects.
#
# Dispatch note: UseMethod() does not work for S7 objects when the package is
# loaded under its own namespace, because S7 uses namespaced class names (e.g.,
# "surveycore::survey_base") that cannot be S3 method suffixes. All functions
# here are implemented as plain functions that validate their first argument
# with S7::S7_inherits(). NSE arguments are captured via rlang::enquo() at the
# function level before any branching.
#
# Functions defined here:
#   Extractors (getters):
#     extract_var_label()        — single variable label
#     extract_val_labels()       — single variable value labels
#     extract_question_preface() — single variable question preface
#     extract_var_note()         — single variable analyst note
#   Singular setters:
#     set_var_label()            — set label for one variable
#     set_val_labels()           — set value labels for one variable
#     set_question_preface()     — set question preface for one variable
#     set_var_note()             — set note for one variable
#   Plural setters:
#     set_variable_labels()      — set labels for multiple variables
#     set_value_labels()         — set value labels for multiple variables
#     set_question_prefaces()    — set question prefaces for multiple variables
#     set_variable_notes()       — set notes for multiple variables
#   Internal helpers:
#     .validate_val_labels()     — check label completeness
#     .extract_haven_metadata()  — read haven-style attrs from a data.frame


# ── Input check helper ────────────────────────────────────────────────────────

# Used by all exported functions to produce a consistent error when x is not
# a survey design object.
.check_is_survey <- function(x, call = rlang::caller_env()) {
  if (!S7::S7_inherits(x, survey_base)) {
    cli::cli_abort(
      c(
        "x" = "{.arg x} must be a survey design object, not {.cls {class(x)[[1L]]}}.",
        "v" = "Create a survey object with {.fn as_survey}, {.fn as_survey_rep},",
        " " = "or {.fn as_survey_twophase}."
      ),
      class = "surveycore_error_not_survey",
      call  = call
    )
  }
  invisible(NULL)
}


# ── Extractors ────────────────────────────────────────────────────────────────

#' Extract a Variable Label
#'
#' Returns the variable label for a single variable in a survey design object,
#' or `NULL` if no label has been set.
#'
#' @param x A survey design object (`survey_taylor`, `survey_replicate`, or
#'   `survey_twophase`).
#' @param var <[`data-masked`][rlang::args_data_masking]> Variable name
#'   (bare, unquoted).
#'
#' @return A character string, or `NULL` if no label has been set.
#'
#' @examples
#' # nhanes_2017 carries haven-style labels auto-extracted by as_survey()
#' d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
#'                strata = sdmvstra, nest = TRUE)
#' extract_var_label(d, riagendr)   # "Gender"
#' extract_var_label(d, ridageyr)   # "Age in years at screening"
#'
#' @seealso [set_var_label()] to set a variable label
#' @family metadata
#' @export
extract_var_label <- function(x, var) {
  .check_is_survey(x)
  var_name <- rlang::as_name(rlang::enquo(var))
  x@metadata@variable_labels[[var_name]]
}


#' Extract Value Labels for a Variable
#'
#' Returns the named value-label vector for a single variable in a survey
#' design object, or `NULL` if no value labels have been set.
#'
#' @param x A survey design object.
#' @param var <[`data-masked`][rlang::args_data_masking]> Variable name
#'   (bare, unquoted).
#'
#' @return A named vector (e.g., `c(Male = 1L, Female = 2L)`), or `NULL`.
#'
#' @examples
#' # nhanes_2017 carries haven-style value labels auto-extracted by as_survey()
#' d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
#'                strata = sdmvstra, nest = TRUE)
#' extract_val_labels(d, riagendr)   # c(Male = 1, Female = 2)
#'
#' @seealso [set_val_labels()] to set value labels
#' @family metadata
#' @export
extract_val_labels <- function(x, var) {
  .check_is_survey(x)
  var_name <- rlang::as_name(rlang::enquo(var))
  x@metadata@value_labels[[var_name]]
}


#' Extract a Question Preface
#'
#' Returns the question preface string for a single variable, or `NULL` if
#' none has been set.
#'
#' @param x A survey design object.
#' @param var <[`data-masked`][rlang::args_data_masking]> Variable name
#'   (bare, unquoted).
#'
#' @return A character string, or `NULL`.
#'
#' @seealso [set_question_preface()] to set a question preface
#' @family metadata
#' @export
extract_question_preface <- function(x, var) {
  .check_is_survey(x)
  var_name <- rlang::as_name(rlang::enquo(var))
  x@metadata@question_prefaces[[var_name]]
}


#' Extract an Analyst Note
#'
#' Returns the analyst note for a single variable, or `NULL` if none has been
#' set.
#'
#' @param x A survey design object.
#' @param var <[`data-masked`][rlang::args_data_masking]> Variable name
#'   (bare, unquoted).
#'
#' @return A character string, or `NULL`.
#'
#' @seealso [set_var_note()] to set a note
#' @family metadata
#' @export
extract_var_note <- function(x, var) {
  .check_is_survey(x)
  var_name <- rlang::as_name(rlang::enquo(var))
  x@metadata@notes[[var_name]]
}


# ── Singular setters ─────────────────────────────────────────────────────────

#' Set a Variable Label
#'
#' Sets the variable label for a single variable in a survey design object.
#'
#' @param x A survey design object.
#' @param var <[`data-masked`][rlang::args_data_masking]> Variable to label
#'   (bare, unquoted).
#' @param label A character string. The variable label to assign.
#'
#' @return The modified survey object, invisibly.
#'
#' @examples
#' d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
#'                strata = sdmvstra, nest = TRUE)
#' d <- set_var_label(d, indfmpir, "Income-to-poverty ratio")
#'
#' # Pipe-friendly
#' d <- d |> set_var_label(bpxsy1, "Systolic BP (1st reading)")
#'
#' @seealso [set_variable_labels()] for setting multiple labels at once,
#'   [extract_var_label()] to retrieve a label
#' @family metadata
#' @export
set_var_label <- function(x, var, label) {
  .check_is_survey(x)
  var_name <- rlang::as_name(rlang::enquo(var))
  if (!var_name %in% names(x@data)) {
    cli::cli_abort(
      c(
        "x" = "Variable {.field {var_name}} not found in {.arg x}.",
        "i" = "Available: {.field {names(x@data)}}"
      ),
      class = "surveycore_error_var_not_found"
    )
  }
  x@metadata@variable_labels[[var_name]] <- label
  invisible(x)
}


#' Set Value Labels for a Variable
#'
#' Sets value labels for a single variable in a survey design object. Extra
#' labels (for values not present in the data) are allowed — they document the
#' full coding scheme. A warning is issued if some observed data values lack a
#' label.
#'
#' @param x A survey design object.
#' @param var <[`data-masked`][rlang::args_data_masking]> Variable to label
#'   (bare, unquoted).
#' @param labels A fully named vector where names are the display labels and
#'   values are the data codes (e.g., `c(Male = 1L, Female = 2L)`). All
#'   elements must be named.
#'
#' @return The modified survey object, invisibly.
#'
#' @examples
#' d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
#'                strata = sdmvstra, nest = TRUE)
#' d <- set_val_labels(
#'   d, ridstatr, c("Interview only" = 1L, "Interview + exam" = 2L)
#' )
#'
#' @seealso [set_value_labels()] for setting labels for multiple variables,
#'   [extract_val_labels()] to retrieve value labels
#' @family metadata
#' @export
set_val_labels <- function(x, var, labels) {
  .check_is_survey(x)
  var_name <- rlang::as_name(rlang::enquo(var))
  if (!var_name %in% names(x@data)) {
    cli::cli_abort(
      c(
        "x" = "Variable {.field {var_name}} not found in {.arg x}.",
        "i" = "Available: {.field {names(x@data)}}"
      ),
      class = "surveycore_error_var_not_found"
    )
  }
  if (is.null(names(labels)) || any(names(labels) == "")) {
    cli::cli_abort(
      c(
        "x" = "{.arg labels} must be a fully named vector.",
        "i" = "All elements must have names."
      ),
      class = "surveycore_error_labels_unnamed"
    )
  }
  .validate_val_labels(x@data[[var_name]], labels, var_name = var_name)
  x@metadata@value_labels[[var_name]] <- labels
  invisible(x)
}


#' Set a Question Preface
#'
#' Sets the question preface string for a single variable in a survey design
#' object. Question prefaces are the shared introductory text for a battery of
#' related questions.
#'
#' @param x A survey design object.
#' @param var <[`data-masked`][rlang::args_data_masking]> Variable name
#'   (bare, unquoted).
#' @param preface A character string. The question preface text.
#'
#' @return The modified survey object, invisibly.
#'
#' @seealso [set_question_prefaces()] for setting prefaces for multiple
#'   variables, [extract_question_preface()] to retrieve a preface
#' @family metadata
#' @export
set_question_preface <- function(x, var, preface) {
  .check_is_survey(x)
  var_name <- rlang::as_name(rlang::enquo(var))
  if (!var_name %in% names(x@data)) {
    cli::cli_abort(
      c(
        "x" = "Variable {.field {var_name}} not found in {.arg x}.",
        "i" = "Available: {.field {names(x@data)}}"
      ),
      class = "surveycore_error_var_not_found"
    )
  }
  x@metadata@question_prefaces[[var_name]] <- preface
  invisible(x)
}


#' Set an Analyst Note
#'
#' Sets an analyst note for a single variable in a survey design object. Notes
#' are free-text annotations for documenting processing decisions, data quality
#' concerns, or other context.
#'
#' @param x A survey design object.
#' @param var <[`data-masked`][rlang::args_data_masking]> Variable name
#'   (bare, unquoted).
#' @param note A character string. The analyst note to attach.
#'
#' @return The modified survey object, invisibly.
#'
#' @seealso [set_variable_notes()] for setting notes for multiple variables,
#'   [extract_var_note()] to retrieve a note
#' @family metadata
#' @export
set_var_note <- function(x, var, note) {
  .check_is_survey(x)
  var_name <- rlang::as_name(rlang::enquo(var))
  if (!var_name %in% names(x@data)) {
    cli::cli_abort(
      c(
        "x" = "Variable {.field {var_name}} not found in {.arg x}.",
        "i" = "Available: {.field {names(x@data)}}"
      ),
      class = "surveycore_error_var_not_found"
    )
  }
  x@metadata@notes[[var_name]] <- note
  invisible(x)
}


# ── Plural setters ────────────────────────────────────────────────────────────

#' Set Variable Labels for Multiple Variables
#'
#' Sets variable labels for multiple variables at once using named arguments.
#' All variable names must exist in the survey data.
#'
#' @param x A survey design object.
#' @param ... Named arguments where the name is the variable (unquoted) and the
#'   value is the label string. Supports `!!!` list splicing for programmatic
#'   use.
#'
#' @return The modified survey object, invisibly.
#'
#' @examples
#' d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
#'                strata = sdmvstra, nest = TRUE)
#' d <- set_variable_labels(
#'   d,
#'   bpxsy1 = "Systolic BP, 1st reading (mm Hg)",
#'   bpxdi1 = "Diastolic BP, 1st reading (mm Hg)"
#' )
#'
#' # Programmatic with list splicing
#' lbls <- list(bpxsy1 = "Systolic BP", bpxdi1 = "Diastolic BP")
#' d <- set_variable_labels(d, !!!lbls)
#'
#' @seealso [set_var_label()] for setting a single label
#' @family metadata
#' @export
set_variable_labels <- function(x, ...) {
  .check_is_survey(x)
  labels_list <- rlang::list2(...)
  var_names   <- names(labels_list)
  missing     <- setdiff(var_names, names(x@data))
  if (length(missing) > 0L) {
    cli::cli_abort(
      c("x" = "Variable(s) not found in {.arg x}: {.field {missing}}"),
      class = "surveycore_error_vars_not_found"
    )
  }
  for (var_name in var_names) {
    x@metadata@variable_labels[[var_name]] <- labels_list[[var_name]]
  }
  invisible(x)
}


#' Set Value Labels for Multiple Variables
#'
#' Sets value labels for multiple variables at once using named arguments.
#' Each argument value must be a fully named vector. A warning is issued for
#' any variable where some observed values lack a label.
#'
#' @param x A survey design object.
#' @param ... Named arguments where the name is the variable (unquoted) and the
#'   value is a named vector of value labels.
#'
#' @return The modified survey object, invisibly.
#'
#' @examples
#' d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
#'                strata = sdmvstra, nest = TRUE)
#' d <- set_value_labels(
#'   d,
#'   riagendr = c(Male = 1L, Female = 2L),
#'   ridstatr = c("Interview only" = 1L, "Interview + exam" = 2L)
#' )
#'
#' @seealso [set_val_labels()] for setting value labels for a single variable
#' @family metadata
#' @export
set_value_labels <- function(x, ...) {
  .check_is_survey(x)
  labels_list <- rlang::list2(...)
  var_names   <- names(labels_list)
  missing     <- setdiff(var_names, names(x@data))
  if (length(missing) > 0L) {
    cli::cli_abort(
      c("x" = "Variable(s) not found in {.arg x}: {.field {missing}}"),
      class = "surveycore_error_vars_not_found"
    )
  }
  for (var_name in var_names) {
    labels <- labels_list[[var_name]]
    if (is.null(names(labels)) || any(names(labels) == "")) {
      cli::cli_abort(
        c(
          "x" = "{.arg labels} must be a fully named vector.",
          "i" = "All elements must have names."
        ),
        class = "surveycore_error_labels_unnamed"
      )
    }
    .validate_val_labels(x@data[[var_name]], labels, var_name = var_name)
    x@metadata@value_labels[[var_name]] <- labels
  }
  invisible(x)
}


#' Set Question Prefaces for Multiple Variables
#'
#' Sets question preface text for multiple variables at once using named
#' arguments.
#'
#' @param x A survey design object.
#' @param ... Named arguments where the name is the variable (unquoted) and the
#'   value is the preface string.
#'
#' @return The modified survey object, invisibly.
#'
#' @seealso [set_question_preface()] for setting a single question preface
#' @family metadata
#' @export
set_question_prefaces <- function(x, ...) {
  .check_is_survey(x)
  prefaces  <- rlang::list2(...)
  var_names <- names(prefaces)
  missing   <- setdiff(var_names, names(x@data))
  if (length(missing) > 0L) {
    cli::cli_abort(
      c("x" = "Variable(s) not found in {.arg x}: {.field {missing}}"),
      class = "surveycore_error_vars_not_found"
    )
  }
  for (var_name in var_names) {
    x@metadata@question_prefaces[[var_name]] <- prefaces[[var_name]]
  }
  invisible(x)
}


#' Set Analyst Notes for Multiple Variables
#'
#' Sets analyst notes for multiple variables at once using named arguments.
#'
#' @param x A survey design object.
#' @param ... Named arguments where the name is the variable (unquoted) and the
#'   value is the note string.
#'
#' @return The modified survey object, invisibly.
#'
#' @seealso [set_var_note()] for setting a single note
#' @family metadata
#' @export
set_variable_notes <- function(x, ...) {
  .check_is_survey(x)
  notes     <- rlang::list2(...)
  var_names <- names(notes)
  missing   <- setdiff(var_names, names(x@data))
  if (length(missing) > 0L) {
    cli::cli_abort(
      c("x" = "Variable(s) not found in {.arg x}: {.field {missing}}"),
      class = "surveycore_error_vars_not_found"
    )
  }
  for (var_name in var_names) {
    x@metadata@notes[[var_name]] <- notes[[var_name]]
  }
  invisible(x)
}


# ── Internal helpers ──────────────────────────────────────────────────────────

#' Validate Value Labels Against Observed Data Values
#'
#' Checks whether all observed (non-NA) values of a variable have a
#' corresponding label. Extra labels (for values not in the data) are silently
#' allowed — they document the full coding scheme. A warning is issued when
#' some observed values lack a label.
#'
#' @param var A vector of data values (one column from `@data`).
#' @param labels A fully named vector of value labels.
#' @param var_name Character string naming the variable (for warning messages).
#' @param strict Logical. If `TRUE`, error instead of warn on missing labels.
#'   Default `FALSE`.
#'
#' @return `invisible(TRUE)`.
#' @keywords internal
#' @noRd
.validate_val_labels <- function(var, labels, var_name, strict = FALSE) {
  unique_vals <- unique(var[!is.na(var)])
  # label_vals: the DATA CODES covered by labels (the vector VALUES, not names)
  label_vals  <- as.character(labels)
  missing     <- setdiff(as.character(unique_vals), label_vals)

  if (length(missing) > 0L) {
    if (strict) {
      cli::cli_abort(
        c(
          "x" = "Not all values of {.field {var_name}} are labeled.",
          "i" = "Unlabeled values: {.val {missing}}"
        ),
        class = "surveycore_error_missing_labels"
      )
    } else {
      cli::cli_warn(
        c(
          "!" = "Not all values of {.field {var_name}} are labeled.",
          "i" = "Unlabeled values: {.val {missing}}"
        ),
        class = "surveycore_warning_missing_labels"
      )
    }
  }

  invisible(TRUE)
}


#' Extract haven-Style Metadata from a Data Frame
#'
#' Scans each column of `data` for `"label"`, `"labels"`, and
#' `"question_preface"` attributes set by haven or by
#' `infer_question_prefaces()` (or any tool following the same convention).
#' Does NOT import haven — uses only base R `attr()`.
#'
#' Edge cases handled:
#' 1. Zero-length or empty-string variable labels — not stored.
#' 2. `NA` as a key in value labels — preserved (SPSS user-defined missing).
#' 3. Empty value-label vectors — not stored.
#' 4. Columns with no attributes — silently skipped.
#'
#' @param data A `data.frame`.
#' @return A [survey_metadata] object. All properties are empty lists if no
#'   haven attributes are found.
#' @keywords internal
#' @noRd
.extract_haven_metadata <- function(data) {
  var_labels <- list()
  val_labels <- list()
  q_prefaces <- list()

  for (col_name in names(data)) {
    col <- data[[col_name]]

    # ── Variable label ────────────────────────────────────────────────────────
    # haven: attr(x, "label") — a length-1 character string
    var_lbl <- attr(col, "label", exact = TRUE)
    if (
      !is.null(var_lbl) &&
      is.character(var_lbl) &&
      length(var_lbl) > 0L &&
      nzchar(var_lbl[[1L]])
    ) {
      var_labels[[col_name]] <- var_lbl[[1L]]
    }

    # ── Value labels ──────────────────────────────────────────────────────────
    # haven: attr(x, "labels") — a named numeric or character vector
    val_lbl <- attr(col, "labels", exact = TRUE)
    if (
      !is.null(val_lbl) &&
      length(val_lbl) > 0L &&
      !is.null(names(val_lbl))
    ) {
      # NA keys (SPSS user-defined missing values) are preserved as-is
      val_labels[[col_name]] <- val_lbl
    }

    # ── Question preface (set by infer_question_prefaces() on data frames) ────
    q_preface <- attr(col, "question_preface", exact = TRUE)
    if (
      !is.null(q_preface) &&
      is.character(q_preface) &&
      nzchar(q_preface[[1L]])
    ) {
      q_prefaces[[col_name]] <- q_preface[[1L]]
    }
  }

  survey_metadata(
    variable_labels   = var_labels,
    value_labels      = val_labels,
    question_prefaces = q_prefaces
  )
}
