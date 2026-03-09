# Extracted from test-variance-twophase.R:170

# test -------------------------------------------------------------------------
skip_if_not_installed("survival")
skip_if_not_installed("survey")
data("pbc", package = "survival", envir = environment())
pbc_ph1        <- subset(pbc, !is.na(trt))
pbc_ph1$in_ph2 <- !is.na(pbc_ph1$chol)
pbc_ph1$wt     <- 1
pbc_ph1$row_id <- seq_len(nrow(pbc_ph1))
pbc_ph1$pi2    <- mean(pbc_ph1$in_ph2)
ph1_sc   <- as_survey(pbc_ph1, ids = row_id, weights = wt)
