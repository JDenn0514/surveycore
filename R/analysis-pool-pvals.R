# R/analysis-pool-pvals.R
#
# Cross-DV multiplicity correction across a list of surveycore analysis
# result tibbles. Exported functions: pool_pvals(),
# print.survey_pooled_pvals(). Shared helpers live in R/analysis-helpers.R
# (.is_plain_list, .validate_pval_adjustment_method, .validate_list_columns).

#' Pool p-values across a list of analysis results and apply a single
#' family-wise multiplicity correction
#'
#' Row-binds a list of analysis result tibbles (each carrying a
#' `p_value` column produced by `get_diffs()`, `get_t_test()`,
#' `get_pairwise()`, `get_anova()`, `clean.survey_glm_fit()`, or any
#' future `get_*()` carrying a `p_value` column) into a single family
#' and applies `stats::p.adjust()` once across the entire pool.
#'
#' @param results A list (named or unnamed) of tibbles / data frames.
#'   Every element must contain a column named per `p_col`. Length
#'   must be at least one. List elements may have heterogeneous column
#'   sets; missing columns are NA-filled on bind.
#' @param method Character(1). Adjustment method, passed verbatim to
#'   `stats::p.adjust()`. One of `stats::p.adjust.methods`. Default
#'   `"BH"`.
#' @param p_col Character(1). Name of the column holding raw p-values
#'   to be pooled. Default `"p_value"`. Must exist in every list
#'   element.
#' @param new_col Character(1). Name of the column where pooled-
#'   adjusted p-values are written. Default `"p_value_adj"`.
#' @param id_col Character(1). Name of the source-identifier column
#'   added to the bound output. Default `"source"`. Filled from list
#'   names; for unnamed elements the integer index is coerced to
#'   character (matching `dplyr::bind_rows(.id = ...)` semantics).
#' @param strip_within_adj Logical(1). If `FALSE` (default) and any
#'   input contains a column named per `new_col`, that column is
#'   renamed to `paste0(new_col, "_within")` per element before
#'   binding, and a warning is emitted. If `TRUE`, any pre-existing
#'   `new_col` column is silently dropped from each element before
#'   binding; no warning.
#'
#' @return An object of S3 class `c("survey_pooled_pvals", "tbl_df",
#'   "tbl", "data.frame")` -- a tibble with an additional class tag.
#'   Column ordering: (1) the union of input columns in input-union
#'   order; (2) `id_col`; (3) `new_col`; (4) `paste0(new_col,
#'   "_within")` if applicable. The result carries a `.meta` attribute
#'   (a list) with keys `method`, `family_size`, `n_total`, `n_na`,
#'   `n_significant_05`, `id_col`, `p_col`, and `new_col`.
#'
#' @details
#'
#' ## Method choice
#'
#' `pool_pvals()` dispatches verbatim to `stats::p.adjust()`; the
#' adjustment formula is determined entirely by `method`.
#'
#' - `"BH"` (Benjamini-Hochberg, 1995) -- controls the false discovery
#'   rate (FDR) under independence or positive regression dependency
#'   (PRDS). Recommended default for multi-DV survey families.
#' - `"BY"` (Benjamini-Yekutieli, 2001) -- controls FDR under arbitrary
#'   dependence; strictly more conservative than BH. Use when the
#'   dependence structure across DVs is unknown or arbitrary.
#' - `"fdr"` -- alias for `"BH"` per `stats::p.adjust()` source. The
#'   two are identical.
#' - `"holm"` (Holm, 1979) -- controls the family-wise error rate
#'   (FWER) under arbitrary dependence. Uniformly more powerful than
#'   Bonferroni.
#' - `"hochberg"` (Hochberg, 1988) -- controls FWER, requires
#'   independence or MTP_2 dependence (not just PRDS). Use Holm
#'   instead when DVs are correlated and FWER control is desired.
#' - `"hommel"` (Hommel, 1988) -- controls FWER, requires independence
#'   or MTP_2 dependence. Same caveat as Hochberg.
#' - `"bonferroni"` -- controls FWER under any dependence structure
#'   (Bonferroni's inequality). Most conservative of the FWER
#'   procedures; preferred for tiny families.
#' - `"none"` -- pass-through; raw p-values returned in `new_col`.
#'
#' ## Default method
#'
#' The default `method = "BH"` reflects the typical structure of
#' survey p-values across DVs, which are usually positively dependent
#' (PRDS) but rarely independent. When the dependence structure is
#' unknown or known to be arbitrary, switch to `method = "BY"` for a
#' robust FDR-controlling alternative.
#'
#' ## Recommended workflow
#'
#' Set `pval_adj = NULL` on every upstream `get_*()` call when planning
#' to pool, so within-call adjustment is not produced and
#' `pool_pvals()` applies the global correction once. Note that
#' attributes carried on input tibbles (e.g., `variable_label` from
#' `get_diffs()` results) are NOT preserved on the output; this matches
#' `dplyr::bind_rows()` default behavior. Users who need attribute
#' preservation must re-attach the attribute after pooling.
#'
#' ## Statistical caveat about double-adjustment
#'
#' surveycore's `get_t_test()`, `get_pairwise()` (default
#' `pval_adj = "holm"`), and `get_diffs()` overwrite the `p_value`
#' column in place when `pval_adj != NULL`. `pool_pvals()` cannot
#' detect this by column inspection alone -- the
#' `surveycore_warning_pool_pvals_input_pre_adjusted` warning class
#' only fires when a separate column matching `new_col` is present.
#' Pass `pval_adj = NULL` upstream to avoid silent double-adjustment.
#'
#' ## Worked NA-denominator example
#'
#' With pooled p-values `(0.01, 0.02, 0.05, NA, NA)` and
#' `method = "BH"`, the BH denominator is `n = sum(!is.na(p)) = 3`
#' (not 5); adjusted values are `(0.03, 0.03, 0.05, NA, NA)`.
#'
#' ## Column-shape user-owned risk
#'
#' Column shapes and the semantic coherence of any `group` column
#' must be checked by the user; `pool_pvals()` does not validate
#' semantic coherence across input elements.
#'
#' ## Cross-design pooling caveat
#'
#' When results come from different surveys, sampling frames, or
#' weighting schemes, the user is responsible for ensuring
#' exchangeability across the pool.
#'
#' ## Small-m regime
#'
#' BH and related step-up methods become very conservative when
#' `m < 5` (the family size). Consider `method = "bonferroni"` or
#' unadjusted-with-exploratory-framing for tiny families.
#'
#' ## `"fdr"` alias note
#'
#' `"fdr"` is a dispatch alias for `"BH"` per `stats::p.adjust()`
#' source; the two produce identical output.
#'
#' ## Discrete p-value caveat
#'
#' Classical BH assumes continuous p-values. Chi-square tests of
#' small contingency tables can produce ties that violate this. See
#' the `DiscreteFDR` package on CRAN for that regime.
#'
#' ## Collection workflow
#'
#' Users with results from a collection-dispatched `get_*()` call (a
#' single tibble carrying a `.id` / `.survey` column) should split
#' into per-`.id` tibbles via `dplyr::group_split()` before passing
#' to `pool_pvals()`.
#'
#' ## See also
#'
#' Storey (2002) q-values, Romano-Wolf (2005) bootstrap stepdown, and
#' the `multcomp` / `mutoss` packages provide multiplicity machinery
#' surveycore does not implement.
#'
#' @references
#' Benjamini, Y. and Hochberg, Y. (1995). Controlling the False
#' Discovery Rate: A Practical and Powerful Approach to Multiple
#' Testing. *Journal of the Royal Statistical Society, Series B*
#' 57(1), 289-300. \doi{10.1111/j.2517-6161.1995.tb02031.x}
#'
#' Benjamini, Y. and Yekutieli, D. (2001). The control of the false
#' discovery rate in multiple testing under dependency. *Annals of
#' Statistics* 29(4), 1165-1188. \doi{10.1214/aos/1013699998}
#'
#' Holm, S. (1979). A simple sequentially rejective multiple test
#' procedure. *Scandinavian Journal of Statistics* 6(2), 65-70.
#'
#' Hochberg, Y. (1988). A sharper Bonferroni procedure for multiple
#' tests of significance. *Biometrika* 75(4), 800-802.
#' \doi{10.1093/biomet/75.4.800}
#'
#' Hommel, G. (1988). A stagewise rejective multiple test procedure
#' based on a modified Bonferroni test. *Biometrika* 75(2), 383-386.
#' \doi{10.1093/biomet/75.2.383}
#'
#' @examples
#' d <- suppressWarnings(
#'   as_survey(
#'     gss_2024,
#'     weights = wtssps,
#'     ids = vpsu,
#'     strata = vstrat,
#'     nest = TRUE
#'   )
#' )
#' r1 <- get_diffs(d, age, sex, pval_adj = NULL)
#' r2 <- get_diffs(d, hrs1, sex, pval_adj = NULL)
#' pool_pvals(list(age = r1, hrs1 = r2))
#'
#' @export
pool_pvals <- function(
  results,
  method = "BH",
  p_col = "p_value",
  new_col = "p_value_adj",
  id_col = "source",
  strip_within_adj = FALSE
) {
  # 1. Non-list / data.frame guard
  if (!.is_plain_list(results)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg results} must be a list of tibbles, ",
          "not {.cls {class(results)[[1L]]}}."
        ),
        "i" = "Got {.cls {class(results)}}.",
        "v" = paste0(
          "Wrap a single result in {.code list()} (e.g., ",
          "{.code pool_pvals(list(get_diffs(...)))}). For multiple ",
          "results, supply a named or unnamed list."
        )
      ),
      class = "surveycore_error_pool_pvals_not_list"
    )
  }

  # 2. Empty list check
  if (length(results) == 0L) {
    cli::cli_abort(
      c(
        "x" = "{.arg results} must be a list of length >= 1.",
        "i" = "Got an empty list."
      ),
      class = "surveycore_error_pool_pvals_empty"
    )
  }

  # 3. Method validation (delegated to shared helper)
  .validate_pval_adjustment_method(
    method,
    arg_name = "method",
    class = "surveycore_error_pool_pvals_invalid_method"
  )

  # 4 & 5. Per-element p_col presence + id_col collision
  checks <- .validate_list_columns(
    results,
    col_names = p_col,
    id_col = id_col
  )

  if (length(checks$missing_pcol) > 0L) {
    bad <- checks$missing_pcol
    cli::cli_abort(
      c(
        "x" = paste0(
          "All elements of {.arg results} must contain a column ",
          "named {.val {p_col}}."
        ),
        "i" = "Element{?s} missing the column: {.val {bad}}.",
        "v" = "Add the column or pass a different {.arg p_col}."
      ),
      class = "surveycore_error_pool_pvals_missing_pcol"
    )
  }

  if (length(checks$id_collision) > 0L) {
    bad <- checks$id_collision
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg id_col} {.val {id_col}} collides with an existing ",
          "column in {length(bad)} input element{?s}."
        ),
        "i" = "Offending element{?s}: {.val {bad}}.",
        "v" = paste0(
          "Rename the offending column, or supply a different ",
          "{.arg id_col}."
        )
      ),
      class = "surveycore_error_pool_pvals_id_col_collision"
    )
  }

  # 6. Per-element pre-existing new_col detection
  bad_pre <- vapply(
    seq_along(results),
    function(i) new_col %in% names(results[[i]]),
    logical(1L)
  )
  pre_ids <- character(0)
  if (any(bad_pre)) {
    nm <- names(results)
    if (is.null(nm)) {
      nm <- as.character(seq_along(results))
    } else {
      blank <- !nzchar(nm)
      if (any(blank)) {
        nm[blank] <- as.character(seq_along(results))[blank]
      }
    }
    pre_ids <- nm[bad_pre]

    within_col <- paste0(new_col, "_within")
    if (isTRUE(strip_within_adj)) {
      for (i in which(bad_pre)) {
        results[[i]][[new_col]] <- NULL
      }
    } else {
      for (i in which(bad_pre)) {
        elem <- results[[i]]
        elem[[within_col]] <- elem[[new_col]]
        elem[[new_col]] <- NULL
        results[[i]] <- elem
      }
      bad <- pre_ids
      cli::cli_warn(
        c(
          "!" = paste0(
            "{length(bad)} input element{?s} already contained a ",
            "column named {.val {new_col}}."
          ),
          "i" = paste0(
            "Renamed to {.val {within_col}} per element before ",
            "binding. Double-adjustment does not formally maintain ",
            "FDR control."
          ),
          "v" = paste0(
            "Set {.arg strip_within_adj = TRUE} to drop pre-existing ",
            "within-call adjustments, or pass {.code pval_adj = NULL} ",
            "to upstream {.fn get_*} calls."
          )
        ),
        class = "surveycore_warning_pool_pvals_input_pre_adjusted"
      )
    }
  }

  # 7. bind_rows
  bound <- dplyr::bind_rows(results, .id = id_col)

  # 8. Post-bind range check on pooled p_col
  pooled <- bound[[p_col]]
  bad_idx <- which(!is.na(pooled) & (pooled < 0 | pooled > 1))
  if (length(bad_idx) > 0L) {
    n_bad <- length(bad_idx)
    src_vals <- bound[[id_col]][bad_idx]
    # Compute within-source row index for each offending row.
    within_idx <- integer(n_bad)
    for (k in seq_along(bad_idx)) {
      same_src <- which(bound[[id_col]] == src_vals[[k]])
      within_idx[[k]] <- match(bad_idx[[k]], same_src)
    }
    bad_locs <- paste0(src_vals, "/", within_idx)
    cli::cli_abort(
      c(
        "x" = paste0(
          "Pooled column {.val {p_col}} contains {n_bad} value(s) ",
          "outside {.code [0, 1]}."
        ),
        "i" = paste0(
          "Offending row{?s} (source / row-within-source): ",
          "{.val {bad_locs}}."
        ),
        "v" = paste0(
          "Verify that {.arg p_col} names a p-value column, not a ",
          "coefficient or test statistic."
        )
      ),
      class = "surveycore_error_pool_pvals_invalid_pvalues"
    )
  }

  # 9. p.adjust over pool
  adj <- stats::p.adjust(pooled, method = method)
  bound[[new_col]] <- adj

  # 10. All-NA pool warning
  if (length(pooled) > 0L && all(is.na(pooled))) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "All values of pooled column {.val {p_col}} are ",
          "{.code NA}."
        ),
        "i" = paste0(
          "Returning the bound tibble with all-{.code NA} ",
          "{.val {new_col}}."
        )
      ),
      class = "surveycore_warning_pool_pvals_no_pvalues_available"
    )
  }

  # Column ordering: input union, then id_col, new_col, optional within_col
  input_union <- character(0)
  for (i in seq_along(results)) {
    input_union <- union(input_union, names(results[[i]]))
  }
  within_col <- paste0(new_col, "_within")
  trailing <- c(id_col, new_col)
  if (within_col %in% names(bound)) {
    trailing <- c(trailing, within_col)
  }
  input_union <- setdiff(input_union, trailing)
  ordered_cols <- c(input_union, trailing)
  ordered_cols <- ordered_cols[ordered_cols %in% names(bound)]
  out <- bound[, ordered_cols, drop = FALSE]
  out <- tibble::as_tibble(out)

  # S3 class + .meta attribute
  meta <- list(
    method = method,
    family_size = sum(!is.na(out[[p_col]])),
    n_total = nrow(out),
    n_na = sum(is.na(out[[p_col]])),
    n_significant_05 = sum(out[[new_col]] < 0.05, na.rm = TRUE),
    id_col = id_col,
    p_col = p_col,
    new_col = new_col
  )
  meta$family_size <- as.integer(meta$family_size)
  meta$n_total <- as.integer(meta$n_total)
  meta$n_na <- as.integer(meta$n_na)
  meta$n_significant_05 <- as.integer(meta$n_significant_05)
  attr(out, ".meta") <- meta
  class(out) <- c("survey_pooled_pvals", class(out))
  out
}


#' Print a `survey_pooled_pvals` object
#'
#' Prints a one-line `cli` header summarizing the adjustment method,
#' family size, and number of significant rows; delegates the body to
#' tibble's print method via `NextMethod()`; and prints a one-line
#' footer when any p-values were excluded as NA.
#'
#' @param x A `survey_pooled_pvals` object.
#' @param n Integer(1). Maximum number of rows to print. Passed
#'   through to `print.tbl_df`. Default `10`.
#' @param ... Additional arguments passed to `print.tbl_df`.
#'
#' @return `invisible(x)`.
#'
#' @export
#' @method print survey_pooled_pvals
print.survey_pooled_pvals <- function(x, n = 10, ...) {
  meta <- attr(x, ".meta")
  cli::cli_text(
    paste0(
      "<survey_pooled_pvals: method = {.val {meta$method}}, ",
      "family_size = {meta$family_size}, ",
      "{meta$n_significant_05} significant at alpha = 0.05>"
    )
  )
  NextMethod()
  if (!is.null(meta$n_na) && meta$n_na > 0L) {
    cli::cli_text(
      "# {meta$n_na} p-value{?s} {?was/were} NA and excluded from the family"
    )
  }
  invisible(x)
}
