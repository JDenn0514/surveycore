# tests/testthat/test-analysis-freqs.R
#
# Tests for get_freqs() — weighted frequency tables.
#
# Sections:
#   1. Happy path — single-variable mode
#   2. Happy path — multi-variable mode
#   3. Happy path — grouped mode
#   4. Variance argument and uncertainty columns
#   5. n_weighted argument
#   6. label_values and label_vars
#   7. name_style = "broom"
#   8. na.rm behavior
#   9. Error paths
#   10. Warning paths
#   11. Edge cases
#   12. Numerical oracle tests (survey package)
#   13. Cross-design type consistency


# ── 1. Happy path — single-variable mode ──────────────────────────────────────

test_that("get_freqs() returns a survey_freqs object for a Taylor design", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 11L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, group)

  test_result_invariants(r, "survey_freqs")
  expect_identical(names(r), c("group", "pct", "n"))
  expect_identical(r$group, c("A", "B", "C"))
  expect_equal(sum(r$pct), 1, tolerance = 1e-8)
  expect_true(all(r$n > 0L))
})

test_that("get_freqs() respects factor level order", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 12L)
  df$group_f <- factor(df$group, levels = c("C", "B", "A"))
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                 nest = TRUE)
  r <- get_freqs(d, group_f)

  test_result_invariants(r, "survey_freqs")
  # group_f column is now a factor with levels in declaration order
  expect_true(is.factor(r$group_f))
  expect_identical(as.character(r$group_f), c("C", "B", "A"))
  expect_identical(levels(r$group_f), c("C", "B", "A"))
})

test_that("get_freqs() sorts non-factor levels ascending", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 13L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, group)

  test_result_invariants(r, "survey_freqs")
  expect_identical(r$group, sort(unique(df$group)))
})

test_that("get_freqs() single-var meta has required keys", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 14L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, group)
  m  <- meta(r)

  expect_identical(names(m$x), "group")
  expect_type(m$group, "list")
  expect_length(m$group, 0L)
})

test_that("get_freqs() works for binary (0/1 integer) variable", {
  df <- make_survey_data(n = 300L, n_psu = 30L, n_strata = 3L, seed = 15L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, y3)

  test_result_invariants(r, "survey_freqs")
  expect_equal(nrow(r), 2L)
  expect_equal(sum(r$pct), 1, tolerance = 1e-8)
})


# ── 2. Happy path — multi-variable mode ───────────────────────────────────────

test_that("get_freqs() stacks rows in multi-variable mode", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 21L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, c(group, y3), names_to = "item", values_to = "response")

  test_result_invariants(r, "survey_freqs")
  expect_identical(names(r), c("item", "response", "pct", "n"))
  # group: 3 levels; y3: 2 levels; total = 5
  expect_equal(nrow(r), 5L)
  # Proportions within each variable sum to 1
  pct_group <- r$pct[r$item == "group"]
  pct_y3    <- r$pct[r$item == "y3"]
  expect_equal(sum(pct_group), 1, tolerance = 1e-8)
  expect_equal(sum(pct_y3),    1, tolerance = 1e-8)
})

test_that("get_freqs() multi-var meta has required keys", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 22L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, c(group, y3), names_to = "item", values_to = "resp")
  m  <- meta(r)

  expect_identical(names(m$x), c("group", "y3"))
  expect_type(m$x, "list")
  expect_length(m$x, 2L)
  # Each x entry has variable_label, question_preface, value_labels
  expect_true(all(c("variable_label", "question_preface", "value_labels") %in%
                    names(m$x$group)))
})

test_that("get_freqs() custom names_to and values_to are used", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 23L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, c(group, y3), names_to = "var_nm", values_to = "val_nm")

  expect_true("var_nm" %in% names(r))
  expect_true("val_nm" %in% names(r))
})


# ── 3. Happy path — grouped mode ──────────────────────────────────────────────

test_that("get_freqs() places group columns first", {
  df <- make_survey_data(n = 300L, n_psu = 30L, n_strata = 3L, seed = 31L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- suppressWarnings(get_freqs(d, group, group = strata))

  test_result_invariants(r, "survey_freqs")
  expect_identical(names(r)[[1L]], "strata")
  expect_identical(names(r)[[2L]], "group")
  # meta group
  expect_identical(names(meta(r)$group), "strata")
})

test_that("get_freqs() pct sums to 100 within each group combo", {
  df <- make_survey_data(n = 300L, n_psu = 30L, n_strata = 3L, seed = 32L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- suppressWarnings(get_freqs(d, group, group = strata))

  for (s in unique(r$strata)) {
    expect_equal(sum(r$pct[r$strata == s]), 1, tolerance = 1e-8,
                 label = paste0("pct sums to 1 in strata = ", s))
  }
})

test_that("get_freqs() grouped meta has group set correctly", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 33L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- suppressWarnings(get_freqs(d, group, group = strata))
  m  <- meta(r)

  expect_identical(names(m$group), "strata")
  expect_type(m$group, "list")
})


# ── 4. Variance argument and uncertainty columns ───────────────────────────────

test_that("get_freqs() variance=NULL produces no uncertainty columns", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 41L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, group)

  expect_false("se" %in% names(r))
  expect_false("ci_low" %in% names(r))
})

test_that("get_freqs() variance='se' adds only se column", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 42L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, group, variance = "se")

  expect_true("se" %in% names(r))
  expect_false("ci_low" %in% names(r))
  expect_true(all(r$se >= 0, na.rm = TRUE))
})

test_that("get_freqs() variance='ci' adds ci_low and ci_high", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 43L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, group, variance = "ci")

  expect_true("ci_low"  %in% names(r))
  expect_true("ci_high" %in% names(r))
  expect_true(all(r$ci_high >= r$ci_low, na.rm = TRUE))
  # n comes after ci_high
  expect_identical(names(r), c("group", "pct", "ci_low", "ci_high", "n"))
})

test_that("get_freqs() variance='deff' adds deff column", {
  df <- make_survey_data(n = 400L, n_psu = 40L, n_strata = 4L, seed = 44L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, group, variance = "deff")

  expect_true("deff" %in% names(r))
  expect_true(all(r$deff >= 0, na.rm = TRUE))
})

test_that("get_freqs() variance=c('ci','moe') adds both sets of columns", {
  df <- make_survey_data(n = 300L, n_psu = 30L, n_strata = 3L, seed = 45L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, group, variance = c("ci", "moe"))

  expect_true("ci_low"  %in% names(r))
  expect_true("ci_high" %in% names(r))
  expect_true("moe"     %in% names(r))
})

test_that("get_freqs() conf_level=0.99 widens CIs vs 0.95", {
  df  <- make_survey_data(n = 400L, n_psu = 40L, n_strata = 4L, seed = 46L)
  d   <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                   nest = TRUE)
  r95 <- get_freqs(d, group, variance = "ci", conf_level = 0.95)
  r99 <- get_freqs(d, group, variance = "ci", conf_level = 0.99)

  expect_true(all(r99$ci_high - r99$ci_low > r95$ci_high - r95$ci_low))
})


# ── 5. n_weighted argument ────────────────────────────────────────────────────

test_that("get_freqs() n_weighted=TRUE adds n_weighted as last column", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 51L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, group, n_weighted = TRUE)

  expect_true("n_weighted" %in% names(r))
  expect_identical(names(r)[[length(names(r))]], "n_weighted")
  expect_true(all(r$n_weighted > 0, na.rm = TRUE))
})

test_that("get_freqs() n_weighted=FALSE does not add n_weighted column", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 52L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, group, n_weighted = FALSE)

  expect_false("n_weighted" %in% names(r))
})


# ── 6. label_values and label_vars ────────────────────────────────────────────

test_that("get_freqs() applies haven value labels when label_values=TRUE", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L,
                         with_labels = TRUE, seed = 61L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, y3, label_values = TRUE)

  test_result_invariants(r, "survey_freqs")
  # y3 has labels c("No" = 0L, "Yes" = 1L)
  expect_true("No"  %in% r$y3)
  expect_true("Yes" %in% r$y3)
})

test_that("get_freqs() uses raw values when label_values=FALSE", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L,
                         with_labels = TRUE, seed = 62L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, y3, label_values = FALSE)

  expect_true("0" %in% r$y3 || 0L %in% r$y3)
  expect_false("No" %in% r$y3)
})

test_that("get_freqs() multi-var label_vars=TRUE uses variable labels in names_to", {
  df <- make_survey_data(n = 300L, n_psu = 30L, n_strata = 3L,
                         with_labels = TRUE, seed = 63L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, c(y3, group), names_to = "item", values_to = "response",
                  label_vars = TRUE)

  # y3 has label "Outcome variable 3 (binary, 0/1)"
  expect_true("Outcome variable 3 (binary, 0/1)" %in% r$item)
})

test_that("get_freqs() multi-var label_vars=FALSE uses raw variable names", {
  df <- make_survey_data(n = 300L, n_psu = 30L, n_strata = 3L,
                         with_labels = TRUE, seed = 64L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, c(y3, group), names_to = "item", values_to = "response",
                  label_vars = FALSE)

  expect_true("y3"    %in% r$item)
  expect_true("group" %in% r$item)
  expect_false("Outcome variable 3 (binary, 0/1)" %in% r$item)
})

test_that("get_freqs() label_vars falls back to raw name when no label set", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 65L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, c(group, y3), names_to = "item", values_to = "response",
                  label_vars = TRUE)

  # No labels set — raw names used
  expect_true("group" %in% r$item)
  expect_true("y3"    %in% r$item)
})


# ── 7. name_style = "broom" ───────────────────────────────────────────────────

test_that("get_freqs() name_style='broom' renames pct to estimate", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 71L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, group, variance = "se", name_style = "broom")

  expect_true("estimate"  %in% names(r))
  expect_true("std.error" %in% names(r))
  expect_false("pct" %in% names(r))
  expect_false("se"  %in% names(r))
})


# ── 8. na.rm behavior ─────────────────────────────────────────────────────────

test_that("get_freqs() na.rm=TRUE excludes NA from levels and denominator", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 81L)
  df$group[1:20] <- NA
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, group, na.rm = TRUE)

  test_result_invariants(r, "survey_freqs")
  # NA should not appear as a level
  expect_false(any(is.na(r$group)))
  # n sums to non-NA rows only
  expect_equal(sum(r$n), sum(!is.na(df$group)))
  # pct sums to 1
  expect_equal(sum(r$pct), 1, tolerance = 1e-8)
})

test_that("get_freqs() na.rm=FALSE adds NA as last level", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 82L)
  df$group[1:10] <- NA
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- suppressWarnings(get_freqs(d, group, na.rm = FALSE))

  test_result_invariants(r, "survey_freqs")
  # 4 rows: A, B, C, NA
  expect_equal(nrow(r), 4L)
  expect_true(any(is.na(r$group)))
  # NA row is last
  expect_true(is.na(r$group[[nrow(r)]]))
  # pct including NA sums to 1
  expect_equal(sum(r$pct), 1, tolerance = 1e-8)
})


# ── 9. Error paths ────────────────────────────────────────────────────────────

test_that("get_freqs() rejects non-survey-base objects", {
  expect_error(
    get_freqs(data.frame(x = 1:3, w = 1), x),
    class = "surveycore_error_unsupported_class"
  )
  expect_snapshot(
    error = TRUE,
    get_freqs(data.frame(x = 1:3, w = 1), x)
  )
})

test_that("get_freqs() rejects invalid variance argument", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 91L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)

  expect_error(
    get_freqs(d, group, variance = "bad_val"),
    class = "surveycore_error_invalid_variance_arg"
  )
  expect_snapshot(
    error = TRUE,
    get_freqs(d, group, variance = "bad_val")
  )
})

test_that("get_freqs() rejects invalid conf_level", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 92L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)

  expect_error(
    get_freqs(d, group, conf_level = 1.5),
    class = "surveycore_error_invalid_conf_level"
  )
  expect_snapshot(
    error = TRUE,
    get_freqs(d, group, conf_level = 1.5)
  )
})

test_that("get_freqs() rejects invalid name_style", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 93L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)

  expect_error(
    get_freqs(d, group, name_style = "tidyverse"),
    class = "surveycore_error_invalid_name_style"
  )
  expect_snapshot(
    error = TRUE,
    get_freqs(d, group, name_style = "tidyverse")
  )
})

test_that("get_freqs() throws surveycore_error_all_na when na.rm=FALSE and all-NA", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 94L)
  df$group_all_na <- NA_character_
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)

  expect_error(
    get_freqs(d, group_all_na, na.rm = FALSE),
    class = "surveycore_error_all_na"
  )
  expect_snapshot(
    error = TRUE,
    get_freqs(d, group_all_na, na.rm = FALSE)
  )
})


# ── 10. Warning paths ─────────────────────────────────────────────────────────

test_that("get_freqs() warns surveycore_warning_small_cell when n < min_cell_n", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 101L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)

  # Group by strata forces small cell counts
  expect_warning(
    get_freqs(d, group, group = strata),
    class = "surveycore_warning_small_cell"
  )
})

test_that("get_freqs() warns surveycore_warning_single_level for 1-level group", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 102L)
  # Set strata to a single value — single-level grouping variable
  df$single_grp <- "only_level"
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)

  expect_warning(
    get_freqs(d, group, group = single_grp),
    class = "surveycore_warning_single_level"
  )
})

test_that("get_freqs() warns surveycore_warning_all_na_freqs when na.rm=TRUE and all-NA", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 103L)
  df$group_all_na <- NA_character_
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)

  expect_warning(
    get_freqs(d, group_all_na, na.rm = TRUE),
    class = "surveycore_warning_all_na_freqs"
  )
})

test_that("get_freqs() warns surveycore_warning_all_na_freqs returns 0-row result", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 104L)
  df$group_all_na <- NA_character_
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)

  expect_warning(
    result <- get_freqs(d, group_all_na, na.rm = TRUE),
    class = "surveycore_warning_all_na_freqs"
  )
  expect_equal(nrow(result), 0L)
})

test_that("get_freqs() warns surveycore_warning_mixed_prefaces for multi-var with different prefaces", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 105L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  # Set different non-NULL question prefaces
  d  <- set_question_preface(d, group, "First section preface")
  d  <- set_question_preface(d, y3,    "Second section preface")

  expect_warning(
    get_freqs(d, c(group, y3), names_to = "item", values_to = "resp"),
    class = "surveycore_warning_mixed_prefaces"
  )
})


# ── 11. Edge cases ─────────────────────────────────────────────────────────────

test_that("get_freqs() single-level variable returns 1 row with pct=100", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 111L)
  df$constant_var <- "only"
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, constant_var)

  test_result_invariants(r, "survey_freqs")
  expect_equal(nrow(r), 1L)
  expect_equal(r$pct[[1L]], 1, tolerance = 1e-8)
})

test_that("get_freqs() min_cell_n=0 suppresses small-cell warnings", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 112L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)

  expect_no_warning(
    get_freqs(d, group, group = strata, min_cell_n = 0L)
  )
})

test_that("get_freqs() factor variable with empty levels drops empty levels", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 113L)
  # 4-level factor but data only has A, B, C
  df$group_f <- factor(df$group, levels = c("A", "B", "C", "D"))
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, group_f)

  test_result_invariants(r, "survey_freqs")
  # "D" has no data — should not appear in output
  expect_equal(nrow(r), 3L)
  expect_false("D" %in% r$group_f)
})

test_that("get_freqs() n column counts unweighted respondents (not weighted)", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 114L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, group)

  expect_equal(sum(r$n), nrow(df))
  expect_identical(class(r$n)[[1L]], "integer")
})

test_that("get_freqs() replicate design produces correct row count", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L,
                         design = "replicate", type = "brr", seed = 115L)
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  d  <- as_survey_rep(df, weights = wt,
                      repweights = tidyselect::all_of(repwt_cols), type = "BRR")
  r  <- get_freqs(d, group)

  test_result_invariants(r, "survey_freqs")
  expect_equal(nrow(r), 3L)
  expect_equal(sum(r$pct), 1, tolerance = 1e-8)
})

test_that("get_freqs() two-phase design returns valid result", {
  df   <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L,
                           design = "twophase", seed = 116L)
  ph1  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                    nest = TRUE)
  twop <- as_survey_twophase(ph1, subset = subset, method = "approx")
  r    <- suppressWarnings(get_freqs(twop, group))

  test_result_invariants(r, "survey_freqs")
  expect_equal(nrow(r), 3L)
  expect_equal(sum(r$pct), 1, tolerance = 1e-8)
})

test_that("get_freqs() na.rm=FALSE NA row is last", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 117L)
  df$group[c(5L, 20L, 40L)] <- NA
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- suppressWarnings(get_freqs(d, group, na.rm = FALSE))

  expect_true(is.na(r$group[[nrow(r)]]))
  expect_false(is.na(r$group[[1L]]))
})

test_that("get_freqs() na.rm=FALSE factor variable: NA row after factor levels", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 118L)
  df$group[1:5] <- NA
  df$group_f    <- factor(df$group, levels = c("C", "B", "A"))
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                 nest = TRUE)
  r <- suppressWarnings(get_freqs(d, group_f, na.rm = FALSE))

  # Factor order: C, B, A, then NA last
  expect_identical(as.character(r$group_f[!is.na(r$group_f)]), c("C", "B", "A"))
  expect_true(is.na(r$group_f[[nrow(r)]]))
})

test_that("get_freqs() survey_calibrated design returns valid result", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 119L)
  d  <- as_survey_calibrated(df, weights = wt)
  r  <- get_freqs(d, group)

  test_result_invariants(r, "survey_freqs")
  expect_equal(nrow(r), 3L)
  expect_equal(sum(r$pct), 1, tolerance = 1e-8)
})


# ── 12. Numerical oracle tests (survey package) ────────────────────────────────

test_that("get_freqs() Taylor pct matches survey::svymean on indicator [numerical]", {
  skip_if_not_installed("survey")

  df <- make_survey_data(n = 500L, n_psu = 50L, n_strata = 5L,
                         design = "taylor", seed = 121L)
  df$ind_A <- as.integer(df$group == "A")
  df$ind_B <- as.integer(df$group == "B")
  df$ind_C <- as.integer(df$group == "C")

  d_sc <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                    nest = TRUE)
  d_sv <- survey::svydesign(ids = ~psu, weights = ~wt, strata = ~strata,
                             fpc = ~fpc, data = df, nest = TRUE)

  r_sc <- get_freqs(d_sc, group, variance = "se")

  sv_A <- survey::svymean(~ind_A, d_sv)
  sv_B <- survey::svymean(~ind_B, d_sv)
  sv_C <- survey::svymean(~ind_C, d_sv)

  expect_equal(r_sc$pct[r_sc$group == "A"],
               as.numeric(coef(sv_A)), tolerance = 1e-10)
  expect_equal(r_sc$pct[r_sc$group == "B"],
               as.numeric(coef(sv_B)), tolerance = 1e-10)
  expect_equal(r_sc$pct[r_sc$group == "C"],
               as.numeric(coef(sv_C)), tolerance = 1e-10)
  expect_equal(r_sc$se[r_sc$group == "A"],
               as.numeric(survey::SE(sv_A)), tolerance = 1e-8)
  expect_equal(r_sc$se[r_sc$group == "B"],
               as.numeric(survey::SE(sv_B)), tolerance = 1e-8)
  expect_equal(r_sc$se[r_sc$group == "C"],
               as.numeric(survey::SE(sv_C)), tolerance = 1e-8)
})

test_that("get_freqs() replicate (BRR) pct matches survey::svymean [numerical]", {
  skip_if_not_installed("survey")

  df <- make_survey_data(n = 500L, n_psu = 50L, n_strata = 5L,
                         design = "replicate", type = "brr", seed = 122L)
  repwt_cols <- grep("^repwt_", names(df), value = TRUE)
  df$ind_A <- as.integer(df$group == "A")
  df$ind_B <- as.integer(df$group == "B")

  d_sc <- as_survey_rep(df, weights = wt,
                        repweights = tidyselect::all_of(repwt_cols),
                        type = "BRR", mse = TRUE)
  # mse = TRUE to match as_survey_rep default (survey package default is FALSE)
  d_sv <- survey::svrepdesign(
    weights    = ~wt,
    repweights = df[, repwt_cols, drop = FALSE],
    type       = "BRR",
    mse        = TRUE,
    data       = df
  )

  r_sc <- get_freqs(d_sc, group, variance = "se")
  sv_A <- survey::svymean(~ind_A, d_sv)
  sv_B <- survey::svymean(~ind_B, d_sv)

  expect_equal(r_sc$pct[r_sc$group == "A"],
               as.numeric(coef(sv_A)), tolerance = 1e-10)
  expect_equal(r_sc$pct[r_sc$group == "B"],
               as.numeric(coef(sv_B)), tolerance = 1e-10)
  expect_equal(r_sc$se[r_sc$group == "A"],
               as.numeric(survey::SE(sv_A)), tolerance = 1e-8)
  expect_equal(r_sc$se[r_sc$group == "B"],
               as.numeric(survey::SE(sv_B)), tolerance = 1e-8)
})

test_that("get_freqs() pct sums to 1 for all design types [oracle sanity]", {
  skip_if_not_installed("survey")

  designs <- make_all_designs(seed = 123L)
  for (nm in names(designs)) {
    r <- suppressWarnings(get_freqs(designs[[nm]], group))
    expect_equal(sum(r$pct), 1, tolerance = 1e-8,
                 label = paste0("pct sums to 1 for design = ", nm))
  }
})


# ── 13. Cross-design type consistency ─────────────────────────────────────────

test_that("get_freqs() returns consistent column structure across design types", {
  designs <- make_all_designs(seed = 131L)
  for (nm in names(designs)) {
    r <- suppressWarnings(get_freqs(designs[[nm]], group, variance = "se"))
    expect_identical(
      names(r), c("group", "pct", "se", "n"),
      label = paste0("column names consistent for design = ", nm)
    )
    expect_equal(nrow(r), 3L,
                 label = paste0("3 rows (A, B, C) for design = ", nm))
  }
})

test_that("get_freqs() column types are consistent across design types", {
  designs <- make_all_designs(seed = 132L)
  for (nm in names(designs)) {
    r <- suppressWarnings(get_freqs(designs[[nm]], group))
    expect_type(r$group, "character")
    expect_type(r$pct, "double")
    expect_type(r$n, "integer")
  }
})

# ---------------------------------------------------------------------------
# New meta structure & label/factor column tests
# ---------------------------------------------------------------------------

test_that("get_freqs() group column is <fct> when group var has haven labels", {
  df <- data.frame(
    x      = sample(1:3, 100, replace = TRUE),
    gender = structure(c(1L, 2L)[rep(1:2, 50)],
                       labels = c(Male = 1L, Female = 2L)),
    w      = rep(1, 100)
  )
  d <- as_survey_srs(df, weights = w)

  r <- get_freqs(d, x, group = gender)
  expect_true(is.factor(r$gender))
  expect_identical(levels(r$gender), c("Male", "Female"))
})

test_that("get_freqs() group column retains raw codes when label_values = FALSE", {
  df <- data.frame(
    x      = sample(1:3, 100, replace = TRUE),
    gender = structure(c(1L, 2L)[rep(1:2, 50)],
                       labels = c(Male = 1L, Female = 2L)),
    w      = rep(1, 100)
  )
  d <- as_survey_srs(df, weights = w)

  r <- get_freqs(d, x, group = gender, label_values = FALSE)
  expect_false(is.factor(r$gender))
})

test_that("get_freqs() value column is <fct> when label_values = TRUE and labels exist", {
  df <- data.frame(
    x = structure(c(1L, 2L)[rep(1:2, 50)],
                  labels = c(Yes = 1L, No = 2L)),
    w = rep(1, 100)
  )
  d <- as_survey_srs(df, weights = w)

  r <- get_freqs(d, x, label_values = TRUE)
  expect_true(is.factor(r$x))
  expect_identical(levels(r$x), c("Yes", "No"))
})

test_that("get_freqs() name column is <fct> with levels in supply order (multi-var)", {
  df <- data.frame(
    a = sample(1:2, 100, replace = TRUE),
    b = sample(1:2, 100, replace = TRUE),
    c = sample(1:2, 100, replace = TRUE),
    w = rep(1, 100)
  )
  d <- as_survey_srs(df, weights = w)

  r <- get_freqs(d, c(c, a, b), names_to = "var", label_vars = FALSE)
  expect_true(is.factor(r$var))
  expect_identical(levels(r$var), c("c", "a", "b"))
})

test_that("get_freqs() meta$x stores value_labels regardless of label_values", {
  df <- data.frame(
    x = structure(c(1L, 2L)[rep(1:2, 50)],
                  labels = c(Yes = 1L, No = 2L)),
    w = rep(1, 100)
  )
  d <- as_survey_srs(df, weights = w)

  r_true  <- get_freqs(d, x, label_values = TRUE)
  r_false <- get_freqs(d, x, label_values = FALSE)

  expect_equal(meta(r_true)$x$x$value_labels,  c(Yes = 1L, No = 2L))
  expect_equal(meta(r_false)$x$x$value_labels, c(Yes = 1L, No = 2L))
})

test_that("get_freqs() meta$group always present (empty list when no groups)", {
  df <- data.frame(x = 1:3, w = rep(1, 3))
  d  <- as_survey_srs(df, weights = w)
  r  <- get_freqs(d, x)
  expect_type(meta(r)$group, "list")
  expect_length(meta(r)$group, 0L)
})


# ── decimals argument ──────────────────────────────────────────────────────────

test_that("get_freqs() decimals=2 rounds all double columns", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 201L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, group, variance = "ci", decimals = 2L)

  # All double columns should have at most 2 decimal places
  dbl_cols <- names(r)[vapply(r, is.double, logical(1L))]
  for (col in dbl_cols) {
    expect_equal(r[[col]], round(r[[col]], 2L),
                 label = paste0(col, " rounded to 2 decimals"))
  }
  # integer n column must not be rounded
  expect_identical(class(r$n)[[1L]], "integer")
})

test_that("get_freqs() decimals=NULL applies no rounding", {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 202L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r_none    <- get_freqs(d, group, variance = "se", decimals = NULL)
  r_rounded <- get_freqs(d, group, variance = "se", decimals = 4L)

  # At least one pct value should differ (more precision without rounding)
  expect_false(identical(r_none$pct, r_rounded$pct))
})

test_that("get_freqs() decimals preserves .meta and S3 class", {
  df <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 203L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)
  r  <- get_freqs(d, group, decimals = 2L)

  expect_true("survey_freqs" %in% class(r))
  expect_false(is.null(attr(r, ".meta")))
})

test_that("get_freqs() rejects negative decimals", {
  df <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 204L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)

  expect_error(
    get_freqs(d, group, decimals = -1L),
    class = "surveycore_error_invalid_decimals"
  )
  expect_snapshot(
    error = TRUE,
    get_freqs(d, group, decimals = -1L)
  )
})

test_that("get_freqs() rejects non-integer decimals", {
  df <- make_survey_data(n = 100L, n_psu = 10L, n_strata = 2L, seed = 205L)
  d  <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc,
                  nest = TRUE)

  expect_error(
    get_freqs(d, group, decimals = 1.5),
    class = "surveycore_error_invalid_decimals"
  )
})
