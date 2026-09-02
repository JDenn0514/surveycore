# R/analysis-corr-latent.R
#
# Internal primitives for weighted polychoric and polyserial correlation
# under complex survey designs (Mannan 2025; Olsson 1979; Cox 1974).
#
# Functions:
#   .corr_detect_ordinal()           — classify a column by type
#   .corr_canonicalize_polyserial()  — assign ordinal/continuous roles
#   .corr_estimate_thresholds()      — weighted marginal threshold estimation
#   .corr_weighted_standardize()     — weighted standardization (Cox 1974)
#   .corr_bivnorm_cdf_grid()         — vectorised bivariate-normal CDF grid
#   .corr_cell_prob_matrix()         — polychoric cell-probability matrix
#   .corr_polychoric_loglik()        — weighted log-likelihood (polychoric)
#   .corr_polyserial_loglik()        — weighted log-likelihood (polyserial)
#   .corr_count_sparse_cells()       — detect sparse ordinal cells
#   .corr_polychoric_fit_core()      — shared MLE core (full fit + delta refit)
#   .corr_polychoric_mle()           — MLE for polychoric rho
#   .corr_polyserial_mle()           — MLE for polyserial rho
#   .corr_detect_boundary_rho()      — detect boundary rho values
#   .corr_fisher_ci()                — Fisher-z CI construction
#   .corr_polychoric_influence_setup() — delta-refit setup for influence loop
#   .corr_polychoric_delta_refit()   — O(1) delta refit for one perturbed row
#   .corr_influence_pc6_abort()      — shared PC-6 rethrow for influence refits
#   .corr_numerical_influence()      — perturbation-based influence function
#   .corr_taylor_variance_latent()   — Taylor variance for latent methods
#   .corr_replicate_variance_latent() — replicate variance for latent methods
#   .corr_latent_pair()              — dispatcher for one variable pair

# ── .corr_detect_ordinal() ────────────────────────────────────────────────────
#
# Classify a column by type to decide ordinal vs continuous treatment.
#
# Return values:
#   "ordered"         — inherits("ordered")
#   "factor"          — is.factor() && !is.ordered()
#   "integer_ordinal" — is.integer(), or is.double() with every non-NA value
#                       finite and whole, and <= cutoff distinct non-NA values
#   "continuous"      — is.double() with a fractional value, an infinite
#                       value, more than cutoff distinct non-NA values, or no
#                       non-NA value at all
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
    # A whole-valued double within the cardinality limit is an ordinal
    # scale. SPSS, Stata and SAS files store every coded scale as a double,
    # so the earlier "is.double means continuous" rule refused the exact
    # input polychoric correlation exists to serve. This branch mirrors the
    # is.integer branch above and shares its cutoff.
    # is.finite() is load-bearing: trunc(Inf) == Inf is TRUE, so without it
    # an infinite value passes as a whole number and becomes a category.
    if (all(is.finite(non_na)) && all(non_na == trunc(non_na))) {
      n_distinct <- length(unique(non_na))
      if (n_distinct <= integer_cardinality_cutoff) {
        return("integer_ordinal")
      }
    }
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
#   ordinal_vec    — factor / ordered / integer / whole-valued double vector
#                    (row-aligned to data)
#   weights        — numeric vector of nonnegative weights (row-aligned)
#   active_domain  — 0/1 numeric mask (row-aligned); 0 means out-of-domain
#
# Returns: list(
#   thresholds      = numeric(K-1),
#   levels_used     = character|integer|double — retained levels in order,
#   dropped_levels  = character|integer|double — zero-weight levels,
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
#   z[i] = NA_real_. A degenerate sd_w — 0, or non-finite because the column
#   holds an infinite value — yields NaN z values and propagates. Callers
#   inside get_corr() never see the non-finite case: the PC-15 gate in
#   .corr_latent_pair() refuses that column first.
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
  # is.finite() is load-bearing: an infinite value in continuous_vec makes
  # mean_w, var_w and sd_w all NaN, and `NaN > 0` is NA, which aborts the
  # `if` with an untyped base error (issue #208).
  if (is.finite(sd_w) && sd_w > 0) {
    z[use] <- (continuous_vec[use] - mean_w) / sd_w
  } else {
    # Degenerate SD: produce NaN so downstream MLE fails visibly.
    z[use] <- NaN
  }

  list(z = z, mean_w = mean_w, sd_w = sd_w)
}


# ── .corr_bivnorm_cdf_grid() ─────────────────────────────────────────────────
#
# Vectorised bivariate-normal CDF over a full grid of thresholds, at a single
# rho. One call replaces the four scalar `.corr_bivnorm_cdf()` calls per cell
# that both `.corr_polychoric_loglik()` and `.corr_count_sparse_cells()` used
# to make: the (k_x + 1) x (k_y + 1) grid holds every distinct corner, and
# neighbouring cells share corners instead of recomputing them.
#
# Inf-handling conventions (checked in this precedence order — NA beats
# -Inf, so a pair of -Inf and NA gives NA, not 0):
#   1. NA / NaN in a, b, or rho -> NA
#   2. a == -Inf or b == -Inf   -> 0
#   3. a == +Inf and b == +Inf  -> 1
#   4. a == +Inf                -> Φ(b)
#   5. b == +Inf                -> Φ(a)
#   6. otherwise                -> one pbivnorm::pbivnorm() call
# pbivnorm itself does not accept infinite or NA arguments.
#
# Arguments:
#   tx_full — length (k_x + 1) numeric vector of x thresholds, including the
#             -Inf / +Inf sentinels.
#   ty_full — length (k_y + 1) numeric vector of y thresholds, including the
#             -Inf / +Inf sentinels.
#   rho     — scalar correlation.
#
# Returns: (k_x + 1) x (k_y + 1) numeric matrix, grid[i, j] = Φ2(tx_full[i],
# ty_full[j]; rho).
.corr_bivnorm_cdf_grid <- function(tx_full, ty_full, rho) {
  n_a <- length(tx_full)
  n_b <- length(ty_full)
  a_mat <- matrix(tx_full, nrow = n_a, ncol = n_b)
  b_mat <- matrix(ty_full, nrow = n_a, ncol = n_b, byrow = TRUE)

  out <- matrix(NA_real_, nrow = n_a, ncol = n_b)

  # Rule 1: NA / NaN in a, b, or rho -> NA (the default `out` value already).
  assigned <- is.na(a_mat) | is.na(b_mat) | is.na(rho)

  # Rule 2: -Inf on either side -> 0. `!assigned` filters out any position
  # already resolved by rule 1; NA & FALSE evaluates to FALSE in R, so a
  # comparison against an NA-holding cell never overrides its rule-1 result.
  mask <- !assigned & (a_mat == -Inf | b_mat == -Inf)
  out[mask] <- 0
  assigned <- assigned | mask

  # Rule 3: both sides +Inf -> 1.
  mask <- !assigned & (a_mat == Inf & b_mat == Inf)
  out[mask] <- 1
  assigned <- assigned | mask

  # Rule 4: a == +Inf -> Φ(b).
  mask <- !assigned & (a_mat == Inf)
  out[mask] <- stats::pnorm(b_mat[mask])
  assigned <- assigned | mask

  # Rule 5: b == +Inf -> Φ(a).
  mask <- !assigned & (b_mat == Inf)
  out[mask] <- stats::pnorm(a_mat[mask])
  assigned <- assigned | mask

  # Rule 6: everything remaining is finite. One vectorised pbivnorm() call.
  remaining <- !assigned
  if (any(remaining)) {
    out[remaining] <- pbivnorm::pbivnorm(
      a_mat[remaining],
      b_mat[remaining],
      rho = rho
    )
  }

  out
}


# ── .corr_cell_prob_matrix() ─────────────────────────────────────────────────
#
# Forms the k_x x k_y polychoric cell-probability matrix by differencing four
# shifted sub-matrices of a CDF grid from `.corr_bivnorm_cdf_grid()`:
#   π_{m,p} = grid[m+1, p+1] - grid[m, p+1] - grid[m+1, p] + grid[m, p]
# Shared by `.corr_polychoric_loglik()` and `.corr_count_sparse_cells()` so
# neither carries its own copy of the differencing.
#
# Arguments:
#   grid — (k_x + 1) x (k_y + 1) matrix from `.corr_bivnorm_cdf_grid()`.
#
# Returns: k_x x k_y numeric matrix of cell probabilities.
.corr_cell_prob_matrix <- function(grid) {
  k_x <- nrow(grid) - 1L
  k_y <- ncol(grid) - 1L
  hi_hi <- grid[2:(k_x + 1L), 2:(k_y + 1L), drop = FALSE]
  lo_hi <- grid[1:k_x, 2:(k_y + 1L), drop = FALSE]
  hi_lo <- grid[2:(k_x + 1L), 1:k_y, drop = FALSE]
  lo_lo <- grid[1:k_x, 1:k_y, drop = FALSE]
  hi_hi - lo_hi - hi_lo + lo_lo
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
  # Full threshold vectors with -Inf / +Inf sentinels.
  tx_full <- c(-Inf, thresholds_x, Inf)
  ty_full <- c(-Inf, thresholds_y, Inf)

  grid <- .corr_bivnorm_cdf_grid(tx_full, ty_full, rho)
  cell_prob <- .corr_cell_prob_matrix(grid)

  # 0 * log(anything) treated as 0: cells with zero weight contribute nothing
  # to `ll` and never set `any_floor_active`, floored or not.
  w_pos <- cell_weights > 0
  floor_mask <- is.na(cell_prob) | cell_prob < cell_prob_floor
  cell_prob[floor_mask] <- cell_prob_floor
  any_floor_active <- any(floor_mask & w_pos)

  # Accumulate in the same (row m outer, column p inner) order, with the
  # same double-precision `+=` steps, that the original per-cell loop used.
  # `sum()` runs a long-double accumulator internally and would move `ll`
  # by about 1 ULP — inside the 1e-8 tolerance the direct tests pin `ll`
  # at, but the influence loop divides by `eps_pert` (1e-4), so even a
  # last-bit shift in the full-sample fit gets amplified 1e4x across every
  # perturbation. The explicit loop keeps `ll`, and everything downstream
  # of it, bit-identical to the pre-vectorisation code.
  w_t <- t(cell_weights)
  p_t <- t(cell_prob)
  pos_t <- t(w_pos)
  terms <- w_t[pos_t] * log(p_t[pos_t])
  ll <- 0
  for (term in terms) {
    ll <- ll + term
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
#   ord_x_vec      — ordinal x (factor/ordered/integer/whole double)
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
  y_name = "y",
  refit = FALSE
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

  core <- .corr_polychoric_fit_core(
    cell_counts = cell_counts,
    thresholds_x = th_x$thresholds,
    thresholds_y = th_y$thresholds,
    eps = eps,
    refit = refit,
    x_name = x_name,
    y_name = y_name
  )

  list(
    rho = core$rho,
    converged = TRUE,
    thresholds_x = th_x$thresholds,
    thresholds_y = th_y$thresholds,
    levels_x = th_x$levels_used,
    levels_y = th_y$levels_used,
    cell_counts = cell_counts,
    n_cells_obs = as.integer(n_cells_obs),
    n_sparse_cells = core$n_sparse_cells,
    log_lik = core$log_lik,
    any_floor_active = core$any_floor_active,
    dropped_levels_x = th_x$dropped_levels,
    dropped_levels_y = th_y$dropped_levels
  )
}


# ── .corr_polychoric_fit_core() ──────────────────────────────────────────────
#
# Shared objective + probe + optimize + error-handling core for the
# polychoric MLE. `.corr_polychoric_mle()` calls this for the full fit; the
# delta refit in `.corr_numerical_influence()` (Step 3) calls it again with
# delta-updated `cell_counts` / thresholds, so both paths run the identical
# optimization code.
#
# Arguments:
#   cell_counts             — K_x × K_y weighted matrix.
#   thresholds_x, thresholds_y — interior threshold vectors.
#   eps                     — boundary offset for the optimizer bounds.
#   refit                   — when TRUE, skip the 5-point probe and the
#                              sparse-cell count (Step 2); `n_sparse_cells`
#                              comes back `NA_integer_`.
#   x_name, y_name          — for diagnostics and error messages.
#
# Returns: list(rho, log_lik, any_floor_active, n_sparse_cells).
#
# Errors:
#   PC-6 surveycore_error_polychoric_optim_failed if the optimizer returns
#        non-finite / boundary results or the objective is not finite at a
#        sentinel test point.
.corr_polychoric_fit_core <- function(
  cell_counts,
  thresholds_x,
  thresholds_y,
  eps,
  refit,
  x_name,
  y_name
) {
  # Objective: weighted log-likelihood as a function of ρ.
  objective <- function(rho) {
    out <- .corr_polychoric_loglik(
      rho,
      cell_weights = cell_counts,
      thresholds_x = thresholds_x,
      thresholds_y = thresholds_y
    )
    out$ll
  }

  if (!refit) {
    # Guard: objective must be finite somewhere before handing off to
    # optimize(). Skipped on a refit — Step 0.5 (check B) confirmed the
    # refit caller reads nothing this guard feeds.
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
  }

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
    thresholds_x = thresholds_x,
    thresholds_y = thresholds_y
  )

  # Count cells whose modeled probability at ρ̂ is below the sparse tolerance
  # (1e-12 per spec). Cells with zero weight are ignored. Skipped on a
  # refit — the influence loop reads only `$rho` (Step 0.5, check B).
  n_sparse <- if (refit) {
    NA_integer_
  } else {
    as.integer(.corr_count_sparse_cells(
      rho_hat,
      cell_counts,
      thresholds_x,
      thresholds_y,
      tol = 1e-12
    ))
  }

  list(
    rho = rho_hat,
    log_lik = opt_out$ll,
    any_floor_active = opt_out$any_floor_active,
    n_sparse_cells = n_sparse
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
  tx_full <- c(-Inf, thresholds_x, Inf)
  ty_full <- c(-Inf, thresholds_y, Inf)
  grid <- .corr_bivnorm_cdf_grid(tx_full, ty_full, rho)
  cell_prob <- .corr_cell_prob_matrix(grid)

  w_pos <- cell_counts > 0
  sparse_mask <- w_pos & (is.na(cell_prob) | cell_prob < tol)
  n_sparse <- as.integer(sum(sparse_mask))
  n_sparse
}


# ── .corr_polyserial_mle() ────────────────────────────────────────────────────
#
# Two-step polyserial MLE: standardize the continuous variable, estimate
# thresholds from the ordinal marginals, then maximize the weighted
# log-likelihood over ρ via stats::optimize().
#
# Arguments:
#   ordinal_vec    — ordinal (factor/ordered/integer/whole double)
#   continuous_vec — numeric, row-aligned
#   weights        — numeric weights, row-aligned
#   active_domain  — 0/1 numeric mask, row-aligned
#   eps            — boundary offset for the optimizer bounds
#   ord_name, cont_name — for diagnostics and error messages
#   refit          — when TRUE, skip the 5-point probe (Step 2). The
#                     influence loop's refits pass TRUE.
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
  cont_name = "continuous",
  refit = FALSE
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

  if (!refit) {
    probe <- vapply(
      c(-0.9, -0.5, 0, 0.5, 0.9),
      function(r) objective(r),
      numeric(1)
    )
    # nocov start
    # Defensive: with cell_prob_floor = 1e-300, the objective is always
    # finite on realistic inputs; only reachable if callers pass NaN
    # thresholds.
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
  }

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


# =============================================================================
# PR 2: Variance paths and pair-level dispatcher
# =============================================================================
#
# Functions added in PR 2:
#   .corr_detect_boundary_rho()        — boundary detector for rho
#   .corr_numerical_influence()        — perturbation-based Fisher-z IF
#   .corr_taylor_variance_latent()     — HT/Hajek Taylor variance on z scale
#   .corr_replicate_variance_latent()  — per-replicate MLE loop variance
#   .corr_fisher_ci()                  — Fisher-z CI back-transform (shared)
#   .corr_latent_pair()                — pair-level dispatcher

# ── .corr_detect_boundary_rho() ──────────────────────────────────────────────
#
# TRUE iff `abs(rho)` is within `eps` of 1 (boundary of parameter space).
# Deterministic, side-effect free, scalar-in / scalar-out.
#
# Note on `eps`: The spec calls for `eps = 1e-6`, matching the optimizer
# clamp used inside `.corr_polychoric_mle()` and `.corr_polyserial_mle()`.
# In practice `stats::optimize()` with `tol = .Machine$double.eps^0.25`
# converges to about `4.2e-5` away from the upper bound, so any ρ̂ returned
# by the MLE that is `> 1 - 1e-4` is effectively at the boundary. The
# default `eps = 1e-4` here reflects the optimizer's achievable resolution
# while still detecting genuine boundary saturation.
.corr_detect_boundary_rho <- function(rho, eps = 1e-4) {
  if (!is.finite(rho)) {
    return(FALSE)
  }
  abs(rho) > 1 - eps
}


# ── .corr_fisher_ci() ────────────────────────────────────────────────────────
#
# Fisher-z confidence-interval back-transform to the rho scale, truncated to
# the admissible [-1, 1] range (Mannan 2025 §8.1-8.2).
#
# Arguments:
#   rho_hat    — scalar ρ̂ on the ρ scale (used only for the fallback when
#                `se_z` is NA; Fisher-z CI is built from atanh(rho_hat)).
#   se_z       — SE on the Fisher-z scale.
#   conf_level — numeric(1) in (0, 1); default 0.95.
#
# Returns: list(ci_low, ci_high, rho_z, se_z). When inputs are NA, CI bounds
# are NA.
.corr_fisher_ci <- function(rho_hat, se_z, conf_level = 0.95) {
  if (is.na(rho_hat) || is.na(se_z)) {
    return(list(
      ci_low = NA_real_,
      ci_high = NA_real_,
      rho_z = NA_real_,
      se_z = NA_real_
    ))
  }
  rho_z <- atanh(rho_hat)
  z_crit <- stats::qnorm((1 + conf_level) / 2)
  ci_low <- tanh(rho_z - z_crit * se_z)
  ci_high <- tanh(rho_z + z_crit * se_z)
  # Truncate to admissible range.
  ci_low <- max(-1, min(1, ci_low))
  ci_high <- max(-1, min(1, ci_high))
  list(ci_low = ci_low, ci_high = ci_high, rho_z = rho_z, se_z = se_z)
}


# ── .corr_polychoric_influence_setup() ───────────────────────────────────────
#
# Delta-refit setup for the polychoric path of `.corr_numerical_influence()`
# (Step 3). Computed once, from the unperturbed data, so each of the n
# refits below touches only what perturbing one row changes: one level sum
# per margin and one cell, instead of rebuilding both O(n) threshold
# estimations and the O(n) cell-count loop from scratch.
#
# Arguments:
#   vec_a, vec_b — full-length ordinal x / ordinal y vectors.
#   w_full       — full-length raw weight vector.
#   active_lgl   — full-length logical active-domain mask.
#
# Returns: list(
#   codes_x, codes_y     — full-length remapped level codes (NA excluded).
#   w_eff                — full-length effective weight (w_full * active,
#                           NA -> 0).
#   level_sum_x, level_sum_y — base per-level weight sums, length K_x / K_y.
#   idx_level_x, idx_level_y — list of row-index vectors per level.
#   cell_counts          — base K_x x K_y weighted cell-count matrix.
#   cell_members         — K_x x K_y list-matrix of row-index vectors, in
#                           increasing row order.
#   thresholds_x, thresholds_y — base interior threshold vectors.
# )
.corr_polychoric_influence_setup <- function(vec_a, vec_b, w_full, active_lgl) {
  th_x <- .corr_estimate_thresholds(vec_a, w_full, active_lgl, var_name = "x")
  th_y <- .corr_estimate_thresholds(vec_b, w_full, active_lgl, var_name = "y")

  k_x <- length(th_x$levels_used)
  k_y <- length(th_y$levels_used)
  codes_x <- th_x$codes
  codes_y <- th_y$codes

  w_eff <- w_full * active_lgl
  w_eff[is.na(w_eff)] <- 0

  idx_level_x <- lapply(seq_len(k_x), function(k) which(codes_x == k))
  idx_level_y <- lapply(seq_len(k_y), function(k) which(codes_y == k))

  use_cell <- !is.na(codes_x) & !is.na(codes_y) & w_eff > 0
  cell_counts <- matrix(0, nrow = k_x, ncol = k_y)
  cell_members <- vector("list", k_x * k_y)
  dim(cell_members) <- c(k_x, k_y)
  for (i in which(use_cell)) {
    m <- codes_x[[i]]
    p <- codes_y[[i]]
    cell_counts[m, p] <- cell_counts[m, p] + w_eff[[i]]
    cell_members[[m, p]] <- c(cell_members[[m, p]], i)
  }

  list(
    codes_x = codes_x,
    codes_y = codes_y,
    w_eff = w_eff,
    level_sum_x = th_x$level_weights_used,
    level_sum_y = th_y$level_weights_used,
    idx_level_x = idx_level_x,
    idx_level_y = idx_level_y,
    cell_counts = cell_counts,
    cell_members = cell_members,
    thresholds_x = th_x$thresholds,
    thresholds_y = th_y$thresholds
  )
}


# ── .corr_polychoric_delta_refit() ───────────────────────────────────────────
#
# O(1) (per row, not O(n)) refit for one perturbed row, using the setup from
# `.corr_polychoric_influence_setup()`. Perturbing row `i` by `w * (1 +
# eps_pert)` changes at most one level sum per margin and one cell; recompute
# only those, rebuild the two small (length K) threshold vectors, and hand
# the delta-updated `cell_counts` / thresholds to the same
# `.corr_polychoric_fit_core()` the full fit uses.
#
# Edge rows:
#   - NA code on one margin: update only the other margin's level sum, no
#     cell.
#   - NA code on both margins, or zero effective weight: no updates at all.
#     The optimizer still runs on the (numerically unchanged) perturbed
#     data, so the result equals the full fit exactly rather than being
#     shortcut to an assumed IF = 0.
#
# The affected level sum is recomputed via `sum()` over the (small) subset
# of `w_eff` values for that level, with row `i`'s entry replaced — the same
# call shape `.corr_estimate_thresholds()` uses today. The affected cell is
# recomputed via an explicit `+=` loop over its member indices in increasing
# row order, not `sum()`: Step 0.5 (check C) showed `sum()` diverges from
# the `+=` loop on lognormal weights.
#
# Arguments:
#   setup    — list from `.corr_polychoric_influence_setup()`.
#   i        — integer(1), the perturbed row's index into `w_full`.
#   w_full   — full-length raw weight vector (unperturbed).
#   eps_pert — perturbation magnitude.
#
# Returns: list(rho, log_lik, any_floor_active, n_sparse_cells) — the
# `.corr_polychoric_fit_core()` contract, always with `refit = TRUE`.
.corr_polychoric_delta_refit <- function(setup, i, w_full, eps_pert) {
  m <- setup$codes_x[[i]]
  p <- setup$codes_y[[i]]
  w_eff_i <- setup$w_eff[[i]]

  thresholds_x <- setup$thresholds_x
  thresholds_y <- setup$thresholds_y
  cell_counts <- setup$cell_counts

  if (w_eff_i > 0 && (!is.na(m) || !is.na(p))) {
    w_eff_pert_i <- w_full[[i]] * (1 + eps_pert)

    if (!is.na(m)) {
      idx_m <- setup$idx_level_x[[m]]
      w_sub <- setup$w_eff[idx_m]
      w_sub[idx_m == i] <- w_eff_pert_i
      level_sum_x <- setup$level_sum_x
      level_sum_x[[m]] <- sum(w_sub, na.rm = TRUE)
      total_w_x <- sum(level_sum_x)
      cum_prop_x <- cumsum(level_sum_x) / total_w_x
      thresholds_x <- stats::qnorm(cum_prop_x[-length(cum_prop_x)])
    }

    if (!is.na(p)) {
      idx_p <- setup$idx_level_y[[p]]
      w_sub <- setup$w_eff[idx_p]
      w_sub[idx_p == i] <- w_eff_pert_i
      level_sum_y <- setup$level_sum_y
      level_sum_y[[p]] <- sum(w_sub, na.rm = TRUE)
      total_w_y <- sum(level_sum_y)
      cum_prop_y <- cumsum(level_sum_y) / total_w_y
      thresholds_y <- stats::qnorm(cum_prop_y[-length(cum_prop_y)])
    }

    if (!is.na(m) && !is.na(p)) {
      members <- setup$cell_members[[m, p]]
      total <- 0
      for (j in members) {
        total <- total + if (identical(j, i)) w_eff_pert_i else setup$w_eff[[j]]
      }
      cell_counts[m, p] <- total
    }
  }

  .corr_polychoric_fit_core(
    cell_counts = cell_counts,
    thresholds_x = thresholds_x,
    thresholds_y = thresholds_y,
    eps = 1e-6,
    refit = TRUE,
    x_name = "x",
    y_name = "y"
  )
}


# ── .corr_influence_pc6_abort() ──────────────────────────────────────────────
#
# Shared PC-6 rethrow for `.corr_numerical_influence()`: both the polychoric
# and the polyserial refit loop catch an inner MLE failure and re-raise it
# pointing at the perturbed row.
#
# Arguments:
#   fit_pert — the caught condition object (an "error").
#   i        — integer(1), the row index that failed.
.corr_influence_pc6_abort <- function(fit_pert, i) {
  cli::cli_abort(
    c(
      "x" = paste0(
        "Numerical optimization did not converge during ",
        "influence-function computation."
      ),
      "i" = paste0(
        "Perturbation at row {.val {i}} failed: ",
        "{.val {conditionMessage(fit_pert)}}"
      ),
      "v" = paste0(
        "Inspect the pair for extreme weight skew, sparse cells, ",
        "or degenerate ordinal coding."
      )
    ),
    class = "surveycore_error_polychoric_optim_failed"
  )
}


# ── .corr_numerical_influence() ──────────────────────────────────────────────
#
# Perturbation-based numerical influence function on the Fisher-z scale:
#   IF_i ≈ (atanh(ρ̂_pert_i) - atanh(ρ̂_full)) / ε
# where ρ̂_pert_i is the MLE with w_i replaced by w_i * (1 + ε).
#
# The polychoric path (Step 3) uses a delta refit — `.corr_polychoric_
# influence_setup()` once, then `.corr_polychoric_delta_refit()` per row —
# instead of calling `.corr_polychoric_mle()` from scratch for every row.
# The polyserial path is unchanged except that its MLE call now passes
# `refit = TRUE` (Step 2): its likelihood is already O(n) per evaluation by
# nature, so a delta setup would not save anything there.
#
# Arguments:
#   design          — survey_taylor (used for @data and @variables$weights)
#   method          — "polychoric" or "polyserial"
#   vec_a, vec_b    — full-length vectors. For polychoric, both are ordinal
#                     (factor / ordered / integer / whole double). For
#                     polyserial, `vec_a` is the ordinal side and `vec_b` is
#                     the raw continuous variable (not pre-standardized).
#   active_domain   — logical or 0/1 mask aligned to @data rows.
#   rho_hat_full    — full-sample ρ̂ (on the ρ scale).
#   eps_pert        — perturbation magnitude; default 1e-4.
#
# Returns: numeric of length `sum(active_domain)`.
#
# Errors: propagates surveycore_error_polychoric_optim_failed (PC-6) if any
# inner MLE fails.
.corr_numerical_influence <- function(
  design,
  method,
  vec_a,
  vec_b,
  active_domain,
  rho_hat_full,
  eps_pert = 1e-4
) {
  w_full <- design@data[[design@variables$weights]]
  active_lgl <- as.logical(active_domain)
  active_idx <- which(active_lgl)
  n_active <- length(active_idx)

  rho_z_full <- atanh(rho_hat_full)
  ifs <- numeric(n_active)

  if (identical(method, "polychoric")) {
    setup <- .corr_polychoric_influence_setup(vec_a, vec_b, w_full, active_lgl)

    for (k in seq_len(n_active)) {
      i <- active_idx[[k]]
      fit_pert <- tryCatch(
        .corr_polychoric_delta_refit(setup, i, w_full, eps_pert),
        error = function(e) e
      )
      if (inherits(fit_pert, "error")) {
        .corr_influence_pc6_abort(fit_pert, i)
      }
      rho_z_pert <- atanh(fit_pert$rho)
      ifs[[k]] <- (rho_z_pert - rho_z_full) / eps_pert
    }

    return(ifs)
  }

  for (k in seq_len(n_active)) {
    i <- active_idx[[k]]
    w_pert <- w_full
    w_pert[[i]] <- w_pert[[i]] * (1 + eps_pert)

    fit_pert <- tryCatch(
      .corr_polyserial_mle(
        vec_a,
        vec_b,
        w_pert,
        active_lgl,
        ord_name = "ord",
        cont_name = "cont",
        refit = TRUE
      ),
      error = function(e) e
    )
    if (inherits(fit_pert, "error")) {
      .corr_influence_pc6_abort(fit_pert, i)
    }
    rho_z_pert <- atanh(fit_pert$rho)
    ifs[[k]] <- (rho_z_pert - rho_z_full) / eps_pert
  }

  ifs
}


# ── .corr_taylor_variance_latent() ───────────────────────────────────────────
#
# Design-based Taylor variance on the Fisher-z scale, reusing the existing
# HT / Hájek machinery (see .vcov_pair_taylor() in R/analysis-corr-helpers.R;
# both paths drive .svy_recvar() with a cluster/strata/FPC matrix built
# from the design).
#
# The influence function `IF_i` is treated as the score for a weighted total
# estimator: Var(ζ̂) = Var(Σ w_i · IF_i) under the design. `var_z_srs` is
# the same HT machinery applied with design weights replaced by 1 — used
# for `deff` computation (no MLE re-fit).
#
# Arguments:
#   design        — survey_taylor.
#   if_z          — numeric length `sum(active_domain)`; Fisher-z IF values.
#   w             — full-length weight vector (aligned to @data rows).
#                   (Not used directly; design weights come from `design`.)
#   active_domain — logical or 0/1 mask aligned to @data rows.
#
# Returns: list(var_z, var_z_srs).
.corr_taylor_variance_latent <- function(
  design,
  if_z,
  w,
  active_domain
) {
  data <- design@data
  vars <- design@variables
  w_full <- data[[vars$weights]]
  active_lgl <- as.logical(active_domain)

  # Expand if_z (length = sum(active)) to full length: 0 out-of-domain.
  if_full <- numeric(nrow(data))
  if_full[active_lgl] <- if_z

  # Build full-length cluster/strata/FPC matrices for .svy_recvar().
  mats <- .build_cluster_matrices(data, vars)
  lonely.psu <- getOption("survey.lonely.psu", "remove")

  infl_mat <- matrix(w_full * if_full, ncol = 1L)
  v <- .svy_recvar(
    infl_mat,
    mats$clusters_mat,
    mats$strata_mat,
    mats$fpcs,
    lonely.psu = lonely.psu
  )
  var_z <- v[[1L, 1L]]

  # SRS-equivalent variance: unit weights, same influence function values.
  w_srs <- rep(1, nrow(data))
  infl_mat_srs <- matrix(w_srs * if_full, ncol = 1L)
  v_srs <- .svy_recvar(
    infl_mat_srs,
    mats$clusters_mat,
    mats$strata_mat,
    mats$fpcs,
    lonely.psu = lonely.psu
  )
  var_z_srs <- v_srs[[1L, 1L]]

  list(var_z = var_z, var_z_srs = var_z_srs)
}


# ── .corr_replicate_variance_latent() ────────────────────────────────────────
#
# Replicate-weight variance on the Fisher-z scale. Per replicate, re-run the
# two-step MLE (thresholds then rho) and record ζ̂^{(r)} = atanh(ρ̂^{(r)}).
# Variance is computed from the design's `scale` and `rscales` using the
# vendored .svy_rep_var() path (identical to the one used elsewhere in
# surveycore).
#
# Emits PC-12 if 0 < n_failed <= 0.2*R. Raises PC-8 if n_failed/R > 0.2 or
# n_ok == 0.
#
# `var_z_srs` is computed by the same replicate loop using a per-row unit
# weight (w_i = 1) baseline so that `deff` is well-defined.
.corr_replicate_variance_latent <- function(
  design,
  method,
  vec_a,
  vec_b,
  active_domain,
  rho_hat_full
) {
  data <- design@data
  vars <- design@variables
  rep_cols <- vars$repweights
  R <- length(rep_cols)
  scale <- vars$scale
  rscales <- if (!is.null(vars$rscales)) vars$rscales else rep(1L, R)
  active_lgl <- as.logical(active_domain)

  rho_z_full <- atanh(rho_hat_full)
  thetas_z <- rep(NA_real_, R)

  for (r in seq_len(R)) {
    w_r <- data[[rep_cols[[r]]]]
    fit_r <- tryCatch(
      if (identical(method, "polychoric")) {
        .corr_polychoric_mle(
          vec_a,
          vec_b,
          w_r,
          active_lgl,
          x_name = "x",
          y_name = "y",
          refit = TRUE
        )
      } else {
        .corr_polyserial_mle(
          vec_a,
          vec_b,
          w_r,
          active_lgl,
          ord_name = "ord",
          cont_name = "cont",
          refit = TRUE
        )
      },
      error = function(e) NULL
    )
    if (!is.null(fit_r) && is.finite(fit_r$rho)) {
      thetas_z[[r]] <- atanh(fit_r$rho)
    }
  }

  n_failed <- sum(is.na(thetas_z))
  n_ok <- R - n_failed
  fail_rate <- n_failed / max(R, 1L)

  if (n_ok == 0L || fail_rate > 0.20) {
    pct <- round(100 * fail_rate, 1)
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.val {n_failed}} of {.val {R}} replicate fit{?s} failed to ",
          "converge ({.val {pct}}%)."
        ),
        "i" = "Threshold for hard failure is {.val 20}% of replicates.",
        "v" = paste0(
          "Inspect the design's replicate weights or reduce the ",
          "number of ordinal levels."
        )
      ),
      class = "surveycore_error_replicate_convergence_failure"
    )
  }

  if (n_failed > 0L) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "{.val {n_failed}} of {.val {R}} replicate fit{?s} failed ",
          "to converge."
        ),
        "i" = paste0(
          "Variance is computed over the {.val {n_ok}} successful ",
          "replicate(s). See {.code meta(result)$n_failed_replicates_total}."
        )
      ),
      class = "surveycore_warning_polychoric_replicate_convergence"
    )
  }

  var_z <- .svy_rep_var(
    thetas_z,
    scale = scale,
    rscales = rscales,
    mse = TRUE,
    coef = rho_z_full
  )

  # SRS-equivalent: re-run the MLE loop with unit weights per replicate.
  # Mannan (2025) doesn't prescribe a deff for latent-variable correlations.
  # We adopt the surveycore convention: use the same replicate structure with
  # a constant-1 base weight, giving a design-free reference variance.
  thetas_z_srs <- rep(NA_real_, R)
  unit_w <- rep(1, nrow(data))
  # Full-sample estimate under unit weights
  fit_srs_full <- tryCatch(
    if (identical(method, "polychoric")) {
      .corr_polychoric_mle(
        vec_a,
        vec_b,
        unit_w,
        active_lgl,
        x_name = "x",
        y_name = "y"
      )
    } else {
      .corr_polyserial_mle(
        vec_a,
        vec_b,
        unit_w,
        active_lgl,
        ord_name = "ord",
        cont_name = "cont"
      )
    },
    error = function(e) NULL
  )
  # nocov start
  # Defensive: the full-weight MLE succeeded already; the unit-weight MLE is
  # a weaker variant and typically also succeeds on any data that produced
  # a valid full-sample estimate.
  if (is.null(fit_srs_full) || !is.finite(fit_srs_full$rho)) {
    var_z_srs <- NA_real_
  } else {
    # nocov end
    rho_z_srs_full <- atanh(fit_srs_full$rho)
    for (r in seq_len(R)) {
      # Under "SRS", every respondent's replicate contribution is equal —
      # we simulate this by using the same per-row replicate weight ratios
      # applied to unit weights. Concretely: rescale w_r by the ratio
      # w_r / w_full for each row that has a positive full weight, so the
      # design structure (which rows get down-weighted in replicate r) is
      # preserved.
      w_full <- data[[vars$weights]]
      w_r <- data[[rep_cols[[r]]]]
      # Avoid divide-by-zero.
      safe_ratio <- ifelse(w_full > 0, w_r / w_full, 0)
      w_r_srs <- unit_w * safe_ratio
      fit_r <- tryCatch(
        if (identical(method, "polychoric")) {
          .corr_polychoric_mle(
            vec_a,
            vec_b,
            w_r_srs,
            active_lgl,
            x_name = "x",
            y_name = "y",
            refit = TRUE
          )
        } else {
          .corr_polyserial_mle(
            vec_a,
            vec_b,
            w_r_srs,
            active_lgl,
            ord_name = "ord",
            cont_name = "cont",
            refit = TRUE
          )
        },
        error = function(e) NULL
      )
      if (!is.null(fit_r) && is.finite(fit_r$rho)) {
        thetas_z_srs[[r]] <- atanh(fit_r$rho)
      }
    }
    if (all(is.na(thetas_z_srs))) {
      var_z_srs <- NA_real_ # nocov
    } else {
      var_z_srs <- tryCatch(
        .svy_rep_var(
          thetas_z_srs,
          scale = scale,
          rscales = rscales,
          mse = TRUE,
          coef = rho_z_srs_full
        ),
        error = function(e) NA_real_ # nocov
      )
    }
  }

  list(
    var_z = var_z,
    var_z_srs = var_z_srs,
    n_ok = as.integer(n_ok),
    n_failed = as.integer(n_failed)
  )
}


# ── .corr_latent_pair() ──────────────────────────────────────────────────────
#
# Pair-level dispatcher for polychoric / polyserial correlation.
#
# Step order:
#   1. PC-7 gate for survey_twophase and survey_nonprob without repweights.
#   2. Canonicalize (polyserial only).
#   3. PC-1 gate for polychoric (reject non-ordinal).
#   4. PC-13 warning when any side is unordered factor.
#   5. Pairwise-complete active domain.
#   6. PC-15 gate for polyserial (reject a non-finite continuous side).
#   7. MLE on the pair (propagates PC-4 / PC-5 / PC-6 / PC-10 / PC-11).
#   8. Variance path by design class (PC-12, PC-8 propagated from replicate).
#   9. PC-9 warning when ρ̂ is boundary; PC-14 additionally on survey_taylor.
#  10. CI via .corr_fisher_ci(); truncated to [-1, 1].
#
# Returns: list with 10 fields
#   r, se_r, se_srs, n, n_weighted, ci_low, ci_high, rho_z, se_z, method.
.corr_latent_pair <- function(
  design,
  x_col,
  y_col,
  method,
  active_domain = NULL,
  na.rm = TRUE,
  conf_level = 0.95
) {
  # 1. PC-7 gate — before any MLE work.
  if (S7::S7_inherits(design, survey_twophase)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.code method = {.val {method}}} is not supported for ",
          "{.cls {class(design)[[1L]]}} designs."
        ),
        "v" = paste0(
          "Use {.code method = \"pearson\"}, or call {.fn get_corr} on a ",
          "{.cls survey_taylor} or {.cls survey_replicate} design."
        )
      ),
      class = "surveycore_error_polychoric_design_unsupported"
    )
  }
  if (
    S7::S7_inherits(design, survey_nonprob) &&
      is.null(design@variables$repweights)
  ) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.code method = {.val {method}}} is not supported for ",
          "{.cls {class(design)[[1L]]}} designs without replicate weights."
        ),
        "i" = paste0(
          "Supply bootstrap replicate weights via {.arg repweights} in ",
          "{.fn as_survey_nonprob} to use this method."
        ),
        "v" = paste0(
          "Use {.code method = \"pearson\"}, or supply replicate weights."
        )
      ),
      class = "surveycore_error_polychoric_design_unsupported"
    )
  }

  data <- design@data
  n_full <- nrow(data)
  if (is.null(active_domain)) {
    active_domain <- rep(TRUE, n_full)
  }

  # 2. Canonicalize (polyserial) / PC-1 gate (polychoric).
  if (identical(method, "polyserial")) {
    roles <- .corr_canonicalize_polyserial(x_col, y_col, data)
    ord_name <- roles$ordinal_name
    cont_name <- roles$continuous_name
  } else {
    # polychoric: each side must be ordinal.
    type_x <- .corr_detect_ordinal(data[[x_col]])
    type_y <- .corr_detect_ordinal(data[[y_col]])
    ordinal_types <- c("ordered", "factor", "integer_ordinal")
    bad <- character(0)
    if (!(type_x %in% ordinal_types)) {
      bad <- c(bad, x_col)
    }
    if (!(type_y %in% ordinal_types)) {
      bad <- c(bad, y_col)
    }
    if (length(bad) > 0L) {
      bad_classes <- vapply(bad, function(nm) class(data[[nm]])[[1L]], "")
      n_bad <- length(bad)
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.code method = \"polychoric\"} requires ordinal variables. ",
            "Non-ordinal {cli::qty(n_bad)}column{?s}: {.field {bad}} ",
            "({.cls {bad_classes}})."
          ),
          "v" = paste0(
            "Coerce to {.cls factor} or {.cls ordered}, or use ",
            "{.code method = \"pearson\"}."
          )
        ),
        class = "surveycore_error_polychoric_requires_ordinal"
      )
    }
    ord_name <- x_col
    cont_name <- y_col
  }

  # 3. PC-13 — warn on unordered factors (both methods, ordinal side(s) only).
  if (identical(method, "polychoric")) {
    for (nm in c(x_col, y_col)) {
      col <- data[[nm]]
      if (is.factor(col) && !is.ordered(col)) {
        cli::cli_warn(
          c(
            "!" = paste0(
              "Variable {.field {nm}} is an unordered {.cls factor}; using ",
              "{.fn levels} order for thresholds."
            ),
            "v" = paste0(
              "Coerce to {.cls ordered} to make the level order explicit."
            )
          ),
          class = "surveycore_warning_polychoric_unordered_factor"
        )
      }
    }
  } else {
    col <- data[[ord_name]]
    if (is.factor(col) && !is.ordered(col)) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "Variable {.field {ord_name}} is an unordered {.cls factor}; ",
            "using {.fn levels} order for thresholds."
          ),
          "v" = paste0(
            "Coerce to {.cls ordered} to make the level order explicit."
          )
        ),
        class = "surveycore_warning_polychoric_unordered_factor"
      )
    }
  }

  # 4. Pairwise-complete active domain.
  x_col_vec <- data[[x_col]]
  y_col_vec <- data[[y_col]]
  active_lgl <- as.logical(active_domain)
  if (isTRUE(na.rm)) {
    pair_active <- active_lgl & !is.na(x_col_vec) & !is.na(y_col_vec)
  } else {
    pair_active <- active_lgl
  }

  w_full <- data[[design@variables$weights]]
  n_pair <- sum(pair_active)
  n_w <- sum(w_full[pair_active], na.rm = TRUE)

  # 5. All-NA pair: early return with NA fields.
  if (n_pair == 0L) {
    return(list(
      r = NA_real_,
      se_r = NA_real_,
      se_srs = NA_real_,
      n = 0L,
      n_weighted = 0,
      ci_low = NA_real_,
      ci_high = NA_real_,
      rho_z = NA_real_,
      se_z = NA_real_,
      method = method
    ))
  }

  # 6. PC-15 gate — the continuous side must be finite on the analysed rows.
  # NA and NaN need no gate: .corr_weighted_standardize() drops them through
  # its !is.na() filter in both na.rm modes. Only an infinite value reaches
  # the moment sums, where it makes mean_w, var_w and sd_w all NaN.
  # The ordinal side needs no gate either: .corr_detect_ordinal() classifies
  # any Inf-carrying double as "continuous", and factor / ordered / integer
  # cannot hold an infinite value, so a canonicalized ordinal side is always
  # finite.
  if (identical(method, "polyserial")) {
    cont_vec <- data[[cont_name]][pair_active]
    nonfinite <- !is.finite(cont_vec) & !is.na(cont_vec)
    n_bad <- sum(nonfinite)
    if (n_bad > 0L) {
      bad_vals <- unique(cont_vec[nonfinite])
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.code method = \"polyserial\"} requires a finite continuous ",
            "variable."
          ),
          "i" = paste0(
            "Column {.field {cont_name}} has {n_bad} non-finite ",
            "value{?s} ({.val {bad_vals}}) in the active domain."
          ),
          "v" = "Filter the non-finite rows, or recode them to {.code NA}."
        ),
        class = "surveycore_error_polyserial_nonfinite_continuous"
      )
    }
  }

  # 7. MLE on the pair.
  if (identical(method, "polychoric")) {
    fit <- .corr_polychoric_mle(
      x_col_vec,
      y_col_vec,
      w_full,
      pair_active,
      x_name = x_col,
      y_name = y_col
    )
    vec_a <- x_col_vec
    vec_b <- y_col_vec
  } else {
    # polyserial: MLE uses ordinal then continuous.
    fit <- .corr_polyserial_mle(
      data[[ord_name]],
      data[[cont_name]],
      w_full,
      pair_active,
      ord_name = ord_name,
      cont_name = cont_name
    )
    vec_a <- data[[ord_name]]
    vec_b <- data[[cont_name]]
  }

  # 8. PC-10 — zero-count interior levels dropped.
  if (identical(method, "polychoric")) {
    dropped_x <- fit$dropped_levels_x
    dropped_y <- fit$dropped_levels_y
    if (length(dropped_x) > 0L) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "Ordinal variable {.field {x_col}} has zero-weight ",
            "level{?s} {.val {dropped_x}} in the active domain."
          ),
          "i" = paste0(
            "Dropped level(s) removed; remaining levels renumbered ",
            "before threshold estimation."
          )
        ),
        class = "surveycore_warning_polychoric_zero_count_level"
      )
    }
    if (length(dropped_y) > 0L) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "Ordinal variable {.field {y_col}} has zero-weight ",
            "level{?s} {.val {dropped_y}} in the active domain."
          ),
          "i" = paste0(
            "Dropped level(s) removed; remaining levels renumbered ",
            "before threshold estimation."
          )
        ),
        class = "surveycore_warning_polychoric_zero_count_level"
      )
    }
  } else {
    dropped <- fit$dropped_levels
    if (length(dropped) > 0L) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "Ordinal variable {.field {ord_name}} has zero-weight ",
            "level{?s} {.val {dropped}} in the active domain."
          ),
          "i" = paste0(
            "Dropped level(s) removed; remaining levels renumbered ",
            "before threshold estimation."
          )
        ),
        class = "surveycore_warning_polychoric_zero_count_level"
      )
    }
  }

  # 9. PC-11 — sparse cells (polychoric only).
  # nocov start
  # Defensive: n_sparse_cells is set by .corr_polychoric_mle() only when an
  # observed cell has modeled probability below 1e-12 at the optimum.
  # Realistic fixtures don't reliably trigger this with stats::optimize()'s
  # default tolerance; the branch is exercised indirectly via the primitives
  # in test-analysis-corr-latent-primitives.R.
  if (identical(method, "polychoric") && fit$n_sparse_cells > 0L) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "{.val {fit$n_sparse_cells}} cell{?s} in pair ",
          "({.field {x_col}}, {.field {y_col}}) {?has/have} modeled ",
          "probability below {.val 1e-12} at the MLE."
        ),
        "i" = paste0(
          "Log-likelihood was floored; estimate may be sensitive ",
          "to small perturbations."
        )
      ),
      class = "surveycore_warning_polychoric_sparse_cell"
    )
  }
  # nocov end

  rho_hat <- fit$rho

  # 10. Variance path by design class.
  if (S7::S7_inherits(design, survey_taylor)) {
    if_z <- .corr_numerical_influence(
      design = design,
      method = method,
      vec_a = vec_a,
      vec_b = vec_b,
      active_domain = pair_active,
      rho_hat_full = rho_hat
    )
    var_out <- .corr_taylor_variance_latent(
      design,
      if_z = if_z,
      w = w_full,
      active_domain = pair_active
    )
  } else if (
    S7::S7_inherits(design, survey_replicate) ||
      S7::S7_inherits(design, survey_nonprob)
  ) {
    var_out <- .corr_replicate_variance_latent(
      design,
      method = method,
      vec_a = vec_a,
      vec_b = vec_b,
      active_domain = pair_active,
      rho_hat_full = rho_hat
    )
  } else {
    # nocov start
    # Defensive: PC-7 gate above already rejects twophase and nonprob without
    # repweights; only taylor, replicate, and nonprob with repweights reach
    # here.
    cli::cli_abort(
      c(
        "x" = paste0(
          "Unsupported design class {.cls {class(design)[[1L]]}} in ",
          "{.fn .corr_latent_pair}."
        )
      ),
      class = "surveycore_error_unsupported_class"
    )
    # nocov end
  }

  var_z <- var_out$var_z
  var_z_srs <- var_out$var_z_srs
  se_z <- if (is.finite(var_z) && var_z >= 0) sqrt(var_z) else NA_real_
  se_z_srs <- if (
    is.finite(var_z_srs) && !is.null(var_z_srs) && var_z_srs >= 0
  ) {
    sqrt(var_z_srs)
  } else {
    NA_real_
  }

  # Delta-method SE on ρ scale: SE(ρ̂) = (1 - ρ̂²) · SE(ζ̂).
  se_r <- if (!is.na(se_z)) (1 - rho_hat^2) * se_z else NA_real_
  se_srs <- if (!is.na(se_z_srs)) (1 - rho_hat^2) * se_z_srs else NA_real_

  # 11. PC-9 / PC-14 boundary warnings.
  if (.corr_detect_boundary_rho(rho_hat)) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "Estimated correlation for pair ({.field {x_col}}, ",
          "{.field {y_col}}) is within {.val 1e-4} of the boundary ",
          "({.val {rho_hat}})."
        ),
        "i" = paste0(
          "Standard errors based on the delta method or Fisher-z ",
          "linearization are unreliable near {.val -1} and {.val 1}."
        )
      ),
      class = "surveycore_warning_polychoric_boundary_rho"
    )
    if (S7::S7_inherits(design, survey_taylor)) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "Taylor linearization for pair ({.field {x_col}}, ",
            "{.field {y_col}}) is near the boundary ({.val {rho_hat}}); ",
            "CI is structurally wide."
          ),
          "i" = paste0(
            "This is a known limitation of the delta-method / ",
            "numerical influence-function approach (Mannan 2025)."
          ),
          "v" = paste0(
            "Use a {.cls survey_replicate} design for tighter inference ",
            "near the boundary."
          )
        ),
        class = "surveycore_warning_polychoric_taylor_boundary_wide_ci"
      )
    }
  }

  # 12. CI via shared Fisher-z helper.
  ci <- .corr_fisher_ci(rho_hat, se_z, conf_level = conf_level)

  list(
    r = rho_hat,
    se_r = se_r,
    se_srs = se_srs,
    n = as.integer(n_pair),
    n_weighted = n_w,
    ci_low = ci$ci_low,
    ci_high = ci$ci_high,
    rho_z = ci$rho_z,
    se_z = se_z,
    method = method
  )
}
