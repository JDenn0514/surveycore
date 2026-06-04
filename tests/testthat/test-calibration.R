# tests/testthat/test-calibration.R
#
# Tests for R/calibration.R — as_caldata()
#
# Coverage: error-messages.md rows CAL-1 through CAL-9.
# Per testing-standards.md: constructor input validation errors use the dual
# pattern: expect_error(class=) + expect_snapshot(error=TRUE).

# Setup shared test data (reused across tests)
base_w <- rep(1, 10)
g <- rep(1.1, 10)
mm <- matrix(1, 10, 2)


# ── Happy paths ────────────────────────────────────────────────────────────────

test_that("as_caldata() returns a list with the correct four names", {
  result <- as_caldata(base_w, g, mm)
  expect_type(result, "list")
  expect_identical(sort(names(result)), sort(c("qr", "w", "stage", "index")))
  expect_s3_class(result$qr, "qr")
  expect_equal(result$stage, 0L)
  expect_null(result$index)
})

test_that("as_caldata() w slot equals g_weights * sqrt(base_weights)", {
  result <- as_caldata(base_w, g, mm)
  expected_w <- g * sqrt(base_w)
  expect_equal(result$w, expected_w)
})

test_that("as_caldata() qr slot is qr of sqrt(base_w) * model_matrix", {
  result <- as_caldata(base_w, g, mm)
  expected_qr <- qr(sqrt(base_w) * mm)
  # Compare rank and pivot (structural equality) rather than identical() on
  # internal floating-point QR decomposition components
  expect_equal(result$qr$rank, expected_qr$rank)
  expect_equal(result$qr$pivot, expected_qr$pivot)
  expect_equal(qr.R(result$qr), qr.R(expected_qr), tolerance = 1e-10)
})

test_that("as_caldata() works with single-column model matrix (~1 intercept)", {
  mm1 <- matrix(1, 10, 1)
  result <- as_caldata(base_w, g, mm1)
  expect_type(result, "list")
  expect_identical(sort(names(result)), sort(c("qr", "w", "stage", "index")))
  expect_identical(result$stage, 0L)
  expect_null(result$index)
})

test_that("as_caldata() works with g_weights all equal to 1.0 (no calibration effect)", {
  g_ones <- rep(1.0, 10)
  result <- as_caldata(base_w, g_ones, mm)
  expected_w <- g_ones * sqrt(base_w)
  expect_equal(result$w, expected_w)
  expect_equal(result$w, sqrt(base_w))
})

test_that("as_caldata() works with n = 1 (single observation, R-6)", {
  bw1 <- 2.0
  gw1 <- 1.1
  mm1 <- matrix(1, 1, 1)
  result <- as_caldata(bw1, gw1, mm1)
  expect_s3_class(result$qr, "qr")
  expect_equal(result$w, gw1 * sqrt(bw1))
  expect_identical(result$stage, 0L)
  expect_null(result$index)
})


# ── Error paths ────────────────────────────────────────────────────────────────

test_that("as_caldata() errors on empty base_weights (n = 0, R-6)", {
  expect_error(
    as_caldata(numeric(0), numeric(0), matrix(0, 0, 1)),
    class = "surveycore_error_caldata_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    as_caldata(numeric(0), numeric(0), matrix(0, 0, 1))
  )
})

test_that("as_caldata() rejects non-positive base_weights", {
  bw_bad <- c(1, -1, 1, 1, 1, 1, 1, 1, 1, 1)
  expect_error(
    as_caldata(bw_bad, g, mm),
    class = "surveycore_error_caldata_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    as_caldata(bw_bad, g, mm)
  )
})

test_that("as_caldata() rejects NA in base_weights (B-4)", {
  bw_na <- c(NA_real_, rep(1, 9))
  expect_error(
    as_caldata(bw_na, g, mm),
    class = "surveycore_error_caldata_weights_missing"
  )
  expect_snapshot(
    error = TRUE,
    as_caldata(bw_na, g, mm)
  )
})

test_that("as_caldata() rejects Inf in base_weights (B-4)", {
  bw_inf <- c(Inf, rep(1, 9))
  expect_error(
    as_caldata(bw_inf, g, mm),
    class = "surveycore_error_caldata_weights_missing"
  )
  expect_snapshot(
    error = TRUE,
    as_caldata(bw_inf, g, mm)
  )
})

test_that("as_caldata() rejects non-positive g_weights", {
  g_bad <- c(1.1, -0.5, rep(1.1, 8))
  expect_error(
    as_caldata(base_w, g_bad, mm),
    class = "surveycore_error_caldata_gweights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    as_caldata(base_w, g_bad, mm)
  )
})

test_that("as_caldata() rejects NA in g_weights (B-4)", {
  g_na <- c(NA_real_, rep(1.1, 9))
  expect_error(
    as_caldata(base_w, g_na, mm),
    class = "surveycore_error_caldata_gweights_missing"
  )
  expect_snapshot(
    error = TRUE,
    as_caldata(base_w, g_na, mm)
  )
})

test_that("as_caldata() rejects g_weights of wrong length (B-3)", {
  g_short <- rep(1.1, 5)
  expect_error(
    as_caldata(base_w, g_short, mm),
    class = "surveycore_error_caldata_gweights_length_mismatch"
  )
  expect_snapshot(
    error = TRUE,
    as_caldata(base_w, g_short, mm)
  )
})

test_that("as_caldata() rejects near-zero g_weights * sqrt(base_weights)", {
  # Use very small g_weights so product < .Machine$double.eps^0.5
  # .Machine$double.eps^0.5 ~ 1.49e-8; use something 100x smaller
  g_tiny <- rep(.Machine$double.eps^0.6, 10)
  expect_error(
    as_caldata(base_w, g_tiny, mm),
    class = "surveycore_error_caldata_weights_near_zero"
  )
  expect_snapshot(
    error = TRUE,
    as_caldata(base_w, g_tiny, mm)
  )
})

test_that("as_caldata() rejects model_matrix with wrong number of rows", {
  mm_wrong <- matrix(1, 5, 2)
  expect_error(
    as_caldata(base_w, g, mm_wrong),
    class = "surveycore_error_caldata_dimension_mismatch"
  )
  expect_snapshot(
    error = TRUE,
    as_caldata(base_w, g, mm_wrong)
  )
})

test_that("as_caldata() rejects model_matrix with 0 columns", {
  mm_empty <- matrix(numeric(0), nrow = 10, ncol = 0)
  expect_error(
    as_caldata(base_w, g, mm_empty),
    class = "surveycore_error_caldata_empty_model_matrix"
  )
  expect_snapshot(
    error = TRUE,
    as_caldata(base_w, g, mm_empty)
  )
})

test_that("as_caldata() rejects model_matrix with NA values", {
  mm_na <- mm
  mm_na[1, 1] <- NA_real_
  expect_error(
    as_caldata(base_w, g, mm_na),
    class = "surveycore_error_caldata_model_matrix_invalid"
  )
  expect_snapshot(
    error = TRUE,
    as_caldata(base_w, g, mm_na)
  )
})

test_that("as_caldata() rejects model_matrix with Inf values", {
  mm_inf <- mm
  mm_inf[2, 1] <- Inf
  expect_error(
    as_caldata(base_w, g, mm_inf),
    class = "surveycore_error_caldata_model_matrix_invalid"
  )
  expect_snapshot(
    error = TRUE,
    as_caldata(base_w, g, mm_inf)
  )
})
