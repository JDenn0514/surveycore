# R/survey-collection.R
#
# Feature-group file for survey_collection mutators and internal helpers.
#   - .repair_collection_names()   — duplicate-name repair algorithm (§3.3.1)
#   - .resolve_caller_names()      — shared name resolution for constructor
#                                     and add_survey() (§3.3)
#   - add_survey()                 — append surveys to a collection (§3.7)
#   - remove_survey()              — drop surveys from a collection (§3.7)
#
# The dispatch helpers `.dispatch_over_collection()` and
# `.warn_on_meta_divergence()` will be appended to this file in PR 2.

# ── .repair_collection_names() ────────────────────────────────────────────────

#' Repair duplicate names by suffixing `_1`, `_2`, …
#'
#' Implements the algorithm in spec §3.3.1. The first occurrence of any
#' duplicated name is kept as-is; subsequent occurrences are suffixed with
#' `_1`, `_2`, … Skipping over suffixes already taken by other arguments.
#'
#' @param nms Character vector of caller-supplied names.
#' @return A list with two elements:
#'   - `repaired`: the repaired name vector (same length as `nms`).
#'   - `mapping`: a named character of `old → new` pairs for entries that
#'      changed, or `character(0)` if nothing changed.
#'
#' @keywords internal
#' @noRd
.repair_collection_names <- function(nms) {
  seen <- character(0L)
  out <- character(length(nms))
  for (i in seq_along(nms)) {
    nm <- nms[[i]]
    if (nm %in% seen) {
      j <- 1L
      repeat {
        candidate <- paste0(nm, "_", j)
        if (!(candidate %in% seen)) {
          break
        }
        j <- j + 1L
      }
      out[i] <- candidate
    } else {
      out[i] <- nm
    }
    seen <- c(seen, out[i])
  }

  changed <- out != nms
  if (any(changed)) {
    mapping <- stats::setNames(out[changed], nms[changed])
  } else {
    mapping <- character(0L)
  }

  list(repaired = out, mapping = mapping)
}


# ── .resolve_caller_names() ───────────────────────────────────────────────────

#' Resolve names for `...` arguments captured as quosures
#'
#' For each quosure: use the caller-supplied name if any; else if the
#' argument expression is a bare symbol, use its printed form; else raise
#' `surveycore_error_collection_unnamed_expr` (row C3) naming the 1-based
#' position of the offending argument.
#'
#' Shared between `as_survey_collection()` and `add_survey()` so the
#' error-class choice and position-index formatting stay consistent.
#'
#' @param quosures A list of quosures from `rlang::enquos(...)`.
#' @return A character vector of resolved names, same length as `quosures`.
#'
#' @keywords internal
#' @noRd
.resolve_caller_names <- function(quosures) {
  supplied <- names(quosures)
  if (is.null(supplied)) {
    supplied <- rep("", length(quosures))
  }

  out <- character(length(quosures))
  for (i in seq_along(quosures)) {
    nm <- supplied[[i]]
    q <- quosures[[i]]
    if (!is.na(nm) && nzchar(nm)) {
      out[i] <- nm
    } else if (rlang::quo_is_symbol(q)) {
      out[i] <- rlang::as_name(rlang::quo_get_expr(q))
    } else {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Argument {i} passed to {.fn as_survey_collection} is ",
            "unnamed and is not a bare symbol."
          ),
          "i" = paste0(
            "Collection elements must be named, or be supplied as ",
            "bare variable names so they can be auto-named."
          ),
          "v" = paste0(
            "Name the argument explicitly, e.g. ",
            "{.code as_survey_collection(wave1 = as_survey(df, ...))}."
          )
        ),
        class = "surveycore_error_collection_unnamed_expr"
      )
    }
  }
  out
}


# ── as_survey_collection() ────────────────────────────────────────────────────
# Constructor lives in R/core-constructors.R to match other as_survey_*()
# constructors. See that file.


# ── add_survey() ──────────────────────────────────────────────────────────────

#' Add Surveys to a `survey_collection`
#'
#' Appends one or more surveys to an existing collection and returns a new
#' `survey_collection`. The original collection is unchanged. Surveys may be
#' passed with explicit names or as bare symbols (auto-named, like
#' [as_survey_collection()]). Duplicate names are repaired by appending
#' `_1`, `_2`, … Existing names are never modified during repair.
#'
#' @details
#' Calling `add_survey(x)` with no additional surveys returns `x` unchanged;
#' no error is raised.
#'
#' @param .collection A `survey_collection`. Named with a leading dot so it
#'   cannot collide with user-supplied names in `...` (e.g., a survey named
#'   `"x"`).
#' @param ... One or more surveys to append. Accepts named arguments
#'   (`"wave3" = d3`) or bare symbols (`d3`, auto-named to `"d3"`). If a new
#'   name collides with an existing one (or with another new one), it is
#'   repaired by appending `_1`, `_2`, … and a
#'   `surveycore_warning_collection_duplicate_name_repaired` warning is
#'   emitted with the mapping.
#'
#' @return A new `survey_collection` with the appended surveys.
#'
#' @examples
#' d1 <- as_survey(gss_2024, ids = vpsu, weights = wtssps,
#'                 strata = vstrat, nest = TRUE)
#' d2 <- as_survey(gss_2024, ids = vpsu, weights = wtssps,
#'                 strata = vstrat, nest = TRUE)
#' coll <- as_survey_collection(a = d1)
#' coll2 <- add_survey(coll, b = d2)
#' names(coll2)
#'
#' @seealso [as_survey_collection()], [remove_survey()]
#' @family collections
#' @export
add_survey <- function(.collection, ...) {
  if (!S7::S7_inherits(.collection, survey_collection)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg .collection} must be a {.cls survey_collection}, not ",
          "{.cls {class(.collection)[[1L]]}}."
        )
      ),
      class = "surveycore_error_not_survey_collection"
    )
  }

  quosures <- rlang::enquos(...)
  if (length(quosures) == 0L) {
    return(.collection)
  }

  new_caller_names <- .resolve_caller_names(quosures)
  existing_names <- names(.collection@surveys)
  combined_names <- c(existing_names, new_caller_names)

  repair <- .repair_collection_names(combined_names)
  stopifnot(identical(
    repair$repaired[seq_along(existing_names)],
    existing_names
  ))

  if (length(repair$mapping) > 0L) {
    .warn_duplicate_name_repair(repair$mapping)
  }

  new_surveys <- lapply(quosures, rlang::eval_tidy)
  names(new_surveys) <- repair$repaired[
    seq.int(length(existing_names) + 1L, length(combined_names))
  ]

  combined_list <- c(.collection@surveys, new_surveys)
  survey_collection(surveys = combined_list)
}


# ── remove_survey() ───────────────────────────────────────────────────────────

#' Remove Surveys from a `survey_collection`
#'
#' Drops one or more named surveys from a collection and returns a new
#' `survey_collection`. Errors if any requested name is not present.
#'
#' @param x A `survey_collection`.
#' @param name Character vector of survey names to drop. All names must be
#'   present in `names(x)`.
#'
#' @return A new `survey_collection` without the dropped surveys. Errors
#'   `surveycore_error_collection_empty` if removing would leave the
#'   collection empty.
#'
#' @examples
#' d1 <- as_survey(gss_2024, ids = vpsu, weights = wtssps,
#'                 strata = vstrat, nest = TRUE)
#' d2 <- as_survey(gss_2024, ids = vpsu, weights = wtssps,
#'                 strata = vstrat, nest = TRUE)
#' coll <- as_survey_collection(a = d1, b = d2)
#' coll2 <- remove_survey(coll, "a")
#' names(coll2)
#'
#' @seealso [as_survey_collection()], [add_survey()]
#' @family collections
#' @export
remove_survey <- function(x, name) {
  if (!S7::S7_inherits(x, survey_collection)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg x} must be a {.cls survey_collection}, not ",
          "{.cls {class(x)[[1L]]}}."
        )
      ),
      class = "surveycore_error_not_survey_collection"
    )
  }
  if (!is.character(name)) {
    cli::cli_abort(
      c(
        "x" = "{.arg name} must be a character vector, not {.cls {class(name)}}."
      ),
      class = "surveycore_error_not_survey_collection"
    )
  }

  existing <- names(x@surveys)
  missing_names <- setdiff(name, existing)
  if (length(missing_names) > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Name{?s} not found in collection: {.val {missing_names}}."
        ),
        "i" = "Available: {.val {existing}}."
      ),
      class = "surveycore_error_collection_name_not_found"
    )
  }

  keep <- setdiff(existing, name)
  new_list <- x@surveys[keep]
  survey_collection(surveys = new_list)
}


# ── Internal warning helper ───────────────────────────────────────────────────

#' Emit the duplicate-name repair warning
#'
#' Shared between `as_survey_collection()` and `add_survey()` so the warning
#' wording and class stay consistent.
#'
#' @param mapping Named character: values = new names, names = originals.
#' @keywords internal
#' @noRd
.warn_duplicate_name_repair <- function(mapping) {
  pairs <- paste0(names(mapping), " -> ", unname(mapping))
  n <- length(pairs)
  cli::cli_warn(
    c(
      "!" = "Duplicate survey {cli::qty(n)}name{?s} in collection repaired.",
      "i" = "{cli::qty(n)}Rename{?s}: {.code {pairs}}."
    ),
    class = "surveycore_warning_collection_duplicate_name_repaired"
  )
}
