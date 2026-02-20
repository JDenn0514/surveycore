# tests/testthat/test-constructors.R
#
# Tests for R/03-constructors.R — as_survey(), as_survey_rep(),
# and as_survey_twophase().
#
# Coverage (per plans/error-messages.md):
#   Rows 1–15: as_survey() errors and warnings
#   Rows 1–4, 8–10, 16–18: as_survey_rep() errors and warnings
#   Rows 19–25: as_survey_twophase() errors and warnings
#
# Test structure (per .claude/rules/testing-standards.md):
#   1. Happy paths  (one block per design type)
#   2. Error paths  (one block per error-messages.md row)
#   3. Edge cases   (boundary conditions)
#   4. Tidy-select  (bare names, c(), helpers)


# ── Happy paths ───────────────────────────────────────────────────────────────

test_that("as_survey() creates survey_taylor for simple random sample (no args)", {
  df <- make_survey_data(n = 100, seed = 1L)
  d  <- suppressWarnings(as_survey(df))  # SRS warning expected
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_taylor))
  expect_identical(d@variables$ids, NULL)
  expect_identical(d@variables$strata, NULL)
  expect_identical(d@variables$weights, "..surveycore_wt..")
  expect_false(d@variables$probs_provided)
})

test_that("as_survey() creates survey_taylor for weighted SRS (weights only)", {
  df <- make_survey_data(n = 100, seed = 1L)
  d  <- as_survey(df, weights = wt)
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_taylor))
  expect_identical(d@variables$weights, "wt")
  expect_identical(d@variables$ids, NULL)
  expect_false(d@variables$probs_provided)
})

test_that("as_survey() creates survey_taylor for stratified design", {
  df <- make_survey_data(n = 200, seed = 2L)
  d  <- as_survey(df, weights = wt, strata = strata)
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_taylor))
  expect_identical(d@variables$weights, "wt")
  expect_identical(d@variables$strata, "strata")
  expect_identical(d@variables$ids, NULL)
})

test_that("as_survey() creates survey_taylor for single-stage cluster design", {
  df <- make_survey_data(n = 200, seed = 3L)
  d  <- suppressWarnings(as_survey(df, ids = psu, weights = wt, strata = strata))
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_taylor))
  expect_identical(d@variables$ids, "psu")
  expect_identical(d@variables$weights, "wt")
  expect_identical(d@variables$strata, "strata")
  expect_false(d@variables$nest)
})

test_that("as_survey() creates survey_taylor for NHANES design (nest = TRUE)", {
  # Filter to MEC-examined respondents: wtmec2yr is 0 for interview-only
  # participants (ridstatr == 1); as_survey() rejects non-positive weights.
  nhanes_mec <- nhanes_2017[nhanes_2017$ridstatr == 2L, ]
  d <- as_survey(
    nhanes_mec,
    ids     = sdmvpsu,
    weights = wtmec2yr,
    strata  = sdmvstra,
    nest    = TRUE
  )
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_taylor))
  expect_identical(d@variables$ids, "sdmvpsu")
  expect_identical(d@variables$weights, "wtmec2yr")
  expect_identical(d@variables$strata, "sdmvstra")
  expect_true(d@variables$nest)
})

test_that("as_survey() stores call in @call", {
  df <- make_survey_data(n = 50, seed = 4L)
  d  <- as_survey(df, weights = wt)
  expect_false(is.null(d@call))
  expect_true(is.call(d@call))
})

test_that("as_survey() extracts haven metadata when present", {
  df <- make_survey_data(n = 100, with_labels = TRUE, seed = 5L)
  d  <- as_survey(df, weights = wt)
  test_invariants(d)
  expect_identical(d@metadata@variable_labels[["y1"]], "Outcome variable 1 (continuous)")
  expect_identical(d@metadata@value_labels[["y3"]], c("No" = 0L, "Yes" = 1L))
})

test_that("as_survey() returns an empty metadata object when no haven attrs", {
  df <- make_survey_data(n = 50, seed = 6L)
  d  <- as_survey(df, weights = wt)
  test_invariants(d)
  expect_identical(length(d@metadata@variable_labels), 0L)
})


# ── Probs argument ─────────────────────────────────────────────────────────────

test_that("as_survey() converts probs to weights (1/probs) stored as ..surveycore_wt..", {
  df      <- data.frame(y = 1:5, prob = rep(0.2, 5))
  d       <- as_survey(df, probs = prob)
  test_invariants(d)
  expect_identical(d@variables$weights, "..surveycore_wt..")
  expect_true(d@variables$probs_provided)
  expect_equal(d@data[["..surveycore_wt.."]], rep(5, 5))
})

test_that("as_survey() uses weights when both probs and weights are consistent", {
  df <- data.frame(
    y    = 1:5,
    prob = rep(0.2, 5),
    wt   = rep(5, 5)   # consistent: 1/0.2 = 5
  )
  expect_message(
    {
      d <- as_survey(df, probs = prob, weights = wt)
    },
    regexp = "consistent"
  )
  test_invariants(d)
  expect_identical(d@variables$weights, "wt")
  expect_true(d@variables$probs_provided)
})

test_that("as_survey() stores fpc column name in @variables", {
  df <- make_survey_data(n = 100, seed = 7L)
  d  <- as_survey(df, weights = wt, fpc = fpc)
  test_invariants(d)
  expect_identical(d@variables$fpc, "fpc")
})


# ── Error paths ───────────────────────────────────────────────────────────────

# Row 1: data not a data frame
test_that("as_survey() errors when data is not a data frame [row 1]", {
  expect_error(
    as_survey(list(x = 1:5), weights = x),
    class = "surveycore_error_not_data_frame"
  )
  expect_snapshot(error = TRUE, as_survey(list(x = 1:5), weights = x))
})

test_that("as_survey() errors when data is a matrix [row 1]", {
  expect_error(
    as_survey(matrix(1:6, nrow = 3)),
    class = "surveycore_error_not_data_frame"
  )
})

# Row 2: data has 0 rows
test_that("as_survey() errors when data has 0 rows [row 2]", {
  empty_df <- data.frame(x = numeric(0), w = numeric(0))
  expect_error(
    as_survey(empty_df, weights = w),
    class = "surveycore_error_empty_data"
  )
  expect_snapshot(error = TRUE, as_survey(empty_df, weights = w))
})

# Row 3: duplicate column names
test_that("as_survey() errors when data has duplicate column names [row 3]", {
  df <- data.frame(x = 1:3, y = 4:6)
  names(df) <- c("x", "x")   # force duplicate
  expect_error(
    as_survey(df, weights = x),
    class = "surveycore_error_duplicate_names"
  )
  expect_snapshot(
    error = TRUE,
    {
      df2       <- data.frame(x = 1:3, y = 4:6)
      names(df2) <- c("x", "x")
      as_survey(df2, weights = x)
    }
  )
})

# Row 4: data has 1 row (warning, not error)
test_that("as_survey() warns when data has 1 row [row 4]", {
  single_row <- data.frame(x = 42, w = 1)
  expect_warning(
    as_survey(single_row, weights = w),
    class = "surveycore_warning_single_row"
  )
})

test_that("as_survey() still returns a valid object after single-row warning [row 4]", {
  single_row <- data.frame(x = 42, w = 1)
  d <- suppressWarnings(as_survey(single_row, weights = w))
  expect_true(S7::S7_inherits(d, survey_taylor))
})

# Row 5: probs and weights inconsistent
test_that("as_survey() errors when probs and weights are inconsistent [row 5]", {
  df <- data.frame(
    y    = 1:5,
    prob = rep(0.2, 5),   # implies weight = 5
    wt   = rep(3, 5)      # inconsistent
  )
  expect_error(
    as_survey(df, probs = prob, weights = wt),
    class = "surveycore_error_probs_weights_conflict"
  )
  expect_snapshot(error = TRUE, as_survey(df, probs = prob, weights = wt))
})

# Row 7: SRS warning (no weights/probs/ids)
test_that("as_survey() warns for SRS (no weights, probs, or ids) [row 7]", {
  df <- data.frame(y = 1:10, x = rnorm(10))
  expect_warning(
    as_survey(df),
    class = "surveycore_warning_srs_no_weights"
  )
})

test_that("as_survey() creates equal weights (..surveycore_wt..) for SRS [row 7]", {
  df <- data.frame(y = 1:10)
  d  <- suppressWarnings(as_survey(df))
  test_invariants(d)
  expect_identical(d@data[["..surveycore_wt.."]], rep(1L, 10L))
})

# Row 8: weights selects 0 columns
test_that("as_survey() errors when weights helper matches no columns [row 8]", {
  df <- data.frame(y = 1:5, wt = 1:5)
  expect_error(
    as_survey(df, weights = starts_with("zzz")),
    class = "surveycore_error_weights_not_found"
  )
  expect_snapshot(
    error = TRUE,
    as_survey(df, weights = starts_with("zzz"))
  )
})

# Row 9: weights selects >1 column
test_that("as_survey() errors when weights expression selects multiple columns [row 9]", {
  df <- data.frame(y = 1:5, wt1 = 1:5, wt2 = 1:5)
  expect_error(
    as_survey(df, weights = starts_with("wt")),
    class = "surveycore_error_weights_multiple"
  )
  expect_snapshot(
    error = TRUE,
    as_survey(df, weights = starts_with("wt"))
  )
})

# Row 10: weights all zero
test_that("as_survey() errors when all weights are zero [row 10]", {
  df <- data.frame(x = 1:5, wt = c(0, 0, 0, 0, 0))
  expect_error(
    as_survey(df, weights = wt),
    class = "surveycore_error_weights_all_zero"
  )
})

test_that("as_survey() errors when all weights are NA [row 10]", {
  df <- data.frame(x = 1:5, wt = rep(NA_real_, 5))
  expect_error(
    as_survey(df, weights = wt),
    class = "surveycore_error_weights_all_zero"
  )
})

# Row 11: strata selects >1 column
test_that("as_survey() errors when strata expression selects multiple columns [row 11]", {
  df <- data.frame(x = 1:5, st1 = c("A","B","A","B","A"), st2 = c("X","Y","X","Y","X"), wt = 1:5)
  expect_error(
    as_survey(df, weights = wt, strata = starts_with("st")),
    class = "surveycore_error_strata_multiple"
  )
  expect_snapshot(
    error = TRUE,
    as_survey(df, weights = wt, strata = starts_with("st"))
  )
})

# Row 12: strata has 1 unique value
test_that("as_survey() warns when strata has only one unique value [row 12]", {
  df <- data.frame(x = 1:10, st = rep("A", 10), wt = rep(1, 10))
  expect_warning(
    as_survey(df, weights = wt, strata = st),
    class = "surveycore_warning_single_stratum"
  )
})

# Row 13: fpc selects >1 column
test_that("as_survey() errors when fpc expression selects multiple columns [row 13]", {
  df <- data.frame(
    x    = 1:5,
    wt   = 1:5,
    fpc1 = rep(1000L, 5),
    fpc2 = rep(2000L, 5)
  )
  expect_error(
    as_survey(df, weights = wt, fpc = starts_with("fpc")),
    class = "surveycore_error_fpc_multiple"
  )
  expect_snapshot(
    error = TRUE,
    as_survey(df, weights = wt, fpc = starts_with("fpc"))
  )
})

# Row 14: fpc column contains NA
test_that("as_survey() errors when fpc column has NA values [row 14]", {
  df <- data.frame(
    x   = 1:5,
    wt  = 1:5,
    fpc = c(1000L, NA_integer_, 1000L, 1000L, 1000L)
  )
  expect_error(
    as_survey(df, weights = wt, fpc = fpc),
    class = "surveycore_error_fpc_na"
  )
  expect_snapshot(error = TRUE, as_survey(df, weights = wt, fpc = fpc))
})

# Row 15: nest = TRUE without strata
test_that("as_survey() errors when nest = TRUE and strata is NULL [row 15]", {
  df <- make_survey_data(n = 100, seed = 8L)
  expect_error(
    as_survey(df, ids = psu, weights = wt, nest = TRUE),
    class = "surveycore_error_nest_without_strata"
  )
  expect_snapshot(
    error = TRUE,
    as_survey(df, ids = psu, weights = wt, nest = TRUE)
  )
})


# ── Edge cases ────────────────────────────────────────────────────────────────

test_that("as_survey() handles weights with NA values mixed in (valid)", {
  df <- data.frame(x = 1:5, wt = c(1.0, NA_real_, 2.0, 1.5, NA_real_))
  d  <- as_survey(df, weights = wt)
  test_invariants(d)
  expect_identical(d@variables$weights, "wt")
})

test_that("as_survey() with tibble input (inherits data.frame)", {
  skip_if_not_installed("tibble")
  tb <- tibble::tibble(y = 1:10, wt = runif(10, 0.5, 2))
  d  <- as_survey(tb, weights = wt)
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_taylor))
})

test_that("as_survey() populates all expected @variables keys", {
  df  <- make_survey_data(n = 100, seed = 9L)
  d   <- as_survey(df, weights = wt)
  expected_keys <- c("ids", "weights", "strata", "fpc", "nest", "probs_provided")
  expect_true(all(expected_keys %in% names(d@variables)))
})

test_that("as_survey() sets NULL for unspecified design vars", {
  df <- data.frame(x = 1:5, wt = rep(1, 5))
  d  <- as_survey(df, weights = wt)
  expect_null(d@variables$ids)
  expect_null(d@variables$strata)
  expect_null(d@variables$fpc)
})

test_that("as_survey() warns for PSU appearing in multiple strata (not nest)", {
  # PSU 1 appears in both stratum A and B
  df <- data.frame(
    psu    = c(1, 1, 2, 2, 3, 3),
    strata = c("A", "B", "A", "A", "B", "B"),
    wt     = rep(1, 6)
  )
  expect_warning(
    as_survey(df, ids = psu, weights = wt, strata = strata),
    class = "surveycore_warning_psu_multi_strata"
  )
})

test_that("as_survey() does NOT warn for PSU in multiple strata when nest = TRUE", {
  # nest = TRUE suppresses the multi-strata PSU check
  df <- data.frame(
    psu    = c(1, 1, 2, 2),
    strata = c("A", "B", "A", "B"),
    wt     = rep(1, 4)
  )
  expect_no_warning(
    as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE),
    message = "surveycore_warning_psu_multi_strata"
  )
})


# ── Tidy-select interface ─────────────────────────────────────────────────────

test_that("as_survey() accepts bare name for weights", {
  df <- data.frame(y = 1:5, weight_col = rep(1, 5))
  d  <- as_survey(df, weights = weight_col)
  test_invariants(d)
  expect_identical(d@variables$weights, "weight_col")
})

test_that("as_survey() accepts bare name for strata", {
  df <- data.frame(y = 1:10, wt = rep(1, 10), region = rep(c("N", "S"), 5))
  d  <- as_survey(df, weights = wt, strata = region)
  test_invariants(d)
  expect_identical(d@variables$strata, "region")
})

test_that("as_survey() accepts c() for multi-stage cluster ids", {
  df <- data.frame(
    psu = rep(1:5, each = 4),
    ssu = rep(1:4, 5),
    wt  = rep(1, 20)
  )
  d <- as_survey(df, ids = c(psu, ssu), weights = wt)
  test_invariants(d)
  expect_identical(d@variables$ids, c("psu", "ssu"))
})

test_that("as_survey() accepts single bare name for ids", {
  df <- make_survey_data(n = 100, seed = 10L)
  d  <- suppressWarnings(as_survey(df, ids = psu, weights = wt, strata = strata))
  test_invariants(d)
  expect_identical(d@variables$ids, "psu")
})

test_that("as_survey() ids = NULL means SRS (no cluster)", {
  df <- data.frame(y = 1:10, wt = rep(1, 10))
  d  <- as_survey(df, weights = wt)
  expect_null(d@variables$ids)
})


# ==============================================================================
# as_survey_rep()
# ==============================================================================


# ── Happy paths ───────────────────────────────────────────────────────────────

test_that("as_survey_rep() creates survey_replicate for BRR design (starts_with)", {
  df <- make_survey_data(n = 200, n_psu = 20L, design = "replicate", seed = 1L)
  d  <- as_survey_rep(
    df,
    weights    = wt,
    repweights = starts_with("repwt_"),
    type       = "BRR"
  )
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_replicate))
  expect_identical(d@variables$weights, "wt")
  expect_identical(d@variables$type, "BRR")
  expect_true(length(d@variables$repweights) > 0L)
  expect_true(all(startsWith(d@variables$repweights, "repwt_")))
})

test_that("as_survey_rep() creates survey_replicate for JK1 design (bare names)", {
  df <- make_survey_data(n = 200, n_psu = 20L, design = "replicate", type = "jk1", seed = 2L)
  d  <- as_survey_rep(
    df,
    weights    = wt,
    repweights = starts_with("repwt_"),
    type       = "JK1"
  )
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_replicate))
  expect_identical(d@variables$type, "JK1")
})

test_that("as_survey_rep() creates survey_replicate for bootstrap design", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", type = "bootstrap", seed = 3L)
  d  <- as_survey_rep(
    df,
    weights    = wt,
    repweights = starts_with("repwt_"),
    type       = "bootstrap"
  )
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_replicate))
  expect_identical(d@variables$type, "bootstrap")
})

test_that("as_survey_rep() stores call in @call", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 4L)
  d  <- as_survey_rep(df, weights = wt, repweights = starts_with("repwt_"), type = "JK1")
  expect_false(is.null(d@call))
  expect_true(is.call(d@call))
})

test_that("as_survey_rep() extracts haven metadata when present", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", with_labels = TRUE, seed = 5L)
  d  <- as_survey_rep(df, weights = wt, repweights = starts_with("repwt_"), type = "JK1")
  test_invariants(d)
  expect_identical(d@metadata@variable_labels[["y1"]], "Outcome variable 1 (continuous)")
})

test_that("as_survey_rep() returns empty metadata when no haven attrs", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 6L)
  d  <- as_survey_rep(df, weights = wt, repweights = starts_with("repwt_"), type = "JK1")
  test_invariants(d)
  expect_identical(length(d@metadata@variable_labels), 0L)
})

test_that("as_survey_rep() accepts explicit rscales of correct length", {
  df    <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", type = "jk1", seed = 7L)
  n_rep <- sum(startsWith(names(df), "repwt_"))
  d     <- as_survey_rep(
    df,
    weights    = wt,
    repweights = starts_with("repwt_"),
    type       = "JK1",
    rscales    = rep(1, n_rep)
  )
  test_invariants(d)
  expect_identical(length(d@variables$rscales), n_rep)
})

test_that("as_survey_rep() accepts explicit scale argument", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 8L)
  d  <- as_survey_rep(
    df,
    weights    = wt,
    repweights = starts_with("repwt_"),
    type       = "JK1",
    scale      = 0.5
  )
  test_invariants(d)
  expect_equal(d@variables$scale, 0.5)
})

test_that("as_survey_rep() computes BRR default scale = 1/R", {
  # BRR scale = 1/R (matching survey::svrepdesign() default)
  # n_psu = 20 → R = 10 BRR replicates → scale = 1/10 = 0.1
  df    <- make_survey_data(n = 200, n_psu = 20L, design = "replicate", seed = 9L)
  n_rep <- sum(startsWith(names(df), "repwt_"))
  d     <- as_survey_rep(df, weights = wt, repweights = starts_with("repwt_"), type = "BRR")
  expect_equal(d@variables$scale, 1 / n_rep)
})

test_that("as_survey_rep() computes JK1 default scale = (R-1)/R", {
  df    <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", type = "jk1", seed = 10L)
  n_rep <- sum(startsWith(names(df), "repwt_"))
  d     <- as_survey_rep(df, weights = wt, repweights = starts_with("repwt_"), type = "JK1")
  expect_equal(d@variables$scale, (n_rep - 1L) / n_rep)
})

test_that("as_survey_rep() computes bootstrap default scale = 1/R", {
  df    <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", type = "bootstrap", seed = 11L)
  n_rep <- sum(startsWith(names(df), "repwt_"))
  d     <- as_survey_rep(df, weights = wt, repweights = starts_with("repwt_"), type = "bootstrap")
  expect_equal(d@variables$scale, 1 / n_rep)
})

test_that("as_survey_rep() stores repweights as column names (not matrix)", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 12L)
  d  <- as_survey_rep(df, weights = wt, repweights = starts_with("repwt_"), type = "JK1")
  # repweights must be a character vector, not a matrix
  expect_true(is.character(d@variables$repweights))
  expect_true(all(d@variables$repweights %in% names(d@data)))
})

test_that("as_survey_rep() stores mse as logical", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 13L)
  d1 <- as_survey_rep(df, weights = wt, repweights = starts_with("repwt_"), type = "JK1", mse = TRUE)
  d2 <- as_survey_rep(df, weights = wt, repweights = starts_with("repwt_"), type = "JK1", mse = FALSE)
  expect_true(d1@variables$mse)
  expect_false(d2@variables$mse)
})

test_that("as_survey_rep() stores fpc column name when fpc provided", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 14L)
  d  <- as_survey_rep(df, weights = wt, repweights = starts_with("repwt_"),
                      type = "BRR", fpc = fpc)
  test_invariants(d)
  expect_identical(d@variables$fpc, "fpc")
})

test_that("as_survey_rep() sets fpc = NULL when not provided", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 15L)
  d  <- as_survey_rep(df, weights = wt, repweights = starts_with("repwt_"), type = "JK1")
  expect_null(d@variables$fpc)
})


# ── Error paths ───────────────────────────────────────────────────────────────

# Row 1: data not a data frame
test_that("as_survey_rep() errors when data is not a data frame [row 1]", {
  expect_error(
    as_survey_rep(list(x = 1:5), weights = x,
                  repweights = starts_with("r"), type = "JK1"),
    class = "surveycore_error_not_data_frame"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_rep(list(x = 1:5), weights = x,
                  repweights = starts_with("r"), type = "JK1")
  )
})

# Row 2: data has 0 rows
test_that("as_survey_rep() errors when data has 0 rows [row 2]", {
  empty_df <- data.frame(x = numeric(0), w = numeric(0), r1 = numeric(0))
  expect_error(
    as_survey_rep(empty_df, weights = w, repweights = r1, type = "JK1"),
    class = "surveycore_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_rep(empty_df, weights = w, repweights = r1, type = "JK1")
  )
})

# Row 3: duplicate column names
test_that("as_survey_rep() errors when data has duplicate column names [row 3]", {
  df <- data.frame(x = 1:3, r = 4:6)
  names(df) <- c("x", "x")
  expect_error(
    as_survey_rep(df, weights = x, repweights = x, type = "JK1"),
    class = "surveycore_error_duplicate_names"
  )
})

# Row 4: data has 1 row (warning, not error)
test_that("as_survey_rep() warns when data has 1 row [row 4]", {
  df <- data.frame(x = 1, w = 1, r1 = 0.9)
  expect_warning(
    as_survey_rep(df, weights = w, repweights = r1, type = "JK1"),
    class = "surveycore_warning_single_row"
  )
})

# Row 8: weights selects 0 columns
test_that("as_survey_rep() errors when weights helper matches no columns [row 8]", {
  df <- make_survey_data(n = 50, n_psu = 10L, design = "replicate", seed = 16L)
  expect_error(
    as_survey_rep(df, weights = starts_with("zzz"),
                  repweights = starts_with("repwt_"), type = "JK1"),
    class = "surveycore_error_weights_not_found"
  )
})

# Row 9: weights selects >1 column
test_that("as_survey_rep() errors when weights expression selects multiple columns [row 9]", {
  df <- data.frame(y = 1:5, wt1 = 1:5, wt2 = 1:5, r1 = rep(1, 5), r2 = rep(1, 5))
  expect_error(
    as_survey_rep(df, weights = starts_with("wt"), repweights = starts_with("r"),
                  type = "JK1"),
    class = "surveycore_error_weights_multiple"
  )
})

# Row 10: weights all zero
test_that("as_survey_rep() errors when all weights are zero [row 10]", {
  df <- data.frame(y = 1:5, wt = c(0, 0, 0, 0, 0), r1 = rep(1, 5))
  expect_error(
    as_survey_rep(df, weights = wt, repweights = r1, type = "JK1"),
    class = "surveycore_error_weights_all_zero"
  )
})

# Row 16: repweights matches 0 columns
test_that("as_survey_rep() errors when repweights matches no columns [row 16]", {
  df <- make_survey_data(n = 50, n_psu = 10L, design = "replicate", seed = 17L)
  expect_error(
    as_survey_rep(df, weights = wt, repweights = starts_with("zzz"), type = "JK1"),
    class = "surveycore_error_repweights_empty"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_rep(df, weights = wt, repweights = starts_with("zzz"), type = "JK1")
  )
})

# Row 17: rscales length mismatch
test_that("as_survey_rep() errors when rscales length doesn't match n_rep [row 17]", {
  df <- make_survey_data(n = 200, n_psu = 20L, design = "replicate", seed = 18L)
  expect_error(
    as_survey_rep(
      df,
      weights    = wt,
      repweights = starts_with("repwt_"),
      type       = "BRR",
      rscales    = c(1, 2)   # wrong length
    ),
    class = "surveycore_error_rscales_length"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_rep(
      df,
      weights    = wt,
      repweights = starts_with("repwt_"),
      type       = "BRR",
      rscales    = c(1, 2)
    )
  )
})

# Row 18: invalid type (handled by match.arg)
test_that("as_survey_rep() errors when type is not a valid replicate method [row 18]", {
  df <- make_survey_data(n = 50, n_psu = 10L, design = "replicate", seed = 19L)
  expect_error(
    as_survey_rep(df, weights = wt, repweights = starts_with("repwt_"),
                  type = "invalid_type"),
    regexp = "should be one of"
  )
})


# ── Edge cases ────────────────────────────────────────────────────────────────

test_that("as_survey_rep() with tibble input (inherits data.frame)", {
  skip_if_not_installed("tibble")
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 20L)
  tb <- tibble::as_tibble(df)
  d  <- as_survey_rep(tb, weights = wt, repweights = starts_with("repwt_"), type = "JK1")
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_replicate))
})

test_that("as_survey_rep() populates all expected @variables keys", {
  df            <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 21L)
  d             <- as_survey_rep(df, weights = wt, repweights = starts_with("repwt_"), type = "JK1")
  expected_keys <- c("weights", "repweights", "type", "scale", "rscales",
                     "fpc", "fpctype", "mse")
  expect_true(all(expected_keys %in% names(d@variables)))
})

test_that("as_survey_rep() accepts fpctype argument", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 22L)
  d  <- as_survey_rep(df, weights = wt, repweights = starts_with("repwt_"),
                      type = "BRR", fpctype = "correction")
  expect_identical(d@variables$fpctype, "correction")
})


# ── Tidy-select interface ─────────────────────────────────────────────────────

test_that("as_survey_rep() accepts starts_with() for repweights", {
  df <- make_survey_data(n = 200, n_psu = 20L, design = "replicate", seed = 23L)
  d  <- as_survey_rep(df, weights = wt, repweights = starts_with("repwt_"), type = "BRR")
  test_invariants(d)
  expect_true(all(startsWith(d@variables$repweights, "repwt_")))
})

test_that("as_survey_rep() accepts c() for explicit repweight columns", {
  df <- data.frame(
    y = 1:10, wt = rep(1, 10),
    r1 = rep(1, 10), r2 = rep(1, 10), r3 = rep(1, 10)
  )
  d <- as_survey_rep(df, weights = wt, repweights = c(r1, r2, r3), type = "JK1")
  test_invariants(d)
  expect_identical(d@variables$repweights, c("r1", "r2", "r3"))
})

test_that("as_survey_rep() accepts bare name for weights", {
  df <- data.frame(
    y = 1:10, sampling_weight = rep(1, 10),
    r1 = rep(1, 10), r2 = rep(1, 10)
  )
  d <- as_survey_rep(df, weights = sampling_weight, repweights = starts_with("r"),
                     type = "JK1")
  test_invariants(d)
  expect_identical(d@variables$weights, "sampling_weight")
})


# ==============================================================================
# as_survey_twophase()
# ==============================================================================


# ── Happy paths ───────────────────────────────────────────────────────────────

test_that("as_survey_twophase() creates survey_twophase for minimal two-phase design", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 1L)
  phase1 <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, subset = phase2_ind)
  )
  test_invariants(d2)
  expect_true(S7::S7_inherits(d2, survey_twophase))
  expect_identical(d2@variables$subset, "phase2_ind")
  expect_identical(d2@variables$method, "full")
})

test_that("as_survey_twophase() creates survey_twophase with method = 'approx'", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 2L)
  phase1 <- as_survey(df, weights = wt)
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, subset = phase2_ind, method = "approx")
  )
  test_invariants(d2)
  expect_identical(d2@variables$method, "approx")
})

test_that("as_survey_twophase() creates survey_twophase with method = 'simple' (no clusters)", {
  # No PSUs in Phase 1 -> no 'simple' warning
  df <- make_survey_data(n = 200, design = "twophase", seed = 3L)
  phase1 <- as_survey(df, weights = wt)
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, subset = phase2_ind, method = "simple")
  )
  test_invariants(d2)
  expect_identical(d2@variables$method, "simple")
})

test_that("as_survey_twophase() stores Phase 2 stratification in @variables$phase2", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 4L)
  phase1 <- as_survey(df, weights = wt)
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, strata2 = strata, subset = phase2_ind)
  )
  test_invariants(d2)
  expect_identical(d2@variables$phase2$strata, "strata")
  expect_null(d2@variables$phase2$ids)
  expect_null(d2@variables$phase2$probs)
  expect_null(d2@variables$phase2$fpc)
})

test_that("as_survey_twophase() stores Phase 2 probs in @variables$phase2", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 5L)
  # Add a fake probs2 column
  df$subsamprate <- rep(0.4, nrow(df))
  phase1 <- as_survey(df, weights = wt)
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, probs2 = subsamprate, subset = phase2_ind,
                       method = "full")
  )
  test_invariants(d2)
  expect_identical(d2@variables$phase2$probs, "subsamprate")
})

test_that("as_survey_twophase() stores Phase 2 cluster ids in @variables$phase2", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 6L)
  phase1 <- as_survey(df, weights = wt)
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, ids2 = psu, subset = phase2_ind)
  )
  test_invariants(d2)
  expect_identical(d2@variables$phase2$ids, "psu")
})

test_that("as_survey_twophase() stores Phase 2 fpc in @variables$phase2", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 7L)
  phase1 <- as_survey(df, weights = wt)
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, fpc2 = fpc, subset = phase2_ind)
  )
  test_invariants(d2)
  expect_identical(d2@variables$phase2$fpc, "fpc")
})

test_that("as_survey_twophase() stores Phase 1 @variables in @variables$phase1", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 8L)
  phase1 <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, subset = phase2_ind)
  )
  test_invariants(d2)
  # Phase 1 variables preserved in nested structure
  expect_identical(d2@variables$phase1$weights, "wt")
  expect_identical(d2@variables$phase1$strata, "strata")
  expect_identical(d2@variables$phase1$ids, "psu")
  expect_true(d2@variables$phase1$nest)
})

test_that("as_survey_twophase() inherits metadata from phase1", {
  df <- make_survey_data(n = 200, design = "twophase", with_labels = TRUE, seed = 9L)
  phase1 <- as_survey(df, weights = wt)
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, subset = phase2_ind)
  )
  test_invariants(d2)
  # Metadata inherited from phase1
  expect_identical(
    d2@metadata@variable_labels[["y1"]],
    "Outcome variable 1 (continuous)"
  )
})

test_that("as_survey_twophase() stores call in @call", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 10L)
  phase1 <- as_survey(df, weights = wt)
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, subset = phase2_ind)
  )
  expect_false(is.null(d2@call))
  expect_true(is.call(d2@call))
})

test_that("as_survey_twophase() uses @data from phase1 (no copy)", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 11L)
  phase1 <- as_survey(df, weights = wt)
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, subset = phase2_ind)
  )
  # @data should be the same data as phase1@data
  expect_identical(nrow(d2@data), nrow(phase1@data))
  expect_identical(names(d2@data), names(phase1@data))
})

test_that("as_survey_twophase() sets all Phase 2 variables to NULL when not provided", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 12L)
  phase1 <- as_survey(df, weights = wt)
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, subset = phase2_ind)
  )
  test_invariants(d2)
  expect_null(d2@variables$phase2$ids)
  expect_null(d2@variables$phase2$strata)
  expect_null(d2@variables$phase2$probs)
  expect_null(d2@variables$phase2$fpc)
})


# ── Warning paths ─────────────────────────────────────────────────────────────

# Row 24: method = "simple" with clustered Phase 1
test_that("as_survey_twophase() warns when method = 'simple' with clustered Phase 1 [row 24]", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 13L)
  phase1 <- suppressWarnings(
    as_survey(df, ids = psu, weights = wt, strata = strata)
  )
  expect_warning(
    as_survey_twophase(phase1, subset = phase2_ind, method = "simple"),
    class = "surveycore_warning_simple_clustered"
  )
})

test_that("as_survey_twophase() does NOT warn for method = 'simple' when Phase 1 has no PSUs [row 24]", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 14L)
  phase1 <- as_survey(df, weights = wt)  # no ids
  expect_no_warning(
    as_survey_twophase(phase1, subset = phase2_ind, method = "simple"),
    message = "surveycore_warning_simple_clustered"
  )
})

# Row 25: method = "full" with no Phase 2 design info
test_that("as_survey_twophase() warns when method = 'full' with no Phase 2 info [row 25]", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 15L)
  phase1 <- as_survey(df, weights = wt)
  expect_warning(
    as_survey_twophase(phase1, subset = phase2_ind, method = "full"),
    class = "surveycore_warning_full_no_phase2"
  )
})

test_that("as_survey_twophase() does NOT warn for method = 'full' when Phase 2 probs provided [row 25]", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 16L)
  df$prob2 <- rep(0.4, nrow(df))
  phase1 <- as_survey(df, weights = wt)
  expect_no_warning(
    as_survey_twophase(phase1, probs2 = prob2, subset = phase2_ind,
                       method = "full"),
    message = "surveycore_warning_full_no_phase2"
  )
})

test_that("as_survey_twophase() snapshot: method = 'simple' + clustered Phase 1 warning", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 17L)
  phase1 <- suppressWarnings(
    as_survey(df, ids = psu, weights = wt, strata = strata)
  )
  expect_snapshot(
    as_survey_twophase(phase1, subset = phase2_ind, method = "simple")
  )
})

test_that("as_survey_twophase() snapshot: method = 'full' + no Phase 2 info warning", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 18L)
  phase1 <- as_survey(df, weights = wt)
  expect_snapshot(
    as_survey_twophase(phase1, subset = phase2_ind, method = "full")
  )
})


# ── Error paths ───────────────────────────────────────────────────────────────

# Row 19: phase1 is not a survey_taylor
test_that("as_survey_twophase() errors when phase1 is not a survey_taylor [row 19]", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 19L)
  expect_error(
    as_survey_twophase(df, subset = phase2_ind),
    class = "surveycore_error_phase1_class"
  )
  expect_snapshot(error = TRUE, as_survey_twophase(df, subset = phase2_ind))
})

test_that("as_survey_twophase() errors when phase1 is a survey_replicate [row 19]", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 20L)
  phase_rep <- as_survey_rep(df, weights = wt, repweights = starts_with("repwt_"),
                              type = "JK1")
  expect_error(
    as_survey_twophase(phase_rep, subset = phase2_ind),
    class = "surveycore_error_phase1_class"
  )
})

# Row 20: subset not provided
test_that("as_survey_twophase() errors when subset is not provided [row 20]", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 21L)
  phase1 <- as_survey(df, weights = wt)
  expect_error(
    as_survey_twophase(phase1),
    class = "surveycore_error_subset_missing"
  )
  expect_snapshot(error = TRUE, as_survey_twophase(phase1))
})

# Row 21: subset selects >1 column
test_that("as_survey_twophase() errors when subset selects multiple columns [row 21]", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 22L)
  # Add a second logical column with same prefix
  df$phase2_ind2 <- runif(nrow(df)) < 0.4
  phase1 <- as_survey(df, weights = wt)
  expect_error(
    as_survey_twophase(phase1, subset = starts_with("phase2_ind")),
    class = "surveycore_error_subset_multiple"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_twophase(phase1, subset = starts_with("phase2_ind"))
  )
})

# Row 22: subset column is not logical
test_that("as_survey_twophase() errors when subset column is not logical [row 22]", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 23L)
  # Replace logical phase2_ind with integer
  df$phase2_int <- as.integer(df$phase2_ind)
  phase1 <- as_survey(df, weights = wt)
  expect_error(
    as_survey_twophase(phase1, subset = phase2_int),
    class = "surveycore_error_subset_not_logical"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_twophase(phase1, subset = phase2_int)
  )
})

# Row 23: subset is all TRUE or all FALSE (degenerate)
test_that("as_survey_twophase() errors when subset is all TRUE [row 23]", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 24L)
  df$all_true <- TRUE
  phase1 <- as_survey(df, weights = wt)
  expect_error(
    as_survey_twophase(phase1, subset = all_true),
    class = "surveycore_error_subset_degenerate"
  )
  expect_snapshot(error = TRUE, as_survey_twophase(phase1, subset = all_true))
})

test_that("as_survey_twophase() errors when subset is all FALSE [row 23]", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 25L)
  df$all_false <- FALSE
  phase1 <- as_survey(df, weights = wt)
  expect_error(
    as_survey_twophase(phase1, subset = all_false),
    class = "surveycore_error_subset_degenerate"
  )
})


# ── Edge cases ────────────────────────────────────────────────────────────────

test_that("as_survey_twophase() with multi-stage Phase 2 ids (c())", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 26L)
  # Add a secondary sampling unit column for Phase 2
  df$psu2 <- rep(1:5, length.out = nrow(df))
  df$ssu2 <- rep(1:4, length.out = nrow(df))
  phase1 <- as_survey(df, weights = wt)
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, ids2 = c(psu2, ssu2), subset = phase2_ind)
  )
  test_invariants(d2)
  expect_identical(d2@variables$phase2$ids, c("psu2", "ssu2"))
})

test_that("as_survey_twophase() preserves all Phase 1 data columns in @data", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 27L)
  phase1 <- as_survey(df, weights = wt)
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, subset = phase2_ind)
  )
  # All original columns must be in @data (none dropped)
  expect_true(all(names(df) %in% names(d2@data)))
})

test_that("as_survey_twophase() subset with only 1 TRUE row is valid (not degenerate)", {
  df <- data.frame(
    id        = 1:20,
    wt        = rep(2, 20),
    in_phase2 = c(TRUE, rep(FALSE, 19)),
    y         = rnorm(20)
  )
  phase1 <- as_survey(df, weights = wt)
  # 1 TRUE and 19 FALSE — not degenerate
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, subset = in_phase2)
  )
  test_invariants(d2)
  expect_true(S7::S7_inherits(d2, survey_twophase))
})

test_that("as_survey_twophase() with method = 'full' and strata2 does not warn [row 25]", {
  # Providing strata2 counts as Phase 2 design info
  df <- make_survey_data(n = 200, design = "twophase", seed = 28L)
  phase1 <- as_survey(df, weights = wt)
  expect_no_warning(
    as_survey_twophase(phase1, strata2 = strata, subset = phase2_ind,
                       method = "full"),
    message = "surveycore_warning_full_no_phase2"
  )
})

test_that("as_survey_twophase() populates all expected @variables keys", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 29L)
  phase1 <- as_survey(df, weights = wt)
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, subset = phase2_ind)
  )
  expected_keys <- c("phase1", "phase2", "subset", "method")
  expect_true(all(expected_keys %in% names(d2@variables)))
})


# ── Tidy-select interface ─────────────────────────────────────────────────────

test_that("as_survey_twophase() accepts bare name for subset", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 30L)
  phase1 <- as_survey(df, weights = wt)
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, subset = phase2_ind)
  )
  test_invariants(d2)
  expect_identical(d2@variables$subset, "phase2_ind")
})

test_that("as_survey_twophase() accepts bare name for strata2", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 31L)
  phase1 <- as_survey(df, weights = wt)
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, strata2 = strata, subset = phase2_ind)
  )
  test_invariants(d2)
  expect_identical(d2@variables$phase2$strata, "strata")
})

test_that("as_survey_twophase() accepts bare name for ids2", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 32L)
  phase1 <- as_survey(df, weights = wt)
  d2 <- suppressWarnings(
    as_survey_twophase(phase1, ids2 = psu, subset = phase2_ind)
  )
  test_invariants(d2)
  expect_identical(d2@variables$phase2$ids, "psu")
})


# ── Coverage: as_survey() probs error paths ──────────────────────────────────

test_that("as_survey() errors when probs expression matches no columns", {
  df <- data.frame(x = 1:5, wt = 1:5)
  expect_error(
    as_survey(df, probs = tidyselect::starts_with("nonexistent_xyz")),
    class = "surveycore_error_weights_not_found"
  )
})

test_that("as_survey() errors when probs expression selects multiple columns", {
  df <- data.frame(x = 1:5, prob1 = rep(0.1, 5), prob2 = rep(0.2, 5))
  expect_error(
    as_survey(df, probs = starts_with("prob")),
    class = "surveycore_error_weights_multiple"
  )
})


# ── Coverage: as_survey_rep() fpc multiple columns ───────────────────────────

test_that("as_survey_rep() errors when fpc expression selects multiple columns", {
  df <- data.frame(
    y    = 1:5,
    wt   = rep(1, 5),
    r1   = rep(1, 5),
    fpc1 = rep(1000L, 5),
    fpc2 = rep(2000L, 5)
  )
  expect_error(
    as_survey_rep(df, weights = wt, repweights = r1, type = "JK1",
                  fpc = starts_with("fpc")),
    class = "surveycore_error_fpc_multiple"
  )
})


# ── Coverage: as_survey_twophase() additional error paths ────────────────────

test_that("as_survey_twophase() errors when subset matches 0 columns", {
  df     <- make_survey_data(n = 100L, design = "twophase", seed = 90L)
  phase1 <- as_survey(df, weights = wt)
  expect_error(
    as_survey_twophase(phase1,
                       subset = tidyselect::starts_with("nonexistent_xyz")),
    class = "surveycore_error_subset_missing"
  )
})

test_that("as_survey_twophase() errors when strata2 selects multiple columns", {
  df      <- make_survey_data(n = 100L, design = "twophase", seed = 91L)
  df$st2a <- df$strata
  df$st2b <- df$strata
  phase1  <- as_survey(df, weights = wt)
  expect_error(
    as_survey_twophase(phase1, strata2 = starts_with("st2"), subset = phase2_ind),
    class = "surveycore_error_strata_multiple"
  )
})

test_that("as_survey_twophase() errors when probs2 selects multiple columns", {
  df        <- make_survey_data(n = 100L, design = "twophase", seed = 92L)
  df$prob2a <- runif(nrow(df), 0.3, 0.8)
  df$prob2b <- runif(nrow(df), 0.3, 0.8)
  phase1    <- as_survey(df, weights = wt)
  expect_error(
    as_survey_twophase(phase1, probs2 = starts_with("prob2"), subset = phase2_ind),
    class = "surveycore_error_weights_multiple"
  )
})

test_that("as_survey_twophase() errors when fpc2 selects multiple columns", {
  df       <- make_survey_data(n = 100L, design = "twophase", seed = 93L)
  df$fpc2a <- rep(1000L, nrow(df))
  df$fpc2b <- rep(2000L, nrow(df))
  phase1   <- as_survey(df, weights = wt)
  expect_error(
    as_survey_twophase(phase1, fpc2 = starts_with("fpc2"), subset = phase2_ind),
    class = "surveycore_error_fpc_multiple"
  )
})


# ── Coverage: zero-length guards (bugs fixed) ─────────────────────────────────

test_that("as_survey() errors when strata expression matches no columns", {
  df <- data.frame(x = 1:10, wt = rep(1, 10))
  expect_error(
    as_survey(df, weights = wt, strata = tidyselect::starts_with("nonexistent_xyz")),
    class = "surveycore_error_strata_not_found"
  )
})

test_that("as_survey() errors when fpc expression matches no columns", {
  df <- data.frame(x = 1:10, wt = rep(1, 10))
  expect_error(
    as_survey(df, weights = wt, fpc = tidyselect::starts_with("nonexistent_xyz")),
    class = "surveycore_error_fpc_not_found"
  )
})

test_that("as_survey_rep() errors when fpc expression matches no columns", {
  df <- data.frame(
    y  = 1:10, wt = rep(1, 10), r1 = rep(1, 10), r2 = rep(1, 10)
  )
  expect_error(
    as_survey_rep(df, weights = wt, repweights = c(r1, r2), type = "BRR",
                  fpc = tidyselect::starts_with("nonexistent_xyz")),
    class = "surveycore_error_fpc_not_found"
  )
})

test_that("as_survey_rep() validates fpc column for NAs", {
  df <- data.frame(
    y   = 1:10, wt = rep(1, 10), r1 = rep(1, 10), r2 = rep(1, 10),
    fpc = c(100L, NA_integer_, rep(100L, 8L))
  )
  expect_error(
    as_survey_rep(df, weights = wt, repweights = c(r1, r2), type = "BRR",
                  fpc = fpc),
    class = "surveycore_error_fpc_na"
  )
})
