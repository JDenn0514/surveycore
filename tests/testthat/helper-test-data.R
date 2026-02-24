# tests/testthat/helper-test-data.R
#
# Shared test infrastructure loaded automatically by testthat before any test
# file runs. Provides:
#   - make_survey_data()  — synthetic survey data generator
#   - test_invariants()   — formal invariant checker for survey objects
#
# Dependency note: test_invariants() references S7 class objects
# (survey_replicate, survey_metadata) and .get_design_vars_flat() from
# R/07-utils.R. Both are available after the package is loaded by
# devtools::test() / devtools::load_all().

# ------------------------------------------------------------------------------
# make_survey_data()
# ------------------------------------------------------------------------------

#' Create synthetic survey data for testing
#'
#' Generates realistic but artificial survey data with a known design structure.
#' PSU sizes vary (not equal), weights vary (lognormal), strata sizes are
#' imbalanced. Returns a plain data.frame — NOT a survey object.
#'
#' Column layout:
#'   - psu      : character PSU identifiers (globally unique)
#'   - strata   : character stratum identifiers
#'   - fpc      : integer population size per stratum (for FPC)
#'   - wt       : numeric sampling weights (lognormal, positive)
#'   - y1       : numeric continuous outcome (mean ~50)
#'   - y2       : numeric continuous outcome (mean ~0)
#'   - y3       : integer binary outcome (0/1, ~30% = 1)
#'   - group    : character categorical variable ("A", "B", "C")
#'
#' Additional columns by design:
#'   - design = "replicate": repwt_1 ... repwt_R replicate weight columns
#'   - design = "twophase":  phase2_ind (logical, ~40% TRUE)
#'
#' @param n         Total number of rows. Default 500L.
#' @param n_psu     Number of PSUs. Default 50L. For BRR/Fay must be even.
#' @param n_strata  Number of strata. Default 5L.
#' @param design    Survey design type: "taylor", "replicate", or "twophase".
#' @param type      Replicate weight method (used when design = "replicate").
#'   One of "brr", "jk1", "jk2", "jkn", "bootstrap", "fay". Default "brr".
#' @param with_labels  If TRUE, attach haven-style label/labels attributes to
#'   y1, y2, y3, group, and wt. Default FALSE.
#' @param seed      Random seed for reproducibility. Default 42L.
#'
#' @return A data.frame.
#' @keywords internal
make_survey_data <- function(
  n           = 500L,
  n_psu       = 50L,
  n_strata    = 5L,
  design      = c("taylor", "replicate", "twophase"),
  type        = "brr",
  with_labels = FALSE,
  seed        = 42L
) {
  design <- match.arg(design)
  type   <- tolower(type)

  if (type %in% c("brr", "fay") && n_psu %% 2L != 0L) {
    stop(
      "n_psu must be even for BRR/Fay replicate designs. ",
      "Got n_psu = ", n_psu, "."
    )
  }

  set.seed(seed)

  # --- PSU-to-stratum assignment ---
  # Distribute PSUs across strata as evenly as possible
  psus_per_stratum <- rep(n_psu %/% n_strata, n_strata)
  remainder        <- n_psu %% n_strata
  if (remainder > 0L) {
    psus_per_stratum[seq_len(remainder)] <- psus_per_stratum[seq_len(remainder)] + 1L
  }
  psu_stratum <- rep(seq_len(n_strata), psus_per_stratum) # stratum for each PSU

  # --- Row-to-PSU assignment with varying PSU sizes ---
  # Use Hamilton (largest remainder) method: floor-allocate, then distribute
  # remaining rows to PSUs with largest fractional parts. Guarantees all
  # PSU sizes >= 1 and sum exactly to n.
  psu_sizes_raw <- sample(5:15, n_psu, replace = TRUE)
  exact         <- psu_sizes_raw / sum(psu_sizes_raw) * n
  psu_sizes     <- as.integer(floor(exact))
  psu_sizes     <- pmax(psu_sizes, 1L)        # ensure every PSU has >= 1 row
  remaining     <- n - sum(psu_sizes)
  if (remaining > 0L) {
    top_idx           <- order(exact - floor(exact), decreasing = TRUE)[seq_len(remaining)]
    psu_sizes[top_idx] <- psu_sizes[top_idx] + 1L
  }

  psu_index <- rep(seq_len(n_psu), times = psu_sizes) # row-level PSU index
  strata    <- psu_stratum[psu_index]                  # row-level stratum index

  # --- FPC: integer population size per stratum ---
  stratum_n   <- tabulate(strata, nbins = n_strata)
  stratum_pop <- round(stratum_n * runif(n_strata, 8, 15))
  fpc         <- stratum_pop[strata]

  # --- Sampling weights: lognormal variation around stratum base weight ---
  base_wt <- stratum_pop / stratum_n    # population/sample ratio per stratum
  wt      <- base_wt[strata] * exp(rnorm(n, mean = 0, sd = 0.2))

  # --- Outcome variables ---
  y1    <- rnorm(n, mean = 50, sd = 10)
  y2    <- rnorm(n, mean = 0, sd = 1)
  y3    <- as.integer(runif(n) < 0.3)
  group <- sample(c("A", "B", "C"), n, replace = TRUE)

  df <- data.frame(
    psu    = paste0("psu_", psu_index),
    strata = paste0("stratum_", strata),
    fpc    = fpc,
    wt     = wt,
    y1     = y1,
    y2     = y2,
    y3     = y3,
    group  = group,
    stringsAsFactors = FALSE
  )

  # --- Replicate weights ---
  if (design == "replicate") {
    R <- switch(type,
      brr       = n_psu %/% 2L,
      fay       = n_psu %/% 2L,
      jk1       = ,
      jk2       = ,
      jkn       = ,
      bootstrap = n_psu,
      n_psu
    )
    repwt_matrix        <- matrix(
      wt * exp(matrix(rnorm(n * R, mean = 0, sd = 0.1), nrow = n, ncol = R)),
      nrow = n,
      ncol = R
    )
    repwt_df            <- as.data.frame(repwt_matrix)
    names(repwt_df)     <- paste0("repwt_", seq_len(R))
    df                  <- cbind(df, repwt_df)
  }

  # --- Two-phase indicator ---
  if (design == "twophase") {
    df$phase2_ind <- runif(n) < 0.4
  }

  # --- Haven-style label attributes ---
  if (with_labels) {
    attr(df$y1,    "label")  <- "Outcome variable 1 (continuous)"
    attr(df$y2,    "label")  <- "Outcome variable 2 (continuous)"
    attr(df$y3,    "label")  <- "Outcome variable 3 (binary, 0/1)"
    attr(df$y3,    "labels") <- c("No" = 0L, "Yes" = 1L)
    attr(df$group, "label")  <- "Demographic group"
    attr(df$group, "labels") <- c("Group A" = "A", "Group B" = "B", "Group C" = "C")
    attr(df$wt,    "label")  <- "Sampling weight"
  }

  df
}

# ------------------------------------------------------------------------------
# test_invariants()
# ------------------------------------------------------------------------------

#' Assert all formal invariants on a survey object
#'
#' Call this at the start of EVERY test_that() block that creates or modifies
#' a survey object. Checks all invariants from formal spec Section I.
#'
#' @param design A survey_taylor, survey_replicate, survey_twophase, or
#'   survey_calibrated object.
#' @return Returns design invisibly on success. Throws testthat failure on any
#'   violated invariant.
#' @keywords internal
test_invariants <- function(design) {

  # survey_srs has additional @variables keys (fpc_type, visible_vars) — check here
  # before the general invariants run.
  if (S7::S7_inherits(design, survey_srs)) {
    testthat::expect_true("fpc_type" %in% names(design@variables))
  }

  # All design types must have visible_vars in @variables (may be NULL).
  # This is required for Phase 0.5 select() compatibility.
  if (!S7::S7_inherits(design, survey_calibrated)) {
    testthat::expect_true(
      "visible_vars" %in% names(design@variables),
      label = "@variables has 'visible_vars' key"
    )
  }

  # survey_calibrated has a different @variables structure — handle separately
  if (S7::S7_inherits(design, survey_calibrated)) {
    testthat::expect_true(is.data.frame(design@data))
    testthat::expect_false(is.null(design@data))
    testthat::expect_gte(nrow(design@data), 1L)
    testthat::expect_false(
      anyDuplicated(names(design@data)) > 0L,
      label = "@data has no duplicate column names"
    )

    testthat::expect_true(
      "weights" %in% names(design@variables),
      label = "@variables has 'weights' key"
    )
    testthat::expect_true(
      "probs_provided" %in% names(design@variables),
      label = "@variables has 'probs_provided' key"
    )

    wt_var <- design@variables$weights
    if (!is.null(wt_var)) {
      testthat::expect_true(
        wt_var %in% names(design@data),
        label = paste0("weight column '", wt_var, "' present in @data")
      )
      wt_col <- design@data[[wt_var]]
      testthat::expect_true(is.numeric(wt_col), label = "weight column is numeric")
      testthat::expect_true(
        sum(!is.na(wt_col)) > 0L,
        label = "weight column has at least one non-NA value"
      )
      testthat::expect_true(
        all(wt_col[!is.na(wt_col)] > 0),
        label = "weight column has all positive non-NA values"
      )
    }

    testthat::expect_true(S7::S7_inherits(design@metadata, survey_metadata))
    meta_vars <- names(design@metadata@variable_labels)
    if (length(meta_vars) > 0L) {
      testthat::expect_true(
        all(meta_vars %in% names(design@data)),
        label = "all metadata-labelled vars present in @data"
      )
    }

    return(invisible(design))
  }
  # Invariant 1: @data is a non-NULL data.frame with >= 1 row, no duplicate names
  testthat::expect_true(is.data.frame(design@data))
  testthat::expect_false(is.null(design@data))
  testthat::expect_gte(nrow(design@data), 1L)
  testthat::expect_false(
    anyDuplicated(names(design@data)) > 0L,
    label = "@data has no duplicate column names"
  )

  # Invariant 2: All named design columns exist in @data and are atomic.
  # survey_twophase has a nested variables structure; handle it separately.
  if (S7::S7_inherits(design, survey_twophase)) {
    p1 <- design@variables$phase1
    p2 <- design@variables$phase2
    design_vars <- c(
      p1$ids, p1$weights, p1$strata, p1$fpc,
      if (!is.null(p2)) c(p2$ids, p2$strata, p2$probs, p2$fpc),
      design@variables$subset
    )
  } else {
    design_vars <- c(
      design@variables$ids,
      design@variables$weights,
      design@variables$strata,
      design@variables$fpc
    )
  }
  design_vars <- design_vars[!is.null(design_vars)]
  for (v in design_vars) {
    testthat::expect_true(
      v %in% names(design@data),
      label = paste0("design var '", v, "' present in @data")
    )
    testthat::expect_true(
      is.atomic(design@data[[v]]),
      label = paste0("design var '", v, "' is atomic")
    )
  }

  # Invariant 3: Weights are numeric and strictly positive.
  # For survey_twophase, weights live under @variables$phase1$weights.
  wt_var <- if (S7::S7_inherits(design, survey_twophase)) {
    design@variables$phase1$weights
  } else {
    design@variables$weights
  }
  if (!is.null(wt_var)) {
    wt_col <- design@data[[wt_var]]
    testthat::expect_true(
      is.numeric(wt_col),
      label = paste0("weight column '", wt_var, "' is numeric")
    )
    testthat::expect_true(
      all(wt_col[!is.na(wt_col)] > 0),
      label = paste0("weight column '", wt_var, "' has all positive values")
    )
  }

  # Invariant 4: Replicate weights are numeric (survey_replicate only)
  if (S7::S7_inherits(design, survey_replicate)) {
    for (rw in design@variables$repweights) {
      testthat::expect_true(
        is.numeric(design@data[[rw]]),
        label = paste0("replicate weight column '", rw, "' is numeric")
      )
    }
  }

  # Additional check for survey_twophase: subset column must be logical
  if (S7::S7_inherits(design, survey_twophase)) {
    subset_var <- design@variables$subset
    if (!is.null(subset_var) && subset_var %in% names(design@data)) {
      testthat::expect_true(
        is.logical(design@data[[subset_var]]),
        label = paste0("subset column '", subset_var, "' is logical")
      )
    }
  }

  # Invariant 5: @metadata is a survey_metadata object; all labelled vars in @data
  testthat::expect_true(S7::S7_inherits(design@metadata, survey_metadata))
  meta_vars <- names(design@metadata@variable_labels)
  if (length(meta_vars) > 0L) {
    testthat::expect_true(
      all(meta_vars %in% names(design@data)),
      label = "all metadata-labelled vars present in @data"
    )
  }

  invisible(design)
}

# ------------------------------------------------------------------------------
# test_result_invariants()
# ------------------------------------------------------------------------------

#' Assert all formal invariants on a survey result object
#'
#' Call this as the FIRST assertion in every test_that() block that creates a
#' result from a get_*() function. The direct parallel to test_invariants()
#' for design objects.
#'
#' @param result A survey_freqs, survey_means, survey_totals, survey_corr,
#'   survey_quantiles, or survey_ratios object.
#' @param expected_class The specific S3 class string expected (e.g.,
#'   "survey_means").
#' @return Returns result invisibly on success. Throws testthat failure on any
#'   violated invariant.
#' @keywords internal
test_result_invariants <- function(result, expected_class) {
  # 1. Correct S3 class hierarchy
  testthat::expect_true(
    inherits(result, expected_class),
    label = paste0("result inherits from ", expected_class)
  )
  testthat::expect_true(
    inherits(result, "survey_result"),
    label = "result inherits from survey_result"
  )
  testthat::expect_true(
    tibble::is_tibble(result),
    label = "result is a tibble"
  )

  # 2. meta() returns a non-NULL list
  m <- meta(result)
  testthat::expect_false(is.null(m), label = "meta() is not NULL")
  testthat::expect_type(m, "list")

  # 3. Required meta keys always present (never absent)
  required_common_keys <- c(
    "design_type", "conf_level", "call", "group_names", "group_labels"
  )
  testthat::expect_true(
    all(required_common_keys %in% names(m)),
    label = "all required meta keys present"
  )

  # 4. group_names is always a character vector (never NULL)
  testthat::expect_type(m$group_names, "character")

  # 5. value_labels is always a non-empty named list
  testthat::expect_true(
    "value_labels" %in% names(m),
    label = "value_labels key present in meta"
  )
  testthat::expect_type(m$value_labels, "list")
  testthat::expect_gt(
    length(m$value_labels), 0L,
    label = "value_labels is non-empty"
  )
  testthat::expect_false(
    is.null(names(m$value_labels)),
    label = "value_labels is a named list"
  )

  invisible(result)
}

# ------------------------------------------------------------------------------
# make_all_designs()
# ------------------------------------------------------------------------------

#' Create all three survey design types for cross-design testing
#'
#' Convenience wrapper that returns one survey object of each class.
#' Use in verb tests to iterate over all design types with a for loop.
#'
#' @param seed   Random seed passed to make_survey_data(). Default 42L.
#' @return A named list with elements: srs, taylor, replicate, twophase, calibrated.
#' @keywords internal
make_all_designs <- function(seed = 42L) {
  # Taylor series design
  df_t <- make_survey_data(
    n = 100L, n_psu = 10L, n_strata = 2L,
    design = "taylor", seed = seed
  )
  taylor <- as_survey(
    df_t,
    ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE
  )

  # Replicate weights design
  df_r <- make_survey_data(
    n = 100L, n_psu = 10L, n_strata = 2L,
    design = "replicate", type = "brr", seed = seed
  )
  repwt_cols <- grep("^repwt_", names(df_r), value = TRUE)
  replicate  <- as_survey_rep(
    df_r,
    weights    = wt,
    repweights = tidyselect::all_of(repwt_cols),
    type       = "BRR"
  )

  # Two-phase design
  df_p <- make_survey_data(
    n = 100L, n_psu = 10L, n_strata = 2L,
    design = "twophase", seed = seed
  )
  phase1   <- as_survey(
    df_p,
    ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE
  )
  twophase <- suppressWarnings(as_survey_twophase(phase1, subset = phase2_ind))

  # Calibrated design (non-probability, weights only)
  df_c <- make_survey_data(
    n = 100L, n_psu = 10L, n_strata = 2L,
    design = "taylor", seed = seed
  )
  calibrated <- as_survey_calibrated(df_c, weights = wt)

  # Simple random sample design
  df_s <- make_survey_data(
    n = 100L, n_psu = 10L, n_strata = 2L,
    design = "taylor", seed = seed
  )
  srs <- as_survey_srs(df_s, weights = wt)

  list(
    srs        = srs,
    taylor     = taylor,
    replicate  = replicate,
    twophase   = twophase,
    calibrated = calibrated
  )
}
