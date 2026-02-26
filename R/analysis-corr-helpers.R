# R/analysis-corr-helpers.R
#
# Internal helpers for get_corr().
#
# Functions:
#   .corr_vcov_pair()   — dispatcher: vcov pair by design class
#   .corr_pair_result() — compute r, SE, CI, t, p from vcov output
#   .corr_wide()        — build wide-format correlation matrix

# ── .corr_vcov_pair() ─────────────────────────────────────────────────────────
#
# Dispatch to the correct per-engine vcov pair estimator by design class.
#
# @param design  Any survey design object.
# @param x_col   Character: first variable name.
# @param y_col   Character: second variable name.
# @param domain  Numeric 0/1 vector (full length): domain membership mask.
# @param na.rm   Logical.
# @return Named list: a, b, c, sigma (3x3), n, n_weighted.
.corr_vcov_pair <- function(design, x_col, y_col, domain, na.rm) {
  if (S7::S7_inherits(design, survey_taylor)) {
    .vcov_pair_taylor(design, x_col, y_col, domain, na.rm)
  } else if (S7::S7_inherits(design, survey_replicate)) {
    .vcov_pair_replicate(design, x_col, y_col, domain, na.rm)
  } else if (S7::S7_inherits(design, survey_twophase)) {
    .vcov_pair_twophase(design, x_col, y_col, domain, na.rm)
  } else if (S7::S7_inherits(design, survey_srs)) {
    .vcov_pair_srs(design, x_col, y_col, domain, na.rm)
  } else if (S7::S7_inherits(design, survey_calibrated)) {
    .vcov_pair_calibrated(design, x_col, y_col, domain, na.rm)
  } else {
    cli::cli_abort(
      c(
        "x" = "Unsupported design class {.cls {class(design)[[1L]]}} in {.fn get_corr}.",
        "i" = "Use {.fn as_survey}, {.fn as_survey_rep}, or {.fn as_survey_twophase}."
      ),
      class = "surveycore_error_unsupported_class"
    )
  }
}


# ── .corr_pair_result() ───────────────────────────────────────────────────────
#
# From the vcov pair output, compute r (Pearson correlation), SE via delta
# method, Fisher Z CIs, t-statistic, and two-tailed p-value.
#
# Delta method for r = b / sqrt(a * c):
#   dr/da = -r / (2 * a)
#   dr/db =  1 / sqrt(a * c)
#   dr/dc = -r / (2 * c)
#   SE(r) = sqrt(g' * sigma * g)
#
# Fisher Z CI:
#   ci_low  = tanh(atanh(r) - z_crit * se_r)
#   ci_high = tanh(atanh(r) + z_crit * se_r)
#
# @param vcov_out Named list from .corr_vcov_pair().
# @return Named list: r, se_r, se_srs, n, n_weighted. NA when n < 2 or
#   variance-covariance is undefined.
.corr_pair_result <- function(vcov_out) {
  a     <- vcov_out$a
  b     <- vcov_out$b
  c_val <- vcov_out$c
  sigma <- vcov_out$sigma
  n_d   <- vcov_out$n

  if (is.na(a) || is.na(b) || is.na(c_val) || a <= 0 || c_val <= 0) {
    return(list(
      r = NA_real_, se_r = NA_real_, se_srs = NA_real_,
      n = n_d, n_weighted = vcov_out$n_weighted
    ))
  }

  r <- b / sqrt(a * c_val)
  # Clamp to [-1, 1] to guard against floating-point overshoot
  r <- max(-1, min(1, r))

  # Delta method gradient: g = (dr/da, dr/db, dr/dc)
  g  <- c(-r / (2 * a), 1 / sqrt(a * c_val), -r / (2 * c_val))
  v  <- as.numeric(t(g) %*% sigma %*% g)
  se_r <- if (is.na(v) || v < 0) NA_real_ else sqrt(v)

  # SRS-equivalent SE: (1 - r^2) / sqrt(max(n-3, 1)) (Fisher Z approximation)
  se_srs <- if (n_d >= 4L) {
    (1 - r^2) / sqrt(n_d - 3L)
  } else {
    NA_real_
  }

  list(r = r, se_r = se_r, se_srs = se_srs, n = n_d, n_weighted = vcov_out$n_weighted)
}


# ── .corr_wide() ──────────────────────────────────────────────────────────────
#
# Build wide-format correlation matrix from computed pair results.
# Wide format always shows the full symmetric correlation matrix.
# Diagonal: NA when diagonal = FALSE, else 1.
# Upper triangle (row_idx > col_idx in input order) mirrors lower triangle.
#
# @return A survey_corr tibble with columns: variable + one per focal variable.
.corr_wide <- function(
  x_names, display_names, pairs_i, pairs_j, pair_results,
  diagonal, design, var_labels_list, q_prefaces_list, val_labels_list,
  conf_level
) {
  p <- length(x_names)
  n_pairs <- length(pairs_i)

  # Build p x p r matrix (NA fill)
  r_mat <- matrix(NA_real_, p, p)

  for (k in seq_len(n_pairs)) {
    i <- pairs_i[[k]]; j <- pairs_j[[k]]
    r_mat[i, j] <- pair_results[[k]]$r
    r_mat[j, i] <- pair_results[[k]]$r   # symmetric
  }

  if (isTRUE(diagonal)) {
    diag(r_mat) <- 1
  }
  # else: diagonal remains NA

  # Build column vectors
  var_col <- display_names[x_names]
  col_vecs <- list(variable = var_col)
  for (k in seq_len(p)) {
    col_vecs[[display_names[[k]]]] <- r_mat[, k]
  }

  meta_args <- list(
    variables         = x_names,
    variable_labels   = var_labels_list,
    question_prefaces = q_prefaces_list,
    value_labels      = val_labels_list,
    method            = "pearson",
    conf_level        = conf_level,
    call              = sys.call(-1L),
    group_names       = character(0),
    group_labels      = list()
  )

  result <- .make_result_tibble(
    col_vecs,
    data.frame(),
    "survey_corr",
    design,
    meta_args,
    CORR_META_KEYS
  )

  result
}
