# R/analysis-corr-latent.R
#
# Internal primitives for weighted polychoric and polyserial correlation
# under complex survey designs (Mannan 2025; Olsson 1979; Cox 1974).
#
# PR 1 scope: estimator primitives only. No user-visible API change.
# Dispatcher (.corr_latent_pair), variance paths, and boundary detection
# land in PR 2. Exported wiring via get_corr() lands in PR 3.
#
# Functions:
#   .corr_detect_ordinal()           — classify a column by type
#   .corr_canonicalize_polyserial()  — assign ordinal/continuous roles
#   .corr_estimate_thresholds()      — weighted marginal threshold estimation
#   .corr_weighted_standardize()     — weighted standardization (Cox 1974)
#   .corr_polychoric_loglik()        — weighted log-likelihood (polychoric)
#   .corr_polyserial_loglik()        — weighted log-likelihood (polyserial)
#   .corr_polychoric_mle()           — MLE for polychoric rho
#   .corr_polyserial_mle()           — MLE for polyserial rho

# ── .corr_detect_ordinal() ────────────────────────────────────────────────────
#
# Classify a column by type to decide ordinal vs continuous treatment.
#
# Return values:
#   "ordered"         — inherits("ordered")
#   "factor"          — is.factor() && !is.ordered()
#   "integer_ordinal" — is.integer() with <= cutoff distinct non-NA values
#   "continuous"      — is.double() and not integer-valued or > cutoff
#                       distinct values
#   "ambiguous"       — everything else (character, logical, high-cardinality
#                       integer, etc.)
.corr_detect_ordinal <- function(col, integer_cardinality_cutoff = 10L) {
  if (is.ordered(col)) {
    return("ordered")
  }
  if (is.factor(col)) {
    return("factor")
  }
  if (is.integer(col)) {
    n_distinct <- length(unique(col[!is.na(col)]))
    if (n_distinct <= integer_cardinality_cutoff) {
      return("integer_ordinal")
    }
    return("ambiguous")
  }
  if (is.double(col)) {
    non_na <- col[!is.na(col)]
    if (length(non_na) == 0L) {
      return("continuous")
    }
    # Integer-valued doubles with small cardinality are still continuous
    # under the spec's strict reading ("is.double" → "continuous").
    return("continuous")
  }
  # character, logical, complex, raw, list → ambiguous
  "ambiguous"
}


# ── .corr_canonicalize_polyserial() ──────────────────────────────────────────
#
# Assign ordinal/continuous roles to the two sides of a polyserial pair.
# Callers pass column names; helper reads the columns from `data`.
#
# Errors:
#   PC-2: both sides classify as ordinal or both as continuous.
#   PC-3: at least one side classifies as "ambiguous".
#
# Returns: list(ordinal_name, continuous_name) — both character(1).
.corr_canonicalize_polyserial <- function(
  x_col_name,
  y_col_name,
  data,
  integer_cardinality_cutoff = 10L
) {
  type_x <- .corr_detect_ordinal(
    data[[x_col_name]],
    integer_cardinality_cutoff = integer_cardinality_cutoff
  )
  type_y <- .corr_detect_ordinal(
    data[[y_col_name]],
    integer_cardinality_cutoff = integer_cardinality_cutoff
  )

  ordinal_types <- c("ordered", "factor", "integer_ordinal")
  continuous_types <- c("continuous")

  x_is_ordinal <- type_x %in% ordinal_types
  y_is_ordinal <- type_y %in% ordinal_types
  x_is_continuous <- type_x %in% continuous_types
  y_is_continuous <- type_y %in% continuous_types
  x_is_ambiguous <- identical(type_x, "ambiguous")
  y_is_ambiguous <- identical(type_y, "ambiguous")

  # PC-3 fires on any ambiguous side; message names all ambiguous columns.
  if (x_is_ambiguous || y_is_ambiguous) {
    ambiguous_vars <- character(0)
    if (x_is_ambiguous) {
      ambiguous_vars <- c(ambiguous_vars, x_col_name)
    }
    if (y_is_ambiguous) {
      ambiguous_vars <- c(ambiguous_vars, y_col_name)
    }
    cli::cli_abort(
      c(
        "x" = paste0(
          "Cannot determine whether {.field {ambiguous_vars}} ",
          "{?is/are} ordinal or continuous."
        ),
        "i" = paste0(
          "Integer vectors with more than {.val ",
          "{integer_cardinality_cutoff}} distinct values, and logical / ",
          "character vectors, are ambiguous."
        ),
        "v" = paste0(
          "Coerce to {.cls ordered} for ordinal or {.cls double} ",
          "for continuous before calling {.fn get_corr}."
        )
      ),
      class = "surveycore_error_polyserial_canonicalization_ambiguous"
    )
  }

  # PC-2 fires when neither side is continuous or both are continuous.
  if (x_is_ordinal && y_is_ordinal) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.code method = \"polyserial\"} requires exactly one ordinal ",
          "and one continuous variable per pair."
        ),
        "i" = paste0(
          "For pair ({.field {x_col_name}}, {.field {y_col_name}}): ",
          "classified as ({.val {type_x}}, {.val {type_y}})."
        ),
        "v" = paste0(
          "Supply one {.cls factor}/{.cls ordered} variable and one ",
          "{.cls numeric} variable, or use ",
          "{.code method = \"polychoric\"} / {.code method = \"pearson\"}."
        )
      ),
      class = "surveycore_error_polyserial_requires_mixed_types"
    )
  }
  if (x_is_continuous && y_is_continuous) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.code method = \"polyserial\"} requires exactly one ordinal ",
          "and one continuous variable per pair."
        ),
        "i" = paste0(
          "For pair ({.field {x_col_name}}, {.field {y_col_name}}): ",
          "classified as ({.val {type_x}}, {.val {type_y}})."
        ),
        "v" = paste0(
          "Supply one {.cls factor}/{.cls ordered} variable and one ",
          "{.cls numeric} variable, or use ",
          "{.code method = \"polychoric\"} / {.code method = \"pearson\"}."
        )
      ),
      class = "surveycore_error_polyserial_requires_mixed_types"
    )
  }

  if (x_is_ordinal) {
    list(ordinal_name = x_col_name, continuous_name = y_col_name)
  } else {
    list(ordinal_name = y_col_name, continuous_name = x_col_name)
  }
}


# ── .corr_estimate_thresholds() ───────────────────────────────────────────────
#
# Weighted threshold estimation for ordinal variables via the normal quantile
# function (Mannan 2025 §6.1.2; Olsson 1979).
#
# Conventions:
#   - Returned `thresholds` has length K-1 (K = retained levels).
#   - θ_1 ≡ -Inf and θ_{K+1} ≡ +Inf are implicit sentinels, never stored.
#   - Zero-weight interior levels are dropped and reported; remaining levels
#     are renumbered 1..K for bookkeeping.
#
# Arguments:
#   ordinal_vec    — factor / ordered / integer vector (row-aligned to data)
#   weights        — numeric vector of nonnegative weights (row-aligned)
#   active_domain  — 0/1 numeric mask (row-aligned); 0 means out-of-domain
#
# Returns: list(
#   thresholds      = numeric(K-1),
#   levels_used     = character|integer — retained levels in order,
#   dropped_levels  = character|integer — zero-weight levels,
#   codes           = integer vector of length-n with re-numbered levels
#                     (NA for rows with zero effective weight)
# )
#
# Errors:
#   PC-4 surveycore_error_polychoric_single_level_ordinal — < 2 positive-weight
#        levels remain.
.corr_estimate_thresholds <- function(
  ordinal_vec,
  weights,
  active_domain,
  var_name = "variable"
) {
  # Effective weight per row: out-of-domain or NA collapse to 0.
  w_eff <- weights * active_domain
  w_eff[is.na(w_eff)] <- 0
  w_eff[is.na(ordinal_vec)] <- 0

  # Canonical level ordering depends on class.
  if (is.factor(ordinal_vec)) {
    all_levels <- levels(ordinal_vec)
    codes_all <- as.integer(ordinal_vec)
  } else if (is.integer(ordinal_vec) || is.numeric(ordinal_vec)) {
    all_levels <- sort(unique(ordinal_vec[!is.na(ordinal_vec)]))
    codes_all <- match(ordinal_vec, all_levels)
  } else {
    # Character or other type: sort unique values lexicographically.
    all_levels <- sort(unique(ordinal_vec[!is.na(ordinal_vec)]))
    codes_all <- match(ordinal_vec, all_levels)
  }

  # Sum effective weight per level over all possible levels.
  n_all_levels <- length(all_levels)
  level_weights <- numeric(n_all_levels)
  if (n_all_levels > 0L) {
    for (k in seq_len(n_all_levels)) {
      level_weights[[k]] <- sum(w_eff[codes_all == k], na.rm = TRUE)
    }
  }

  # Partition levels into retained (positive weight) and dropped (zero weight).
  keep_mask <- level_weights > 0
  levels_used <- all_levels[keep_mask]
  dropped_levels <- all_levels[!keep_mask]

  if (length(levels_used) < 2L) {
    n_levels <- length(levels_used)
    cli::cli_abort(
      c(
        "x" = paste0(
          "Ordinal variable {.field {var_name}} has only ",
          "{.val {n_levels}} observed level{?s} in the active domain."
        ),
        "i" = "Threshold estimation requires at least 2 distinct levels.",
        "v" = paste0(
          "Filter to a domain with more than one level of ",
          "{.field {var_name}}."
        )
      ),
      class = "surveycore_error_polychoric_single_level_ordinal"
    )
  }

  # Renumber retained levels 1..K and compute cumulative weights.
  kept_weights <- level_weights[keep_mask]
  total_w <- sum(kept_weights)
  # Cumulative proportions for k = 1..K-1 (last always sums to 1).
  cum_prop <- cumsum(kept_weights) / total_w
  thresholds <- stats::qnorm(cum_prop[-length(cum_prop)])

  # Remap codes: rows mapping to dropped levels become NA; retained levels
  # get renumbered 1..K.
  keep_level_map <- integer(n_all_levels)
  keep_level_map[keep_mask] <- seq_len(sum(keep_mask))
  keep_level_map[!keep_mask] <- NA_integer_
  codes_remapped <- keep_level_map[codes_all]

  list(
    thresholds = thresholds,
    levels_used = levels_used,
    dropped_levels = dropped_levels,
    codes = codes_remapped,
    level_weights_used = kept_weights,
    total_weight = total_w
  )
}


# ── .corr_weighted_standardize() ─────────────────────────────────────────────
#
# Weighted standardization using Cox (1974) population SD (no df correction).
#
# Arguments:
#   continuous_vec — numeric vector (row-aligned to data)
#   weights        — numeric vector (row-aligned)
#   active_domain  — 0/1 numeric mask (row-aligned)
#
# Returns: list(z = numeric, mean_w = numeric(1), sd_w = numeric(1)).
#   z is the same length as the input. Rows with zero effective weight get
#   z[i] = NA_real_. Degenerate sd_w = 0 yields NaN z values and propagates.
.corr_weighted_standardize <- function(
  continuous_vec,
  weights,
  active_domain
) {
  w_eff <- weights * active_domain
  w_eff[is.na(w_eff)] <- 0
  # NA in the continuous column gets zero weight for the moment calc.
  use <- w_eff > 0 & !is.na(continuous_vec)

  if (!any(use)) {
    z <- rep(NA_real_, length(continuous_vec))
    return(list(z = z, mean_w = NA_real_, sd_w = NA_real_))
  }

  total_w <- sum(w_eff[use])
  mean_w <- sum(w_eff[use] * continuous_vec[use]) / total_w
  # Population SD (Cox 1974): divide by Σw, not (Σw - 1).
  var_w <- sum(w_eff[use] * (continuous_vec[use] - mean_w)^2) / total_w
  sd_w <- sqrt(var_w)

  # Zero-weight row → NA. NA values in continuous_vec also become NA.
  z <- rep(NA_real_, length(continuous_vec))
  if (sd_w > 0) {
    z[use] <- (continuous_vec[use] - mean_w) / sd_w
  } else {
    # Degenerate SD: produce NaN so downstream MLE fails visibly.
    z[use] <- NaN
  }

  list(z = z, mean_w = mean_w, sd_w = sd_w)
}


# ── .corr_bivnorm_cdf() ──────────────────────────────────────────────────────
#
# Thin wrapper over pbivnorm::pbivnorm with Inf-handling conventions:
#   Φ_2(+∞, b; ρ) = Φ(b)
#   Φ_2(a, +∞; ρ) = Φ(a)
#   Φ_2(a, -∞; ρ) = 0
#   Φ_2(-∞, b; ρ) = 0
# pbivnorm itself does not accept infinite arguments.
.corr_bivnorm_cdf <- function(a, b, rho) {
  # NA / NaN arguments propagate as NA (pbivnorm does not accept them).
  if (is.na(a) || is.na(b) || is.na(rho)) {
    return(NA_real_)
  }
  # Handle -Inf first (dominates).
  if (is.infinite(a) && a < 0) {
    return(0)
  }
  if (is.infinite(b) && b < 0) {
    return(0)
  }
  if (is.infinite(a) && a > 0 && is.infinite(b) && b > 0) {
    return(1)
  }
  if (is.infinite(a) && a > 0) {
    return(stats::pnorm(b))
  }
  if (is.infinite(b) && b > 0) {
    return(stats::pnorm(a))
  }
  pbivnorm::pbivnorm(a, b, rho = rho)
}


# ── .corr_polychoric_loglik() ────────────────────────────────────────────────
#
# Weighted log-likelihood for polychoric correlation (Mannan 2025 §5.2;
# Olsson 1979) at a given ρ and fixed thresholds.
#
# Arguments:
#   rho           — scalar in (-1, 1)
#   cell_weights  — K_x × K_y numeric matrix of summed weights per observed
#                   cell (rows = levels of X; cols = levels of Y).
#   thresholds_x  — length K_x - 1 numeric vector of interior thresholds.
#   thresholds_y  — length K_y - 1 numeric vector of interior thresholds.
#   cell_prob_floor — numeric(1), default 1e-300.
#
# Returns: list(ll = numeric(1), any_floor_active = logical(1)).
.corr_polychoric_loglik <- function(
  rho,
  cell_weights,
  thresholds_x,
  thresholds_y,
  cell_prob_floor = 1e-300
) {
  k_x <- nrow(cell_weights)
  k_y <- ncol(cell_weights)
  # Full threshold vectors with -Inf / +Inf sentinels.
  tx_full <- c(-Inf, thresholds_x, Inf)
  ty_full <- c(-Inf, thresholds_y, Inf)

  ll <- 0
  any_floor_active <- FALSE

  for (m in seq_len(k_x)) {
    for (p in seq_len(k_y)) {
      w_cell <- cell_weights[m, p]
      if (w_cell == 0) {
        # 0 * log(anything) treated as 0. Skip to avoid log(0) on floored cell.
        next
      }
      # π_{m,p}(ρ) = Φ2(t_{m+1}, t'_{p+1}) − Φ2(t_m, t'_{p+1})
      #            − Φ2(t_{m+1}, t'_p) + Φ2(t_m, t'_p)
      a_hi <- tx_full[[m + 1L]]
      a_lo <- tx_full[[m]]
      b_hi <- ty_full[[p + 1L]]
      b_lo <- ty_full[[p]]
      p_mp <- .corr_bivnorm_cdf(a_hi, b_hi, rho) -
        .corr_bivnorm_cdf(a_lo, b_hi, rho) -
        .corr_bivnorm_cdf(a_hi, b_lo, rho) +
        .corr_bivnorm_cdf(a_lo, b_lo, rho)
      if (is.na(p_mp) || p_mp < cell_prob_floor) {
        any_floor_active <- TRUE
        p_mp <- cell_prob_floor
      }
      ll <- ll + w_cell * log(p_mp)
    }
  }

  list(ll = ll, any_floor_active = any_floor_active)
}


# ── .corr_polyserial_loglik() ────────────────────────────────────────────────
#
# Weighted log-likelihood for polyserial correlation (Mannan 2025 §5.1;
# Cox 1974) at a given ρ, fixed thresholds, and standardized continuous.
#
# The ρ-independent φ(z) factor is dropped from the objective; only the
# [Φ(u_hi) - Φ(u_lo)] bracket is evaluated, with
#   u_k = (θ_k - ρ z) / √(1 - ρ²).
#
# Arguments:
#   rho             — scalar in (-1, 1)
#   z               — numeric vector of standardized continuous values
#                     (row-aligned to observations used in the likelihood).
#   ordinal_level_int — integer vector of ordinal codes 1..K
#                     (row-aligned to z).
#   thresholds      — length K-1 interior thresholds.
#   weights         — numeric vector (row-aligned).
#   cell_prob_floor — numeric(1), default 1e-300.
#
# Returns: list(ll = numeric(1), any_floor_active = logical(1)).
.corr_polyserial_loglik <- function(
  rho,
  z,
  ordinal_level_int,
  thresholds,
  weights,
  cell_prob_floor = 1e-300
) {
  use <- !is.na(z) &
    !is.na(ordinal_level_int) &
    !is.na(weights) &
    weights > 0
  if (!any(use)) {
    return(list(ll = 0, any_floor_active = FALSE))
  }
  z_u <- z[use]
  m_u <- ordinal_level_int[use]
  w_u <- weights[use]
  k <- length(thresholds) + 1L
  # Full threshold vector with -Inf / +Inf sentinels.
  t_full <- c(-Inf, thresholds, Inf)
  denom <- sqrt(1 - rho^2)
  # nocov start
  # Defensive: ρ is clamped by stats::optimize() bounds to (-1 + eps, 1 - eps),
  # so sqrt(1 - rho^2) > 0 whenever this helper is invoked from the MLE path.
  # Reachable only if a future caller bypasses the MLE's optimizer bounds.
  if (!is.finite(denom) || denom <= 0) {
    return(list(ll = -Inf, any_floor_active = TRUE))
  }
  # nocov end

  # Precompute Φ((t_k - ρ z_i) / denom) on demand for each observation.
  theta_hi <- t_full[m_u + 1L]
  theta_lo <- t_full[m_u]
  u_hi <- (theta_hi - rho * z_u) / denom
  u_lo <- (theta_lo - rho * z_u) / denom
  phi_hi <- ifelse(is.infinite(theta_hi) & theta_hi > 0, 1, stats::pnorm(u_hi))
  phi_lo <- ifelse(is.infinite(theta_lo) & theta_lo < 0, 0, stats::pnorm(u_lo))
  p_mi <- phi_hi - phi_lo

  any_floor_active <- FALSE
  bad <- is.na(p_mi) | p_mi < cell_prob_floor
  if (any(bad)) {
    any_floor_active <- TRUE
    p_mi[bad] <- cell_prob_floor
  }
  ll <- sum(w_u * log(p_mi))

  list(ll = ll, any_floor_active = any_floor_active)
}


# ── .corr_polychoric_mle() ────────────────────────────────────────────────────
#
# Two-step polychoric MLE: estimate thresholds from marginals, then maximize
# the weighted log-likelihood over ρ via stats::optimize().
#
# Arguments:
#   ord_x_vec      — ordinal x (factor/ordered/integer), row-aligned
#   ord_y_vec      — ordinal y, row-aligned
#   weights        — numeric weights, row-aligned
#   active_domain  — 0/1 numeric mask, row-aligned
#   eps            — boundary offset for the optimizer bounds
#   x_name, y_name — for diagnostics and error messages
#
# Returns: list(
#   rho, converged, thresholds_x, thresholds_y, levels_x, levels_y,
#   cell_counts (K_x × K_y weighted matrix),
#   n_cells_obs (number of non-empty cells),
#   n_sparse_cells (count of cells with modeled prob < floor at MLE),
#   log_lik, any_floor_active
# )
#
# Errors:
#   PC-4 propagated from threshold helper (each side).
#   PC-5 surveycore_error_polychoric_insufficient_cells when n_cells_obs < 4.
#   PC-6 surveycore_error_polychoric_optim_failed if the optimizer returns
#        non-finite / boundary results or the objective is not finite at a
#        sentinel test point.
.corr_polychoric_mle <- function(
  ord_x_vec,
  ord_y_vec,
  weights,
  active_domain,
  eps = 1e-6,
  x_name = "x",
  y_name = "y"
) {
  th_x <- .corr_estimate_thresholds(
    ord_x_vec,
    weights,
    active_domain,
    var_name = x_name
  )
  th_y <- .corr_estimate_thresholds(
    ord_y_vec,
    weights,
    active_domain,
    var_name = y_name
  )

  k_x <- length(th_x$levels_used)
  k_y <- length(th_y$levels_used)

  # Build weighted K_x × K_y cell counts. Rows with NA code or zero effective
  # weight contribute nothing.
  w_eff <- weights * active_domain
  w_eff[is.na(w_eff)] <- 0
  codes_x <- th_x$codes
  codes_y <- th_y$codes
  use <- !is.na(codes_x) & !is.na(codes_y) & w_eff > 0
  cell_counts <- matrix(0, nrow = k_x, ncol = k_y)
  if (any(use)) {
    for (i in which(use)) {
      cell_counts[codes_x[[i]], codes_y[[i]]] <-
        cell_counts[codes_x[[i]], codes_y[[i]]] + w_eff[[i]]
    }
  }

  n_cells_obs <- sum(cell_counts > 0)
  if (n_cells_obs < 4L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Pair ({.field {x_name}}, {.field {y_name}}) has only ",
          "{.val {n_cells_obs}} non-empty cell{?s} in the active domain."
        ),
        "i" = paste0(
          "Polychoric MLE is not identified with fewer than 4 ",
          "non-empty cells (surveycore guardrail)."
        ),
        "v" = "Collapse levels or choose a different pair."
      ),
      class = "surveycore_error_polychoric_insufficient_cells"
    )
  }

  # Objective: weighted log-likelihood as a function of ρ.
  objective <- function(rho) {
    out <- .corr_polychoric_loglik(
      rho,
      cell_weights = cell_counts,
      thresholds_x = th_x$thresholds,
      thresholds_y = th_y$thresholds
    )
    out$ll
  }

  # Guard: objective must be finite somewhere before we hand off to optimize().
  probe <- vapply(
    c(-0.9, -0.5, 0, 0.5, 0.9),
    function(r) objective(r),
    numeric(1)
  )
  # nocov start
  # Defensive: with cell_prob_floor = 1e-300, log(floor) ≈ -690 is finite,
  # so objective(r) is finite for any r in the probe set on any realistic
  # cell_weights. This branch is only reachable if future changes remove
  # the floor or callers pass non-finite thresholds directly.
  if (!any(is.finite(probe))) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Numerical optimization did not converge for pair ",
          "({.field {x_name}}, {.field {y_name}})."
        ),
        "i" = "Optimizer message: {.val objective not finite at any probe point}.",
        "v" = paste0(
          "Inspect the pair for extreme weight skew, sparse cells, ",
          "or degenerate ordinal coding."
        )
      ),
      class = "surveycore_error_polychoric_optim_failed"
    )
  }
  # nocov end

  fit <- tryCatch(
    stats::optimize(
      objective,
      lower = -1 + eps,
      upper = 1 - eps,
      tol = .Machine$double.eps^0.25,
      maximum = TRUE
    ),
    error = function(e) NULL
  )

  if (is.null(fit) || !is.finite(fit$maximum) || !is.finite(fit$objective)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Numerical optimization did not converge for pair ",
          "({.field {x_name}}, {.field {y_name}})."
        ),
        "i" = "Optimizer message: {.val stats::optimize() returned a non-finite result}.",
        "v" = paste0(
          "Inspect the pair for extreme weight skew, sparse cells, ",
          "or degenerate ordinal coding."
        )
      ),
      class = "surveycore_error_polychoric_optim_failed"
    )
  }

  rho_hat <- fit$maximum
  # Final any_floor_active at optimum drives the sparse-cell bookkeeping.
  opt_out <- .corr_polychoric_loglik(
    rho_hat,
    cell_weights = cell_counts,
    thresholds_x = th_x$thresholds,
    thresholds_y = th_y$thresholds
  )

  # Count cells whose modeled probability at ρ̂ is below the sparse tolerance
  # (1e-12 per spec). Cells with zero weight are ignored.
  n_sparse <- .corr_count_sparse_cells(
    rho_hat,
    cell_counts,
    th_x$thresholds,
    th_y$thresholds,
    tol = 1e-12
  )

  list(
    rho = rho_hat,
    converged = TRUE,
    thresholds_x = th_x$thresholds,
    thresholds_y = th_y$thresholds,
    levels_x = th_x$levels_used,
    levels_y = th_y$levels_used,
    cell_counts = cell_counts,
    n_cells_obs = as.integer(n_cells_obs),
    n_sparse_cells = as.integer(n_sparse),
    log_lik = opt_out$ll,
    any_floor_active = opt_out$any_floor_active,
    dropped_levels_x = th_x$dropped_levels,
    dropped_levels_y = th_y$dropped_levels
  )
}


# Internal: count observed cells whose modeled probability at ρ is below
# the sparse-cell tolerance (spec §Warnings PC-11).
.corr_count_sparse_cells <- function(
  rho,
  cell_counts,
  thresholds_x,
  thresholds_y,
  tol = 1e-12
) {
  k_x <- nrow(cell_counts)
  k_y <- ncol(cell_counts)
  tx_full <- c(-Inf, thresholds_x, Inf)
  ty_full <- c(-Inf, thresholds_y, Inf)
  n_sparse <- 0L
  for (m in seq_len(k_x)) {
    for (p in seq_len(k_y)) {
      if (cell_counts[m, p] == 0) next
      a_hi <- tx_full[[m + 1L]]
      a_lo <- tx_full[[m]]
      b_hi <- ty_full[[p + 1L]]
      b_lo <- ty_full[[p]]
      p_mp <- .corr_bivnorm_cdf(a_hi, b_hi, rho) -
        .corr_bivnorm_cdf(a_lo, b_hi, rho) -
        .corr_bivnorm_cdf(a_hi, b_lo, rho) +
        .corr_bivnorm_cdf(a_lo, b_lo, rho)
      if (is.na(p_mp) || p_mp < tol) {
        n_sparse <- n_sparse + 1L
      }
    }
  }
  n_sparse
}


# ── .corr_polyserial_mle() ────────────────────────────────────────────────────
#
# Two-step polyserial MLE: standardize the continuous variable, estimate
# thresholds from the ordinal marginals, then maximize the weighted
# log-likelihood over ρ via stats::optimize().
#
# Arguments:
#   ordinal_vec    — ordinal (factor/ordered/integer), row-aligned
#   continuous_vec — numeric, row-aligned
#   weights        — numeric weights, row-aligned
#   active_domain  — 0/1 numeric mask, row-aligned
#   eps            — boundary offset for the optimizer bounds
#   ord_name, cont_name — for diagnostics and error messages
#
# Returns: list(
#   rho, converged, thresholds, levels_used, mean_w, sd_w, z,
#   ordinal_codes, log_lik, any_floor_active, dropped_levels
# )
#
# Errors:
#   PC-4 propagated from threshold helper.
#   PC-6 surveycore_error_polychoric_optim_failed.
.corr_polyserial_mle <- function(
  ordinal_vec,
  continuous_vec,
  weights,
  active_domain,
  eps = 1e-6,
  ord_name = "ordinal",
  cont_name = "continuous"
) {
  th <- .corr_estimate_thresholds(
    ordinal_vec,
    weights,
    active_domain,
    var_name = ord_name
  )
  stdz <- .corr_weighted_standardize(
    continuous_vec,
    weights,
    active_domain
  )

  w_eff <- weights * active_domain
  w_eff[is.na(w_eff)] <- 0

  objective <- function(rho) {
    out <- .corr_polyserial_loglik(
      rho,
      z = stdz$z,
      ordinal_level_int = th$codes,
      thresholds = th$thresholds,
      weights = w_eff
    )
    out$ll
  }

  probe <- vapply(
    c(-0.9, -0.5, 0, 0.5, 0.9),
    function(r) objective(r),
    numeric(1)
  )
  # nocov start
  # Defensive: with cell_prob_floor = 1e-300, the objective is always finite
  # on realistic inputs; only reachable if callers pass NaN thresholds.
  if (!any(is.finite(probe))) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Numerical optimization did not converge for pair ",
          "({.field {ord_name}}, {.field {cont_name}})."
        ),
        "i" = "Optimizer message: {.val objective not finite at any probe point}.",
        "v" = paste0(
          "Inspect the pair for extreme weight skew, sparse cells, ",
          "or degenerate ordinal coding."
        )
      ),
      class = "surveycore_error_polychoric_optim_failed"
    )
  }
  # nocov end

  fit <- tryCatch(
    stats::optimize(
      objective,
      lower = -1 + eps,
      upper = 1 - eps,
      tol = .Machine$double.eps^0.25,
      maximum = TRUE
    ),
    error = function(e) NULL
  )

  if (is.null(fit) || !is.finite(fit$maximum) || !is.finite(fit$objective)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Numerical optimization did not converge for pair ",
          "({.field {ord_name}}, {.field {cont_name}})."
        ),
        "i" = "Optimizer message: {.val stats::optimize() returned a non-finite result}.",
        "v" = paste0(
          "Inspect the pair for extreme weight skew, sparse cells, ",
          "or degenerate ordinal coding."
        )
      ),
      class = "surveycore_error_polychoric_optim_failed"
    )
  }

  rho_hat <- fit$maximum
  opt_out <- .corr_polyserial_loglik(
    rho_hat,
    z = stdz$z,
    ordinal_level_int = th$codes,
    thresholds = th$thresholds,
    weights = w_eff
  )

  list(
    rho = rho_hat,
    converged = TRUE,
    thresholds = th$thresholds,
    levels_used = th$levels_used,
    mean_w = stdz$mean_w,
    sd_w = stdz$sd_w,
    z = stdz$z,
    ordinal_codes = th$codes,
    log_lik = opt_out$ll,
    any_floor_active = opt_out$any_floor_active,
    dropped_levels = th$dropped_levels
  )
}
