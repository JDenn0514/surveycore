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


# ── .dispatch_over_collection() ───────────────────────────────────────────────

#' Dispatch a `get_*()` analysis function across every survey in a collection
#'
#' Runs `fn(survey, ...)` for each survey in `collection@surveys`, handles
#' missing variables per `.on_missing`, row-binds the per-survey results,
#' prepends a `.id` identifier column, and carries over per-survey `.meta`
#' under `$per_survey`. See spec §4.1.
#'
#' @param fn          The `get_*()` function being dispatched.
#' @param collection  A `survey_collection`.
#' @param ...         Forwarded to `fn()`. NSE args must be forwarded with
#'   `{{ }}` at the dispatch-branch call site.
#' @param .id         Column name for the survey identifier.
#' @param .on_missing `"error"` (default) or `"skip"` — behavior when a
#'   survey is missing a requested variable.
#' @return A tibble (same S3 class as the per-survey results) with `.id`
#'   prepended and `.meta` carried over.
#'
#' @keywords internal
#' @noRd
.dispatch_over_collection <- function(
  fn,
  collection,
  ...,
  .id = ".survey",
  .on_missing = c("error", "skip")
) {
  if (
    !is.character(.id) ||
      length(.id) != 1L ||
      is.na(.id) ||
      !nzchar(.id)
  ) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg .id} must be a single non-empty, non-NA character ",
          "string. Got {.cls {class(.id)[1]}} of length {.val {length(.id)}}."
        )
      ),
      class = "surveycore_error_collection_invalid_id"
    )
  }

  .on_missing <- rlang::arg_match(.on_missing)
  nms <- names(collection@surveys)

  results <- list()
  skipped <- character(0L)
  for (nm in nms) {
    r <- tryCatch(
      fn(collection@surveys[[nm]], ...),
      surveycore_error_variable_not_found = function(cnd) {
        if (.on_missing == "skip") {
          skipped <<- c(skipped, nm)
          NULL
        } else {
          cli::cli_abort(
            c(
              "x" = paste0(
                "Survey {.val {nm}} in the collection is missing a ",
                "required variable."
              ),
              "i" = "Original error: {conditionMessage(cnd)}",
              "v" = paste0(
                "Set {.code .on_missing = \"skip\"} to drop surveys ",
                "missing the variable."
              )
            ),
            class = "surveycore_error_collection_missing_var",
            parent = cnd
          )
        }
      }
    )
    if (!is.null(r)) {
      results[[nm]] <- r
    }
  }

  if (length(skipped) > 0L) {
    cli::cli_inform(
      c(
        "i" = paste0(
          "Skipped {length(skipped)} survey{?s} missing the requested ",
          "variable: {.val {skipped}}."
        )
      ),
      class = "surveycore_message_collection_skipped_surveys"
    )
  }

  if (length(results) == 0L) {
    cli::cli_abort(
      c(
        "x" = "No surveys in the collection contained the requested variable."
      ),
      class = "surveycore_error_collection_all_skipped"
    )
  }

  first_cols <- names(results[[1L]])
  if (.id %in% first_cols) {
    id_name <- .id
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg .id} value {.val {id_name}} conflicts with a column ",
          "produced by the analysis function."
        ),
        "v" = paste0(
          "Pass a different {.arg .id}, e.g. {.code .id = \"wave\"}."
        )
      ),
      class = "surveycore_error_collection_id_collision"
    )
  }

  for (nm in names(results)) {
    results[[nm]][[.id]] <- nm
  }

  out <- tryCatch(
    dplyr::bind_rows(results),
    vctrs_error_incompatible_type = function(cnd) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Cannot combine per-survey results: column type mismatch. ",
            "Each survey must produce compatible types for shared columns."
          ),
          "i" = "Original error: {conditionMessage(cnd)}"
        ),
        class = "surveycore_error_collection_bind_type_mismatch",
        parent = cnd
      )
    },
    vctrs_error = function(cnd) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Cannot combine per-survey results: column type mismatch. ",
            "Each survey must produce compatible types for shared columns."
          ),
          "i" = "Original error: {conditionMessage(cnd)}"
        ),
        class = "surveycore_error_collection_bind_type_mismatch",
        parent = cnd
      )
    }
  )

  out <- out[, c(.id, setdiff(names(out), .id))]

  first_meta <- attr(results[[1L]], ".meta")
  per_survey_meta <- lapply(results, function(r) attr(r, ".meta"))
  collection_meta <- list(
    surveys = names(results),
    survey_classes = vapply(
      names(results),
      function(nm) {
        sub("^[^:]+::", "", class(collection@surveys[[nm]])[[1L]])
      },
      character(1L)
    )
  )
  new_meta <- c(
    first_meta,
    list(
      per_survey = per_survey_meta,
      collection = collection_meta
    )
  )
  attr(out, ".meta") <- new_meta

  .warn_on_meta_divergence(per_survey_meta)

  class(out) <- class(results[[1L]])
  out
}


# ── .warn_on_meta_divergence() ────────────────────────────────────────────────

#' Warn when per-survey metadata disagrees on a closed set of fields
#'
#' @details
#' The closed set of compared `(slot, var, field)` triples is:
#' `slot ∈ {"group", "x"}`, `var` is every variable-name key appearing under
#' either slot across any survey, and `field ∈ {"value_labels",
#' "variable_label", "question_preface"}`. Other keys (e.g.,
#' `variable_note`, user-added fields) are not compared. If a future change
#' adds a correctness-critical field, update this helper explicitly —
#' divergence scope is closed by design.
#'
#' Comparison uses `identical()`. Absence-vs-presence counts as divergence:
#' `identical(value, NULL)` is `FALSE`.
#'
#' @param per_survey_meta A named list of per-survey `.meta` lists.
#' @return `invisible(NULL)`. Emits a
#'   `surveycore_warning_collection_meta_divergence` warning when any
#'   divergent variable is found.
#'
#' @keywords internal
#' @noRd
.warn_on_meta_divergence <- function(per_survey_meta) {
  if (length(per_survey_meta) <= 1L) {
    return(invisible(NULL))
  }

  slots <- c("group", "x")
  fields <- c("value_labels", "variable_label", "question_preface")

  divergent <- character(0L)
  for (slot in slots) {
    vars <- unique(unlist(
      lapply(per_survey_meta, function(m) names(m[[slot]])),
      use.names = FALSE
    ))
    for (v in vars) {
      if (v %in% divergent) {
        next
      }
      for (field in fields) {
        vals <- lapply(
          per_survey_meta,
          function(m) m[[slot]][[v]][[field]]
        )
        first <- vals[[1L]]
        diverged <- FALSE
        for (i in seq.int(2L, length(vals))) {
          if (!identical(first, vals[[i]])) {
            diverged <- TRUE
            break
          }
        }
        if (diverged) {
          divergent <- c(divergent, v)
          break
        }
      }
    }
  }

  divergent <- sort(unique(divergent))

  if (length(divergent) == 0L) {
    return(invisible(NULL))
  }

  cli::cli_warn(
    c(
      "!" = paste0(
        "Per-survey metadata diverges for {length(divergent)} ",
        "variable{?s}: {.field {divergent}}."
      ),
      "i" = paste0(
        "The top-level {.code .meta} reflects only the first survey. ",
        "Per-survey metadata is preserved under ",
        "{.code attr(result, \".meta\")$per_survey}."
      ),
      "i" = paste0(
        "Downstream helpers (e.g., {.fn clean}, {.fn gt}) should consult ",
        "{.code $per_survey} for accurate per-row labeling."
      )
    ),
    class = "surveycore_warning_collection_meta_divergence"
  )
  invisible(NULL)
}
