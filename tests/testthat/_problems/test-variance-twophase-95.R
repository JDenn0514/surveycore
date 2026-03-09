# Extracted from test-variance-twophase.R:95

# test -------------------------------------------------------------------------
df  <- make_survey_data(design = "twophase", n = 200L, n_psu = 20L,
                           n_strata = 2L, seed = 6L)
ph1 <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
