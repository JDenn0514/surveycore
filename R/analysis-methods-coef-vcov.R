# R/analysis-methods-coef-vcov.R
#
# S3 methods for extracting model-like summaries from survey_result objects:
#   coef.survey_result()   — named estimate vector
#   vcov.survey_result()   — named variance-covariance matrix (diagonal)
#   SE()                   — new generic (masks survey::SE)
#   SE.default()           — default method for non-survey_result objects
#   SE.survey_result()     — named SE vector via sqrt(diag(vcov()))
#   confint.survey_result()— CI matrix using t-distribution + stored df
#
# Error/warning classes used (all in plans/error-messages.md):
#   surveycore_error_result_method_unsupported (SCR-1)
#   surveycore_error_invalid_conf_level        (SCR-2, reuses row 45a class)
#   surveycore_error_invalid_df                (SCR-3)
#   surveycore_warning_vcov_incomplete         (SCR-W1)
#   surveycore_warning_vcov_diagonal_only      (SCR-W2)
#   surveycore_warning_parm_na                 (SCR-W3)
#   surveycore_warning_parm_unmatched          (SCR-W4)

# ── Internal helpers ──────────────────────────────────────────────────────────

# Check preconditions shared by all four methods (SCR-1).
# Applied in order: unsupported-class check, absent-attribute check,
# wide-format survey_corr check (Template 4), broom-rename check (Template 3).
# Returns the .survey_result attribute invisibly on success.
.check_result_preconditions <- function(object, fn_name) {
  # Template 1: unsupported class (survey_t_test / survey_pairwise)
  if (
    inherits(object, "survey_t_test") || inherits(object, "survey_pairwise")
  ) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.fn {fn_name}} is not supported for ",
          "{.cls {class(object)[1L]}} objects."
        ),
        "i" = paste0(
          "These result types have dedicated columns ",
          "({.field estimate}, {.field se}, {.field t_stat}, ",
          "{.field df}, {.field p_value}). Access them directly."
        ),
        "v" = "Use {.code result$estimate}, {.code result$se}, etc."
      ),
      class = "surveycore_error_result_method_unsupported"
    )
  }

  # Template 4: wide-format survey_corr (before the generic absent-attr check)
  if (
    inherits(object, "survey_corr") &&
      is.null(attr(object, ".survey_result"))
  ) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.fn {fn_name}} is not supported for wide-format ",
          "{.cls survey_corr} objects."
        ),
        "i" = paste0(
          "Wide-format correlation results do not have an ",
          "{.code estimate_cols} mapping."
        ),
        "v" = paste0(
          "Use {.code format = \"long\"} in {.fn get_corr} before calling ",
          "{.fn {fn_name}}."
        )
      ),
      class = "surveycore_error_result_method_unsupported"
    )
  }

  sr <- attr(object, ".survey_result")

  # Template 2: absent attribute
  if (is.null(sr)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.fn {fn_name}} requires a {.cls survey_result} built with ",
          "{.fn get_means}, {.fn get_totals}, or another supported ",
          "{.fn get_*} function."
        ),
        "i" = "The {.code .survey_result} metadata attribute is absent."
      ),
      class = "surveycore_error_result_method_unsupported"
    )
  }

  # Phase guard: multi-estimate-column not yet supported
  if (length(sr$estimate_cols) > 1L) {
    # nocov start
    # Phase guard: multi-estimate-column support is deferred to a future phase.
    # Reached only if a get_*() function incorrectly sets multiple estimate_cols.
    stop("multi-estimate-column coef() not yet supported")
    # nocov end
  }

  # Template 3: broom-renamed estimate column
  est_col <- sr$estimate_cols[[1L]]
  if (!est_col %in% names(object)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.fn {fn_name}} cannot find estimate column {.field {est_col}} ",
          "in {.cls {class(object)[1L]}}."
        ),
        "i" = paste0(
          "Column was renamed by {.code name_style = \"broom\"}. ",
          "The original column name {.field {est_col}} is stored in ",
          "{.code attr(x, '.survey_result')$estimate_cols}."
        ),
        "v" = paste0(
          "Call {.fn coef} before applying {.code name_style = \"broom\"}, ",
          "or access the estimate directly."
        )
      ),
      class = "surveycore_error_result_method_unsupported"
    )
  }

  invisible(sr)
}


# Build coefficient names from a survey_result object.
# Returns a character vector of length nrow(object).
.build_coef_names <- function(object, sr) {
  meta <- attr(object, ".meta")
  statistic <- sr$statistic
  group_cols <- sr$group_cols

  has_groups <- length(group_cols) > 0L
  n_rows <- nrow(object)

  if (n_rows == 0L) {
    # nocov start
    # Defensive: coef.survey_result() returns early for zero-row objects before
    # calling .build_coef_names(), so this branch is unreachable via public API.
    return(character(0))
    # nocov end
  }

  # Build the row identifier (intra-row label) for each row
  row_id <- switch(
    statistic,
    "mean" = ,
    "total" = {
      # Variable name from .meta$x; "N" in no-variable mode
      x_names <- names(meta$x)
      if (is.null(x_names) || length(x_names) == 0L) {
        rep("N", n_rows)
      } else {
        rep(x_names[[1L]], n_rows)
      }
    },
    "freq" = {
      # variable_name.level — from the focal column
      # In multi-var mode, names_to column is present; use it
      # In single-var mode, use first column not in group_cols
      x_names <- names(meta$x)
      if (
        length(x_names) == 1L &&
          x_names[[1L]] %in% names(object)
      ) {
        # Single-variable mode: focal col is the variable name
        focal_col <- as.character(object[[x_names[[1L]]]])
        paste0(x_names[[1L]], ".", focal_col)
      } else {
        # Multi-variable mode: names_to + values_to columns
        # names_to column: the non-group, non-pct columns
        non_estimate_cols <- setdiff(
          names(object),
          c(
            group_cols,
            sr$estimate_cols,
            "n",
            "se",
            "var",
            "cv",
            "ci_low",
            "ci_high",
            "moe",
            "deff"
          )
        )
        if (length(non_estimate_cols) >= 2L) {
          # names_to is first, values_to is second
          names_to_col <- as.character(object[[non_estimate_cols[[1L]]]])
          values_to_col <- as.character(object[[non_estimate_cols[[2L]]]])
          paste0(names_to_col, ".", values_to_col)
        } else if (length(non_estimate_cols) == 1L) {
          focal_col <- as.character(object[[non_estimate_cols[[1L]]]])
          paste0(non_estimate_cols[[1L]], ".", focal_col)
        } else {
          # Fallback: use row index
          as.character(seq_len(n_rows))
        }
      }
    },
    "quantile" = {
      # variable_name.quantile_label (e.g., "age.p25")
      x_name <- names(meta$x)[[1L]]
      quantile_col <- as.character(object[["quantile"]])
      paste0(x_name, ".", quantile_col)
    },
    "ratio" = {
      # numerator/denominator
      num_name <- meta$numerator$name
      den_name <- meta$denominator$name
      rep(paste0(num_name, "/", den_name), n_rows)
    },
    "corr" = {
      # var1.var2 from the factor columns
      v1 <- as.character(object[["var1"]])
      v2 <- as.character(object[["var2"]])
      paste0(v1, ".", v2)
    },
    "covariance" = {
      # var1.var2 from the factor columns
      v1 <- as.character(object[["var1"]])
      v2 <- as.character(object[["var2"]])
      paste0(v1, ".", v2)
    },
    "diffs" = {
      # "treatment_level - reference_level" from the treats column
      ref_level <- meta$treats$ref_level
      treats_col <- meta$treats$name
      treat_vals <- as.character(object[[treats_col]])
      paste0(treat_vals, " - ", ref_level)
    },
    {
      # Fallback: use row index
      as.character(seq_len(n_rows))
    }
  )

  # Prepend group label for grouped results
  if (has_groups) {
    # Build group label: colon-joined values from group columns
    group_vals <- do.call(
      paste,
      c(
        lapply(group_cols, function(gc) as.character(object[[gc]])),
        list(sep = ":")
      )
    )
    paste0(group_vals, ":", row_id)
  } else {
    row_id
  }
}


# ── SE generic ────────────────────────────────────────────────────────────────

#' Extract standard errors from a model or result object
#'
#' A generic function that extracts standard errors. For `survey_result` objects
#' (produced by `get_means()`, `get_totals()`, and other `get_*()` functions),
#' returns a named numeric vector matching `names(coef(object))`.
#'
#' @param object A model or result object.
#' @param ... Additional arguments passed to methods.
#'
#' @return A named numeric vector of standard errors. The exact structure
#'   depends on the method.
#'
#' @note When both `surveycore` and `survey` are loaded, `surveycore::SE`
#'   masks `survey::SE`. The `SE.default()` method handles most `survey`
#'   package objects (`svystat`, `svyby`) via `sqrt(diag(vcov(object, ...)))`.
#'   Exception: `SE.default` is NOT equivalent to `survey::SE.svyby` when
#'   `vartype = "cvpct"` was requested — in that case, qualify the call with
#'   `survey::SE()`.
#'
#' @export
#' @family analysis
SE <- function(object, ...) UseMethod("SE")


#' Default SE method: extracts from vcov diagonal
#'
#' Computes `sqrt(diag(vcov(object, ...)))`. Works for any object with a
#' `vcov()` method, including `lm`, `glm`, and `survey::svystat` objects.
#'
#' @param object An object with a `vcov()` method.
#' @param ... Forwarded to `vcov()`.
#'
#' @return A named numeric vector of standard errors.
#'
#' @note When `surveycore::SE` masks `survey::SE`, this default method covers
#'   `survey::svystat` objects but NOT `survey::svyby` with `vartype = "cvpct"`.
#'   Use `survey::SE()` explicitly in that case.
#'
#' @export
SE.default <- function(object, ...) sqrt(diag(stats::vcov(object, ...)))


# ── coef.survey_result() ─────────────────────────────────────────────────────

#' Extract coefficients from a survey result object
#'
#' Returns a named numeric vector of point estimates from a `survey_result`
#' object (produced by `get_means()`, `get_totals()`, `get_freqs()`,
#' `get_ratios()`, `get_quantiles()`, `get_corr()`, `get_covariance()`,
#' or `get_diffs()`).
#'
#' @param object A `survey_result` object from any supported `get_*()` function.
#' @param ... Unused. Reserved for future extensions.
#'
#' @return A named numeric vector. Names follow variable-major, group-secondary
#'   ordering matching `survey::coef.svyby()`. For grouped results, names are
#'   `"group_value:variable_name"` (e.g., `"A:y1"`, `"B:y1"`). For ungrouped
#'   results, names are the variable name (e.g., `"y1"`). See the spec for
#'   class-specific naming rules.
#'
#' @details
#' Not all `survey_result` subclasses support `coef()`. `survey_t_test` and
#' `survey_pairwise` objects throw `surveycore_error_result_method_unsupported`.
#' Wide-format `survey_corr` objects (from `get_corr(format = "wide")`) also
#' throw this error. For those objects, access columns directly (e.g.,
#' `result$estimate`, `result$se`).
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' result <- get_means(d, ridageyr, variance = "se")
#' coef(result)
#' @export
#' @method coef survey_result
coef.survey_result <- function(object, ...) {
  sr <- .check_result_preconditions(object, "coef")

  n_rows <- nrow(object)
  if (n_rows == 0L) {
    out <- numeric(0)
    names(out) <- character(0)
    return(out)
  }

  est_col <- sr$estimate_cols[[1L]]
  estimates <- as.numeric(object[[est_col]])
  nms <- .build_coef_names(object, sr)
  stats::setNames(estimates, nms)
}


# ── vcov.survey_result() ─────────────────────────────────────────────────────

#' Extract variance-covariance matrix from a survey result object
#'
#' Returns a named numeric matrix from a `survey_result` object. The diagonal
#' contains per-parameter variances (`se^2`). Off-diagonal elements are
#' structural zeros for most classes (except `survey_corr` with multiple pair
#' rows, which uses `NA_real_`).
#'
#' @param object A `survey_result` object from any supported `get_*()` function.
#' @param ... Unused.
#'
#' @return A `p × p` numeric matrix with `rownames` and `colnames` equal to
#'   `names(coef(object))`. When `p > 1`, emits
#'   `surveycore_warning_vcov_diagonal_only`. When the `se` column is absent,
#'   returns a `p × p` matrix of `NA_real_` with no warning.
#'
#' @details
#' Off-diagonal elements represent the covariance between estimates. For
#' survey results, only the diagonal (per-estimate variances) is available
#' from stored per-row data. Cross-estimate covariances require joint
#' influence-function estimation from the original design. Zeros in off-diagonal
#' positions are approximations that may not hold when groups share PSUs.
#'
#' `survey_corr` (long-format) results with more than one pair row have
#' `NA_real_` off-diagonal elements and emit `surveycore_warning_vcov_incomplete`.
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' result <- get_means(d, ridageyr, variance = "se")
#' vcov(result)
#' @export
#' @method vcov survey_result
vcov.survey_result <- function(object, ...) {
  sr <- .check_result_preconditions(object, "vcov")

  nms <- names(stats::coef(object))
  p <- length(nms)

  if (p == 0L) {
    return(
      matrix(
        numeric(0),
        nrow = 0L,
        ncol = 0L,
        dimnames = list(character(0), character(0))
      )
    )
  }

  # Phase guard
  if (length(sr$estimate_cols) > 1L) {
    # nocov start
    # Phase guard: multi-estimate-column support is deferred to a future phase.
    # Reached only if a get_*() function incorrectly sets multiple estimate_cols.
    stop("multi-estimate-column vcov() not yet supported")
    # nocov end
  }

  # Check if se column is present
  if (!"se" %in% names(object)) {
    # Return NA matrix — no warning
    mat <- matrix(NA_real_, nrow = p, ncol = p, dimnames = list(nms, nms))
    return(mat)
  }

  # Extract SE values and coerce NaN -> NA
  se_vals <- as.numeric(object[["se"]])
  se_vals[is.nan(se_vals)] <- NA_real_

  # Compute diagonal variances
  var_vals <- se_vals^2

  # survey_corr with multiple pair rows: off-diagonal = NA_real_
  is_corr_multi <- inherits(object, "survey_corr") && nrow(object) > 1L

  if (is_corr_multi) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "Off-diagonal elements of {.fn vcov} are {.code NA_real_} for ",
          "{.cls survey_corr} results."
        ),
        "i" = paste0(
          "Cross-pair covariances require joint estimation and are not ",
          "available from per-pair stored data."
        ),
        "i" = paste0(
          "Use {.code diag(vcov(result))} for per-pair variances, or ",
          "{.code result$se} directly."
        )
      ),
      class = "surveycore_warning_vcov_incomplete"
    )
    mat <- matrix(NA_real_, nrow = p, ncol = p, dimnames = list(nms, nms))
    diag(mat) <- var_vals
  } else {
    # Block-diagonal: diagonal = se^2, off-diagonal = 0
    mat <- matrix(0, nrow = p, ncol = p, dimnames = list(nms, nms))
    diag(mat) <- var_vals
  }

  # Emit warning when p > 1 (off-diagonal approximation)
  if (p > 1L) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "Off-diagonal elements of {.fn vcov} are structural zeros ",
          "(only diagonal variances are estimated)."
        ),
        "i" = "This matches {.fn survey::vcov.svyby} behavior.",
        "i" = paste0(
          "For joint multi-parameter inference, see {.fn survey::svycontrast}."
        )
      ),
      class = "surveycore_warning_vcov_diagonal_only"
    )
  }

  mat
}


# ── SE.survey_result() ───────────────────────────────────────────────────────

#' Extract standard errors from a survey result object
#'
#' Returns a named numeric vector of standard errors from a `survey_result`
#' object. Values are `sqrt(diag(vcov(object)))`, ensuring consistency between
#' `SE()` and `vcov()`.
#'
#' @param object A `survey_result` object from any supported `get_*()` function.
#' @param ... Unused.
#'
#' @return A named numeric vector. Names are identical to `names(coef(object))`.
#'   `NA` entries propagate from missing `se` column or `NA` in `se`.
#'
#' @note `vcov.survey_result()` emits `surveycore_warning_vcov_diagonal_only`
#'   when `p > 1`. This warning is suppressed inside `SE.survey_result()` because
#'   the off-diagonal structure is irrelevant when only standard errors are
#'   requested. Call `vcov(result)` directly to observe this warning.
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' result <- get_means(d, ridageyr, variance = "se")
#' SE(result)
#' @export
SE.survey_result <- function(object, ...) {
  sqrt(diag(suppressWarnings(stats::vcov(object))))
}


# ── confint.survey_result() ──────────────────────────────────────────────────

#' Confidence intervals for survey result objects
#'
#' Computes confidence intervals for the parameters of a `survey_result` object
#' using the t-distribution with per-parameter degrees of freedom stored in
#' `attr(object, ".survey_result")$df`.
#'
#' @param object A `survey_result` object from any supported `get_*()` function.
#' @param parm A numeric, integer, or character vector selecting a subset of
#'   parameters, or missing (all parameters). Character `parm` is matched
#'   against `names(coef(object))`.
#' @param level Confidence level, strictly between 0 and 1. Default `0.95`.
#' @param ... Unused.
#'
#' @return A numeric matrix with two columns. Column names are
#'   `"2.5 %"` and `"97.5 %"` for `level = 0.95` (matching
#'   `stats::confint.default()` format). Rownames are
#'   `names(coef(object))[parm]`. Dimensions: `length(parm) × 2`.
#'
#' @details
#' For non-calibrated Taylor, replicate, and nonprob designs, `df = Inf` is
#' stored, so `qt(1 - (1 - level)/2, df = Inf)` equals `qnorm(...)` — a normal
#' approximation. For calibrated Taylor designs, per-cell finite df values are
#' used.
#'
#' When `SE(object)[i]` is `NA`, the corresponding CI row is `c(NA, NA)`.
#'
#' @examples
#' d <- as_survey(
#'   nhanes_2017,
#'   ids = sdmvpsu,
#'   weights = wtint2yr,
#'   strata = sdmvstra,
#'   nest = TRUE
#' )
#' result <- get_means(d, ridageyr, variance = "se")
#' confint(result)
#' confint(result, level = 0.90)
#' @export
#' @method confint survey_result
confint.survey_result <- function(object, parm, level = 0.95, ...) {
  # ── 1. Validate level first ─────────────────────────────────────────────────
  if (isTRUE(is.na(level)) || length(level) != 1L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg level} must be a single number strictly between 0 and 1."
        ),
        "i" = "Got {.val {level}}."
      ),
      class = "surveycore_error_invalid_conf_level"
    )
  }
  if (!is.numeric(level) || level <= 0 || level >= 1) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg level} must be a single number strictly between 0 and 1."
        ),
        "i" = "Got {.val {level}}."
      ),
      class = "surveycore_error_invalid_conf_level"
    )
  }

  # ── 2. Apply preconditions (via coef) ────────────────────────────────────
  cf <- stats::coef(object)
  sr <- attr(object, ".survey_result")
  df_vec <- sr$df # length p

  # Column names matching stats::confint.default() format
  a <- (1 - level) / 2
  pct_lo <- paste0(format(100 * a, trim = TRUE), " %")
  pct_hi <- paste0(format(100 * (1 - a), trim = TRUE), " %")
  col_nms <- c(pct_lo, pct_hi)

  p <- length(cf)

  # ── 3. Resolve parm ────────────────────────────────────────────────────────
  if (missing(parm)) {
    parm_idx <- seq_len(p)
  } else if (is.character(parm)) {
    # Drop NA elements with warning
    if (any(is.na(parm))) {
      n_na <- sum(is.na(parm))
      cli::cli_warn(
        c(
          "!" = paste0(
            "{.arg parm} contains {.val {n_na}} {.code NA} element(s)."
          ),
          "i" = "{.code NA} elements are dropped before parameter selection."
        ),
        class = "surveycore_warning_parm_na"
      )
      parm <- parm[!is.na(parm)]
    }
    if (length(parm) == 0L) {
      mat <- matrix(
        numeric(0),
        nrow = 0L,
        ncol = 2L,
        dimnames = list(character(0), col_nms)
      )
      return(mat)
    }
    # Match against names
    m <- match(parm, names(cf))
    if (any(is.na(m))) {
      unmatched <- parm[is.na(m)]
      n_unmatched <- length(unmatched)
      cli::cli_warn(
        c(
          "!" = paste0(
            "{.arg parm} contains {.val {n_unmatched}} name(s) not found ",
            "in {.fn coef} output."
          ),
          "i" = "Unmatched names: {.val {unmatched}}.",
          "i" = paste0(
            "These parameters are dropped. Check {.code names(coef(result))} ",
            "for valid names."
          )
        ),
        class = "surveycore_warning_parm_unmatched"
      )
      m <- m[!is.na(m)]
    }
    if (length(m) == 0L) {
      mat <- matrix(
        numeric(0),
        nrow = 0L,
        ncol = 2L,
        dimnames = list(character(0), col_nms)
      )
      return(mat)
    }
    parm_idx <- m
  } else if (is.logical(parm)) {
    if (length(parm) != p) {
      stop("logical 'parm' must have the same length as coef(object)")
    }
    parm_idx <- which(parm)
  } else {
    # Numeric/integer
    parm_idx <- as.integer(parm)
  }

  # Handle empty parm
  if (length(parm_idx) == 0L) {
    mat <- matrix(
      numeric(0),
      nrow = 0L,
      ncol = 2L,
      dimnames = list(character(0), col_nms)
    )
    return(mat)
  }

  # ── 4. Validate df for each resolved parm position ───────────────────────
  for (i in parm_idx) {
    dfi <- df_vec[i]
    if (is.na(dfi) || (is.finite(dfi) && dfi <= 0)) {
      cli::cli_abort(
        c(
          "x" = "Design degrees of freedom must be positive (got {.val {dfi}}).",
          "i" = paste0(
            "The {.code .survey_result} attribute was constructed with ",
            "{.code df = {dfi}}."
          ),
          "v" = "Ensure the survey design has at least one degree of freedom."
        ),
        class = "surveycore_error_invalid_df"
      )
    }
  }

  # ── 5. Compute CI bounds ─────────────────────────────────────────────────
  se_vals <- suppressWarnings(SE(object))

  lower <- numeric(length(parm_idx))
  upper <- numeric(length(parm_idx))
  row_nms <- character(length(parm_idx))

  for (j in seq_along(parm_idx)) {
    i <- parm_idx[[j]]
    dfi <- df_vec[i]
    t_crit <- stats::qt(1 - a, df = dfi)
    lower[j] <- cf[i] - t_crit * se_vals[i]
    upper[j] <- cf[i] + t_crit * se_vals[i]
    row_nms[j] <- names(cf)[i]
  }

  mat <- matrix(
    c(lower, upper),
    nrow = length(parm_idx),
    ncol = 2L,
    dimnames = list(row_nms, col_nms)
  )
  mat
}
