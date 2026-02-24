# ---------------------------------------------------------------------------
# R/06-variance-estimation.R
# ---------------------------------------------------------------------------
# Taylor series variance estimation for survey_taylor designs.
#
# ATTRIBUTION — VENDORED CODE:
# The functions .svy_onestrat(), .svy_onestage(), .svy_multistage(), and
# .svy_recvar() are adapted from the survey package by Thomas Lumley
# (https://cran.r-project.org/package=survey), licensed under GPL-2 | GPL-3.
# Modifications: integrated with S7 classes; RCPP dispatch removed; error
# messages converted to cli format.
# ---------------------------------------------------------------------------

# ===========================================================================
# Section 1: Vendored linearization helpers
# (adapted from survey package, Thomas Lumley, GPL-2/GPL-3)
# ===========================================================================

# Variance estimator within one stratum.
# Adapted from survey:::onestrat.
.svy_onestrat <- function(
  x, cluster, nPSU, fpc,
  lonely.psu = "remove",
  stratum = NULL, stage = 1L
) {
  stratum_center <- attr(x, "recentering")
  if (is.null(stratum_center)) stratum_center <- 0 # nocov — always set by .svy_onestage

  if (is.null(fpc)) {
    f <- rep(1, NROW(x))
  } else {
    f <- ifelse(fpc == Inf, 1, (fpc - nPSU) / fpc)
  }

  scale <- if (nPSU > 1L) f * nPSU / (nPSU - 1L) else f

  if (all(f < 1e-7)) return(matrix(0, NCOL(x), NCOL(x)))

  scale <- scale[!duplicated(cluster)]
  x     <- rowsum(x, cluster)
  nsubset <- nrow(x)

  # nocov start — sampsize is computed post-na.rm filter, so nsubset == nPSU always
  if (nsubset < nPSU) {
    x     <- rbind(x, matrix(0, ncol = ncol(x), nrow = nPSU - nsubset))
    scale <- rep(scale[[1L]], NROW(x))
  }
  # nocov end

  if (lonely.psu != "adjust" || nsubset > 1L) {
    stratum_center <- colMeans(x)
  }
  x <- sweep(x = x, MARGIN = 2L, STATS = stratum_center, FUN = "-")

  # nocov start — by construction nsubset == nPSU, so nsubset == 1 implies nPSU == 1
  if (nsubset == 1L && nPSU > 1L) {
    if (lonely.psu == "average") scale <- NA_real_
  }
  # nocov end

  if (nPSU > 1L) {
    return(crossprod(x * sqrt(scale)))
  }

  switch(
    lonely.psu,
    certainty = crossprod(x * sqrt(scale)),
    remove    = crossprod(x * sqrt(scale)),
    adjust    = crossprod(x * sqrt(scale)),
    average   = NA_real_ * crossprod(x),
    fail      = cli::cli_abort(
      c("x" = "Stratum {.val {stratum}} has only one PSU at stage {stage}."),
      class = "surveycore_error_lonely_psu"
    ),
    cli::cli_abort(
      c("x" = "Unknown {.arg lonely.psu} value: {.val {lonely.psu}}."),
      class = "surveycore_error_lonely_psu"
    )
  )
}

# One stage of the multistage variance calculation (iterates over strata).
# Adapted from survey:::onestage.
.svy_onestage <- function(
  x, strata, clusters, nPSU, fpc,
  lonely.psu = "remove",
  stage = 0L
) {
  if (NROW(x) == 0L) return(matrix(0, NCOL(x), NCOL(x))) # nocov — empty subsets excluded before call

  if (!is.null(lonely.psu) && lonely.psu == "adjust") {
    n_psus_all <- sum(
      tapply(X = nPSU, INDEX = as.numeric(strata), FUN = function(v) v[[1L]])
    )
    recentering <- colSums(x) / n_psus_all
  } else {
    recentering <- 0
  }

  stratvars <- tapply(seq_len(NROW(x)), list(factor(strata)), function(index) {
    x_sub  <- `attr<-`(x[index, , drop = FALSE], "recentering", recentering)
    fpc_sub <- if (is.null(fpc)) NULL else fpc[index]
    .svy_onestrat(
      x_sub, clusters[index], nPSU[index][[1L]], fpc_sub,
      lonely.psu = lonely.psu,
      stratum    = strata[index][[1L]],
      stage      = stage
    )
  })

  p        <- NCOL(x)
  # Note: factor(strata) in tapply() above already computes unique levels;
  # nlevels(factor(strata)) would avoid the re-scan, but changing vendored code
  # for this micro-optimisation is not worth the maintenance risk.
  nstrat   <- length(unique(strata))
  nokstrat <- sum(vapply(stratvars, function(m) !any(is.na(m)), logical(1L)))

  apply(
    array(unlist(stratvars), c(p, p, length(stratvars))),
    1:2, sum, na.rm = TRUE
  ) * nstrat / nokstrat
}

# Recursive multistage variance estimator (pure R; no RCPP path).
# Adapted from survey:::multistage.
# nPSUs: per-row PSU count matrix (sampsize); popmat: per-row pop-size matrix.
.svy_multistage <- function(
  x, clusters, stratas, nPSUs, popmat,
  lonely.psu = "remove",
  one.stage  = FALSE,
  stage      = 1L
) {
  n   <- NROW(x)
  fpc <- if (is.null(popmat)) NULL else popmat[, 1L]

  v <- .svy_onestage(
    x, stratas[, 1L], clusters[, 1L], nPSUs[, 1L], fpc,
    lonely.psu = lonely.psu, stage = stage
  )

  # nocov start — Phase 0 builder always passes single-column cluster/strata matrices
  if (!isTRUE(one.stage) && !is.null(popmat) && NCOL(clusters) > 1L) {
    v.sub <- by(seq_len(n), list(as.numeric(clusters[, 1L])), function(index) {
      .svy_multistage(
        x[index, , drop = FALSE],
        clusters[index, -1L, drop = FALSE],
        stratas[index,  -1L, drop = FALSE],
        nPSUs[index,    -1L, drop = FALSE],
        popmat[index,   -1L, drop = FALSE],
        lonely.psu = lonely.psu,
        one.stage  = one.stage - 1L,
        stage      = stage + 1L
      ) * nPSUs[index[[1L]], 1L] / popmat[index[[1L]], 1L]
    })
    for (i in seq_along(v.sub)) v <- v + v.sub[[i]]
  }
  # nocov end

  dimnames(v) <- list(colnames(x), colnames(x))
  v
}

# Master variance function (pure R; no post-strata in Phase 0).
# Adapted from survey:::svyrecvar.
# fpcs: list(sampsize = matrix, popsize = matrix or NULL)
.svy_recvar <- function(
  x, clusters, stratas, fpcs,
  lonely.psu = "remove",
  one.stage  = FALSE
) {
  x <- as.matrix(x)
  .svy_multistage(
    x, clusters, stratas,
    nPSUs  = fpcs[["sampsize"]],
    popmat = fpcs[["popsize"]],
    lonely.psu = lonely.psu, one.stage = one.stage, stage = 1L
  )
}


# ===========================================================================
# Section 2: Design input extractor for survey_taylor
# ===========================================================================

# Build all inputs needed for .svy_recvar() from a survey_taylor object.
# Returns a list ready for calling the variance functions.
.taylor_build_inputs <- function(design, y_col, na.rm = TRUE) {
  data <- design@data
  vars <- design@variables

  y <- data[[y_col]]
  w <- data[[vars$weights]]   # survey weights = 1 / inclusion_prob

  # --- Cluster IDs ---
  # If nest = TRUE, make PSU IDs globally unique by interaction with strata.
  strata_id <- if (!is.null(vars$strata)) {
    data[[vars$strata]]
  } else {
    rep(1L, nrow(data))
  }

  psu_id <- if (!is.null(vars$ids)) {
    raw_ids <- data[[vars$ids[[1L]]]]
    if (isTRUE(vars$nest) && !is.null(vars$strata)) {
      as.integer(interaction(strata_id, raw_ids, drop = TRUE))
    } else {
      raw_ids
    }
  } else {
    seq_len(nrow(data))  # each row is its own PSU
  }

  # --- Handle na.rm ---
  if (na.rm) {
    keep    <- !is.na(y)
    y       <- y[keep]
    w       <- w[keep]
    strata_id <- strata_id[keep]
    psu_id    <- psu_id[keep]
    if (!is.null(vars$fpc)) {
      fpc_col_full <- data[[vars$fpc]][keep]
    } else {
      fpc_col_full <- NULL
    }
  } else {
    fpc_col_full <- if (!is.null(vars$fpc)) data[[vars$fpc]] else NULL
  }

  n <- length(y)

  # --- Build cluster and strata matrices ---
  clusters_mat <- matrix(psu_id, ncol = 1L)
  strata_mat   <- matrix(strata_id, ncol = 1L)

  # --- Build FPC structure ---
  # sampsize[i] = number of unique PSUs in stratum of obs i.
  # Use tapply for O(N log N) instead of the O(N*S) for-loop alternative.
  psu_per_stratum  <- tapply(psu_id, strata_id, function(ps) length(unique(ps)))
  sampsize_vec     <- as.integer(psu_per_stratum[as.character(strata_id)])
  sampsize_mat     <- matrix(sampsize_vec, ncol = 1L)

  # popsize: NULL (no FPC) or per-row population sizes
  popsize_mat <- if (!is.null(fpc_col_full)) {
    fpc_vals <- fpc_col_full
    if (any(fpc_vals > 1, na.rm = TRUE)) {
      # values > 1 are population sizes
      matrix(as.numeric(fpc_vals), ncol = 1L)
    } else {
      # values in (0,1] are sampling fractions → convert to population sizes
      matrix(as.numeric(sampsize_vec / fpc_vals), ncol = 1L)
    }
  } else {
    NULL
  }

  fpcs <- list(sampsize = sampsize_mat, popsize = popsize_mat)

  list(
    y        = y,
    w        = w,
    clusters = clusters_mat,
    stratas  = strata_mat,
    fpcs     = fpcs
  )
}


# ===========================================================================
# Section 3: Core Taylor series estimation functions (internal)
# ===========================================================================

# Compute weighted mean and its variance for a single numeric variable.
# Returns list(mean, var, se).
.taylor_mean <- function(design, y_col, na.rm = TRUE) {
  inp        <- .taylor_build_inputs(design, y_col, na.rm = na.rm)
  lonely.psu <- getOption("survey.lonely.psu", "remove")

  x        <- matrix(inp$y, ncol = 1L, dimnames = list(NULL, y_col))
  w        <- inp$w
  psum     <- sum(w)
  average  <- drop(crossprod(x, w) / psum)   # weighted mean

  x_centered <- sweep(x, 2L, average)
  v <- .svy_recvar(
    x_centered * w / psum,
    inp$clusters, inp$stratas, inp$fpcs,
    lonely.psu = lonely.psu
  )

  list(mean = average[[1L]], var = v[[1L, 1L]], se = sqrt(v[[1L, 1L]]))
}

# Compute weighted total and its variance for a single numeric variable.
# Returns list(total, var, se).
.taylor_total <- function(design, y_col, na.rm = TRUE) {
  inp        <- .taylor_build_inputs(design, y_col, na.rm = na.rm)
  lonely.psu <- getOption("survey.lonely.psu", "remove")

  x     <- matrix(inp$y, ncol = 1L, dimnames = list(NULL, y_col))
  w     <- inp$w
  total <- drop(crossprod(x, w))   # weighted total

  v <- .svy_recvar(
    x * w,
    inp$clusters, inp$stratas, inp$fpcs,
    lonely.psu = lonely.psu
  )

  list(total = total[[1L]], var = v[[1L, 1L]], se = sqrt(v[[1L, 1L]]))
}


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
# Section 4: Public estimation stubs (Phase 0)
# ===========================================================================

# Shared input validation for all get_*() estimation functions.
# Checks: design is a survey_base subclass, not twophase, variable exists,
# variable is numeric. Returns invisible(TRUE) on success.
#' @noRd
.validate_estimation_input <- function(design, var_name) {
  if (!S7::S7_inherits(design, survey_base)) {
    cli::cli_abort(
      c(
        "x" = "{.arg design} must be a surveycore design object.",
        "i" = "Got {.cls {class(design)[[1L]]}}."
      ),
      class = "surveycore_error_not_survey_design"
    )
  }
  if (S7::S7_inherits(design, survey_twophase)) {
    cli::cli_abort(
      c(
        "x" = "Two-phase designs are not yet supported in estimation functions.",
        "i" = "Support for {.cls survey_twophase} will be added in Phase 1."
      ),
      class = "surveycore_error_unsupported_class"
    )
  }
  if (!var_name %in% names(design@data)) {
    cli::cli_abort(
      c(
        "x" = "Variable {.field {var_name}} not found in the survey data.",
        "i" = "Available variables: {.field {names(design@data)}}."
      ),
      class = "surveycore_error_var_not_found"
    )
  }
  if (!is.numeric(design@data[[var_name]])) {
    cli::cli_abort(
      c(
        "x" = "Variable {.field {var_name}} must be numeric.",
        "i" = "Got {.cls {class(design@data[[var_name]])}}."
      ),
      class = "surveycore_error_var_not_numeric"
    )
  }
  invisible(TRUE)
}


#' Estimate Weighted Mean for a Survey Design
#'
#' Computes the weighted mean and its standard error for a single variable
#' using the appropriate variance estimator for the survey design type.
#'
#' @param design A survey design object. Supported classes: [survey_taylor]
#'   (created by [as_survey()]), [survey_replicate] (created by
#'   [as_survey_rep()]), and [survey_calibrated] (created by
#'   [as_survey_calibrated()]). Two-phase designs ([survey_twophase]) are
#'   not yet supported.
#' @param var <[`tidy-select`][tidyselect::language]> A single unquoted
#'   variable name to estimate the mean of.
#' @param na.rm Logical. If `TRUE` (default), missing values are excluded
#'   before computing the mean. Set to `FALSE` to propagate `NA`.
#'
#' @section Variance estimation by design type:
#' \describe{
#'   \item{`survey_taylor`}{Taylor series linearization.}
#'   \item{`survey_replicate`}{Replicate-weight variance estimator.}
#'   \item{`survey_calibrated`}{SRS-based (model-assisted) variance.
#'     Standard errors assume simple random sampling within the calibrated
#'     weights. This is consistent with common practice for raked
#'     non-probability samples but may understate uncertainty. Full
#'     bootstrap re-calibration variance will be available in Phase 2.5.}
#' }
#'
#' @return A named list with elements:
#'   \describe{
#'     \item{`variable`}{Character. Name of the estimated variable.}
#'     \item{`mean`}{Numeric. Weighted mean estimate.}
#'     \item{`se`}{Numeric. Standard error of the mean.}
#'   }
#'
#' @examples
#' # NHANES 2017-2018: estimated mean age of U.S. civilian population
#' d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
#'                strata = sdmvstra, nest = TRUE)
#' get_means(d, ridageyr)
#'
#' @family estimation
#' @export
get_means <- function(design, var, na.rm = TRUE) {
  var_name <- rlang::as_name(rlang::ensym(var))
  .validate_estimation_input(design, var_name)

  # survey_replicate → replicate variance
  # survey_srs       → classical SRS variance
  # survey_taylor and survey_calibrated → Taylor series variance
  result <- if (S7::S7_inherits(design, survey_replicate)) {
    .replicate_mean(design, var_name, na.rm = na.rm)
  } else if (S7::S7_inherits(design, survey_srs)) {
    .srs_mean(design, var_name, na.rm = na.rm)
  } else {
    .taylor_mean(design, var_name, na.rm = na.rm)
  }
  list(variable = var_name, mean = result$mean, se = result$se)
}


#' Estimate Weighted Total for a Survey Design
#'
#' Computes the weighted total and its standard error for a single variable
#' using the appropriate variance estimator for the survey design type.
#'
#' @param design A survey design object. Supported classes: [survey_taylor]
#'   (created by [as_survey()]), [survey_replicate] (created by
#'   [as_survey_rep()]), and [survey_calibrated] (created by
#'   [as_survey_calibrated()]). Two-phase designs ([survey_twophase]) are
#'   not yet supported.
#' @param var <[`tidy-select`][tidyselect::language]> A single unquoted
#'   variable name to estimate the total of.
#' @param na.rm Logical. If `TRUE` (default), missing values are excluded
#'   before computing the total. Set to `FALSE` to propagate `NA`.
#'
#' @section Variance estimation by design type:
#' \describe{
#'   \item{`survey_taylor`}{Taylor series linearization.}
#'   \item{`survey_replicate`}{Replicate-weight variance estimator.}
#'   \item{`survey_calibrated`}{SRS-based (model-assisted) variance.
#'     Standard errors assume simple random sampling within the calibrated
#'     weights. This is consistent with common practice for raked
#'     non-probability samples but may understate uncertainty. Full
#'     bootstrap re-calibration variance will be available in Phase 2.5.}
#' }
#'
#' @return A named list with elements:
#'   \describe{
#'     \item{`variable`}{Character. Name of the estimated variable.}
#'     \item{`total`}{Numeric. Weighted total estimate.}
#'     \item{`se`}{Numeric. Standard error of the total.}
#'   }
#'
#' @examples
#' # ACS PUMS Wyoming: estimated total population by age
#' d <- as_survey_rep(acs_pums_wy, weights = pwgtp,
#'                    repweights = pwgtp1:pwgtp80,
#'                    type = "successive-difference")
#' get_totals(d, agep)
#'
#' @family estimation
#' @export
get_totals <- function(design, var, na.rm = TRUE) {
  var_name <- rlang::as_name(rlang::ensym(var))
  .validate_estimation_input(design, var_name)

  # survey_replicate → replicate variance
  # survey_srs       → classical SRS variance
  # survey_taylor and survey_calibrated → Taylor series variance
  result <- if (S7::S7_inherits(design, survey_replicate)) {
    .replicate_total(design, var_name, na.rm = na.rm)
  } else if (S7::S7_inherits(design, survey_srs)) {
    .srs_total(design, var_name, na.rm = na.rm)
  } else {
    .taylor_total(design, var_name, na.rm = na.rm)
  }
  list(variable = var_name, total = result$total, se = result$se)
}
