# R/analysis-variance-helpers.R
#
# Internal helpers for get_variance().
#
# Functions:
#   .score_variance()         — build the score z_i = a_i * (y_i - ybar)^2 * n/(n-1)
#   .taylor_variance_cell()   — Taylor domain-estimation variance of variance
#   .replicate_variance_cell() — replicate-weight domain variance
#   .variance_cell()          — dispatcher

# ── .score_variance() ─────────────────────────────────────────────────────────
#
# Build the score vector z_i used by get_variance():
#     z_i = a_i * (y_i - ybar_d)^2 * n_d / (n_d - 1)
# where ybar_d and n_d are computed on the in-domain, non-NA-in-y, positive-
# weight subset.
#
# Out-of-domain / NA / non-positive-weight rows contribute z_i = 0. Returns
# the score vector along with the plug-in point estimate and sufficient
# statistics the dispatch branches need.
#
# @param y_col    Numeric vector of the focal variable (full length).
# @param w        Numeric vector of weights (full length).
# @param domain   Numeric 0/1 vector of "active" membership (full length).
# @return Named list:
#   score     — numeric(n_full): z_i with 0 on inactive rows.
#   v_hat     — plug-in variance estimate (scalar).
#   ybar      — plug-in domain mean of y (scalar, NaN if n_d = 0).
#   W         — sum(w * a) domain weight total (scalar).
#   n_d       — integer unweighted count of active rows.
#   active    — logical(n_full): TRUE for in-domain, non-NA-y, w > 0 rows.
#
# Notes:
#   - When n_d = 0L or W <= 0, returns v_hat = NaN, ybar = NaN, score all-zero.
#   - When n_d = 1L, n/(n-1) = Inf and (y - ybar)^2 = 0, so score contains NaN
#     (from 0 * Inf); v_hat = NaN. Caller is responsible for the
#     insufficient-n warning.
.score_variance <- function(y_col, w, domain) {
  n_full <- length(y_col)
  active <- (domain > 0) & !is.na(y_col) & (w > 0)
  n_d <- as.integer(sum(active))
  score <- numeric(n_full)

  if (n_d == 0L) {
    return(list(
      score = score,
      v_hat = NaN,
      ybar = NaN,
      W = 0,
      n_d = 0L,
      active = active
    ))
  }

  W <- sum(w[active])
  if (W <= 0) {
    return(list(
      score = score,
      v_hat = NaN,
      ybar = NaN,
      W = 0,
      n_d = n_d,
      active = active
    ))
  }

  ybar <- sum(w[active] * y_col[active]) / W

  if (n_d < 2L) {
    # n/(n-1) is undefined; point estimate is NaN, score is NaN for active
    # rows (caller emits surveycore_warning_variance_insufficient_n).
    score[active] <- NaN
    return(list(
      score = score,
      v_hat = NaN,
      ybar = ybar,
      W = W,
      n_d = n_d,
      active = active
    ))
  }

  kish <- n_d / (n_d - 1L)
  sq_dev <- (y_col[active] - ybar)^2
  # Snap squared deviations to exact 0 when they are numerically
  # indistinguishable from 0 (arises with constant variables where the
  # weighted mean has trailing floating-point noise).
  scale_sq <- (abs(ybar) + 1)^2
  sq_dev[sq_dev < scale_sq * .Machine$double.eps] <- 0
  score_active <- kish * sq_dev
  score[active] <- score_active

  v_hat <- sum(w[active] * score_active) / W

  list(
    score = score,
    v_hat = v_hat,
    ybar = ybar,
    W = W,
    n_d = n_d,
    active = active
  )
}


# ── .taylor_variance_cell() ───────────────────────────────────────────────────
#
# Taylor-linearization domain variance of variance. The point estimate is
# the weighted mean of the score z_i = a_i * (y_i - ybar)^2 * n/(n-1), and
# the variance of that estimate is the plugged-in weighted-mean influence
# function run through the stratified-clustered recursive variance engine.
#
# Returns the same cell payload as .taylor_mean_cell() but with keys renamed:
# variance (the point estimate), se, se_srs, n, n_weighted.
#
# @param design  A survey_taylor object.
# @param y_col   Character: column name.
# @param domain  Numeric 0/1 vector (full length).
# @return Named list: variance, se, se_srs, n, n_weighted.
.taylor_variance_cell <- function(design, y_col, domain) {
  data <- design@data
  vars <- design@variables
  w <- data[[vars$weights]]
  y_all <- data[[y_col]]

  sc <- .score_variance(y_all, w, domain)
  n_d <- sc$n_d

  if (n_d == 0L || !is.finite(sc$W) || sc$W <= 0) {
    return(list(
      variance = NaN,
      se = NaN,
      se_srs = NaN,
      n = 0L,
      n_weighted = 0
    ))
  }

  if (n_d < 2L) {
    return(list(
      variance = NaN,
      se = NaN,
      se_srs = NaN,
      n = n_d,
      n_weighted = sc$W
    ))
  }

  v_hat <- sc$v_hat
  W <- sc$W
  score <- sc$score
  active_num <- as.numeric(sc$active)

  # Influence function of the weighted mean of the score:
  #   u_i = w_i * a_i * (score_i - v_hat) / W   (out-of-domain rows = 0)
  u <- w * active_num * (score - v_hat) / W

  mats <- .build_cluster_matrices(data, vars)
  lonely.psu <- getOption("survey.lonely.psu", "remove")

  infl_mat <- matrix(u, ncol = 1L, dimnames = list(NULL, y_col))
  v <- .svy_recvar(
    infl_mat,
    mats$clusters_mat,
    mats$strata_mat,
    mats$fpcs,
    lonely.psu = lonely.psu
  )

  se <- sqrt(max(0, v[1L, 1L]))

  # SRS-equivalent SE for design effect: treat the score as an ordinary
  # variable under SRS sampling of size n_d.
  sc_active <- score[sc$active]
  score_mean <- mean(sc_active)
  se_srs <- if (n_d >= 2L) {
    s2 <- sum((sc_active - score_mean)^2) / (n_d - 1L)
    sqrt(s2 / n_d)
  } else {
    0
  }

  list(
    variance = v_hat,
    se = se,
    se_srs = se_srs,
    n = n_d,
    n_weighted = W
  )
}


# ── .replicate_variance_cell() ────────────────────────────────────────────────
#
# Replicate-weight domain variance of variance. Recomputes V^{(r)} per
# replicate with per-replicate ybar^{(r)} and runs .svy_rep_var() on the
# replicate estimates.
#
# @param design  A survey_replicate object.
# @param y_col   Character: variable name.
# @param domain  Numeric 0/1 vector (full length).
# @return Named list: variance, se, se_srs, n, n_weighted.
.replicate_variance_cell <- function(design, y_col, domain) {
  data <- design@data
  vars <- design@variables
  w <- data[[vars$weights]]
  y_all <- data[[y_col]]

  sc <- .score_variance(y_all, w, domain)
  n_d <- sc$n_d

  if (n_d == 0L || !is.finite(sc$W) || sc$W <= 0) {
    return(list(
      variance = NaN,
      se = NaN,
      se_srs = NaN,
      n = 0L,
      n_weighted = 0
    ))
  }

  if (n_d < 2L) {
    return(list(
      variance = NaN,
      se = NaN,
      se_srs = NaN,
      n = n_d,
      n_weighted = sc$W
    ))
  }

  v_hat <- sc$v_hat
  active <- sc$active
  active_num <- as.numeric(active)

  # Per-replicate recomputation: use replicate weights to recompute ybar^{(r)}
  # and V^{(r)} on the same active rows (n is fixed across replicates).
  rep_mat <- as.matrix(data[, vars$repweights, drop = FALSE])
  n_rep <- ncol(rep_mat)
  kish <- n_d / (n_d - 1L)

  # Restrict rows to active for efficiency; rep_mat rows correspond to data
  # rows, so subset by active directly.
  rep_active <- rep_mat[active, , drop = FALSE]
  y_active <- y_all[active]

  # Per-replicate W and ybar
  rep_W <- colSums(rep_active)
  rep_Y <- colSums(rep_active * y_active)
  rep_ybar <- ifelse(rep_W > 0, rep_Y / rep_W, NA_real_)

  # Per-replicate V: sum_i w_r[i] * (y_i - ybar_r)^2 * n/(n-1) / W_r.
  # Snap sq_dev to exact 0 when numerically indistinguishable from 0 to
  # avoid floating-point drift on constant variables.
  rep_v <- vapply(
    seq_len(n_rep),
    function(r) {
      Wr <- rep_W[[r]]
      if (!is.finite(Wr) || Wr <= 0) {
        return(NA_real_)
      }
      yb_r <- rep_ybar[[r]]
      sq_dev_r <- (y_active - yb_r)^2
      scale_sq_r <- (abs(yb_r) + 1)^2
      sq_dev_r[sq_dev_r < scale_sq_r * .Machine$double.eps] <- 0
      num <- sum(rep_active[, r] * sq_dev_r) * kish
      num / Wr
    },
    numeric(1L)
  )

  v <- .svy_rep_var(
    rep_v,
    scale = vars$scale,
    rscales = if (!is.null(vars$rscales)) vars$rscales else rep(1L, n_rep),
    mse = isTRUE(vars$mse),
    coef = v_hat
  )

  se <- sqrt(max(0, v))

  # SRS-equivalent SE using the full-sample score vector
  sc_active <- sc$score[active]
  score_mean <- mean(sc_active)
  se_srs <- if (n_d >= 2L) {
    s2 <- sum((sc_active - score_mean)^2) / (n_d - 1L)
    sqrt(s2 / n_d)
  } else {
    0
  }

  list(
    variance = v_hat,
    se = se,
    se_srs = se_srs,
    n = n_d,
    n_weighted = sc$W
  )
}


# ── .variance_cell() ──────────────────────────────────────────────────────────
#
# Dispatch to the correct per-cell variance estimator by design class.
# PR 1 supports survey_taylor and survey_replicate only; survey_twophase
# and survey_nonprob raise surveycore_error_unsupported_class and are
# implemented in PR 2.
#
# @param design  Any survey design object.
# @param y_col   Character: variable name.
# @param domain  Numeric 0/1 vector (full length).
# @return Named list: variance, se, se_srs, n, n_weighted.
.variance_cell <- function(design, y_col, domain) {
  if (S7::S7_inherits(design, survey_taylor)) {
    .taylor_variance_cell(design, y_col, domain)
  } else if (S7::S7_inherits(design, survey_replicate)) {
    .replicate_variance_cell(design, y_col, domain)
  } else if (
    S7::S7_inherits(design, survey_twophase) ||
      S7::S7_inherits(design, survey_nonprob)
  ) {
    # Deferred to PR 2.
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.fn get_variance} does not yet support ",
          "{.cls {class(design)[[1L]]}}."
        ),
        "i" = "Twophase and nonprob dispatch ships in a follow-up release."
      ),
      class = "surveycore_error_unsupported_class"
    )
  } else {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Unsupported design class {.cls {class(design)[[1L]]}} ",
          "in {.fn get_variance}."
        )
      ),
      class = "surveycore_error_unsupported_class"
    )
  }
}
