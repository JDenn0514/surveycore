# ---------------------------------------------------------------------------
# R/variance-twophase.R
# ---------------------------------------------------------------------------
# Two-phase sampling variance estimation for survey_twophase designs.
#
# ATTRIBUTION — VENDORED CODE:
# The functions .twophasevar(), .twophase_phase1_var(), .twophase_phase2_var(),
# .twophase_same_scale(), .twophase_full_var() and .compute_phase2_probs() are
# adapted from the survey package by Thomas Lumley
# (https://cran.r-project.org/package=survey), licensed under GPL-2 | GPL-3.
# Modifications: integrated with S7 classes; three-method dispatch made
# explicit; RCPP path removed; error messages converted to cli format;
# data access via @variables instead of survey's internal list structure;
# the twophase2 check matrices reduced to grouped sums.
# ---------------------------------------------------------------------------

# ===========================================================================
# Section 1: General two-phase variance engine
# ===========================================================================

# General two-phase variance engine. Dispatches to phase 1 and optionally
# phase 2 variance components based on method stored in design@variables$method.
# Returns a numeric scalar.
#' @noRd
.twophasevar <- function(
  influence,
  design,
  lonely.psu = getOption("survey.lonely.psu", "remove")
) {
  vars <- design@variables
  method <- vars$method
  subset <- design@data[[vars$subset]] # logical vector, length = nrow(data)

  # method = "full" requires phase 2 design information at estimation time
  if (identical(method, "full")) {
    has_phase2_info <- !is.null(vars$phase2$ids) ||
      !is.null(vars$phase2$strata) ||
      !is.null(vars$phase2$probs)
    if (!has_phase2_info) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Two-phase variance method {.val full} requires ",
            "phase 2 design structure."
          ),
          "i" = paste0(
            "No {.arg ids2}, {.arg strata2}, or {.arg probs2} were ",
            "specified in {.fn as_survey_twophase}."
          ),
          "v" = paste0(
            'Reconstruct with {.arg method = "approx"} or supply ',
            "phase 2 design variables."
          )
        ),
        class = "surveycore_error_full_requires_phase2"
      )
    }
  }

  # method = "full" is survey::twophase2()'s Horvitz-Thompson variance;
  # "approx" and "simple" are survey::twophase()'s, and "simple" is "approx":
  # survey documents the two as the same method and never branches on
  # "simple" (issue #330)
  if (identical(method, "full")) {
    return(.twophase_full_var(influence, design))
  }

  # Phase 1 variance contribution
  v1 <- .twophase_phase1_var(influence, design, lonely.psu)

  # Phase 2 variance contribution
  v2 <- .twophase_phase2_var(influence, design, subset, lonely.psu)

  v1 + v2
}


# ===========================================================================
# Section 2: Phase 1 and Phase 2 variance components
# ===========================================================================

# Compute phase 1 variance contribution.
# Adapted from survey:::svyrecvar.phase1 / onestrat.phase1.
# Implements the onestrat.phase1 formula directly, for "approx" and "simple":
#   V1 = sum_s { f_s * nPSUfull_s/(nPSUfull_s-1) *
#                sum_j { ((x_j * pi2_j - xcenter_s) / sqrt(pi2_j))^2 } }
# where nPSU_s = phase 2 PSUs in stratum, nPSUfull_s = phase 1 PSUs in stratum,
# pi2_j = nPSU_s/nPSUfull_s (PSU-level stratum sampling fraction,
# survey's `usu`),
# xcenter_s = mean(x_j * nPSU_s/nPSUfull_s) centering term,
# and f_s = (N_s - n_s) / N_s is the Phase 1 FPC factor for stratum s
# (1 when no FPC column is provided).
# Returns a numeric scalar.
.twophase_phase1_var <- function(influence, design, lonely.psu) {
  ph1_data <- design@data
  ph1_vars <- design@variables$phase1
  subset <- design@data[[design@variables$subset]]
  n_ph1 <- nrow(ph1_data)

  # Build phase 1 strata and PSU columns (all n1 rows, used for nPSUfull)
  strata_all <- if (!is.null(ph1_vars$strata)) {
    ph1_data[[ph1_vars$strata]]
  } else {
    rep(1L, n_ph1)
  }

  psu_all <- if (!is.null(ph1_vars$ids)) {
    raw_ids <- ph1_data[[ph1_vars$ids[[1L]]]]
    if (isTRUE(ph1_vars$nest) && !is.null(ph1_vars$strata)) {
      as.integer(interaction(strata_all, raw_ids, drop = TRUE))
    } else {
      raw_ids
    }
  } else {
    seq_len(n_ph1)
  }

  # onestrat.phase1 formula using phase 2 rows only
  ph2_idx <- which(subset)
  infl_ph2 <- influence[ph2_idx]
  strata_ph2 <- strata_all[ph2_idx]
  psu_ph2 <- psu_all[ph2_idx]

  # nPSUfull per phase 1 stratum (total distinct PSU IDs across all n1 rows)
  nPSUfull_by_strat <- tapply(psu_all, strata_all, function(p) {
    length(unique(p))
  })

  # Compute per-row Phase 2 PSU sampling fraction (survey's `usu`).
  # With phase 2 strata: n_ph2_PSU_in_strata2 / n_ph1_PSU_in_strata2
  # per Phase 2 row.
  # Without phase 2 strata: n_ph2_PSU_in_ph1_strat / n_ph1_PSU_in_ph1_strat
  # per Phase 2 row.
  strata2_var <- design@variables$phase2$strata
  if (!is.null(strata2_var)) {
    strata2_all <- ph1_data[[strata2_var]]
    strata2_ph2 <- strata2_all[ph2_idx]
    n_ph2_by_s2 <- tapply(psu_ph2, strata2_ph2, function(p) length(unique(p)))
    n_ph1_by_s2 <- tapply(psu_all, strata2_all, function(p) length(unique(p)))
    usu_ph2 <- as.numeric(
      n_ph2_by_s2[as.character(strata2_ph2)] /
        n_ph1_by_s2[as.character(strata2_ph2)]
    )
  } else {
    n_ph2_by_strat <- tapply(psu_ph2, strata_ph2, function(p) length(unique(p)))
    usu_ph2 <- as.numeric(
      n_ph2_by_strat[as.character(strata_ph2)] /
        nPSUfull_by_strat[as.character(strata_ph2)]
    )
  }

  # Phase 1 FPC column (if provided)
  fpc_all <- if (!is.null(ph1_vars$fpc)) ph1_data[[ph1_vars$fpc]] else NULL

  # Compute V1 by phase 1 stratum using onestrat.phase1 formula
  v1_total <- 0
  unique_strata <- unique(strata_ph2)

  for (s in unique_strata) {
    idx_s <- which(strata_ph2 == s)
    x_s <- infl_ph2[idx_s]
    psu_s <- psu_ph2[idx_s]
    nPSUfull_s <- as.integer(nPSUfull_by_strat[[as.character(s)]])

    # Aggregate influence to PSU level
    x_agg <- as.numeric(tapply(x_s, psu_s, sum))
    nPSU_s <- length(x_agg)

    # Aggregate usu to PSU level (mean handles PSUs spanning multiple
    # phase 2 strata). Deliberately not survey's rule: onestrat.phase1()
    # pairs rowsum()'s sorted PSU totals with usu in row order, so its SE
    # moves with row order and PSU labels when strata2 cuts across phase 1
    # PSUs. Nested strata give the same answer either way (issue #341).
    pi2_agg <- as.numeric(tapply(usu_ph2[idx_s], psu_s, mean))

    if (nPSU_s <= 1L) {
      next
    } # lonely PSU: contributes 0

    # xcenter = colMeans(x * nPSU/nPSUfull) — BEFORE multiplying by pi2
    xcenter_s <- mean(x_agg * nPSU_s / nPSUfull_s)

    # x = x * pi2 - xcenter
    x_scaled <- x_agg * pi2_agg - xcenter_s

    # Phase 1 FPC correction (if given)
    fpc_s <- if (!is.null(fpc_all)) fpc_all[ph2_idx[idx_s[[1L]]]] else NULL
    f_s <- if (is.null(fpc_s)) {
      1
    } else {
      ifelse(is.infinite(fpc_s), 1, (fpc_s - nPSUfull_s) / fpc_s)
    }

    scale_s <- f_s * nPSUfull_s / (nPSUfull_s - 1L)

    # V1_s = scale * crossprod(x_scaled / sqrt(pi2_agg))
    v1_total <- v1_total + sum((x_scaled / sqrt(pi2_agg))^2) * scale_s
  }

  v1_total
}


# Compute phase 2 variance contribution (used by "approx" and "simple").
# Adapted from the phase 2 component of survey:::twophasevar.
# The Phase 2 score is the influence itself when no Phase 1 sampling unit
# holds more than one Phase 2 unit (survey's `samescale`), and the influence
# times sqrt(1 / w1) otherwise.
# Returns a numeric scalar (extracts [1L, 1L] from the .svy_recvar() matrix).
#' @noRd
.twophase_phase2_var <- function(influence, design, subset, lonely.psu) {
  ph1_vars <- design@variables$phase1
  ph2_vars <- design@variables$phase2
  ph2_data <- design@data[subset, , drop = FALSE]
  n_ph2 <- nrow(ph2_data)

  # Phase 2 score
  score_ph2 <- if (.twophase_same_scale(design, subset)) {
    influence[subset]
  } else {
    w1 <- design@data[[ph1_vars$weights]]
    influence[subset] * sqrt(1 / w1[subset])
  }
  score_mat <- matrix(score_ph2, ncol = 1L)

  # Phase 2 strata column
  strata2_col <- if (!is.null(ph2_vars$strata)) {
    ph2_data[[ph2_vars$strata]]
  } else {
    rep(1L, n_ph2)
  }

  # Phase 2 PSU column (each row is own PSU if no ids2)
  psu2_col <- if (!is.null(ph2_vars$ids)) {
    ph2_data[[ph2_vars$ids[[1L]]]]
  } else {
    seq_len(n_ph2)
  }

  clusters2_mat <- matrix(psu2_col, ncol = 1L)
  strata2_mat <- matrix(strata2_col, ncol = 1L)

  # Phase 2 sampsize: unique PSU IDs per Phase 2 stratum among subset == TRUE
  psu2_per_stratum <- tapply(psu2_col, strata2_col, function(ps) {
    length(unique(ps))
  })
  sampsize2_vec <- as.integer(psu2_per_stratum[as.character(strata2_col)])
  sampsize2_mat <- matrix(sampsize2_vec, ncol = 1L)

  # Phase 2 popsize
  popsize2_mat <- if (!is.null(ph2_vars$fpc)) {
    # Explicit FPC column
    fpc2_vals <- ph2_data[[ph2_vars$fpc]]
    matrix(as.integer(fpc2_vals), ncol = 1L)
  } else if (!is.null(ph2_vars$strata) || !is.null(ph2_vars$ids)) {
    # Auto-compute popsize from all Phase 1 rows
    strata2_all <- if (!is.null(ph2_vars$strata)) {
      design@data[[ph2_vars$strata]]
    } else {
      rep(1L, nrow(design@data))
    }
    psu2_all <- if (!is.null(ph2_vars$ids)) {
      design@data[[ph2_vars$ids[[1L]]]]
    } else {
      seq_len(nrow(design@data))
    }
    pop2_per_stratum <- tapply(psu2_all, strata2_all, function(ps) {
      length(unique(ps))
    })
    popsize2_vec <- as.integer(pop2_per_stratum[as.character(strata2_col)])
    matrix(popsize2_vec, ncol = 1L)
  } else {
    # No explicit Phase 2 structure (probs2, strata2, ids2, or fpc2):
    # treat Phase 1 sample as the Phase 2 population (standard two-phase FPC)
    matrix(rep(as.integer(nrow(design@data)), n_ph2), ncol = 1L)
  }

  fpcs2 <- list(sampsize = sampsize2_mat, popsize = popsize2_mat)

  v <- .svy_recvar(
    score_mat,
    clusters2_mat,
    strata2_mat,
    fpcs2,
    lonely.psu = lonely.psu
  )
  v[1L, 1L]
}


# Does each Phase 1 sampling unit hold at most one Phase 2 unit? This is
# survey::twophase()'s `samescale`: it takes the last-stage Phase 1 cluster of
# the first row of each Phase 2 first-stage unit and checks for repeats. It
# holds for an unclustered Phase 1 and when ids2 names the Phase 1 cluster; it
# fails when Phase 2 subsamples rows or smaller units within Phase 1 clusters.
# A Phase 1 unit is keyed by its stratum and every id stage, so nested ids
# count once per stratum.
#' @noRd
.twophase_same_scale <- function(design, subset) {
  ph1_vars <- design@variables$phase1
  data <- design@data
  n <- nrow(data)

  unit1 <- if (is.null(ph1_vars$ids)) {
    as.character(seq_len(n))
  } else {
    strata1 <- if (!is.null(ph1_vars$strata)) {
      as.character(data[[ph1_vars$strata]])
    } else {
      rep("1", n)
    }
    stages <- lapply(ph1_vars$ids, function(v) as.character(data[[v]]))
    do.call(paste, c(list(strata1), stages, sep = "\r"))
  }
  unit2 <- .phase2_units(design)$psu

  first_rows <- !duplicated(unit2[subset])
  anyDuplicated(unit1[subset][first_rows]) == 0L
}


# Compute the method = "full" variance: the double-expansion
# Horvitz-Thompson estimator of survey:::twophase2var(),
#   V = sum_ij x_i x_j * (D1 + D2 - D1 o D2)_ij,
# over Phase 2 rows, where x is the (already weighted) influence and D1, D2
# are survey's "check" matrices (pi_ij - pi_i pi_j) / pi_ij for each phase
# (survey:::Dcheck_subset, survey:::Dcheck_strat, survey:::twophaseDcheck).
# Each D takes one of three values for a pair of rows:
#   same sampling unit            1 - p
#   same stratum, other unit      -(1 - p) / (n_h - 1)
#   otherwise                     0
# where p is the unit's inclusion probability and n_h the number of units
# sampled in the stratum. Each value is a function of the row i's unit, so
# the quadratic form reduces to sums of x within groups and needs no n x n
# matrix.
#
# Phase 1: p = 1 / w1 taken from each unit's first Phase 2 row (as survey
# does); the off-diagonal term applies only with a Phase 1 fpc, because
# survey treats a design without one as sampled with replacement. A Phase 1
# with no weights, probs, strata or fpc and no repeated cluster is iid, as in
# survey (phase1_is_iid): D1 is the identity, i.e. p = 0.
# n_h counts the stratum's Phase 1 units. survey 4.5 reads n_h from the wrong
# rows here (Dcheck_multi_subset passes a row-length sampsize that
# Dcheck_subset indexes by unit), which changes the answer when a Phase 1 fpc
# meets strata with unequal unit counts; this function uses the stratum's own
# count.
#
# Both phases use their first-stage clusters only, and lonely PSUs need no
# rule: a stratum with one unit has no off-diagonal pair.
# Returns a numeric scalar.
#' @noRd
.twophase_full_var <- function(influence, design) {
  data <- design@data
  vars <- design@variables
  ph1_vars <- vars$phase1
  subset <- data[[vars$subset]]
  n <- nrow(data)

  # Phase 1 units (keyed by stratum, so nested and unique ids agree)
  strata1 <- if (!is.null(ph1_vars$strata)) {
    as.character(data[[ph1_vars$strata]])
  } else {
    rep("1", n)
  }
  ids1 <- if (!is.null(ph1_vars$ids)) {
    as.character(data[[ph1_vars$ids[[1L]]]])
  } else {
    as.character(seq_len(n))
  }
  psu1 <- paste(strata1, ids1, sep = "\r")
  n1_h <- .count_units(psu1, strata1, rep(TRUE, n))

  phase1_is_iid <- .twophase_phase1_is_iid(design)

  # Phase 2 units and probabilities
  units2 <- .phase2_units(design)
  pi2 <- .compute_phase2_probs(design, subset)
  n2_h <- .count_units(units2$psu, units2$strata, subset)

  # Restrict everything to Phase 2 rows
  x <- influence[subset]
  strata1 <- strata1[subset]
  psu1 <- psu1[subset]
  n1_h <- n1_h[subset]
  strata2 <- units2$strata[subset]
  psu2 <- units2$psu[subset]
  n2_h <- n2_h[subset]

  # Unit-level probabilities, from each unit's first Phase 2 row
  first_of <- function(v, unit) v[match(unit, unit)]
  p1 <- if (phase1_is_iid) {
    rep(0, length(x))
  } else {
    first_of(1 / data[[ph1_vars$weights]][subset], psu1)
  }
  p2 <- first_of(pi2[subset], psu2)

  same_unit1 <- 1 - p1
  same_strat1 <- if (is.null(ph1_vars$fpc)) {
    rep(0, length(x))
  } else {
    -(1 - p1) / (n1_h - 1)
  }
  same_strat1[n1_h <= 1] <- 0
  same_unit2 <- 1 - p2
  same_strat2 <- -(1 - p2) / (n2_h - 1)
  same_strat2[n2_h <= 1] <- 0

  # Sums of x over each row's groups
  group_sum <- function(...) stats::ave(x, ..., FUN = sum)
  s_u1 <- group_sum(psu1)
  s_s1 <- group_sum(strata1)
  s_u2 <- group_sum(psu2)
  s_s2 <- group_sum(strata2)
  s_u1u2 <- group_sum(psu1, psu2)
  s_u1s2 <- group_sum(psu1, strata2)
  s_s1u2 <- group_sum(strata1, psu2)
  s_s1s2 <- group_sum(strata1, strata2)

  # (D1 x)_i, (D2 x)_i and ((D1 o D2) x)_i; "other unit" sums subtract the
  # same-unit part
  d1x <- same_unit1 * s_u1 + same_strat1 * (s_s1 - s_u1)
  d2x <- same_unit2 * s_u2 + same_strat2 * (s_s2 - s_u2)
  d12x <- same_unit1 *
    same_unit2 *
    s_u1u2 +
    same_unit1 * same_strat2 * (s_u1s2 - s_u1u2) +
    same_strat1 * same_unit2 * (s_s1u2 - s_u1u2) +
    same_strat1 * same_strat2 * (s_s1s2 - s_u1s2 - s_s1u2 + s_u1u2)

  sum(x * (d1x + d2x - d12x))
}


# ===========================================================================
# Section 3: Phase 2 probability computation
# ===========================================================================

# Derive conditional Phase 2 inclusion probabilities (pi2|1,i).
# Adapted from the phase 2 design survey::twophase() and survey::twophase2()
# build from data[subset, ].
#
# Priority: an explicit probs2 column, then fpc2, then the fraction of Phase 2
# sampling units drawn within each Phase 2 stratum. A Phase 2 sampling unit is
# the first-stage ids2 cluster when ids2 is given, and the row otherwise, so
# cluster subsampling gets the cluster fraction (m_h / M_h) and not the row
# fraction. With no strata2 the whole Phase 1 sample is one stratum.
# Returns numeric vector of length nrow(design@data), with 1 for Phase 1-only
# rows (influence = 0 there, so the placeholder value does not affect results).
#' @noRd
.compute_phase2_probs <- function(design, subset) {
  vars <- design@variables
  data <- design@data

  if (!is.null(vars$phase2$probs)) {
    pi2 <- as.numeric(data[[vars$phase2$probs]])
  } else {
    units <- .phase2_units(design)
    n2_h <- .count_units(units$psu, units$strata, subset)
    pi2 <- if (!is.null(vars$phase2$fpc)) {
      fpc2 <- as.numeric(data[[vars$phase2$fpc]])
      # survey::as.fpc() reads a column of values <= 1 as sampling fractions
      # and anything else as population sizes
      if (all(fpc2[subset] <= 1)) fpc2 else n2_h / fpc2
    } else {
      n2_h / .count_units(units$psu, units$strata, rep(TRUE, nrow(data)))
    }
  }

  pi2[!subset] <- 1 # Phase 1-only rows: placeholder 1
  pi2
}


# Phase 2 stratum and first-stage sampling-unit keys for every row. The unit
# key carries the stratum, so a unit is counted within its own stratum.
#' @noRd
.phase2_units <- function(design) {
  vars <- design@variables$phase2
  data <- design@data
  n <- nrow(data)

  strata <- if (!is.null(vars$strata)) {
    as.character(data[[vars$strata]])
  } else {
    rep("1", n)
  }
  ids <- if (!is.null(vars$ids)) {
    as.character(data[[vars$ids[[1L]]]])
  } else {
    as.character(seq_len(n))
  }

  list(strata = strata, psu = paste(strata, ids, sep = "\r"))
}


# Number of distinct units per stratum among the rows `keep` selects, returned
# for every row (0 for a stratum with no selected row).
#' @noRd
.count_units <- function(psu, strata, keep) {
  counts <- tapply(psu[keep], strata[keep], function(p) length(unique(p)))
  out <- as.numeric(counts[strata])
  out[is.na(out)] <- 0
  out
}


# ===========================================================================
# Section 5: Variance-covariance pair estimation for survey_twophase
# (used by get_corr())
# ===========================================================================

# Compute variance-covariance pair estimates and the 3x3 meta-vcov of
# (Var(X), Cov(X,Y), Var(Y)) for two-phase designs.
#
# Constructs full-length influence vectors for each of the three estimands
# (Var(X), Cov(X,Y), Var(Y)) using calibrated Phase 2 weights, then
# computes the 3x3 meta-vcov using the polarization identity:
#   Cov(T_a, T_b) = (Var(T_a + T_b) - Var(T_a) - Var(T_b)) / 2
# This allows reuse of the scalar .twophasevar() for all variance methods
# (simple, approx, full) without modification.
#
# @param design  A survey_twophase object.
# @param x_col  Character. Name of the first numeric variable.
# @param y_col  Character. Name of the second numeric variable.
# @param domain Numeric 0/1 vector (full length). Domain membership mask.
# @param na.rm  Logical. If TRUE, exclude rows where x or y is NA.
# @return Named list: $a, $b, $c, $sigma (3x3), $n, $n_weighted
#' @noRd
.vcov_pair_twophase <- function(design, x_col, y_col, domain, na.rm = TRUE) {
  data <- design@data
  ph1_vars <- design@variables$phase1
  subset <- data[[design@variables$subset]] # logical, full length
  n_total <- nrow(data)

  # Calibrated weights (Phase 1 weight / conditional Phase 2 inclusion prob)
  w_full <- data[[ph1_vars$weights]]
  pi2_full <- .compute_phase2_probs(design, subset)
  cal_wt <- w_full / pi2_full

  x_all_full <- data[[x_col]]
  y_all_full <- data[[y_col]]

  # Restrict domain to Phase 2 rows
  dom_ph2 <- domain[subset]
  cal_ph2 <- cal_wt[subset]
  x_ph2 <- x_all_full[subset]
  y_ph2 <- y_all_full[subset]

  # Pair mask over Phase 2 rows
  if (na.rm) {
    pair_ph2 <- dom_ph2 * as.numeric(!is.na(x_ph2) & !is.na(y_ph2))
  } else {
    pair_ph2 <- dom_ph2
  }

  n_d <- as.integer(sum(pair_ph2))
  W_d <- sum(cal_ph2 * pair_ph2)

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

  x_safe <- ifelse(pair_ph2 > 0, x_ph2, 0)
  y_safe <- ifelse(pair_ph2 > 0, y_ph2, 0)
  xbar <- sum(cal_ph2 * pair_ph2 * x_safe) / W_d
  ybar <- sum(cal_ph2 * pair_ph2 * y_safe) / W_d

  cx <- pair_ph2 * (x_safe - xbar)
  cy <- pair_ph2 * (y_safe - ybar)

  a <- sum(cal_ph2 * cx^2) / W_d
  b <- sum(cal_ph2 * cx * cy) / W_d
  c_val <- sum(cal_ph2 * cy^2) / W_d

  # Full-length influence vectors (0 for Phase 1-only rows)
  ph2_idx <- which(subset)
  infl_a <- numeric(n_total)
  infl_b <- numeric(n_total)
  infl_c <- numeric(n_total)
  infl_a[ph2_idx] <- cal_ph2 * pair_ph2 * (cx^2 - a) / W_d
  infl_b[ph2_idx] <- cal_ph2 * pair_ph2 * (cx * cy - b) / W_d
  infl_c[ph2_idx] <- cal_ph2 * pair_ph2 * (cy^2 - c_val) / W_d

  lonely.psu <- getOption("survey.lonely.psu", "remove")

  # Diagonal variances
  var_a <- .twophasevar(infl_a, design, lonely.psu)
  var_b <- .twophasevar(infl_b, design, lonely.psu)
  var_c <- .twophasevar(infl_c, design, lonely.psu)

  # Off-diagonal covariances via polarization identity:
  # Cov(T_a, T_b) = (Var(T_a + T_b) - Var(T_a) - Var(T_b)) / 2
  var_ab <- .twophasevar(infl_a + infl_b, design, lonely.psu)
  var_ac <- .twophasevar(infl_a + infl_c, design, lonely.psu)
  var_bc <- .twophasevar(infl_b + infl_c, design, lonely.psu)

  cov_ab <- (var_ab - var_a - var_b) / 2
  cov_ac <- (var_ac - var_a - var_c) / 2
  cov_bc <- (var_bc - var_b - var_c) / 2

  sigma <- matrix(
    c(var_a, cov_ab, cov_ac, cov_ab, var_b, cov_bc, cov_ac, cov_bc, var_c),
    nrow = 3L,
    ncol = 3L
  )

  list(a = a, b = b, c = c_val, sigma = sigma, n = n_d, n_weighted = W_d)
}
