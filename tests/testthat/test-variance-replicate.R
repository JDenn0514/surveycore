# test-variance-replicate.R
# Tests for the replicate-weight variance engine: .svy_rep_var(),
# .replicate_estimate(), .replicate_mean(), .replicate_total().
#
# Numerical tolerance: 1e-10 for point estimates, 1e-8 for SE/variance.
# Oracle tests skip if the 'survey' package is not installed.

# ---------------------------------------------------------------------------
# Block 10: Replicate weight variance — numerical comparison
# ---------------------------------------------------------------------------

test_that("get_means() replicate SE matches survey::svymean() — BRR design", {
  skip_if_not_installed("survey")

  d <- make_survey_data(
    n = 200,
    n_psu = 20,
    n_strata = 4,
    design = "replicate",
    type = "brr",
    seed = 7
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)

  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "BRR"
  )
  test_invariants(sc)

  expect_no_warning(
    sv <- survey::svrepdesign(
      weights = d$wt,
      repweights = d[, repwt_cols],
      type = "BRR",
      mse = TRUE,
      data = d
    )
  )

  # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
  expect_equal(sv$scale, 1 / length(repwt_cols), tolerance = 1e-8)

  sc_mean <- get_means(sc, y1, variance = c("se", "ci"))
  sv_mean <- survey::svymean(~y1, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_mean$se, as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
  expect_equal(sc_mean$ci_low, confint(sv_mean)[1], tolerance = 1e-6)
  expect_equal(sc_mean$ci_high, confint(sv_mean)[2], tolerance = 1e-6)
})

test_that("get_totals() replicate SE matches survey::svytotal() — BRR design", {
  skip_if_not_installed("survey")

  d <- make_survey_data(
    n = 200,
    n_psu = 20,
    n_strata = 4,
    design = "replicate",
    type = "brr",
    seed = 7
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)

  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "BRR"
  )
  expect_no_warning(
    sv <- survey::svrepdesign(
      weights = d$wt,
      repweights = d[, repwt_cols],
      type = "BRR",
      mse = TRUE,
      data = d
    )
  )

  # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
  expect_equal(sv$scale, 1 / length(repwt_cols), tolerance = 1e-8)

  sc_total <- get_totals(sc, y1, variance = c("se", "ci"))
  sv_total <- survey::svytotal(~y1, sv, na.rm = TRUE)

  expect_equal(sc_total$total, coef(sv_total)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_total$se, as.numeric(survey::SE(sv_total)), tolerance = 1e-8)
  expect_equal(sc_total$ci_low, confint(sv_total)[1], tolerance = 1e-6)
  expect_equal(sc_total$ci_high, confint(sv_total)[2], tolerance = 1e-6)
})

test_that("get_means() replicate SE matches survey::svymean() — JK1 design", {
  skip_if_not_installed("survey")

  d <- make_survey_data(
    n = 200,
    n_psu = 20,
    n_strata = 4,
    design = "replicate",
    type = "jk1",
    seed = 15
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)
  n_rep <- length(repwt_cols)

  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "JK1",
    mse = TRUE
  )

  # survey has no JK1 default: with combined weights it guesses (R-1)/R and
  # says so. Match the fragment, not the full text, which carries "(n-1)/n"
  # and reads as a regular-expression group; and not "JK1" alone, which also
  # matches the "rho not relevant to JK1 design" branch on four other types.
  jk1_warnings <- testthat::capture_warnings(
    sv <- survey::svrepdesign(
      weights = d$wt,
      repweights = d[, repwt_cols],
      type = "JK1",
      mse = TRUE,
      data = d
    )
  )
  expect_length(jk1_warnings, 1L)
  expect_match(
    jk1_warnings,
    "guessing n=number of replicates",
    fixed = TRUE
  )

  # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
  expect_equal(sv$scale, (n_rep - 1) / n_rep, tolerance = 1e-8)

  sc_mean <- get_means(sc, y1, variance = c("se", "ci"))
  sv_mean <- survey::svymean(~y1, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_mean$se, as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
  expect_equal(sc_mean$ci_low, confint(sv_mean)[1], tolerance = 1e-6)
  expect_equal(sc_mean$ci_high, confint(sv_mean)[2], tolerance = 1e-6)
})

test_that("get_means() replicate SE matches survey::svymean() — JK2 design", {
  skip_if_not_installed("survey")

  # survey::svrepdesign() fixes scale = 1 and rscales = rep(1, R) for JK2 and
  # warns that it ignores both arguments. The constructor left scale at the
  # delete-one factor (R-1)/R, so every JK2 design built without an explicit
  # scale reported a standard error low by sqrt((R-1)/R) (issue #242).
  d <- make_survey_data(
    n = 200,
    n_psu = 20,
    n_strata = 4,
    design = "replicate",
    type = "jk1",
    seed = 15
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)

  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "JK2",
    mse = TRUE
  )
  expect_equal(sc@variables$scale, 1)

  # survey warns for JK2 unconditionally, even when the caller supplies
  # neither scale nor rscales, so the block asserts the warning instead of
  # hiding it.
  jk2_warnings <- testthat::capture_warnings(
    sv <- survey::svrepdesign(
      weights = d$wt,
      repweights = d[, repwt_cols],
      type = "JK2",
      mse = TRUE,
      data = d
    )
  )
  expect_length(jk2_warnings, 1L)
  expect_match(
    jk2_warnings,
    "with type JK2 scale= and rscales= are not needed",
    fixed = TRUE
  )

  # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
  expect_equal(sv$scale, 1, tolerance = 1e-8)

  sc_mean <- get_means(sc, y1, variance = c("se", "ci"))
  sv_mean <- survey::svymean(~y1, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_mean$se, as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
  expect_equal(sc_mean$ci_low, confint(sv_mean)[1], tolerance = 1e-6)
  expect_equal(sc_mean$ci_high, confint(sv_mean)[2], tolerance = 1e-6)
})

test_that("get_means() agrees between the two JK2 constructors", {
  d <- make_survey_data(
    n = 200,
    n_psu = 20,
    n_strata = 4,
    design = "replicate",
    type = "jk1",
    seed = 15
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)

  sc_rep <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "JK2"
  )
  sc_np <- as_survey_nonprob(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "JK2",
    rscales = rep(1, length(repwt_cols))
  )

  m_rep <- get_means(sc_rep, y1, variance = "se")
  m_np <- get_means(sc_np, y1, variance = "se")

  expect_equal(m_rep$mean, m_np$mean, tolerance = 1e-10)
  expect_equal(m_rep$se, m_np$se, tolerance = 1e-8)
})

test_that("get_means() replicate: mse=FALSE matches survey with mse=FALSE", {
  skip_if_not_installed("survey")

  d <- make_survey_data(
    n = 100,
    n_psu = 10,
    n_strata = 2,
    design = "replicate",
    type = "brr",
    seed = 22
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)

  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "BRR",
    mse = FALSE
  )
  expect_no_warning(
    sv <- survey::svrepdesign(
      weights = d$wt,
      repweights = d[, repwt_cols],
      type = "BRR",
      mse = FALSE,
      data = d
    )
  )

  # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
  expect_equal(sv$scale, 1 / length(repwt_cols), tolerance = 1e-8)

  sc_mean <- get_means(sc, y1, variance = c("se", "ci"))
  sv_mean <- survey::svymean(~y1, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_mean$se, as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
  expect_equal(sc_mean$ci_low, confint(sv_mean)[1], tolerance = 1e-6)
  expect_equal(sc_mean$ci_high, confint(sv_mean)[2], tolerance = 1e-6)
})

test_that("get_means() and get_totals() work for survey_replicate (return structure)", {
  d <- make_survey_data(
    n = 100,
    n_psu = 10,
    design = "replicate",
    type = "brr",
    seed = 3
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)
  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "BRR"
  )

  m <- get_means(sc, y1, variance = "se")
  test_result_invariants(m, "survey_means")
  expect_identical(names(meta(m)$x), "y1")
  expect_true(is.finite(m$mean[[1L]]))
  expect_gte(m$se[[1L]], 0)

  t <- get_totals(sc, y1, variance = "se")
  test_result_invariants(t, "survey_totals")
  expect_true(is.finite(t$total[[1L]]))
  expect_gte(t$se[[1L]], 0)
})

test_that("get_means() BRR scale formula 1/n_rep is correct for n_rep != 4", {
  # Verifies that scale = 1/n_rep (not 1/4) is the correct BRR formula.
  # With n_psu = 20, n_rep = 10 (half-samples from 20 PSUs).
  # If 1/n_rep is correct, surveycore and survey::svrepdesign agree at 1e-8.
  skip_if_not_installed("survey")

  d <- make_survey_data(
    n = 200,
    n_psu = 20,
    n_strata = 4,
    design = "replicate",
    type = "brr",
    seed = 99
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)
  n_rep <- length(repwt_cols) # should be 10 (n_psu / 2)

  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "BRR"
  )
  # survey hardcodes scale = 1/R for BRR internally; the scale= argument is
  # ignored. Both packages independently compute (1/n_rep) * sum((theta_r - theta)^2).
  expect_no_warning(
    sv <- survey::svrepdesign(
      weights = d$wt,
      repweights = d[, repwt_cols],
      type = "BRR",
      mse = TRUE,
      data = d
    )
  )

  # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
  expect_equal(sv$scale, 1 / n_rep, tolerance = 1e-8)

  sc_mean <- get_means(sc, y1, variance = c("se", "ci"))
  sv_mean <- survey::svymean(~y1, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_mean$se, as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
  expect_equal(sc_mean$ci_low, confint(sv_mean)[1], tolerance = 1e-6)
  expect_equal(sc_mean$ci_high, confint(sv_mean)[2], tolerance = 1e-6)
})


# ---------------------------------------------------------------------------
# Block 11: successive-difference and ACS scale factor oracle tests
# ---------------------------------------------------------------------------

test_that("as_survey_replicate() stores scale = 4/n_rep for successive-difference", {
  d <- make_survey_data(
    n = 100,
    n_psu = 10,
    design = "replicate",
    type = "brr",
    seed = 200
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)
  n_rep <- length(repwt_cols)

  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "successive-difference"
  )

  expect_equal(sc@variables$scale, 4 / n_rep)
})

test_that("as_survey_replicate() stores scale = 4/n_rep for ACS", {
  d <- make_survey_data(
    n = 100,
    n_psu = 10,
    design = "replicate",
    type = "brr",
    seed = 201
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)
  n_rep <- length(repwt_cols)

  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "ACS"
  )

  expect_equal(sc@variables$scale, 4 / n_rep)
})

test_that("get_means() successive-difference SE matches survey::svymean()", {
  skip_if_not_installed("survey")

  d <- make_survey_data(
    n = 200,
    n_psu = 20,
    n_strata = 4,
    design = "replicate",
    type = "brr",
    seed = 300
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)

  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "successive-difference",
    mse = TRUE
  )
  expect_no_warning(
    sv <- survey::svrepdesign(
      weights = d$wt,
      repweights = d[, repwt_cols],
      type = "successive-difference",
      mse = TRUE,
      data = d
    )
  )

  # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
  expect_equal(sv$scale, 4 / length(repwt_cols), tolerance = 1e-8)

  sc_mean <- get_means(sc, y1, variance = c("se", "ci"))
  sv_mean <- survey::svymean(~y1, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_mean$se, as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
  expect_equal(sc_mean$ci_low, confint(sv_mean)[1], tolerance = 1e-6)
  expect_equal(sc_mean$ci_high, confint(sv_mean)[2], tolerance = 1e-6)
})

test_that("get_totals() successive-difference SE matches survey::svytotal()", {
  skip_if_not_installed("survey")

  d <- make_survey_data(
    n = 200,
    n_psu = 20,
    n_strata = 4,
    design = "replicate",
    type = "brr",
    seed = 301
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)

  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "successive-difference",
    mse = TRUE
  )
  expect_no_warning(
    sv <- survey::svrepdesign(
      weights = d$wt,
      repweights = d[, repwt_cols],
      type = "successive-difference",
      mse = TRUE,
      data = d
    )
  )

  # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
  expect_equal(sv$scale, 4 / length(repwt_cols), tolerance = 1e-8)

  sc_total <- get_totals(sc, y1, variance = c("se", "ci"))
  sv_total <- survey::svytotal(~y1, sv, na.rm = TRUE)

  expect_equal(sc_total$total, coef(sv_total)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_total$se, as.numeric(survey::SE(sv_total)), tolerance = 1e-8)
  expect_equal(sc_total$ci_low, confint(sv_total)[1], tolerance = 1e-6)
  expect_equal(sc_total$ci_high, confint(sv_total)[2], tolerance = 1e-6)
})

test_that("get_means() ACS SE matches survey::svymean()", {
  skip_if_not_installed("survey")

  d <- make_survey_data(
    n = 200,
    n_psu = 20,
    n_strata = 4,
    design = "replicate",
    type = "brr",
    seed = 302
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)

  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "ACS",
    mse = TRUE
  )
  expect_no_warning(
    sv <- survey::svrepdesign(
      weights = d$wt,
      repweights = d[, repwt_cols],
      type = "ACS",
      mse = TRUE,
      data = d
    )
  )

  # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
  expect_equal(sv$scale, 4 / length(repwt_cols), tolerance = 1e-8)

  sc_mean <- get_means(sc, y1, variance = c("se", "ci"))
  sv_mean <- survey::svymean(~y1, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_mean$se, as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
  expect_equal(sc_mean$ci_low, confint(sv_mean)[1], tolerance = 1e-6)
  expect_equal(sc_mean$ci_high, confint(sv_mean)[2], tolerance = 1e-6)
})

test_that("get_totals() ACS SE matches survey::svytotal()", {
  skip_if_not_installed("survey")

  d <- make_survey_data(
    n = 200,
    n_psu = 20,
    n_strata = 4,
    design = "replicate",
    type = "brr",
    seed = 303
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)

  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "ACS",
    mse = TRUE
  )
  expect_no_warning(
    sv <- survey::svrepdesign(
      weights = d$wt,
      repweights = d[, repwt_cols],
      type = "ACS",
      mse = TRUE,
      data = d
    )
  )

  # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
  expect_equal(sv$scale, 4 / length(repwt_cols), tolerance = 1e-8)

  sc_total <- get_totals(sc, y1, variance = c("se", "ci"))
  sv_total <- survey::svytotal(~y1, sv, na.rm = TRUE)

  expect_equal(sc_total$total, coef(sv_total)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_total$se, as.numeric(survey::SE(sv_total)), tolerance = 1e-8)
  expect_equal(sc_total$ci_low, confint(sv_total)[1], tolerance = 1e-6)
  expect_equal(sc_total$ci_high, confint(sv_total)[2], tolerance = 1e-6)
})

# ---------------------------------------------------------------------------
# Block 12: na.rm = FALSE paths
# ---------------------------------------------------------------------------

test_that("get_means() na.rm = FALSE on replicate design covers .replicate_mean FALSE path", {
  df <- make_survey_data(
    n = 50L,
    n_psu = 10L,
    design = "replicate",
    type = "brr",
    seed = 200L
  )
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  sc <- as_survey_replicate(
    df,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "BRR"
  )
  # na.rm = FALSE on NA-free data exercises the else branch and returns a valid estimate
  result <- get_means(sc, y1, variance = "se", na.rm = FALSE)
  expect_true(is.finite(result$mean[[1L]]))
  expect_true(is.finite(result$se[[1L]]))
})

test_that("get_totals() na.rm = FALSE on replicate design covers .replicate_total FALSE path", {
  df <- make_survey_data(
    n = 50L,
    n_psu = 10L,
    design = "replicate",
    type = "brr",
    seed = 201L
  )
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  sc <- as_survey_replicate(
    df,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "BRR"
  )
  # na.rm = FALSE on NA-free data exercises the else branch and returns a valid estimate
  result <- get_totals(sc, y1, variance = "se", na.rm = FALSE)
  expect_true(is.finite(result$total[[1L]]))
  expect_true(is.finite(result$se[[1L]]))
})


# ---------------------------------------------------------------------------
# Block 16: .svy_rep_var() with NA replicates (lines 317–323)
# ---------------------------------------------------------------------------

test_that(".svy_rep_var() skips NA replicates and returns finite variance [direct]", {
  thetas <- c(1.2, 1.3, NA_real_, 1.1, 1.4)
  rscales <- rep(1L, 5L)
  v <- surveycore:::.svy_rep_var(
    thetas,
    scale = 0.2,
    rscales = rscales,
    mse = TRUE,
    coef = 1.25
  )
  expect_true(is.finite(v))
  expect_gte(v, 0)
})

test_that(".svy_rep_var() errors when all replicates are NA [direct]", {
  thetas <- rep(NA_real_, 5L)
  rscales <- rep(1L, 5L)
  expect_error(
    surveycore:::.svy_rep_var(
      thetas,
      scale = 0.2,
      rscales = rscales,
      mse = TRUE,
      coef = 1.25
    ),
    class = "surveycore_error_all_replicates_na"
  )
})

# ---------------------------------------------------------------------------
# Block 22: Direct .replicate_mean() and .replicate_total() calls
# ---------------------------------------------------------------------------

test_that(".replicate_mean() returns finite mean and se for BRR design", {
  d <- make_survey_data(
    n = 100,
    n_psu = 10,
    n_strata = 2,
    design = "replicate",
    type = "brr",
    seed = 50
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)
  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = tidyselect::all_of(repwt_cols),
    type = "BRR"
  )

  result <- surveycore:::.replicate_mean(sc, "y1")
  expect_true(is.finite(result$mean))
  expect_true(is.finite(result$se))
  expect_gte(result$se, 0)
  expect_true(is.finite(result$var))
})

test_that(".replicate_mean() na.rm = FALSE errors when all replicates produce NA", {
  d <- make_survey_data(
    n = 60,
    n_psu = 10,
    n_strata = 2,
    design = "replicate",
    type = "brr",
    seed = 51
  )
  d$y1[[1L]] <- NA_real_
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)
  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = tidyselect::all_of(repwt_cols),
    type = "BRR"
  )

  expect_error(
    surveycore:::.replicate_mean(sc, "y1", na.rm = FALSE),
    class = "surveycore_error_all_replicates_na"
  )
})

test_that(".replicate_total() returns finite total and se for BRR design", {
  d <- make_survey_data(
    n = 100,
    n_psu = 10,
    n_strata = 2,
    design = "replicate",
    type = "brr",
    seed = 52
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)
  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = tidyselect::all_of(repwt_cols),
    type = "BRR"
  )

  result <- surveycore:::.replicate_total(sc, "y1")
  expect_true(is.finite(result$total))
  expect_true(is.finite(result$se))
  expect_gte(result$se, 0)
})

test_that(".replicate_total() na.rm = FALSE errors when all replicates produce NA", {
  d <- make_survey_data(
    n = 60,
    n_psu = 10,
    n_strata = 2,
    design = "replicate",
    type = "brr",
    seed = 53
  )
  d$y1[[2L]] <- NA_real_
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)
  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = tidyselect::all_of(repwt_cols),
    type = "BRR"
  )

  expect_error(
    surveycore:::.replicate_total(sc, "y1", na.rm = FALSE),
    class = "surveycore_error_all_replicates_na"
  )
})

# ---------------------------------------------------------------------------
# Block 23: get_corr() with replicate design — covers .vcov_pair_replicate()
# ---------------------------------------------------------------------------

test_that("get_corr() works for survey_replicate (BRR) design", {
  d <- make_survey_data(
    n = 100,
    n_psu = 10,
    n_strata = 2,
    design = "replicate",
    type = "brr",
    seed = 54
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)
  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = tidyselect::all_of(repwt_cols),
    type = "BRR"
  )

  result <- get_corr(sc, x = c(y1, y2), variance = "se")
  test_result_invariants(result, "survey_corr")
  expect_identical(as.character(result$var1[[1L]]), "y1")
  expect_identical(as.character(result$var2[[1L]]), "y2")
  expect_true(is.finite(result$r[[1L]]))
  expect_gte(result$se[[1L]], 0)
})

test_that("get_corr() replicate returns NA for domain with fewer than 2 paired obs", {
  d <- make_survey_data(
    n = 60,
    n_psu = 10,
    n_strata = 2,
    design = "replicate",
    type = "brr",
    seed = 55
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)
  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = tidyselect::all_of(repwt_cols),
    type = "BRR"
  )
  # Only 1 row in domain → n_d < 2 → NA r
  sc@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- seq_len(nrow(d)) == 1L

  result <- get_corr(sc, x = c(y1, y2), variance = "se")
  expect_true(is.na(result$r[[1L]]))
})

# ---------------------------------------------------------------------------
# Block 24: Oracle blocks for the remaining replicate types
# ---------------------------------------------------------------------------

test_that("get_means() JKn SE disagrees with survey::svymean() — issue #253", {
  skip_if_not_installed("survey")

  # surveycore stores (R-1)/R for JKn where survey stores 1, so surveycore's
  # standard error is low by sqrt((R-1)/R) and both confidence bounds inherit
  # the gap. Issue #253 corrects the surveycore default. Until it lands the
  # three expect_failure() wrappers below pin the wrong numbers, so branch
  # protection can still merge.
  #
  # When issue #253 lands, delete FOUR lines: the three expect_failure()
  # wrapper lines and the ratio assertion at the end of this block. Deleting
  # only the three leaves the ratio assertion to fail against the corrected
  # default.
  d <- make_survey_data(
    n = 200,
    n_psu = 20,
    n_strata = 4,
    design = "replicate",
    type = "jkn",
    seed = 15
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)
  n_rep <- length(repwt_cols)

  # survey refuses JKn with combined weights and no rscales ("Must provide
  # rscales for combined JKn weights"), so this is the one block in the file
  # that supplies the argument to svrepdesign(). The literal is written out
  # twice, once per side; neither copy is read off a design.
  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "JKn",
    mse = TRUE,
    rscales = rep(1, n_rep)
  )

  expect_no_warning(
    sv <- survey::svrepdesign(
      weights = d$wt,
      repweights = d[, repwt_cols],
      type = "JKn",
      mse = TRUE,
      rscales = rep(1, n_rep),
      data = d
    )
  )

  # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
  expect_equal(sv$scale, 1, tolerance = 1e-8)

  sc_mean <- get_means(sc, y1, variance = c("se", "ci"))
  sv_mean <- survey::svymean(~y1, sv, na.rm = TRUE)

  # The point estimate agrees exactly: the scale enters the variance only.
  expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)

  # One assertion per wrapper. expect_failure() passes on exactly one failing
  # assertion and zero passing ones, so a wrapper holding all three fails.
  testthat::expect_failure(
    expect_equal(sc_mean$se, as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
  )
  testthat::expect_failure(
    expect_equal(sc_mean$ci_low, confint(sv_mean)[1], tolerance = 1e-6)
  )
  testthat::expect_failure(
    expect_equal(sc_mean$ci_high, confint(sv_mean)[2], tolerance = 1e-6)
  )

  # A wrapper cannot say why it failed. This names the exact factor the two
  # sides differ by, so the block proves "wrong by this amount" and not merely
  # "different". Measured at R = 20: 0.974679434480991 against
  # sqrt(19 / 20) = 0.974679434480896. SE/variance row, 1e-8.
  expect_equal(
    sc_mean$se / as.numeric(survey::SE(sv_mean)),
    sqrt((n_rep - 1) / n_rep),
    tolerance = 1e-8
  )
})

test_that("get_means() bootstrap SE disagrees with survey::svymean() — issue #253", {
  skip_if_not_installed("survey")

  # surveycore stores 1/R for bootstrap where survey stores 1/(R-1), so
  # surveycore's standard error is low by sqrt((R-1)/R) and both confidence
  # bounds inherit the gap. Issue #253 corrects the surveycore default.
  # Until it lands the three expect_failure() wrappers below pin the wrong
  # numbers, so branch protection can still merge.
  #
  # When issue #253 lands, delete FOUR lines: the three expect_failure()
  # wrapper lines and the ratio assertion at the end of this block.
  # Deleting only the three leaves the ratio assertion to fail against the
  # corrected default.
  d <- make_survey_data(
    n = 200,
    n_psu = 20,
    n_strata = 4,
    design = "replicate",
    type = "bootstrap",
    seed = 15
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)
  n_rep <- length(repwt_cols)

  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "bootstrap",
    mse = TRUE
  )

  # survey's bootstrap.average has no surveycore equivalent, so neither side
  # passes it (plans/issue-cleanup.md D5).
  expect_no_warning(
    sv <- survey::svrepdesign(
      weights = d$wt,
      repweights = d[, repwt_cols],
      type = "bootstrap",
      mse = TRUE,
      data = d
    )
  )

  # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
  expect_equal(sv$scale, 1 / (n_rep - 1), tolerance = 1e-8)

  sc_mean <- get_means(sc, y1, variance = c("se", "ci"))
  sv_mean <- survey::svymean(~y1, sv, na.rm = TRUE)

  # The point estimate agrees exactly: the scale enters the variance only.
  expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)

  # One assertion per wrapper. expect_failure() passes on exactly one
  # failing assertion and zero passing ones, so a wrapper holding all three
  # fails.
  testthat::expect_failure(
    expect_equal(
      sc_mean$se,
      as.numeric(survey::SE(sv_mean)),
      tolerance = 1e-8
    )
  )
  testthat::expect_failure(
    expect_equal(sc_mean$ci_low, confint(sv_mean)[1], tolerance = 1e-6)
  )
  testthat::expect_failure(
    expect_equal(sc_mean$ci_high, confint(sv_mean)[2], tolerance = 1e-6)
  )

  # A wrapper cannot say why it failed. This names the exact factor the two
  # sides differ by, so the block proves "wrong by this amount" and not
  # merely "different". Measured at R = 20: 0.974679434480991 against
  # sqrt(19 / 20) = 0.974679434480896. SE/variance row, 1e-8.
  expect_equal(
    sc_mean$se / as.numeric(survey::SE(sv_mean)),
    sqrt((n_rep - 1) / n_rep),
    tolerance = 1e-8
  )
})

test_that("get_means() replicate SE matches survey::svymean() — other design", {
  skip_if_not_installed("survey")

  # The generator has no "other" mode, so the block builds type = "other" on
  # the jk1 replicate columns, the way the JK2 block builds on them.
  d <- make_survey_data(
    n = 200,
    n_psu = 20,
    n_strata = 4,
    design = "replicate",
    type = "jk1",
    seed = 15
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)

  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "other",
    mse = TRUE
  )

  # survey warns for type "other" when the caller supplies neither scale nor
  # rscales, and it raises the same warning when a scale IS supplied. So
  # supplying one silences nothing and still feeds survey a number this side
  # computed; the block supplies neither and asserts the warning instead.
  # capture_warnings() plus expect_length() counts them, because a fragment
  # match alone passes when a second, unexpected warning fires alongside —
  # including the "Data do not look like combined weights" warning that means
  # the fixture moved.
  other_warnings <- testthat::capture_warnings(
    sv <- survey::svrepdesign(
      weights = d$wt,
      repweights = d[, repwt_cols],
      type = "other",
      mse = TRUE,
      data = d
    )
  )
  expect_length(other_warnings, 1L)
  expect_match(
    other_warnings,
    "scale or rscales not specified, set to 1",
    fixed = TRUE
  )

  # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
  expect_equal(sv$scale, 1, tolerance = 1e-8)

  sc_mean <- get_means(sc, y1, variance = c("se", "ci"))
  sv_mean <- survey::svymean(~y1, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_mean$se, as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
  expect_equal(sc_mean$ci_low, confint(sv_mean)[1], tolerance = 1e-6)
  expect_equal(sc_mean$ci_high, confint(sv_mean)[2], tolerance = 1e-6)
})

test_that("survey::svrepdesign() refuses Fay without rho — Fay design", {
  skip_if_not_installed("survey")

  # This block compares nothing. survey refuses type = "Fay" without a rho
  # before it builds anything, and surveycore has no rho argument today, so
  # no comparison is possible. Issue #243 owns the gap: a later PR adds the
  # rho argument and rewrites this block into a real oracle comparison.
  #
  # The first half asserts what another package refuses to do, so that half
  # guards survey's behaviour and not surveycore's. A failure there most
  # likely means survey changed its message or dropped the requirement —
  # read it that way before reading it as a surveycore regression.
  d <- make_survey_data(
    n = 200,
    n_psu = 20,
    n_strata = 4,
    design = "replicate",
    type = "fay",
    seed = 15
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)
  n_rep <- length(repwt_cols)

  # The error is a bare stop(), so it carries no class but simpleError, and
  # the message text is the only thing that names the branch.
  expect_error(
    survey::svrepdesign(
      weights = d$wt,
      repweights = d[, repwt_cols],
      type = "Fay",
      data = d
    ),
    "With type='Fay' you must supply the correct rho",
    fixed = TRUE
  )

  # surveycore builds the design and stores the BRR scale, 1 / R, because it
  # has no rho to shrink by. R is 10 here, not 20: the generator returns
  # n_psu %/% 2 replicate columns in the fay mode as it does in brr.
  # SE/variance row, 1e-8.
  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = all_of(repwt_cols),
    type = "Fay"
  )
  expect_equal(sc@variables$scale, 1 / n_rep, tolerance = 1e-8)
})
