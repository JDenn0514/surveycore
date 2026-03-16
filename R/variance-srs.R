# ---------------------------------------------------------------------------
# R/06-variance-srs.R
# ---------------------------------------------------------------------------
# SRS variance estimation for survey_srs designs.
# surveycore-original code.
#
# Variance is computed via the same Taylor (HT) linearization used by
# survey::svydesign(ids = ~1): each row is its own PSU in a single stratum.
# .build_cluster_matrices() handles this automatically when ids = NULL and
# strata = NULL. This approach is correct for ANY weight structure, including
# non-proportional weights from post-stratification adjustments.
# ---------------------------------------------------------------------------

# ===========================================================================
# Section 3b: SRS variance estimators (survey_srs)
# ===========================================================================

# @param design  A survey_srs object.
# @param var_name Character. Name of the variable column.
# @param na.rm   Logical. Default TRUE.
# @return Named list: list(mean, se, df)
#' @noRd
.srs_mean <- function(design, var_name, na.rm = TRUE) {
  data <- design@data
  vars <- design@variables
  y_all <- data[[var_name]]
  w_all <- data[[vars$weights]]

  if (na.rm) {
    keep   <- !is.na(y_all)
    y      <- y_all[keep]
    w      <- w_all[keep]
    n_used <- length(y)
  } else {
    keep   <- NULL
    y      <- y_all
    w      <- w_all
    n_used <- nrow(data)
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

  # na.rm = FALSE with NAs in y -> ybar is NA
  if (is.na(ybar)) {
    return(list(mean = NA_real_, se = NA_real_, df = n_used - 1L))
  }

  # Taylor linearization via .build_cluster_matrices() + .svy_recvar()
  # For SRS: ids = NULL, strata = NULL -> each row is its own PSU, k = 1
  mats <- .build_cluster_matrices(data, vars)
  lonely.psu <- getOption("survey.lonely.psu", "remove")

  x_mat <- matrix(y, ncol = 1L, dimnames = list(NULL, var_name))
  x_centered <- sweep(x_mat, 2L, ybar)

  # Subset cluster/strata/FPC matrices to non-NA rows
  if (!is.null(keep)) {
    clusters <- mats$clusters_mat[keep, , drop = FALSE]
    stratas  <- mats$strata_mat[keep, , drop = FALSE]
    fpcs <- list(
      sampsize = mats$fpcs$sampsize[keep, , drop = FALSE],
      popsize = if (!is.null(mats$fpcs$popsize)) {
        mats$fpcs$popsize[keep, , drop = FALSE]
      }
    )
  } else {
    clusters <- mats$clusters_mat
    stratas  <- mats$strata_mat
    fpcs     <- mats$fpcs
  }

  v <- .svy_recvar(
    x_centered * w / w_sum,
    clusters, stratas, fpcs,
    lonely.psu = lonely.psu
  )

  list(mean = ybar, se = sqrt(v[[1L, 1L]]), df = n_used - 1L)
}


# @param design  A survey_srs object.
# @param var_name Character. Name of the variable column.
# @param na.rm   Logical. Default TRUE.
# @return Named list: list(total, se, df)
#' @noRd
.srs_total <- function(design, var_name, na.rm = TRUE) {
  data <- design@data
  vars <- design@variables
  y_all <- data[[var_name]]
  w_all <- data[[vars$weights]]

  if (na.rm) {
    keep   <- !is.na(y_all)
    y      <- y_all[keep]
    w      <- w_all[keep]
    n_used <- length(y)
  } else {
    keep   <- NULL
    y      <- y_all
    w      <- w_all
    n_used <- nrow(data)
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
  T_hat <- sum(w * y, na.rm = na.rm)

  # na.rm = FALSE with NAs in y -> T_hat is NA
  if (is.na(T_hat)) {
    return(list(total = NA_real_, se = NA_real_, df = n_used - 1L))
  }

  # Taylor linearization via .build_cluster_matrices() + .svy_recvar()
  # For totals, the influence function is simply w_i * y_i (no centering)
  mats <- .build_cluster_matrices(data, vars)
  lonely.psu <- getOption("survey.lonely.psu", "remove")

  x_mat <- matrix(y, ncol = 1L, dimnames = list(NULL, var_name))

  # Subset cluster/strata/FPC matrices to non-NA rows
  if (!is.null(keep)) {
    clusters <- mats$clusters_mat[keep, , drop = FALSE]
    stratas  <- mats$strata_mat[keep, , drop = FALSE]
    fpcs <- list(
      sampsize = mats$fpcs$sampsize[keep, , drop = FALSE],
      popsize = if (!is.null(mats$fpcs$popsize)) {
        mats$fpcs$popsize[keep, , drop = FALSE]
      }
    )
  } else {
    clusters <- mats$clusters_mat
    stratas  <- mats$strata_mat
    fpcs     <- mats$fpcs
  }

  v <- .svy_recvar(
    x_mat * w,
    clusters, stratas, fpcs,
    lonely.psu = lonely.psu
  )

  list(total = T_hat, se = sqrt(v[[1L, 1L]]), df = n_used - 1L)
}


# ===========================================================================
# Section 4: Variance-covariance pair estimation for survey_srs and
#            survey_nonprob (used by get_corr())
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

  # Build cluster/strata/FPC matrices via shared helper.
  # SRS vars have ids = NULL, strata = NULL → k = 1, each row is its own PSU.
  mats <- .build_cluster_matrices(data, vars)
  clusters_mat <- mats$clusters_mat
  strata_mat   <- mats$strata_mat
  fpcs         <- mats$fpcs
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
# @param design  A survey_nonprob object.
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
