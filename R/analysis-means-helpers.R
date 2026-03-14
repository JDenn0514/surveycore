# R/analysis-means-helpers.R
#
# Internal helpers for get_means().
#
# Functions:
#   .mean_domain_vec()      — build na-aware active-domain vector
#   .taylor_mean_cell()     — Taylor domain-estimation mean
#   .replicate_mean_cell()  — replicate-weight domain mean
#   .srs_mean_cell()        — SRS domain mean
#   .twophase_mean_cell()   — two-phase domain mean
#   .calibrated_mean_cell() — calibrated domain mean
#   .mean_cell()            — dispatcher
#
# Note: .mean_domain_vec() is also used by get_totals() in
# analysis-totals.R for the NA-aware domain vector.

# ── .mean_domain_vec() ────────────────────────────────────────────────────────
#
# Build the domain indicator vector for a continuous variable. Each element
# is 1 if the row is in the active group/domain AND the variable is non-NA
# (when na.rm = TRUE), else 0. All downstream cell functions treat a 0 entry
# as zero influence.
#
# @param active_mask   Logical vector (full length): TRUE for rows in the
#                      current group/domain combination.
# @param y_col        Atomic vector: the focal variable column.
# @param na.rm        Logical.
# @return Numeric 0/1 vector of length nrow(design@data).
.mean_domain_vec <- function(active_mask, y_col, na.rm) {
  if (na.rm) {
    as.numeric(active_mask & !is.na(y_col))
  } else {
    as.numeric(active_mask)
  }
}


# ── .taylor_mean_cell() ───────────────────────────────────────────────────────
#
# Domain estimation of a weighted mean using Taylor linearization. Uses the
# full cluster/strata structure — domain rows have influence, non-domain rows
# have zero influence. This gives correct SEs for subpopulation means (wider
# than physical subsetting).
#
# @param design  A survey_taylor or survey_nonprob object.
# @param y_col   Character: name of the numeric variable column.
# @param domain  Numeric 0/1 vector (full length): 1 = in domain and non-NA.
# @return Named list: mean, se, se_srs, n, n_weighted.
.taylor_mean_cell <- function(design, y_col, domain) {
  data <- design@data
  vars <- design@variables
  n_full <- nrow(data)
  w <- data[[vars$weights]]
  y_all <- data[[y_col]]

  N_d <- sum(w * domain)
  n_d <- as.integer(sum(domain))

  if (n_d == 0L || N_d <= 0) {
    return(list(
      mean = NA_real_,
      se = NA_real_,
      se_srs = NA_real_,
      n = 0L,
      n_weighted = 0
    ))
  }

  # Replace out-of-domain NAs with 0 so arithmetic is safe
  y_safe <- ifelse(domain > 0, y_all, 0)
  ybar <- sum(w * domain * y_safe) / N_d

  # Linearized influence: u_i = domain_i * (y_i - ybar)
  # Out-of-domain rows contribute 0; in-domain rows contribute (y_i - ybar)
  u <- domain * (y_safe - ybar)

  # Build cluster / strata / FPC matrices (full dataset, multi-stage aware)
  mats <- .build_cluster_matrices(data, vars)
  lonely.psu <- getOption("survey.lonely.psu", "remove")

  infl_mat <- matrix(w * u / N_d, ncol = 1L, dimnames = list(NULL, y_col))
  v <- .svy_recvar(
    infl_mat,
    mats$clusters_mat,
    mats$strata_mat,
    mats$fpcs,
    lonely.psu = lonely.psu
  )

  se <- sqrt(max(0, v[1L, 1L]))

  # SRS-equivalent SE for design effect computation
  y_domain <- y_all[domain > 0]
  se_srs <- if (n_d >= 2L) {
    s2 <- sum((y_domain - ybar)^2) / (n_d - 1L)
    sqrt(s2 / n_d)
  } else {
    0
  }

  list(mean = ybar, se = se, se_srs = se_srs, n = n_d, n_weighted = N_d)
}


# ── .replicate_mean_cell() ────────────────────────────────────────────────────
#
# Domain estimation of a weighted mean using replicate weights.
#
# @param design  A survey_replicate object.
# @param y_col   Character: variable name.
# @param domain  Numeric 0/1 vector (full length).
# @return Named list: mean, se, se_srs, n, n_weighted.
.replicate_mean_cell <- function(design, y_col, domain) {
  data <- design@data
  vars <- design@variables
  w <- data[[vars$weights]]
  y_all <- data[[y_col]]

  y_safe <- ifelse(domain > 0, y_all, 0)

  N_d <- sum(w * domain)
  n_d <- as.integer(sum(domain))

  if (n_d == 0L || N_d <= 0) {
    return(list(
      mean = NA_real_,
      se = NA_real_,
      se_srs = NA_real_,
      n = 0L,
      n_weighted = 0
    ))
  }

  ybar <- sum(w * domain * y_safe) / N_d

  # Per-replicate domain means
  rep_mat <- as.matrix(data[, vars$repweights, drop = FALSE])
  rep_N_d <- as.numeric(domain %*% rep_mat) # weighted domain size per replicate
  rep_Y <- as.numeric((y_safe * domain) %*% rep_mat) # weighted sum per replicate
  rep_p <- ifelse(rep_N_d > 0, rep_Y / rep_N_d, NA_real_)

  n_rep <- ncol(rep_mat)
  v <- .svy_rep_var(
    rep_p,
    scale = vars$scale,
    rscales = if (!is.null(vars$rscales)) vars$rscales else rep(1L, n_rep),
    mse = isTRUE(vars$mse),
    coef = ybar
  )

  se <- sqrt(max(0, v))

  y_domain <- y_all[domain > 0]
  se_srs <- if (n_d >= 2L) {
    s2 <- sum((y_domain - ybar)^2) / (n_d - 1L)
    sqrt(s2 / n_d)
  } else {
    0
  }

  list(mean = ybar, se = se, se_srs = se_srs, n = n_d, n_weighted = N_d)
}


# ── .srs_mean_cell() ──────────────────────────────────────────────────────────
#
# Domain estimation of a weighted mean for SRS designs. For SRS, physical
# subsetting to the domain is equivalent to domain estimation. se_srs = se.
#
# @param design  A survey_srs object.
# @param y_col   Character: variable name.
# @param domain  Numeric 0/1 vector (full length).
# @return Named list: mean, se, se_srs, n, n_weighted.
.srs_mean_cell <- function(design, y_col, domain) {
  data <- design@data
  vars <- design@variables

  idx <- domain > 0
  n_d <- as.integer(sum(idx))

  if (n_d == 0L) {
    return(list(
      mean = NA_real_,
      se = NA_real_,
      se_srs = NA_real_,
      n = 0L,
      n_weighted = 0
    ))
  }

  w_sub <- data[[vars$weights]][idx]
  y_sub <- data[[y_col]][idx]
  N_d <- sum(w_sub)
  ybar <- sum(w_sub * y_sub) / N_d

  if (n_d == 1L) {
    return(list(
      mean = ybar,
      se = NA_real_,
      se_srs = NA_real_,
      n = 1L,
      n_weighted = N_d
    ))
  }

  # FPC
  fpc_var <- vars$fpc
  fpc_type <- vars$fpc_type
  f <- 0
  if (!is.null(fpc_var)) {
    fpc_col <- data[[fpc_var]][idx]
    f <- if (identical(fpc_type, "population")) {
      n_d / mean(fpc_col, na.rm = TRUE)
    } else {
      mean(fpc_col, na.rm = TRUE)
    }
  }

  s2 <- sum((y_sub - ybar)^2) / (n_d - 1L)
  se <- sqrt(max(0, (1 - f) * s2 / n_d))

  list(mean = ybar, se = se, se_srs = se, n = n_d, n_weighted = N_d)
}


# ── .twophase_mean_cell() ─────────────────────────────────────────────────────
#
# Domain estimation of a weighted mean for two-phase designs. Computes
# calibrated weights and builds the full-length influence vector for the
# domain, then calls .twophasevar().
#
# @param design  A survey_twophase object.
# @param y_col   Character: variable name.
# @param domain  Numeric 0/1 vector (full length): 1 = in domain and non-NA.
# @return Named list: mean, se, se_srs, n, n_weighted.
.twophase_mean_cell <- function(design, y_col, domain) {
  data <- design@data
  ph1_vars <- design@variables$phase1
  subset <- data[[design@variables$subset]] # logical, full length

  w_full <- data[[ph1_vars$weights]]
  pi2_full <- .compute_phase2_probs(design, subset)
  cal_wt <- w_full / pi2_full

  # Restrict to Phase 2 rows
  dom_ph2 <- domain[subset]
  cal_ph2 <- cal_wt[subset]
  y_ph2 <- data[[y_col]][subset]

  n_d <- as.integer(sum(dom_ph2))
  N_d <- sum(cal_ph2 * dom_ph2)

  if (n_d == 0L || N_d <= 0) {
    return(list(
      mean = NA_real_,
      se = NA_real_,
      se_srs = NA_real_,
      n = 0L,
      n_weighted = 0
    ))
  }

  y_safe_ph2 <- ifelse(dom_ph2 > 0, y_ph2, 0)
  ybar <- sum(cal_ph2 * dom_ph2 * y_safe_ph2) / N_d

  # Full-length influence vector (0 for Phase 1-only rows)
  n_total <- nrow(data)
  influence <- numeric(n_total)
  ph2_idx <- which(subset)
  influence[ph2_idx] <- cal_ph2 * dom_ph2 * (y_safe_ph2 - ybar) / N_d

  lonely.psu <- getOption("survey.lonely.psu", "remove")
  v_raw <- .twophasevar(influence, design, lonely.psu)
  v_scalar <- if (is.matrix(v_raw)) drop(v_raw)[1L] else as.numeric(v_raw)

  se <- sqrt(max(0, v_scalar))

  y_domain <- y_ph2[dom_ph2 > 0]
  se_srs <- if (n_d >= 2L) {
    s2 <- sum((y_domain - ybar)^2) / (n_d - 1L)
    sqrt(s2 / n_d)
  } else {
    0
  }

  list(mean = ybar, se = se, se_srs = se_srs, n = n_d, n_weighted = N_d)
}


# ── .calibrated_mean_cell() ───────────────────────────────────────────────────
#
# Domain estimation of a weighted mean for calibrated (non-probability) designs.
# Uses the HT Taylor linearization variance (matching survey::svydesign(ids=~1)):
#   z_i = w_i * (y_i - ybar_w) / N_hat
#   Var(ybar_w) = n/(n-1) * sum(z_i^2)
#              = n/(n-1) * sum(w_i^2 * (y_i - ybar_w)^2) / N_hat^2
#
# @param design  A survey_nonprob object.
# @param y_col   Character: variable name.
# @param domain  Numeric 0/1 vector (full length).
# @return Named list: mean, se, se_srs, n, n_weighted.
.calibrated_mean_cell <- function(design, y_col, domain) {
  data <- design@data
  vars <- design@variables

  idx <- domain > 0
  n_d <- as.integer(sum(idx))

  if (n_d == 0L) {
    return(list(
      mean = NA_real_,
      se = NA_real_,
      se_srs = NA_real_,
      n = 0L,
      n_weighted = 0
    ))
  }

  w_sub <- data[[vars$weights]][idx]
  y_sub <- data[[y_col]][idx]
  N_d <- sum(w_sub)
  ybar <- sum(w_sub * y_sub) / N_d

  if (n_d == 1L) {
    return(list(
      mean = ybar,
      se = NA_real_,
      se_srs = NA_real_,
      n = 1L,
      n_weighted = N_d
    ))
  }

  # HT Taylor linearization: n/(n-1) * sum(z_i^2), z_i = w_i*(y_i-ybar)/N_hat
  var_ybar <- (n_d / (n_d - 1L)) * sum(w_sub^2 * (y_sub - ybar)^2) / N_d^2
  se <- sqrt(max(0, var_ybar))

  # SRS-equivalent SE for deff
  se_srs <- if (n_d >= 2L) {
    s2 <- sum((y_sub - ybar)^2) / (n_d - 1L)
    sqrt(s2 / n_d)
  } else {
    0
  }

  list(mean = ybar, se = se, se_srs = se_srs, n = n_d, n_weighted = N_d)
}


# ── .mean_cell() ──────────────────────────────────────────────────────────────
#
# Dispatch to the correct per-cell mean estimator by design class.
#
# @param design  Any survey design object.
# @param y_col   Character: variable name.
# @param domain  Numeric 0/1 vector (full length).
# @return Named list: mean, se, se_srs, n, n_weighted.
.mean_cell <- function(design, y_col, domain) {
  if (S7::S7_inherits(design, survey_taylor)) {
    .taylor_mean_cell(design, y_col, domain)
  } else if (S7::S7_inherits(design, survey_replicate)) {
    .replicate_mean_cell(design, y_col, domain)
  } else if (S7::S7_inherits(design, survey_twophase)) {
    .twophase_mean_cell(design, y_col, domain)
  } else if (S7::S7_inherits(design, survey_srs)) {
    .srs_mean_cell(design, y_col, domain)
  } else if (S7::S7_inherits(design, survey_nonprob)) {
    .calibrated_mean_cell(design, y_col, domain)
  } else {
    cli::cli_abort(
      c(
        "x" = "Unsupported design class {.cls {class(design)[[1L]]}} in {.fn get_means}.",
        "i" = "Use {.fn as_survey}, {.fn as_survey_replicate}, or {.fn as_survey_twophase}."
      ),
      class = "surveycore_error_unsupported_class"
    )
  }
}
