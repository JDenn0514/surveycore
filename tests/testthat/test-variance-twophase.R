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
#
# The "full" blocks in Sections 2 and 3 compare against survey::twophase(
# method = "full"), the twophase2 design, and the "approx" blocks against
# method = "approx". Phase 1 is the whole cohort with no weights, which both
# packages read as an iid sample. Until issue #329 the "full" blocks built
# survey's "approx" object, so they passed only while surveycore's "full"
# computed the approx variance.

test_that("get_means() full method matches survey::svymean on pbc [oracle]", {
  skip_if_not_installed("survival")
  skip_if_not_installed("survey")

  data("pbc", package = "survival", envir = environment())
  pbc_ph1 <- subset(pbc, !is.na(trt))
  pbc_ph1$in_ph2 <- !is.na(pbc_ph1$chol)
  pbc_ph1$row_id <- seq_len(nrow(pbc_ph1))
  pbc_ph1$pi2 <- mean(pbc_ph1$in_ph2)

  expect_warning(
    ph1_sc <- as_survey(pbc_ph1, ids = row_id),
    class = "surveycore_warning_srs_no_weights"
  )
  d_sc <- as_survey_twophase(
    ph1_sc,
    probs2 = pi2,
    subset = in_ph2,
    method = "full"
  )

  d_sv <- survey::twophase(
    id = list(~row_id, ~row_id),
    probs = list(NULL, ~pi2),
    data = pbc_ph1,
    subset = ~in_ph2,
    method = "full"
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
  pbc_ph1$row_id <- seq_len(nrow(pbc_ph1))
  pbc_ph1$pi2 <- mean(pbc_ph1$in_ph2)

  expect_warning(
    ph1_sc <- as_survey(pbc_ph1, ids = row_id),
    class = "surveycore_warning_srs_no_weights"
  )
  d_sc <- as_survey_twophase(
    ph1_sc,
    probs2 = pi2,
    subset = in_ph2,
    method = "full"
  )

  d_sv <- survey::twophase(
    id = list(~row_id, ~row_id),
    probs = list(NULL, ~pi2),
    data = pbc_ph1,
    subset = ~in_ph2,
    method = "full"
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

  expect_warning(
    ph1_sc <- as_survey(nwtco, ids = seqno),
    class = "surveycore_warning_srs_no_weights"
  )
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
    method = "full"
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

  expect_warning(
    ph1_sc <- as_survey(nwtco, ids = seqno),
    class = "surveycore_warning_srs_no_weights"
  )
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
    method = "full"
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

# ── Section 5: SRS phase-1 designs ──────────────────────────────────────────

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

# ── Section 6: Oracle — method = "full" with phase-1 weights (issue #329) ────
#
# Phase 1 is a stratified cluster sample with unequal weights, so the
# phase-1 term of the twophase2 variance is not the identity. survey's
# method = "full" refuses a weights argument, so the same weight column goes
# in as probs = ~I(1 / wt); no number surveycore computed reaches survey.
#
# Two phase-2 designs: strata2 subsamples rows within the phase-1 strata, and
# ids2 subsamples whole phase-1 clusters, three per stratum. Under ids2 the
# phase-2 probability is the cluster fraction, which the row fraction
# surveycore used before #329 got wrong for totals.

full_oracle_data <- function() {
  df <- make_survey_data(
    n = 400L,
    n_psu = 40L,
    n_strata = 8L,
    design = "twophase",
    seed = 7L
  )
  clusters <- unique(df[c("strata", "psu")])
  set.seed(3L)
  kept <- unlist(lapply(split(clusters$psu, clusters$strata), sample, 3L))
  df$in_clusters <- df$psu %in% kept
  df
}

full_oracle_phase1 <- function(df) {
  as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
}

full_oracle_strata2 <- function() {
  df <- full_oracle_data()
  sc <- as_survey_twophase(
    full_oracle_phase1(df),
    strata2 = strata,
    subset = subset,
    method = "full"
  )
  sv <- survey::twophase(
    id = list(~psu, ~1),
    strata = list(~strata, ~strata),
    probs = list(~ I(1 / wt), NULL),
    data = df,
    subset = ~subset,
    method = "full"
  )
  list(sc = sc, sv = sv)
}

full_oracle_ids2 <- function() {
  df <- full_oracle_data()
  sc <- as_survey_twophase(
    full_oracle_phase1(df),
    ids2 = psu,
    subset = in_clusters,
    method = "full"
  )
  sv <- survey::twophase(
    id = list(~psu, ~psu),
    strata = list(~strata, NULL),
    probs = list(~ I(1 / wt), NULL),
    data = df,
    subset = ~in_clusters,
    method = "full"
  )
  list(sc = sc, sv = sv)
}

# Mark the domain group == "A" on both sides
full_oracle_filter <- function(designs) {
  sc <- designs$sc
  sc@data[[SURVEYCORE_DOMAIN_COL]] <- sc@data$group == "A"
  list(sc = sc, sv = subset(designs$sv, group == "A"))
}

expect_full_mean_oracle <- function(designs) {
  sc_est <- get_means(
    designs$sc,
    y1,
    variance = c("se", "ci"),
    min_cell_n = 1L
  )
  sv_est <- survey::svymean(~y1, designs$sv)
  expect_equal(sc_est$mean, coef(sv_est)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_est$se, as.numeric(survey::SE(sv_est)), tolerance = 1e-8)
  expect_equal(sc_est$ci_low, confint(sv_est)[1], tolerance = 1e-6)
  expect_equal(sc_est$ci_high, confint(sv_est)[2], tolerance = 1e-6)
}

expect_full_total_oracle <- function(designs) {
  sc_est <- get_totals(
    designs$sc,
    y1,
    variance = c("se", "ci"),
    min_cell_n = 1L
  )
  sv_est <- survey::svytotal(~y1, designs$sv)
  expect_equal(sc_est$total, coef(sv_est)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_est$se, as.numeric(survey::SE(sv_est)), tolerance = 1e-8)
  expect_equal(sc_est$ci_low, confint(sv_est)[1], tolerance = 1e-6)
  expect_equal(sc_est$ci_high, confint(sv_est)[2], tolerance = 1e-6)
}

# On a domain, survey's restricted object carries zero-weight rows, and
# svyglm() reports them once from each of its two summary.glm() calls.
expect_full_glm_oracle <- function(designs, domain = FALSE) {
  sc_fit <- survey_glm(designs$sc, y1 ~ y2)
  if (domain) {
    zero_weight <- "observations with zero weight not used"
    expect_warning(
      expect_warning(
        sv_fit <- survey::svyglm(y1 ~ y2, designs$sv),
        zero_weight
      ),
      zero_weight
    )
  } else {
    sv_fit <- survey::svyglm(y1 ~ y2, designs$sv)
  }
  expect_equal(
    unname(coef(sc_fit)),
    unname(coef(sv_fit)),
    tolerance = 1e-10
  )
  expect_equal(
    unname(sqrt(diag(vcov(sc_fit)))),
    unname(survey::SE(sv_fit)),
    tolerance = 1e-8
  )
}

test_that("get_means() full method with strata2 matches survey twophase2 [oracle]", {
  skip_if_not_installed("survey")
  designs <- full_oracle_strata2()
  test_invariants(designs$sc)
  expect_full_mean_oracle(designs)
})

test_that("get_means() full method with strata2 on a domain matches survey twophase2 [oracle]", {
  skip_if_not_installed("survey")
  expect_full_mean_oracle(full_oracle_filter(full_oracle_strata2()))
})

test_that("get_means() full method with ids2 matches survey twophase2 [oracle]", {
  skip_if_not_installed("survey")
  expect_full_mean_oracle(full_oracle_ids2())
})

test_that("get_means() full method with ids2 on a domain matches survey twophase2 [oracle]", {
  skip_if_not_installed("survey")
  expect_full_mean_oracle(full_oracle_filter(full_oracle_ids2()))
})

test_that("get_totals() full method with strata2 matches survey twophase2 [oracle]", {
  skip_if_not_installed("survey")
  expect_full_total_oracle(full_oracle_strata2())
})

test_that("get_totals() full method with strata2 on a domain matches survey twophase2 [oracle]", {
  skip_if_not_installed("survey")
  expect_full_total_oracle(full_oracle_filter(full_oracle_strata2()))
})

test_that("get_totals() full method with ids2 matches survey twophase2 [oracle]", {
  skip_if_not_installed("survey")
  expect_full_total_oracle(full_oracle_ids2())
})

test_that("get_totals() full method with ids2 on a domain matches survey twophase2 [oracle]", {
  skip_if_not_installed("survey")
  expect_full_total_oracle(full_oracle_filter(full_oracle_ids2()))
})

test_that("survey_glm() full method with strata2 matches survey twophase2 [oracle]", {
  skip_if_not_installed("survey")
  expect_full_glm_oracle(full_oracle_strata2())
})

test_that("survey_glm() full method with strata2 on a domain matches survey twophase2 [oracle]", {
  skip_if_not_installed("survey")
  expect_full_glm_oracle(
    full_oracle_filter(full_oracle_strata2()),
    domain = TRUE
  )
})

test_that("survey_glm() full method with ids2 matches survey twophase2 [oracle]", {
  skip_if_not_installed("survey")
  expect_full_glm_oracle(full_oracle_ids2())
})

test_that("survey_glm() full method with ids2 on a domain matches survey twophase2 [oracle]", {
  skip_if_not_installed("survey")
  expect_full_glm_oracle(
    full_oracle_filter(full_oracle_ids2()),
    domain = TRUE
  )
})

# A phase-1 fpc makes the phase-1 term without-replacement: pairs of clusters
# in one stratum get the off-diagonal -(1 - p) / (n_h - 1). Every stratum
# here keeps five clusters, so survey's misread n_h (see the block below)
# reads the right count and survey is a valid oracle.
test_that("get_means() full method with a phase-1 fpc matches survey twophase2 [oracle]", {
  skip_if_not_installed("survey")
  df <- full_oracle_data()
  ph1 <- as_survey(
    df,
    ids = psu,
    weights = wt,
    strata = strata,
    fpc = fpc,
    nest = TRUE
  )
  sc <- as_survey_twophase(
    ph1,
    strata2 = strata,
    subset = subset,
    method = "full"
  )
  sv <- survey::twophase(
    id = list(~psu, ~1),
    strata = list(~strata, ~strata),
    probs = list(~ I(1 / wt), NULL),
    fpc = list(~fpc, NULL),
    data = df,
    subset = ~subset,
    method = "full"
  )
  expect_full_mean_oracle(list(sc = sc, sv = sv))
  expect_full_total_oracle(list(sc = sc, sv = sv))
})

test_that("get_totals() full method with fpc2 matches survey twophase2 [oracle]", {
  skip_if_not_installed("survey")
  df <- full_oracle_data()
  df$n_stratum <- as.numeric(stats::ave(df$y1, df$strata, FUN = length))
  sc <- as_survey_twophase(
    full_oracle_phase1(df),
    strata2 = strata,
    fpc2 = n_stratum,
    subset = subset,
    method = "full"
  )
  sv <- survey::twophase(
    id = list(~psu, ~1),
    strata = list(~strata, ~strata),
    probs = list(~ I(1 / wt), NULL),
    fpc = list(NULL, ~n_stratum),
    data = df,
    subset = ~subset,
    method = "full"
  )
  expect_full_total_oracle(list(sc = sc, sv = sv))
})

# survey 4.5 cannot be the oracle when a phase-1 fpc meets strata holding
# unequal numbers of clusters: survey:::Dcheck_multi_subset() hands
# Dcheck_subset() a row-length sampsize that it indexes by cluster, so n_h is
# read off the wrong rows, and on this design survey's variance of the total
# is negative. The reference is the textbook double-expansion form written
# out pair by pair, (D1 + D2 - D1 o D2)_ij, over the phase-2 rows.
test_that("get_totals() full method with a phase-1 fpc and unequal strata matches the pairwise HT form", {
  df <- full_oracle_data()
  clusters <- unique(df[c("strata", "psu")])
  dropped <- unlist(lapply(
    split(clusters$psu, clusters$strata)[c(1L, 3L, 4L)],
    function(p) p[1:2]
  ))
  df <- df[!df$psu %in% dropped, ]
  ph1 <- as_survey(
    df,
    ids = psu,
    weights = wt,
    strata = strata,
    fpc = fpc,
    nest = TRUE
  )
  sc <- as_survey_twophase(
    ph1,
    strata2 = strata,
    subset = subset,
    method = "full"
  )
  sc_est <- get_totals(sc, y1, variance = "se", min_cell_n = 1L)

  ph2 <- df[df$subset, ]
  n1_h <- tapply(df$psu, df$strata, function(p) length(unique(p)))
  n2_h <- table(ph2$strata)
  n_all <- table(df$strata)
  p1 <- 1 / ph2$wt[match(ph2$psu, ph2$psu)]
  p2 <- as.numeric(n2_h[ph2$strata] / n_all[ph2$strata])
  x <- ph2$y1 * ph2$wt / p2
  m <- nrow(ph2)
  v <- 0
  for (i in seq_len(m)) {
    for (j in seq_len(m)) {
      same_stratum <- ph2$strata[i] == ph2$strata[j]
      d1 <- if (ph2$psu[i] == ph2$psu[j]) {
        1 - p1[i]
      } else if (same_stratum) {
        -(1 - p1[i]) / (n1_h[[ph2$strata[i]]] - 1)
      } else {
        0
      }
      d2 <- if (i == j) {
        1 - p2[i]
      } else if (same_stratum) {
        -(1 - p2[i]) / (n2_h[[ph2$strata[i]]] - 1)
      } else {
        0
      }
      v <- v + x[i] * x[j] * (d1 + d2 - d1 * d2)
    }
  }

  expect_equal(sc_est$total, sum(x), tolerance = 1e-10)
  expect_equal(sc_est$se, sqrt(v), tolerance = 1e-8)
})
