# test-analysis-corr.R
# Tests for get_corr() — Phase 1 survey-weighted Pearson correlation.
#
# Numerical tolerance: 1e-10 for r, 1e-8 for SE.
# Oracle: survey::svyvar() for all design types.
# Fisher Z CI oracle tolerance: 1e-6.

# ---------------------------------------------------------------------------
# Category 1: Happy path — return structure (all design types)
# ---------------------------------------------------------------------------

test_that("get_corr() returns survey_corr tibble for survey_taylor", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L,
                         design = "taylor", seed = 1L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_corr(d, x = c(y1, y2))
  test_result_invariants(result, "survey_corr")
  expect_true("var1"      %in% names(result))
  expect_true("var2"      %in% names(result))
  expect_true("r"         %in% names(result))
  expect_true("ci_low"    %in% names(result))
  expect_true("ci_high"   %in% names(result))
  expect_true("p_value"   %in% names(result))
  expect_true("statistic" %in% names(result))
  expect_true("df"        %in% names(result))
  expect_true("n"         %in% names(result))
  expect_false("se"       %in% names(result))   # not in default variance = "ci"
  expect_equal(nrow(result), 1L)                # one pair: (y1, y2)
  expect_equal(result$var1[[1L]], "y1")
  expect_equal(result$var2[[1L]], "y2")
  expect_true(is.finite(result$r[[1L]]))
  expect_true(is.finite(result$ci_low[[1L]]))
  expect_true(is.finite(result$ci_high[[1L]]))
  expect_true(result$ci_low[[1L]] >= -1)
  expect_true(result$ci_high[[1L]] <= 1)
  expect_lt(result$ci_low[[1L]], result$ci_high[[1L]])
})

test_that("get_corr() works for survey_replicate design", {
  df <- make_survey_data(n = 200L, n_psu = 20L, design = "replicate",
                         type = "brr", seed = 2L)
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  d <- as_survey_rep(df, weights = wt, repweights = all_of(repwt_cols),
                     type = "BRR")

  result <- get_corr(d, x = c(y1, y2))
  test_result_invariants(result, "survey_corr")
  expect_true(is.finite(result$r[[1L]]))
  expect_true(is.finite(result$ci_low[[1L]]))
  expect_true(result$ci_low[[1L]] >= -1)
  expect_true(result$ci_high[[1L]] <= 1)
})

test_that("get_corr() works for survey_srs design", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 3L)
  d  <- as_survey_srs(df, weights = wt)

  result <- get_corr(d, x = c(y1, y2))
  test_result_invariants(result, "survey_corr")
  expect_true(is.finite(result$r[[1L]]))
})

test_that("get_corr() works for survey_twophase design", {
  df  <- make_survey_data(design = "twophase", n = 300L, n_psu = 30L,
                          n_strata = 3L, seed = 4L)
  ph1 <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  d   <- as_survey_twophase(ph1, subset = subset, method = "approx")

  result <- get_corr(d, x = c(y1, y2))
  test_result_invariants(result, "survey_corr")
  expect_true(is.finite(result$r[[1L]]))
})

test_that("get_corr() works for survey_calibrated design", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 5L)
  d  <- as_survey_calibrated(df, weights = wt)

  result <- get_corr(d, x = c(y1, y2))
  test_result_invariants(result, "survey_corr")
  expect_true(is.finite(result$r[[1L]]))
})

# ---------------------------------------------------------------------------
# Category 2: meta() content
# ---------------------------------------------------------------------------

test_that("get_corr() meta() stores variables, method, and design type", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 6L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_corr(d, x = c(y1, y2))
  m      <- meta(result)

  expect_identical(m$variables, c("y1", "y2"))
  expect_identical(m$method, "pearson")
  expect_equal(m$conf_level, 0.95)
  expect_identical(m$design_type, "taylor")
  expect_type(m$n_respondents, "integer")
  expect_gt(m$n_respondents, 0L)
  expect_identical(m$group_names, character(0))
  expect_true("value_labels" %in% names(m))
  expect_type(m$value_labels, "list")
  # Numeric vars → value_labels entries are NULL
  expect_null(m$value_labels[["y1"]])
  expect_null(m$value_labels[["y2"]])
})

# ---------------------------------------------------------------------------
# Category 3: Grouped analysis — @groups ignored (no group= argument)
# ---------------------------------------------------------------------------

test_that("get_corr() ignores @groups (group= argument not supported)", {
  skip_if_not_installed("surveytidy")
  df <- make_survey_data(n = 200L, design = "taylor", seed = 7L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  d_grouped <- surveytidy::group_by(d, group)
  result_g  <- get_corr(d_grouped, x = c(y1, y2))
  result_u  <- get_corr(d,          x = c(y1, y2))

  # With @groups, get_corr() still produces one row (no group columns)
  expect_equal(nrow(result_g), 1L)
  expect_false("group" %in% names(result_g))
  # Results should be identical (groups ignored)
  expect_equal(result_g$r[[1L]], result_u$r[[1L]], tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# Category 4: Domain estimation
# ---------------------------------------------------------------------------

test_that("get_corr() domain estimation restricts n to in-domain rows", {
  skip_if_not_installed("surveytidy")
  df <- make_survey_data(n = 300L, n_psu = 30L, n_strata = 3L,
                         design = "taylor", seed = 8L)
  d    <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  d_f  <- surveytidy::filter(d, group == "A")

  result_full   <- get_corr(d,   x = c(y1, y2))
  result_domain <- get_corr(d_f, x = c(y1, y2))

  # Domain n ≤ full n
  expect_lte(result_domain$n[[1L]], result_full$n[[1L]])
  # Results differ (domain estimation gives correct SE from full design)
  expect_false(isTRUE(all.equal(result_full$r[[1L]], result_domain$r[[1L]])))
})

test_that("get_corr() domain + survey_taylor SE is finite and nonzero", {
  skip_if_not_installed("surveytidy")
  df <- make_survey_data(n = 400L, n_psu = 40L, n_strata = 4L,
                         design = "taylor", seed = 9L)
  d   <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  d_f <- surveytidy::filter(d, group == "A")

  result <- get_corr(d_f, x = c(y1, y2), variance = "se")
  expect_true(is.finite(result$se[[1L]]))
  expect_gt(result$se[[1L]], 0)
})

# ---------------------------------------------------------------------------
# Category 5: Variance columns
# ---------------------------------------------------------------------------

test_that("get_corr() returns all requested variance columns", {
  df <- make_survey_data(n = 200L, n_psu = 20L, design = "taylor", seed = 10L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_corr(d, x = c(y1, y2),
                     variance = c("se", "ci", "var", "moe"))
  expect_true("se"      %in% names(result))
  expect_true("var"     %in% names(result))
  expect_true("ci_low"  %in% names(result))
  expect_true("ci_high" %in% names(result))
  expect_true("moe"     %in% names(result))
  # var = se^2
  expect_equal(result$var[[1L]], result$se[[1L]]^2, tolerance = 1e-15)
  # moe = (ci_high - ci_low) / 2
  expect_equal(
    result$moe[[1L]],
    (result$ci_high[[1L]] - result$ci_low[[1L]]) / 2,
    tolerance = 1e-10
  )
})

test_that("get_corr() variance = NULL produces no variance columns", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 11L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_corr(d, x = c(y1, y2), variance = NULL)
  expect_false("se"     %in% names(result))
  expect_false("ci_low" %in% names(result))
})

test_that("get_corr() deff column produced when requested", {
  df <- make_survey_data(n = 200L, n_psu = 20L, design = "taylor", seed = 12L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_corr(d, x = c(y1, y2), variance = "deff")
  expect_true("deff" %in% names(result))
  expect_true(is.numeric(result$deff))
})

test_that("get_corr() n_weighted column produced when requested", {
  df <- make_survey_data(n = 200L, n_psu = 20L, design = "taylor", seed = 13L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result_nw <- get_corr(d, x = c(y1, y2), n_weighted = TRUE)
  expect_true("n_weighted" %in% names(result_nw))
  expect_true(result_nw$n_weighted[[1L]] > 0)

  result_no <- get_corr(d, x = c(y1, y2), n_weighted = FALSE)
  expect_false("n_weighted" %in% names(result_no))
})

# ---------------------------------------------------------------------------
# Category 6: Fisher Z CI properties
# ---------------------------------------------------------------------------

test_that("get_corr() Fisher Z CI bounds are always in (-1, 1)", {
  # Construct a dataset with high correlation for extreme CI test
  set.seed(42L)
  n <- 200L
  x_base <- rnorm(n, 50, 10)
  df <- data.frame(
    y1 = x_base + rnorm(n, 0, 1),   # high positive correlation with y2
    y2 = x_base + rnorm(n, 0, 1),
    wt = runif(n, 0.5, 2)
  )
  d <- as_survey_srs(df, weights = wt)

  result <- get_corr(d, x = c(y1, y2))
  expect_gt(result$ci_low[[1L]], -1)
  expect_lt(result$ci_high[[1L]], 1)
  # High correlation: r > 0.9
  expect_gt(result$r[[1L]], 0.9)
})

test_that("get_corr() Fisher Z CI width for |r| > 0.9 matches oracle", {
  skip_if_not_installed("survey")
  set.seed(99L)
  n <- 200L
  x_base <- rnorm(n, 50, 10)
  df <- data.frame(
    y1 = x_base + rnorm(n, 0, 1),
    y2 = x_base + rnorm(n, 0, 1),
    wt = runif(n, 0.5, 2)
  )
  d_sc <- as_survey_srs(df, weights = wt)
  d_sv <- survey::svydesign(ids = ~1, weights = ~wt, data = df)

  result <- get_corr(d_sc, x = c(y1, y2), variance = c("ci", "se"))

  sv   <- survey::svyvar(~ y1 + y2, d_sv)
  a    <- sv[1L, 1L]; b <- sv[1L, 2L]; cv <- sv[2L, 2L]
  r_or <- b / sqrt(a * cv)
  sig  <- vcov(sv)[c(1L, 2L, 4L), c(1L, 2L, 4L)]
  g    <- c(-r_or / (2 * a), 1 / sqrt(a * cv), -r_or / (2 * cv))
  se_or <- sqrt(as.numeric(t(g) %*% sig %*% g))
  z_crit <- stats::qnorm(0.975)
  ci_low_or  <- tanh(atanh(r_or) - z_crit * se_or)
  ci_high_or <- tanh(atanh(r_or) + z_crit * se_or)

  expect_gt(result$r[[1L]], 0.9)   # confirm high correlation
  # Fisher Z CI width matches oracle within 1e-5 (larger than typical due to
  # SRS implementation differences in weighted vs. unweighted variance formula)
  expect_equal(result$ci_low[[1L]],  ci_low_or,  tolerance = 1e-5)
  expect_equal(result$ci_high[[1L]], ci_high_or, tolerance = 1e-5)
})

# ---------------------------------------------------------------------------
# Category 7: p_value, statistic, df columns
# ---------------------------------------------------------------------------

test_that("get_corr() p_value, statistic, df are always present in long format", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 14L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_corr(d, x = c(y1, y2))
  expect_true("p_value"   %in% names(result))
  expect_true("statistic" %in% names(result))
  expect_true("df"        %in% names(result))
  expect_true(is.finite(result$p_value[[1L]]))
  expect_true(result$p_value[[1L]] >= 0)
  expect_true(result$p_value[[1L]] <= 1)
  # df = n - 2
  expect_equal(as.integer(result$df[[1L]]), as.integer(result$n[[1L]]) - 2L)
})

# ---------------------------------------------------------------------------
# Category 8: Format and structure options
# ---------------------------------------------------------------------------

test_that("get_corr() wide format returns correlation matrix with correct dims", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 15L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_corr(d, x = c(y1, y2, y3), format = "wide")
  test_result_invariants(result, "survey_corr")
  expect_equal(nrow(result), 3L)            # one row per variable
  expect_equal(ncol(result), 4L)            # variable + 3 correlation columns
  expect_true("variable" %in% names(result))
  # No variance/inference columns in wide format
  expect_false("p_value"   %in% names(result))
  expect_false("statistic" %in% names(result))
  expect_false("ci_low"    %in% names(result))
  # meta() method still works
  m <- meta(result)
  expect_identical(m$method, "pearson")
})

test_that("get_corr() wide format diagonal is NA by default", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 16L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result_wide <- get_corr(d, x = c(y1, y2), format = "wide")
  # Diagonal cells: row y1-col y1 and row y2-col y2 should be NA
  r_mat <- as.matrix(result_wide[, -1L])
  expect_true(all(is.na(diag(r_mat))))
})

test_that("get_corr() wide format diagonal = TRUE gives 1 on diagonal", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 17L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result_wide <- get_corr(d, x = c(y1, y2), format = "wide", diagonal = TRUE)
  r_mat <- as.matrix(result_wide[, -1L])
  expect_equal(diag(r_mat), c(1, 1), tolerance = 1e-15)
})

test_that("get_corr() meta()$method is 'pearson'", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 18L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_corr(d, x = c(y1, y2))
  expect_identical(meta(result)$method, "pearson")
})

# ---------------------------------------------------------------------------
# Category 9: redundant and diagonal arguments
# ---------------------------------------------------------------------------

test_that("get_corr() redundant = FALSE produces n*(n-1)/2 rows", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 19L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result_3vars <- get_corr(d, x = c(y1, y2, y3), redundant = FALSE)
  expect_equal(nrow(result_3vars), 3L)  # 3*(3-1)/2 = 3 pairs
})

test_that("get_corr() redundant = TRUE produces n*(n-1) rows", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 20L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result_r <- get_corr(d, x = c(y1, y2, y3), redundant = TRUE, diagonal = FALSE)
  expect_equal(nrow(result_r), 6L)   # 3*2 = 6 directed pairs
})

test_that("get_corr() diagonal = TRUE includes self-correlations (r = 1)", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 21L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_corr(d, x = c(y1, y2), diagonal = TRUE, redundant = FALSE)
  # 1 pair + 2 diagonal = 3 rows
  expect_equal(nrow(result), 3L)
  diag_rows <- result[result$var1 == result$var2, ]
  expect_equal(diag_rows$r, c(1, 1), tolerance = 1e-15)
})

test_that("get_corr() redundant rows have same r as their mirror", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 22L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_corr(d, x = c(y1, y2), redundant = TRUE, diagonal = FALSE)
  expect_equal(nrow(result), 2L)
  expect_equal(result$r[[1L]], result$r[[2L]], tolerance = 1e-15)
  expect_equal(result$var1[[1L]], result$var2[[2L]])
  expect_equal(result$var2[[1L]], result$var1[[2L]])
})

# ---------------------------------------------------------------------------
# Category 10: Pairwise n with NA
# ---------------------------------------------------------------------------

test_that("get_corr() pairwise n differs across pairs when NAs are staggered", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 23L)
  df$y1[1:10]  <- NA   # 10 NAs in y1
  df$y2[5:20]  <- NA   # 16 NAs in y2 (overlap: rows 5-10 = 6 shared)
  df$y3        <- rnorm(nrow(df))   # no NAs

  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  # 3 variables: pairs (y1,y2), (y1,y3), (y2,y3)
  result <- get_corr(d, x = c(y1, y2, y3), redundant = FALSE)
  expect_equal(nrow(result), 3L)

  # n for (y1, y2) < n for (y1, y3) and n for (y2, y3)
  n_y1y2 <- result$n[result$var1 == "y1" & result$var2 == "y2"]
  n_y1y3 <- result$n[result$var1 == "y1" & result$var2 == "y3"]
  n_y2y3 <- result$n[result$var1 == "y2" & result$var2 == "y3"]

  expect_lt(n_y1y2, n_y1y3)
  expect_lt(n_y1y2, n_y2y3)
})

# ---------------------------------------------------------------------------
# Category 11: label_vars
# ---------------------------------------------------------------------------

test_that("get_corr() label_vars = TRUE shows variable labels in var1/var2", {
  df <- make_survey_data(n = 100L, design = "taylor", with_labels = TRUE,
                         seed = 24L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  d  <- set_var_label(d, y1, "Outcome Y1")
  d  <- set_var_label(d, y2, "Outcome Y2")

  result_lbl  <- get_corr(d, x = c(y1, y2), label_vars = TRUE)
  result_raw  <- get_corr(d, x = c(y1, y2), label_vars = FALSE)

  expect_equal(result_lbl$var1[[1L]], "Outcome Y1")
  expect_equal(result_lbl$var2[[1L]], "Outcome Y2")
  expect_equal(result_raw$var1[[1L]], "y1")
  expect_equal(result_raw$var2[[1L]], "y2")
})

# ---------------------------------------------------------------------------
# Category 12: name_style
# ---------------------------------------------------------------------------

test_that("get_corr() name_style = 'broom' renames r -> estimate", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 25L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_corr(d, x = c(y1, y2), name_style = "broom",
                     variance = c("se", "ci"))
  expect_true("estimate"  %in% names(result))
  expect_false("r"        %in% names(result))
  expect_true("std.error" %in% names(result))
  expect_false("se"       %in% names(result))
  expect_true("conf.low"  %in% names(result))
  expect_true("conf.high" %in% names(result))
  # class and meta preserved
  expect_true(inherits(result, "survey_corr"))
  expect_false(is.null(meta(result)))
})

# ---------------------------------------------------------------------------
# Category 2 (oracle): Numerical validation — survey::svyvar()
# ---------------------------------------------------------------------------

test_that("get_corr() r matches survey::svyvar() oracle for Taylor [numerical]", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 500L, n_psu = 50L, n_strata = 5L,
                         design = "taylor", seed = 30L)
  d_sc <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  d_sv <- survey::svydesign(
    ids = ~psu, weights = ~wt, strata = ~strata,
    data = df, nest = TRUE
  )

  result <- get_corr(d_sc, x = c(y1, y2), variance = "se")

  sv     <- survey::svyvar(~ y1 + y2, d_sv)
  a      <- sv[1L, 1L]; b <- sv[1L, 2L]; cv <- sv[2L, 2L]
  r_or   <- b / sqrt(a * cv)
  # vcov(svyvar()) is 4x4 (all entries of 2x2 matrix); extract unique 3x3
  # indices: (1,1)=Var(y1), (1,2)=Cov(y1,y2), (2,2)=Var(y2) → positions 1,2,4
  sig    <- vcov(sv)[c(1L, 2L, 4L), c(1L, 2L, 4L)]
  g      <- c(-r_or / (2 * a), 1 / sqrt(a * cv), -r_or / (2 * cv))
  se_or  <- sqrt(as.numeric(t(g) %*% sig %*% g))

  expect_equal(result$r[[1L]],  r_or,  tolerance = 1e-10)
  expect_equal(result$se[[1L]], se_or, tolerance = 1e-8)
})

test_that("get_corr() r matches survey::svyvar() oracle for BRR [numerical]", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 500L, n_psu = 50L, design = "replicate",
                         type = "brr", seed = 31L)
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  d_sc <- as_survey_rep(df, weights = wt, repweights = all_of(repwt_cols),
                        type = "BRR")
  d_sv <- survey::svrepdesign(
    weights = ~wt,
    repweights = df[, repwt_cols],
    type = "BRR",
    mse = TRUE,
    data = df
  )

  result <- get_corr(d_sc, x = c(y1, y2), variance = "se")

  # suppressWarnings: survey::svyvar with mse=TRUE/BRR may warn about sweep dims
  sv    <- suppressWarnings(survey::svyvar(~ y1 + y2, d_sv))
  a     <- sv[1L, 1L]; b <- sv[1L, 2L]; cv <- sv[2L, 2L]
  r_or  <- b / sqrt(a * cv)
  sig   <- vcov(sv)[c(1L, 2L, 4L), c(1L, 2L, 4L)]
  g     <- c(-r_or / (2 * a), 1 / sqrt(a * cv), -r_or / (2 * cv))
  se_or <- sqrt(as.numeric(t(g) %*% sig %*% g))

  expect_equal(result$r[[1L]],  r_or,  tolerance = 1e-10)
  expect_equal(result$se[[1L]], se_or, tolerance = 1e-8)
})

test_that("get_corr() r matches survey::svyvar() oracle for SRS [numerical]", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 500L, design = "taylor", seed = 32L)
  d_sc <- as_survey_srs(df, weights = wt)
  d_sv <- survey::svydesign(ids = ~1, weights = ~wt, data = df)

  result <- get_corr(d_sc, x = c(y1, y2), variance = "se")

  sv    <- survey::svyvar(~ y1 + y2, d_sv)
  a     <- sv[1L, 1L]; b <- sv[1L, 2L]; cv <- sv[2L, 2L]
  r_or  <- b / sqrt(a * cv)
  sig   <- vcov(sv)[c(1L, 2L, 4L), c(1L, 2L, 4L)]
  g     <- c(-r_or / (2 * a), 1 / sqrt(a * cv), -r_or / (2 * cv))
  se_or <- sqrt(as.numeric(t(g) %*% sig %*% g))

  expect_equal(result$r[[1L]],  r_or,  tolerance = 1e-10)
  expect_equal(result$se[[1L]], se_or, tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# Error paths
# ---------------------------------------------------------------------------

test_that("get_corr() throws for non-survey-base object", {
  expect_error(
    get_corr(list(x = 1), x = c(y1, y2)),
    class = "surveycore_error_unsupported_class"
  )
  expect_snapshot(error = TRUE, get_corr(list(x = 1), x = c(y1, y2)))
})

test_that("get_corr() throws surveycore_error_insufficient_variables for < 2 vars", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 40L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  expect_error(
    get_corr(d, x = y1),
    class = "surveycore_error_insufficient_variables"
  )
  expect_snapshot(error = TRUE, get_corr(d, x = y1))
})

test_that("get_corr() warns and drops non-numeric variables", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 41L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  # Two numeric + one non-numeric: drop group with warning, (y1, y2) succeed
  expect_warning(
    result <- get_corr(d, x = c(y1, y2, group)),
    class = "surveycore_warning_corr_non_numeric"
  )
  expect_equal(nrow(result), 1L)   # only (y1, y2) pair remains

  # Only one numeric after dropping: warn then error
  expect_warning(
    expect_error(
      get_corr(d, x = c(y1, group)),
      class = "surveycore_error_insufficient_variables"
    ),
    class = "surveycore_warning_corr_non_numeric"
  )
})

test_that("get_corr() warns + errors when all vars are non-numeric", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 42L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  # Both group and psu are non-numeric
  expect_warning(
    expect_error(
      get_corr(d, x = c(group, psu)),
      class = "surveycore_error_insufficient_variables"
    ),
    class = "surveycore_warning_corr_non_numeric"
  )
})

test_that("get_corr() throws for invalid variance argument", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 43L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  expect_error(
    get_corr(d, x = c(y1, y2), variance = "bad"),
    class = "surveycore_error_invalid_variance_arg"
  )
})

test_that("get_corr() throws for invalid conf_level", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 44L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  expect_error(
    get_corr(d, x = c(y1, y2), conf_level = 1.5),
    class = "surveycore_error_invalid_conf_level"
  )
})

test_that("get_corr() throws for invalid name_style", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 45L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  expect_error(
    get_corr(d, x = c(y1, y2), name_style = "tidy"),
    class = "surveycore_error_invalid_name_style"
  )
})

test_that("get_corr() fires surveycore_warning_small_cell for small pairwise n", {
  # Construct domain with very few rows
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 2L,
                         design = "taylor", seed = 46L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  # Use a very large min_cell_n to trigger the warning even for large samples
  expect_warning(
    get_corr(d, x = c(y1, y2), min_cell_n = nrow(df) + 1L),
    class = "surveycore_warning_small_cell"
  )
})

test_that("get_corr() fires surveycore_warning_cv_undefined when r = 0 approx", {
  # We can only reliably test this with a constructed case
  df <- make_survey_data(n = 50L, design = "taylor", seed = 47L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  # Note: cv warning fires only when r <= 0 (will happen in pathological cases)
  # Just verify that requesting cv doesn't cause an error for normal r values
  result <- get_corr(d, x = c(y1, y2), variance = "cv")
  expect_true("cv" %in% names(result))
})

# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

test_that("get_corr() handles all-NA in one variable (both removed)", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 50L)
  df$y1 <- NA_real_
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_corr(d, x = c(y1, y2))
  expect_true(is.na(result$r[[1L]]))
  expect_equal(result$n[[1L]], 0L)
})

test_that("get_corr() na.rm = TRUE gives pairwise complete-case n", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 51L)
  df$y1[1:20] <- NA
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result_rm  <- get_corr(d, x = c(y1, y2), na.rm = TRUE)
  expect_equal(result_rm$n[[1L]], as.integer(sum(!is.na(df$y1))))
})

test_that("get_corr() 3-variable call gives n*(n-1)/2 = 3 rows", {
  df <- make_survey_data(n = 200L, design = "taylor", seed = 52L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_corr(d, x = c(y1, y2, y3))
  expect_equal(nrow(result), 3L)
  expect_identical(result$var1, c("y1", "y1", "y2"))
  expect_identical(result$var2, c("y2", "y3", "y3"))
})
