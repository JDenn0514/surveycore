# R/analysis-means.R
#
# Weighted mean estimation for survey designs.
# Exported function: get_means()
#
# Internal helpers: analysis-means-helpers.R

# ── get_means() ───────────────────────────────────────────────────────────────

#' Weighted Mean for a Survey Design
#'
#' Compute the weighted mean of a single numeric variable in a survey design,
#' with optional grouping, uncertainty quantification, and metadata-driven
#' labelling.
#'
#' @param design A survey design object: `survey_taylor`, `survey_replicate`,
#'   `survey_twophase`, `survey_srs`, or `survey_calibrated`.
#' @param x <[`tidy-select`][tidyselect::language]> A single unquoted numeric
#'   variable name. Must resolve to exactly one numeric column.
#' @param group <[`tidy-select`][tidyselect::language]> Optional grouping
#'   variable(s). Combined with any grouping set by `group_by()`. Default
#'   `NULL`.
#' @param variance `NULL` or a character vector of one or more of `"se"`,
#'   `"ci"`, `"var"`, `"cv"`, `"moe"`, `"deff"`. Controls which uncertainty
#'   columns appear in the output. Default `"ci"`.
#' @param conf_level Numeric scalar in (0, 1). Confidence level for intervals.
#'   Default `0.95`.
#' @param n_weighted Logical. If `TRUE`, add an `n_weighted` column with the
#'   sum of weights for non-NA observations in each group. Default `FALSE`.
#' @param min_cell_n Integer. Minimum unweighted cell count before
#'   `surveycore_warning_small_cell` fires. Default `30L` (AAPOR guidance).
#' @param na.rm Logical. If `TRUE` (default), `NA` values in `x` are excluded.
#' @param label_values Logical. Accepted for API uniformity; has no visible
#'   effect since `get_means()` output contains no categorical value cells.
#'   Default `TRUE`.
#' @param label_vars Logical. Accepted for API uniformity; has no visible
#'   effect since `get_means()` output contains no variable-name value cells.
#'   Default `TRUE`.
#' @param name_style `"surveycore"` (default) or `"broom"`. When `"broom"`,
#'   renames `mean` → `estimate`, `se` → `std.error`, etc.
#'
#' @return A `survey_means` tibble (also inheriting `survey_result`). Columns:
#' \itemize{
#'   \item `[group_cols...]` — group variable columns (when active), first.
#'   \item `mean` — weighted mean estimate.
#'   \item Variance columns (`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`,
#'     `deff`) — only those requested via `variance`.
#'   \item `n` — unweighted count of non-NA observations used in the estimate.
#'   \item `n_weighted` — sum of weights (only when requested).
#' }
#' The variable name is stored in `meta(result)$variable`, not as a column.
#' Use `meta(result)` to access design type, variable labels, and other
#' metadata.
#'
#' @examples
#' d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
#'                strata = sdmvstra, nest = TRUE)
#' get_means(d, ridageyr)
#'
#' # With grouped estimate
#' get_means(d, ridageyr, group = riagendr)
#'
#' # AAPOR-compliant
#' get_means(d, ridageyr, variance = c("ci", "moe"), n_weighted = TRUE)
#'
#' @family analysis
#' @export
get_means <- function(
  design,
  x,
  group        = NULL,
  variance     = "ci",
  conf_level   = 0.95,
  n_weighted   = FALSE,
  min_cell_n   = 30L,
  na.rm        = TRUE,
  label_values = TRUE,
  label_vars   = TRUE,
  name_style   = "surveycore"
) {
  # ── Step 1: Validate ────────────────────────────────────────────────────────
  .check_unsupported_class(design, "get_means")
  .validate_shared_args(variance, conf_level, name_style)

  # ── Step 2: Resolve variable, groups, domain ─────────────────────────────────
  x_quo     <- rlang::enquo(x)
  group_quo <- rlang::enquo(group)

  x_names <- .resolve_tidy_select(x_quo, design@data)

  if (length(x_names) != 1L) {
    cli::cli_abort(
      c(
        "x" = "{.fn get_means} requires exactly one variable.",
        "i" = "{.arg x} resolved to {length(x_names)} variable{?s}."
      ),
      class = "surveycore_error_wrong_variable_count"
    )
  }

  x_name <- x_names[[1L]]
  x_col  <- design@data[[x_name]]

  if (!is.numeric(x_col)) {
    cli::cli_abort(
      c(
        "x" = "{.arg x} must be numeric, not {.cls {class(x_col)}}.",
        "i" = "Column {.field {x_name}} cannot be used with {.fn get_means}."
      ),
      class = "surveycore_error_non_numeric_variable"
    )
  }

  group_vars  <- .resolve_groups(design, group_quo)
  domain_mask <- .apply_domain(design)
  degf        <- .degf(design)

  # ── Step 3: Single-level warning for group variables ─────────────────────────
  if (length(group_vars) > 0L) {
    for (gv in group_vars) {
      gv_vals   <- design@data[[gv]][domain_mask]
      uniq_lvls <- unique(gv_vals[!is.na(gv_vals)])
      if (length(uniq_lvls) == 1L) {
        cli::cli_warn(
          c(
            "!" = paste0(
              "Grouping variable {.field {gv}} has only one observed level ",
              "({.val {as.character(uniq_lvls[[1L]])}}).",
              " Grouped estimates will have a single row."
            )
          ),
          class = "surveycore_warning_single_level"
        )
      }
    }
  }

  # ── Step 4: Build group combinations ─────────────────────────────────────────
  if (length(group_vars) > 0L) {
    domain_data  <- design@data[domain_mask, group_vars, drop = FALSE]
    group_combos <- unique(domain_data)
    ord <- do.call(
      order,
      lapply(group_vars, function(gv) group_combos[[gv]])
    )
    group_combos <- group_combos[ord, , drop = FALSE]
    rownames(group_combos) <- NULL
    n_combos <- nrow(group_combos)
  } else {
    group_combos <- data.frame()
    n_combos     <- 1L
  }

  # ── Step 5: Collect variable metadata ───────────────────────────────────────
  var_label    <- design@metadata@variable_labels[[x_name]] %||%
    attr(design@data[[x_name]], "label", exact = TRUE)
  q_preface    <- design@metadata@question_prefaces[[x_name]]
  val_labels   <- design@metadata@value_labels[[x_name]] %||%
    attr(design@data[[x_name]], "labels", exact = TRUE)
  val_labels_l <- list(val_labels)
  names(val_labels_l) <- x_name

  # ── Step 6: Main accumulation loop ──────────────────────────────────────────
  acc_mean  <- numeric(0)
  acc_se    <- numeric(0)
  acc_sesrs <- numeric(0)
  acc_n     <- integer(0)
  acc_nw    <- numeric(0)
  acc_grp_rows <- vector("list", 0L)

  small_cell_ns <- integer(0)

  for (ci in seq_len(n_combos)) {
    if (length(group_vars) > 0L) {
      combo_row   <- group_combos[ci, , drop = FALSE]
      group_match <- rep(TRUE, nrow(design@data))
      for (gv in group_vars) {
        gv_col <- design@data[[gv]]
        cv     <- combo_row[[gv]]
        # NA group values: those rows excluded (they don't match any combo)
        group_match <- group_match & !is.na(gv_col) & (gv_col == cv)
      }
      active_mask <- domain_mask & group_match
    } else {
      active_mask <- domain_mask
    }

    domain <- .mean_domain_vec(active_mask, x_col, na.rm)
    cell   <- .mean_cell(design, x_name, domain)

    if (!is.na(cell$n) && cell$n > 0L && cell$n < min_cell_n) {
      small_cell_ns <- c(small_cell_ns, cell$n)
    }

    acc_mean  <- c(acc_mean,  cell$mean)
    acc_se    <- c(acc_se,    cell$se)
    acc_sesrs <- c(acc_sesrs, cell$se_srs)
    acc_n     <- c(acc_n,     cell$n)
    acc_nw    <- c(acc_nw,    cell$n_weighted)

    if (length(group_vars) > 0L) {
      acc_grp_rows <- c(acc_grp_rows, list(combo_row))
    }
  }

  # ── Step 7: Small-cell warning ───────────────────────────────────────────────
  n_small <- length(small_cell_ns)
  if (n_small > 0L) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "{n_small} cell{?s} {?has/have} fewer than {min_cell_n} unweighted ",
          "observations. Estimates in these cells may be unreliable for ",
          "public reporting (AAPOR guidance)."
        )
      ),
      class = "surveycore_warning_small_cell"
    )
  }

  # ── Step 8: Build column vectors ─────────────────────────────────────────────
  var_cols <- .add_variance_cols(
    se_vec       = acc_se,
    estimate_vec = acc_mean,
    se_srs_vec   = acc_sesrs,
    conf_level   = conf_level,
    degf         = degf,
    variance     = variance
  )

  col_vecs <- list()
  col_vecs$mean <- acc_mean
  col_vecs      <- c(col_vecs, var_cols)
  col_vecs$n    <- acc_n

  if (isTRUE(n_weighted)) {
    col_vecs$n_weighted <- acc_nw
  }

  # ── Step 9: Build groups_df ──────────────────────────────────────────────────
  if (length(group_vars) > 0L && length(acc_grp_rows) > 0L) {
    groups_df <- do.call(rbind, acc_grp_rows)
    rownames(groups_df) <- NULL
  } else {
    groups_df <- data.frame()
  }

  # ── Step 10: Build meta_args ──────────────────────────────────────────────────
  group_labels_list <- lapply(
    group_vars,
    function(gv) design@metadata@variable_labels[[gv]] %||%
      attr(design@data[[gv]], "label", exact = TRUE)
  )
  if (length(group_vars) > 0L) {
    names(group_labels_list) <- group_vars
  }

  meta_args <- list(
    variable         = x_name,
    variable_label   = var_label,
    question_preface = q_preface,
    value_labels     = val_labels_l,
    conf_level       = conf_level,
    call             = match.call(),
    group_names      = group_vars,
    group_labels     = group_labels_list
  )

  # ── Step 11: Assemble result ─────────────────────────────────────────────────
  result <- .make_result_tibble(
    col_vecs,
    groups_df,
    "survey_means",
    design,
    meta_args,
    MEANS_META_KEYS
  )

  # ── Step 12: Apply name style ─────────────────────────────────────────────────
  .apply_name_style(result, name_style)
}


