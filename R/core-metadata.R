# R/core-metadata.R
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

# ── PR 2 internal helper infrastructure ──────────────────────────────────────

# .check_is_survey_or_df(x, call)
# Type guard accepting survey objects and plain data frames; replaces
# .check_is_survey() for all functions that gain data frame support.
.check_is_survey_or_df <- function(x, call = rlang::caller_env()) {
  if (!S7::S7_inherits(x, survey_base) && !is.data.frame(x)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg x} must be a survey design object or a data frame,",
          " not {.cls {class(x)[[1L]]}}."
        ),
        "v" = paste0(
          "Create a survey object with {.fn as_survey},",
          " {.fn as_survey_replicate}, or {.fn as_survey_twophase}."
        )
      ),
      class = "surveycore_error_not_survey_or_df",
      call  = call
    )
  }
  invisible(NULL)
}

# .get_data_cols(x)
# Returns the names of all data columns: names(x) for data frames,
# names(x@data) for survey objects.
.get_data_cols <- function(x) {
  if (is.data.frame(x)) names(x) else names(x@data)
}

# .get_metadata(x)
# Returns x@metadata for survey objects, NULL for data frames.
.get_metadata <- function(x) {
  if (S7::S7_inherits(x, survey_base)) x@metadata else NULL
}

# .parse_setter_input(dots, variable, content, content_arg_name,
#                     content_type, fn_name, call)
# Shared convention detection for all unified setters. Receives `dots` as an
# evaluated list (rlang::list2(...) at the caller). Returns a named list
# mapping variable names to content values; NULL values signal deletion.
#
# content_type:
#   "scalar" — Convention 2 expects a named character vector in ...
#   "vector" — Convention 2 expects a named list in ...
.parse_setter_input <- function(
  dots,
  variable,
  content,
  content_arg_name,
  content_type = c("scalar", "vector"),
  fn_name,
  call = rlang::caller_env()
) {
  content_type <- match.arg(content_type)
  dots_len <- length(dots)
  var_provided <- !is.null(variable)

  # Ambiguity: both ... and variable provided
  if (dots_len > 0L && var_provided) {
    cli::cli_abort(
      c(
        "x" = "Provide variable names via {.arg ...} or via {.arg variable}, not both.",
        "i" = paste0(
          "Use named {.arg ...} args, a named vector in {.arg ...}, or",
          " {.arg variable} + {.arg {content_arg_name}} \u2014 not a mix."
        )
      ),
      class = "surveycore_error_setter_ambiguous",
      call = call
    )
  }

  # Empty: neither provided
  if (dots_len == 0L && !var_provided) {
    cli::cli_abort(
      c(
        "x" = "{.fn {fn_name}} requires at least one variable-label pair.",
        "v" = "Use named {.arg ...} args: {.code {fn_name}(x, age = 'Age in years')}."
      ),
      class = "surveycore_error_setter_empty",
      call = call
    )
  }

  # Convention 3: explicit variable + content arg
  if (var_provided && dots_len == 0L) {
    if (length(variable) == 0L) {
      cli::cli_warn(
        c(
          "!" = "{.fn {fn_name}} was called with {.arg variable} of length 0.",
          "i" = "No metadata was set. Did you accidentally filter all variable names out?"
        ),
        class = "surveycore_warning_setter_empty_variables",
        call = call
      )
      return(list())
    }
    if (!is.null(content) && length(variable) != length(content)) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg variable} has {length(variable)} element{?s} but",
            " {.arg {content_arg_name}} has {length(content)} element{?s}."
          ),
          "i" = "They must be the same length (one content value per variable name)."
        ),
        class = "surveycore_error_setter_mismatched_lengths",
        call = call
      )
    }
    if (is.null(content)) {
      return(stats::setNames(vector("list", length(variable)), variable))
    }
    return(stats::setNames(as.list(content), variable))
  }

  # From here: dots_len > 0 and variable is NULL
  dot_names <- names(dots)
  has_unnamed <- is.null(dot_names) || any(!nzchar(dot_names))

  if (has_unnamed) {
    # Check Convention 2: single unnamed element that is itself a named
    # character vector (scalar) or named list (vector)
    if (dots_len == 1L) {
      elem <- dots[[1L]]
      is_named_char_vec <- (
        is.character(elem) &&
          !is.null(names(elem)) &&
          length(elem) > 0L &&
          all(nzchar(names(elem)))
      )
      is_named_list <- (
        is.list(elem) &&
          !is.null(names(elem)) &&
          length(elem) > 0L &&
          all(nzchar(names(elem)))
      )
      if (content_type == "scalar" && is_named_char_vec) {
        return(as.list(elem))
      }
      if (content_type == "vector" && is_named_list) {
        return(elem)
      }
    }
    # Not Convention 2 — mixed or fully unnamed ... elements
    n_named <- if (!is.null(dot_names)) sum(nzchar(dot_names)) else 0L
    n_unnamed <- dots_len - n_named
    cli::cli_abort(
      c(
        "x" = "All {.arg ...} arguments must be named when using Convention 1.",
        "i" = "Got {n_named} named and {n_unnamed} unnamed element{?s}.",
        "v" = paste0(
          "Use {.code {fn_name}(x, age = 'Age', income = 'Annual income')}",
          " or a fully named vector."
        )
      ),
      class = "surveycore_error_setter_mixed_dots",
      call = call
    )
  }

  # Convention 1: all elements are named
  dots
}

# .resolve_vars(x, var_exprs, call)
# Resolves the `...` quosures for extractor functions. If var_exprs is empty,
# returns all column names. Otherwise evaluates bare symbols and character
# expressions; warns and skips variables not found.
.resolve_vars <- function(
  x,
  var_exprs,
  call = rlang::caller_env()
) {
  all_cols <- .get_data_cols(x)

  if (length(var_exprs) == 0L) {
    return(all_cols)
  }

  requested <- unlist(lapply(var_exprs, function(q) {
    if (rlang::quo_is_symbol(q)) {
      rlang::as_name(q)
    } else {
      rlang::eval_tidy(q)
    }
  }), use.names = FALSE)

  missing <- setdiff(requested, all_cols)
  if (length(missing) > 0L) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "{length(missing)} variable{?s} not found in {.arg x}",
          " and {?was/were} skipped: {.field {missing}}."
        )
      ),
      class = "surveycore_warning_var_not_found",
      call = call
    )
  }

  intersect(requested, all_cols)
}

# .format_scalar_result(result_list, format, col_name, empty_value)
# Converts a named list of character scalars to the requested output format.
# empty_value = NULL omits NULL entries; empty_value = NA_character_ replaces
# NULL entries with NA.
.format_scalar_result <- function(
  result_list,
  format,
  col_name,
  empty_value
) {
  if (is.null(empty_value)) {
    result_list <- result_list[!vapply(result_list, is.null, logical(1L))]
  } else {
    result_list <- lapply(
      result_list,
      function(v) if (is.null(v)) empty_value else v
    )
  }

  var_names <- names(result_list)

  switch(format,
    "named_vector" = {
      values <- unlist(result_list, use.names = FALSE)
      stats::setNames(values, var_names)
    },
    "list" = result_list,
    "data_frame" = {
      values <- unname(vapply(
        result_list,
        function(v) if (is.null(v)) NA_character_ else v,
        character(1L)
      ))
      result <- tibble::tibble(variable = var_names)
      result[[col_name]] <- values
      result
    }
  )
}

# .format_list_result(result_list, format, fn_name)
# Converts a named list of vectors to "list" or "data_frame" format.
# "named_vector" is rejected with surveycore_error_format_invalid since vector
# content cannot be collapsed into a flat named vector.
.format_list_result <- function(
  result_list,
  format,
  fn_name
) {
  valid_formats <- c("list", "data_frame")
  if (!format %in% valid_formats) {
    cli::cli_abort(
      c(
        "x" = "{.fn {fn_name}} received an invalid {.arg format} value {.val {format}}.",
        "i" = "{.arg format} must be one of {.val {valid_formats}}."
      ),
      class = "surveycore_error_format_invalid"
    )
  }

  if (format == "list") {
    return(result_list)
  }

  # data_frame: one row per (variable, code) pair
  empty_out <- tibble::tibble(
    variable = character(0L),
    label    = character(0L),
    value    = character(0L)
  )

  if (length(result_list) == 0L) {
    return(empty_out)
  }

  rows <- lapply(names(result_list), function(var_name) {
    vec <- result_list[[var_name]]
    if (is.null(vec) || length(vec) == 0L) {
      return(NULL)
    }
    lbl <- if (!is.null(names(vec))) names(vec) else rep(NA_character_, length(vec))
    tibble::tibble(
      variable = var_name,
      label    = lbl,
      value    = as.character(vec)
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1L))]

  if (length(rows) == 0L) {
    return(empty_out)
  }

  dplyr::bind_rows(rows)
}


# ── Input check helper ────────────────────────────────────────────────────────

# Used by all exported functions to produce a consistent error when x is not
# a survey design object.
.check_is_survey <- function(x, call = rlang::caller_env()) {
  if (!S7::S7_inherits(x, survey_base)) {
    cli::cli_abort(
      c(
        "x" = "{.arg x} must be a survey design object, not {.cls {class(x)[[1L]]}}.",
        "v" = "Create a survey object with {.fn as_survey}, {.fn as_survey_replicate},",
        " " = "or {.fn as_survey_twophase}."
      ),
      class = "surveycore_error_not_survey",
      call = call
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
  var_names <- names(labels_list)
  missing <- setdiff(var_names, names(x@data))
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
  var_names <- names(labels_list)
  missing <- setdiff(var_names, names(x@data))
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
  prefaces <- rlang::list2(...)
  var_names <- names(prefaces)
  missing <- setdiff(var_names, names(x@data))
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
  notes <- rlang::list2(...)
  var_names <- names(notes)
  missing <- setdiff(var_names, names(x@data))
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
  label_vals <- as.character(labels)
  missing <- setdiff(as.character(unique_vals), label_vals)

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
    variable_labels = var_labels,
    value_labels = val_labels,
    question_prefaces = q_prefaces
  )
}
