# Extracted from test-variance-twophase.R:419

# test -------------------------------------------------------------------------
df  <- make_survey_data(design = "twophase", n = 100L, n_psu = 10L,
                           n_strata = 2L, seed = 21L)
ph1 <- as_survey(df, ids = psu, weights = wt, strata = strata)
