# test-variance-dispatch.R
# Tests for the public estimation dispatch: .validate_estimation_input(),
# get_means(), get_totals() — dispatch to correct engine, error paths,
# return structure, and trivial numerical correctness.

# ---------------------------------------------------------------------------
# Block 7: Return value structure
# ---------------------------------------------------------------------------

test_that("get_means() returns correct structure", {
  df <- data.frame(y = 1:10, w = rep(1, 10))
  d  <- as_survey_srs(df, weights = w)
  result <- get_means(d, y)

  expect_type(result, "list")
  expect_named(result, c("variable", "mean", "se"))
  expect_identical(result$variable, "y")
  expect_type(result$mean, "double")
  expect_type(result$se, "double")
  expect_true(is.finite(result$mean))
  expect_true(is.finite(result$se))
  expect_gte(result$se, 0)
})

test_that("get_totals() returns correct structure", {
  df <- data.frame(y = 1:10, w = rep(1, 10))
  d  <- as_survey_srs(df, weights = w)
  result <- get_totals(d, y)

  expect_type(result, "list")
  expect_named(result, c("variable", "total", "se"))
  expect_identical(result$variable, "y")
  expect_type(result$total, "double")
  expect_type(result$se, "double")
  expect_true(is.finite(result$total))
  expect_true(is.finite(result$se))
  expect_gte(result$se, 0)
})

# ---------------------------------------------------------------------------
# Block 8: Error paths
# ---------------------------------------------------------------------------

test_that("get_means() dispatches to two-phase engine for survey_twophase", {
  d      <- make_survey_data(design = "twophase", seed = 1)
  phase1 <- as_survey(d, ids = psu, strata = strata, weights = wt)
  two    <- as_survey_twophase(phase1, subset = subset, method = "approx")
  result <- get_means(two, y1)

  expect_type(result, "list")
  expect_named(result, c("variable", "mean", "se"))
  expect_identical(result$variable, "y1")
  expect_true(is.finite(result$mean))
  expect_true(is.finite(result$se))
  expect_gte(result$se, 0)
})

test_that("get_totals() dispatches to two-phase engine for survey_twophase", {
  d      <- make_survey_data(design = "twophase", seed = 1)
  phase1 <- as_survey(d, ids = psu, strata = strata, weights = wt)
  two    <- as_survey_twophase(phase1, subset = subset, method = "approx")
  result <- get_totals(two, y1)

  expect_type(result, "list")
  expect_named(result, c("variable", "total", "se"))
  expect_identical(result$variable, "y1")
  expect_true(is.finite(result$total))
  expect_true(is.finite(result$se))
  expect_gte(result$se, 0)
})

test_that("get_means() errors when variable not found", {
  df <- data.frame(y = 1:5, w = rep(1, 5))
  d  <- as_survey_srs(df, weights = w)
  expect_error(
    get_means(d, nonexistent),
    class = "surveycore_error_var_not_found"
  )
})

test_that("get_totals() errors when variable not found", {
  df <- data.frame(y = 1:5, w = rep(1, 5))
  d  <- as_survey_srs(df, weights = w)
  expect_error(
    get_totals(d, nonexistent),
    class = "surveycore_error_var_not_found"
  )
})

test_that("get_means() errors for non-numeric variable", {
  df <- data.frame(y = letters[1:5], w = rep(1, 5), stringsAsFactors = FALSE)
  d  <- as_survey_srs(df, weights = w)
  expect_error(
    get_means(d, y),
    class = "surveycore_error_var_not_numeric"
  )
})

test_that("get_totals() errors for non-numeric variable", {
  df <- data.frame(y = letters[1:5], w = rep(1, 5), stringsAsFactors = FALSE)
  d  <- as_survey_srs(df, weights = w)
  expect_error(
    get_totals(d, y),
    class = "surveycore_error_var_not_numeric"
  )
})

# ---------------------------------------------------------------------------
# Block 9: Numerical correctness — simple known values
# ---------------------------------------------------------------------------

test_that("get_means() computes correct weighted mean for trivial case", {
  # Weighted mean of (1, 2, 3) with weights (1, 2, 3) = (1*1 + 2*2 + 3*3)/(1+2+3) = 14/6
  df <- data.frame(y = c(1, 2, 3), w = c(1, 2, 3))
  d  <- as_survey_srs(df, weights = w)
  result <- get_means(d, y)
  expect_equal(result$mean, 14 / 6, tolerance = 1e-14)
})

test_that("get_totals() computes correct weighted total for trivial case", {
  # Weighted total of (1, 2, 3) with weights (2, 3, 4) = 2 + 6 + 12 = 20
  df <- data.frame(y = c(1, 2, 3), w = c(2, 3, 4))
  d  <- as_survey_srs(df, weights = w)
  result <- get_totals(d, y)
  expect_equal(result$total, 20, tolerance = 1e-14)
})

# ---------------------------------------------------------------------------
# Block 11: Error paths — non-survey inputs to get_means()/get_totals()
# ---------------------------------------------------------------------------

test_that("get_means() errors for non-survey-design object", {
  expect_error(
    get_means(data.frame(x = 1:5, y = rnorm(5)), y),
    class = "surveycore_error_not_survey_design"
  )
})

test_that("get_totals() errors for non-survey-design object", {
  expect_error(
    get_totals(list(x = 1), x),
    class = "surveycore_error_not_survey_design"
  )
})
