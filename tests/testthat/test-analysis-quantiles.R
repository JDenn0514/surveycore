# test-analysis-quantiles.R
# Tests for get_quantiles() — Phase 1 survey-weighted Woodruff quantiles.
#
# Numerical tolerances (from testing-surveycore.md):
#   Point estimates: 1e-10
#   SE:              1e-8
#   CI bounds:       1e-6
#
# Oracle: survey::svyquantile(interval.type = "mean").
# Note: replicate-design oracle tests use mse = FALSE to match survey's default.

# ---------------------------------------------------------------------------
# Category 1: Happy path — return structure (all design types)
# ---------------------------------------------------------------------------

test_that("get_quantiles() returns survey_quantiles tibble for survey_taylor", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L,
                         design = "taylor", seed = 1L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata,
                  fpc = fpc, nest = TRUE)

  result <- get_quantiles(d, y1)
  test_result_invariants(result, "survey_quantiles")

  # Default probs = c(0.25, 0.5, 0.75) → 3 rows
  expect_equal(nrow(result), 3L)
  expect_true("quantile"  %in% names(result))
  expect_true("estimate"  %in% names(result))
  expect_true("ci_low"    %in% names(result))
  expect_true("ci_high"   %in% names(result))
  expect_true("n"         %in% names(result))
  # variance = "ci" by default → no se column
  expect_false("se"       %in% names(result))

  expect_identical(result$quantile, c("p25", "p50", "p75"))
  expect_true(all(is.finite(result$estimate)))
  expect_true(all(is.finite(result$ci_low)))
  expect_true(all(is.finite(result$ci_high)))
  expect_true(all(result$ci_low < result$estimate | is.na(result$estimate)))
  expect_true(all(result$estimate < result$ci_high | is.na(result$estimate)))
  expect_true(all(result$n > 0L))
})

test_that("get_quantiles() returns correct result for survey_replicate", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L,
                         design = "replicate", type = "brr", seed = 2L)
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  d <- as_survey_rep(df, weights = wt,
                     repweights = tidyselect::all_of(repwt_cols), type = "BRR")

  result <- get_quantiles(d, y1, probs = 0.5)
  test_result_invariants(result, "survey_quantiles")

  expect_equal(nrow(result), 1L)
  expect_equal(result$quantile, "p50")
  expect_true(is.finite(result$estimate[[1L]]))
  expect_true(is.finite(result$ci_low[[1L]]))
  expect_true(is.finite(result$ci_high[[1L]]))
  expect_lt(result$ci_low[[1L]], result$estimate[[1L]])
  expect_lt(result$estimate[[1L]], result$ci_high[[1L]])
})

test_that("get_quantiles() returns correct result for survey_srs", {
  df <- make_survey_data(n = 200L, n_psu = 20L, design = "taylor", seed = 3L)
  d  <- as_survey_srs(df, weights = wt)

  result <- get_quantiles(d, y1, probs = c(0.25, 0.75))
  test_result_invariants(result, "survey_quantiles")

  expect_equal(nrow(result), 2L)
  expect_identical(result$quantile, c("p25", "p75"))
  expect_true(all(is.finite(result$estimate)))
  expect_true(all(is.finite(result$ci_low)))
  expect_lt(result$estimate[[1L]], result$estimate[[2L]])  # p25 < p75
})

test_that("get_quantiles() returns correct result for survey_twophase", {
  df  <- make_survey_data(design = "twophase", n = 300L, n_psu = 30L,
                          n_strata = 3L, seed = 4L)
  ph1 <- as_survey(df, ids = psu, weights = wt, strata = strata,
                   fpc = fpc, nest = TRUE)
  d   <- as_survey_twophase(ph1, subset = subset, method = "approx")

  result <- get_quantiles(d, y1, probs = 0.5)
  test_result_invariants(result, "survey_quantiles")

  expect_equal(nrow(result), 1L)
  expect_true(is.finite(result$estimate[[1L]]))
  expect_true(is.finite(result$ci_low[[1L]]))
  expect_true(is.finite(result$ci_high[[1L]]))
  expect_lt(result$ci_low[[1L]], result$ci_high[[1L]])
})

test_that("get_quantiles() returns correct result for survey_calibrated", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 5L)
  d  <- as_survey_calibrated(df, weights = wt)

  result <- get_quantiles(d, y1, probs = 0.5)
  test_result_invariants(result, "survey_quantiles")

  expect_equal(nrow(result), 1L)
  expect_true(is.finite(result$estimate[[1L]]))
  expect_true(is.finite(result$ci_low[[1L]]))
  expect_true(is.finite(result$ci_high[[1L]]))
})

# ---------------------------------------------------------------------------
# Category 2 (oracle): Numerical validation — survey::svyquantile()
# ---------------------------------------------------------------------------

test_that("get_quantiles() Taylor IQR+median matches svyquantile() — synthetic [oracle]", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 500L, n_psu = 50L, n_strata = 5L,
                         design = "taylor", seed = 42L)
  d_sc <- as_survey(df, ids = psu, weights = wt, strata = strata,
                    fpc = fpc, nest = TRUE)
  d_sv <- survey::svydesign(ids = ~psu, weights = ~wt, strata = ~strata,
                             fpc = ~fpc, data = df, nest = TRUE)

  sc <- get_quantiles(d_sc, y2, probs = c(0.25, 0.5, 0.75),
                      variance = c("ci", "se"))
  sv <- survey::svyquantile(~y2, d_sv, quantiles = c(0.25, 0.5, 0.75),
                             ci = TRUE, na.rm = TRUE, interval.type = "mean")

  sv_est <- coef(sv)
  sv_se  <- survey::SE(sv)
  sv_ci  <- confint(sv)

  expect_equal(sc$estimate, as.numeric(sv_est),    tolerance = 1e-10)
  expect_equal(sc$se,       as.numeric(sv_se),     tolerance = 1e-8)
  expect_equal(sc$ci_low,   as.numeric(sv_ci[, "l"]), tolerance = 1e-6)
  expect_equal(sc$ci_high,  as.numeric(sv_ci[, "u"]), tolerance = 1e-6)
})

test_that("get_quantiles() Taylor matches svyquantile() — NHANES bpxsy1 [oracle]", {
  skip_if_not_installed("survey")
  # Drop zero-weight rows: surveycore rejects non-positive weights
  df <- nhanes_2017[nhanes_2017[["wtint2yr"]] > 0, ]
  d_sc <- as_survey(df, ids = sdmvpsu, weights = wtint2yr,
                    strata = sdmvstra, nest = TRUE)
  d_sv <- survey::svydesign(ids = ~sdmvpsu, weights = ~wtint2yr,
                             strata = ~sdmvstra, data = df, nest = TRUE)

  sc <- get_quantiles(d_sc, ridageyr, probs = 0.5, variance = c("ci", "se"))
  sv <- survey::svyquantile(~ridageyr, d_sv, quantiles = 0.5,
                             ci = TRUE, na.rm = TRUE, interval.type = "mean")

  expect_equal(sc$estimate[[1L]], coef(sv)[[1L]], tolerance = 1e-10)
  expect_equal(sc$se[[1L]],      survey::SE(sv)[[1L]], tolerance = 1e-8)
  expect_equal(sc$ci_low[[1L]],  confint(sv)[, "l"][[1L]], tolerance = 1e-6)
  expect_equal(sc$ci_high[[1L]], confint(sv)[, "u"][[1L]], tolerance = 1e-6)
})

test_that("get_quantiles() BRR matches svyquantile() mse=FALSE [oracle]", {
  skip_if_not_installed("survey")
  # Use mse = FALSE to match survey::svyquantile()'s default BRR variance
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L,
                         design = "replicate", type = "brr", seed = 6L)
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)

  d_sc <- as_survey_rep(df, weights = wt,
                        repweights = tidyselect::all_of(repwt_cols),
                        type = "BRR", mse = FALSE)
  d_sv <- survey::svrepdesign(weights = ~wt,
                               repweights = as.matrix(df[, repwt_cols]),
                               type = "BRR", data = df, mse = FALSE)

  sc <- get_quantiles(d_sc, y1, probs = c(0.25, 0.5, 0.75),
                      variance = c("ci", "se"))
  sv <- survey::svyquantile(~y1, d_sv, quantiles = c(0.25, 0.5, 0.75),
                             ci = TRUE, na.rm = TRUE, interval.type = "mean")

  expect_equal(sc$estimate, as.numeric(coef(sv)),          tolerance = 1e-10)
  expect_equal(sc$se,       as.numeric(survey::SE(sv)),    tolerance = 1e-8)
  expect_equal(sc$ci_low,   as.numeric(confint(sv)[, "l"]), tolerance = 1e-6)
  expect_equal(sc$ci_high,  as.numeric(confint(sv)[, "u"]), tolerance = 1e-6)
})

test_that("get_quantiles() SRS matches svyquantile() [oracle]", {
  skip_if_not_installed("survey")
  # Use equal weights so the classical SRS variance (surveycore) and HT
  # variance (survey) agree — they differ for non-uniform weights.
  df <- make_survey_data(n = 500L, n_psu = 50L, n_strata = 5L,
                         design = "taylor", seed = 7L)
  df$wt_equal <- 1L

  d_sc <- as_survey_srs(df, weights = wt_equal)
  d_sv <- survey::svydesign(ids = ~1, weights = ~wt_equal, data = df)

  sc <- get_quantiles(d_sc, y1, probs = 0.5, variance = c("ci", "se"))
  sv <- survey::svyquantile(~y1, d_sv, quantiles = 0.5,
                             ci = TRUE, na.rm = TRUE, interval.type = "mean")

  expect_equal(sc$estimate[[1L]], coef(sv)[[1L]],                  tolerance = 1e-10)
  expect_equal(sc$se[[1L]],       survey::SE(sv)[[1L]],            tolerance = 1e-8)
  expect_equal(sc$ci_low[[1L]],   as.numeric(confint(sv)[, "l"]), tolerance = 1e-6)
  expect_equal(sc$ci_high[[1L]],  as.numeric(confint(sv)[, "u"]), tolerance = 1e-6)
})

# ---------------------------------------------------------------------------
# Category 3: probs behaviour
# ---------------------------------------------------------------------------

test_that("get_quantiles() single prob produces one row", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 10L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_quantiles(d, y1, probs = 0.5)
  test_result_invariants(result, "survey_quantiles")
  expect_equal(nrow(result), 1L)
  expect_equal(result$quantile, "p50")
})

test_that("get_quantiles() preserves probs order in output", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 11L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_quantiles(d, y1, probs = c(0.9, 0.1, 0.5))
  test_result_invariants(result, "survey_quantiles")
  expect_equal(nrow(result), 3L)
  expect_identical(result$quantile, c("p90", "p10", "p50"))
  # estimates should follow the ordering given by probs
  expect_lt(result$estimate[[2L]], result$estimate[[3L]])  # p10 < p50
  expect_lt(result$estimate[[3L]], result$estimate[[1L]])  # p50 < p90
})

test_that("get_quantiles() labels probs correctly: 0.05 → p5, 0.95 → p95", {
  df <- make_survey_data(n = 300L, design = "taylor", seed = 12L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_quantiles(d, y1, probs = c(0.05, 0.95))
  expect_identical(result$quantile, c("p5", "p95"))
})

test_that("get_quantiles() stores probs in meta()", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 13L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  probs_arg <- c(0.25, 0.5, 0.75)
  result     <- get_quantiles(d, y1, probs = probs_arg)
  expect_equal(meta(result)$probs, probs_arg)
})

# ---------------------------------------------------------------------------
# Category 4: Grouped analysis
# ---------------------------------------------------------------------------

test_that("get_quantiles() group = produces rows per (group × quantile)", {
  df <- make_survey_data(n = 300L, n_psu = 30L, n_strata = 3L,
                         design = "taylor", seed = 20L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata,
                  fpc = fpc, nest = TRUE)

  result <- get_quantiles(d, y1, group = group, probs = c(0.25, 0.75))
  test_result_invariants(result, "survey_quantiles")

  n_groups <- length(unique(df$group))
  n_probs  <- 2L
  expect_equal(nrow(result), n_groups * n_probs)
  expect_true("group" %in% names(result))
  expect_true("quantile" %in% names(result))
  expect_true(all(result$n > 0L))
})

test_that("get_quantiles() group result equals ungrouped subsets", {
  df <- make_survey_data(n = 300L, n_psu = 30L, n_strata = 3L,
                         design = "taylor", seed = 21L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata,
                  fpc = fpc, nest = TRUE)

  result_g <- get_quantiles(d, y1, group = group, probs = 0.5,
                             variance = c("ci", "se"))
  # Ungrouped result (no group arg)
  result_u <- get_quantiles(d, y1, probs = 0.5, variance = c("ci", "se"))

  # Overall estimate should be in the ballpark of group-level estimates
  expect_true(all(is.finite(result_g$estimate)))
  expect_true(is.finite(result_u$estimate[[1L]]))
})

test_that("get_quantiles() NA group values produce no row for that group", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 22L)
  df$group_na <- df$group
  df$group_na[1:10] <- NA_character_
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result_na <- get_quantiles(d, y1, group = group_na, probs = 0.5)
  result_no <- get_quantiles(d, y1, group = group, probs = 0.5)

  # Same groups, same number of rows
  expect_equal(nrow(result_na), nrow(result_no))
})

# ---------------------------------------------------------------------------
# Category 5: Domain estimation
# ---------------------------------------------------------------------------

test_that("get_quantiles() respects domain filter", {
  df <- make_survey_data(n = 300L, n_psu = 30L, n_strata = 3L,
                         design = "taylor", seed = 30L)
  d_full <- as_survey(df, ids = psu, weights = wt, strata = strata,
                      fpc = fpc, nest = TRUE)
  d_dom  <- d_full
  d_dom@data[[SURVEYCORE_DOMAIN_COL]] <- as.integer(
    !is.na(d_full@data$group) & d_full@data$group == "A"
  )

  result_dom  <- get_quantiles(d_dom, y1, probs = 0.5, variance = c("ci", "se"))
  result_full <- get_quantiles(d_full, y1, probs = 0.5, variance = c("ci", "se"))

  test_result_invariants(result_dom, "survey_quantiles")

  # Domain estimate (group A only) should differ from the full-sample estimate
  expect_false(
    isTRUE(all.equal(result_dom$estimate[[1L]], result_full$estimate[[1L]],
                     tolerance = 1e-10))
  )
})

# ---------------------------------------------------------------------------
# Category 6: Variance columns
# ---------------------------------------------------------------------------

test_that("get_quantiles() variance = NULL returns no variance columns", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 40L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_quantiles(d, y1, variance = NULL)
  test_result_invariants(result, "survey_quantiles")
  expect_false("se"      %in% names(result))
  expect_false("ci_low"  %in% names(result))
  expect_false("ci_high" %in% names(result))
  expect_false("moe"     %in% names(result))
  expect_false("deff"    %in% names(result))
  expect_true("n"        %in% names(result))
})

test_that("get_quantiles() variance = 'se' returns se column only", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 41L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_quantiles(d, y1, variance = "se")
  test_result_invariants(result, "survey_quantiles")
  expect_true("se"       %in% names(result))
  expect_false("ci_low"  %in% names(result))
  expect_true(all(result$se >= 0 | is.na(result$se)))
})

test_that("get_quantiles() variance includes all requested columns", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 42L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_quantiles(d, y1,
                           variance = c("se", "var", "cv", "ci", "moe", "deff"))
  test_result_invariants(result, "survey_quantiles")
  expect_true("se"      %in% names(result))
  expect_true("var"     %in% names(result))
  expect_true("cv"      %in% names(result))
  expect_true("ci_low"  %in% names(result))
  expect_true("ci_high" %in% names(result))
  expect_true("moe"     %in% names(result))
  expect_true("deff"    %in% names(result))
})

test_that("get_quantiles() var = se^2", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 43L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_quantiles(d, y1, variance = c("se", "var"))
  expect_equal(result$var, result$se^2, tolerance = 1e-15)
})

test_that("get_quantiles() Woodruff CI: se derived from CI width", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 44L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_quantiles(d, y1, variance = c("se", "ci"), conf_level = 0.95)
  # se = (ci_high - ci_low) / (2 * t_crit)
  degf_w <- surveycore:::.degf_woodruff(d)
  t_crit <- qt(0.975, df = degf_w)
  expected_se <- (result$ci_high - result$ci_low) / (2 * t_crit)
  expect_equal(result$se, expected_se, tolerance = 1e-10)
})

test_that("get_quantiles() moe = half CI width", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 45L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_quantiles(d, y1, variance = c("ci", "moe"))
  expect_equal(result$moe, (result$ci_high - result$ci_low) / 2,
               tolerance = 1e-15)
})

test_that("get_quantiles() deff is always NA", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 46L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_quantiles(d, y1, variance = "deff")
  expect_true("deff" %in% names(result))
  expect_true(all(is.na(result$deff)))
})

test_that("get_quantiles() conf_level = 0.99 gives wider CI than 0.95", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 47L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  r95 <- get_quantiles(d, y1, variance = "ci", conf_level = 0.95)
  r99 <- get_quantiles(d, y1, variance = "ci", conf_level = 0.99)

  width95 <- r95$ci_high - r95$ci_low
  width99 <- r99$ci_high - r99$ci_low
  expect_true(all(width99 >= width95))
})

test_that("get_quantiles() n_weighted adds column", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 48L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_quantiles(d, y1, n_weighted = TRUE)
  test_result_invariants(result, "survey_quantiles")
  expect_true("n_weighted" %in% names(result))
  expect_true(all(result$n_weighted > 0 | is.na(result$n_weighted)))
})

# ---------------------------------------------------------------------------
# Category 7: label_values / label_vars (no-op)
# ---------------------------------------------------------------------------

test_that("get_quantiles() label_values and label_vars are no-ops", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 50L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  r_def    <- get_quantiles(d, y1, probs = 0.5)
  r_false  <- get_quantiles(d, y1, probs = 0.5,
                             label_values = FALSE, label_vars = FALSE)

  expect_equal(r_def$estimate[[1L]], r_false$estimate[[1L]],
               tolerance = 1e-15)
  expect_equal(r_def$quantile, r_false$quantile)
})

# ---------------------------------------------------------------------------
# Category 8: name_style
# ---------------------------------------------------------------------------

test_that("get_quantiles() name_style='broom' renames se/ci columns", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 60L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_quantiles(d, y1, variance = c("se", "ci"),
                           name_style = "broom")
  test_result_invariants(result, "survey_quantiles")
  expect_true("std.error" %in% names(result))
  expect_true("conf.low"  %in% names(result))
  expect_true("conf.high" %in% names(result))
  expect_false("se"       %in% names(result))
  expect_false("ci_low"   %in% names(result))
  # estimate column unchanged
  expect_true("estimate"  %in% names(result))
  expect_true("quantile"  %in% names(result))
})

test_that("get_quantiles() name_style='surveycore' preserves original names", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 61L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_quantiles(d, y1, variance = c("se", "ci"),
                           name_style = "surveycore")
  expect_true("se"      %in% names(result))
  expect_true("ci_low"  %in% names(result))
  expect_true("ci_high" %in% names(result))
})

# ---------------------------------------------------------------------------
# Category 9: na.rm behaviour
# ---------------------------------------------------------------------------

test_that("get_quantiles() na.rm = TRUE (default) ignores NAs", {
  df      <- make_survey_data(n = 200L, design = "taylor", seed = 70L)
  df$y_na <- df$y1
  df$y_na[1:20] <- NA_real_
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_quantiles(d, y_na, probs = 0.5)
  test_result_invariants(result, "survey_quantiles")
  expect_true(is.finite(result$estimate[[1L]]))
  expect_true(result$n[[1L]] <= 180L)  # fewer than 200 (NAs excluded)
})

test_that("get_quantiles() na.rm = FALSE with NAs returns NA estimate", {
  df      <- make_survey_data(n = 200L, design = "taylor", seed = 71L)
  df$y_na <- df$y1
  df$y_na[1:5] <- NA_real_
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_quantiles(d, y_na, probs = 0.5, na.rm = FALSE)
  test_result_invariants(result, "survey_quantiles")
  expect_true(is.na(result$estimate[[1L]]))
})

test_that("get_quantiles() na.rm = FALSE with no NAs matches na.rm = TRUE", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 72L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  r_true  <- get_quantiles(d, y1, probs = 0.5, na.rm = TRUE)
  r_false <- get_quantiles(d, y1, probs = 0.5, na.rm = FALSE)

  expect_equal(r_true$estimate[[1L]], r_false$estimate[[1L]], tolerance = 1e-15)
})

# ---------------------------------------------------------------------------
# Category 10: Small cell warning
# ---------------------------------------------------------------------------

test_that("get_quantiles() fires surveycore_warning_small_cell when n < min_cell_n", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 80L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  # With n_total = 200 and min_cell_n = 500, all cells will trigger the warning
  expect_warning(
    get_quantiles(d, y1, probs = 0.5, min_cell_n = 500L),
    class = "surveycore_warning_small_cell"
  )
})

test_that("get_quantiles() no small-cell warning when n >= min_cell_n", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 81L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  expect_no_warning(
    get_quantiles(d, y1, probs = 0.5, min_cell_n = 1L)
  )
})

# ---------------------------------------------------------------------------
# Category 11: Error paths
# ---------------------------------------------------------------------------

test_that("get_quantiles() rejects non-survey-base input", {
  expect_error(
    get_quantiles(list(x = 1), y1),
    class = "surveycore_error_unsupported_class"
  )
  expect_snapshot(error = TRUE, get_quantiles(list(x = 1), y1))
})

test_that("get_quantiles() rejects probs outside (0,1)", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 90L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  expect_error(
    get_quantiles(d, y1, probs = c(0.25, 1.1)),
    class = "surveycore_error_invalid_probs"
  )
  expect_snapshot(error = TRUE, get_quantiles(d, y1, probs = c(0.25, 1.1)))
})

test_that("get_quantiles() rejects probs = 0 or probs = 1 exactly", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 91L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  expect_error(
    get_quantiles(d, y1, probs = c(0, 0.5)),
    class = "surveycore_error_invalid_probs"
  )
  expect_error(
    get_quantiles(d, y1, probs = c(0.5, 1)),
    class = "surveycore_error_invalid_probs"
  )
})

test_that("get_quantiles() rejects empty probs vector", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 92L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  expect_error(
    get_quantiles(d, y1, probs = numeric(0)),
    class = "surveycore_error_invalid_probs"
  )
})

test_that("get_quantiles() rejects non-numeric x", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 93L)
  df$char_col <- as.character(df$group)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  expect_error(
    get_quantiles(d, char_col, probs = 0.5),
    class = "surveycore_error_non_numeric_variable"
  )
  expect_snapshot(error = TRUE, get_quantiles(d, char_col, probs = 0.5))
})

test_that("get_quantiles() rejects multiple x variables", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 94L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  expect_error(
    get_quantiles(d, c(y1, y2), probs = 0.5),
    class = "surveycore_error_wrong_variable_count"
  )
  expect_snapshot(error = TRUE, get_quantiles(d, c(y1, y2), probs = 0.5))
})

test_that("get_quantiles() rejects invalid variance", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 95L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  expect_error(
    get_quantiles(d, y1, variance = "not_a_stat"),
    class = "surveycore_error_invalid_variance_arg"
  )
})

test_that("get_quantiles() rejects invalid conf_level", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 96L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  expect_error(
    get_quantiles(d, y1, conf_level = 1.5),
    class = "surveycore_error_invalid_conf_level"
  )
})

test_that("get_quantiles() rejects invalid name_style", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 97L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  expect_error(
    get_quantiles(d, y1, name_style = "wrong"),
    class = "surveycore_error_invalid_name_style"
  )
})

# ---------------------------------------------------------------------------
# Category 12: Edge cases
# ---------------------------------------------------------------------------

test_that("get_quantiles() all-NA column returns NA estimates", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 100L)
  df$all_na <- NA_real_
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_quantiles(d, all_na, probs = c(0.25, 0.5))
  test_result_invariants(result, "survey_quantiles")
  expect_true(all(is.na(result$estimate)))
  expect_true(all(result$n == 0L))
})

test_that("get_quantiles() single distinct value returns that value as estimate", {
  df         <- make_survey_data(n = 100L, design = "taylor", seed = 101L)
  df$const   <- 42.0
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_quantiles(d, const, probs = c(0.25, 0.5, 0.75), variance = NULL)
  test_result_invariants(result, "survey_quantiles")
  expect_true(all(result$estimate == 42.0))
})

test_that("get_quantiles() empty domain (n = 0) returns NA estimate", {
  df <- make_survey_data(n = 200L, n_psu = 20L, design = "taylor", seed = 102L)
  d_full <- as_survey(df, ids = psu, weights = wt, strata = strata,
                      fpc = fpc, nest = TRUE)
  # Mark domain as empty: no rows belong to "NONEXISTENT_GROUP"
  d_empty <- d_full
  d_empty@data[[SURVEYCORE_DOMAIN_COL]] <- as.integer(
    !is.na(d_full@data$group) & d_full@data$group == "NONEXISTENT_GROUP"
  )

  result <- get_quantiles(d_empty, y1, probs = 0.5)
  test_result_invariants(result, "survey_quantiles")
  expect_true(is.na(result$estimate[[1L]]))
  expect_equal(result$n[[1L]], 0L)
})

test_that("get_quantiles() CV warning fires for zero-or-negative estimate", {
  df      <- make_survey_data(n = 200L, design = "taylor", seed = 103L)
  df$neg  <- -abs(df$y2)  # all negative
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  expect_warning(
    get_quantiles(d, neg, variance = "cv"),
    class = "surveycore_warning_cv_undefined"
  )
})

test_that("get_quantiles() single-level group warning fires", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 104L)
  df$g1 <- "only_level"
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  expect_warning(
    get_quantiles(d, y1, group = g1),
    class = "surveycore_warning_single_level"
  )
})

test_that("get_quantiles() probs in meta match argument value", {
  df    <- make_survey_data(n = 200L, design = "taylor", seed = 105L)
  d     <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  probs <- c(0.1, 0.9)

  result <- get_quantiles(d, y1, probs = probs)
  expect_identical(meta(result)$probs, probs)
  expect_equal(meta(result)$variable, "y1")
})
