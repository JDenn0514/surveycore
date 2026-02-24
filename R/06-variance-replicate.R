# ---------------------------------------------------------------------------
# R/06-variance-replicate.R
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
  ok  <- !is.na(thetas)
  if (!any(ok)) cli::cli_abort(
    c("x" = "All replicates produced NA estimates."),
    class = "surveycore_error_all_replicates_na"
  )
  if (any(!ok)) {
    rscales <- rscales[ok]
    thetas  <- thetas[ok]
  }

  if (isTRUE(mse)) {
    meantheta <- coef
  } else {
    meantheta <- mean(thetas[rscales > 0])
  }

  sum((thetas - meantheta)^2 * rscales) * scale
}

# Shared scaffolding for replicate-weight variance estimation.
#
# Survey package default (combined.weights = TRUE): replicate weights are
# full survey weights, so the replicate mean is sum(repwt * y) / sum(repwt).
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
#' @noRd
.replicate_estimate <- function(design, y_col, na.rm, full_stat_fn, rep_stat_fn) {
  data <- design@data
  vars <- design@variables

  y <- data[[y_col]]
  w <- data[[vars$weights]]    # base/full-sample weights

  if (na.rm) {
    keep    <- !is.na(y)
    y       <- y[keep]
    w       <- w[keep]
    rep_mat <- as.matrix(data[keep, vars$repweights, drop = FALSE])
  } else {
    rep_mat <- as.matrix(data[, vars$repweights, drop = FALSE])
  }

  n_rep    <- ncol(rep_mat)
  full_est <- full_stat_fn(y, w)
  rep_ests <- rep_stat_fn(y, rep_mat)   # vectorised; see callers below

  v <- .svy_rep_var(
    rep_ests,
    scale   = vars$scale,
    rscales = if (!is.null(vars$rscales)) vars$rscales else rep(1L, n_rep),
    mse     = isTRUE(vars$mse),
    coef    = full_est
  )

  list(stat = full_est, var = v, se = sqrt(v))
}

# Compute weighted mean and its variance for a survey_replicate design.
# Returns list(mean, var, se).
.replicate_mean <- function(design, y_col, na.rm = TRUE) {
  res <- .replicate_estimate(
    design, y_col, na.rm,
    full_stat_fn = function(y, w) sum(y * w) / sum(w),
    # BLAS matrix multiply: (y %*% rep_mat) gives row sums, colSums(rep_mat)
    # gives column (replicate) weight sums. Both are O(N*R) with BLAS.
    rep_stat_fn  = function(y, rep_mat) {
      as.numeric(y %*% rep_mat) / colSums(rep_mat)
    }
  )
  list(mean = res$stat, var = res$var, se = res$se)
}

# Compute weighted total and its variance for a survey_replicate design.
# Returns list(total, var, se).
.replicate_total <- function(design, y_col, na.rm = TRUE) {
  res <- .replicate_estimate(
    design, y_col, na.rm,
    full_stat_fn = function(y, w) sum(y * w),
    # BLAS matrix multiply: (y %*% rep_mat) gives per-replicate weighted totals.
    rep_stat_fn  = function(y, rep_mat) as.numeric(y %*% rep_mat)
  )
  list(total = res$stat, var = res$var, se = res$se)
}
