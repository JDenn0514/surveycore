# Extracted from test-variance-twophase.R:467

# test -------------------------------------------------------------------------
d <- make_survey_data(n = 100, n_psu = 10, n_strata = 2,
                        design = "twophase", seed = 70)
phase1 <- as_survey(d, ids = psu, weights = wt, strata = strata,
                      fpc = fpc, nest = TRUE)
