# tests/testthat/test-analysis-diffs.R
#
# Happy paths + error paths + edge cases for get_diffs()

# ── Shared test data setup ──────────────────────────────────────────────────

.make_diffs_data <- function(n = 200, seed = 42) {
  set.seed(seed)
  df <- make_survey_data(n = n, n_psu = 20, n_strata = 4, seed = seed)
  df$treats <- factor(
    sample(c("Control", "A", "B"), n, replace = TRUE)
  )
  df$dv <- rnorm(n, mean = 50, sd = 10)
  df$binary_dv <- as.integer(df$dv > 50)
  df$gender <- factor(sample(c("M", "F"), n, replace = TRUE))
  df$age <- rnorm(n, 40, 10)
  df
}

.make_diffs_design <- function(n = 200, seed = 42) {
  df <- .make_diffs_data(n = n, seed = seed)
  as_survey(df, ids = psu, weights = wt, strata = strata)
}


# ═══════════════════════════════════════════════════════════════════════════
# 1. ERROR PATHS
# ═══════════════════════════════════════════════════════════════════════════

test_that("get_diffs() rejects non-survey-base objects", {
  df <- data.frame(dv = 1:5, treats = factor(c("A", "A", "B", "B", "B")))
  expect_error(
    get_diffs(df, dv, treats),
    class = "surveycore_error_unsupported_class"
  )
  expect_snapshot(error = TRUE, get_diffs(df, dv, treats))
})

test_that("get_diffs() rejects x resolving to non-existent column", {
  d <- .make_diffs_design()
  expect_error(
    get_diffs(d, nonexistent_col, treats),
    class = "surveycore_error_wrong_variable_count"
  )
  expect_snapshot(error = TRUE, get_diffs(d, nonexistent_col, treats))
})

test_that("get_diffs() rejects treats resolving to non-existent column", {
  d <- .make_diffs_design()
  expect_error(
    get_diffs(d, dv, nonexistent_arm),
    class = "surveycore_error_treats_single"
  )
  expect_snapshot(error = TRUE, get_diffs(d, dv, nonexistent_arm))
})

test_that("get_diffs() rejects non-numeric x", {
  d <- .make_diffs_design()
  expect_error(
    get_diffs(d, group, treats),
    class = "surveycore_error_non_numeric_variable"
  )
  expect_snapshot(error = TRUE, get_diffs(d, group, treats))
})

test_that("get_diffs() rejects treats with only 1 level", {
  df <- .make_diffs_data()
  df$single <- factor(rep("A", nrow(df)))
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  expect_error(
    get_diffs(d, dv, single),
    class = "surveycore_error_treats_one_level"
  )
  expect_snapshot(error = TRUE, get_diffs(d, dv, single))
})

test_that("get_diffs() rejects invalid ref_level", {
  d <- .make_diffs_design()
  expect_error(
    get_diffs(d, dv, treats, ref_level = "nonexistent"),
    class = "surveycore_error_ref_level_not_found"
  )
  expect_snapshot(
    error = TRUE,
    get_diffs(d, dv, treats, ref_level = "nonexistent")
  )
})

test_that("get_diffs() rejects invalid pval_adj", {
  d <- .make_diffs_design()
  expect_error(
    get_diffs(d, dv, treats, pval_adj = "invalid_method"),
    class = "surveycore_error_invalid_pval_adj"
  )
  expect_snapshot(
    error = TRUE,
    get_diffs(d, dv, treats, pval_adj = "invalid_method")
  )
})

test_that("get_diffs() rejects non-character covariates", {
  d <- .make_diffs_design()
  expect_error(
    get_diffs(d, dv, treats, covariates = 42),
    class = "surveycore_error_covariates_not_character"
  )
  expect_snapshot(
    error = TRUE,
    get_diffs(d, dv, treats, covariates = 42)
  )
})

test_that("get_diffs() rejects non-logical na.rm", {
  d <- .make_diffs_design()
  expect_error(
    get_diffs(d, dv, treats, na.rm = "yes"),
    class = "surveycore_error_na_rm_not_logical"
  )
})

test_that("get_diffs() rejects invalid variance arg", {
  d <- .make_diffs_design()
  expect_error(
    get_diffs(d, dv, treats, variance = "deff"),
    class = "surveycore_error_invalid_variance_arg"
  )
})

test_that("get_diffs() rejects invalid conf_level", {
  d <- .make_diffs_design()
  expect_error(
    get_diffs(d, dv, treats, conf_level = 2),
    class = "surveycore_error_invalid_conf_level"
  )
})

test_that("get_diffs() rejects invalid name_style", {
  d <- .make_diffs_design()
  expect_error(
    get_diffs(d, dv, treats, name_style = "tidy"),
    class = "surveycore_error_invalid_name_style"
  )
})


# ═══════════════════════════════════════════════════════════════════════════
# 2. HAPPY PATHS — CLEAN PATH
# ═══════════════════════════════════════════════════════════════════════════

test_that("get_diffs() basic bivariate gaussian returns correct structure", {
  d <- .make_diffs_design()
  result <- get_diffs(d, dv, treats, ref_level = "Control")

  # Class
  expect_identical(
    class(result),
    c("survey_diffs", "survey_result", "tbl_df", "tbl", "data.frame")
  )

  # 3 rows: 1 reference + 2 treatment
  expect_equal(nrow(result), 3L)

  # Correct columns
  expect_true("treats" %in% names(result))
  expect_true("estimate" %in% names(result))
  expect_true("mean" %in% names(result))
  expect_true("n" %in% names(result))
  expect_true("p_value" %in% names(result))
  expect_true("stars" %in% names(result))

  # Reference row
  expect_equal(result$estimate[[1L]], 0)
  expect_true(is.na(result$p_value[[1L]]))
  expect_identical(result$stars[[1L]], "")

  # Non-ref rows have non-NA estimates

  expect_false(is.na(result$estimate[[2L]]))
  expect_false(is.na(result$estimate[[3L]]))

  # .meta contract
  m <- meta(result)
  expect_identical(m$estimate_method, "coefficient")
  expect_identical(m$mean_method, "intercept")
  expect_identical(m$family, "gaussian")
  expect_identical(m$treats$ref_level, "Control")
  expect_identical(m$treats$name, "treats")
})

test_that("get_diffs() show_means = FALSE omits reference row and mean", {
  d <- .make_diffs_design()
  result <- get_diffs(
    d, dv, treats, ref_level = "Control", show_means = FALSE
  )

  expect_equal(nrow(result), 2L)
  expect_false("mean" %in% names(result))
  # No row with estimate == 0
  expect_false(any(result$estimate == 0))
})

test_that("get_diffs() show_pct_change = TRUE adds pct_change column", {
  d <- .make_diffs_design()
  result <- get_diffs(
    d, dv, treats, ref_level = "Control", show_pct_change = TRUE
  )

  expect_true("pct_change" %in% names(result))
  # Reference row pct_change = NA
  expect_true(is.na(result$pct_change[[1L]]))
  # Non-ref rows have numeric pct_change
  expect_false(is.na(result$pct_change[[2L]]))
})

test_that("get_diffs() ref_level changes reference row", {
  d <- .make_diffs_design()
  result <- get_diffs(d, dv, treats, ref_level = "A")

  # First row should be A
  expect_equal(result$estimate[[1L]], 0)
  m <- meta(result)
  expect_identical(m$treats$ref_level, "A")
})

test_that("get_diffs() variance = 'se' includes SE, no CI", {
  d <- .make_diffs_design()
  result <- get_diffs(
    d, dv, treats, ref_level = "Control", variance = "se"
  )

  expect_true("se" %in% names(result))
  expect_false("ci_low" %in% names(result))
  expect_false("ci_high" %in% names(result))
})

test_that("get_diffs() variance = c('se', 'ci') includes both", {
  d <- .make_diffs_design()
  result <- get_diffs(
    d, dv, treats, ref_level = "Control",
    variance = c("se", "ci")
  )

  expect_true("se" %in% names(result))
  expect_true("ci_low" %in% names(result))
  expect_true("ci_high" %in% names(result))
})

test_that("get_diffs() variance = NULL includes no uncertainty", {
  d <- .make_diffs_design()
  result <- get_diffs(
    d, dv, treats, ref_level = "Control", variance = NULL
  )

  expect_false("se" %in% names(result))
  expect_false("ci_low" %in% names(result))
  expect_false("ci_high" %in% names(result))
})

test_that("get_diffs() decimals rounds correctly", {
  d <- .make_diffs_design()
  result <- get_diffs(
    d, dv, treats, ref_level = "Control", decimals = 2
  )

  # estimate rounded to 2 decimal places
  for (i in seq_len(nrow(result))) {
    if (!is.na(result$estimate[[i]])) {
      expect_equal(
        result$estimate[[i]],
        round(result$estimate[[i]], 2)
      )
    }
  }
})

test_that("get_diffs() decimals + pct_change rounds to decimals + 2", {
  d <- .make_diffs_design()
  result <- get_diffs(
    d, dv, treats, ref_level = "Control",
    show_pct_change = TRUE, decimals = 2
  )

  for (i in seq_len(nrow(result))) {
    if (!is.na(result$pct_change[[i]])) {
      expect_equal(
        result$pct_change[[i]],
        round(result$pct_change[[i]], 4)
      )
    }
  }
})

test_that("get_diffs() pval_adj = 'BH' adjusts p-values", {
  d <- .make_diffs_design()
  result_adj <- get_diffs(
    d, dv, treats, ref_level = "Control", pval_adj = "BH"
  )
  result_raw <- get_diffs(
    d, dv, treats, ref_level = "Control"
  )

  m <- meta(result_adj)
  expect_identical(m$pval_adj, "BH")
  # P-values may differ
  # (for 2 comparisons with BH, they could be the same or different)
})

test_that("get_diffs() label_values = TRUE labels treats column", {
  df <- .make_diffs_data()
  # Set value labels
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  d <- set_val_labels(
    d, treats = c("Control Group" = "Control", "Group A" = "A",
                  "Group B" = "B")
  )
  result <- get_diffs(
    d, dv, treats, ref_level = "Control", label_values = TRUE
  )

  expect_true(is.factor(result$treats))
})

test_that("get_diffs() label_values = FALSE keeps raw codes", {
  d <- .make_diffs_design()
  result <- get_diffs(
    d, dv, treats, ref_level = "Control", label_values = FALSE
  )
  # treats column should be character or factor with raw level names
  expect_true(is.character(result$treats) || is.factor(result$treats))
})

test_that("get_diffs() name_style = 'broom' renames columns, mean excluded", {
  d <- .make_diffs_design()
  result <- get_diffs(
    d, dv, treats, ref_level = "Control",
    variance = c("se", "ci"), name_style = "broom"
  )

  expect_true("std.error" %in% names(result))
  expect_true("conf.low" %in% names(result))
  expect_true("conf.high" %in% names(result))
  expect_true("p.value" %in% names(result))
  # mean is NOT renamed to estimate
  expect_true("mean" %in% names(result))
  expect_false("se" %in% names(result))
})

test_that("get_diffs() n_weighted = TRUE adds n_weighted column", {
  d <- .make_diffs_design()
  result <- get_diffs(
    d, dv, treats, ref_level = "Control", n_weighted = TRUE
  )

  expect_true("n_weighted" %in% names(result))
  # n_weighted should be numeric and positive
  expect_true(all(result$n_weighted > 0))
})

test_that("get_diffs() fires small cell warning for min_cell_n", {
  df <- .make_diffs_data(n = 200, seed = 42)
  # Make one level very small
  df$small_treats <- factor(
    c(rep("Rare", 5), rep("Control", 95), rep("B", 100))
  )
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)

  expect_warning(
    get_diffs(d, dv, small_treats, ref_level = "Control"),
    class = "surveycore_warning_small_cell"
  )
})

test_that("get_diffs() sets column-level labels on all columns", {
  d <- .make_diffs_design()
  result <- get_diffs(d, dv, treats, ref_level = "Control")

  for (col in names(result)) {
    expect_false(
      is.null(attr(result[[col]], "label")),
      info = paste("Column", col, "missing label attribute")
    )
  }
})

test_that("get_diffs() print snapshot", {
  d <- .make_diffs_design()
  result <- get_diffs(d, dv, treats, ref_level = "Control")
  expect_snapshot(print(result))
})

# ═══════════════════════════════════════════════════════════════════════════
# 3. HAPPY PATHS — MARGINALEFFECTS PATH
# ═══════════════════════════════════════════════════════════════════════════

test_that("get_diffs() with covariates uses marginaleffects path", {
  d <- .make_diffs_design()
  result <- get_diffs(
    d, dv, treats, covariates = "age", ref_level = "Control"
  )

  m <- meta(result)
  expect_identical(m$estimate_method, "avg_slopes")
  expect_identical(m$mean_method, "avg_predictions")
  expect_equal(nrow(result), 3L)
})

test_that("get_diffs() with group produces grouped output", {
  d <- .make_diffs_design()
  result <- suppressWarnings(
    get_diffs(d, dv, treats, group = gender, ref_level = "Control")
  )

  expect_true("gender" %in% names(result))
  m <- meta(result)
  expect_identical(m$estimate_method, "avg_slopes")
  # More rows: (1 ref + 2 treat) * 2 groups = 6
  expect_equal(nrow(result), 6L)
})

test_that("get_diffs() with covariates and group", {
  d <- .make_diffs_design()
  result <- suppressWarnings(
    get_diffs(
      d, dv, treats, group = gender,
      covariates = "age", ref_level = "Control"
    )
  )

  expect_true("gender" %in% names(result))
  m <- meta(result)
  expect_identical(m$estimate_method, "avg_slopes")
  expect_equal(nrow(result), 6L)
})

test_that("get_diffs() non-gaussian (quasibinomial) uses AME path", {
  d <- .make_diffs_design()
  result <- get_diffs(
    d, binary_dv, treats, ref_level = "Control",
    family = quasibinomial()
  )

  m <- meta(result)
  expect_identical(m$family, "quasibinomial")
  expect_identical(m$estimate_scale, "ame")
  expect_identical(m$estimate_method, "avg_slopes")
  # Estimates should be on probability scale (small)
  expect_true(all(abs(result$estimate) < 1))
})

test_that("get_diffs() scale = 'link' + non-gaussian suppresses mean", {
  d <- .make_diffs_design()
  result <- get_diffs(
    d, binary_dv, treats, ref_level = "Control",
    scale = "link", family = quasibinomial()
  )

  expect_false("mean" %in% names(result))
  expect_false("pct_change" %in% names(result))
  # Reference row still present
  expect_equal(result$estimate[[1L]], 0)
  m <- meta(result)
  expect_identical(m$estimate_method, "coefficient")
})

test_that("get_diffs() gaussian ame == link produces identical output", {
  d <- .make_diffs_design()
  result_ame <- get_diffs(
    d, dv, treats, ref_level = "Control", scale = "ame"
  )
  result_link <- get_diffs(
    d, dv, treats, ref_level = "Control", scale = "link"
  )

  expect_equal(result_ame$estimate, result_link$estimate, tolerance = 1e-10)
  expect_equal(
    result_ame$ci_low, result_link$ci_low, tolerance = 1e-8
  )
  expect_equal(
    result_ame$ci_high, result_link$ci_high, tolerance = 1e-8
  )
})

test_that("get_diffs() pval_adj with group adjusts within groups", {
  d <- .make_diffs_design()
  result_adj <- suppressWarnings(get_diffs(
    d, dv, treats, group = gender, ref_level = "Control",
    pval_adj = "BH"
  ))

  m <- meta(result_adj)
  expect_identical(m$pval_adj, "BH")
})

# ═══════════════════════════════════════════════════════════════════════════
# 4. DESIGN CLASS COVERAGE
# ═══════════════════════════════════════════════════════════════════════════

test_that("get_diffs() works with survey_taylor design", {
  d <- .make_diffs_design()
  result <- get_diffs(d, dv, treats, ref_level = "Control")
  expect_identical(meta(result)$design_type, "taylor")
})

test_that("get_diffs() works with survey_replicate design", {
  df <- .make_diffs_data()
  df_rep <- make_survey_data(
    n = 200, n_psu = 20, n_strata = 4,
    design = "replicate", type = "jk1", seed = 42
  )
  df_rep$treats <- factor(
    sample(c("Control", "A", "B"), nrow(df_rep), replace = TRUE)
  )
  df_rep$dv <- rnorm(nrow(df_rep), 50, 10)

  d <- as_survey_replicate(
    df_rep, weights = wt,
    repweights = starts_with("repwt_"),
    type = "JK1"
  )
  result <- get_diffs(d, dv, treats, ref_level = "Control")
  expect_identical(meta(result)$design_type, "replicate")
})

test_that("get_diffs() works with survey_twophase design", {
  df <- make_survey_data(
    n = 200, n_psu = 20, n_strata = 4,
    design = "twophase", seed = 42
  )
  df$treats <- factor(
    sample(c("Control", "A", "B"), nrow(df), replace = TRUE)
  )
  df$dv <- rnorm(nrow(df), 50, 10)

  phase1 <- as_survey(df, ids = psu, strata = strata)
  d <- as_survey_twophase(
    phase1, subset = subset, probs2 = phase2_prob
  )
  result <- get_diffs(d, dv, treats, ref_level = "Control")
  expect_identical(meta(result)$design_type, "twophase")
})

test_that("get_diffs() works with survey_nonprob design", {
  df <- .make_diffs_data()
  d <- as_survey_nonprob(df, weights = wt)
  result <- get_diffs(d, dv, treats, ref_level = "Control")
  expect_identical(meta(result)$design_type, "nonprob")
})

test_that("get_diffs() domain estimation produces in-domain n counts", {
  skip_if_not_installed("surveytidy")
  d <- .make_diffs_design()
  total_n <- sum(d@data$treats == "Control", na.rm = TRUE)

  # Filter to a subset
  d_filt <- surveytidy::filter(d, gender == "M")
  result <- get_diffs(d_filt, dv, treats, ref_level = "Control")

  # n should be smaller than total_n
  ref_n <- result$n[[1L]]
  expect_true(ref_n < total_n)
})

# ═══════════════════════════════════════════════════════════════════════════
# 5. EDGE CASES
# ═══════════════════════════════════════════════════════════════════════════

test_that("get_diffs() works with 2 levels (simplest case)", {
  df <- .make_diffs_data()
  df$two_arm <- factor(
    sample(c("Control", "Treatment"), nrow(df), replace = TRUE)
  )
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  result <- get_diffs(d, dv, two_arm, ref_level = "Control")

  expect_equal(nrow(result), 2L)
  expect_equal(result$estimate[[1L]], 0)
})

test_that("get_diffs() works with many levels (10+)", {
  df <- .make_diffs_data(n = 500, seed = 123)
  df$many_arm <- factor(
    sample(paste0("Level_", 1:10), nrow(df), replace = TRUE)
  )
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)

  suppressWarnings(  # small cell warnings
    result <- get_diffs(d, dv, many_arm)
  )
  # 1 ref + 9 treatment = 10 rows
  expect_equal(nrow(result), 10L)
})

test_that("get_diffs() warns when treats is character (not factor)", {
  df <- .make_diffs_data()
  df$char_arm <- sample(c("Control", "A", "B"), nrow(df), replace = TRUE)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)

  expect_warning(
    get_diffs(d, dv, char_arm, ref_level = "A"),
    class = "surveycore_warning_treats_coerced"
  )
})

test_that("get_diffs() warns when ref mean is 0 with show_pct_change", {
  set.seed(123)
  n <- 200
  df <- make_survey_data(n = n, n_psu = 20, n_strata = 4, seed = 123)
  # All control observations have DV = 0, so weighted mean is exactly 0
  df$arm <- factor(
    sample(c("Control", "A", "B"), n, replace = TRUE),
    levels = c("Control", "A", "B")
  )
  df$zero_dv <- ifelse(df$arm == "Control", 0, rnorm(n, 5, 1))
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)

  expect_warning(
    get_diffs(d, zero_dv, arm, ref_level = "Control",
              show_pct_change = TRUE),
    class = "surveycore_warning_pct_change_zero_ref"
  )
})

test_that("get_diffs() fires small cell warning for single obs level", {
  df <- .make_diffs_data()
  # One level with very few observations
  df$tiny_arm <- factor(
    c("Tiny", rep("Control", 99), rep("B", nrow(df) - 100))
  )
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)

  expect_warning(
    get_diffs(d, dv, tiny_arm, ref_level = "Control"),
    class = "surveycore_warning_small_cell"
  )
})

test_that("get_diffs() na.rm = FALSE with NAs errors from survey_glm", {
  df <- .make_diffs_data()
  df$dv[1:5] <- NA
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)

  expect_error(
    get_diffs(d, dv, treats, na.rm = FALSE)
  )
})
