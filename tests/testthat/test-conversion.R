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

# E-1 and E-3. The dual pattern. The nonprob branch takes one input class
#              out of the else branch, and the message is only correct
#              afterwards, so the snapshot records the current text as the
#              text the four call sites keep.
test_that("as_svydesign() rejects a plain data.frame", {
  skip_if_not_installed("survey")
  expect_error(
    as_svydesign(data.frame(x = 1)),
    class = "surveycore_error_not_survey_object"
  )
  expect_snapshot(error = TRUE, as_svydesign(data.frame(x = 1)))
})

# E-2. The same guard on an atomic input, which inherits no S7 class at
#      all. The message reports the class it got, so the two rows exercise
#      two different renderings of the "i" bullet.
test_that("as_svydesign() rejects a character string", {
  skip_if_not_installed("survey")
  expect_error(
    as_svydesign("apistrat"),
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

# R-3. A factor-form source: structure only. survey::as.svrepdesign() reports
#      combined.weights FALSE, so step 9 folds the base weight into every
#      stored column. R-11 carries the standard-error parity this enables.
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
  # survey::as.svrepdesign() reports combined.weights FALSE, so step 9 folds
  # the base weight in and the stored column is the source column times
  # x$pweights (§VI property 10). R-11 and R-12 test the fold-in itself; this
  # block still tests the column count, the names and the double type.
  for (j in seq_len(ncol(rep_mat))) {
    expect_identical(typeof(d@data[[d@variables$repweights[[j]]]]), "double")
    expect_equal(
      d@data[[d@variables$repweights[[j]]]],
      as.numeric(rep_mat[, j]) * as.numeric(sv$pweights),
      tolerance = 1e-12
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


# ── R-11 … R-21. from_svydesign() — the base weight fold-in (#197) ────────────
#
# When the source design reports replication factors rather than finished
# weights — isTRUE(x$combined.weights) is FALSE — the import route multiplies
# every expanded replicate column by x$pweights. Spec §III.2 step 9.
#
# The fold-in is silent on both branches: both weight forms describe the same
# design, the product is exact, and survey performs the same multiplication
# itself at call time (§V.8, §V.9). No block here expects a condition.

# R-11. The defect #197 exists to remove. survey::as.svrepdesign() reports the
#       factor form for every replicate type, so before the fold-in the stored
#       columns were replication factors and the standard error was wrong by a
#       design-dependent amount: spec §III.1 measures 35%, 8%, 4%, 10% and
#       0.1% across five designs, in both directions.
test_that("from_svydesign() matches survey on a JKn factor-form source [numerical]", {
  skip_if_not_installed("survey")
  set.seed(201L)
  n <- 40L
  df <- data.frame(
    psu = rep(seq_len(20L), each = 2L),
    strata = rep(seq_len(4L), each = 10L),
    # A wide weight spread: the size of the pre-fold-in error depends on how
    # the factor pattern correlates with the base weights, and barely-varying
    # weights make it nearly vanish (§III.1).
    wt = runif(n, 1, 60),
    y1 = rnorm(n)
  )
  sv_t <- survey::svydesign(
    ids = ~psu,
    strata = ~strata,
    weights = ~wt,
    data = df
  )
  sv <- survey::as.svrepdesign(sv_t, type = "JKn")

  # Precondition: this must be a factor-form source, or the block passes on
  # the branch it is not testing.
  expect_false(isTRUE(sv$combined.weights))

  d <- from_svydesign(sv)

  sm <- survey::svymean(~y1, sv)
  sc <- get_means(d, y1, variance = c("se", "ci"))
  ci <- confint(sm)

  expect_equal(sc$mean[[1L]], coef(sm)[["y1"]], tolerance = 1e-10)
  expect_equal(sc$se[[1L]], as.numeric(survey::SE(sm)), tolerance = 1e-8)
  expect_equal(sc$ci_low[[1L]], ci[1], tolerance = 1e-6)
  expect_equal(sc$ci_high[[1L]], ci[2], tolerance = 1e-6)
})

# R-12. The stored value itself (§VI property 10). The product is row-wise:
#       x$pweights recycles down each column, so [i, r] becomes R[i, r] * p[i].
test_that("from_svydesign() stores each replicate column times the base weight", {
  skip_if_not_installed("survey")
  set.seed(202L)
  n <- 40L
  df <- data.frame(
    psu = rep(seq_len(20L), each = 2L),
    wt = runif(n, 1, 60),
    y1 = rnorm(n)
  )
  sv_t <- survey::svydesign(ids = ~psu, weights = ~wt, data = df)
  sv <- survey::as.svrepdesign(sv_t, type = "JK1")

  expect_false(isTRUE(sv$combined.weights))

  rep_mat <- unclass(as.matrix(sv$repweights))
  d <- from_svydesign(sv)

  # The base weights must vary, or the multiplication is unobservable.
  expect_gt(diff(range(sv$pweights)), 1)

  for (j in seq_len(ncol(rep_mat))) {
    expect_equal(
      d@data[[d@variables$repweights[[j]]]],
      as.numeric(rep_mat[, j]) * as.numeric(sv$pweights),
      tolerance = 1e-12
    )
  }
})

# R-13. The other branch of step 9. A finished-weight source passes through
#       unmultiplied — the fold-in must not fire twice on the same design.
test_that("from_svydesign() leaves a finished-weight source unmultiplied", {
  skip_if_not_installed("survey")
  set.seed(203L)
  n <- 40L
  df <- data.frame(wt = runif(n, 1, 60), y1 = rnorm(n))
  rep_mat <- matrix(runif(n * 8L, 0.5, 2), ncol = 8L) * df$wt
  sv <- survey::svrepdesign(
    data = df,
    weights = ~wt,
    repweights = rep_mat,
    type = "BRR",
    combined.weights = TRUE
  )

  expect_true(isTRUE(sv$combined.weights))
  # The base weights vary, so a spurious fold-in would be visible.
  expect_gt(diff(range(sv$pweights)), 1)

  d <- from_svydesign(sv)

  for (j in seq_len(ncol(rep_mat))) {
    expect_equal(
      d@data[[d@variables$repweights[[j]]]],
      as.numeric(rep_mat[, j]),
      tolerance = 0
    )
  }
})

# R-14. Genuine zeros survive the fold-in and the write (§III.4, §III.6). JK1
#       and JKn delete a whole PSU per replicate, so a deleted row genuinely
#       carries weight 0 in that replicate.
test_that("from_svydesign() keeps genuine zeros on JK1 and JKn conversions", {
  skip_if_not_installed("survey")
  set.seed(204L)
  n <- 40L
  df <- data.frame(
    psu = rep(seq_len(20L), each = 2L),
    strata = rep(seq_len(4L), each = 10L),
    wt = runif(n, 1, 60),
    y1 = rnorm(n)
  )
  sources <- list(
    JK1 = survey::svydesign(ids = ~psu, weights = ~wt, data = df),
    JKn = survey::svydesign(
      ids = ~psu,
      strata = ~strata,
      weights = ~wt,
      data = df
    )
  )

  for (ty in names(sources)) {
    sv <- survey::as.svrepdesign(sources[[ty]], type = ty)
    rep_mat <- unclass(as.matrix(sv$repweights))
    n_zero <- sum(rep_mat == 0)

    # Precondition: the deletion pattern must really put zeros in the matrix.
    expect_gt(n_zero, 0L)

    d <- from_svydesign(sv)
    stored <- sum(vapply(
      d@data[d@variables$repweights],
      function(col) sum(col == 0),
      numeric(1L)
    ))
    expect_identical(stored, as.numeric(n_zero))
  }
})

# R-15. An NA in the replicate matrix passes through unchanged (§III.6).
#       survey::svrepdesign() refuses an NA at construction — "Missing values
#       not allowed in 'repweights'" — so the only way to hold one is to put
#       it on the built object. The route reads the field, not the call.
test_that("from_svydesign() keeps an NA in the replicate matrix", {
  skip_if_not_installed("survey")
  set.seed(205L)
  n <- 24L
  df <- data.frame(wt = runif(n, 1, 3), y1 = rnorm(n))
  rep_mat <- matrix(runif(n * 4L, 0.5, 2), ncol = 4L)
  # suppressWarnings(): survey guesses at combined.weights from the mean
  # magnitudes and can warn "Data look like combined weights". Its heuristic
  # is not under test here.
  sv <- suppressWarnings(survey::svrepdesign(
    data = df,
    weights = ~wt,
    repweights = rep_mat,
    type = "BRR",
    combined.weights = FALSE
  ))
  sv$repweights[2L, 1L] <- NA

  expect_false(isTRUE(sv$combined.weights))
  expect_identical(sum(is.na(as.matrix(sv$repweights))), 1L)

  d <- from_svydesign(sv)
  first <- d@data[[d@variables$repweights[[1L]]]]

  expect_true(is.na(first[[2L]]))
  expect_identical(sum(is.na(first)), 1L)
  # Every other row of that column still folded in.
  expect_equal(
    first[-2L],
    as.numeric(rep_mat[-2L, 1L]) * as.numeric(sv$pweights)[-2L],
    tolerance = 1e-12
  )
})

# R-16. A negative replicate weight is preserved, not rejected and not
#       rescaled (§III.4, §III.6). Some calibrated replicate files carry them.
#       The survey_replicate validator checks each replicate column for
#       numeric only; the positivity check covers the base weight alone.
test_that("from_svydesign() preserves a negative replicate weight", {
  skip_if_not_installed("survey")
  set.seed(206L)
  n <- 24L
  df <- data.frame(wt = runif(n, 1, 3), y1 = rnorm(n))
  rep_mat <- matrix(runif(n * 4L, 0.5, 2), ncol = 4L)
  rep_mat[3L, 2L] <- -0.75
  rep_mat[4L, 3L] <- 0
  sv <- suppressWarnings(survey::svrepdesign(
    data = df,
    weights = ~wt,
    repweights = rep_mat,
    type = "BRR",
    combined.weights = FALSE
  ))

  expect_false(isTRUE(sv$combined.weights))

  d <- from_svydesign(sv)
  rep_cols <- d@variables$repweights

  expect_equal(
    d@data[[rep_cols[[2L]]]][[3L]],
    -0.75 * df$wt[[3L]],
    tolerance = 1e-12
  )
  expect_lt(d@data[[rep_cols[[2L]]]][[3L]], 0)
  expect_identical(d@data[[rep_cols[[3L]]]][[4L]], 0)
})

# R-17. A zero or negative base weight is refused at construction. Existing
#       structural behaviour, unchanged by the fold-in (§III.6). Class only —
#       no snapshot, since this change does not add the condition.
test_that("from_svydesign() rejects a replicate source with a nonpositive base weight", {
  skip_if_not_installed("survey")
  set.seed(207L)
  n <- 24L
  df <- data.frame(wt = runif(n, 1, 3), y1 = rnorm(n))
  rep_mat <- matrix(runif(n * 4L, 0.5, 2), ncol = 4L)

  for (bad in c(0, -2)) {
    pw <- df$wt
    pw[[5L]] <- bad
    sv <- suppressWarnings(survey::svrepdesign(
      data = df,
      weights = pw,
      repweights = rep_mat,
      type = "BRR",
      combined.weights = FALSE
    ))
    expect_error(
      from_svydesign(sv),
      class = "surveycore_error_weights_nonpositive"
    )
  }
})

# R-18. Survey's own names reach @variables$repweights unchanged and in order
#       on a factor-form source, and the columns hold the folded-in values
#       (§III.6, §VI property 5). Spec §III.6: "The route overwrites those
#       columns with the finished weights. The names do not change."
test_that("from_svydesign() keeps survey's replicate names on a factor-form source", {
  skip_if_not_installed("survey")
  set.seed(208L)
  n <- 24L
  df <- data.frame(wt = runif(n, 1, 3), y1 = rnorm(n))
  rep_mat <- matrix(runif(n * 4L, 0.5, 2), ncol = 4L)
  colnames(rep_mat) <- c("rw_a", "rw_b", "rw_c", "rw_d")
  sv <- suppressWarnings(survey::svrepdesign(
    data = df,
    weights = ~wt,
    repweights = rep_mat,
    type = "BRR",
    combined.weights = FALSE
  ))

  expect_false(isTRUE(sv$combined.weights))
  expect_identical(colnames(sv$repweights), colnames(rep_mat))

  d <- from_svydesign(sv)

  expect_identical(d@variables$repweights, colnames(rep_mat))
  expect_false(any(grepl("surveycore_repwt", names(d@data), fixed = TRUE)))
  for (j in seq_len(ncol(rep_mat))) {
    expect_equal(
      d@data[[colnames(rep_mat)[[j]]]],
      as.numeric(rep_mat[, j]) * as.numeric(sv$pweights),
      tolerance = 1e-12
    )
  }
})

# R-19. A replicate name that also names a column of unrelated values. The
#       route overwrites that column with the replicate weight (§III.6).
#       survey::svrepdesign() cross-checks `variables` against `repweights`
#       for neither name nor value, so the two can disagree, and the
#       replicate matrix is the source of truth.
test_that("from_svydesign() overwrites a data column that a replicate name shadows", {
  skip_if_not_installed("survey")
  set.seed(209L)
  n <- 24L
  df <- data.frame(
    wt = runif(n, 1, 3),
    y1 = rnorm(n),
    rw_a = rep(-999, n), # unrelated values under a replicate name
    rw_b = rep(-888, n)
  )
  rep_mat <- matrix(runif(n * 2L, 0.5, 2), ncol = 2L)
  colnames(rep_mat) <- c("rw_a", "rw_b")
  sv <- suppressWarnings(survey::svrepdesign(
    data = df,
    weights = ~wt,
    repweights = rep_mat,
    type = "BRR",
    combined.weights = FALSE
  ))

  # Precondition: the design really does disagree with itself.
  expect_identical(sv$variables$rw_a, rep(-999, n))
  expect_equal(as.matrix(sv$repweights)[, 1L], rep_mat[, 1L], tolerance = 0)

  d <- from_svydesign(sv)

  expect_identical(d@variables$repweights, c("rw_a", "rw_b"))
  # The unrelated values are gone; no column was added to hold them.
  expect_false(any(d@data$rw_a == -999))
  expect_false(any(d@data$rw_b == -888))
  expect_identical(ncol(d@data), ncol(df))
  expect_equal(
    d@data$rw_a,
    as.numeric(rep_mat[, 1L]) * as.numeric(sv$pweights),
    tolerance = 1e-12
  )
})

# R-20. Generated name widths at the narrow end (§III.6). R-7 and R-8 cover
#       the twenty- and four-replicate widths.
test_that("from_svydesign() generates unpadded names for one and two replicates", {
  skip_if_not_installed("survey")
  set.seed(210L)
  n <- 24L
  df <- data.frame(wt = runif(n, 1, 3), y1 = rnorm(n))
  expected <- list(
    "..surveycore_repwt_1..",
    c("..surveycore_repwt_1..", "..surveycore_repwt_2..")
  )

  for (k in 1:2) {
    rep_mat <- matrix(runif(n * k, 0.5, 2), ncol = k)
    sv <- suppressWarnings(survey::svrepdesign(
      data = df,
      weights = ~wt,
      repweights = rep_mat,
      type = "other",
      combined.weights = FALSE,
      scale = 1,
      rscales = rep(1, k)
    ))

    # Precondition: survey names no column, so step 6 must generate.
    expect_length(colnames(sv$repweights), 0L)

    d <- from_svydesign(sv)

    expect_identical(d@variables$repweights, expected[[k]])
  }
})

# R-21. The FPC keys this route records (§III.3). The import route reads no
#       FPC from the source design, whatever the source carries.
test_that("from_svydesign() records no FPC on an imported replicate design", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 40L, n_psu = 20L, n_strata = 4L, seed = 211L)
  sv_t <- survey::svydesign(
    ids = ~psu,
    strata = ~strata,
    weights = ~wt,
    fpc = ~fpc,
    data = df
  )
  sv <- survey::as.svrepdesign(sv_t, type = "JKn")

  d <- from_svydesign(sv)

  expect_null(d@variables$fpc)
  expect_identical(d@variables$fpctype, "fraction")
  expect_true("fpc" %in% names(d@variables))
  expect_true("fpctype" %in% names(d@variables))
})

# R-22. Oracle parity for the case where a replicate column holds exactly
#       x$pweights and no data column does (§III.6). Step 10 runs before step
#       11, so the base weight search never reaches the replicate block. R-10
#       asserts the resulting name; this asserts the numbers.
test_that("from_svydesign() matches survey when a replicate equals the base weights [numerical]", {
  skip_if_not_installed("survey")
  set.seed(212L)
  n <- 40L
  df <- data.frame(y1 = rnorm(n)) # no weight column in the data
  ext_wts <- runif(n, 1, 3)
  rep_mat <- matrix(runif(n * 8L, 0.5, 2), ncol = 8L)
  rep_mat[, 1L] <- 1 # this replicate deletes nothing and scales nothing
  sv <- suppressWarnings(survey::svrepdesign(
    data = df,
    weights = ext_wts,
    repweights = rep_mat,
    type = "BRR",
    combined.weights = FALSE
  ))

  d <- from_svydesign(sv)

  # After the fold-in, replicate 1 holds exactly the base weights.
  expect_identical(d@variables$weights, "..surveycore_wt..")
  expect_equal(
    d@data[[d@variables$repweights[[1L]]]],
    ext_wts,
    tolerance = 1e-12
  )

  sm <- survey::svymean(~y1, sv)
  sc <- get_means(d, y1, variance = c("se", "ci"))
  ci <- confint(sm)

  expect_equal(sc$mean[[1L]], coef(sm)[["y1"]], tolerance = 1e-10)
  expect_equal(sc$se[[1L]], as.numeric(survey::SE(sm)), tolerance = 1e-8)
  expect_equal(sc$ci_low[[1L]], ci[1], tolerance = 1e-6)
  expect_equal(sc$ci_high[[1L]], ci[2], tolerance = 1e-6)
})

# R-23. The written columns add no metadata entry, and the base columns keep
#       the entries they arrived with (§III.2 step 13, §VI property 12).
test_that("from_svydesign() adds no metadata entry for the written replicate columns", {
  skip_if_not_installed("survey")
  set.seed(213L)
  n <- 24L
  df <- data.frame(wt = runif(n, 1, 3), y1 = rnorm(n))
  attr(df$y1, "label") <- "Outcome one"
  sv_t <- survey::svydesign(ids = ~1, weights = ~wt, data = df)
  sv <- survey::as.svrepdesign(sv_t, type = "JK1")

  expect_false(isTRUE(sv$combined.weights))

  d <- from_svydesign(sv)
  rep_cols <- d@variables$repweights

  # The base column keeps the label it arrived with.
  expect_identical(extract_var_label(d), c(y1 = "Outcome one"))
  expect_identical(d@metadata@variable_labels, list(y1 = "Outcome one"))

  # The written columns contribute nothing.
  expect_false(any(rep_cols %in% names(d@metadata@variable_labels)))
  expect_false(any(rep_cols %in% names(d@metadata@value_labels)))
  for (nm in rep_cols) {
    expect_identical(typeof(d@data[[nm]]), "double")
    expect_null(attributes(d@data[[nm]]))
  }
})


# ── R-24 … R-30. from_svydesign() — the four import refusals (D5, D6, #197) ───
#
# The replicate import route refuses four source designs, each with a typed
# condition, in the step order spec §III.2 gives: the replicate type at step
# 1, the row count at step 3, the resolved names at step 7, and a generated
# name that already names a column at step 8.
#
# Each class carries one snapshot of its message. The second trigger of a
# class carries the class assertion alone.

# R-24. Step 1, the route's first step. survey::as.svrepdesign() accepts
#       "subbootstrap" and stores the literal string, and the
#       survey_replicate validator does not check `type`, so without this
#       step the route stores a value the export route cannot use (§V.5).
test_that("from_svydesign() rejects a subbootstrap replicate design", {
  skip_if_not_installed("survey")
  set.seed(240L)
  n <- 40L
  df <- data.frame(
    psu = rep(1:10, each = 4L),
    strata = rep(1:2, each = 20L),
    wt = runif(n, 1, 3),
    y1 = rnorm(n)
  )
  sv_t <- survey::svydesign(
    ids = ~psu,
    strata = ~strata,
    weights = ~wt,
    data = df,
    nest = TRUE
  )
  # survey's bootstrap heuristics warn on their own; keep them out of the
  # assertions so the suite gains no warning.
  sv <- suppressWarnings(
    survey::as.svrepdesign(sv_t, type = "subbootstrap", replicates = 5L)
  )

  expect_identical(sv$type, "subbootstrap")

  expect_error(
    from_svydesign(sv),
    class = "surveycore_error_replicate_type_unsupported"
  )
  expect_snapshot(error = TRUE, from_svydesign(sv))
})

# R-25. The second reachable offending value (§III.6). Class only — R-24
#       snapshots the message.
test_that("from_svydesign() rejects an mrbbootstrap replicate design", {
  skip_if_not_installed("survey")
  set.seed(241L)
  n <- 40L
  df <- data.frame(
    psu = rep(1:10, each = 4L),
    strata = rep(1:2, each = 20L),
    wt = runif(n, 1, 3),
    y1 = rnorm(n)
  )
  sv_t <- survey::svydesign(
    ids = ~psu,
    strata = ~strata,
    weights = ~wt,
    data = df,
    nest = TRUE
  )
  sv <- suppressWarnings(
    survey::as.svrepdesign(sv_t, type = "mrbbootstrap", replicates = 5L)
  )

  expect_identical(sv$type, "mrbbootstrap")
  expect_error(
    from_svydesign(sv),
    class = "surveycore_error_replicate_type_unsupported"
  )
})

# R-26. Step 3. A zero-row svyrep.design is reachable: a zero-row
#       survey.design through survey::as.svrepdesign(type = "JK1") builds and
#       reports nrow(variables) 0 with a 0 x 0 replicate matrix. An empty
#       replicate design supports no estimate and no variance (§V.6).
test_that("from_svydesign() rejects a zero-row replicate design", {
  skip_if_not_installed("survey")
  df0 <- data.frame(
    psu = integer(0),
    wt = numeric(0),
    y1 = numeric(0)
  )
  sv_t <- suppressWarnings(
    survey::svydesign(ids = ~psu, weights = ~wt, data = df0)
  )
  sv <- suppressWarnings(survey::as.svrepdesign(sv_t, type = "JK1"))

  # Precondition: the source really is empty, in both the data and the matrix.
  expect_identical(nrow(sv$variables), 0L)
  expect_identical(dim(unclass(as.matrix(sv$repweights))), c(0L, 0L))
  expect_identical(sv$type, "JK1")

  expect_error(from_svydesign(sv), class = "surveycore_error_empty_data")
  expect_snapshot(error = TRUE, from_svydesign(sv))
})

# R-27. Step 7, first of its two triggers. survey accepts a matrix whose
#       colnames() holds one or more empty strings, and an empty string
#       cannot name a column (§V.1).
test_that("from_svydesign() rejects a partly named replicate matrix", {
  skip_if_not_installed("survey")
  set.seed(242L)
  n <- 20L
  df <- data.frame(wt = runif(n, 1, 3), y1 = rnorm(n))
  rep_mat <- matrix(runif(n * 4L, 0.5, 2), ncol = 4L)
  colnames(rep_mat) <- c("r1", "", "r3", "")
  sv <- survey::svrepdesign(
    data = df,
    weights = ~wt,
    repweights = rep_mat,
    type = "BRR",
    combined.weights = FALSE
  )

  # Precondition: survey kept the empty strings, so step 6 does not generate.
  expect_identical(colnames(sv$repweights), c("r1", "", "r3", ""))

  expect_error(
    from_svydesign(sv),
    class = "surveycore_error_repweights_names_lost"
  )
  expect_snapshot(error = TRUE, from_svydesign(sv))
})

# R-28. Step 7, second trigger. Writing a repeated name would collapse two
#       replicates into one column (§V.1). Class only — R-27 snapshots the
#       message.
test_that("from_svydesign() rejects a replicate matrix with a repeated name", {
  skip_if_not_installed("survey")
  set.seed(243L)
  n <- 20L
  df <- data.frame(wt = runif(n, 1, 3), y1 = rnorm(n))
  rep_mat <- matrix(runif(n * 4L, 0.5, 2), ncol = 4L)
  colnames(rep_mat) <- c("r1", "r2", "r2", "r4")
  sv <- survey::svrepdesign(
    data = df,
    weights = ~wt,
    repweights = rep_mat,
    type = "BRR",
    combined.weights = FALSE
  )

  expect_identical(colnames(sv$repweights), c("r1", "r2", "r2", "r4"))
  expect_error(
    from_svydesign(sv),
    class = "surveycore_error_repweights_names_lost"
  )
})

# R-29. Step 8, at one collision. The route generated the names and one of
#       them already names a column of the data, which is what an earlier
#       conversion leaves behind (§V.2). The message pluralizes per bullet,
#       so this asserts the singular rendering.
test_that("from_svydesign() rejects one generated name that already names a column", {
  skip_if_not_installed("survey")
  set.seed(244L)
  n <- 20L
  df <- data.frame(wt = runif(n, 1, 3), y1 = rnorm(n))
  df[["..surveycore_repwt_2.."]] <- 1
  rep_mat <- matrix(runif(n * 3L, 0.5, 2), ncol = 3L)
  sv <- survey::svrepdesign(
    data = df,
    weights = ~wt,
    repweights = rep_mat,
    type = "BRR",
    combined.weights = FALSE
  )

  # Precondition: survey named no column, so step 6 generates three names.
  expect_length(colnames(sv$repweights), 0L)

  cnd <- expect_error(
    from_svydesign(sv),
    class = "surveycore_error_repwt_name_collision"
  )
  expect_match(conditionMessage(cnd), "has a column named", fixed = TRUE)
  expect_snapshot(error = TRUE, from_svydesign(sv))
})

# R-30. Step 8, at three collisions. Each bullet carries its own quantity, so
#       each pluralizes on its own (§V.2). Class and plural rendering only —
#       R-29 snapshots the message.
test_that("from_svydesign() pluralizes the collision message at three collisions", {
  skip_if_not_installed("survey")
  set.seed(245L)
  n <- 20L
  df <- data.frame(wt = runif(n, 1, 3), y1 = rnorm(n))
  df[["..surveycore_repwt_1.."]] <- 1
  df[["..surveycore_repwt_2.."]] <- 2
  df[["..surveycore_repwt_3.."]] <- 3
  rep_mat <- matrix(runif(n * 3L, 0.5, 2), ncol = 3L)
  sv <- survey::svrepdesign(
    data = df,
    weights = ~wt,
    repweights = rep_mat,
    type = "BRR",
    combined.weights = FALSE
  )

  expect_length(colnames(sv$repweights), 0L)

  cnd <- expect_error(
    from_svydesign(sv),
    class = "surveycore_error_repwt_name_collision"
  )
  msg <- conditionMessage(cnd)
  expect_match(msg, "has columns named", fixed = TRUE)
  expect_match(msg, "conflicting\\s+columns")
})


# ─────────────────────────────────────────────────────────────────────────────
# Export route — as_svydesign() on a survey_replicate (§IV)
#
#   X-1.  The FPC drop warns, and the conversion still returns a design
#   X-2.  Export parity with a recorded FPC [numerical]
#   X-3.  Export parity without a recorded FPC [numerical]
#   X-4.  Every replicate type converts with an FPC recorded
#   X-5.  No FPC recorded, no warning
#   X-6.  The drop leaves the surveycore design untouched
#   X-7.  A design that names no replicate column is refused
#   X-8.  A Fay design exports with its scale and its source's SE
#   X-9.  The constructor's default Fay scale recovers rho = 0
#   X-10. A Fay scale that yields no rho is refused
#   X-11. A Fay design that records no scale is refused
#   X-12. Round-trip parity on a JKn source [numerical]
#   X-13. Round-trip parity on a Fay source [numerical]
#   X-14. Round-trip parity through the FPC drop [numerical]
#   X-15. Export parity for bootstrap [numerical]
#   X-16. Export parity for JKn [numerical]
#   X-17. Every accepted replicate type crosses both routes
#   X-18. Export parity with no FPC recorded, and no condition raised
#   X-19. A replicate column of zeros passes through [numerical]
# ─────────────────────────────────────────────────────────────────────────────

# Build a replicate design that records an FPC column. make_survey_data()
# supplies fpc as a per-stratum population size, which is what
# as_survey_replicate(fpc = fpc) stores.
make_rep_fpc <- function(type = "BRR", seed = 401L, rscales = NULL) {
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
    type = type,
    rscales = rscales,
    fpc = fpc
  )
}

# X-1. §IV.2 step 5 and §VI property 6. The warning is not the whole
#      behaviour: the call has to succeed as well, so the result comes off the
#      return value of the warned call.
test_that("as_svydesign() warns and drops a recorded FPC, and still converts", {
  skip_if_not_installed("survey")
  d <- make_rep_fpc()
  test_invariants(d)
  expect_identical(d@variables$fpc, "fpc")

  expect_warning(
    sv <- as_svydesign(d),
    class = "surveycore_warning_replicate_fpc_dropped"
  )
  expect_true(inherits(sv, "svyrep.design"))

  # The condition names the dropped column, and the FPC reached none of the
  # replicate scales survey::svrepdesign() built.
  cnd <- expect_warning(as_svydesign(d))
  expect_match(conditionMessage(cnd), "fpc", fixed = TRUE)
  expect_equal(sv$rscales, rep(1, length(d@variables$repweights)))

  expect_snapshot(sv2 <- as_svydesign(d))
})

# X-2. §VI property 2 with an FPC recorded. The exported design must report
#      surveycore's own numbers, which is the reason the FPC is dropped rather
#      than reshaped (§IV.5).
test_that("as_svydesign() with a dropped FPC reproduces surveycore's mean and SE [numerical]", {
  skip_if_not_installed("survey")
  d <- make_rep_fpc(seed = 402L)
  sc <- get_means(d, y1, variance = "se")

  expect_warning(
    sv <- as_svydesign(d),
    class = "surveycore_warning_replicate_fpc_dropped"
  )
  sv_mean <- survey::svymean(~y1, sv)

  expect_equal(coef(sv_mean)[["y1"]], sc$mean[[1L]], tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sv_mean)), sc$se[[1L]], tolerance = 1e-8)
})

# X-3. §VI property 2 without an FPC. The same parity has to hold on the
#      branch that raises nothing, so the drop is the only difference between
#      the two calls.
test_that("as_svydesign() without an FPC reproduces surveycore's mean and SE [numerical]", {
  skip_if_not_installed("survey")
  d <- make_rep(seed = 403L)
  expect_null(d@variables$fpc)
  sc <- get_means(d, y1, variance = "se")

  sv_mean <- survey::svymean(~y1, as_svydesign(d))

  expect_equal(coef(sv_mean)[["y1"]], sc$mean[[1L]], tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sv_mean)), sc$se[[1L]], tolerance = 1e-8)
})

# X-4. §IV.6 and §IV.7. survey rejects an FPC outright for "BRR", "JK2",
#      "ACS" and "successive-difference" with 'fpc not available for this
#      type', and for "bootstrap" with 'Separate fpc not needed for
#      bootstrap'. It accepts one for "JK1" and "JKn". The rule does not
#      depend on the type: warn, drop, convert, and let no bare survey error
#      reach the caller. "Fay" is out of scope here — it needs the recovered
#      shrinkage factor.
test_that("as_svydesign() warns and converts for every replicate type carrying an FPC", {
  skip_if_not_installed("survey")
  types <- c("JK1", "JK2", "BRR", "bootstrap", "ACS", "successive-difference")
  for (ty in types) {
    d <- make_rep_fpc(type = ty, seed = 404L)
    # survey::svrepdesign() reports its own simpleWarning for the types that
    # ignore a scale — 'with type JK2 scale= and rscales= are not needed'.
    # That is untouched behaviour of the scale argument (step 3), not of the
    # FPC, so muffle it by class and leave the typed condition to reach
    # expect_warning().
    expect_warning(
      sv <- suppressWarnings(as_svydesign(d), classes = "simpleWarning"),
      class = "surveycore_warning_replicate_fpc_dropped"
    )
    expect_true(inherits(sv, "svyrep.design"))
    expect_identical(nrow(sv$variables), nrow(d@data))
  }

  # "JKn" needs rscales of its own — survey::svrepdesign() refuses combined
  # JKn weights without them, for reasons unrelated to the FPC.
  d_jkn <- make_rep_fpc(type = "JKn", seed = 404L, rscales = rep(1, 5L))
  expect_warning(
    sv_jkn <- suppressWarnings(
      as_svydesign(d_jkn),
      classes = "simpleWarning"
    ),
    class = "surveycore_warning_replicate_fpc_dropped"
  )
  expect_true(inherits(sv_jkn, "svyrep.design"))
})

# X-5. §IV.6 first row. The silent branch.
test_that("as_svydesign() raises no warning when the design records no FPC", {
  skip_if_not_installed("survey")
  d <- make_rep(seed = 405L)
  expect_null(d@variables$fpc)
  expect_no_warning(sv <- as_svydesign(d))
  expect_true(inherits(sv, "svyrep.design"))
})

# X-6. §IV.4 and §VI property 7. The drop is a fact about the exported design
#      only. Nothing on x moves, so a second call warns again.
test_that("as_svydesign() leaves the surveycore design untouched when it drops the FPC", {
  skip_if_not_installed("survey")
  d <- make_rep_fpc(seed = 406L)
  data_before <- d@data
  vars_before <- d@variables

  expect_warning(
    as_svydesign(d),
    class = "surveycore_warning_replicate_fpc_dropped"
  )

  expect_identical(d@data, data_before)
  expect_identical(d@variables, vars_before)
  expect_identical(d@variables$fpc, "fpc")
  expect_identical(d@variables$fpctype, "fraction")
  expect_true("fpc" %in% names(d@data))

  # A second conversion is not quieter than the first.
  expect_warning(
    as_svydesign(d),
    class = "surveycore_warning_replicate_fpc_dropped"
  )
})

# X-7. §IV.2 step 2 and §VI property 11. The state is reachable through the
#      exported survey_replicate() constructor, which takes an untyped
#      variables list and never calls .validate_data_frame(). No
#      test_invariants() call here: invariant 4 covers named design columns,
#      and this design names no replicate column by construction.
test_that("as_svydesign() rejects a replicate design that names no replicate column", {
  skip_if_not_installed("survey")
  set.seed(407L)
  n <- 20L
  df <- data.frame(wt = runif(n, 1, 3), y1 = rnorm(n))
  d <- survey_replicate(
    data = df,
    variables = list(
      weights = "wt",
      repweights = character(0),
      type = "BRR",
      scale = 1,
      rscales = NULL,
      fpc = NULL,
      fpctype = "fraction",
      mse = TRUE,
      visible_vars = NULL
    )
  )

  # Precondition: the design built, so the guard is the only thing standing
  # between this object and survey's untyped
  # 'missing value where TRUE/FALSE needed'.
  expect_length(d@variables$repweights, 0L)

  cnd <- expect_error(
    as_svydesign(d),
    class = "surveycore_error_repweights_empty"
  )
  expect_match(
    conditionMessage(cnd),
    "no replicate weight column",
    fixed = TRUE
  )
  expect_snapshot(error = TRUE, as_svydesign(d))
})

# Build the survey Taylor design that the Fay and round-trip blocks convert
# from. as.svrepdesign() reports the factor form, which is the path nearly
# every real conversion takes.
make_taylor_source <- function(seed = 421L, n = 60L) {
  set.seed(seed)
  data.frame(
    strata = rep(1:6, each = n %/% 6L),
    psu = rep(1:12, each = n %/% 12L),
    wt = runif(n, 1, 4),
    y1 = rnorm(n, mean = 10, sd = 2)
  )
}

# Build a replicate design of a given type, with no FPC recorded. The data is
# the same block make_rep_fpc() uses; only the recorded type and the scale
# arguments change.
make_rep_type <- function(type = "BRR", seed = 430L, rscales = NULL) {
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
    type = type,
    rscales = rscales
  )
}

# X-8. §IV.2 step 4 and §VI property 9. The anchor is the measured case: a
#      design built with fay.rho = 0.3 recovers 0.3 exactly. Without the
#      recovery the call stops with survey's own 'With type='Fay' you must
#      supply the correct rho'.
test_that("as_svydesign() exports a Fay design with its scale and SE [numerical]", {
  skip_if_not_installed("survey")
  df <- make_taylor_source()
  tay <- survey::svydesign(
    ids = ~psu,
    strata = ~strata,
    weights = ~wt,
    data = df,
    nest = TRUE
  )
  src <- survey::as.svrepdesign(tay, type = "Fay", fay.rho = 0.3)

  d <- from_svydesign(src)
  expect_identical(d@variables$type, "Fay")

  sv <- as_svydesign(d)
  expect_true(inherits(sv, "svyrep.design"))

  # The shrinkage factor the replicates were built with, recovered from the
  # recorded scale alone.
  expect_equal(sv$rho, 0.3, tolerance = 1e-10)

  # The scale is the design's own, and the source's. Step 3 passes no scale
  # for "Fay": survey recomputes it from the recovered rho.
  expect_equal(sv$scale, d@variables$scale, tolerance = 1e-10)
  expect_equal(sv$scale, src$scale, tolerance = 1e-10)

  sm_src <- survey::svymean(~y1, src)
  sm_out <- survey::svymean(~y1, sv)
  expect_equal(coef(sm_out)[["y1"]], coef(sm_src)[["y1"]], tolerance = 1e-10)
  expect_equal(
    as.numeric(survey::SE(sm_out)),
    as.numeric(survey::SE(sm_src)),
    tolerance = 1e-8
  )
})

# X-9. §IV.6. as_survey_replicate(type = "Fay") with no scale fills 1 / n_rep,
#      which recovers rho = 0. A Fay design with rho = 0 is the BRR case, so
#      the constructor never produces the missing-scale state.
test_that("as_svydesign() recovers rho = 0 from the default Fay scale", {
  skip_if_not_installed("survey")
  d <- make_rep_type(type = "Fay", seed = 422L)

  n_rep <- length(d@variables$repweights)
  expect_equal(d@variables$scale, 1 / n_rep, tolerance = 1e-10)

  sv <- as_svydesign(d)
  expect_equal(sv$rho, 0, tolerance = 1e-10)
  expect_equal(sv$scale, d@variables$scale, tolerance = 1e-10)

  # Export parity, §VI property 2, on the recovered branch.
  sc <- get_means(d, y1, variance = "se")
  sm <- survey::svymean(~y1, sv)
  expect_equal(coef(sm)[["y1"]], sc$mean[[1L]], tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sm)), sc$se[[1L]], tolerance = 1e-8)
})

# X-10. §IV.2 step 4, out-of-range arm. as_survey_replicate() accepts any
#       numeric scale — no validator checks its value — so a scale whose
#       product with the replicate count is below 1 puts the recovered
#       shrinkage factor below 0. Measured: scale 0.05 over 8 replicates
#       gives -0.581.
test_that("as_svydesign() refuses a Fay design whose scale yields no rho", {
  skip_if_not_installed("survey")
  df <- make_survey_data(
    n = 80L,
    n_psu = 16L,
    n_strata = 2L,
    design = "replicate",
    type = "brr",
    seed = 423L
  )
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  expect_length(repwt_cols, 8L)

  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::all_of(repwt_cols),
    type = "Fay",
    scale = 0.05
  )
  expect_equal(d@variables$scale, 0.05, tolerance = 1e-10)

  cnd <- expect_error(
    as_svydesign(d),
    class = "surveycore_error_fay_rho_unrecoverable"
  )
  msg <- conditionMessage(cnd)
  expect_match(msg, "0.05", fixed = TRUE)
  expect_match(msg, "shrinkage", fixed = TRUE)
  expect_snapshot(error = TRUE, as_svydesign(d))
})

# X-11. §IV.2 step 4, missing-scale arm. The exported survey_replicate()
#       constructor takes an untyped variables list and its validator checks
#       neither scale nor type, so a "Fay" design with no scale key at all is
#       reachable — issue #198's own reproduction builds one. The message
#       reads "none" here, so this arm needs a snapshot of its own.
test_that("as_svydesign() refuses a Fay design that records no scale", {
  skip_if_not_installed("survey")
  df <- make_survey_data(
    n = 50L,
    n_psu = 10L,
    n_strata = 2L,
    design = "replicate",
    type = "brr",
    seed = 424L
  )
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  d <- survey_replicate(
    data = df,
    variables = list(
      weights = "wt",
      repweights = repwt_cols,
      type = "Fay",
      rscales = NULL,
      fpc = NULL,
      fpctype = "fraction",
      mse = TRUE,
      visible_vars = NULL
    )
  )
  expect_null(d@variables$scale)

  cnd <- expect_error(
    as_svydesign(d),
    class = "surveycore_error_fay_rho_unrecoverable"
  )
  expect_match(conditionMessage(cnd), "none", fixed = TRUE)
  expect_snapshot(error = TRUE, as_svydesign(d))
})

# X-12. §VI property 3. The round trip crosses the import route and then the
#       export route, so a loss on either leg shows here.
test_that("as_svydesign(from_svydesign(b)) reproduces b's mean, SE and CI [numerical]", {
  skip_if_not_installed("survey")
  df <- make_taylor_source(seed = 425L)
  tay <- survey::svydesign(
    ids = ~psu,
    strata = ~strata,
    weights = ~wt,
    data = df,
    nest = TRUE
  )
  b <- survey::as.svrepdesign(tay, type = "JKn")

  rt <- as_svydesign(from_svydesign(b))
  expect_true(inherits(rt, "svyrep.design"))

  sm_b <- survey::svymean(~y1, b)
  sm_rt <- survey::svymean(~y1, rt)
  expect_equal(coef(sm_rt)[["y1"]], coef(sm_b)[["y1"]], tolerance = 1e-10)
  expect_equal(
    as.numeric(survey::SE(sm_rt)),
    as.numeric(survey::SE(sm_b)),
    tolerance = 1e-8
  )
  expect_equal(
    as.numeric(confint(sm_rt)),
    as.numeric(confint(sm_b)),
    tolerance = 1e-6
  )
})

# X-13. §VI properties 3 and 9 together. The Fay leg of the round trip needs
#       the recovered shrinkage factor twice: once to build the exported
#       design, and once for the numbers it reports.
test_that("the round trip reproduces a Fay source's mean, SE and CI [numerical]", {
  skip_if_not_installed("survey")
  df <- make_taylor_source(seed = 426L)
  tay <- survey::svydesign(
    ids = ~psu,
    strata = ~strata,
    weights = ~wt,
    data = df,
    nest = TRUE
  )
  b <- survey::as.svrepdesign(tay, type = "Fay", fay.rho = 0.5)

  rt <- as_svydesign(from_svydesign(b))
  expect_equal(rt$rho, 0.5, tolerance = 1e-10)
  expect_equal(rt$scale, b$scale, tolerance = 1e-10)

  sm_b <- survey::svymean(~y1, b)
  sm_rt <- survey::svymean(~y1, rt)
  expect_equal(coef(sm_rt)[["y1"]], coef(sm_b)[["y1"]], tolerance = 1e-10)
  expect_equal(
    as.numeric(survey::SE(sm_rt)),
    as.numeric(survey::SE(sm_b)),
    tolerance = 1e-8
  )
  expect_equal(
    as.numeric(confint(sm_rt)),
    as.numeric(confint(sm_b)),
    tolerance = 1e-6
  )
})

# X-14. §VI properties 2 and 3 on a design that records an FPC. The export
#       leg warns and drops (§IV.2 step 5); the returned design still
#       reproduces surveycore's own numbers, because surveycore's replicate
#       variance never reads the FPC (§IV.5).
test_that("a round trip through the FPC drop still matches the design [numerical]", {
  skip_if_not_installed("survey")
  d <- make_rep_fpc(seed = 427L)
  sc <- get_means(d, y1, variance = "se")
  sc_ci <- get_means(d, y1, variance = "ci")

  expect_warning(
    sv <- as_svydesign(d),
    class = "surveycore_warning_replicate_fpc_dropped"
  )
  d2 <- from_svydesign(sv)

  # The re-imported design records no FPC, and reports the same numbers.
  expect_null(d2@variables$fpc)
  sc2 <- get_means(d2, y1, variance = "se")
  sc2_ci <- get_means(d2, y1, variance = "ci")
  expect_equal(sc2$mean[[1L]], sc$mean[[1L]], tolerance = 1e-10)
  expect_equal(sc2$se[[1L]], sc$se[[1L]], tolerance = 1e-8)
  expect_equal(sc2_ci$ci_low[[1L]], sc_ci$ci_low[[1L]], tolerance = 1e-6)
  expect_equal(sc2_ci$ci_high[[1L]], sc_ci$ci_high[[1L]], tolerance = 1e-6)
})

# X-15. §VI property 2 for "bootstrap". survey refuses an FPC for this type
#       with 'Separate fpc not needed for bootstrap', so the drop is what
#       lets the design convert at all.
test_that("as_svydesign() reproduces surveycore's mean and SE for bootstrap [numerical]", {
  skip_if_not_installed("survey")
  d <- make_rep_fpc(type = "bootstrap", seed = 428L)
  sc <- get_means(d, y1, variance = "se")

  expect_warning(
    sv <- as_svydesign(d),
    class = "surveycore_warning_replicate_fpc_dropped"
  )
  sm <- survey::svymean(~y1, sv)
  expect_equal(coef(sm)[["y1"]], sc$mean[[1L]], tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sm)), sc$se[[1L]], tolerance = 1e-8)
})

# X-16. §VI property 2 for "JKn", the type survey accepts an FPC for. It
#       needs rscales of its own, for reasons unrelated to the FPC.
test_that("as_svydesign() reproduces surveycore's mean and SE for JKn [numerical]", {
  skip_if_not_installed("survey")
  d <- make_rep_fpc(type = "JKn", seed = 429L, rscales = rep(1, 5L))
  sc <- get_means(d, y1, variance = "se")

  expect_warning(
    sv <- as_svydesign(d),
    class = "surveycore_warning_replicate_fpc_dropped"
  )
  sm <- survey::svymean(~y1, sv)
  expect_equal(coef(sm)[["y1"]], sc$mean[[1L]], tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sm)), sc$se[[1L]], tolerance = 1e-8)
})

# X-17. §VI property 8. All nine types as_survey_replicate() accepts cross
#       the export route and then the import route, Fay included. survey
#       reports its own simpleWarning for the types that ignore a scale —
#       'with type ACS scale= and rscales= are not needed' — and for "other"
#       with no rscales. Those are untouched behaviour of the scale argument
#       (step 3), so muffle them by class.
test_that("every accepted replicate type crosses both conversion routes", {
  skip_if_not_installed("survey")
  types <- c(
    "JK1",
    "JK2",
    "JKn",
    "BRR",
    "Fay",
    "bootstrap",
    "ACS",
    "successive-difference",
    "other"
  )
  for (ty in types) {
    rs <- if (ty %in% c("JK2", "JKn")) rep(1, 5L) else NULL
    d <- make_rep_type(type = ty, seed = 430L, rscales = rs)
    expect_identical(d@variables$type, ty)

    sv <- suppressWarnings(as_svydesign(d), classes = "simpleWarning")
    expect_true(inherits(sv, "svyrep.design"))
    expect_identical(sv$type, ty)

    d2 <- from_svydesign(sv)
    expect_identical(d2@variables$type, ty)
    expect_length(d2@variables$repweights, length(d@variables$repweights))
    expect_identical(nrow(d2@data), nrow(d@data))
  }
})

# X-18. §IV.6 first row and §VI property 2 together. X-5 shows the silent
#       branch on the default type, and X-15 shows bootstrap parity through
#       the FPC drop. Neither covers the pair: a design of an accepted type
#       that records no FPC converts without raising anything, and the design
#       it returns reports surveycore's own numbers.
test_that("as_svydesign() converts a bootstrap design with no FPC and matches it [numerical]", {
  skip_if_not_installed("survey")
  d <- make_rep_type(type = "bootstrap", seed = 431L)
  expect_null(d@variables$fpc)
  sc <- get_means(d, y1, variance = "se")

  expect_no_warning(sv <- as_svydesign(d))
  expect_true(inherits(sv, "svyrep.design"))

  sm <- survey::svymean(~y1, sv)
  expect_equal(coef(sm)[["y1"]], sc$mean[[1L]], tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sm)), sc$se[[1L]], tolerance = 1e-8)
})

# X-19. §IV.2 step 6 and §VI property 2. A replicate column of zeros is
#       legal: "JK1" and "JKn" delete a whole PSU per replicate, so a deleted
#       row genuinely carries weight 0 in that replicate. The route gives the
#       columns no special handling and passes them through, so the design
#       converts with no condition of its own and reports surveycore's own
#       numbers.
test_that("as_svydesign() passes a zeroed replicate column through [numerical]", {
  skip_if_not_installed("survey")
  df <- make_survey_data(
    n = 50L,
    n_psu = 10L,
    n_strata = 2L,
    design = "replicate",
    type = "brr",
    seed = 432L
  )
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  df[[repwt_cols[[1L]]]] <- 0

  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::all_of(repwt_cols),
    type = "JK1"
  )
  expect_true(all(d@data[[repwt_cols[[1L]]]] == 0))
  sc <- get_means(d, y1, variance = "se")

  expect_no_warning(sv <- as_svydesign(d))
  expect_true(inherits(sv, "svyrep.design"))

  # The zeros reached the exported design unchanged.
  expect_equal(sum(sv$repweights[, 1L]), 0, tolerance = 1e-10)

  # survey::svymean() reports its own simpleWarning here — '1 replicates
  # gave NA results and were discarded'. That is survey's variance code
  # reacting to the zeros, not the conversion. surveycore discards the same
  # replicate, which is why the two standard errors still agree.
  sm <- suppressWarnings(survey::svymean(~y1, sv), classes = "simpleWarning")
  expect_equal(coef(sm)[["y1"]], sc$mean[[1L]], tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sm)), sc$se[[1L]], tolerance = 1e-8)
})


# ─────────────────────────────────────────────────────────────────────────────
# Export route — as_svydesign() on a survey_nonprob (§B, §C, §D, §E)
#
#   B-1.  The replicate shape returns a svyrep.design and raises nothing
#   B-2.  The replicate shape keeps all eight replicate columns
#   B-3.  The plain shape returns a survey.design2 and warns
#   B-4.  The plain-shape warning message [snapshot]
#   B-5.  Export parity on the replicate shape [numerical]
#   B-6.  Export parity on the plain shape [numerical]
#   B-7.  Neither shape raises the replicate FPC drop warning
#   B-9.  Default confint() parity on the replicate shape [numerical]
#   B-10. Default confint() parity on the plain shape [numerical]
#   B-11. A plain shape carrying one zero-weight row converts and matches
#   C-1.  as_tbl_svy() converts the replicate shape
#   C-2.  as_tbl_svy() converts the plain shape and propagates the warning
#   D-1.  The round trip returns a probability design, not a nonprob one
#   D-2.  The rebuilt design stops raising the SRS fallback warning
#   E-4.  The replicate shape raises no not-survey-object refusal
# ─────────────────────────────────────────────────────────────────────────────

# Fixture 1. A 40-row non-probability design, in either shape. The frame comes
# from make_survey_data(); its weight column is renamed cal_wt so it reads as a
# calibration weight, and the design variables psu, strata and fpc are dropped,
# because as_survey_nonprob() names none of them and a nonprob design records
# ids, strata and fpc as NULL in both shapes.
#
# Eight replicate columns is the count the roxygen's degrees-of-freedom section
# states: survey::degf() answers 7 on the replicate shape, against 39 on the
# plain shape of the same 40 rows.
make_nonprob <- function(shape = c("replicate", "plain"), seed = 601L) {
  shape <- match.arg(shape)
  df <- make_survey_data(
    n = 40L,
    n_psu = 8L,
    n_strata = 2L,
    design = "taylor",
    seed = seed
  )
  df$cal_wt <- df$wt
  df <- df[, c("cal_wt", "y1", "y2", "y3")]

  if (identical(shape, "plain")) {
    return(as_survey_nonprob(df, weights = cal_wt))
  }

  # Independent perturbations, so the replicate matrix has full column rank
  # and survey::degf() answers R - 1 rather than less.
  set.seed(seed)
  for (i in seq_len(8L)) {
    df[[paste0("bw_", i)]] <- df$cal_wt * stats::runif(nrow(df), 0.85, 1.15)
  }
  as_survey_nonprob(
    df,
    weights = cal_wt,
    repweights = tidyselect::all_of(paste0("bw_", seq_len(8L))),
    type = "bootstrap"
  )
}


# B-1. The replicate shape routes to .as_svydesign_replicate(). Before this
#      change the call raised surveycore_error_not_survey_object, which is
#      issue #237's defect. This is the file's only as_survey_nonprob()
#      invariant call, per the once-per-constructor-per-file rule.
test_that("as_svydesign() converts a replicate-shaped survey_nonprob", {
  skip_if_not_installed("survey")
  d <- make_nonprob("replicate")
  test_invariants(d)

  expect_no_condition(sv <- as_svydesign(d))
  expect_true(inherits(sv, "svyrep.design"))
})


# B-3. The plain shape routes to .as_svydesign_taylor(), and the route warns
#      first. The result comes off the return value of the warned call, so the
#      block asserts the conversion succeeded as well as that it warned.
test_that("as_svydesign() converts a plain-shaped survey_nonprob and warns", {
  skip_if_not_installed("survey")
  d <- make_nonprob("plain")

  expect_warning(
    sv <- as_svydesign(d),
    class = "surveycore_warning_nonprob_srs_conversion"
  )
  expect_true(inherits(sv, "survey.design2"))
})


# B-2. The replicate columns have to survive the conversion, or the converted
#      design would compute a different variance. survey stores the analysis
#      weights as an n-by-R matrix, and the column names reach the returned
#      design's own data frame.
test_that("as_svydesign() keeps every replicate column of a nonprob design", {
  skip_if_not_installed("survey")
  d <- make_nonprob("replicate")
  sv <- as_svydesign(d)

  expect_identical(ncol(stats::weights(sv, "analysis")), 8L)
  expect_true(all(paste0("bw_", seq_len(8L)) %in% names(sv$variables)))
})


# B-4. The golden copy of the plain-shape message. C-1 and C-2 raise the same
#      warning through as_tbl_svy() and write no second snapshot of it.
test_that("as_svydesign() reports the plain-shape nonprob conversion", {
  skip_if_not_installed("survey")
  d <- make_nonprob("plain")
  expect_snapshot(sv <- as_svydesign(d))
})


# B-7. A nonprob design records fpc as NULL in both shapes, so branch 4a
#      reaches .as_svydesign_replicate() without triggering that helper's FPC
#      drop warning. The plain shape raises the SRS conversion warning, which
#      the outer expectation captures; the inner one asserts the absence.
test_that("neither nonprob shape raises the replicate FPC drop warning", {
  skip_if_not_installed("survey")
  d_rep <- make_nonprob("replicate")
  expect_no_warning(
    sv_rep <- as_svydesign(d_rep),
    class = "surveycore_warning_replicate_fpc_dropped"
  )
  expect_true(inherits(sv_rep, "svyrep.design"))

  d_plain <- make_nonprob("plain")
  expect_warning(
    expect_no_warning(
      sv_plain <- as_svydesign(d_plain),
      class = "surveycore_warning_replicate_fpc_dropped"
    ),
    class = "surveycore_warning_nonprob_srs_conversion"
  )
  expect_true(inherits(sv_plain, "survey.design2"))
})


# B-5. The point of routing on the shape: the converted design has to report
#      the standard error surveycore reports. The expectation is computed in
#      the block from the source design, never pasted as a literal — a printed
#      figure carries fewer digits than the 1e-8 tolerance resolves.
test_that("as_svydesign() reproduces a replicate nonprob's mean and SE [numerical]", {
  skip_if_not_installed("survey")
  d <- make_nonprob("replicate")
  sc <- get_means(d, y1, variance = "se")

  sv <- as_svydesign(d)
  sm <- survey::svymean(~y1, sv)
  expect_equal(coef(sm)[["y1"]], sc$mean[[1L]], tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sm)), sc$se[[1L]], tolerance = 1e-8)
})


# B-6. The same equality on the plain shape. Two warnings fire here for two
#      different reasons: get_means() raises surveycore's own SRS fallback,
#      which is existing behaviour and not this block's subject, and
#      as_svydesign() raises the conversion warning.
test_that("as_svydesign() reproduces a plain nonprob's mean and SE [numerical]", {
  skip_if_not_installed("survey")
  d <- make_nonprob("plain")
  expect_warning(
    sc <- get_means(d, y1, variance = "se"),
    class = "surveycore_warning_nonprob_srs_fallback"
  )

  expect_warning(
    sv <- as_svydesign(d),
    class = "surveycore_warning_nonprob_srs_conversion"
  )
  sm <- survey::svymean(~y1, sv)
  expect_equal(coef(sm)[["y1"]], sc$mean[[1L]], tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sm)), sc$se[[1L]], tolerance = 1e-8)
})


# B-9. The default confint() call on a svrepstat uses df = Inf, which is the
#      degrees of freedom surveycore reports for a nonprob design, so the
#      default intervals agree. The block builds its own fixture and converts
#      it again rather than reading an object B-5 left behind.
test_that("default confint() on a converted replicate nonprob matches [numerical]", {
  skip_if_not_installed("survey")
  d <- make_nonprob("replicate")
  sc_ci <- get_means(d, y1, variance = "ci")

  sv <- as_svydesign(d)
  bounds <- as.numeric(confint(survey::svymean(~y1, sv)))
  expect_equal(bounds[[1L]], sc_ci$ci_low[[1L]], tolerance = 1e-6)
  expect_equal(bounds[[2L]], sc_ci$ci_high[[1L]], tolerance = 1e-6)
})


# B-10. The same on the plain shape, and the same two warnings as B-6.
test_that("default confint() on a converted plain nonprob matches [numerical]", {
  skip_if_not_installed("survey")
  d <- make_nonprob("plain")
  expect_warning(
    sc_ci <- get_means(d, y1, variance = "ci"),
    class = "surveycore_warning_nonprob_srs_fallback"
  )

  expect_warning(
    sv <- as_svydesign(d),
    class = "surveycore_warning_nonprob_srs_conversion"
  )
  bounds <- as.numeric(confint(survey::svymean(~y1, sv)))
  expect_equal(bounds[[1L]], sc_ci$ci_low[[1L]], tolerance = 1e-6)
  expect_equal(bounds[[2L]], sc_ci$ci_high[[1L]], tolerance = 1e-6)
})


# Fixture 2. The plain shape with one weight set to 0. The design cannot be
# constructed this way: .validate_weights() rejects any non-positive weight
# with surveycore_error_weights_nonpositive. So the fixture is built in two
# steps — construct normally, then write the edited frame back into @data. The
# survey_nonprob validator checks only that no weight is negative and that the
# column holds at least one positive value, so a single zero passes it. The
# survey_taylor and survey_replicate validators repeat the strict check, which
# is why this fixture exists on this class alone.
make_nonprob_zero_wt <- function(seed = 601L) {
  d <- make_nonprob("plain", seed = seed)
  df <- survey_data(d)
  df$cal_wt[[1L]] <- 0
  d@data <- df
  d
}


# B-11. A zero-weight row costs the bridge nothing: both sides still agree
#       exactly. survey::degf() answers 38 rather than 39 on this design,
#       because it counts only the rows whose weight is not zero; the roxygen
#       carries that qualifier and no code guards the case.
test_that("as_svydesign() converts a nonprob design carrying a zero weight [numerical]", {
  skip_if_not_installed("survey")
  d <- make_nonprob_zero_wt()
  expect_warning(
    sc <- get_means(d, y1, variance = "se"),
    class = "surveycore_warning_nonprob_srs_fallback"
  )

  expect_warning(
    sv <- as_svydesign(d),
    class = "surveycore_warning_nonprob_srs_conversion"
  )
  expect_true(inherits(sv, "survey.design2"))

  sm <- survey::svymean(~y1, sv)
  expect_equal(coef(sm)[["y1"]], sc$mean[[1L]], tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sm)), sc$se[[1L]], tolerance = 1e-8)
})


# C-1. as_tbl_svy() needs no edit of its own. Its guard tests survey_base,
#      which a survey_nonprob design already inherits, so the wrapper starts
#      accepting both shapes the moment as_svydesign() does.
test_that("as_tbl_svy() converts a replicate-shaped survey_nonprob", {
  skip_if_not_installed("survey")
  skip_if_not_installed("srvyr")
  d <- make_nonprob("replicate")
  ts <- as_tbl_svy(d)
  expect_true(inherits(ts, "tbl_svy"))
})


# C-2. The conversion warning propagates through the wrapper, because
#      as_tbl_svy() calls as_svydesign() and raises no condition of its own.
#      B-4 holds the golden copy of the message, so this block writes no
#      second snapshot of it.
test_that("as_tbl_svy() propagates the plain-shape nonprob warning", {
  skip_if_not_installed("survey")
  skip_if_not_installed("srvyr")
  d <- make_nonprob("plain")

  expect_warning(
    ts <- as_tbl_svy(d),
    class = "surveycore_warning_nonprob_srs_conversion"
  )
  expect_true(inherits(ts, "tbl_svy"))
})


# D-1. The round trip loses the non-probability identity. A survey object
#      records nothing that marks a sample as non-probability, so
#      from_svydesign() rebuilds a probability design on data that has not
#      changed.
test_that("the nonprob round trip returns a probability design", {
  skip_if_not_installed("survey")
  d <- make_nonprob("replicate")
  rebuilt <- from_svydesign(as_svydesign(d))

  expect_true(S7::S7_inherits(rebuilt, survey_replicate))
  expect_false(S7::S7_inherits(rebuilt, survey_nonprob))
})


# D-2. The consequence a caller feels: the rebuilt design reports design-based
#      standard errors and stops warning about the SRS approximation. The
#      block rebuilds its own design rather than reading D-1's.
test_that("the rebuilt design no longer warns about the SRS approximation", {
  skip_if_not_installed("survey")
  d <- make_nonprob("replicate")
  rebuilt <- from_svydesign(as_svydesign(d))

  expect_no_warning(
    result <- get_means(rebuilt, y1, variance = "se"),
    class = "surveycore_warning_nonprob_srs_fallback"
  )
  expect_true(is.finite(result$se[[1L]]))
})


# E-4. The nonprob branch takes both shapes out of the else branch, so the
#      refusal no longer reaches a design that inherits survey_base. The
#      replicate shape is the shape that raises no other condition, so it is
#      the one this absence can be asserted on cleanly.
test_that("as_svydesign() raises no refusal for a replicate-shaped nonprob", {
  skip_if_not_installed("survey")
  d <- make_nonprob("replicate")
  expect_no_error(
    sv <- as_svydesign(d),
    class = "surveycore_error_not_survey_object"
  )
  expect_true(inherits(sv, "svyrep.design"))
})


# ── Domain restriction on the Taylor route ───────────────────────────────────
#
# Issue #245. A design that surveytidy's filter() has marked keeps every row
# and records domain membership in the column SURVEYCORE_DOMAIN_COL names.
# as_svydesign() used to pass that column through as ordinary data, so
# survey::svymean() on the converted object answered for the full sample.
# .as_svydesign_taylor() now indexes the object it builds by the marker, so
# the converted object answers the domain estimate.
#
# This section covers the Taylor route and the survey_nonprob shape that names
# no replicate weights, because as_svydesign() sends that shape into the same
# helper after its SRS warning.

# Fixture. A 50-row stratified cluster design with a domain marked by hand.
# The mask splits on y1's median, so it keeps rows in both strata and thins no
# stratum to one PSU.
make_filtered_taylor <- function(seed = 42L) {
  d <- make_taylor(seed = seed)
  df <- survey_data(d)
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- df$y1 > stats::median(df$y1)
  d@data <- df
  d
}


# The estimate a caller reads off the converted object is the domain estimate
# and not the full-sample one. get_means() on the filtered design is the
# reference, because that is the answer the same design already gives through
# surveycore's own estimator.
test_that("as_svydesign() converts a filtered Taylor design to the domain [numerical]", {
  skip_if_not_installed("survey")
  d <- make_filtered_taylor()
  mask <- survey_data(d)[[surveycore::SURVEYCORE_DOMAIN_COL]]
  # min_cell_n = 1 keeps the AAPOR small-cell warning out of the way. The
  # domain holds 25 rows and the default threshold is 30; the estimate itself
  # does not depend on the argument.
  sc <- get_means(d, y1, variance = "se", min_cell_n = 1L)

  sv <- as_svydesign(d)
  sm <- survey::svymean(~y1, sv)

  expect_identical(nrow(sv$variables), sum(mask))
  expect_equal(coef(sm)[["y1"]], sc$mean[[1L]], tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sm)), sc$se[[1L]], tolerance = 1e-8)
})


# The same agreement on a marker that surveytidy's filter() wrote, rather than
# one written by hand. filter() is how a domain arrives in practice, and it
# records the column this helper reads.
test_that("as_svydesign() converts a filter()-marked Taylor design to the domain [numerical]", {
  skip_if_not_installed("survey")
  skip_if_not_installed("surveytidy")
  d <- surveytidy::filter(make_taylor(), y1 > 50)
  mask <- survey_data(d)[[surveycore::SURVEYCORE_DOMAIN_COL]]
  sc <- get_means(d, y1, variance = "se", min_cell_n = 1L)

  sv <- as_svydesign(d)
  sm <- survey::svymean(~y1, sv)

  expect_identical(nrow(sv$variables), sum(mask))
  expect_equal(coef(sm)[["y1"]], sc$mean[[1L]], tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sm)), sc$se[[1L]], tolerance = 1e-8)
})


# The same agreement on a real design. nhanes_2017 has 9,254 rows in 15 strata,
# so the domain leaves every stratum populated and the two estimators are
# compared on a design no synthetic generator produced.
test_that("as_svydesign() converts a filtered nhanes design to the domain [numerical]", {
  skip_if_not_installed("survey")
  d <- as_survey(
    nhanes_2017,
    ids = sdmvpsu,
    weights = wtint2yr,
    strata = sdmvstra,
    nest = TRUE
  )
  df <- survey_data(d)
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- df$riagendr == 1
  d@data <- df
  sc <- get_means(d, ridageyr, variance = "se")

  sv <- as_svydesign(d)
  sm <- survey::svymean(~ridageyr, sv, na.rm = TRUE)

  expect_identical(nrow(sv$variables), sum(df$riagendr == 1))
  expect_equal(coef(sm)[["ridageyr"]], sc$mean[[1L]], tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sm)), sc$se[[1L]], tolerance = 1e-8)
})


# The Taylor call site serves a second input shape. as_svydesign() sends a
# survey_nonprob design that names no replicate weights into
# .as_svydesign_taylor() after its SRS warning, so the restriction reaches
# that shape with no branch of its own. The two conversion warnings are
# pre-existing and the restriction changes neither.
test_that("as_svydesign() converts a filtered plain-shaped nonprob to the domain [numerical]", {
  skip_if_not_installed("survey")
  d <- make_nonprob("plain")
  df <- survey_data(d)
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- df$y1 > stats::median(df$y1)
  d@data <- df
  mask <- df[[surveycore::SURVEYCORE_DOMAIN_COL]]

  expect_warning(
    sc <- get_means(d, y1, variance = "se", min_cell_n = 1L),
    class = "surveycore_warning_nonprob_srs_fallback"
  )
  expect_warning(
    sv <- as_svydesign(d),
    class = "surveycore_warning_nonprob_srs_conversion"
  )

  sm <- survey::svymean(~y1, sv)
  expect_identical(nrow(sv$variables), sum(mask))
  expect_equal(coef(sm)[["y1"]], sc$mean[[1L]], tolerance = 1e-10)

  # The standard error agrees too. It did not until PR #263:
  # .calibrated_mean_cell() took its finite correction from the domain size,
  # n_d / (n_d - 1), where survey::svymean() takes it from the full sample,
  # n / (n - 1), because survey's `[` keeps each retained row's recorded
  # stratum sample size. The two stood in exactly that ratio. #263 re-based
  # the correction on the full sample, so this is now a plain parity check.
  expect_equal(as.numeric(survey::SE(sm)), sc$se[[1L]], tolerance = 1e-8)

  # The same frame and the same domain, converted through as_survey() rather
  # than as_survey_nonprob(), gives the same standard error. The calibrated
  # fallback and the Taylor estimator agree on a domain, which is the
  # property #263 established and this block keeps under guard.
  sc_taylor <- get_means(
    as_survey(df, weights = cal_wt),
    y1,
    variance = "se",
    min_cell_n = 1L
  )
  expect_equal(
    as.numeric(survey::SE(sm)),
    sc_taylor$se[[1L]],
    tolerance = 1e-8
  )

  # The marker column stays in the converted object's data, and every value
  # left in it is TRUE.
  expect_true(surveycore::SURVEYCORE_DOMAIN_COL %in% names(sv$variables))
  expect_true(all(sv$variables[[surveycore::SURVEYCORE_DOMAIN_COL]]))
})


# An unfiltered design carries no marker column, so the helper returns the
# object un-indexed and the conversion is what it was before this change.
test_that("as_svydesign() converts an unfiltered Taylor design unrestricted", {
  skip_if_not_installed("survey")
  d <- make_taylor()

  # No marker column means no indexing step, so nothing at all fires here.
  # The filtered case has the same requirement and no pre-existing condition
  # to tolerate either.
  expect_no_condition(sv <- as_svydesign(d))
  expect_identical(nrow(sv$variables), nrow(survey_data(d)))
  expect_false(surveycore::SURVEYCORE_DOMAIN_COL %in% names(sv$variables))
})


# A marker that selects everything is indexed anyway. There is no all-TRUE
# column to detect on an unfiltered design, so presence of the column is the
# whole guard, and indexing by an all-TRUE mask has to cost nothing.
test_that("as_svydesign() converts an all-TRUE marker to every row [numerical]", {
  skip_if_not_installed("survey")
  d <- make_taylor()
  df <- survey_data(d)
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- rep(TRUE, nrow(df))
  d@data <- df
  sc <- get_means(d, y1, variance = "se")

  sv <- as_svydesign(d)
  sm <- survey::svymean(~y1, sv)

  expect_identical(nrow(sv$variables), nrow(df))
  expect_equal(coef(sm)[["y1"]], sc$mean[[1L]], tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sm)), sc$se[[1L]], tolerance = 1e-8)
})


# The route restricts the object it built and never the design it was given,
# so the same design converts the same way twice.
test_that("as_svydesign() leaves the input design unchanged", {
  skip_if_not_installed("survey")
  d <- make_filtered_taylor()
  n_before <- nrow(survey_data(d))
  mask_before <- survey_data(d)[[surveycore::SURVEYCORE_DOMAIN_COL]]

  sv1 <- as_svydesign(d)

  expect_identical(nrow(survey_data(d)), n_before)
  expect_identical(
    survey_data(d)[[surveycore::SURVEYCORE_DOMAIN_COL]],
    mask_before
  )

  sv2 <- as_svydesign(d)
  expect_identical(nrow(sv2$variables), nrow(sv1$variables))
})


# The round trip is the guard on the choice of `[` over subset(). survey's
# subset() methods overwrite the stored call, and from_svydesign() reads the
# design variables back out of that call inside a tryCatch that returns NULL
# on failure — so a lost call reads as a design that names no ids and no
# strata, with nothing raised.
test_that("the round trip on a filtered Taylor design recovers the design variables", {
  skip_if_not_installed("survey")
  keys <- c("ids", "strata", "weights")
  filtered <- from_svydesign(as_svydesign(make_filtered_taylor()))
  unfiltered <- from_svydesign(as_svydesign(make_taylor()))

  expect_identical(filtered@variables[keys], unfiltered@variables[keys])
})


# The comparison above is only worth something if the unfiltered round trip
# names all three, so that block asserts it.
test_that("the round trip on an unfiltered Taylor design names ids, strata and weights", {
  skip_if_not_installed("survey")
  rebuilt <- from_svydesign(as_svydesign(make_taylor()))

  expect_identical(rebuilt@variables$ids, "psu")
  expect_identical(rebuilt@variables$strata, "strata")
  expect_identical(rebuilt@variables$weights, "wt")
})


# The mechanism behind the two blocks above: `[` never rewrites the stored
# call, so the expression from_svydesign() parses is the same expression on a
# filtered design as on an unfiltered one.
test_that("the restriction leaves the converted object's stored call unchanged", {
  skip_if_not_installed("survey")
  filtered <- as_svydesign(make_filtered_taylor())
  unfiltered <- as_svydesign(make_taylor())

  expect_identical(deparse(filtered$call), deparse(unfiltered$call))
})


# The restriction raises nothing of its own on this route, for any domain.
# as.logical() is what makes the claim hold for a marker column that is not
# logical; a character column raised an unclassed base error without it.
test_that("as_svydesign() raises no condition on a filtered Taylor design", {
  skip_if_not_installed("survey")
  expect_no_condition(sv <- as_svydesign(make_filtered_taylor()))
  expect_true(inherits(sv, "survey.design2"))
})


# The marker column's type does not change which rows survive. Nothing in the
# package guarantees the column is logical, no validator checks its type, and
# code in this repository already writes an integer one. as.logical() is what
# makes the mask work on all five types: `&` alone errors on a character
# column and returns an all-NA mask on a factor one, which yields an object
# that later dies inside survey with `invalid 'type' (list) of argument`.
test_that("as_svydesign() selects the same rows for every marker column type", {
  skip_if_not_installed("survey")
  d <- make_taylor()
  df <- survey_data(d)
  mask <- df$y1 > stats::median(df$y1)

  markers <- list(
    logical = mask,
    integer = as.integer(mask),
    double = as.numeric(mask),
    character = as.character(mask),
    factor = factor(mask, levels = c(FALSE, TRUE))
  )

  for (nm in names(markers)) {
    df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- markers[[nm]]
    d@data <- df
    expect_no_condition(sv <- as_svydesign(d))
    expect_identical(nrow(sv$variables), sum(mask), info = nm)

    # The row count alone passes on a corrupt object, so the probabilities
    # are checked too. Indexing by the all-NA mask that `&` returned on the
    # factor marker gave an object whose probability vector was neither
    # finite nor infinite; estimating on it died three frames down inside
    # survey with `invalid 'type' (list) of argument`. A numeric probability
    # vector with a finite value for every retained row is the state that
    # cannot hold on such an object. The two tests are one expectation so
    # that a list-valued vector fails here rather than erroring in
    # is.finite().
    expect_true(
      is.numeric(sv$prob) && all(is.finite(sv$prob)),
      info = nm
    )
  }
})


# A factor whose levels say nothing about domain membership converts to all
# NA, which the mask reads as an empty domain. That is safe and inspectable,
# where `&` alone gave a 200-row object with a corrupt probability vector.
test_that("as_svydesign() reads an unconvertible marker as an empty domain", {
  skip_if_not_installed("survey")
  d <- make_taylor()
  df <- survey_data(d)
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- factor(
    rep(c("yes", "no"), length.out = nrow(df))
  )
  d@data <- df

  expect_no_condition(sv <- as_svydesign(d))
  expect_identical(nrow(sv$variables), 0L)
})


# A row whose marker is NA falls outside the domain. `!is.na(r)` does this,
# and it also absorbs the NA that as.logical() returns for a value it cannot
# convert.
test_that("as_svydesign() treats an NA marker row as outside the domain", {
  skip_if_not_installed("survey")
  d <- make_taylor()
  df <- survey_data(d)
  mask <- df$y1 > stats::median(df$y1)
  mask[[which(mask)[[1L]]]] <- NA
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- mask
  d@data <- df

  expect_no_condition(sv <- as_svydesign(d))
  expect_identical(nrow(sv$variables), sum(mask, na.rm = TRUE))
})


# A filter that matches no row still converts, and the conversion raises no
# condition. On the Taylor route the caller then reads 0 with a standard error
# of 0 out of survey; the empty object is survey's to interpret, not this
# helper's to refuse.
test_that("as_svydesign() converts an all-FALSE marker to a zero-row object", {
  skip_if_not_installed("survey")
  d <- make_taylor()
  df <- survey_data(d)
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- rep(FALSE, nrow(df))
  d@data <- df

  expect_no_condition(sv <- as_svydesign(d))
  expect_identical(nrow(sv$variables), 0L)

  sm <- survey::svymean(~y1, sv)
  expect_equal(coef(sm)[["y1"]], 0, tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sm)), 0, tolerance = 1e-8)
})


# A marker with exactly one TRUE gives a one-row object, and the conversion
# raises nothing. survey's `[` is content with one row; what survey reports if
# a caller then estimates on that object belongs to survey, so this block
# asserts nothing about estimation.
test_that("as_svydesign() converts a single-TRUE marker to a one-row object", {
  skip_if_not_installed("survey")
  d <- make_taylor()
  df <- survey_data(d)
  mask <- rep(FALSE, nrow(df))
  mask[[1L]] <- TRUE
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- mask
  d@data <- df

  expect_no_condition(sv <- as_svydesign(d))
  expect_identical(nrow(sv$variables), 1L)
})


# A marker of nothing but NA is the all-FALSE case reached by the other half
# of the mask: as.logical() leaves the NAs alone and `!is.na(r)` drops every
# row. On the Taylor route the empty object then answers 0 with a standard
# error of 0, as it does for an all-FALSE marker.
test_that("as_svydesign() converts an all-NA marker to a zero-row object", {
  skip_if_not_installed("survey")
  d <- make_taylor()
  df <- survey_data(d)
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- rep(NA, nrow(df))
  d@data <- df

  expect_no_condition(sv <- as_svydesign(d))
  expect_identical(nrow(sv$variables), 0L)

  sm <- survey::svymean(~y1, sv)
  expect_equal(coef(sm)[["y1"]], 0, tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sm)), 0, tolerance = 1e-8)
})


# as_tbl_svy() inherits the restriction with no edit of its own. It calls
# as_svydesign() and wraps the result, so the tbl_svy it hands to srvyr
# carries one row per marked row.
test_that("as_tbl_svy() inherits the restriction on a filtered Taylor design", {
  skip_if_not_installed("survey")
  skip_if_not_installed("srvyr")
  d <- make_filtered_taylor()
  mask <- survey_data(d)[[surveycore::SURVEYCORE_DOMAIN_COL]]

  ts <- as_tbl_svy(d)

  expect_true(inherits(ts, "tbl_svy"))
  expect_identical(nrow(ts$variables), sum(mask))
})


# The round trip agrees with the converted object on the numbers, not only on
# the design variables. The rebuilt design is a design over the domain rows
# carrying an all-TRUE marker, so surveycore's own estimator answers what
# survey answers on the object the rebuild read.
test_that("the round trip on a filtered Taylor design agrees on the numbers [numerical]", {
  skip_if_not_installed("survey")
  d <- make_filtered_taylor()
  sv <- as_svydesign(d)
  sm <- survey::svymean(~y1, sv)
  ci <- stats::confint(sm)

  rebuilt <- from_svydesign(sv)
  # min_cell_n = 1 keeps the AAPOR small-cell warning out of the way. The
  # domain holds 25 rows and the default threshold is 30.
  sc <- get_means(rebuilt, y1, variance = c("se", "ci"), min_cell_n = 1L)

  expect_equal(sc$mean[[1L]], coef(sm)[["y1"]], tolerance = 1e-10)
  expect_equal(sc$se[[1L]], as.numeric(survey::SE(sm)), tolerance = 1e-8)
  expect_equal(sc$ci_low[[1L]], ci[[1L, 1L]], tolerance = 1e-6)
  expect_equal(sc$ci_high[[1L]], ci[[1L, 2L]], tolerance = 1e-6)
})


# The all-TRUE marker column travels back into the rebuilt design, where the
# print method reads it and reports a domain. The original N is unrecoverable
# from a survey object, which records a subset and not a marker, so the
# rebuilt design's row count is its new total and the line names the same
# number twice.
test_that("the round trip on a filtered Taylor design prints n of n rows", {
  skip_if_not_installed("survey")
  rebuilt <- from_svydesign(as_svydesign(make_filtered_taylor()))
  df <- survey_data(rebuilt)
  n <- nrow(df)

  expect_true(surveycore::SURVEYCORE_DOMAIN_COL %in% names(df))
  expect_true(all(df[[surveycore::SURVEYCORE_DOMAIN_COL]]))

  # The inner capture takes the tibble on stdout, the outer one takes the cli
  # text on the message stream, so the block prints nothing during a run.
  out <- capture.output(
    invisible(capture.output(print(rebuilt))),
    type = "message"
  )
  expect_true(any(grepl(
    paste0("Domain: ", n, " of ", n, " rows"),
    out,
    fixed = TRUE
  )))
})


# ── Domain restriction on the replicate route and both nonprob shapes ────────
#
# Issue #245, the second call site. .as_svydesign_replicate() now indexes the
# object it builds by the marker column, exactly as .as_svydesign_taylor()
# does. One call site serves two input shapes: a survey_replicate design, and
# a survey_nonprob design that names replicate weights, which as_svydesign()
# already sends here on the shape of the weights. The section also covers the
# survey_nonprob shape that names none, because that shape reaches the Taylor
# call site and its SRS warning has to keep its class and its count.

# Fixture. The file's 50-row BRR replicate design with a domain marked by
# hand. The mask splits on y1's median, so it keeps rows in both strata.
make_filtered_rep <- function(seed = 42L) {
  d <- make_rep(seed = seed)
  df <- survey_data(d)
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- df$y1 > stats::median(df$y1)
  d@data <- df
  d
}

# Fixture. The file's 40-row non-probability design in either shape, with a
# domain marked the same way.
make_filtered_nonprob <- function(
  shape = c("replicate", "plain"),
  seed = 601L
) {
  d <- make_nonprob(match.arg(shape), seed = seed)
  df <- survey_data(d)
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- df$y1 > stats::median(df$y1)
  d@data <- df
  d
}


# The estimate a caller reads off the converted object is the domain estimate
# and not the full-sample one. get_means() on the filtered design is the
# reference, because that is the answer the same design already gives through
# surveycore's own replicate estimator.
test_that("as_svydesign() converts a filtered replicate design to the domain [numerical]", {
  skip_if_not_installed("survey")
  d <- make_filtered_rep()
  mask <- survey_data(d)[[surveycore::SURVEYCORE_DOMAIN_COL]]
  # min_cell_n = 1 keeps the AAPOR small-cell warning out of the way. The
  # domain holds 25 rows against a default threshold of 30, and the argument
  # does not touch the estimate.
  sc <- get_means(d, y1, variance = "se", min_cell_n = 1L)

  sv <- as_svydesign(d)
  sm <- survey::svymean(~y1, sv)

  expect_identical(nrow(sv$variables), sum(mask))
  expect_equal(coef(sm)[["y1"]], sc$mean[[1L]], tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sm)), sc$se[[1L]], tolerance = 1e-8)

  # The marker column stays in the converted object's data, and every value
  # left in it is TRUE.
  expect_true(surveycore::SURVEYCORE_DOMAIN_COL %in% names(sv$variables))
  expect_true(all(sv$variables[[surveycore::SURVEYCORE_DOMAIN_COL]]))
})


# The same agreement on a marker that surveytidy's filter() wrote rather than
# one written by hand. filter() is how a domain arrives in practice, and it
# records the column this helper reads.
test_that("as_svydesign() converts a filter()-marked replicate design to the domain [numerical]", {
  skip_if_not_installed("survey")
  skip_if_not_installed("surveytidy")
  d <- surveytidy::filter(make_rep(), y1 > 50)
  mask <- survey_data(d)[[surveycore::SURVEYCORE_DOMAIN_COL]]
  sc <- get_means(d, y1, variance = "se", min_cell_n = 1L)

  sv <- as_svydesign(d)
  sm <- survey::svymean(~y1, sv)

  expect_identical(nrow(sv$variables), sum(mask))
  expect_equal(coef(sm)[["y1"]], sc$mean[[1L]], tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sm)), sc$se[[1L]], tolerance = 1e-8)
})


# The replicate call site serves a second input shape. as_svydesign() routes a
# survey_nonprob design that names replicate weights into
# .as_svydesign_replicate(), so the restriction reaches that shape with no
# branch of its own and no ninth copy of the routing predicate.
test_that("as_svydesign() converts a filtered replicate nonprob to the domain [numerical]", {
  skip_if_not_installed("survey")
  d <- make_filtered_nonprob("replicate")
  mask <- survey_data(d)[[surveycore::SURVEYCORE_DOMAIN_COL]]
  sc <- get_means(d, y1, variance = "se", min_cell_n = 1L)

  sv <- as_svydesign(d)
  sm <- survey::svymean(~y1, sv)

  expect_identical(nrow(sv$variables), sum(mask))
  expect_equal(coef(sm)[["y1"]], sc$mean[[1L]], tolerance = 1e-10)
  expect_equal(as.numeric(survey::SE(sm)), sc$se[[1L]], tolerance = 1e-8)

  expect_true(surveycore::SURVEYCORE_DOMAIN_COL %in% names(sv$variables))
  expect_true(all(sv$variables[[surveycore::SURVEYCORE_DOMAIN_COL]]))
})


# An unfiltered replicate design carries no marker column, so the helper
# returns the object un-indexed and the conversion is what it was before this
# change. This fixture records no FPC, so nothing at all may fire.
test_that("as_svydesign() converts an unfiltered replicate design unrestricted", {
  skip_if_not_installed("survey")
  d <- make_rep()

  expect_no_condition(sv <- as_svydesign(d))
  expect_identical(nrow(sv$variables), nrow(survey_data(d)))
  expect_false(surveycore::SURVEYCORE_DOMAIN_COL %in% names(sv$variables))
})


# The same on the unfiltered replicate-shaped nonprob design, which reaches
# the same call site.
test_that("as_svydesign() converts an unfiltered replicate nonprob unrestricted", {
  skip_if_not_installed("survey")
  d <- make_nonprob("replicate")

  expect_no_condition(sv <- as_svydesign(d))
  expect_identical(nrow(sv$variables), nrow(survey_data(d)))
  expect_false(surveycore::SURVEYCORE_DOMAIN_COL %in% names(sv$variables))
})


# The unfiltered plain-shaped nonprob design raises the one condition that
# shape already raises, and no other. The SRS warning fires in as_svydesign()
# itself, before dispatch, so the restriction can neither double it nor
# suppress it.
test_that("as_svydesign() converts an unfiltered plain nonprob unrestricted", {
  skip_if_not_installed("survey")
  d <- make_nonprob("plain")

  expect_no_warning(
    expect_warning(
      sv <- as_svydesign(d),
      class = "surveycore_warning_nonprob_srs_conversion"
    )
  )
  expect_identical(nrow(sv$variables), nrow(survey_data(d)))
  expect_false(surveycore::SURVEYCORE_DOMAIN_COL %in% names(sv$variables))
})


# A filter that matches no row still converts, and the conversion raises no
# condition. What the caller then reads out of survey is survey's to decide:
# on the replicate route survey refuses to estimate on an empty object, with
# an untyped error of its own. The block asserts that error by message, with
# no class and no snapshot, because the condition is not surveycore's.
test_that("as_svydesign() converts an all-FALSE marker on the replicate route to zero rows", {
  skip_if_not_installed("survey")
  d <- make_rep()
  df <- survey_data(d)
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- rep(FALSE, nrow(df))
  d@data <- df

  expect_no_condition(sv <- as_svydesign(d))
  expect_identical(nrow(sv$variables), 0L)

  expect_error(survey::svymean(~y1, sv), "All replicates contained NAs")
})


# The same empty domain on the replicate-shaped nonprob design: zero rows and
# nothing raised by the conversion.
test_that("as_svydesign() converts an all-FALSE marker on a replicate nonprob to zero rows", {
  skip_if_not_installed("survey")
  d <- make_nonprob("replicate")
  df <- survey_data(d)
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- rep(FALSE, nrow(df))
  d@data <- df

  expect_no_condition(sv <- as_svydesign(d))
  expect_identical(nrow(sv$variables), 0L)
})


# The same empty domain on the plain-shaped nonprob design: zero rows, and
# the SRS warning alone.
test_that("as_svydesign() converts an all-FALSE marker on a plain nonprob to zero rows", {
  skip_if_not_installed("survey")
  d <- make_nonprob("plain")
  df <- survey_data(d)
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- rep(FALSE, nrow(df))
  d@data <- df

  expect_no_warning(
    expect_warning(
      sv <- as_svydesign(d),
      class = "surveycore_warning_nonprob_srs_conversion"
    )
  )
  expect_identical(nrow(sv$variables), 0L)
})


# as_tbl_svy() inherits the restriction on the nonprob shape that names no
# replicate weights, with no edit of its own: it calls as_svydesign() and
# wraps the result, so it propagates the SRS warning and the domain rows
# together.
test_that("as_tbl_svy() inherits the restriction on a filtered plain nonprob", {
  skip_if_not_installed("survey")
  skip_if_not_installed("srvyr")
  d <- make_filtered_nonprob("plain")
  mask <- survey_data(d)[[surveycore::SURVEYCORE_DOMAIN_COL]]

  expect_warning(
    ts <- as_tbl_svy(d),
    class = "surveycore_warning_nonprob_srs_conversion"
  )

  expect_true(inherits(ts, "tbl_svy"))
  expect_identical(nrow(ts$variables), sum(mask))
})


# The restriction adds no condition of its own on either shape that reaches
# the replicate call site, whatever the domain.
test_that("as_svydesign() raises no condition on a filtered replicate design", {
  skip_if_not_installed("survey")
  expect_no_condition(as_svydesign(make_filtered_rep()))
  expect_no_condition(as_svydesign(make_filtered_nonprob("replicate")))
})


# On the filtered plain-shaped nonprob design the SRS warning fires exactly
# once and nothing else fires. The inner expectation consumes the typed
# warning and re-raises anything it does not match; the outer one fails on a
# second copy of the same warning, or on any other warning.
test_that("as_svydesign() raises the SRS warning once on a filtered plain nonprob", {
  skip_if_not_installed("survey")
  d <- make_filtered_nonprob("plain")
  mask <- survey_data(d)[[surveycore::SURVEYCORE_DOMAIN_COL]]

  expect_no_warning(
    expect_warning(
      sv <- as_svydesign(d),
      class = "surveycore_warning_nonprob_srs_conversion"
    )
  )
  expect_identical(nrow(sv$variables), sum(mask))
})


# The FPC warning fires inside the replicate route before the object is built,
# so the restriction can neither double it nor suppress it. The result comes
# off the return value of the warned call, and the domain row count is read
# from that object.
test_that("as_svydesign() warns once about a dropped FPC on a filtered replicate design", {
  skip_if_not_installed("survey")
  d <- make_rep_fpc()
  df <- survey_data(d)
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- df$y1 > stats::median(df$y1)
  d@data <- df
  mask <- df[[surveycore::SURVEYCORE_DOMAIN_COL]]

  expect_no_warning(
    expect_warning(
      sv <- as_svydesign(d),
      class = "surveycore_warning_replicate_fpc_dropped"
    )
  )
  expect_identical(nrow(sv$variables), sum(mask))
  expect_true(all(sv$variables[[surveycore::SURVEYCORE_DOMAIN_COL]]))
})


# ── Domain restriction on the two-phase route ────────────────────────────────
#
# Issue #245, the third and last call site. The two-phase route differs from
# the other four in two ways, and both are forced by the survey package.
#
# Which frame. A two-phase object keeps the marker column at
# phase1$sample$variables, not at variables, because @data holds one row per
# phase-1 row where the converted object's phase-1 sample holds only the
# phase-2 rows. Indexing with the @data-side vector raises a bare
# `logical subscript too long`. The helper reads the object's class and picks
# the frame itself, so this call site passes nothing extra.
#
# How the domain applies. `[.twophase` removes no row. It keeps every row and
# sets each excluded row's probability to Inf, so on this route "zero rows"
# reads as "no finite probability" and the row count never changes.

# Fixture. A 60-row two-phase design that names a phase-2 cluster identifier,
# 29 of whose rows reach phase 2. The file's own make_twophase() names none.
make_twophase_ids2 <- function(seed = 42L) {
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
  as_survey_twophase(phase1, ids2 = psu, subset = subset)
}

# The same design with a domain marked by hand. The mask splits on y1's
# median over all 60 phase-1 rows, which leaves 14 of the 29 phase-2 rows
# inside the domain and thins no stratum to one PSU.
make_filtered_twophase <- function(seed = 42L) {
  d <- make_twophase_ids2(seed = seed)
  df <- survey_data(d)
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- df$y1 > stats::median(df$y1)
  d@data <- df
  d
}


# The estimate a caller reads off the converted object is the domain estimate
# and not the full-sample one. get_means() cannot be the reference on this
# route: surveycore's two-phase estimator weights by the phase-1 weight column
# where survey's two-phase object weights by the combined two-phase
# probability, and the two answers differ on an unfiltered design as well
# (issue #261, pinned by the block below). The reference here is therefore
# what a caller got by restricting the converted object by hand, which is what
# this function's documentation told them to do before the change: a two-phase
# object built straight from survey, indexed by the marker column read off its
# own phase-1 sample variables.
test_that("as_svydesign() converts a filtered two-phase design to the domain [numerical]", {
  skip_if_not_installed("survey")
  d <- make_filtered_twophase()
  test_invariants(d)
  df <- survey_data(d)

  oracle <- suppressWarnings(survey::twophase(
    id = list(~psu, ~psu),
    strata = list(~strata, NULL),
    fpc = list(~fpc, NULL),
    data = df,
    subset = ~subset,
    method = "full"
  ))
  r <- as.logical(
    oracle$phase1$sample$variables[[surveycore::SURVEYCORE_DOMAIN_COL]]
  )
  by_hand <- suppressWarnings(oracle[r & !is.na(r), ])
  sm_hand <- suppressWarnings(survey::svymean(~y1, by_hand))

  sv <- suppressWarnings(as_svydesign(d))
  sm <- suppressWarnings(survey::svymean(~y1, sv))

  expect_equal(coef(sm)[["y1"]], coef(sm_hand)[["y1"]], tolerance = 1e-10)
  expect_equal(
    as.numeric(survey::SE(sm)),
    as.numeric(survey::SE(sm_hand)),
    tolerance = 1e-8
  )
})


# The two estimators disagree on this route, and the disagreement is not the
# domain's doing. surveycore's two-phase estimator weights by the phase-1
# weight column; survey's two-phase object weights by the combined two-phase
# probability. Both hand computations below reproduce their estimator exactly,
# and they answer different numbers on a design carrying no domain at all.
# Issue #261 owns the gap and nothing in this change closes it, so this block
# pins it: it fails if the gap ever moves.
test_that("the two-phase estimators weight differently on an unfiltered design [numerical]", {
  skip_if_not_installed("survey")
  d <- make_twophase_ids2()
  sv <- suppressWarnings(as_svydesign(d))
  frame <- sv$phase1$sample$variables

  # min_cell_n = 1 keeps the AAPOR small-cell warning out of the way. The
  # phase-2 sample holds 29 rows against a default threshold of 30, and the
  # argument does not touch the estimate.
  sc <- get_means(d, y1, variance = "se", min_cell_n = 1L)
  by_phase1_weight <- stats::weighted.mean(frame$y1, frame$wt)
  expect_equal(sc$mean[[1L]], by_phase1_weight, tolerance = 1e-10)

  sm <- suppressWarnings(survey::svymean(~y1, sv))
  by_combined_prob <- stats::weighted.mean(frame$y1, 1 / sv$prob)
  expect_equal(coef(sm)[["y1"]], by_combined_prob, tolerance = 1e-10)

  expect_false(isTRUE(all.equal(by_phase1_weight, by_combined_prob)))
})


# `[.twophase` removes no row, so the count that records the restriction is
# the count of finite probabilities. Each excluded row keeps its place and
# takes an infinite probability, which weights it out of every estimate. This
# block asserts no row count on purpose.
test_that("as_svydesign() leaves one finite probability per marked phase-2 row", {
  skip_if_not_installed("survey")
  d <- make_filtered_twophase()
  df <- survey_data(d)
  marked_phase2 <- sum(df[[surveycore::SURVEYCORE_DOMAIN_COL]] & df$subset)

  sv <- suppressWarnings(as_svydesign(d))

  expect_identical(sum(is.finite(sv$prob)), marked_phase2)
})


# The file's own two-phase builder names no phase-2 cluster identifier, so it
# reaches survey::twophase() through a different formula list than the fixture
# above. The restriction applies to it too, and the conversion does not stop.
test_that("as_svydesign() converts a filtered two-phase design that names no phase-2 ids", {
  skip_if_not_installed("survey")
  d <- make_twophase()
  df <- survey_data(d)
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- df$y1 > stats::median(df$y1)
  d@data <- df
  marked_phase2 <- sum(df[[surveycore::SURVEYCORE_DOMAIN_COL]] & df$subset)

  expect_no_error(sv <- suppressWarnings(as_svydesign(d)))
  expect_identical(sum(is.finite(sv$prob)), marked_phase2)
})


# An unfiltered two-phase design carries no marker column, so the helper
# returns the object un-indexed and the conversion is what it was before this
# change: the phase-1 full frame holds one row per design row, the phase-1
# sample holds one row per phase-2 row, and every probability is finite.
test_that("as_svydesign() converts an unfiltered two-phase design unrestricted", {
  skip_if_not_installed("survey")
  d <- make_twophase_ids2()
  df <- survey_data(d)

  sv <- suppressWarnings(as_svydesign(d))

  expect_identical(nrow(sv$phase1$full$variables), nrow(df))
  expect_identical(nrow(sv$phase1$sample$variables), sum(df$subset))
  expect_false(
    surveycore::SURVEYCORE_DOMAIN_COL %in% names(sv$phase1$sample$variables)
  )
  expect_true(all(is.finite(sv$prob)))
})


# A filter that matches no row still converts. On this route the object keeps
# every row and none of them keeps a finite probability, so survey answers
# NaN rather than the zero the Taylor route answers.
test_that("as_svydesign() converts an all-FALSE two-phase marker to no finite probability", {
  skip_if_not_installed("survey")
  d <- make_twophase_ids2()
  df <- survey_data(d)
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- rep(FALSE, nrow(df))
  d@data <- df
  n_phase2 <- sum(df$subset)

  sv <- suppressWarnings(as_svydesign(d))

  expect_identical(nrow(sv$phase1$sample$variables), n_phase2)
  expect_false(any(is.finite(sv$prob)))

  sm <- suppressWarnings(survey::svymean(~y1, sv))
  expect_true(is.nan(coef(sm)[["y1"]]))
})


# A marker of nothing but NA is the all-FALSE case reached by the other half
# of the mask: as.logical() leaves the NAs alone and `!is.na(r)` drops every
# row from the domain.
test_that("as_svydesign() converts an all-NA two-phase marker to no finite probability", {
  skip_if_not_installed("survey")
  d <- make_twophase_ids2()
  df <- survey_data(d)
  df[[surveycore::SURVEYCORE_DOMAIN_COL]] <- rep(NA, nrow(df))
  d@data <- df
  n_phase2 <- sum(df$subset)

  sv <- suppressWarnings(as_svydesign(d))

  expect_identical(nrow(sv$phase1$sample$variables), n_phase2)
  expect_false(any(is.finite(sv$prob)))

  sm <- suppressWarnings(survey::svymean(~y1, sv))
  expect_true(is.nan(coef(sm)[["y1"]]))
})


# The marker column stays in the converted object's data on every route, and
# its values read differently on the two kinds of route. This block is the
# cross-check on a route that removes rows: every value left in the column is
# TRUE, because the rows marked FALSE are gone.
test_that("the marker column survives a Taylor conversion with every value TRUE", {
  skip_if_not_installed("survey")
  sv <- as_svydesign(make_filtered_taylor())

  expect_true(surveycore::SURVEYCORE_DOMAIN_COL %in% names(sv$variables))
  expect_true(all(sv$variables[[surveycore::SURVEYCORE_DOMAIN_COL]]))
})


# On the two-phase route no row is removed, so the marker column arrives
# unchanged and still marks the zero-weighted rows FALSE. Its values are the
# design's own marker read over the phase-2 rows, mixed and not all TRUE.
test_that("the marker column survives a two-phase conversion with its values unchanged", {
  skip_if_not_installed("survey")
  d <- make_filtered_twophase()
  df <- survey_data(d)
  expected <- df[[surveycore::SURVEYCORE_DOMAIN_COL]][df$subset]

  sv <- suppressWarnings(as_svydesign(d))
  frame <- sv$phase1$sample$variables

  expect_true(surveycore::SURVEYCORE_DOMAIN_COL %in% names(frame))
  expect_identical(frame[[surveycore::SURVEYCORE_DOMAIN_COL]], expected)
  expect_false(all(expected))
  expect_true(any(expected))
})


# The two-phase round trip recovers the domain, because the restriction
# removed nothing for it to lose. from_svydesign() reads the phase-1 full
# frame, which the restriction never touched, so the rebuilt design carries
# every phase-1 row and the original unrestricted marker.
test_that("the round trip on a filtered two-phase design rebuilds the full phase-1 frame", {
  skip_if_not_installed("survey")
  d <- make_filtered_twophase()
  df <- survey_data(d)

  sv <- suppressWarnings(as_svydesign(d))
  rebuilt <- suppressWarnings(from_svydesign(sv))
  rebuilt_df <- survey_data(rebuilt)

  expect_identical(nrow(rebuilt_df), nrow(df))
  expect_identical(
    rebuilt_df[[surveycore::SURVEYCORE_DOMAIN_COL]],
    df[[surveycore::SURVEYCORE_DOMAIN_COL]]
  )
})


# The restriction adds no surveycore condition on this route, for any domain.
# expect_no_condition() cannot say so here: survey's own `[.twophase` emits an
# untyped warning when a domain thins a stratum to one PSU, and that
# expectation would fail on it. So the block collects every condition the call
# signals and asserts that none of them carries a surveycore class. The
# collector stays local to this block.
test_that("as_svydesign() raises no surveycore condition on a filtered two-phase design", {
  skip_if_not_installed("survey")
  d <- make_filtered_twophase()

  collect <- function(expr) {
    seen <- list()
    withCallingHandlers(
      force(expr),
      condition = function(cnd) {
        seen[[length(seen) + 1L]] <<- cnd
        if (inherits(cnd, "warning")) {
          invokeRestart("muffleWarning")
        }
        if (inherits(cnd, "message")) {
          invokeRestart("muffleMessage")
        }
      }
    )
    seen
  }

  seen <- collect(as_svydesign(d))
  surveycore_classes <- unlist(lapply(seen, function(cnd) {
    grep("^surveycore_", class(cnd), value = TRUE)
  }))

  expect_identical(as.character(surveycore_classes), character(0L))
})
