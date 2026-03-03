# R/methods-print.R
#
# Print and summary S7 methods for survey design objects.
#
# All methods use S7::method() registration — NOT S3 syntax.
# S3 method naming (print.survey_taylor <- ...) is silently ignored
# for S7 objects and must never be used here.
#
# Classes defined in R/00-s7-classes.R:
#   survey_srs      — Simple random sample design
#   survey_taylor   — Taylor series linearization design
#   survey_replicate — Replicate weights design
#   survey_twophase — Two-phase sampling design
#
# See plans/surveycore-phase0-formal-specification.md Section VIII for
# the full output format specification.


# ── Internal helpers ────────────────────────────────────────────────────────

# Return the subset of @data to display, converted to tibble for printing.
# Respects @variables$visible_vars when set by surveytidy's select().
# NULL (the surveycore default) → all columns shown.
#' @noRd
.data_for_print <- function(x) {
  visible <- x@variables[["visible_vars"]]
  data <- if (!is.null(visible)) {
    x@data[, visible, drop = FALSE] # nocov — only set by surveytidy
  } else {
    x@data
  }
  tibble::as_tibble(data)
}

# Print a note about design variables that are not in data_shown.
# Only fires when surveytidy's select() has hidden design variables
# (i.e., visible_vars is set). Never fires in standalone surveycore use.
#' @noRd
.print_hidden_note <- function(design_vars, data_shown) {
  hidden <- setdiff(design_vars, names(data_shown))
  if (length(hidden) > 0L) { # nocov start — only set by surveytidy
    cli::cli_text("")
    cli::cli_bullets(c(
      "i" = "Design variables preserved but hidden: {.field {hidden}}.",
      "i" = "Use {.code print(x, full = TRUE)} to show all variables."
    ))
  } # nocov end
  invisible(NULL)
}

# Format weight distribution as bulleted list lines.
#' @noRd
.print_weight_distribution <- function(wts) {
  wt_min  <- round(min(wts, na.rm = TRUE), 2L)
  wt_max  <- round(max(wts, na.rm = TRUE), 2L)
  wt_mean <- round(mean(wts, na.rm = TRUE), 2L)
  wt_cv   <- if (length(wts[!is.na(wts)]) > 1L) {
    round(stats::sd(wts, na.rm = TRUE) / mean(wts, na.rm = TRUE), 3L)
  } else {
    NA_real_
  }
  cli::cli_bullets(c(
    "*" = "Range: {.val {wt_min}} \u2013 {.val {wt_max}}",
    "*" = "Mean: {.val {wt_mean}}",
    "*" = "CV: {.val {wt_cv}}"
  ))
}


# ── print.survey_taylor ────────────────────────────────────────────────────

# Print a Taylor Series Survey Design
#
# @param x A survey_taylor object.
# @param n Maximum number of data rows to print. Default 10L.
# @param design_info Show design specification section?
# @param weights_info Show weight distribution statistics?
# @param strata_info Currently bundled into design_info.
# @param cluster_info Currently bundled into design_info.
# @param metadata_info Show metadata summary?
# @param full If TRUE, show all sections.
# @param ... Passed to tibble print.
# @return x, invisibly.
# Class defined in R/00-s7-classes.R
S7::method(print, survey_taylor) <- function(
  x,
  n             = 10L,
  design_info   = FALSE,
  weights_info  = FALSE,
  strata_info   = FALSE,
  cluster_info  = FALSE,
  metadata_info = FALSE,
  full          = FALSE,
  ...
) {
  if (full) {
    design_info <- weights_info <- strata_info <-
      cluster_info <- metadata_info <- TRUE
  }

  # ── Header ────────────────────────────────────────────────────────────────
  cli::cli_h1("Survey Design")
  cli::cli_text("{.cls survey_taylor} (Taylor series linearization)")
  cli::cli_text("Sample size: {.val {nrow(x@data)}}")

  if (length(x@groups) > 0L) {
    cli::cli_text("Groups: {.field {x@groups}}")
  }

  if (weights_info) {
    wts        <- x@data[[x@variables$weights]]
    weighted_n <- round(sum(wts, na.rm = TRUE))
    cli::cli_text("Weighted N: {.val {weighted_n}}")
  }

  # ── Design specification ──────────────────────────────────────────────────
  if (design_info) {
    cli::cli_text("")
    cli::cli_h2("Design specification")

    ids_vars <- x@variables$ids
    if (!is.null(ids_vars) && length(ids_vars) > 0L) {
      n_psus <- length(unique(x@data[[ids_vars[[1L]]]]))
      cli::cli_bullets(c(
        "*" = "IDs: {.field {ids_vars}} ({n_psus} PSUs)"
      ))
    }

    strata_var <- x@variables$strata
    if (!is.null(strata_var)) {
      n_strata <- length(unique(x@data[[strata_var]]))
      cli::cli_bullets(c(
        "*" = "Strata: {.field {strata_var}} ({n_strata} strata)"
      ))
    }

    wts_var <- x@variables$weights
    cli::cli_bullets(c("*" = "Weights: {.field {wts_var}}"))

    # Show "Weights provided as:" unless this is a pure SRS auto-weight design
    # (..surveycore_wt.. AND probs_provided = FALSE).
    # When probs are provided and converted to ..surveycore_wt.., still show
    # the "sampling probabilities (converted)" indicator.
    is_srs_auto <- identical(wts_var, "..surveycore_wt..") &&
      !isTRUE(x@variables$probs_provided)
    if (!is_srs_auto) {
      wt_source <- if (isTRUE(x@variables$probs_provided)) {
        "sampling probabilities (converted)"
      } else {
        "sampling weights"
      }
      cli::cli_bullets(c("*" = "Weights provided as: {wt_source}"))
    }

    fpc_var <- x@variables$fpc
    if (!is.null(fpc_var)) {
      cli::cli_bullets(c("*" = "FPC: {.field {fpc_var}}"))
    } else {
      cli::cli_bullets(c("*" = "FPC: not specified"))
    }

    cli::cli_bullets(c("*" = "Nesting: {.val {isTRUE(x@variables$nest)}}"))

    design_vars_spec <- unique(c(ids_vars, wts_var, strata_var, fpc_var))
    cli::cli_text("")
    cli::cli_text("Design variables: {.field {design_vars_spec}}")
  }

  # ── Weight distribution ───────────────────────────────────────────────────
  if (weights_info) {
    wts <- x@data[[x@variables$weights]]
    cli::cli_text("")
    cli::cli_h2("Weight distribution")
    .print_weight_distribution(wts)
  }

  # ── Metadata ──────────────────────────────────────────────────────────────
  if (metadata_info) {
    n_labeled <- length(x@metadata@variable_labels)
    cli::cli_text("")
    cli::cli_h2("Metadata")
    cli::cli_text("{n_labeled} variable(s) labeled")
  }

  # ── Data ──────────────────────────────────────────────────────────────────
  cli::cli_text("")
  data_shown <- .data_for_print(x)
  print(data_shown, n = n, ...)

  design_vars_all <- unique(c(
    x@variables$ids,
    x@variables$weights,
    x@variables$strata,
    x@variables$fpc
  ))
  .print_hidden_note(design_vars_all, data_shown)

  invisible(x)
}


# ── print.survey_srs ───────────────────────────────────────────────────────

# Print a Simple Random Sample Survey Design
#
# @param x A survey_srs object.
# @param n Maximum number of data rows to print. Default 10L.
# @param design_info Show design specification section?
# @param weights_info Show weight distribution statistics?
# @param metadata_info Show metadata summary?
# @param full If TRUE, show all sections.
# @param ... Passed to tibble print.
# @return x, invisibly.
# Class defined in R/00-s7-classes.R
S7::method(print, survey_srs) <- function(
  x,
  n             = 10L,
  design_info   = FALSE,
  weights_info  = FALSE,
  metadata_info = FALSE,
  full          = FALSE,
  ...
) {
  if (full) {
    design_info <- weights_info <- metadata_info <- TRUE
  }

  # ── Header ────────────────────────────────────────────────────────────────
  cli::cli_h1("Survey Design")
  cli::cli_text("{.cls survey_srs} (simple random sample)")
  cli::cli_text("Sample size: {.val {nrow(x@data)}}")

  if (length(x@groups) > 0L) {
    cli::cli_text("Groups: {.field {x@groups}}")
  }

  if (weights_info) {
    wts        <- x@data[[x@variables$weights]]
    weighted_n <- round(sum(wts, na.rm = TRUE))
    cli::cli_text("Weighted N: {.val {weighted_n}}")
  }

  # ── Design specification ──────────────────────────────────────────────────
  if (design_info) {
    cli::cli_text("")
    cli::cli_h2("Design")

    wts_var    <- x@variables$weights
    is_uniform <- identical(wts_var, .SURVEYCORE_WT_COL) &&
      !isTRUE(x@variables$probs_provided)
    if (is_uniform) {
      cli::cli_bullets(c("*" = "Weights: uniform (auto-assigned)"))
    } else if (isTRUE(x@variables$probs_provided)) {
      cli::cli_bullets(c(
        "*" = "Weights: {.field {wts_var}} (from sampling probabilities)"
      ))
    } else {
      cli::cli_bullets(c("*" = "Weights: {.field {wts_var}}"))
    }

    fpc_var  <- x@variables$fpc
    fpc_type <- x@variables$fpc_type
    if (!is.null(fpc_var)) {
      fpc_label <- if (identical(fpc_type, "population")) {
        "(population sizes)"
      } else {
        "(sampling fractions)"
      }
      cli::cli_bullets(c("*" = "FPC: {.field {fpc_var}} {fpc_label}"))
      fpc_col <- x@data[[fpc_var]]
      n_obs   <- nrow(x@data)
      f <- if (identical(fpc_type, "population")) {
        round(n_obs / mean(fpc_col, na.rm = TRUE), 4L)
      } else {
        round(mean(fpc_col, na.rm = TRUE), 4L)
      }
      cli::cli_bullets(c("*" = "Sampling fraction: {.val {f}}"))
    } else {
      cli::cli_bullets(c("*" = "FPC: not specified"))
    }
  }

  # ── Weight distribution ───────────────────────────────────────────────────
  if (weights_info) {
    wts <- x@data[[x@variables$weights]]
    cli::cli_text("")
    cli::cli_h2("Weight distribution")
    .print_weight_distribution(wts)
  }

  # ── Metadata ──────────────────────────────────────────────────────────────
  if (metadata_info) {
    n_labeled <- length(x@metadata@variable_labels)
    cli::cli_text("")
    cli::cli_h2("Metadata")
    cli::cli_text("{n_labeled} variable(s) labeled")
  }

  # ── Data ──────────────────────────────────────────────────────────────────
  cli::cli_text("")
  data_shown <- .data_for_print(x)
  print(data_shown, n = n, ...)

  .print_hidden_note(c(x@variables$weights, x@variables$fpc), data_shown)

  invisible(x)
}


# ── print.survey_replicate ─────────────────────────────────────────────────

# Print a Replicate Weights Survey Design
#
# @param x A survey_replicate object.
# @param n Maximum number of data rows to print. Default 10L.
# @param design_info Show design specification section?
# @param weights_info Show weight distribution statistics?
# @param strata_info Reserved.
# @param cluster_info Reserved.
# @param metadata_info Show metadata summary?
# @param full If TRUE, show all sections.
# @param ... Passed to tibble print.
# @return x, invisibly.
# Class defined in R/00-s7-classes.R
S7::method(print, survey_replicate) <- function(
  x,
  n             = 10L,
  design_info   = FALSE,
  weights_info  = FALSE,
  strata_info   = FALSE,
  cluster_info  = FALSE,
  metadata_info = FALSE,
  full          = FALSE,
  ...
) {
  if (full) {
    design_info <- weights_info <- strata_info <-
      cluster_info <- metadata_info <- TRUE
  }

  n_reps <- length(x@variables$repweights)

  # ── Header ────────────────────────────────────────────────────────────────
  cli::cli_h1("Survey Design")
  cli::cli_text(
    "{.cls survey_replicate} ({toupper(x@variables$type)}, {n_reps} replicates)"
  )
  cli::cli_text("Sample size: {.val {nrow(x@data)}}")

  if (length(x@groups) > 0L) {
    cli::cli_text("Groups: {.field {x@groups}}")
  }

  if (weights_info) {
    wts        <- x@data[[x@variables$weights]]
    weighted_n <- round(sum(wts, na.rm = TRUE))
    cli::cli_text("Weighted N: {.val {weighted_n}}")
  }

  # ── Design specification ──────────────────────────────────────────────────
  if (design_info) {
    cli::cli_text("")
    cli::cli_h2("Design specification")

    wts_var <- x@variables$weights
    cli::cli_bullets(c("*" = "Weights: {.field {wts_var}}"))
    cli::cli_bullets(c("*" = "Replicates: {n_reps} {toupper(x@variables$type)} replicate weight column(s)"))
    cli::cli_bullets(c("*" = "Scale: {.val {x@variables$scale}}"))
    cli::cli_bullets(c("*" = "MSE: {.val {isTRUE(x@variables$mse)}}"))

    fpc_var <- x@variables$fpc
    if (!is.null(fpc_var)) {
      cli::cli_bullets(c(
        "*" = "FPC: {.field {fpc_var}} ({x@variables$fpctype})"
      ))
    } else {
      cli::cli_bullets(c("*" = "FPC: not specified"))
    }
  }

  # ── Weight distribution ───────────────────────────────────────────────────
  if (weights_info) {
    wts <- x@data[[x@variables$weights]]
    cli::cli_text("")
    cli::cli_h2("Weight distribution")
    .print_weight_distribution(wts)
  }

  # ── Metadata ──────────────────────────────────────────────────────────────
  if (metadata_info) {
    n_labeled <- length(x@metadata@variable_labels)
    cli::cli_text("")
    cli::cli_h2("Metadata")
    cli::cli_text("{n_labeled} variable(s) labeled")
  }

  # ── Data ──────────────────────────────────────────────────────────────────
  cli::cli_text("")
  data_shown <- .data_for_print(x)
  print(data_shown, n = n, ...)

  design_vars_all <- unique(c(x@variables$weights, x@variables$repweights))
  .print_hidden_note(design_vars_all, data_shown)

  invisible(x)
}


# ── print.survey_twophase ─────────────────────────────────────────────────

# Print a Two-Phase Survey Design
#
# @param x A survey_twophase object.
# @param n Maximum number of data rows to print. Default 10L.
# @param design_info Show phase 1 and phase 2 specification sections?
# @param weights_info Reserved (phase1 weight shown in design_info).
# @param strata_info Reserved.
# @param cluster_info Reserved.
# @param metadata_info Show metadata summary?
# @param full If TRUE, show all sections.
# @param ... Passed to tibble print.
# @return x, invisibly.
# Class defined in R/00-s7-classes.R
S7::method(print, survey_twophase) <- function(
  x,
  n             = 10L,
  design_info   = FALSE,
  weights_info  = FALSE,
  strata_info   = FALSE,
  cluster_info  = FALSE,
  metadata_info = FALSE,
  full          = FALSE,
  ...
) {
  if (full) {
    design_info <- weights_info <- strata_info <-
      cluster_info <- metadata_info <- TRUE
  }

  subset_var <- x@variables$subset
  n_total    <- nrow(x@data)
  n_phase2   <- if (!is.null(subset_var) && subset_var %in% names(x@data)) {
    sum(x@data[[subset_var]], na.rm = TRUE)
  } else {
    NA_integer_
  }

  # ── Header ────────────────────────────────────────────────────────────────
  cli::cli_h1("Survey Design")
  cli::cli_text(
    "{.cls survey_twophase} (method: {x@variables$method})"
  )
  cli::cli_text("Phase 1 sample size: {.val {n_total}}")
  if (!is.na(n_phase2)) {
    cli::cli_text("Phase 2 sample size: {.val {n_phase2}}")
  }

  if (length(x@groups) > 0L) {
    cli::cli_text("Groups: {.field {x@groups}}")
  }

  # ── Design specification ──────────────────────────────────────────────────
  if (design_info) {
    cli::cli_text("")
    cli::cli_h2("Phase 1 design")

    p1 <- x@variables$phase1
    if (!is.null(p1$ids) && length(p1$ids) > 0L) {
      n_psus <- length(unique(x@data[[p1$ids[[1L]]]]))
      cli::cli_bullets(c("*" = "IDs: {.field {p1$ids}} ({n_psus} PSUs)"))
    }
    if (!is.null(p1$strata)) {
      n_strata <- length(unique(x@data[[p1$strata]]))
      cli::cli_bullets(c(
        "*" = "Strata: {.field {p1$strata}} ({n_strata} strata)"
      ))
    }
    if (!is.null(p1$weights)) {
      cli::cli_bullets(c("*" = "Weights: {.field {p1$weights}}"))
    }

    p2 <- x@variables$phase2
    cli::cli_text("")
    cli::cli_h2("Phase 2 design")
    cli::cli_bullets(c("*" = "Subset: {.field {subset_var}}"))
    if (!is.null(p2$ids) && length(p2$ids) > 0L) {
      cli::cli_bullets(c("*" = "IDs: {.field {p2$ids}}"))
    }
    if (!is.null(p2$strata)) {
      cli::cli_bullets(c("*" = "Strata: {.field {p2$strata}}"))
    }
    if (!is.null(p2$probs)) {
      cli::cli_bullets(c("*" = "Probs: {.field {p2$probs}}"))
    }
    if (!is.null(p2$fpc)) {
      cli::cli_bullets(c("*" = "FPC: {.field {p2$fpc}}"))
    }
  }

  # ── Metadata ──────────────────────────────────────────────────────────────
  if (metadata_info) {
    n_labeled <- length(x@metadata@variable_labels)
    cli::cli_text("")
    cli::cli_h2("Metadata")
    cli::cli_text("{n_labeled} variable(s) labeled")
  }

  # ── Data ──────────────────────────────────────────────────────────────────
  cli::cli_text("")
  data_shown <- .data_for_print(x)
  print(data_shown, n = n, ...)

  p1 <- x@variables$phase1
  p2 <- x@variables$phase2
  p2_cols <- if (!is.null(p2)) {
    unlist(p2[!vapply(p2, is.null, logical(1L))], use.names = FALSE)
  } else {
    character(0L)
  }
  design_vars_all <- unique(c(
    p1$ids, p1$weights, p1$strata, p1$fpc,
    p2_cols,
    subset_var
  ))
  .print_hidden_note(design_vars_all, data_shown)

  invisible(x)
}


# ── print.survey_calibrated ───────────────────────────────────────────────

# Print a Calibrated / Non-Probability Survey Design
#
# @param x A survey_calibrated object.
# @param n Maximum number of data rows to print. Default 10L.
# @param design_info Show design specification section?
# @param weights_info Show weight distribution statistics?
# @param metadata_info Show metadata summary?
# @param full If TRUE, show all sections.
# @param ... Passed to tibble print.
# @return x, invisibly.
# Class defined in R/00-s7-classes.R
S7::method(print, survey_calibrated) <- function(
  x,
  n             = 10L,
  design_info   = FALSE,
  weights_info  = FALSE,
  metadata_info = FALSE,
  full          = FALSE,
  ...
) {
  if (full) {
    design_info <- weights_info <- metadata_info <- TRUE
  }

  # Hoist weight extraction once; used by header and weight-distribution sections
  wts     <- x@data[[x@variables$weights]]
  wts_var <- x@variables$weights

  # ── Header ────────────────────────────────────────────────────────────────
  cli::cli_h1("Survey Design")
  cli::cli_text("{.cls survey_calibrated} (calibrated / non-probability) [experimental]")
  cli::cli_text("Sample size: {.val {nrow(x@data)}}")

  if (length(x@groups) > 0L) {
    cli::cli_text("Groups: {.field {x@groups}}")
  }

  if (weights_info) {
    weighted_n <- round(sum(wts, na.rm = TRUE))
    cli::cli_text("Weighted N: {.val {weighted_n}}")
  }

  # ── Design specification ──────────────────────────────────────────────────
  if (design_info) {
    cli::cli_text("")
    cli::cli_h2("Design specification")

    cli::cli_bullets(c("*" = "Weights: {.field {wts_var}}"))

    cal_label <- if (!is.null(x@calibration)) "stored" else "none stored"
    cli::cli_bullets(c("*" = "Calibration provenance: {cal_label}"))

    cli::cli_text("")
    cli::cli_text("Design variables: {.field {wts_var}}")
  }

  # ── Weight distribution ───────────────────────────────────────────────────
  if (weights_info) {
    cli::cli_text("")
    cli::cli_h2("Weight distribution")
    .print_weight_distribution(wts)
  }

  # ── Metadata ──────────────────────────────────────────────────────────────
  if (metadata_info) {
    n_labeled <- length(x@metadata@variable_labels)
    cli::cli_text("")
    cli::cli_h2("Metadata")
    cli::cli_text("{n_labeled} variable(s) labeled")
  }

  # ── Data ──────────────────────────────────────────────────────────────────
  cli::cli_text("")
  data_shown <- .data_for_print(x)
  print(data_shown, n = n, ...)

  .print_hidden_note(wts_var, data_shown)

  invisible(x)
}


# ── summary.survey_calibrated ─────────────────────────────────────────────

# Summarise a Calibrated / Non-Probability Survey Design
# @param object A survey_calibrated object.
# @return object, invisibly.
# Class defined in R/00-s7-classes.R
S7::method(summary, survey_calibrated) <- function(object, ...) {
  x <- object

  cli::cli_h1("Survey Design Summary")
  cli::cli_text("Type: calibrated / non-probability [experimental]")
  cli::cli_text("Sample size: {.val {nrow(x@data)}}")

  wts_var    <- x@variables$weights
  wts        <- x@data[[wts_var]]
  weighted_n <- round(sum(wts, na.rm = TRUE))
  cli::cli_text("Weighted N: {.val {weighted_n}}")

  cli::cli_text("")
  cli::cli_h2("Design")
  cli::cli_text("Weights: {.field {wts_var}}")
  .print_weight_distribution(wts)

  cal_label <- if (!is.null(x@calibration)) "stored" else "none stored"
  cli::cli_text("Calibration provenance: {cal_label}")

  cli::cli_text("")
  n_labeled <- length(x@metadata@variable_labels)
  n_total   <- ncol(x@data)
  cli::cli_text("Metadata: {n_labeled} of {n_total} variable(s) labeled")

  invisible(x)
}


# ── summary.survey_taylor ──────────────────────────────────────────────────

# Summarise a Taylor Series Survey Design
# @param object A survey_taylor object.
# @return object, invisibly.
# Class defined in R/00-s7-classes.R
S7::method(summary, survey_taylor) <- function(object, ...) {
  x <- object

  cli::cli_h1("Survey Design Summary")
  cli::cli_text("Type: Taylor series linearization")
  cli::cli_text("Sample size: {.val {nrow(x@data)}}")

  wts_var    <- x@variables$weights
  wts        <- x@data[[wts_var]]
  weighted_n <- round(sum(wts, na.rm = TRUE))
  cli::cli_text("Weighted N: {.val {weighted_n}}")

  cli::cli_text("")
  cli::cli_h2("Design")

  ids_vars <- x@variables$ids
  if (!is.null(ids_vars) && length(ids_vars) > 0L) {
    n_psus <- length(unique(x@data[[ids_vars[[1L]]]]))
    cli::cli_text("IDs: {.field {ids_vars}} ({n_psus} PSUs)")
  } else {
    cli::cli_text("IDs: none (SRS)")
  }

  strata_var <- x@variables$strata
  if (!is.null(strata_var)) {
    n_strata <- length(unique(x@data[[strata_var]]))
    cli::cli_text("Strata: {.field {strata_var}} ({n_strata} strata)")
  } else {
    cli::cli_text("Strata: none")
  }

  cli::cli_text("Weights: {.field {wts_var}}")
  .print_weight_distribution(wts)

  fpc_var <- x@variables$fpc
  if (!is.null(fpc_var)) {
    cli::cli_text("FPC: {.field {fpc_var}}")
  }

  cli::cli_text("")
  n_labeled <- length(x@metadata@variable_labels)
  n_total   <- ncol(x@data)
  cli::cli_text("Metadata: {n_labeled} of {n_total} variable(s) labeled")

  invisible(x)
}


# ── summary.survey_srs ────────────────────────────────────────────────────

# Summarise a Simple Random Sample Survey Design
# @param object A survey_srs object.
# @return object, invisibly.
# Class defined in R/00-s7-classes.R
S7::method(summary, survey_srs) <- function(object, ...) {
  x <- object

  cli::cli_h1("Survey Design Summary")
  cli::cli_text("Type: simple random sample (SRS)")
  cli::cli_text("Sample size: {.val {nrow(x@data)}}")

  wts_var    <- x@variables$weights
  wts        <- x@data[[wts_var]]
  weighted_n <- round(sum(wts, na.rm = TRUE))
  cli::cli_text("Weighted N: {.val {weighted_n}}")

  cli::cli_text("")
  cli::cli_h2("Design")

  is_uniform <- identical(wts_var, .SURVEYCORE_WT_COL) &&
    !isTRUE(x@variables$probs_provided)
  if (is_uniform) {
    cli::cli_text("Weights: uniform (auto-assigned)")
  } else {
    cli::cli_text("Weights: {.field {wts_var}}")
  }
  .print_weight_distribution(wts)

  fpc_var  <- x@variables$fpc
  fpc_type <- x@variables$fpc_type
  if (!is.null(fpc_var)) {
    fpc_label <- if (identical(fpc_type, "population")) {
      "(population sizes)"
    } else {
      "(sampling fractions)"
    }
    cli::cli_text("FPC: {.field {fpc_var}} {fpc_label}")
  } else {
    cli::cli_text("FPC: not specified")
  }

  cli::cli_text("")
  n_labeled <- length(x@metadata@variable_labels)
  n_total   <- ncol(x@data)
  cli::cli_text("Metadata: {n_labeled} of {n_total} variable(s) labeled")

  invisible(x)
}


# ── summary.survey_replicate ──────────────────────────────────────────────

# Summarise a Replicate Weights Survey Design
# @param object A survey_replicate object.
# @return object, invisibly.
# Class defined in R/00-s7-classes.R
S7::method(summary, survey_replicate) <- function(object, ...) {
  x <- object

  n_reps <- length(x@variables$repweights)

  cli::cli_h1("Survey Design Summary")
  cli::cli_text(
    "Type: replicate weights ({toupper(x@variables$type)}, {n_reps} replicates)"
  )
  cli::cli_text("Sample size: {.val {nrow(x@data)}}")

  wts_var    <- x@variables$weights
  wts        <- x@data[[wts_var]]
  weighted_n <- round(sum(wts, na.rm = TRUE))
  cli::cli_text("Weighted N: {.val {weighted_n}}")

  cli::cli_text("")
  cli::cli_h2("Design")
  cli::cli_text("Weights: {.field {wts_var}}")
  .print_weight_distribution(wts)
  cli::cli_text("Scale: {.val {x@variables$scale}}")
  cli::cli_text("MSE: {.val {isTRUE(x@variables$mse)}}")

  fpc_var <- x@variables$fpc
  if (!is.null(fpc_var)) {
    cli::cli_text("FPC: {.field {fpc_var}} ({x@variables$fpctype})")
  }

  cli::cli_text("")
  n_labeled <- length(x@metadata@variable_labels)
  n_total   <- ncol(x@data)
  cli::cli_text("Metadata: {n_labeled} of {n_total} variable(s) labeled")

  invisible(x)
}


# ── summary.survey_twophase ───────────────────────────────────────────────

# Summarise a Two-Phase Survey Design
# @param object A survey_twophase object.
# @return object, invisibly.
# Class defined in R/00-s7-classes.R
S7::method(summary, survey_twophase) <- function(object, ...) {
  x <- object

  subset_var <- x@variables$subset
  n_total    <- nrow(x@data)
  n_phase2   <- if (!is.null(subset_var) && subset_var %in% names(x@data)) {
    sum(x@data[[subset_var]], na.rm = TRUE)
  } else {
    NA_integer_
  }

  cli::cli_h1("Survey Design Summary")
  cli::cli_text("Type: two-phase sampling (method: {x@variables$method})")
  cli::cli_text("Phase 1 sample size: {.val {n_total}}")
  if (!is.na(n_phase2)) {
    cli::cli_text("Phase 2 sample size: {.val {n_phase2}}")
  }

  cli::cli_text("")
  cli::cli_h2("Phase 1 design")
  p1 <- x@variables$phase1
  if (!is.null(p1$ids) && length(p1$ids) > 0L) {
    n_psus <- length(unique(x@data[[p1$ids[[1L]]]]))
    cli::cli_text("IDs: {.field {p1$ids}} ({n_psus} PSUs)")
  } else {
    cli::cli_text("IDs: none (SRS)")
  }
  if (!is.null(p1$strata)) {
    n_strata <- length(unique(x@data[[p1$strata]]))
    cli::cli_text("Strata: {.field {p1$strata}} ({n_strata} strata)")
  } else {
    cli::cli_text("Strata: none")
  }
  if (!is.null(p1$weights)) {
    p1_wts    <- x@data[[p1$weights]]
    weighted_n <- round(sum(p1_wts, na.rm = TRUE))
    cli::cli_text("Weights: {.field {p1$weights}}")
    cli::cli_text("Weighted N: {.val {weighted_n}}")
  }

  cli::cli_text("")
  cli::cli_h2("Phase 2 design")
  cli::cli_text("Subset: {.field {subset_var}}")
  p2 <- x@variables$phase2
  if (!is.null(p2$ids) && length(p2$ids) > 0L) {
    cli::cli_text("IDs: {.field {p2$ids}}")
  }
  if (!is.null(p2$strata)) {
    cli::cli_text("Strata: {.field {p2$strata}}")
  }

  cli::cli_text("")
  n_labeled <- length(x@metadata@variable_labels)
  n_total_vars <- ncol(x@data)
  cli::cli_text("Metadata: {n_labeled} of {n_total_vars} variable(s) labeled")

  invisible(x)
}
