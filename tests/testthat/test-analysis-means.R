# test-analysis-means.R
# Tests for get_means() — the Phase 1 weighted-mean estimation function.
#
# Numerical tolerance: 1e-10 for point estimates, 1e-8 for SE.
# Oracle tests skip if the 'survey' package is not installed.

# ---------------------------------------------------------------------------
# Category 1: Happy path — return structure (all design types)
# ---------------------------------------------------------------------------

test_that("get_means() returns survey_means tibble for survey_taylor", {
  df <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L,
                         design = "taylor", seed = 1L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_means(d, y1)
  test_result_invariants(result, "survey_means")
  expect_true("mean"    %in% names(result))
  expect_true("ci_low"  %in% names(result))
  expect_true("ci_high" %in% names(result))
  expect_true("n"       %in% names(result))
  expect_false("se"     %in% names(result))   # not in default variance = "ci"
  expect_true(is.finite(result$mean[[1L]]))
  expect_true(is.finite(result$ci_low[[1L]]))
  expect_true(is.finite(result$ci_high[[1L]]))
  expect_lt(result$ci_low[[1L]], result$ci_high[[1L]])
})

test_that("get_means() works for survey_replicate design", {
  df <- make_survey_data(n = 100L, n_psu = 10L, design = "replicate",
                         type = "brr", seed = 2L)
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  d <- as_survey_rep(df, weights = wt, repweights = all_of(repwt_cols), type = "BRR")

  result <- get_means(d, y1)
  test_result_invariants(result, "survey_means")
  expect_true(is.finite(result$mean[[1L]]))
  expect_true(is.finite(result$ci_low[[1L]]))
})

test_that("get_means() works for survey_srs design", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 3L)
  d  <- as_survey_srs(df, weights = wt)

  result <- get_means(d, y1)
  test_result_invariants(result, "survey_means")
  expect_true(is.finite(result$mean[[1L]]))
})

test_that("get_means() works for survey_twophase design", {
  df  <- make_survey_data(design = "twophase", n = 200L, n_psu = 20L,
                          n_strata = 2L, seed = 4L)
  ph1 <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  d   <- as_survey_twophase(ph1, subset = subset, method = "approx")

  result <- get_means(d, y1)
  test_result_invariants(result, "survey_means")
  expect_true(is.finite(result$mean[[1L]]))
})

test_that("get_means() works for survey_calibrated design", {
  df <- make_survey_data(n = 100L, design = "taylor", seed = 5L)
  d  <- as_survey_calibrated(df, weights = wt)

  result <- get_means(d, y1)
  test_result_invariants(result, "survey_means")
  expect_true(is.finite(result$mean[[1L]]))
})

# ---------------------------------------------------------------------------
# Category 2: meta() content
# ---------------------------------------------------------------------------

test_that("get_means() meta() stores variable name and design type", {
  df <- make_survey_data(n = 50L, design = "taylor", seed = 6L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_means(d, y1)
  m      <- meta(result)

  expect_identical(names(m$x), "y1")
  expect_true(is.character(m$design_type))
  expect_equal(m$conf_level, 0.95)
  expect_type(m$group, "list")
  expect_length(m$group, 0L)
})

# ---------------------------------------------------------------------------
# Category 3: variance= argument — column presence
# ---------------------------------------------------------------------------

test_that("get_means() variance = 'se' produces se column", {
  df <- make_survey_data(n = 50L, design = "taylor", seed = 7L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_means(d, y1, variance = "se")
  expect_true("se" %in% names(result))
  expect_false("ci_low" %in% names(result))
  expect_false("ci_high" %in% names(result))
  expect_true(is.finite(result$se[[1L]]))
  expect_gte(result$se[[1L]], 0)
})

test_that("get_means() variance = c('se', 'ci') produces se + CI columns", {
  df <- make_survey_data(n = 50L, design = "taylor", seed = 8L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_means(d, y1, variance = c("se", "ci"))
  expect_true("se"     %in% names(result))
  expect_true("ci_low" %in% names(result))
  expect_true("ci_high" %in% names(result))
})

test_that("get_means() variance = 'var' produces var column", {
  df <- make_survey_data(n = 50L, design = "taylor", seed = 9L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_means(d, y1, variance = "var")
  expect_true("var" %in% names(result))
  expect_gte(result$var[[1L]], 0)
  expect_equal(sqrt(result$var[[1L]]),
               get_means(d, y1, variance = "se")$se[[1L]],
               tolerance = 1e-14)
})

test_that("get_means() variance = 'cv' produces cv column", {
  df <- make_survey_data(n = 50L, design = "taylor", seed = 10L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_means(d, y1, variance = "cv")
  expect_true("cv" %in% names(result))
  # cv = se / |mean|
  r2 <- get_means(d, y1, variance = "se")
  expect_equal(result$cv[[1L]],
               r2$se[[1L]] / abs(r2$mean[[1L]]),
               tolerance = 1e-14)
})

test_that("get_means() variance = 'moe' produces moe column", {
  df <- make_survey_data(n = 50L, design = "taylor", seed = 11L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_means(d, y1, variance = "moe")
  expect_true("moe" %in% names(result))
  expect_gte(result$moe[[1L]], 0)
})

test_that("get_means() variance = 'deff' produces deff column", {
  df <- make_survey_data(n = 100L, n_psu = 10L, design = "taylor", seed = 12L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_means(d, y1, variance = "deff")
  expect_true("deff" %in% names(result))
  expect_gte(result$deff[[1L]], 0)
})

test_that("get_means() variance = NULL produces only mean + n columns", {
  df <- make_survey_data(n = 50L, design = "taylor", seed = 13L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result <- get_means(d, y1, variance = NULL)
  expect_identical(names(result), c("mean", "n"))
})

# ---------------------------------------------------------------------------
# Category 4: n_weighted
# ---------------------------------------------------------------------------

test_that("get_means() n_weighted = TRUE adds n_weighted column", {
  df <- make_survey_data(n = 50L, design = "taylor", seed = 14L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result_no <- get_means(d, y1, variance = NULL)
  result_nw <- get_means(d, y1, variance = NULL, n_weighted = TRUE)

  expect_false("n_weighted" %in% names(result_no))
  expect_true("n_weighted" %in% names(result_nw))
  expect_gte(result_nw$n_weighted[[1L]], 0)
})

# ---------------------------------------------------------------------------
# Category 5: group= argument
# ---------------------------------------------------------------------------

test_that("get_means() group= produces one row per group level", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 2L,
                         design = "taylor", seed = 15L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  n_strata <- length(unique(df$strata))
  result   <- get_means(d, y1, group = strata)

  test_result_invariants(result, "survey_means")
  expect_equal(nrow(result), n_strata)
  expect_true("strata" %in% names(result))
  expect_true(all(is.finite(result$mean)))
  expect_identical(names(meta(result)$group), "strata")
})

test_that("get_means() group= with multiple group vars produces correct row count", {
  set.seed(1)
  df <- data.frame(
    g1  = rep(c("A", "B"), each = 50),
    g2  = rep(c("X", "Y"), 50),
    y   = rnorm(100),
    wt  = runif(100, 0.5, 2),
    psu = rep(1:20, 5)
  )
  d <- as_survey(df, ids = psu, weights = wt)

  result <- get_means(d, y, group = c(g1, g2))

  # 2 levels of g1 × 2 levels of g2 = 4 rows
  expect_equal(nrow(result), 4L)
  expect_true("g1" %in% names(result))
  expect_true("g2" %in% names(result))
})

# ---------------------------------------------------------------------------
# Category 6: na.rm
# ---------------------------------------------------------------------------

test_that("get_means() na.rm = TRUE excludes NAs from computation", {
  df <- make_survey_data(n = 100L, n_psu = 10L, design = "taylor", seed = 16L)
  df$y1[c(1, 5, 10)] <- NA_real_
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  result_rm  <- get_means(d, y1, variance = "se", na.rm = TRUE)
  result_nrm <- get_means(d, y1, variance = "se", na.rm = FALSE)

  expect_true(is.finite(result_rm$mean[[1L]]))
  expect_equal(result_rm$n[[1L]], 97L)   # 100 - 3 NAs
  expect_true(is.na(result_nrm$mean[[1L]]))
})

test_that("get_means() na.rm = FALSE returns NA when any x is NA", {
  df <- data.frame(y = c(1.0, 2.0, NA_real_), w = rep(1, 3))
  d  <- as_survey_srs(df, weights = w)
  result <- get_means(d, y, variance = NULL, na.rm = FALSE)
  expect_true(is.na(result$mean[[1L]]))
})

# ---------------------------------------------------------------------------
# Category 7: name_style = "broom"
# ---------------------------------------------------------------------------

test_that("get_means() name_style = 'broom' renames estimate columns", {
  df     <- make_survey_data(n = 50L, design = "taylor", seed = 17L)
  d      <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  result <- get_means(d, y1, variance = c("se", "ci"), name_style = "broom")

  expect_true("estimate"  %in% names(result))
  expect_true("std.error" %in% names(result))
  expect_true("conf.low"  %in% names(result))
  expect_true("conf.high" %in% names(result))
  expect_false("mean"     %in% names(result))
  expect_false("se"       %in% names(result))
})

# ---------------------------------------------------------------------------
# Category 8: min_cell_n warning
# ---------------------------------------------------------------------------

test_that("get_means() emits small-cell warning when n < min_cell_n", {
  # Use a group that produces a very small cell
  df <- data.frame(
    y     = c(rep(1.0, 5),  rep(2.0, 95)),
    g     = c(rep("tiny", 5), rep("big", 95)),
    w     = rep(1, 100),
    psu   = rep(1:20, 5)
  )
  d <- as_survey(df, ids = psu, weights = w)

  expect_warning(
    get_means(d, y, group = g, min_cell_n = 10L),
    class = "surveycore_warning_small_cell"
  )
})

# ---------------------------------------------------------------------------
# Category 9: Error paths
# ---------------------------------------------------------------------------

test_that("get_means() errors for non-survey-design object", {
  expect_error(
    get_means(data.frame(x = 1:5, y = rnorm(5)), y),
    class = "surveycore_error_unsupported_class"
  )
})

test_that("get_means() errors for non-numeric variable", {
  df <- data.frame(y = letters[1:10], w = rep(1, 10))
  d  <- as_survey_srs(df, weights = w)
  expect_error(
    get_means(d, y),
    class = "surveycore_error_non_numeric_variable"
  )
  expect_snapshot(error = TRUE, get_means(d, y))
})

test_that("get_means() errors when x resolves to zero variables", {
  df <- data.frame(y1 = 1:10, w = rep(1, 10))
  d  <- as_survey_srs(df, weights = w)
  # Select an empty set
  expect_error(
    get_means(d, starts_with("zzz")),
    class = "surveycore_error_wrong_variable_count"
  )
})

test_that("get_means() errors when x resolves to multiple variables", {
  df <- data.frame(y1 = 1:10, y2 = 1:10, w = rep(1, 10))
  d  <- as_survey_srs(df, weights = w)
  expect_error(
    get_means(d, starts_with("y")),
    class = "surveycore_error_wrong_variable_count"
  )
})

test_that("get_means() errors for invalid variance value", {
  df <- data.frame(y = 1:10, w = rep(1, 10))
  d  <- as_survey_srs(df, weights = w)
  expect_error(
    get_means(d, y, variance = "bogus"),
    class = "surveycore_error_invalid_variance_arg"
  )
  expect_snapshot(error = TRUE, get_means(d, y, variance = "bogus"))
})

test_that("get_means() errors for invalid conf_level", {
  df <- data.frame(y = 1:10, w = rep(1, 10))
  d  <- as_survey_srs(df, weights = w)
  expect_error(
    get_means(d, y, conf_level = 1.5),
    class = "surveycore_error_invalid_conf_level"
  )
})

# ---------------------------------------------------------------------------
# Category 10: n column and domain estimation
# ---------------------------------------------------------------------------

test_that("get_means() n column equals unweighted count of non-NA observations", {
  df <- data.frame(y = c(1:8, NA_real_, NA_real_), w = rep(1, 10))
  d  <- as_survey_srs(df, weights = w)
  result <- get_means(d, y, variance = NULL, na.rm = TRUE)
  expect_equal(result$n[[1L]], 8L)
})

test_that("get_means() domain SE is not smaller than physical subset SE (Taylor)", {
  # Domain estimation retains full cluster/strata structure → SE >= subset SE
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 2L,
                         design = "taylor", seed = 20L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  # Full design grouped by strata (domain estimation)
  result_domain <- get_means(d, y1, variance = "se", group = strata)
  se_domain     <- result_domain$se[[1L]]

  # Physical subset
  strata_levels <- sort(unique(df$strata))
  df_sub        <- df[df$strata == strata_levels[[1L]], ]
  d_sub         <- as_survey(df_sub, ids = psu, weights = wt, strata = strata,
                              nest = TRUE)
  result_sub    <- get_means(d_sub, y1, variance = "se")
  se_sub        <- result_sub$se[[1L]]

  expect_gte(se_domain, se_sub * 0.99)  # domain SE >= subset SE (allow tiny float gap)
})

# ---------------------------------------------------------------------------
# Category 11: conf_level argument
# ---------------------------------------------------------------------------

test_that("get_means() wider CI for higher conf_level", {
  df <- make_survey_data(n = 100L, n_psu = 10L, design = "taylor", seed = 21L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)

  r95 <- get_means(d, y1, variance = "ci", conf_level = 0.95)
  r99 <- get_means(d, y1, variance = "ci", conf_level = 0.99)

  width95 <- r95$ci_high[[1L]] - r95$ci_low[[1L]]
  width99 <- r99$ci_high[[1L]] - r99$ci_low[[1L]]
  expect_gt(width99, width95)
})

# ---------------------------------------------------------------------------
# Category 12: Oracle — NHANES Taylor design
# ---------------------------------------------------------------------------

test_that("get_means() Taylor point + SE + CI match survey::svymean() — NHANES [oracle]", {
  skip_if_not_installed("survey")

  d <- nhanes_2017[nhanes_2017$ridstatr == 2, ]
  sc <- as_survey(d, ids = sdmvpsu, strata = sdmvstra, weights = wtmec2yr,
                  nest = TRUE)
  sv <- survey::svydesign(ids = ~sdmvpsu, strata = ~sdmvstra,
                          weights = ~wtmec2yr, data = d, nest = TRUE)

  sc_est <- get_means(sc, bpxsy1, variance = c("se", "ci"))
  sv_est <- survey::svymean(~bpxsy1, sv, na.rm = TRUE)

  expect_equal(sc_est$mean[[1L]],    coef(sv_est)[["bpxsy1"]], tolerance = 1e-10)
  expect_equal(sc_est$se[[1L]],      as.numeric(survey::SE(sv_est)), tolerance = 1e-8)
  expect_equal(sc_est$ci_low[[1L]],  confint(sv_est)[1], tolerance = 1e-6)
  expect_equal(sc_est$ci_high[[1L]], confint(sv_est)[2], tolerance = 1e-6)
})

# ---------------------------------------------------------------------------
# Category 13: All designs via make_all_designs()
# ---------------------------------------------------------------------------

test_that("get_means() returns a finite estimate for all 5 design types", {
  designs <- make_all_designs(seed = 99L)
  for (nm in names(designs)) {
    d      <- designs[[nm]]
    result <- get_means(d, y1)
    test_result_invariants(result, "survey_means")
    expect_true(
      is.finite(result$mean[[1L]]),
      label = paste0("get_means() finite mean for design type: ", nm)
    )
  }
})

# ---------------------------------------------------------------------------
# Category 14: New meta structure & group label conversion
# ---------------------------------------------------------------------------

test_that("get_means() group column is <fct> when group var has haven labels", {
  df <- data.frame(
    y      = rnorm(100),
    gender = structure(c(1L, 2L, 1L, 2L)[rep(1:4, 25)],
                       labels = c(Male = 1L, Female = 2L)),
    w      = rep(1, 100)
  )
  d <- as_survey_srs(df, weights = w)

  result <- get_means(d, y, group = gender, variance = NULL)
  expect_true(is.factor(result$gender))
  expect_identical(levels(result$gender), c("Male", "Female"))
  expect_identical(as.character(result$gender), c("Male", "Female"))
})

test_that("get_means() group column is <fct> when group var is a plain R factor", {
  df <- data.frame(
    y   = rnorm(100),
    grp = factor(rep(c("B", "A"), 50), levels = c("B", "A")),
    w   = rep(1, 100)
  )
  d <- as_survey_srs(df, weights = w)

  result <- get_means(d, y, group = grp, variance = NULL)
  expect_true(is.factor(result$grp))
  expect_identical(levels(result$grp), c("B", "A"))
})

test_that("get_means() group column retains raw codes when label_values = FALSE", {
  df <- data.frame(
    y      = rnorm(100),
    gender = structure(c(1L, 2L)[rep(1:2, 50)],
                       labels = c(Male = 1L, Female = 2L)),
    w      = rep(1, 100)
  )
  d <- as_survey_srs(df, weights = w)

  result <- get_means(d, y, group = gender, variance = NULL, label_values = FALSE)
  expect_false(is.factor(result$gender))
  expect_true(is.integer(result$gender))
})

test_that("get_means() meta$group stores value_labels regardless of label_values", {
  df <- data.frame(
    y      = rnorm(100),
    gender = structure(c(1L, 2L)[rep(1:2, 50)],
                       labels = c(Male = 1L, Female = 2L)),
    w      = rep(1, 100)
  )
  d <- as_survey_srs(df, weights = w)

  r_true  <- get_means(d, y, group = gender, variance = NULL, label_values = TRUE)
  r_false <- get_means(d, y, group = gender, variance = NULL, label_values = FALSE)

  # .meta always stores labels regardless of label_values argument
  expect_equal(meta(r_true)$group$gender$value_labels,
               c(Male = 1L, Female = 2L))
  expect_equal(meta(r_false)$group$gender$value_labels,
               c(Male = 1L, Female = 2L))
})

test_that("get_means() group column name is always raw variable name (not label)", {
  df <- data.frame(y = rnorm(50), grp = rep(1:2, 25), w = rep(1, 50))
  d  <- as_survey_srs(df, weights = w)
  d  <- set_var_label(d, grp, "Group variable")

  result <- get_means(d, y, group = grp, variance = NULL, label_vars = TRUE)
  # Column is named "grp", not "Group variable"
  expect_true("grp" %in% names(result))
  expect_false("Group variable" %in% names(result))
})

test_that("get_means() meta$x has correct nested structure", {
  df <- data.frame(y = rnorm(50), w = rep(1, 50))
  d  <- as_survey_srs(df, weights = w)
  d  <- set_var_label(d, y, "Outcome variable")

  result <- get_means(d, y, variance = NULL)
  m      <- meta(result)

  expect_identical(names(m$x), "y")
  expect_identical(m$x$y$variable_label, "Outcome variable")
  expect_type(m$x$y, "list")
  expect_true(all(c("variable_label", "question_preface", "value_labels") %in%
                    names(m$x$y)))
})


# ── decimals argument ──────────────────────────────────────────────────────────

test_that("get_means() decimals=2 rounds all double columns", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 301L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_means(d, y1, variance = "ci", decimals = 2L)

  dbl_cols <- names(r)[vapply(r, is.double, logical(1L))]
  for (col in dbl_cols) {
    expect_equal(r[[col]], round(r[[col]], 2L),
                 label = paste0(col, " rounded to 2 decimals"))
  }
})

test_that("get_means() decimals=NULL applies no rounding", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 302L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r_none    <- get_means(d, y1, variance = "se", decimals = NULL)
  r_rounded <- get_means(d, y1, variance = "se", decimals = 0L)

  # Rounding to 0 places changes at least one value
  expect_false(identical(r_none$mean, r_rounded$mean))
})

test_that("get_means() rejects invalid decimals", {
  df <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 303L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)

  expect_error(
    get_means(d, y1, decimals = -1L),
    class = "surveycore_error_invalid_decimals"
  )
})
