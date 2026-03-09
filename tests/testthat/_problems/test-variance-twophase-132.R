# Extracted from test-variance-twophase.R:132

# test -------------------------------------------------------------------------
df_nest <- data.frame(
    psu    = c(rep(1:5, each = 2), rep(1:5, each = 2)),
    strata = c(rep(1L, 10), rep(2L, 10)),
    weight = rep(1, 20),
    y1     = rnorm(20),
    subset = rep(c(TRUE, FALSE), 10)
  )
ph1 <- as_survey(df_nest, ids = psu, weights = weight, strata = strata,
                   nest = TRUE)
