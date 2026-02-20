# tests/testthat/test-utils.R
#
# Tests for utility functions in R/07-utils.R.
#
# survey_data() is the only exported function.
# .update_design_var_names() and .rename_metadata_keys() live in
# R/02-validators.R and are tested in test-validators.R.
#
# Test structure:
#   1. survey_data() — happy path (all three design types)
#   2. survey_data() — rejects non-survey input
#   3. .get_design_vars_flat() — survey_taylor
#   4. .get_design_vars_flat() — survey_replicate
#   5. .get_design_vars_flat() — survey_twophase
#   6. .get_design_vars_flat() — NULL design variables dropped
#   7. .get_design_vars() — survey_taylor named list
#   8. .get_design_vars() — survey_replicate named list
#   9. .get_design_vars() — survey_twophase named list
#  10. .resolve_tidy_select() — NULL quosure → NULL
#  11. .resolve_tidy_select() — bare name → character vector
#  12. .resolve_tidy_select() — c() → multiple column names
#  13. .resolve_tidy_select() — starts_with() helper
#  14. SURVEYCORE_DOMAIN_COL — correct constant value


# ── Fixtures ─────────────────────────────────────────────────────────────────

make_taylor <- function(seed = 42L) {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = seed)
  as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE)
}

make_rep <- function(seed = 42L) {
  df <- make_survey_data(
    n = 50L, n_psu = 10L, n_strata = 2L,
    design = "replicate", type = "brr", seed = seed
  )
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  as_survey_rep(df, weights = wt, repweights = tidyselect::all_of(repwt_cols), type = "BRR")
}

make_twophase <- function(seed = 42L) {
  df <- make_survey_data(
    n = 60L, n_psu = 10L, n_strata = 2L, design = "twophase", seed = seed
  )
  phase1 <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE)
  suppressWarnings(as_survey_twophase(phase1, subset = phase2_ind))
}


# ── 1. survey_data() — happy path ────────────────────────────────────────────

test_that("survey_data() returns @data as a data.frame for survey_taylor", {
  d <- make_taylor()
  test_invariants(d)
  result <- survey_data(d)
  expect_true(is.data.frame(result))
  expect_identical(result, d@data)
})

test_that("survey_data() returns @data for survey_replicate", {
  d <- make_rep()
  test_invariants(d)
  expect_identical(survey_data(d), d@data)
})

test_that("survey_data() returns @data for survey_twophase", {
  d <- make_twophase()
  test_invariants(d)
  expect_identical(survey_data(d), d@data)
})


# ── 2. survey_data() — rejects non-survey input ──────────────────────────────

test_that("survey_data() rejects a plain data.frame", {
  expect_error(
    survey_data(data.frame(x = 1)),
    class = "surveycore_error_not_survey_object"
  )
})

test_that("survey_data() rejects a list", {
  expect_error(
    survey_data(list(data = data.frame(x = 1))),
    class = "surveycore_error_not_survey_object"
  )
})


# ── 3. .get_design_vars_flat() — survey_taylor ───────────────────────────────

test_that(".get_design_vars_flat() returns all design var names for survey_taylor", {
  d    <- make_taylor()
  test_invariants(d)
  flat <- surveycore:::.get_design_vars_flat(d)
  expect_true(is.character(flat))
  expect_true("psu"    %in% flat)
  expect_true("wt"     %in% flat)
  expect_true("strata" %in% flat)
  expect_true("fpc"    %in% flat)
})

test_that(".get_design_vars_flat() returns unique names only", {
  d    <- make_taylor()
  flat <- surveycore:::.get_design_vars_flat(d)
  expect_identical(flat, unique(flat))
})


# ── 4. .get_design_vars_flat() — survey_replicate ───────────────────────────

test_that(".get_design_vars_flat() returns weights and repweights for survey_replicate", {
  d    <- make_rep()
  test_invariants(d)
  flat <- surveycore:::.get_design_vars_flat(d)
  expect_true("wt" %in% flat)
  repwt_cols <- grep("^repwt_", names(d@data), value = TRUE)
  expect_true(all(repwt_cols %in% flat))
})


# ── 5. .get_design_vars_flat() — survey_twophase ────────────────────────────

test_that(".get_design_vars_flat() returns phase1, phase2, and subset vars for survey_twophase", {
  d    <- make_twophase()
  test_invariants(d)
  flat <- surveycore:::.get_design_vars_flat(d)
  expect_true("psu"        %in% flat)
  expect_true("wt"         %in% flat)
  expect_true("strata"     %in% flat)
  expect_true("fpc"        %in% flat)
  expect_true("phase2_ind" %in% flat)
})


# ── 6. .get_design_vars_flat() — NULL variables dropped ─────────────────────

test_that(".get_design_vars_flat() does not include 'NULL' or NA in result", {
  df <- data.frame(y = 1:5, w = runif(5, 0.5, 2))
  d  <- suppressWarnings(as_survey(df, weights = w))
  test_invariants(d)
  flat <- surveycore:::.get_design_vars_flat(d)
  expect_false("NULL" %in% flat)
  expect_false(any(is.na(flat)))
})


# ── 7. .get_design_vars() — survey_taylor named list ────────────────────────

test_that(".get_design_vars() returns a named list for survey_taylor", {
  d    <- make_taylor()
  test_invariants(d)
  vars <- surveycore:::.get_design_vars(d)
  expect_true(is.list(vars))
  expect_true("ids"     %in% names(vars))
  expect_true("weights" %in% names(vars))
  expect_true("strata"  %in% names(vars))
  expect_true("fpc"     %in% names(vars))
})

test_that(".get_design_vars() omits NULL slots for SRS design (survey_taylor)", {
  df <- data.frame(y = 1:5, w = runif(5, 0.5, 2))
  d  <- suppressWarnings(as_survey(df, weights = w))
  test_invariants(d)
  vars <- surveycore:::.get_design_vars(d)
  # ids, strata, fpc are NULL — they should be absent
  expect_false("ids"    %in% names(vars))
  expect_false("strata" %in% names(vars))
  expect_false("fpc"    %in% names(vars))
})

test_that(".get_design_vars() can be unlist()ed to a char vector", {
  d    <- make_taylor()
  vars <- surveycore:::.get_design_vars(d)
  flat <- unlist(vars, use.names = FALSE)
  expect_true(is.character(flat))
  expect_true("wt" %in% flat)
})


# ── 8. .get_design_vars() — survey_replicate named list ─────────────────────

test_that(".get_design_vars() returns weights and repweights for survey_replicate", {
  d    <- make_rep()
  test_invariants(d)
  vars <- surveycore:::.get_design_vars(d)
  expect_true("weights"    %in% names(vars))
  expect_true("repweights" %in% names(vars))
  expect_false("ids"       %in% names(vars))
  expect_false("strata"    %in% names(vars))
})


# ── 9. .get_design_vars() — survey_twophase named list ──────────────────────

test_that(".get_design_vars() returns phase1 vars and subset for survey_twophase", {
  d    <- make_twophase()
  test_invariants(d)
  vars <- surveycore:::.get_design_vars(d)
  expect_true("ids"     %in% names(vars))
  expect_true("weights" %in% names(vars))
  expect_true("strata"  %in% names(vars))
  expect_true("subset"  %in% names(vars))
})

test_that(".get_design_vars() unlist() gives all design var names for survey_twophase", {
  d    <- make_twophase()
  flat <- unlist(surveycore:::.get_design_vars(d), use.names = FALSE)
  expect_true("psu"        %in% flat)
  expect_true("wt"         %in% flat)
  expect_true("phase2_ind" %in% flat)
})


# ── 10. .resolve_tidy_select() — NULL quosure → NULL ────────────────────────

test_that(".resolve_tidy_select() returns NULL for a NULL quosure", {
  df     <- data.frame(x = 1:3, y = 4:6)
  result <- surveycore:::.resolve_tidy_select(rlang::quo(NULL), df)
  expect_null(result)
})


# ── 11. .resolve_tidy_select() — bare name → character vector ───────────────

test_that(".resolve_tidy_select() resolves a bare name to a column name", {
  df     <- data.frame(x = 1:3, y = 4:6, wt = runif(3))
  result <- surveycore:::.resolve_tidy_select(rlang::quo(wt), df)
  expect_identical(result, "wt")
})

test_that(".resolve_tidy_select() returns a character vector", {
  df     <- data.frame(x = 1:3, wt = runif(3))
  result <- surveycore:::.resolve_tidy_select(rlang::quo(x), df)
  expect_true(is.character(result))
  expect_length(result, 1L)
})


# ── 12. .resolve_tidy_select() — c() → multiple column names ────────────────

test_that(".resolve_tidy_select() resolves c() to multiple column names", {
  df     <- data.frame(psu = 1:3, ssu = 1:3, y = rnorm(3))
  result <- surveycore:::.resolve_tidy_select(rlang::quo(c(psu, ssu)), df)
  expect_identical(result, c("psu", "ssu"))
})


# ── 13. .resolve_tidy_select() — starts_with() helper ───────────────────────

test_that(".resolve_tidy_select() resolves starts_with() to matching column names", {
  df <- data.frame(
    repwt_1 = runif(3), repwt_2 = runif(3), repwt_3 = runif(3), y = rnorm(3)
  )
  result <- surveycore:::.resolve_tidy_select(
    rlang::quo(tidyselect::starts_with("repwt_")), df
  )
  expect_identical(result, c("repwt_1", "repwt_2", "repwt_3"))
})


# ── 14. SURVEYCORE_DOMAIN_COL — correct constant value ──────────────────────

test_that("SURVEYCORE_DOMAIN_COL is the expected string constant", {
  expect_identical(
    surveycore:::SURVEYCORE_DOMAIN_COL,
    "..surveycore_domain.."
  )
})
