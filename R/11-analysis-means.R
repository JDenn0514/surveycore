# R/11-analysis-means.R
#
# Weighted mean and total estimation for survey designs.
# Exported functions: get_means(), get_totals()
#
# Single-use helpers (used only in this file):
#   .mean_domain_vec()        — build na-aware active-domain vector
#   .taylor_mean_cell()       — Taylor domain-estimation mean
#   .taylor_total_cell()      — Taylor domain-estimation total
#   .replicate_mean_cell()    — replicate-weight domain mean
#   .replicate_total_cell()   — replicate-weight domain total
#   .srs_mean_cell()          — SRS domain mean
#   .srs_total_cell()         — SRS domain total
#   .twophase_mean_cell()     — two-phase domain mean
#   .twophase_total_cell()    — two-phase domain total
#   .calibrated_mean_cell()   — calibrated (weighted SRS) domain mean
#   .calibrated_total_cell()  — calibrated (weighted SRS) domain total
#   .mean_cell()              — dispatcher: mean
#   .total_cell()             — dispatcher: total


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
# @param design  A survey_taylor or survey_calibrated object.
# @param y_col   Character: name of the numeric variable column.
# @param domain  Numeric 0/1 vector (full length): 1 = in domain and non-NA.
# @return Named list: mean, se, se_srs, n, n_weighted.
.taylor_mean_cell <- function(design, y_col, domain) {
  data   <- design@data
  vars   <- design@variables
  n_full <- nrow(data)
  w      <- data[[vars$weights]]
  y_all  <- data[[y_col]]

  N_d <- sum(w * domain)
  n_d <- as.integer(sum(domain))

  if (n_d == 0L || N_d <= 0) {
    return(list(
      mean = NA_real_, se = NA_real_, se_srs = NA_real_, n = 0L, n_weighted = 0
    ))
  }

  # Replace out-of-domain NAs with 0 so arithmetic is safe
  y_safe <- ifelse(domain > 0, y_all, 0)
  ybar   <- sum(w * domain * y_safe) / N_d

  # Linearized influence: u_i = domain_i * (y_i - ybar)
  # Out-of-domain rows contribute 0; in-domain rows contribute (y_i - ybar)
  u <- domain * (y_safe - ybar)

  # Build cluster / strata IDs (full dataset)
  strata_id <- if (!is.null(vars$strata)) {
    data[[vars$strata]]
  } else {
    rep(1L, n_full)
  }

  psu_id <- if (!is.null(vars$ids)) {
    raw_ids <- data[[vars$ids[[1L]]]]
    if (isTRUE(vars$nest) && !is.null(vars$strata)) {
      as.integer(interaction(strata_id, raw_ids, drop = TRUE))
    } else {
      raw_ids
    }
  } else {
    seq_len(n_full)
  }

  clusters_mat <- matrix(psu_id, ncol = 1L)
  strata_mat   <- matrix(strata_id, ncol = 1L)

  psu_per_stratum <- tapply(psu_id, strata_id, function(ps) length(unique(ps)))
  sampsize_vec    <- as.integer(psu_per_stratum[as.character(strata_id)])
  sampsize_mat    <- matrix(sampsize_vec, ncol = 1L)

  fpc_col_full <- if (!is.null(vars$fpc)) data[[vars$fpc]] else NULL
  popsize_mat <- if (!is.null(fpc_col_full)) {
    fpc_vals <- fpc_col_full
    if (any(fpc_vals > 1, na.rm = TRUE)) {
      matrix(as.numeric(fpc_vals), ncol = 1L)
    } else {
      matrix(as.numeric(sampsize_vec / fpc_vals), ncol = 1L)
    }
  } else {
    NULL
  }

  fpcs       <- list(sampsize = sampsize_mat, popsize = popsize_mat)
  lonely.psu <- getOption("survey.lonely.psu", "remove")

  infl_mat <- matrix(w * u / N_d, ncol = 1L, dimnames = list(NULL, y_col))
  v        <- .svy_recvar(
    infl_mat, clusters_mat, strata_mat, fpcs, lonely.psu = lonely.psu
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


# ── .taylor_total_cell() ──────────────────────────────────────────────────────
#
# Domain estimation of a weighted total using Taylor linearization.
#
# @param design  A survey_taylor or survey_calibrated object.
# @param y_col   Character: variable name, OR NULL for population size.
# @param domain  Numeric 0/1 vector (full length).
# @return Named list: total, se, se_srs, n, n_weighted.
.taylor_total_cell <- function(design, y_col, domain) {
  data   <- design@data
  vars   <- design@variables
  n_full <- nrow(data)
  w      <- data[[vars$weights]]

  if (is.null(y_col)) {
    # Population size mode: y_i = 1 for all in-domain rows
    y_safe <- domain
    y_all  <- rep(1, n_full)
  } else {
    y_all  <- data[[y_col]]
    y_safe <- ifelse(domain > 0, y_all, 0)
  }

  N_d <- sum(w * domain)
  n_d <- as.integer(sum(domain))

  if (n_d == 0L || N_d <= 0) {
    return(list(
      total = NA_real_, se = NA_real_, se_srs = NA_real_,
      n = if (is.null(y_col)) NULL else 0L,
      n_weighted = 0
    ))
  }

  T_hat <- sum(w * domain * y_safe)

  # Influence: u_i = domain_i * y_i  (total linearization)
  u <- domain * y_safe

  # Build cluster / strata IDs
  strata_id <- if (!is.null(vars$strata)) {
    data[[vars$strata]]
  } else {
    rep(1L, n_full)
  }

  psu_id <- if (!is.null(vars$ids)) {
    raw_ids <- data[[vars$ids[[1L]]]]
    if (isTRUE(vars$nest) && !is.null(vars$strata)) {
      as.integer(interaction(strata_id, raw_ids, drop = TRUE))
    } else {
      raw_ids
    }
  } else {
    seq_len(n_full)
  }

  clusters_mat <- matrix(psu_id, ncol = 1L)
  strata_mat   <- matrix(strata_id, ncol = 1L)

  psu_per_stratum <- tapply(psu_id, strata_id, function(ps) length(unique(ps)))
  sampsize_vec    <- as.integer(psu_per_stratum[as.character(strata_id)])
  sampsize_mat    <- matrix(sampsize_vec, ncol = 1L)

  fpc_col_full <- if (!is.null(vars$fpc)) data[[vars$fpc]] else NULL
  popsize_mat <- if (!is.null(fpc_col_full)) {
    fpc_vals <- fpc_col_full
    if (any(fpc_vals > 1, na.rm = TRUE)) {
      matrix(as.numeric(fpc_vals), ncol = 1L)
    } else {
      matrix(as.numeric(sampsize_vec / fpc_vals), ncol = 1L)
    }
  } else {
    NULL
  }

  fpcs       <- list(sampsize = sampsize_mat, popsize = popsize_mat)
  lonely.psu <- getOption("survey.lonely.psu", "remove")

  lbl      <- if (is.null(y_col)) "pop_total" else y_col
  infl_mat <- matrix(w * u, ncol = 1L, dimnames = list(NULL, lbl))
  v        <- .svy_recvar(
    infl_mat, clusters_mat, strata_mat, fpcs, lonely.psu = lonely.psu
  )

  se <- sqrt(max(0, v[1L, 1L]))

  # SRS-equivalent SE
  y_domain <- y_safe[domain > 0]
  se_srs <- if (n_d >= 2L) {
    N_hat <- N_d
    ybar  <- T_hat / N_hat
    s2    <- sum((y_domain - ybar)^2) / (n_d - 1L)
    N_hat * sqrt(s2 / n_d)
  } else {
    0
  }

  list(
    total      = T_hat,
    se         = se,
    se_srs     = se_srs,
    n          = if (is.null(y_col)) NULL else n_d,
    n_weighted = N_d
  )
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
  w    <- data[[vars$weights]]
  y_all <- data[[y_col]]

  y_safe <- ifelse(domain > 0, y_all, 0)

  N_d <- sum(w * domain)
  n_d <- as.integer(sum(domain))

  if (n_d == 0L || N_d <= 0) {
    return(list(
      mean = NA_real_, se = NA_real_, se_srs = NA_real_, n = 0L, n_weighted = 0
    ))
  }

  ybar <- sum(w * domain * y_safe) / N_d

  # Per-replicate domain means
  rep_mat <- as.matrix(data[, vars$repweights, drop = FALSE])
  rep_N_d <- as.numeric(domain %*% rep_mat)       # weighted domain size per replicate
  rep_Y   <- as.numeric((y_safe * domain) %*% rep_mat)  # weighted sum per replicate
  rep_p   <- ifelse(rep_N_d > 0, rep_Y / rep_N_d, NA_real_)

  n_rep <- ncol(rep_mat)
  v <- .svy_rep_var(
    rep_p,
    scale   = vars$scale,
    rscales = if (!is.null(vars$rscales)) vars$rscales else rep(1L, n_rep),
    mse     = isTRUE(vars$mse),
    coef    = ybar
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


# ── .replicate_total_cell() ───────────────────────────────────────────────────
#
# Domain estimation of a weighted total using replicate weights.
#
# @param design  A survey_replicate object.
# @param y_col   Character: variable name, OR NULL for population size.
# @param domain  Numeric 0/1 vector (full length).
# @return Named list: total, se, se_srs, n, n_weighted.
.replicate_total_cell <- function(design, y_col, domain) {
  data <- design@data
  vars <- design@variables
  w    <- data[[vars$weights]]

  if (is.null(y_col)) {
    y_safe <- domain
    y_all  <- rep(1, nrow(data))
  } else {
    y_all  <- data[[y_col]]
    y_safe <- ifelse(domain > 0, y_all, 0)
  }

  N_d <- sum(w * domain)
  n_d <- as.integer(sum(domain))

  if (n_d == 0L || N_d <= 0) {
    return(list(
      total = NA_real_, se = NA_real_, se_srs = NA_real_,
      n = if (is.null(y_col)) NULL else 0L,
      n_weighted = 0
    ))
  }

  T_hat <- sum(w * domain * y_safe)

  # Per-replicate domain totals
  rep_mat <- as.matrix(data[, vars$repweights, drop = FALSE])
  rep_Y   <- as.numeric((y_safe * domain) %*% rep_mat)

  n_rep <- ncol(rep_mat)
  v <- .svy_rep_var(
    rep_Y,
    scale   = vars$scale,
    rscales = if (!is.null(vars$rscales)) vars$rscales else rep(1L, n_rep),
    mse     = isTRUE(vars$mse),
    coef    = T_hat
  )

  se <- sqrt(max(0, v))

  # SRS-equivalent SE for deff
  y_domain <- y_safe[domain > 0]
  se_srs <- if (n_d >= 2L) {
    N_hat <- N_d
    ybar  <- T_hat / N_hat
    s2    <- sum((y_domain - ybar)^2) / (n_d - 1L)
    N_hat * sqrt(s2 / n_d)
  } else {
    0
  }

  list(
    total      = T_hat,
    se         = se,
    se_srs     = se_srs,
    n          = if (is.null(y_col)) NULL else n_d,
    n_weighted = N_d
  )
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

  idx   <- domain > 0
  n_d   <- as.integer(sum(idx))

  if (n_d == 0L) {
    return(list(
      mean = NA_real_, se = NA_real_, se_srs = NA_real_, n = 0L, n_weighted = 0
    ))
  }

  w_sub <- data[[vars$weights]][idx]
  y_sub <- data[[y_col]][idx]
  N_d   <- sum(w_sub)
  ybar  <- sum(w_sub * y_sub) / N_d

  if (n_d == 1L) {
    return(list(
      mean = ybar, se = NA_real_, se_srs = NA_real_, n = 1L, n_weighted = N_d
    ))
  }

  # FPC
  fpc_var  <- vars$fpc
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

  s2  <- sum((y_sub - ybar)^2) / (n_d - 1L)
  se  <- sqrt(max(0, (1 - f) * s2 / n_d))

  list(mean = ybar, se = se, se_srs = se, n = n_d, n_weighted = N_d)
}


# ── .srs_total_cell() ─────────────────────────────────────────────────────────
#
# Domain estimation of a weighted total for SRS designs.
#
# @param design  A survey_srs object.
# @param y_col   Character: variable name, OR NULL for population size.
# @param domain  Numeric 0/1 vector (full length).
# @return Named list: total, se, se_srs, n, n_weighted.
.srs_total_cell <- function(design, y_col, domain) {
  data <- design@data
  vars <- design@variables

  idx <- domain > 0
  n_d <- as.integer(sum(idx))

  if (n_d == 0L) {
    return(list(
      total = NA_real_, se = NA_real_, se_srs = NA_real_,
      n = if (is.null(y_col)) NULL else 0L,
      n_weighted = 0
    ))
  }

  w_sub <- data[[vars$weights]][idx]

  if (is.null(y_col)) {
    # Population size mode
    T_hat <- sum(w_sub)
    y_sub <- rep(1, n_d)
  } else {
    y_sub <- data[[y_col]][idx]
    T_hat <- sum(w_sub * y_sub)
  }

  N_d <- sum(w_sub)

  if (n_d == 1L) {
    return(list(
      total = T_hat, se = NA_real_, se_srs = NA_real_,
      n = if (is.null(y_col)) NULL else 1L,
      n_weighted = N_d
    ))
  }

  # FPC
  fpc_var  <- vars$fpc
  fpc_type <- vars$fpc_type
  f        <- 0
  N_hat    <- N_d

  if (!is.null(fpc_var)) {
    fpc_col <- data[[fpc_var]][idx]
    if (identical(fpc_type, "population")) {
      N_hat <- mean(fpc_col, na.rm = TRUE)
      f     <- n_d / N_hat
    } else {
      f <- mean(fpc_col, na.rm = TRUE)
    }
  }

  ybar <- T_hat / N_d
  s2   <- sum((y_sub - ybar)^2) / (n_d - 1L)

  var_T <- if (identical(fpc_type, "population")) {
    N_hat^2 * (1 - f) * s2 / n_d
  } else if (identical(fpc_type, "fraction")) {
    N_d^2 * (1 - f) * s2 / n_d
  } else {
    N_d^2 * s2 / n_d
  }

  se <- sqrt(max(0, var_T))

  list(
    total      = T_hat,
    se         = se,
    se_srs     = se,    # SRS: se_srs = se
    n          = if (is.null(y_col)) NULL else n_d,
    n_weighted = N_d
  )
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
  data     <- design@data
  ph1_vars <- design@variables$phase1
  subset   <- data[[design@variables$subset]]  # logical, full length

  w_full   <- data[[ph1_vars$weights]]
  pi2_full <- .compute_phase2_probs(design, subset)
  cal_wt   <- w_full / pi2_full

  # Restrict to Phase 2 rows
  dom_ph2   <- domain[subset]
  cal_ph2   <- cal_wt[subset]
  y_ph2     <- data[[y_col]][subset]

  n_d <- as.integer(sum(dom_ph2))
  N_d <- sum(cal_ph2 * dom_ph2)

  if (n_d == 0L || N_d <= 0) {
    return(list(
      mean = NA_real_, se = NA_real_, se_srs = NA_real_, n = 0L, n_weighted = 0
    ))
  }

  y_safe_ph2 <- ifelse(dom_ph2 > 0, y_ph2, 0)
  ybar       <- sum(cal_ph2 * dom_ph2 * y_safe_ph2) / N_d

  # Full-length influence vector (0 for Phase 1-only rows)
  n_total   <- nrow(data)
  influence <- numeric(n_total)
  ph2_idx   <- which(subset)
  influence[ph2_idx] <- cal_ph2 * dom_ph2 * (y_safe_ph2 - ybar) / N_d

  lonely.psu <- getOption("survey.lonely.psu", "remove")
  v_raw      <- .twophasevar(influence, design, lonely.psu)
  v_scalar   <- if (is.matrix(v_raw)) drop(v_raw)[1L] else as.numeric(v_raw)

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


# ── .twophase_total_cell() ────────────────────────────────────────────────────
#
# Domain estimation of a weighted total for two-phase designs.
#
# @param design  A survey_twophase object.
# @param y_col   Character: variable name, OR NULL for population size.
# @param domain  Numeric 0/1 vector (full length).
# @return Named list: total, se, se_srs, n, n_weighted.
.twophase_total_cell <- function(design, y_col, domain) {
  data     <- design@data
  ph1_vars <- design@variables$phase1
  subset   <- data[[design@variables$subset]]

  w_full   <- data[[ph1_vars$weights]]
  pi2_full <- .compute_phase2_probs(design, subset)
  cal_wt   <- w_full / pi2_full

  dom_ph2 <- domain[subset]
  cal_ph2 <- cal_wt[subset]

  if (is.null(y_col)) {
    y_ph2 <- rep(1, sum(subset))
  } else {
    y_ph2 <- data[[y_col]][subset]
  }

  n_d <- as.integer(sum(dom_ph2))
  N_d <- sum(cal_ph2 * dom_ph2)

  if (n_d == 0L || N_d <= 0) {
    return(list(
      total = NA_real_, se = NA_real_, se_srs = NA_real_,
      n = if (is.null(y_col)) NULL else 0L,
      n_weighted = 0
    ))
  }

  y_safe_ph2 <- ifelse(dom_ph2 > 0, y_ph2, 0)
  T_hat      <- sum(cal_ph2 * dom_ph2 * y_safe_ph2)

  # Full-length influence vector
  n_total   <- nrow(data)
  influence <- numeric(n_total)
  ph2_idx   <- which(subset)
  influence[ph2_idx] <- cal_ph2 * dom_ph2 * y_safe_ph2

  lonely.psu <- getOption("survey.lonely.psu", "remove")
  v_raw      <- .twophasevar(influence, design, lonely.psu)
  v_scalar   <- if (is.matrix(v_raw)) drop(v_raw)[1L] else as.numeric(v_raw)

  se <- sqrt(max(0, v_scalar))

  y_domain <- y_safe_ph2[dom_ph2 > 0]
  se_srs <- if (n_d >= 2L) {
    ybar <- T_hat / N_d
    s2   <- sum((y_domain - ybar)^2) / (n_d - 1L)
    N_d * sqrt(s2 / n_d)
  } else {
    0
  }

  list(
    total      = T_hat,
    se         = se,
    se_srs     = se_srs,
    n          = if (is.null(y_col)) NULL else n_d,
    n_weighted = N_d
  )
}


# ── .calibrated_mean_cell() ───────────────────────────────────────────────────
#
# Domain estimation of a weighted mean for calibrated (non-probability) designs.
# Uses the HT Taylor linearization variance (matching survey::svydesign(ids=~1)):
#   z_i = w_i * (y_i - ybar_w) / N_hat
#   Var(ybar_w) = n/(n-1) * sum(z_i^2)
#              = n/(n-1) * sum(w_i^2 * (y_i - ybar_w)^2) / N_hat^2
#
# @param design  A survey_calibrated object.
# @param y_col   Character: variable name.
# @param domain  Numeric 0/1 vector (full length).
# @return Named list: mean, se, se_srs, n, n_weighted.
.calibrated_mean_cell <- function(design, y_col, domain) {
  data <- design@data
  vars <- design@variables

  idx   <- domain > 0
  n_d   <- as.integer(sum(idx))

  if (n_d == 0L) {
    return(list(
      mean = NA_real_, se = NA_real_, se_srs = NA_real_, n = 0L, n_weighted = 0
    ))
  }

  w_sub <- data[[vars$weights]][idx]
  y_sub <- data[[y_col]][idx]
  N_d   <- sum(w_sub)
  ybar  <- sum(w_sub * y_sub) / N_d

  if (n_d == 1L) {
    return(list(
      mean = ybar, se = NA_real_, se_srs = NA_real_, n = 1L, n_weighted = N_d
    ))
  }

  # HT Taylor linearization: n/(n-1) * sum(z_i^2), z_i = w_i*(y_i-ybar)/N_hat
  var_ybar <- (n_d / (n_d - 1L)) * sum(w_sub^2 * (y_sub - ybar)^2) / N_d^2
  se       <- sqrt(max(0, var_ybar))

  # SRS-equivalent SE for deff
  se_srs <- if (n_d >= 2L) {
    s2 <- sum((y_sub - ybar)^2) / (n_d - 1L)
    sqrt(s2 / n_d)
  } else {
    0
  }

  list(mean = ybar, se = se, se_srs = se_srs, n = n_d, n_weighted = N_d)
}


# ── .calibrated_total_cell() ──────────────────────────────────────────────────
#
# Domain estimation of a weighted total for calibrated designs.
# Uses the HT variance of the total (matching survey::svydesign(ids=~1)):
#   z_i = w_i * y_i   (contribution to the total)
#   Var(T_hat) = n/(n-1) * sum((z_i - T_hat/n)^2)
#
#
# @param design  A survey_calibrated object.
# @param y_col   Character: variable name, OR NULL for population size.
# @param domain  Numeric 0/1 vector (full length).
# @return Named list: total, se, se_srs, n, n_weighted.
.calibrated_total_cell <- function(design, y_col, domain) {
  data <- design@data
  vars <- design@variables

  idx <- domain > 0
  n_d <- as.integer(sum(idx))

  if (n_d == 0L) {
    return(list(
      total = NA_real_, se = NA_real_, se_srs = NA_real_,
      n = if (is.null(y_col)) NULL else 0L,
      n_weighted = 0
    ))
  }

  w_sub <- data[[vars$weights]][idx]

  if (is.null(y_col)) {
    y_sub <- rep(1, n_d)
    T_hat <- sum(w_sub)
  } else {
    y_sub <- data[[y_col]][idx]
    T_hat <- sum(w_sub * y_sub)
  }

  N_d <- sum(w_sub)

  if (n_d == 1L) {
    return(list(
      total = T_hat, se = NA_real_, se_srs = NA_real_,
      n = if (is.null(y_col)) NULL else 1L,
      n_weighted = N_d
    ))
  }

  # HT variance of total: n/(n-1) * sum((z_i - T_hat/n)^2), z_i = w_i * y_i
  z_sub  <- w_sub * y_sub
  T_mean <- T_hat / n_d
  var_T  <- (n_d / (n_d - 1L)) * sum((z_sub - T_mean)^2)
  se     <- sqrt(max(0, var_T))

  # SRS-equivalent SE for deff (uses unweighted sample mean)
  se_srs <- if (n_d >= 2L) {
    s2 <- sum((y_sub - mean(y_sub))^2) / (n_d - 1L)
    N_d * sqrt(s2 / n_d)
  } else {
    0
  }

  list(
    total      = T_hat,
    se         = se,
    se_srs     = se_srs,
    n          = if (is.null(y_col)) NULL else n_d,
    n_weighted = N_d
  )
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
  } else if (S7::S7_inherits(design, survey_calibrated)) {
    .calibrated_mean_cell(design, y_col, domain)
  } else {
    cli::cli_abort(
      c(
        "x" = "Unsupported design class {.cls {class(design)[[1L]]}} in {.fn get_means}.",
        "i" = "Use {.fn as_survey}, {.fn as_survey_rep}, or {.fn as_survey_twophase}."
      ),
      class = "surveycore_error_unsupported_class"
    )
  }
}


# ── .total_cell() ─────────────────────────────────────────────────────────────
#
# Dispatch to the correct per-cell total estimator by design class.
#
# @param design  Any survey design object.
# @param y_col   Character: variable name, OR NULL for population size.
# @param domain  Numeric 0/1 vector (full length).
# @return Named list: total, se, se_srs, n, n_weighted.
.total_cell <- function(design, y_col, domain) {
  if (S7::S7_inherits(design, survey_taylor)) {
    .taylor_total_cell(design, y_col, domain)
  } else if (S7::S7_inherits(design, survey_replicate)) {
    .replicate_total_cell(design, y_col, domain)
  } else if (S7::S7_inherits(design, survey_twophase)) {
    .twophase_total_cell(design, y_col, domain)
  } else if (S7::S7_inherits(design, survey_srs)) {
    .srs_total_cell(design, y_col, domain)
  } else if (S7::S7_inherits(design, survey_calibrated)) {
    .calibrated_total_cell(design, y_col, domain)
  } else {
    cli::cli_abort(
      c(
        "x" = "Unsupported design class {.cls {class(design)[[1L]]}} in {.fn get_totals}.",
        "i" = "Use {.fn as_survey}, {.fn as_survey_rep}, or {.fn as_survey_twophase}."
      ),
      class = "surveycore_error_unsupported_class"
    )
  }
}


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


# ── get_totals() ──────────────────────────────────────────────────────────────

#' Weighted Total for a Survey Design
#'
#' Compute the estimated population total of a numeric variable in a survey
#' design, or the estimated population size when no variable is supplied.
#' Supports optional grouping, uncertainty quantification, and metadata-driven
#' labelling.
#'
#' @param design A survey design object: `survey_taylor`, `survey_replicate`,
#'   `survey_twophase`, `survey_srs`, or `survey_calibrated`.
#' @param x <[`tidy-select`][tidyselect::language]> Optional single unquoted
#'   numeric variable name. When `NULL` (default), estimates the population
#'   size (`Σ w_i`). When supplied, estimates the weighted sum (`Σ w_i × x_i`).
#' @param group <[`tidy-select`][tidyselect::language]> Optional grouping
#'   variable(s). Default `NULL`.
#' @param variance `NULL` or a character vector from `"se"`, `"ci"`, `"var"`,
#'   `"cv"`, `"moe"`, `"deff"`. Default `"ci"`.
#' @param conf_level Numeric scalar in (0, 1). Default `0.95`.
#' @param n_weighted Logical. For `get_totals(d)` (no variable), equals the
#'   `total` column and is included for API uniformity. For variable mode,
#'   adds the sum of weights for non-NA observations. Default `FALSE`.
#' @param min_cell_n Integer. Default `30L`.
#' @param na.rm Logical. If `TRUE` (default), `NA` values are excluded.
#' @param label_values Logical. Accepted for API uniformity. Default `TRUE`.
#' @param label_vars Logical. Accepted for API uniformity. Default `TRUE`.
#' @param name_style `"surveycore"` (default) or `"broom"`.
#'
#' @return A `survey_totals` tibble (also inheriting `survey_result`). Columns:
#' \itemize{
#'   \item `[group_cols...]` — group variable columns (when active), first.
#'   \item `total` — the weighted sum estimate.
#'   \item Variance columns — only those requested via `variance`.
#'   \item `n` — unweighted count (omitted in no-variable mode).
#'   \item `n_weighted` — sum of weights (only when requested).
#' }
#' The variable name (or `NULL` for no-variable mode) is in
#' `meta(result)$variable`. Use `meta(result)` for additional metadata.
#'
#' @examples
#' d <- as_survey_rep(acs_pums_wy, weights = pwgtp,
#'                    repweights = pwgtp1:pwgtp80,
#'                    type = "successive-difference")
#'
#' # Population size
#' get_totals(d)
#'
#' # Total for a variable
#' get_totals(d, agep)
#'
#' # Grouped
#' get_totals(d, agep, group = sex)
#'
#' @family analysis
#' @export
get_totals <- function(
  design,
  x            = NULL,
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
  .check_unsupported_class(design, "get_totals")
  .validate_shared_args(variance, conf_level, name_style)

  # ── Step 2: Resolve variable, groups, domain ─────────────────────────────────
  x_quo     <- rlang::enquo(x)
  group_quo <- rlang::enquo(group)

  no_variable <- rlang::quo_is_null(x_quo)

  if (no_variable) {
    x_name <- NULL
    x_col  <- NULL
  } else {
    x_names <- .resolve_tidy_select(x_quo, design@data)

    if (length(x_names) != 1L) {
      cli::cli_abort(
        c(
          "x" = "{.fn get_totals} requires exactly one variable.",
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
          "i" = "Column {.field {x_name}} cannot be used with {.fn get_totals}."
        ),
        class = "surveycore_error_non_numeric_variable"
      )
    }
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
  if (!no_variable) {
    var_label  <- design@metadata@variable_labels[[x_name]] %||%
      attr(design@data[[x_name]], "label", exact = TRUE)
    q_preface  <- design@metadata@question_prefaces[[x_name]]
    val_labels <- design@metadata@value_labels[[x_name]] %||%
      attr(design@data[[x_name]], "labels", exact = TRUE)
    val_labels_l <- list(val_labels)
    names(val_labels_l) <- x_name
  } else {
    var_label    <- NULL
    q_preface    <- NULL
    val_labels_l <- list(NULL)
    names(val_labels_l) <- "population"
  }

  # ── Step 6: Main accumulation loop ──────────────────────────────────────────
  acc_total <- numeric(0)
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
        group_match <- group_match & !is.na(gv_col) & (gv_col == cv)
      }
      active_mask <- domain_mask & group_match
    } else {
      active_mask <- domain_mask
    }

    if (no_variable) {
      # Population size: domain includes all in-mask rows (no NA filtering)
      domain <- as.numeric(active_mask)
    } else {
      domain <- .mean_domain_vec(active_mask, x_col, na.rm)
    }

    cell <- .total_cell(design, x_name, domain)

    if (!no_variable && !is.na(cell$n) && cell$n > 0L && cell$n < min_cell_n) {
      small_cell_ns <- c(small_cell_ns, cell$n)
    }

    acc_total <- c(acc_total, cell$total)
    acc_se    <- c(acc_se,    cell$se)
    acc_sesrs <- c(acc_sesrs, cell$se_srs)
    acc_nw    <- c(acc_nw,    cell$n_weighted)

    if (!no_variable) {
      acc_n <- c(acc_n, cell$n)
    }

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
    estimate_vec = acc_total,
    se_srs_vec   = acc_sesrs,
    conf_level   = conf_level,
    degf         = degf,
    variance     = variance
  )

  col_vecs        <- list()
  col_vecs$total  <- acc_total
  col_vecs        <- c(col_vecs, var_cols)

  if (!no_variable) {
    col_vecs$n <- acc_n
  }

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
    "survey_totals",
    design,
    meta_args,
    TOTALS_META_KEYS
  )

  # ── Step 12: Apply name style ─────────────────────────────────────────────────
  .apply_name_style(result, name_style)
}
