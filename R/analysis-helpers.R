# R/analysis-helpers.R
#
# Shared internal helpers for Phase 1 analysis functions.
# All functions are unexported. Single-use helpers for individual analysis
# functions live at the top of their respective source files.
#
# Contents:
#   Meta-key constants (six character vectors)
#   .degf_taylor()          — Taylor df formula (retained; not called by .degf())
#   .resolve_groups()       — combine @groups + group= arg
#   .apply_domain()         — extract domain membership mask
#   .build_meta()           — assemble .meta list
#   .make_result_tibble()   — assemble result tibble + attach metadata
#   .validate_shared_args() — validate variance/conf_level/name_style
#   .apply_name_style()     — rename columns for broom compatibility
#   .check_unsupported_class() — throw for non-survey-base objects
#   .add_variance_cols()    — compute requested uncertainty columns
#   .degf()                 — design degrees of freedom


# ── Meta-key constants ────────────────────────────────────────────────────────
#
# Required meta_args keys for each get_*() function. Pass the appropriate
# constant to .make_result_tibble() as required_meta_keys. The new nested
# structure uses "group" and "x" (or "numerator"/"denominator" for ratios)
# as top-level keys, replacing the old flat key sets.
# These are the single source of truth for each function's meta_args contract.
# Adding a new meta field requires updating only the constant here.

FREQS_META_KEYS     <- c("group", "x")
MEANS_META_KEYS     <- c("group", "x")
TOTALS_META_KEYS    <- c("group", "x")
CORR_META_KEYS      <- c("group", "x", "method")
QUANTILES_META_KEYS <- c("group", "x", "probs")
RATIOS_META_KEYS    <- c("group", "numerator", "denominator")
DIFFS_META_KEYS     <- c(
  "group", "x", "treats", "covariates", "family", "link",
  "pval_adj", "estimate_method", "mean_method", "estimate_scale"
)


# ── .extract_var_meta() ───────────────────────────────────────────────────────
#
# Returns a list(variable_label, question_preface, value_labels) for one
# variable. Checks @metadata first; falls back to haven attributes on the
# column when @metadata has no entry. For factor columns with no haven labels,
# surfaces levels() as value_labels in haven format: a named integer vector
# where names are level strings and values are sequential integers starting
# at 1L.
#
# @param design   A survey design object.
# @param var_name Character(1): column name in design@data.
# @return Named list with keys: variable_label, question_preface, value_labels.
.extract_var_meta <- function(design, var_name) {
  col <- design@data[[var_name]]

  variable_label <- design@metadata@variable_labels[[var_name]] %||%
    attr(col, "label", exact = TRUE)

  question_preface <- design@metadata@question_prefaces[[var_name]]

  value_labels <- design@metadata@value_labels[[var_name]] %||%
    attr(col, "labels", exact = TRUE)

  if (is.null(value_labels) && is.factor(col)) {
    lvls        <- levels(col)
    value_labels <- stats::setNames(seq_along(lvls), lvls)
    storage.mode(value_labels) <- "integer"
  }

  list(
    variable_label   = variable_label,
    question_preface = question_preface,
    value_labels     = value_labels
  )
}


# ── .build_group_meta() ───────────────────────────────────────────────────────
#
# Returns a named list, one entry per group variable, each being the output
# of .extract_var_meta(). Returns list() when group_vars is empty or has
# length 0.
#
# @param design     A survey design object.
# @param group_vars Character vector of group variable names.
# @return Named list of per-variable metadata lists.
.build_group_meta <- function(design, group_vars) {
  if (length(group_vars) == 0L) return(list())
  meta <- lapply(group_vars, function(gv) .extract_var_meta(design, gv))
  stats::setNames(meta, group_vars)
}


# ── .apply_group_labels() ─────────────────────────────────────────────────────
#
# Converts coded group columns in a group_combos data frame to labelled
# factors in-place. When label_values = FALSE, returns group_combos unchanged.
#
# Haven-labelled columns: the value_labels vector has names = label strings
# and values = numeric/integer codes. Produces a factor whose levels are
# the label strings ordered by code value (ascending numeric order).
#
# Plain R factor columns: re-factors using the original levels() order exactly.
#
# Other columns (unlabelled integer, character, etc.): returned unchanged.
#
# IMPORTANT: Must be called AFTER group_combos is sorted on raw codes.
# Sorting after label conversion would use factor level order, not raw numeric.
#
# @param group_combos A data.frame of group variable columns.
# @param group_vars   Character vector of group variable names (must be
#                     column names in group_combos and design@data).
# @param design       A survey design object.
# @param label_values Logical(1). When FALSE, returns group_combos unmodified.
# @return The (possibly modified) group_combos data frame.
.apply_group_labels <- function(group_combos, group_vars, design,
                                label_values = TRUE) {
  if (!label_values) return(group_combos)
  for (gv in group_vars) {
    col     <- group_combos[[gv]]
    src_col <- design@data[[gv]]

    labels <- design@metadata@value_labels[[gv]] %||%
      attr(src_col, "labels", exact = TRUE)

    if (!is.null(labels)) {
      # labels: c("Male" = 1, "Female" = 2) — names=label strings, values=codes
      # Build a map from regular code (as character) to label string.
      label_map <- stats::setNames(names(labels), as.character(unname(labels)))

      # Build a map from haven tagged-NA tag character to label string.
      # Requires haven at runtime; falls back gracefully when not installed:
      # tagged NAs without a resolvable tag remain NA in the factor output.
      haven_ok      <- requireNamespace("haven", quietly = TRUE)
      # Tagged NAs are always doubles (special NaN bit patterns). Build a map
      # from tag character to label string by checking double NA entries in
      # labels. Non-double NA entries (integer NA, etc.) are plain NAs.
      tagged_na_map <- list()
      if (haven_ok) {
        for (i in seq_along(labels)) {
          lv <- labels[[i]]
          if (is.na(lv) && is.double(lv)) {
            tag <- haven::na_tag(lv)
            if (!is.na(tag)) tagged_na_map[[tag]] <- names(labels)[[i]]
          }
        }
      }

      labeled_col <- vapply(col, function(val) {
        if (!is.na(val)) {
          lbl <- label_map[as.character(val)]
          if (is.na(lbl)) NA_character_ else lbl
        } else if (haven_ok && is.double(val)) {
          # Double NA: may be a haven tagged NA — try to resolve to label
          tag <- haven::na_tag(val)
          if (!is.na(tag) && !is.null(tagged_na_map[[tag]])) {
            tagged_na_map[[tag]]
          } else {
            NA_character_
          }
        } else {
          NA_character_
        }
      }, character(1L))

      # Build factor levels from label names, excluding plain-NA label entries.
      # Tagged-NA label entries (double NAs with a haven tag) ARE included.
      is_plain_na_label <- vapply(labels, function(x) {
        if (!is.na(x)) return(FALSE)
        if (!haven_ok || !is.double(x)) return(TRUE)
        is.na(haven::na_tag(x))
      }, logical(1L))
      group_combos[[gv]] <- factor(labeled_col, levels = names(labels)[!is_plain_na_label])
    } else if (is.factor(src_col)) {
      # Re-factor preserving original level order
      group_combos[[gv]] <- factor(as.character(col), levels = levels(src_col))
    }
    # else: leave unchanged (stays integer/numeric/character as-is)
  }
  group_combos
}


# ── .build_group_combos() ─────────────────────────────────────────────────────
#
# Build the data frame of unique group value combinations from domain_data
# (a data frame already filtered to the active domain rows, containing only
# group variable columns). When na.rm = TRUE, rows with any NA are excluded
# before unique(). When na.rm = FALSE, all rows including NA-containing are
# used. Output is sorted: non-NA-containing combos first (ascending), then
# NA-containing combos.
#
# @param domain_data  data.frame; rows = active domain; cols = group vars only
# @param na.rm        logical; if TRUE, NA rows excluded before unique()
# @return             data.frame of unique group combinations, sorted

# Sync note: spec §II is authoritative — keep this block in sync with the spec
# if either changes. Do not edit one without updating the other.
.build_group_combos <- function(domain_data, na.rm) {
  if (na.rm) {
    domain_data <- domain_data[stats::complete.cases(domain_data), , drop = FALSE]
  }
  combos <- unique(domain_data)
  if (nrow(combos) == 0L) return(combos)
  # Sort: non-NA combos first, NA combos last.
  # Leftmost group variable is the primary sort key.
  # unname() prevents column names from colliding with order()'s named
  # formals (decreasing, method, na.last) if a group var shares a name.
  # rownames reset AFTER subsetting — before would leave non-sequential names.
  sort_vecs        <- unname(lapply(names(combos), function(v) combos[[v]]))
  ord              <- do.call(order, c(sort_vecs, list(na.last = TRUE)))
  combos           <- combos[ord, , drop = FALSE]
  rownames(combos) <- NULL
  combos
}


# ── .match_group_combo() ──────────────────────────────────────────────────────
#
# Returns a logical vector indicating which rows in data_cols match the single
# group combination combo_row. Handles NA correctly: when combo_row[[gv]] is
# NA, matches rows where data_cols[[gv]] is also NA. This replaces the inline
# !is.na(gv_col) & (gv_col == cv) loop in all 6 analysis functions.
#
# data_cols must be full-design-length (not domain-filtered). Build as
# as.list(design@data[group_vars]) and apply domain_mask after:
# active_mask <- domain_mask & .match_group_combo(data_cols, combo_row).
#
# @param data_cols  named list; one element per group var; each a vector of
#                   length nrow(design@data) — full design, NOT domain-filtered
# @param combo_row  single-row data.frame; colnames match names(data_cols)
# @return           logical vector; TRUE where the row matches the combo

# Sync note: spec §II is authoritative — keep this block in sync with the spec
# if either changes. Do not edit one without updating the other.
.match_group_combo <- function(data_cols, combo_row) {
  match_vec <- rep(TRUE, length(data_cols[[1L]]))
  for (gv in names(combo_row)) {
    gv_col <- data_cols[[gv]]
    cv     <- combo_row[[gv]]
    if (is.na(cv)) {
      match_vec <- match_vec & is.na(gv_col)
    } else {
      match_vec <- match_vec & !is.na(gv_col) & (gv_col == cv)
    }
  }
  match_vec
}


# ── .degf_taylor() ─────────────────────────────────────────────────────────────
#
# Compute Taylor series degrees of freedom from a data frame + variables list.
# Retained for potential future use (e.g., deff computation, user-accessible
# degf). Not called by .degf() — all designs now use Inf (normal approx CI).
#
# Rules:
#   Stratified cluster: Σ(n_h - 1) = total PSUs - number of strata
#   Unstratified cluster: n_psus - 1
#   Stratified, no PSUs: n_obs - n_strata
#   No structure: n - 1
#
# @param data  A data.frame (the design's @data).
# @param vars  A named list with ids, strata, nest keys.
# @return      Numeric(1): degrees of freedom.
.degf_taylor <- function(data, vars) {
  ids_var    <- vars$ids
  strata_var <- vars$strata
  nest       <- isTRUE(vars$nest)

  if (!is.null(strata_var) && !is.null(ids_var)) {
    # Stratified cluster: Σ(n_h - 1) = total_psus - n_strata
    psu_col    <- as.character(data[[ids_var[[1L]]]])
    strata_col <- as.character(data[[strata_var]])
    if (nest) {
      # Make PSU IDs globally unique across strata before counting
      psu_col <- paste(strata_col, psu_col, sep = ".")
    }
    n_psus_per_stratum <- tapply(
      psu_col, strata_col, function(x) length(unique(x))
    )
    sum(n_psus_per_stratum) - length(n_psus_per_stratum)
  } else if (!is.null(ids_var)) {
    # Unstratified cluster: n_psus - 1
    psu_col <- as.character(data[[ids_var[[1L]]]])
    length(unique(psu_col)) - 1L
  } else if (!is.null(strata_var)) {
    # Stratified but no PSUs: n_obs - n_strata
    strata_col <- as.character(data[[strata_var]])
    nrow(data) - length(unique(strata_col))
  } else {
    # No design structure (SRS): n - 1
    nrow(data) - 1L
  }
}


# ── .resolve_groups() ─────────────────────────────────────────────────────────
#
# Combine grouping variables from @groups (set by group_by()) and the group=
# argument. The two sources are ANDed — both apply simultaneously. Returns
# a deduplicated character vector of group variable names, or character(0)
# if no groups are active.
#
# @param design     A survey design object.
# @param group_expr A quosure from rlang::enquo(group).
# @return character vector of group variable names.
.resolve_groups <- function(design, group_expr) {
  from_groups_prop <- design@groups
  from_arg         <- .resolve_tidy_select(group_expr, design@data)
  unique(c(from_groups_prop, from_arg))
}


# ── .apply_domain() ───────────────────────────────────────────────────────────
#
# Return a logical vector indicating which rows belong to the active domain.
# If no domain column is present, all rows are in-domain (all TRUE).
#
# Domain rows are NOT physically removed — the full design is used for correct
# variance estimation; only the estimation sum is restricted to in-domain rows.
#
# @param design A survey design object.
# @return logical vector of length nrow(design@data).
.apply_domain <- function(design) {
  if (SURVEYCORE_DOMAIN_COL %in% names(design@data)) {
    design@data[[SURVEYCORE_DOMAIN_COL]]
  } else {
    rep(TRUE, nrow(design@data))
  }
}


# ── .build_meta() ─────────────────────────────────────────────────────────────
#
# Assemble the structured .meta list. Derives design_type and n_respondents
# automatically from the design object; merges with meta_args (which carries
# the common fields conf_level, call, group_names, group_labels, and all
# function-specific fields).
#
# Valid design_type strings: "taylor", "replicate", "twophase", "srs",
# "calibrated". Downstream code branches on these exact strings.
#
# @param design    A survey design object.
# @param meta_args Named list of function-supplied metadata. Must include
#                  the common fields (conf_level, call, group_names,
#                  group_labels) plus all function-specific fields.
# @return Named list representing the full .meta structure.
.build_meta <- function(design, meta_args) {
  design_type <-
    if (S7::S7_inherits(design, survey_taylor))      "taylor"
    else if (S7::S7_inherits(design, survey_replicate))  "replicate"
    else if (S7::S7_inherits(design, survey_twophase))   "twophase"
    else if (S7::S7_inherits(design, survey_nonprob)) "calibrated"
    else cli::cli_abort(
      c("x" = "Unrecognized design class {.cls {class(design)[1L]}}."),
      class = "surveycore_error_unsupported_class"
    )

  c(
    list(
      design_type   = design_type,
      n_respondents = as.integer(nrow(design@data))
    ),
    meta_args
  )
}


# ── .make_result_tibble() ─────────────────────────────────────────────────────
#
# Assemble a survey_result tibble from pre-computed column vectors.
# Uses the column-by-column accumulation pattern (no vctrs/dplyr dependency).
#
# @param col_vecs           Named list of vectors; one per result column.
# @param groups_df          data.frame of group variable columns. Pass
#                           data.frame() when there are no grouping variables.
# @param class_name         Character(1): e.g. "survey_means".
# @param design             A survey design object (passed to .build_meta()).
# @param meta_args          Named list of metadata for the .meta attribute.
# @param required_meta_keys Character vector of required function-specific
#                           keys in meta_args. No default — always pass the
#                           function's *_META_KEYS constant. Omitting it is
#                           a programmer error.
# @return A tibble with class c(class_name, "survey_result", "tbl_df", ...).
.make_result_tibble <- function(
  col_vecs,
  groups_df,
  class_name,
  design,
  meta_args,
  required_meta_keys
) {
  stopifnot(all(required_meta_keys %in% names(meta_args)))
  result <- tibble::as_tibble(c(as.list(groups_df), col_vecs))
  attr(result, ".meta") <- .build_meta(design, meta_args)
  class(result) <- c(class_name, "survey_result", "tbl_df", "tbl", "data.frame")
  result
}


# ── .validate_shared_args() ───────────────────────────────────────────────────
#
# Validate the cross-cutting arguments that appear on all get_*() functions:
# variance, conf_level, name_style, and decimals.
#
# Call this as the FIRST action in every get_*() function, before any tidy-
# select resolution or estimation logic. This is the single canonical source
# for these validation errors — never duplicate the checks inside individual
# get_*() functions.
#
# Errors (from plans/error-messages.md):
#   surveycore_error_invalid_variance_arg  (row 45)
#   surveycore_error_invalid_conf_level    (row 45a)
#   surveycore_error_invalid_name_style    (row 46)
#   surveycore_error_invalid_decimals      (row 45b)
#
# @param variance       NULL or character vector of variance types.
# @param conf_level     Numeric scalar in (0, 1).
# @param name_style     "surveycore" or "broom".
# @param decimals       NULL or a non-negative whole number.
# @param valid_variance Character vector of accepted variance values.
# @param call           Caller environment for error attribution.
# @return invisible(TRUE) on success.
.validate_shared_args <- function(
  variance,
  conf_level,
  name_style,
  decimals       = NULL,
  na.rm          = TRUE,
  valid_variance = c("se", "ci", "var", "cv", "moe", "deff"),
  call = rlang::caller_env()
) {
  # Sync note: spec §V is authoritative — keep in sync if validation logic changes.
  if (!isTRUE(na.rm) && !isFALSE(na.rm)) {
    cli::cli_abort(
      c(
        "x" = "{.arg na.rm} must be {.code TRUE} or {.code FALSE}.",
        "i" = "Got {.obj_type_friendly {na.rm}}."
      ),
      class = "surveycore_error_na_rm_not_logical",
      call  = call
    )
  }
  if (!is.null(variance)) {
    bad_vals <- setdiff(variance, valid_variance)
    if (length(bad_vals) > 0L) {
      cli::cli_abort(
        c(
          "x" = "{.arg variance} values must be from {.or {.val {valid_variance}}}.",
          "i" = "Unknown value{?s}: {.val {bad_vals}}."
        ),
        class = "surveycore_error_invalid_variance_arg",
        call  = call
      )
    }
  }
  if (!is.numeric(conf_level) || length(conf_level) != 1L ||
      conf_level <= 0 || conf_level >= 1) {
    cli::cli_abort(
      c(
        "x" = "{.arg conf_level} must be a single number strictly between 0 and 1.",
        "i" = "Got {.val {conf_level}}."
      ),
      class = "surveycore_error_invalid_conf_level",
      call  = call
    )
  }
  if (!name_style %in% c("surveycore", "broom")) {
    cli::cli_abort(
      c(
        "x" = '{.arg name_style} must be {.val "surveycore"} or {.val "broom"}.',
        "i" = "Got {.val {name_style}}."
      ),
      class = "surveycore_error_invalid_name_style",
      call  = call
    )
  }
  if (!is.null(decimals)) {
    if (
      !is.numeric(decimals) ||
      length(decimals) != 1L ||
      decimals < 0 ||
      decimals != round(decimals)
    ) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg decimals} must be a non-negative whole number or ",
            "{.code NULL}."
          ),
          "i" = "Got {.val {decimals}}."
        ),
        class = "surveycore_error_invalid_decimals",
        call  = call
      )
    }
  }
  invisible(TRUE)
}


# ── .apply_decimals() ─────────────────────────────────────────────────────────
#
# Round all double-typed columns in a survey_result tibble to the specified
# number of decimal places. Integer columns (e.g., n) and non-numeric columns
# (group vars, character columns) are left unchanged. The .meta attribute and
# S3 class are preserved across rounding using the same pattern as
# .apply_name_style().
#
# @param result   A survey_result tibble.
# @param decimals A non-negative whole number.
# @return The result tibble with double columns rounded.
.apply_decimals <- function(result, decimals) {
  saved_meta  <- attr(result, ".meta")
  saved_class <- class(result)
  for (i in seq_along(result)) {
    if (is.double(result[[i]])) {
      result[[i]] <- round(result[[i]], decimals)
    }
  }
  attr(result, ".meta") <- saved_meta
  class(result) <- saved_class
  result
}


# ── .apply_name_style() ───────────────────────────────────────────────────────
#
# Rename result columns according to name_style. Called at the very end of
# each get_*() function. No-op when name_style = "surveycore" (the default).
# Preserves the .meta attribute and S3 class across the rename.
#
# Broom rename mapping (only columns that are present are renamed):
#   se           → std.error
#   ci_low       → conf.low
#   ci_high      → conf.high
#   p_value      → p.value
#   mean/total/pct/r/ratio/estimate → estimate
#   df           → parameter
#   (statistic is unchanged)
#
# @param result     A survey_result tibble.
# @param name_style "surveycore" (no-op) or "broom".
# @return The (possibly renamed) result tibble with class and .meta preserved.
.apply_name_style <- function(result, name_style, exclude = NULL) {
  if (name_style == "surveycore") return(result)

  broom_map <- c(
    se       = "std.error",
    ci_low   = "conf.low",
    ci_high  = "conf.high",
    p_value  = "p.value",
    mean     = "estimate",
    total    = "estimate",
    pct      = "estimate",
    r        = "estimate",
    ratio    = "estimate",
    estimate = "estimate",
    df       = "parameter"
  )

  cols_present <- names(result)
  to_rename    <- intersect(names(broom_map), cols_present)
  if (!is.null(exclude)) {
    to_rename <- setdiff(to_rename, exclude)
  }

  if (length(to_rename) > 0L) {
    saved_meta  <- attr(result, ".meta")
    saved_class <- class(result)
    names(result)[match(to_rename, names(result))] <- broom_map[to_rename]
    attr(result, ".meta") <- saved_meta
    class(result)         <- saved_class
  }

  result
}


# ── .check_unsupported_class() ────────────────────────────────────────────────
#
# Throw surveycore_error_unsupported_class when design does not inherit from
# survey_base. Call at the very start of every get_*() function, before any
# other validation or tidy-select resolution.
#
# Since Phase 0.75 is complete, this does NOT block survey_twophase — only
# objects that are not survey_base at all trigger the error.
#
# @param design  The first argument passed to a get_*() function.
# @param fn_name Character(1): calling function name for error messages.
# @return invisible(NULL) on success.
.check_unsupported_class <- function(design, fn_name) {
  if (!S7::S7_inherits(design, survey_base)) {
    cli::cli_abort(
      c(
        "x" = "{.fn {fn_name}} requires a survey design object.",
        "i" = "Got {.cls {class(design)[[1L]]}}."
      ),
      class = "surveycore_error_unsupported_class"
    )
  }
  invisible(NULL)
}


# ── .add_variance_cols() ──────────────────────────────────────────────────────
#
# Compute the requested uncertainty columns from a vector of standard errors.
# Called after the point estimate and SE are computed in each get_*() function.
# Returns only the columns requested in variance (order: se, var, cv, ci_low,
# ci_high, moe, deff).
#
# @param se_vec       Numeric vector of standard errors (length = n_cells).
# @param estimate_vec Numeric vector of point estimates (same length).
# @param se_srs_vec   Numeric vector of SRS-equivalent SEs (for deff).
#                     Pass NULL when deff not requested. For SRS designs,
#                     the calling function always passes se_srs_vec = se_vec.
# @param conf_level   Numeric scalar in (0, 1).
# @param degf         Degrees of freedom for qt() (scalar or vector).
# @param variance     NULL or character vector of requested variance types.
# @return Named list of numeric vectors (only requested columns included).
.add_variance_cols <- function(
  se_vec,
  estimate_vec,
  se_srs_vec = NULL,
  conf_level,
  degf,
  variance
) {
  if (is.null(variance)) return(list())

  out <- list()

  if ("se" %in% variance) {
    out$se <- se_vec
  }

  if ("var" %in% variance) {
    out$var <- se_vec^2
  }

  if ("cv" %in% variance) {
    cv       <- se_vec / estimate_vec
    is_undef <- !is.na(estimate_vec) & estimate_vec <= 0
    n_undef  <- sum(is_undef)
    if (n_undef > 0L) {
      cv[is_undef] <- NA_real_
      cli::cli_warn(
        c(
          "!" = paste0(
            '{.arg variance = "cv"} is undefined for {n_undef} ',
            "cell{?s} where the estimate is 0 or negative."
          ),
          "i" = "{.code cv} set to {.code NA} for those cells."
        ),
        class = "surveycore_warning_cv_undefined"
      )
    }
    out$cv <- cv
  }

  # Compute t_crit once — reused for both ci and moe
  if ("ci" %in% variance || "moe" %in% variance) {
    t_crit  <- stats::qt((1 + conf_level) / 2, df = degf)
    ci_low  <- estimate_vec - t_crit * se_vec
    ci_high <- estimate_vec + t_crit * se_vec
    if ("ci" %in% variance) {
      out$ci_low  <- ci_low
      out$ci_high <- ci_high
    }
    if ("moe" %in% variance) {
      out$moe <- (ci_high - ci_low) / 2
    }
  }

  if ("deff" %in% variance) {
    if (is.null(se_srs_vec) || all(se_srs_vec == 0, na.rm = TRUE)) {
      out$deff <- rep(NA_real_, length(se_vec))
    } else {
      out$deff <- (se_vec / se_srs_vec)^2
    }
  }

  out
}


# ── .degf() ───────────────────────────────────────────────────────────────────
#
# Return design-based degrees of freedom as a numeric scalar.
#
# Used by survey_glm() for t-distribution critical values in CIs and Wald
# tests. Phase 1 analysis functions (get_means, get_totals, etc.) use Inf
# directly (normal approximation matching survey::svymean() defaults) and do
# NOT call .degf().
#
# Design-specific formulas (matching survey::degf()):
#   Taylor:    Σ(n_h - 1) = total PSUs − number of strata (.degf_taylor())
#   Replicate: R − 1 where R = number of replicate columns
#   Twophase:  Phase-1 Taylor df
#   SRS:       n − 1
#   Calibrated: n − 1 (conservative approximation)
#
# @param design A survey design object.
# @return Numeric(1): degrees of freedom (always >= 1).
.degf <- function(design) {
  if (!S7::S7_inherits(design, survey_base)) {
    cli::cli_abort(
      c(
        "x" = "Cannot compute degrees of freedom for {.cls {class(design)[1L]}}."
      ),
      class = "surveycore_error_unsupported_class"
    )
  }
  if (S7::S7_inherits(design, survey_taylor)) {
    max(1, .degf_taylor(design@data, design@variables))
  } else if (S7::S7_inherits(design, survey_replicate)) {
    rep_mat <- as.matrix(
      design@data[, design@variables$repweights, drop = FALSE]
    )
    max(1L, ncol(rep_mat) - 1L)
  } else if (S7::S7_inherits(design, survey_twophase)) {
    subset   <- design@data[[design@variables$subset]]
    ph1_data <- design@data[subset, , drop = FALSE]
    max(1, .degf_taylor(ph1_data, design@variables$phase1))
  } else {
    # survey_nonprob, unknown
    max(1L, nrow(design@data) - 1L)
  }
}
