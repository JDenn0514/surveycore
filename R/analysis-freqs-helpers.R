# R/analysis-freqs-helpers.R
#
# Internal helpers for get_freqs().
#
# Functions:
#   .taylor_freq_cell()      — ratio linearization influence (survey_taylor)
#   .replicate_freq_cell()   — replicate-weight proportion variance
#   .freq_rep_total()        — per-replicate total of a 0/1 indicator
#   .twophase_freq_cell()    — two-phase proportion via .twophasevar()
#   .calibrated_freq_cell()  — HT proportion variance (survey_nonprob)
#   .freq_cell()             — dispatcher

# ── .taylor_freq_cell() ───────────────────────────────────────────────────────
#
# Compute a weighted proportion and its Taylor-linearized influence column for
# one cell using the ratio (domain estimation) approach. The cell runs no
# variance call: get_freqs() takes every live cell's SE from one stacked
# call after the cell loop (.taylor_cell_se()), so `se` is NA_real_ here.
#
# @param design  A survey_taylor object.
# @param num     Numeric vector (0/1): rows in the cell
#                (level AND domain/group).
# @param denom   Numeric vector (0/1): rows in the group/domain (denominator).
# @param mats    The .build_cluster_matrices() list from the call context
#                (ctx$mats).
#
# @return Named list: pct, se (NA_real_), se_srs, n (unweighted cell count),
#   n_weighted, joint (see .joint_vcov()).
.taylor_freq_cell <- function(design, num, denom, mats) {
  data <- design@data
  vars <- design@variables
  n <- nrow(data)
  w <- data[[vars$weights]]

  N_d <- sum(w * denom)
  n_g <- as.integer(sum(denom)) # unweighted group/domain count

  if (n_g == 0L || N_d <= 0) {
    return(list(
      pct = NA_real_,
      se = NA_real_,
      se_srs = NA_real_,
      n = 0L,
      n_weighted = 0,
      joint = .joint_na()
    ))
  }

  Y <- sum(w * num)
  p <- Y / N_d
  n_cell <- as.integer(sum(num))

  # Linearized influence: u_i = num_i - p * denom_i
  u <- num - p * denom

  infl_mat <- matrix(w * u / N_d, ncol = 1L, dimnames = list(NULL, "prop"))
  infl_mat <- .maybe_apply_calibration(infl_mat, design)

  se_srs <- if (n_g >= 2L && p > 0 && p < 1) {
    sqrt(p * (1 - p) / n_g)
  } else {
    0
  }

  list(
    pct = p,
    se = NA_real_,
    se_srs = se_srs,
    n = n_cell,
    n_weighted = Y,
    joint = .joint_infl(infl_mat)
  )
}


# ── .replicate_freq_cell() ────────────────────────────────────────────────────
#
# Compute a weighted proportion and its replicate-weight variance for one cell.
#
# @param design      A survey_replicate object, or a survey_nonprob object
#                    with replicate weights.
# @param num         Numeric vector (0/1): cell membership (level AND
#                    domain/group).
# @param denom       Numeric vector (0/1): group/domain membership.
# @param rep_mat     The replicate weight matrix from the call context
#                    (ctx$rep_mat).
# @param rep_finite  ctx$rep_finite. TRUE sums rep_mat over the cell's rows
#                    only; FALSE uses the full product num %*% rep_mat.
# @param rep_N_d     The per-replicate denominator totals of `denom`, from
#                    .freq_rep_total(denom, ...) in the same form as
#                    `rep_finite`, computed once per group combination.
#
# @return Named list: pct, se, se_srs, n, n_weighted, joint (see
#   .joint_vcov()).
.replicate_freq_cell <- function(
  design,
  num,
  denom,
  rep_mat,
  rep_finite,
  rep_N_d
) {
  data <- design@data
  vars <- design@variables
  w <- data[[vars$weights]] # full-sample base weights

  N_d <- sum(w * denom)
  n_g <- as.integer(sum(denom))

  if (n_g == 0L || N_d <= 0) {
    return(list(
      pct = NA_real_,
      se = NA_real_,
      se_srs = NA_real_,
      n = 0L,
      n_weighted = 0,
      joint = .joint_na()
    ))
  }

  Y <- sum(w * num)
  p <- Y / N_d
  n_cell <- as.integer(sum(num))

  # Per-replicate proportions using BLAS matrix operations
  rep_Y <- .freq_rep_total(num, rep_mat, rep_finite) # cell count per replicate
  rep_p <- ifelse(rep_N_d > 0, rep_Y / rep_N_d, NA_real_)

  R <- ncol(rep_mat)
  na_dropped <- sum(is.na(rep_p))
  na_frac <- na_dropped / R
  if (
    isTRUE(
      .nonprob_rep_na_warn(design, na_frac, na_dropped, R, vars$scale)
    )
  ) {
    return(list(
      pct = NA_real_,
      se = NA_real_,
      se_srs = NA_real_,
      n = n_cell,
      n_weighted = Y,
      joint = .joint_na()
    ))
  }

  v <- .svy_rep_var(
    rep_p,
    scale = vars$scale,
    rscales = if (!is.null(vars$rscales)) vars$rscales else rep(1L, R),
    mse = isTRUE(vars$mse),
    coef = p
  )

  se <- sqrt(max(0, v))
  se_srs <- if (n_g >= 2L && p > 0 && p < 1) {
    sqrt(p * (1 - p) / n_g)
  } else {
    0
  }

  list(
    pct = p,
    se = se,
    se_srs = se_srs,
    n = n_cell,
    n_weighted = Y,
    joint = .joint_rep(rep_p, p)
  )
}


# ── .freq_rep_total() ─────────────────────────────────────────────────────────
#
# Per-replicate weighted total of a 0/1 indicator: the replicate denominator
# totals rep_N_d (indicator `denom`) and the numerator totals rep_Y
# (indicator `num`) of get_freqs(). With every replicate weight finite, sum
# the rows where the indicator is 1 only; the dropped terms are exact zeros,
# so the result equals the full product. With an NA or Inf replicate weight,
# use the full product: a row outside the cell then gives NA or NaN for that
# replicate in every cell, and .svy_rep_var() drops it, as on the base code.
# Keep both forms as BLAS products; colSums() adds in long double and would
# move the last bit.
#
# @param ind         Numeric vector (0/1), full design length.
# @param rep_mat     The replicate weight matrix (ctx$rep_mat).
# @param rep_finite  ctx$rep_finite.
# @return Numeric vector, one total per replicate.
.freq_rep_total <- function(ind, rep_mat, rep_finite) {
  if (rep_finite) {
    idx <- which(ind > 0)
    as.numeric(rep(1, length(idx)) %*% rep_mat[idx, , drop = FALSE])
  } else {
    as.numeric(ind %*% rep_mat)
  }
}


# ── .twophase_freq_cell() ─────────────────────────────────────────────────────
#
# Compute a weighted proportion and its two-phase linearized standard error
# for one cell. Uses calibrated weights and the full .twophasevar() engine.
#
# @param design  A survey_twophase object.
# @param num     Numeric vector (0/1): cell membership (full length, Phase 2
#   rows only have non-zero values).
# @param denom   Numeric vector (0/1): group/domain membership (full length).
#
# @return Named list: pct, se, se_srs, n, n_weighted.
.twophase_freq_cell <- function(design, num, denom) {
  data <- design@data
  ph1_vars <- design@variables$phase1
  subset <- data[[design@variables$subset]] # logical, full length

  w_full <- data[[ph1_vars$weights]]
  pi2_full <- .compute_phase2_probs(design, subset)
  cal_wt <- w_full / pi2_full

  # Restrict to Phase 2 rows
  num_ph2 <- num[subset]
  denom_ph2 <- denom[subset]
  cal_ph2 <- cal_wt[subset]

  n_g <- as.integer(sum(denom_ph2))
  N_d <- sum(cal_ph2 * denom_ph2)

  if (n_g == 0L || N_d <= 0) {
    return(list(
      pct = NA_real_,
      se = NA_real_,
      se_srs = NA_real_,
      n = 0L,
      n_weighted = 0
    ))
  }

  Y <- sum(cal_ph2 * num_ph2)
  p <- Y / N_d
  n_cell <- as.integer(sum(num_ph2))

  # Full-length influence vector (0 for Phase 1-only rows)
  n_total <- nrow(data)
  influence <- numeric(n_total)
  ph2_idx <- which(subset)
  influence[ph2_idx] <- cal_ph2 * (num_ph2 - p * denom_ph2) / N_d

  lonely.psu <- getOption("survey.lonely.psu", "remove")
  v_raw <- .twophasevar(influence, design, lonely.psu)
  v_scalar <- if (is.matrix(v_raw)) drop(v_raw)[1L, 1L] else as.numeric(v_raw)

  se <- sqrt(max(0, v_scalar))
  se_srs <- if (n_g >= 2L && p > 0 && p < 1) {
    sqrt(p * (1 - p) / n_g)
  } else {
    0
  }

  list(
    pct = p,
    se = se,
    se_srs = se_srs,
    n = n_cell,
    n_weighted = Y
  )
}


# ── .calibrated_freq_cell() ──────────────────────────────────────────────────
#
# Compute a weighted proportion and its HT standard error for one cell in a
# calibrated (non-probability) design. Uses the HT variance directly on the
# 0/1 indicator. This keeps survey_nonprob dispatch consistent across all six
# analysis functions (all use the HT variance path rather than Taylor
# linearization).
#
# @param design  A survey_nonprob object.
# @param num     Numeric vector (0/1): cell membership (level AND domain/group).
# @param denom   Numeric vector (0/1): group/domain membership (denominator).
#
# @return Named list: pct, se, se_srs, n (unweighted cell count), n_weighted.
.calibrated_freq_cell <- function(design, num, denom) {
  data <- design@data
  vars <- design@variables
  w <- data[[vars$weights]]

  n_g <- as.integer(sum(denom))
  N_d <- sum(w * denom)
  n_cell <- as.integer(sum(num))
  Y <- sum(w * num)
  p <- if (N_d > 0) Y / N_d else NA_real_

  if (n_g == 0L || N_d <= 0) {
    return(list(
      pct = NA_real_,
      se = NA_real_,
      se_srs = NA_real_,
      n = 0L,
      n_weighted = 0
    ))
  }

  if (n_g < 2L) {
    return(list(
      pct = p,
      se = NA_real_,
      se_srs = NA_real_,
      n = n_cell,
      n_weighted = Y
    ))
  }

  # HT variance: n/(n-1) * sum(z_i^2), z_i = w_i*(I_i - p)/N_d
  # Only rows in the denominator domain contribute
  idx <- denom > 0
  w_sub <- w[idx]
  I_sub <- (num / denom)[idx] # 0/1 indicator within domain
  z <- w_sub * (I_sub - p) / N_d
  var_p <- (n_g / (n_g - 1L)) * sum(z^2)
  se <- sqrt(max(0, var_p))

  se_srs <- if (p > 0 && p < 1) sqrt(p * (1 - p) / n_g) else 0

  list(
    pct = p,
    se = se,
    se_srs = se_srs,
    n = n_cell,
    n_weighted = Y
  )
}


# ── .freq_cell() ──────────────────────────────────────────────────────────────
#
# Dispatch to the correct per-cell proportion estimator by design class.
#
# @param design   Any survey design object.
# @param num      Numeric 0/1 vector: cell membership (full length).
# @param denom    Numeric 0/1 vector: group/domain membership (full length).
# @param ctx      The call context (.cell_context()). ctx$mats goes to the
#                 Taylor cell; ctx$rep_mat and ctx$rep_finite go to the
#                 replicate cell.
# @param rep_N_d  The replicate denominator totals (.freq_rep_total()), or
#                 NULL off the replicate route. Goes to the replicate cell.
#
# @return Named list: pct, se, se_srs, n, n_weighted.
.freq_cell <- function(design, num, denom, ctx, rep_N_d) {
  if (S7::S7_inherits(design, survey_taylor)) {
    .taylor_freq_cell(design, num, denom, ctx$mats)
  } else if (S7::S7_inherits(design, survey_nonprob)) {
    if (!is.null(design@variables$repweights)) {
      .replicate_freq_cell(
        design,
        num,
        denom,
        ctx$rep_mat,
        ctx$rep_finite,
        rep_N_d
      )
    } else {
      cli::cli_warn(
        c(
          "!" = paste0(
            "{.cls survey_nonprob} object has no bootstrap replicate ",
            "weights. Standard errors use an SRS approximation that ",
            "underestimates calibration uncertainty."
          ),
          "i" = paste0(
            "Run {.fn surveywts::create_bootstrap_weights} on this ",
            "design for correct SEs."
          )
        ),
        class = "surveycore_warning_nonprob_srs_fallback"
      )
      .calibrated_freq_cell(design, num, denom)
    }
  } else if (S7::S7_inherits(design, survey_replicate)) {
    .replicate_freq_cell(
      design,
      num,
      denom,
      ctx$rep_mat,
      ctx$rep_finite,
      rep_N_d
    )
  } else if (S7::S7_inherits(design, survey_twophase)) {
    .twophase_freq_cell(design, num, denom)
  } else {
    cli::cli_abort(
      c(
        "x" = "Unsupported design class {.cls {class(design)[[1L]]}} in",
        "i" = "{.fn get_freqs} does not support this design type."
      ),
      class = "surveycore_error_unsupported_class"
    )
  }
}
