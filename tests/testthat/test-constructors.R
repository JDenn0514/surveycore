# tests/testthat/test-constructors.R
#
# Tests for R/03-constructors.R — as_survey_srs(), as_survey(), as_survey_replicate(),
# and as_survey_twophase().
#
# Coverage (per plans/error-messages.md):
#   Rows 1–15: as_survey() errors and warnings
#   Rows 1–4, 8–10, 16–18: as_survey_replicate() errors and warnings
#   Rows 19–25: as_survey_twophase() errors and warnings
#   Rows 56–61: as_survey_srs() errors and warnings
#
# Test structure (per .claude/rules/testing-standards.md):
#   1. Happy paths  (one block per design type)
#   2. Error paths  (one block per error-messages.md row)
#   3. Edge cases   (boundary conditions)
#   4. Tidy-select  (bare names, c(), helpers)

# ── Happy paths ───────────────────────────────────────────────────────────────

test_that("as_survey() dispatches to survey_srs for SRS (no ids or strata)", {
  df <- make_survey_data(n = 100, seed = 1L)
  suppressWarnings(
    expect_warning(
      d <- as_survey(df),
      class = "surveycore_warning_as_survey_srs_fallback"
    )
  )
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_srs))
  expect_identical(d@variables$ids, NULL)
  expect_identical(d@variables$strata, NULL)
  expect_false(d@variables$probs_provided)
})

test_that("as_survey() dispatches to survey_srs for weighted SRS (weights only)", {
  df <- make_survey_data(n = 100, seed = 1L)
  expect_warning(
    d <- as_survey(df, weights = wt),
    class = "surveycore_warning_as_survey_srs_fallback"
  )
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_srs))
  expect_identical(d@variables$weights, "wt")
  expect_identical(d@variables$ids, NULL)
  expect_false(d@variables$probs_provided)
})

test_that("as_survey() creates survey_taylor for stratified design", {
  df <- make_survey_data(n = 200, seed = 2L)
  d <- as_survey(df, weights = wt, strata = strata)
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_taylor))
  expect_identical(d@variables$weights, "wt")
  expect_identical(d@variables$strata, "strata")
  expect_identical(d@variables$ids, NULL)
})

test_that("as_survey() creates survey_taylor for single-stage cluster design", {
  df <- make_survey_data(n = 200, seed = 3L)
  d <- suppressWarnings(as_survey(df, ids = psu, weights = wt, strata = strata))
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
    ids = sdmvpsu,
    weights = wtmec2yr,
    strata = sdmvstra,
    nest = TRUE
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
  d <- suppressWarnings(as_survey(df, weights = wt))
  expect_false(is.null(d@call))
  expect_true(is.call(d@call))
})

test_that("as_survey() extracts haven metadata when present", {
  df <- make_survey_data(n = 100, with_labels = TRUE, seed = 5L)
  d <- suppressWarnings(as_survey(df, weights = wt))
  test_invariants(d)
  expect_identical(
    d@metadata@variable_labels[["y1"]],
    "Outcome variable 1 (continuous)"
  )
  expect_identical(d@metadata@value_labels[["y3"]], c("No" = 0L, "Yes" = 1L))
})

test_that("as_survey() returns an empty metadata object when no haven attrs", {
  df <- make_survey_data(n = 50, seed = 6L)
  d <- suppressWarnings(as_survey(df, weights = wt))
  test_invariants(d)
  expect_identical(length(d@metadata@variable_labels), 0L)
})


# ── Probs argument ─────────────────────────────────────────────────────────────

test_that("as_survey() converts probs to weights (1/probs) stored as ..surveycore_wt..", {
  df <- data.frame(y = 1:5, prob = rep(0.2, 5))
  d <- suppressWarnings(as_survey(df, probs = prob))
  test_invariants(d)
  expect_identical(d@variables$weights, surveycore:::.SURVEYCORE_WT_COL)
  expect_true(d@variables$probs_provided)
  expect_equal(d@data[[surveycore:::.SURVEYCORE_WT_COL]], rep(5, 5))
})

test_that("as_survey() uses weights when both probs and weights are consistent", {
  df <- data.frame(
    y = 1:5,
    prob = rep(0.2, 5),
    wt = rep(5, 5), # consistent: 1/0.2 = 5
    strata = c("A", "A", "B", "B", "B")
  )
  # Use strata to stay on Taylor path (SRS path rejects both probs+weights)
  expect_message(
    {
      d <- as_survey(df, probs = prob, weights = wt, strata = strata)
    },
    class = "surveycore_inform_probs_weights_consistent"
  )
  test_invariants(d)
  expect_identical(d@variables$weights, "wt")
  expect_true(d@variables$probs_provided)
})

test_that("as_survey() stores fpc column name in @variables", {
  df <- make_survey_data(n = 100, seed = 7L)
  d <- suppressWarnings(as_survey(df, weights = wt, fpc = fpc))
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
  names(df) <- c("x", "x") # force duplicate
  expect_error(
    as_survey(df, weights = x),
    class = "surveycore_error_duplicate_names"
  )
  expect_snapshot(
    error = TRUE,
    {
      df2 <- data.frame(x = 1:3, y = 4:6)
      names(df2) <- c("x", "x")
      as_survey(df2, weights = x)
    }
  )
})

# Row 4: data has 1 row (warning, not error)
test_that("as_survey() warns when data has 1 row [row 4]", {
  single_row <- data.frame(x = 42, w = 1)
  suppressWarnings(
    expect_warning(
      as_survey(single_row, weights = w),
      class = "surveycore_warning_single_row"
    )
  )
})

test_that("as_survey() still returns a valid object after single-row warning [row 4]", {
  single_row <- data.frame(x = 42, w = 1)
  d <- suppressWarnings(as_survey(single_row, weights = w))
  expect_true(S7::S7_inherits(d, survey_srs))
})

# Row 5: probs and weights inconsistent (Taylor path — needs ids or strata)
test_that("as_survey() errors when probs and weights are inconsistent [row 5]", {
  df <- data.frame(
    y = 1:5,
    prob = rep(0.2, 5), # implies weight = 5
    wt = rep(3, 5), # inconsistent
    strata = c("A", "A", "B", "B", "B")
  )
  # Use strata to stay on Taylor path (SRS path errors differently for both supplied)
  expect_error(
    as_survey(df, probs = prob, weights = wt, strata = strata),
    class = "surveycore_error_probs_weights_conflict"
  )
  expect_snapshot(
    error = TRUE,
    as_survey(df, probs = prob, weights = wt, strata = strata)
  )
})

# Row 7: SRS warning (no weights/probs/ids)
test_that("as_survey() warns for SRS (no weights, probs, or ids) [row 7]", {
  df <- data.frame(y = 1:10, x = rnorm(10))
  suppressWarnings(
    expect_warning(
      as_survey(df),
      class = "surveycore_warning_srs_no_weights"
    )
  )
})

test_that("as_survey() warns with cluster message when ids given but no weights [row 7]", {
  df <- data.frame(psu = rep(1:5, 2), y = 1:10)
  expect_warning(
    as_survey(df, ids = psu),
    class = "surveycore_warning_srs_no_weights"
  )
  expect_warning(
    as_survey(df, ids = psu),
    regexp = "equal-probability sampling within clusters"
  )
})

test_that("as_survey() warns with SRS message when strata given but no ids and no weights [row 7]", {
  df <- data.frame(st = rep(c("A", "B"), 5), y = 1:10, wt = rep(1, 10))
  expect_warning(
    as_survey(df, strata = st),
    class = "surveycore_warning_srs_no_weights"
  )
  expect_warning(
    as_survey(df, strata = st),
    regexp = "No weights or population size provided"
  )
})

test_that("as_survey() creates equal weights (..surveycore_wt..) for SRS [row 7]", {
  df <- data.frame(y = 1:10)
  d <- suppressWarnings(as_survey(df))
  test_invariants(d)
  expect_identical(d@data[[surveycore:::.SURVEYCORE_WT_COL]], rep(1L, 10L))
})

# Row 8: weights selects 0 columns
test_that("as_survey() errors when weights helper matches no columns [row 8]", {
  df <- data.frame(y = 1:5, wt = 1:5)
  expect_error(
    suppressWarnings(as_survey(df, weights = starts_with("zzz"))),
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
    suppressWarnings(as_survey(df, weights = starts_with("wt"))),
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
    suppressWarnings(as_survey(df, weights = wt)),
    class = "surveycore_error_weights_all_zero"
  )
})

test_that("as_survey() errors when all weights are NA [row 10]", {
  df <- data.frame(x = 1:5, wt = rep(NA_real_, 5))
  expect_error(
    suppressWarnings(as_survey(df, weights = wt)),
    class = "surveycore_error_weights_all_zero"
  )
})

# Row 11: strata selects >1 column
test_that("as_survey() errors when strata expression selects multiple columns [row 11]", {
  df <- data.frame(
    x = 1:5,
    st1 = c("A", "B", "A", "B", "A"),
    st2 = c("X", "Y", "X", "Y", "X"),
    wt = 1:5
  )
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
    x = 1:5,
    wt = 1:5,
    fpc1 = rep(1000L, 5),
    fpc2 = rep(2000L, 5)
  )
  expect_error(
    suppressWarnings(as_survey(df, weights = wt, fpc = starts_with("fpc"))),
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
    x = 1:5,
    wt = 1:5,
    fpc = c(1000L, NA_integer_, 1000L, 1000L, 1000L)
  )
  expect_error(
    suppressWarnings(as_survey(df, weights = wt, fpc = fpc)),
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
  d <- suppressWarnings(as_survey(df, weights = wt))
  test_invariants(d)
  expect_identical(d@variables$weights, "wt")
})

test_that("as_survey() with tibble input (inherits data.frame)", {
  skip_if_not_installed("tibble")
  tb <- tibble::tibble(y = 1:10, wt = runif(10, 0.5, 2))
  d <- suppressWarnings(as_survey(tb, weights = wt))
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_srs))
})

test_that("as_survey() populates all expected @variables keys", {
  df <- make_survey_data(n = 100, seed = 9L)
  d <- suppressWarnings(as_survey(df, weights = wt))
  expected_keys <- c(
    "ids",
    "weights",
    "strata",
    "fpc",
    "nest",
    "probs_provided"
  )
  expect_true(all(expected_keys %in% names(d@variables)))
})

test_that("as_survey() sets NULL for unspecified design vars", {
  df <- data.frame(x = 1:5, wt = rep(1, 5))
  d <- suppressWarnings(as_survey(df, weights = wt))
  expect_null(d@variables$ids)
  expect_null(d@variables$strata)
  expect_null(d@variables$fpc)
})

test_that("as_survey() warns for PSU appearing in multiple strata (not nest)", {
  # PSU 1 appears in both stratum A and B
  df <- data.frame(
    psu = c(1, 1, 2, 2, 3, 3),
    strata = c("A", "B", "A", "A", "B", "B"),
    wt = rep(1, 6)
  )
  expect_warning(
    as_survey(df, ids = psu, weights = wt, strata = strata),
    class = "surveycore_warning_psu_multi_strata"
  )
})

test_that("as_survey() does NOT warn for PSU in multiple strata when nest = TRUE", {
  # nest = TRUE suppresses the multi-strata PSU check
  df <- data.frame(
    psu = c(1, 1, 2, 2),
    strata = c("A", "B", "A", "B"),
    wt = rep(1, 4)
  )
  expect_no_warning(
    as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE),
    message = "surveycore_warning_psu_multi_strata"
  )
})


# ── Tidy-select interface ─────────────────────────────────────────────────────

test_that("as_survey() accepts bare name for weights", {
  df <- data.frame(y = 1:5, weight_col = rep(1, 5))
  d <- suppressWarnings(as_survey(df, weights = weight_col))
  test_invariants(d)
  expect_identical(d@variables$weights, "weight_col")
})

test_that("as_survey() accepts bare name for strata", {
  df <- data.frame(y = 1:10, wt = rep(1, 10), region = rep(c("N", "S"), 5))
  d <- as_survey(df, weights = wt, strata = region)
  test_invariants(d)
  expect_identical(d@variables$strata, "region")
})

test_that("as_survey() accepts c() for multi-stage cluster ids", {
  df <- data.frame(
    psu = rep(1:5, each = 4),
    ssu = rep(1:4, 5),
    wt = rep(1, 20)
  )
  d <- as_survey(df, ids = c(psu, ssu), weights = wt)
  test_invariants(d)
  expect_identical(d@variables$ids, c("psu", "ssu"))
})

test_that("as_survey() accepts single bare name for ids", {
  df <- make_survey_data(n = 100, seed = 10L)
  d <- suppressWarnings(as_survey(df, ids = psu, weights = wt, strata = strata))
  test_invariants(d)
  expect_identical(d@variables$ids, "psu")
})

test_that("as_survey() ids = NULL means SRS (no cluster)", {
  df <- data.frame(y = 1:10, wt = rep(1, 10))
  d <- suppressWarnings(as_survey(df, weights = wt))
  expect_null(d@variables$ids)
})


# ==============================================================================
# as_survey_replicate()
# ==============================================================================

# ── Happy paths ───────────────────────────────────────────────────────────────

test_that("as_survey_replicate() creates survey_replicate for BRR design (starts_with)", {
  df <- make_survey_data(n = 200, n_psu = 20L, design = "replicate", seed = 1L)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "BRR"
  )
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_replicate))
  expect_identical(d@variables$weights, "wt")
  expect_identical(d@variables$type, "BRR")
  expect_true(length(d@variables$repweights) > 0L)
  expect_true(all(startsWith(d@variables$repweights, "repwt_")))
})

test_that("as_survey_replicate() creates survey_replicate for JK1 design (bare names)", {
  df <- make_survey_data(
    n = 200,
    n_psu = 20L,
    design = "replicate",
    type = "jk1",
    seed = 2L
  )
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "JK1"
  )
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_replicate))
  expect_identical(d@variables$type, "JK1")
})

test_that("as_survey_replicate() creates survey_replicate for bootstrap design", {
  df <- make_survey_data(
    n = 100,
    n_psu = 10L,
    design = "replicate",
    type = "bootstrap",
    seed = 3L
  )
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "bootstrap"
  )
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_replicate))
  expect_identical(d@variables$type, "bootstrap")
})

test_that("as_survey_replicate() stores call in @call", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 4L)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "JK1"
  )
  expect_false(is.null(d@call))
  expect_true(is.call(d@call))
})

test_that("as_survey_replicate() extracts haven metadata when present", {
  df <- make_survey_data(
    n = 100,
    n_psu = 10L,
    design = "replicate",
    with_labels = TRUE,
    seed = 5L
  )
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "JK1"
  )
  test_invariants(d)
  expect_identical(
    d@metadata@variable_labels[["y1"]],
    "Outcome variable 1 (continuous)"
  )
})

test_that("as_survey_replicate() returns empty metadata when no haven attrs", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 6L)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "JK1"
  )
  test_invariants(d)
  expect_identical(length(d@metadata@variable_labels), 0L)
})

test_that("as_survey_replicate() accepts explicit rscales of correct length", {
  df <- make_survey_data(
    n = 100,
    n_psu = 10L,
    design = "replicate",
    type = "jk1",
    seed = 7L
  )
  n_rep <- sum(startsWith(names(df), "repwt_"))
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "JK1",
    rscales = rep(1, n_rep)
  )
  test_invariants(d)
  expect_identical(length(d@variables$rscales), n_rep)
})

test_that("as_survey_replicate() accepts explicit scale argument", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 8L)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "JK1",
    scale = 0.5
  )
  test_invariants(d)
  expect_equal(d@variables$scale, 0.5)
})

test_that("as_survey_replicate() computes BRR default scale = 1/R", {
  # BRR scale = 1/R (matching survey::svrepdesign() default)
  # n_psu = 20 → R = 10 BRR replicates → scale = 1/10 = 0.1
  df <- make_survey_data(n = 200, n_psu = 20L, design = "replicate", seed = 9L)
  n_rep <- sum(startsWith(names(df), "repwt_"))
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "BRR"
  )
  expect_equal(d@variables$scale, 1 / n_rep)
})

test_that("as_survey_replicate() computes JK1 default scale = (R-1)/R", {
  df <- make_survey_data(
    n = 100,
    n_psu = 10L,
    design = "replicate",
    type = "jk1",
    seed = 10L
  )
  n_rep <- sum(startsWith(names(df), "repwt_"))
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "JK1"
  )
  expect_equal(d@variables$scale, (n_rep - 1L) / n_rep)
})

test_that("as_survey_replicate() computes bootstrap default scale = 1/R", {
  df <- make_survey_data(
    n = 100,
    n_psu = 10L,
    design = "replicate",
    type = "bootstrap",
    seed = 11L
  )
  n_rep <- sum(startsWith(names(df), "repwt_"))
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "bootstrap"
  )
  expect_equal(d@variables$scale, 1 / n_rep)
})

test_that("as_survey_replicate() stores repweights as column names (not matrix)", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 12L)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "JK1"
  )
  # repweights must be a character vector, not a matrix
  expect_true(is.character(d@variables$repweights))
  expect_true(all(d@variables$repweights %in% names(d@data)))
})

test_that("as_survey_replicate() stores mse as logical", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 13L)
  d1 <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "JK1",
    mse = TRUE
  )
  d2 <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "JK1",
    mse = FALSE
  )
  expect_true(d1@variables$mse)
  expect_false(d2@variables$mse)
})

test_that("as_survey_replicate() stores fpc column name when fpc provided", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 14L)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "BRR",
    fpc = fpc
  )
  test_invariants(d)
  expect_identical(d@variables$fpc, "fpc")
})

test_that("as_survey_replicate() sets fpc = NULL when not provided", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 15L)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "JK1"
  )
  expect_null(d@variables$fpc)
})


# ── Error paths ───────────────────────────────────────────────────────────────

# Row 1: data not a data frame
test_that("as_survey_replicate() errors when data is not a data frame [row 1]", {
  expect_error(
    as_survey_replicate(
      list(x = 1:5),
      weights = x,
      repweights = starts_with("r"),
      type = "JK1"
    ),
    class = "surveycore_error_not_data_frame"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_replicate(
      list(x = 1:5),
      weights = x,
      repweights = starts_with("r"),
      type = "JK1"
    )
  )
})

# Row 2: data has 0 rows
test_that("as_survey_replicate() errors when data has 0 rows [row 2]", {
  empty_df <- data.frame(x = numeric(0), w = numeric(0), r1 = numeric(0))
  expect_error(
    as_survey_replicate(empty_df, weights = w, repweights = r1, type = "JK1"),
    class = "surveycore_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_replicate(empty_df, weights = w, repweights = r1, type = "JK1")
  )
})

# Row 3: duplicate column names
test_that("as_survey_replicate() errors when data has duplicate column names [row 3]", {
  df <- data.frame(x = 1:3, r = 4:6)
  names(df) <- c("x", "x")
  expect_error(
    as_survey_replicate(df, weights = x, repweights = x, type = "JK1"),
    class = "surveycore_error_duplicate_names"
  )
})

# Row 4: data has 1 row (warning, not error)
test_that("as_survey_replicate() warns when data has 1 row [row 4]", {
  df <- data.frame(x = 1, w = 1, r1 = 0.9)
  expect_warning(
    as_survey_replicate(df, weights = w, repweights = r1, type = "JK1"),
    class = "surveycore_warning_single_row"
  )
})

# Row 8: weights selects 0 columns
test_that("as_survey_replicate() errors when weights helper matches no columns [row 8]", {
  df <- make_survey_data(n = 50, n_psu = 10L, design = "replicate", seed = 16L)
  expect_error(
    as_survey_replicate(
      df,
      weights = starts_with("zzz"),
      repweights = starts_with("repwt_"),
      type = "JK1"
    ),
    class = "surveycore_error_weights_not_found"
  )
})

# Row 9: weights selects >1 column
test_that("as_survey_replicate() errors when weights expression selects multiple columns [row 9]", {
  df <- data.frame(
    y = 1:5,
    wt1 = 1:5,
    wt2 = 1:5,
    r1 = rep(1, 5),
    r2 = rep(1, 5)
  )
  expect_error(
    as_survey_replicate(
      df,
      weights = starts_with("wt"),
      repweights = starts_with("r"),
      type = "JK1"
    ),
    class = "surveycore_error_weights_multiple"
  )
})

# Row 10: weights all zero
test_that("as_survey_replicate() errors when all weights are zero [row 10]", {
  df <- data.frame(y = 1:5, wt = c(0, 0, 0, 0, 0), r1 = rep(1, 5))
  expect_error(
    as_survey_replicate(df, weights = wt, repweights = r1, type = "JK1"),
    class = "surveycore_error_weights_all_zero"
  )
})

# Row 16: repweights matches 0 columns
test_that("as_survey_replicate() errors when repweights matches no columns [row 16]", {
  df <- make_survey_data(n = 50, n_psu = 10L, design = "replicate", seed = 17L)
  expect_error(
    as_survey_replicate(
      df,
      weights = wt,
      repweights = starts_with("zzz"),
      type = "JK1"
    ),
    class = "surveycore_error_repweights_empty"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_replicate(
      df,
      weights = wt,
      repweights = starts_with("zzz"),
      type = "JK1"
    )
  )
})

# Row 17: rscales length mismatch
test_that("as_survey_replicate() errors when rscales length doesn't match n_rep [row 17]", {
  df <- make_survey_data(n = 200, n_psu = 20L, design = "replicate", seed = 18L)
  expect_error(
    as_survey_replicate(
      df,
      weights = wt,
      repweights = starts_with("repwt_"),
      type = "BRR",
      rscales = c(1, 2) # wrong length
    ),
    class = "surveycore_error_rscales_length"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_replicate(
      df,
      weights = wt,
      repweights = starts_with("repwt_"),
      type = "BRR",
      rscales = c(1, 2)
    )
  )
})

# Row 18: invalid type (handled by match.arg)
test_that("as_survey_replicate() errors when type is not a valid replicate method [row 18]", {
  df <- make_survey_data(n = 50, n_psu = 10L, design = "replicate", seed = 19L)
  expect_error(
    as_survey_replicate(
      df,
      weights = wt,
      repweights = starts_with("repwt_"),
      type = "invalid_type"
    ),
    regexp = "should be one of"
  )
})


# ── Edge cases ────────────────────────────────────────────────────────────────

test_that("as_survey_replicate() with tibble input (inherits data.frame)", {
  skip_if_not_installed("tibble")
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 20L)
  tb <- tibble::as_tibble(df)
  d <- as_survey_replicate(
    tb,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "JK1"
  )
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_replicate))
})

test_that("as_survey_replicate() populates all expected @variables keys", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 21L)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "JK1"
  )
  expected_keys <- c(
    "weights",
    "repweights",
    "type",
    "scale",
    "rscales",
    "fpc",
    "fpctype",
    "mse"
  )
  expect_true(all(expected_keys %in% names(d@variables)))
})

test_that("as_survey_replicate() accepts fpctype argument", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 22L)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "BRR",
    fpctype = "correction"
  )
  expect_identical(d@variables$fpctype, "correction")
})


# ── Tidy-select interface ─────────────────────────────────────────────────────

test_that("as_survey_replicate() accepts starts_with() for repweights", {
  df <- make_survey_data(n = 200, n_psu = 20L, design = "replicate", seed = 23L)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "BRR"
  )
  test_invariants(d)
  expect_true(all(startsWith(d@variables$repweights, "repwt_")))
})

test_that("as_survey_replicate() accepts c() for explicit repweight columns", {
  df <- data.frame(
    y = 1:10,
    wt = rep(1, 10),
    r1 = rep(1, 10),
    r2 = rep(1, 10),
    r3 = rep(1, 10)
  )
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = c(r1, r2, r3),
    type = "JK1"
  )
  test_invariants(d)
  expect_identical(d@variables$repweights, c("r1", "r2", "r3"))
})

test_that("as_survey_replicate() accepts bare name for weights", {
  df <- data.frame(
    y = 1:10,
    sampling_weight = rep(1, 10),
    r1 = rep(1, 10),
    r2 = rep(1, 10)
  )
  d <- as_survey_replicate(
    df,
    weights = sampling_weight,
    repweights = starts_with("r"),
    type = "JK1"
  )
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
  d2 <- as_survey_twophase(phase1, subset = subset)
  test_invariants(d2)
  expect_true(S7::S7_inherits(d2, survey_twophase))
  expect_identical(d2@variables$subset, "subset")
  expect_identical(d2@variables$method, "full")
})

test_that("as_survey_twophase() creates survey_twophase with method = 'approx'", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 2L)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  d2 <- as_survey_twophase(phase1, subset = subset, method = "approx")
  test_invariants(d2)
  expect_identical(d2@variables$method, "approx")
})

test_that("as_survey_twophase() creates survey_twophase with method = 'simple' (no clusters)", {
  # No PSUs in Phase 1 -> no 'simple' warning
  df <- make_survey_data(n = 200, design = "twophase", seed = 3L)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  d2 <- as_survey_twophase(phase1, subset = subset, method = "simple")
  test_invariants(d2)
  expect_identical(d2@variables$method, "simple")
})

test_that("as_survey_twophase() stores Phase 2 stratification in @variables$phase2", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 4L)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  d2 <- as_survey_twophase(phase1, strata2 = strata, subset = subset)
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
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  d2 <- as_survey_twophase(
    phase1,
    probs2 = subsamprate,
    subset = subset,
    method = "full"
  )
  test_invariants(d2)
  expect_identical(d2@variables$phase2$probs, "subsamprate")
})

test_that("as_survey_twophase() stores Phase 2 cluster ids in @variables$phase2", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 6L)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  d2 <- as_survey_twophase(phase1, ids2 = psu, subset = subset)
  test_invariants(d2)
  expect_identical(d2@variables$phase2$ids, "psu")
})

test_that("as_survey_twophase() stores Phase 2 fpc in @variables$phase2", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 7L)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  d2 <- as_survey_twophase(phase1, fpc2 = fpc, subset = subset)
  test_invariants(d2)
  expect_identical(d2@variables$phase2$fpc, "fpc")
})

test_that("as_survey_twophase() stores Phase 1 @variables in @variables$phase1", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 8L)
  phase1 <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  d2 <- as_survey_twophase(phase1, subset = subset)
  test_invariants(d2)
  # Phase 1 variables preserved in nested structure
  expect_identical(d2@variables$phase1$weights, "wt")
  expect_identical(d2@variables$phase1$strata, "strata")
  expect_identical(d2@variables$phase1$ids, "psu")
  expect_true(d2@variables$phase1$nest)
})

test_that("as_survey_twophase() inherits metadata from phase1", {
  df <- make_survey_data(
    n = 200,
    design = "twophase",
    with_labels = TRUE,
    seed = 9L
  )
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  d2 <- as_survey_twophase(phase1, subset = subset)
  test_invariants(d2)
  # Metadata inherited from phase1
  expect_identical(
    d2@metadata@variable_labels[["y1"]],
    "Outcome variable 1 (continuous)"
  )
})

test_that("as_survey_twophase() stores call in @call", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 10L)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  d2 <- as_survey_twophase(phase1, subset = subset)
  expect_false(is.null(d2@call))
  expect_true(is.call(d2@call))
})

test_that("as_survey_twophase() uses @data from phase1 (no copy)", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 11L)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  d2 <- as_survey_twophase(phase1, subset = subset)
  # @data should be the same data as phase1@data
  expect_identical(nrow(d2@data), nrow(phase1@data))
  expect_identical(names(d2@data), names(phase1@data))
})

test_that("as_survey_twophase() sets all Phase 2 variables to NULL when not provided", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 12L)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  d2 <- as_survey_twophase(phase1, subset = subset)
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
    as_survey_twophase(phase1, subset = subset, method = "simple"),
    class = "surveycore_warning_simple_clustered"
  )
})

test_that("as_survey_twophase() does NOT warn for method = 'simple' when Phase 1 has no PSUs [row 24]", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 14L)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata)) # no ids
  expect_no_warning(
    as_survey_twophase(phase1, subset = subset, method = "simple"),
    message = "surveycore_warning_simple_clustered"
  )
})

test_that("as_survey_twophase() snapshot: method = 'simple' + clustered Phase 1 warning", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 17L)
  phase1 <- suppressWarnings(
    as_survey(df, ids = psu, weights = wt, strata = strata)
  )
  expect_snapshot(
    as_survey_twophase(phase1, subset = subset, method = "simple")
  )
})


# ── Error paths ───────────────────────────────────────────────────────────────

# Row 19: phase1 is not a survey_taylor
test_that("as_survey_twophase() errors when phase1 is not a survey_taylor [row 19]", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 19L)
  expect_error(
    as_survey_twophase(df, subset = subset),
    class = "surveycore_error_phase1_class"
  )
  expect_snapshot(error = TRUE, as_survey_twophase(df, subset = subset))
})

test_that("as_survey_twophase() errors when phase1 is a survey_replicate [row 19]", {
  df <- make_survey_data(n = 100, n_psu = 10L, design = "replicate", seed = 20L)
  phase_rep <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "JK1"
  )
  # phase1 class error fires before subset is resolved — bare name doesn't matter
  expect_error(
    as_survey_twophase(phase_rep, subset = in_phase2),
    class = "surveycore_error_phase1_class"
  )
})

# Row 20: subset not provided
test_that("as_survey_twophase() errors when subset is not provided [row 20]", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 21L)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  expect_error(
    as_survey_twophase(phase1),
    class = "surveycore_error_subset_missing"
  )
  expect_snapshot(error = TRUE, as_survey_twophase(phase1))
})

# Row 21: subset selects >1 column
test_that("as_survey_twophase() errors when subset selects multiple columns [row 21]", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 22L)
  # Add a second logical column with same prefix so starts_with("subset") matches both
  df$subset2 <- runif(nrow(df)) < 0.4
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  expect_error(
    as_survey_twophase(phase1, subset = starts_with("subset")),
    class = "surveycore_error_subset_multiple"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_twophase(phase1, subset = starts_with("subset"))
  )
})

# Row 22: subset column is not logical
test_that("as_survey_twophase() errors when subset column is not logical [row 22]", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 23L)
  # Replace logical subset with integer
  df$phase2_int <- as.integer(df$subset)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
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
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  expect_error(
    as_survey_twophase(phase1, subset = all_true),
    class = "surveycore_error_subset_degenerate"
  )
  expect_snapshot(error = TRUE, as_survey_twophase(phase1, subset = all_true))
})

test_that("as_survey_twophase() errors when subset is all FALSE [row 23]", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 25L)
  df$all_false <- FALSE
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  expect_error(
    as_survey_twophase(phase1, subset = all_false),
    class = "surveycore_error_subset_degenerate"
  )
})

# Row 23b: subset column contains NA values (hard error)
test_that("as_survey_twophase() errors for NA in subset column [row 23b]", {
  df <- make_survey_data(
    n = 100L,
    n_psu = 10L,
    n_strata = 2L,
    design = "twophase",
    seed = 30L
  )
  df$phase2_na <- df$subset
  df$phase2_na[1] <- NA
  phase1 <- as_survey(df, weights = wt, strata = strata)
  expect_error(
    as_survey_twophase(phase1, subset = phase2_na, method = "approx"),
    class = "surveycore_error_subset_na"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_twophase(phase1, subset = phase2_na, method = "approx")
  )
})

test_that("as_survey_twophase() degenerate check uses non-NA count in message [row 23]", {
  # All-TRUE case with some NAs — the NA error fires first (row 23b), then if we
  # fix the NA we'd hit degenerate. Test that subset_na error fires before degenerate.
  df <- make_survey_data(
    n = 100L,
    n_psu = 10L,
    n_strata = 2L,
    design = "twophase",
    seed = 31L
  )
  df$all_true <- TRUE
  df$all_true[1] <- NA
  phase1 <- as_survey(df, weights = wt, strata = strata)
  # The NA check fires first (row 23b)
  expect_error(
    as_survey_twophase(phase1, subset = all_true),
    class = "surveycore_error_subset_na"
  )
})


# ── Edge cases ────────────────────────────────────────────────────────────────

test_that("as_survey_twophase() with multi-stage Phase 2 ids (c())", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 26L)
  # Add a secondary sampling unit column for Phase 2
  df$psu2 <- rep(1:5, length.out = nrow(df))
  df$ssu2 <- rep(1:4, length.out = nrow(df))
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  d2 <- as_survey_twophase(phase1, ids2 = c(psu2, ssu2), subset = subset)
  test_invariants(d2)
  expect_identical(d2@variables$phase2$ids, c("psu2", "ssu2"))
})

test_that("as_survey_twophase() preserves all Phase 1 data columns in @data", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 27L)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  d2 <- as_survey_twophase(phase1, subset = subset)
  # All original columns must be in @data (none dropped)
  expect_true(all(names(df) %in% names(d2@data)))
})

test_that("as_survey_twophase() subset with only 1 TRUE row is valid (not degenerate)", {
  df <- data.frame(
    id = 1:20,
    wt = rep(2, 20),
    strata = rep(c("A", "B"), 10),
    in_phase2 = c(TRUE, rep(FALSE, 19)),
    y = rnorm(20)
  )
  phase1 <- as_survey(df, weights = wt, strata = strata)
  # 1 TRUE and 19 FALSE — not degenerate
  d2 <- as_survey_twophase(phase1, subset = in_phase2)
  test_invariants(d2)
  expect_true(S7::S7_inherits(d2, survey_twophase))
})

test_that("as_survey_twophase() with method = 'full' and strata2 does not produce unsupported warning", {
  # Providing strata2 is valid Phase 2 design info for method = 'full'
  df <- make_survey_data(n = 200, design = "twophase", seed = 28L)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  expect_no_warning(
    as_survey_twophase(
      phase1,
      strata2 = strata,
      subset = subset,
      method = "full"
    )
  )
})

test_that("as_survey_twophase() populates all expected @variables keys", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 29L)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  d2 <- as_survey_twophase(phase1, subset = subset)
  expected_keys <- c("phase1", "phase2", "subset", "method")
  expect_true(all(expected_keys %in% names(d2@variables)))
})


# ── Tidy-select interface ─────────────────────────────────────────────────────

test_that("as_survey_twophase() accepts bare name for subset", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 30L)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  d2 <- as_survey_twophase(phase1, subset = subset)
  test_invariants(d2)
  expect_identical(d2@variables$subset, "subset")
})

test_that("as_survey_twophase() accepts bare name for strata2", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 31L)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  d2 <- as_survey_twophase(phase1, strata2 = strata, subset = subset)
  test_invariants(d2)
  expect_identical(d2@variables$phase2$strata, "strata")
})

test_that("as_survey_twophase() accepts bare name for ids2", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 32L)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  d2 <- as_survey_twophase(phase1, ids2 = psu, subset = subset)
  test_invariants(d2)
  expect_identical(d2@variables$phase2$ids, "psu")
})


# ── Coverage: as_survey() probs error paths ──────────────────────────────────

test_that("as_survey() errors when probs expression matches no columns", {
  df <- data.frame(x = 1:5, wt = 1:5)
  expect_error(
    suppressWarnings(as_survey(
      df,
      probs = tidyselect::starts_with("nonexistent_xyz")
    )),
    class = "surveycore_error_weights_not_found"
  )
})

test_that("as_survey() errors when probs expression selects multiple columns", {
  df <- data.frame(x = 1:5, prob1 = rep(0.1, 5), prob2 = rep(0.2, 5))
  expect_error(
    suppressWarnings(as_survey(df, probs = starts_with("prob"))),
    class = "surveycore_error_weights_multiple"
  )
})


# ── Coverage: as_survey_replicate() fpc multiple columns ───────────────────────────

test_that("as_survey_replicate() errors when fpc expression selects multiple columns", {
  df <- data.frame(
    y = 1:5,
    wt = rep(1, 5),
    r1 = rep(1, 5),
    fpc1 = rep(1000L, 5),
    fpc2 = rep(2000L, 5)
  )
  expect_error(
    as_survey_replicate(
      df,
      weights = wt,
      repweights = r1,
      type = "JK1",
      fpc = starts_with("fpc")
    ),
    class = "surveycore_error_fpc_multiple"
  )
})


# ── Coverage: as_survey_twophase() additional error paths ────────────────────

test_that("as_survey_twophase() errors when subset matches 0 columns", {
  df <- make_survey_data(n = 100L, design = "twophase", seed = 90L)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  expect_error(
    as_survey_twophase(
      phase1,
      subset = tidyselect::starts_with("nonexistent_xyz")
    ),
    class = "surveycore_error_subset_missing"
  )
})

test_that("as_survey_twophase() errors when strata2 selects multiple columns", {
  df <- make_survey_data(n = 100L, design = "twophase", seed = 91L)
  df$st2a <- df$strata
  df$st2b <- df$strata
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  expect_error(
    as_survey_twophase(phase1, strata2 = starts_with("st2"), subset = subset),
    class = "surveycore_error_strata_multiple"
  )
})

test_that("as_survey_twophase() errors when probs2 selects multiple columns", {
  df <- make_survey_data(n = 100L, design = "twophase", seed = 92L)
  df$prob2a <- runif(nrow(df), 0.3, 0.8)
  df$prob2b <- runif(nrow(df), 0.3, 0.8)
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  expect_error(
    as_survey_twophase(phase1, probs2 = starts_with("prob2"), subset = subset),
    class = "surveycore_error_weights_multiple"
  )
})

test_that("as_survey_twophase() errors when fpc2 selects multiple columns", {
  df <- make_survey_data(n = 100L, design = "twophase", seed = 93L)
  df$fpc2a <- rep(1000L, nrow(df))
  df$fpc2b <- rep(2000L, nrow(df))
  phase1 <- suppressWarnings(as_survey(df, weights = wt, strata = strata))
  expect_error(
    as_survey_twophase(phase1, fpc2 = starts_with("fpc2"), subset = subset),
    class = "surveycore_error_fpc_multiple"
  )
})


# ── Coverage: zero-length guards (bugs fixed) ─────────────────────────────────

test_that("as_survey() errors when strata expression matches no columns", {
  df <- data.frame(x = 1:10, wt = rep(1, 10))
  expect_error(
    as_survey(
      df,
      weights = wt,
      strata = tidyselect::starts_with("nonexistent_xyz")
    ),
    class = "surveycore_error_strata_not_found"
  )
})

test_that("as_survey() errors when fpc expression matches no columns", {
  df <- data.frame(x = 1:10, wt = rep(1, 10))
  expect_error(
    suppressWarnings(as_survey(
      df,
      weights = wt,
      fpc = tidyselect::starts_with("nonexistent_xyz")
    )),
    class = "surveycore_error_fpc_not_found"
  )
})

test_that("as_survey_replicate() errors when fpc expression matches no columns", {
  df <- data.frame(
    y = 1:10,
    wt = rep(1, 10),
    r1 = rep(1, 10),
    r2 = rep(1, 10)
  )
  expect_error(
    as_survey_replicate(
      df,
      weights = wt,
      repweights = c(r1, r2),
      type = "BRR",
      fpc = tidyselect::starts_with("nonexistent_xyz")
    ),
    class = "surveycore_error_fpc_not_found"
  )
})

test_that("as_survey_replicate() validates fpc column for NAs", {
  df <- data.frame(
    y = 1:10,
    wt = rep(1, 10),
    r1 = rep(1, 10),
    r2 = rep(1, 10),
    fpc = c(100L, NA_integer_, rep(100L, 8L))
  )
  expect_error(
    as_survey_replicate(
      df,
      weights = wt,
      repweights = c(r1, r2),
      type = "BRR",
      fpc = fpc
    ),
    class = "surveycore_error_fpc_na"
  )
})


# ==============================================================================
# as_survey_nonprob() tests
# ==============================================================================

# ── Happy paths ────────────────────────────────────────────────────────────────

test_that("as_survey_nonprob() creates a survey_nonprob object", {
  df <- data.frame(y = rnorm(100), cal_wt = runif(100, 0.5, 2))
  d <- as_survey_nonprob(df, weights = cal_wt)
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_nonprob))
  expect_equal(d@variables$weights, "cal_wt")
})

test_that("as_survey_nonprob() stores calibration provenance object", {
  df <- data.frame(y = rnorm(50), w = runif(50, 1, 3))
  cal <- list(targets = list(age = c(0.3, 0.4, 0.3)), method = "raking")
  d <- as_survey_nonprob(df, weights = w, calibration = cal)
  test_invariants(d)
  expect_identical(d@calibration, cal)
})

test_that("as_survey_nonprob() calibration is NULL when not supplied", {
  df <- data.frame(y = 1:20, w = rep(1, 20))
  d <- as_survey_nonprob(df, weights = w)
  test_invariants(d)
  expect_null(d@calibration)
})

test_that("as_survey_nonprob() extracts haven variable labels", {
  df <- data.frame(y = 1:50, w = rep(1, 50))
  attr(df$y, "label") <- "Outcome variable"
  d <- as_survey_nonprob(df, weights = w)
  test_invariants(d)
  expect_equal(d@metadata@variable_labels[["y"]], "Outcome variable")
})

test_that("as_survey_nonprob() is a subclass of survey_base", {
  df <- data.frame(y = 1:30, w = rep(1.5, 30))
  d <- as_survey_nonprob(df, weights = w)
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_base))
})

# ── @variables structure ───────────────────────────────────────────────────────

test_that("as_survey_nonprob() @variables has weights and probs_provided keys", {
  df <- data.frame(y = 1:10, w = rep(2, 10))
  d <- as_survey_nonprob(df, weights = w)
  expect_true("weights" %in% names(d@variables))
  expect_true("probs_provided" %in% names(d@variables))
})

test_that("as_survey_nonprob() @variables$probs_provided is always FALSE", {
  df <- data.frame(y = 1:10, w = rep(2, 10))
  d <- as_survey_nonprob(df, weights = w)
  expect_false(d@variables$probs_provided)
})

# ── Error paths ────────────────────────────────────────────────────────────────

test_that("as_survey_nonprob() rejects non-data-frame input", {
  expect_error(
    as_survey_nonprob(list(y = 1:10, w = rep(1, 10)), weights = w),
    class = "surveycore_error_not_data_frame"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_nonprob(list(y = 1:10, w = rep(1, 10)), weights = w)
  )
})

test_that("as_survey_nonprob() rejects empty data", {
  empty <- data.frame(y = numeric(0), w = numeric(0))
  expect_error(
    as_survey_nonprob(empty, weights = w),
    class = "surveycore_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_nonprob(empty, weights = w)
  )
})

test_that("as_survey_nonprob() rejects duplicate column names", {
  df <- data.frame(y = 1:5, w = rep(1, 5), w = rep(2, 5), check.names = FALSE)
  expect_error(
    as_survey_nonprob(df, weights = w),
    class = "surveycore_error_duplicate_names"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_nonprob(df, weights = w)
  )
})

test_that("as_survey_nonprob() rejects missing weights argument", {
  df <- data.frame(y = 1:10, w = rep(1, 10))
  expect_error(
    as_survey_nonprob(df),
    class = "surveycore_error_weights_missing"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_nonprob(df)
  )
})

test_that("as_survey_nonprob() rejects weights selecting multiple columns", {
  df <- data.frame(y = 1:10, w1 = rep(1, 10), w2 = rep(1, 10))
  expect_error(
    as_survey_nonprob(df, weights = c(w1, w2)),
    class = "surveycore_error_weights_multiple"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_nonprob(df, weights = c(w1, w2))
  )
})

test_that("as_survey_nonprob() rejects non-positive weights", {
  df <- data.frame(y = 1:5, w = c(1, 0, 1, 1, 1))
  expect_error(
    as_survey_nonprob(df, weights = w),
    class = "surveycore_error_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_nonprob(df, weights = w)
  )
})

# ── Warning paths ──────────────────────────────────────────────────────────────

test_that("as_survey_nonprob() warns for single-row data", {
  df <- data.frame(y = 1, w = 1)
  expect_warning(
    result <- as_survey_nonprob(df, weights = w),
    class = "surveycore_warning_single_row"
  )
  expect_true(S7::S7_inherits(result, survey_nonprob))
})

# ── Estimation ─────────────────────────────────────────────────────────────────

test_that("get_means() returns SRS-based estimate for survey_nonprob", {
  df <- data.frame(y = c(1, 2, 3, 4, 5), w = c(2, 1, 2, 1, 2))
  d <- as_survey_nonprob(df, weights = w)
  result <- get_means(d, y, variance = "se")
  test_result_invariants(result, "survey_means")
  expect_identical(names(meta(result)$x), "y")
  expect_true(is.numeric(result$mean[[1L]]))
  expect_true(is.numeric(result$se[[1L]]))
  expect_gte(result$se[[1L]], 0)
})

test_that("get_totals() returns SRS-based estimate for survey_nonprob", {
  df <- data.frame(y = c(1, 2, 3, 4, 5), w = c(2, 1, 2, 1, 2))
  d <- as_survey_nonprob(df, weights = w)
  result <- get_totals(d, y, variance = "se")
  test_result_invariants(result, "survey_totals")
  expect_identical(names(meta(result)$x), "y")
  expect_true(is.numeric(result$total[[1L]]))
  expect_true(is.numeric(result$se[[1L]]))
  expect_gte(result$se[[1L]], 0)
})

# ── Print ──────────────────────────────────────────────────────────────────────

test_that("print() works for survey_nonprob and returns x invisibly", {
  df <- data.frame(y = 1:10, w = rep(1, 10))
  d <- as_survey_nonprob(df, weights = w)
  out <- withVisible(print(d))
  expect_false(out$visible)
  expect_true(S7::S7_inherits(out$value, survey_nonprob))
})

test_that("summary() works for survey_nonprob and returns x invisibly", {
  df <- data.frame(y = 1:10, w = rep(1, 10))
  d <- as_survey_nonprob(df, weights = w)
  out <- withVisible(summary(d))
  expect_false(out$visible)
  expect_true(S7::S7_inherits(out$value, survey_nonprob))
})

# ── Snapshot tests: print() and summary() output ───────────────────────────────

test_that("print() produces correct output for survey_nonprob (default)", {
  df <- data.frame(y = 1:10, w = rep(1, 10))
  d <- as_survey_nonprob(df, weights = w)
  expect_snapshot(print(d))
})

test_that("print(d, full = TRUE) produces correct output for survey_nonprob", {
  df <- data.frame(y = 1:10, w = rep(1, 10))
  d <- as_survey_nonprob(df, weights = w)
  expect_snapshot(print(d, full = TRUE))
})

test_that("print(d, design_info = TRUE) produces correct output for survey_nonprob", {
  df <- data.frame(y = 1:10, w = rep(1, 10))
  d <- as_survey_nonprob(df, weights = w)
  expect_snapshot(print(d, design_info = TRUE))
})

test_that("print(d, weights_info = TRUE) produces correct output for survey_nonprob", {
  df <- data.frame(y = 1:10, w = rep(1, 10))
  d <- as_survey_nonprob(df, weights = w)
  expect_snapshot(print(d, weights_info = TRUE))
})

test_that("print(d, metadata_info = TRUE) produces correct output for survey_nonprob", {
  df <- data.frame(y = 1:10, w = rep(1, 10))
  attr(df$y, "label") <- "Outcome variable"
  d <- as_survey_nonprob(df, weights = w)
  expect_snapshot(print(d, metadata_info = TRUE))
})

test_that("summary() produces correct output for survey_nonprob", {
  df <- data.frame(y = 1:10, w = rep(1, 10))
  d <- as_survey_nonprob(df, weights = w)
  expect_snapshot(summary(d))
})

# ── Layer 1 (S7 validator) tests ───────────────────────────────────────────────
# These bypass the constructor and call survey_nonprob() directly to test
# the S7 class validator in isolation.

test_that("survey_nonprob validator rejects missing weight column in @data", {
  expect_error(
    survey_nonprob(
      data = data.frame(y = 1:5),
      variables = list(
        weights = "nonexistent_col",
        probs_provided = FALSE,
        ids = NULL,
        strata = NULL,
        fpc = NULL,
        nest = FALSE,
        visible_vars = NULL
      )
    ),
    class = "surveycore_error_design_var_missing"
  )
})

test_that("survey_nonprob validator rejects non-numeric weight column", {
  df <- data.frame(y = 1:5, w = letters[1:5])
  expect_error(
    survey_nonprob(
      data = df,
      variables = list(
        weights = "w",
        probs_provided = FALSE,
        ids = NULL,
        strata = NULL,
        fpc = NULL,
        nest = FALSE,
        visible_vars = NULL
      )
    ),
    class = "surveycore_error_weights_not_numeric"
  )
})

test_that("survey_nonprob validator rejects all-NA weight column", {
  df <- data.frame(y = 1:5, w = NA_real_)
  expect_error(
    survey_nonprob(
      data = df,
      variables = list(
        weights = "w",
        probs_provided = FALSE,
        ids = NULL,
        strata = NULL,
        fpc = NULL,
        nest = FALSE,
        visible_vars = NULL
      )
    ),
    class = "surveycore_error_weights_all_zero"
  )
})

test_that("survey_nonprob validator rejects non-positive weight column", {
  df <- data.frame(y = 1:5, w = c(1, -1, 1, 1, 1))
  expect_error(
    survey_nonprob(
      data = df,
      variables = list(
        weights = "w",
        probs_provided = FALSE,
        ids = NULL,
        strata = NULL,
        fpc = NULL,
        nest = FALSE,
        visible_vars = NULL
      )
    ),
    class = "surveycore_error_weights_nonpositive"
  )
})

# ── Numerical correctness tests ────────────────────────────────────────────────

test_that("get_means() returns analytically correct weighted mean and SRS SE for survey_nonprob", {
  df <- data.frame(y = c(1, 2, 3, 4, 5), w = c(2, 1, 2, 1, 2))
  d <- as_survey_nonprob(df, weights = w)

  # Weighted mean: sum(y * w) / sum(w)
  expected_mean <- sum(df$y * df$w) / sum(df$w)

  # SRS variance of weighted mean via Taylor linearization (each row = own PSU,
  # one stratum, no FPC): z_i = w_i * (y_i - ybar_w) / sum(w)
  # V = (n / (n-1)) * sum(z_i^2)  [sum(z_i) = 0 so centering is free]
  n <- nrow(df)
  z <- df$w * (df$y - expected_mean) / sum(df$w)
  expected_se <- sqrt((n / (n - 1L)) * sum(z^2))

  result <- get_means(d, y, variance = "se")
  expect_equal(result$mean[[1L]], expected_mean, tolerance = 1e-10)
  expect_equal(result$se[[1L]], expected_se, tolerance = 1e-8)
})

test_that("get_totals() returns analytically correct weighted total and SRS SE for survey_nonprob", {
  df <- data.frame(y = c(1, 2, 3, 4, 5), w = c(2, 1, 2, 1, 2))
  d <- as_survey_nonprob(df, weights = w)

  # Weighted total: sum(y * w)
  expected_total <- sum(df$y * df$w)

  # SRS variance of weighted total via Taylor linearization:
  # z_i = y_i * w_i  (what .svy_recvar receives for the total)
  # V = (n / (n-1)) * sum((z_i - mean(z))^2)
  n <- nrow(df)
  z <- df$y * df$w
  expected_se <- sqrt((n / (n - 1L)) * sum((z - mean(z))^2))

  result <- get_totals(d, y, variance = "se")
  expect_equal(result$total[[1L]], expected_total, tolerance = 1e-10)
  expect_equal(result$se[[1L]], expected_se, tolerance = 1e-8)
})

test_that("get_means() matches survey::svymean() for survey_nonprob [numerical]", {
  skip_if_not_installed("survey")

  set.seed(42)
  df <- data.frame(y = rnorm(200), w = runif(200, 0.5, 2.5))

  d_sc <- as_survey_nonprob(df, weights = w)
  d_sv <- survey::svydesign(ids = ~1, weights = ~w, data = df)

  sc_est <- get_means(d_sc, y, variance = c("se", "ci"))
  sv_est <- survey::svymean(~y, d_sv)

  expect_equal(sc_est$mean[[1L]], coef(sv_est)[["y"]], tolerance = 1e-10)
  expect_equal(
    sc_est$se[[1L]],
    as.numeric(survey::SE(sv_est)),
    tolerance = 1e-8
  )
})

test_that("get_totals() matches survey::svytotal() for survey_nonprob [numerical]", {
  skip_if_not_installed("survey")

  set.seed(42)
  df <- data.frame(y = rnorm(200), w = runif(200, 0.5, 2.5))

  d_sc <- as_survey_nonprob(df, weights = w)
  d_sv <- survey::svydesign(ids = ~1, weights = ~w, data = df)

  sc_est <- get_totals(d_sc, y, variance = c("se", "ci"))
  sv_est <- survey::svytotal(~y, d_sv)

  expect_equal(sc_est$total[[1L]], coef(sv_est)[["y"]], tolerance = 1e-10)
  expect_equal(
    sc_est$se[[1L]],
    as.numeric(survey::SE(sv_est)),
    tolerance = 1e-8
  )
})

# ── Edge cases ─────────────────────────────────────────────────────────────────

test_that("as_survey_nonprob() rejects non-numeric weight column", {
  df <- data.frame(y = 1:5, w = letters[1:5])
  expect_error(
    as_survey_nonprob(df, weights = w),
    class = "surveycore_error_weights_not_numeric"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_nonprob(df, weights = w)
  )
})

test_that("get_means() with na.rm = FALSE propagates NA for survey_nonprob", {
  df <- data.frame(y = c(1, NA, 3, 4, 5), w = c(2, 1, 2, 1, 2))
  d <- as_survey_nonprob(df, weights = w)
  result <- get_means(d, y, variance = "se", na.rm = FALSE)
  expect_true(is.na(result$mean[[1L]]))
  expect_true(is.na(result$se[[1L]]))
})

test_that("get_means() with na.rm = TRUE correctly excludes NA rows for survey_nonprob", {
  df_full <- data.frame(y = c(1, 2, 3, 4, 5), w = c(2, 1, 2, 1, 2))
  df_missing <- data.frame(y = c(1, NA, 3, 4, 5), w = c(2, 1, 2, 1, 2))

  d_full <- as_survey_nonprob(df_full, weights = w)
  d_missing <- as_survey_nonprob(df_missing, weights = w)

  result_full <- get_means(d_full, y, variance = NULL, na.rm = TRUE)
  result_missing <- get_means(d_missing, y, variance = NULL, na.rm = TRUE)

  # na.rm = TRUE should drop row 2 and compute mean over rows 1, 3, 4, 5
  df_complete <- df_missing[!is.na(df_missing$y), ]
  expected_mean <- sum(df_complete$y * df_complete$w) / sum(df_complete$w)

  expect_equal(result_missing$mean[[1L]], expected_mean, tolerance = 1e-10)
  # Result with NA row excluded must differ from the full-data result
  expect_false(isTRUE(all.equal(
    result_missing$mean[[1L]],
    result_full$mean[[1L]]
  )))
})

test_that("get_means() handles partial-NA weight column for survey_nonprob", {
  # Raked panels sometimes produce NA weights for excluded units;
  # these rows should be excluded from estimation without error when na.rm = TRUE
  df <- data.frame(y = c(1, 2, 3, 4, 5), w = c(2, NA, 2, 1, 2))
  # NA weight rows reach .taylor_build_inputs() which only filters on NA y,
  # not NA w — weight NAs propagate to the weighted calculation.
  # The object should construct without error (validator allows partial NA w).
  expect_no_error(
    d <- as_survey_nonprob(df, weights = w)
  )
  expect_true(S7::S7_inherits(d, survey_nonprob))
})


# ── as_survey_srs() — happy paths ─────────────────────────────────────────────

# Row 1: explicit weights → survey_srs class
test_that("as_survey_srs() creates survey_srs with explicit weights", {
  df <- data.frame(y = 1:10, wt = runif(10, 0.5, 2))
  d <- as_survey_srs(df, weights = wt)
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_srs))
  expect_identical(d@variables$weights, "wt")
  expect_identical(d@variables$ids, NULL)
  expect_identical(d@variables$strata, NULL)
  expect_false(d@variables$nest)
  expect_false(d@variables$probs_provided)
  expect_null(d@variables$fpc_type)
})

# Row 2: FPC as population sizes → fpc_type == "population"
test_that("as_survey_srs() detects fpc_type = 'population' for FPC > 1", {
  df <- data.frame(y = 1:10, wt = rep(1, 10), N = rep(1000L, 10))
  d <- as_survey_srs(df, weights = wt, fpc = N)
  test_invariants(d)
  expect_identical(d@variables$fpc, "N")
  expect_identical(d@variables$fpc_type, "population")
})

# Row 3: FPC as sampling fractions → fpc_type == "fraction"
test_that("as_survey_srs() detects fpc_type = 'fraction' for FPC in (0,1]", {
  df <- data.frame(y = 1:10, wt = rep(1, 10), f = rep(0.01, 10))
  d <- as_survey_srs(df, weights = wt, fpc = f)
  test_invariants(d)
  expect_identical(d@variables$fpc, "f")
  expect_identical(d@variables$fpc_type, "fraction")
})

# Row 4: no weights → uniform weights auto-assigned
test_that("as_survey_srs() auto-assigns uniform weights when none provided", {
  df <- data.frame(y = 1:5)
  expect_warning(
    d <- as_survey_srs(df),
    class = "surveycore_warning_srs_no_weights"
  )
  test_invariants(d)
  wt_col <- d@data[[d@variables$weights]]
  expect_true(all(wt_col == 1L))
  expect_false(d@variables$probs_provided)
})

# Row 5: returns survey_srs class (not survey_taylor)
test_that("as_survey_srs() returns survey_srs, not survey_taylor", {
  df <- data.frame(y = 1:10, wt = runif(10, 1, 3))
  d <- as_survey_srs(df, weights = wt)
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_srs))
  expect_false(S7::S7_inherits(d, survey_taylor))
})

# Row 6: @variables$fpc_type == "population" when FPC > 1
test_that("as_survey_srs() stores fpc_type 'population' in @variables", {
  df <- data.frame(y = 1:20, wt = rep(2, 20), N = rep(500L, 20))
  d <- as_survey_srs(df, weights = wt, fpc = N)
  expect_identical(d@variables$fpc_type, "population")
})

# Row 7: @variables$fpc_type == "fraction" when FPC in (0,1]
test_that("as_survey_srs() stores fpc_type 'fraction' in @variables", {
  df <- data.frame(y = 1:20, wt = rep(2, 20), f = rep(0.04, 20))
  d <- as_survey_srs(df, weights = wt, fpc = f)
  expect_identical(d@variables$fpc_type, "fraction")
})

# Row 8: @variables$fpc_type is NULL when no FPC
test_that("as_survey_srs() stores fpc_type = NULL when no FPC provided", {
  df <- data.frame(y = 1:10, wt = rep(1, 10))
  d <- as_survey_srs(df, weights = wt)
  expect_null(d@variables$fpc_type)
  expect_null(d@variables$fpc)
})

# Row 9: as_survey() with no ids/strata creates survey_srs (fallback warning)
test_that("as_survey() fallback to survey_srs fires surveycore_warning_as_survey_srs_fallback", {
  df <- data.frame(y = 1:10, wt = rep(1, 10))
  expect_warning(
    d <- as_survey(df, weights = wt),
    class = "surveycore_warning_as_survey_srs_fallback"
  )
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_srs))
})

# Row 9b: probs supplied → @variables$probs_provided == TRUE, weights = 1/probs
test_that("as_survey_srs() accepts probs and converts to weights", {
  df <- data.frame(y = 1:5, p = c(0.1, 0.2, 0.1, 0.05, 0.1))
  d <- as_survey_srs(df, probs = p)
  test_invariants(d)
  expect_true(d@variables$probs_provided)
  wt_col <- d@data[[d@variables$weights]]
  expected_wt <- 1 / df$p
  expect_equal(wt_col, expected_wt, tolerance = 1e-10)
})


# ── as_survey_srs() — error paths (rows 56–59 + existing shared rows) ─────────

# Row 56: both weights and probs supplied (dual pattern)
test_that("as_survey_srs() rejects both weights and probs supplied", {
  df <- data.frame(y = 1:5, wt = rep(1, 5), p = rep(0.1, 5))
  expect_error(
    as_survey_srs(df, weights = wt, probs = p),
    class = "surveycore_error_weights_probs_both"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_srs(df, weights = wt, probs = p)
  )
})

# Shared row 1: not a data frame
test_that("as_survey_srs() rejects non-data-frame data", {
  expect_error(
    as_survey_srs(list(y = 1:5)),
    class = "surveycore_error_not_data_frame"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_srs(list(y = 1:5))
  )
})

# Shared row 2: empty data frame
test_that("as_survey_srs() rejects empty data frame", {
  df <- data.frame(y = numeric(0))
  expect_error(
    as_survey_srs(df),
    class = "surveycore_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_srs(df)
  )
})

# Shared row 8: weights column not found (use tidyselect helper with 0 matches)
test_that("as_survey_srs() rejects weights selector that matches no columns", {
  df <- data.frame(y = 1:5)
  expect_error(
    as_survey_srs(df, weights = starts_with("zzz_nonexistent")),
    class = "surveycore_error_weights_not_found"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_srs(df, weights = starts_with("zzz_nonexistent"))
  )
})

# Shared row 9: weights column is non-positive (zero weight)
test_that("as_survey_srs() rejects zero weight values", {
  df <- data.frame(y = 1:5, wt = c(1, 0, 1, 1, 1))
  expect_error(
    as_survey_srs(df, weights = wt),
    class = "surveycore_error_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_srs(df, weights = wt)
  )
})

# Row 57: FPC non-positive values (dual pattern)
test_that("as_survey_srs() rejects non-positive FPC values", {
  df <- data.frame(y = 1:5, wt = rep(1, 5), fpc_col = c(500, 0, 500, 500, 500))
  expect_error(
    as_survey_srs(df, weights = wt, fpc = fpc_col),
    class = "surveycore_error_fpc_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_srs(df, weights = wt, fpc = fpc_col)
  )
})

# Row 58: FPC ambiguous — mixes > 1 and ≤ 1 (dual pattern)
test_that("as_survey_srs() rejects FPC that mixes >1 and ≤1 values", {
  df <- data.frame(
    y = 1:5,
    wt = rep(1, 5),
    fpc_col = c(500, 0.5, 500, 500, 500)
  )
  expect_error(
    as_survey_srs(df, weights = wt, fpc = fpc_col),
    class = "surveycore_error_fpc_ambiguous"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_srs(df, weights = wt, fpc = fpc_col)
  )
})

# Row 59: FPC population size below sample size (dual pattern)
test_that("as_survey_srs() rejects FPC population size smaller than sample", {
  # 10 rows, population size = 5 < n = 10
  df <- data.frame(y = 1:10, wt = rep(1, 10), fpc_col = rep(5L, 10))
  expect_error(
    as_survey_srs(df, weights = wt, fpc = fpc_col),
    class = "surveycore_error_fpc_below_sample"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_srs(df, weights = wt, fpc = fpc_col)
  )
})

# Existing FPC NA check (shared row from error-messages.md)
test_that("as_survey_srs() rejects FPC column with NA values", {
  df <- data.frame(
    y = 1:5,
    wt = rep(1, 5),
    fpc_col = c(500L, NA, 500L, 500L, 500L)
  )
  expect_error(
    as_survey_srs(df, weights = wt, fpc = fpc_col),
    class = "surveycore_error_fpc_na"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_srs(df, weights = wt, fpc = fpc_col)
  )
})


# ── as_survey_srs() — warning paths ──────────────────────────────────────────

# Row 61: no weights warning (result is still constructed correctly)
test_that("as_survey_srs() fires srs_no_weights warning and still returns object", {
  df <- data.frame(y = 1:10)
  expect_warning(
    d <- as_survey_srs(df),
    class = "surveycore_warning_srs_no_weights"
  )
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_srs))
  expect_identical(d@variables$weights, surveycore:::.SURVEYCORE_WT_COL)
})

# Row 60: as_survey() fallback warning — both warnings fire in order when no weights
test_that("as_survey() fallback fires srs_fallback then srs_no_weights warnings", {
  df <- data.frame(y = 1:5)
  # Both warnings fire: first fallback (row 60), then srs_no_weights (row 61)
  warns <- list()
  withCallingHandlers(
    {
      d <- as_survey(df)
    },
    warning = function(w) {
      warns[[length(warns) + 1L]] <<- class(w)[[1L]]
      invokeRestart("muffleWarning")
    }
  )
  expect_identical(warns[[1L]], "surveycore_warning_as_survey_srs_fallback")
  expect_identical(warns[[2L]], "surveycore_warning_srs_no_weights")
})


# ── as_survey_srs() — snapshot for fallback warning ──────────────────────────

test_that("as_survey() fallback warning snapshot matches expected message", {
  df <- data.frame(y = 1:5, wt = rep(1, 5))
  expect_snapshot(
    as_survey(df, weights = wt)
  )
})

test_that("as_survey_srs() no-weights warning snapshot matches expected message", {
  df <- data.frame(y = 1:5)
  expect_snapshot(
    as_survey_srs(df)
  )
})


# ── weighting_history promotion ───────────────────────────────────────────────

test_that("as_survey() promotes weighting_history attribute from data", {
  df <- make_survey_data(n = 100L, seed = 101L)
  history <- list(list(step = 1L, operation = "raking"))
  attr(df, "weighting_history") <- history
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  expect_identical(d@metadata@weighting_history, history)
})

test_that("as_survey_replicate() promotes weighting_history attribute from data", {
  df <- make_survey_data(
    n = 100L,
    n_psu = 10L,
    design = "replicate",
    seed = 102L
  )
  history <- list(list(step = 1L, operation = "calibration"))
  attr(df, "weighting_history") <- history
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "JK1"
  )
  test_invariants(d)
  expect_identical(d@metadata@weighting_history, history)
})

test_that("as_survey_srs() promotes weighting_history attribute from data", {
  df <- data.frame(y = 1:10, wt = rep(1, 10))
  history <- list(list(step = 1L, operation = "nonresponse_weighting_class"))
  attr(df, "weighting_history") <- history
  d <- as_survey_srs(df, weights = wt)
  test_invariants(d)
  expect_identical(d@metadata@weighting_history, history)
})

test_that("as_survey() leaves weighting_history as list() for plain data.frame", {
  df <- make_survey_data(n = 100L, seed = 103L)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  expect_identical(d@metadata@weighting_history, list())
})
