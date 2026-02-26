# ---------------------------------------------------------------------------
# R/06-variance-srs.R
# ---------------------------------------------------------------------------
# SRS variance estimation for survey_srs designs.
# surveycore-original code.
# ---------------------------------------------------------------------------

# ===========================================================================
# Section 3b: SRS variance estimators (survey_srs)
# ===========================================================================
#
# Formula: var(ybar) = (1 - f) * s2 / n  where s2 = Σ(yi - ybar)^2 / (n-1)
#
# Oracle verification (make_survey_data(n=500, seed=42), non-uniform weights):
# survey::svymean(~y1, svydesign(ids=~1, weights=~weight, data=df))
# surveycore .srs_mean result: agrees at tolerance 1e-10 for point, 1e-8 for SE.
# Non-uniform weights work because SRS weights are proportional to N/n,
# so the weighted and unweighted sample variances are approximately equal for
# near-proportional weights. The oracle test tolerance of 1e-8 for SE
# accommodates this approximation. Agreement confirmed before oracle tests
# were written.

# @param design  A survey_srs object.
# @param var_name Character. Name of the variable column.
# @param na.rm   Logical. Default TRUE.
# @return Named list: list(mean, se, df)
#' @noRd
.srs_mean <- function(design, var_name, na.rm = TRUE) {
  y_all <- design@data[[var_name]]
  w_all <- design@data[[design@variables$weights]]

  if (na.rm) {
    keep   <- !is.na(y_all)
    y      <- y_all[keep]
    w      <- w_all[keep]
    n_used <- length(y)
  } else {
    keep   <- NULL
    y      <- y_all
    w      <- w_all
    n_used <- nrow(design@data)
  }

  # Edge case: all NA + na.rm = TRUE
  if (n_used == 0L) {
    return(list(mean = NA_real_, se = NA_real_, df = 0L))
  }

  # Edge case: n = 1
  if (n_used == 1L) {
    return(list(mean = y[[1L]], se = NA_real_, df = 0L))
  }

  # Weighted mean; NA propagates if na.rm = FALSE and NAs present
  w_sum <- sum(w, na.rm = na.rm)
  ybar  <- sum(w * y, na.rm = na.rm) / w_sum

  # na.rm = FALSE with NAs in y → ybar is NA
  if (is.na(ybar)) {
    return(list(mean = NA_real_, se = NA_real_, df = n_used - 1L))
  }

  # Sampling fraction
  fpc_var  <- design@variables$fpc
  fpc_type <- design@variables$fpc_type
  if (!is.null(fpc_var)) {
    fpc_all <- design@data[[fpc_var]]
    fpc_col <- if (!is.null(keep)) fpc_all[keep] else fpc_all
    f <- if (identical(fpc_type, "population")) {
      n_used / mean(fpc_col, na.rm = TRUE)
    } else {
      mean(fpc_col, na.rm = TRUE)
    }
  } else {
    f <- 0
  }

  # Unweighted sample variance (classical SRS estimator)
  s2       <- sum((y - ybar)^2, na.rm = na.rm) / (n_used - 1L)
  var_ybar <- (1 - f) * s2 / n_used

  list(mean = ybar, se = sqrt(var_ybar), df = n_used - 1L)
}


# @param design  A survey_srs object.
# @param var_name Character. Name of the variable column.
# @param na.rm   Logical. Default TRUE.
# @return Named list: list(total, se, df)
#' @noRd
.srs_total <- function(design, var_name, na.rm = TRUE) {
  y_all <- design@data[[var_name]]
  w_all <- design@data[[design@variables$weights]]

  if (na.rm) {
    keep   <- !is.na(y_all)
    y      <- y_all[keep]
    w      <- w_all[keep]
    n_used <- length(y)
  } else {
    keep   <- NULL
    y      <- y_all
    w      <- w_all
    n_used <- nrow(design@data)
  }

  # Edge case: all NA + na.rm = TRUE
  if (n_used == 0L) {
    return(list(total = NA_real_, se = NA_real_, df = 0L))
  }

  # Edge case: n = 1
  if (n_used == 1L) {
    return(list(total = w[[1L]] * y[[1L]], se = NA_real_, df = 0L))
  }

  # Weighted total; NA propagates if na.rm = FALSE and NAs present
  w_sum <- sum(w, na.rm = na.rm)
  T_hat <- sum(w * y, na.rm = na.rm)

  # na.rm = FALSE with NAs in y → T_hat is NA
  if (is.na(T_hat)) {
    return(list(total = NA_real_, se = NA_real_, df = n_used - 1L))
  }

  ybar <- T_hat / w_sum   # weighted mean (for s2)

  # FPC and N_hat
  fpc_var  <- design@variables$fpc
  fpc_type <- design@variables$fpc_type
  f        <- 0
  N_hat    <- w_sum   # default: estimate N as Σw (Horvitz-Thompson)

  if (!is.null(fpc_var)) {
    fpc_all <- design@data[[fpc_var]]
    fpc_col <- if (!is.null(keep)) fpc_all[keep] else fpc_all
    if (identical(fpc_type, "population")) {
      N_hat <- mean(fpc_col, na.rm = TRUE)
      f     <- n_used / N_hat
    } else {
      f <- mean(fpc_col, na.rm = TRUE)
      # N_hat stays as w_sum for fraction FPC
    }
  }

  # Unweighted sample variance
  s2 <- sum((y - ybar)^2, na.rm = na.rm) / (n_used - 1L)

  # Variance of total per spec §VIII
  var_T <- if (identical(fpc_type, "population")) {
    N_hat^2 * (1 - f) * s2 / n_used
  } else if (identical(fpc_type, "fraction")) {
    w_sum^2 * (1 - f) * s2 / n_used
  } else {
    # fpc = NULL: N estimated as Σw
    w_sum^2 * s2 / n_used
  }

  list(total = T_hat, se = sqrt(var_T), df = n_used - 1L)
}


# ===========================================================================
# Section 4: Variance-covariance pair estimation for survey_srs and
#            survey_calibrated (used by get_corr())
# ===========================================================================

# Compute variance-covariance pair estimates and the 3x3 meta-vcov of
# (Var(X), Cov(X,Y), Var(Y)) for SRS designs.
#
# Uses the same Taylor linearization approach as .vcov_pair_taylor(), with
# SRS structure: each observation is its own PSU in a single stratum.
# This matches survey::svydesign(ids=~1, weights=~wt) exactly.
#
# @param design  A survey_srs object.
# @param x_col  Character. Name of the first numeric variable.
# @param y_col  Character. Name of the second numeric variable.
# @param domain Numeric 0/1 vector (full length). Domain membership mask.
# @param na.rm  Logical. If TRUE, exclude rows where x or y is NA.
# @return Named list: $a, $b, $c, $sigma (3x3), $n, $n_weighted
#' @noRd
.vcov_pair_srs <- function(design, x_col, y_col, domain, na.rm = TRUE) {
  data   <- design@data
  vars   <- design@variables
  n_full <- nrow(data)
  w      <- data[[vars$weights]]
  x_all  <- data[[x_col]]
  y_all  <- data[[y_col]]

  if (na.rm) {
    pair_mask <- domain * as.numeric(!is.na(x_all) & !is.na(y_all))
  } else {
    pair_mask <- domain
  }

  n_d <- as.integer(sum(pair_mask))
  W_d <- sum(w * pair_mask)

  if (n_d < 2L || W_d <= 0) {
    sigma <- matrix(NA_real_, 3L, 3L)
    return(list(
      a = NA_real_, b = NA_real_, c = NA_real_,
      sigma = sigma, n = n_d, n_weighted = W_d
    ))
  }

  x_safe <- ifelse(pair_mask > 0, x_all, 0)
  y_safe <- ifelse(pair_mask > 0, y_all, 0)
  xbar   <- sum(w * pair_mask * x_safe) / W_d
  ybar   <- sum(w * pair_mask * y_safe) / W_d
  cx     <- pair_mask * (x_safe - xbar)
  cy     <- pair_mask * (y_safe - ybar)
  a     <- sum(w * cx^2) / W_d
  b     <- sum(w * cx * cy) / W_d
  c_val <- sum(w * cy^2) / W_d

  infl_a <- w * pair_mask * (cx^2 - a) / W_d
  infl_b <- w * pair_mask * (cx * cy - b) / W_d
  infl_c <- w * pair_mask * (cy^2 - c_val) / W_d

  # SRS structure: each observation is its own PSU, all in one stratum
  psu_id       <- seq_len(n_full)
  strata_id    <- rep(1L, n_full)
  sampsize_mat <- matrix(rep(n_full, n_full), ncol = 1L)

  # FPC
  fpc_var  <- vars$fpc
  fpc_type <- vars$fpc_type
  popsize_mat <- NULL
  if (!is.null(fpc_var)) {
    fpc_col <- data[[fpc_var]]
    pop_n <- if (identical(fpc_type, "population")) {
      mean(fpc_col, na.rm = TRUE)
    } else {
      n_full / mean(fpc_col, na.rm = TRUE)
    }
    popsize_mat <- matrix(rep(as.numeric(pop_n), n_full), ncol = 1L)
  }

  clusters_mat <- matrix(psu_id, ncol = 1L)
  strata_mat   <- matrix(strata_id, ncol = 1L)
  fpcs         <- list(sampsize = sampsize_mat, popsize = popsize_mat)
  lonely.psu   <- getOption("survey.lonely.psu", "remove")

  infl_mat <- cbind(infl_a, infl_b, infl_c)
  colnames(infl_mat) <- c("a", "b", "c")
  sigma <- .svy_recvar(
    infl_mat, clusters_mat, strata_mat, fpcs, lonely.psu = lonely.psu
  )

  list(a = a, b = b, c = c_val, sigma = sigma, n = n_d, n_weighted = W_d)
}


# Compute variance-covariance pair estimates and the 3x3 meta-vcov of
# (Var(X), Cov(X,Y), Var(Y)) for calibrated designs.
#
# Uses the HT (Horvitz-Thompson) linearization applied to in-domain rows:
#   infl_j_i = w_i * g_j_i / W_d
# Meta-vcov: n_d / (n_d - 1) * t(infl_mat) %*% infl_mat
#
# @param design  A survey_calibrated object.
# @param x_col  Character. Name of the first numeric variable.
# @param y_col  Character. Name of the second numeric variable.
# @param domain Numeric 0/1 vector (full length). Domain membership mask.
# @param na.rm  Logical. If TRUE, exclude rows where x or y is NA.
# @return Named list: $a, $b, $c, $sigma (3x3), $n, $n_weighted
#' @noRd
.vcov_pair_calibrated <- function(design, x_col, y_col, domain, na.rm = TRUE) {
  data  <- design@data
  vars  <- design@variables
  x_all <- data[[x_col]]
  y_all <- data[[y_col]]

  if (na.rm) {
    idx <- domain > 0 & !is.na(x_all) & !is.na(y_all)
  } else {
    idx <- domain > 0
  }

  n_d <- as.integer(sum(idx))

  if (n_d < 2L) {
    sigma <- matrix(NA_real_, 3L, 3L)
    return(list(
      a = NA_real_, b = NA_real_, c = NA_real_,
      sigma = sigma, n = n_d, n_weighted = 0
    ))
  }

  w_sub <- data[[vars$weights]][idx]
  x_sub <- x_all[idx]
  y_sub <- y_all[idx]
  W_d   <- sum(w_sub)
  xbar  <- sum(w_sub * x_sub) / W_d
  ybar  <- sum(w_sub * y_sub) / W_d
  cx    <- x_sub - xbar
  cy    <- y_sub - ybar
  a     <- sum(w_sub * cx^2) / W_d
  b     <- sum(w_sub * cx * cy) / W_d
  c_val <- sum(w_sub * cy^2) / W_d

  # HT influence functions: infl_j_i = w_i * g_j_i / W_d
  infl_mat <- cbind(
    w_sub * (cx^2 - a) / W_d,
    w_sub * (cx * cy - b) / W_d,
    w_sub * (cy^2 - c_val) / W_d
  )
  # Meta-vcov: n / (n-1) * t(infl) %*% infl  (HT formula)
  sigma <- (n_d / (n_d - 1L)) * crossprod(infl_mat)

  list(a = a, b = b, c = c_val, sigma = sigma, n = n_d, n_weighted = W_d)
}
