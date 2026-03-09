# Extracted from test-variance-twophase.R:449

# test -------------------------------------------------------------------------
df  <- make_survey_data(design = "twophase", n = 50L, n_psu = 10L,
                           n_strata = 2L, phase2_frac = 0.1, seed = 23L)
ph1 <- as_survey(df, ids = psu, weights = wt, strata = strata)
