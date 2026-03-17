# tests/testthat/test-analysis-diffs-helpers.R
#
# Tests for diffs infrastructure:
#   1. .stars_pval() — significance star helper
#   2. .apply_name_style(exclude) — exclude parameter
#   3. print.survey_diffs() — snapshot
#   4. DIFFS_META_KEYS constant


# -- Category 1: .stars_pval() ------------------------------------------------

test_that(".stars_pval() returns '***' for p < 0.001", {
  expect_identical(.stars_pval(0.0005), "***")
})

test_that(".stars_pval() returns '**' for p < 0.01", {
  expect_identical(.stars_pval(0.005), "**")
})

test_that(".stars_pval() returns '*' for p < 0.05", {
  expect_identical(.stars_pval(0.03), "*")
})

test_that(".stars_pval() returns '.' for p < 0.1", {
  expect_identical(.stars_pval(0.08), ".")
})

test_that(".stars_pval() returns '' for p >= 0.1", {
  expect_identical(.stars_pval(0.15), "")
})

test_that(".stars_pval() returns '' for NA p-values", {
  expect_identical(.stars_pval(NA_real_), "")
})

test_that(".stars_pval() boundary: p = 0.001 returns '**' (not '***')", {

  expect_identical(.stars_pval(0.001), "**")
})

test_that(".stars_pval() boundary: p = 0.01 returns '*' (not '**')", {
  expect_identical(.stars_pval(0.01), "*")
})

test_that(".stars_pval() boundary: p = 0.05 returns '.' (not '*')", {
  expect_identical(.stars_pval(0.05), ".")
})

test_that(".stars_pval() boundary: p = 0.1 returns '' (not '.')", {

  expect_identical(.stars_pval(0.1), "")
})

test_that(".stars_pval() handles vector input correctly", {
  p_vals <- c(0.0005, 0.005, 0.03, 0.08, 0.15, NA_real_)
  expected <- c("***", "**", "*", ".", "", "")
  expect_identical(.stars_pval(p_vals), expected)
})

test_that(".stars_pval() returns '' for p = 0", {
  expect_identical(.stars_pval(0), "***")
})

test_that(".stars_pval() returns '' for p = 1", {
  expect_identical(.stars_pval(1), "")
})


# -- Category 2: .apply_name_style(exclude) -----------------------------------

test_that('.apply_name_style() exclude = NULL preserves default behavior', {
  result <- structure(
    tibble::tibble(
      mean     = 10.0,
      se       = 1.0,
      ci_low   = 8.0,
      ci_high  = 12.0,
      n        = 100L
    ),
    .meta = list(design_type = "taylor"),
    class = c(
      "survey_means", "survey_result", "tbl_df", "tbl", "data.frame"
    )
  )
  out <- .apply_name_style(result, "broom", exclude = NULL)
  expect_true("estimate" %in% names(out))
  expect_true("std.error" %in% names(out))
  expect_true("conf.low" %in% names(out))
  expect_true("conf.high" %in% names(out))
  expect_false("mean" %in% names(out))
  expect_false("se" %in% names(out))
})

test_that('.apply_name_style() exclude = "mean" keeps mean, renames others', {
  result <- structure(
    tibble::tibble(
      mean     = 10.0,
      se       = 1.0,
      ci_low   = 8.0,
      ci_high  = 12.0,
      n        = 100L
    ),
    .meta = list(design_type = "taylor"),
    class = c(
      "survey_means", "survey_result", "tbl_df", "tbl", "data.frame"
    )
  )
  out <- .apply_name_style(result, "broom", exclude = "mean")
  expect_true("mean" %in% names(out))
  expect_false("estimate" %in% names(out))
  expect_true("std.error" %in% names(out))
  expect_true("conf.low" %in% names(out))
  expect_true("conf.high" %in% names(out))
})

test_that('.apply_name_style() exclude with surveycore style is no-op', {
  result <- structure(
    tibble::tibble(mean = 10.0, se = 1.0, n = 100L),
    .meta = list(design_type = "taylor"),
    class = c(
      "survey_means", "survey_result", "tbl_df", "tbl", "data.frame"
    )
  )
  out <- .apply_name_style(result, "surveycore", exclude = "mean")
  expect_identical(names(out), c("mean", "se", "n"))
})

test_that(".apply_name_style() exclude preserves .meta and class", {
  result <- structure(
    tibble::tibble(mean = 10.0, se = 1.0, n = 100L),
    .meta = list(design_type = "taylor", n_respondents = 100L),
    class = c(
      "survey_means", "survey_result", "tbl_df", "tbl", "data.frame"
    )
  )
  out <- .apply_name_style(result, "broom", exclude = "mean")
  expect_identical(attr(out, ".meta"), attr(result, ".meta"))
  expect_identical(class(out), class(result))
})


# -- Category 3: print.survey_diffs() -----------------------------------------

test_that("print.survey_diffs() renders expected header", {
  mock_diffs <- tibble::tibble(
    message_arm = factor(c("Control", "Msg A", "Msg B")),
    estimate    = c(0, 0.082, 0.103),
    mean        = c(0.401, 0.483, 0.504),
    n           = c(752L, 748L, 751L),
    ci_low      = c(NA, 0.042, 0.063),
    ci_high     = c(NA, 0.122, 0.143),
    p_value     = c(NA, 0.001, 0.000),
    stars       = c("", "**", "***")
  )
  attr(mock_diffs, ".meta") <- list(
    design_type     = "taylor",
    conf_level      = 0.95,
    call            = quote(get_diffs(d, agree_trope, message_arm)),
    n_respondents   = 2251L,
    group           = list(),
    x               = list(agree_trope = list(
      variable_label = "Agree with trope",
      question_preface = NULL,
      value_labels = NULL
    )),
    treats          = list(
      variable_label = "Message arm",
      question_preface = NULL,
      value_labels = NULL,
      name = "message_arm",
      ref_level = "Control"
    ),
    covariates      = NULL,
    family          = "gaussian",
    link            = "identity",
    pval_adj        = NULL,
    estimate_method = "coefficient",
    mean_method     = "intercept",
    estimate_scale  = "coefficient"
  )
  class(mock_diffs) <- c(
    "survey_diffs", "survey_result", "tbl_df", "tbl", "data.frame"
  )
  expect_snapshot(print(mock_diffs))
})

test_that("print.survey_diffs() shows replicate design type", {
  mock_diffs <- tibble::tibble(
    arm      = factor(c("Ctrl", "T1")),
    estimate = c(0, 0.05),
    mean     = c(0.5, 0.55),
    n        = c(100L, 100L)
  )
  attr(mock_diffs, ".meta") <- list(
    design_type     = "replicate",
    conf_level      = 0.95,
    call            = quote(get_diffs(d, y, arm)),
    n_respondents   = 200L,
    group           = list(),
    x               = list(y = list(
      variable_label = NULL, question_preface = NULL,
      value_labels = NULL
    )),
    treats          = list(
      variable_label = NULL, question_preface = NULL,
      value_labels = NULL, name = "arm", ref_level = "Ctrl"
    ),
    covariates      = NULL,
    family          = "gaussian",
    link            = "identity",
    pval_adj        = NULL,
    estimate_method = "coefficient",
    mean_method     = "intercept",
    estimate_scale  = "coefficient"
  )
  class(mock_diffs) <- c(
    "survey_diffs", "survey_result", "tbl_df", "tbl", "data.frame"
  )
  out <- capture.output(print(mock_diffs))
  expect_true(any(grepl("Replicate weights", out)))
})

test_that("print.survey_diffs() returns invisible(x)", {
  mock_diffs <- tibble::tibble(
    arm      = factor(c("Ctrl", "T1")),
    estimate = c(0, 0.05),
    mean     = c(0.5, 0.55),
    n        = c(100L, 100L)
  )
  attr(mock_diffs, ".meta") <- list(
    design_type     = "taylor",
    conf_level      = 0.95,
    call            = quote(get_diffs(d, y, arm)),
    n_respondents   = 200L,
    group           = list(),
    x               = list(y = list(
      variable_label = NULL, question_preface = NULL,
      value_labels = NULL
    )),
    treats          = list(
      variable_label = NULL, question_preface = NULL,
      value_labels = NULL, name = "arm", ref_level = "Ctrl"
    ),
    covariates      = NULL,
    family          = "gaussian",
    link            = "identity",
    pval_adj        = NULL,
    estimate_method = "coefficient",
    mean_method     = "intercept",
    estimate_scale  = "coefficient"
  )
  class(mock_diffs) <- c(
    "survey_diffs", "survey_result", "tbl_df", "tbl", "data.frame"
  )
  expect_invisible(print(mock_diffs))
})


# -- Category 4: DIFFS_META_KEYS constant -------------------------------------

test_that("DIFFS_META_KEYS contains all required keys", {
  expected <- c(
    "group", "x", "treats", "covariates", "family", "link",
    "pval_adj", "estimate_method", "mean_method", "estimate_scale"
  )
  expect_identical(DIFFS_META_KEYS, expected)
})
