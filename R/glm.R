# R/glm.R
#
# Phase 2: Survey-weighted GLM
#
# Contents:
#   survey_glm_fit       — S7 class definition + validator
#   survey_glm()         — constructor (Steps 1–6)
#   .glm_score()         — per-observation score matrix (n × p)
#   .glm_sandwich_vcov() — bread · meat · bread sandwich assembler
#   .taylor_var_score_matrix()  — Taylor variance of p-dimensional score total
#   .glm_vcov_dispatch() — variance dispatch for all 5 design classes
#   .glm_degrees_of_freedom()   — design-based residual df (with clamping)
#
# Spec: plans/spec-phase-2.md §II–IV, §VIII
# Error classes: plans/error-messages.md rows 65–87

# ===========================================================================
# Section 1: survey_glm_fit S7 class
# ===========================================================================

#' Survey-Weighted GLM Fit Object
#'
#' S7 class produced by [survey_glm()]. Holds all regression output from a
#' survey-weighted generalised linear model: design-based coefficient
#' estimates, variance-covariance matrix, fitted values, residuals, and
#' model metadata.
#'
#' @param coefficients Named numeric vector of length `p`.
#' @param vcov `p × p` design-based variance-covariance matrix.
#' @param fitted_values Numeric vector of length `n` (response scale).
#' @param residuals Working residuals from IRLS, length `n`.
#' @param weights Survey weights used in fitting, length `n`.
#' @param design The original [survey_base] survey design object.
#' @param degf Design degrees of freedom (positive scalar).
#' @param family GLM family object (e.g. `gaussian()`, `binomial()`).
#' @param formula Model formula.
#' @param null_deviance Null model deviance.
#' @param deviance Residual deviance.
#' @param df_null Classical null df (`fit$df.null` from `stats::glm()`).
#' @param df_residual Classical residual df (`fit$df.residual`, i.e. `n - p`).
#'   Used for the deviance display; **not** the design-based residual df.
#' @param converged Logical; whether IRLS converged.
#' @param call The `survey_glm()` call (language object or `NULL`).
#' @param fit_ Internal raw `stats::glm()` result; `NULL` after serialisation.
#'
#' @return A `survey_glm_fit` object.
#'
#' @seealso [survey_glm()] to create a `survey_glm_fit`.
#' @family constructors
#' @export
survey_glm_fit <- S7::new_class(
  "survey_glm_fit",
  properties = list(
    coefficients  = S7::new_property(S7::class_numeric),
    vcov          = S7::new_property(S7::class_any),
    fitted_values = S7::new_property(S7::class_numeric),
    residuals     = S7::new_property(S7::class_numeric),
    weights       = S7::new_property(S7::class_numeric),
    design        = S7::new_property(class = survey_base),
    degf          = S7::new_property(S7::class_numeric),
    family        = S7::new_property(S7::class_list),
    formula       = S7::new_property(default = NULL),
    null_deviance = S7::new_property(S7::class_numeric),
    deviance      = S7::new_property(S7::class_numeric),
    df_null       = S7::new_property(S7::class_numeric),
    df_residual   = S7::new_property(S7::class_numeric),
    converged     = S7::new_property(S7::class_logical),
    call          = S7::new_property(default = NULL),
    fit_          = S7::new_property(default = NULL)
  ),
  validator = function(self) {
    p <- length(self@coefficients)
    if (p == 0L) {
      "coefficients must be non-empty"
    } else if (!identical(dim(self@vcov), c(p, p))) {
      paste0("vcov must be ", p, "x", p,
             " (same dimension as coefficients)")
    } else if (length(self@fitted_values) == 0L) {
      "fitted_values must be non-empty"
    } else if (length(self@residuals) != length(self@fitted_values)) {
      "residuals and fitted_values must have the same length"
    } else if (length(self@weights) != length(self@fitted_values)) {
      "weights and fitted_values must have the same length"
    } else if (length(self@degf) != 1L || self@degf <= 0) {
      "degf must be a single positive number"
    } else if (!is.null(self@formula) &&
               !inherits(self@formula, "formula")) {
      "formula must be a formula object or NULL"
    } else {
      NULL
    }
  }
)


# ===========================================================================
# Section 2: Internal helpers
# ===========================================================================

# ── .glm_score() ──────────────────────────────────────────────────────────────
#
# Compute the per-observation score matrix for the Binder (1983) sandwich.
# Score for obs i: u_i = w_i * x_i * e_i, where e_i = working residual.
#
# Working residuals from the final IRLS step are the correct choice for
# all GLM families. For Gaussian/identity they equal response residuals;
# for binomial and Poisson they differ — using response residuals here
# would produce wrong SEs.
#
# @param fit    A stats::glm() result (fitted model with survey weights).
# @param design The survey_base design object (for weights).
# @param row_mask Integer or logical vector indexing the rows of design@data
#   that were used in fitting. NULL means all rows were used.
# @param domain_mask Logical vector length nrow(design@data). TRUE = in-domain.
# @return n × p matrix (full design row count); zero rows for out-of-domain
#   or NA-excluded observations.
#' @noRd
.glm_score <- function(fit, design, row_mask = NULL, domain_mask = NULL) {
  n_full <- nrow(design@data)
  p      <- length(stats::coef(fit))
  w_full <- design@data[[design@variables$weights]]

  # Build full-design model matrix (n_full × p), zero for excluded rows
  mm_full  <- matrix(0.0, nrow = n_full, ncol = p)
  res_full <- numeric(n_full)

  if (is.null(row_mask)) {
    row_idx <- seq_len(n_full)
  } else {
    row_idx <- row_mask
  }

  mm_fit  <- stats::model.matrix(fit)   # n_fit × p
  res_fit <- stats::residuals(fit, type = "working")  # n_fit

  mm_full[row_idx, ]  <- mm_fit
  res_full[row_idx]   <- res_fit

  # Apply domain mask: out-of-domain contributions are zero
  if (!is.null(domain_mask)) {
    zero_rows              <- !domain_mask
    mm_full[zero_rows, ]   <- 0.0
    res_full[zero_rows]    <- 0.0
  }

  # u_i = w_i * x_i * e_i  (element-wise; broadcasting weight over p cols)
  mm_full * (w_full * res_full)
}


# ── .glm_sandwich_vcov() ──────────────────────────────────────────────────────
#
# Assemble the sandwich variance-covariance matrix:
#   Var(β̂) = bread · meat · bread
#
# bread = summary(fit)$cov.unscaled = (X'W̃X)⁻¹ from the IRLS information
# matrix — correct for ALL GLM families (uses working weights, not just
# survey weights). For Gaussian/identity, reduces to (X'WX)⁻¹.
#
# @param meat_vcov p × p meat matrix = Var_design(Σ u_i).
# @param bread     p × p matrix from summary(fit)$cov.unscaled.
# @return p × p variance-covariance matrix.
#' @noRd
.glm_sandwich_vcov <- function(meat_vcov, bread) {
  bread %*% meat_vcov %*% bread
}


# ── .taylor_var_score_matrix() ────────────────────────────────────────────────
#
# Compute the design-based variance of the p-dimensional score total vector
# for a Taylor series design, using the Phase 0 variance machinery.
#
# Passes the n × p score matrix to .svy_recvar() treating each column as a
# survey-weighted total. Returns the p × p variance (meat) matrix.
#
# @param score_matrix n × p score matrix from .glm_score() (pre-weighted).
# @param design       A survey_taylor object.
# @return p × p meat matrix.
#' @noRd
.taylor_var_score_matrix <- function(score_matrix, design) {
  vars <- design@variables
  data <- design@data
  n    <- nrow(data)

  strata_id <- if (!is.null(vars$strata)) {
    data[[vars$strata]]
  } else {
    rep(1L, n)
  }

  psu_id <- if (!is.null(vars$ids)) {
    raw_ids <- data[[vars$ids[[1L]]]]
    if (isTRUE(vars$nest) && !is.null(vars$strata)) {
      as.integer(interaction(strata_id, raw_ids, drop = TRUE))
    } else {
      raw_ids
    }
  } else {
    seq_len(n)
  }

  clusters_mat <- matrix(psu_id, ncol = 1L)
  strata_mat   <- matrix(strata_id, ncol = 1L)

  psu_per_stratum <- tapply(
    psu_id, strata_id, function(ps) length(unique(ps))
  )
  sampsize_vec <- as.integer(psu_per_stratum[as.character(strata_id)])
  sampsize_mat <- matrix(sampsize_vec, ncol = 1L)

  popsize_mat <- if (!is.null(vars$fpc)) {
    fpc_vals <- data[[vars$fpc]]
    if (any(fpc_vals > 1L, na.rm = TRUE)) {
      matrix(as.numeric(fpc_vals), ncol = 1L)
    } else {
      matrix(as.numeric(sampsize_vec / fpc_vals), ncol = 1L)
    }
  } else {
    NULL
  }

  fpcs       <- list(sampsize = sampsize_mat, popsize = popsize_mat)
  lonely.psu <- getOption("survey.lonely.psu", "remove")

  .svy_recvar(
    score_matrix, clusters_mat, strata_mat, fpcs,
    lonely.psu = lonely.psu
  )
}


# ── .twophase_var_score_matrix() ──────────────────────────────────────────────
#
# Compute the p × p meat matrix for a twophase design by calling
# .twophasevar() for each pair of score columns using the polarization
# identity: Cov(A,B) = (Var(A+B) - Var(A) - Var(B)) / 2.
#
# @param score_matrix n × p matrix from .glm_score().
# @param design       A survey_twophase object.
# @return p × p meat matrix.
#' @noRd
.twophase_var_score_matrix <- function(score_matrix, design) {
  p    <- ncol(score_matrix)
  meat <- matrix(0.0, p, p)

  # Diagonal: Var(col j)
  for (j in seq_len(p)) {
    meat[j, j] <- .twophasevar(score_matrix[, j], design)
  }

  # Off-diagonal: use polarization identity
  if (p > 1L) {
    for (j in seq_len(p - 1L)) {
      for (k in (j + 1L):p) {
        sum_jk      <- score_matrix[, j] + score_matrix[, k]
        cov_jk      <- (.twophasevar(sum_jk, design) -
                         meat[j, j] - meat[k, k]) / 2
        meat[j, k]  <- cov_jk
        meat[k, j]  <- cov_jk
      }
    }
  }
  meat
}


# ── .glm_vcov_dispatch() ──────────────────────────────────────────────────────
#
# Dispatch to the correct variance estimation path based on design class.
# Returns the p × p design-based variance-covariance matrix for coefficients.
#
# @param fit         stats::glm() result.
# @param design      Survey design object.
# @param row_mask    Integer index of rows used in fitting (from na.action).
# @param domain_mask Logical full-length domain indicator.
# @return p × p matrix.
#' @noRd
.glm_vcov_dispatch <- function(fit, design, row_mask, domain_mask) {
  bread <- summary(fit)$cov.unscaled

  if (S7::S7_inherits(design, survey_taylor)) {
    score_mat <- .glm_score(fit, design, row_mask, domain_mask)
    meat      <- .taylor_var_score_matrix(score_mat, design)
    .glm_sandwich_vcov(meat, bread)

  } else if (S7::S7_inherits(design, survey_twophase)) {
    score_mat <- .glm_score(fit, design, row_mask, domain_mask)
    meat      <- .twophase_var_score_matrix(score_mat, design)
    .glm_sandwich_vcov(meat, bread)

  } else if (S7::S7_inherits(design, survey_replicate)) {
    .glm_replicate_vcov(fit, design, row_mask, domain_mask)

  } else {
    # survey_srs, survey_calibrated — SRS sandwich
    .glm_srs_vcov(fit, design, row_mask, domain_mask)
  }
}


# ── .glm_replicate_vcov() ─────────────────────────────────────────────────────
#
# Replicate-weight variance for GLM:
#   1. For each replicate r: refit GLM with repweights_r → β̂_r
#   2. Deviation: d_r = β̂_r − β̂
#   3. Var(β̂) = Σ_r c_r * d_r %*% t(d_r)
#
# If a replicate refit fails to converge, warn and use d_r = 0 (zero
# deviation), per spec §8.3.
#
# @param fit         Full-sample stats::glm() result.
# @param design      A survey_replicate object.
# @param row_mask    Rows used in full-sample fit.
# @param domain_mask Domain membership (for in-domain-only refitting).
# @return p × p matrix.
#' @noRd
.glm_replicate_vcov <- function(fit, design, row_mask, domain_mask) {
  vars    <- design@variables
  data    <- design@data
  rep_mat <- as.matrix(data[, vars$repweights, drop = FALSE])
  n_rep   <- ncol(rep_mat)
  coef_0  <- stats::coef(fit)
  p       <- length(coef_0)

  scale   <- vars$scale
  rscales <- if (!is.null(vars$rscales)) vars$rscales else rep(1.0, n_rep)
  mse     <- isTRUE(vars$mse)

  # Determine fitting rows (intersection of row_mask and domain_mask)
  if (is.null(row_mask)) {
    fit_rows <- seq_len(nrow(data))
  } else {
    fit_rows <- row_mask
  }
  # Domain restriction (already applied for main fit; refit on same rows)
  if (!is.null(domain_mask)) {
    fit_rows <- fit_rows[domain_mask[fit_rows]]
  }

  fit_data <- data[fit_rows, , drop = FALSE]

  # Accumulate variance: sigma = scale * Σ rscales_r * d_r d_r'
  sigma    <- matrix(0.0, p, p)
  center   <- if (mse) coef_0 else NULL
  rep_coefs <- matrix(NA_real_, nrow = n_rep, ncol = p)

  for (r in seq_len(n_rep)) {
    wr    <- rep_mat[fit_rows, r]
    fit_r <- tryCatch(
      suppressWarnings(
        stats::glm(
          formula  = stats::formula(fit),
          family   = stats::family(fit),
          data     = fit_data,
          weights  = wr,
          na.action = stats::na.omit
        )
      ),
      error = function(e) NULL
    )

    if (is.null(fit_r) || !fit_r$converged) {
      if (!is.null(fit_r) && !fit_r$converged) {
        cli::cli_warn(
          c(
            "!" = "Replicate {r} of {n_rep} did not converge.",
            "i" = "Using zero deviation for this replicate."
          ),
          class = "surveycore_warning_glm_convergence"
        )
      }
      rep_coefs[r, ] <- coef_0  # zero deviation
    } else {
      rep_coefs[r, ] <- stats::coef(fit_r)
    }
  }

  if (!mse) {
    ok     <- !apply(rep_coefs, 1L, anyNA)
    center <- colMeans(rep_coefs[ok & rscales > 0, , drop = FALSE])
  }

  for (r in seq_len(n_rep)) {
    d_r    <- rep_coefs[r, ] - center
    sigma  <- sigma + rscales[r] * outer(d_r, d_r)
  }
  sigma * scale
}


# ── .glm_srs_vcov() ───────────────────────────────────────────────────────────
#
# SRS score-based sandwich (also used for survey_calibrated):
#   meat = N² * (1 - f) / n * var(score_matrix)
#
# Uses the full p × p sample covariance matrix of the score columns —
# off-diagonal terms are required when bread is non-diagonal (multiple
# predictors). Using only the diagonal would produce wrong SEs.
#
# N is approximated from the weight sum when not supplied explicitly via FPC.
#
# @param fit         Full-sample stats::glm() result.
# @param design      A survey_srs or survey_calibrated object.
# @param row_mask    Rows used in fitting.
# @param domain_mask Domain indicator.
# @return p × p matrix.
#' @noRd
.glm_srs_vcov <- function(fit, design, row_mask, domain_mask) {
  bread     <- summary(fit)$cov.unscaled
  score_mat <- .glm_score(fit, design, row_mask, domain_mask)

  n_full   <- nrow(design@data)
  w_full   <- design@data[[design@variables$weights]]
  N_approx <- sum(w_full)

  # Use only rows that contributed to the fit for variance estimation
  fit_rows <- if (is.null(row_mask)) seq_len(n_full) else row_mask
  if (!is.null(domain_mask)) {
    fit_rows <- fit_rows[domain_mask[fit_rows]]
  }
  n_fit <- length(fit_rows)

  # Sampling fraction f = n/N
  vars <- design@variables
  fpc_var <- if (S7::S7_inherits(design, survey_srs)) vars$fpc else NULL
  if (!is.null(fpc_var) && !is.null(fpc_var)) {
    fpc_val <- design@data[[fpc_var]][fit_rows[1L]]
    f <- if (fpc_val > 1) n_fit / fpc_val else fpc_val
  } else {
    f <- n_fit / N_approx
  }

  # p × p sample covariance of score columns (includes off-diagonals)
  score_used <- score_mat[fit_rows, , drop = FALSE]
  meat       <- N_approx^2 * (1 - f) / n_fit * stats::var(score_used)

  .glm_sandwich_vcov(meat, bread)
}


# ── .glm_degrees_of_freedom() ─────────────────────────────────────────────────
#
# Compute design-based degf and warn if clamping is needed.
#
# @param design     Survey design object.
# @param n_coef     Total coefficients p (including intercept).
# @return Numeric(1): max(1, .degf(design) - (p - 1)).
#' @noRd
.glm_degrees_of_freedom <- function(design, n_coef) {
  degf_raw  <- .degf(design)
  df_resid  <- degf_raw - (n_coef - 1L)
  if (df_resid <= 0) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "Design degrees of freedom (", degf_raw, ") minus model ",
          "parameters (", n_coef - 1L, ") is \u2264 0. ",
          "Clamping {.code df_residual = 1}."
        ),
        "i" = "CI bounds and p-values are conservative."
      ),
      class = "surveycore_warning_insufficient_df"
    )
  }
  degf_raw  # store the raw degf; clamping happens in .glm_confint()
}


# ===========================================================================
# Section 3: survey_glm() constructor
# ===========================================================================

#' Fit a Survey-Weighted Generalised Linear Model
#'
#' Fits a GLM to survey data, producing design-based coefficient estimates
#' and variance-covariance matrix via the Binder (1983) sandwich estimator.
#' All five surveycore design classes are supported.
#'
#' @param design A survey design object created by [as_survey()],
#'   [as_survey_rep()], [as_survey_twophase()], [as_survey_srs()], or
#'   [as_survey_calibrated()].
#' @param formula A model formula in standard R notation
#'   (e.g. `y ~ x1 + x2`). Mutually exclusive with `response`/`predictors`.
#'   If `NULL` and `response` is also `NULL`, errors with
#'   `surveycore_error_formula_missing`.
#' @param response Character string naming the outcome variable.
#'   Programmatic alternative to `formula`. Mutually exclusive with
#'   `formula`. Use with `predictors` to build a model formula via
#'   `reformulate(predictors, response)`. Suitable for `lapply()` iteration.
#' @param predictors Character vector of predictor variable names. Used with
#'   `response` to build the model formula. If `response` is supplied and
#'   `predictors` is `NULL`, an intercept-only model is fitted.
#' @param family A GLM family object specifying the error distribution and
#'   link function. Default `gaussian()`. Any family accepted by
#'   [stats::glm()] is supported. For `binomial()` and `quasibinomial()`
#'   families, the "non-integer #successes" warning is suppressed because
#'   survey weights are non-integer by design.
#' @param na.action How to handle `NA` values in the model frame.
#'   Default `na.omit` (silently drops rows with any `NA` in model
#'   variables). `na.fail` errors with `surveycore_error_na_in_data` listing
#'   the offending columns and NA counts. Note: `na.action` applies only to
#'   model frame variables; survey weights are validated separately.
#' @param start Starting values for the coefficient vector.
#' @param etastart Starting values for the linear predictor.
#' @param mustart Starting values for the mean.
#' @param control A list of GLM control parameters passed to
#'   [stats::glm.control()].
#'
#' @return A [survey_glm_fit] S7 object.
#'
#' @details
#' **Variance estimation:** Uses the Binder (1983) sandwich estimator, which
#' decomposes into per-observation score vectors passed to the Phase 0
#' variance machinery. The bread `(X'W̃X)⁻¹` accounts for IRLS working
#' weights and is correct for all GLM families including binomial and
#' Poisson.
#'
#' **`binomial()` family:** Wraps the `stats::glm()` call in
#' `suppressWarnings()` to suppress the "non-integer #successes" warning
#' that fires for every survey-weighted binomial model.
#'
#' **Domain estimation:** Use `surveytidy::filter()` before calling
#' `survey_glm()`. The GLM is fit on in-domain rows only; variance
#' estimation uses the full design for correct design-based SEs.
#'
#' **Multinomial response:** `cbind()` on the LHS of `formula` is not
#' supported. Multinomial logistic regression is deferred to a later phase.
#'
#' @examples
#' d <- as_survey(gss_2024, ids = vpsu, weights = wtssps, strata = vstrat,
#'                nest = TRUE)
#'
#' # Linear model: respondent age predicted by education and sex
#' fit <- survey_glm(d, age ~ educ + sex)
#' fit@coefficients
#' fit@vcov
#'
#' # Programmatic interface — suitable for lapply()
#' results <- lapply(c("age", "educ"), function(v) {
#'   survey_glm(d, response = v, predictors = "sex")
#' })
#'
#' @family constructors
#' @export
survey_glm <- function(
  design,
  formula    = NULL,
  response   = NULL,
  predictors = NULL,
  family     = stats::gaussian(),
  na.action  = stats::na.omit,
  start      = NULL,
  etastart   = NULL,
  mustart    = NULL,
  control    = list()
) {
  # ── Step 1: Validate inputs ────────────────────────────────────────────────
  .check_unsupported_class(design, "survey_glm")

  # Warn if design has @groups set
  if (length(design@groups) > 0L) {
    cli::cli_warn(
      c(
        "!" = "{.fn survey_glm} does not support grouped designs.",
        "i" = paste0(
          "The {.field @groups} property is ignored. ",
          "Use {.fn surveytidy::group_by} after fitting to group results."
        )
      ),
      class = "surveycore_warning_groups_ignored_in_glm"
    )
  }

  # Formula resolution
  has_formula    <- !is.null(formula)
  has_response   <- !is.null(response)
  has_predictors <- !is.null(predictors)

  if (has_formula && (has_response || has_predictors)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg formula} and {.arg response}/{.arg predictors} ",
          "are mutually exclusive."
        ),
        "i" = paste0(
          "Specify the model using either {.arg formula} or ",
          "{.arg response}/{.arg predictors}, not both."
        )
      ),
      class = "surveycore_error_formula_conflict"
    )
  }

  if (!has_formula && !has_response && !has_predictors) {
    cli::cli_abort(
      c("x" = "{.arg formula} is required."),
      class = "surveycore_error_formula_missing"
    )
  }

  if (!has_formula && !has_response && has_predictors) {
    cli::cli_abort(
      c(
        "x" = "{.arg formula} is required.",
        "i" = "{.arg response} is required when using {.arg predictors}."
      ),
      class = "surveycore_error_formula_missing"
    )
  }

  # Build formula from programmatic interface
  if (!has_formula && has_response) {
    formula <- stats::reformulate(
      termlabels = if (!is.null(predictors)) predictors else "1",
      response   = response
    )
    # Reset environment: reformulate() inherits survey_glm()'s frame, which
    # would embed all local variables in the stored object. Use globalenv()
    # so the stored formula is portable.
    environment(formula) <- globalenv()
  }

  # Validate formula type
  if (!inherits(formula, "formula")) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg formula} must be a formula object, ",
          "not {.cls {class(formula)[1]}}."
        )
      ),
      class = "surveycore_error_formula_invalid"
    )
  }

  # Check for cbind() LHS (multinomial — unsupported)
  lhs <- formula[[2L]]
  if (is.call(lhs) && identical(lhs[[1L]], quote(cbind))) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.code cbind()} on the left-hand side of {.arg formula} ",
          "is not supported."
        ),
        "i" = paste0(
          "Multinomial logistic regression is deferred to a later phase. ",
          "Use a single binary or continuous response variable."
        )
      ),
      class = "surveycore_error_cbind_response_unsupported"
    )
  }

  # Validate response variables exist in design@data
  resp_vars <- all.vars(formula[[2L]])
  missing_resp <- setdiff(resp_vars, names(design@data))
  if (length(missing_resp) > 0L) {
    cli::cli_abort(
      c(
        "x" = "Response variable {.field {missing_resp[1L]}} not found in survey data."
      ),
      class = "surveycore_error_response_not_found"
    )
  }

  # Warn if response is a design variable
  design_vars <- c(
    design@variables$ids,
    design@variables$weights,
    design@variables$strata,
    design@variables$fpc
  )
  design_vars <- design_vars[!is.null(design_vars)]
  for (rv in resp_vars) {
    if (rv %in% design_vars) {
      role <- if (rv == design@variables$weights) {
        "weight"
      } else if (rv %in% design@variables$ids) {
        "id"
      } else if (rv == design@variables$strata) {
        "stratum"
      } else {
        "fpc"
      }
      cli::cli_warn(
        c(
          "!" = paste0(
            "Response variable {.field {rv}} is a design variable ",
            "({.field {role}}). Results may be misleading."
          )
        ),
        class = "surveycore_warning_response_is_design_var"
      )
    }
  }

  # Validate predictor variables exist in design@data
  pred_vars <- setdiff(all.vars(formula[[3L]]), resp_vars)
  missing_preds <- setdiff(pred_vars, names(design@data))
  if (length(missing_preds) > 0L) {
    cli::cli_abort(
      c(
        "x" = "Predictor {.field {missing_preds[1L]}} not found in survey data.",
        "i" = paste0(
          "Available columns: ",
          "{.field {head(names(design@data), 10L)}}."
        )
      ),
      class = "surveycore_error_predictor_not_found"
    )
  }

  # ── Step 2: Apply domain ───────────────────────────────────────────────────
  domain_mask <- .apply_domain(design)
  fit_data    <- design@data[domain_mask, , drop = FALSE]

  if (nrow(fit_data) == 0L) {
    cli::cli_abort(
      c(
        "x" = "Active domain contains no in-domain rows.",
        "i" = paste0(
          "Apply a less restrictive {.fn surveytidy::filter} before ",
          "calling {.fn survey_glm}."
        )
      ),
      class = "surveycore_error_empty_domain"
    )
  }

  # Row indices (in full design@data) that are in-domain
  domain_idx <- which(domain_mask)

  # ── Step 3: Check weights, apply na.action ─────────────────────────────────
  wt_var <- design@variables$weights
  wt_all <- design@data[[wt_var]]
  wt_fit <- wt_all[domain_idx]

  # Check for NA weights
  n_na_wt <- sum(is.na(wt_fit))
  if (n_na_wt > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Weight column {.field {wt_var}} contains ",
          "{n_na_wt} NA value(s)."
        ),
        "i" = paste0(
          "Survey weights must be fully observed. Remove rows with missing ",
          "weights or impute before calling {.fn survey_glm}."
        )
      ),
      class = "surveycore_error_na_weights"
    )
  }

  # Warn for non-positive weights
  # nocov start
  # Defensive: all S7 design validators already reject non-positive weights, so
  # this branch is unreachable via the public API in normal use. Kept as a
  # safety net for corrupted design objects.
  n_nonpos <- sum(wt_fit <= 0, na.rm = TRUE)
  if (n_nonpos > 0L) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "Weight column {.field {wt_var}} contains ",
          "{n_nonpos} non-positive value(s)."
        ),
        "i" = paste0(
          "Zero-weight rows are excluded from fitting by {.fn stats::glm}. ",
          "Negative weights are statistically invalid."
        )
      ),
      class = "surveycore_warning_nonpositive_weights"
    )
  }
  # nocov end

  # Check for na.action = na.fail: pre-detect NAs and throw typed error
  na_action_fn <- match.fun(na.action)
  is_na_fail   <- identical(na_action_fn, stats::na.fail)
  if (is_na_fail) {
    # Build model frame to find which variables have NAs
    model_vars <- unique(c(resp_vars, pred_vars))
    na_info    <- vapply(model_vars, function(v) {
      col    <- fit_data[[v]]
      n_miss <- sum(is.na(col))
      if (n_miss > 0L) paste0(v, " (", n_miss, " NA)") else NA_character_
    }, character(1L))
    na_info <- na_info[!is.na(na_info)]
    if (length(na_info) > 0L) {
      n_na_cols <- length(na_info)
      cli::cli_abort(
        c(
          "x" = paste0(
            "{n_na_cols} column{?s} in the model {?has/have} NA values ",
            "with {.arg na.action = na.fail}: {.field {na_info}}."
          ),
          "v" = paste0(
            "Set {.arg na.action = na.omit} to drop rows with NA, ",
            "or remove them manually before calling {.fn survey_glm}."
          )
        ),
        class = "surveycore_error_na_in_data"
      )
    }
  }

  # ── Step 4: Fit weighted GLM ───────────────────────────────────────────────
  fam  <- family
  is_binomial <- identical(fam$family, "binomial") ||
    identical(fam$family, "quasibinomial")

  # Use do.call so wt_fit is passed as an already-evaluated numeric vector.
  # stats::glm() uses model.frame.default which evaluates the weights argument
  # in environment(formula), not in survey_glm()'s local frame. do.call()
  # embeds the vector value directly, bypassing the symbol-lookup failure.
  glm_args <- list(
    formula   = formula,
    family    = fam,
    data      = fit_data,
    weights   = wt_fit,
    na.action = na.action,
    start     = start,
    etastart  = etastart,
    mustart   = mustart,
    control   = do.call(stats::glm.control, control)
  )

  fit <- if (is_binomial) {
    suppressWarnings(do.call(stats::glm, glm_args))
  } else {
    do.call(stats::glm, glm_args)
  }

  # Convergence warning
  if (!fit$converged) {
    cli::cli_warn(
      c(
        "!" = "{.fn survey_glm} did not converge.",
        "i" = "Increase {.arg control$maxit} or simplify the model."
      ),
      class = "surveycore_warning_glm_convergence"
    )
  }

  # Singular / aliased model matrix
  if (any(is.na(stats::coef(fit)))) {
    cli::cli_abort(
      c(
        "x" = "Model matrix is singular.",
        "i" = "Check for perfect collinearity or empty factor levels."
      ),
      class = "surveycore_error_singular_model_matrix"
    )
  }

  # Perfect separation (binomial)
  if (is_binomial) {
    fv <- stats::fitted(fit)
    if (any(fv <= .Machine$double.eps | fv >= 1 - .Machine$double.eps)) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "Fitted probabilities are numerically 0 or 1. ",
            "Perfect or quasi-complete separation may have occurred."
          )
        ),
        class = "surveycore_warning_perfect_separation"
      )
    }
  }

  # ── Step 5: Compute design-based variance ─────────────────────────────────
  # Determine which rows of design@data were used in the fit (after na.action)
  # stats::glm() drops rows with NA via na.action; use the na.action attribute
  # on the model frame to find which rows were kept.
  mf       <- stats::model.frame(fit)
  na_idx   <- attr(mf, "na.action")   # indices of dropped rows (in fit_data)

  # Translate to indices in full design@data
  if (!is.null(na_idx)) {
    used_in_fit <- domain_idx[-na_idx]
  } else {
    used_in_fit <- domain_idx
  }

  # Build full-length domain indicator for score zeroing
  domain_for_score            <- logical(nrow(design@data))
  domain_for_score[used_in_fit] <- TRUE

  vcov_mat <- .glm_vcov_dispatch(
    fit, design,
    row_mask    = used_in_fit,
    domain_mask = domain_for_score
  )

  # Name the vcov matrix
  coef_names             <- names(stats::coef(fit))
  dimnames(vcov_mat)     <- list(coef_names, coef_names)

  # ── Step 6: Check degf and assemble survey_glm_fit ────────────────────────
  degf_val <- .glm_degrees_of_freedom(design, n_coef = length(coef_names))

  survey_glm_fit(
    coefficients  = stats::coef(fit),
    vcov          = vcov_mat,
    fitted_values = as.numeric(stats::fitted(fit)),
    residuals     = as.numeric(stats::residuals(fit, type = "working")),
    weights       = as.numeric(wt_fit[seq_len(length(stats::fitted(fit)))]),
    design        = design,
    degf          = degf_val,
    family        = as.list(fam),
    formula       = formula,
    null_deviance = fit$null.deviance,
    deviance      = fit$deviance,
    df_null       = as.numeric(fit$df.null),
    df_residual   = as.numeric(fit$df.residual),
    converged     = isTRUE(fit$converged),
    call          = match.call(),
    fit_          = fit
  )
}
