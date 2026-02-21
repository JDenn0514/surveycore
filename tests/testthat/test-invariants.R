# tests/testthat/test-invariants.R
#
# Meta-tests: verify that test_invariants() correctly FAILS when given
# intentionally broken survey objects.
#
# Why this matters: test_invariants() is called as the FIRST assertion in every
# constructor test block. If the checker silently passed on broken objects, all
# constructor tests would give false confidence. These tests confirm the checker
# actually fires on each invariant violation.
#
# Technique: construct a valid object first, then break exactly one invariant
# by setting the underlying attribute directly via attr() — this bypasses the
# S7 property setter and class validator, allowing us to create invalid states
# that would be rejected by normal property assignment.
# S7 stores each property as a named attribute (e.g., attr(x, "data")).


# ── Helpers ───────────────────────────────────────────────────────────────────

# Build a valid survey_taylor to start from.
.make_valid_taylor <- function() {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 99L)
  as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE)
}


# ── Invariant: @data is a data.frame ──────────────────────────────────────────

test_that("test_invariants() fails when @data is not a data.frame", {
  d      <- .make_valid_taylor()
  broken <- d
  attr(broken, "data") <- list(x = 1:5)  # list, not data.frame
  expect_failure(test_invariants(broken))
})


# ── Invariant: @data has at least 1 row ───────────────────────────────────────

test_that("test_invariants() fails when @data has 0 rows", {
  d      <- .make_valid_taylor()
  broken <- d
  attr(broken, "data") <- d@data[integer(0L), ]
  expect_failure(test_invariants(broken))
})


# ── Invariant: @data has no duplicate column names ────────────────────────────

test_that("test_invariants() fails when @data has duplicate column names", {
  d      <- .make_valid_taylor()
  broken <- d
  duped  <- d@data
  names(duped)[1:2] <- c("dup", "dup")
  attr(broken, "data") <- duped
  expect_failure(test_invariants(broken))
})


# ── Invariant: design columns exist in @data ─────────────────────────────────

test_that("test_invariants() fails when a design column is missing from @data", {
  d      <- .make_valid_taylor()
  broken <- d
  # Drop the weights column from @data (keep @variables pointing to it)
  no_wt <- d@data[, setdiff(names(d@data), d@variables$weights), drop = FALSE]
  attr(broken, "data") <- no_wt
  expect_failure(test_invariants(broken))
})


# ── Invariant: weight column is numeric and positive ─────────────────────────

test_that("test_invariants() fails when weight column has non-positive values", {
  d       <- .make_valid_taylor()
  broken  <- d
  bad_dat <- d@data
  bad_dat[[d@variables$weights]][[1L]] <- -1
  attr(broken, "data") <- bad_dat
  expect_failure(test_invariants(broken))
})


# ── Invariant: @metadata is a survey_metadata object ─────────────────────────

test_that("test_invariants() fails when @metadata is not a survey_metadata", {
  d      <- .make_valid_taylor()
  broken <- d
  attr(broken, "metadata") <- list(not_a_metadata = TRUE)
  expect_failure(test_invariants(broken))
})
