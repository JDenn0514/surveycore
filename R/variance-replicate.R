# ---------------------------------------------------------------------------
# R/variance-replicate.R
# ---------------------------------------------------------------------------
# Replicate-weight variance estimation for survey_replicate designs.
#
# ATTRIBUTION — VENDORED CODE:
# The function .svy_rep_var() is adapted from the survey package by Thomas
# Lumley (https://cran.r-project.org/package=survey), licensed under
# GPL-2 | GPL-3.
# Modifications: integrated with S7 classes; error messages converted to
# cli format; NA replicate handling made explicit.
# ---------------------------------------------------------------------------

# ===========================================================================
# Section 3b: Replicate weight variance computation
# (adapted from survey package, Thomas Lumley, GPL-2/GPL-3)
# ===========================================================================

# Variance of replicate statistics.
# Adapted from survey:::svrVar.
# thetas: numeric vector of per-replicate estimates.
# scale, rscales: variance scale factors from the design.
# mse: TRUE = compare to full-sample estimate (coef); FALSE = compare to
#      mean of replicates.
# coef: the full-sample estimate (used only when mse = TRUE).
.svy_rep_var <- function(thetas, scale, rscales, mse = TRUE, coef = NULL) {
  # Drop NA replicates
  ok <- !is.na(thetas)
  if (!any(ok)) {
    cli::cli_abort(
      c("x" = "All replicates produced NA estimates."),
      class = "surveycore_error_all_replicates_na"
    )
  }
  if (any(!ok)) {
    rscales <- rscales[ok]
    thetas <- thetas[ok]
  }

  if (isTRUE(mse)) {
    meantheta <- coef
  } else {
    meantheta <- mean(thetas[rscales > 0])
  }

  sum((thetas - meantheta)^2 * rscales) * scale
}

# Matrix form of .svy_rep_var(): the k x k covariance of k statistics from
# their R x k matrix of per-replicate estimates,
#   sigma[j, l] = scale * sum_r(rscales_r * dev_r[j] * dev_r[l]).
# An NA replicate estimate drops that replicate from its own column only, so
# entry [j, l] sums over the replicates where both columns are non-NA and the
# diagonal equals .svy_rep_var() on each column. mse = FALSE centres each
# column on the mean of its non-NA replicates with rscales > 0, as
# .svy_rep_var() does.
#
# thetas: R x k numeric matrix of per-replicate estimates (may hold NA).
# coef:   numeric(k) full-sample estimates (used only when mse = TRUE).
.svy_rep_vcov <- function(thetas, scale, rscales, mse = TRUE, coef = NULL) {
  ok <- !is.na(thetas)
  if (isTRUE(mse)) {
    center <- coef
  } else {
    center <- vapply(
      seq_len(ncol(thetas)),
      function(j) mean(thetas[ok[, j] & rscales > 0, j]),
      numeric(1L)
    )
  }
  diff_mat <- sweep(thetas, 2L, center, "-")
  diff_mat[!ok] <- 0
  t(diff_mat * rscales) %*% diff_mat * scale
}

# Shared scaffolding for replicate-weight variance estimation.
#
# Replicate weights are full survey weights (surveycore always uses the
# combined.weights = TRUE mode): replicate mean is sum(repwt * y) / sum(repwt).
# The base weights are used only for the full-sample statistic denominator.
#
# @param design       A survey_replicate object.
# @param y_col        Character(1). Name of the response column.
# @param na.rm        Logical. Exclude NA y values before estimation?
# @param full_stat_fn function(y, w) → scalar. Full-sample statistic.
# @param rep_stat_fn  function(y, rep_mat) → numeric(n_rep). Per-replicate
#                     statistics, vectorised over the replicate weight matrix
#                     using BLAS matrix operations.
# @return list(stat, var, se) where stat is the full-sample estimate.
.replicate_estimate <- function(
  design,
  y_col,
  na.rm,
  full_stat_fn,
  rep_stat_fn
) {
  data <- design@data
  vars <- design@variables

  y <- data[[y_col]]
  w <- data[[vars$weights]] # base/full-sample weights

  if (na.rm) {
    keep <- !is.na(y)
    y <- y[keep]
    w <- w[keep]
    rep_mat <- as.matrix(data[keep, vars$repweights, drop = FALSE])
  } else {
    rep_mat <- as.matrix(data[, vars$repweights, drop = FALSE])
  }

  n_rep <- ncol(rep_mat)
  full_est <- full_stat_fn(y, w)
  rep_ests <- rep_stat_fn(y, rep_mat) # vectorised; see callers below

  v <- .svy_rep_var(
    rep_ests,
    scale = vars$scale,
    rscales = if (!is.null(vars$rscales)) vars$rscales else rep(1L, n_rep),
    mse = isTRUE(vars$mse),
    coef = full_est
  )

  list(stat = full_est, var = v, se = sqrt(v))
}

# Compute weighted mean and its variance for a survey_replicate design.
# Returns list(mean, var, se).
.replicate_mean <- function(design, y_col, na.rm = TRUE) {
  res <- .replicate_estimate(
    design,
    y_col,
    na.rm,
    full_stat_fn = function(y, w) sum(y * w) / sum(w),
    # BLAS matrix multiply: (y %*% rep_mat) gives row sums, colSums(rep_mat)
    # gives column (replicate) weight sums. Both are O(N*R) with BLAS.
    rep_stat_fn = function(y, rep_mat) {
      as.numeric(y %*% rep_mat) / colSums(rep_mat)
    }
  )
  list(mean = res$stat, var = res$var, se = res$se)
}

# Compute weighted total and its variance for a survey_replicate design.
# Returns list(total, var, se).
.replicate_total <- function(design, y_col, na.rm = TRUE) {
  res <- .replicate_estimate(
    design,
    y_col,
    na.rm,
    full_stat_fn = function(y, w) sum(y * w),
    # BLAS matrix multiply: (y %*% rep_mat) gives per-replicate weighted totals.
    rep_stat_fn = function(y, rep_mat) as.numeric(y %*% rep_mat)
  )
  list(total = res$stat, var = res$var, se = res$se)
}


# ===========================================================================
# Section 4: Variance-covariance pair estimation for survey_replicate
# (used by get_corr())
# ===========================================================================

# Compute variance-covariance pair estimates and the 3x3 meta-vcov of
# (Var(X), Cov(X,Y), Var(Y)) using replicate weights.
#
# For each replicate, the full-sample variance-covariance estimators are
# recomputed using replicate weights, then .svy_rep_var() is generalised to
# the matrix case: sigma[j,k] = scale * sum_r(rscales_r * dev_r[j] * dev_r[k]).
#
# @param design  A survey_replicate object.
# @param x_col  Character. Name of the first numeric variable.
# @param y_col  Character. Name of the second numeric variable.
# @param domain Numeric 0/1 vector (full length). Domain membership mask.
# @param na.rm  Logical. If TRUE, exclude rows where x or y is NA.
# @return Named list: $a, $b, $c, $sigma (3x3), $n, $n_weighted
.vcov_pair_replicate <- function(design, x_col, y_col, domain, na.rm = TRUE) {
  data <- design@data
  vars <- design@variables
  x_all <- data[[x_col]]
  y_all <- data[[y_col]]
  w <- data[[vars$weights]] # base/full-sample weights

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
      a = NA_real_,
      b = NA_real_,
      c = NA_real_,
      sigma = sigma,
      n = n_d,
      n_weighted = W_d
    ))
  }

  x_safe <- ifelse(pair_mask > 0, x_all, 0)
  y_safe <- ifelse(pair_mask > 0, y_all, 0)

  # Full-sample variance-covariance estimates
  xbar <- sum(w * pair_mask * x_safe) / W_d
  ybar <- sum(w * pair_mask * y_safe) / W_d
  cx <- pair_mask * (x_safe - xbar)
  cy <- pair_mask * (y_safe - ybar)
  a <- sum(w * cx^2) / W_d
  b <- sum(w * cx * cy) / W_d
  c_val <- sum(w * cy^2) / W_d

  # Per-replicate estimates of (Var(X), Cov(X,Y), Var(Y))
  rep_mat <- as.matrix(data[, vars$repweights, drop = FALSE])
  n_rep <- ncol(rep_mat)

  rep_abc <- matrix(NA_real_, nrow = n_rep, ncol = 3L)
  for (r in seq_len(n_rep)) {
    wr <- rep_mat[, r]
    W_r <- sum(wr * pair_mask)
    if (W_r <= 0) {
      next
    }
    xbar_r <- sum(wr * pair_mask * x_safe) / W_r
    ybar_r <- sum(wr * pair_mask * y_safe) / W_r
    cx_r <- pair_mask * (x_safe - xbar_r)
    cy_r <- pair_mask * (y_safe - ybar_r)
    rep_abc[r, 1L] <- sum(wr * cx_r^2) / W_r
    rep_abc[r, 2L] <- sum(wr * cx_r * cy_r) / W_r
    rep_abc[r, 3L] <- sum(wr * cy_r^2) / W_r
  }

  rscales <- if (!is.null(vars$rscales)) vars$rscales else rep(1L, n_rep)
  scale <- vars$scale
  mse <- isTRUE(vars$mse)
  coef <- c(a, b, c_val)

  # 3x3 meta-vcov: sigma[j,k] = scale * sum_r(rscales_r * dev_r[j] * dev_r[k])
  ok <- apply(rep_abc, 1L, function(row) !any(is.na(row)))
  na_dropped_abc <- sum(!ok)
  na_frac_abc <- na_dropped_abc / n_rep
  if (
    isTRUE(
      .nonprob_rep_na_warn(
        design,
        na_frac_abc,
        na_dropped_abc,
        n_rep,
        scale
      )
    )
  ) {
    sigma <- matrix(NA_real_, 3L, 3L)
    return(list(
      a = a,
      b = b,
      c = c_val,
      sigma = sigma,
      n = n_d,
      n_weighted = W_d
    ))
  }
  if (!any(ok)) {
    sigma <- matrix(NA_real_, 3L, 3L)
    return(list(
      a = a,
      b = b,
      c = c_val,
      sigma = sigma,
      n = n_d,
      n_weighted = W_d
    ))
  }
  if (any(!ok)) {
    rscales <- rscales[ok]
    rep_abc <- rep_abc[ok, , drop = FALSE]
  }

  sigma <- .svy_rep_vcov(rep_abc, scale, rscales, mse = mse, coef = coef)

  list(a = a, b = b, c = c_val, sigma = sigma, n = n_d, n_weighted = W_d)
}
