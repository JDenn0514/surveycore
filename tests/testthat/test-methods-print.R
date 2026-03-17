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
  as_survey(
    df,
    ids = psu,
    weights = wt,
    strata = strata,
    fpc = fpc,
    nest = TRUE
  )
}

# Taylor design with no ids/strata and auto-weights (tests print/summary "none" branches)
make_srs_design <- function(seed = 42L) {
  df <- make_survey_data(n = 30L, n_psu = 10L, n_strata = 2L, seed = seed)
  wt_col <- surveycore:::.SURVEYCORE_WT_COL
  df[[wt_col]] <- rep(1L, nrow(df))
  survey_taylor(
    data = df,
    metadata = survey_metadata(),
    variables = list(
      ids = NULL,
      weights = wt_col,
      strata = NULL,
      fpc = NULL,
      nest = FALSE,
      probs_provided = FALSE,
      visible_vars = NULL
    )
  )
}

# replicate weights design (BRR)
make_rep_design <- function(seed = 42L) {
  df <- make_survey_data(
    n = 50L,
    n_psu = 10L,
    n_strata = 2L,
    design = "replicate",
    type = "brr",
    seed = seed
  )
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::all_of(repwt_cols),
    type = "BRR"
  )
}

# two-phase design
make_twophase_design <- function(seed = 42L) {
  df <- make_survey_data(
    n = 60L,
    n_psu = 10L,
    n_strata = 2L,
    design = "twophase",
    seed = seed
  )
  phase1 <- as_survey(
    df,
    ids = psu,
    weights = wt,
    strata = strata,
    fpc = fpc,
    nest = TRUE
  )
  as_survey_twophase(phase1, subset = subset)
}


# ── 1. print.survey_taylor — default output ─────────────────────────────────

test_that("print.survey_taylor default output matches snapshot", {
  d <- make_taylor_design()
  test_invariants(d)
  expect_false(surveycore::SURVEYCORE_DOMAIN_COL %in% names(d@data))
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
  df <- make_survey_data(
    n = 50L,
    n_psu = 10L,
    n_strata = 2L,
    seed = 42L,
    with_labels = TRUE
  )
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
  expect_false(surveycore::SURVEYCORE_DOMAIN_COL %in% names(d@data))
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
  expect_false(surveycore::SURVEYCORE_DOMAIN_COL %in% names(d@data))
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


# ── Domain info line ─────────────────────────────────────────────────────────
# 28. print.survey_taylor — domain line present (snapshot)
# 29. print.survey_taylor — domain count excludes NAs (snapshot)
# 30. print.survey_taylor — domain line appears before groups line (snapshot)
# 31. print.survey_replicate — domain line present (snapshot)
# 32. print.survey_twophase — domain line present (snapshot)
# 33. print.survey_nonprob — default output (snapshot; net-new baseline)
# 34. print.survey_nonprob — domain line present (snapshot)
# 35. print.survey_taylor — zero rows in domain (snapshot)

# ── 28. print.survey_taylor — domain line present ────────────────────────────

test_that("print.survey_taylor() shows domain line when domain column is present", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_taylor_design()
  test_invariants(d)
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$y1 > 0
  expect_snapshot(print(d))
})


# ── 29. print.survey_taylor — domain count excludes NAs ──────────────────────

test_that("print.survey_taylor() domain count excludes NAs", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_taylor_design()
  test_invariants(d)
  mask <- rep(c(TRUE, FALSE, NA), length.out = nrow(d@data))
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- mask
  expect_snapshot(print(d))
})


# ── 30. print.survey_taylor — domain line appears before groups line ──────────

test_that("print.survey_taylor() domain line appears before groups line", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_taylor_design()
  test_invariants(d)
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$y1 > 0
  d@groups <- "strata"
  expect_snapshot(print(d))
})


# ── 31. print.survey_replicate — domain line present ─────────────────────────

test_that("print.survey_replicate() shows domain line when domain column is present", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_rep_design()
  test_invariants(d)
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$y1 > 0
  expect_snapshot(print(d))
})


# ── 33. print.survey_twophase — domain line present ──────────────────────────

test_that("print.survey_twophase() shows domain line when domain column is present", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_twophase_design()
  test_invariants(d)
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$y1 > 0
  expect_snapshot(print(d))
})


# ── 34. print.survey_nonprob — default output (net-new baseline) ──────────

test_that("print.survey_nonprob() default output", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  df <- make_survey_data(n = 30L, n_psu = 6L, n_strata = 2L, seed = 42L)
  set.seed(123L)
  df$cal_wt <- df$wt * runif(nrow(df), 0.9, 1.1)
  d <- as_survey_nonprob(df, weights = cal_wt)
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_nonprob))
  expect_false(surveycore::SURVEYCORE_DOMAIN_COL %in% names(d@data))
  expect_snapshot(print(d))
})


# ── 35. print.survey_nonprob — domain line present ────────────────────────

test_that("print.survey_nonprob() shows domain line when domain column is present", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  df <- make_survey_data(n = 30L, n_psu = 6L, n_strata = 2L, seed = 42L)
  set.seed(123L)
  df$cal_wt <- df$wt * runif(nrow(df), 0.9, 1.1)
  d <- as_survey_nonprob(df, weights = cal_wt)
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_nonprob))
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- d@data$y1 > 0
  expect_snapshot(print(d))
})


# ── 36. print.survey_taylor — zero rows in domain ────────────────────────────

test_that("print.survey_taylor() shows domain line when zero rows are in domain", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_taylor_design()
  test_invariants(d)
  d@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- FALSE
  expect_snapshot(print(d))
})

# ── 37. print.survey_replicate — groups + FPC ────────────────────────────────

test_that("print.survey_replicate() shows groups when @groups is set", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_rep_design()
  test_invariants(d)
  d@groups <- "strata"
  out <- capture.output(print(d), type = "message")
  expect_true(any(grepl("Groups", out)))
})

test_that("print.survey_replicate() with FPC covers FPC design_info block", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_rep_design()
  test_invariants(d)
  # Add a synthetic FPC column to trigger the FPC design_info block
  d@data$fpc_rep <- rep(500L, nrow(d@data))
  d@variables$fpc <- "fpc_rep"
  d@variables$fpctype <- "population"
  out <- capture.output(print(d, design_info = TRUE), type = "message")
  expect_true(any(grepl("FPC", out)))
})

# ── 39. print.survey_twophase — groups + Phase 2 strata/ids ─────────────────

test_that("print.survey_twophase() shows groups when @groups is set", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_twophase_design()
  test_invariants(d)
  d@groups <- "strata"
  out <- capture.output(print(d), type = "message")
  expect_true(any(grepl("Groups", out)))
})

test_that("print.survey_twophase full=TRUE includes Phase 2 fields", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_twophase_design()
  test_invariants(d)
  out <- capture.output(print(d, full = TRUE), type = "message")
  expect_true(any(grepl("Phase 2", out)))
})

# ── 40. summary.survey_replicate — content checks ────────────────────────────

test_that("summary.survey_replicate() shows BRR type and replicate count", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_rep_design()
  test_invariants(d)
  out <- capture.output(summary(d), type = "message")
  expect_true(any(grepl("BRR", out)))
  expect_true(any(grepl("Replicate", out, ignore.case = TRUE)))
})

# ── 41. summary.survey_twophase — content checks ─────────────────────────────

test_that("summary.survey_twophase() shows Phase 1 and Phase 2 sections", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_twophase_design()
  test_invariants(d)
  out <- capture.output(summary(d), type = "message")
  expect_true(any(grepl("Phase 1", out)))
  expect_true(any(grepl("Phase 2", out)))
})

test_that("summary.survey_twophase() shows Phase 2 IDs and strata when present", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  # Build a twophase design that has Phase 2 strata and IDs
  df <- make_survey_data(
    n = 80L,
    n_psu = 10L,
    n_strata = 2L,
    design = "twophase",
    seed = 99L
  )
  phase1 <- as_survey(
    df,
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
  out <- capture.output(summary(sc), type = "message")
  expect_true(any(grepl("Phase 2", out)))
})

# ---------------------------------------------------------------------------
# Additional coverage: calibrated print, replicate FPC summary,
# twophase print with Phase 2 ids/strata
# ---------------------------------------------------------------------------

test_that("print.survey_nonprob() runs without error and produces output", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  set.seed(901)
  df <- data.frame(y = rnorm(30), w = runif(30, 0.5, 2))
  sc <- as_survey_nonprob(df, weights = w)
  out <- capture.output(print(sc), type = "message")
  expect_true(any(grepl("survey_nonprob", out)))
})

test_that("summary.survey_replicate() with FPC covers the FPC line", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_survey_data(
    n = 60,
    n_psu = 10,
    n_strata = 2,
    design = "replicate",
    type = "brr",
    seed = 902
  )
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)
  sc <- as_survey_replicate(
    d,
    weights = wt,
    repweights = tidyselect::all_of(repwt_cols),
    type = "BRR",
    fpc = fpc,
    fpctype = "fraction"
  )
  out <- capture.output(summary(sc), type = "message")
  expect_true(any(grepl("FPC", out)))
})

test_that("print.survey_twophase() with full=TRUE shows Phase 2 ids and strata lines", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_survey_data(
    n = 100,
    n_psu = 10,
    n_strata = 2,
    design = "twophase",
    seed = 903
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
  out <- capture.output(print(sc, full = TRUE), type = "message")
  expect_true(any(grepl("Phase 2", out)))
  expect_true(any(grepl("IDs|Strata|ids|strata", out)))
})

test_that("summary.survey_twophase() with Phase 1 strata covers the Strata line", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_survey_data(
    n = 100,
    n_psu = 10,
    n_strata = 2,
    design = "twophase",
    seed = 904
  )
  phase1 <- as_survey(
    d,
    ids = psu,
    weights = wt,
    strata = strata,
    fpc = fpc,
    nest = TRUE
  )
  sc <- as_survey_twophase(phase1, subset = subset, method = "approx")
  out <- capture.output(summary(sc), type = "message")
  expect_true(any(grepl("Strata|strata", out)))
})


# ── Multi-stage FPC display ──────────────────────────────────────────────────

test_that("print.survey_taylor shows per-stage FPC for 2-stage design", {
  df <- make_survey_data(n = 200, n_psu = 20, n_ssu = 5, seed = 1)
  sc <- as_survey(
    df,
    ids = c(psu, ssu),
    weights = wt,
    strata = strata,
    fpc = c(fpc, fpc2)
  )
  test_invariants(sc)
  withr::local_options(list(width = 80L, cli.width = 80L))
  expect_snapshot(print(sc, design_info = TRUE))
})

test_that("print.survey_taylor shows single FPC line for 1-stage design", {
  d <- make_taylor_design()
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))
  out <- capture.output(print(d, design_info = TRUE), type = "message")
  # Should show single "FPC: fpc" line, not "FPC (stage 1):"

  expect_true(any(grepl("FPC: fpc$", out)))
  expect_false(any(grepl("FPC \\(stage", out)))
})
