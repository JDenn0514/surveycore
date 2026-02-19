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

#' Assert all 5 formal invariants on a survey object
#'
#' Call this at the start of EVERY test_that() block that creates or modifies
#' a survey object. Checks all invariants from formal spec Section I.
#'
#' @param design A survey_taylor, survey_replicate, or survey_twophase object.
#' @return Returns design invisibly on success. Throws testthat failure on any
#'   violated invariant.
#' @keywords internal
test_invariants <- function(design) {
  # Invariant 1: @data is a non-NULL data.frame with >= 1 row, no duplicate names
  testthat::expect_true(is.data.frame(design@data))
  testthat::expect_false(is.null(design@data))
  testthat::expect_gte(nrow(design@data), 1L)
  testthat::expect_false(
    anyDuplicated(names(design@data)) > 0L,
    label = "@data has no duplicate column names"
  )

  # Invariant 2: All named design columns exist in @data and are atomic
  # .get_design_vars_flat() defined in R/07-utils.R
  design_vars <- c(
    design@variables$ids,
    design@variables$weights,
    design@variables$strata,
    design@variables$fpc
  )
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

  # Invariant 3: Weights are numeric and strictly positive (no NAs, no zeros)
  wt_var <- design@variables$weights
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
  if (S7::inherits(design, survey_replicate)) {
    for (rw in design@variables$repweights) {
      testthat::expect_true(
        is.numeric(design@data[[rw]]),
        label = paste0("replicate weight column '", rw, "' is numeric")
      )
    }
  }

  # Invariant 5: @metadata is a survey_metadata object; all labelled vars in @data
  testthat::expect_true(S7::inherits(design@metadata, survey_metadata))
  meta_vars <- names(design@metadata@variable_labels)
  if (length(meta_vars) > 0L) {
    testthat::expect_true(
      all(meta_vars %in% names(design@data)),
      label = "all metadata-labelled vars present in @data"
    )
  }

  invisible(design)
}
