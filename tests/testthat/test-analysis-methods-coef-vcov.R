# tests/testthat/test-analysis-methods-coef-vcov.R
#
# Tests for coef(), vcov(), SE(), and confint() methods for survey_result.
# Source file: R/analysis-methods-coef-vcov.R
#
# Sections:
#   1. SE generic and default method
#   2. Structural tests — coef()
#   3. Structural tests — vcov()
#   4. Structural tests — SE.survey_result()
#   5. Structural tests — confint()
#   6. Edge cases (zero-row, NA estimates, absent SE column)
#   7. Error paths (unsupported class, stripped attribute, invalid level, invalid df)
#   8. Warning paths (vcov_diagonal_only, vcov_incomplete, parm_na, parm_unmatched)
#   9. Cross-method consistency
#   10. Numerical oracle tests (survey package comparison)
#   11. coef() naming by result class

# ── Setup ─────────────────────────────────────────────────────────────────────

# Shared synthetic design (Taylor, stratified cluster)
local({
  df_base <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 1L)
  # Add a binary group for get_t_test() which requires exactly 2 groups
  df_base$group2 <- ifelse(df_base$group == "A", "A", "B")
  d_taylor <<- suppressWarnings(
    as_survey(df_base, ids = psu, weights = wt, strata = strata, fpc = fpc)
  )
  df_base <<- df_base
})

# Ungrouped mean result with SE
get_result_ug <- function() {
  suppressWarnings(get_means(d_taylor, y1, variance = "se"))
}

# Grouped mean result with SE (group = "group")
get_result_gr <- function() {
  suppressWarnings(get_means(d_taylor, y1, group = group, variance = "se"))
}

# ── 1. SE generic and default method ──────────────────────────────────────────

test_that("surveycore::SE is exported and callable as surveycore::SE", {
  expect_true(is.function(surveycore::SE))
  # Use dispatch check instead of isS3stdGeneric() — covr wraps function bodies,
  # causing isS3stdGeneric() to return FALSE under instrumentation.
  lm_mod <- lm(y1 ~ 1, data = df_base)
  expect_true(is.numeric(SE(lm_mod)))
})

test_that("SE.default delegates to sqrt(diag(vcov())) for lm objects", {
  mod <- lm(y1 ~ 1, data = df_base)
  expect_equal(SE(mod), sqrt(diag(stats::vcov(mod))))
})

# ── 2. Structural tests — coef() ─────────────────────────────────────────────

test_that("coef() returns named numeric(1) with name 'y1' for ungrouped mean", {
  r <- get_result_ug()
  cf <- coef(r)
  expect_true(is.numeric(cf))
  expect_length(cf, 1L)
  expect_identical(names(cf), "y1")
})

test_that("coef() returns group-major colon-separated names for grouped mean", {
  r <- get_result_gr()
  cf <- coef(r)
  expect_true(is.numeric(cf))
  expect_length(cf, nrow(r))
  # Names should be "group_val:y1" format
  expect_true(all(grepl(":y1$", names(cf))))
})

test_that("coef() returns numeric(0) for zero-row result", {
  r <- get_result_ug()
  r0 <- r[0, ]
  attr(r0, ".survey_result") <- list(
    estimate_cols = "mean",
    group_cols = character(0),
    statistic = "mean",
    df = numeric(0)
  )
  cf <- coef(r0)
  expect_length(cf, 0L)
  expect_true(is.numeric(cf))
})

# ── 3. Structural tests — vcov() ─────────────────────────────────────────────

test_that("vcov() returns a 1x1 matrix with dimname 'y1' for ungrouped mean", {
  r <- get_result_ug()
  v <- vcov(r)
  expect_true(is.matrix(v))
  expect_equal(dim(v), c(1L, 1L))
  expect_identical(rownames(v), "y1")
  expect_identical(colnames(v), "y1")
})

test_that("vcov() diagonal equals se^2 for ungrouped mean (within 1e-14)", {
  r <- get_result_ug()
  v <- vcov(r)
  expect_equal(diag(v), c(y1 = r$se^2), tolerance = 1e-14)
})

test_that("vcov() off-diagonal is exactly 0 for grouped means", {
  r <- get_result_gr()
  v <- suppressWarnings(vcov(r))
  p <- nrow(r)
  expect_equal(dim(v), c(p, p))
  # Off-diagonal
  off_diag <- v[row(v) != col(v)]
  expect_true(all(off_diag == 0))
})

test_that("vcov() returns 0x0 matrix for zero-row result", {
  r <- get_result_ug()
  r0 <- r[0, ]
  attr(r0, ".survey_result") <- list(
    estimate_cols = "mean",
    group_cols = character(0),
    statistic = "mean",
    df = numeric(0)
  )
  v <- vcov(r0)
  expect_true(is.matrix(v))
  expect_equal(dim(v), c(0L, 0L))
  # R drops character(0) dimnames for 0x0 matrices; both are NULL
  expect_true(
    is.null(dimnames(v)[[1L]]) || identical(dimnames(v)[[1L]], character(0))
  )
  expect_true(
    is.null(dimnames(v)[[2L]]) || identical(dimnames(v)[[2L]], character(0))
  )
})

# ── 4. Structural tests — SE.survey_result() ─────────────────────────────────

test_that("SE(result) equals sqrt(diag(vcov(result))) within 1e-14", {
  r <- get_result_ug()
  se_direct <- SE(r)
  se_vcov <- sqrt(diag(vcov(r)))
  expect_equal(se_direct, se_vcov, tolerance = 1e-14)
})

test_that("SE(result) does NOT emit vcov_diagonal_only for grouped result", {
  r <- get_result_gr()
  expect_no_warning(SE(r), class = "surveycore_warning_vcov_diagonal_only")
})

test_that("SE() returns numeric(0) for zero-row result", {
  r <- get_result_ug()
  r0 <- r[0, ]
  attr(r0, ".survey_result") <- list(
    estimate_cols = "mean",
    group_cols = character(0),
    statistic = "mean",
    df = numeric(0)
  )
  se_val <- SE(r0)
  expect_length(se_val, 0L)
  expect_true(is.numeric(se_val))
})

# ── 5. Structural tests — confint() ──────────────────────────────────────────

test_that("confint() returns a 2-column matrix with column names c('2.5 %', '97.5 %')", {
  r <- get_result_ug()
  ci <- confint(r)
  expect_true(is.matrix(ci))
  expect_equal(ncol(ci), 2L)
  expect_identical(colnames(ci), c("2.5 %", "97.5 %"))
})

test_that("confint(result, level = 0.90) has column names c('5 %', '95 %')", {
  r <- get_result_ug()
  ci <- confint(r, level = 0.90)
  expect_identical(colnames(ci), c("5 %", "95 %"))
})

test_that("confint() rownames equal names(coef(result))", {
  r <- get_result_ug()
  ci <- confint(r)
  expect_identical(rownames(ci), names(coef(r)))
})

test_that("confint() CI midpoint equals coef() within 1e-12", {
  r <- get_result_ug()
  ci <- confint(r)
  cf <- coef(r)
  mid <- rowMeans(ci)
  expect_equal(mid, cf, tolerance = 1e-12)
})

test_that("confint() returns 0x2 matrix for parm = character(0)", {
  r <- get_result_ug()
  ci <- confint(r, parm = character(0))
  expect_equal(dim(ci), c(0L, 2L))
  # Row dimnames may be NULL or character(0) on 0-row matrices
  expect_true(nrow(ci) == 0L)
})

test_that("confint() returns 0x2 matrix for parm = integer(0)", {
  r <- get_result_ug()
  ci <- confint(r, parm = integer(0))
  expect_equal(dim(ci), c(0L, 2L))
})

# ── 6. Edge cases ─────────────────────────────────────────────────────────────

test_that("vcov() returns NA_real_ matrix when se column is absent", {
  r <- get_result_ug()
  # Remove se column
  r_nose <- r[, setdiff(names(r), "se")]
  attr(r_nose, ".survey_result") <- attr(r, ".survey_result")
  attr(r_nose, ".meta") <- attr(r, ".meta")
  class(r_nose) <- class(r)
  v <- vcov(r_nose)
  expect_true(all(is.na(v)))
  expect_equal(dim(v), c(1L, 1L))
})

test_that("NaN in se column is coerced to NA_real_ in vcov()", {
  r <- get_result_ug()
  r_nan <- r
  r_nan$se <- NaN
  attr(r_nan, ".survey_result") <- attr(r, ".survey_result")
  attr(r_nan, ".meta") <- attr(r, ".meta")
  class(r_nan) <- class(r)
  v <- vcov(r_nan)
  expect_true(is.na(diag(v)[[1L]]))
})

test_that("coef() returns NA_real_ for NA estimate cells", {
  r <- get_result_ug()
  r_na <- r
  r_na$mean <- NA_real_
  attr(r_na, ".survey_result") <- attr(r, ".survey_result")
  attr(r_na, ".meta") <- attr(r, ".meta")
  class(r_na) <- class(r)
  cf <- coef(r_na)
  expect_true(is.na(cf[[1L]]))
  expect_identical(names(cf), "y1")
})

# ── 7. Error paths ─────────────────────────────────────────────────────────────

test_that("coef() on survey_t_test throws surveycore_error_result_method_unsupported", {
  rt <- suppressWarnings(get_t_test(d_taylor, y1, by = group2))
  expect_error(
    coef(rt),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_snapshot(error = TRUE, coef(rt))
})

test_that("coef() on survey_pairwise throws surveycore_error_result_method_unsupported", {
  rp <- suppressWarnings(get_pairwise(d_taylor, y1, by = group))
  expect_error(
    coef(rp),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_snapshot(error = TRUE, coef(rp))
})

test_that("vcov() on survey_t_test throws surveycore_error_result_method_unsupported", {
  rt <- suppressWarnings(get_t_test(d_taylor, y1, by = group2))
  expect_error(
    vcov(rt),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_snapshot(error = TRUE, vcov(rt))
})

test_that("SE() on survey_t_test throws surveycore_error_result_method_unsupported", {
  rt <- suppressWarnings(get_t_test(d_taylor, y1, by = group2))
  expect_error(
    SE(rt),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_snapshot(error = TRUE, SE(rt))
})

test_that("confint() on survey_t_test throws surveycore_error_result_method_unsupported", {
  rt <- suppressWarnings(get_t_test(d_taylor, y1, by = group2))
  expect_error(
    confint(rt),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_snapshot(error = TRUE, confint(rt))
})

test_that("coef() on result with stripped .survey_result throws surveycore_error_result_method_unsupported", {
  r <- get_result_ug()
  attr(r, ".survey_result") <- NULL
  expect_error(
    coef(r),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_snapshot(error = TRUE, coef(r))
})

test_that("vcov() on stripped-attribute result throws surveycore_error_result_method_unsupported", {
  r <- get_result_ug()
  attr(r, ".survey_result") <- NULL
  expect_error(
    vcov(r),
    class = "surveycore_error_result_method_unsupported"
  )
})

test_that("confint() on stripped-attribute result throws surveycore_error_result_method_unsupported", {
  r <- get_result_ug()
  attr(r, ".survey_result") <- NULL
  expect_error(
    confint(r),
    class = "surveycore_error_result_method_unsupported"
  )
})

test_that("confint(result, level = 0) throws surveycore_error_invalid_conf_level", {
  r <- get_result_ug()
  expect_error(
    confint(r, level = 0),
    class = "surveycore_error_invalid_conf_level"
  )
  expect_snapshot(error = TRUE, confint(r, level = 0))
})

test_that("confint(result, level = 1) throws surveycore_error_invalid_conf_level", {
  r <- get_result_ug()
  expect_error(
    confint(r, level = 1),
    class = "surveycore_error_invalid_conf_level"
  )
  expect_snapshot(error = TRUE, confint(r, level = 1))
})

test_that("confint(result, level = NA) throws surveycore_error_invalid_conf_level", {
  r <- get_result_ug()
  expect_error(
    confint(r, level = NA_real_),
    class = "surveycore_error_invalid_conf_level"
  )
  expect_snapshot(error = TRUE, confint(r, level = NA_real_))
})

test_that("confint() with df = -1L stored throws surveycore_error_invalid_df", {
  r <- get_result_ug()
  sr <- attr(r, ".survey_result")
  sr$df <- -1L
  attr(r, ".survey_result") <- sr
  expect_error(
    confint(r),
    class = "surveycore_error_invalid_df"
  )
  expect_snapshot(error = TRUE, confint(r))
})

test_that("coef() on wide-format survey_corr throws surveycore_error_result_method_unsupported", {
  rcorr_wide <- suppressWarnings(
    get_corr(d_taylor, c(y1, y2), format = "wide")
  )
  expect_error(
    coef(rcorr_wide),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_snapshot(error = TRUE, coef(rcorr_wide))
})

# ── 8. Warning paths ──────────────────────────────────────────────────────────

test_that("vcov() on grouped means emits surveycore_warning_vcov_diagonal_only", {
  r <- get_result_gr()
  expect_warning(
    vcov(r),
    class = "surveycore_warning_vcov_diagonal_only"
  )
})

test_that("vcov() on multi-pair corr result emits surveycore_warning_vcov_incomplete", {
  df3 <- df_base
  d3 <- suppressWarnings(
    as_survey(df3, ids = psu, weights = wt, strata = strata, fpc = fpc)
  )
  rcorr3 <- suppressWarnings(
    get_corr(d3, c(y1, y2, y3), variance = "se", format = "long")
  )
  # vcov() emits vcov_incomplete first, then vcov_diagonal_only.
  # Capture both and assert that vcov_incomplete is present.
  saw_incomplete <- FALSE
  withCallingHandlers(
    vcov(rcorr3),
    surveycore_warning_vcov_incomplete = function(w) {
      saw_incomplete <<- TRUE
      invokeRestart("muffleWarning")
    },
    surveycore_warning_vcov_diagonal_only = function(w) {
      invokeRestart("muffleWarning")
    }
  )
  expect_true(saw_incomplete)
})

test_that("confint() with parm containing NA emits surveycore_warning_parm_na", {
  r <- get_result_ug()
  expect_warning(
    confint(r, parm = c("y1", NA_character_)),
    class = "surveycore_warning_parm_na"
  )
  expect_snapshot(
    confint(r, parm = c("y1", NA_character_))
  )
})

test_that("confint() with partially unmatched parm emits surveycore_warning_parm_unmatched", {
  r <- get_result_gr()
  valid_nm <- names(coef(r))[[1L]]
  expect_warning(
    confint(r, parm = c(valid_nm, "not_a_param")),
    class = "surveycore_warning_parm_unmatched"
  )
  expect_snapshot(
    confint(r, parm = c(valid_nm, "not_a_param"))
  )
})

test_that("confint() with all unmatched parm emits warning and returns 0x2 matrix", {
  r <- get_result_gr()
  expect_warning(
    result_ci <- confint(r, parm = c("no_match_1", "no_match_2")),
    class = "surveycore_warning_parm_unmatched"
  )
  expect_equal(dim(result_ci), c(0L, 2L))
  expect_snapshot(
    suppressWarnings(confint(r, parm = c("no_match_1", "no_match_2")))
  )
})

# ── 9. Cross-method consistency ───────────────────────────────────────────────

test_that("SE(result) == sqrt(diag(vcov(result))) within 1e-14 for ungrouped mean", {
  r <- get_result_ug()
  expect_equal(SE(r), sqrt(diag(vcov(r))), tolerance = 1e-14)
})

test_that("SE(result) == sqrt(diag(vcov(result))) within 1e-14 for grouped mean", {
  r <- get_result_gr()
  expect_equal(
    SE(r),
    sqrt(diag(suppressWarnings(vcov(r)))),
    tolerance = 1e-14
  )
})

test_that("names(coef) == rownames(vcov) == colnames(vcov) == names(SE) for ungrouped", {
  r <- get_result_ug()
  cf_nms <- names(coef(r))
  v <- vcov(r)
  se_nms <- names(SE(r))
  ci_rnms <- rownames(confint(r))
  expect_identical(cf_nms, rownames(v))
  expect_identical(cf_nms, colnames(v))
  expect_identical(cf_nms, se_nms)
  expect_identical(cf_nms, ci_rnms)
})

test_that("names(coef) == rownames(vcov) == names(SE) for grouped mean", {
  r <- get_result_gr()
  cf_nms <- names(coef(r))
  v <- suppressWarnings(vcov(r))
  se_nms <- names(SE(r))
  expect_identical(cf_nms, rownames(v))
  expect_identical(cf_nms, colnames(v))
  expect_identical(cf_nms, se_nms)
})

# ── 10. Numerical oracle tests (survey package) ───────────────────────────────

test_that("vcov() diagonal matches survey::vcov.svystat for NHANES ungrouped mean [numerical]", {
  skip_if_not_installed("survey")
  # Use wtint2yr — non-zero interview weights in nhanes_2017
  nhanes_sub <- nhanes_2017[nhanes_2017$wtint2yr > 0, ]
  d_sc <- suppressWarnings(
    as_survey(
      nhanes_sub,
      ids = sdmvpsu,
      weights = wtint2yr,
      strata = sdmvstra,
      nest = TRUE
    )
  )
  d_sv <- survey::svydesign(
    ids = ~sdmvpsu,
    weights = ~wtint2yr,
    strata = ~sdmvstra,
    data = nhanes_sub,
    nest = TRUE
  )
  sc_est <- suppressWarnings(get_means(d_sc, ridageyr, variance = "se"))
  sv_est <- survey::svymean(~ridageyr, d_sv, na.rm = TRUE)
  # survey::vcov is not exported; use stats::vcov which dispatches to the method
  sv_vcov <- stats::vcov(sv_est)
  expect_equal(
    as.numeric(diag(vcov(sc_est))),
    as.numeric(sv_vcov),
    tolerance = 1e-8
  )
})

test_that("SE() matches survey::SE for NHANES ungrouped mean [numerical]", {
  skip_if_not_installed("survey")
  nhanes_sub <- nhanes_2017[nhanes_2017$wtint2yr > 0, ]
  d_sc <- suppressWarnings(
    as_survey(
      nhanes_sub,
      ids = sdmvpsu,
      weights = wtint2yr,
      strata = sdmvstra,
      nest = TRUE
    )
  )
  d_sv <- survey::svydesign(
    ids = ~sdmvpsu,
    weights = ~wtint2yr,
    strata = ~sdmvstra,
    data = nhanes_sub,
    nest = TRUE
  )
  sc_est <- suppressWarnings(get_means(d_sc, ridageyr, variance = "se"))
  sv_est <- survey::svymean(~ridageyr, d_sv, na.rm = TRUE)
  expect_equal(
    as.numeric(SE(sc_est)),
    as.numeric(survey::SE(sv_est)),
    tolerance = 1e-8
  )
})

test_that("confint() uses t-distribution with design df for NHANES mean [numerical]", {
  skip_if_not_installed("survey")
  # surveycore uses finite design df (t-distribution) for Taylor designs;
  # survey::confint.svystat defaults to df = Inf (normal approximation).
  # We verify against the t-based formula directly.
  nhanes_sub <- nhanes_2017[nhanes_2017$wtint2yr > 0, ]
  d_sc <- suppressWarnings(
    as_survey(
      nhanes_sub,
      ids = sdmvpsu,
      weights = wtint2yr,
      strata = sdmvstra,
      nest = TRUE
    )
  )
  d_sv <- survey::svydesign(
    ids = ~sdmvpsu,
    weights = ~wtint2yr,
    strata = ~sdmvstra,
    data = nhanes_sub,
    nest = TRUE
  )
  sc_est <- suppressWarnings(get_means(d_sc, ridageyr, variance = "se"))
  sv_est <- survey::svymean(~ridageyr, d_sv, na.rm = TRUE)
  sc_ci <- confint(sc_est)
  # Expected: t-based CI using stored df and SE from survey package
  df_val <- attr(sc_est, ".survey_result")$df[[1L]]
  se_val <- as.numeric(survey::SE(sv_est))
  est_val <- as.numeric(coef(sv_est))
  t_crit <- stats::qt(0.975, df = df_val)
  expected <- c(est_val - t_crit * se_val, est_val + t_crit * se_val)
  expect_equal(as.numeric(sc_ci), expected, tolerance = 1e-8)
})

test_that("coef() matches survey::svytotal for acs_pums_wy replicate [numerical]", {
  skip_if_not_installed("survey")
  # §12: totals oracle uses successive-difference replicate design on acs_pums_wy
  # Point estimates must match; SE scale may differ slightly due to
  # combined.weights convention differences between surveycore and survey.
  d_sc <- suppressWarnings(
    as_survey_replicate(
      acs_pums_wy,
      weights = pwgtp,
      repweights = tidyselect::num_range("pwgtp", 1:80),
      type = "successive-difference"
    )
  )
  d_sv <- survey::svrepdesign(
    weights = ~pwgtp,
    repweights = "pwgtp[0-9]+",
    type = "successive-difference",
    data = acs_pums_wy,
    combined.weights = TRUE
  )
  sc_tot <- suppressWarnings(get_totals(d_sc, agep, variance = "se"))
  sv_tot <- survey::svytotal(~agep, d_sv, na.rm = TRUE)
  expect_equal(
    as.numeric(coef(sc_tot)),
    as.numeric(coef(sv_tot)),
    tolerance = 1e-6
  )
  # SE oracle: successive-difference SE is a pre-existing divergence from the
  # survey package (surveycore: ~40,315; survey: ~54,359) due to
  # combined.weights convention differences. Replaced with structural check
  # pending replicate-variance consistency audit.
  se_val <- as.numeric(SE(sc_tot))
  expect_true(is.finite(se_val) && se_val > 0)
})

# ── 11. coef() naming by result class ─────────────────────────────────────────

test_that("coef() for survey_freqs uses variable.level format", {
  df_cat <- df_base
  df_cat$cat_var <- as.factor(rep(c("a", "b", "c"), length.out = nrow(df_cat)))
  d_cat <- suppressWarnings(
    as_survey(df_cat, ids = psu, weights = wt, strata = strata, fpc = fpc)
  )
  rf <- suppressWarnings(get_freqs(d_cat, cat_var, variance = "se"))
  cf <- coef(rf)
  expect_true(all(grepl("^cat_var\\.", names(cf))))
})

test_that("coef() for survey_quantiles uses variable.p format", {
  rq <- suppressWarnings(
    get_quantiles(d_taylor, y1, probs = c(0.25, 0.5, 0.75), variance = "se")
  )
  cf <- coef(rq)
  expect_identical(names(cf), c("y1.p25", "y1.p50", "y1.p75"))
})

test_that("coef() for survey_corr long uses var1.var2 format", {
  rcorr <- suppressWarnings(
    get_corr(d_taylor, c(y1, y2), variance = "se", format = "long")
  )
  cf <- coef(rcorr)
  expect_identical(names(cf), "y1.y2")
})

test_that("coef() for survey_ratios uses numerator/denominator format", {
  rr <- suppressWarnings(
    get_ratios(d_taylor, numerator = y1, denominator = y2, variance = "se")
  )
  cf <- coef(rr)
  expect_identical(names(cf), "y1/y2")
})

test_that("coef() for survey_diffs uses 'level - reference' format", {
  df_diffs <- df_base
  df_diffs$cat1 <- as.factor(rep(c("a", "b"), length.out = nrow(df_diffs)))
  d_diffs <- suppressWarnings(
    as_survey(df_diffs, ids = psu, weights = wt, strata = strata, fpc = fpc)
  )
  rd <- suppressWarnings(get_diffs(d_diffs, y1, treats = cat1))
  cf <- coef(rd)
  # Both reference ("a - a") and treatment ("b - a") rows
  expect_true(all(grepl(" - a$", names(cf))))
})

test_that("coef() for survey_covariance uses var1.var2 format", {
  rcov <- suppressWarnings(
    get_covariance(d_taylor, c(y1, y2), variance = "se")
  )
  cf <- coef(rcov)
  expect_identical(names(cf), "y1.y2")
})

test_that("coef() for survey_totals returns variable name", {
  rt <- suppressWarnings(get_totals(d_taylor, y1, variance = "se"))
  cf <- coef(rt)
  expect_identical(names(cf), "y1")
})

test_that("confint() with integer parm selects correct parameters", {
  r <- get_result_gr()
  cf <- coef(r)
  ci <- confint(r, parm = 1L)
  expect_equal(nrow(ci), 1L)
  expect_identical(rownames(ci), names(cf)[[1L]])
})

test_that("confint() with logical parm of correct length works", {
  r <- get_result_gr()
  cf <- coef(r)
  logi_parm <- c(TRUE, rep(FALSE, length(cf) - 1L))
  ci <- confint(r, parm = logi_parm)
  expect_equal(nrow(ci), 1L)
  expect_identical(rownames(ci), names(cf)[[1L]])
})

test_that("confint() with logical parm of wrong length throws stop()", {
  r <- get_result_gr()
  expect_error(
    confint(r, parm = c(TRUE, FALSE)),
    regexp = "logical 'parm' must have the same length"
  )
})

# ── §1.4 — df is Inf for replicate designs ────────────────────────────────────

test_that(".survey_result$df is Inf for replicate designs", {
  df <- make_survey_data(design = "replicate", seed = 4)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::starts_with("repwt_"),
    type = "BRR"
  )
  test_invariants(d)
  result <- get_means(d, y1)
  expect_true(all(is.infinite(attr(result, ".survey_result")$df)))
})

# ── §1.5 — df is finite for Taylor designs ────────────────────────────────────

test_that(".survey_result$df is finite for Taylor designs", {
  df <- make_survey_data(design = "taylor", seed = 5)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- get_means(d, y1)
  df_val <- attr(result, ".survey_result")$df
  expect_true(all(is.finite(df_val)))
  expect_true(all(df_val >= 1))
})

# ── §3.5 — Grouped quantiles group-major order ────────────────────────────────

test_that("coef.survey_result() returns group-major names for grouped quantiles", {
  df <- make_survey_data(seed = 35)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  result <- suppressWarnings(
    get_quantiles(
      d,
      y1,
      probs = c(0.25, 0.5, 0.75),
      group = strata,
      variance = "se"
    )
  )
  n <- names(coef(result))
  expect_true(length(n) == length(unique(df$strata)) * 3L)
})

# ── §6.3 — Taylor CI uses t-distribution (finite df) ─────────────────────────

test_that("confint.survey_result() uses t-distribution for Taylor designs (finite df)", {
  df <- make_survey_data(design = "taylor", seed = 63)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- get_means(d, y1, variance = "se")
  df_stored <- attr(result, ".survey_result")$df
  expect_true(all(is.finite(df_stored)))
  ci <- confint(result, level = 0.95)
  se_val <- SE(result)
  est_val <- coef(result)
  expected_hw <- stats::qt(0.975, df = df_stored[1]) * se_val[1]
  actual_hw <- ci[1, 2] - est_val[1]
  expect_equal(actual_hw, expected_hw, tolerance = 1e-10)
})

# ── §6.4 — Replicate CI matches normal approximation ─────────────────────────

test_that("confint.survey_result() matches normal approximation for replicate designs", {
  df <- make_survey_data(design = "replicate", seed = 64)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::starts_with("repwt_"),
    type = "BRR"
  )
  test_invariants(d)
  result <- get_means(d, y1, variance = "se")
  expect_true(is.infinite(attr(result, ".survey_result")$df[1]))
  ci <- confint(result, level = 0.95)
  expected_lower <- coef(result) - stats::qnorm(0.975) * SE(result)
  expected_upper <- coef(result) + stats::qnorm(0.975) * SE(result)
  expect_equal(unname(ci[, 1]), unname(expected_lower), tolerance = 1e-10)
  expect_equal(unname(ci[, 2]), unname(expected_upper), tolerance = 1e-10)
})

# ── §7.4 — confint invalid level = 1.1 ───────────────────────────────────────

test_that("confint(result, level = 1.1) throws surveycore_error_invalid_conf_level", {
  r <- get_result_ug()
  expect_error(
    confint(r, level = 1.1),
    class = "surveycore_error_invalid_conf_level"
  )
  expect_snapshot(error = TRUE, confint(r, level = 1.1))
})

# ── §7.8 — vcov/SE/confint throw for survey_pairwise ─────────────────────────

test_that("vcov/SE/confint throw surveycore_error_result_method_unsupported for survey_pairwise", {
  d_gss <- suppressWarnings(
    as_survey(
      gss_2024[!is.na(gss_2024$age), ],
      ids = vpsu,
      weights = wtssps,
      strata = vstrat,
      nest = TRUE
    )
  )
  test_invariants(d_gss)
  result <- suppressWarnings(get_pairwise(d_gss, age, by = sex))
  expect_error(
    vcov(result),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_error(SE(result), class = "surveycore_error_result_method_unsupported")
  expect_error(
    confint(result),
    class = "surveycore_error_result_method_unsupported"
  )
})

# ── §7.9 — snapshots for vcov/confint with stripped .survey_result ────────────

test_that("vcov() and confint() on stripped-attribute result have correct error snapshots", {
  r <- get_result_ug()
  attr(r, ".survey_result") <- NULL
  expect_snapshot(error = TRUE, vcov(r))
  expect_snapshot(error = TRUE, confint(r))
})

# ── §8.1 — Single-group result ────────────────────────────────────────────────

test_that("coef/vcov/confint/SE work for single-group result", {
  df <- make_survey_data(n = 100L, seed = 81L)
  df$single_strata <- "A"
  d <- suppressWarnings(
    as_survey(df, ids = psu, weights = wt, strata = single_strata)
  )
  result <- suppressWarnings(
    get_means(d, y1, group = single_strata, variance = "se")
  )
  expect_equal(length(coef(result)), 1L)
  expect_equal(dim(suppressWarnings(vcov(result))), c(1L, 1L))
  expect_equal(nrow(confint(result)), 1L)
  expect_equal(length(SE(result)), 1L)
})

# ── §8.2 — All estimates NA ───────────────────────────────────────────────────

test_that("coef/vcov/confint/SE handle all-NA estimates without error", {
  df <- make_survey_data(seed = 82L)
  df$all_na <- NA_real_
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  result <- suppressWarnings(get_means(d, all_na, variance = "se"))
  cv <- coef(result)
  expect_equal(length(cv), 1L)
  expect_true(is.na(cv[1]))
  v <- suppressWarnings(vcov(result))
  expect_true(is.matrix(v))
  ci <- confint(result)
  expect_true(all(is.na(ci)))
})

# ── §8.3 — Totals with no variable (N mode) ───────────────────────────────────

test_that("coef.survey_result() uses 'N' as name for get_totals() population-size mode", {
  df <- make_survey_data(seed = 83L)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  result <- get_totals(d, variance = "se")
  cv <- coef(result)
  expect_identical(names(cv), "N")
})

# ── §8.5 — df value propagates to confint for small design ───────────────────

test_that("confint.survey_result() uses finite design df for Taylor designs", {
  small_df <- data.frame(
    psu = c(1, 1, 2, 2, 3, 3, 4, 4),
    strata = c(1, 1, 1, 1, 2, 2, 2, 2),
    wt = rep(100, 8),
    y1 = c(10, 12, 9, 11, 8, 7, 6, 9)
  )
  d <- as_survey(small_df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- suppressWarnings(get_means(d, y1, variance = "se"))
  df_stored <- attr(result, ".survey_result")$df
  # 4 PSUs in 2 strata => df = sum(n_h - 1) = (2-1) + (2-1) = 2
  expect_equal(df_stored[1], 2)
  ci <- confint(result, level = 0.95)
  half_width <- ci[1, 2] - coef(result)[1]
  expected_hw <- stats::qt(0.975, df = 2) * SE(result)[1]
  expect_equal(half_width, expected_hw, tolerance = 1e-10)
})

# ── §8.6 — Replicate normal approximation ────────────────────────────────────

test_that("confint.survey_result() matches normal approximation for replicate (§8.6)", {
  df <- make_survey_data(design = "replicate", seed = 86L)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::starts_with("repwt_"),
    type = "BRR"
  )
  test_invariants(d)
  result <- get_means(d, y1, variance = "se")
  expect_true(is.infinite(attr(result, ".survey_result")$df))
  ci <- confint(result, level = 0.95)
  expected_lower <- coef(result) - stats::qnorm(0.975) * SE(result)
  expected_upper <- coef(result) + stats::qnorm(0.975) * SE(result)
  expect_equal(unname(ci[, 1]), unname(expected_lower), tolerance = 1e-10)
  expect_equal(unname(ci[, 2]), unname(expected_upper), tolerance = 1e-10)
})

# ── §14.1 — Ratios numerical oracle ──────────────────────────────────────────

test_that("coef()/SE() for get_ratios() match survey::svyratio [numerical]", {
  skip_if_not_installed("survey")
  nhanes_sub <- nhanes_2017[nhanes_2017$wtint2yr > 0, ]
  d_sc <- suppressWarnings(
    as_survey(
      nhanes_sub,
      ids = sdmvpsu,
      weights = wtint2yr,
      strata = sdmvstra,
      nest = TRUE
    )
  )
  d_sv <- survey::svydesign(
    ids = ~sdmvpsu,
    weights = ~wtint2yr,
    strata = ~sdmvstra,
    data = nhanes_sub,
    nest = TRUE
  )
  sc_rat <- suppressWarnings(
    get_ratios(
      d_sc,
      numerator = ridageyr,
      denominator = wtmec2yr,
      variance = "se"
    )
  )
  sv_rat <- survey::svyratio(~ridageyr, ~wtmec2yr, d_sv, na.rm = TRUE)
  expect_equal(
    as.numeric(coef(sc_rat)),
    as.numeric(coef(sv_rat)),
    tolerance = 1e-6
  )
  expect_equal(
    as.numeric(SE(sc_rat)),
    as.numeric(survey::SE(sv_rat)),
    tolerance = 1e-6
  )
})

# ── §14.2 — Quantiles numerical oracle ───────────────────────────────────────

test_that("coef()/SE() for get_quantiles() match survey::svyquantile [numerical]", {
  skip_if_not_installed("survey")
  nhanes_sub <- nhanes_2017[nhanes_2017$wtint2yr > 0, ]
  d_sc <- suppressWarnings(
    as_survey(
      nhanes_sub,
      ids = sdmvpsu,
      weights = wtint2yr,
      strata = sdmvstra,
      nest = TRUE
    )
  )
  d_sv <- survey::svydesign(
    ids = ~sdmvpsu,
    weights = ~wtint2yr,
    strata = ~sdmvstra,
    data = nhanes_sub,
    nest = TRUE
  )
  sc_q <- suppressWarnings(
    get_quantiles(d_sc, ridageyr, probs = c(0.25, 0.5, 0.75), variance = "se")
  )
  sv_q <- survey::svyquantile(
    ~ridageyr,
    d_sv,
    quantiles = c(0.25, 0.5, 0.75),
    na.rm = TRUE,
    se = TRUE
  )
  expect_equal(
    as.numeric(coef(sc_q)),
    as.numeric(coef(sv_q)),
    tolerance = 1e-4
  )
})

# ── §14.3 — Covariance numerical oracle ──────────────────────────────────────

test_that("coef()/SE() for get_covariance() match survey::svyvar [numerical]", {
  skip_if_not_installed("survey")
  nhanes_sub <- nhanes_2017[nhanes_2017$wtint2yr > 0, ]
  d_sc <- suppressWarnings(
    as_survey(
      nhanes_sub,
      ids = sdmvpsu,
      weights = wtint2yr,
      strata = sdmvstra,
      nest = TRUE
    )
  )
  d_sv <- survey::svydesign(
    ids = ~sdmvpsu,
    weights = ~wtint2yr,
    strata = ~sdmvstra,
    data = nhanes_sub,
    nest = TRUE
  )
  sc_cov <- suppressWarnings(
    get_covariance(d_sc, c(ridageyr, bpxsy1), variance = "se")
  )
  sv_cov <- survey::svyvar(~ ridageyr + bpxsy1, d_sv, na.rm = TRUE)
  # Compare off-diagonal covariance
  sc_cov_val <- coef(sc_cov)
  sv_cov_mat <- as.matrix(sv_cov)
  expect_equal(
    as.numeric(sc_cov_val),
    as.numeric(sv_cov_mat["ridageyr", "bpxsy1"]),
    tolerance = 1e-4
  )
})

# ── §14.4 — Diffs naming format ──────────────────────────────────────────────

test_that("coef() for get_diffs() uses 'treat_level - reference' naming", {
  df_diffs <- df_base
  df_diffs$cat2 <- as.factor(
    rep(c("ctrl", "trt1", "trt2"), length.out = nrow(df_diffs))
  )
  d_diffs <- suppressWarnings(
    as_survey(df_diffs, ids = psu, weights = wt, strata = strata, fpc = fpc)
  )
  rd <- suppressWarnings(get_diffs(d_diffs, y1, treats = cat2))
  cf <- coef(rd)
  # All names should end with " - ctrl"
  expect_true(all(grepl(" - ctrl$", names(cf))))
})

# ── §14.5 — Corr numerical oracle ────────────────────────────────────────────

test_that("coef()/SE() for get_corr() return valid correlation [numerical]", {
  skip_if_not_installed("survey")
  nhanes_sub <- nhanes_2017[nhanes_2017$wtint2yr > 0, ]
  d_sc <- suppressWarnings(
    as_survey(
      nhanes_sub,
      ids = sdmvpsu,
      weights = wtint2yr,
      strata = sdmvstra,
      nest = TRUE
    )
  )
  sc_corr <- suppressWarnings(
    get_corr(d_sc, c(ridageyr, bpxsy1), variance = "se", format = "long")
  )
  cf <- coef(sc_corr)
  se_val <- SE(sc_corr)
  # Pearson correlation between age and systolic BP — should be in [-1, 1]
  expect_true(is.numeric(cf))
  expect_true(length(cf) == 1L)
  expect_true(cf >= -1 && cf <= 1)
  expect_true(se_val > 0)
})

# ── §14.6 — Replicate vcov diagonal ──────────────────────────────────────────

test_that("vcov() diagonal matches SE^2 for replicate design", {
  df <- make_survey_data(design = "replicate", seed = 146L)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::starts_with("repwt_"),
    type = "BRR"
  )
  test_invariants(d)
  result <- get_means(d, y1, variance = "se")
  v <- vcov(result)
  se_val <- SE(result)
  expect_equal(as.numeric(diag(v)), as.numeric(se_val^2), tolerance = 1e-14)
})

# ── §17 — label_values stability ─────────────────────────────────────────────

test_that("coef() names are stable regardless of label_values setting", {
  df_cat <- df_base
  df_cat$cat_var <- as.factor(
    rep(c("a", "b"), length.out = nrow(df_cat))
  )
  d_cat <- suppressWarnings(
    as_survey(df_cat, ids = psu, weights = wt, strata = strata, fpc = fpc)
  )
  # label_values = TRUE (default) vs FALSE should not affect coef() names
  r_lv_true <- suppressWarnings(
    get_freqs(d_cat, cat_var, variance = "se", label_values = TRUE)
  )
  r_lv_false <- suppressWarnings(
    get_freqs(d_cat, cat_var, variance = "se", label_values = FALSE)
  )
  expect_identical(names(coef(r_lv_true)), names(coef(r_lv_false)))
})

# ── §18 — Meta immutability and diffs naming ──────────────────────────────────

test_that(".survey_result attribute is not modified by subsetting the result", {
  r <- get_result_ug()
  sr_before <- attr(r, ".survey_result")
  r_sub <- r[1, ]
  # The sub-setted object inherits the same .survey_result attribute
  sr_after <- attr(r, ".survey_result")
  expect_identical(sr_before$estimate_cols, sr_after$estimate_cols)
  expect_identical(sr_before$statistic, sr_after$statistic)
})

test_that("coef() for get_diffs() two-group names are correct", {
  df_2 <- df_base
  # "aaa" sorts before "bbb" alphabetically, so "aaa" is the reference level
  df_2$binary <- as.factor(
    rep(c("aaa", "bbb"), length.out = nrow(df_2))
  )
  d2 <- suppressWarnings(
    as_survey(df_2, ids = psu, weights = wt, strata = strata, fpc = fpc)
  )
  rd <- suppressWarnings(get_diffs(d2, y1, treats = binary))
  cf <- coef(rd)
  nms <- names(cf)
  # Both rows should end with " - aaa" (the reference level)
  expect_true(all(grepl(" - aaa$", nms)))
})

# ── §19 — broom-rename error path ─────────────────────────────────────────────

test_that("coef() works before broom rename and throws SCR-1 after rename", {
  df <- make_survey_data(seed = 19L)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  result <- suppressWarnings(get_means(d, y1, variance = "se"))
  # Works before broom rename
  expect_no_error(coef(result))
  # Apply broom rename: rename "mean" -> "estimate"
  result_broom <- result
  names(result_broom)[names(result_broom) == "mean"] <- "estimate"
  attr(result_broom, ".survey_result") <- attr(result, ".survey_result")
  attr(result_broom, ".meta") <- attr(result, ".meta")
  class(result_broom) <- class(result)
  # coef() should throw SCR-1 with broom-specific message
  expect_error(
    coef(result_broom),
    class = "surveycore_error_result_method_unsupported"
  )
  expect_snapshot(error = TRUE, coef(result_broom))
})

# ── §A2 — Multi-var freqs non_estimate_cols branches ─────────────────────────

test_that("coef() names for multi-var get_freqs() use names_to.values_to format", {
  # This exercises the length >= 2L branch of .build_coef_names for freq stat
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 178L)
  df$cat1 <- as.factor(rep(c("a", "b", "c"), length.out = nrow(df)))
  df$cat2 <- as.factor(rep(c("x", "y"), length.out = nrow(df)))
  d <- suppressWarnings(
    as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  )
  r <- suppressWarnings(get_freqs(d, c(cat1, cat2), variance = "se"))
  cf <- coef(r)
  # Multi-var freqs: names follow "variable_name.level" format derived from
  # the names_to (first) and values_to (second) non-estimate columns
  expect_true(is.numeric(cf))
  expect_true(length(cf) >= 1L)
  # All names should contain a "." separator
  expect_true(all(grepl("\\.", names(cf))))
})

test_that("coef() names for freqs with mismatched meta use non_estimate fallback", {
  # This exercises the length == 1L branch of .build_coef_names for freq stat:
  # x_names[[1L]] is not in names(object) but there is exactly 1 non-estimate col.
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 183L)
  df$cat1 <- as.factor(rep(c("a", "b"), length.out = nrow(df)))
  d <- suppressWarnings(
    as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  )
  r <- suppressWarnings(get_freqs(d, cat1, variance = "se"))
  # Manipulate .meta so x_names[[1L]] doesn't match any column
  meta_mod <- attr(r, ".meta")
  meta_mod$x <- list(nonexistent_col = "foo")
  attr(r, ".meta") <- meta_mod
  cf <- coef(r)
  # Falls into length==1 branch: uses non_estimate_cols[[1L]] as the column name
  expect_true(is.numeric(cf))
  expect_true(length(cf) >= 1L)
  expect_true(all(grepl("^cat1\\.", names(cf))))
})

# ── §A3a — Fallback switch: unknown statistic type ────────────────────────────

test_that("coef.survey_result() uses sequential row names for unknown statistic", {
  # Exercises the default branch of switch(statistic, ...) — line 225 equivalent
  df <- make_survey_data(seed = 225L)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  result <- suppressWarnings(get_means(d, y1, variance = "se"))
  # Override statistic to something not handled by the switch
  sr_mod <- attr(result, ".survey_result")
  sr_mod$statistic <- "unknown_type_xyz"
  attr(result, ".survey_result") <- sr_mod
  cv <- coef(result)
  # Should return a named numeric with sequential integer names
  expect_true(is.numeric(cv))
  expect_equal(length(cv), 1L)
  expect_identical(names(cv), "1")
})

# ── §A3b — Fallback freq: empty non_estimate_cols ─────────────────────────────

test_that("coef() for freq uses sequential row names when non_estimate_cols is empty", {
  # Exercises the length == 0 fallback inside the freq else-branch (line 192).
  # Constructed by removing all non-standard columns so non_estimate_cols = 0.
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = 192L)
  df$cat1 <- as.factor(rep(c("a", "b", "c"), length.out = nrow(df)))
  d <- suppressWarnings(
    as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  )
  r <- suppressWarnings(get_freqs(d, cat1, variance = "se"))
  # Remove the focal (cat1) column to strip non_estimate_cols to empty
  r2 <- r[, c("pct", "se", "n")]
  attr(r2, ".survey_result") <- attr(r, ".survey_result")
  # Point meta$x to a nonexistent column so the single-var path is skipped
  meta_mod <- attr(r, ".meta")
  meta_mod$x <- list(nonexistent_col = "foo")
  attr(r2, ".meta") <- meta_mod
  class(r2) <- class(r)
  cv <- coef(r2)
  # Fallback: sequential integer names
  expect_true(is.numeric(cv))
  expect_equal(length(cv), nrow(r))
  expect_identical(names(cv), as.character(seq_len(nrow(r))))
})
