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
  expect_true(isS3stdGeneric(surveycore::SE))
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

test_that("confint() matches survey::confint.svystat for NHANES mean [numerical]", {
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
  sc_ci <- confint(sc_est)
  sv_ci <- stats::confint(sv_est)
  expect_equal(as.numeric(sc_ci), as.numeric(sv_ci), tolerance = 1e-6)
})

test_that("coef() + SE() match survey::svytotal for acs_pums_wy [numerical]", {
  skip_if_not_installed("survey")
  # acs_pums_wy uses puma as ids, st as strata, pwgtp as weights
  d_sc <- suppressWarnings(
    as_survey(acs_pums_wy, ids = puma, weights = pwgtp, strata = st)
  )
  d_sv <- survey::svydesign(
    ids = ~puma,
    weights = ~pwgtp,
    strata = ~st,
    data = acs_pums_wy
  )
  sc_tot <- suppressWarnings(get_totals(d_sc, agep, variance = "se"))
  sv_tot <- survey::svytotal(~agep, d_sv, na.rm = TRUE)
  expect_equal(
    as.numeric(coef(sc_tot)),
    as.numeric(coef(sv_tot)),
    tolerance = 1e-6
  )
  # survey::SE may have unnamed output; compare as numeric
  expect_equal(
    as.numeric(SE(sc_tot)),
    as.numeric(survey::SE(sv_tot)),
    tolerance = 1e-6
  )
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
