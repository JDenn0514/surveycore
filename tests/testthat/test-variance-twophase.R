# test-variance-twophase.R
# Tests for the two-phase variance engine: .twophasevar() and associated helpers.

skip_on_cran()

# ── Section 1: Error paths ────────────────────────────────────────────────────

test_that('get_means() errors for method = "full" with no phase 2 design info', {
  df <- make_survey_data(
    design = "twophase",
    n = 100L,
    n_psu = 10L,
    n_strata = 2L,
    seed = 10L
  )
  ph1 <- as_survey(df, ids = psu, weights = wt, strata = strata)
  # method = "full" with no ids2/strata2/probs2 → error at estimation time
  d <- as_survey_twophase(ph1, subset = subset, method = "full")

  expect_error(
    get_means(d, y1),
    class = "surveycore_error_full_requires_phase2"
  )
  expect_snapshot(
    error = TRUE,
    get_means(d, y1)
  )
})

# ── Section 2: Oracle — survival::pbc ─────────────────────────────────────────

test_that("get_means() full method matches survey::svymean on pbc [oracle]", {
  skip_if_not_installed("survival")
  skip_if_not_installed("survey")

  data("pbc", package = "survival", envir = environment())
  pbc_ph1 <- subset(pbc, !is.na(trt))
  pbc_ph1$in_ph2 <- !is.na(pbc_ph1$chol)
  pbc_ph1$wt <- 1
  pbc_ph1$row_id <- seq_len(nrow(pbc_ph1))
  pbc_ph1$pi2 <- mean(pbc_ph1$in_ph2)

  ph1_sc <- as_survey(pbc_ph1, ids = row_id, weights = wt)
  d_sc <- as_survey_twophase(
    ph1_sc,
    probs2 = pi2,
    subset = in_ph2,
    method = "full"
  )

  d_sv <- survey::twophase(
    id = list(~1, ~1),
    data = pbc_ph1,
    subset = ~in_ph2,
    method = "approx"
  )

  sc_est <- get_means(d_sc, chol, variance = c("se", "ci"))
  sv_est <- survey::svymean(~chol, d_sv, na.rm = TRUE)

  expect_equal(sc_est$mean, coef(sv_est)[["chol"]], tolerance = 1e-10)
  expect_equal(sc_est$se, as.numeric(survey::SE(sv_est)), tolerance = 1e-8)
  expect_equal(sc_est$ci_low, confint(sv_est)[1], tolerance = 1e-6)
  expect_equal(sc_est$ci_high, confint(sv_est)[2], tolerance = 1e-6)
})

test_that("get_means() approx method matches survey::svymean on pbc [oracle]", {
  skip_if_not_installed("survival")
  skip_if_not_installed("survey")

  data("pbc", package = "survival", envir = environment())
  pbc_ph1 <- subset(pbc, !is.na(trt))
  pbc_ph1$in_ph2 <- !is.na(pbc_ph1$chol)
  pbc_ph1$wt <- 1
  pbc_ph1$row_id <- seq_len(nrow(pbc_ph1))

  ph1_sc <- as_survey(pbc_ph1, ids = row_id, weights = wt)
  d_sc <- as_survey_twophase(ph1_sc, subset = in_ph2, method = "approx")

  d_sv <- survey::twophase(
    id = list(~1, ~1),
    data = pbc_ph1,
    subset = ~in_ph2,
    method = "approx"
  )

  sc_est <- get_means(d_sc, chol, variance = c("se", "ci"))
  sv_est <- survey::svymean(~chol, d_sv, na.rm = TRUE)

  expect_equal(sc_est$mean, coef(sv_est)[["chol"]], tolerance = 1e-10)
  expect_equal(sc_est$se, as.numeric(survey::SE(sv_est)), tolerance = 1e-8)
  expect_equal(sc_est$ci_low, confint(sv_est)[1], tolerance = 1e-6)
  expect_equal(sc_est$ci_high, confint(sv_est)[2], tolerance = 1e-6)
})

test_that("get_totals() full method matches survey::svytotal on pbc [oracle]", {
  skip_if_not_installed("survival")
  skip_if_not_installed("survey")

  data("pbc", package = "survival", envir = environment())
  pbc_ph1 <- subset(pbc, !is.na(trt))
  pbc_ph1$in_ph2 <- !is.na(pbc_ph1$chol)
  pbc_ph1$wt <- 1
  pbc_ph1$row_id <- seq_len(nrow(pbc_ph1))
  pbc_ph1$pi2 <- mean(pbc_ph1$in_ph2)

  ph1_sc <- as_survey(pbc_ph1, ids = row_id, weights = wt)
  d_sc <- as_survey_twophase(
    ph1_sc,
    probs2 = pi2,
    subset = in_ph2,
    method = "full"
  )

  d_sv <- survey::twophase(
    id = list(~1, ~1),
    data = pbc_ph1,
    subset = ~in_ph2,
    method = "approx"
  )

  sc_est <- get_totals(d_sc, chol, variance = c("se", "ci"))
  sv_est <- survey::svytotal(~chol, d_sv, na.rm = TRUE)

  expect_equal(sc_est$total, coef(sv_est)[["chol"]], tolerance = 1e-10)
  expect_equal(sc_est$se, as.numeric(survey::SE(sv_est)), tolerance = 1e-8)
  expect_equal(sc_est$ci_low, confint(sv_est)[1], tolerance = 1e-6)
  expect_equal(sc_est$ci_high, confint(sv_est)[2], tolerance = 1e-6)
})

test_that("get_totals() approx method matches survey::svytotal on pbc [oracle]", {
  skip_if_not_installed("survival")
  skip_if_not_installed("survey")

  data("pbc", package = "survival", envir = environment())
  pbc_ph1 <- subset(pbc, !is.na(trt))
  pbc_ph1$in_ph2 <- !is.na(pbc_ph1$chol)
  pbc_ph1$wt <- 1
  pbc_ph1$row_id <- seq_len(nrow(pbc_ph1))

  ph1_sc <- as_survey(pbc_ph1, ids = row_id, weights = wt)
  d_sc <- as_survey_twophase(ph1_sc, subset = in_ph2, method = "approx")

  d_sv <- survey::twophase(
    id = list(~1, ~1),
    data = pbc_ph1,
    subset = ~in_ph2,
    method = "approx"
  )

  sc_est <- get_totals(d_sc, chol, variance = c("se", "ci"))
  sv_est <- survey::svytotal(~chol, d_sv, na.rm = TRUE)

  expect_equal(sc_est$total, coef(sv_est)[["chol"]], tolerance = 1e-10)
  expect_equal(sc_est$se, as.numeric(survey::SE(sv_est)), tolerance = 1e-8)
  expect_equal(sc_est$ci_low, confint(sv_est)[1], tolerance = 1e-6)
  expect_equal(sc_est$ci_high, confint(sv_est)[2], tolerance = 1e-6)
})

# ── Section 3: Oracle — survival::nwtco ───────────────────────────────────────

test_that("get_means() full method matches survey::svymean on nwtco [oracle]", {
  skip_if_not_installed("survival")
  skip_if_not_installed("survey")

  data("nwtco", package = "survival", envir = environment())
  nwtco$in_ph2 <- nwtco$rel == 1 | nwtco$in.subcohort == 1
  nwtco$wt <- 1

  ph1_sc <- as_survey(nwtco, ids = seqno, weights = wt)
  d_sc <- as_survey_twophase(
    ph1_sc,
    strata2 = rel,
    subset = in_ph2,
    method = "full"
  )

  d_sv <- survey::twophase(
    id = list(~seqno, ~seqno),
    strata = list(NULL, ~rel),
    data = nwtco,
    subset = ~in_ph2,
    method = "approx"
  )

  sc_est <- get_means(d_sc, edrel, variance = c("se", "ci"))
  sv_est <- survey::svymean(~edrel, d_sv, na.rm = TRUE)

  expect_equal(sc_est$mean, coef(sv_est)[["edrel"]], tolerance = 1e-10)
  expect_equal(sc_est$se, as.numeric(survey::SE(sv_est)), tolerance = 1e-8)
  expect_equal(sc_est$ci_low, confint(sv_est)[1], tolerance = 1e-6)
  expect_equal(sc_est$ci_high, confint(sv_est)[2], tolerance = 1e-6)
})

test_that("get_means() approx method matches survey::svymean on nwtco [oracle]", {
  skip_if_not_installed("survival")
  skip_if_not_installed("survey")

  data("nwtco", package = "survival", envir = environment())
  nwtco$in_ph2 <- nwtco$rel == 1 | nwtco$in.subcohort == 1
  nwtco$wt <- 1

  ph1_sc <- as_survey(nwtco, ids = seqno, weights = wt)
  d_sc <- as_survey_twophase(
    ph1_sc,
    strata2 = rel,
    subset = in_ph2,
    method = "approx"
  )

  d_sv <- survey::twophase(
    id = list(~seqno, ~seqno),
    strata = list(NULL, ~rel),
    data = nwtco,
    subset = ~in_ph2,
    method = "approx"
  )

  sc_est <- get_means(d_sc, edrel, variance = c("se", "ci"))
  sv_est <- survey::svymean(~edrel, d_sv, na.rm = TRUE)

  expect_equal(sc_est$mean, coef(sv_est)[["edrel"]], tolerance = 1e-10)
  expect_equal(sc_est$se, as.numeric(survey::SE(sv_est)), tolerance = 1e-8)
  expect_equal(sc_est$ci_low, confint(sv_est)[1], tolerance = 1e-6)
  expect_equal(sc_est$ci_high, confint(sv_est)[2], tolerance = 1e-6)
})

test_that("get_totals() full method matches survey::svytotal on nwtco [oracle]", {
  skip_if_not_installed("survival")
  skip_if_not_installed("survey")

  data("nwtco", package = "survival", envir = environment())
  nwtco$in_ph2 <- nwtco$rel == 1 | nwtco$in.subcohort == 1
  nwtco$wt <- 1

  ph1_sc <- as_survey(nwtco, ids = seqno, weights = wt)
  d_sc <- as_survey_twophase(
    ph1_sc,
    strata2 = rel,
    subset = in_ph2,
    method = "full"
  )

  d_sv <- survey::twophase(
    id = list(~seqno, ~seqno),
    strata = list(NULL, ~rel),
    data = nwtco,
    subset = ~in_ph2,
    method = "approx"
  )

  sc_est <- get_totals(d_sc, edrel, variance = c("se", "ci"))
  sv_est <- survey::svytotal(~edrel, d_sv, na.rm = TRUE)

  expect_equal(sc_est$total, coef(sv_est)[["edrel"]], tolerance = 1e-10)
  expect_equal(sc_est$se, as.numeric(survey::SE(sv_est)), tolerance = 1e-8)
  expect_equal(sc_est$ci_low, confint(sv_est)[1], tolerance = 1e-6)
  expect_equal(sc_est$ci_high, confint(sv_est)[2], tolerance = 1e-6)
})

test_that("get_totals() approx method matches survey::svytotal on nwtco [oracle]", {
  skip_if_not_installed("survival")
  skip_if_not_installed("survey")

  data("nwtco", package = "survival", envir = environment())
  nwtco$in_ph2 <- nwtco$rel == 1 | nwtco$in.subcohort == 1
  nwtco$wt <- 1

  ph1_sc <- as_survey(nwtco, ids = seqno, weights = wt)
  d_sc <- as_survey_twophase(
    ph1_sc,
    strata2 = rel,
    subset = in_ph2,
    method = "approx"
  )

  d_sv <- survey::twophase(
    id = list(~seqno, ~seqno),
    strata = list(NULL, ~rel),
    data = nwtco,
    subset = ~in_ph2,
    method = "approx"
  )

  sc_est <- get_totals(d_sc, edrel, variance = c("se", "ci"))
  sv_est <- survey::svytotal(~edrel, d_sv, na.rm = TRUE)

  expect_equal(sc_est$total, coef(sv_est)[["edrel"]], tolerance = 1e-10)
  expect_equal(sc_est$se, as.numeric(survey::SE(sv_est)), tolerance = 1e-8)
  expect_equal(sc_est$ci_low, confint(sv_est)[1], tolerance = 1e-6)
  expect_equal(sc_est$ci_high, confint(sv_est)[2], tolerance = 1e-6)
})

# ── Section 4: Additional design variants ─────────────────────────────────────

test_that("get_corr() works for survey_twophase design", {
  d <- make_survey_data(
    n = 100,
    n_psu = 10,
    n_strata = 2,
    design = "twophase",
    seed = 70
  )
  phase1 <- as_survey(
    d,
    ids = psu,
    weights = wt,
    strata = strata,
    fpc = fpc,
    nest = TRUE
  )
  sc <- as_survey_twophase(
    phase1,
    subset = subset,
    ids2 = psu,
    strata2 = strata
  )

  result <- get_corr(sc, x = c(y1, y2), variance = "se")
  test_result_invariants(result, "survey_corr")
  expect_true(is.finite(result$r[[1L]]))
  expect_gte(result$se[[1L]], 0)
})

test_that("get_corr() twophase with small domain returns NA r", {
  d <- make_survey_data(
    n = 80,
    n_psu = 10,
    n_strata = 2,
    design = "twophase",
    seed = 71
  )
  phase1 <- as_survey(
    d,
    ids = psu,
    weights = wt,
    strata = strata,
    fpc = fpc,
    nest = TRUE
  )
  sc <- as_survey_twophase(
    phase1,
    subset = subset,
    ids2 = psu,
    strata2 = strata
  )
  # Keep only 1 phase-2 row in domain via domain column
  ph2_rows <- which(d$subset)
  sc@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <-
    seq_len(nrow(d)) == ph2_rows[[1L]]

  result <- get_corr(sc, x = c(y1, y2), variance = "se")
  expect_true(is.na(result$r[[1L]]))
})

test_that("twophase design with nested phase1 PSUs covers nest branch in .twophasevar()", {
  d <- make_survey_data(
    n = 100,
    n_psu = 10,
    n_strata = 2,
    design = "twophase",
    seed = 72
  )
  phase1 <- as_survey(
    d,
    ids = psu,
    weights = wt,
    strata = strata,
    fpc = fpc,
    nest = TRUE
  )
  sc <- as_survey_twophase(
    phase1,
    subset = subset,
    ids2 = psu,
    strata2 = strata
  )

  result <- get_means(sc, y1, variance = "se")
  expect_true(is.finite(result$mean[[1L]]))
  expect_gte(result$se[[1L]], 0)
})

test_that("get_totals() returns finite values for survey_twophase", {
  d <- make_survey_data(
    n = 80,
    n_psu = 10,
    n_strata = 2,
    design = "twophase",
    seed = 73
  )
  phase1 <- as_survey(d, ids = psu, weights = wt, strata = strata, nest = TRUE)
  sc <- as_survey_twophase(
    phase1,
    subset = subset,
    ids2 = psu,
    strata2 = strata
  )

  result <- get_totals(sc, y1, variance = "se")
  expect_true(is.finite(result$total[[1L]]))
  expect_gte(result$se[[1L]], 0)
})

test_that("get_means() twophase with method='simple' returns finite estimates", {
  d <- make_survey_data(
    n = 100,
    n_psu = 10,
    n_strata = 2,
    design = "twophase",
    seed = 901
  )
  phase1 <- as_survey(
    d,
    ids = psu,
    weights = wt,
    strata = strata,
    fpc = fpc,
    nest = TRUE
  )
  sc <- suppressWarnings(
    as_survey_twophase(phase1, subset = subset, method = "simple")
  )
  result <- get_means(sc, y1, variance = "se")
  test_result_invariants(result, "survey_means")
  expect_true(is.finite(result$mean[[1L]]))
})

# ── Section 5: SRS / replicate phase-1 designs ──────────────────────────────

test_that("two-phase with SRS phase-1 matches survey [oracle]", {
  skip_if_not_installed("survival")
  skip_if_not_installed("survey")

  # Use the pbc dataset: SRS phase-1 (no clusters, no strata)
  data("pbc", package = "survival", envir = environment())
  pbc_ph1 <- subset(pbc, !is.na(trt))
  pbc_ph1$in_ph2 <- !is.na(pbc_ph1$chol)
  pbc_ph1$wt <- 1

  ph1_sc <- as_survey(pbc_ph1, weights = wt)
  d_sc <- as_survey_twophase(ph1_sc, subset = in_ph2, method = "approx")

  d_sv <- survey::twophase(
    id = list(~1, ~1),
    data = pbc_ph1,
    subset = ~in_ph2,
    method = "approx"
  )

  sc_est <- get_means(d_sc, chol, variance = c("se", "ci"))
  sv_est <- survey::svymean(~chol, d_sv, na.rm = TRUE)

  expect_equal(sc_est$mean, coef(sv_est)[["chol"]], tolerance = 1e-10)
  expect_equal(sc_est$se, as.numeric(survey::SE(sv_est)), tolerance = 1e-8)
  expect_equal(sc_est$ci_low, confint(sv_est)[1], tolerance = 1e-6)
  expect_equal(sc_est$ci_high, confint(sv_est)[2], tolerance = 1e-6)
})

test_that("two-phase with SRS phase-1 get_totals matches survey [oracle]", {
  skip_if_not_installed("survival")
  skip_if_not_installed("survey")

  data("pbc", package = "survival", envir = environment())
  pbc_ph1 <- subset(pbc, !is.na(trt))
  pbc_ph1$in_ph2 <- !is.na(pbc_ph1$chol)
  pbc_ph1$wt <- 1

  ph1_sc <- as_survey(pbc_ph1, weights = wt)
  d_sc <- as_survey_twophase(ph1_sc, subset = in_ph2, method = "approx")

  d_sv <- survey::twophase(
    id = list(~1, ~1),
    data = pbc_ph1,
    subset = ~in_ph2,
    method = "approx"
  )

  sc_est <- get_totals(d_sc, chol, variance = c("se", "ci"))
  sv_est <- survey::svytotal(~chol, d_sv, na.rm = TRUE)

  expect_equal(sc_est$total, coef(sv_est)[["chol"]], tolerance = 1e-10)
  expect_equal(sc_est$se, as.numeric(survey::SE(sv_est)), tolerance = 1e-8)
  expect_equal(sc_est$ci_low, confint(sv_est)[1], tolerance = 1e-6)
  expect_equal(sc_est$ci_high, confint(sv_est)[2], tolerance = 1e-6)
})

test_that("two-phase with survey_replicate phase-1 constructs and estimates", {
  df <- make_survey_data(
    n = 100,
    n_psu = 10L,
    design = "replicate",
    seed = 801L
  )
  df$in_phase2 <- c(rep(TRUE, 50), rep(FALSE, 50))

  phase_rep <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "JK1"
  )
  tp <- as_survey_twophase(phase_rep, subset = in_phase2, method = "approx")

  expect_true(S7::S7_inherits(tp, survey_twophase))

  result <- get_means(tp, y1, variance = "se")
  expect_true(is.finite(result$mean[[1L]]))
  expect_gte(result$se[[1L]], 0)
})
