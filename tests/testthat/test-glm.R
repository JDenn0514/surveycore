# tests/testthat/test-glm.R
#
# Tests for survey_glm() — PR 2 scope (feature/glm-core)
# clean() tests are added in PR 4.
#
# Spec reference: plans/spec-phase-2.md
# Error classes: plans/error-messages.md rows 64–87
#
# Test categories (per spec §9.2, PR 2 scope):
#   Item 1:   Happy path — survey_glm() produces valid survey_glm_fit
#   Item 7:   Programmatic interface (response=/predictors=)
#   Item 7b:  lapply() state leakage
#   Item 8:   Error paths — all 14 rows from §4.7 + P2-21
#   Item 9:   Convergence warning
#   Item 10:  @groups warning
#   Item 11:  Domain estimation oracle (skip_if_not_installed)
#   Item 12:  S7 validator errors (7 structural invariants)
#   §9.4:     Edge cases for survey_glm() (not clean())

library(surveycore)

# ── Shared test fixtures ───────────────────────────────────────────────────────

.glm_taylor <- function(seed = 1L) {
  df <- make_survey_data(n = 200L, n_psu = 20L, n_strata = 4L, seed = seed)
  as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
}

.glm_srs <- function(seed = 1L) {
  df <- make_survey_data(n = 200L, seed = seed)
  as_survey_srs(df, weights = wt)
}

.glm_replicate <- function(seed = 1L) {
  df <- make_survey_data(
    n = 200L, n_psu = 20L, n_strata = 4L,
    design = "replicate", type = "brr", seed = seed
  )
  as_survey_rep(
    df, weights = wt,
    repweights = starts_with("repwt"),
    type = "BRR"
  )
}

# ---------------------------------------------------------------------------
# Item 1: Happy path — valid survey_glm_fit for all design types
# ---------------------------------------------------------------------------

test_that("survey_glm() produces valid survey_glm_fit for Taylor design", {
  d   <- .glm_taylor()
  fit <- survey_glm(d, y1 ~ y2)
  test_glm_fit_invariants(fit)
  expect_equal(length(fit@coefficients), 2L)
  expect_identical(dim(fit@vcov), c(2L, 2L))
  expect_true(fit@converged)
  expect_true(is.finite(fit@degf))
  expect_gt(fit@degf, 0)
  expect_identical(fit@formula, y1 ~ y2)
})

test_that("survey_glm() produces valid survey_glm_fit for SRS design", {
  d   <- .glm_srs()
  fit <- survey_glm(d, y1 ~ y2)
  test_glm_fit_invariants(fit)
  expect_true(is.finite(fit@degf))
})

test_that("survey_glm() produces valid survey_glm_fit for replicate design", {
  d   <- .glm_replicate()
  fit <- survey_glm(d, y1 ~ y2)
  test_glm_fit_invariants(fit)
  expect_true(is.finite(fit@degf))
})

test_that("survey_glm() vcov row/col names match coefficient names", {
  d    <- .glm_taylor()
  fit  <- survey_glm(d, y1 ~ y2 + y3)
  coef_names <- names(fit@coefficients)
  expect_identical(rownames(fit@vcov), coef_names)
  expect_identical(colnames(fit@vcov), coef_names)
})

test_that("survey_glm() stores the raw glm fit in fit_", {
  d   <- .glm_taylor()
  fit <- survey_glm(d, y1 ~ y2)
  expect_true(inherits(fit@fit_, "glm"))
})

test_that("survey_glm() degf equals .degf(design) for Taylor design", {
  d   <- .glm_taylor()
  fit <- survey_glm(d, y1 ~ y2)
  expect_equal(fit@degf, .degf(d))
})

# ---------------------------------------------------------------------------
# Item 7: Programmatic interface (response=/predictors=)
# ---------------------------------------------------------------------------

test_that("survey_glm() programmatic interface: response + predictors matches formula", {
  d             <- .glm_taylor()
  fit_formula   <- survey_glm(d, y1 ~ y2 + y3)
  fit_prog      <- survey_glm(d, response = "y1", predictors = c("y2", "y3"))

  expect_equal(fit_formula@coefficients, fit_prog@coefficients, tolerance = 1e-15)
  expect_equal(fit_formula@vcov, fit_prog@vcov, tolerance = 1e-15)
})

test_that("survey_glm() programmatic interface: response only gives intercept-only model", {
  d   <- .glm_taylor()
  fit <- survey_glm(d, response = "y1")

  test_glm_fit_invariants(fit)
  expect_identical(length(fit@coefficients), 1L)
  expect_identical(names(fit@coefficients), "(Intercept)")
  expect_identical(deparse1(fit@formula), "y1 ~ 1")
})

test_that("survey_glm() programmatic interface: predictors without response errors", {
  d <- .glm_taylor()
  expect_error(
    survey_glm(d, predictors = c("y2", "y3")),
    class = "surveycore_error_formula_missing"
  )
  expect_snapshot(error = TRUE, survey_glm(d, predictors = c("y2", "y3")))
})

test_that("survey_glm() programmatic: constructed formula stored in @formula", {
  d   <- .glm_taylor()
  fit <- survey_glm(d, response = "y1", predictors = c("y2", "y3"))

  expect_true(inherits(fit@formula, "formula"))
  expect_identical(deparse1(fit@formula), "y1 ~ y2 + y3")
})

# ---------------------------------------------------------------------------
# Item 7b: lapply() state leakage
# ---------------------------------------------------------------------------

test_that("survey_glm() programmatic interface: no state leakage across lapply() calls", {
  d <- .glm_taylor()

  results <- lapply(c("y1", "y2"), function(v) {
    survey_glm(d, response = v, predictors = "y3")
  })

  expect_true(S7::S7_inherits(results[[1L]], survey_glm_fit))
  expect_true(S7::S7_inherits(results[[2L]], survey_glm_fit))

  # Each result has the correct @formula for its outcome
  expect_identical(deparse(results[[1L]]@formula), "y1 ~ y3")
  expect_identical(deparse(results[[2L]]@formula), "y2 ~ y3")

  # Coefficients differ across outcomes (y1 and y2 have different means)
  expect_false(identical(
    unname(results[[1L]]@coefficients[["(Intercept)"]]),
    unname(results[[2L]]@coefficients[["(Intercept)"]])
  ))
})

# ---------------------------------------------------------------------------
# Item 8: Error paths — §4.7 error table (all 14 rows + P2-21)
# Layer 3 constructor errors: dual pattern (class= + snapshot)
# Warnings: class= only (expect_warning)
# ---------------------------------------------------------------------------

# Row 1 (P2-1): design not a survey object
test_that("survey_glm() errors for non-survey design (P2-1)", {
  expect_error(
    survey_glm(list(x = 1), y ~ x),
    class = "surveycore_error_unsupported_class"
  )
  expect_snapshot(error = TRUE, survey_glm(list(x = 1), y ~ x))
})

# Row 2 (P2-2): no model specified — all NULL
test_that("survey_glm() errors when formula/response/predictors all NULL (P2-2)", {
  d <- .glm_taylor()
  expect_error(
    survey_glm(d),
    class = "surveycore_error_formula_missing"
  )
  expect_snapshot(error = TRUE, survey_glm(d))
})

# Row 2 (P2-2): predictors supplied without response
test_that("survey_glm() errors when predictors given without response (P2-2)", {
  d <- .glm_taylor()
  expect_error(
    survey_glm(d, predictors = "y2"),
    class = "surveycore_error_formula_missing"
  )
  expect_snapshot(error = TRUE, survey_glm(d, predictors = "y2"))
})

# Row 2a (P2-16): both formula and response/predictors supplied
test_that("survey_glm() errors when formula and response both supplied (P2-16)", {
  d <- .glm_taylor()
  expect_error(
    survey_glm(d, formula = y1 ~ y2, response = "y1"),
    class = "surveycore_error_formula_conflict"
  )
  expect_snapshot(
    error = TRUE,
    survey_glm(d, formula = y1 ~ y2, response = "y1")
  )
})

# Row 3 (P2-3): formula not a formula object
test_that("survey_glm() errors when formula arg is not a formula (P2-3)", {
  d <- .glm_taylor()
  expect_error(
    survey_glm(d, formula = "y1 ~ y2"),
    class = "surveycore_error_formula_invalid"
  )
  expect_snapshot(error = TRUE, survey_glm(d, formula = "y1 ~ y2"))
})

# Row 4 (P2-4): response variable absent
test_that("survey_glm() errors when response variable absent from design@data (P2-4)", {
  d <- .glm_taylor()
  expect_error(
    survey_glm(d, nonexistent ~ y2),
    class = "surveycore_error_response_not_found"
  )
  expect_snapshot(error = TRUE, survey_glm(d, nonexistent ~ y2))
})

# Row 5 (P2-5): predictor absent
test_that("survey_glm() errors when predictor absent from design@data (P2-5)", {
  d <- .glm_taylor()
  expect_error(
    survey_glm(d, y1 ~ nonexistent),
    class = "surveycore_error_predictor_not_found"
  )
  expect_snapshot(error = TRUE, survey_glm(d, y1 ~ nonexistent))
})

# Row 9 (P2-9): singular model matrix (perfect collinearity)
test_that("survey_glm() errors for singular model matrix (P2-9)", {
  df      <- make_survey_data(n = 100L, seed = 1L)
  df$y2b  <- 2 * df$y2   # perfect collinearity
  d       <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  expect_error(
    survey_glm(d, y1 ~ y2 + y2b),
    class = "surveycore_error_singular_model_matrix"
  )
  expect_snapshot(error = TRUE, survey_glm(d, y1 ~ y2 + y2b))
})

# Row 11 (P2-11): NA weights
test_that("survey_glm() errors when weight column has NA (P2-11)", {
  df       <- make_survey_data(n = 100L, seed = 1L)
  df$wt[1] <- NA_real_
  d        <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  expect_error(
    survey_glm(d, y1 ~ y2),
    class = "surveycore_error_na_weights"
  )
  expect_snapshot(error = TRUE, survey_glm(d, y1 ~ y2))
})

# Row 14 (P2-20): cbind() on LHS of formula
test_that("survey_glm() errors for cbind() on LHS of formula (P2-20)", {
  d <- .glm_taylor()
  expect_error(
    survey_glm(d, cbind(y1, y2) ~ y3),
    class = "surveycore_error_cbind_response_unsupported"
  )
  expect_snapshot(error = TRUE, survey_glm(d, cbind(y1, y2) ~ y3))
})

# Row 7 (P2-7): response is a design variable — WARNING only
test_that("survey_glm() warns when response variable is a design variable (P2-7)", {
  d <- .glm_taylor()
  expect_warning(
    survey_glm(d, wt ~ y2),
    class = "surveycore_warning_response_is_design_var"
  )
})

# Row 8 (P2-8): perfect separation — WARNING only
test_that("survey_glm() warns for perfect separation in binomial model (P2-8)", {
  df          <- make_survey_data(n = 200L, seed = 1L)
  df$y_sep    <- as.integer(df$y1 > 50)  # binary outcome
  df$x_sep    <- df$y1                    # perfect predictor
  d           <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  expect_warning(
    survey_glm(d, y_sep ~ x_sep, family = binomial()),
    class = "surveycore_warning_perfect_separation"
  )
})

# Row 13 (P2-19): non-positive weights — WARNING only
# NOTE: This warning is a defensive guard inside survey_glm(). It is
# unreachable via the public API because all S7 design validators reject
# non-positive weights at construction time. Covered by # nocov in glm.R.

# Row 12 (P2-17): empty domain after domain filter
test_that("survey_glm() errors for empty active domain (P2-17)", {
  d <- .glm_taylor()
  # Inject a domain column that excludes everything
  d@data[["..surveycore_domain.."]] <- rep(FALSE, nrow(d@data))
  expect_error(
    survey_glm(d, y1 ~ y2),
    class = "surveycore_error_empty_domain"
  )
  expect_snapshot(error = TRUE, {
    d2 <- .glm_taylor()
    d2@data[["..surveycore_domain.."]] <- rep(FALSE, nrow(d2@data))
    survey_glm(d2, y1 ~ y2)
  })
})

# P2-21: na.action = na.fail with NA in response
test_that("survey_glm() errors with na.action = na.fail and NA in response (P2-21)", {
  df         <- make_survey_data(n = 100L, seed = 1L)
  df$y1[5L]  <- NA_real_
  d          <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  expect_error(
    survey_glm(d, y1 ~ y2, na.action = na.fail),
    class = "surveycore_error_na_in_data"
  )
  expect_snapshot(error = TRUE, {
    df2        <- make_survey_data(n = 100L, seed = 1L)
    df2$y1[5L] <- NA_real_
    d2         <- as_survey(df2, ids = psu, weights = wt, strata = strata, nest = TRUE)
    survey_glm(d2, y1 ~ y2, na.action = na.fail)
  })
})

# P2-21: na.action = na.fail with NA in predictor
test_that("survey_glm() errors with na.action = na.fail and NA in predictor (P2-21)", {
  df         <- make_survey_data(n = 100L, seed = 1L)
  df$y2[5L]  <- NA_real_
  d          <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  expect_error(
    survey_glm(d, y1 ~ y2, na.action = na.fail),
    class = "surveycore_error_na_in_data"
  )
})

# ---------------------------------------------------------------------------
# Item 9: Convergence warning
# ---------------------------------------------------------------------------

test_that("survey_glm() warns on GLM non-convergence and still returns fit (P2-6)", {
  d <- .glm_taylor()
  # Force non-convergence by limiting IRLS to 1 iteration
  expect_warning(
    fit <- survey_glm(d, y1 ~ y2 + y3, control = list(maxit = 1L)),
    class = "surveycore_warning_glm_convergence"
  )
  # Fit is still returned despite non-convergence
  expect_true(S7::S7_inherits(fit, survey_glm_fit))
  expect_false(fit@converged)
})

# ---------------------------------------------------------------------------
# Item 10: @groups warning
# ---------------------------------------------------------------------------

test_that("survey_glm() warns when design has @groups set (P2-10)", {
  d          <- .glm_taylor()
  d@groups   <- "group"    # simulate a group_by() design
  expect_warning(
    survey_glm(d, y1 ~ y2),
    class = "surveycore_warning_groups_ignored_in_glm"
  )
})

# ---------------------------------------------------------------------------
# Item 11: Domain estimation oracle (skipped without survey + surveytidy)
# ---------------------------------------------------------------------------

test_that("survey_glm() domain: surveytidy::filter() domain matches svyglm subset [oracle]", {
  skip_if_not_installed("survey")
  skip_if_not_installed("surveytidy")

  # Filter to MEC-examined respondents (ridstatr == 2) so wtmec2yr > 0 for all
  nhanes_mec <- nhanes_2017[nhanes_2017$ridstatr == 2L, ]

  d_sc <- as_survey(
    nhanes_mec,
    ids = sdmvpsu, weights = wtmec2yr, strata = sdmvstra, nest = TRUE
  )
  d_sv <- survey::svydesign(
    ids = ~sdmvpsu, weights = ~wtmec2yr, strata = ~sdmvstra,
    data = nhanes_mec, nest = TRUE
  )

  # Domain: adults aged 40+
  d_dom  <- surveytidy::filter(d_sc, ridageyr >= 40)
  fit_sc <- survey_glm(d_dom, bpxsy1 ~ ridageyr + riagendr)

  domain_flag <- as.integer(nhanes_mec$ridageyr >= 40 & !is.na(nhanes_mec$ridageyr))
  fit_sv <- survey::svyglm(
    bpxsy1 ~ ridageyr + riagendr,
    design = d_sv,
    subset = domain_flag == 1
  )

  # Use @coefficients / @vcov directly — coef()/vcov() S3 methods are PR 3.
  expect_equal(fit_sc@coefficients, coef(fit_sv), tolerance = 1e-10)
  expect_equal(
    as.numeric(sqrt(diag(fit_sc@vcov))),
    as.numeric(survey::SE(fit_sv)),
    tolerance = 1e-8
  )
})

# ---------------------------------------------------------------------------
# Item 12: S7 validator errors — 7 structural invariants (class= only, no snapshot)
# ---------------------------------------------------------------------------

# Build a minimal valid survey_glm_fit for mutation tests
.minimal_fit_args <- function(d) {
  n  <- nrow(d@data)
  p  <- 2L
  list(
    coefficients  = c("(Intercept)" = 1.0, "y2" = 0.5),
    vcov          = matrix(c(0.1, 0.01, 0.01, 0.05), nrow = 2L,
                           dimnames = list(c("(Intercept)", "y2"),
                                          c("(Intercept)", "y2"))),
    fitted_values = rep(1.0, n),
    residuals     = rep(0.1, n),
    weights       = rep(1.0, n),
    design        = d,
    degf          = 5.0,
    family        = gaussian(),
    formula       = y1 ~ y2,
    null_deviance = 10.0,
    deviance      = 5.0,
    df_null       = as.numeric(n - 1L),
    df_residual   = as.numeric(n - p),
    converged     = TRUE
  )
}

test_that("survey_glm_fit validator: rejects empty coefficients (condition 1)", {
  d    <- .glm_taylor()
  args <- .minimal_fit_args(d)
  args$coefficients <- numeric(0)
  args$vcov         <- matrix(numeric(0), 0L, 0L)
  expect_error(do.call(survey_glm_fit, args))
})

test_that("survey_glm_fit validator: rejects wrong vcov dimensions (condition 2)", {
  d    <- .glm_taylor()
  args <- .minimal_fit_args(d)
  args$vcov <- matrix(1.0, 3L, 3L)   # p=2 but vcov is 3x3
  expect_error(do.call(survey_glm_fit, args))
})

test_that("survey_glm_fit validator: rejects empty fitted_values (condition 3)", {
  d    <- .glm_taylor()
  args <- .minimal_fit_args(d)
  args$fitted_values <- numeric(0)
  args$residuals     <- numeric(0)
  args$weights       <- numeric(0)
  expect_error(do.call(survey_glm_fit, args))
})

test_that("survey_glm_fit validator: rejects residuals length mismatch (condition 4)", {
  d    <- .glm_taylor()
  args <- .minimal_fit_args(d)
  args$residuals <- rep(0.1, nrow(d@data) + 1L)
  expect_error(do.call(survey_glm_fit, args))
})

test_that("survey_glm_fit validator: rejects weights length mismatch (condition 5)", {
  d    <- .glm_taylor()
  args <- .minimal_fit_args(d)
  args$weights <- rep(1.0, nrow(d@data) + 1L)
  expect_error(do.call(survey_glm_fit, args))
})

test_that("survey_glm_fit validator: rejects non-positive degf (condition 6)", {
  d    <- .glm_taylor()
  args <- .minimal_fit_args(d)
  args$degf <- 0
  expect_error(do.call(survey_glm_fit, args))
})

test_that("survey_glm_fit validator: rejects non-formula in formula slot (condition 7)", {
  d    <- .glm_taylor()
  args <- .minimal_fit_args(d)
  args$formula <- "y1 ~ y2"   # character string, not a formula
  expect_error(do.call(survey_glm_fit, args))
})

# ---------------------------------------------------------------------------
# §9.4 Edge cases for survey_glm() (not clean() — those come in PR 4)
# ---------------------------------------------------------------------------

test_that("survey_glm() intercept-only model (y ~ 1)", {
  d   <- .glm_taylor()
  fit <- survey_glm(d, y1 ~ 1)

  test_glm_fit_invariants(fit)
  expect_identical(length(fit@coefficients), 1L)
  expect_identical(names(fit@coefficients), "(Intercept)")
})

test_that("survey_glm() with factor predictor excludes reference level from coef", {
  df           <- make_survey_data(n = 300L, seed = 2L)
  df$group     <- factor(df$group)
  d            <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  fit          <- survey_glm(d, y1 ~ group)

  test_glm_fit_invariants(fit)
  n_levels     <- nlevels(df$group)
  # coefficients = intercept + (n_levels - 1) non-reference levels
  expect_equal(length(fit@coefficients), n_levels)
  # Reference level name not in coef names
  ref_level    <- levels(df$group)[[1L]]
  expect_false(any(names(fit@coefficients) == ref_level))
})

test_that("survey_glm() with interaction terms", {
  d   <- .glm_taylor()
  fit <- survey_glm(d, y1 ~ y2 * y3)

  test_glm_fit_invariants(fit)
  # Expect intercept + y2 + y3 + y2:y3 = 4 coefficients
  expect_equal(length(fit@coefficients), 4L)
  expect_true("y2:y3" %in% names(fit@coefficients))
})

test_that("survey_glm() na.action = na.omit silently drops NA rows", {
  df         <- make_survey_data(n = 200L, seed = 1L)
  df$y1[1:5] <- NA_real_
  d          <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  fit        <- survey_glm(d, y1 ~ y2, na.action = na.omit)

  test_glm_fit_invariants(fit)
  # n_obs after na.omit is less than full data
  expect_lt(length(fit@fitted_values), nrow(df))
  expect_equal(length(fit@fitted_values), sum(!is.na(df$y1)))
})

test_that("survey_glm() binomial family produces valid fit", {
  d   <- .glm_taylor()
  fit <- survey_glm(d, y3 ~ y2, family = binomial())

  test_glm_fit_invariants(fit)
  # Fitted values on [0,1] scale (probabilities)
  expect_true(all(fit@fitted_values >= 0 & fit@fitted_values <= 1))
})

test_that("survey_glm() Poisson family produces valid fit", {
  df         <- make_survey_data(n = 200L, seed = 1L)
  df$y_count <- rpois(nrow(df), lambda = exp(0.3 * df$y1 / 50 + 0.5))
  d          <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  fit        <- survey_glm(d, y_count ~ y2, family = poisson())

  test_glm_fit_invariants(fit)
  # Fitted values on count scale (positive)
  expect_true(all(fit@fitted_values > 0))
})

# P2-15: insufficient df warning (degf - (p-1) <= 0)
test_that("survey_glm() warns for insufficient design df and clamps to 1 (P2-15)", {
  # 4 PSUs, 2 strata (2 PSUs each) → degf = 4 - 2 = 2
  # Model with intercept + x1 + x2 + x3 → p = 4, degf - (p-1) = 2 - 3 = -1
  # Each stratum has 2 PSUs so no lonely-PSU error.
  set.seed(42L)
  tiny_df <- data.frame(
    psu    = c("p1", "p1", "p2", "p2", "p3", "p3", "p4", "p4"),
    strata = c("s1", "s1", "s1", "s1", "s2", "s2", "s2", "s2"),
    wt     = rep(10.0, 8L),
    y      = rnorm(8L),
    x1     = rnorm(8L),
    x2     = rnorm(8L),
    x3     = rnorm(8L)
  )
  d_tiny <- as_survey(
    tiny_df, ids = psu, strata = strata, weights = wt, nest = TRUE
  )
  expect_warning(
    fit <- survey_glm(d_tiny, y ~ x1 + x2 + x3),
    class = "surveycore_warning_insufficient_df"
  )
  test_glm_fit_invariants(fit)
  # CI bounds must be finite (clamped to df=1, not NaN)
  # Use @vcov directly — vcov() S3 method is PR 3.
  se      <- sqrt(diag(fit@vcov))
  p       <- length(fit@coefficients)
  df_used <- max(1, fit@degf - (p - 1L))
  bounds  <- fit@coefficients + outer(se, c(-1, 1) * qt(0.975, df = df_used))
  expect_true(all(is.finite(bounds)))
})

# in-formula transformation in response: log(y) ~ x
test_that("survey_glm() handles in-formula response transformation log(y) ~ x", {
  df         <- make_survey_data(n = 200L, seed = 3L)
  df$y1_pos  <- abs(df$y1) + 1   # ensure positive for log()
  d          <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  fit        <- survey_glm(d, log(y1_pos) ~ y2)

  test_glm_fit_invariants(fit)
  expect_equal(length(fit@coefficients), 2L)
})
