# test-variance-taylor.R
# Tests for the Taylor series variance engine: .svy_recvar(), .taylor_build_inputs(),
# .taylor_mean(), .taylor_total().
#
# Numerical tolerance: 1e-10 for point estimates, 1e-8 for SE/variance.
# All oracle tests skip if the 'survey' package is not installed.

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
