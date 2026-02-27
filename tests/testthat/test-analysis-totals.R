# test-analysis-totals.R
# Tests for get_totals() — the Phase 1 weighted-total estimation function.
#
# Numerical tolerance: 1e-10 for point estimates, 1e-8 for SE.
# Oracle tests skip if the 'survey' package is not installed.

# ---------------------------------------------------------------------------
# Category 1: Happy path — two modes
# ---------------------------------------------------------------------------

test_that("get_totals() with variable returns survey_totals tibble with n column", {
  df <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L,
                         design = "taylor", seed = 1L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_totals(d, y1)
  test_result_invariants(result, "survey_totals")
  expect_true("total"   %in% names(result))
  expect_true("ci_low"  %in% names(result))
  expect_true("ci_high" %in% names(result))
  expect_true("n"       %in% names(result))
  expect_false("se"     %in% names(result))   # not in default variance = "ci"
  expect_true(is.finite(result$total[[1L]]))
  expect_lt(result$ci_low[[1L]], result$ci_high[[1L]])
  expect_identical(names(meta(result)$x), "y1")
})

test_that("get_totals() with no variable estimates population size (no n column)", {
  df <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L,
                         design = "taylor", seed = 2L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_totals(d)
  test_result_invariants(result, "survey_totals")
  expect_true("total"  %in% names(result))
  expect_false("n"     %in% names(result))   # omitted in no-variable mode
  expect_true(is.finite(result$total[[1L]]))
  expect_null(meta(result)$x)

  # Population size ≈ sum of weights
  expected_N <- sum(df$wt)
  expect_equal(result$total[[1L]], expected_N, tolerance = 1e-10)
})

test_that("get_totals() no-variable n_weighted = TRUE includes n_weighted column", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 3L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_totals(d, n_weighted = TRUE)
  expect_true("n_weighted" %in% names(result))
  # For no-variable mode n_weighted equals total
  expect_equal(result$n_weighted[[1L]], result$total[[1L]], tolerance = 1e-14)
})

# ---------------------------------------------------------------------------
# Category 2: All 5 design types — variable mode
# ---------------------------------------------------------------------------

test_that("get_totals() works for survey_replicate design", {
  df <- make_survey_data(n = 100L, n_psu = 10L, design = "replicate",
                         type = "brr", seed = 4L)
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  d <- as_survey_rep(df, weights = wt, repweights = all_of(repwt_cols), type = "BRR")

  result <- get_totals(d, y1)
  test_result_invariants(result, "survey_totals")
  expect_true(is.finite(result$total[[1L]]))
})

test_that("get_totals() works for survey_srs design", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 5L)
  d  <- as_survey_srs(df, weights = wt)

  result <- get_totals(d, y1)
  test_result_invariants(result, "survey_totals")
  expect_true(is.finite(result$total[[1L]]))
})

test_that("get_totals() works for survey_twophase design", {
  df  <- make_survey_data(design = "twophase", n = 200L, n_psu = 20L,
                          n_strata = 2L, seed = 6L)
  ph1 <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  d   <- as_survey_twophase(ph1, subset = subset, method = "approx")

  result <- get_totals(d, y1)
  test_result_invariants(result, "survey_totals")
  expect_true(is.finite(result$total[[1L]]))
})

test_that("get_totals() works for survey_calibrated design", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 7L)
  d  <- as_survey_calibrated(df, weights = wt)

  result <- get_totals(d, y1)
  test_result_invariants(result, "survey_totals")
  expect_true(is.finite(result$total[[1L]]))
})

# ---------------------------------------------------------------------------
# Category 3: meta() content
# ---------------------------------------------------------------------------

test_that("get_totals() meta() stores variable and design type", {
  df <- make_survey_data(n = 50L, design = "taylor", seed = 8L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_totals(d, y1)
  m      <- meta(result)

  expect_identical(names(m$x), "y1")
  expect_true(is.character(m$design_type))
  expect_equal(m$conf_level, 0.95)
})

test_that("get_totals() meta()$x is NULL in no-variable mode", {
  df <- make_survey_data(n = 50L, design = "taylor", seed = 9L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_totals(d)
  expect_null(meta(result)$x)
})

# ---------------------------------------------------------------------------
# Category 4: variance= argument
# ---------------------------------------------------------------------------

test_that("get_totals() variance = 'se' produces se column", {
  df <- make_survey_data(n = 50L, design = "taylor", seed = 10L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_totals(d, y1, variance = "se")
  expect_true("se" %in% names(result))
  expect_false("ci_low" %in% names(result))
  expect_gte(result$se[[1L]], 0)
})

test_that("get_totals() variance = NULL produces only total (+ n in variable mode)", {
  df <- make_survey_data(n = 50L, design = "taylor", seed = 11L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result_var    <- get_totals(d, y1, variance = NULL)
  result_novar  <- get_totals(d, variance = NULL)

  expect_identical(names(result_var),   c("total", "n"))
  expect_identical(names(result_novar), c("total"))
})

test_that("get_totals() variance = 'deff' produces deff column", {
  df <- make_survey_data(n = 100L, n_psu = 10L, design = "taylor", seed = 12L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_totals(d, y1, variance = "deff")
  expect_true("deff" %in% names(result))
  expect_gte(result$deff[[1L]], 0)
})

# ---------------------------------------------------------------------------
# Category 5: group= argument
# ---------------------------------------------------------------------------

test_that("get_totals() group= produces one row per group level", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 2L,
                         design = "taylor", seed = 13L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  n_strata <- length(unique(df$strata))
  result   <- get_totals(d, y1, group = strata)

  test_result_invariants(result, "survey_totals")
  expect_equal(nrow(result), n_strata)
  expect_true("strata" %in% names(result))
  expect_true(all(is.finite(result$total)))
})

test_that("get_totals() group= no-variable mode produces grouped pop sizes", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 2L,
                         design = "taylor", seed = 14L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_totals(d, group = strata)
  test_result_invariants(result, "survey_totals")
  expect_false("n" %in% names(result))  # no n in no-variable mode
  expect_true(all(is.finite(result$total)))

  # Sum of grouped population sizes ≈ total population size
  result_all  <- get_totals(d)
  expect_equal(sum(result$total), result_all$total[[1L]], tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# Category 6: na.rm
# ---------------------------------------------------------------------------

test_that("get_totals() na.rm = TRUE excludes NAs from computation", {
  df <- make_survey_data(n = 100L, n_psu = 10L, design = "taylor", seed = 15L)
  df$y1[c(1, 5, 10)] <- NA_real_
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result_rm  <- get_totals(d, y1, variance = NULL, na.rm = TRUE)
  result_nrm <- get_totals(d, y1, variance = NULL, na.rm = FALSE)

  expect_true(is.finite(result_rm$total[[1L]]))
  expect_equal(result_rm$n[[1L]], 97L)
  expect_true(is.na(result_nrm$total[[1L]]))
})

# ---------------------------------------------------------------------------
# Category 7: n_weighted
# ---------------------------------------------------------------------------

test_that("get_totals() n_weighted = TRUE adds n_weighted column", {
  df <- make_survey_data(n = 50L, design = "taylor", seed = 16L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_totals(d, y1, variance = NULL, n_weighted = TRUE)
  expect_true("n_weighted" %in% names(result))
  expect_gte(result$n_weighted[[1L]], 0)
})

# ---------------------------------------------------------------------------
# Category 8: name_style = "broom"
# ---------------------------------------------------------------------------

test_that("get_totals() name_style = 'broom' renames columns", {
  df     <- make_survey_data(n = 50L, design = "taylor", seed = 17L)
  d      <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  result <- get_totals(d, y1, variance = c("se", "ci"), name_style = "broom")

  expect_true("estimate"  %in% names(result))
  expect_true("std.error" %in% names(result))
  expect_true("conf.low"  %in% names(result))
  expect_true("conf.high" %in% names(result))
  expect_false("total"    %in% names(result))
})

# ---------------------------------------------------------------------------
# Category 9: min_cell_n warning
# ---------------------------------------------------------------------------

test_that("get_totals() emits small-cell warning when n < min_cell_n", {
  df <- data.frame(
    y     = c(rep(1.0, 5),  rep(2.0, 95)),
    g     = c(rep("tiny", 5), rep("big", 95)),
    w     = rep(1, 100),
    psu   = rep(1:20, 5)
  )
  d <- as_survey(df, ids = psu, weights = w)

  expect_warning(
    get_totals(d, y, group = g, min_cell_n = 10L),
    class = "surveycore_warning_small_cell"
  )
})

# ---------------------------------------------------------------------------
# Category 10: Error paths
# ---------------------------------------------------------------------------

test_that("get_totals() errors for non-survey-design object", {
  expect_error(
    get_totals(data.frame(x = 1:5, y = rnorm(5)), y),
    class = "surveycore_error_unsupported_class"
  )
})

test_that("get_totals() errors for non-numeric variable", {
  df <- data.frame(y = letters[1:10], w = rep(1, 10))
  d  <- as_survey_srs(df, weights = w)
  expect_error(
    get_totals(d, y),
    class = "surveycore_error_non_numeric_variable"
  )
  expect_snapshot(error = TRUE, get_totals(d, y))
})

test_that("get_totals() errors when x resolves to multiple variables", {
  df <- data.frame(y1 = 1:10, y2 = 1:10, w = rep(1, 10))
  d  <- as_survey_srs(df, weights = w)
  expect_error(
    get_totals(d, starts_with("y")),
    class = "surveycore_error_wrong_variable_count"
  )
})

test_that("get_totals() errors for invalid variance value", {
  df <- data.frame(y = 1:10, w = rep(1, 10))
  d  <- as_survey_srs(df, weights = w)
  expect_error(
    get_totals(d, y, variance = "bad_val"),
    class = "surveycore_error_invalid_variance_arg"
  )
  expect_snapshot(error = TRUE, get_totals(d, y, variance = "bad_val"))
})

# ---------------------------------------------------------------------------
# Category 11: Oracle — NHANES Taylor design
# ---------------------------------------------------------------------------

test_that("get_totals() Taylor point + SE + CI match survey::svytotal() — NHANES [oracle]", {
  skip_if_not_installed("survey")

  d <- nhanes_2017[nhanes_2017$ridstatr == 2, ]
  sc <- as_survey(d, ids = sdmvpsu, strata = sdmvstra, weights = wtmec2yr,
                  nest = TRUE)
  sv <- survey::svydesign(ids = ~sdmvpsu, strata = ~sdmvstra,
                          weights = ~wtmec2yr, data = d, nest = TRUE)

  sc_est <- get_totals(sc, bpxsy1, variance = c("se", "ci"))
  sv_est <- survey::svytotal(~bpxsy1, sv, na.rm = TRUE)

  expect_equal(sc_est$total[[1L]],   coef(sv_est)[["bpxsy1"]], tolerance = 1e-10)
  expect_equal(sc_est$se[[1L]],      as.numeric(survey::SE(sv_est)), tolerance = 1e-8)
  expect_equal(sc_est$ci_low[[1L]],  confint(sv_est)[1], tolerance = 1e-6)
  expect_equal(sc_est$ci_high[[1L]], confint(sv_est)[2], tolerance = 1e-6)
})

# ---------------------------------------------------------------------------
# Category 12: Numerical correctness — trivial cases
# ---------------------------------------------------------------------------

test_that("get_totals() total = sum(w * y) for trivial SRS design", {
  df <- data.frame(y = c(1.0, 2.0, 3.0), w = c(2.0, 3.0, 4.0))
  d  <- as_survey_srs(df, weights = w)
  result <- get_totals(d, y, variance = NULL)
  expect_equal(result$total[[1L]], 2*1 + 3*2 + 4*3, tolerance = 1e-14)
})

test_that("get_totals() no-variable total = sum(weights)", {
  df <- data.frame(y = 1:5, w = c(1, 2, 3, 4, 5))
  d  <- as_survey_srs(df, weights = w)
  result <- get_totals(d, variance = NULL)
  expect_equal(result$total[[1L]], 15.0, tolerance = 1e-14)
})

# ---------------------------------------------------------------------------
# Category 13: All designs via make_all_designs()
# ---------------------------------------------------------------------------

test_that("get_totals() returns a finite total for all 5 design types", {
  designs <- make_all_designs(seed = 99L)
  for (nm in names(designs)) {
    d      <- designs[[nm]]
    result <- get_totals(d, y1)
    test_result_invariants(result, "survey_totals")
    expect_true(
      is.finite(result$total[[1L]]),
      label = paste0("get_totals() finite total for design type: ", nm)
    )
  }
})

test_that("get_totals() no-variable mode returns finite total for all 5 design types", {
  designs <- make_all_designs(seed = 100L)
  for (nm in names(designs)) {
    d      <- designs[[nm]]
    result <- get_totals(d)
    test_result_invariants(result, "survey_totals")
    expect_true(
      is.finite(result$total[[1L]]),
      label = paste0("get_totals() no-var finite total for design type: ", nm)
    )
  }
})

# ── decimals argument ──────────────────────────────────────────────────────────

test_that("get_totals() decimals=2 rounds all double columns", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 401L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_totals(d, y1, variance = "ci", decimals = 2L)

  dbl_cols <- names(r)[vapply(r, is.double, logical(1L))]
  for (col in dbl_cols) {
    expect_equal(r[[col]], round(r[[col]], 2L),
                 label = paste0(col, " rounded to 2 decimals"))
  }
})

test_that("get_totals() decimals=NULL applies no rounding", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 402L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r_none    <- get_totals(d, y1, variance = NULL, decimals = NULL)
  r_rounded <- get_totals(d, y1, variance = NULL, decimals = 0L)

  expect_false(identical(r_none$total, r_rounded$total))
})

test_that("get_totals() rejects invalid decimals", {
  df <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 403L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)

  expect_error(
    get_totals(d, y1, decimals = 1.5),
    class = "surveycore_error_invalid_decimals"
  )
})
