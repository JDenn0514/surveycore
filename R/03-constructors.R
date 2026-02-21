# R/03-constructors.R
#
# Constructor functions for survey design objects.
#
# Functions defined here (Phase 0, steps 5–7 + Phase 2.5 skeleton):
#   as_survey()             — creates a survey_taylor object (Taylor series design)
#   as_survey_rep()         — creates a survey_replicate object (replicate weights)
#   as_survey_twophase()    — creates a survey_twophase object (two-phase sampling)
#   as_survey_calibrated()  — creates a survey_calibrated object (Phase 2.5 skeleton)
#
# This file implements Layer 3 of the 3-layer validator architecture:
#   Layer 1 — S7 class validators      (R/00-s7-classes.R)
#   Layer 2 — reusable validator helpers (R/02-validators.R)
#   Layer 3 — constructor input parsing  (R/03-constructors.R)  <-- this file
#
# Error classes match plans/error-messages.md exactly (rows 1–25).
# All cli_abort()/cli_warn() calls include a class= argument.


# ── as_survey ─────────────────────────────────────────────────────────────────

#' Create a Taylor Series Linearization Survey Design
#'
#' Creates a survey design object using Taylor series (linearization) for
#' variance estimation. Supports simple random samples, stratified designs,
#' single- and multi-stage cluster designs, and designs with finite population
#' correction. Uses a tidy-select interface for all design variable arguments.
#'
#' @param data A `data.frame` containing the survey responses. Must have at
#'   least one row and unique column names.
#' @param ids <[`tidy-select`][tidyselect::language]> Cluster (PSU) ID column(s).
#'   For single-stage: `ids = psu`. For multi-stage: `ids = c(psu, ssu)`.
#'   Omit entirely for simple random sampling.
#' @param probs <[`tidy-select`][tidyselect::language]> Sampling probability
#'   column (a single column, values in (0, 1]). Converted to weights
#'   `= 1/probs` and stored internally. Cannot be used together with `weights`
#'   unless the values are consistent (`weights == 1/probs`).
#' @param weights <[`tidy-select`][tidyselect::language]> Sampling weight
#'   column (a single column, values strictly > 0).
#' @param strata <[`tidy-select`][tidyselect::language]> Stratification
#'   variable column (a single column).
#' @param fpc <[`tidy-select`][tidyselect::language]> Finite population
#'   correction column (a single column). Accepts either total population size
#'   (integer) or sampling fraction (numeric, 0–1). Cannot contain `NA`.
#' @param nest Logical. If `TRUE`, PSU IDs are treated as nested within
#'   strata — i.e., the same ID value in two different strata refers to two
#'   distinct PSUs. Set `nest = TRUE` when PSU IDs are not globally unique
#'   (e.g., NHANES, where PSU IDs restart from 1 in each stratum). Requires
#'   `strata` to be specified. Default `FALSE`.
#'
#' @return A `survey_taylor` object.
#'
#' @section Tidy-select:
#' All design variable arguments (`ids`, `probs`, `weights`, `strata`, `fpc`)
#' support tidy-select syntax:
#' ```r
#' # Bare name
#' as_survey(df, weights = wt)
#' # c() for multi-stage ids
#' as_survey(df, ids = c(psu, ssu), weights = wt)
#' # tidy-select helpers also work (e.g., starts_with())
#' ```
#'
#' @section Simple random sample:
#' If `ids`, `weights`, and `probs` are all omitted, an equal-probability SRS
#' is assumed. A warning is issued because population totals cannot be
#' estimated without weights or population size.
#'
#' @examples
#' # Full NHANES design: stratified cluster with PSU IDs nested within strata
#' d <- as_survey(
#'   nhanes_2017,
#'   ids     = sdmvpsu,
#'   weights = wtint2yr,
#'   strata  = sdmvstra,
#'   nest    = TRUE
#' )
#'
#' # Stratified design without PSU cluster IDs
#' d_strat <- as_survey(nhanes_2017, weights = wtint2yr, strata = sdmvstra)
#'
#' # Blood pressure analysis: filter to exam participants, use MEC weight
#' exam <- nhanes_2017[nhanes_2017$ridstatr == 2, ]
#' d_bp <- as_survey(exam, ids = sdmvpsu, weights = wtmec2yr,
#'                   strata = sdmvstra, nest = TRUE)
#'
#' @seealso
#'   [as_survey_rep()] for replicate-weight designs,
#'   [as_survey_twophase()] for two-phase designs,
#'   [set_var_label()], [set_variable_labels()] to add variable metadata
#'
#' @family constructors
#' @export
as_survey <- function(
  data,
  ids     = NULL,
  probs   = NULL,
  weights = NULL,
  strata  = NULL,
  fpc     = NULL,
  nest    = FALSE
) {
  call <- match.call()

  # ── Layer 3: data-level validation ─────────────────────────────────────────

  # Error 1: data must be a data frame
  if (!is.data.frame(data)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg data} must be a data frame, not ",
          "{.cls {class(data)[[1L]]}}"
        )
      ),
      class = "surveycore_error_not_data_frame"
    )
  }

  # Error 2: data must have at least one row
  if (nrow(data) == 0L) {
    cli::cli_abort(
      c("x" = "{.arg data} must have at least one row"),
      class = "surveycore_error_empty_data"
    )
  }

  # Error 3: column names must be unique
  if (anyDuplicated(names(data)) > 0L) {
    dupes <- unique(names(data)[duplicated(names(data))])
    cli::cli_abort(
      c(
        "x" = paste0(
          "Column names in {.arg data} must be unique. ",
          "Duplicates: {.field {dupes}}"
        )
      ),
      class = "surveycore_error_duplicate_names"
    )
  }

  # Warning 4: single-row data cannot support variance estimation
  if (nrow(data) == 1L) {
    cli::cli_warn(
      c("!" = "{.arg data} has only 1 row \u2014 variance cannot be estimated"),
      class = "surveycore_warning_single_row"
    )
  }

  # ── Resolve tidy-select expressions ────────────────────────────────────────

  # ids (may select multiple columns for multi-stage designs)
  ids_quo <- rlang::enquo(ids)
  if (rlang::quo_is_null(ids_quo)) {
    ids_vars <- NULL
  } else {
    ids_cols <- tidyselect::eval_select(ids_quo, data)
    ids_vars <- names(ids_cols)
  }

  # probs (must select exactly one column)
  probs_quo <- rlang::enquo(probs)
  if (rlang::quo_is_null(probs_quo)) {
    probs_var <- NULL
  } else {
    probs_cols <- tidyselect::eval_select(probs_quo, data)
    if (length(probs_cols) == 0L) {
      cli::cli_abort(
        c("x" = "{.arg probs} matched no columns in {.arg data}"),
        class = "surveycore_error_weights_not_found"
      )
    }
    if (length(probs_cols) > 1L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg probs} must select exactly one column, not ",
            "{length(probs_cols)}"
          )
        ),
        class = "surveycore_error_weights_multiple"
      )
    }
    probs_var <- names(probs_cols)
  }

  # weights (must select exactly one column)
  weights_quo <- rlang::enquo(weights)
  if (rlang::quo_is_null(weights_quo)) {
    weights_var <- NULL
  } else {
    weights_cols <- tidyselect::eval_select(weights_quo, data)
    if (length(weights_cols) == 0L) {
      cli::cli_abort(
        c("x" = "{.arg weights} matched no columns in {.arg data}"),
        class = "surveycore_error_weights_not_found"
      )
    }
    if (length(weights_cols) > 1L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg weights} must select exactly one column, not ",
            "{length(weights_cols)}"
          )
        ),
        class = "surveycore_error_weights_multiple"
      )
    }
    weights_var <- names(weights_cols)
  }

  # strata (must select exactly one column)
  strata_quo <- rlang::enquo(strata)
  if (rlang::quo_is_null(strata_quo)) {
    strata_var <- NULL
  } else {
    strata_cols <- tidyselect::eval_select(strata_quo, data)
    if (length(strata_cols) == 0L) {
      cli::cli_abort(
        c("x" = "{.arg strata} matched no columns in {.arg data}"),
        class = "surveycore_error_strata_not_found"
      )
    }
    if (length(strata_cols) > 1L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg strata} must select exactly one column, not ",
            "{length(strata_cols)}"
          )
        ),
        class = "surveycore_error_strata_multiple"
      )
    }
    strata_var <- names(strata_cols)
  }

  # fpc (must select exactly one column)
  fpc_quo <- rlang::enquo(fpc)
  if (rlang::quo_is_null(fpc_quo)) {
    fpc_var <- NULL
  } else {
    fpc_cols <- tidyselect::eval_select(fpc_quo, data)
    if (length(fpc_cols) == 0L) {
      cli::cli_abort(
        c("x" = "{.arg fpc} matched no columns in {.arg data}"),
        class = "surveycore_error_fpc_not_found"
      )
    }
    if (length(fpc_cols) > 1L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg fpc} must select exactly one column, not ",
            "{length(fpc_cols)}"
          )
        ),
        class = "surveycore_error_fpc_multiple"
      )
    }
    fpc_var <- names(fpc_cols)
  }

  # ── Probs / weights reconciliation ─────────────────────────────────────────

  probs_provided <- FALSE

  if (!is.null(probs_var) && !is.null(weights_var)) {
    # Both specified — check for consistency
    computed_wt  <- 1 / data[[probs_var]]
    provided_wt  <- data[[weights_var]]
    if (!isTRUE(all.equal(computed_wt, provided_wt, tolerance = 1e-6))) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Cannot specify both {.arg probs} and {.arg weights} ",
            "with inconsistent values. ",
            "{.arg weights} should equal 1 / {.arg probs}"
          )
        ),
        class = "surveycore_error_probs_weights_conflict"
      )
    }
    # Consistent — use the provided weights column, note probs was consistent
    cli::cli_inform(
      paste0(
        "Using {.arg weights}; provided {.arg probs} is consistent ",
        "(weights = 1/probs)"
      )
    )
    probs_provided <- TRUE
  } else if (!is.null(probs_var) && is.null(weights_var)) {
    # Only probs provided — convert to weights
    weights_var    <- "..surveycore_wt.."
    data[[weights_var]] <- 1 / data[[probs_var]]
    probs_provided <- TRUE
  } else if (is.null(probs_var) && is.null(weights_var)) {
    # Neither probs nor weights — SRS fallback
    # Warning 7: no weights or probs (SRS fallback)
    weights_var         <- "..surveycore_wt.."
    data[[weights_var]] <- rep(1L, nrow(data))
    probs_provided      <- FALSE

    cli::cli_warn(
      c(
        "!" = "No weights or population size provided.",
        "i" = paste0(
          "Treating as equal-probability SRS with unknown ",
          "population size."
        ),
        "v" = paste0(
          "Valid: means, proportions, correlations, ",
          "and their standard errors."
        ),
        "x" = paste0(
          "Invalid: population totals (will equal sample totals, ",
          "not population totals)."
        ),
        "i" = paste0(
          "To fix: provide {.arg fpc} = population size, ",
          "or {.arg weights} = N / n."
        )
      ),
      class = "surveycore_warning_srs_no_weights"
    )
  }

  # ── Business-rule validations ───────────────────────────────────────────────

  # Error 15: nest = TRUE requires strata
  if (isTRUE(nest) && is.null(strata_var)) {
    cli::cli_abort(
      c("x" = "{.arg nest = TRUE} requires {.arg strata} to be specified"),
      class = "surveycore_error_nest_without_strata"
    )
  }

  # Validate weights column (all zero / non-positive check via Layer 2)
  .validate_weights(weights_var, data)

  # Validate design variable columns exist and are atomic
  .validate_design_vars(c(ids_vars, strata_var), data)

  # Validate fpc column (no NAs) via Layer 2
  .validate_fpc(fpc_var, data)

  # Warning 12: strata has only one unique value
  if (!is.null(strata_var)) {
    n_unique_strata <- length(unique(data[[strata_var]]))
    if (n_unique_strata == 1L) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "{.arg strata} ({.field {strata_var}}) has only 1 unique ",
            "value \u2014 stratification has no effect"
          )
        ),
        class = "surveycore_warning_single_stratum"
      )
    }
  }

  # ── Build @variables list ───────────────────────────────────────────────────

  variables <- list(
    ids            = ids_vars,
    weights        = weights_var,
    strata         = strata_var,
    fpc            = fpc_var,
    nest           = isTRUE(nest),
    probs_provided = probs_provided,
    visible_vars   = NULL
  )

  # ── Extract haven-style metadata ────────────────────────────────────────────

  metadata <- .extract_haven_metadata(data)

  # ── Construct and return survey_taylor object ───────────────────────────────

  survey_taylor(
    data      = data,
    metadata  = metadata,
    variables = variables,
    call      = call
  )
}


# ── as_survey_rep ──────────────────────────────────────────────────────────────

#' Create a Replicate Weights Survey Design
#'
#' Creates a survey design object using replicate weights for variance
#' estimation. Supports all common replicate methods: jackknife (JK1, JK2,
#' JKn), balanced repeated replication (BRR, Fay), bootstrap, ACS,
#' successive-difference, and user-defined types. Uses a tidy-select
#' interface for weight and replicate-weight columns.
#'
#' @param data A `data.frame` containing the survey responses. Must have at
#'   least one row and unique column names.
#' @param weights <[`tidy-select`][tidyselect::language]> Sampling weight
#'   column (a single column, values strictly > 0). Required.
#' @param repweights <[`tidy-select`][tidyselect::language]> Replicate weight
#'   columns. Must select at least one column. Supports tidy-select helpers
#'   (e.g., `starts_with("repwt")`). Required.
#' @param type Character. Replicate weight method. One of `"JK1"` (delete-1
#'   jackknife), `"JK2"` (delete-1 jackknife, stratified), `"JKn"` (delete-1
#'   jackknife with varying replication counts), `"BRR"` (balanced repeated
#'   replication), `"Fay"` (Fay's method, a modified BRR), `"bootstrap"`,
#'   `"ACS"` (used in American Community Survey), `"successive-difference"`,
#'   or `"other"` (user-specified scale).
#' @param scale Numeric. Scaling factor applied to the replicate variance
#'   formula. If `NULL` (default), computed automatically from `type` and
#'   the number of replicates: `(R-1)/R` for jackknife methods, `1/4` for
#'   BRR/Fay, `1/R` for bootstrap/ACS, `2/R` for successive-difference,
#'   `1` for other.
#' @param rscales Numeric vector of replicate-specific scaling factors, or
#'   `NULL`. If provided, must have the same length as the number of
#'   replicate weight columns selected by `repweights`.
#' @param fpc <[`tidy-select`][tidyselect::language]> Finite population
#'   correction column (a single column). Used by some replicate methods to
#'   adjust the variance estimator. `NULL` means no FPC correction.
#' @param fpctype Character. How `fpc` is interpreted: `"fraction"` (sampling
#'   fraction, 0–1) or `"correction"` (multiplier for the replicate variance).
#'   Default `"fraction"`.
#' @param mse Logical. If `TRUE` (default), use mean-squared-error estimates
#'   (subtract the full-sample estimate rather than the mean replicate estimate
#'   when computing variance). Recommended for most designs.
#'
#' @return A `survey_replicate` object.
#'
#' @section Tidy-select:
#' Both `weights` and `repweights` support tidy-select syntax:
#' ```r
#' # Bare name for weights
#' as_survey_rep(df, weights = wt, repweights = starts_with("repwt"), type = "BRR")
#' # c() for explicit replicate columns
#' as_survey_rep(df, weights = wt, repweights = c(rep1, rep2, rep3), type = "JK1")
#' ```
#'
#' @section Replicate weight matrix:
#' The replicate weight matrix is **not stored** in the object. Only the
#' column names are stored in `@variables$repweights`. Variance estimation
#' computes the matrix on demand:
#' `as.matrix(design@data[, design@variables$repweights])`.
#'
#' @examples
#' # ACS PUMS Wyoming: 80 successive-difference replicate weights
#' d_acs <- as_survey_rep(
#'   acs_pums_wy,
#'   weights    = pwgtp,
#'   repweights = pwgtp1:pwgtp80,
#'   type       = "successive-difference"
#' )
#'
#' # Explicit replicate columns using c()
#' d_sub <- as_survey_rep(
#'   acs_pums_wy,
#'   weights    = pwgtp,
#'   repweights = c(pwgtp1, pwgtp2, pwgtp3, pwgtp4),
#'   type       = "JK1"
#' )
#'
#' @seealso
#'   [as_survey()] for Taylor series designs,
#'   [as_survey_twophase()] for two-phase designs,
#'   [set_var_label()], [set_variable_labels()] to add variable metadata
#'
#' @family constructors
#' @export
as_survey_rep <- function(
  data,
  weights,
  repweights,
  type = c(
    "JK1", "JK2", "JKn", "BRR", "Fay",
    "bootstrap", "ACS", "successive-difference", "other"
  ),
  scale   = NULL,
  rscales = NULL,
  fpc     = NULL,
  fpctype = c("fraction", "correction"),
  mse     = TRUE
) {
  call    <- match.call()
  type    <- match.arg(type)
  fpctype <- match.arg(fpctype)

  # ── Layer 3: data-level validation ─────────────────────────────────────────

  # Error 1: data must be a data frame
  if (!is.data.frame(data)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg data} must be a data frame, not ",
          "{.cls {class(data)[[1L]]}}"
        )
      ),
      class = "surveycore_error_not_data_frame"
    )
  }

  # Error 2: data must have at least one row
  if (nrow(data) == 0L) {
    cli::cli_abort(
      c("x" = "{.arg data} must have at least one row"),
      class = "surveycore_error_empty_data"
    )
  }

  # Error 3: column names must be unique
  if (anyDuplicated(names(data)) > 0L) {
    dupes <- unique(names(data)[duplicated(names(data))])
    cli::cli_abort(
      c(
        "x" = paste0(
          "Column names in {.arg data} must be unique. ",
          "Duplicates: {.field {dupes}}"
        )
      ),
      class = "surveycore_error_duplicate_names"
    )
  }

  # Warning 4: single-row data cannot support variance estimation
  if (nrow(data) == 1L) {
    cli::cli_warn(
      c("!" = "{.arg data} has only 1 row \u2014 variance cannot be estimated"),
      class = "surveycore_warning_single_row"
    )
  }

  # ── Resolve tidy-select expressions ────────────────────────────────────────

  # weights (must select exactly one column)
  weights_quo  <- rlang::enquo(weights)
  weights_cols <- tidyselect::eval_select(weights_quo, data)
  if (length(weights_cols) == 0L) {
    cli::cli_abort(
      c("x" = "{.arg weights} matched no columns in {.arg data}"),
      class = "surveycore_error_weights_not_found"
    )
  }
  if (length(weights_cols) > 1L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg weights} must select exactly one column, not ",
          "{length(weights_cols)}"
        )
      ),
      class = "surveycore_error_weights_multiple"
    )
  }
  weights_var <- names(weights_cols)

  # repweights (must select at least one column)
  repweights_quo  <- rlang::enquo(repweights)
  repweights_cols <- tidyselect::eval_select(repweights_quo, data)
  if (length(repweights_cols) == 0L) {
    cli::cli_abort(
      c("x" = "{.arg repweights} must select at least one column"),
      class = "surveycore_error_repweights_empty"
    )
  }
  repweights_vars <- names(repweights_cols)
  n_rep           <- length(repweights_vars)

  # fpc (optional; must select exactly one column if provided)
  fpc_quo <- rlang::enquo(fpc)
  if (rlang::quo_is_null(fpc_quo)) {
    fpc_var <- NULL
  } else {
    fpc_cols <- tidyselect::eval_select(fpc_quo, data)
    if (length(fpc_cols) == 0L) {
      cli::cli_abort(
        c("x" = "{.arg fpc} matched no columns in {.arg data}"),
        class = "surveycore_error_fpc_not_found"
      )
    }
    if (length(fpc_cols) > 1L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg fpc} must select exactly one column, not ",
            "{length(fpc_cols)}"
          )
        ),
        class = "surveycore_error_fpc_multiple"
      )
    }
    fpc_var <- names(fpc_cols)
  }

  # ── Business-rule validations ───────────────────────────────────────────────

  # Validate weights column (all zero / non-positive check via Layer 2)
  .validate_weights(weights_var, data)

  # Validate repweights columns are numeric (Layer 2)
  .validate_repweights(repweights_vars, data)

  # Validate fpc column if provided (no NAs allowed)
  .validate_fpc(fpc_var, data)

  # Error 17: rscales length must match number of replicates (Layer 2)
  .validate_rscales(rscales, n_rep)

  # ── Compute default scale based on type and n_rep ───────────────────────────

  if (is.null(scale)) {
    scale <- switch(type,
      JK1                     = (n_rep - 1L) / n_rep,
      JK2                     = (n_rep - 1L) / n_rep,
      JKn                     = (n_rep - 1L) / n_rep,
      BRR                     = 1 / n_rep,
      Fay                     = 1 / n_rep,
      bootstrap               = 1 / n_rep,
      ACS                     = 1 / n_rep,
      `successive-difference` = 2 / n_rep,
      other                   = 1
    )
  }

  # ── Build @variables list ───────────────────────────────────────────────────

  variables <- list(
    weights      = weights_var,
    repweights   = repweights_vars,
    type         = type,
    scale        = scale,
    rscales      = rscales,
    fpc          = fpc_var,
    fpctype      = fpctype,
    mse          = isTRUE(mse),
    visible_vars = NULL
  )

  # ── Extract haven-style metadata ────────────────────────────────────────────

  metadata <- .extract_haven_metadata(data)

  # ── Construct and return survey_replicate object ────────────────────────────

  survey_replicate(
    data      = data,
    metadata  = metadata,
    variables = variables,
    call      = call
  )
}


# ── as_survey_twophase ─────────────────────────────────────────────────────────

#' Create a Two-Phase Survey Design
#'
#' Creates a two-phase (double) sampling design from an existing
#' `survey_taylor` Phase 1 object. Phase 1 covers all rows; Phase 2 is a
#' strict subset indicated by a logical column. Uses a tidy-select interface
#' for all Phase 2 design variable arguments.
#'
#' @param phase1 A `survey_taylor` object representing the Phase 1 design.
#'   Its `@data` must contain ALL rows from both phases, plus a logical
#'   indicator column for Phase 2 membership. Create with [as_survey()].
#' @param ids2 <[`tidy-select`][tidyselect::language]> Phase 2 cluster ID
#'   column(s). For single-stage Phase 2: `ids2 = psu2`. For multi-stage:
#'   `ids2 = c(psu2, ssu2)`. Omit if Phase 2 has no within-stratum
#'   clustering.
#' @param strata2 <[`tidy-select`][tidyselect::language]> Phase 2
#'   stratification column (a single column). Optional.
#' @param probs2 <[`tidy-select`][tidyselect::language]> Phase 2 inclusion
#'   probability column (a single column, values in (0, 1]). Optional.
#' @param fpc2 <[`tidy-select`][tidyselect::language]> Phase 2 finite
#'   population correction column (a single column). Optional.
#' @param subset <[`tidy-select`][tidyselect::language]> Single logical column
#'   in `phase1@data`. `TRUE` = row selected into Phase 2;
#'   `FALSE` = Phase 1 only. Required. Must contain both `TRUE` and `FALSE`
#'   values (non-degenerate).
#' @param method Character. Variance estimation method for combining Phase 1
#'   and Phase 2 variability. One of `"full"` (default), `"approx"`, or
#'   `"simple"`. See Details.
#'
#' @details
#' ## Variance methods
#'
#' * `"full"` — Full two-phase variance formula. Accounts for variability in
#'   both phases. Requires Phase 2 design information (`probs2`, `ids2`,
#'   `strata2`) when Phase 2 is not a simple random subsample. If none of
#'   these are provided, a warning is issued and Phase 2 selection is treated
#'   as SRS within Phase 1 strata.
#'
#' * `"approx"` — Approximation that ignores Phase 1 sampling variability.
#'   Faster but less accurate than `"full"` when the Phase 1 sampling fraction
#'   is non-negligible.
#'
#' * `"simple"` — Treats Phase 2 as a single-phase design, ignoring Phase 1.
#'   Only valid when Phase 1 is a census (no sampling). Issues a warning when
#'   Phase 1 has PSU cluster variables, because this understates variance for
#'   clustered designs.
#'
#' @return A `survey_twophase` object.
#'
#' @examples
#' # Minimal two-phase design: Phase 1 = full cohort, Phase 2 = random subset
#' df <- data.frame(
#'   id        = 1:20,
#'   wt        = rep(2, 20),
#'   in_phase2 = c(rep(TRUE, 10), rep(FALSE, 10)),
#'   y         = rnorm(20)
#' )
#' phase1 <- as_survey(df, weights = wt)
#' d2 <- as_survey_twophase(phase1, subset = in_phase2)
#'
#' # With Phase 2 stratification and inclusion probabilities
#' df2 <- data.frame(
#'   id          = 1:30,
#'   wt          = rep(3, 30),
#'   in_phase2   = c(rep(TRUE, 15), rep(FALSE, 15)),
#'   arm         = rep(c("A", "B", "C"), 10),
#'   subsamprate = rep(c(0.5, 0.7, 0.3), 10),
#'   y           = rnorm(30)
#' )
#' phase1b <- as_survey(df2, weights = wt)
#' d2b <- as_survey_twophase(
#'   phase1b,
#'   strata2 = arm,
#'   probs2  = subsamprate,
#'   subset  = in_phase2,
#'   method  = "full"
#' )
#'
#' @seealso
#'   [as_survey()] for Taylor series designs,
#'   [as_survey_rep()] for replicate-weight designs
#'
#' @family constructors
#' @export
as_survey_twophase <- function(
  phase1,
  ids2    = NULL,
  strata2 = NULL,
  probs2  = NULL,
  fpc2    = NULL,
  subset,
  method  = c("full", "approx", "simple")
) {
  call   <- match.call()
  method <- match.arg(method)

  # ── Error 19: phase1 must be a survey_taylor object ─────────────────────────

  if (!S7::S7_inherits(phase1, survey_taylor)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg phase1} must be a {.cls survey_taylor} object, not ",
          "{.cls {class(phase1)[[1L]]}}."
        ),
        "i" = "Create it first with {.fn as_survey}."
      ),
      class = "surveycore_error_phase1_class"
    )
  }

  data <- phase1@data

  # ── Error 20: subset is required ────────────────────────────────────────────

  subset_quo <- rlang::enquo(subset)
  if (rlang::quo_is_missing(subset_quo)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg subset} is required: a logical column indicating ",
          "Phase 2 membership"
        )
      ),
      class = "surveycore_error_subset_missing"
    )
  }

  subset_cols <- tidyselect::eval_select(subset_quo, data)

  # ── Error 21: subset must select exactly one column ──────────────────────────

  if (length(subset_cols) == 0L) {
    cli::cli_abort(
      c("x" = "{.arg subset} matched no columns in {.arg phase1}"),
      class = "surveycore_error_subset_missing"
    )
  }
  if (length(subset_cols) > 1L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg subset} must select exactly one column, not ",
          "{length(subset_cols)}"
        )
      ),
      class = "surveycore_error_subset_multiple"
    )
  }
  subset_var <- names(subset_cols)

  # ── Error 22: subset column must be logical ──────────────────────────────────

  if (!is.logical(data[[subset_var]])) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg subset} column {.field {subset_var}} must be logical, ",
          "not {.cls {class(data[[subset_var]])}}"
        )
      ),
      class = "surveycore_error_subset_not_logical"
    )
  }

  # ── Error 23: subset must be non-degenerate ──────────────────────────────────

  subset_vals <- data[[subset_var]]
  n_true      <- sum(subset_vals, na.rm = TRUE)
  n_total     <- length(subset_vals)
  if (all(subset_vals, na.rm = TRUE) || !any(subset_vals, na.rm = TRUE)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg subset} column {.field {subset_var}} must contain both ",
          "TRUE and FALSE values. ",
          "Found {n_true} TRUE out of {n_total} rows."
        )
      ),
      class = "surveycore_error_subset_degenerate"
    )
  }

  # ── Resolve optional Phase 2 design columns via tidy-select ─────────────────

  # ids2 (may select multiple columns for multi-stage Phase 2 clustering)
  ids2_quo <- rlang::enquo(ids2)
  if (rlang::quo_is_null(ids2_quo)) {
    ids2_vars <- NULL
  } else {
    ids2_cols <- tidyselect::eval_select(ids2_quo, data)
    ids2_vars <- if (length(ids2_cols) == 0L) NULL else names(ids2_cols)
  }

  # strata2 (must select exactly one column)
  strata2_quo <- rlang::enquo(strata2)
  if (rlang::quo_is_null(strata2_quo)) {
    strata2_var <- NULL
  } else {
    strata2_cols <- tidyselect::eval_select(strata2_quo, data)
    if (length(strata2_cols) > 1L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg strata2} must select exactly one column, not ",
            "{length(strata2_cols)}"
          )
        ),
        class = "surveycore_error_strata_multiple"
      )
    }
    strata2_var <- if (length(strata2_cols) == 0L) NULL else names(strata2_cols)
  }

  # probs2 (must select exactly one column)
  probs2_quo <- rlang::enquo(probs2)
  if (rlang::quo_is_null(probs2_quo)) {
    probs2_var <- NULL
  } else {
    probs2_cols <- tidyselect::eval_select(probs2_quo, data)
    if (length(probs2_cols) > 1L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg probs2} must select exactly one column, not ",
            "{length(probs2_cols)}"
          )
        ),
        class = "surveycore_error_weights_multiple"
      )
    }
    probs2_var <- if (length(probs2_cols) == 0L) NULL else names(probs2_cols)
  }

  # fpc2 (must select exactly one column)
  fpc2_quo <- rlang::enquo(fpc2)
  if (rlang::quo_is_null(fpc2_quo)) {
    fpc2_var <- NULL
  } else {
    fpc2_cols <- tidyselect::eval_select(fpc2_quo, data)
    if (length(fpc2_cols) > 1L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg fpc2} must select exactly one column, not ",
            "{length(fpc2_cols)}"
          )
        ),
        class = "surveycore_error_fpc_multiple"
      )
    }
    fpc2_var <- if (length(fpc2_cols) == 0L) NULL else names(fpc2_cols)
  }

  # ── Warning 24: method = "simple" with clustered Phase 1 ────────────────────

  if (method == "simple" && !is.null(phase1@variables$ids)) {
    cli::cli_warn(
      c(
        "!" = paste0(
          '{.code method = "simple"} ignores the Phase 1 cluster design ',
          "(PSUs: {.field {phase1@variables$ids}}). ",
          "This understates variance. ",
          'Use {.code method = "full"} or {.code method = "approx"}.'
        )
      ),
      class = "surveycore_warning_simple_clustered"
    )
  }

  # ── Warning 25: method = "full" with no Phase 2 design info ─────────────────

  no_phase2_info <- is.null(ids2_vars) && is.null(strata2_var) &&
                    is.null(probs2_var) && is.null(fpc2_var)
  if (method == "full" && no_phase2_info) {
    cli::cli_warn(
      c(
        "!" = paste0(
          'No Phase 2 design information provided with ',
          '{.code method = "full"}. ',
          "Phase 2 selection treated as simple random subsampling within ",
          "Phase 1 strata."
        )
      ),
      class = "surveycore_warning_full_no_phase2"
    )
  }

  # ── Build @variables list ────────────────────────────────────────────────────

  phase2_vars <- list(
    ids    = ids2_vars,
    strata = strata2_var,
    probs  = probs2_var,
    fpc    = fpc2_var
  )

  variables <- list(
    phase1       = phase1@variables,
    phase2       = phase2_vars,
    subset       = subset_var,
    method       = method,
    visible_vars = NULL
  )

  # ── Inherit metadata from phase1 ────────────────────────────────────────────

  metadata <- phase1@metadata

  # ── Construct and return survey_twophase object ──────────────────────────────

  survey_twophase(
    data      = data,
    metadata  = metadata,
    variables = variables,
    call      = call
  )
}


# ── as_survey_calibrated ───────────────────────────────────────────────────────

#' Create a Calibrated / Non-Probability Survey Design
#'
#' `r lifecycle::badge("experimental")`
#'
#' Creates a survey design object for non-probability samples and post-hoc
#' calibrated designs (e.g., raked online panels, post-stratified samples).
#' Accepts pre-computed calibration weights and optionally stores calibration
#' provenance from \pkg{surveyweights} output for reproducibility.
#'
#' @section Phase 2.5 skeleton:
#' This constructor is a **skeleton**. The resulting `survey_calibrated` object
#' supports estimation via a model-assisted SRS variance assumption — the same
#' as calling [as_survey()] with weights only. Full bootstrap re-calibration
#' variance (which re-applies the raking procedure on each replicate) will be
#' implemented in Phase 2.5 alongside the \pkg{surveyweights} package.
#'
#' @section When to use:
#' Use `as_survey_calibrated()` instead of [as_survey()] when:
#' \itemize{
#'   \item Your data comes from a non-probability sample (online panel, quota
#'     sample, MTurk/Prolific, etc.)
#'   \item You have calibration or raking weights but no probability sampling
#'     design structure (no PSU IDs, strata, etc.)
#'   \item You want to explicitly record the provenance of your calibration
#'     weights for reproducibility
#' }
#'
#' If your data comes from a probability sample with known design structure,
#' use [as_survey()], [as_survey_rep()], or [as_survey_twophase()] instead.
#'
#' @section Variance estimation note:
#' Standard errors from a `survey_calibrated` object assume simple random
#' sampling within the calibrated weights. This is consistent with common
#' applied practice for raked non-probability samples, but is technically
#' a model-assisted approximation rather than design-based variance. See
#' `vignette("creating-survey-objects")` for details and limitations.
#'
#' @param data A `data.frame` containing the survey responses with
#'   pre-computed calibration weights. Must have at least one row and
#'   unique column names.
#' @param weights <[`tidy-select`][tidyselect::language]> Calibration weight
#'   column (a single column, values strictly > 0). Typically produced by
#'   an external raking function (e.g., `anesrake::anesrake()`) or a
#'   \pkg{surveyweights} calibration function.
#' @param calibration Optional. The calibration provenance object returned by
#'   a \pkg{surveyweights} calibration function (e.g., `surveyweights::rake()`).
#'   Stored in `@calibration` for reproducibility. Supply `NULL` (the default)
#'   when calibration was performed externally and provenance metadata is not
#'   available. The object's structure is defined by \pkg{surveyweights} and will
#'   be formally specified in Phase 2.5.
#'
#' @return A `survey_calibrated` object.
#'
#' @examples
#' # Minimal: pre-computed calibration weights from an external tool
#' df <- data.frame(
#'   y      = rnorm(200),
#'   age    = sample(c("18-34", "35-54", "55+"), 200, replace = TRUE),
#'   cal_wt = runif(200, 0.5, 2.5)
#' )
#' d <- as_survey_calibrated(df, weights = cal_wt)
#'
#' @seealso
#'   [as_survey()] for probability designs with Taylor variance,
#'   [as_survey_rep()] for replicate-weight designs
#'
#' @family constructors
#' @export
as_survey_calibrated <- function(
  data,
  weights,
  calibration = NULL
) {
  call <- match.call()

  # ── Layer 3: data-level validation ─────────────────────────────────────────

  # Error 1: data must be a data frame
  if (!is.data.frame(data)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg data} must be a data frame, not ",
          "{.cls {class(data)[[1L]]}}"
        )
      ),
      class = "surveycore_error_not_data_frame"
    )
  }

  # Error 2: data must have at least one row
  if (nrow(data) == 0L) {
    cli::cli_abort(
      c("x" = "{.arg data} must have at least one row"),
      class = "surveycore_error_empty_data"
    )
  }

  # Error 3: column names must be unique
  if (anyDuplicated(names(data)) > 0L) {
    dupes <- unique(names(data)[duplicated(names(data))])
    cli::cli_abort(
      c(
        "x" = paste0(
          "Column names in {.arg data} must be unique. ",
          "Duplicates: {.field {dupes}}"
        )
      ),
      class = "surveycore_error_duplicate_names"
    )
  }

  # Warning 4: single-row data cannot support variance estimation
  if (nrow(data) == 1L) {
    cli::cli_warn(
      c("!" = "{.arg data} has only 1 row \u2014 variance cannot be estimated"),
      class = "surveycore_warning_single_row"
    )
  }

  # ── Resolve weights (required) ──────────────────────────────────────────────

  weights_quo <- rlang::enquo(weights)

  if (rlang::quo_is_missing(weights_quo)) {
    cli::cli_abort(
      c(
        "x" = "{.arg weights} is required for {.fn as_survey_calibrated}.",
        "i" = paste0(
          "Supply the column name of your calibration weight variable ",
          "(e.g., {.code weights = cal_wt})."
        )
      ),
      class = "surveycore_error_weights_missing"
    )
  }

  weights_cols <- tidyselect::eval_select(weights_quo, data)
  if (length(weights_cols) != 1L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg weights} must select exactly 1 column, ",
          "not {length(weights_cols)}"
        )
      ),
      class = "surveycore_error_weights_multiple"
    )
  }
  weights_var <- names(weights_cols)

  # ── Validate weight values ──────────────────────────────────────────────────

  .validate_weights(weights_var, data)

  # ── Extract haven metadata ──────────────────────────────────────────────────

  metadata <- .extract_haven_metadata(data)

  # ── Build @variables ────────────────────────────────────────────────────────

  variables <- list(
    weights        = weights_var,
    probs_provided = FALSE,
    visible_vars   = NULL
  )

  # ── Construct and return survey_calibrated object ───────────────────────────

  survey_calibrated(
    data        = data,
    metadata    = metadata,
    variables   = variables,
    calibration = calibration,
    call        = call
  )
}
