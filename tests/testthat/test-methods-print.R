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
#  18. print.survey_srs — default output (snapshot)
#  19. print.survey_srs — design_info with population FPC (snapshot)
#  20. print.survey_srs — design_info with fraction FPC (snapshot)
#  21. print.survey_srs — full = TRUE (snapshot)
#  22. print.survey_srs — uniform auto-weights label
#  23. print.survey_srs — invisible return
#  24. summary.survey_srs — output and invisible return
#  25. summary.survey_srs — FPC info in output
#  26. summary.survey_srs — output (snapshot)
#  27. print.survey_srs — probs_provided label in design_info
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

# Taylor design with no ids/strata and auto-weights (tests print/summary "none" branches)
# Directly constructed to bypass SRS dispatch (as_survey() without ids/strata
# now creates survey_srs; survey_srs print/summary added in Step 3)
make_srs_design <- function(seed = 42L) {
  df <- make_survey_data(n = 30L, n_psu = 10L, n_strata = 2L, seed = seed)
  wt_col <- surveycore:::.SURVEYCORE_WT_COL
  df[[wt_col]] <- rep(1L, nrow(df))
  survey_taylor(
    data      = df,
    metadata  = survey_metadata(),
    variables = list(
      ids            = NULL,
      weights        = wt_col,
      strata         = NULL,
      fpc            = NULL,
      nest           = FALSE,
      probs_provided = FALSE,
      visible_vars   = NULL
    )
  )
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


# ── 18. print.survey_srs — default output ────────────────────────────────────

test_that("print.survey_srs default output matches snapshot", {
  d <- as_survey_srs(
    data.frame(y = 1:10, wt = rep(2, 10)),
    weights = wt
  )
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  expect_snapshot(print(d))
})


# ── 19. print.survey_srs — design_info with population FPC ───────────────────

test_that("print.survey_srs design_info=TRUE with population FPC matches snapshot", {
  df <- data.frame(y = 1:5, wt = rep(2, 5), pop = rep(100L, 5))
  d  <- as_survey_srs(df, weights = wt, fpc = pop)
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  expect_snapshot(print(d, design_info = TRUE))
})


# ── 20. print.survey_srs — design_info with fraction FPC ─────────────────────

test_that("print.survey_srs design_info=TRUE with fraction FPC matches snapshot", {
  df <- data.frame(y = 1:5, wt = rep(2, 5), frac = rep(0.1, 5))
  d  <- as_survey_srs(df, weights = wt, fpc = frac)
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  expect_snapshot(print(d, design_info = TRUE))
})


# ── 21. print.survey_srs — full = TRUE ───────────────────────────────────────

test_that("print.survey_srs full=TRUE output matches snapshot", {
  d <- as_survey_srs(
    data.frame(y = 1:5, wt = rep(2, 5)),
    weights = wt
  )
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  expect_snapshot(print(d, full = TRUE))
})


# ── 22. print.survey_srs — uniform auto-weights label ────────────────────────

test_that("print.survey_srs shows 'uniform (auto-assigned)' for no-weights design", {
  d <- suppressWarnings(as_survey_srs(data.frame(y = 1:5)))
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  out <- capture.output(print(d, design_info = TRUE), type = "message")
  expect_true(any(grepl("uniform \\(auto-assigned\\)", out)))
})


# ── 23. print.survey_srs — invisible return ───────────────────────────────────

test_that("print.survey_srs returns object invisibly", {
  d      <- as_survey_srs(data.frame(y = 1:5, wt = rep(1, 5)), weights = wt)
  result <- withVisible(suppressMessages(print(d)))
  expect_false(result$visible)
  expect_true(S7::S7_inherits(result$value, survey_srs))
})


# ── 24. summary.survey_srs — output and invisible return ─────────────────────

test_that("summary.survey_srs shows type, size, weights, FPC, and metadata sections", {
  d <- as_survey_srs(data.frame(y = 1:10, wt = rep(2, 10)), weights = wt)
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  out <- capture.output(summary(d), type = "message")
  expect_true(any(grepl("simple random sample", out, ignore.case = TRUE)))
  expect_true(any(grepl("Sample size", out)))
  expect_true(any(grepl("Weighted N", out)))
  expect_true(any(grepl("FPC", out)))
  expect_true(any(grepl("Metadata", out)))
})

test_that("summary.survey_srs returns object invisibly", {
  d <- as_survey_srs(data.frame(y = 1:10, wt = rep(2, 10)), weights = wt)
  test_invariants(d)
  result <- suppressMessages(summary(d))
  expect_identical(result, d)
})


# ── 25. summary.survey_srs — FPC info in output ───────────────────────────────

test_that("summary.survey_srs reflects population FPC in output", {
  df <- data.frame(y = 1:5, wt = rep(1, 5), pop = rep(100L, 5))
  d  <- as_survey_srs(df, weights = wt, fpc = pop)
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  out <- capture.output(summary(d), type = "message")
  expect_true(any(grepl("pop", out)))
  expect_true(any(grepl("population sizes", out)))
})

test_that("summary.survey_srs reflects fraction FPC in output", {
  df <- data.frame(y = 1:5, wt = rep(1, 5), frac = rep(0.1, 5))
  d  <- as_survey_srs(df, weights = wt, fpc = frac)
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  out <- capture.output(summary(d), type = "message")
  expect_true(any(grepl("frac", out)))
  expect_true(any(grepl("sampling fractions", out)))
})


# ── 26. summary.survey_srs — output (snapshot) ───────────────────────────────

test_that("summary.survey_srs output matches snapshot", {
  d <- as_survey_srs(data.frame(y = 1:10, wt = rep(2, 10)), weights = wt)
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  expect_snapshot(summary(d))
})


# ── 27. print.survey_srs — probs_provided label ──────────────────────────────

test_that("print.survey_srs shows '(from sampling probabilities)' when probs_provided", {
  df <- data.frame(y = 1:10, p = rep(0.1, 10))
  d  <- as_survey_srs(df, probs = p)
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  out <- capture.output(print(d, design_info = TRUE), type = "message")
  expect_true(any(grepl("from sampling probabilities", out)))
})
