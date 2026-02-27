# R/analysis-corr.R
#
# Survey-weighted Pearson correlation for survey designs.
# Exported function: get_corr()
#
# Internal helpers: analysis-corr-helpers.R

# ── get_corr() ────────────────────────────────────────────────────────────────

#' Survey-Weighted Pearson Correlation
#'
#' Compute pairwise Pearson correlations between two or more numeric variables
#' in a survey design, with design-based standard errors and confidence
#' intervals. Returns results in long or wide format.
#'
#' @param design A survey design object: `survey_taylor`, `survey_replicate`,
#'   `survey_twophase`, `survey_srs`, or `survey_calibrated`.
#' @param x <[`tidy-select`][tidyselect::language]> Two or more unquoted
#'   numeric variable names. Non-numeric variables are dropped with a warning.
#'   At least two numeric variables must remain.
#' @param group <[`tidy-select`][tidyselect::language]> Optional grouping
#'   variable(s). Combined with any grouping set by `group_by()`. Default
#'   `NULL`.
#' @param format `"long"` (default) or `"wide"`. Long format returns one row
#'   per variable pair with inference statistics. Wide format returns the
#'   correlation matrix (`r` values only — no variance or inference columns).
#'   When `group` is active, group columns are prepended in both formats.
#' @param redundant Logical. If `FALSE` (default), each pair appears once
#'   (lower triangle: pairs where var1 precedes var2 in input order). If
#'   `TRUE`, both `(A, B)` and `(B, A)` are included (full directed pairs).
#'   Only affects long format; wide format always shows the full symmetric
#'   matrix.
#' @param diagonal Logical. If `FALSE` (default), self-correlations are
#'   excluded (diagonal is `NA` in wide format). If `TRUE`, self-correlations
#'   (r equals 1) are included.
#' @param variance `NULL` or a character vector of one or more of `"se"`,
#'   `"ci"`, `"var"`, `"cv"`, `"moe"`, `"deff"`. Default `"ci"`. CI bounds
#'   use the Fisher Z transform (guaranteeing bounds in (−1, 1)). Only
#'   applies to long format.
#' @param conf_level Numeric scalar in (0, 1). Default `0.95`.
#' @param n_weighted Logical. If `TRUE`, add an `n_weighted` column with the
#'   pairwise sum of weights (both variables non-NA). Default `FALSE`.
#' @param min_cell_n Integer. Minimum pairwise unweighted count before
#'   `surveycore_warning_small_cell` fires. Default `30L` (AAPOR guidance).
#' @param na.rm Logical. If `TRUE` (default), pairs use complete cases for
#'   each variable pair separately (pairwise deletion).
#' @param label_values Logical. If `TRUE` (default) and the grouping variable
#'   has value labels, the group column is converted to a labelled factor.
#'   Has no visible effect when no groups are active.
#' @param label_vars Logical. If `TRUE` (default) and variable labels are
#'   set in metadata, `var1`/`var2` columns (long) and `variable` column
#'   (wide) show labels instead of raw names. Falls back to raw names if
#'   labels are unset.
#' @param name_style `"surveycore"` (default) or `"broom"`. When `"broom"`,
#'   renames `r` → `estimate`, `se` → `std.error`, etc. Only affects long
#'   format.
#'
#' @return A `survey_corr` tibble (also inheriting `survey_result`).
#'
#'   When `group` is active, group variable columns are prepended before all
#'   other columns in both long and wide formats.
#'
#'   **Long format** columns:
#'   \itemize{
#'     \item `[group_cols...]` — group variable columns (when active), first.
#'     \item `var1`, `var2` — variable names (or labels when `label_vars = TRUE`).
#'     \item `r` — Pearson correlation coefficient.
#'     \item Variance columns (`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`,
#'       `deff`) — only those requested via `variance`.
#'     \item `p_value` — two-tailed p-value.
#'     \item `statistic` — t-statistic.
#'     \item `df` — degrees of freedom for the t-test (n minus 2).
#'     \item `n` — pairwise unweighted count.
#'     \item `n_weighted` — pairwise sum of weights (only when requested).
#'   }
#'
#'   **Wide format** columns:
#'   \itemize{
#'     \item `[group_cols...]` — group variable columns (when active), first.
#'     \item `variable` — row variable names (or labels).
#'     \item One column per focal variable, containing `r` values.
#'   }
#'
#'   Use `meta(result)` to access design type, variable labels, and
#'   `method` (`"pearson"`).
#'
#' @examples
#' d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
#'                strata = sdmvstra, nest = TRUE)
#' get_corr(d, x = c(ridageyr, bpxsy1))
#'
#' # Wide correlation matrix
#' get_corr(d, x = c(ridageyr, bpxsy1), format = "wide")
#'
#' # AAPOR-compliant
#' get_corr(d, x = c(ridageyr, bpxsy1),
#'          variance = c("ci", "moe"), n_weighted = TRUE)
#'
#' @family analysis
#' @export
get_corr <- function(
  design,
  x,
  group        = NULL,
  format       = c("long", "wide"),
  redundant    = FALSE,
  diagonal     = FALSE,
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
  .check_unsupported_class(design, "get_corr")
  .validate_shared_args(variance, conf_level, name_style)
  format <- match.arg(format)

  # ── Step 2: Resolve variables ────────────────────────────────────────────────
  x_quo     <- rlang::enquo(x)
  group_quo <- rlang::enquo(group)

  x_names_all <- .resolve_tidy_select(x_quo, design@data)

  # Drop non-numeric variables with warning (per dropped variable)
  is_numeric_col <- vapply(
    x_names_all,
    function(nm) is.numeric(design@data[[nm]]),
    logical(1L)
  )
  dropped <- x_names_all[!is_numeric_col]
  if (length(dropped) > 0L) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "{.fn get_corr} requires numeric variables. ",
          "Dropping non-numeric column{?s}: {.field {dropped}}."
        )
      ),
      class = "surveycore_warning_corr_non_numeric"
    )
  }
  x_names <- x_names_all[is_numeric_col]

  if (length(x_names) < 2L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.fn get_corr} requires at least 2 variables, but {.arg x} ",
          "resolved to {length(x_names)} variable{?s}."
        )
      ),
      class = "surveycore_error_insufficient_variables"
    )
  }

  # ── Step 3: Domain mask ───────────────────────────────────────────────────────
  domain_mask <- .apply_domain(design)

  # ── Step 4: Collect variable metadata ───────────────────────────────────────
  x_meta_list <- lapply(x_names, function(nm) .extract_var_meta(design, nm))
  names(x_meta_list) <- x_names

  # ── Step 5: Determine display names (labels or raw names) ───────────────────
  display_names <- if (isTRUE(label_vars)) {
    vapply(x_names, function(nm) {
      lbl <- x_meta_list[[nm]]$variable_label
      if (!is.null(lbl) && nchar(as.character(lbl)) > 0L) {
        as.character(lbl)
      } else {
        nm
      }
    }, character(1L))
  } else {
    x_names
  }
  names(display_names) <- x_names

  # ── Step 6: Build pair list ───────────────────────────────────────────────────
  p <- length(x_names)
  pairs_i <- integer(0); pairs_j <- integer(0)
  for (i in seq_len(p - 1L)) {
    for (j in seq(i + 1L, p)) {
      pairs_i <- c(pairs_i, i)
      pairs_j <- c(pairs_j, j)
    }
  }
  n_pairs <- length(pairs_i)

  # ── Step 7: Resolve group vars ────────────────────────────────────────────────
  group_vars <- .resolve_groups(design, group_quo)

  # ── Step 8: Single-level warning per group var ────────────────────────────────
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

  # ── Step 9: Build group combinations ──────────────────────────────────────────
  if (length(group_vars) > 0L) {
    domain_data  <- design@data[domain_mask, group_vars, drop = FALSE]
    # Exclude rows with NA in any group variable before building combos
    has_na       <- Reduce(`|`, lapply(group_vars,
                                       function(gv) is.na(domain_data[[gv]])))
    group_combos <- unique(domain_data[!has_na, , drop = FALSE])
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

  # ── Step 10: Outer group / inner pair loops ───────────────────────────────────
  all_pair_results  <- vector("list", n_combos)
  all_grp_rows      <- vector("list", n_combos)
  all_active_masks  <- vector("list", n_combos)
  small_cell_ns     <- integer(0)

  for (ci in seq_len(n_combos)) {
    # Build active mask for this combo
    if (length(group_vars) > 0L) {
      combo_row   <- group_combos[ci, , drop = FALSE]
      group_match <- rep(TRUE, nrow(design@data))
      for (gv in group_vars) {
        gv_col      <- design@data[[gv]]
        cv          <- combo_row[[gv]]
        group_match <- group_match & !is.na(gv_col) & (gv_col == cv)
      }
      active_mask <- domain_mask & group_match
      all_grp_rows[[ci]] <- combo_row
    } else {
      active_mask <- domain_mask
    }
    all_active_masks[[ci]] <- active_mask
    active_domain <- as.numeric(active_mask)

    # Inner loop: pairs
    pair_results_this <- vector("list", n_pairs)
    for (k in seq_len(n_pairs)) {
      xnm <- x_names[[pairs_i[[k]]]]
      ynm <- x_names[[pairs_j[[k]]]]
      vco <- .corr_vcov_pair(design, xnm, ynm, active_domain, na.rm)
      res <- .corr_pair_result(vco)
      pair_results_this[[k]] <- res
      if (!is.na(res$n) && res$n > 0L && res$n < min_cell_n) {
        small_cell_ns <- c(small_cell_ns, res$n)
      }
    }
    all_pair_results[[ci]] <- pair_results_this
  }

  # ── Step 11: Small-cell warning (fires once, after all groups) ───────────────
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

  # ── Step 12: Group metadata ───────────────────────────────────────────────────
  group_meta <- .build_group_meta(design, group_vars)

  # ── Step 13: Wide format path (grouped) ──────────────────────────────────────
  if (format == "wide") {
    wide_col_vecs_list <- vector("list", n_combos)
    wide_grp_rows      <- vector("list", n_combos)

    for (ci in seq_len(n_combos)) {
      wide_col_vecs_list[[ci]] <- .corr_build_matrix_col_vecs(
        x_names, display_names, pairs_i, pairs_j,
        all_pair_results[[ci]], diagonal
      )
      if (length(group_vars) > 0L) {
        wide_grp_rows[[ci]] <- all_grp_rows[[ci]][rep(1L, p), , drop = FALSE]
      }
    }

    # Stack col_vecs across combos
    all_col_names <- names(wide_col_vecs_list[[1L]])
    stacked_wide <- lapply(all_col_names, function(nm) {
      unlist(lapply(wide_col_vecs_list, `[[`, nm), use.names = FALSE)
    })
    names(stacked_wide) <- all_col_names

    # Build groups_df for wide result
    if (length(group_vars) > 0L) {
      wide_groups_df <- do.call(rbind, wide_grp_rows)
      rownames(wide_groups_df) <- NULL
      wide_groups_df <- .apply_group_labels(
        wide_groups_df, group_vars, design, label_values
      )
    } else {
      wide_groups_df <- data.frame()
    }

    meta_args_wide <- list(
      conf_level = conf_level,
      call       = match.call(),
      method     = "pearson",
      group      = group_meta,
      x          = x_meta_list
    )

    return(.make_result_tibble(
      stacked_wide, wide_groups_df, "survey_corr",
      design, meta_args_wide, CORR_META_KEYS
    ))
  }

  # ── Step 14: Long format — pre-loop constants ─────────────────────────────────
  # Expand pairs according to redundant/diagonal flags (same for every group)
  row_i <- integer(0); row_j <- integer(0)
  for (k in seq_len(n_pairs)) {
    row_i <- c(row_i, pairs_i[[k]])
    row_j <- c(row_j, pairs_j[[k]])
    if (isTRUE(redundant)) {
      row_i <- c(row_i, pairs_j[[k]])
      row_j <- c(row_j, pairs_i[[k]])
    }
  }
  if (isTRUE(diagonal)) {
    row_i <- c(row_i, seq_len(p))
    row_j <- c(row_j, seq_len(p))
  }
  n_rows_per_combo <- length(row_i)

  # Lookup from (i, j) pair index to pair_results index
  pair_idx_map <- matrix(NA_integer_, p, p)
  for (k in seq_len(n_pairs)) {
    pair_idx_map[pairs_i[[k]], pairs_j[[k]]] <- k
    pair_idx_map[pairs_j[[k]], pairs_i[[k]]] <- k
  }

  # ── Step 15: Pre-allocate accumulator vectors ─────────────────────────────────
  total_rows   <- n_combos * n_rows_per_combo
  acc_var1     <- character(total_rows)
  acc_var2     <- character(total_rows)
  acc_r        <- numeric(total_rows)
  acc_se       <- numeric(total_rows)
  acc_se_srs   <- numeric(total_rows)
  acc_pval     <- numeric(total_rows)
  acc_stat     <- numeric(total_rows)
  acc_df       <- integer(total_rows)
  acc_n        <- integer(total_rows)
  acc_nw       <- numeric(total_rows)
  acc_grp_rows <- vector("list", n_combos)

  # ── Step 16: Combo fill loop ──────────────────────────────────────────────────
  for (ci in seq_len(n_combos)) {
    offset       <- (ci - 1L) * n_rows_per_combo
    idx          <- offset + seq_len(n_rows_per_combo)
    active_mask  <- all_active_masks[[ci]]
    pair_results <- all_pair_results[[ci]]

    for (ri in seq_len(n_rows_per_combo)) {
      i   <- row_i[[ri]]
      j   <- row_j[[ri]]
      out <- offset + ri

      acc_var1[[out]] <- display_names[[x_names[[i]]]]
      acc_var2[[out]] <- display_names[[x_names[[j]]]]

      if (i == j) {
        # Self-correlation (diagonal = TRUE case)
        acc_r[[out]]      <- 1
        acc_se[[out]]     <- 0
        acc_se_srs[[out]] <- 0
        acc_pval[[out]]   <- 0
        acc_stat[[out]]   <- Inf
        acc_df[[out]]     <- 0L
        acc_n[[out]]      <- as.integer(
          sum(active_mask & !is.na(design@data[[x_names[[i]]]]))
        )
        acc_nw[[out]]     <- 0
      } else {
        k   <- pair_idx_map[i, j]
        res <- pair_results[[k]]
        r   <- res$r
        se  <- res$se_r
        nn  <- res$n

        acc_r[[out]]      <- r
        acc_se[[out]]     <- se
        acc_se_srs[[out]] <- res$se_srs
        acc_n[[out]]      <- as.integer(nn)
        acc_nw[[out]]     <- res$n_weighted

        if (!is.na(r) && !is.na(nn) && nn >= 3L) {
          df_t <- nn - 2L
          if (abs(r) < 1) {
            t_stat <- r * sqrt(df_t) / sqrt(1 - r^2)
          } else {
            t_stat <- if (r > 0) Inf else -Inf
          }
          acc_stat[[out]] <- t_stat
          acc_df[[out]]   <- df_t
          acc_pval[[out]] <- 2 * stats::pt(-abs(t_stat), df = df_t)
        } else {
          acc_stat[[out]] <- NA_real_
          acc_df[[out]]   <- NA_integer_
          acc_pval[[out]] <- NA_real_
        }
      }
    }

    if (length(group_vars) > 0L) {
      grp_block        <- all_grp_rows[[ci]][rep(1L, n_rows_per_combo), , drop = FALSE]
      acc_grp_rows[[ci]] <- grp_block
    }
  }

  # ── Step 17: Build groups_df ──────────────────────────────────────────────────
  if (length(group_vars) > 0L) {
    groups_df <- do.call(rbind, acc_grp_rows)
    rownames(groups_df) <- NULL
    groups_df <- .apply_group_labels(groups_df, group_vars, design, label_values)
  } else {
    groups_df <- data.frame()
  }

  # ── Step 18: Build variance columns ──────────────────────────────────────────
  r_vec     <- acc_r
  se_vec    <- acc_se
  sesrs_vec <- acc_se_srs

  var_col_list <- list()

  if (!is.null(variance)) {
    if ("se" %in% variance) {
      var_col_list$se <- se_vec
    }
    if ("var" %in% variance) {
      var_col_list$var <- se_vec^2
    }
    if ("cv" %in% variance) {
      cv <- se_vec / r_vec
      is_undef <- !is.na(r_vec) & r_vec <= 0
      n_undef  <- sum(is_undef)
      if (n_undef > 0L) {
        cv[is_undef] <- NA_real_
        cli::cli_warn(
          c(
            "!" = paste0(
              '{.arg variance = "cv"} is undefined for {n_undef} ',
              "cell{?s} where the correlation is 0 or negative."
            ),
            "i" = "{.code cv} set to {.code NA} for those cells."
          ),
          class = "surveycore_warning_cv_undefined"
        )
      }
      var_col_list$cv <- cv
    }
    if ("ci" %in% variance || "moe" %in% variance) {
      z_crit  <- stats::qnorm((1 + conf_level) / 2)
      ci_low  <- tanh(atanh(r_vec) - z_crit * se_vec)
      ci_high <- tanh(atanh(r_vec) + z_crit * se_vec)
      if ("ci" %in% variance) {
        var_col_list$ci_low  <- ci_low
        var_col_list$ci_high <- ci_high
      }
      if ("moe" %in% variance) {
        var_col_list$moe <- (ci_high - ci_low) / 2
      }
    }
    if ("deff" %in% variance) {
      deff <- (se_vec / sesrs_vec)^2
      deff[is.na(sesrs_vec) | sesrs_vec <= 0] <- NA_real_
      var_col_list$deff <- deff
    }
  }

  # ── Step 19: Assemble col_vecs in canonical order ─────────────────────────────
  col_vecs <- list(var1 = acc_var1, var2 = acc_var2, r = r_vec)
  col_vecs <- c(col_vecs, var_col_list)
  col_vecs$p_value   <- acc_pval
  col_vecs$statistic <- acc_stat
  col_vecs$df        <- acc_df
  col_vecs$n         <- acc_n
  if (isTRUE(n_weighted)) {
    col_vecs$n_weighted <- acc_nw
  }

  # ── Step 20: Build meta_args ──────────────────────────────────────────────────
  meta_args <- list(
    conf_level = conf_level,
    call       = match.call(),
    method     = "pearson",
    group      = group_meta,
    x          = x_meta_list
  )

  # ── Step 21: Assemble result ──────────────────────────────────────────────────
  result <- .make_result_tibble(
    col_vecs,
    groups_df,
    "survey_corr",
    design,
    meta_args,
    CORR_META_KEYS
  )

  # ── Step 22: Convert var1/var2 to factors (levels in variable supply order) ───
  # Display strings determine the factor level values; supply order is preserved.
  # Same uniq_display levels across all groups.
  uniq_display <- unique(display_names)
  result$var1  <- factor(result$var1, levels = uniq_display)
  result$var2  <- factor(result$var2, levels = uniq_display)

  # ── Step 23: Apply name style ─────────────────────────────────────────────────
  .apply_name_style(result, name_style)
}

