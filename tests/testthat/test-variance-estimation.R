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

test_that("get_means() matches survey::svymean() for unweighted SRS", {
  skip_if_not_installed("survey")

  set.seed(42)
  df <- data.frame(y = rnorm(200), w = rep(1, 200))

  sc <- as_survey(df, weights = w)
  sv <- survey::svydesign(ids = ~1, weights = ~w, data = df)

  sc_mean <- get_means(sc, y)
  sv_mean <- survey::svymean(~y, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,   as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
})

test_that("get_means() matches survey::svymean() for weighted SRS", {
  skip_if_not_installed("survey")

  set.seed(123)
  df <- data.frame(y = rnorm(100), w = runif(100, 0.5, 3))

  sc <- as_survey(df, weights = w)
  sv <- survey::svydesign(ids = ~1, weights = ~w, data = df)

  sc_mean <- get_means(sc, y)
  sv_mean <- survey::svymean(~y, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean, coef(sv_mean)[["y"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,   as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
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
  d  <- as_survey(df, weights = w)
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
  d  <- as_survey(df, weights = w)
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

test_that("get_means() errors on non-survey_taylor design", {
  d <- make_survey_data(design = "replicate")
  rep_design <- as_survey_rep(
    d,
    weights    = wt,
    repweights = starts_with("repwt"),
    type       = "BRR"
  )
  expect_error(
    get_means(rep_design, y1),
    class = "surveycore_error_unsupported_class"
  )
})

test_that("get_totals() errors on non-survey_taylor design", {
  d <- make_survey_data(design = "replicate")
  rep_design <- as_survey_rep(
    d,
    weights    = wt,
    repweights = starts_with("repwt"),
    type       = "BRR"
  )
  expect_error(
    get_totals(rep_design, y1),
    class = "surveycore_error_unsupported_class"
  )
})

test_that("get_means() errors when variable not found", {
  df <- data.frame(y = 1:5, w = rep(1, 5))
  d  <- as_survey(df, weights = w)
  expect_error(
    get_means(d, nonexistent),
    class = "surveycore_error_var_not_found"
  )
})

test_that("get_totals() errors when variable not found", {
  df <- data.frame(y = 1:5, w = rep(1, 5))
  d  <- as_survey(df, weights = w)
  expect_error(
    get_totals(d, nonexistent),
    class = "surveycore_error_var_not_found"
  )
})

test_that("get_means() errors for non-numeric variable", {
  df <- data.frame(y = letters[1:5], w = rep(1, 5), stringsAsFactors = FALSE)
  d  <- as_survey(df, weights = w)
  expect_error(
    get_means(d, y),
    class = "surveycore_error_var_not_numeric"
  )
})

test_that("get_totals() errors for non-numeric variable", {
  df <- data.frame(y = letters[1:5], w = rep(1, 5), stringsAsFactors = FALSE)
  d  <- as_survey(df, weights = w)
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
  d  <- as_survey(df, weights = w)
  result <- get_means(d, y)
  expect_equal(result$mean, 14 / 6, tolerance = 1e-14)
})

test_that("get_totals() computes correct weighted total for trivial case", {
  # Weighted total of (1, 2, 3) with weights (2, 3, 4) = 2 + 6 + 12 = 20
  df <- data.frame(y = c(1, 2, 3), w = c(2, 3, 4))
  d  <- as_survey(df, weights = w)
  result <- get_totals(d, y)
  expect_equal(result$total, 20, tolerance = 1e-14)
})
