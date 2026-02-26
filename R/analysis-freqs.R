# R/analysis-freqs.R
#
# Weighted frequency tables for categorical survey variables.
# Exported function: get_freqs()
#
# Internal helpers: analysis-freqs-helpers.R




# ── get_freqs() ───────────────────────────────────────────────────────────────

#' Weighted Frequency Tables for Categorical Survey Variables
#'
#' Compute weighted proportions (percentages) for one or more categorical
#' variables in a survey design, with optional grouping, uncertainty
#' quantification, and metadata-driven labelling.
#'
#' @param design A survey design object: `survey_taylor`, `survey_replicate`,
#'   `survey_twophase`, `survey_srs`, or `survey_calibrated`.
#' @param x <[`tidy-select`][tidyselect::language]> One or more categorical
#'   variables. Bare names or tidy-select helpers (e.g., `c(q1, q2, q3)`).
#'   When two or more variables are selected, multi-variable stacking mode
#'   is activated (see Details).
#' @param ... Additional arguments passed to tidy-select (future-proof;
#'   currently unused).
#' @param group <[`tidy-select`][tidyselect::language]> Optional grouping
#'   variable(s). Combined with any grouping set by `group_by()`. Default
#'   `NULL`.
#' @param names_to Character(1). Column name for the variable identifier in
#'   multi-variable mode. Default `"name"`.
#' @param values_to Character(1). Column name for the response value in
#'   multi-variable mode. Default `"value"`.
#' @param variance `NULL` or a character vector of one or more of `"se"`,
#'   `"ci"`, `"var"`, `"cv"`, `"moe"`, `"deff"`. Controls which uncertainty
#'   columns appear in the output. Default `NULL` (no uncertainty columns).
#' @param conf_level Numeric scalar in (0, 1). Confidence level for intervals.
#'   Default `0.95`.
#' @param n_weighted Logical. If `TRUE`, add an `n_weighted` column with the
#'   sum of weights (estimated population count) per cell. Default `FALSE`.
#' @param min_cell_n Integer. Minimum unweighted cell count before
#'   `surveycore_warning_small_cell` fires. Default `30L` (AAPOR guidance).
#' @param na.rm Logical. If `TRUE` (default), `NA` values are excluded from
#'   all proportions; `NA` does not appear as a level. If `FALSE`, `NA`
#'   appears as its own last row and the denominator includes `NA` rows.
#' @param label_values Logical. If `TRUE` (default), convert raw variable
#'   values to labels using metadata or `haven` attributes. Falls back to
#'   raw values when no labels exist.
#' @param label_vars Logical. If `TRUE` (default), use variable labels from
#'   metadata in the `names_to` column (multi-variable mode only). Falls back
#'   to the raw variable name when no label is set.
#' @param name_style `"surveycore"` (default) or `"broom"`. When `"broom"`,
#'   renames `pct` → `estimate`, `se` → `std.error`, etc.
#'
#' @details
#' **Single-variable mode** (when `x` resolves to exactly one variable):
#' The focal variable name becomes the first column. Rows follow the factor
#' level order (if the variable is a factor) or ascending sort order otherwise.
#'
#' **Multi-variable mode** (when `x` resolves to two or more variables):
#' Results are stacked in long format. The `names_to` column contains the
#' variable label (when `label_vars = TRUE`) or the raw variable name as
#' fallback. The `values_to` column contains the response values.
#'
#' **Domain estimation:** Proportions use the ratio linearization approach,
#' equivalent to `survey::svymean()` on a binary indicator within the active
#' domain. The full design structure is used for variance estimation — rows are
#' not physically removed for domain/group subsets.
#'
#' **`na.rm = FALSE`:** `NA` is appended as the last level. All proportions
#' (including non-`NA` levels) have their denominator inflated to include
#' `NA` rows, so the `pct` column sums to 100.
#'
#' @return A `survey_freqs` tibble (also inheriting `survey_result`). Columns:
#' \itemize{
#'   \item `[group_cols...]` — group variable columns (when active), first.
#'   \item `[variable_name]` (single) or `[names_to]` + `[values_to]` (multi).
#'   \item `pct` — weighted proportion as a percentage (0–100).
#'   \item Variance columns (`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`,
#'     `deff`) — only those requested via `variance`.
#'   \item `n` — unweighted cell count (sample basis of each estimate).
#'   \item `n_weighted` — estimated population count (only when requested).
#' }
#' Use `meta(result)` to access design type, variable labels, value labels,
#' and other metadata.
#'
#' @examples
#' # NHANES exam weights are 0 for non-examined participants; filter first
#' nhanes_sub <- nhanes_2017[nhanes_2017$wtmec2yr > 0, ]
#' d <- as_survey(nhanes_sub, ids = sdmvpsu, weights = wtmec2yr,
#'                strata = sdmvstra, nest = TRUE)
#'
#' # Single variable
#' get_freqs(d, riagendr)
#'
#' # With confidence intervals
#' get_freqs(d, riagendr, variance = "ci")
#'
#' # Grouped
#' get_freqs(d, riagendr, group = sdmvstra)
#'
#' # Multi-variable (stacked)
#' get_freqs(d, c(riagendr, ridreth3), names_to = "item", values_to = "value")
#'
#' @family analysis
#' @export
get_freqs <- function(
  design,
  x,
  ...,
  group        = NULL,
  names_to     = "name",
  values_to    = "value",
  variance     = NULL,
  conf_level   = 0.95,
  n_weighted   = FALSE,
  min_cell_n   = 30L,
  na.rm        = TRUE,
  label_values = TRUE,
  label_vars   = TRUE,
  name_style   = "surveycore"
) {
  # ── Step 1: Validate ────────────────────────────────────────────────────────
  .check_unsupported_class(design, "get_freqs")
  .validate_shared_args(variance, conf_level, name_style)

  # ── Step 2: Resolve variables, groups, domain ───────────────────────────────
  x_quo     <- rlang::enquo(x)
  group_quo <- rlang::enquo(group)

  var_names  <- .resolve_tidy_select(x_quo, design@data)
  group_vars <- .resolve_groups(design, group_quo)
  domain_mask <- .apply_domain(design)   # logical, full length
  degf        <- .degf(design)

  n_vars   <- length(var_names)
  is_multi <- n_vars >= 2L

  # ── Step 3: Single-level warnings for group variables ───────────────────────
  if (length(group_vars) > 0L) {
    for (gv in group_vars) {
      gv_vals  <- design@data[[gv]][domain_mask]
      uniq_lvls <- unique(gv_vals[!is.na(gv_vals)])
      if (length(uniq_lvls) == 1L) {
        lvl_str <- as.character(uniq_lvls[[1L]])
        cli::cli_warn(
          c(
            "!" = paste0(
              "Grouping variable {.field {gv}} has only one observed level ",
              "({.val {lvl_str}}). Grouped estimates will have a single row."
            )
          ),
          class = "surveycore_warning_single_level"
        )
      }
    }
  }

  # ── Step 4: Mixed prefaces warning (multi-var only) ─────────────────────────
  if (is_multi) {
    prefaces_list <- lapply(
      var_names,
      function(vn) design@metadata@question_prefaces[[vn]]
    )
    non_null_prefaces <- Filter(Negate(is.null), prefaces_list)
    unique_prefaces   <- unique(unlist(non_null_prefaces))
    if (length(unique_prefaces) > 1L) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "{length(unique_prefaces)} different question prefaces found ",
            "across {n_vars} variables."
          ),
          "i" = paste0(
            "Variables with different prefaces may not belong in the same ",
            "{.fn get_freqs} call."
          ),
          "i" = paste0(
            "Prefaces stored in ",
            "{.code meta(result)$question_prefaces}."
          ),
          "v" = paste0(
            "Consider splitting into separate {.fn get_freqs} calls, ",
            "one per preface."
          )
        ),
        class = "surveycore_warning_mixed_prefaces"
      )
    }
  }

  # ── Step 5: Build group combinations ────────────────────────────────────────
  # Find unique combinations of group variables among in-domain rows.
  # If no groups, group_combos is a data.frame with 0 columns and 1 row
  # (representing the single "all in-domain rows" group).
  if (length(group_vars) > 0L) {
    domain_data   <- design@data[domain_mask, group_vars, drop = FALSE]
    group_combos  <- unique(domain_data)
    # Sort ascending by each group variable (leftmost first)
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

  # ── Step 6: Pre-collect variable metadata ───────────────────────────────────
  var_labels_list    <- vector("list", n_vars)
  q_prefaces_list    <- vector("list", n_vars)
  val_labels_list    <- vector("list", n_vars)
  names(var_labels_list) <- var_names
  names(q_prefaces_list) <- var_names
  names(val_labels_list) <- var_names

  for (vn in var_names) {
    col_data <- design@data[[vn]]
    # Variable label: metadata first, then haven attribute fallback
    # Use single-bracket assignment to preserve NULL entries in the list
    # (double-bracket assignment with NULL removes the element entirely).
    var_labels_list[vn] <- list(
      design@metadata@variable_labels[[vn]] %||%
        attr(col_data, "label", exact = TRUE)
    )
    # Question preface: metadata only (no haven equivalent)
    q_prefaces_list[vn] <- list(design@metadata@question_prefaces[[vn]])
    # Value labels: metadata first, then haven attribute fallback
    val_labels_list[vn] <- list(
      design@metadata@value_labels[[vn]] %||%
        attr(col_data, "labels", exact = TRUE)
    )
  }

  # ── Step 7: Main accumulation loop ──────────────────────────────────────────
  # Parallel vectors for all result rows
  acc_focal   <- character(0)   # focal column or names_to column
  acc_values  <- character(0)   # values_to column (multi-var only)
  acc_pct     <- numeric(0)
  acc_se      <- numeric(0)
  acc_sesrs   <- numeric(0)
  acc_n       <- integer(0)
  acc_nw      <- numeric(0)
  acc_grp_rows <- vector("list", 0L)   # list of single-row data.frames

  small_cell_ns <- integer(0)   # for small-cell warning

  for (vn in var_names) {
    x_col     <- design@data[[vn]]
    vl        <- val_labels_list[[vn]]   # named vector or NULL
    vl_map    <- if (!is.null(vl)) structure(names(vl), names = as.character(vl)) else NULL

    # domain-only x values for level detection
    x_domain <- x_col[domain_mask]

    # ── All-NA check ──────────────────────────────────────────────────────────
    if (!na.rm) {
      if (all(is.na(x_domain))) {
        cli::cli_abort(
          c(
            "x" = "All values of {.field {vn}} are {.code NA}.",
            "i" = paste0(
              "Cannot compute estimate with {.arg na.rm = FALSE}. ",
              "Set {.arg na.rm = TRUE} to exclude {.code NA} values."
            )
          ),
          class = "surveycore_error_all_na"
        )
      }
    }

    # ── Get levels ────────────────────────────────────────────────────────────
    levels_vn <- .get_levels(x_domain, na.rm)

    if (na.rm && length(levels_vn) == 0L) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "All values of {.field {vn}} are {.code NA} with ",
            "{.arg na.rm = TRUE}. Returning 0 rows."
          )
        ),
        class = "surveycore_warning_all_na_freqs"
      )
      next   # skip this variable; contributes 0 rows
    }

    # ── Display name for multi-var names_to column ────────────────────────────
    if (is_multi) {
      vn_display <- if (
        label_vars && !is.null(var_labels_list[[vn]])
      ) {
        var_labels_list[[vn]]
      } else {
        vn
      }
    }

    # ── Loop over group combinations ──────────────────────────────────────────
    for (ci in seq_len(n_combos)) {

      if (length(group_vars) > 0L) {
        # Build mask: domain AND all group variable values match this combo
        combo_row   <- group_combos[ci, , drop = FALSE]
        group_match <- rep(TRUE, nrow(design@data))
        for (gv in group_vars) {
          group_match <- group_match & (design@data[[gv]] == combo_row[[gv]])
        }
        active_mask <- domain_mask & group_match
      } else {
        active_mask <- domain_mask
      }

      # ── Build denominator ──────────────────────────────────────────────────
      # Denominator: in active_mask AND (not NA if na.rm)
      if (na.rm) {
        denom <- as.numeric(active_mask & !is.na(x_col))
      } else {
        denom <- as.numeric(active_mask)
      }

      # ── Loop over levels ───────────────────────────────────────────────────
      for (lvl in levels_vn) {
        # Build numerator: in active_mask AND matches this level
        if (is.na(lvl)) {
          num <- as.numeric(active_mask & is.na(x_col))
        } else {
          num <- as.numeric(active_mask & !is.na(x_col) & (x_col == lvl))
        }

        cell <- .freq_cell(design, num, denom)

        # Track small cells
        if (!is.na(cell$n) && cell$n > 0L && cell$n < min_cell_n) {
          small_cell_ns <- c(small_cell_ns, cell$n)
        }

        # ── Level display value ────────────────────────────────────────────
        if (label_values && !is.null(vl_map) && !is.na(lvl)) {
          lvl_display <- vl_map[[as.character(lvl)]]
          if (is.null(lvl_display) || is.na(lvl_display)) {
            lvl_display <- as.character(lvl)
          }
        } else {
          lvl_display <- if (is.na(lvl)) NA_character_ else as.character(lvl)
        }

        # ── Accumulate ────────────────────────────────────────────────────
        if (is_multi) {
          acc_focal  <- c(acc_focal, vn_display)
          acc_values <- c(acc_values, lvl_display)
        } else {
          acc_focal <- c(acc_focal, lvl_display)
        }

        acc_pct   <- c(acc_pct,   cell$pct)
        acc_se    <- c(acc_se,    cell$se)
        acc_sesrs <- c(acc_sesrs, cell$se_srs)
        acc_n     <- c(acc_n,     cell$n)
        acc_nw    <- c(acc_nw,    cell$n_weighted)

        if (length(group_vars) > 0L) {
          acc_grp_rows <- c(acc_grp_rows, list(combo_row))
        }
      }  # end level loop
    }  # end group combo loop
  }  # end variable loop

  # ── Step 8: Small-cell warning ───────────────────────────────────────────────
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

  # ── Step 9: Build column vectors ─────────────────────────────────────────────
  # Variance columns (only requested types)
  var_cols <- .add_variance_cols(
    se_vec       = acc_se,
    estimate_vec = acc_pct,
    se_srs_vec   = acc_sesrs,
    conf_level   = conf_level,
    degf         = degf,
    variance     = variance
  )

  # Assemble col_vecs in canonical column order
  col_vecs <- list()

  if (is_multi) {
    col_vecs[[names_to]]  <- acc_focal
    col_vecs[[values_to]] <- acc_values
  } else {
    # Single-var: convert NA display back to NA (not "NA" string)
    focal_out <- acc_focal
    is_na_str <- !is.na(acc_focal) & acc_focal == "NA"
    if (any(is_na_str)) focal_out[is_na_str] <- NA_character_
    col_vecs[[var_names[[1L]]]] <- focal_out
  }

  col_vecs$pct <- acc_pct
  col_vecs     <- c(col_vecs, var_cols)
  col_vecs$n   <- acc_n

  if (isTRUE(n_weighted)) {
    col_vecs$n_weighted <- acc_nw
  }

  # ── Step 10: Build groups_df ──────────────────────────────────────────────────
  if (length(group_vars) > 0L && length(acc_grp_rows) > 0L) {
    groups_df <- do.call(rbind, acc_grp_rows)
    rownames(groups_df) <- NULL
  } else {
    groups_df <- data.frame()
  }

  # ── Step 11: Build meta_args ──────────────────────────────────────────────────
  group_labels_list <- lapply(
    group_vars,
    function(gv) design@metadata@variable_labels[[gv]] %||%
      attr(design@data[[gv]], "label", exact = TRUE)
  )
  if (length(group_vars) > 0L) {
    names(group_labels_list) <- group_vars
  }

  if (!is_multi) {
    meta_args <- list(
      mode             = "single",
      variable         = var_names[[1L]],
      variable_label   = var_labels_list[[var_names[[1L]]]],
      question_preface = q_prefaces_list[[var_names[[1L]]]],
      value_labels     = val_labels_list,   # always a named list
      conf_level       = conf_level,
      call             = match.call(),
      group_names      = group_vars,
      group_labels     = group_labels_list
    )
    required_keys <- FREQS_SINGLE_META_KEYS
  } else {
    meta_args <- list(
      mode              = "multi",
      variables         = var_names,
      variable_labels   = var_labels_list,
      question_prefaces = q_prefaces_list,
      value_labels      = val_labels_list,   # named list: var -> labels
      conf_level        = conf_level,
      call              = match.call(),
      group_names       = group_vars,
      group_labels      = group_labels_list
    )
    required_keys <- FREQS_MULTI_META_KEYS
  }

  # ── Step 12: Assemble result ──────────────────────────────────────────────────
  result <- .make_result_tibble(
    col_vecs,
    groups_df,
    "survey_freqs",
    design,
    meta_args,
    required_keys
  )

  # ── Step 13: Apply name style ─────────────────────────────────────────────────
  .apply_name_style(result, name_style)
}
