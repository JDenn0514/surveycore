# Extracted from test-variance-twophase.R:436

# test -------------------------------------------------------------------------
df  <- make_survey_data(design = "twophase", n = 100L, n_psu = 10L,
                           n_strata = 2L, phase2_frac = 0.95, seed = 22L)
ph1 <- as_survey(df, ids = psu, weights = wt, strata = strata)
