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
#     extract_var_label()        — variable labels
#     extract_val_labels()       — value labels
#     extract_question_preface() — question preface text
#     extract_var_note()         — analyst notes
#     extract_universe()         — universe (eligibility) descriptions
#     extract_missing_codes()    — missing value sentinel codes
#     extract_var_extra()        — extension-slot payloads
#     extract_metadata()         — all metadata fields for one or more variables
#     extract_sata()             — SATA (select-all-that-apply) flags
#     extract_higher_is()        — direction-of-improvement attributes
#     extract_reverse_coded()    — reverse-coded flags
#   Unified setters (conventions 1/2/3, survey objects + data frames):
#     set_var_label()            — set label for one or more variables
#     set_val_labels()           — set value labels for one or more variables
#     set_question_preface()     — set question preface for one or more
#                                  variables
#     set_var_note()             — set note for one or more variables
#     set_universe()             — set universe description for one or more vars
#     set_missing_codes()        — set missing codes for one or more variables
#     set_var_extra()            — set extension-slot payload for one or more
#                                  variables
#     set_sata()                 — set SATA flag for one or more variables
#     set_higher_is()            — set direction-of-improvement attribute
#     set_reverse_coded()        — set reverse-coded flag
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
      call = call
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
#                     content_type, fn_name, name_arg_name, pair_noun,
#                     example_pairs, container_noun, call)
# Shared convention detection for all unified setters. Receives `dots` as an
# evaluated list (rlang::list2(...) at the caller). Returns a named list
# mapping variable names to content values; NULL values signal deletion.
#
# content_type:
#   "scalar" — Convention 2 expects a named character vector in ...
#   "vector" — Convention 2 expects a named list in ...
#
# Message parameterization. The seven per-variable setters name a variable and
# set a label, so their five convention messages read in that register. The
# dataset-metadata setter names a KEY and sets a value, and its Convention 2
# container is a list rather than a vector. Four parameters carry the
# difference:
#
#   name_arg_name  — the name-bearing argument: "variable" / "key"
#   pair_noun      — the pair being set: "variable-label" / "key-value"
#   example_pairs  — two example argument strings, one pair then two pairs,
#                    used in the setter_empty and setter_mixed_dots remedies
#   container_noun — the Convention 2 container noun: "vector" / "list"
#
# The defaults render all five templates byte-identically to their pre-1.2.0
# text, so no existing setter's message changes. The container noun cannot be
# derived from content_type — a "scalar" content type still takes a named
# vector in Convention 2 — so it is its own parameter.
.parse_setter_input <- function(
  dots,
  variable,
  content,
  content_arg_name,
  content_type = c("scalar", "vector"),
  fn_name,
  name_arg_name = "variable",
  pair_noun = "variable-label",
  example_pairs = c(
    "age = 'Age in years'",
    "age = 'Age', income = 'Annual income'"
  ),
  container_noun = "vector",
  call = rlang::caller_env()
) {
  content_type <- match.arg(content_type)
  dots_len <- length(dots)
  var_provided <- !is.null(variable)

  # The two example calls are composed here rather than inline, so each cli
  # template interpolates one finished data variable.
  example_call_1 <- paste0(fn_name, "(x, ", example_pairs[[1L]], ")")
  example_call_2 <- paste0(fn_name, "(x, ", example_pairs[[2L]], ")")

  # Ambiguity: both ... and variable provided
  if (dots_len > 0L && var_provided) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Provide {name_arg_name} names via {.arg ...} or via ",
          "{.arg {name_arg_name}}, not both."
        ),
        "i" = paste0(
          "Use named {.arg ...} args, a named {container_noun} in",
          " {.arg ...}, or {.arg {name_arg_name}} +",
          " {.arg {content_arg_name}} \u2014 not a mix."
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
        "x" = "{.fn {fn_name}} requires at least one {pair_noun} pair.",
        "v" = paste0(
          "Use named {.arg ...} args: ",
          "{.code {example_call_1}}."
        )
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
          "!" = paste0(
            "{.fn {fn_name}} was called with {.arg {name_arg_name}} of",
            " length 0."
          ),
          "i" = paste0(
            "No metadata was set. Did you accidentally filter ",
            "all {name_arg_name} names out?"
          )
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
            "{.arg {name_arg_name}} has {length(variable)} element{?s} but",
            " {.arg {content_arg_name}} has {length(content)} element{?s}."
          ),
          "i" = paste0(
            "They must be the same length ",
            "(one content value per {name_arg_name} name)."
          )
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
      is_named_char_vec <- (is.character(elem) &&
        !is.null(names(elem)) &&
        length(elem) > 0L &&
        all(nzchar(names(elem))))
      is_named_list <- (is.list(elem) &&
        !is.null(names(elem)) &&
        length(elem) > 0L &&
        all(nzchar(names(elem))))
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
          "Use {.code {example_call_2}}",
          " or a fully named {container_noun}."
        )
      ),
      class = "surveycore_error_setter_mixed_dots",
      call = call
    )
  }

  # Convention 1: all elements are named
  dots
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

  switch(
    format,
    "named_vector" = {
      if (length(var_names) == 0L) {
        return(character(0L))
      }
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
        "x" = paste0(
          "{.fn {fn_name}} received an invalid {.arg format} ",
          "value {.val {format}}."
        ),
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
    label = character(0L),
    value = character(0L)
  )

  if (length(result_list) == 0L) {
    return(empty_out)
  }

  rows <- lapply(names(result_list), function(var_name) {
    vec <- result_list[[var_name]]
    if (is.null(vec) || length(vec) == 0L) {
      return(NULL)
    }
    lbl <- if (!is.null(names(vec))) {
      names(vec)
    } else {
      rep(NA_character_, length(vec))
    }
    tibble::tibble(
      variable = var_name,
      label = lbl,
      value = as.character(vec)
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1L))]

  if (length(rows) == 0L) {
    return(empty_out)
  }

  dplyr::bind_rows(rows)
}

# .format_logical_result(result, format)
# Converts a named logical vector into the format requested by extract_sata().
# - "named_vector": returns the input vector as-is (empty: logical(0)).
# - "list": as.list(result) (empty: list()).
# - "data_frame": tibble with columns `variable` and `sata`
#   (empty: zero-row tibble with both columns typed).
.format_logical_result <- function(result, format) {
  switch(
    format,
    "named_vector" = result,
    "list" = as.list(result),
    "data_frame" = tibble::tibble(
      variable = names(result),
      sata = unname(result)
    )
  )
}


# ── Input check helper ────────────────────────────────────────────────────────

# Used by all exported functions to produce a consistent error when x is not
# a survey design object.
.check_is_survey <- function(x, call = rlang::caller_env()) {
  if (!S7::S7_inherits(x, survey_base)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg x} must be a survey design object, not ",
          "{.cls {class(x)[[1L]]}}."
        ),
        "v" = paste0(
          "Create a survey object with {.fn as_survey}, ",
          "{.fn as_survey_replicate}, or {.fn as_survey_twophase}."
        )
      ),
      class = "surveycore_error_not_survey",
      call = call
    )
  }
  invisible(NULL)
}


# ── Extractors ────────────────────────────────────────────────────────────────

# Shared fill validator for individual extractors.
#
# The default accepts NULL or NA_character_ and renders the two-value message,
# byte-identically to every existing extractor. allow_na = TRUE widens the
# accepted set with plain (logical) NA and lists all three in the message;
# extract_dataset_metadata() is its only widened caller, because a
# dataset-metadata fill has to type-match a Date key as well as a character
# key, and `NA` is the only spelling that reads naturally for both.
.check_extractor_fill <- function(fill, fn_name, call, allow_na = FALSE) {
  accepted <- is.null(fill) ||
    identical(fill, NA_character_) ||
    (allow_na && identical(fill, NA))
  if (accepted) {
    return(invisible(NULL))
  }

  valid_values <- if (allow_na) {
    paste0(
      "{.val NULL} (omit), {.code NA}, or {.code NA_character_} ",
      "(include with NA)."
    )
  } else {
    "{.val NULL} (omit) or {.code NA_character_} (include with NA)."
  }

  cli::cli_abort(
    c(
      "x" = "{.fn {fn_name}} does not accept {.code fill = {.val {fill}}}.",
      "i" = paste0("Valid values for {.fn {fn_name}}: ", valid_values)
    ),
    class = "surveycore_error_fill_invalid",
    call = call
  )
}

# Shared format validator. valid_formats must match the function's contract.
.check_extractor_format <- function(format, fn_name, valid_formats, call) {
  if (!format %in% valid_formats) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.fn {fn_name}} received an invalid {.arg format} value ",
          "{.val {format}}."
        ),
        "i" = "{.arg format} must be one of {.val {valid_formats}}."
      ),
      class = "surveycore_error_format_invalid",
      call = call
    )
  }
  invisible(NULL)
}


#' Extract Variable Labels
#'
#' Returns variable labels for one or more variables in a survey design object
#' or data frame.
#'
#' @param x A survey design object or `data.frame`.
#' @param ... <[`tidy-select`][tidyselect::language]> Variables to query.
#'   Supports selection helpers: [tidyselect::starts_with()],
#'   [tidyselect::all_of()], [tidyselect::any_of()], [tidyselect::matches()],
#'   etc. If empty, returns metadata for all variables. Use
#'   [tidyselect::any_of()] to silently skip missing variable names.
#' @param format `character(1)`. Output format: `"named_vector"` (default),
#'   `"list"`, or `"data_frame"`.
#' @param fill Scalar or `NULL`. How to handle variables with no label:
#'   `NULL` (default) omits them; `NA_character_` includes them with `NA`.
#'
#' @return
#' - `"named_vector"` (default): named character vector. Empty: `character(0)`.
#' - `"list"`: named list of character scalars. Empty: `list()`.
#' - `"data_frame"`: tibble with columns `variable` and `label`. Empty:
#'   zero-row tibble.
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' extract_var_label(d)
#' extract_var_label(d, riagendr, ridageyr)
#' extract_var_label(d, format = "data_frame")
#' extract_var_label(d, fill = NA_character_)
#' @seealso [set_var_label()] to set a variable label
#' @family metadata
#' @export
extract_var_label <- function(x, ..., format = "named_vector", fill = NULL) {
  call <- rlang::caller_env()
  fn_name <- "extract_var_label"
  .check_extractor_fill(fill, fn_name, call)
  .check_extractor_format(
    format,
    fn_name,
    c("named_vector", "list", "data_frame"),
    call
  )
  .check_is_survey_or_df(x, call = call)
  var_names <- if (...length() == 0L) {
    .get_data_cols(x)
  } else {
    names(tidyselect::eval_select(
      rlang::expr(c(...)),
      data = .get_data_for_select(x)
    ))
  }
  result_list <- stats::setNames(
    lapply(var_names, function(v) {
      if (S7::S7_inherits(x, survey_base)) {
        x@metadata@variable_labels[[v]]
      } else {
        attr(x[[v]], "label", exact = TRUE)
      }
    }),
    var_names
  )
  .format_scalar_result(result_list, format, "label", fill)
}


#' Extract Value Labels
#'
#' Returns value labels for one or more variables in a survey design object
#' or data frame.
#'
#' @param x A survey design object or `data.frame`.
#' @param ... <[`tidy-select`][tidyselect::language]> Variables to query.
#'   Supports selection helpers: [tidyselect::starts_with()],
#'   [tidyselect::all_of()], [tidyselect::any_of()], [tidyselect::matches()],
#'   etc. If empty, returns metadata for all variables. Use
#'   [tidyselect::any_of()] to silently skip missing variable names.
#' @param format `character(1)`. Output format: `"list"` (default) or
#'   `"data_frame"`. `"named_vector"` is not valid for this function.
#' @param fill Scalar or `NULL`. How to handle variables with no labels:
#'   `NULL` (default) omits them; `NA_character_` includes them as `NULL`
#'   entries in `"list"` format. In `"data_frame"` format, variables with
#'   no labels are always excluded regardless of `fill`.
#'
#' @return
#' - `"list"` (default): named list of named vectors. Empty: `list()`.
#' - `"data_frame"`: long-format tibble with columns `variable`, `label`,
#'   `value` (codes coerced to character). Empty: zero-row tibble.
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' extract_val_labels(d, riagendr)
#' extract_val_labels(d, riagendr, format = "data_frame")
#' @seealso [set_val_labels()] to set value labels
#' @family metadata
#' @export
extract_val_labels <- function(x, ..., format = "list", fill = NULL) {
  call <- rlang::caller_env()
  fn_name <- "extract_val_labels"
  .check_extractor_fill(fill, fn_name, call)
  .check_extractor_format(format, fn_name, c("list", "data_frame"), call)
  .check_is_survey_or_df(x, call = call)
  var_names <- if (...length() == 0L) {
    .get_data_cols(x)
  } else {
    names(tidyselect::eval_select(
      rlang::expr(c(...)),
      data = .get_data_for_select(x)
    ))
  }
  result_list <- stats::setNames(
    lapply(var_names, function(v) {
      if (S7::S7_inherits(x, survey_base)) {
        x@metadata@value_labels[[v]]
      } else {
        attr(x[[v]], "labels", exact = TRUE)
      }
    }),
    var_names
  )
  if (is.null(fill)) {
    result_list <- result_list[!vapply(result_list, is.null, logical(1L))]
  }
  .format_list_result(result_list, format, fn_name)
}


#' Extract Question Prefaces
#'
#' Returns question preface text for one or more variables in a survey design
#' object or data frame.
#'
#' @param x A survey design object or `data.frame`.
#' @param ... <[`tidy-select`][tidyselect::language]> Variables to query.
#'   Supports selection helpers: [tidyselect::starts_with()],
#'   [tidyselect::all_of()], [tidyselect::any_of()], [tidyselect::matches()],
#'   etc. If empty, returns metadata for all variables. Use
#'   [tidyselect::any_of()] to silently skip missing variable names.
#' @param format `character(1)`. Output format: `"named_vector"` (default),
#'   `"list"`, or `"data_frame"`.
#' @param fill Scalar or `NULL`. How to handle variables with no preface:
#'   `NULL` (default) omits them; `NA_character_` includes them with `NA`.
#'
#' @return
#' - `"named_vector"` (default): named character vector. Empty: `character(0)`.
#' - `"list"`: named list of character scalars. Empty: `list()`.
#' - `"data_frame"`: tibble with columns `variable` and `preface`. Empty:
#'   zero-row tibble.
#'
#' @examples
#' d <- as_survey(
#'   gss_2024,
#'   ids = vpsu,
#'   weights = wtssps,
#'   strata = vstrat,
#'   nest = TRUE
#' )
#' d <- set_question_preface(d, happy = "Taken all together...")
#' extract_question_preface(d, happy)
#' @seealso [set_question_preface()] to set a question preface
#' @family metadata
#' @export
extract_question_preface <- function(
  x,
  ...,
  format = "named_vector",
  fill = NULL
) {
  call <- rlang::caller_env()
  fn_name <- "extract_question_preface"
  .check_extractor_fill(fill, fn_name, call)
  .check_extractor_format(
    format,
    fn_name,
    c("named_vector", "list", "data_frame"),
    call
  )
  .check_is_survey_or_df(x, call = call)
  var_names <- if (...length() == 0L) {
    .get_data_cols(x)
  } else {
    names(tidyselect::eval_select(
      rlang::expr(c(...)),
      data = .get_data_for_select(x)
    ))
  }
  result_list <- stats::setNames(
    lapply(var_names, function(v) {
      if (S7::S7_inherits(x, survey_base)) {
        x@metadata@question_prefaces[[v]]
      } else {
        attr(x[[v]], "question_preface", exact = TRUE)
      }
    }),
    var_names
  )
  .format_scalar_result(result_list, format, "preface", fill)
}


#' Extract Analyst Notes
#'
#' Returns analyst notes for one or more variables in a survey design object
#' or data frame.
#'
#' @param x A survey design object or `data.frame`.
#' @param ... <[`tidy-select`][tidyselect::language]> Variables to query.
#'   Supports selection helpers: [tidyselect::starts_with()],
#'   [tidyselect::all_of()], [tidyselect::any_of()], [tidyselect::matches()],
#'   etc. If empty, returns metadata for all variables. Use
#'   [tidyselect::any_of()] to silently skip missing variable names.
#' @param format `character(1)`. Output format: `"named_vector"` (default),
#'   `"list"`, or `"data_frame"`.
#' @param fill Scalar or `NULL`. How to handle variables with no note:
#'   `NULL` (default) omits them; `NA_character_` includes them with `NA`.
#'
#' @return
#' - `"named_vector"` (default): named character vector. Empty: `character(0)`.
#' - `"list"`: named list of character scalars. Empty: `list()`.
#' - `"data_frame"`: tibble with columns `variable` and `note`. Empty:
#'   zero-row tibble.
#'
#' @examples
#' d <- as_survey(
#'   gss_2024,
#'   ids = vpsu,
#'   weights = wtssps,
#'   strata = vstrat,
#'   nest = TRUE
#' )
#' d <- set_var_note(d, age = "Top-coded at 89")
#' extract_var_note(d, age)
#' @seealso [set_var_note()] to set a note
#' @family metadata
#' @export
extract_var_note <- function(x, ..., format = "named_vector", fill = NULL) {
  call <- rlang::caller_env()
  fn_name <- "extract_var_note"
  .check_extractor_fill(fill, fn_name, call)
  .check_extractor_format(
    format,
    fn_name,
    c("named_vector", "list", "data_frame"),
    call
  )
  .check_is_survey_or_df(x, call = call)
  var_names <- if (...length() == 0L) {
    .get_data_cols(x)
  } else {
    names(tidyselect::eval_select(
      rlang::expr(c(...)),
      data = .get_data_for_select(x)
    ))
  }
  result_list <- stats::setNames(
    lapply(var_names, function(v) {
      if (S7::S7_inherits(x, survey_base)) {
        x@metadata@notes[[v]]
      } else {
        attr(x[[v]], "note", exact = TRUE)
      }
    }),
    var_names
  )
  .format_scalar_result(result_list, format, "note", fill)
}


#' Extract Universe Descriptions
#'
#' Returns universe (eligibility) descriptions for one or more variables in a
#' survey design object or data frame.
#'
#' @param x A survey design object or `data.frame`.
#' @param ... <[`tidy-select`][tidyselect::language]> Variables to query.
#'   Supports selection helpers: [tidyselect::starts_with()],
#'   [tidyselect::all_of()], [tidyselect::any_of()], [tidyselect::matches()],
#'   etc. If empty, returns metadata for all variables. Use
#'   [tidyselect::any_of()] to silently skip missing variable names.
#' @param format `character(1)`. Output format: `"named_vector"` (default),
#'   `"list"`, or `"data_frame"`.
#' @param fill Scalar or `NULL`. How to handle variables with no universe:
#'   `NULL` (default) omits them; `NA_character_` includes them with `NA`.
#'
#' @return
#' - `"named_vector"` (default): named character vector. Empty: `character(0)`.
#' - `"list"`: named list of character scalars. Empty: `list()`.
#' - `"data_frame"`: tibble with columns `variable` and `universe`. Empty:
#'   zero-row tibble.
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' d <- set_universe(d, ridageyr = "All participants 0+")
#' extract_universe(d)
#' extract_universe(d, ridageyr, format = "data_frame")
#' @seealso [set_universe()] to set a universe description
#' @family metadata
#' @export
extract_universe <- function(x, ..., format = "named_vector", fill = NULL) {
  call <- rlang::caller_env()
  fn_name <- "extract_universe"
  .check_extractor_fill(fill, fn_name, call)
  .check_extractor_format(
    format,
    fn_name,
    c("named_vector", "list", "data_frame"),
    call
  )
  .check_is_survey_or_df(x, call = call)
  var_names <- if (...length() == 0L) {
    .get_data_cols(x)
  } else {
    names(tidyselect::eval_select(
      rlang::expr(c(...)),
      data = .get_data_for_select(x)
    ))
  }
  result_list <- stats::setNames(
    lapply(var_names, function(v) {
      if (S7::S7_inherits(x, survey_base)) {
        x@metadata@universe[[v]]
      } else {
        attr(x[[v]], "universe", exact = TRUE)
      }
    }),
    var_names
  )
  .format_scalar_result(result_list, format, "universe", fill)
}


#' Extract Missing Value Codes
#'
#' Returns missing value sentinel codes for one or more variables in a survey
#' design object or data frame.
#'
#' @param x A survey design object or `data.frame`.
#' @param ... <[`tidy-select`][tidyselect::language]> Variables to query.
#'   Supports selection helpers: [tidyselect::starts_with()],
#'   [tidyselect::all_of()], [tidyselect::any_of()], [tidyselect::matches()],
#'   etc. If empty, returns metadata for all variables. Use
#'   [tidyselect::any_of()] to silently skip missing variable names.
#' @param format `character(1)`. Output format: `"list"` (default) or
#'   `"data_frame"`. `"named_vector"` is not valid for this function.
#' @param fill Scalar or `NULL`. How to handle variables with no codes:
#'   `NULL` (default) omits them; `NA_character_` includes them as `NULL`
#'   entries in `"list"` format. In `"data_frame"` format, variables with
#'   no codes are always excluded regardless of `fill`.
#'
#' @return
#' - `"list"` (default): named list of atomic vectors. Empty: `list()`.
#' - `"data_frame"`: long-format tibble with columns `variable`, `description`
#'   (`NA` if codes vector is unnamed), `code` (coerced to character). Empty:
#'   zero-row tibble.
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' d <- set_missing_codes(d, ridageyr = c("Not applicable" = 999L))
#' extract_missing_codes(d, ridageyr)
#' extract_missing_codes(d, ridageyr, format = "data_frame")
#' @seealso [set_missing_codes()] to set missing value codes
#' @family metadata
#' @export
extract_missing_codes <- function(x, ..., format = "list", fill = NULL) {
  call <- rlang::caller_env()
  fn_name <- "extract_missing_codes"
  .check_extractor_fill(fill, fn_name, call)
  .check_extractor_format(format, fn_name, c("list", "data_frame"), call)
  .check_is_survey_or_df(x, call = call)
  var_names <- if (...length() == 0L) {
    .get_data_cols(x)
  } else {
    names(tidyselect::eval_select(
      rlang::expr(c(...)),
      data = .get_data_for_select(x)
    ))
  }
  result_list <- stats::setNames(
    lapply(var_names, function(v) {
      if (S7::S7_inherits(x, survey_base)) {
        x@metadata@missing_codes[[v]]
      } else {
        attr(x[[v]], "missing_codes", exact = TRUE)
      }
    }),
    var_names
  )
  if (is.null(fill)) {
    result_list <- result_list[!vapply(result_list, is.null, logical(1L))]
  }
  if (format == "list") {
    return(result_list)
  }
  # data_frame: long format with variable / description / code columns
  # (different column names from extract_val_labels data_frame)
  result_list_nonnull <- result_list[
    !vapply(result_list, is.null, logical(1L))
  ]
  empty_out <- tibble::tibble(
    variable = character(0L),
    description = character(0L),
    code = character(0L)
  )
  if (length(result_list_nonnull) == 0L) {
    return(empty_out)
  }
  rows <- lapply(names(result_list_nonnull), function(var_name) {
    vec <- result_list_nonnull[[var_name]]
    if (is.null(vec) || length(vec) == 0L) {
      return(NULL)
    }
    desc <- if (!is.null(names(vec))) {
      names(vec)
    } else {
      rep(NA_character_, length(vec))
    }
    tibble::tibble(
      variable = var_name,
      description = desc,
      code = as.character(vec)
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1L))]
  if (length(rows) == 0L) {
    return(empty_out)
  }
  dplyr::bind_rows(rows)
}


#' Extract Extension Slot Payload(s)
#'
#' Returns the extension-slot payload for one or more variables in a survey
#' design object or data frame. Read-only; performs no validation of payload
#' contents — values are returned exactly as stored, never coerced.
#'
#' @param x A survey design object or `data.frame`.
#' @param ... <[`tidy-select`][tidyselect::language]> Variables to query.
#'   Supports selection helpers: [tidyselect::starts_with()],
#'   [tidyselect::all_of()], [tidyselect::any_of()], [tidyselect::matches()],
#'   etc. If empty, returns the payload for every column in `x`. Use
#'   [tidyselect::any_of()] to silently skip missing variable names.
#' @param format `character(1)`. Output format: `"list"` (default) or
#'   `"data_frame"`. `"named_vector"` is not valid for this function (payloads
#'   are not scalar).
#' @param fill Scalar or `NULL`. How to handle variables with no payload:
#'   `NULL` (default) omits them; `NA_character_` includes them as `NULL`
#'   entries in `"list"` format. In `"data_frame"` format, variables with no
#'   payload are always excluded regardless of `fill`.
#'
#' @return
#' - `"list"` (default): named list. Keys are variable names; values are each
#'   variable's stored payload, or `NULL` for variables included via
#'   `fill = NA_character_` with no payload set. Empty: `list()`.
#' - `"data_frame"`: a tibble with columns `variable` (`character`), `key`
#'   (`character`), and `value` (a list-column, one raw payload value per
#'   row, unvalidated and untouched). One row per `(variable, key)` pair; a
#'   variable whose payload is `list()` or unset contributes zero rows.
#'   Empty: a zero-row tibble typed as above.
#'
#' @examples
#' d <- as_survey(
#'   gss_2024,
#'   ids = vpsu,
#'   weights = wtssps,
#'   strata = vstrat,
#'   nest = TRUE
#' )
#' d <- set_var_extra(d, age = list(role = "demographic"))
#' extract_var_extra(d, age)
#' extract_var_extra(d, age, format = "data_frame")
#' @seealso [set_var_extra()] to set an extension-slot payload
#' @family metadata
#' @export
extract_var_extra <- function(x, ..., format = "list", fill = NULL) {
  call <- rlang::caller_env()
  fn_name <- "extract_var_extra"
  .check_extractor_fill(fill, fn_name, call)
  .check_extractor_format(format, fn_name, c("list", "data_frame"), call)
  .check_is_survey_or_df(x, call = call)
  var_names <- if (...length() == 0L) {
    .get_data_cols(x)
  } else {
    names(tidyselect::eval_select(
      rlang::expr(c(...)),
      data = .get_data_for_select(x)
    ))
  }
  result_list <- stats::setNames(
    lapply(var_names, function(v) {
      if (S7::S7_inherits(x, survey_base)) {
        x@metadata@var_extra[[v]]
      } else {
        attr(x[[v]], "var_extra", exact = TRUE)
      }
    }),
    var_names
  )

  if (format == "list") {
    if (is.null(fill)) {
      result_list <- result_list[!vapply(result_list, is.null, logical(1L))]
    }
    return(result_list)
  }

  # data_frame: one row per (variable, key) pair. A variable with no payload
  # or an empty list() payload contributes zero rows, regardless of `fill` —
  # there are no keys to enumerate a row for. Written as a dedicated block
  # (rather than reusing .format_list_result()) because `value` must stay a
  # raw, unvalidated list-column — .format_list_result() coerces its `value`
  # column to character, which would fail the round-trip fidelity guarantee.
  result_list_nonnull <- result_list[
    !vapply(result_list, is.null, logical(1L))
  ]
  empty_out <- tibble::tibble(
    variable = character(0L),
    key = character(0L),
    value = list()
  )
  if (length(result_list_nonnull) == 0L) {
    return(empty_out)
  }
  rows <- lapply(names(result_list_nonnull), function(var_name) {
    payload <- result_list_nonnull[[var_name]]
    if (length(payload) == 0L) {
      return(NULL)
    }
    tibble::tibble(
      variable = var_name,
      key = names(payload),
      value = unname(payload)
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1L))]
  if (length(rows) == 0L) {
    return(empty_out)
  }
  dplyr::bind_rows(rows)
}


#' Extract All Metadata for Variables
#'
#' Returns a summary of all metadata fields for one or more variables in a
#' survey design object or data frame. Useful for auditing metadata state or
#' building codebooks.
#'
#' @details
#' This function reports per-variable fields only; dataset-level keys such as
#' `vendor` and `field_start` are not variables, so they are excluded — read
#' them with [extract_dataset_metadata()].
#'
#' @param x A survey design object or `data.frame`.
#' @param ... <[`tidy-select`][tidyselect::language]> Variables to query.
#'   Supports selection helpers: [tidyselect::starts_with()],
#'   [tidyselect::all_of()], [tidyselect::any_of()], [tidyselect::matches()],
#'   etc. If empty, returns metadata for all variables. Use
#'   [tidyselect::any_of()] to silently skip missing variable names.
#' @param fill `NULL` (default) or `"include"`. `NULL` omits variables that
#'   have no metadata in any field; `"include"` returns all variables
#'   regardless.
#'
#' @return A named list. Each entry is a named list with keys:
#'   `variable_label`, `value_labels`, `question_preface`, `note`,
#'   `universe`, `missing_codes`, `transformations`.
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' d <- set_universe(d, ridageyr = "All participants 0+")
#' extract_metadata(d, ridageyr)
#' extract_metadata(d, fill = "include")
#' @family metadata
#' @export
extract_metadata <- function(x, ..., fill = NULL) {
  call <- rlang::caller_env()
  fn_name <- "extract_metadata"
  if (!is.null(fill) && !identical(fill, "include")) {
    cli::cli_abort(
      c(
        "x" = "{.fn {fn_name}} does not accept {.code fill = {.val {fill}}}.",
        "i" = paste0(
          "Valid values for {.fn {fn_name}}: ",
          "{.val NULL} (omit empty) or {.val \"include\"} (return all)."
        )
      ),
      class = "surveycore_error_fill_invalid",
      call = call
    )
  }
  .check_is_survey_or_df(x, call = call)
  var_names <- if (...length() == 0L) {
    .get_data_cols(x)
  } else {
    names(tidyselect::eval_select(
      rlang::expr(c(...)),
      data = .get_data_for_select(x)
    ))
  }
  result <- stats::setNames(
    lapply(var_names, function(v) {
      if (S7::S7_inherits(x, survey_base)) {
        t <- x@metadata@transformations[[v]]
        list(
          variable_label = x@metadata@variable_labels[[v]],
          value_labels = x@metadata@value_labels[[v]],
          question_preface = x@metadata@question_prefaces[[v]],
          note = x@metadata@notes[[v]],
          universe = x@metadata@universe[[v]],
          missing_codes = x@metadata@missing_codes[[v]],
          transformations = if (is.null(t)) list() else t
        )
      } else {
        list(
          variable_label = attr(x[[v]], "label", exact = TRUE),
          value_labels = attr(x[[v]], "labels", exact = TRUE),
          question_preface = attr(x[[v]], "question_preface", exact = TRUE),
          note = attr(x[[v]], "note", exact = TRUE),
          universe = attr(x[[v]], "universe", exact = TRUE),
          missing_codes = attr(x[[v]], "missing_codes", exact = TRUE),
          transformations = list()
        )
      }
    }),
    var_names
  )
  if (is.null(fill)) {
    content_fields <- c(
      "variable_label",
      "value_labels",
      "question_preface",
      "note",
      "universe",
      "missing_codes"
    )
    has_meta <- vapply(
      result,
      function(entry) {
        any(
          !vapply(content_fields, function(f) is.null(entry[[f]]), logical(1L))
        ) ||
          length(entry$transformations) > 0L
      },
      logical(1L)
    )
    result <- result[has_meta]
    if (length(result) == 0L) return(list())
  }
  result
}


# ── Dataset-level metadata ────────────────────────────────────────────────────

# Resolve the effective dataset key-value list for either input mode. A survey
# object reads its metadata property through the guarded reader, so an object
# restored from a pre-1.2.0 file yields list(). A data frame reads the seven
# recognized whole-object attributes; the `dropped` report is discarded here,
# because extractors never warn.
.get_dataset_metadata_list <- function(x) {
  if (S7::S7_inherits(x, survey_base)) {
    return(.dataset_metadata_or_empty(x@metadata))
  }
  .read_dataset_attributes(x)$values
}

# Refuse a dataset-metadata WRITE on a survey object whose stored class predates
# the property. Reads are guarded and simply report nothing (see
# .dataset_metadata_or_empty()), but a write has nowhere to go, so it fails with
# a surveycore error naming the remedy rather than with S7's raw property error.
# The membership test is the same one the guarded reader uses.
#
# A data frame is always writable: attributes need no class property.
#
# @param x    A survey design object or a data frame.
# @param call The user-facing caller.
# @return Invisibly NULL, or an error.
.check_dataset_metadata_writable <- function(x, call = rlang::caller_env()) {
  if (!S7::S7_inherits(x, survey_base)) {
    return(invisible(NULL))
  }
  if ("dataset_metadata" %in% S7::prop_names(x@metadata)) {
    return(invisible(NULL))
  }
  cli::cli_abort(
    c(
      "x" = "This object cannot store dataset metadata.",
      "i" = paste0(
        "It was created by surveycore <= 1.1.0, before the ",
        "{.field dataset_metadata} property existed."
      ),
      "v" = paste0(
        "Rebuild the object with {.fn as_survey} (or the matching ",
        "constructor), then set the metadata."
      )
    ),
    class = "surveycore_error_dataset_metadata_unavailable",
    call = call
  )
}

# The nearest valid dataset key within Levenshtein distance 1 of the lowercased
# candidate, or NULL when nothing is that close. Lowercasing is what catches a
# capitalization slip such as `Vendor`; distance 1 catches `vender`.
#
# @param key character(1). The rejected key name.
# @return character(1) or NULL.
.dataset_key_suggestion <- function(key) {
  distances <- as.integer(
    utils::adist(tolower(key), .dataset_metadata_keys)
  )
  if (min(distances) > 1L) {
    return(NULL)
  }
  .dataset_metadata_keys[[which.min(distances)]]
}

# Raise the unknown-key error for a requested or supplied dataset key. The
# parameter is named `key` so the message template reads as the error table
# states it.
#
# Two bullets are always present: the rejection and the valid-key list. Two
# layers sit on top of them:
#   * the did-you-mean hint, whenever the key is a near miss;
#   * the legacy-`dates` explanation, which only a setter can trigger, because
#     it needs a non-NULL value. `dates = NULL` never reaches here — it resolves
#     to field_period. An extractor has no value at all, so it never sets
#     `legacy_alias`.
.abort_dataset_key_unknown <- function(key, call, legacy_alias = FALSE) {
  valid_keys <- .dataset_metadata_keys
  bullets <- c(
    "x" = "{.val {key}} is not a dataset metadata key.",
    "i" = "Valid keys: {.val {valid_keys}}."
  )

  suggestion <- .dataset_key_suggestion(key)
  if (!is.null(suggestion)) {
    bullets <- c(bullets, "i" = "Did you mean {.val {suggestion}}?")
  }

  if (legacy_alias) {
    bullets <- c(
      bullets,
      "i" = paste0(
        "The legacy {.val dates} attribute maps to {.val field_period}."
      ),
      "v" = "Use {.fn set_field_period}, or {.code dates = NULL} to delete."
    )
  }

  cli::cli_abort(
    bullets,
    class = "surveycore_error_dataset_key_unknown",
    call = call
  )
}

# Resolve one captured `...` element to a key name. Bare symbols and character
# scalars are names; anything else — a call, a tidyselect helper, a number — is
# not, and a dataset key is not a column, so no helper can apply.
.dataset_key_from_expr <- function(expr, call) {
  if (rlang::is_symbol(expr)) {
    return(rlang::as_string(expr))
  }
  if (is.character(expr) && length(expr) == 1L && !is.na(expr)) {
    return(expr)
  }
  cli::cli_abort(
    c(
      "x" = "{.arg ...} must contain bare key names or strings.",
      "i" = paste0(
        "Tidy-select helpers do not apply here: a dataset metadata key is ",
        "not a column."
      ),
      "v" = paste0(
        "Use bare names ({.code vendor}), strings ({.val vendor}), or the ",
        "{.arg key} argument."
      )
    ),
    class = "surveycore_error_dataset_key_not_name",
    call = call
  )
}

# Convert a resolved dataset-metadata list to the requested output shape.
#
# `result_list` arrives in output order, holding NULL for every key that is not
# set. A NULL fill drops those entries; a non-NULL fill keeps them, type-matched
# per key in "list" format and always NA_character_ in "data_frame" format.
#
# .format_scalar_result() is not reusable here: it names the first column
# `variable`, and its data_frame branch coerces through a character(1) vapply
# that cannot carry Date values or type-matched fills.
.format_dataset_result <- function(result_list, format, fill) {
  if (is.null(fill)) {
    result_list <- result_list[!vapply(result_list, is.null, logical(1L))]
  }
  keys <- names(result_list)

  if (format == "list") {
    if (length(keys) == 0L) {
      return(list())
    }
    filled <- lapply(keys, function(k) {
      value <- result_list[[k]]
      if (!is.null(value)) {
        return(value)
      }
      if (k %in% .dataset_date_keys) as.Date(NA) else NA_character_
    })
    return(stats::setNames(filled, keys))
  }

  # "data_frame": two columns, `key` and `value`, value always character.
  if (length(keys) == 0L) {
    return(tibble::tibble(key = character(0L), value = character(0L)))
  }
  values <- vapply(
    keys,
    function(k) {
      value <- result_list[[k]]
      if (is.null(value)) {
        return(NA_character_)
      }
      if (inherits(value, "Date")) format(value) else as.character(value)
    },
    character(1L),
    USE.NAMES = FALSE
  )
  tibble::tibble(key = keys, value = values)
}


#' Extract Dataset-Level Metadata
#'
#' Returns whole-dataset metadata — the survey name, the display name, the
#' fielding vendor, and the field dates — from a survey design object or a
#' data frame.
#'
#' @details
#' The key vocabulary is closed. Exactly six keys are valid, and this is their
#' canonical order:
#'
#' \describe{
#'   \item{`survey_name`}{`character(1)`. Full formal survey name.}
#'   \item{`data_name`}{`character(1)`. Display label for this dataset.}
#'   \item{`vendor`}{`character(1)`. Fielding vendor.}
#'   \item{`field_start`}{`Date(1)`. First day in the field.}
#'   \item{`field_end`}{`Date(1)`. Last day in the field.}
#'   \item{`field_period`}{`character(1)`. Prose field period, for display.}
#' }
#'
#' `survey_name` and `data_name` are independent. This function never reads one
#' to compute the other, and it never composes a label from the field dates.
#'
#' On a survey design object the stored metadata is the single source of truth;
#' attributes on the underlying data frame are not consulted. On a data frame
#' the six attribute names above are read directly, plus the pre-1.2.0 name
#' `dates`, which is read as `field_period` when no `field_period` attribute is
#' present. Any other attribute is ignored. An attribute whose value fails the
#' type rules above is dropped silently — this function never warns.
#'
#' A design object restored from a file written by surveycore 1.1.0 or earlier
#' reports no dataset metadata rather than failing.
#'
#' [extract_metadata()] is deliberately separate: it reports per-variable
#' fields only, and a dataset-level key is not a variable.
#'
#' Each key also has a convenience extractor that returns one scalar:
#' [extract_survey_name()], [extract_data_name()], [extract_vendor()],
#' [extract_field_dates()], and [extract_field_period()].
#'
#' @param x A survey design object or `data.frame`.
#' @param ... Keys to return, as bare names (`vendor`) or strings
#'   (`"vendor"`). Supports `!!!` splicing of a character vector of names.
#'   Matching is by plain name and is **not** tidy-select: a key is not a
#'   column, so selection helpers such as `all_of()` are rejected. Repeated
#'   requests are deduplicated, keeping the first position. If empty, returns
#'   every key that is set.
#' @param key `character` vector of key names, or `NULL` (default). A
#'   programmatic alternative to `...`; supplying both is an error. Must be
#'   supplied by name, because it follows `...`.
#' @param format `character(1)`. Output shape: `"list"` (default) or
#'   `"data_frame"`. Must be supplied by name, because it follows `...`.
#' @param fill `NULL` (default), `NA`, or `NA_character_`. Has two effects.
#'   For keys named in `...` or `key` that are not set: `NULL` omits them,
#'   while `NA` and `NA_character_` include them with a missing value. With an
#'   empty request, a non-`NULL` `fill` returns the full six-key schema with
#'   every absent key filled — the codebook idiom. Must be supplied by name,
#'   because it follows `...`.
#'
#' @return
#' - `"list"` (default): named list of the stored values, in request order, or
#'   canonical key order for an empty request. Date keys are `Date(1)`. A
#'   filled absent key is type-matched: `as.Date(NA)` for `field_start` and
#'   `field_end`, `NA_character_` for the four character keys. Empty result:
#'   `list()`.
#' - `"data_frame"`: tibble with columns `key` and `value`, both character. A
#'   `Date` renders through `format()` as `YYYY-MM-DD`, and a filled absent key
#'   is always `NA_character_` regardless of its type. Empty result: zero-row
#'   tibble with both columns.
#'
#' @examples
#' # On a data frame, dataset metadata lives in whole-object attributes.
#' df <- data.frame(id = 1:5, y = c(2, 4, 3, 5, 1), w = rep(1, 5))
#' attr(df, "survey_name") <- "Example Attitudes Survey 2026"
#' attr(df, "vendor") <- "Ipsos KnowledgePanel"
#' attr(df, "field_start") <- as.Date("2026-02-10")
#' attr(df, "field_end") <- as.Date("2026-03-04")
#'
#' extract_dataset_metadata(df)
#' extract_dataset_metadata(df, vendor)
#' extract_dataset_metadata(df, key = c("field_start", "field_end"))
#' extract_dataset_metadata(df, format = "data_frame")
#'
#' # An unset key is omitted by default, or filled on request.
#' extract_dataset_metadata(df, data_name)
#' extract_dataset_metadata(df, data_name, fill = NA)
#'
#' # A non-NULL fill plus an empty request gives the whole six-key schema.
#' extract_dataset_metadata(df, fill = NA, format = "data_frame")
#' @family metadata
#' @export
extract_dataset_metadata <- function(
  x,
  ...,
  key = NULL,
  format = "list",
  fill = NULL
) {
  call <- rlang::caller_env()
  fn_name <- "extract_dataset_metadata"

  .check_is_survey_or_df(x, call = call)
  .check_extractor_fill(fill, fn_name, call, allow_na = TRUE)
  .check_extractor_format(format, fn_name, c("list", "data_frame"), call)

  dots <- rlang::enexprs(...)
  if (length(dots) > 0L && !is.null(key)) {
    cli::cli_abort(
      c(
        "x" = "Provide key names via {.arg ...} or via {.arg key}, not both.",
        "i" = paste0(
          "Use named {.arg ...} args, a named list in {.arg ...}, or the ",
          "{.arg key} argument \u2014 not a mix."
        )
      ),
      class = "surveycore_error_setter_ambiguous",
      call = call
    )
  }

  requested <- if (length(dots) > 0L) {
    vapply(
      dots,
      function(expr) .dataset_key_from_expr(expr, call),
      character(1L),
      USE.NAMES = FALSE
    )
  } else if (!is.null(key)) {
    as.character(key)
  } else {
    NULL
  }

  if (!is.null(requested)) {
    requested <- requested[!duplicated(requested)]
    unknown <- setdiff(requested, .dataset_metadata_keys)
    if (length(unknown) > 0L) {
      .abort_dataset_key_unknown(unknown[[1L]], call)
    }
  }

  stored <- .get_dataset_metadata_list(x)

  out_keys <- if (!is.null(requested)) {
    requested
  } else if (is.null(fill)) {
    intersect(.dataset_metadata_keys, names(stored))
  } else {
    .dataset_metadata_keys
  }

  result_list <- stats::setNames(
    lapply(out_keys, function(k) stored[[k]]),
    out_keys
  )
  .format_dataset_result(result_list, format, fill)
}


#' Set Dataset-Level Metadata
#'
#' Sets whole-dataset metadata — the survey name, the display name, the fielding
#' vendor, and the field dates — on a survey design object or a data frame,
#' using one of three conventions.
#'
#' **Convention 1 (named `...`)** — recommended:
#' ```r
#' set_dataset_metadata(x, vendor = "Ipsos", field_start = "2026-02-10")
#' ```
#'
#' **Convention 2 (single named list in `...`)**:
#' ```r
#' set_dataset_metadata(x, list(vendor = "Ipsos"))
#' ```
#'
#' **Convention 3 (`key` + `value`)**:
#' ```r
#' set_dataset_metadata(x, key = "vendor", value = "Ipsos")
#' ```
#'
#' @details
#' The key vocabulary is closed. Exactly six keys are valid, and this is their
#' canonical order:
#'
#' \describe{
#'   \item{`survey_name`}{`character(1)`. Full formal survey name.}
#'   \item{`data_name`}{`character(1)`. Display label for this dataset.}
#'   \item{`vendor`}{`character(1)`. Fielding vendor.}
#'   \item{`field_start`}{`Date(1)`. First day in the field.}
#'   \item{`field_end`}{`Date(1)`. Last day in the field.}
#'   \item{`field_period`}{`character(1)`. Prose field period, for display.}
#' }
#'
#' Any other key is an error. The four character keys take one non-`NA` string.
#' The two date keys take a `Date` scalar or an ISO 8601 string
#' (`"YYYY-MM-DD"`), which is stored as a `Date`; a looser string such as
#' `"2026/02/10"` or `"2026-2-1"` is rejected. Stored keys are always kept in
#' the canonical order above.
#'
#' `survey_name` and `data_name` are independent. This function never reads one
#' to fill or check the other.
#'
#' Each key also has a convenience setter that takes one value:
#' [set_survey_name()], [set_data_name()], [set_vendor()], [set_field_dates()],
#' and [set_field_period()]. Use [extract_dataset_metadata()] to read the keys
#' back.
#'
#' A `NULL` value deletes a key. Deleting a key that is not set does nothing and
#' raises no condition. A zero-length value such as `character(0)` is not a
#' deletion — it is an invalid value.
#'
#' `field_start` must not be after `field_end`. The comparison uses the
#' *effective* value of each date: the new value when the call supplies one, no
#' value when the call supplies `NULL`, and the stored value otherwise. So one
#' call can repair a reversed stored pair by deleting one date and setting the
#' other. Every check runs before any write, so a rejected call changes nothing.
#'
#' On a survey design object the values go into the design's metadata, which is
#' the single source of truth on every read path; attributes on the underlying
#' data frame are neither read nor written. On a data frame the values go into
#' whole-object attributes, one per key, and the columns are left untouched —
#' even a column whose name matches a key.
#'
#' `dates` is the pre-1.2.0 attribute name for the prose field period. Setting
#' it is an error that points at `field_period` and [set_field_period()].
#' Deleting it is allowed:
#' `dates = NULL` is an alias for `field_period = NULL`, and either spelling
#' removes both the `field_period` and the legacy `dates` attribute from a data
#' frame.
#'
#' A design object restored from a file written by surveycore 1.1.0 or earlier
#' cannot store dataset metadata. Reading such an object works, but a write
#' raises an error naming the remedy: rebuild the object with a constructor.
#'
#' @section Attribute persistence:
#' On a data frame, dataset metadata lives in whole-object attributes, and
#' those are fragile. Common operations return a new frame without them:
#'
#' - base `[` when it selects columns, as in `df[, cols]`
#' - `merge()` and `subset()`
#' - `tibble::as_tibble()`, which has dropped them in some versions and keeps
#'   them in others, so neither behavior is safe to rely on
#'
#' So set dataset metadata **last**, directly before `usethis::use_data()`.
#' Or set it on the survey design instead: there it lives in the design's
#' metadata, where no data-frame operation can drop it.
#'
#' A constructor **copies** these attributes into the design; it never strips
#' them. The data frame inside a design therefore still carries the values it
#' was built with. A later `set_vendor()` call, or a deletion, changes the
#' design's metadata only. Rebuilding a design from the data frame that
#' [survey_data()] returns re-promotes the original attributes, so an edited or
#' deleted key comes back. Avoid that round trip and keep working with the
#' design object.
#'
#' @param x A survey design object or `data.frame`.
#' @param ... Named arguments where the name is a dataset metadata key and the
#'   value is the value to store. A single named list is also accepted.
#'   Supports `!!!` list splicing. A `NULL` value deletes the key.
#' @param key `character` vector of key names, or `NULL` (default). Use with
#'   `value`. Must be supplied by name, because it follows `...`.
#' @param value A list with one element per element of `key`, or `NULL`
#'   (default). An atomic vector is coerced with `as.list()`. Names on `value`
#'   are ignored — `key` supplies the names. A `NULL` element deletes that one
#'   key; `value = NULL` deletes every key in `key` and skips the length check.
#'   Must be supplied by name, because it follows `...`.
#'
#' @return The modified object, invisibly.
#'
#' @examples
#' # On a data frame, dataset metadata lives in whole-object attributes.
#' df <- data.frame(id = 1:5, y = c(2, 4, 3, 5, 1), w = rep(1, 5))
#' df <- set_dataset_metadata(
#'   df,
#'   survey_name = "Example Attitudes Survey 2026",
#'   vendor = "Ipsos KnowledgePanel"
#' )
#' extract_dataset_metadata(df)
#'
#' # An ISO 8601 string is stored as a Date.
#' df <- set_dataset_metadata(df, field_start = "2026-02-10")
#' extract_dataset_metadata(df, field_start)
#'
#' # Convention 2: one named list.
#' df <- set_dataset_metadata(df, list(field_end = "2026-03-04"))
#'
#' # Convention 3: key plus value.
#' df <- set_dataset_metadata(
#'   df,
#'   key = c("data_name", "field_period"),
#'   value = list("Example (February-March 2026)", "February-March 2026")
#' )
#' extract_dataset_metadata(df, format = "data_frame")
#'
#' # A NULL value deletes a key.
#' df <- set_dataset_metadata(df, vendor = NULL)
#' extract_dataset_metadata(df, vendor, fill = NA)
#'
#' # The same API works on a survey design object.
#' d <- as_survey(df, weights = w)
#' d <- set_dataset_metadata(d, vendor = "Cint")
#' extract_dataset_metadata(d, vendor)
#' @family metadata
#' @export
set_dataset_metadata <- function(x, ..., key = NULL, value = NULL) {
  call <- rlang::caller_env()

  # Rule 1: x is a survey object or a data frame.
  .check_is_survey_or_df(x, call = call)

  # Rule 2: the metadata object carries the property. This runs before any input
  # parsing, so an object restored from a pre-1.2.0 file reports the one problem
  # the caller has to fix first.
  .check_dataset_metadata_writable(x, call = call)

  # Rules 3-7 run inside the shared parser, in the key/key-value/list register.
  dots <- rlang::list2(...)
  pairs <- .parse_setter_input(
    dots = dots,
    variable = key,
    content = value,
    content_arg_name = "value",
    content_type = "vector",
    fn_name = "set_dataset_metadata",
    name_arg_name = "key",
    pair_noun = "key-value",
    example_pairs = c(
      "vendor = 'Ipsos'",
      "vendor = 'Ipsos', data_name = 'AAA Ipsos (February-March 2026)'"
    ),
    container_noun = "list",
    call = call
  )

  # A length-0 `key` warned inside the parser and returns nothing to write.
  if (length(pairs) == 0L) {
    return(invisible(x))
  }

  # Rule 8: every resulting key name is non-NA and non-empty. Conventions 1-2
  # cannot reach this: a blank or missing name there fails inside the parser as
  # surveycore_error_setter_mixed_dots. Convention 3 carries the names in `key`,
  # so it is the reachable route.
  keys <- names(pairs)
  bad <- is.na(keys) | !nzchar(keys)
  if (any(bad)) {
    n_bad <- sum(bad)
    cli::cli_abort(
      c(
        "x" = "All dataset metadata keys must have a non-empty name.",
        "i" = "Found {n_bad} unnamed or blank-named entr{?y/ies}."
      ),
      class = "surveycore_error_dataset_metadata_unnamed",
      call = call
    )
  }

  # Legacy alias. `dates = NULL` is the one accepted spelling of the pre-1.2.0
  # name: it is an explicit alias for `field_period = NULL`. It resolves BEFORE
  # the duplicate check, so a call naming both spellings names one key twice. A
  # non-NULL `dates` keeps its own name and falls to the unknown-key rule.
  alias <- keys == .dataset_legacy_period_attr &
    vapply(pairs, is.null, logical(1L))
  keys[alias] <- "field_period"
  names(pairs) <- keys

  # Rule 9: no key name appears twice in one call.
  dupes <- unique(keys[duplicated(keys)])
  if (length(dupes) > 0L) {
    cli::cli_abort(
      c(
        "x" = "Duplicate dataset metadata key{?s}: {.val {dupes}}.",
        "i" = "Each key must appear exactly once."
      ),
      class = "surveycore_error_dataset_metadata_duplicate_key",
      call = call
    )
  }

  # Rule 10: every key name is one of the six. A `dates` key surviving the
  # alias step necessarily carries a non-NULL value, which is the condition the
  # legacy explanation reports.
  unknown <- setdiff(keys, .dataset_metadata_keys)
  if (length(unknown) > 0L) {
    .abort_dataset_key_unknown(
      unknown[[1L]],
      call,
      legacy_alias = identical(unknown[[1L]], .dataset_legacy_period_attr)
    )
  }

  # Rule 11: every non-NULL value passes the canonical per-key value table. A
  # NULL value is a deletion, not a value, so it is not checked. Every check
  # runs before any write, which is what makes a rejected call atomic.
  for (k in names(pairs)) {
    if (!is.null(pairs[[k]])) {
      pairs[[k]] <- .check_dataset_key_value(
        k,
        pairs[[k]],
        mode = "error",
        key_style = "val",
        call = call
      )
    }
  }

  # The effective key-value list of `x`, read the same way in both input modes.
  stored <- .get_dataset_metadata_list(x)

  # Rule 12: the effective date pair, per the three-way rule. A key the call
  # supplies takes its new value; a key the call sets to NULL counts as ABSENT,
  # because the deletion counts; a key the call does not mention keeps the value
  # already stored. The comparison runs only when both effective values exist,
  # so one call can repair a reversed stored pair by deleting one date and
  # setting the other, and deleting both dates always succeeds.
  effective <- lapply(
    .dataset_date_keys,
    function(k) if (k %in% names(pairs)) pairs[[k]] else stored[[k]]
  )
  names(effective) <- .dataset_date_keys

  if (!is.null(effective$field_start) && !is.null(effective$field_end)) {
    if (effective$field_start > effective$field_end) {
      start <- format(effective$field_start)
      end <- format(effective$field_end)
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.val field_start} ({start}) is after {.val field_end} ({end})."
          ),
          "v" = "Swap the two dates, or correct the wrong one."
        ),
        class = "surveycore_error_field_dates_reversed",
        call = call
      )
    }
  }

  # Every check has passed, so the writes below cannot fail part-way.
  if (S7::S7_inherits(x, survey_base)) {
    for (k in names(pairs)) {
      stored[[k]] <- pairs[[k]]
    }
    x@metadata@dataset_metadata <- stored[
      intersect(.dataset_metadata_keys, names(stored))
    ]
    return(invisible(x))
  }

  # A data frame carries one whole-object attribute per key. Only the keys the
  # call names are written, so an attribute the call does not mention keeps its
  # value even when that value would fail the table.
  for (k in names(pairs)) {
    attr(x, k) <- pairs[[k]]
  }

  # Legacy cleanup. Deleting field_period removes the pre-1.2.0 `dates`
  # attribute too, so the deletion is idempotent and construction cannot
  # resurrect the value through the legacy read. Only a deletion cleans up;
  # writing a new field_period leaves `dates` in place, and the reader ignores
  # it because field_period is then present.
  if (
    "field_period" %in% names(pairs) && is.null(pairs[["field_period"]])
  ) {
    attr(x, .dataset_legacy_period_attr) <- NULL
  }
  invisible(x)
}


# ── Dataset-level metadata: convenience wrappers ──────────────────────────────

# Raise the setter_empty error a convenience setter owns. This is the WRAPPER's
# own message, not the general setter's key-value template: a wrapper has one
# named argument and no conventions, so the useful thing to report is the
# function the caller wrote and the argument the caller left out. A missing
# value is therefore a typed surveycore error, never a base "argument missing"
# error.
#
# @param fn_name character(1). The wrapper's own name.
# @param args    character. The wrapper's value argument(s): one name for the
#                four scalar setters, both date names for set_field_dates().
# @param call    The user-facing caller.
# @return Never returns; always raises.
.abort_wrapper_setter_empty <- function(fn_name, args, call) {
  headline <- if (length(args) == 1L) {
    "{.fn {fn_name}} requires a value for {.arg {args}}."
  } else {
    paste0(
      "{.fn {fn_name}} requires at least one of {.arg {args[[1L]]}} or ",
      "{.arg {args[[2L]]}}."
    )
  }
  cli::cli_abort(
    c(
      "x" = headline,
      "v" = paste0(
        "Supply a single character value, or {.code NULL} to delete the key."
      )
    ),
    class = "surveycore_error_setter_empty",
    call = call
  )
}

# The two guards every convenience setter runs before its own argument guard, in
# the order spec section VII fixes: the `x` class check first, then the
# stale-object property check. Running them here rather than relying on the
# delegated call is what makes a stale object report the rebuild remedy even
# when the caller also forgot the value.
.check_wrapper_target <- function(x, call) {
  .check_is_survey_or_df(x, call = call)
  .check_dataset_metadata_writable(x, call = call)
  invisible(NULL)
}

# Read one dataset metadata key as a scalar, filling an unset key with a
# type-matched NA. Delegating to extract_dataset_metadata() keeps ONE key
# resolution path: the guarded property read on a survey object and the silent
# seven-attribute read on a data frame, with the same value rules in both. The
# caller has already run the class check, and a fixed valid key with a fixed
# valid `fill` cannot fail, so the delegated call raises nothing.
.extract_dataset_scalar <- function(x, key) {
  extract_dataset_metadata(x, key = key, fill = NA)[[key]]
}

# Validate and coerce one supplied set_field_dates() argument. NULL is a
# deletion, not a value, so it passes straight through. Anything else goes
# through the canonical value table in the argument register, which is what
# makes the message name `field_start` / `field_end` as this function's own
# argument rather than as a stored key.
.coerce_wrapper_field_date <- function(key, value, call) {
  if (is.null(value)) {
    return(NULL)
  }
  .check_dataset_key_value(
    key,
    value,
    mode = "error",
    key_style = "arg",
    call = call
  )
}


#' Set the Fielding Vendor
#'
#' Sets the `vendor` dataset-level metadata key — the company that fielded the
#' survey — on a survey design object or a data frame.
#'
#' @details
#' A convenience wrapper for
#' `set_dataset_metadata(x, vendor = vendor)`. It writes only the `vendor` key
#' and leaves every other key untouched.
#'
#' @param x A survey design object or `data.frame`.
#' @param vendor `character(1)`, non-`NA`, or `NULL` to delete the key.
#'   Omitting it is an error, not a deletion.
#'
#' @return The modified object, invisibly.
#'
#' @examples
#' df <- data.frame(id = 1:5, y = c(2, 4, 3, 5, 1), w = rep(1, 5))
#' df <- set_vendor(df, "Ipsos KnowledgePanel")
#' extract_vendor(df)
#'
#' # NULL deletes the key.
#' df <- set_vendor(df, NULL)
#' extract_vendor(df)
#'
#' # The same call works on a survey design object.
#' d <- as_survey(df, weights = w)
#' d <- set_vendor(d, "Cint")
#' extract_vendor(d)
#' @family metadata
#' @export
set_vendor <- function(x, vendor) {
  call <- rlang::caller_env()
  .check_wrapper_target(x, call)
  if (rlang::is_missing(vendor)) {
    .abort_wrapper_setter_empty("set_vendor", "vendor", call)
  }
  invisible(set_dataset_metadata(x, vendor = vendor))
}


#' Extract the Fielding Vendor
#'
#' Returns the `vendor` dataset-level metadata key from a survey design object
#' or a data frame.
#'
#' @details
#' Returns the stored value only. This function never composes a value from
#' another key, and it never warns: an unset key is a normal state, reported as
#' `NA_character_`. A design object restored from a file written by surveycore
#' 1.1.0 or earlier reports `NA_character_` rather than failing.
#'
#' @param x A survey design object or `data.frame`.
#'
#' @return `character(1)`: the stored vendor, or `NA_character_` when the key is
#'   not set.
#'
#' @examples
#' df <- data.frame(id = 1:5, y = c(2, 4, 3, 5, 1), w = rep(1, 5))
#' extract_vendor(df)
#'
#' df <- set_vendor(df, "Ipsos KnowledgePanel")
#' extract_vendor(df)
#' @family metadata
#' @export
extract_vendor <- function(x) {
  .check_is_survey_or_df(x, call = rlang::caller_env())
  .extract_dataset_scalar(x, "vendor")
}


#' Set the Formal Survey Name
#'
#' Sets the `survey_name` dataset-level metadata key — the full formal name of
#' the survey — on a survey design object or a data frame.
#'
#' @details
#' A convenience wrapper for
#' `set_dataset_metadata(x, survey_name = name)`.
#'
#' `survey_name` and `data_name` are independent keys. This function writes
#' `survey_name` and nothing else: it never reads, fills, or checks
#' `data_name`. Use [set_data_name()] for the display label. The two values may
#' drift, and no function in the package reconciles them.
#'
#' @param x A survey design object or `data.frame`.
#' @param name `character(1)`, non-`NA`, or `NULL` to delete the key. Omitting
#'   it is an error, not a deletion.
#'
#' @return The modified object, invisibly.
#'
#' @examples
#' df <- data.frame(id = 1:5, y = c(2, 4, 3, 5, 1), w = rep(1, 5))
#' df <- set_survey_name(df, "Example Attitudes Survey 2026")
#' extract_survey_name(df)
#'
#' # The display label is a separate key and stays unset.
#' extract_data_name(df)
#'
#' d <- as_survey(df, weights = w)
#' d <- set_survey_name(d, "Example Attitudes Survey, Wave 2")
#' extract_survey_name(d)
#' @family metadata
#' @export
set_survey_name <- function(x, name) {
  call <- rlang::caller_env()
  .check_wrapper_target(x, call)
  if (rlang::is_missing(name)) {
    .abort_wrapper_setter_empty("set_survey_name", "name", call)
  }
  invisible(set_dataset_metadata(x, survey_name = name))
}


#' Extract the Formal Survey Name
#'
#' Returns the `survey_name` dataset-level metadata key from a survey design
#' object or a data frame.
#'
#' @details
#' Returns the stored `survey_name` only. When the key is not set this function
#' returns `NA_character_` even if `data_name` is set: the two keys are
#' independent, and no extractor substitutes one for the other. A design object
#' restored from a file written by surveycore 1.1.0 or earlier reports
#' `NA_character_` rather than failing.
#'
#' @param x A survey design object or `data.frame`.
#'
#' @return `character(1)`: the stored survey name, or `NA_character_` when the
#'   key is not set.
#'
#' @examples
#' df <- data.frame(id = 1:5, y = c(2, 4, 3, 5, 1), w = rep(1, 5))
#' extract_survey_name(df)
#'
#' df <- set_survey_name(df, "Example Attitudes Survey 2026")
#' extract_survey_name(df)
#' @family metadata
#' @export
extract_survey_name <- function(x) {
  .check_is_survey_or_df(x, call = rlang::caller_env())
  .extract_dataset_scalar(x, "survey_name")
}


#' Set the Dataset Display Name
#'
#' Sets the `data_name` dataset-level metadata key — the display label for this
#' particular dataset — on a survey design object or a data frame.
#'
#' @details
#' A convenience wrapper for `set_dataset_metadata(x, data_name = name)`.
#'
#' `data_name` is usually a short name plus the field period, for example
#' `"AAA Ipsos (February-March 2026)"`. It is independent of `survey_name`:
#' this function writes `data_name` and nothing else, and it never reads,
#' fills, or checks `survey_name`. Use [set_survey_name()] for the formal name.
#'
#' @param x A survey design object or `data.frame`.
#' @param name `character(1)`, non-`NA`, or `NULL` to delete the key. Omitting
#'   it is an error, not a deletion.
#'
#' @return The modified object, invisibly.
#'
#' @examples
#' df <- data.frame(id = 1:5, y = c(2, 4, 3, 5, 1), w = rep(1, 5))
#' df <- set_data_name(df, "Example (February-March 2026)")
#' extract_data_name(df)
#'
#' # The formal survey name is a separate key and stays unset.
#' extract_survey_name(df)
#'
#' d <- as_survey(df, weights = w)
#' d <- set_data_name(d, "Example (March 2026)")
#' extract_data_name(d)
#' @family metadata
#' @export
set_data_name <- function(x, name) {
  call <- rlang::caller_env()
  .check_wrapper_target(x, call)
  if (rlang::is_missing(name)) {
    .abort_wrapper_setter_empty("set_data_name", "name", call)
  }
  invisible(set_dataset_metadata(x, data_name = name))
}


#' Extract the Dataset Display Name
#'
#' Returns the `data_name` dataset-level metadata key from a survey design
#' object or a data frame.
#'
#' @details
#' Returns the stored `data_name` only. When the key is not set this function
#' returns `NA_character_` even when `survey_name`, `field_start`, `field_end`,
#' and `field_period` are all set. It never composes a label from the other
#' keys. A design object restored from a file written by surveycore 1.1.0 or
#' earlier reports `NA_character_` rather than failing.
#'
#' @param x A survey design object or `data.frame`.
#'
#' @return `character(1)`: the stored display name, or `NA_character_` when the
#'   key is not set.
#'
#' @examples
#' df <- data.frame(id = 1:5, y = c(2, 4, 3, 5, 1), w = rep(1, 5))
#' df <- set_survey_name(df, "Example Attitudes Survey 2026")
#'
#' # A set survey_name does not fill data_name.
#' extract_data_name(df)
#'
#' df <- set_data_name(df, "Example (February-March 2026)")
#' extract_data_name(df)
#' @family metadata
#' @export
extract_data_name <- function(x) {
  .check_is_survey_or_df(x, call = rlang::caller_env())
  .extract_dataset_scalar(x, "data_name")
}


#' Set the Prose Field Period
#'
#' Sets the `field_period` dataset-level metadata key — the field period
#' written for display, such as `"February-March 2026"` — on a survey design
#' object or a data frame.
#'
#' @details
#' A convenience wrapper for
#' `set_dataset_metadata(x, field_period = period)`.
#'
#' The argument is named `period` because the function name already carries the
#' `field_` context; the stored key is `field_period`. This function never
#' touches the two structured dates — use [set_field_dates()] for those.
#'
#' On a data frame, deleting the key also removes the pre-1.2.0 `dates`
#' attribute, so the deletion is idempotent and a later
#' [as_survey()] call cannot restore the old value.
#'
#' @param x A survey design object or `data.frame`.
#' @param period `character(1)`, non-`NA`, or `NULL` to delete the key.
#'   Omitting it is an error, not a deletion.
#'
#' @return The modified object, invisibly.
#'
#' @examples
#' df <- data.frame(id = 1:5, y = c(2, 4, 3, 5, 1), w = rep(1, 5))
#' df <- set_field_period(df, "February-March 2026")
#' extract_field_period(df)
#'
#' d <- as_survey(df, weights = w)
#' d <- set_field_period(d, "Spring 2026")
#' extract_field_period(d)
#' @family metadata
#' @export
set_field_period <- function(x, period) {
  call <- rlang::caller_env()
  .check_wrapper_target(x, call)
  if (rlang::is_missing(period)) {
    .abort_wrapper_setter_empty("set_field_period", "period", call)
  }
  invisible(set_dataset_metadata(x, field_period = period))
}


#' Extract the Prose Field Period
#'
#' Returns the `field_period` dataset-level metadata key from a survey design
#' object or a data frame.
#'
#' @details
#' Returns the stored `field_period` only. It never composes a period from
#' `field_start` and `field_end` — use [extract_field_dates()] for those. On a
#' data frame the pre-1.2.0 attribute name `dates` is read as `field_period`
#' when no `field_period` attribute is present. A design object restored from a
#' file written by surveycore 1.1.0 or earlier reports `NA_character_` rather
#' than failing.
#'
#' @param x A survey design object or `data.frame`.
#'
#' @return `character(1)`: the stored field period, or `NA_character_` when the
#'   key is not set.
#'
#' @examples
#' df <- data.frame(id = 1:5, y = c(2, 4, 3, 5, 1), w = rep(1, 5))
#' extract_field_period(df)
#'
#' df <- set_field_period(df, "February-March 2026")
#' extract_field_period(df)
#' @family metadata
#' @export
extract_field_period <- function(x) {
  .check_is_survey_or_df(x, call = rlang::caller_env())
  .extract_dataset_scalar(x, "field_period")
}


#' Set the Field Dates
#'
#' Sets the `field_start` and `field_end` dataset-level metadata keys — the
#' first and last day in the field — on a survey design object or a data frame.
#'
#' @details
#' A convenience wrapper for `set_dataset_metadata()` that forwards **only the
#' arguments the call supplies**. The three states of each argument are
#' distinct:
#'
#' \describe{
#'   \item{not supplied}{The stored key is left unchanged.}
#'   \item{`NULL`}{The stored key is deleted.}
#'   \item{a value}{The key is set, after validation and coercion.}
#' }
#'
#' A value is either a `Date` scalar or an ISO 8601 string (`"YYYY-MM-DD"`),
#' which is stored as a `Date`. A looser string such as `"2026/02/10"` or
#' `"2026-2-1"` is rejected, and the error names this function's own argument.
#'
#' `field_start` must not be after `field_end`. The comparison uses the
#' *effective* value of each key: the new value when the call supplies one, no
#' value when the call supplies `NULL`, and the stored value when the call does
#' not mention the key. So one call can repair a reversed stored pair by
#' deleting one date and setting the other, and deleting both always succeeds.
#'
#' This function never touches `field_period` — the prose period has its own
#' setter, [set_field_period()].
#'
#' @param x A survey design object or `data.frame`.
#' @param field_start `Date(1)`, an ISO 8601 `character(1)`, or `NULL` to
#'   delete the key. Omit the argument to leave the stored value unchanged.
#' @param field_end `Date(1)`, an ISO 8601 `character(1)`, or `NULL` to delete
#'   the key. Omit the argument to leave the stored value unchanged.
#'
#' @return The modified object, invisibly.
#'
#' @examples
#' df <- data.frame(id = 1:5, y = c(2, 4, 3, 5, 1), w = rep(1, 5))
#' df <- set_field_dates(df, "2026-02-10", "2026-03-04")
#' extract_field_dates(df)
#'
#' # Supplying one argument leaves the other key unchanged.
#' df <- set_field_dates(df, field_end = "2026-03-10")
#' extract_field_dates(df)
#'
#' # NULL deletes a key.
#' df <- set_field_dates(df, field_start = NULL)
#' extract_field_dates(df)
#'
#' d <- as_survey(df, weights = w)
#' d <- set_field_dates(d, field_start = as.Date("2026-02-11"))
#' extract_field_dates(d)
#' @family metadata
#' @export
set_field_dates <- function(x, field_start, field_end) {
  call <- rlang::caller_env()
  .check_wrapper_target(x, call)

  # Missing is tested on the unevaluated arguments, so an omitted argument is
  # never forced and never reaches the delegated call. That is what separates
  # "leave the stored key alone" from the explicit NULL that deletes it.
  supplied <- c(
    field_start = !rlang::is_missing(field_start),
    field_end = !rlang::is_missing(field_end)
  )
  if (!any(supplied)) {
    .abort_wrapper_setter_empty(
      "set_field_dates",
      .dataset_date_keys,
      call
    )
  }

  # Pre-validate in the wrapper, in the argument register and with the
  # wrapper's own `call`, so a bad value reports this function and this
  # function's argument name. The delegated call then receives Date values that
  # have already passed the canonical table.
  #
  # Each argument is read only inside its own branch: collecting both into one
  # list first would force the unsupplied one. `[<-` with a one-element list is
  # what keeps an explicit NULL in `pairs`, because `[[<-` would drop it and the
  # deletion would silently become "leave the key alone".
  pairs <- list()
  if (supplied[["field_start"]]) {
    pairs["field_start"] <- list(
      .coerce_wrapper_field_date("field_start", field_start, call)
    )
  }
  if (supplied[["field_end"]]) {
    pairs["field_end"] <- list(
      .coerce_wrapper_field_date("field_end", field_end, call)
    )
  }

  invisible(set_dataset_metadata(x, !!!pairs))
}


#' Extract the Field Dates
#'
#' Returns the `field_start` and `field_end` dataset-level metadata keys from a
#' survey design object or a data frame.
#'
#' @details
#' Returns the two structured dates only. The prose field period has its own
#' extractor, [extract_field_period()], and this function never derives one
#' from the other. An unset key is a normal state, reported as `as.Date(NA)`;
#' this function never warns. A design object restored from a file written by
#' surveycore 1.1.0 or earlier reports both entries as `as.Date(NA)` rather
#' than failing.
#'
#' @param x A survey design object or `data.frame`.
#'
#' @return A named list of length 2, `field_start` then `field_end`, each a
#'   `Date` of length 1. An unset key is `as.Date(NA)`.
#'
#' @examples
#' df <- data.frame(id = 1:5, y = c(2, 4, 3, 5, 1), w = rep(1, 5))
#' extract_field_dates(df)
#'
#' df <- set_field_dates(df, "2026-02-10", "2026-03-04")
#' extract_field_dates(df)
#' @family metadata
#' @export
extract_field_dates <- function(x) {
  .check_is_survey_or_df(x, call = rlang::caller_env())
  extract_dataset_metadata(x, key = .dataset_date_keys, fill = NA)
}


# ── Unified setters ───────────────────────────────────────────────────────────

# Internal helper: shared scalar validation for set_var_label(),
# set_question_preface(), set_var_note(), and set_universe().
# Errors with surveycore_error_label_not_scalar when content is non-NULL and
# is not a character scalar.
.validate_scalar_content <- function(content, var_name, call) {
  if (!is.null(content)) {
    if (!is.character(content) || length(content) != 1L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Label content for {.field {var_name}} must be a character",
            " scalar, not {.cls {class(content)[[1L]]}} of length",
            " {length(content)}."
          ),
          "v" = paste0(
            "Pass a single character string, e.g.",
            " {.code set_var_label(x, {var_name} = 'My label')}."
          )
        ),
        class = "surveycore_error_label_not_scalar",
        call = call
      )
    }
  }
  invisible(NULL)
}


#' Set Variable Label(s)
#'
#' Sets variable labels using one of three conventions.
#'
#' **Convention 1 (named `...`)** — recommended for interactive use:
#' ```r
#' set_var_label(x, age = "Age in years", income = "Annual income")
#' set_var_label(x, !!!labels_list)   # list splicing
#' ```
#'
#' **Convention 2 (named vector in `...`)** — useful for programmatic use:
#' ```r
#' set_var_label(x, c(age = "Age in years", income = "Annual income"))
#' ```
#'
#' **Convention 3 (`variable` + `label` arguments)** — for vector input:
#' ```r
#' vars <- c("age", "income")
#' lbls <- c("Age in years", "Annual income")
#' set_var_label(x, variable = vars, label = lbls)
#' ```
#'
#' @param x A survey design object or a data frame.
#' @param ... Named arguments where the name is the variable and the value is
#'   the label string. Supports `!!!` list splicing.
#' @param variable A character vector of variable names. Use with `label`.
#' @param label A character vector of label strings, one per element of
#'   `variable`.
#'
#' @return The modified object, invisibly.
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' d <- set_var_label(d, indfmpir = "Income-to-poverty ratio")
#'
#' # Multiple variables
#' d <- set_var_label(
#'   d,
#'   bpxsy1 = "Systolic BP (1st reading)",
#'   bpxdi1 = "Diastolic BP (1st reading)"
#' )
#' @seealso [extract_var_label()] to retrieve a label
#' @family metadata
#' @export
set_var_label <- function(x, ..., variable = NULL, label = NULL) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  # Detect old positional form: set_var_label(x, bare_symbol, "string")
  dot_quos <- rlang::enquos(...)
  nms <- names(dot_quos)
  if (
    length(dot_quos) == 2L &&
      (is.null(nms) ||
        (!nzchar(if (!is.null(nms[[1L]])) nms[[1L]] else "") &&
          !nzchar(if (!is.null(nms[[2L]])) nms[[2L]] else ""))) &&
      rlang::quo_is_symbol(dot_quos[[1L]])
  ) {
    val2 <- tryCatch(rlang::eval_tidy(dot_quos[[2L]]), error = function(e) NULL)
    if (is.character(val2) && length(val2) == 1L) {
      var_nm2 <- rlang::as_name(dot_quos[[1L]])
      cli::cli_abort(
        c(
          "x" = paste0(
            "The old positional calling form",
            " {.code set_var_label(x, var, content)} is no longer supported."
          ),
          "i" = "The new unified setter uses named arguments.",
          "v" = paste0(
            "Use {.code set_var_label(x, {var_nm2} = {.val {val2}})} ",
            "instead."
          )
        ),
        class = "surveycore_error_old_positional_setter",
        call = call
      )
    }
  }

  dots <- rlang::list2(...)
  pairs <- .parse_setter_input(
    dots = dots,
    variable = variable,
    content = label,
    content_arg_name = "label",
    content_type = "scalar",
    fn_name = "set_var_label",
    call = call
  )

  all_cols <- .get_data_cols(x)
  for (var_name in names(pairs)) {
    content <- pairs[[var_name]]
    if (!var_name %in% all_cols) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "Variable {.field {var_name}} not found in ",
            "{.arg x} and was skipped."
          )
        ),
        class = "surveycore_warning_var_not_found",
        call = call
      )
      next
    }
    .validate_scalar_content(content, var_name, call)
    if (S7::S7_inherits(x, survey_base)) {
      x@metadata@variable_labels[[var_name]] <- content
    } else {
      attr(x[[var_name]], "label") <- content
    }
  }
  invisible(x)
}


#' Set Value Labels
#'
#' Sets value labels for one or more variables using one of three conventions.
#'
#' **Convention 1 (named `...`)** — recommended:
#' ```r
#' set_val_labels(x, sex = c(Male = 1L, Female = 2L))
#' ```
#'
#' **Convention 2 (single named list in `...`)**:
#' ```r
#' set_val_labels(x, list(sex = c(Male = 1L, Female = 2L)))
#' ```
#'
#' **Convention 3 (`variable` + `labels`)**:
#' ```r
#' set_val_labels(x, variable = "sex", labels = c(Male = 1L, Female = 2L))
#' ```
#'
#' @param x A survey design object or a data frame.
#' @param ... Named arguments where the name is the variable and the value is
#'   a fully named vector of value labels. Supports `!!!` list splicing.
#' @param variable A character vector of variable names.
#' @param labels A list of named vectors, one per element of `variable`. When
#'   `variable` has length 1, a bare named vector is also accepted.
#'
#' @return The modified object, invisibly.
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' d <- set_val_labels(d, riagendr = c(Male = 1L, Female = 2L))
#' @seealso [extract_val_labels()] to retrieve value labels
#' @family metadata
#' @export
set_val_labels <- function(x, ..., variable = NULL, labels = NULL) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  # Convention 3 bare-vector exception: wrap scalar atomic vector in a list
  # when length(variable) == 1 and labels is not already a list.
  if (
    !is.null(variable) &&
      length(variable) == 1L &&
      !is.null(labels) &&
      !is.list(labels) &&
      is.atomic(labels)
  ) {
    labels <- list(labels)
  }

  dots <- rlang::list2(...)
  pairs <- .parse_setter_input(
    dots = dots,
    variable = variable,
    content = labels,
    content_arg_name = "labels",
    content_type = "vector",
    fn_name = "set_val_labels",
    call = call
  )

  all_cols <- .get_data_cols(x)
  for (var_name in names(pairs)) {
    content <- pairs[[var_name]]
    if (!var_name %in% all_cols) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "Variable {.field {var_name}} not found in ",
            "{.arg x} and was skipped."
          )
        ),
        class = "surveycore_warning_var_not_found",
        call = call
      )
      next
    }
    if (!is.null(content)) {
      if (is.null(names(content)) || any(!nzchar(names(content)))) {
        cli::cli_abort(
          c(
            "x" = "{.arg labels} must be a fully named vector.",
            "i" = "All elements must have names."
          ),
          class = "surveycore_error_labels_unnamed",
          call = call
        )
      }
      var_data <- if (S7::S7_inherits(x, survey_base)) {
        x@data[[var_name]]
      } else {
        x[[var_name]]
      }
      .validate_val_labels(var_data, content, var_name = var_name)
    }
    if (S7::S7_inherits(x, survey_base)) {
      x@metadata@value_labels[[var_name]] <- content
    } else {
      attr(x[[var_name]], "labels") <- content
    }
  }
  invisible(x)
}


#' Set Question Preface(s)
#'
#' Sets the question preface string for one or more variables. Question prefaces
#' are the shared introductory text for a battery of related questions.
#'
#' Supports Conventions 1, 2, and 3 — see [set_var_label()] for details.
#'
#' @param x A survey design object or a data frame.
#' @param ... Named arguments where the name is the variable and the value is
#'   the preface string. Supports `!!!` list splicing.
#' @param variable A character vector of variable names. Use with `preface`.
#' @param preface A character vector of preface strings, one per element of
#'   `variable`.
#'
#' @return The modified object, invisibly.
#'
#' @examples
#' d <- as_survey(
#'   gss_2024,
#'   ids = vpsu,
#'   weights = wtssps,
#'   strata = vstrat,
#'   nest = TRUE
#' )
#' d <- set_question_preface(d, happy = "Taken all together...")
#' extract_question_preface(d, happy)
#' @seealso [extract_question_preface()] to retrieve a preface
#' @family metadata
#' @export
set_question_preface <- function(x, ..., variable = NULL, preface = NULL) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  dots <- rlang::list2(...)
  pairs <- .parse_setter_input(
    dots = dots,
    variable = variable,
    content = preface,
    content_arg_name = "preface",
    content_type = "scalar",
    fn_name = "set_question_preface",
    call = call
  )

  all_cols <- .get_data_cols(x)
  for (var_name in names(pairs)) {
    content <- pairs[[var_name]]
    if (!var_name %in% all_cols) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "Variable {.field {var_name}} not found in ",
            "{.arg x} and was skipped."
          )
        ),
        class = "surveycore_warning_var_not_found",
        call = call
      )
      next
    }
    .validate_scalar_content(content, var_name, call)
    if (S7::S7_inherits(x, survey_base)) {
      x@metadata@question_prefaces[[var_name]] <- content
    } else {
      attr(x[[var_name]], "question_preface") <- content
    }
  }
  invisible(x)
}


#' Set Analyst Note(s)
#'
#' Sets an analyst note for one or more variables. Notes are free-text
#' annotations for documenting processing decisions, data quality concerns,
#' or other context.
#'
#' Supports Conventions 1, 2, and 3 — see [set_var_label()] for details.
#'
#' @param x A survey design object or a data frame.
#' @param ... Named arguments where the name is the variable and the value is
#'   the note string. Supports `!!!` list splicing.
#' @param variable A character vector of variable names. Use with `note`.
#' @param note A character vector of note strings, one per element of
#'   `variable`.
#'
#' @return The modified object, invisibly.
#'
#' @examples
#' d <- as_survey(
#'   gss_2024,
#'   ids = vpsu,
#'   weights = wtssps,
#'   strata = vstrat,
#'   nest = TRUE
#' )
#' d <- set_var_note(d, age = "Top-coded at 89")
#' extract_var_note(d, age)
#' @seealso [extract_var_note()] to retrieve a note
#' @family metadata
#' @export
set_var_note <- function(x, ..., variable = NULL, note = NULL) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  dots <- rlang::list2(...)
  pairs <- .parse_setter_input(
    dots = dots,
    variable = variable,
    content = note,
    content_arg_name = "note",
    content_type = "scalar",
    fn_name = "set_var_note",
    call = call
  )

  all_cols <- .get_data_cols(x)
  for (var_name in names(pairs)) {
    content <- pairs[[var_name]]
    if (!var_name %in% all_cols) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "Variable {.field {var_name}} not found in ",
            "{.arg x} and was skipped."
          )
        ),
        class = "surveycore_warning_var_not_found",
        call = call
      )
      next
    }
    .validate_scalar_content(content, var_name, call)
    if (S7::S7_inherits(x, survey_base)) {
      x@metadata@notes[[var_name]] <- content
    } else {
      attr(x[[var_name]], "note") <- content
    }
  }
  invisible(x)
}


#' Set Universe Description(s)
#'
#' Sets the universe description for one or more variables. The universe
#' describes the population to which a variable applies
#' (e.g., `"Adults 18+"`).
#'
#' Supports Conventions 1, 2, and 3 — see [set_var_label()] for details.
#'
#' @param x A survey design object or a data frame.
#' @param ... Named arguments where the name is the variable and the value is
#'   the universe description string. Supports `!!!` list splicing.
#' @param variable A character vector of variable names. Use with `universe`.
#' @param universe A character vector of universe description strings, one per
#'   element of `variable`.
#'
#' @return The modified object, invisibly.
#'
#' @examples
#' d <- as_survey(
#'   gss_2024,
#'   ids = vpsu,
#'   weights = wtssps,
#'   strata = vstrat,
#'   nest = TRUE
#' )
#' d <- set_universe(d, age = "All respondents 18+")
#' extract_metadata(d, age)
#' @seealso [extract_universe()] to retrieve universe descriptions
#' @family metadata
#' @export
set_universe <- function(x, ..., variable = NULL, universe = NULL) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  dots <- rlang::list2(...)
  pairs <- .parse_setter_input(
    dots = dots,
    variable = variable,
    content = universe,
    content_arg_name = "universe",
    content_type = "scalar",
    fn_name = "set_universe",
    call = call
  )

  all_cols <- .get_data_cols(x)
  for (var_name in names(pairs)) {
    content <- pairs[[var_name]]
    if (!var_name %in% all_cols) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "Variable {.field {var_name}} not found in ",
            "{.arg x} and was skipped."
          )
        ),
        class = "surveycore_warning_var_not_found",
        call = call
      )
      next
    }
    .validate_scalar_content(content, var_name, call)
    if (S7::S7_inherits(x, survey_base)) {
      x@metadata@universe[[var_name]] <- content
    } else {
      attr(x[[var_name]], "universe") <- content
    }
  }
  invisible(x)
}


#' Set Missing Code(s)
#'
#' Sets missing-value codes for one or more variables. Missing codes are atomic
#' vectors documenting which data values represent missing data
#' (e.g., `c(Refused = -2L, DontKnow = -1L)`).
#'
#' Supports Conventions 1, 2, and 3 — see [set_var_label()] for details on
#' the calling conventions. For Convention 3 with a single variable, a bare
#' named atomic vector is accepted in addition to a list.
#'
#' @param x A survey design object or a data frame.
#' @param ... Named arguments where the name is the variable and the value is
#'   a named atomic vector of missing codes. Supports `!!!` list splicing.
#' @param variable A character vector of variable names. Use with `codes`.
#' @param codes A list of named atomic vectors, one per element of `variable`.
#'   When `variable` has length 1, a bare named atomic vector is also accepted.
#'
#' @return The modified object, invisibly.
#'
#' @examples
#' d <- as_survey(
#'   gss_2024,
#'   ids = vpsu,
#'   weights = wtssps,
#'   strata = vstrat,
#'   nest = TRUE
#' )
#' d <- set_missing_codes(d, happy = c(Refused = -1L, DK = -2L))
#' extract_missing_codes(d, happy)
#' @seealso [extract_missing_codes()] to retrieve missing value codes
#' @family metadata
#' @export
set_missing_codes <- function(x, ..., variable = NULL, codes = NULL) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  # Convention 3 bare-vector exception: wrap atomic vector in a list
  # when length(variable) == 1 and codes is not already a list.
  if (
    !is.null(variable) &&
      length(variable) == 1L &&
      !is.null(codes) &&
      !is.list(codes) &&
      is.atomic(codes)
  ) {
    codes <- list(codes)
  }

  dots <- rlang::list2(...)
  pairs <- .parse_setter_input(
    dots = dots,
    variable = variable,
    content = codes,
    content_arg_name = "codes",
    content_type = "vector",
    fn_name = "set_missing_codes",
    call = call
  )

  all_cols <- .get_data_cols(x)
  for (var_name in names(pairs)) {
    content <- pairs[[var_name]]
    if (!var_name %in% all_cols) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "Variable {.field {var_name}} not found in ",
            "{.arg x} and was skipped."
          )
        ),
        class = "surveycore_warning_var_not_found",
        call = call
      )
      next
    }
    if (!is.null(content) && is.list(content)) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Missing codes for {.field {var_name}} must be an atomic",
            " vector, not a list."
          ),
          "i" = paste0(
            "Got class {.cls {class(content)[[1L]]}}."
          ),
          "v" = paste0(
            "Use {.code set_missing_codes(x, {var_name} =",
            " c(Missing = -1L))} instead."
          )
        ),
        class = "surveycore_error_missing_codes_not_vector",
        call = call
      )
    }
    if (S7::S7_inherits(x, survey_base)) {
      x@metadata@missing_codes[[var_name]] <- content
    } else {
      attr(x[[var_name]], "missing_codes") <- content
    }
  }
  invisible(x)
}


# .validate_var_extra_content(content, var_name, call)
# Shape-only check for one resolved var_extra payload: NULL or a list; a
# non-empty list must have names() present, non-empty, and unique. Never
# inspects values (however deeply nested) — see spec §III Errors.
.validate_var_extra_content <- function(content, var_name, call) {
  if (is.null(content)) {
    return(invisible(NULL))
  }
  if (!is.list(content)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Extension slot content for {.field {var_name}} must be a list",
          " or {.code NULL}, not {.cls {class(content)[[1L]]}}."
        ),
        "i" = paste0(
          "surveycore stores {.arg extra} as-is and does not validate its",
          " values, but every top-level entry must be named."
        ),
        "v" = paste0(
          "Pass a named list, e.g. {.code set_var_extra(x, {var_name} =",
          " list(role = \"free_text\"))}."
        )
      ),
      class = "surveycore_error_var_extra_not_list",
      call = call
    )
  }
  if (length(content) > 0L) {
    nms <- names(content)
    malformed <- is.null(nms) ||
      anyNA(nms) ||
      any(!nzchar(nms)) ||
      anyDuplicated(nms) > 0L
    if (malformed) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Extension slot content for {.field {var_name}} must be a",
            " list or {.code NULL}, not {.cls {class(content)[[1L]]}}."
          ),
          "i" = paste0(
            "surveycore stores {.arg extra} as-is and does not validate",
            " its values, but every top-level entry must be named."
          ),
          "v" = paste0(
            "Pass a named list, e.g. {.code set_var_extra(x, {var_name} =",
            " list(role = \"free_text\"))}."
          )
        ),
        class = "surveycore_error_var_extra_not_list",
        call = call
      )
    }
  }
  invisible(NULL)
}


#' Set Variable Extension Slot Payload(s)
#'
#' Sets a per-variable extension-slot payload — a flat, pass-through named
#' list that surveycore stores and returns unchanged. surveycore never reads,
#' validates, or acts on the payload's *values*; it confirms only that the
#' top-level value is a list or `NULL`, and that a non-empty list's top-level
#' names are present, non-empty, and unique.
#'
#' Supports Conventions 1, 2, and 3 — see [set_var_label()] for details on the
#' calling conventions. Unlike [set_missing_codes()], there is no bare-payload
#' shorthand for Convention 3 with a single variable: a bare named list cannot
#' be distinguished from a one-element outer list, so the payload must be
#' wrapped in an outer list (`extra = list(list(role = "demographic"))`).
#' Passing an un-wrapped named list of length 1 raises
#' `surveycore_error_var_extra_ambiguous_wrap`.
#'
#' @param x A survey design object or a data frame.
#' @param ... Named arguments where the name is the variable and the value is
#'   the extension payload (a list, or `NULL` to clear it). Supports `!!!`
#'   list splicing.
#' @param variable A character vector of variable names. Use with `extra`.
#' @param extra A list of payloads, one element per entry of `variable`, in
#'   the same order. Each element must itself be a list or `NULL`.
#'
#' @return The modified object, invisibly.
#'
#' @examples
#' d <- as_survey(
#'   gss_2024,
#'   ids = vpsu,
#'   weights = wtssps,
#'   strata = vstrat,
#'   nest = TRUE
#' )
#' d <- set_var_extra(d, age = list(role = "demographic"))
#' extract_var_extra(d, age)
#' @seealso [extract_var_extra()] to retrieve extension-slot payloads
#' @family metadata
#' @export
set_var_extra <- function(x, ..., variable = NULL, extra = NULL) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  # Ambiguous-wrap guard (Convention 3 only): a single variable whose extra
  # is itself a named list of length 1 almost certainly omitted the outer
  # wrap. Checked before .parse_setter_input() so it fires ahead of the
  # generic mismatched-lengths check. A correctly wrapped payload is an
  # UNNAMED length-1 outer list, so it never matches this guard.
  dots_len <- ...length()
  if (
    dots_len == 0L &&
      !is.null(variable) &&
      length(variable) == 1L &&
      is.list(extra) &&
      length(extra) == 1L &&
      !is.null(names(extra)) &&
      nzchar(names(extra)[[1L]])
  ) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg extra} for a single variable must be wrapped in an",
          " outer list."
        ),
        "i" = paste0(
          "{.code extra = list(role = \"free_text\")} is ambiguous with a",
          " length-1 outer list."
        ),
        "v" = "Use {.code extra = list(list(role = \"free_text\"))} instead."
      ),
      class = "surveycore_error_var_extra_ambiguous_wrap",
      call = call
    )
  }

  dots <- rlang::list2(...)
  pairs <- .parse_setter_input(
    dots = dots,
    variable = variable,
    content = extra,
    content_arg_name = "extra",
    content_type = "vector",
    fn_name = "set_var_extra",
    call = call
  )

  all_cols <- .get_data_cols(x)
  pair_names <- names(pairs)
  # Iterate by index, not by name: when the same variable name is repeated
  # within a single call (Convention 1), `pairs[[name]]` would always
  # resolve to the FIRST match. Indexing preserves argument order, so the
  # last repeated entry is the one actually stored (R's own `...` /
  # named-list semantics — see spec §III edge case).
  for (i in seq_along(pairs)) {
    var_name <- pair_names[[i]]
    content <- pairs[[i]]
    if (!var_name %in% all_cols) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "Variable {.field {var_name}} not found in ",
            "{.arg x} and was skipped."
          )
        ),
        class = "surveycore_warning_var_not_found",
        call = call
      )
      next
    }
    .validate_var_extra_content(content, var_name, call)
    if (S7::S7_inherits(x, survey_base)) {
      x@metadata@var_extra[[var_name]] <- content
    } else {
      attr(x[[var_name]], "var_extra") <- content
    }
  }
  invisible(x)
}


# ── SATA (Select-All-That-Apply) setter/getter ────────────────────────────────

#' Set SATA (Select-All-That-Apply) Flag
#'
#' Marks one or more variables as select-all-that-apply (SATA) in a survey
#' design object or a data frame. Unlike the other unified setters (which map
#' variable names to heterogeneous content), `set_sata()` applies a single
#' logical flag to all listed variables, so it uses a simplified two-convention
#' pattern.
#'
#' **Convention A (tidy-select `...`)** — recommended:
#' ```r
#' design |> set_sata(news_tv, news_online, news_radio)
#' design |> set_sata(starts_with("news_"))
#' ```
#'
#' **Convention B (`variable` = character vector)** — programmatic:
#' ```r
#' sata_vars <- c("news_tv", "news_online", "news_radio")
#' design |> set_sata(variable = sata_vars)
#' ```
#'
#' Setting `sata = FALSE` unmarks the listed variables.
#'
#' @param x A survey design object or `data.frame`.
#' @param ... <[`tidy-select`][tidyselect::language]> Variables to mark.
#'   Supports selection helpers: [tidyselect::starts_with()],
#'   [tidyselect::all_of()], [tidyselect::any_of()], etc. Cannot be combined
#'   with `variable`.
#' @param variable `character`. Alternative programmatic interface: character
#'   vector of variable names. Cannot be combined with `...`.
#' @param sata `logical(1)`. `TRUE` (default) marks variables as SATA; `FALSE`
#'   removes the SATA flag. `NA` is not accepted.
#'
#' @return The modified object, invisibly.
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' d <- set_sata(d, riagendr, ridageyr)
#' d <- set_sata(d, riagendr, sata = FALSE)
#' @seealso [extract_sata()] to retrieve SATA flags
#' @family metadata
#' @export
set_sata <- function(x, ..., variable = NULL, sata = TRUE) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  if (!is.logical(sata) || length(sata) != 1L || is.na(sata)) {
    cli::cli_abort(
      c("x" = "{.arg sata} must be {.code TRUE} or {.code FALSE}."),
      class = "surveycore_error_sata_not_logical",
      call = call
    )
  }

  dots_used <- ...length() > 0L
  var_used <- !is.null(variable)

  if (dots_used && var_used) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Provide variable names via {.arg ...} or via ",
          "{.arg variable}, not both."
        )
      ),
      class = "surveycore_error_sata_ambiguous_input",
      call = call
    )
  }

  if (!dots_used && (!var_used || length(variable) == 0L)) {
    cli::cli_abort(
      c("x" = "{.fn set_sata} requires at least one variable name."),
      class = "surveycore_error_sata_no_vars",
      call = call
    )
  }

  all_cols <- .get_data_cols(x)

  if (dots_used) {
    var_names <- names(tidyselect::eval_select(
      rlang::expr(c(...)),
      data = .get_data_for_select(x)
    ))
  } else {
    missing <- setdiff(variable, all_cols)
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
    var_names <- intersect(variable, all_cols)
  }

  for (v in var_names) {
    if (S7::S7_inherits(x, survey_base)) {
      if (isTRUE(sata)) {
        x@metadata@sata[[v]] <- TRUE
      } else {
        x@metadata@sata[[v]] <- NULL
      }
    } else {
      attr(x[[v]], "sata") <- if (isTRUE(sata)) TRUE else NULL
    }
  }

  invisible(x)
}


#' Extract SATA (Select-All-That-Apply) Flags
#'
#' Returns the SATA status for one or more variables in a survey design object
#' or a data frame.
#'
#' @param x A survey design object or `data.frame`.
#' @param ... <[`tidy-select`][tidyselect::language]> Variables to query.
#'   Supports selection helpers: [tidyselect::starts_with()],
#'   [tidyselect::all_of()], [tidyselect::any_of()], etc. If empty, returns
#'   SATA status for all columns of `x`.
#' @param format `character(1)`. Output format: `"named_vector"` (default),
#'   `"list"`, or `"data_frame"`.
#' @param fill `FALSE` (default) or `NULL`. Controls how unmarked variables
#'   are reported. `FALSE` includes them in the result with value `FALSE`
#'   (dense view); `NULL` omits them (sparse view). `TRUE` and other values
#'   are rejected.
#'
#' @return
#' - `"named_vector"` (default): named logical vector. Empty: `logical(0)`.
#' - `"list"`: named list of logical scalars. Empty: `list()`.
#' - `"data_frame"`: tibble with columns `variable` (character) and `sata`
#'   (logical). Empty: zero-row tibble.
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' d <- set_sata(d, riagendr)
#' extract_sata(d, riagendr)
#' extract_sata(d, fill = NULL)
#' @seealso [set_sata()] to set SATA flags
#' @family metadata
#' @export
extract_sata <- function(x, ..., format = "named_vector", fill = FALSE) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  if (!is.null(fill) && !identical(fill, FALSE)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg fill} must be {.code FALSE} or {.code NULL}."
        )
      ),
      class = "surveycore_error_fill_not_logical",
      call = call
    )
  }

  .check_extractor_format(
    format,
    "extract_sata",
    c("named_vector", "list", "data_frame"),
    call
  )

  var_names <- if (...length() == 0L) {
    .get_data_cols(x)
  } else {
    names(tidyselect::eval_select(
      rlang::expr(c(...)),
      data = .get_data_for_select(x)
    ))
  }

  result <- stats::setNames(
    vapply(
      var_names,
      function(v) {
        raw <- if (S7::S7_inherits(x, survey_base)) {
          x@metadata@sata[[v]]
        } else {
          attr(x[[v]], "sata", exact = TRUE)
        }
        isTRUE(raw)
      },
      logical(1L)
    ),
    var_names
  )

  if (is.null(fill)) {
    result <- result[result]
  }

  .format_logical_result(result, format)
}


# ── set_higher_is() / extract_higher_is() ─────────────────────────────────────

#' Set Direction-of-Improvement Attribute
#'
#' Records whether a higher value is better (`"better"`) or worse (`"worse"`)
#' for one or more variables in a survey design object or data frame. This
#' metadata is used by [get_diffs()] when `show_favorability = TRUE`.
#'
#' @param x A survey design object or `data.frame`.
#' @param ... Named arguments where the name is the variable and the value is
#'   the direction (`"better"` or `"worse"`). Supports Convention 1 (named
#'   args: `bpxsy1 = "worse"`) and Convention 2 (named character vector:
#'   `c(bpxsy1 = "worse", lbxtc = "better")`). Mutually exclusive with
#'   `variable`.
#' @param variable `character`. Variable name(s) — Convention 3 alternative
#'   to `...`. Mutually exclusive with `...`.
#' @param direction `character`. Direction value(s) for Convention 3. Must be
#'   `"better"`, `"worse"`, or `NULL` (to remove the attribute). Same length
#'   as `variable`, or `NULL` to remove.
#'
#' @return The modified object, invisibly.
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' d <- set_higher_is(d, bpxsy1 = "worse")
#' extract_higher_is(d, bpxsy1)
#' @seealso [extract_higher_is()] to retrieve direction attributes
#' @family metadata
#' @export
set_higher_is <- function(x, ..., variable = NULL, direction = NULL) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  dots <- rlang::list2(...)
  dots_used <- length(dots) > 0L
  var_used <- !is.null(variable)

  if (dots_used && var_used) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Provide variable names via {.arg ...} or via ",
          "{.arg variable}, not both."
        )
      ),
      class = "surveycore_error_higher_is_ambiguous_input",
      call = call
    )
  }

  if (!dots_used && !var_used) {
    cli::cli_abort(
      c("x" = "{.fn set_higher_is} requires at least one variable name."),
      class = "surveycore_error_higher_is_no_vars",
      call = call
    )
  }

  # Convention 3 pre-check: scalar direction validation before parse
  if (
    var_used &&
      length(direction) == 1L &&
      !is.null(direction) &&
      !direction %in% c("better", "worse")
  ) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg direction} must be {.val \"better\"} or {.val \"worse\"} ",
          "(or {.code NULL} to remove). Got {.val {direction}}."
        )
      ),
      class = "surveycore_error_direction_invalid",
      call = call
    )
  }

  pairs <- .parse_setter_input(
    dots = dots,
    variable = variable,
    content = direction,
    content_arg_name = "direction",
    content_type = "scalar",
    fn_name = "set_higher_is",
    call = call
  )

  all_cols <- .get_data_cols(x)

  for (v in names(pairs)) {
    if (!v %in% all_cols) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "1 variable not found in {.arg x} and was skipped: {.field {v}}."
          )
        ),
        class = "surveycore_warning_var_not_found",
        call = call
      )
      next
    }
    val <- pairs[[v]]
    if (!is.null(val) && !val %in% c("better", "worse")) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg direction} must be {.val \"better\"} or {.val \"worse\"} ",
            "(or {.code NULL} to remove). Got {.val {val}}."
          )
        ),
        class = "surveycore_error_direction_invalid",
        call = call
      )
    }
    if (S7::S7_inherits(x, survey_base)) {
      x@metadata@higher_is[[v]] <- val
    } else {
      attr(x[[v]], "higher_is") <- val
    }
  }

  invisible(x)
}


#' Extract Direction-of-Improvement Attributes
#'
#' Returns the direction-of-improvement (`"better"` or `"worse"`) for one or
#' more variables in a survey design object or data frame. Variables with no
#' direction set return `NA_character_`.
#'
#' @param x A survey design object or `data.frame`.
#' @param ... <[`tidy-select`][tidyselect::language]> Variables to query.
#'   If empty, returns direction for all columns of `x`. Mutually exclusive
#'   with `variable`.
#' @param variable `character`. Variable name(s) — alternative to `...`.
#'   Mutually exclusive with `...`.
#'
#' @return A named character vector. Unset variables return `NA_character_`.
#'   Returns `character(0)` (named, zero-length) when all specified variables
#'   are missing from `x`.
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' d <- set_higher_is(d, bpxsy1 = "worse")
#' extract_higher_is(d, bpxsy1)
#' extract_higher_is(d)
#' @seealso [set_higher_is()] to set direction attributes
#' @family metadata
#' @export
extract_higher_is <- function(x, ..., variable = NULL) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  dots_used <- ...length() > 0L
  var_used <- !is.null(variable)

  if (dots_used && var_used) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Provide variable names via {.arg ...} or via ",
          "{.arg variable}, not both."
        )
      ),
      class = "surveycore_error_higher_is_ambiguous_input",
      call = call
    )
  }

  all_cols <- .get_data_cols(x)

  if (dots_used) {
    var_names <- names(tidyselect::eval_select(
      rlang::expr(c(...)),
      data = .get_data_for_select(x)
    ))
  } else if (var_used) {
    missing <- setdiff(variable, all_cols)
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
    var_names <- intersect(variable, all_cols)
  } else {
    var_names <- all_cols
  }

  out <- vapply(
    var_names,
    function(v) {
      if (S7::S7_inherits(x, survey_base)) {
        x@metadata@higher_is[[v]] %||% NA_character_
      } else {
        attr(x[[v]], "higher_is", exact = TRUE) %||% NA_character_
      }
    },
    character(1L)
  )

  if (length(out) == 0L) {
    out <- unname(out)
  }
  out
}


# ── set_reverse_coded() / extract_reverse_coded() ─────────────────────────────

#' Set Reverse-Coded Flag
#'
#' Marks one or more variables as reverse-coded in a survey design object or
#' data frame. Uses the same two-convention pattern as [set_sata()].
#'
#' **Convention A (tidy-select `...`)** — recommended:
#' ```r
#' design |> set_reverse_coded(anxiety, worry)
#' ```
#'
#' **Convention B (`variable` = character vector)** — programmatic:
#' ```r
#' vars <- c("anxiety", "worry")
#' design |> set_reverse_coded(variable = vars)
#' ```
#'
#' Setting `reverse_coded = FALSE` removes the flag.
#'
#' @param x A survey design object or `data.frame`.
#' @param ... <[`tidy-select`][tidyselect::language]> Variables to mark.
#'   Cannot be combined with `variable`.
#' @param variable `character`. Alternative programmatic interface: character
#'   vector of variable names. Cannot be combined with `...`.
#' @param reverse_coded `logical(1)`. `TRUE` (default) marks variables as
#'   reverse-coded; `FALSE` removes the flag. `NA` is not accepted.
#'
#' @return The modified object, invisibly.
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' d <- set_reverse_coded(d, bpxsy1, ridageyr)
#' d <- set_reverse_coded(d, bpxsy1, reverse_coded = FALSE)
#' @seealso [extract_reverse_coded()] to retrieve reverse-coded flags
#' @family metadata
#' @export
set_reverse_coded <- function(x, ..., variable = NULL, reverse_coded = TRUE) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  if (
    !is.logical(reverse_coded) ||
      length(reverse_coded) != 1L ||
      is.na(reverse_coded)
  ) {
    cli::cli_abort(
      c("x" = "{.arg reverse_coded} must be {.code TRUE} or {.code FALSE}."),
      class = "surveycore_error_reverse_coded_not_logical",
      call = call
    )
  }

  dots_used <- ...length() > 0L
  var_used <- !is.null(variable)

  if (dots_used && var_used) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Provide variable names via {.arg ...} or via ",
          "{.arg variable}, not both."
        )
      ),
      class = "surveycore_error_reverse_coded_ambiguous_input",
      call = call
    )
  }

  if (!dots_used && (!var_used || length(variable) == 0L)) {
    cli::cli_abort(
      c("x" = "{.fn set_reverse_coded} requires at least one variable name."),
      class = "surveycore_error_reverse_coded_no_vars",
      call = call
    )
  }

  all_cols <- .get_data_cols(x)

  if (dots_used) {
    var_names <- names(tidyselect::eval_select(
      rlang::expr(c(...)),
      data = .get_data_for_select(x)
    ))
  } else {
    missing <- setdiff(variable, all_cols)
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
    var_names <- intersect(variable, all_cols)
  }

  for (v in var_names) {
    if (S7::S7_inherits(x, survey_base)) {
      x@metadata@reverse_coded[[v]] <- if (isTRUE(reverse_coded)) TRUE else NULL
    } else {
      attr(x[[v]], "reverse_coded") <- if (isTRUE(reverse_coded)) TRUE else NULL
    }
  }

  invisible(x)
}


#' Extract Reverse-Coded Flags
#'
#' Returns the reverse-coded status for one or more variables in a survey
#' design object or data frame.
#'
#' @param x A survey design object or `data.frame`.
#' @param ... <[`tidy-select`][tidyselect::language]> Variables to query.
#'   If empty, returns reverse-coded status for all columns of `x`.
#'   Cannot be combined with `variable`.
#' @param variable `character`. Alternative programmatic interface: character
#'   vector of variable names. Cannot be combined with `...`.
#'
#' @return A named logical vector. Variables not marked as reverse-coded return
#'   `FALSE`. When all specified variables are missing, returns `logical(0)`.
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' d <- set_reverse_coded(d, bpxsy1)
#' extract_reverse_coded(d, bpxsy1)
#' extract_reverse_coded(d)
#' @seealso [set_reverse_coded()] to set reverse-coded flags
#' @family metadata
#' @export
extract_reverse_coded <- function(x, ..., variable = NULL) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  dots_used <- ...length() > 0L
  var_used <- !is.null(variable)

  if (dots_used && var_used) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Provide variable names via {.arg ...} or via ",
          "{.arg variable}, not both."
        )
      ),
      class = "surveycore_error_reverse_coded_ambiguous_input",
      call = call
    )
  }

  all_cols <- .get_data_cols(x)

  if (dots_used) {
    var_names <- names(tidyselect::eval_select(
      rlang::expr(c(...)),
      data = .get_data_for_select(x)
    ))
  } else if (var_used) {
    missing <- setdiff(variable, all_cols)
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
    var_names <- intersect(variable, all_cols)
  } else {
    var_names <- all_cols
  }

  out <- vapply(
    var_names,
    function(v) {
      if (S7::S7_inherits(x, survey_base)) {
        isTRUE(x@metadata@reverse_coded[[v]])
      } else {
        isTRUE(attr(x[[v]], "reverse_coded", exact = TRUE))
      }
    },
    logical(1L)
  )

  if (length(out) == 0L) {
    out <- unname(out)
  }
  out
}


# ── classify_question_type() — variable type classifier ──────────────────────

#' Classify Variable Question Types
#'
#' Groups variables by their shared `question_preface` metadata and classifies
#' each group as one of `"single"`, `"sata"`, or `"battery"`. This is the single
#' source of truth used by downstream export functions to decide how to render
#' each question.
#'
#' The classification rules, applied per requested variable:
#'
#' 1. If the variable has no `question_preface`, or is the only requested
#'    variable sharing its preface, `type = "single"`.
#' 2. If a `question_preface` is shared by 2+ requested variables and at least
#'    one is flagged via [set_sata()], all variables in that group get
#'    `type = "sata"`.
#' 3. Otherwise (shared preface, no SATA flag), all variables in the group
#'    get `type = "battery"`.
#'
#' Group numbers are assigned sequentially by first appearance in the input.
#'
#' @param x A survey design object or `data.frame`.
#' @param ... <[`tidy-select`][tidyselect::language]> Variables to classify.
#'   Supports selection helpers: [tidyselect::starts_with()],
#'   [tidyselect::all_of()], [tidyselect::any_of()], etc. Cannot be combined
#'   with `variable`.
#' @param variable `character`. Alternative programmatic interface: character
#'   vector of variable names. Cannot be combined with `...`.
#'
#' @return A tibble with columns:
#' - `variable` (character) — variable name
#' - `question_preface` (character) — the preface, or `NA` if none
#' - `type` (character) — one of `"single"`, `"sata"`, or `"battery"`
#' - `group` (integer) — group id; variables with the same non-NA preface
#'   share a group
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' d <- set_question_preface(
#'   d,
#'   riagendr = "Demographics",
#'   ridageyr = "Demographics"
#' )
#' d <- set_sata(d, riagendr, ridageyr)
#' classify_question_type(d, riagendr, ridageyr, bpxsy1)
#' @seealso [set_sata()], [extract_sata()], [set_question_preface()]
#' @family metadata
#' @export
classify_question_type <- function(x, ..., variable = NULL) {
  call <- rlang::caller_env()
  .check_is_survey_or_df(x, call = call)

  dots_used <- ...length() > 0L
  var_used <- !is.null(variable)

  if (dots_used && var_used) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Provide variable names via {.arg ...} or via ",
          "{.arg variable}, not both."
        )
      ),
      class = "surveycore_error_detect_ambiguous_input",
      call = call
    )
  }

  if (!dots_used && (!var_used || length(variable) == 0L)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.fn classify_question_type} requires at least one variable name."
        )
      ),
      class = "surveycore_error_detect_no_vars",
      call = call
    )
  }

  all_cols <- .get_data_cols(x)

  if (dots_used) {
    var_names <- names(tidyselect::eval_select(
      rlang::expr(c(...)),
      data = .get_data_for_select(x)
    ))
  } else {
    missing <- setdiff(variable, all_cols)
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
    var_names <- intersect(variable, all_cols)
  }

  empty_out <- tibble::tibble(
    variable = character(0L),
    question_preface = character(0L),
    type = character(0L),
    group = integer(0L)
  )
  if (length(var_names) == 0L) {
    return(empty_out)
  }

  # Extract preface + sata for each requested variable
  is_survey <- S7::S7_inherits(x, survey_base)
  prefaces <- vapply(
    var_names,
    function(v) {
      raw <- if (is_survey) {
        x@metadata@question_prefaces[[v]]
      } else {
        attr(x[[v]], "question_preface", exact = TRUE)
      }
      if (is.null(raw) || !is.character(raw) || length(raw) == 0L) {
        NA_character_
      } else {
        raw[[1L]]
      }
    },
    character(1L)
  )
  sata_flags <- vapply(
    var_names,
    function(v) {
      raw <- if (is_survey) {
        x@metadata@sata[[v]]
      } else {
        attr(x[[v]], "sata", exact = TRUE)
      }
      isTRUE(raw)
    },
    logical(1L)
  )

  # Group numbering: sequential by first appearance of each non-NA preface.
  # Variables with NA preface each get their own unique group (one row each).
  # Variables that share a non-NA preface share a group number.
  group_ids <- integer(length(var_names))
  preface_to_group <- list()
  next_group <- 1L
  for (i in seq_along(var_names)) {
    p <- prefaces[[i]]
    if (is.na(p)) {
      group_ids[[i]] <- next_group
      next_group <- next_group + 1L
    } else {
      existing <- preface_to_group[[p]]
      if (is.null(existing)) {
        preface_to_group[[p]] <- next_group
        group_ids[[i]] <- next_group
        next_group <- next_group + 1L
      } else {
        group_ids[[i]] <- existing
      }
    }
  }

  # Classify each group
  types <- character(length(var_names))
  for (g in unique(group_ids)) {
    idx <- which(group_ids == g)
    group_prefs <- prefaces[idx]
    group_sata <- sata_flags[idx]
    if (length(idx) == 1L) {
      # Singleton group
      types[[idx]] <- "single"
      # Edge case: SATA-flagged with a preface but no peers → warn
      if (isTRUE(group_sata[[1L]]) && !is.na(group_prefs[[1L]])) {
        var_name <- var_names[[idx]]
        cli::cli_warn(
          c(
            "!" = paste0(
              "Variable {.field {var_name}} is marked SATA but has no",
              " shared {.code question_preface} with other variables.",
              " Classified as {.val single}."
            )
          ),
          class = "surveycore_warning_sata_no_preface",
          call = call
        )
      }
    } else {
      # Shared-preface group: sata if any flag is TRUE, else battery
      if (any(group_sata)) {
        types[idx] <- "sata"
        if (!all(group_sata)) {
          preface <- group_prefs[[1L]]
          cli::cli_warn(
            c(
              "!" = paste0(
                "Variables sharing {.code question_preface} {.val {preface}}",
                " have mixed SATA status. Treating entire group as",
                " {.val sata}. Use {.fn set_sata} to mark all variables",
                " in the group."
              )
            ),
            class = "surveycore_warning_sata_mixed_group",
            call = call
          )
        }
      } else {
        types[idx] <- "battery"
      }
    }
  }

  # Renumber groups to ensure contiguous 1..n in first-appearance order
  # (they already are by construction, but unname for cleanliness).
  tibble::tibble(
    variable = unname(var_names),
    question_preface = unname(prefaces),
    type = types,
    group = group_ids
  )
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
#' Also promotes a `"var_extra"` column attribute (set by [set_var_extra()]
#' on a data frame) into `@var_extra`, unlike the attributes above — it
#' promotes whenever the attribute is present and non-`NULL`, regardless of
#' length, because a `list()` payload is a valid "set but empty" state.
#'
#' Edge cases handled:
#' 1. Zero-length or empty-string variable labels — not stored.
#' 2. `NA` as a key in value labels — preserved (SPSS user-defined missing).
#' 3. Empty value-label vectors — not stored.
#' 4. Columns with no attributes — silently skipped.
#' 5. A `"var_extra"` attribute of `list()` — promoted unchanged, not
#'   filtered out as empty.
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
  notes <- list()
  universe <- list()
  missing_codes <- list()
  var_extra <- list()

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

    # ── Analyst note ──────────────────────────────────────────────────────────
    var_note <- attr(col, "note", exact = TRUE)
    if (
      !is.null(var_note) &&
        is.character(var_note) &&
        nzchar(var_note[[1L]])
    ) {
      notes[[col_name]] <- var_note[[1L]]
    }

    # ── Universe description ──────────────────────────────────────────────────
    var_universe <- attr(col, "universe", exact = TRUE)
    if (
      !is.null(var_universe) &&
        is.character(var_universe) &&
        nzchar(var_universe[[1L]])
    ) {
      universe[[col_name]] <- var_universe[[1L]]
    }

    # ── Missing codes ─────────────────────────────────────────────────────────
    var_missing <- attr(col, "missing_codes", exact = TRUE)
    if (
      !is.null(var_missing) &&
        is.atomic(var_missing) &&
        length(var_missing) > 0L
    ) {
      missing_codes[[col_name]] <- var_missing
    }

    # ── Extension-slot payload ────────────────────────────────────────────────
    # Unlike the blocks above, promotes whenever the attribute is present and
    # non-NULL, regardless of length — a payload of list() is a valid,
    # meaningful "set but empty" state (spec §III edge cases) that an
    # emptiness filter would silently revert to "never set."
    var_ext <- attr(col, "var_extra", exact = TRUE)
    if (!is.null(var_ext)) {
      var_extra[[col_name]] <- var_ext
    }
  }

  survey_metadata(
    variable_labels = var_labels,
    value_labels = val_labels,
    question_prefaces = q_prefaces,
    notes = notes,
    universe = universe,
    missing_codes = missing_codes,
    var_extra = var_extra
  )
}
