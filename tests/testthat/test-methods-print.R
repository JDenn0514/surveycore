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


# ── 52. Dataset metadata block (spec section X.2) ───────────────────────────

test_that("metadata_info block shows Survey, Vendor and Field dates in order", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d, metadata_info = TRUE))$cli
  block <- out[grepl("^(Survey|Vendor|Field dates|[0-9]+ variable)", out)]
  expect_identical(
    block,
    c(
      "Survey: Antisemitic Attitudes in America 2026",
      "Vendor: Ipsos KnowledgePanel Omnibus",
      "Field dates: 2026-02-10 to 2026-03-04 (February-March 2026)",
      "0 variable(s) labeled"
    )
  )
})

test_that("metadata_info block sits above the labeled-count line", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d, metadata_info = TRUE))$cli
  expect_true(grep("^Survey: ", out) < grep("variable\\(s\\) labeled", out))
  expect_true(grep("^Vendor: ", out) < grep("variable\\(s\\) labeled", out))
  expect_true(
    grep("^Field dates: ", out) < grep("variable\\(s\\) labeled", out)
  )
  # And below the Metadata heading, so the block is inside that section.
  expect_true(grep("^-- Metadata", out) < grep("^Survey: ", out))
})

test_that("metadata_info block omits Survey when only survey_name is set", {
  d <- make_dataset_design("taylor", "survey_name")
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d, metadata_info = TRUE))$cli
  # The header already printed the string, so it must not appear again.
  expect_length(grep("Antisemitic Attitudes in America 2026", out), 1L)
  expect_false(any(grepl("^Survey: ", out)))
  expect_true(any(grepl("^Dataset: ", out)))
})

test_that("metadata_info block omits Survey when the two names are identical", {
  d <- make_dataset_design("taylor", "none")
  d <- set_dataset_metadata(
    d,
    survey_name = "Shared Name 2026",
    data_name = "Shared Name 2026"
  )
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d, metadata_info = TRUE))$cli
  expect_false(any(grepl("^Survey: ", out)))
  # One string, one line — never two.
  expect_length(grep("Shared Name 2026", out), 1L)
  expect_identical(out[grepl("^Dataset: ", out)], "Dataset: Shared Name 2026")
})

test_that("metadata_info block shows Survey when the two names differ", {
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d, metadata_info = TRUE))$cli
  expect_identical(
    out[grepl("^Dataset: ", out)],
    "Dataset: AAA Ipsos (February-March 2026)"
  )
  expect_identical(
    out[grepl("^Survey: ", out)],
    "Survey: Antisemitic Attitudes in America 2026"
  )
})

test_that("metadata_info block shows a one-sided range for a single start date", {
  d <- make_dataset_design("taylor", "partial")
  test_invariants(d)
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d, metadata_info = TRUE))$cli
  expect_identical(
    out[grepl("^Field dates: ", out)],
    "Field dates: 2026-02-10 to ? (February-March 2026)"
  )
  expect_identical(out[grepl("^Vendor: ", out)], "Vendor: Ipsos KnowledgePanel Omnibus")
  # partial has no survey_name, so no Survey line.
  expect_false(any(grepl("^Survey: ", out)))
})

test_that("metadata_info block shows a one-sided range for a single end date", {
  d <- make_dataset_design("taylor", "none")
  d <- set_dataset_metadata(d, field_end = as.Date("2026-03-04"))
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d, metadata_info = TRUE))$cli
  expect_identical(
    out[grepl("^Field dates: ", out)],
    "Field dates: ? to 2026-03-04"
  )
})

test_that("metadata_info block shows a plain range when no period is set", {
  d <- make_dataset_design("taylor", "none")
  d <- set_dataset_metadata(
    d,
    field_start = as.Date("2026-02-10"),
    field_end = as.Date("2026-03-04")
  )
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d, metadata_info = TRUE))$cli
  expect_identical(
    out[grepl("^Field dates: ", out)],
    "Field dates: 2026-02-10 to 2026-03-04"
  )
})

test_that("metadata_info block shows the period alone when no dates are set", {
  d <- make_dataset_design("taylor", "none")
  d <- set_dataset_metadata(d, field_period = "February-March 2026")
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d, metadata_info = TRUE))$cli
  expect_identical(
    out[grepl("^Field dates: ", out)],
    "Field dates: February-March 2026"
  )
})

test_that("metadata_info block omits Field dates when no date key is set", {
  d <- make_dataset_design("taylor", "none")
  d <- set_dataset_metadata(d, vendor = "Ipsos KnowledgePanel Omnibus")
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d, metadata_info = TRUE))$cli
  expect_false(any(grepl("^Field dates: ", out)))
  # Positive control: the block itself did render.
  expect_true(any(grepl("^Vendor: ", out)))
})

test_that("metadata_info section is unchanged when no dataset metadata is set", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  designs <- c("taylor", "replicate", "twophase", "nonprob", "nonprob_rep")

  for (design in designs) {
    d_none <- make_dataset_design(design, "none")
    d_full <- make_dataset_design(design, "full")
    test_invariants(d_none)

    none_out <- capture_design_output(print(d_none, metadata_info = TRUE))
    full_out <- capture_design_output(print(d_full, metadata_info = TRUE))

    expect_false(
      any(grepl("^(Dataset|Survey|Vendor|Field dates): ", none_out$cli)),
      info = design
    )
    # Dropping the four added lines reproduces the unset output exactly, so
    # no blank line or spacing change slipped in with the block.
    added <- grepl("^(Dataset|Survey|Vendor|Field dates): ", full_out$cli)
    expect_identical(full_out$cli[!added], none_out$cli, info = design)
    # Positive control: the full design printed all four lines.
    expect_identical(sum(added), 4L, info = design)
  }
})

test_that("full = TRUE shows the header and the block in every design class", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  designs <- c("taylor", "replicate", "twophase", "nonprob", "nonprob_rep")

  for (design in designs) {
    d <- make_dataset_design(design, "full")
    test_invariants(d)
    out <- capture_design_output(print(d, full = TRUE))$cli

    expect_identical(
      out[grepl("^Dataset: ", out)],
      "Dataset: AAA Ipsos (February-March 2026)",
      info = design
    )
    expect_identical(
      out[grepl("^Survey: ", out)],
      "Survey: Antisemitic Attitudes in America 2026",
      info = design
    )
    expect_identical(
      out[grepl("^Vendor: ", out)],
      "Vendor: Ipsos KnowledgePanel Omnibus",
      info = design
    )
    expect_identical(
      out[grepl("^Field dates: ", out)],
      "Field dates: 2026-02-10 to 2026-03-04 (February-March 2026)",
      info = design
    )
  }
})

test_that("full = TRUE matches metadata_info = TRUE for the dataset lines", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  designs <- c("taylor", "replicate", "twophase", "nonprob", "nonprob_rep")
  pattern <- "^(Dataset|Survey|Vendor|Field dates): "

  for (design in designs) {
    d <- make_dataset_design(design, "full")
    test_invariants(d)
    full_out <- capture_design_output(print(d, full = TRUE))$cli
    meta_out <- capture_design_output(print(d, metadata_info = TRUE))$cli
    expect_identical(
      full_out[grepl(pattern, full_out)],
      meta_out[grepl(pattern, meta_out)],
      info = design
    )
    # Positive control: there are four such lines, not zero.
    expect_length(grep(pattern, full_out), 4L)
  }
})

test_that("full = TRUE leaves output unchanged when nothing is set", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  designs <- c("taylor", "replicate", "twophase", "nonprob", "nonprob_rep")
  pattern <- "^(Dataset|Survey|Vendor|Field dates): "

  for (design in designs) {
    d_none <- make_dataset_design(design, "none")
    d_full <- make_dataset_design(design, "full")
    test_invariants(d_none)

    none_out <- capture_design_output(print(d_none, full = TRUE))
    full_out <- capture_design_output(print(d_full, full = TRUE))

    expect_false(any(grepl(pattern, none_out$cli)), info = design)
    expect_identical(
      full_out$cli[!grepl(pattern, full_out$cli)],
      none_out$cli,
      info = design
    )
    expect_identical(full_out$data, none_out$data, info = design)
  }
})

# ── 56. Stale (pre-1.2.0) objects (spec section IV) ─────────────────────────

test_that("a stale design prints and summarises with every argument combination", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  dataset_line <- "^(Dataset|Survey|Vendor|Field dates): "

  for (cls in c("taylor", "replicate", "twophase", "nonprob")) {
    d <- make_stale_metadata_design(cls)
    test_invariants(d)

    # Four calls per class: the default, the two metadata-bearing argument
    # combinations, and summary(). All read through the guarded reader, so
    # S7's "Can't find property" error never surfaces.
    expect_no_error(default_out <- capture_design_output(print(d, n = 3)))
    expect_no_error(
      meta_out <- capture_design_output(print(d, metadata_info = TRUE, n = 3))
    )
    expect_no_error(
      full_out <- capture_design_output(print(d, full = TRUE, n = 3))
    )
    expect_no_error(summary_out <- capture_design_output(summary(d)))

    expect_false(any(grepl(dataset_line, default_out$cli)), info = cls)
    expect_false(any(grepl(dataset_line, meta_out$cli)), info = cls)
    expect_false(any(grepl(dataset_line, full_out$cli)), info = cls)
    expect_false(any(grepl(dataset_line, summary_out$cli)), info = cls)

    # Positive control: the calls really did produce output, so the four
    # negatives above are not passing on empty vectors.
    expect_true(any(grepl("Survey Design", default_out$cli)), info = cls)
    expect_true(any(grepl("variable\\(s\\) labeled", meta_out$cli)), info = cls)
    expect_true(any(grepl("variable\\(s\\) labeled", full_out$cli)), info = cls)
    expect_true(
      any(grepl("^Metadata: ", summary_out$cli)),
      info = cls
    )
  }
})

test_that("a stale design prints the same lines as an empty current design", {
  withr::local_options(list(width = 80L, cli.width = 80L))

  # The stale taylor fixture and the "none" taylor fixture use the same seed
  # but different row counts, so compare the shape of the metadata section
  # rather than the whole output.
  stale <- make_stale_metadata_design("taylor")
  test_invariants(stale)
  out <- capture_design_output(print(stale, metadata_info = TRUE, n = 3))$cli
  meta_idx <- grep("^-- Metadata", out)
  expect_length(meta_idx, 1L)
  # The line directly below the heading is the blank cli_h2 spacer, and the
  # one below that is the labeled count — no dataset block in between.
  expect_identical(out[[meta_idx + 1L]], "")
  expect_true(grepl("variable\\(s\\) labeled", out[[meta_idx + 2L]]))
})


# ── 55. Print hardening (spec section X.5) ──────────────────────────────────

test_that("print renders braces in the header name literally", {
  hostile <- "{.val x} {1 + 1} {unknown_var}"
  d <- make_dataset_design("taylor", "none")
  d <- set_dataset_metadata(d, data_name = hostile)
  withr::local_options(list(width = 80L, cli.width = 80L))

  expect_no_error(out <- capture_design_output(print(d))$cli)
  expect_identical(out[grepl("^Dataset: ", out)], paste0("Dataset: ", hostile))
})

test_that("print renders braces in the block values literally", {
  hostile_survey <- "{.val survey} {stop('boom')}"
  hostile_vendor <- "{vendor_var}"
  hostile_period <- "{format(Sys.Date())}"
  d <- make_dataset_design("taylor", "none")
  d <- set_dataset_metadata(
    d,
    survey_name = hostile_survey,
    data_name = "A Data Name",
    vendor = hostile_vendor,
    field_period = hostile_period
  )
  withr::local_options(list(width = 80L, cli.width = 80L))

  expect_no_error(
    out <- capture_design_output(print(d, metadata_info = TRUE))$cli
  )
  expect_identical(
    out[grepl("^Survey: ", out)],
    paste0("Survey: ", hostile_survey)
  )
  expect_identical(
    out[grepl("^Vendor: ", out)],
    paste0("Vendor: ", hostile_vendor)
  )
  expect_identical(
    out[grepl("^Field dates: ", out)],
    paste0("Field dates: ", hostile_period)
  )
})

test_that("print replaces newline, carriage return and tab in the header name", {
  d <- make_dataset_design("taylor", "none")
  d <- set_dataset_metadata(d, data_name = "AAA\nIpsos\rOmnibus\t2026")
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d))$cli
  line <- out[grepl("^Dataset: ", out)]
  expect_identical(line, "Dataset: AAA Ipsos Omnibus 2026")
  expect_false(any(grepl("[\n\r\t]", line)))
})

test_that("print replaces newline, carriage return and tab in the block values", {
  d <- make_dataset_design("taylor", "none")
  d <- set_dataset_metadata(
    d,
    survey_name = "Survey\nName",
    data_name = "A Data Name",
    vendor = "Ipsos\tKnowledgePanel",
    field_period = "February\r2026"
  )
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d, metadata_info = TRUE))$cli
  expect_identical(out[grepl("^Survey: ", out)], "Survey: Survey Name")
  expect_identical(
    out[grepl("^Vendor: ", out)],
    "Vendor: Ipsos KnowledgePanel"
  )
  expect_identical(
    out[grepl("^Field dates: ", out)],
    "Field dates: February 2026"
  )
})

test_that("print truncates a header name longer than 60 characters", {
  long_name <- strrep("a", 70L)
  d <- make_dataset_design("taylor", "none")
  d <- set_dataset_metadata(d, data_name = long_name)
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d))$cli
  line <- out[grepl("^Dataset: ", out)]
  expect_identical(line, paste0("Dataset: ", strrep("a", 57L), "..."))
  expect_identical(nchar(sub("^Dataset: ", "", line)), 60L)
})

test_that("print keeps a header name of exactly 60 characters whole", {
  exact_name <- strrep("b", 60L)
  d <- make_dataset_design("taylor", "none")
  d <- set_dataset_metadata(d, data_name = exact_name)
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d))$cli
  expect_identical(out[grepl("^Dataset: ", out)], paste0("Dataset: ", exact_name))
})

test_that("print truncates a header name of exactly 61 characters", {
  over_name <- strrep("c", 61L)
  d <- make_dataset_design("taylor", "none")
  d <- set_dataset_metadata(d, data_name = over_name)
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d))$cli
  expect_identical(
    out[grepl("^Dataset: ", out)],
    paste0("Dataset: ", strrep("c", 57L), "...")
  )
})

test_that("print truncates each block value independently", {
  d <- make_dataset_design("taylor", "none")
  d <- set_dataset_metadata(
    d,
    survey_name = strrep("s", 70L),
    data_name = "A Data Name",
    vendor = strrep("v", 70L),
    field_period = strrep("p", 70L)
  )
  withr::local_options(list(width = 80L, cli.width = 80L))

  out <- capture_design_output(print(d, metadata_info = TRUE))$cli
  expect_identical(
    out[grepl("^Survey: ", out)],
    paste0("Survey: ", strrep("s", 57L), "...")
  )
  expect_identical(
    out[grepl("^Vendor: ", out)],
    paste0("Vendor: ", strrep("v", 57L), "...")
  )
  expect_identical(
    out[grepl("^Field dates: ", out)],
    paste0("Field dates: ", strrep("p", 57L), "...")
  )
})

test_that("summary renders a hostile header name without aborting", {
  hostile <- paste0("{.val x}\t", strrep("z", 70L))
  d <- make_dataset_design("taylor", "none")
  d <- set_dataset_metadata(d, data_name = hostile)
  withr::local_options(list(width = 80L, cli.width = 80L))

  expect_no_error(out <- capture_design_output(summary(d))$cli)
  line <- out[grepl("^Dataset: ", out)]
  expect_identical(
    line,
    paste0("Dataset: ", substr(paste0("{.val x} ", strrep("z", 70L)), 1L, 57L), "...")
  )
})


# ── 54. Dataset line in the summary methods (spec section X.4) ──────────────

test_that("summary shows the Dataset line directly above the Metadata line", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  designs <- c("taylor", "replicate", "twophase", "nonprob", "nonprob_rep")

  for (design in designs) {
    d <- make_dataset_design(design, "data_name")
    test_invariants(d)
    out <- capture_design_output(summary(d))$cli

    idx <- grep("^Dataset: ", out)
    expect_length(idx, 1L)
    expect_identical(
      out[[idx]],
      "Dataset: AAA Ipsos (February-March 2026)",
      info = design
    )
    expect_true(grepl("^Metadata: ", out[[idx + 1L]]), info = design)
    # The blank line that already preceded the Metadata line stays above it.
    expect_identical(out[[idx - 1L]], "", info = design)
  }
})

test_that("summary falls back to survey_name", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  designs <- c("taylor", "replicate", "twophase", "nonprob", "nonprob_rep")

  for (design in designs) {
    d <- make_dataset_design(design, "survey_name")
    test_invariants(d)
    out <- capture_design_output(summary(d))$cli
    expect_identical(
      out[grepl("^Dataset: ", out)],
      "Dataset: Antisemitic Attitudes in America 2026",
      info = design
    )
  }
})

test_that("summary output is unchanged when no dataset metadata is set", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  designs <- c("taylor", "replicate", "twophase", "nonprob", "nonprob_rep")

  for (design in designs) {
    d_none <- make_dataset_design(design, "none")
    d_named <- make_dataset_design(design, "data_name")
    test_invariants(d_none)

    none_out <- capture_design_output(summary(d_none))
    named_out <- capture_design_output(summary(d_named))

    expect_false(any(grepl("^Dataset: ", none_out$cli)), info = design)
    expect_identical(
      named_out$cli[!grepl("^Dataset: ", named_out$cli)],
      none_out$cli,
      info = design
    )
    # Positive control: the named design printed exactly one Dataset line.
    expect_length(grep("^Dataset: ", named_out$cli), 1L)
  }
})

test_that("summary shows no Survey, Vendor or Field dates lines", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)

  out <- capture_design_output(summary(d))$cli
  # Only the one name line belongs in a summary (spec section X.4).
  expect_false(any(grepl("^(Survey|Vendor|Field dates): ", out)))
  expect_length(grep("^Dataset: ", out), 1L)
})

test_that("summary(survey_taylor): Dataset line snapshot", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_dataset_design("taylor", "data_name")
  test_invariants(d)
  expect_snapshot(summary(d))
})


# ── 53. Verbatim console contract (spec section X.3) ────────────────────────

test_that("print(survey_taylor, metadata_info = TRUE): all six keys snapshot", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_dataset_design("taylor", "full")
  test_invariants(d)
  expect_snapshot(print(d, metadata_info = TRUE, n = 3))
})

test_that("print(survey_taylor, metadata_info = TRUE): period-only snapshot", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_dataset_design("taylor", "data_name")
  d <- set_dataset_metadata(d, field_period = "February-March 2026")
  expect_snapshot(print(d, metadata_info = TRUE, n = 3))
})

test_that("print(survey_taylor): survey_name fallback header snapshot", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_dataset_design("taylor", "survey_name")
  test_invariants(d)
  expect_snapshot(print(d, n = 3))
})

test_that("print(survey_replicate): Dataset header snapshot", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_dataset_design("replicate", "data_name")
  test_invariants(d)
  expect_snapshot(print(d, n = 3))
})

test_that("print(survey_twophase): Dataset header snapshot", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_dataset_design("twophase", "data_name")
  test_invariants(d)
  expect_snapshot(print(d, n = 3))
})

test_that("print(survey_nonprob): Dataset header snapshot", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_dataset_design("nonprob", "data_name")
  test_invariants(d)
  expect_snapshot(print(d, n = 3))
})

test_that("print(survey_nonprob) with repweights: Dataset header snapshot", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  d <- make_dataset_design("nonprob_rep", "data_name")
  test_invariants(d)
  expect_snapshot(print(d, n = 3))
})


test_that("metadata_info block renders in every design class", {
  withr::local_options(list(width = 80L, cli.width = 80L))
  designs <- c("replicate", "twophase", "nonprob", "nonprob_rep")

  for (design in designs) {
    d <- make_dataset_design(design, "full")
    test_invariants(d)
    out <- capture_design_output(print(d, metadata_info = TRUE))$cli
    expect_true(
      any(out == "Survey: Antisemitic Attitudes in America 2026"),
      info = design
    )
    expect_true(
      any(out == "Vendor: Ipsos KnowledgePanel Omnibus"),
      info = design
    )
    expect_true(
      any(
        out == "Field dates: 2026-02-10 to 2026-03-04 (February-March 2026)"
      ),
      info = design
    )
  }
})
