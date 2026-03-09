# Extracted from test-variance-twophase.R:347

# test -------------------------------------------------------------------------
skip_if_not_installed("survival")
skip_if_not_installed("survey")
data("nwtco", package = "survival", envir = environment())
nwtco$in_ph2 <- nwtco$rel == 1 | nwtco$in.subcohort == 1
nwtco$wt     <- 1
ph1_sc <- as_survey(nwtco, ids = seqno, weights = wt)
