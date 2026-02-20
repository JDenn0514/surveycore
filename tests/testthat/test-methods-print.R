# tests/testthat/test-methods-print.R
#
# Tests for print and summary S7 methods on survey design objects.
# Source: R/04-methods-print.R
#
# Test structure:
#   1. print.survey_taylor — default output (snapshot)
#   2. print.survey_taylor — full = TRUE (snapshot)
#   3. print.survey_taylor — individual info flags (content checks)
#   4. print.survey_taylor — invisible return
#   5. print.survey_taylor — probs_provided indicator
#   6. print.survey_taylor — SRS auto-weight (no "Weights provided as:" line)
#   7. print.survey_replicate — default output (snapshot)
#   8. print.survey_replicate — full = TRUE (snapshot)
#   9. print.survey_replicate — invisible return
#  10. print.survey_twophase — default output (snapshot)
#  11. print.survey_twophase — full = TRUE (snapshot)
#  12. print.survey_twophase — invisible return
#  13. summary.survey_taylor — output (snapshot)
#  14. summary.survey_taylor — content checks
#  15. summary.survey_taylor — invisible return
#  16. summary.survey_replicate — output (snapshot)
#  17. summary.survey_twophase — output (snapshot)
#
# Note: cli output (cli_h1/h2/text/bullets) goes to message(), not stdout.
# Use capture.output(type = "message") to capture cli output in tests.
# Tibble data output goes to stdout; use capture.output() (default).
# expect_snapshot() captures both stdout and message automatically.


# ── Fixtures ────────────────────────────────────────────────────────────────

# taylor design with ids, strata, fpc, weights
make_taylor_design <- function(seed = 42L) {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = seed)
  as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE)
}

# SRS design (no design vars — uses ..surveycore_wt..)
make_srs_design <- function(seed = 42L) {
  df <- make_survey_data(n = 30L, n_psu = 10L, n_strata = 2L, seed = seed)
  suppressWarnings(as_survey(df))
}

# replicate weights design (BRR)
make_rep_design <- function(seed = 42L) {
  df <- make_survey_data(
    n = 50L, n_psu = 10L, n_strata = 2L,
    design = "replicate", type = "brr", seed = seed
  )
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  as_survey_rep(
    df,
    weights    = wt,
    repweights = tidyselect::all_of(repwt_cols),
    type       = "BRR"
  )
}

# two-phase design
make_twophase_design <- function(seed = 42L) {
  df <- make_survey_data(
    n = 60L, n_psu = 10L, n_strata = 2L,
    design = "twophase", seed = seed
  )
  phase1 <- as_survey(
    df,
    ids     = psu,
    weights = wt,
    strata  = strata,
    fpc     = fpc,
    nest    = TRUE
  )
  suppressWarnings(as_survey_twophase(phase1, subset = phase2_ind))
}


# ── 1. print.survey_taylor — default output ─────────────────────────────────

test_that("print.survey_taylor default output matches snapshot", {
  d <- make_taylor_design()
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  expect_snapshot(print(d))
})


# ── 2. print.survey_taylor — full = TRUE ────────────────────────────────────

test_that("print.survey_taylor full=TRUE output matches snapshot", {
  d <- make_taylor_design()
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  expect_snapshot(print(d, full = TRUE))
})


# ── 3. print.survey_taylor — individual info flags ──────────────────────────

test_that("print.survey_taylor design_info=TRUE shows design spec section", {
  d <- make_taylor_design()
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  # cli output goes to message(), not stdout
  out <- capture.output(print(d, design_info = TRUE), type = "message")
  expect_true(any(grepl("Design specification", out)))
  expect_true(any(grepl("Strata", out)))
  expect_true(any(grepl("IDs", out)))
})

test_that("print.survey_taylor weights_info=TRUE shows weight distribution and Weighted N", {
  d <- make_taylor_design()
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  out <- capture.output(print(d, weights_info = TRUE), type = "message")
  expect_true(any(grepl("Weight distribution", out)))
  expect_true(any(grepl("Range", out)))
  expect_true(any(grepl("Weighted N", out)))
})

test_that("print.survey_taylor metadata_info=TRUE shows labeled count", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L,
                         seed = 42L, with_labels = TRUE)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  out <- capture.output(print(d, metadata_info = TRUE), type = "message")
  expect_true(any(grepl("Metadata", out)))
  expect_true(any(grepl("labeled", out)))
})

test_that("print.survey_taylor default suppresses detail sections", {
  d <- make_taylor_design()
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  out <- capture.output(print(d), type = "message")
  expect_false(any(grepl("Design specification", out)))
  expect_false(any(grepl("Weight distribution", out)))
  expect_false(any(grepl("Metadata", out)))
})


# ── 4. print.survey_taylor — invisible return ────────────────────────────────

test_that("print.survey_taylor returns x invisibly", {
  d <- make_taylor_design()
  test_invariants(d)
  # capture.output suppresses stdout (tibble); cli msg goes to message
  result <- suppressMessages(print(d, n = 1L))
  expect_identical(result, d)
})


# ── 5. print.survey_taylor — probs_provided indicator ───────────────────────

test_that("print.survey_taylor design_info shows 'sampling weights' when weights given", {
  d <- make_taylor_design()
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  out <- capture.output(print(d, design_info = TRUE), type = "message")
  expect_true(any(grepl("sampling weights", out)))
})

test_that("print.survey_taylor design_info shows 'probabilities (converted)' when probs given", {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 42L)
  df$prob <- 1 / df$wt
  d <- as_survey(df, ids = psu, probs = prob, strata = strata, nest = TRUE)
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  out <- capture.output(print(d, design_info = TRUE), type = "message")
  expect_true(any(grepl("probabilities.*converted", out)))
})


# ── 6. print.survey_taylor — SRS auto-weight ────────────────────────────────

test_that("print.survey_taylor SRS design omits 'Weights provided as:' line", {
  d <- make_srs_design()
  test_invariants(d)
  # @variables$weights should be the internal auto-weight column
  expect_identical(d@variables$weights, "..surveycore_wt..")
  withr::local_options(list(width = 80L, cli.width = 80L))
  out <- capture.output(print(d, design_info = TRUE), type = "message")
  # SRS: no "Weights provided as:" bullet
  expect_false(any(grepl("Weights provided as:", out)))
})


# ── 7. print.survey_replicate — default output ──────────────────────────────

test_that("print.survey_replicate default output matches snapshot", {
  d <- make_rep_design()
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  expect_snapshot(print(d))
})


# ── 8. print.survey_replicate — full = TRUE ─────────────────────────────────

test_that("print.survey_replicate full=TRUE output matches snapshot", {
  d <- make_rep_design()
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  expect_snapshot(print(d, full = TRUE))
})


# ── 9. print.survey_replicate — invisible return ─────────────────────────────

test_that("print.survey_replicate returns x invisibly", {
  d <- make_rep_design()
  test_invariants(d)
  result <- suppressMessages(print(d, n = 1L))
  expect_identical(result, d)
})


# ── 10. print.survey_twophase — default output ──────────────────────────────

test_that("print.survey_twophase default output matches snapshot", {
  d <- make_twophase_design()
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  expect_snapshot(print(d))
})


# ── 11. print.survey_twophase — full = TRUE ─────────────────────────────────

test_that("print.survey_twophase full=TRUE output matches snapshot", {
  d <- make_twophase_design()
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  expect_snapshot(print(d, full = TRUE))
})


# ── 12. print.survey_twophase — invisible return ─────────────────────────────

test_that("print.survey_twophase returns x invisibly", {
  d <- make_twophase_design()
  test_invariants(d)
  result <- suppressMessages(print(d, n = 1L))
  expect_identical(result, d)
})


# ── 13. summary.survey_taylor — output ──────────────────────────────────────

test_that("summary.survey_taylor output matches snapshot", {
  d <- make_taylor_design()
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  expect_snapshot(summary(d))
})


# ── 14. summary.survey_taylor — content checks ──────────────────────────────

test_that("summary.survey_taylor shows type, size, design, and metadata sections", {
  d <- make_taylor_design()
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  out <- capture.output(summary(d), type = "message")
  expect_true(any(grepl("Taylor series linearization", out)))
  expect_true(any(grepl("Sample size", out)))
  expect_true(any(grepl("Weighted N", out)))
  expect_true(any(grepl("IDs", out)))
  expect_true(any(grepl("Strata", out)))
  expect_true(any(grepl("Metadata", out)))
})

test_that("summary.survey_taylor SRS design shows 'none' for IDs and Strata", {
  d <- make_srs_design()
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  out <- capture.output(summary(d), type = "message")
  expect_true(any(grepl("IDs: none", out)))
  expect_true(any(grepl("Strata: none", out)))
})


# ── 15. summary.survey_taylor — invisible return ────────────────────────────

test_that("summary.survey_taylor returns object invisibly", {
  d <- make_taylor_design()
  test_invariants(d)
  result <- suppressMessages(summary(d))
  expect_identical(result, d)
})


# ── 16. summary.survey_replicate — output ───────────────────────────────────

test_that("summary.survey_replicate output matches snapshot", {
  d <- make_rep_design()
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  expect_snapshot(summary(d))
})

test_that("summary.survey_replicate returns object invisibly", {
  d <- make_rep_design()
  test_invariants(d)
  result <- suppressMessages(summary(d))
  expect_identical(result, d)
})


# ── 17. summary.survey_twophase — output ────────────────────────────────────

test_that("summary.survey_twophase output matches snapshot", {
  d <- make_twophase_design()
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  expect_snapshot(summary(d))
})

test_that("summary.survey_twophase returns object invisibly", {
  d <- make_twophase_design()
  test_invariants(d)
  result <- suppressMessages(summary(d))
  expect_identical(result, d)
})
