# tests/testthat/test-conversion.R
#
# Tests for conversion functions in R/05-methods-conversion.R.
# Step 11: as_svydesign(), as_tbl_svy()
# Step 12: from_svydesign(), from_tbl_svy()
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
#   from_svydesign() — happy paths
#    15. svydesign (Taylor) → survey_taylor
#    16. svyrep.design (BRR) → survey_replicate
#    17. twophase → survey_twophase
#   from_svydesign() — output class
#    18. returns survey_taylor for svydesign
#    19. returns survey_replicate for svyrep.design
#    20. returns survey_twophase for twophase
#   from_svydesign() — data preserved
#    21. data rows match
#    22. original columns preserved in @data
#   from_svydesign() — design variables recovered
#    23. strata column recovered from Taylor design
#    24. repweight columns recovered from replicate design
#   from_svydesign() — numerical round-trip
#    25. svymean round-trip for Taylor design [numerical]
#    26. svymean round-trip for replicate design [numerical]
#   from_svydesign() — error on non-survey input
#    27. rejects plain data.frame
#   as_svydesign() — survey_taylor with no ids uses ids = ~1
#    37. as_svydesign(survey_taylor) with ids = NULL produces ids = ~1
#   from_svydesign() — twophase method unknown fallback warning
#    38. warns when twophase x$method is unrecognised
#   from_tbl_svy() — happy path
#    28. tbl_svy → survey_taylor
#   from_tbl_svy() — error on non-tbl_svy input
#    29. rejects plain data.frame

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

make_srs <- function(seed = 42L) {
  df <- make_survey_data(n = 30L, n_psu = 10L, n_strata = 2L, seed = seed)
  as_survey(df, weights = wt)
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


# ── 1. as_svydesign() — survey_taylor happy path ─────────────────────────────

test_that("as_svydesign() converts survey_taylor without error", {
  skip_if_not_installed("survey")
  d <- make_taylor()
  test_invariants(d)
  sv <- as_svydesign(d)
  expect_true(!is.null(sv))
})


# ── 2. as_svydesign() — SRS survey_taylor happy path ─────────────────────────

test_that("as_svydesign() converts SRS-style survey_taylor without error", {
  skip_if_not_installed("survey")
  d <- make_srs()
  sv <- as_svydesign(d)
  expect_true(!is.null(sv))
})


# ── 3. as_svydesign() — survey_replicate happy path ──────────────────────────

test_that("as_svydesign() converts survey_replicate without error", {
  skip_if_not_installed("survey")
  d <- make_rep()
  sv <- as_svydesign(d)
  expect_true(!is.null(sv))
})


# ── 4. as_svydesign() — survey_twophase happy path ───────────────────────────

test_that("as_svydesign() converts survey_twophase without error", {
  skip_if_not_installed("survey")
  d <- make_twophase()
  sv <- suppressWarnings(as_svydesign(d))
  expect_true(!is.null(sv))
})


# ── 5–7. as_svydesign() — output class ───────────────────────────────────────

test_that("as_svydesign(survey_taylor) returns a survey.design2 object", {
  skip_if_not_installed("survey")
  d <- make_taylor()
  sv <- as_svydesign(d)
  expect_true(inherits(sv, "survey.design"))
})

test_that("as_svydesign(survey_replicate) returns a svyrep.design object", {
  skip_if_not_installed("survey")
  d <- make_rep()
  sv <- as_svydesign(d)
  expect_true(inherits(sv, "svyrep.design"))
})

test_that("as_svydesign(survey_twophase) returns a twophase2 survey.design object", {
  skip_if_not_installed("survey")
  d <- make_twophase()
  sv <- suppressWarnings(as_svydesign(d))
  # survey::twophase() with method="full" returns class "twophase2"; the
  # broader "survey.design" class is always present for two-phase designs.
  expect_true(inherits(sv, "survey.design"))
})


# ── 8–9. as_svydesign() — data preserved ─────────────────────────────────────

test_that("as_svydesign() preserves all data rows", {
  skip_if_not_installed("survey")
  d <- make_taylor()
  sv <- as_svydesign(d)
  expect_identical(nrow(sv$variables), nrow(d@data))
})

test_that("as_svydesign() preserves all original columns in output data", {
  skip_if_not_installed("survey")
  d <- make_taylor()
  sv <- as_svydesign(d)
  expect_true(all(names(d@data) %in% names(sv$variables)))
})


# ── 10. as_svydesign() — svymean numerical agreement: survey_taylor ──────────

test_that("as_svydesign(survey_taylor) gives svymean matching survey::svydesign [numerical]", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 99L)

  d_sc <- as_survey(
    df,
    ids = psu,
    weights = wt,
    strata = strata,
    fpc = fpc,
    nest = TRUE
  )
  d_sv <- survey::svydesign(
    ids = ~psu,
    weights = ~wt,
    strata = ~strata,
    fpc = ~fpc,
    data = df,
    nest = TRUE
  )

  sc_mean <- survey::svymean(~y1, as_svydesign(d_sc))
  sv_mean <- survey::svymean(~y1, d_sv)

  expect_equal(coef(sc_mean)[["y1"]], coef(sv_mean)[["y1"]], tolerance = 1e-10)
  # survey::SE() returns a 1×1 matrix in survey >= 4.4; use as.numeric() for
  # robust indexing across package versions.
  expect_equal(
    as.numeric(survey::SE(sc_mean)),
    as.numeric(survey::SE(sv_mean)),
    tolerance = 1e-8
  )
})


# ── 11. as_svydesign() — svymean numerical agreement: survey_replicate ────────

test_that("as_svydesign(survey_replicate) gives svymean matching survey::svrepdesign [numerical]", {
  skip_if_not_installed("survey")
  df <- make_survey_data(
    n = 50L,
    n_psu = 10L,
    n_strata = 2L,
    design = "replicate",
    type = "brr",
    seed = 99L
  )
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)

  d_sc <- as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::all_of(repwt_cols),
    type = "BRR"
  )
  d_sv <- survey::svrepdesign(
    weights = df$wt,
    repweights = df[, repwt_cols],
    type = "BRR",
    mse = TRUE, # as_survey_replicate() defaults to mse = TRUE
    data = df
  )

  sc_mean <- survey::svymean(~y1, as_svydesign(d_sc))
  sv_mean <- survey::svymean(~y1, d_sv)

  expect_equal(coef(sc_mean)[["y1"]], coef(sv_mean)[["y1"]], tolerance = 1e-10)
  # survey::SE() returns a 1×1 matrix in survey >= 4.4; use as.numeric() for
  # robust indexing across package versions.
  expect_equal(
    as.numeric(survey::SE(sc_mean)),
    as.numeric(survey::SE(sv_mean)),
    tolerance = 1e-8
  )
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
  d <- make_taylor()
  ts <- as_tbl_svy(d)
  expect_true(inherits(ts, "tbl_svy"))
})

test_that("as_tbl_svy() preserves all data rows", {
  skip_if_not_installed("survey")
  skip_if_not_installed("srvyr")
  d <- make_taylor()
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


# ── 15–17. from_svydesign() — happy paths ────────────────────────────────────

test_that("from_svydesign() converts svydesign to survey_taylor without error", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 42L)
  sv <- survey::svydesign(
    ids = ~psu,
    weights = ~wt,
    strata = ~strata,
    fpc = ~fpc,
    data = df,
    nest = TRUE
  )
  d <- from_svydesign(sv)
  expect_true(!is.null(d))
})

test_that("from_svydesign() converts svyrep.design to survey_replicate without error", {
  skip_if_not_installed("survey")
  df <- make_survey_data(
    n = 50L,
    n_psu = 10L,
    n_strata = 2L,
    design = "replicate",
    type = "brr",
    seed = 42L
  )
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  sv <- survey::svrepdesign(
    weights = df$wt,
    repweights = df[, repwt_cols],
    type = "BRR",
    mse = TRUE,
    data = df
  )
  d <- from_svydesign(sv)
  expect_true(!is.null(d))
})

test_that("from_svydesign() converts twophase design to survey_twophase without error", {
  skip_if_not_installed("survey")
  df <- make_survey_data(
    n = 60L,
    n_psu = 10L,
    n_strata = 2L,
    design = "twophase",
    seed = 42L
  )
  phase1 <- as_survey(
    df,
    ids = psu,
    weights = wt,
    strata = strata,
    fpc = fpc,
    nest = TRUE
  )
  d_sc <- as_survey_twophase(phase1, subset = subset)
  sv_tp <- suppressWarnings(as_svydesign(d_sc))
  d <- suppressWarnings(from_svydesign(sv_tp))
  expect_true(!is.null(d))
})


# ── 18–20. from_svydesign() — output class ───────────────────────────────────

test_that("from_svydesign(svydesign) returns a survey_taylor object", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 42L)
  sv <- survey::svydesign(
    ids = ~psu,
    weights = ~wt,
    strata = ~strata,
    fpc = ~fpc,
    data = df,
    nest = TRUE
  )
  d <- from_svydesign(sv)
  expect_true(S7::S7_inherits(d, survey_taylor))
})

test_that("from_svydesign(svyrep.design) returns a survey_replicate object", {
  skip_if_not_installed("survey")
  df <- make_survey_data(
    n = 50L,
    n_psu = 10L,
    n_strata = 2L,
    design = "replicate",
    type = "brr",
    seed = 42L
  )
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  sv <- survey::svrepdesign(
    weights = df$wt,
    repweights = df[, repwt_cols],
    type = "BRR",
    mse = TRUE,
    data = df
  )
  d <- from_svydesign(sv)
  expect_true(S7::S7_inherits(d, survey_replicate))
})

test_that("from_svydesign(twophase) returns a survey_twophase object", {
  skip_if_not_installed("survey")
  df <- make_survey_data(
    n = 60L,
    n_psu = 10L,
    n_strata = 2L,
    design = "twophase",
    seed = 42L
  )
  phase1 <- as_survey(
    df,
    ids = psu,
    weights = wt,
    strata = strata,
    fpc = fpc,
    nest = TRUE
  )
  d_sc <- as_survey_twophase(phase1, subset = subset)
  sv_tp <- suppressWarnings(as_svydesign(d_sc))
  d <- suppressWarnings(from_svydesign(sv_tp))
  expect_true(S7::S7_inherits(d, survey_twophase))
})


# ── 21–22. from_svydesign() — data preserved ─────────────────────────────────

test_that("from_svydesign() preserves all data rows", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 42L)
  sv <- survey::svydesign(
    ids = ~psu,
    weights = ~wt,
    strata = ~strata,
    fpc = ~fpc,
    data = df,
    nest = TRUE
  )
  d <- from_svydesign(sv)
  expect_identical(nrow(d@data), nrow(df))
})

test_that("from_svydesign() preserves original columns in @data", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 42L)
  sv <- survey::svydesign(
    ids = ~psu,
    weights = ~wt,
    strata = ~strata,
    fpc = ~fpc,
    data = df,
    nest = TRUE
  )
  d <- from_svydesign(sv)
  expect_true(all(names(df) %in% names(d@data)))
})


# ── 23–24. from_svydesign() — design variables recovered ─────────────────────

test_that("from_svydesign() recovers strata column name from Taylor design", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 42L)
  sv <- survey::svydesign(
    ids = ~psu,
    weights = ~wt,
    strata = ~strata,
    fpc = ~fpc,
    data = df,
    nest = TRUE
  )
  d <- from_svydesign(sv)
  expect_identical(d@variables$strata, "strata")
})

test_that("from_svydesign() recovers replicate weight column names", {
  skip_if_not_installed("survey")
  df <- make_survey_data(
    n = 50L,
    n_psu = 10L,
    n_strata = 2L,
    design = "replicate",
    type = "brr",
    seed = 42L
  )
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  sv <- survey::svrepdesign(
    weights = df$wt,
    repweights = df[, repwt_cols],
    type = "BRR",
    mse = TRUE,
    data = df
  )
  d <- from_svydesign(sv)
  expect_identical(d@variables$repweights, repwt_cols)
})


# ── 25–26. from_svydesign() — numerical round-trip ───────────────────────────

test_that("from_svydesign() + as_svydesign() Taylor round-trip agrees [numerical]", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, seed = 77L)

  # Direct survey design
  sv_direct <- survey::svydesign(
    ids = ~psu,
    weights = ~wt,
    strata = ~strata,
    fpc = ~fpc,
    data = df,
    nest = TRUE
  )

  # Round-trip: survey → surveycore → survey
  d_sc <- from_svydesign(sv_direct)
  sv_rt <- as_svydesign(d_sc)

  m_direct <- survey::svymean(~y1, sv_direct)
  m_rt <- survey::svymean(~y1, sv_rt)

  expect_equal(coef(m_direct)[["y1"]], coef(m_rt)[["y1"]], tolerance = 1e-10)
  expect_equal(
    as.numeric(survey::SE(m_direct)),
    as.numeric(survey::SE(m_rt)),
    tolerance = 1e-8
  )
})

test_that("from_svydesign() + as_svydesign() replicate round-trip agrees [numerical]", {
  skip_if_not_installed("survey")
  df <- make_survey_data(
    n = 50L,
    n_psu = 10L,
    n_strata = 2L,
    design = "replicate",
    type = "brr",
    seed = 77L
  )
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)

  sv_direct <- survey::svrepdesign(
    weights = df$wt,
    repweights = df[, repwt_cols],
    type = "BRR",
    mse = TRUE,
    data = df
  )

  d_sc <- from_svydesign(sv_direct)
  sv_rt <- as_svydesign(d_sc)

  m_direct <- survey::svymean(~y1, sv_direct)
  m_rt <- survey::svymean(~y1, sv_rt)

  expect_equal(coef(m_direct)[["y1"]], coef(m_rt)[["y1"]], tolerance = 1e-10)
  expect_equal(
    as.numeric(survey::SE(m_direct)),
    as.numeric(survey::SE(m_rt)),
    tolerance = 1e-8
  )
})


# ── 27. from_svydesign() — error on non-survey input ─────────────────────────

test_that("from_svydesign() rejects a plain data.frame", {
  skip_if_not_installed("survey")
  expect_error(
    from_svydesign(data.frame(x = 1)),
    class = "surveycore_error_not_survey_design"
  )
})


# ── 28. from_tbl_svy() — happy path ──────────────────────────────────────────

test_that("from_tbl_svy() converts tbl_svy to survey_taylor", {
  skip_if_not_installed("survey")
  skip_if_not_installed("srvyr")
  d <- make_taylor()
  ts <- as_tbl_svy(d)
  d2 <- from_tbl_svy(ts)
  expect_true(S7::S7_inherits(d2, survey_taylor))
  expect_identical(nrow(d2@data), nrow(d@data))
})


# ── 29. from_tbl_svy() — error on non-tbl_svy input ─────────────────────────

test_that("from_tbl_svy() rejects a plain data.frame", {
  skip_if_not_installed("survey")
  skip_if_not_installed("srvyr")
  expect_error(
    from_tbl_svy(data.frame(x = 1)),
    class = "surveycore_error_not_tbl_svy"
  )
})


# ── Coverage additions ────────────────────────────────────────────────────────

# 30. as_svydesign() for JK1 replicate design (scale_arg non-NULL path, line 129)
test_that("as_svydesign() converts JK1 replicate design (scale arg non-NULL path)", {
  skip_if_not_installed("survey")
  df <- make_survey_data(
    n = 50L,
    n_psu = 10L,
    n_strata = 2L,
    design = "replicate",
    type = "jk1",
    seed = 300L
  )
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::all_of(repwt_cols),
    type = "JK1"
  )
  sv <- as_svydesign(d)
  expect_true(inherits(sv, "svyrep.design"))
})

# 31. as_svydesign() for twophase with SRS phase1 (p1$ids NULL → ~1, line 158)
test_that("as_svydesign() handles twophase design with SRS phase1 (no ids)", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 100L, design = "twophase", seed = 301L)
  # phase1 with no ids (SRS-like) — p1$ids will be NULL
  phase1 <- as_survey(df, weights = wt, strata = strata)
  d2 <- as_survey_twophase(phase1, subset = subset)
  sv <- suppressWarnings(as_svydesign(d2))
  expect_true(inherits(sv, "survey.design"))
})

# 32. as_svydesign() for twophase with phase2 ids (p2$ids non-NULL → line 166)
test_that("as_svydesign() handles twophase design with phase2 ids", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 100L, design = "twophase", seed = 302L)
  phase1 <- as_survey(df, weights = wt, strata = strata)
  d2 <- as_survey_twophase(phase1, ids2 = psu, subset = subset)
  sv <- suppressWarnings(as_svydesign(d2))
  expect_true(inherits(sv, "survey.design"))
})

# 33. from_svydesign() for SRS design covers .vars_from_formula(~1) → NULL (line 265)
test_that("from_svydesign() handles SRS design with ids = ~1 (.vars_from_formula NULL path)", {
  skip_if_not_installed("survey")
  set.seed(42)
  df <- data.frame(y = rnorm(50), w = runif(50, 0.5, 2))
  sv <- survey::svydesign(ids = ~1, weights = ~w, data = df)
  d <- from_svydesign(sv)
  expect_true(S7::S7_inherits(d, survey_taylor))
  expect_null(d@variables$ids)
})

# 34. from_svydesign() for replicate with external weight vector (lines 413-414)
test_that("from_svydesign() for replicate with external weights adds ..surveycore_wt.. column", {
  skip_if_not_installed("survey")
  set.seed(42)
  n <- 20L
  df <- data.frame(y = rnorm(n)) # no weight column in data
  ext_wts <- runif(n, 0.5, 2) # external weight vector
  rep_data <- matrix(runif(n * 4L), ncol = 4L)
  sv <- survey::svrepdesign(
    data = df,
    weights = ext_wts, # passed as vector, not formula — won't be in data
    repweights = rep_data,
    type = "BRR",
    combined.weights = TRUE
  )
  d <- from_svydesign(sv)
  expect_true(S7::S7_inherits(d, survey_replicate))
  # The fallback weight column should be added
  expect_true("..surveycore_wt.." %in% names(d@data))
})

# 35. from_svydesign() for twophase with inline subset (lines 447-448 fallback)
test_that("from_svydesign() twophase with inline subset creates ..surveycore_subset.. column", {
  skip_if_not_installed("survey")
  set.seed(42)
  n <- 30L
  df <- data.frame(x = rnorm(n), wt = rep(1, n))
  # subset is an inline logical vector — not a column in df, so .find_col_by_value returns NULL
  sub_lgl <- sample(c(TRUE, FALSE), n, replace = TRUE, prob = c(0.5, 0.5))
  sv <- survey::twophase(
    id = list(~1, ~1),
    strata = list(NULL, NULL),
    probs = list(NULL, NULL),
    data = df,
    subset = sub_lgl
  )
  d <- suppressWarnings(from_svydesign(sv))
  expect_true(S7::S7_inherits(d, survey_twophase))
  # The fallback subset column must have been created
  expect_true("..surveycore_subset.." %in% names(d@data))
})

# 36. visible_vars present after round-trip (from_svydesign Taylor and replicate)
test_that("from_svydesign() taylor result has visible_vars key in @variables", {
  skip_if_not_installed("survey")
  set.seed(42)
  df <- data.frame(x = rnorm(30), w = runif(30, 0.5, 2), s = rep(1:3, 10))
  sv <- survey::svydesign(ids = ~1, weights = ~w, strata = ~s, data = df)
  d <- from_svydesign(sv)
  expect_true("visible_vars" %in% names(d@variables))
})

test_that("from_svydesign() replicate result has visible_vars key in @variables", {
  skip_if_not_installed("survey")
  set.seed(42)
  n <- 20L
  df <- data.frame(y = rnorm(n), wt = runif(n, 1, 3))
  rep <- matrix(runif(n * 4L), ncol = 4L)
  sv <- survey::svrepdesign(
    data = df,
    weights = ~wt,
    repweights = rep,
    type = "BRR",
    combined.weights = TRUE
  )
  d <- from_svydesign(sv)
  expect_true("visible_vars" %in% names(d@variables))
})


# 37. as_svydesign() for survey_taylor with ids = NULL uses ids = ~1 (line 111)
test_that("as_svydesign() uses ids = ~1 when survey_taylor has ids = NULL", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 30L, n_psu = 10L, n_strata = 2L, seed = 42L)
  # Stratified design with no cluster ids — ids = NULL in @variables
  d <- as_survey(df, weights = wt, strata = strata)
  test_invariants(d)
  expect_null(d@variables$ids)
  sv <- as_svydesign(d)
  expect_true(inherits(sv, "survey.design"))
})


# 38. from_svydesign() warns when twophase x$method is unrecognised (lines 465-472)
test_that("from_svydesign() warns surveycore_warning_twophase_method_unknown for unknown method", {
  skip_if_not_installed("survey")
  set.seed(42)
  n <- 30L
  df <- data.frame(x = rnorm(n), wt = rep(1, n))
  sub <- sample(c(TRUE, FALSE), n, replace = TRUE, prob = c(0.6, 0.4))
  # method = "approx" creates a plain "twophase" object (not "twophase2"), so
  # the class-based fallback does not fire and only x$method controls dispatch.
  sv <- survey::twophase(
    id = list(~1, ~1),
    strata = list(NULL, NULL),
    probs = list(NULL, NULL),
    data = df,
    subset = sub,
    method = "approx"
  )
  # Replace method with an unrecognised value to trigger the fallback warning.
  sv$method <- "nonexistent_method"

  expect_warning(
    d <- from_svydesign(sv),
    class = "surveycore_warning_twophase_method_unknown"
  )
  expect_true(S7::S7_inherits(d, survey_twophase))
  expect_identical(d@variables$method, "approx")
})


# ── Round trip through the survey package ────────────────────────────────────
#
# as_svydesign() builds a survey::svydesign() object, and survey stores its own
# call. R records the unevaluated argument expressions there, so passing a
# variable that holds a formula recorded the variable's name rather than the
# formula. from_svydesign() reads those back with all.vars() to recover the
# design column names, so every Taylor design failed to rebuild. These rows
# pin the repair.

test_that("from_svydesign() rebuilds a Taylor design that as_svydesign() made", {
  skip_if_not_installed("survey")
  df <- make_survey_data(seed = 3L)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)

  back <- from_svydesign(as_svydesign(d))

  expect_identical(back@variables$ids, d@variables$ids)
  expect_identical(back@variables$strata, d@variables$strata)
  expect_identical(back@variables$weights, d@variables$weights)
  expect_identical(back@variables$fpc, d@variables$fpc)
})

test_that("the survey round trip preserves the estimate and its standard error", {
  skip_if_not_installed("survey")
  df <- make_survey_data(seed = 3L)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)

  back <- from_svydesign(as_svydesign(d))
  before <- suppressWarnings(get_means(d, y1, variance = "se"))
  after <- suppressWarnings(get_means(back, y1, variance = "se"))

  expect_equal(after$mean, before$mean, tolerance = 0)
  expect_equal(after$se, before$se, tolerance = 0)
})

test_that("the survey round trip works for every Taylor design shape", {
  skip_if_not_installed("survey")
  df <- make_survey_data(seed = 4L)
  # A constant FPC. make_survey_data() varies fpc by PSU, which makes survey
  # warn that it varies within a stratum. That warning is about the fixture,
  # not about the round trip under test.
  df$fpc_const <- 1000

  shapes <- list(
    ids_only = as_survey(df, ids = psu, weights = wt),
    with_strata = as_survey(df, ids = psu, weights = wt, strata = strata),
    with_fpc = as_survey(df, ids = psu, weights = wt, fpc = fpc_const),
    srs = as_survey(df, weights = wt)
  )

  for (nm in names(shapes)) {
    back <- from_svydesign(as_svydesign(shapes[[nm]]))
    expect_identical(
      back@variables$weights,
      shapes[[nm]]@variables$weights,
      label = paste("shape:", nm)
    )
  }
})

test_that("as_svydesign() stores a call naming real columns, not local variables", {
  skip_if_not_installed("survey")
  df <- make_survey_data(seed = 5L)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)

  sv <- as_svydesign(d)

  # The regression this guards: these read "ids_formula" and "strata_var"
  # before the fix, because R recorded the argument expressions rather than
  # the formulas they evaluated to.
  expect_identical(all.vars(sv$call$ids), "psu")
  expect_identical(all.vars(sv$call$strata), "strata")
  expect_identical(all.vars(sv$call$weights), "wt")
})


# ── C-0–C-9. haven-labelled data on the conversion routes ────────────────────
#
# Gate 10 (spec section XI.10): `@metadata@value_labels` is populated on every
# route that builds a design from a frame carrying a `labels` attribute,
# `from_svydesign()` included. C-3, C-5 and C-6 are the proof.
#
# `make_labelled()` is in `tests/testthat/helper-test-data.R`. It builds the
# `haven_labelled` class vector with base R, so `haven` stays in Suggests.

# A source frame with two labelled analysis columns and a plain weight.
make_labelled_frame <- function(n = 40L, seed = 42L) {
  set.seed(seed)
  df <- data.frame(
    psu = rep(seq_len(10L), each = n %/% 10L),
    strata = rep(1:2, each = n %/% 2L),
    wt = runif(n, 1, 3)
  )
  df$y1 <- make_labelled(rnorm(n), label = "Outcome variable 1")
  df$y3 <- make_labelled(
    rep(c(0, 1), n %/% 2L),
    labels = c("No" = 0, "Yes" = 1),
    label = "Outcome variable 3"
  )
  df
}

# Names of the columns of `data` that still carry the labelled class.
labelled_cols <- function(data) {
  names(data)[vapply(data, inherits, logical(1L), "haven_labelled")]
}

# The value labels y3 carries in every fixture below.
y3_labels <- c("No" = 0, "Yes" = 1)


# C-0. get_means(label_vars = TRUE) over a from_svydesign() design shows the
#      variable label rather than the raw column name.
test_that("get_means() on a from_svydesign() design reports the variable label", {
  skip_if_not_installed("survey")
  df <- make_labelled_frame()
  sv <- survey::svydesign(
    ids = ~psu,
    weights = ~wt,
    strata = ~strata,
    data = df
  )
  d <- from_svydesign(sv)

  res <- get_means(d, y1, variance = "se", label_vars = TRUE)
  shown <- attr(res, ".meta")$x$y1$variable_label

  expect_identical(shown, "Outcome variable 1")
  expect_false(identical(shown, "y1"))
})


# C-1. as_svydesign() hands over plain columns that keep their attributes.
test_that("as_svydesign() returns plain columns that keep their labels", {
  skip_if_not_installed("survey")
  df <- make_labelled_frame()
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)

  sv <- as_svydesign(d)

  expect_true(inherits(sv, "survey.design"))
  expect_identical(labelled_cols(sv$variables), character(0))
  expect_identical(attr(sv$variables$y3, "labels", exact = TRUE), y3_labels)
  expect_identical(
    attr(sv$variables$y1, "label", exact = TRUE),
    "Outcome variable 1"
  )
})


# C-2. The converted object estimates identically to the surveycore design.
test_that("svymean() on the as_svydesign() output matches get_means() [numerical]", {
  skip_if_not_installed("survey")
  df <- make_labelled_frame()
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  sv <- as_svydesign(d)

  sc <- get_means(d, y1, variance = "se")
  sm <- survey::svymean(~y1, sv)

  expect_equal(sc$mean[[1L]], coef(sm)[["y1"]], tolerance = 1e-10)
  expect_equal(sc$se[[1L]], as.numeric(survey::SE(sm)), tolerance = 1e-8)
})


# C-3. from_svydesign() harvests the labels into @metadata. Gate 10.
test_that("from_svydesign() captures value labels from a labelled svydesign", {
  skip_if_not_installed("survey")
  df <- make_labelled_frame()
  sv <- survey::svydesign(
    ids = ~psu,
    weights = ~wt,
    strata = ~strata,
    data = df
  )

  d <- from_svydesign(sv)

  expect_true(S7::S7_inherits(d, survey_taylor))
  expect_identical(labelled_cols(d@data), character(0))
  expect_identical(extract_val_labels(d), list(y3 = y3_labels))
  expect_identical(d@metadata@value_labels, list(y3 = y3_labels))
  expect_identical(
    extract_var_label(d),
    c(y1 = "Outcome variable 1", y3 = "Outcome variable 3")
  )
})


# C-4. A labelled weight column no longer aborts the Taylor route.
test_that("from_svydesign() converts a design whose weight column is labelled", {
  skip_if_not_installed("survey")
  set.seed(11L)
  n <- 40L
  w <- runif(n, 1, 3)
  # `probs` rather than `weights` keeps the weight formula out of the stored
  # call, so the weight column is recovered by value. That reaches
  # `.find_col_by_value()`, which casts each candidate with as.numeric().
  df <- data.frame(y = rnorm(n), p = 1 / w)
  df$wt <- make_labelled(w, label = "Sampling weight")

  sv <- survey::svydesign(ids = ~1, probs = ~p, data = df)
  d <- from_svydesign(sv)

  expect_true(S7::S7_inherits(d, survey_taylor))
  expect_identical(labelled_cols(d@data), character(0))
  expect_identical(d@variables$weights, "wt")
  expect_equal(d@data$wt, w, tolerance = 0, ignore_attr = TRUE)
})


# C-5. The replicate route captures labels. Gate 10.
test_that("from_svydesign() captures value labels from a labelled svrepdesign", {
  skip_if_not_installed("survey")
  set.seed(12L)
  n <- 20L
  df <- data.frame(wt = runif(n, 1, 3))
  df$y3 <- make_labelled(
    rep(c(0, 1), n %/% 2L),
    labels = y3_labels,
    label = "Outcome variable 3"
  )
  rep_mat <- matrix(runif(n * 4L), ncol = 4L)
  sv <- survey::svrepdesign(
    data = df,
    weights = ~wt,
    repweights = rep_mat,
    type = "BRR",
    combined.weights = TRUE
  )

  d <- from_svydesign(sv)

  expect_true(S7::S7_inherits(d, survey_replicate))
  expect_identical(labelled_cols(d@data), character(0))
  expect_identical(extract_val_labels(d), list(y3 = y3_labels))
  expect_identical(extract_var_label(d), c(y3 = "Outcome variable 3"))
})


# C-6. The two-phase route carries the phase 1 metadata forward. Gate 10.
test_that("from_svydesign() captures value labels from a labelled twophase", {
  skip_if_not_installed("survey")
  set.seed(13L)
  n <- 30L
  df <- data.frame(x = rnorm(n), wt = rep(1, n))
  df$y3 <- make_labelled(
    rep(c(0, 1), n %/% 2L),
    labels = y3_labels,
    label = "Outcome variable 3"
  )
  sub <- rep(c(TRUE, FALSE), n %/% 2L)
  sv <- survey::twophase(
    id = list(~1, ~1),
    strata = list(NULL, NULL),
    probs = list(NULL, NULL),
    data = df,
    subset = sub
  )

  d <- suppressWarnings(from_svydesign(sv))

  expect_true(S7::S7_inherits(d, survey_twophase))
  expect_identical(labelled_cols(d@data), character(0))
  expect_identical(extract_val_labels(d), list(y3 = y3_labels))
  expect_identical(extract_var_label(d), c(y3 = "Outcome variable 3"))
})


# C-7. Round trip out through survey and back keeps the labels at both ends.
test_that("as_survey() to as_svydesign() to from_svydesign() keeps the labels", {
  skip_if_not_installed("survey")
  df <- make_labelled_frame()
  d1 <- as_survey(df, ids = psu, weights = wt, strata = strata)

  expect_identical(labelled_cols(d1@data), character(0))
  expect_identical(extract_val_labels(d1), list(y3 = y3_labels))

  sv <- as_svydesign(d1)
  expect_identical(labelled_cols(sv$variables), character(0))

  # The return leg used to abort for a reason unrelated to labels: `survey`
  # recorded the local variable names in `$call`, so `from_svydesign()` read
  # them back as design variables and raised
  # `surveycore_error_design_var_missing`. Fixed separately in #195, which
  # inlines the formulas into the stored call. This row asserts the whole
  # round trip now.
  d2 <- from_svydesign(sv)

  expect_identical(labelled_cols(d2@data), character(0))
  expect_identical(extract_val_labels(d2), list(y3 = y3_labels))
  expect_identical(
    extract_var_label(d2),
    c(y1 = "Outcome variable 1", y3 = "Outcome variable 3")
  )
})


# C-8. The srvyr round trip behaves the same way.
test_that("as_tbl_svy() to from_tbl_svy() keeps the labels", {
  skip_if_not_installed("survey")
  skip_if_not_installed("srvyr")
  df <- make_labelled_frame()
  d1 <- as_survey(df, ids = psu, weights = wt, strata = strata)

  tbl <- as_tbl_svy(d1)
  expect_identical(labelled_cols(tbl$variables), character(0))

  d2 <- from_tbl_svy(tbl)

  expect_identical(labelled_cols(d2@data), character(0))
  expect_identical(extract_val_labels(d2), list(y3 = y3_labels))
  expect_identical(
    extract_var_label(d2),
    c(y1 = "Outcome variable 1", y3 = "Outcome variable 3")
  )
})


# C-9. A source frame with no labels harvests nothing and does not error.
test_that("from_svydesign() on an unlabelled frame returns no value labels", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 40L, n_psu = 10L, n_strata = 2L, seed = 42L)
  sv <- survey::svydesign(
    ids = ~psu,
    weights = ~wt,
    strata = ~strata,
    data = df
  )

  d <- from_svydesign(sv)

  expect_identical(extract_val_labels(d), stats::setNames(list(), character(0)))
  expect_identical(d@metadata@value_labels, list())
})


# ── R-1 … R-10. from_svydesign() — the replicate bridge (#197) ───────────────
#
# The import route expands x$repweights, generates a name for every replicate
# column survey leaves unnamed, and writes one column per replicate into the
# data. Spec §III.2 steps 2, 4, 5, 6, 10, 11, 12 and 13.

# R-1. Numerical parity, finished weights, uncompressed source.
test_that("from_svydesign() matches survey on an uncompressed finished-weight source [numerical]", {
  skip_if_not_installed("survey")
  set.seed(101L)
  n <- 40L
  df <- data.frame(
    wt = runif(n, 1, 4),
    y1 = rnorm(n)
  )
  rep_mat <- matrix(runif(n * 16L, 0.5, 2), ncol = 16L) * df$wt
  sv <- survey::svrepdesign(
    data = df,
    weights = ~wt,
    repweights = rep_mat,
    type = "BRR",
    combined.weights = TRUE
  )

  # Preconditions: the source must really be uncompressed and must really
  # declare finished weights, or the block passes without testing anything.
  expect_false(inherits(sv$repweights, "repweights_compressed"))
  expect_true(isTRUE(sv$combined.weights))

  d <- from_svydesign(sv)
  test_invariants(d)

  sm <- survey::svymean(~y1, sv)
  sc <- get_means(d, y1, variance = "se")

  expect_equal(sc$mean[[1L]], coef(sm)[["y1"]], tolerance = 1e-10)
  expect_equal(sc$se[[1L]], as.numeric(survey::SE(sm)), tolerance = 1e-8)
})

# R-2. Numerical parity, finished weights, compressed source. This is the
# storage form that a dim() check cannot tell apart from a plain matrix.
test_that("from_svydesign() matches survey on a compressed finished-weight source [numerical]", {
  skip_if_not_installed("survey")
  set.seed(102L)
  n <- 40L
  df <- data.frame(
    wt = runif(n, 1, 4),
    y1 = rnorm(n)
  )
  rep_mat <- matrix(runif(n * 16L, 0.5, 2), ncol = 16L) * df$wt
  sv_raw <- survey::svrepdesign(
    data = df,
    weights = ~wt,
    repweights = rep_mat,
    type = "BRR",
    combined.weights = TRUE
  )
  sv <- survey::compressWeights(sv_raw)

  # Preconditions: the installed survey must actually compress, and the
  # finished-weight declaration must survive compression.
  expect_true(inherits(sv$repweights, "repweights_compressed"))
  expect_true(isTRUE(sv$combined.weights))

  d <- from_svydesign(sv)

  sm <- survey::svymean(~y1, sv)
  sc <- get_means(d, y1, variance = "se")

  expect_equal(sc$mean[[1L]], coef(sm)[["y1"]], tolerance = 1e-10)
  expect_equal(sc$se[[1L]], as.numeric(survey::SE(sm)), tolerance = 1e-8)
  expect_length(d@variables$repweights, 16L)
})

# R-3. A factor-form source: structure only, no standard-error parity.
#      survey::as.svrepdesign() reports combined.weights FALSE, so the stored
#      columns are replication factors. Spec §III.1 measures the resulting
#      standard-error error at 35%, 8%, 4%, 10% and 0.1% across five designs,
#      in both directions. The fold-in that removes it is not in this change.
test_that("from_svydesign() stores every replicate of a compressed factor-form source", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 40L, n_psu = 20L, n_strata = 4L, seed = 103L)
  sv_t <- survey::svydesign(
    ids = ~psu,
    strata = ~strata,
    weights = ~wt,
    data = df
  )
  sv <- survey::as.svrepdesign(sv_t, type = "JKn")

  # Preconditions for the factor form, and for survey naming no column.
  expect_false(isTRUE(sv$combined.weights))
  expect_length(colnames(sv$repweights), 0L)

  n_rep <- ncol(as.matrix(sv$repweights))
  d <- from_svydesign(sv)

  expect_length(d@variables$repweights, n_rep)
  expect_true(all(grepl(
    "^\\.\\.surveycore_repwt_[0-9]+\\.\\.$",
    d@variables$repweights
  )))
  expect_true(all(d@variables$repweights %in% names(d@data)))
  expect_true(all(vapply(
    d@data[d@variables$repweights],
    is.numeric,
    logical(1L)
  )))
  expect_no_error(get_means(d, y1, variance = "se"))
})

# R-4. The uncompressed factor form. as.matrix() leaves survey's "repweights"
#      class on the object here, so this is the source that proves the
#      unclass() in step 4 does its job: the route must still produce n_rep
#      separate double columns.
test_that("from_svydesign() writes one double column per replicate for an uncompressed source", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 40L, n_psu = 20L, n_strata = 4L, seed = 104L)
  sv_t <- survey::svydesign(
    ids = ~psu,
    strata = ~strata,
    weights = ~wt,
    data = df
  )
  sv <- survey::as.svrepdesign(sv_t, type = "JKn", compress = FALSE)

  # Precondition: the class survey puts on the stored object survives
  # as.matrix(), which is exactly what step 4 has to strip.
  expect_true(inherits(as.matrix(sv$repweights), "repweights"))

  rep_mat <- unclass(as.matrix(sv$repweights))
  d <- from_svydesign(sv)

  expect_length(d@variables$repweights, ncol(rep_mat))
  expect_identical(ncol(d@data), ncol(df) + ncol(rep_mat))
  for (j in seq_len(ncol(rep_mat))) {
    expect_identical(typeof(d@data[[d@variables$repweights[[j]]]]), "double")
    expect_equal(
      d@data[[d@variables$repweights[[j]]]],
      as.numeric(rep_mat[, j]),
      tolerance = 0
    )
  }
})

# R-5. No silent loss (spec §VI property 4).
test_that("from_svydesign() stores one existing data column per source replicate", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 40L, n_psu = 20L, n_strata = 4L, seed = 105L)
  # JK1 needs an unstratified design.
  sv_t <- survey::svydesign(ids = ~psu, weights = ~wt, data = df)
  sv <- survey::as.svrepdesign(sv_t, type = "JK1")

  n_rep <- ncol(as.matrix(sv$repweights))
  d <- from_svydesign(sv)

  expect_length(d@variables$repweights, n_rep)
  expect_identical(setdiff(d@variables$repweights, names(d@data)), character(0))
})

# R-6. The regression guard for #197 itself. Before this change the route
#      stored zero names, wrote no columns, and the loss surfaced later at
#      analysis time as surveycore_error_all_replicates_na.
test_that("get_means() runs on a design converted from survey::as.svrepdesign()", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 40L, n_psu = 20L, n_strata = 4L, seed = 106L)
  sv_t <- survey::svydesign(
    ids = ~psu,
    strata = ~strata,
    weights = ~wt,
    data = df
  )
  sv <- survey::as.svrepdesign(sv_t, type = "JKn")

  expect_no_error(get_means(from_svydesign(sv), y1))
})

# R-7. Generated names pad to the width of the replicate count (§II.2, §III.6).
test_that("from_svydesign() zero-pads generated replicate names for 20 replicates", {
  skip_if_not_installed("survey")
  set.seed(107L)
  n <- 24L
  df <- data.frame(wt = runif(n, 1, 3), y1 = rnorm(n))
  rep_mat <- matrix(runif(n * 20L, 0.5, 2), ncol = 20L)
  sv <- survey::svrepdesign(
    data = df,
    weights = ~wt,
    repweights = rep_mat,
    type = "BRR",
    combined.weights = TRUE
  )

  d <- from_svydesign(sv)

  expect_length(d@variables$repweights, 20L)
  expect_identical(d@variables$repweights[[1L]], "..surveycore_repwt_01..")
  expect_identical(d@variables$repweights[[9L]], "..surveycore_repwt_09..")
  expect_identical(d@variables$repweights[[20L]], "..surveycore_repwt_20..")
})

# R-8. A one-digit replicate count generates unpadded names.
test_that("from_svydesign() leaves generated replicate names unpadded for 4 replicates", {
  skip_if_not_installed("survey")
  set.seed(108L)
  n <- 24L
  df <- data.frame(wt = runif(n, 1, 3), y1 = rnorm(n))
  rep_mat <- matrix(runif(n * 4L, 0.5, 2), ncol = 4L)
  sv <- survey::svrepdesign(
    data = df,
    weights = ~wt,
    repweights = rep_mat,
    type = "BRR",
    combined.weights = TRUE
  )

  d <- from_svydesign(sv)

  expect_identical(
    d@variables$repweights,
    c(
      "..surveycore_repwt_1..",
      "..surveycore_repwt_2..",
      "..surveycore_repwt_3..",
      "..surveycore_repwt_4.."
    )
  )
})

# R-9. Survey's own names pass through unchanged and in order, and the route
#      still writes every column from the expanded matrix
#      (§III.6, §VI property 5).
test_that("from_svydesign() passes survey's replicate column names through unchanged", {
  skip_if_not_installed("survey")
  df <- make_survey_data(
    n = 40L,
    n_psu = 20L,
    n_strata = 4L,
    design = "replicate",
    type = "brr",
    seed = 109L
  )
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  sv <- survey::svrepdesign(
    data = df,
    weights = ~wt,
    repweights = df[, repwt_cols],
    type = "BRR",
    combined.weights = TRUE
  )

  # Precondition: survey kept the names, so step 6 must not generate.
  expect_identical(colnames(sv$repweights), repwt_cols)

  rep_mat <- unclass(as.matrix(sv$repweights))
  d <- from_svydesign(sv)

  expect_identical(d@variables$repweights, repwt_cols)
  expect_false(any(grepl("surveycore_repwt", names(d@data), fixed = TRUE)))
  for (j in seq_along(repwt_cols)) {
    expect_equal(
      d@data[[repwt_cols[[j]]]],
      as.numeric(rep_mat[, j]),
      tolerance = 0
    )
  }
})

# R-10. A replicate column holds exactly x$pweights and no data column does.
#       Step 10 runs before step 11, so the base weight search never sees the
#       replicate block and the route manufactures ..surveycore_wt.. (§III.6).
test_that("from_svydesign() manufactures the weight column when a replicate holds the base weights", {
  skip_if_not_installed("survey")
  set.seed(110L)
  n <- 24L
  df <- data.frame(y1 = rnorm(n)) # no weight column in the data
  ext_wts <- runif(n, 1, 3)
  rep_mat <- matrix(runif(n * 4L, 0.5, 2), ncol = 4L) * ext_wts
  rep_mat[, 1L] <- ext_wts # replicate 1 deletes nothing and scales nothing
  sv <- survey::svrepdesign(
    data = df,
    weights = ext_wts,
    repweights = rep_mat,
    type = "BRR",
    combined.weights = TRUE
  )

  d <- from_svydesign(sv)

  expect_identical(d@variables$weights, "..surveycore_wt..")
  expect_false(d@variables$weights %in% d@variables$repweights)
  expect_equal(d@data[["..surveycore_wt.."]], ext_wts, tolerance = 0)
  expect_equal(d@data[[d@variables$repweights[[1L]]]], ext_wts, tolerance = 0)
})
