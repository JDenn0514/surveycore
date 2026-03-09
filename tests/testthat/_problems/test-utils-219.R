# Extracted from test-utils.R:219

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "surveycore", path = "..")
attach(test_env, warn.conflicts = FALSE)

# prequel ----------------------------------------------------------------------
make_taylor <- function(seed = 42L) {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = seed)
  as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE)
}
make_rep <- function(seed = 42L) {
  df <- make_survey_data(
    n = 50L, n_psu = 10L, n_strata = 2L,
    design = "replicate", type = "brr", seed = seed
  )
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  as_survey_repweights(df, weights = wt, repweights = tidyselect::all_of(repwt_cols), type = "BRR")
}
make_twophase <- function(seed = 42L) {
  df <- make_survey_data(
    n = 60L, n_psu = 10L, n_strata = 2L, design = "twophase", seed = seed
  )
  phase1 <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE)
  as_survey_twophase(phase1, subset = subset)
}
make_twophase_with_p2 <- function(seed = 42L) {
  set.seed(seed)
  df <- data.frame(
    wt        = runif(30L, 0.8, 1.5),
    arm       = rep(c("A", "B", "C"), 10L),
    strata    = rep(c("S1", "S2"), 15L),
    sampfrac  = rep(c(0.5, 0.6, 0.4), 10L),
    in_phase2 = c(rep(TRUE, 15L), rep(FALSE, 15L)),
    y         = rnorm(30L)
  )
  phase1 <- as_survey(df, weights = wt, strata = strata)
  as_survey_twophase(
    phase1,
    strata2 = arm,
    probs2  = sampfrac,
    subset  = in_phase2,
    method  = "full"
  )
}
make_calibrated <- function() {
  df <- data.frame(y = 1:10, w = rep(1, 10))
  as_survey_calibrated(df, weights = w)
}

# test -------------------------------------------------------------------------
d    <- make_calibrated()
flat <- surveycore:::.get_design_vars_flat(d)
expect_true(is.character(flat))
expect_length(flat, 0L)
