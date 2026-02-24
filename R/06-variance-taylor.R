# ---------------------------------------------------------------------------
# R/06-variance-taylor.R
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
