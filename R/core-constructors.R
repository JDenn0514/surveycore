# R/core-constructors.R
#
# Constructor functions for survey design objects.
#
# Functions defined here (Phase 0, steps 5–7 + Phase 2.5 skeleton):
#   as_survey_srs()         — creates a survey_srs object (equal-probability SRS)
#   as_survey()             — creates a survey_taylor object (Taylor series design)
#   as_survey_replicate()         — creates a survey_replicate object (replicate weights)
#   as_survey_twophase()    — creates a survey_twophase object (two-phase sampling)
#   as_survey_nonprob()  — creates a survey_nonprob object (Phase 2.5 skeleton)
#
# This file implements Layer 3 of the 3-layer validator architecture:
#   Layer 1 — S7 class validators      (R/00-s7-classes.R)
#   Layer 2 — reusable validator helpers (R/02-validators.R)
#   Layer 3 — constructor input parsing  (R/03-constructors.R)  <-- this file
#
# Error classes match plans/error-messages.md exactly (rows 1–25, 56–61).
# All cli_abort()/cli_warn() calls include a class= argument.

# ── as_survey_srs ──────────────────────────────────────────────────────────────

#' Create a Simple Random Sample Survey Design
#'
#' Creates a survey design object for equal-probability simple random samples
#' (SRS). Computes variances using the classical SRS formula
#' `var(ȳ) = (1 - f) × s² / n`, where `s²` is the unweighted sample variance,
#' `n` is the sample size, and `f = n/N` is the sampling fraction (0 when
#' population size is unknown).
#'
#' @param data A `data.frame` containing the survey responses. Must have at
#'   least one row and unique column names.
#' @param weights <[`tidy-select`][tidyselect::language]> Sampling weight
#'   column (a single column, values strictly > 0). Supply either `weights` or
#'   `probs`, not both. If both are `NULL`, uniform weights (`= 1`) are
#'   auto-assigned and a warning is issued; population totals will then
#'   equal sample totals, not estimated population totals.
#' @param probs <[`tidy-select`][tidyselect::language]> Sampling probability
#'   column (a single column, values in (0, 1]). Converted to weights
#'   `= 1/probs` and stored internally as `..surveycore_wt..`. Supply either
#'   `weights` or `probs`, not both.
#' @param fpc <[`tidy-select`][tidyselect::language]> Finite population
#'   correction column (a single column). Accepts either total population size
#'   (all values > 1) or sampling fraction (all values in (0, 1]). Cannot mix
#'   the two types. Cannot contain `NA` or non-positive values. If any FPC
#'   value (of population-size type) is less than the sample size, an error is
#'   thrown.
#'
#' @return A `survey_srs` object.
#'
#' @examples
#' # Minimal: no weights, no FPC (uniform weights auto-assigned)
#' d <- suppressWarnings(as_survey_srs(data.frame(y = 1:5)))
#'
#' @seealso [as_survey()] for designs with cluster or stratification structure,
#'   [as_survey_replicate()] for replicate-weight designs
#'
#' @family constructors
#' @export
as_survey_srs <- function(
  data,
  weights = NULL,
  probs = NULL,
  fpc = NULL
) {
  call <- match.call()

  # ── Layer 3: data-level validation ─────────────────────────────────────────
  .validate_data_frame(data)

  # ── Capture quosures ────────────────────────────────────────────────────────
  weights_quo <- rlang::enquo(weights)
  probs_quo <- rlang::enquo(probs)
  fpc_quo <- rlang::enquo(fpc)

  weights_is_null <- rlang::quo_is_null(weights_quo)
  probs_is_null <- rlang::quo_is_null(probs_quo)

  # ── Error 56: both weights and probs supplied ───────────────────────────────
  if (!weights_is_null && !probs_is_null) {
    cli::cli_abort(
      c(
        "x" = "Supply {.arg weights} or {.arg probs}, not both.",
        "i" = paste0(
          "Use {.arg weights} for sampling weights or ",
          "{.arg probs} for sampling probabilities."
        )
      ),
      class = "surveycore_error_weights_probs_both"
    )
  }

  # ── Probs → weights conversion ──────────────────────────────────────────────
  probs_provided <- FALSE

  if (!probs_is_null) {
    # Resolve probs column, compute 1/probs, store as internal weight column
    probs_var <- .resolve_single_col(
      probs_quo,
      data,
      "probs",
      class_none = "surveycore_error_weights_not_found",
      class_multi = "surveycore_error_weights_multiple"
    )
    weights_var <- .SURVEYCORE_WT_COL
    data[[weights_var]] <- 1 / data[[probs_var]]
    probs_provided <- TRUE
  } else if (!weights_is_null) {
    # Weights path: resolve column via tidy-select
    weights_var <- .resolve_single_col(
      weights_quo,
      data,
      "weights",
      class_none = "surveycore_error_weights_not_found",
      class_multi = "surveycore_error_weights_multiple"
    )
  } else {
    # No-weights fallback: auto-assign uniform weights (row 61)
    weights_var <- .SURVEYCORE_WT_COL
    data[[weights_var]] <- rep(1L, nrow(data))
    cli::cli_warn(
      c(
        "!" = paste0(
          "No {.arg weights} provided to {.fn as_survey_srs}. ",
          "Assigning uniform weights ({.code ..surveycore_wt.. = 1})."
        ),
        "i" = paste0(
          "Population size unknown \u2014 total estimates will use ",
          "{.code \u03a3w_i = n} as the estimated N."
        )
      ),
      class = "surveycore_warning_srs_no_weights"
    )
  }

  # ── Validate weights ────────────────────────────────────────────────────────
  .validate_weights(weights_var, data)

  # ── FPC checks (only when fpc is non-NULL) ──────────────────────────────────
  fpc_is_null <- rlang::quo_is_null(fpc_quo)
  fpc_type <- NULL

  if (!fpc_is_null) {
    # Resolve FPC column
    fpc_var <- .resolve_single_col(
      fpc_quo,
      data,
      "fpc",
      class_none = "surveycore_error_fpc_not_found",
      class_multi = "surveycore_error_fpc_multiple"
    )

    # FPC check 1: NA values (via Layer 2 helper)
    .validate_fpc(fpc_var, data)

    fpc_col <- data[[fpc_var]]
    n <- nrow(data)

    # FPC check 2: non-positive values (row 57)
    n_bad <- sum(fpc_col <= 0, na.rm = TRUE)
    if (n_bad > 0L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg fpc} column {.field {fpc_var}} has {n_bad} ",
            "non-positive value(s). FPC values must be > 0."
          ),
          "i" = paste0(
            "FPC must be either population sizes (> 1) or ",
            "sampling fractions (0 < f \u2264 1)."
          )
        ),
        class = "surveycore_error_fpc_nonpositive"
      )
    }

    # FPC check 3: ambiguous — mixes values > 1 and ≤ 1 (row 58)
    has_above_one <- any(fpc_col > 1, na.rm = TRUE)
    has_le_one <- any(fpc_col <= 1, na.rm = TRUE)
    if (has_above_one && has_le_one) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg fpc} column {.field {fpc_var}} mixes values > 1 ",
            "(population sizes) and values \u2264 1 (sampling fractions). ",
            "All FPC values must be consistently one type."
          ),
          "i" = paste0(
            "Use all values > 1 for population sizes, or all values ",
            "in (0, 1] for sampling fractions."
          )
        ),
        class = "surveycore_error_fpc_ambiguous"
      )
    }

    # FPC check 4: population size < sample size (row 59)
    if (has_above_one) {
      n_bad <- sum(fpc_col < n, na.rm = TRUE)
      if (n_bad > 0L) {
        cli::cli_abort(
          c(
            "x" = paste0(
              "{.arg fpc} column {.field {fpc_var}} has {n_bad} ",
              "value(s) smaller than the sample size ({n}). ",
              "Population size cannot be smaller than the number of ",
              "sampled units."
            ),
            "i" = paste0(
              "Check your FPC column. For sampling fractions, ",
              "supply values in (0, 1] instead."
            )
          ),
          class = "surveycore_error_fpc_below_sample"
        )
      }
    }

    # Detect fpc_type after all checks pass
    fpc_type <- if (has_above_one) "population" else "fraction"
  } else {
    fpc_var <- NULL
  }

  # ── Extract haven-style metadata ────────────────────────────────────────────
  metadata <- .extract_haven_metadata(data)
  metadata <- .promote_weighting_history(data, metadata)

  # ── Build @variables list (all 8 keys always present) ──────────────────────
  variables <- list(
    weights = weights_var,
    fpc = fpc_var,
    fpc_type = fpc_type,
    probs_provided = probs_provided,
    ids = NULL,
    strata = NULL,
    nest = FALSE,
    visible_vars = NULL
  )

  # ── Construct and return survey_srs object ──────────────────────────────────
  survey_srs(
    data = data,
    metadata = metadata,
    variables = variables,
    call = call
  )
}


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
#'   correction column(s). For single-stage designs, supply one column.
#'   For multi-stage designs, supply one column per stage:
#'   `fpc = c(fpc_stage1, fpc_stage2)`. Each column accepts either total
#'   population size (integer, all > 1) or sampling fraction (numeric,
#'   all in (0, 1]). Cannot contain `NA`. Cannot have more columns than
#'   `ids` stages; fewer is allowed (later stages assume infinite population).
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
#' @section Known limitations:
#' `as_survey()` does not support probability-proportional-to-size (PPS)
#' variance estimation. Taylor series linearization treats all designs as
#' with-replacement, which overestimates (is conservative for) variance in
#' PPS-without-replacement designs. The Yates-Grundy and Brewer/Overton
#' estimators available in [survey::svydesign()] via its `pps` and `variance`
#' arguments are not supported.
#'
#' If your design requires PPS-specific variance estimation, create the design
#' with [survey::svydesign()] and convert it with [from_svydesign()]:
#' ```r
#' d_survey <- survey::svydesign(
#'   ids = ~psu, weights = ~wt, strata = ~stratum,
#'   pps = "brewer", data = mydata
#' )
#' d <- from_svydesign(d_survey)
#' ```
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
#'   [as_survey_replicate()] for replicate-weight designs,
#'   [as_survey_twophase()] for two-phase designs,
#'   [set_var_label()] to add variable labels
#'
#' @family constructors
#' @export
as_survey <- function(
  data,
  ids = NULL,
  probs = NULL,
  weights = NULL,
  strata = NULL,
  fpc = NULL,
  nest = FALSE
) {
  call <- match.call()

  # ── Layer 3: data-level validation ─────────────────────────────────────────
  .validate_data_frame(data)

  # ── Capture all quosures at top (before any resolution) ────────────────────
  ids_quo <- rlang::enquo(ids)
  probs_quo <- rlang::enquo(probs)
  weights_quo <- rlang::enquo(weights)
  strata_quo <- rlang::enquo(strata)
  fpc_quo <- rlang::enquo(fpc)

  # ── SRS dispatch: when ids and strata are both NULL ─────────────────────────
  # Forward to as_survey_srs() via rlang::inject() to preserve tidy-select NSE.
  ids_is_null <- rlang::quo_is_null(ids_quo)
  strata_is_null <- rlang::quo_is_null(strata_quo)

  if (ids_is_null && strata_is_null) {
    cli::cli_inform(
      c(
        "i" = paste0(
          "No {.arg ids} or {.arg strata} specified; ",
          "creating a {.cls survey_srs} design."
        ),
        "i" = "Use {.fn as_survey_srs} to avoid this message."
      ),
      class = "surveycore_message_as_survey_srs_fallback"
    )
    return(rlang::inject(as_survey_srs(
      data,
      weights = !!weights_quo,
      probs = !!probs_quo,
      fpc = !!fpc_quo
    )))
  }

  # ── Taylor path: resolve tidy-select expressions ────────────────────────────

  # ids (may select multiple columns for multi-stage designs)
  if (rlang::quo_is_null(ids_quo)) {
    ids_vars <- NULL
  } else {
    ids_cols <- tidyselect::eval_select(ids_quo, data)
    ids_vars <- names(ids_cols)
  }

  probs_var <- .resolve_single_col(
    probs_quo,
    data,
    "probs",
    class_none = "surveycore_error_weights_not_found",
    class_multi = "surveycore_error_weights_multiple"
  )
  weights_var <- .resolve_single_col(
    weights_quo,
    data,
    "weights",
    class_none = "surveycore_error_weights_not_found",
    class_multi = "surveycore_error_weights_multiple"
  )
  strata_var <- .resolve_single_col(
    strata_quo,
    data,
    "strata",
    class_none = "surveycore_error_strata_not_found",
    class_multi = "surveycore_error_strata_multiple"
  )
  # fpc (may select multiple columns for multi-stage designs)
  if (rlang::quo_is_null(fpc_quo)) {
    fpc_vars <- NULL
  } else {
    fpc_cols <- tidyselect::eval_select(fpc_quo, data)
    if (length(fpc_cols) == 0L) {
      cli::cli_abort(
        c("x" = "{.arg fpc} matched no columns in {.arg data}"),
        class = "surveycore_error_fpc_not_found"
      )
    }
    fpc_vars <- names(fpc_cols)
  }

  # ── Probs / weights reconciliation ─────────────────────────────────────────

  probs_provided <- FALSE

  if (!is.null(probs_var) && !is.null(weights_var)) {
    # Both specified — check for consistency
    computed_wt <- 1 / data[[probs_var]]
    provided_wt <- data[[weights_var]]
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
      ),
      class = "surveycore_inform_probs_weights_consistent"
    )
    probs_provided <- TRUE
  } else if (!is.null(probs_var) && is.null(weights_var)) {
    # Only probs provided — convert to weights
    weights_var <- .SURVEYCORE_WT_COL
    data[[weights_var]] <- 1 / data[[probs_var]]
    probs_provided <- TRUE
  } else if (is.null(probs_var) && is.null(weights_var)) {
    # Neither probs nor weights — SRS fallback
    # Warning 7: no weights or probs (SRS fallback); text varies by ids presence
    weights_var <- .SURVEYCORE_WT_COL
    data[[weights_var]] <- rep(1L, nrow(data))
    probs_provided <- FALSE

    if (!is.null(ids_vars)) {
      cli::cli_warn(
        c(
          "!" = "No weights provided.",
          "i" = paste0(
            "Treating as equal-probability sampling within clusters ",
            "(unknown population size)."
          ),
          "i" = paste0(
            "Population totals will equal sample totals, not ",
            "estimated population totals."
          )
        ),
        class = "surveycore_warning_srs_no_weights"
      )
    } else {
      cli::cli_warn(
        c(
          "!" = "No weights or population size provided.",
          "i" = paste0(
            "Treating as equal-probability SRS with unknown ",
            "population size."
          ),
          "i" = paste0(
            "Population totals will equal sample totals, not ",
            "estimated population totals."
          )
        ),
        class = "surveycore_warning_srs_no_weights"
      )
    }
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

  # ── Multi-stage FPC validation ──────────────────────────────────────────────

  if (!is.null(fpc_vars)) {
    n_fpc <- length(fpc_vars)
    n_ids <- if (is.null(ids_vars)) 1L else length(ids_vars)

    # Error 88: fpc has more columns than ID stages
    if (n_fpc > n_ids) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg fpc} selected {n_fpc} column(s) but ",
            "{.arg ids} has only {n_ids} stage(s)."
          ),
          "i" = paste0(
            "FPC columns must correspond 1-to-1 with ID stages. ",
            "Supply at most {n_ids} FPC column(s)."
          )
        ),
        class = "surveycore_error_fpc_too_many_stages"
      )
    }

    # Warning 89: fpc has fewer columns than ID stages
    if (n_fpc < n_ids) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "{.arg fpc} has {n_fpc} column(s) but ",
            "{.arg ids} has {n_ids} stage(s)."
          ),
          "i" = paste0(
            "Later stages assume sampling from an infinite ",
            "population (no FPC)."
          )
        ),
        class = "surveycore_warning_fpc_partial_stages"
      )
    }

    # Per-column FPC validation loop
    for (j in seq_along(fpc_vars)) {
      fpc_var_j <- fpc_vars[[j]]
      fpc_col_j <- data[[fpc_var_j]]

      # FPC check: NA values (reuse Layer 2 helper for each column)
      .validate_fpc(fpc_var_j, data)

      # FPC check: non-positive values (row 57)
      n_bad <- sum(fpc_col_j <= 0, na.rm = TRUE)
      if (n_bad > 0L) {
        cli::cli_abort(
          c(
            "x" = paste0(
              "{.arg fpc} column {.field {fpc_var_j}} has {n_bad} ",
              "non-positive value(s). FPC values must be > 0."
            ),
            "i" = paste0(
              "FPC must be either population sizes (> 1) or ",
              "sampling fractions (0 < f \u2264 1)."
            )
          ),
          class = "surveycore_error_fpc_nonpositive"
        )
      }

      # Determine if this column is population size or fraction
      has_above_one <- any(fpc_col_j > 1, na.rm = TRUE)
      has_le_one <- any(fpc_col_j <= 1, na.rm = TRUE)

      # FPC check: ambiguous (mixes > 1 and <= 1) — row 58
      if (has_above_one && has_le_one) {
        cli::cli_abort(
          c(
            "x" = paste0(
              "{.arg fpc} column {.field {fpc_var_j}} mixes ",
              "values > 1 (population sizes) and values ",
              "\u2264 1 (sampling fractions). All FPC values ",
              "must be consistently one type."
            ),
            "i" = paste0(
              "Use all values > 1 for population sizes, or ",
              "all values in (0, 1] for sampling fractions."
            )
          ),
          class = "surveycore_error_fpc_ambiguous"
        )
      }

      # Stage-j-aware checks: parent cluster grouping
      if (has_above_one) {
        # Population size type: check within parent clusters
        # For stage 1: group by strata (if present) or treat as one group
        # For stage j>1: group by the (j-1)th ID column
        if (j == 1L) {
          parent_col <- if (!is.null(strata_var)) {
            data[[strata_var]]
          } else {
            rep(1L, nrow(data))
          }
        } else {
          parent_col <- data[[ids_vars[[j - 1L]]]]
        }

        # Error 90: FPC pop size < cluster count within parent
        parent_groups <- split(
          seq_len(nrow(data)),
          parent_col
        )
        n_bad_parents <- 0L
        for (grp_rows in parent_groups) {
          fpc_val <- fpc_col_j[grp_rows[[1L]]]
          # Count clusters at this stage within this parent
          if (j <= length(ids_vars)) {
            n_clusters <- length(
              unique(data[[ids_vars[[j]]]][grp_rows])
            )
          } else {
            n_clusters <- length(grp_rows)
          }
          if (fpc_val < n_clusters) {
            n_bad_parents <- n_bad_parents + 1L
          }
        }

        if (n_bad_parents > 0L) {
          cli::cli_abort(
            c(
              "x" = paste0(
                "Stage-{j} FPC column {.field {fpc_var_j}} has ",
                "population sizes smaller than the observed ",
                "cluster count in {n_bad_parents} parent ",
                "group(s)."
              ),
              "i" = paste0(
                "Population size must be >= the number of ",
                "sampled units within each parent cluster."
              )
            ),
            class = "surveycore_error_fpc_smaller_than_n"
          )
        }
      } else {
        # Fraction type: check constancy within parent clusters
        if (j == 1L) {
          parent_col <- if (!is.null(strata_var)) {
            data[[strata_var]]
          } else {
            rep(1L, nrow(data))
          }
        } else {
          parent_col <- data[[ids_vars[[j - 1L]]]]
        }

        parent_groups <- split(
          seq_len(nrow(data)),
          parent_col
        )
        any_not_constant <- FALSE
        for (grp_rows in parent_groups) {
          vals <- fpc_col_j[grp_rows]
          if (length(unique(vals)) > 1L) {
            any_not_constant <- TRUE
            break
          }
        }

        if (any_not_constant) {
          cli::cli_abort(
            c(
              "x" = paste0(
                "Stage-{j} FPC column {.field {fpc_var_j}} is ",
                "not constant within parent clusters."
              ),
              "i" = paste0(
                "FPC fractions must be the same for all units ",
                "within each parent cluster."
              )
            ),
            class = "surveycore_error_fpc_not_constant"
          )
        }
      }
    }
  }

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
    ids = ids_vars,
    weights = weights_var,
    strata = strata_var,
    fpc = fpc_vars,
    nest = isTRUE(nest),
    probs_provided = probs_provided,
    visible_vars = NULL
  )

  # ── Extract haven-style metadata ────────────────────────────────────────────

  metadata <- .extract_haven_metadata(data)
  metadata <- .promote_weighting_history(data, metadata)

  # ── Construct and return survey_taylor object ───────────────────────────────

  survey_taylor(
    data = data,
    metadata = metadata,
    variables = variables,
    call = call
  )
}


# ── as_survey_replicate ──────────────────────────────────────────────────────────────

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
#' as_survey_replicate(df, weights = wt, repweights = starts_with("repwt"), type = "BRR")
#' # c() for explicit replicate columns
#' as_survey_replicate(df, weights = wt, repweights = c(rep1, rep2, rep3), type = "JK1")
#' ```
#'
#' @section Replicate weight matrix:
#' The replicate weight matrix is **not stored** in the object. Only the
#' column names are stored in `@variables$repweights`. Variance estimation
#' computes the matrix on demand:
#' `as.matrix(design@data[, design@variables$repweights])`.
#'
#' @section Memory usage:
#' Each call to an estimation function (e.g., [get_means()], [get_totals()])
#' materialises the full replicate weight matrix from the data frame. For large
#' designs (e.g., ACS PUMS with 500k+ rows × 80 replicates), this is roughly
#' `nrow * n_replicates * 8` bytes per call (~363 MB for ACS Wyoming × 80).
#' If you are estimating many variables, this is repeated for each call.
#' This behaviour matches the `survey` package reference implementation.
#'
#' @examples
#' # ACS PUMS Wyoming: 80 successive-difference replicate weights
#' d_acs <- as_survey_replicate(
#'   acs_pums_wy,
#'   weights    = pwgtp,
#'   repweights = pwgtp1:pwgtp80,
#'   type       = "successive-difference"
#' )
#'
#' # Explicit replicate columns using c()
#' d_sub <- as_survey_replicate(
#'   acs_pums_wy,
#'   weights    = pwgtp,
#'   repweights = c(pwgtp1, pwgtp2, pwgtp3, pwgtp4),
#'   type       = "JK1"
#' )
#'
#' @seealso
#'   [as_survey()] for Taylor series designs,
#'   [as_survey_twophase()] for two-phase designs,
#'   [set_var_label()] to add variable labels
#'
#' @family constructors
#' @export
as_survey_replicate <- function(
  data,
  weights,
  repweights,
  type = c(
    "JK1",
    "JK2",
    "JKn",
    "BRR",
    "Fay",
    "bootstrap",
    "ACS",
    "successive-difference",
    "other"
  ),
  scale = NULL,
  rscales = NULL,
  fpc = NULL,
  fpctype = c("fraction", "correction"),
  mse = TRUE
) {
  call <- match.call()
  type <- match.arg(type)
  fpctype <- match.arg(fpctype)

  # ── Layer 3: data-level validation ─────────────────────────────────────────
  .validate_data_frame(data)

  # ── Resolve tidy-select expressions ────────────────────────────────────────

  # weights (must select exactly one column; R function signature already
  # requires it — no default, so missing arg is caught by R before we run)
  weights_var <- .resolve_single_col(
    rlang::enquo(weights),
    data,
    "weights",
    class_none = "surveycore_error_weights_not_found",
    class_multi = "surveycore_error_weights_multiple"
  )

  # repweights (must select at least one column)
  repweights_quo <- rlang::enquo(repweights)
  repweights_cols <- tidyselect::eval_select(repweights_quo, data)
  if (length(repweights_cols) == 0L) {
    cli::cli_abort(
      c("x" = "{.arg repweights} must select at least one column"),
      class = "surveycore_error_repweights_empty"
    )
  }
  repweights_vars <- names(repweights_cols)
  n_rep <- length(repweights_vars)

  fpc_var <- .resolve_single_col(
    rlang::enquo(fpc),
    data,
    "fpc",
    class_none = "surveycore_error_fpc_not_found",
    class_multi = "surveycore_error_fpc_multiple"
  )

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
    scale <- switch(
      type,
      JK1 = (n_rep - 1L) / n_rep,
      JK2 = (n_rep - 1L) / n_rep,
      JKn = (n_rep - 1L) / n_rep,
      # BRR variance formula: (1/R) * sum((theta_r - theta)^2). The survey
      # package hardcodes this same formula internally (scale= is ignored for
      # BRR). Oracle test in test-variance-replicate.R verifies agreement.
      BRR = 1 / n_rep,
      Fay = 1 / n_rep,
      bootstrap = 1 / n_rep,
      ACS = 1 / n_rep,
      `successive-difference` = 2 / n_rep,
      other = 1
    )
  }

  # ── Build @variables list ───────────────────────────────────────────────────

  variables <- list(
    weights = weights_var,
    repweights = repweights_vars,
    type = type,
    scale = scale,
    rscales = rscales,
    fpc = fpc_var,
    fpctype = fpctype,
    mse = isTRUE(mse),
    visible_vars = NULL
  )

  # ── Extract haven-style metadata ────────────────────────────────────────────

  metadata <- .extract_haven_metadata(data)
  metadata <- .promote_weighting_history(data, metadata)

  # ── Construct and return survey_replicate object ────────────────────────────

  survey_replicate(
    data = data,
    metadata = metadata,
    variables = variables,
    call = call
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
#' @param phase1 A survey design object (inheriting from `survey_base`)
#'   representing the Phase 1 design. Accepts `survey_taylor`,
#'   `survey_srs`, or `survey_replicate` objects.
#'   Its `@data` must contain ALL rows from both phases, plus a logical
#'   indicator column for Phase 2 membership. Create with [as_survey()],
#'   [as_survey_srs()], or [as_survey_replicate()].
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
#' phase1 <- as_survey(df, ids = id, weights = wt)
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
#' phase1b <- as_survey(df2, ids = id, weights = wt)
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
#'   [as_survey_replicate()] for replicate-weight designs
#'
#' @family constructors
#' @export
as_survey_twophase <- function(
  phase1,
  ids2 = NULL,
  strata2 = NULL,
  probs2 = NULL,
  fpc2 = NULL,
  subset,
  method = c("full", "approx", "simple")
) {
  call <- match.call()
  method <- match.arg(method)

  # ── Error 19: phase1 must be a survey design object ─────────────────────────

  if (!S7::S7_inherits(phase1, survey_base)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg phase1} must be a survey design object ",
          "({.cls survey_base}), not {.cls {class(phase1)[[1L]]}}."
        ),
        "i" = paste0(
          "Create it first with {.fn as_survey}, ",
          "{.fn as_survey_srs}, or {.fn as_survey_replicate}."
        )
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

  # Error: NAs in subset column — phase 2 membership must be fully observed.
  n_na <- sum(is.na(subset_vals))
  if (n_na > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg subset} column {.field {subset_var}} contains {n_na} ",
          "NA value(s)."
        ),
        "i" = paste0(
          "The phase 2 membership indicator must be fully observed ",
          "for all phase 1 units."
        ),
        "v" = paste0(
          "Remove rows with missing {.arg subset} values before calling ",
          "{.fn as_survey_twophase}."
        )
      ),
      class = "surveycore_error_subset_na"
    )
  }

  n_true <- sum(subset_vals, na.rm = TRUE)
  n_false <- sum(!subset_vals, na.rm = TRUE)
  if (n_true == 0L || n_false == 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg subset} column {.field {subset_var}} must contain both ",
          "TRUE and FALSE values (non-NA). ",
          "Found {n_true} TRUE and {n_false} FALSE (non-NA) value(s)."
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

  strata2_var <- .resolve_single_col(
    rlang::enquo(strata2),
    data,
    "strata2",
    class_none = "surveycore_error_strata_not_found",
    class_multi = "surveycore_error_strata_multiple"
  )
  probs2_var <- .resolve_single_col(
    rlang::enquo(probs2),
    data,
    "probs2",
    class_none = "surveycore_error_weights_not_found",
    class_multi = "surveycore_error_weights_multiple"
  )
  fpc2_var <- .resolve_single_col(
    rlang::enquo(fpc2),
    data,
    "fpc2",
    class_none = "surveycore_error_fpc_not_found",
    class_multi = "surveycore_error_fpc_multiple"
  )

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

  # ── Build @variables list ────────────────────────────────────────────────────

  phase2_vars <- list(
    ids = ids2_vars,
    strata = strata2_var,
    probs = probs2_var,
    fpc = fpc2_var
  )

  variables <- list(
    phase1 = phase1@variables,
    phase2 = phase2_vars,
    subset = subset_var,
    method = method,
    visible_vars = NULL
  )

  # ── Inherit metadata from phase1 ────────────────────────────────────────────

  metadata <- phase1@metadata

  # ── Construct and return survey_twophase object ──────────────────────────────

  survey_twophase(
    data = data,
    metadata = metadata,
    variables = variables,
    call = call
  )
}


# ── as_survey_nonprob ───────────────────────────────────────────────────────

#' Create a Calibrated / Non-Probability Survey Design
#'
#' `r lifecycle::badge("experimental")`
#'
#' Creates a survey design object for non-probability samples and post-hoc
#' calibrated designs (e.g., raked online panels, post-stratified samples).
#' Accepts pre-computed calibration weights and optionally stores calibration
#' provenance from \pkg{surveywts} output for reproducibility.
#'
#' @section Phase 2.5 skeleton:
#' This constructor is a **skeleton**. The resulting `survey_nonprob` object
#' supports estimation via a model-assisted SRS variance assumption — the same
#' as calling [as_survey()] with weights only. Full bootstrap re-calibration
#' variance (which re-applies the raking procedure on each replicate) will be
#' implemented in Phase 2.5 alongside the \pkg{surveywts} package.
#'
#' @section When to use:
#' Use `as_survey_nonprob()` instead of [as_survey()] when:
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
#' use [as_survey()], [as_survey_replicate()], or [as_survey_twophase()] instead.
#'
#' @section Variance estimation note:
#' Standard errors from a `survey_nonprob` object assume simple random
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
#'   \pkg{surveywts} calibration function.
#' @param calibration Optional. The calibration provenance object returned by
#'   a \pkg{surveywts} calibration function (e.g., `surveywts::rake()`).
#'   Stored in `@calibration` for reproducibility. Supply `NULL` (the default)
#'   when calibration was performed externally and provenance metadata is not
#'   available. The object's structure is defined by \pkg{surveywts} and will
#'   be formally specified in Phase 2.5.
#'
#' @return A `survey_nonprob` object.
#'
#' @examples
#' # Minimal: pre-computed calibration weights from an external tool
#' df <- data.frame(
#'   y      = rnorm(200),
#'   age    = sample(c("18-34", "35-54", "55+"), 200, replace = TRUE),
#'   cal_wt = runif(200, 0.5, 2.5)
#' )
#' d <- as_survey_nonprob(df, weights = cal_wt)
#'
#' @seealso
#'   [as_survey()] for probability designs with Taylor variance,
#'   [as_survey_replicate()] for replicate-weight designs
#'
#' @family constructors
#' @export
as_survey_nonprob <- function(
  data,
  weights,
  calibration = NULL
) {
  call <- match.call()

  # ── Layer 3: data-level validation ─────────────────────────────────────────
  .validate_data_frame(data)

  # ── Resolve weights (required) ──────────────────────────────────────────────

  weights_quo <- rlang::enquo(weights)

  if (rlang::quo_is_missing(weights_quo)) {
    cli::cli_abort(
      c(
        "x" = "{.arg weights} is required for {.fn as_survey_nonprob}.",
        "i" = paste0(
          "Supply the column name of your calibration weight variable ",
          "(e.g., {.code weights = cal_wt})."
        )
      ),
      class = "surveycore_error_weights_missing"
    )
  }

  weights_var <- .resolve_single_col(
    weights_quo,
    data,
    "weights",
    class_none = "surveycore_error_weights_not_found",
    class_multi = "surveycore_error_weights_multiple"
  )

  # ── Validate weight values ──────────────────────────────────────────────────

  .validate_weights(weights_var, data)

  # ── Extract haven metadata ──────────────────────────────────────────────────

  metadata <- .extract_haven_metadata(data)

  # ── Build @variables ────────────────────────────────────────────────────────

  variables <- list(
    weights = weights_var,
    probs_provided = FALSE,
    ids = NULL,
    strata = NULL,
    fpc = NULL,
    nest = FALSE,
    visible_vars = NULL
  )

  # ── Construct and return survey_nonprob object ───────────────────────────

  survey_nonprob(
    data = data,
    metadata = metadata,
    variables = variables,
    calibration = calibration,
    call = call
  )
}
