# tests/testthat/test-utils.R
#
# Tests for utility functions in R/07-utils.R.
#
# survey_data() is the only exported function.
# .update_design_var_names() and .rename_metadata_keys() live in
# R/02-validators.R and are tested in test-validators.R.
#
# Test structure:
#   1. survey_data() — happy path (all three design types + survey_nonprob)
#   2. survey_data() — rejects non-survey input
#   3. .get_design_vars_flat() — survey_taylor
#   4. .get_design_vars_flat() — survey_replicate
#   5. .get_design_vars_flat() — survey_twophase (no p2 info)
#   6. .get_design_vars_flat() — NULL design variables dropped
#   7. .get_design_vars_flat() — survey_twophase with p2 design info
#   8. .get_design_vars_flat() — survey_nonprob returns weights column
#   9. .get_design_vars_flat() — SRS-style survey_taylor returns weights (and fpc when set)
#  10. .get_design_vars() — survey_taylor named list
#  11. .get_design_vars() — survey_replicate named list
#  12. .get_design_vars() — survey_twophase named list (no p2 info)
#  13. .get_design_vars() — survey_twophase with p2 design info
#  14. .get_design_vars() — survey_nonprob returns weights entry
#  15. .get_design_vars() — SRS-style survey_taylor returns weights (and fpc when set)
#  16. .resolve_tidy_select() — NULL quosure → NULL
#  17. .resolve_tidy_select() — bare name → character vector
#  18. .resolve_tidy_select() — c() → multiple column names
#  19. .resolve_tidy_select() — starts_with() helper
#  20. .resolve_single_col() — NULL quosure, required = FALSE → NULL
#  21. .resolve_single_col() — NULL quosure, required = TRUE → error
#  22. .resolve_single_col() — single column match → char(1)
#  23. .resolve_single_col() — 0 columns → error with class_none
#  24. .resolve_single_col() — >1 columns → error with class_multi
#  25. .resolve_single_col() — custom error classes forwarded
#  26. SURVEYCORE_DOMAIN_COL — correct constant value
#  27. .SURVEYCORE_WT_COL — correct constant value

# ── Fixtures ─────────────────────────────────────────────────────────────────

make_taylor <- function(seed = 42L) {
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

make_rep <- function(seed = 42L) {
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

make_twophase <- function(seed = 42L) {
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

make_twophase_with_p2 <- function(seed = 42L) {
  set.seed(seed)
  df <- data.frame(
    wt = runif(30L, 0.8, 1.5),
    arm = rep(c("A", "B", "C"), 10L),
    strata = rep(c("S1", "S2"), 15L),
    sampfrac = rep(c(0.5, 0.6, 0.4), 10L),
    in_phase2 = c(rep(TRUE, 15L), rep(FALSE, 15L)),
    y = rnorm(30L)
  )
  phase1 <- as_survey(df, weights = wt, strata = strata)
  as_survey_twophase(
    phase1,
    strata2 = arm,
    probs2 = sampfrac,
    subset = in_phase2,
    method = "full"
  )
}

make_calibrated <- function() {
  df <- data.frame(y = 1:10, w = rep(1, 10))
  as_survey_nonprob(df, weights = w)
}

make_srs <- function(seed = 42L) {
  set.seed(seed)
  df <- data.frame(y = rnorm(20L), w = runif(20L, 0.5, 2.0))
  suppressWarnings(as_survey(df, weights = w))
}

make_srs_with_fpc <- function(seed = 42L) {
  set.seed(seed)
  df <- data.frame(
    y = rnorm(20L),
    w = runif(20L, 0.5, 2.0),
    fpc = rep(200L, 20L)
  )
  suppressWarnings(as_survey(df, weights = w, fpc = fpc))
}


# ── 1. survey_data() — happy path ───────────────────────────────────────────

test_that("survey_data() returns @data as a data.frame for survey_taylor", {
  d <- make_taylor()
  test_invariants(d)
  result <- survey_data(d)
  expect_true(is.data.frame(result))
  expect_identical(result, d@data)
})

test_that("survey_data() returns @data for survey_replicate", {
  d <- make_rep()
  expect_identical(survey_data(d), d@data)
})

test_that("survey_data() returns @data for survey_twophase", {
  d <- make_twophase()
  expect_identical(survey_data(d), d@data)
})

test_that("survey_data() returns @data for survey_nonprob", {
  d <- make_calibrated()
  result <- survey_data(d)
  expect_true(is.data.frame(result))
  expect_identical(result, d@data)
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


# ── 3. .get_design_vars_flat() — survey_taylor ──────────────────────────────

test_that(".get_design_vars_flat() returns all design var names for survey_taylor", {
  d <- make_taylor()
  flat <- surveycore:::.get_design_vars_flat(d)
  expect_true(is.character(flat))
  expect_true("psu" %in% flat)
  expect_true("wt" %in% flat)
  expect_true("strata" %in% flat)
  expect_true("fpc" %in% flat)
})

test_that(".get_design_vars_flat() returns unique names only", {
  d <- make_taylor()
  flat <- surveycore:::.get_design_vars_flat(d)
  expect_identical(flat, unique(flat))
})


# ── 4. .get_design_vars_flat() — survey_replicate ───────────────────────────

test_that(".get_design_vars_flat() returns weights and repweights for survey_replicate", {
  d <- make_rep()
  flat <- surveycore:::.get_design_vars_flat(d)
  expect_true("wt" %in% flat)
  repwt_cols <- grep("^repwt_", names(d@data), value = TRUE)
  expect_true(all(repwt_cols %in% flat))
})


# ── 5. .get_design_vars_flat() — survey_twophase (no p2 info) ───────────────

test_that(".get_design_vars_flat() returns phase1, phase2, and subset vars for survey_twophase", {
  d <- make_twophase()
  flat <- surveycore:::.get_design_vars_flat(d)
  expect_true("psu" %in% flat)
  expect_true("wt" %in% flat)
  expect_true("strata" %in% flat)
  expect_true("fpc" %in% flat)
  expect_true("subset" %in% flat)
})


# ── 6. .get_design_vars_flat() — NULL variables dropped ─────────────────────

test_that(".get_design_vars_flat() does not include 'NULL' or NA in result", {
  df <- data.frame(y = 1:5, w = runif(5, 0.5, 2))
  d <- suppressWarnings(as_survey(df, weights = w))
  test_invariants(d)
  flat <- surveycore:::.get_design_vars_flat(d)
  expect_false("NULL" %in% flat)
  expect_false(any(is.na(flat)))
})


# ── 7. .get_design_vars_flat() — survey_twophase with p2 design info ────────

test_that(".get_design_vars_flat() includes p2 column names for survey_twophase with p2 info", {
  d <- make_twophase_with_p2()
  flat <- surveycore:::.get_design_vars_flat(d)
  # Phase 1 weight column
  expect_true("wt" %in% flat)
  # Phase 2 strata and probs columns
  expect_true("arm" %in% flat)
  expect_true("sampfrac" %in% flat)
  # Subset column
  expect_true("in_phase2" %in% flat)
})

test_that(".get_design_vars_flat() returns unique names for twophase with p2 info", {
  d <- make_twophase_with_p2()
  flat <- surveycore:::.get_design_vars_flat(d)
  expect_identical(flat, unique(flat))
})


# ── 8. .get_design_vars_flat() — survey_nonprob returns weights column ─────

test_that(".get_design_vars_flat() returns weights column name for survey_nonprob", {
  d <- make_calibrated()
  flat <- surveycore:::.get_design_vars_flat(d)
  expect_identical(flat, d@variables$weights)
})


# ── 9. .get_design_vars_flat() — SRS-style survey_taylor returns weights (and fpc) ──

test_that(".get_design_vars_flat() returns weights column name for SRS-style design", {
  d <- make_srs()
  flat <- surveycore:::.get_design_vars_flat(d)
  expect_true(d@variables$weights %in% flat)
})

test_that(".get_design_vars_flat() includes fpc column for SRS-style design with fpc", {
  d <- make_srs_with_fpc()
  flat <- surveycore:::.get_design_vars_flat(d)
  expect_true(d@variables$weights %in% flat)
  expect_true(d@variables$fpc %in% flat)
})

test_that(".get_design_vars_flat() excludes fpc for SRS-style design without fpc", {
  d <- make_srs()
  flat <- surveycore:::.get_design_vars_flat(d)
  expect_null(d@variables$fpc)
  expect_false("fpc" %in% flat)
})


# ── 10. .get_design_vars() — survey_taylor named list ────────────────────────

test_that(".get_design_vars() returns a named list for survey_taylor", {
  d <- make_taylor()
  vars <- surveycore:::.get_design_vars(d)
  expect_true(is.list(vars))
  expect_true("ids" %in% names(vars))
  expect_true("weights" %in% names(vars))
  expect_true("strata" %in% names(vars))
  expect_true("fpc" %in% names(vars))
})

test_that(".get_design_vars() omits NULL slots for SRS design (survey_taylor)", {
  df <- data.frame(y = 1:5, w = runif(5, 0.5, 2))
  d <- suppressWarnings(as_survey(df, weights = w))
  vars <- surveycore:::.get_design_vars(d)
  # ids, strata, fpc are NULL — they should be absent
  expect_false("ids" %in% names(vars))
  expect_false("strata" %in% names(vars))
  expect_false("fpc" %in% names(vars))
})

test_that(".get_design_vars() can be unlist()ed to a char vector", {
  d <- make_taylor()
  vars <- surveycore:::.get_design_vars(d)
  flat <- unlist(vars, use.names = FALSE)
  expect_true(is.character(flat))
  expect_true("wt" %in% flat)
})


# ── 10. .get_design_vars() — survey_replicate named list ────────────────────

test_that(".get_design_vars() returns weights and repweights for survey_replicate", {
  d <- make_rep()
  vars <- surveycore:::.get_design_vars(d)
  expect_true("weights" %in% names(vars))
  expect_true("repweights" %in% names(vars))
  expect_false("ids" %in% names(vars))
  expect_false("strata" %in% names(vars))
})


# ── 11. .get_design_vars() — survey_twophase named list (no p2 info) ────────

test_that(".get_design_vars() returns phase1 vars and subset for survey_twophase", {
  d <- make_twophase()
  vars <- surveycore:::.get_design_vars(d)
  expect_true("ids" %in% names(vars))
  expect_true("weights" %in% names(vars))
  expect_true("strata" %in% names(vars))
  expect_true("subset" %in% names(vars))
})

test_that(".get_design_vars() unlist() gives all design var names for survey_twophase", {
  d <- make_twophase()
  flat <- unlist(surveycore:::.get_design_vars(d), use.names = FALSE)
  expect_true("psu" %in% flat)
  expect_true("wt" %in% flat)
  expect_true("subset" %in% flat)
})


# ── 12. .get_design_vars() — survey_twophase with p2 design info ─────────────

test_that(".get_design_vars() includes strata2 and probs2 slots for twophase with p2 info", {
  d <- make_twophase_with_p2()
  vars <- surveycore:::.get_design_vars(d)
  # Phase 2 info slots present
  expect_true("strata2" %in% names(vars))
  expect_true("probs2" %in% names(vars))
  # ids2 and fpc2 were not provided — absent
  expect_false("ids2" %in% names(vars))
  expect_false("fpc2" %in% names(vars))
})

test_that(".get_design_vars() strata2/probs2 slots hold correct column names", {
  d <- make_twophase_with_p2()
  vars <- surveycore:::.get_design_vars(d)
  expect_identical(vars$strata2, "arm")
  expect_identical(vars$probs2, "sampfrac")
})


# ── 14. .get_design_vars() — survey_nonprob returns weights entry ──────────

test_that(".get_design_vars() returns a list with weights entry for survey_nonprob", {
  d <- make_calibrated()
  vars <- surveycore:::.get_design_vars(d)
  expect_true(is.list(vars))
  expect_true("weights" %in% names(vars))
  expect_identical(vars$weights, d@variables$weights)
})


# ── 15. .get_design_vars() — SRS-style survey_taylor returns weights (and fpc when set) ───

test_that(".get_design_vars() returns weights entry for SRS-style design", {
  d <- make_srs()
  vars <- surveycore:::.get_design_vars(d)
  expect_true(is.list(vars))
  expect_true("weights" %in% names(vars))
  expect_false("fpc" %in% names(vars))
})

test_that(".get_design_vars() includes fpc entry for SRS-style design with fpc", {
  d <- make_srs_with_fpc()
  vars <- surveycore:::.get_design_vars(d)
  expect_true("weights" %in% names(vars))
  expect_true("fpc" %in% names(vars))
  expect_identical(vars$fpc, d@variables$fpc)
})


# ── 16. .resolve_tidy_select() — NULL quosure → NULL ────────────────────────

test_that(".resolve_tidy_select() returns NULL for a NULL quosure", {
  df <- data.frame(x = 1:3, y = 4:6)
  result <- surveycore:::.resolve_tidy_select(rlang::quo(NULL), df)
  expect_null(result)
})


# ── 15. .resolve_tidy_select() — bare name → character vector ───────────────

test_that(".resolve_tidy_select() resolves a bare name to a column name", {
  df <- data.frame(x = 1:3, y = 4:6, wt = runif(3))
  result <- surveycore:::.resolve_tidy_select(rlang::quo(wt), df)
  expect_identical(result, "wt")
})

test_that(".resolve_tidy_select() returns a character vector", {
  df <- data.frame(x = 1:3, wt = runif(3))
  result <- surveycore:::.resolve_tidy_select(rlang::quo(x), df)
  expect_true(is.character(result))
  expect_length(result, 1L)
})


# ── 16. .resolve_tidy_select() — c() → multiple column names ────────────────

test_that(".resolve_tidy_select() resolves c() to multiple column names", {
  df <- data.frame(psu = 1:3, ssu = 1:3, y = rnorm(3))
  result <- surveycore:::.resolve_tidy_select(rlang::quo(c(psu, ssu)), df)
  expect_identical(result, c("psu", "ssu"))
})


# ── 17. .resolve_tidy_select() — starts_with() helper ───────────────────────

test_that(".resolve_tidy_select() resolves starts_with() to matching column names", {
  df <- data.frame(
    repwt_1 = runif(3),
    repwt_2 = runif(3),
    repwt_3 = runif(3),
    y = rnorm(3)
  )
  result <- surveycore:::.resolve_tidy_select(
    rlang::quo(tidyselect::starts_with("repwt_")),
    df
  )
  expect_identical(result, c("repwt_1", "repwt_2", "repwt_3"))
})


# ── 18. .resolve_single_col() — NULL quosure, required = FALSE → NULL ────────

test_that(".resolve_single_col() returns NULL for a NULL quosure when required = FALSE", {
  df <- data.frame(x = 1:3, y = 4:6)
  result <- surveycore:::.resolve_single_col(rlang::quo(NULL), df, "myarg")
  expect_null(result)
})

test_that(".resolve_single_col() returns NULL for a NULL quosure (default required = FALSE)", {
  df <- data.frame(wt = runif(3))
  # Omit required= — defaults to FALSE
  result <- surveycore:::.resolve_single_col(rlang::quo(NULL), df, "weights")
  expect_null(result)
})


# ── 19. .resolve_single_col() — NULL quosure, required = TRUE → error ────────

test_that(".resolve_single_col() errors for a NULL quosure when required = TRUE", {
  df <- data.frame(x = 1:3, y = 4:6)
  expect_error(
    surveycore:::.resolve_single_col(
      rlang::quo(NULL),
      df,
      "myarg",
      required = TRUE
    ),
    class = "surveycore_error_design_var_missing"
  )
})

test_that(".resolve_single_col() required=TRUE error uses class_none", {
  df <- data.frame(x = 1:3)
  expect_error(
    surveycore:::.resolve_single_col(
      rlang::quo(NULL),
      df,
      "weights",
      required = TRUE,
      class_none = "surveycore_error_weights_not_found"
    ),
    class = "surveycore_error_weights_not_found"
  )
})


# ── 20. .resolve_single_col() — single column match → char(1) ────────────────

test_that(".resolve_single_col() returns the column name for a single match", {
  df <- data.frame(x = 1:3, wt = runif(3))
  result <- surveycore:::.resolve_single_col(rlang::quo(wt), df, "weights")
  expect_identical(result, "wt")
})

test_that(".resolve_single_col() returns a character scalar (length 1)", {
  df <- data.frame(a = 1:3, b = 4:6, c = 7:9)
  result <- surveycore:::.resolve_single_col(rlang::quo(b), df, "myarg")
  expect_true(is.character(result))
  expect_length(result, 1L)
})

test_that(".resolve_single_col() resolves starts_with() when exactly one column matches", {
  df <- data.frame(wt_final = runif(3), y = 1:3)
  result <- surveycore:::.resolve_single_col(
    rlang::quo(tidyselect::starts_with("wt_")),
    df,
    "weights"
  )
  expect_identical(result, "wt_final")
})


# ── 21. .resolve_single_col() — 0 columns → error with class_none ────────────

test_that(".resolve_single_col() errors with class_none when 0 columns match", {
  df <- data.frame(x = 1:3, y = 4:6)
  expect_error(
    surveycore:::.resolve_single_col(
      rlang::quo(tidyselect::starts_with("zzz")),
      df,
      "weights"
    ),
    class = "surveycore_error_design_var_missing"
  )
})

test_that(".resolve_single_col() uses caller-supplied class_none for 0-match error", {
  df <- data.frame(x = 1:3)
  expect_error(
    surveycore:::.resolve_single_col(
      rlang::quo(tidyselect::starts_with("zzz")),
      df,
      "fpc",
      class_none = "surveycore_error_fpc_not_found"
    ),
    class = "surveycore_error_fpc_not_found"
  )
})


# ── 22. .resolve_single_col() — >1 columns → error with class_multi ──────────

test_that(".resolve_single_col() errors with class_multi when >1 columns match", {
  df <- data.frame(wt_a = runif(3), wt_b = runif(3), y = 1:3)
  expect_error(
    surveycore:::.resolve_single_col(
      rlang::quo(tidyselect::starts_with("wt_")),
      df,
      "weights"
    ),
    class = "surveycore_error_design_var_missing"
  )
})

test_that(".resolve_single_col() uses caller-supplied class_multi for multi-match error", {
  df <- data.frame(st_a = 1:3, st_b = 1:3, y = 1:3)
  expect_error(
    surveycore:::.resolve_single_col(
      rlang::quo(tidyselect::starts_with("st_")),
      df,
      "strata",
      class_multi = "surveycore_error_strata_multiple"
    ),
    class = "surveycore_error_strata_multiple"
  )
})

test_that(".resolve_single_col() errors when c() selects two columns", {
  df <- data.frame(x = 1:3, y = 1:3, z = 1:3)
  expect_error(
    surveycore:::.resolve_single_col(rlang::quo(c(x, y)), df, "ids"),
    class = "surveycore_error_design_var_missing"
  )
})


# ── 23. .resolve_single_col() — call attribution ──────────────────────────────

test_that(".resolve_single_col() surfaces the calling function name in errors", {
  # When called from a wrapper, the error's call should name the wrapper,
  # not .resolve_single_col() itself (thanks to call = rlang::caller_call()).
  df <- data.frame(x = 1:3)

  .my_wrapper <- function() {
    surveycore:::.resolve_single_col(
      rlang::quo(tidyselect::starts_with("zzz")),
      df,
      "weights"
    )
  }

  err <- tryCatch(.my_wrapper(), error = function(e) e)
  expect_s3_class(err, "surveycore_error_design_var_missing")
  # conditionCall() reflects the immediate caller (.my_wrapper), not
  # .resolve_single_col() — this is the intended UX behavior.
  expect_true(!is.null(conditionCall(err)))
})


# ── 24. SURVEYCORE_DOMAIN_COL — correct constant value ──────────────────────

test_that("SURVEYCORE_DOMAIN_COL is the expected string constant", {
  expect_identical(
    surveycore:::SURVEYCORE_DOMAIN_COL,
    "..surveycore_domain.."
  )
})


# ── 25. .SURVEYCORE_WT_COL — correct constant value ──────────────────────────

test_that(".SURVEYCORE_WT_COL is the expected string constant", {
  expect_identical(
    surveycore:::.SURVEYCORE_WT_COL,
    "..surveycore_wt.."
  )
})

# ---------------------------------------------------------------------------
# Additional coverage: survey_weighting_history() error path
# ---------------------------------------------------------------------------

test_that("survey_weighting_history() errors for non-survey-object input", {
  expect_error(
    survey_weighting_history(list(x = 1)),
    class = "surveycore_error_not_survey_object"
  )
  expect_snapshot(error = TRUE, survey_weighting_history(42))
})

test_that("survey_weighting_history() returns empty list for design with no history", {
  df <- make_survey_data(n = 40, n_psu = 8, n_strata = 2, seed = 999)
  sc <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  result <- survey_weighting_history(sc)
  expect_equal(result, list())
})

# ---------------------------------------------------------------------------
# Additional coverage: .delete_metadata_col() internal function
# ---------------------------------------------------------------------------

test_that(".delete_metadata_col() removes column from all metadata slots", {
  df <- make_survey_data(n = 30, n_psu = 6, n_strata = 2, seed = 1001)
  sc <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  sc <- set_var_label(sc, y1 = "Outcome variable")

  # Confirm label is present
  expect_identical(sc@metadata@variable_labels[["y1"]], "Outcome variable")

  # Delete the metadata column
  sc2 <- surveycore:::.delete_metadata_col(sc, "y1")
  expect_null(sc2@metadata@variable_labels[["y1"]])
  expect_null(sc2@metadata@value_labels[["y1"]])
  expect_null(sc2@metadata@question_prefaces[["y1"]])
  expect_null(sc2@metadata@notes[["y1"]])
  expect_null(sc2@metadata@transformations[["y1"]])
})

test_that(".delete_metadata_col() removes var_extra entry and leaves other variables' payloads", {
  df <- make_survey_data(n = 30, n_psu = 6, n_strata = 2, seed = 1001)
  sc <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  sc <- set_var_extra(
    sc,
    y1 = list(role = "outcome"),
    y2 = list(role = "other")
  )

  sc2 <- surveycore:::.delete_metadata_col(sc, "y1")
  expect_null(sc2@metadata@var_extra[["y1"]])
  expect_identical(sc2@metadata@var_extra[["y2"]], list(role = "other"))
})

test_that(".delete_metadata_col() on a variable with no var_extra payload is a no-op", {
  df <- make_survey_data(n = 30, n_psu = 6, n_strata = 2, seed = 1001)
  sc <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  sc <- set_var_extra(sc, y2 = list(role = "other"))

  sc2 <- surveycore:::.delete_metadata_col(sc, "y1")
  expect_identical(sc2@metadata@var_extra, list(y2 = list(role = "other")))
})

# ---------------------------------------------------------------------------
# .compute_nonprob_scale() — replicate scale helper
# ---------------------------------------------------------------------------

test_that("`.compute_nonprob_scale()` returns correct default for each type", {
  expect_equal(surveycore:::.compute_nonprob_scale("bootstrap", 5L), 1 / 5)
  expect_equal(surveycore:::.compute_nonprob_scale("JK1", 4L), 3 / 4)
  expect_equal(surveycore:::.compute_nonprob_scale("JK2", 10L), 1)
  expect_equal(surveycore:::.compute_nonprob_scale("JKn", 10L), 1)
})


# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# survey_data() on a design built from a labelled frame (spec III.1, VIII.1)
# ---------------------------------------------------------------------------
#
# survey_data() returns @data unchanged, so it is how anything outside the
# package sees the stored state. These blocks read the as_survey() route and
# assert both halves of the storage contract: the haven labelled class is gone,
# and every other attribute the import set is still readable.

# A labelled frame carrying one column of each backing type, plus the SPSS
# variant. make_labelled(), make_labelled_spss() and make_tagged_na() live in
# helper-test-data.R.
.labelled_import_frame <- function(seed = 42L) {
  set.seed(seed)
  df <- data.frame(
    psu = rep(1:10, each = 4L),
    strata = rep(1:2, each = 20L),
    wt = runif(40, 0.5, 2),
    dbl = rep(c(1, 2, 3, 4), 10L),
    int = rep(c(0L, 1L), 20L),
    chr = rep(c("a", "b"), 20L),
    spss = rep(c(1, 2, 98, 99), 10L),
    stringsAsFactors = FALSE
  )
  df$dbl <- make_labelled(
    df$dbl,
    c(`Strongly agree` = 1, Agree = 2, Disagree = 3, `Strongly disagree` = 4),
    "Agreement"
  )
  df$int <- make_labelled(df$int, c(No = 0L, Yes = 1L), "Binary")
  df$chr <- make_labelled(df$chr, c(Alpha = "a", Beta = "b"), "Cohort")
  df$spss <- make_labelled_spss(
    df$spss,
    labels = c(Yes = 1, No = 2, Refused = 98, `Don't know` = 99),
    na_values = c(98, 99),
    na_range = c(98, 99),
    label = "SPSS coded"
  )
  df
}

.labelled_import_design <- function(seed = 42L) {
  as_survey(
    .labelled_import_frame(seed),
    ids = psu,
    weights = wt,
    strata = strata
  )
}

test_that("D-1: survey_data() returns no column carrying the labelled class", {
  out <- survey_data(.labelled_import_design())

  hits <- vapply(out, inherits, logical(1L), "haven_labelled")
  expect_identical(names(out)[hits], character(0))

  spss_hits <- vapply(out, inherits, logical(1L), "haven_labelled_spss")
  expect_identical(names(out)[spss_hits], character(0))
})

test_that("D-2: every previously labelled column is a plain base type", {
  out <- survey_data(.labelled_import_design())

  # The backing type is preserved, so the token differs by input type.
  expect_identical(class(out$dbl), "numeric")
  expect_identical(class(out$int), "integer")
  expect_identical(class(out$chr), "character")
  expect_identical(class(out$spss), "numeric")

  expect_identical(typeof(out$dbl), "double")
  expect_identical(typeof(out$int), "integer")
  expect_identical(typeof(out$chr), "character")
})

test_that("D-3: the label and labels attributes stay readable", {
  out <- survey_data(.labelled_import_design())

  expect_identical(attr(out$dbl, "label", exact = TRUE), "Agreement")
  expect_identical(attr(out$int, "label", exact = TRUE), "Binary")
  expect_identical(attr(out$chr, "label", exact = TRUE), "Cohort")

  expect_identical(
    attr(out$dbl, "labels", exact = TRUE),
    c(`Strongly agree` = 1, Agree = 2, Disagree = 3, `Strongly disagree` = 4)
  )
  expect_identical(
    attr(out$int, "labels", exact = TRUE),
    c(No = 0L, Yes = 1L)
  )
  expect_identical(
    attr(out$chr, "labels", exact = TRUE),
    c(Alpha = "a", Beta = "b")
  )
})

test_that("D-4: the SPSS missing-value attributes stay readable", {
  out <- survey_data(.labelled_import_design())

  expect_identical(attr(out$spss, "na_values", exact = TRUE), c(98, 99))
  expect_identical(attr(out$spss, "na_range", exact = TRUE), c(98, 99))
  expect_identical(attr(out$spss, "label", exact = TRUE), "SPSS coded")
})

test_that("D-5: survey_data() returns a plain frame unchanged", {
  # The early return in .strip_labelled_columns() means a frame with nothing to
  # strip comes back as the identical object, not a rebuilt copy.
  plain <- .labelled_import_frame()
  for (nm in c("dbl", "int", "chr", "spss")) {
    attr(plain[[nm]], "class") <- NULL
  }
  d <- as_survey(plain, ids = psu, weights = wt, strata = strata)

  expect_identical(survey_data(d), plain)
})

test_that("D-6: a caller class stacked above haven_labelled goes too", {
  # attr(x, "class") <- NULL removes the whole class vector, so a class the
  # caller stacked on top goes with it. Accepted, not fixed: spec III.3a gives
  # the reasoning, and NEWS.md records it as this PR's breaking change.
  set.seed(7L)
  df <- data.frame(
    psu = rep(1:10, each = 4L),
    wt = runif(40, 0.5, 2),
    y = rep(c(1, 2, 3, 4), 10L)
  )
  df$y <- make_labelled(df$y, c(A = 1, B = 2, C = 3, D = 4), "Stacked")
  attr(df$y, "class") <- c(
    "my_class",
    "haven_labelled",
    "vctrs_vctr",
    "double"
  )

  out <- survey_data(as_survey(df, ids = psu, weights = wt))

  # A bare base type: the caller's own class is gone with the rest.
  expect_identical(class(out$y), "numeric")
  expect_false(inherits(out$y, "my_class"))
  expect_false(inherits(out$y, "haven_labelled"))
  expect_false(inherits(out$y, "vctrs_vctr"))

  # Every attribute other than class still survives.
  expect_identical(attr(out$y, "label", exact = TRUE), "Stacked")
  expect_identical(
    attr(out$y, "labels", exact = TRUE),
    c(A = 1, B = 2, C = 3, D = 4)
  )
  expect_identical(c(unname(out$y)), rep(c(1, 2, 3, 4), 10L))
})


# ---------------------------------------------------------------------------
# survey_data(haven_class = TRUE) — the rebuild (spec II, VIII.1)
# ---------------------------------------------------------------------------
#
# The rebuild writes the class chain with base R, so none of D-8 to D-15 may
# carry skip_if_not_installed("haven"). That is the observable proof of quality
# gate 11: a user without haven can still produce a properly classed column.
# The rows that hand the result to another package are guarded by that package.

test_that("D-7: survey_data() still strips by default", {
  out <- survey_data(.labelled_import_design())

  hits <- vapply(out, inherits, logical(1L), "haven_labelled")
  expect_identical(names(out)[hits], character(0))
})

test_that("D-8: haven_class = TRUE rebuilds the class on every labelled column", {
  out <- survey_data(.labelled_import_design(), haven_class = TRUE)

  labelled_cols <- c("dbl", "int", "chr", "spss")
  for (nm in labelled_cols) {
    expect_true(inherits(out[[nm]], "haven_labelled"), info = nm)
  }

  # And on no other column. psu, strata and wt never carried a `labels`
  # attribute, so the helper returns them untouched.
  hits <- vapply(out, inherits, logical(1L), "haven_labelled")
  expect_identical(sort(names(out)[hits]), sort(labelled_cols))
})

test_that("D-9: a double-backed column gets the exact three-entry chain", {
  out <- survey_data(.labelled_import_design(), haven_class = TRUE)

  expect_identical(
    class(out$dbl),
    c("haven_labelled", "vctrs_vctr", "double")
  )
})

test_that("D-10: an integer-backed column gets the exact three-entry chain", {
  out <- survey_data(.labelled_import_design(), haven_class = TRUE)

  expect_identical(
    class(out$int),
    c("haven_labelled", "vctrs_vctr", "integer")
  )
})

test_that("D-11: a character-backed column gets the exact three-entry chain", {
  out <- survey_data(.labelled_import_design(), haven_class = TRUE)

  expect_identical(
    class(out$chr),
    c("haven_labelled", "vctrs_vctr", "character")
  )
})

test_that("D-12: na_values alone rebuilds the SPSS four-entry chain", {
  df <- .labelled_import_frame()
  df$spss <- make_labelled_spss(
    rep(c(1, 2, 98, 99), 10L),
    labels = c(Yes = 1, No = 2, Refused = 98, `Don't know` = 99),
    na_values = c(98, 99),
    label = "SPSS coded"
  )
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  out <- survey_data(d, haven_class = TRUE)

  expect_identical(
    class(out$spss),
    c("haven_labelled_spss", "haven_labelled", "vctrs_vctr", "double")
  )
  expect_identical(attr(out$spss, "na_values", exact = TRUE), c(98, 99))
  expect_null(attr(out$spss, "na_range", exact = TRUE))
})

test_that("D-13: na_range alone rebuilds the SPSS four-entry chain", {
  df <- .labelled_import_frame()
  df$spss <- make_labelled_spss(
    rep(c(1, 2, 98, 99), 10L),
    labels = c(Yes = 1, No = 2, Refused = 98, `Don't know` = 99),
    na_range = c(98, 99),
    label = "SPSS coded"
  )
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  out <- survey_data(d, haven_class = TRUE)

  expect_identical(
    class(out$spss),
    c("haven_labelled_spss", "haven_labelled", "vctrs_vctr", "double")
  )
  expect_identical(attr(out$spss, "na_range", exact = TRUE), c(98, 99))
  expect_null(attr(out$spss, "na_values", exact = TRUE))
})

test_that("D-14: strip then rebuild returns the input column identically", {
  df <- .labelled_import_frame()
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  out <- survey_data(d, haven_class = TRUE)

  for (nm in c("dbl", "int", "chr", "spss")) {
    expect_identical(out[[nm]], df[[nm]], info = nm)
  }
})

test_that("D-15: haven_class = TRUE on an unlabelled design changes nothing", {
  d <- make_taylor()

  expect_identical(survey_data(d, haven_class = TRUE), survey_data(d))
})

test_that("D-16: a tagged NA survives the rebuild and keeps its tag", {
  df <- .labelled_import_frame()
  tagged <- rep(c(1, 2, make_tagged_na("a")), length.out = 40L)
  df$tag <- make_labelled(
    tagged,
    c(Yes = 1, No = 2, Refused = make_tagged_na("a")),
    "Tagged"
  )
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  out <- survey_data(d, haven_class = TRUE)

  expect_identical(class(out$tag), c("haven_labelled", "vctrs_vctr", "double"))
  expect_true(all(is.na(c(unname(out$tag))[seq(3L, 39L, by = 3L)])))

  # Reading the tag back needs haven; the value being NA does not.
  skip_if_not_installed("haven")
  expect_identical(haven::na_tag(c(unname(out$tag))[[3L]]), "a")
})

test_that("D-17: haven::as_factor() on the rebuilt column returns the labels", {
  skip_if_not_installed("haven")
  out <- survey_data(.labelled_import_design(), haven_class = TRUE)

  expect_identical(
    as.character(haven::as_factor(out$dbl)),
    rep(c("Strongly agree", "Agree", "Disagree", "Strongly disagree"), 10L)
  )
})

test_that("D-18: haven::as_factor() on the stripped column returns the codes", {
  skip_if_not_installed("haven")
  out <- survey_data(.labelled_import_design())

  expect_identical(
    as.character(haven::as_factor(out$dbl)),
    rep(c("1", "2", "3", "4"), 10L)
  )
})

test_that("D-19: labelled::to_factor() on the rebuilt column returns the labels", {
  skip_if_not_installed("labelled")
  out <- survey_data(.labelled_import_design(), haven_class = TRUE)

  expect_identical(
    as.character(labelled::to_factor(out$dbl)),
    rep(c("Strongly agree", "Agree", "Disagree", "Strongly disagree"), 10L)
  )
})

test_that("D-20: a rebuilt column round trips through haven::write_sav()", {
  skip_if_not_installed("haven")
  out <- survey_data(.labelled_import_design(), haven_class = TRUE)
  path <- withr::local_tempfile(fileext = ".sav")

  haven::write_sav(out[c("dbl", "int")], path)
  back <- haven::read_sav(path)

  expect_identical(
    attr(back$dbl, "labels", exact = TRUE),
    c(`Strongly agree` = 1, Agree = 2, Disagree = 3, `Strongly disagree` = 4)
  )
  expect_identical(attr(back$int, "labels", exact = TRUE), c(No = 0, Yes = 1))
})

test_that("D-21: haven::write_sav() raises on a column holding a tagged NA", {
  # The .sav format has no room for a tagged NA, so haven raises when it writes
  # one. Nothing here causes it: a column built straight from haven's own
  # constructor, with no strip and no rebuild involved, fails identically. The
  # row is a fence, so nobody attributes the failure to haven_class = TRUE.
  skip_if_not_installed("haven")
  df <- .labelled_import_frame()
  df$tag <- make_labelled(
    rep(c(1, 2, make_tagged_na("a")), length.out = 40L),
    c(Yes = 1, No = 2, Refused = make_tagged_na("a")),
    "Tagged"
  )
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  out <- survey_data(d, haven_class = TRUE)
  path <- withr::local_tempfile(fileext = ".sav")

  expect_error(haven::write_sav(out["tag"], path))
})

test_that("D-22: haven_class rejects anything but a length-one logical", {
  d <- make_taylor()

  expect_error(
    survey_data(d, haven_class = "yes"),
    class = "surveycore_error_haven_class_not_logical"
  )
  expect_error(
    survey_data(d, haven_class = NA),
    class = "surveycore_error_haven_class_not_logical"
  )
  expect_error(
    survey_data(d, haven_class = c(TRUE, TRUE)),
    class = "surveycore_error_haven_class_not_logical"
  )
  expect_error(
    survey_data(d, haven_class = NULL),
    class = "surveycore_error_haven_class_not_logical"
  )

  expect_snapshot(error = TRUE, survey_data(d, haven_class = "yes"))
  expect_snapshot(error = TRUE, survey_data(d, haven_class = NA))
  expect_snapshot(error = TRUE, survey_data(d, haven_class = c(TRUE, TRUE)))
  expect_snapshot(error = TRUE, survey_data(d, haven_class = NULL))
})

test_that("D-23: survey_data() still rejects a non-survey object", {
  expect_error(
    survey_data(data.frame(x = 1), haven_class = TRUE),
    class = "surveycore_error_not_survey_object"
  )
  expect_snapshot(error = TRUE, survey_data(42))
})

# ── X. Behaviour worth covering that matches no numbered row ─────────────────
#
# An `X-` label claims no row identifier.

test_that("X-16: the stored values equal the plain-input values", {
  plain <- .labelled_import_frame()
  for (nm in c("dbl", "int", "chr", "spss")) {
    attr(plain[[nm]], "class") <- NULL
  }
  d <- as_survey(plain, ids = psu, weights = wt, strata = strata)

  expect_identical(survey_data(.labelled_import_design()), survey_data(d))
})

test_that("X-17: a tagged NA survives the strip unchanged", {
  df <- .labelled_import_frame()
  tagged <- rep(c(1, 2, make_tagged_na("a")), length.out = 40L)
  df$tag <- make_labelled(
    tagged,
    c(Yes = 1, No = 2, Refused = make_tagged_na("a")),
    "Tagged"
  )
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  out <- survey_data(d)

  # Byte-for-byte identical to the payload the import produced. writeBin()
  # rejects an object carrying attributes, so drop them for the comparison —
  # the attributes themselves are D-3's and D-4's subject.
  bytes <- function(x) writeBin(c(unname(x)), raw(), endian = "little")
  expect_identical(bytes(out$tag), bytes(tagged))
  expect_true(all(is.na(out$tag[seq(3L, 39L, by = 3L)])))

  skip_if_not_installed("haven")
  expect_identical(haven::na_tag(out$tag[[3L]]), "a")
})
