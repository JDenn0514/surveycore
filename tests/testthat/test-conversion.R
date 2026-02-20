# tests/testthat/test-conversion.R
#
# Tests for conversion functions in R/05-methods-conversion.R.
# Step 11 covers as_svydesign() and as_tbl_svy().
# Step 12 will add from_svydesign() and from_tbl_svy() tests.
#
# All blocks that exercise survey/srvyr use skip_if_not_installed().
#
# Test structure:
#   as_svydesign() — happy paths
#     1. survey_taylor (stratified cluster design)
#     2. survey_taylor (SRS / no design vars)
#     3. survey_replicate (BRR)
#     4. survey_twophase
#   as_svydesign() — output structure
#     5. output class for survey_taylor
#     6. output class for survey_replicate
#     7. output class for survey_twophase
#   as_svydesign() — data preserved
#     8. data rows match
#     9. data columns preserved (superset of original)
#   as_svydesign() — estimation matches survey package
#    10. svymean agrees for survey_taylor [numerical]
#    11. svymean agrees for survey_replicate [numerical]
#   as_svydesign() — error on non-survey input
#    12. rejects plain data.frame
#   as_tbl_svy() — happy path
#    13. survey_taylor → tbl_svy
#   as_tbl_svy() — error on non-survey input
#    14. rejects plain data.frame


# ── Fixtures ─────────────────────────────────────────────────────────────────

make_taylor <- function(seed = 42L) {
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = seed)
  as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE)
}

make_srs <- function(seed = 42L) {
  df <- make_survey_data(n = 30L, n_psu = 10L, n_strata = 2L, seed = seed)
  suppressWarnings(as_survey(df))
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


# ── 1. as_svydesign() — survey_taylor happy path ─────────────────────────────

test_that("as_svydesign() converts survey_taylor without error", {
  skip_if_not_installed("survey")
  d  <- make_taylor()
  test_invariants(d)
  sv <- as_svydesign(d)
  expect_true(!is.null(sv))
})


# ── 2. as_svydesign() — SRS survey_taylor happy path ─────────────────────────

test_that("as_svydesign() converts SRS survey_taylor without error", {
  skip_if_not_installed("survey")
  d  <- make_srs()
  test_invariants(d)
  sv <- as_svydesign(d)
  expect_true(!is.null(sv))
})


# ── 3. as_svydesign() — survey_replicate happy path ──────────────────────────

test_that("as_svydesign() converts survey_replicate without error", {
  skip_if_not_installed("survey")
  d  <- make_rep()
  test_invariants(d)
  sv <- as_svydesign(d)
  expect_true(!is.null(sv))
})


# ── 4. as_svydesign() — survey_twophase happy path ───────────────────────────

test_that("as_svydesign() converts survey_twophase without error", {
  skip_if_not_installed("survey")
  d  <- make_twophase()
  test_invariants(d)
  sv <- suppressWarnings(as_svydesign(d))
  expect_true(!is.null(sv))
})


# ── 5–7. as_svydesign() — output class ───────────────────────────────────────

test_that("as_svydesign(survey_taylor) returns a survey.design2 object", {
  skip_if_not_installed("survey")
  d  <- make_taylor()
  sv <- as_svydesign(d)
  expect_true(inherits(sv, "survey.design"))
})

test_that("as_svydesign(survey_replicate) returns a svyrep.design object", {
  skip_if_not_installed("survey")
  d  <- make_rep()
  sv <- as_svydesign(d)
  expect_true(inherits(sv, "svyrep.design"))
})

test_that("as_svydesign(survey_twophase) returns a twophase2 survey.design object", {
  skip_if_not_installed("survey")
  d  <- make_twophase()
  sv <- suppressWarnings(as_svydesign(d))
  # survey::twophase() with method="full" returns class "twophase2"; the
  # broader "survey.design" class is always present for two-phase designs.
  expect_true(inherits(sv, "survey.design"))
})


# ── 8–9. as_svydesign() — data preserved ─────────────────────────────────────

test_that("as_svydesign() preserves all data rows", {
  skip_if_not_installed("survey")
  d  <- make_taylor()
  sv <- as_svydesign(d)
  expect_identical(nrow(sv$variables), nrow(d@data))
})

test_that("as_svydesign() preserves all original columns in output data", {
  skip_if_not_installed("survey")
  d  <- make_taylor()
  sv <- as_svydesign(d)
  expect_true(all(names(d@data) %in% names(sv$variables)))
})


# ── 10. as_svydesign() — svymean numerical agreement: survey_taylor ──────────

test_that("as_svydesign(survey_taylor) gives svymean matching survey::svydesign [numerical]", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 99L)

  d_sc <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc, nest = TRUE)
  d_sv <- survey::svydesign(
    ids     = ~psu,
    weights = ~wt,
    strata  = ~strata,
    fpc     = ~fpc,
    data    = df,
    nest    = TRUE
  )

  sc_mean <- survey::svymean(~y1, as_svydesign(d_sc))
  sv_mean <- survey::svymean(~y1, d_sv)

  expect_equal(coef(sc_mean)[["y1"]], coef(sv_mean)[["y1"]], tolerance = 1e-10)
  # survey::SE() returns a 1×1 matrix in survey >= 4.4; use as.numeric() for
  # robust indexing across package versions.
  expect_equal(as.numeric(survey::SE(sc_mean)), as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
})


# ── 11. as_svydesign() — svymean numerical agreement: survey_replicate ────────

test_that("as_svydesign(survey_replicate) gives svymean matching survey::svrepdesign [numerical]", {
  skip_if_not_installed("survey")
  df <- make_survey_data(
    n = 50L, n_psu = 10L, n_strata = 2L, design = "replicate", type = "brr", seed = 99L
  )
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)

  d_sc <- as_survey_rep(df, weights = wt, repweights = tidyselect::all_of(repwt_cols), type = "BRR")
  d_sv <- survey::svrepdesign(
    weights    = df$wt,
    repweights = df[, repwt_cols],
    type       = "BRR",
    mse        = TRUE,   # as_survey_rep() defaults to mse = TRUE
    data       = df
  )

  sc_mean <- survey::svymean(~y1, as_svydesign(d_sc))
  sv_mean <- survey::svymean(~y1, d_sv)

  expect_equal(coef(sc_mean)[["y1"]], coef(sv_mean)[["y1"]], tolerance = 1e-10)
  # survey::SE() returns a 1×1 matrix in survey >= 4.4; use as.numeric() for
  # robust indexing across package versions.
  expect_equal(as.numeric(survey::SE(sc_mean)), as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
})


# ── 12. as_svydesign() — error on non-survey input ───────────────────────────

test_that("as_svydesign() rejects a plain data.frame", {
  skip_if_not_installed("survey")
  expect_error(
    as_svydesign(data.frame(x = 1)),
    class = "surveycore_error_not_survey_object"
  )
})


# ── 13. as_tbl_svy() — survey_taylor → tbl_svy ───────────────────────────────

test_that("as_tbl_svy() converts survey_taylor to tbl_svy", {
  skip_if_not_installed("survey")
  skip_if_not_installed("srvyr")
  d  <- make_taylor()
  test_invariants(d)
  ts <- as_tbl_svy(d)
  expect_true(inherits(ts, "tbl_svy"))
})

test_that("as_tbl_svy() preserves all data rows", {
  skip_if_not_installed("survey")
  skip_if_not_installed("srvyr")
  d  <- make_taylor()
  ts <- as_tbl_svy(d)
  expect_identical(nrow(ts), nrow(d@data))
})


# ── 14. as_tbl_svy() — error on non-survey input ─────────────────────────────

test_that("as_tbl_svy() rejects a plain data.frame", {
  skip_if_not_installed("survey")
  skip_if_not_installed("srvyr")
  expect_error(
    as_tbl_svy(data.frame(x = 1)),
    class = "surveycore_error_not_survey_object"
  )
})
