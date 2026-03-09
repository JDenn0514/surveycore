# Extracted from test-variance-twophase.R:143

# test -------------------------------------------------------------------------
df  <- make_survey_data(design = "twophase", n = 100L, n_psu = 10L,
                           n_strata = 2L, seed = 10L)
ph1 <- as_survey(df, ids = psu, weights = wt, strata = strata)
