# R/analysis-quantiles-helpers.R
#
# Internal helpers for get_quantiles().
#
# Functions:
#   .last()                     — index of last TRUE (vendored from survey)
#   .wtd_qs()                   — weighted quantile via sorted ECDF (vendored)
#   .get_quantile_weights()     — effective weights (handles twophase)
#   .quantile_woodruff_cell()   — Woodruff SE + CI for one (domain, prob) cell
#
# Vendoring note:
#   .last() and .wtd_qs() are derived from survey (GPL-2/GPL-3):
#   survey:::.last() and survey:::qs() (Thomas Lumley, 2004-2024).
#   Renamed and lightly edited for integration with surveycore internals.
#   See VENDORED.md for the full attribution.

# ── .last() ───────────────────────────────────────────────────────────────────
#
# Return the index of the last TRUE element in a logical vector, or 1 if none
# are TRUE. Vendored from survey:::.last().
#
# @param a Logical vector.
# @return Integer(1).
#' @noRd
.last <- function(a) {
  if (any(a)) max(which(a)) else 1L
}


# ── .wtd_qs() ─────────────────────────────────────────────────────────────────
#
# Weighted quantile via sorted cumulative-weight ECDF (lower-quantile rule).
# Vendored from survey:::qs() with survey:::qrule_math logic inlined.
#
# Algorithm:
#   1. Sort x; build cumulative weights.
#   2. pos  = last index where cumulative weight ≤ p * total_weight.
#   3. wlow = p - cumw[pos] / sum(w).
#   4. If wlow ≤ 0 (or pos == n): return x[pos].  Else: return x[pos+1].
#
# @param x Numeric vector of observed values (no NAs).
# @param w Numeric vector of positive weights (same length as x).
# @param p Numeric scalar in [0, 1]: the desired quantile probability.
# @return Numeric(1): the weighted p-th quantile.
#' @noRd
.wtd_qs <- function(x, w, p) {
  n <- length(x)
  ii <- order(x)
  x <- x[ii]
  cumw <- cumsum(w[ii])
  sw <- cumw[n] # sum(w) — last element after cumsum
  pos <- .last(cumw <= p * sw)
  wlow <- p - cumw[pos] / sw
  if (wlow <= 0 || pos == n) x[pos] else x[pos + 1L]
}


# ── .get_quantile_weights() ───────────────────────────────────────────────────
#
# Return the full-length effective weight vector appropriate for weighted
# quantile computation. For twophase designs, this is the calibrated weight
# (phase1_weight / phase2_sampling_probability); for all others, the standard
# survey weight column.
#
# Note: For twophase designs, Phase 1-only rows receive a finite weight:
# .compute_phase2_probs() gives them a placeholder probability of 1. The
# caller must exclude them from the quantile domain; get_quantiles() does so
# by restricting its domain mask to the phase-2 subset (issue #328).
#
# @param design A survey design object.
# @return Numeric vector of length nrow(design@data).
#' @noRd
.get_quantile_weights <- function(design) {
  if (S7::S7_inherits(design, survey_twophase)) {
    subset <- design@data[[design@variables$subset]]
    pi2_full <- .compute_phase2_probs(design, subset)
    w_full <- design@data[[design@variables$phase1$weights]]
    w_full / pi2_full
  } else {
    design@data[[design@variables$weights]]
  }
}


# ── .quantile_woodruff_cell() ─────────────────────────────────────────────────
#
# Compute a single quantile estimate plus Woodruff (1952) SE and CI for one
# (active-domain, prob) combination.
#
# Woodruff method:
#   1. qhat   = weighted p-th quantile of y_domain (.wtd_qs).
#   2. z_i    = I(y_i <= qhat) for i in active domain, 0 elsewhere.
#   3. p_hat  = svymean(z) over the domain → P(y <= qhat | domain).
#   4. SE(p_hat) via .mean_cell() (all five design classes reused).
#   5. Back-transform CI for p_hat to quantile scale via .wtd_qs.
#   6. se_q   = (ci_high - ci_low) / (2 * z_crit).
#
# The CDF indicator column "..surveycore_quantile_cdf.." is injected into a
# local copy of design@data for the .mean_cell() call. S7 copy-on-modify
# semantics ensure the caller's design is not modified.
#
# @param design        A survey design object.
# @param y_all         Full-length numeric vector: the focal variable column
#                      (may contain NAs; out-of-domain values are ignored).
# @param active_domain Numeric 0/1 vector (full length): 1 = in domain and
#                      non-NA. Built by the caller with na.rm already applied.
# @param prob          Numeric scalar in (0, 1): quantile probability.
# @param conf_level    Numeric scalar in (0, 1): confidence level for Woodruff.
# @param degf_w        Numeric(1): degrees of freedom for the t-critical value.
#                      Use .degf(design, rows) over the cell's non-missing
#                      rows. Finite df gives CI bounds that match
#                      survey::svyquantile() at 1e-6 tolerance.
# @return Named list: estimate, se, ci_low, ci_high, se_srs, n, n_weighted.
#' @noRd
.quantile_woodruff_cell <- function(
  design,
  y_all,
  active_domain,
  prob,
  conf_level,
  degf_w
) {
  dom_idx <- active_domain > 0
  n_d <- as.integer(sum(dom_idx))
  w_full <- .get_quantile_weights(design)

  if (n_d == 0L) {
    return(list(
      estimate = NA_real_,
      se = NA_real_,
      ci_low = NA_real_,
      ci_high = NA_real_,
      se_srs = NA_real_,
      n = 0L,
      n_weighted = 0
    ))
  }

  y_domain <- y_all[dom_idx]
  w_domain <- w_full[dom_idx]
  N_d <- sum(w_domain)

  # ── Weighted quantile ────────────────────────────────────────────────────
  qhat <- .wtd_qs(y_domain, w_domain, prob)

  # ── Woodruff: CDF indicator column ───────────────────────────────────────
  # z_i = I(y_i <= qhat) for in-domain rows; 0 for out-of-domain rows.
  # NAs in y_all are treated as > qhat (z_i = 0).
  z_full <- as.numeric(!is.na(y_all) & dom_idx & (y_all <= qhat))
  tmp_col <- "..surveycore_quantile_cdf.."
  design@data[[tmp_col]] <- z_full

  # ── SE of the CDF proportion via existing mean cell functions ────────────
  cell <- .mean_cell(design, tmp_col, active_domain)
  p_hat <- cell$mean
  se_p <- cell$se

  if (is.na(p_hat) || is.na(se_p)) {
    return(list(
      estimate = qhat,
      se = NA_real_,
      ci_low = NA_real_,
      ci_high = NA_real_,
      se_srs = NA_real_,
      n = n_d,
      n_weighted = N_d
    ))
  }

  # ── Woodruff back-transformation ─────────────────────────────────────────
  # Use t critical value with design df (finite df matches survey::svyquantile).
  z_crit <- stats::qt((1 + conf_level) / 2, df = degf_w)
  p_low <- max(0, p_hat - z_crit * se_p)
  p_high <- min(1, p_hat + z_crit * se_p)
  ci_low <- .wtd_qs(y_domain, w_domain, p_low)
  ci_high <- .wtd_qs(y_domain, w_domain, p_high)
  se_q <- (ci_high - ci_low) / (2 * z_crit)

  list(
    estimate = qhat,
    se = se_q,
    ci_low = ci_low,
    ci_high = ci_high,
    se_srs = NA_real_, # DEFF for quantiles requires a kernel density
    # estimate at the quantile point (Woodruff SRS
    # approximation; see survey::svyquantile(deff=TRUE)).
    # Not implemented — deff is always NA.
    n = n_d,
    n_weighted = N_d
  )
}
