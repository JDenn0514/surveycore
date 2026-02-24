# ---------------------------------------------------------------------------
# R/06-variance-srs.R
# ---------------------------------------------------------------------------
# SRS variance estimation for survey_srs designs.
# surveycore-original code.
# ---------------------------------------------------------------------------

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
