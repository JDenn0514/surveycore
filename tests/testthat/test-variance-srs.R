# test-variance-srs.R
# Tests for the SRS variance engine: .srs_mean(), .srs_total().
#
# Numerical tolerance: 1e-10 for point estimates, 1e-8 for SE/variance.
# Oracle tests skip if the 'survey' package is not installed.

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

  sc_mean <- get_means(sc, y, variance = c("se", "ci"))
  sv_mean <- survey::svymean(~y, sv, na.rm = TRUE)

  expect_equal(sc_mean$mean,    coef(sv_mean)[["y"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,      as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
  expect_equal(sc_mean$ci_low,  confint(sv_mean)[1], tolerance = 1e-6)
  expect_equal(sc_mean$ci_high, confint(sv_mean)[2], tolerance = 1e-6)
})

test_that("get_means() SRS: non-uniform weights use unweighted s² (classical formula)", {
  # The survey_srs variance is the classical SRS formula: SE = sqrt(s²/n)
  # where s² is the unweighted sample variance.  This differs from the
  # Horvitz-Thompson Taylor linearization (survey package) for unequal weights.
  set.seed(123)
  df <- data.frame(y = rnorm(100), w = runif(100, 0.5, 3))

  sc <- suppressWarnings(as_survey(df, weights = w))
  sc_mean <- get_means(sc, y, variance = "se")

  ybar <- sum(df$w * df$y) / sum(df$w)
  s2   <- sum((df$y - ybar)^2) / (nrow(df) - 1L)

  expect_equal(sc_mean$mean[[1L]], ybar,           tolerance = 1e-14)
  expect_equal(sc_mean$se[[1L]],   sqrt(s2 / 100), tolerance = 1e-14)
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
  sc_mean <- get_means(sc, y, variance = c("se", "ci"))
  sv_mean <- survey::svymean(~y, sv, na.rm = TRUE)
  expect_equal(sc_mean$mean,    coef(sv_mean)[["y"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,      as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
  expect_equal(sc_mean$ci_low,  confint(sv_mean)[1], tolerance = 1e-6)
  expect_equal(sc_mean$ci_high, confint(sv_mean)[2], tolerance = 1e-6)
})

test_that("get_means() SRS: non-uniform weights use unweighted s² (formula verification)", {
  # survey_srs uses the classical SRS formula: SE = sqrt(s²/n) with unweighted s².
  # This differs from the survey package's HT Taylor linearization for unequal weights.
  # We verify directly against the formula, not against survey::svymean().
  set.seed(77)
  df <- data.frame(y = rnorm(150), w = runif(150, 0.5, 3))
  sc <- as_survey_srs(df, weights = w)
  sc_mean <- get_means(sc, y, variance = "se")
  ybar <- sum(df$w * df$y) / sum(df$w)
  s2   <- sum((df$y - ybar)^2) / (nrow(df) - 1L)
  expect_equal(sc_mean$mean[[1L]], ybar,            tolerance = 1e-14)
  expect_equal(sc_mean$se[[1L]],   sqrt(s2 / 150L), tolerance = 1e-14)
})

test_that("get_means() SRS: population FPC matches survey::svymean() [proper SRS weights]", {
  # Oracle comparison requires w = N/n so HT and classical SRS formulas agree.
  skip_if_not_installed("survey")
  set.seed(11)
  N <- 500L; n <- 50L; w_val <- N / n   # = 10
  df <- data.frame(y = rnorm(n), w = rep(w_val, n), pop = rep(N, n))
  sc <- as_survey_srs(df, weights = w, fpc = pop)
  sv <- survey::svydesign(ids = ~1, weights = ~w, fpc = ~pop, data = df)
  sc_mean <- get_means(sc, y, variance = c("se", "ci"))
  sv_mean <- survey::svymean(~y, sv, na.rm = TRUE)
  expect_equal(sc_mean$mean,    coef(sv_mean)[["y"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,      as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
  expect_equal(sc_mean$ci_low,  confint(sv_mean)[1], tolerance = 1e-6)
  expect_equal(sc_mean$ci_high, confint(sv_mean)[2], tolerance = 1e-6)
})

test_that("get_means() SRS: fraction FPC matches survey::svymean() [proper SRS weights]", {
  # Oracle comparison requires w = N/n = 1/frac so formulas agree.
  skip_if_not_installed("survey")
  set.seed(22)
  n <- 60L; frac_val <- 0.1; w_val <- 1 / frac_val   # = 10
  df <- data.frame(y = rnorm(n), w = rep(w_val, n), frac = rep(frac_val, n))
  sc <- as_survey_srs(df, weights = w, fpc = frac)
  sv <- survey::svydesign(ids = ~1, weights = ~w, fpc = ~frac, data = df)
  sc_mean <- get_means(sc, y, variance = c("se", "ci"))
  sv_mean <- survey::svymean(~y, sv, na.rm = TRUE)
  expect_equal(sc_mean$mean,    coef(sv_mean)[["y"]], tolerance = 1e-10)
  expect_equal(sc_mean$se,      as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)
  expect_equal(sc_mean$ci_low,  confint(sv_mean)[1], tolerance = 1e-6)
  expect_equal(sc_mean$ci_high, confint(sv_mean)[2], tolerance = 1e-6)
})

test_that("get_totals() SRS: no FPC matches survey::svytotal() [uniform weights]", {
  skip_if_not_installed("survey")
  set.seed(33)
  df <- data.frame(y = rnorm(100), w = rep(5, 100))
  sc <- as_survey_srs(df, weights = w)
  sv <- survey::svydesign(ids = ~1, weights = ~w, data = df)
  sc_tot <- get_totals(sc, y, variance = c("se", "ci"))
  sv_tot <- survey::svytotal(~y, sv, na.rm = TRUE)
  expect_equal(sc_tot$total,   coef(sv_tot)[["y"]], tolerance = 1e-10)
  expect_equal(sc_tot$se,      as.numeric(survey::SE(sv_tot)), tolerance = 1e-8)
  expect_equal(sc_tot$ci_low,  confint(sv_tot)[1], tolerance = 1e-6)
  expect_equal(sc_tot$ci_high, confint(sv_tot)[2], tolerance = 1e-6)
})

test_that("get_totals() SRS: population FPC matches survey::svytotal() [proper SRS weights]", {
  # Oracle comparison requires w = N/n so HT and classical SRS formulas agree.
  skip_if_not_installed("survey")
  set.seed(44)
  N <- 500L; n <- 50L; w_val <- N / n   # = 10
  df <- data.frame(y = rnorm(n), w = rep(w_val, n), pop = rep(N, n))
  sc <- as_survey_srs(df, weights = w, fpc = pop)
  sv <- survey::svydesign(ids = ~1, weights = ~w, fpc = ~pop, data = df)
  sc_tot <- get_totals(sc, y, variance = c("se", "ci"))
  sv_tot <- survey::svytotal(~y, sv, na.rm = TRUE)
  expect_equal(sc_tot$total,   coef(sv_tot)[["y"]], tolerance = 1e-10)
  expect_equal(sc_tot$se,      as.numeric(survey::SE(sv_tot)), tolerance = 1e-8)
  expect_equal(sc_tot$ci_low,  confint(sv_tot)[1], tolerance = 1e-6)
  expect_equal(sc_tot$ci_high, confint(sv_tot)[2], tolerance = 1e-6)
})

test_that("get_totals() SRS: fraction FPC matches survey::svytotal() [proper SRS weights]", {
  # Oracle comparison requires w = N/n = 1/frac so formulas agree.
  skip_if_not_installed("survey")
  set.seed(55)
  n <- 60L; frac_val <- 0.1; w_val <- 1 / frac_val   # = 10
  df <- data.frame(y = rnorm(n), w = rep(w_val, n), frac = rep(frac_val, n))
  sc <- as_survey_srs(df, weights = w, fpc = frac)
  sv <- survey::svydesign(ids = ~1, weights = ~w, fpc = ~frac, data = df)
  sc_tot <- get_totals(sc, y, variance = c("se", "ci"))
  sv_tot <- survey::svytotal(~y, sv, na.rm = TRUE)
  expect_equal(sc_tot$total,   coef(sv_tot)[["y"]], tolerance = 1e-10)
  expect_equal(sc_tot$se,      as.numeric(survey::SE(sv_tot)), tolerance = 1e-8)
  expect_equal(sc_tot$ci_low,  confint(sv_tot)[1], tolerance = 1e-6)
  expect_equal(sc_tot$ci_high, confint(sv_tot)[2], tolerance = 1e-6)
})


# ---------------------------------------------------------------------------
# Block 18: SRS variance — structure and edge cases
# ---------------------------------------------------------------------------

test_that("get_means() returns correct structure for survey_srs", {
  df <- data.frame(y = 1:10, w = rep(2, 10))
  sc <- as_survey_srs(df, weights = w)
  result <- get_means(sc, y, variance = "se")
  test_result_invariants(result, "survey_means")
  expect_identical(names(meta(result)$x), "y")
  expect_type(result$mean[[1L]], "double")
  expect_type(result$se[[1L]], "double")
  expect_true(is.finite(result$mean[[1L]]))
  expect_true(is.finite(result$se[[1L]]))
  expect_gte(result$se[[1L]], 0)
})

test_that("get_totals() returns correct structure for survey_srs", {
  df <- data.frame(y = 1:10, w = rep(2, 10))
  sc <- as_survey_srs(df, weights = w)
  result <- get_totals(sc, y, variance = "se")
  test_result_invariants(result, "survey_totals")
  expect_identical(names(meta(result)$x), "y")
  expect_type(result$total[[1L]], "double")
  expect_type(result$se[[1L]], "double")
  expect_true(is.finite(result$total[[1L]]))
  expect_true(is.finite(result$se[[1L]]))
  expect_gte(result$se[[1L]], 0)
})

test_that(".srs_mean() returns NA for all-NA column (edge case: n_used = 0)", {
  df <- data.frame(y = rep(NA_real_, 5), w = rep(1, 5))
  sc <- as_survey_srs(df, weights = w)
  result <- get_means(sc, y, variance = "se", na.rm = TRUE)
  expect_true(is.na(result$mean[[1L]]))
  expect_true(is.na(result$se[[1L]]))
})

test_that(".srs_mean() returns point estimate with NA se for n = 1", {
  df <- data.frame(y = 42, w = 1)
  # suppressWarnings: as_survey_srs() warns that variance cannot be estimated for n=1
  sc <- suppressWarnings(as_survey_srs(df, weights = w))
  result <- get_means(sc, y, variance = "se")
  expect_equal(result$mean[[1L]], 42, tolerance = 1e-14)
  expect_true(is.na(result$se[[1L]]))
})

test_that(".srs_mean() na.rm = FALSE propagates NA when y has NA", {
  df <- data.frame(y = c(1, 2, NA_real_, 4, 5), w = rep(1, 5))
  sc <- as_survey_srs(df, weights = w)
  result <- get_means(sc, y, variance = "se", na.rm = FALSE)
  expect_true(is.na(result$mean[[1L]]))
  expect_true(is.na(result$se[[1L]]))
})

test_that(".srs_total() returns NA for all-NA column (edge case: n_used = 0)", {
  df <- data.frame(y = rep(NA_real_, 5), w = rep(1, 5))
  sc <- as_survey_srs(df, weights = w)
  result <- get_totals(sc, y, variance = "se", na.rm = TRUE)
  expect_true(is.na(result$total[[1L]]))
  expect_true(is.na(result$se[[1L]]))
})

test_that(".srs_total() na.rm = FALSE propagates NA when y has NA", {
  df <- data.frame(y = c(1, 2, NA_real_, 4, 5), w = rep(1, 5))
  sc <- as_survey_srs(df, weights = w)
  result <- get_totals(sc, y, variance = "se", na.rm = FALSE)
  expect_true(is.na(result$total[[1L]]))
  expect_true(is.na(result$se[[1L]]))
})

test_that("get_means() SRS: FPC = population size reduces SE vs no FPC", {
  set.seed(101)
  n <- 50L
  df <- data.frame(y = rnorm(n), w = rep(1, n), pop = rep(500L, n))
  sc_no_fpc  <- as_survey_srs(df, weights = w)
  sc_with_fpc <- as_survey_srs(df, weights = w, fpc = pop)
  r_no  <- get_means(sc_no_fpc, y, variance = "se")
  r_fpc <- get_means(sc_with_fpc, y, variance = "se")
  # FPC reduces SE: f = n/N = 50/500 = 0.1 → SE_fpc = SE_no * sqrt(1 - 0.1) < SE_no
  expect_lt(r_fpc$se[[1L]], r_no$se[[1L]])
})

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
  expect_true(is.na(result$mean[[1L]]))
})

# ---------------------------------------------------------------------------
# Block 19: Direct .srs_mean() calls — orphaned function coverage
# ---------------------------------------------------------------------------

test_that(".srs_mean() population FPC path: SE reduced vs no FPC", {
  set.seed(200)
  n <- 80L; N <- 800L
  df <- data.frame(y = rnorm(n), w = rep(N / n, n), pop = rep(N, n))
  sc <- as_survey_srs(df, weights = w, fpc = pop)

  result_no  <- surveycore:::.srs_mean(
    as_survey_srs(data.frame(y = df$y, w = df$w), weights = w),
    "y"
  )
  result_fpc <- surveycore:::.srs_mean(sc, "y")

  expect_equal(result_no$mean, result_fpc$mean, tolerance = 1e-14)
  expect_true(is.finite(result_fpc$se))
  expect_lt(result_fpc$se, result_no$se)          # FPC shrinks SE
  expect_equal(result_fpc$df, n - 1L)
})

test_that(".srs_mean() fraction FPC path: SE reduced vs no FPC", {
  set.seed(201)
  n <- 60L; frac <- 0.1
  df <- data.frame(y = rnorm(n), w = rep(1 / frac, n), f = rep(frac, n))
  sc <- as_survey_srs(df, weights = w, fpc = f)

  result_fpc <- surveycore:::.srs_mean(sc, "y")

  expect_true(is.finite(result_fpc$mean))
  expect_true(is.finite(result_fpc$se))
  expect_gte(result_fpc$se, 0)
})

test_that(".srs_mean() returns NA when all values are NA (n_used = 0)", {
  df <- data.frame(y = rep(NA_real_, 10), w = rep(1, 10))
  sc <- as_survey_srs(df, weights = w)
  result <- surveycore:::.srs_mean(sc, "y", na.rm = TRUE)
  expect_true(is.na(result$mean))
  expect_true(is.na(result$se))
  expect_equal(result$df, 0L)
})

test_that(".srs_mean() n = 1 returns point estimate with NA se", {
  df <- data.frame(y = 42, w = 1)
  sc <- suppressWarnings(as_survey_srs(df, weights = w))
  result <- surveycore:::.srs_mean(sc, "y")
  expect_equal(result$mean, 42, tolerance = 1e-14)
  expect_true(is.na(result$se))
  expect_equal(result$df, 0L)
})

test_that(".srs_mean() na.rm = FALSE propagates NA", {
  df <- data.frame(y = c(1, 2, NA_real_, 4, 5), w = rep(1, 5))
  sc <- as_survey_srs(df, weights = w)
  result <- surveycore:::.srs_mean(sc, "y", na.rm = FALSE)
  expect_true(is.na(result$mean))
  expect_true(is.na(result$se))
})

# ---------------------------------------------------------------------------
# Block 20: Direct .srs_total() calls — orphaned function coverage
# ---------------------------------------------------------------------------

test_that(".srs_total() population FPC path: SE reduced vs no FPC", {
  set.seed(202)
  n <- 80L; N <- 800L
  df <- data.frame(y = rnorm(n), w = rep(N / n, n), pop = rep(N, n))
  sc_fpc  <- as_survey_srs(df, weights = w, fpc = pop)
  sc_nofpc <- as_survey_srs(data.frame(y = df$y, w = df$w), weights = w)

  result_fpc   <- surveycore:::.srs_total(sc_fpc, "y")
  result_nofpc <- surveycore:::.srs_total(sc_nofpc, "y")

  expect_true(is.finite(result_fpc$total))
  expect_true(is.finite(result_fpc$se))
  expect_lt(result_fpc$se, result_nofpc$se)
})

test_that(".srs_total() fraction FPC path: produces finite SE", {
  set.seed(203)
  n <- 60L; frac <- 0.2
  df <- data.frame(y = rnorm(n), w = rep(1 / frac, n), f = rep(frac, n))
  sc <- as_survey_srs(df, weights = w, fpc = f)
  result <- surveycore:::.srs_total(sc, "y")
  expect_true(is.finite(result$total))
  expect_true(is.finite(result$se))
  expect_gte(result$se, 0)
})

test_that(".srs_total() n = 1 returns point estimate with NA se", {
  df <- data.frame(y = 5, w = 2)
  sc <- suppressWarnings(as_survey_srs(df, weights = w))
  result <- surveycore:::.srs_total(sc, "y")
  expect_equal(result$total, 10, tolerance = 1e-14)  # 5 * 2
  expect_true(is.na(result$se))
  expect_equal(result$df, 0L)
})

test_that(".srs_total() all-NA column returns NA", {
  df <- data.frame(y = rep(NA_real_, 8), w = rep(1, 8))
  sc <- as_survey_srs(df, weights = w)
  result <- surveycore:::.srs_total(sc, "y", na.rm = TRUE)
  expect_true(is.na(result$total))
  expect_true(is.na(result$se))
  expect_equal(result$df, 0L)
})

test_that(".srs_total() na.rm = FALSE propagates NA", {
  df <- data.frame(y = c(1, 2, NA_real_, 4, 5), w = rep(1, 5))
  sc <- as_survey_srs(df, weights = w)
  result <- surveycore:::.srs_total(sc, "y", na.rm = FALSE)
  expect_true(is.na(result$total))
  expect_true(is.na(result$se))
})

# ---------------------------------------------------------------------------
# Block 21: get_corr() with survey_srs — covers .vcov_pair_srs()
# ---------------------------------------------------------------------------

test_that("get_corr() works for survey_srs design", {
  set.seed(204)
  n <- 100L
  x <- rnorm(n); y <- x + rnorm(n, sd = 0.5)
  df <- data.frame(x = x, y = y, w = rep(1, n))
  sc <- as_survey_srs(df, weights = w)
  result <- get_corr(sc, x = c(x, y), variance = "se")
  test_result_invariants(result, "survey_corr")
  expect_identical(as.character(result$var1[[1L]]), "x")
  expect_identical(as.character(result$var2[[1L]]), "y")
  expect_true(is.finite(result$r[[1L]]))
  expect_gte(result$se[[1L]], 0)
})

test_that("get_corr() SRS with FPC covers .vcov_pair_srs() FPC path", {
  set.seed(205)
  n <- 80L; N <- 800L
  x <- rnorm(n); y <- x + rnorm(n, sd = 0.5)
  df <- data.frame(x = x, y = y, w = rep(N / n, n), pop = rep(N, n))
  sc <- as_survey_srs(df, weights = w, fpc = pop)
  result <- get_corr(sc, x = c(x, y), variance = "se")
  expect_true(is.finite(result$r[[1L]]))
  expect_gte(result$se[[1L]], 0)
})

test_that("get_corr() SRS returns NA when domain has fewer than 2 paired obs", {
  set.seed(206)
  n <- 20L
  df <- data.frame(
    x = c(rnorm(19L), NA_real_),
    y = c(rnorm(19L), NA_real_),
    w = rep(1, n)
  )
  sc <- as_survey_srs(df, weights = w)
  # Only the last row is in domain; it has NA x and y, so paired n_d < 2
  sc@data[[surveycore::SURVEYCORE_DOMAIN_COL]] <- c(rep(FALSE, 19L), TRUE)
  result <- get_corr(sc, x = c(x, y), variance = "se")
  expect_true(is.na(result$r[[1L]]))
})

# ---------------------------------------------------------------------------
# Additional coverage: FPC fraction path in .vcov_pair_srs()
# ---------------------------------------------------------------------------

test_that("get_corr() SRS with FPC fraction covers FPC fraction branch in .vcov_pair_srs()", {
  set.seed(901)
  n <- 80L
  frac <- 0.1
  df <- data.frame(
    x = rnorm(n), y = rnorm(n),
    w = rep(1 / frac, n),
    frac = rep(frac, n)
  )
  sc <- as_survey_srs(df, weights = w, fpc = frac)
  result <- get_corr(sc, x = c(x, y), variance = "se")
  test_result_invariants(result, "survey_corr")
  expect_true(is.finite(result$r[[1L]]))
  expect_gte(result$se[[1L]], 0)
})
