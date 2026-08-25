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


# ── print.survey_collection ──────────────────────────────────────────────────

test_that("print.survey_collection snapshot: small 3-survey collection", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  df1 <- make_survey_data(n = 1200L, n_psu = 20L, n_strata = 4L, seed = 31L)
  df2 <- make_survey_data(n = 1500L, n_psu = 30L, n_strata = 5L, seed = 32L)
  df3 <- make_survey_data(n = 2000L, n_psu = 20L, n_strata = 4L, seed = 33L)
  d1 <- suppressMessages(suppressWarnings(
    as_survey(df1, ids = psu, weights = wt, strata = strata, fpc = fpc)
  ))
  d2 <- suppressMessages(suppressWarnings(
    as_survey(df2, ids = psu, weights = wt, strata = strata, fpc = fpc)
  ))
  d3 <- suppressMessages(suppressWarnings(
    as_survey(df3, ids = psu, weights = wt, strata = strata, fpc = fpc)
  ))
  coll <- as_survey_collection(
    "2017-18" = d1,
    "2019-20" = d2,
    "2021-22" = d3
  )
  expect_snapshot(print(coll))
})

test_that("print.survey_collection snapshot: length-25 abbreviation", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  designs <- lapply(seq_len(25L), function(i) {
    df <- make_survey_data(
      n = 40L,
      n_psu = 8L,
      n_strata = 2L,
      seed = 100L + i
    )
    suppressMessages(suppressWarnings(
      as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
    ))
  })
  names(designs) <- paste0("wave_", sprintf("%02d", seq_len(25L)))
  coll <- do.call(
    as_survey_collection,
    designs
  )
  expect_snapshot(print(coll))
})

test_that("print.survey_collection snapshot: length-1 pluralisation", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 41L)
  d <- suppressMessages(suppressWarnings(
    as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  ))
  coll <- as_survey_collection(only = d)
  expect_snapshot(print(coll))
})


# ── NEW: survey_nonprob with repweights ──────────────────────────────────────

test_that("print.survey_nonprob() shows BOOTSTRAP class line with repweights", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  set.seed(42L)
  df <- make_survey_data(n = 100L, seed = 42L)
  # Add 10 repweight columns
  R <- 10L
  for (r in seq_len(R)) {
    df[[paste0("repwt_", r)]] <- pmax(0.1, df$wt * rexp(nrow(df)))
  }
  d <- as_survey_nonprob(df, weights = wt, repweights = starts_with("repwt_"))
  expect_snapshot(print(d))
})

test_that("print.survey_nonprob() shows SRS approximation note without repweights", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  df <- data.frame(y = rnorm(50L), wt = runif(50L, 0.5, 2.5))
  d <- as_survey_nonprob(df, weights = wt)
  expect_snapshot(print(d))
})

test_that("print.survey_nonprob() with repweights and design_info = TRUE shows replicate bullets", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  set.seed(42L)
  df <- make_survey_data(n = 100L, seed = 42L)
  R <- 10L
  for (r in seq_len(R)) {
    df[[paste0("repwt_", r)]] <- pmax(0.1, df$wt * rexp(nrow(df)))
  }
  d <- as_survey_nonprob(df, weights = wt, repweights = starts_with("repwt_"))
  expect_snapshot(print(d, design_info = TRUE))
})


# ── Task Group 6: print/summary for jackknife types ──────────────────────────

# Helper data for jackknife print tests
.make_nonprob_repwt_df <- function(n = 10, R = 4) {
  df <- data.frame(
    y = seq_len(n),
    wt = rep(1, n)
  )
  for (r in seq_len(R)) {
    df[[paste0("r", r)]] <- rep(1, n)
  }
  df
}

test_that("print(survey_nonprob): JK1 header contains 'JK1' not 'BOOTSTRAP'", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  df <- .make_nonprob_repwt_df(n = 10, R = 4)
  d <- as_survey_nonprob(
    df,
    weights = wt,
    repweights = c(r1, r2, r3, r4),
    type = "JK1"
  )
  test_invariants(d)
  output <- capture.output(print(d), type = "message")
  expect_true(any(grepl("JK1", output)))
  expect_false(any(grepl("BOOTSTRAP", output)))
})

test_that("print(survey_nonprob): JK2 header contains 'JK2'", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  df <- .make_nonprob_repwt_df(n = 10, R = 4)
  d <- as_survey_nonprob(
    df,
    weights = wt,
    repweights = c(r1, r2, r3, r4),
    type = "JK2",
    rscales = rep(0.75, 4)
  )
  test_invariants(d)
  output <- capture.output(print(d), type = "message")
  expect_true(any(grepl("JK2", output)))
  expect_false(any(grepl("BOOTSTRAP", output)))
})

test_that("print(survey_nonprob): JKn header contains 'JKN'", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  df <- .make_nonprob_repwt_df(n = 10, R = 4)
  d <- as_survey_nonprob(
    df,
    weights = wt,
    repweights = c(r1, r2, r3, r4),
    type = "JKn",
    rscales = rep(0.75, 4)
  )
  test_invariants(d)
  output <- capture.output(print(d), type = "message")
  expect_true(any(grepl("JKN", output)))
  expect_false(any(grepl("BOOTSTRAP", output)))
})

test_that("print(survey_nonprob): bootstrap header still contains 'BOOTSTRAP' [regression]", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  df <- .make_nonprob_repwt_df(n = 10, R = 4)
  d <- as_survey_nonprob(
    df,
    weights = wt,
    repweights = c(r1, r2, r3, r4),
    type = "bootstrap"
  )
  test_invariants(d)
  output <- capture.output(print(d), type = "message")
  expect_true(any(grepl("BOOTSTRAP", output)))
})

test_that("print(survey_nonprob): SRS-mode header does not contain 'JK' or 'BOOTSTRAP'", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  df <- data.frame(y = 1:10, wt = rep(1, 10))
  d <- as_survey_nonprob(df, weights = wt)
  output <- capture.output(print(d), type = "message")
  expect_false(any(grepl("JK", output)))
  expect_false(any(grepl("BOOTSTRAP", output)))
})

test_that("print(survey_nonprob): return value is input object, invisibly", {
  df <- .make_nonprob_repwt_df(n = 10, R = 4)
  d <- as_survey_nonprob(
    df,
    weights = wt,
    repweights = c(r1, r2, r3, r4),
    type = "JK1"
  )
  result <- withVisible(print(d))
  expect_false(result$visible)
  expect_true(S7::S7_inherits(result$value, survey_nonprob))
})

test_that("print(survey_nonprob): JK1 snapshot", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  df <- .make_nonprob_repwt_df(n = 10, R = 4)
  d <- as_survey_nonprob(
    df,
    weights = wt,
    repweights = c(r1, r2, r3, r4),
    type = "JK1"
  )
  expect_snapshot(print(d))
})

test_that("print(survey_nonprob): JK2 snapshot", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  df <- .make_nonprob_repwt_df(n = 10, R = 4)
  d <- as_survey_nonprob(
    df,
    weights = wt,
    repweights = c(r1, r2, r3, r4),
    type = "JK2",
    rscales = rep(0.75, 4)
  )
  expect_snapshot(print(d))
})

test_that("print(survey_nonprob): JKn snapshot", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  df <- .make_nonprob_repwt_df(n = 10, R = 4)
  d <- as_survey_nonprob(
    df,
    weights = wt,
    repweights = c(r1, r2, r3, r4),
    type = "JKn",
    rscales = rep(0.75, 4)
  )
  expect_snapshot(print(d))
})

test_that("print(survey_nonprob): bootstrap snapshot [regression guard]", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  df <- .make_nonprob_repwt_df(n = 10, R = 4)
  d <- as_survey_nonprob(
    df,
    weights = wt,
    repweights = c(r1, r2, r3, r4),
    type = "bootstrap"
  )
  expect_snapshot(print(d))
})

# ── summary tests for jackknife types ────────────────────────────────────────

test_that("summary(survey_nonprob): JK1 type line contains 'JK1 replicates'", {
  df <- .make_nonprob_repwt_df(n = 10, R = 4)
  d <- as_survey_nonprob(
    df,
    weights = wt,
    repweights = c(r1, r2, r3, r4),
    type = "JK1"
  )
  output <- capture.output(summary(d), type = "message")
  expect_true(any(grepl("JK1", output)))
  expect_true(any(grepl("replicates", output)))
})

test_that("summary(survey_nonprob): JKn type line contains 'JKn' (as-stored, no case transformation)", {
  df <- .make_nonprob_repwt_df(n = 10, R = 4)
  d <- as_survey_nonprob(
    df,
    weights = wt,
    repweights = c(r1, r2, r3, r4),
    type = "JKn",
    rscales = rep(0.75, 4)
  )
  output <- capture.output(summary(d), type = "message")
  expect_true(any(grepl("JKn", output)))
})

test_that("summary(survey_nonprob): bootstrap type line contains 'bootstrap' [regression guard]", {
  df <- .make_nonprob_repwt_df(n = 10, R = 4)
  d <- as_survey_nonprob(
    df,
    weights = wt,
    repweights = c(r1, r2, r3, r4),
    type = "bootstrap"
  )
  output <- capture.output(summary(d), type = "message")
  expect_true(any(grepl("bootstrap", output)))
})

test_that("summary(survey_nonprob): SRS type line does not contain 'JK' or 'BOOTSTRAP'", {
  df <- data.frame(y = 1:10, wt = rep(1, 10))
  d <- as_survey_nonprob(df, weights = wt)
  output <- capture.output(summary(d), type = "message")
  expect_false(any(grepl("JK", output)))
  expect_false(any(grepl("BOOTSTRAP", output)))
})

test_that("summary(survey_nonprob): JK1 snapshot", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  df <- .make_nonprob_repwt_df(n = 10, R = 4)
  d <- as_survey_nonprob(
    df,
    weights = wt,
    repweights = c(r1, r2, r3, r4),
    type = "JK1"
  )
  expect_snapshot(summary(d))
})

test_that("summary(survey_nonprob): JK2 snapshot", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  df <- .make_nonprob_repwt_df(n = 10, R = 4)
  d <- as_survey_nonprob(
    df,
    weights = wt,
    repweights = c(r1, r2, r3, r4),
    type = "JK2",
    rscales = rep(0.75, 4)
  )
  expect_snapshot(summary(d))
})

test_that("summary(survey_nonprob): JKn snapshot", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  df <- .make_nonprob_repwt_df(n = 10, R = 4)
  d <- as_survey_nonprob(
    df,
    weights = wt,
    repweights = c(r1, r2, r3, r4),
    type = "JKn",
    rscales = rep(0.75, 4)
  )
  expect_snapshot(summary(d))
})

test_that("summary(survey_nonprob): bootstrap snapshot [regression guard]", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  df <- .make_nonprob_repwt_df(n = 10, R = 4)
  d <- as_survey_nonprob(
    df,
    weights = wt,
    repweights = c(r1, r2, r3, r4),
    type = "bootstrap"
  )
  expect_snapshot(summary(d))
})


# ── Dataset-level metadata: shared capture helper ───────────────────────────
#
# Capture cli output (message stream) and tibble output (stdout) from one
# print or summary call, keeping the two streams apart so a test can compare
# cli lines exactly.
capture_design_output <- function(expr) {
  cli_lines <- character(0L)
  data_lines <- utils::capture.output(
    cli_lines <- utils::capture.output(force(expr), type = "message")
  )
  list(cli = cli_lines, data = data_lines)
}


# ── 50. Dataset header line — survey_taylor (spec section X.1) ──────────────

test_that("print.survey_taylor shows a Dataset line holding data_name", {
  d <- make_dataset_design("taylor", "data_name")
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d))$cli
  expect_identical(
    out[grepl("^Dataset: ", out)],
    "Dataset: AAA Ipsos (February-March 2026)"
  )
})

test_that("print.survey_taylor Dataset line sits directly above Sample size", {
  d <- make_dataset_design("taylor", "data_name")
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d))$cli
  idx <- grep("^Dataset: ", out)
  expect_length(idx, 1L)
  expect_true(grepl("^<survey_taylor>", out[[idx - 1L]]))
  expect_true(grepl("^Sample size: ", out[[idx + 1L]]))
})

test_that("print.survey_taylor Dataset line falls back to survey_name", {
  d <- make_dataset_design("taylor", "survey_name")
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d))$cli
  expect_identical(
    out[grepl("^Dataset: ", out)],
    "Dataset: Antisemitic Attitudes in America 2026"
  )
})

test_that("print.survey_taylor Dataset line prefers data_name to survey_name", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d))$cli
  expect_identical(
    out[grepl("^Dataset: ", out)],
    "Dataset: AAA Ipsos (February-March 2026)"
  )
})

test_that("print.survey_taylor omits the Dataset line when nothing is set", {
  d_none <- make_dataset_design("taylor", "none")
  d_named <- make_dataset_design("taylor", "data_name")
  test_invariants(d_none)
  withr::local_options(list(width = 80L, cli.width = 80L))

  none_out <- capture_design_output(print(d_none))
  named_out <- capture_design_output(print(d_named))

  # No Dataset line, and no other change: dropping the one line the named
  # design prints reproduces the unset design's output exactly. This fails if
  # the header emits a blank line, an empty "Dataset: " line, or any other
  # line when the metadata list is empty.
  expect_false(any(grepl("^Dataset: ", none_out$cli)))
  expect_identical(
    named_out$cli[!grepl("^Dataset: ", named_out$cli)],
    none_out$cli
  )
  expect_identical(named_out$data, none_out$data)
  # Positive control: the named design really printed a Dataset line, so the
  # negative assertion above is informative and not vacuous.
  expect_length(grep("^Dataset: ", named_out$cli), 1L)
})


# ── 51. Dataset header line — remaining classes (spec section X.1) ──────────

test_that("print.survey_replicate shows a Dataset line above Sample size", {
  d <- make_dataset_design("replicate", "data_name")
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d))$cli
  idx <- grep("^Dataset: ", out)
  expect_length(idx, 1L)
  expect_identical(out[[idx]], "Dataset: AAA Ipsos (February-March 2026)")
  expect_true(grepl("^<survey_replicate>", out[[idx - 1L]]))
  expect_true(grepl("^Sample size: ", out[[idx + 1L]]))
})

test_that("print.survey_twophase shows a Dataset line above Phase 1 sample size", {
  d <- make_dataset_design("twophase", "data_name")
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d))$cli
  idx <- grep("^Dataset: ", out)
  expect_length(idx, 1L)
  expect_identical(out[[idx]], "Dataset: AAA Ipsos (February-March 2026)")
  expect_true(grepl("^<survey_twophase>", out[[idx - 1L]]))
  expect_true(grepl("^Phase 1 sample size: ", out[[idx + 1L]]))
})

test_that("print.survey_nonprob puts the Dataset line after the variance bullet", {
  d <- make_dataset_design("nonprob", "data_name")
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d))$cli
  idx <- grep("^Dataset: ", out)
  expect_length(idx, 1L)
  expect_identical(out[[idx]], "Dataset: AAA Ipsos (February-March 2026)")
  # The no-repweights branch carries a variance bullet; the Dataset line goes
  # below it and directly above Sample size.
  expect_true(grepl("Variance: SRS approximation", out[[idx - 1L]]))
  expect_true(grepl("^Sample size: ", out[[idx + 1L]]))
})

test_that("print.survey_nonprob with repweights puts Dataset after the class line", {
  d <- make_dataset_design("nonprob_rep", "data_name")
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d))$cli
  idx <- grep("^Dataset: ", out)
  expect_length(idx, 1L)
  expect_identical(out[[idx]], "Dataset: AAA Ipsos (February-March 2026)")
  # This branch has no variance bullet, so the class line is the line above.
  expect_false(any(grepl("Variance: SRS approximation", out)))
  expect_true(grepl("^<survey_nonprob>", out[[idx - 1L]]))
  expect_true(grepl("^Sample size: ", out[[idx + 1L]]))
})

test_that("print falls back to survey_name in every design class", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  designs <- c("replicate", "twophase", "nonprob", "nonprob_rep")

  for (design in designs) {
    d <- make_dataset_design(design, "survey_name")
    test_invariants(d)
    out <- capture_design_output(print(d))$cli
    expect_identical(
      out[grepl("^Dataset: ", out)],
      "Dataset: Antisemitic Attitudes in America 2026",
      info = design
    )
  }
})

test_that("print output is unchanged in every class when nothing is set", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  designs <- c("replicate", "twophase", "nonprob", "nonprob_rep")

  for (design in designs) {
    d_none <- make_dataset_design(design, "none")
    d_named <- make_dataset_design(design, "data_name")
    test_invariants(d_none)

    none_out <- capture_design_output(print(d_none))
    named_out <- capture_design_output(print(d_named))

    expect_false(any(grepl("^Dataset: ", none_out$cli)), info = design)
    # Dropping the single added line reproduces the unset output exactly.
    expect_identical(
      named_out$cli[!grepl("^Dataset: ", named_out$cli)],
      none_out$cli,
      info = design
    )
    expect_identical(named_out$data, none_out$data, info = design)
    # Positive control: the named design did print one Dataset line.
    expect_length(grep("^Dataset: ", named_out$cli), 1L)
  }
})
