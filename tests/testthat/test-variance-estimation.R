# test-variance-estimation.R
# Numerical validation: surveycore Taylor variance == survey package variance
# Tolerance: 1e-10 for point estimates, 1e-8 for SE/variance
#
# All tests skip if the 'survey' package is not installed.

# ---------------------------------------------------------------------------
# Block 1: Taylor Series — NHANES stratified cluster design
# ---------------------------------------------------------------------------

test_that("get_means() Taylor SE matches survey::svymean() — NHANES", {
  skip_if_not_installed("survey")

  # Filter to complete-case examination respondents (wtmec2yr > 0)
  d <- nhanes_2017[nhanes_2017$ridstatr == 2, ]

  sc <- as_survey(d, ids = sdmvpsu, strata = sdmvstra, weights = wtmec2yr, nest = TRUE)
  sv <- survey::svydesign(
    ids     = ~sdmvpsu,
    strata  = ~sdmvstra,
    weights = ~wtmec2yr,
    data    = d,
    nest    = TRUE
  )

  sc_mean <- get_means(sc, bpxsy1)
  sv_mean <- survey::svymean(~bpxsy1, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["bpxsy1"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,   as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
})

test_that("get_totals() Taylor SE matches survey::svytotal() — NHANES", {
  skip_if_not_installed("survey")

  d <- nhanes_2017[nhanes_2017$ridstatr == 2, ]

  sc <- as_survey(d, ids = sdmvpsu, strata = sdmvstra, weights = wtmec2yr, nest = TRUE)
  sv <- survey::svydesign(
    ids     = ~sdmvpsu,
    strata  = ~sdmvstra,
    weights = ~wtmec2yr,
    data    = d,
    nest    = TRUE
  )

  sc_total <- get_totals(sc, bpxsy1)
  sv_total <- survey::svytotal(~bpxsy1, sv, na.rm = TRUE)

  expect_equal(sc_total$total, coef(sv_total)[["bpxsy1"]], tolerance = 1e-10)
  expect_equal(sc_total$se,    as.numeric(survey::SE(sv_total)), tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# Block 2: SRS (no ids, no strata)
# ---------------------------------------------------------------------------

test_that("get_means() matches survey::svymean() for uniform-weight SRS", {
  skip_if_not_installed("survey")

  set.seed(42)
  df <- data.frame(y = rnorm(200), w = rep(1, 200))

  # as_survey_srs() avoids the fallback warning
  sc <- as_survey_srs(df, weights = w)
  sv <- survey::svydesign(ids = ~1, weights = ~w, data = df)

  sc_mean <- get_means(sc, y)
  sv_mean <- survey::svymean(~y, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,   as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
})

test_that("get_means() SRS: non-uniform weights use unweighted s² (classical formula)", {
  # The survey_srs variance is the classical SRS formula: SE = sqrt(s²/n)
  # where s² is the unweighted sample variance.  This differs from the
  # Horvitz-Thompson Taylor linearization (survey package) for unequal weights.
  set.seed(123)
  df <- data.frame(y = rnorm(100), w = runif(100, 0.5, 3))

  sc <- suppressWarnings(as_survey(df, weights = w))
  sc_mean <- get_means(sc, y)

  ybar <- sum(df$w * df$y) / sum(df$w)
  s2   <- sum((df$y - ybar)^2) / (nrow(df) - 1L)

  expect_equal(sc_mean$mean, ybar,           tolerance = 1e-14)
  expect_equal(sc_mean$se,   sqrt(s2 / 100), tolerance = 1e-14)
})

# ---------------------------------------------------------------------------
# Block 3: Stratified design (no clusters)
# ---------------------------------------------------------------------------

test_that("get_means() matches survey::svymean() for stratified design", {
  skip_if_not_installed("survey")

  set.seed(99)
  df <- data.frame(
    strat = rep(c("A", "B", "C"), each = 30),
    wt    = c(runif(30, 1, 2), runif(30, 2, 4), runif(30, 0.5, 1.5)),
    y     = rnorm(90)
  )

  sc <- as_survey(df, strata = strat, weights = wt)
  sv <- survey::svydesign(ids = ~1, strata = ~strat, weights = ~wt, data = df)

  sc_mean <- get_means(sc, y)
  sv_mean <- survey::svymean(~y, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,   as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
})

test_that("get_totals() matches survey::svytotal() for stratified design", {
  skip_if_not_installed("survey")

  set.seed(77)
  df <- data.frame(
    strat = rep(c("X", "Y"), each = 20),
    wt    = c(runif(20, 1, 3), runif(20, 2, 5)),
    y     = rnorm(40)
  )

  sc <- as_survey(df, strata = strat, weights = wt)
  sv <- survey::svydesign(ids = ~1, strata = ~strat, weights = ~wt, data = df)

  sc_total <- get_totals(sc, y)
  sv_total <- survey::svytotal(~y, sv, na.rm = TRUE)

  expect_equal(sc_total$total, coef(sv_total)[["y"]], tolerance = 1e-10)
  expect_equal(sc_total$se,    as.numeric(survey::SE(sv_total)), tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# Block 4: Clustered design without stratification
# ---------------------------------------------------------------------------

test_that("get_means() matches survey::svymean() for cluster-only design", {
  skip_if_not_installed("survey")

  set.seed(55)
  df <- data.frame(
    psu = rep(1:10, each = 5),
    wt  = rep(runif(10, 1, 4), each = 5),
    y   = rnorm(50)
  )

  sc <- as_survey(df, ids = psu, weights = wt)
  sv <- survey::svydesign(ids = ~psu, weights = ~wt, data = df)

  sc_mean <- get_means(sc, y)
  sv_mean <- survey::svymean(~y, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,   as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# Block 5: Design with FPC
# ---------------------------------------------------------------------------

test_that("get_means() matches survey::svymean() with population-size FPC", {
  skip_if_not_installed("survey")

  set.seed(8)
  df <- data.frame(
    psu  = rep(1:4, each = 5),
    st   = rep(c("A", "B"), each = 10),
    wt   = rep(c(100, 150, 200, 250), each = 5),
    fpc  = rep(c(8L, 8L, 12L, 12L), each = 5),  # population PSU count
    y    = rnorm(20)
  )

  sc <- as_survey(df, ids = psu, strata = st, weights = wt, fpc = fpc)
  sv <- survey::svydesign(
    ids     = ~psu,
    strata  = ~st,
    weights = ~wt,
    fpc     = ~fpc,
    data    = df,
    nest    = TRUE
  )

  sc_mean <- get_means(sc, y)
  sv_mean <- survey::svymean(~y, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,   as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# Block 6: na.rm behaviour
# ---------------------------------------------------------------------------

test_that("get_means() na.rm = TRUE matches survey::svymean() with NAs", {
  skip_if_not_installed("survey")

  set.seed(321)
  df <- data.frame(
    psu  = rep(1:5, each = 4),
    st   = rep(c("A", "B", "A", "B", "A"), each = 4),
    wt   = rep(runif(5, 1, 3), each = 4),
    y    = c(rnorm(10), rep(NA_real_, 2), rnorm(8))
  )

  sc <- as_survey(df, ids = psu, strata = st, weights = wt)
  sv <- survey::svydesign(
    ids     = ~psu,
    strata  = ~st,
    weights = ~wt,
    data    = df,
    nest    = TRUE
  )

  sc_mean <- get_means(sc, y, na.rm = TRUE)
  sv_mean <- survey::svymean(~y, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,   as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# Block 7: Return value structure
# ---------------------------------------------------------------------------

test_that("get_means() returns correct structure", {
  df <- data.frame(y = 1:10, w = rep(1, 10))
  d  <- as_survey_srs(df, weights = w)
  result <- get_means(d, y)

  expect_type(result, "list")
  expect_named(result, c("variable", "mean", "se"))
  expect_identical(result$variable, "y")
  expect_type(result$mean, "double")
  expect_type(result$se, "double")
  expect_true(is.finite(result$mean))
  expect_true(is.finite(result$se))
  expect_gte(result$se, 0)
})

test_that("get_totals() returns correct structure", {
  df <- data.frame(y = 1:10, w = rep(1, 10))
  d  <- as_survey_srs(df, weights = w)
  result <- get_totals(d, y)

  expect_type(result, "list")
  expect_named(result, c("variable", "total", "se"))
  expect_identical(result$variable, "y")
  expect_type(result$total, "double")
  expect_type(result$se, "double")
  expect_true(is.finite(result$total))
  expect_true(is.finite(result$se))
  expect_gte(result$se, 0)
})

# ---------------------------------------------------------------------------
# Block 8: Error paths
# ---------------------------------------------------------------------------

test_that("get_means() errors on two-phase design (not yet implemented)", {
  d <- make_survey_data(design = "twophase", seed = 1)
  phase1 <- as_survey(d, ids = psu, strata = strata, weights = wt)
  two    <- suppressWarnings(
    as_survey_twophase(phase1, subset = phase2_ind)
  )
  expect_error(
    get_means(two, y1),
    class = "surveycore_error_unsupported_class"
  )
})

test_that("get_totals() errors on two-phase design (not yet implemented)", {
  d <- make_survey_data(design = "twophase", seed = 1)
  phase1 <- as_survey(d, ids = psu, strata = strata, weights = wt)
  two    <- suppressWarnings(
    as_survey_twophase(phase1, subset = phase2_ind)
  )
  expect_error(
    get_totals(two, y1),
    class = "surveycore_error_unsupported_class"
  )
})

test_that("get_means() errors when variable not found", {
  df <- data.frame(y = 1:5, w = rep(1, 5))
  d  <- as_survey_srs(df, weights = w)
  expect_error(
    get_means(d, nonexistent),
    class = "surveycore_error_var_not_found"
  )
})

test_that("get_totals() errors when variable not found", {
  df <- data.frame(y = 1:5, w = rep(1, 5))
  d  <- as_survey_srs(df, weights = w)
  expect_error(
    get_totals(d, nonexistent),
    class = "surveycore_error_var_not_found"
  )
})

test_that("get_means() errors for non-numeric variable", {
  df <- data.frame(y = letters[1:5], w = rep(1, 5), stringsAsFactors = FALSE)
  d  <- as_survey_srs(df, weights = w)
  expect_error(
    get_means(d, y),
    class = "surveycore_error_var_not_numeric"
  )
})

test_that("get_totals() errors for non-numeric variable", {
  df <- data.frame(y = letters[1:5], w = rep(1, 5), stringsAsFactors = FALSE)
  d  <- as_survey_srs(df, weights = w)
  expect_error(
    get_totals(d, y),
    class = "surveycore_error_var_not_numeric"
  )
})

# ---------------------------------------------------------------------------
# Block 9: Numerical correctness — simple known values
# ---------------------------------------------------------------------------

test_that("get_means() computes correct weighted mean for trivial case", {
  # Weighted mean of (1, 2, 3) with weights (1, 2, 3) = (1*1 + 2*2 + 3*3)/(1+2+3) = 14/6
  df <- data.frame(y = c(1, 2, 3), w = c(1, 2, 3))
  d  <- as_survey_srs(df, weights = w)
  result <- get_means(d, y)
  expect_equal(result$mean, 14 / 6, tolerance = 1e-14)
})

test_that("get_totals() computes correct weighted total for trivial case", {
  # Weighted total of (1, 2, 3) with weights (2, 3, 4) = 2 + 6 + 12 = 20
  df <- data.frame(y = c(1, 2, 3), w = c(2, 3, 4))
  d  <- as_survey_srs(df, weights = w)
  result <- get_totals(d, y)
  expect_equal(result$total, 20, tolerance = 1e-14)
})

# ---------------------------------------------------------------------------
# Block 10: Replicate weight variance — numerical comparison
# ---------------------------------------------------------------------------

test_that("get_means() replicate SE matches survey::svymean() — BRR design", {
  skip_if_not_installed("survey")

  d <- make_survey_data(n = 200, n_psu = 20, n_strata = 4,
                        design = "replicate", type = "brr", seed = 7)
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)

  sc <- as_survey_rep(d, weights = wt, repweights = all_of(repwt_cols), type = "BRR")
  sv <- survey::svrepdesign(
    weights    = d$wt,
    repweights = d[, repwt_cols],
    type       = "BRR",
    mse        = TRUE,
    data       = d
  )

  sc_mean <- get_means(sc, y1)
  sv_mean <- survey::svymean(~y1, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,   as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
})

test_that("get_totals() replicate SE matches survey::svytotal() — BRR design", {
  skip_if_not_installed("survey")

  d <- make_survey_data(n = 200, n_psu = 20, n_strata = 4,
                        design = "replicate", type = "brr", seed = 7)
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)

  sc <- as_survey_rep(d, weights = wt, repweights = all_of(repwt_cols), type = "BRR")
  sv <- survey::svrepdesign(
    weights    = d$wt,
    repweights = d[, repwt_cols],
    type       = "BRR",
    mse        = TRUE,
    data       = d
  )

  sc_total <- get_totals(sc, y1)
  sv_total <- survey::svytotal(~y1, sv, na.rm = TRUE)

  expect_equal(sc_total$total, coef(sv_total)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_total$se,    as.numeric(survey::SE(sv_total)), tolerance = 1e-8)
})

test_that("get_means() replicate SE matches survey::svymean() — JK1 design", {
  skip_if_not_installed("survey")

  d <- make_survey_data(n = 200, n_psu = 20, n_strata = 4,
                        design = "replicate", type = "jk1", seed = 15)
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)

  # Compute scale explicitly to avoid survey package "guessing" warning.
  n_rep <- length(repwt_cols)
  jk1_scale <- (n_rep - 1L) / n_rep

  sc <- as_survey_rep(d, weights = wt, repweights = all_of(repwt_cols), type = "JK1")
  sv <- suppressWarnings(survey::svrepdesign(
    weights    = d$wt,
    repweights = d[, repwt_cols],
    type       = "JK1",
    scale      = jk1_scale,
    mse        = TRUE,
    data       = d
  ))

  sc_mean <- get_means(sc, y1)
  sv_mean <- survey::svymean(~y1, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,   as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
})

test_that("get_means() replicate: mse=FALSE matches survey with mse=FALSE", {
  skip_if_not_installed("survey")

  d <- make_survey_data(n = 100, n_psu = 10, n_strata = 2,
                        design = "replicate", type = "brr", seed = 22)
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)

  sc <- as_survey_rep(d, weights = wt, repweights = all_of(repwt_cols),
                      type = "BRR", mse = FALSE)
  sv <- survey::svrepdesign(
    weights    = d$wt,
    repweights = d[, repwt_cols],
    type       = "BRR",
    mse        = FALSE,
    data       = d
  )

  sc_mean <- get_means(sc, y1)
  sv_mean <- survey::svymean(~y1, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,   as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
})

test_that("get_means() and get_totals() work for survey_replicate (return structure)", {
  d <- make_survey_data(n = 100, n_psu = 10, design = "replicate", type = "brr", seed = 3)
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)
  sc <- as_survey_rep(d, weights = wt, repweights = all_of(repwt_cols), type = "BRR")

  m <- get_means(sc, y1)
  expect_named(m, c("variable", "mean", "se"))
  expect_identical(m$variable, "y1")
  expect_true(is.finite(m$mean))
  expect_gte(m$se, 0)

  t <- get_totals(sc, y1)
  expect_named(t, c("variable", "total", "se"))
  expect_true(is.finite(t$total))
  expect_gte(t$se, 0)
})

test_that("get_means() BRR scale formula 1/n_rep is correct for n_rep != 4", {
  # Verifies that scale = 1/n_rep (not 1/4) is the correct BRR formula.
  # With n_psu = 20, n_rep = 10 (half-samples from 20 PSUs).
  # If 1/n_rep is correct, surveycore and survey::svrepdesign agree at 1e-8.
  skip_if_not_installed("survey")

  d <- make_survey_data(n = 200, n_psu = 20, n_strata = 4,
                        design = "replicate", type = "brr", seed = 99)
  repwt_cols <- grep("^repwt_", names(d), value = TRUE)
  n_rep      <- length(repwt_cols)  # should be 10 (n_psu / 2)

  sc <- as_survey_rep(d, weights = wt, repweights = all_of(repwt_cols), type = "BRR")
  # survey package default scale for BRR is 1/4 when not specified.
  # Pass scale = 1/n_rep explicitly to match surveycore behaviour.
  sv <- survey::svrepdesign(
    weights    = d$wt,
    repweights = d[, repwt_cols],
    type       = "BRR",
    scale      = 1 / n_rep,
    mse        = TRUE,
    data       = d
  )

  sc_mean <- get_means(sc, y1)
  sv_mean <- survey::svymean(~y1, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,   as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
})


# ---------------------------------------------------------------------------
# Block 11: Error paths — non-survey inputs to get_means()/get_totals()
# ---------------------------------------------------------------------------

test_that("get_means() errors for non-survey-design object", {
  expect_error(
    get_means(data.frame(x = 1:5, y = rnorm(5)), y),
    class = "surveycore_error_not_survey_design"
  )
})

test_that("get_totals() errors for non-survey-design object", {
  expect_error(
    get_totals(list(x = 1), x),
    class = "surveycore_error_not_survey_design"
  )
})


# ---------------------------------------------------------------------------
# Block 12: na.rm = FALSE paths
# ---------------------------------------------------------------------------

test_that("get_means() na.rm = FALSE with FPC returns NA when data has NA", {
  set.seed(42)
  df <- data.frame(
    y   = c(rnorm(49), NA_real_),
    w   = runif(50, 0.5, 2),
    fpc = rep(1000L, 50)
  )
  # Use as_survey_srs() directly: fpc=1000L (>1) → population FPC
  sc     <- as_survey_srs(df, weights = w, fpc = fpc)
  result <- get_means(sc, y, na.rm = FALSE)
  expect_true(is.na(result$mean))
})

test_that("get_means() na.rm = FALSE on replicate design covers .replicate_mean FALSE path", {
  df         <- make_survey_data(n = 50L, n_psu = 10L,
                                 design = "replicate", type = "brr", seed = 200L)
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  sc         <- as_survey_rep(df, weights = wt,
                               repweights = all_of(repwt_cols), type = "BRR")
  # na.rm = FALSE on NA-free data exercises the else branch and returns a valid estimate
  result <- get_means(sc, y1, na.rm = FALSE)
  expect_true(is.finite(result$mean))
  expect_true(is.finite(result$se))
})

test_that("get_totals() na.rm = FALSE on replicate design covers .replicate_total FALSE path", {
  df         <- make_survey_data(n = 50L, n_psu = 10L,
                                 design = "replicate", type = "brr", seed = 201L)
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  sc         <- as_survey_rep(df, weights = wt,
                               repweights = all_of(repwt_cols), type = "BRR")
  # na.rm = FALSE on NA-free data exercises the else branch and returns a valid estimate
  result <- get_totals(sc, y1, na.rm = FALSE)
  expect_true(is.finite(result$total))
  expect_true(is.finite(result$se))
})


# ---------------------------------------------------------------------------
# Block 13: Fraction FPC (sampling fraction path in .taylor_build_inputs)
# ---------------------------------------------------------------------------

test_that("get_means() Taylor: fraction FPC (values <= 1) converts to population sizes", {
  skip_if_not_installed("survey")
  set.seed(42)
  n  <- 100L
  # Add psu column (each row its own PSU) so as_survey() uses the Taylor path,
  # not the SRS fallback.  This test verifies .taylor_build_inputs() FPC conversion.
  df <- data.frame(
    psu      = seq_len(n),
    y        = rnorm(n),
    w        = runif(n, 0.5, 2),
    fpc_frac = rep(0.1, n)     # sampling fraction
  )
  sc     <- as_survey(df, ids = psu, weights = w, fpc = fpc_frac)
  sv     <- survey::svydesign(ids = ~psu, weights = ~w, fpc = ~fpc_frac, data = df)
  sc_est <- get_means(sc, y)
  sv_est <- survey::svymean(~y, sv, na.rm = TRUE)
  expect_equal(sc_est$mean, coef(sv_est)[["y"]], tolerance = 1e-10)
  expect_equal(sc_est$se,   as.numeric(survey::SE(sv_est)), tolerance = 1e-8)
})


# ---------------------------------------------------------------------------
# Block 14: Lonely PSU — 1-PSU stratum covers .svy_onestrat switch (lines 62-74)
# ---------------------------------------------------------------------------

# Shared fixture: design where stratum B has exactly 1 PSU
make_lonely_design <- function() {
  set.seed(42)
  data.frame(
    y      = rnorm(30),
    w      = runif(30, 0.5, 2),
    strata = c(rep("A", 20), rep("B", 10)),
    psu    = c(rep(1L, 10), rep(2L, 10), rep(3L, 10))
  )
}

test_that("get_means() works with lonely PSU (lonely.psu = 'remove', default)", {
  old_opt <- getOption("survey.lonely.psu")
  options(survey.lonely.psu = "remove")
  on.exit(options(survey.lonely.psu = old_opt), add = TRUE)
  df <- make_lonely_design()
  sc <- as_survey(df, ids = psu, weights = w, strata = strata, nest = TRUE)
  result <- get_means(sc, y)
  expect_true(is.finite(result$mean))
})

test_that("get_means() works with lonely PSU (lonely.psu = 'certainty')", {
  old_opt <- getOption("survey.lonely.psu")
  options(survey.lonely.psu = "certainty")
  on.exit(options(survey.lonely.psu = old_opt), add = TRUE)
  df <- make_lonely_design()
  sc <- as_survey(df, ids = psu, weights = w, strata = strata, nest = TRUE)
  result <- get_means(sc, y)
  expect_true(is.finite(result$mean))
})

test_that("get_means() works with lonely PSU (lonely.psu = 'average')", {
  old_opt <- getOption("survey.lonely.psu")
  options(survey.lonely.psu = "average")
  on.exit(options(survey.lonely.psu = old_opt), add = TRUE)
  df <- make_lonely_design()
  sc <- as_survey(df, ids = psu, weights = w, strata = strata, nest = TRUE)
  result <- get_means(sc, y)
  # Mean is still finite; SE may be NA due to NA variance contribution
  expect_true(is.finite(result$mean))
})

test_that("get_means() works with lonely PSU (lonely.psu = 'adjust')", {
  old_opt <- getOption("survey.lonely.psu")
  options(survey.lonely.psu = "adjust")
  on.exit(options(survey.lonely.psu = old_opt), add = TRUE)
  df <- make_lonely_design()
  sc <- as_survey(df, ids = psu, weights = w, strata = strata, nest = TRUE)
  # suppressWarnings: base R "NAs introduced by coercion" is expected for 'adjust'
  result <- suppressWarnings(get_means(sc, y))
  expect_true(is.finite(result$mean))
})

test_that("get_means() errors with lonely PSU (lonely.psu = 'fail')", {
  old_opt <- getOption("survey.lonely.psu")
  options(survey.lonely.psu = "fail")
  on.exit(options(survey.lonely.psu = old_opt), add = TRUE)
  df <- make_lonely_design()
  sc <- as_survey(df, ids = psu, weights = w, strata = strata, nest = TRUE)
  expect_error(
    get_means(sc, y),
    class = "surveycore_error_lonely_psu"
  )
})

test_that("get_means() errors with unknown lonely.psu option", {
  old_opt <- getOption("survey.lonely.psu")
  options(survey.lonely.psu = "bogus_option")
  on.exit(options(survey.lonely.psu = old_opt), add = TRUE)
  df <- make_lonely_design()
  sc <- as_survey(df, ids = psu, weights = w, strata = strata, nest = TRUE)
  expect_error(
    get_means(sc, y),
    class = "surveycore_error_lonely_psu"
  )
})


# ---------------------------------------------------------------------------
# Block 15: Complete census FPC (f ≈ 0) — .svy_onestrat line 37
# ---------------------------------------------------------------------------

test_that("get_means() returns zero SE when FPC indicates complete census (fpc = nPSU)", {
  # fpc == nPSU for each stratum → f = (fpc-nPSU)/fpc = 0 → variance is 0
  df <- data.frame(
    y      = rnorm(20),
    w      = rep(1, 20),
    strata = rep(c("A", "B"), each = 10),
    psu    = rep(1:5, 4),       # 5 unique PSUs per stratum
    fpc    = rep(5L, 20)        # fpc == nPSU
  )
  sc     <- as_survey(df, ids = psu, weights = w, strata = strata, fpc = fpc, nest = TRUE)
  result <- get_means(sc, y)
  expect_equal(result$se, 0, tolerance = 1e-10)
})


# ---------------------------------------------------------------------------
# Block 16: .svy_rep_var() with NA replicates (lines 317–323)
# ---------------------------------------------------------------------------

test_that(".svy_rep_var() skips NA replicates and returns finite variance [direct]", {
  thetas  <- c(1.2, 1.3, NA_real_, 1.1, 1.4)
  rscales <- rep(1L, 5L)
  v <- surveycore:::.svy_rep_var(
    thetas, scale = 0.2, rscales = rscales, mse = TRUE, coef = 1.25
  )
  expect_true(is.finite(v))
  expect_gte(v, 0)
})

test_that(".svy_rep_var() errors when all replicates are NA [direct]", {
  thetas  <- rep(NA_real_, 5L)
  rscales <- rep(1L, 5L)
  expect_error(
    surveycore:::.svy_rep_var(
      thetas, scale = 0.2, rscales = rscales, mse = TRUE, coef = 1.25
    ),
    class = "surveycore_error_all_replicates_na"
  )
})


# ---------------------------------------------------------------------------
# Block 17: SRS variance — oracle comparison
# ---------------------------------------------------------------------------

test_that("get_means() SRS: unweighted uniform weights match survey::svymean()", {
  skip_if_not_installed("survey")
  set.seed(42)
  df <- data.frame(y = rnorm(200), w = rep(1, 200))
  sc <- as_survey_srs(df, weights = w)
  sv <- survey::svydesign(ids = ~1, weights = ~w, data = df)
  sc_mean <- get_means(sc, y)
  sv_mean <- survey::svymean(~y, sv, na.rm = TRUE)
  expect_equal(sc_mean$mean, coef(sv_mean)[["y"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,   as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
})

test_that("get_means() SRS: non-uniform weights use unweighted s² (formula verification)", {
  # survey_srs uses the classical SRS formula: SE = sqrt(s²/n) with unweighted s².
  # This differs from the survey package's HT Taylor linearization for unequal weights.
  # We verify directly against the formula, not against survey::svymean().
  set.seed(77)
  df <- data.frame(y = rnorm(150), w = runif(150, 0.5, 3))
  sc <- as_survey_srs(df, weights = w)
  sc_mean <- get_means(sc, y)
  ybar <- sum(df$w * df$y) / sum(df$w)
  s2   <- sum((df$y - ybar)^2) / (nrow(df) - 1L)
  expect_equal(sc_mean$mean, ybar,            tolerance = 1e-14)
  expect_equal(sc_mean$se,   sqrt(s2 / 150L), tolerance = 1e-14)
})

test_that("get_means() SRS: population FPC matches survey::svymean() [proper SRS weights]", {
  # Oracle comparison requires w = N/n so HT and classical SRS formulas agree.
  skip_if_not_installed("survey")
  set.seed(11)
  N <- 500L; n <- 50L; w_val <- N / n   # = 10
  df <- data.frame(y = rnorm(n), w = rep(w_val, n), pop = rep(N, n))
  sc <- as_survey_srs(df, weights = w, fpc = pop)
  sv <- survey::svydesign(ids = ~1, weights = ~w, fpc = ~pop, data = df)
  sc_mean <- get_means(sc, y)
  sv_mean <- survey::svymean(~y, sv, na.rm = TRUE)
  expect_equal(sc_mean$mean, coef(sv_mean)[["y"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,   as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
})

test_that("get_means() SRS: fraction FPC matches survey::svymean() [proper SRS weights]", {
  # Oracle comparison requires w = N/n = 1/frac so formulas agree.
  skip_if_not_installed("survey")
  set.seed(22)
  n <- 60L; frac_val <- 0.1; w_val <- 1 / frac_val   # = 10
  df <- data.frame(y = rnorm(n), w = rep(w_val, n), frac = rep(frac_val, n))
  sc <- as_survey_srs(df, weights = w, fpc = frac)
  sv <- survey::svydesign(ids = ~1, weights = ~w, fpc = ~frac, data = df)
  sc_mean <- get_means(sc, y)
  sv_mean <- survey::svymean(~y, sv, na.rm = TRUE)
  expect_equal(sc_mean$mean, coef(sv_mean)[["y"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,   as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
})

test_that("get_totals() SRS: no FPC matches survey::svytotal() [uniform weights]", {
  skip_if_not_installed("survey")
  set.seed(33)
  df <- data.frame(y = rnorm(100), w = rep(5, 100))
  sc <- as_survey_srs(df, weights = w)
  sv <- survey::svydesign(ids = ~1, weights = ~w, data = df)
  sc_tot <- get_totals(sc, y)
  sv_tot <- survey::svytotal(~y, sv, na.rm = TRUE)
  expect_equal(sc_tot$total, coef(sv_tot)[["y"]], tolerance = 1e-10)
  expect_equal(sc_tot$se,    as.numeric(survey::SE(sv_tot)), tolerance = 1e-8)
})

test_that("get_totals() SRS: population FPC matches survey::svytotal() [proper SRS weights]", {
  # Oracle comparison requires w = N/n so HT and classical SRS formulas agree.
  skip_if_not_installed("survey")
  set.seed(44)
  N <- 500L; n <- 50L; w_val <- N / n   # = 10
  df <- data.frame(y = rnorm(n), w = rep(w_val, n), pop = rep(N, n))
  sc <- as_survey_srs(df, weights = w, fpc = pop)
  sv <- survey::svydesign(ids = ~1, weights = ~w, fpc = ~pop, data = df)
  sc_tot <- get_totals(sc, y)
  sv_tot <- survey::svytotal(~y, sv, na.rm = TRUE)
  expect_equal(sc_tot$total, coef(sv_tot)[["y"]], tolerance = 1e-10)
  expect_equal(sc_tot$se,    as.numeric(survey::SE(sv_tot)), tolerance = 1e-8)
})

test_that("get_totals() SRS: fraction FPC matches survey::svytotal() [proper SRS weights]", {
  # Oracle comparison requires w = N/n = 1/frac so formulas agree.
  skip_if_not_installed("survey")
  set.seed(55)
  n <- 60L; frac_val <- 0.1; w_val <- 1 / frac_val   # = 10
  df <- data.frame(y = rnorm(n), w = rep(w_val, n), frac = rep(frac_val, n))
  sc <- as_survey_srs(df, weights = w, fpc = frac)
  sv <- survey::svydesign(ids = ~1, weights = ~w, fpc = ~frac, data = df)
  sc_tot <- get_totals(sc, y)
  sv_tot <- survey::svytotal(~y, sv, na.rm = TRUE)
  expect_equal(sc_tot$total, coef(sv_tot)[["y"]], tolerance = 1e-10)
  expect_equal(sc_tot$se,    as.numeric(survey::SE(sv_tot)), tolerance = 1e-8)
})


# ---------------------------------------------------------------------------
# Block 18: SRS variance — structure and edge cases
# ---------------------------------------------------------------------------

test_that("get_means() returns correct structure for survey_srs", {
  df <- data.frame(y = 1:10, w = rep(2, 10))
  sc <- as_survey_srs(df, weights = w)
  result <- get_means(sc, y)
  expect_type(result, "list")
  expect_named(result, c("variable", "mean", "se"))
  expect_identical(result$variable, "y")
  expect_type(result$mean, "double")
  expect_type(result$se, "double")
  expect_true(is.finite(result$mean))
  expect_true(is.finite(result$se))
  expect_gte(result$se, 0)
})

test_that("get_totals() returns correct structure for survey_srs", {
  df <- data.frame(y = 1:10, w = rep(2, 10))
  sc <- as_survey_srs(df, weights = w)
  result <- get_totals(sc, y)
  expect_type(result, "list")
  expect_named(result, c("variable", "total", "se"))
  expect_identical(result$variable, "y")
  expect_type(result$total, "double")
  expect_type(result$se, "double")
  expect_true(is.finite(result$total))
  expect_true(is.finite(result$se))
  expect_gte(result$se, 0)
})

test_that(".srs_mean() returns NA for all-NA column (edge case: n_used = 0)", {
  df <- data.frame(y = rep(NA_real_, 5), w = rep(1, 5))
  sc <- as_survey_srs(df, weights = w)
  result <- get_means(sc, y, na.rm = TRUE)
  expect_true(is.na(result$mean))
  expect_true(is.na(result$se))
})

test_that(".srs_mean() returns point estimate with NA se for n = 1", {
  df <- data.frame(y = 42, w = 1)
  # suppressWarnings: as_survey_srs() warns that variance cannot be estimated for n=1
  sc <- suppressWarnings(as_survey_srs(df, weights = w))
  result <- get_means(sc, y)
  expect_equal(result$mean, 42, tolerance = 1e-14)
  expect_true(is.na(result$se))
})

test_that(".srs_mean() na.rm = FALSE propagates NA when y has NA", {
  df <- data.frame(y = c(1, 2, NA_real_, 4, 5), w = rep(1, 5))
  sc <- as_survey_srs(df, weights = w)
  result <- get_means(sc, y, na.rm = FALSE)
  expect_true(is.na(result$mean))
  expect_true(is.na(result$se))
})

test_that(".srs_total() returns NA for all-NA column (edge case: n_used = 0)", {
  df <- data.frame(y = rep(NA_real_, 5), w = rep(1, 5))
  sc <- as_survey_srs(df, weights = w)
  result <- get_totals(sc, y, na.rm = TRUE)
  expect_true(is.na(result$total))
  expect_true(is.na(result$se))
})

test_that(".srs_total() na.rm = FALSE propagates NA when y has NA", {
  df <- data.frame(y = c(1, 2, NA_real_, 4, 5), w = rep(1, 5))
  sc <- as_survey_srs(df, weights = w)
  result <- get_totals(sc, y, na.rm = FALSE)
  expect_true(is.na(result$total))
  expect_true(is.na(result$se))
})

test_that("get_means() SRS: FPC = population size reduces SE vs no FPC", {
  set.seed(101)
  n <- 50L
  df <- data.frame(y = rnorm(n), w = rep(1, n), pop = rep(500L, n))
  sc_no_fpc  <- as_survey_srs(df, weights = w)
  sc_with_fpc <- as_survey_srs(df, weights = w, fpc = pop)
  r_no  <- get_means(sc_no_fpc, y)
  r_fpc <- get_means(sc_with_fpc, y)
  # FPC reduces SE: f = n/N = 50/500 = 0.1 → SE_fpc = SE_no * sqrt(1 - 0.1) < SE_no
  expect_lt(r_fpc$se, r_no$se)
})
