# `get_corr()` Grouping — Implementation Plan

**Feature:** Add `group = NULL` parameter to `get_corr()` so it computes
per-group survey-weighted correlations, matching the grouping interface of
all other Phase 1 analysis functions.

**Branch:** `feature/get-corr-grouping`
**Target:** `develop`
**Tier:** Tier 3 (Direct — established pattern, all infrastructure in place)

---

## Context

Every other Phase 1 analysis function (`get_means`, `get_freqs`, `get_totals`,
`get_ratios`, `get_quantiles`) has a `group = NULL` parameter. `get_corr()` is
the only one missing it. There is currently an explicit test asserting that
`@groups` is **ignored**. That test gets replaced.

All shared infrastructure is already in place:
- `.resolve_groups()` — combines `design@groups` + `group=` arg
- `.build_group_meta()` — builds nested `meta$group` structure
- `.apply_group_labels()` — converts coded group cols to labelled factors
- `.apply_domain()` — domain estimation mask

---

## Decision Log

| # | Decision | Choice | Rationale |
|---|----------|--------|-----------|
| 1 | `wide` + groups output shape | Group cols prepended; p rows per group (stacked matrices) | Consistent with "group cols always prepended" pattern; user confirmed |
| 2 | `@groups` from `group_by()` | Respected (was silently ignored before) | Matches all other functions via `.resolve_groups()` |
| 3 | NA group values | Excluded from combinations | Standard R `unique()` behavior; matches `get_means()` |
| 4 | Empty group combo (0 in-domain rows) | `r = NA`, `n = 0L`; fires `surveycore_warning_small_cell` | Consistent with domain estimation pattern |
| 5 | `.corr_wide()` fate | Extract `.corr_build_matrix_col_vecs()` from `.corr_wide()`; delete `.corr_wide()` (no callers after B4 replaces the wide path) | Eliminates dead code; `get_corr()` calls the new helper directly for all combos (DRY; matches `get_means()` single-call pattern) |
| 6 | Factor levels for `var1`/`var2` | Same `uniq_display` levels across all groups | Groups don't change the set of variable pairs or display names |

---

## PR Checklist

- [x] PR 1: `feature/get-corr-grouping` — add `group = NULL` to `get_corr()` with per-group loop, stacked wide output, group labels, and full test coverage

---

## PR 1 Detail

### Files to Change

| File | Nature of change |
|------|-----------------|
| `R/analysis-corr-helpers.R` | Extract `.corr_build_matrix_col_vecs()` from `.corr_wide()`; delete `.corr_wide()` (zero callers after B4) |
| `NEWS.md` | One-line entry in `## Unreleased` for new `group` parameter |
| `R/analysis-corr.R` | Add `group` param; restructure to per-group outer loop; wide path via stacked col_vecs |
| `tests/testthat/test-analysis-corr.R` | Replace "ignores @groups" test; add 7+ grouping tests; update snapshots |
| `man/get_corr.Rd` | Auto-updated by `devtools::document()` |

---

### Step A — Refactor `analysis-corr-helpers.R`

Extract the `r`-matrix building logic from `.corr_wide()` into a new internal
helper that returns only `col_vecs` (no call to `.make_result_tibble()`):

```r
# NEW helper
# Returns list: variable col + one named col per focal variable (r values).
# Does NOT call .make_result_tibble() — caller assembles and calls once.
.corr_build_matrix_col_vecs <- function(
  x_names, display_names, pairs_i, pairs_j, pair_results, diagonal
) {
  p       <- length(x_names)
  n_pairs <- length(pairs_i)

  r_mat <- matrix(NA_real_, p, p)
  for (k in seq_len(n_pairs)) {
    i <- pairs_i[[k]]; j <- pairs_j[[k]]
    r_mat[i, j] <- pair_results[[k]]$r
    r_mat[j, i] <- pair_results[[k]]$r
  }
  if (isTRUE(diagonal)) diag(r_mat) <- 1

  var_col  <- display_names[x_names]
  col_vecs <- list(variable = var_col)
  for (k in seq_len(p)) {
    col_vecs[[display_names[[k]]]] <- r_mat[, k]
  }
  col_vecs
}
```

**Delete `.corr_wide()` entirely.** After B4, `get_corr()` calls
`.corr_build_matrix_col_vecs()` directly for every combo (including the
ungrouped single-combo case). `.corr_wide()` has no callers and must not be
left in the file.

---

### Step B — Restructure `get_corr()` in `analysis-corr.R`

#### B1 — Signature: add `group = NULL` after `x`, before `format`

```r
get_corr <- function(
  design,
  x,
  group        = NULL,
  format       = c("long", "wide"),
  redundant    = FALSE,
  diagonal     = FALSE,
  variance     = "ci",
  conf_level   = 0.95,
  n_weighted   = FALSE,
  min_cell_n   = 30L,
  na.rm        = TRUE,
  label_values = TRUE,
  label_vars   = TRUE,
  name_style   = "surveycore"
)
```

Capture enquo immediately after function opens:
```r
x_quo     <- rlang::enquo(x)
group_quo <- rlang::enquo(group)
```

#### B2 — New steps between existing Step 3 (domain mask) and Step 6 (pair list)

After resolving x vars, domain mask, x_meta_list, and display_names, insert:

**Step 5-new: Resolve group vars**
```r
group_vars <- .resolve_groups(design, group_quo)
```

**Step 6-new: Single-level warning per group var**
```r
if (length(group_vars) > 0L) {
  for (gv in group_vars) {
    gv_vals   <- design@data[[gv]][domain_mask]
    uniq_lvls <- unique(gv_vals[!is.na(gv_vals)])
    if (length(uniq_lvls) == 1L) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "Grouping variable {.field {gv}} has only one observed level ",
            "({.val {as.character(uniq_lvls[[1L]])}}).",
            " Grouped estimates will have a single row."
          )
        ),
        class = "surveycore_warning_single_level"
      )
    }
  }
}
```

**Step 7-new: Build group combinations**
```r
if (length(group_vars) > 0L) {
  domain_data  <- design@data[domain_mask, group_vars, drop = FALSE]
  group_combos <- unique(domain_data)
  ord <- do.call(
    order,
    lapply(group_vars, function(gv) group_combos[[gv]])
  )
  group_combos <- group_combos[ord, , drop = FALSE]
  rownames(group_combos) <- NULL
  n_combos <- nrow(group_combos)
} else {
  group_combos <- data.frame()
  n_combos     <- 1L
}
```

#### B3 — Replace flat pair loop with outer group / inner pair loops

Replace current Steps 7–8 (pair loop + small-cell warning) with:

```r
# ── Outer: group combos; Inner: variable pairs ────────────────────────────
all_pair_results <- vector("list", n_combos)
all_grp_rows     <- vector("list", n_combos)
small_cell_ns    <- integer(0)

for (ci in seq_len(n_combos)) {
  # Build active mask for this combo
  if (length(group_vars) > 0L) {
    combo_row   <- group_combos[ci, , drop = FALSE]
    group_match <- rep(TRUE, nrow(design@data))
    for (gv in group_vars) {
      gv_col      <- design@data[[gv]]
      cv          <- combo_row[[gv]]
      group_match <- group_match & !is.na(gv_col) & (gv_col == cv)
    }
    active_mask <- domain_mask & group_match
    all_grp_rows[[ci]] <- combo_row
  } else {
    active_mask <- domain_mask
  }
  active_domain <- as.numeric(active_mask)

  # Inner loop: pairs
  pair_results_this <- vector("list", n_pairs)
  for (k in seq_len(n_pairs)) {
    xnm <- x_names[[pairs_i[[k]]]]
    ynm <- x_names[[pairs_j[[k]]]]
    vco <- .corr_vcov_pair(design, xnm, ynm, active_domain, na.rm)
    res <- .corr_pair_result(vco)
    pair_results_this[[k]] <- res
    if (!is.na(res$n) && res$n > 0L && res$n < min_cell_n) {
      small_cell_ns <- c(small_cell_ns, res$n)
    }
  }
  all_pair_results[[ci]] <- pair_results_this
}

# Small-cell warning (fires once, across all groups)
n_small <- length(small_cell_ns)
if (n_small > 0L) {
  cli::cli_warn(
    c(
      "!" = paste0(
        "{n_small} cell{?s} {?has/have} fewer than {min_cell_n} unweighted ",
        "observations. Estimates in these cells may be unreliable for ",
        "public reporting (AAPOR guidance)."
      )
    ),
    class = "surveycore_warning_small_cell"
  )
}

# Group metadata — use resolved group_vars (not design@groups directly)
group_meta <- .build_group_meta(design, group_vars)
```

#### B4 — Wide format path (grouped)

Replace the current early-return wide block with:

```r
if (format == "wide") {
  p <- length(x_names)

  # Build col_vecs per combo, stack into one result
  wide_col_vecs_list <- vector("list", n_combos)
  wide_grp_rows      <- vector("list", n_combos)

  for (ci in seq_len(n_combos)) {
    wide_col_vecs_list[[ci]] <- .corr_build_matrix_col_vecs(
      x_names, display_names, pairs_i, pairs_j,
      all_pair_results[[ci]], diagonal
    )
    if (length(group_vars) > 0L) {
      # Repeat group row p times (one row per variable in the matrix)
      wide_grp_rows[[ci]] <- all_grp_rows[[ci]][rep(1L, p), , drop = FALSE]
    }
  }

  # Stack col_vecs across combos
  all_col_names <- names(wide_col_vecs_list[[1L]])
  stacked_wide <- lapply(all_col_names, function(nm) {
    unlist(lapply(wide_col_vecs_list, `[[`, nm), use.names = FALSE)
  })
  names(stacked_wide) <- all_col_names

  # Build groups_df for wide result
  if (length(group_vars) > 0L) {
    wide_groups_df <- do.call(rbind, wide_grp_rows)
    rownames(wide_groups_df) <- NULL
    wide_groups_df <- .apply_group_labels(
      wide_groups_df, group_vars, design, label_values
    )
  } else {
    wide_groups_df <- data.frame()
  }

  meta_args_wide <- list(
    conf_level = conf_level,
    call       = match.call(),
    method     = "pearson",
    group      = group_meta,
    x          = x_meta_list
  )

  return(.make_result_tibble(
    stacked_wide, wide_groups_df, "survey_corr",
    design, meta_args_wide, CORR_META_KEYS
  ))
}
```

#### B5 — Long format accumulation (grouped)

**Pre-loop constants** — compute these ONCE before the combo loop (they are
the same for every group):

```r
n_rows_per_combo <- n_pairs +
  (if (isTRUE(redundant)) n_pairs else 0L) +
  (if (isTRUE(diagonal)) p else 0L)

# row_i / row_j / pair_idx_map from existing Steps 10–12
# (expansion of pairs_i/pairs_j according to redundant/diagonal)
# ... existing code unchanged, just moved outside the loop ...
```

Pre-allocate accumulator vectors (also outside the loop, sized
`n_combos * n_rows_per_combo`):

```r
total_rows   <- n_combos * n_rows_per_combo
acc_var1     <- character(total_rows)
acc_var2     <- character(total_rows)
# ... etc for every acc_* vector ...
acc_grp_rows <- vector("list", n_combos)  # one block per combo
```

**Inside the combo loop** — only the fill-and-accumulate step:

```r
for (ci in seq_len(n_combos)) {
  offset <- (ci - 1L) * n_rows_per_combo
  idx    <- offset + seq_len(n_rows_per_combo)

  # Fill acc_* slices using all_pair_results[[ci]]
  # (existing Steps 10–12 fill logic, referencing idx instead of seq_along)

  if (length(group_vars) > 0L) {
    grp_block <- all_grp_rows[[ci]][rep(1L, n_rows_per_combo), , drop = FALSE]
    acc_grp_rows[[ci]] <- grp_block
  }
}
```

After the combo loop, build `groups_df`:

```r
if (length(group_vars) > 0L) {
  groups_df <- do.call(rbind, acc_grp_rows)
  rownames(groups_df) <- NULL
  groups_df <- .apply_group_labels(groups_df, group_vars, design, label_values)
} else {
  groups_df <- data.frame()
}
```

Pass `groups_df` to `.make_result_tibble()` (was `data.frame()` always).

---

### Step C — Roxygen: add `@param group`

Add above `@param format` in the roxygen block:

```r
#' @param group <[`tidy-select`][tidyselect::language]> Optional grouping
#'   variable(s). Combined with any grouping set by `group_by()`. Default
#'   `NULL`.
```

Update `@return` to document that group columns are prepended when `group` is
active (both long and wide formats).

---

### Step D — Test Changes

#### Remove / replace

| Test (approx line) | Action |
|--------------------|--------|
| Lines 112–126: "get_corr() ignores @groups" | **Replace** with a positive test that `@groups` is now respected |

#### Add (10 new test blocks)

1. **`group=` basic (long)** — two groups, two pairs; result has n_groups × n_pairs rows; group column present and correct; r values differ between groups.

2. **`@groups` from `group_by()` respected** — `surveytidy::group_by(d, g) |> get_corr(x = c(y1, y2))` equals `get_corr(d, x = c(y1, y2), group = g)`.

3. **Wide + groups** — three vars, two groups; `format = "wide"` yields `n_groups * p` rows; group column precedes `variable` column; correct stacked matrix structure.

4. **Group labels** — when group var has value labels and `label_values = TRUE`, group column is a factor with labelled levels.

5. **`meta$group` non-empty** — `meta(result)$group` is a named list (one entry per group var) when `group` is active.

6. **Numerical accuracy (grouped)** — for each group level, correlation from grouped result matches `get_corr()` run on a domain-subsetted design (tolerance 1e-10). No external package needed; no `skip_if_not_installed`.

7. **Single-level group warning** — fires `surveycore_warning_single_level` when a group variable has exactly one observed level.

8. **Zero-row group combo** — design with a `filter()` domain that excludes all rows for one group value; assert that combo's `r = NA`, `n = 0L`, and `surveycore_warning_small_cell` fires (once, not per-pair).

9. **NA group values excluded** — group column contains `NA` values; assert the result has only `n_unique_non_na` rows and no `NA` appears in the group column.

10. **`redundant = TRUE` row count with groups** — two groups, three vars; `redundant = TRUE`; assert `nrow(result) == n_combos * 2 * n_pairs`. **`diagonal = TRUE` row count with groups** — same setup; `diagonal = TRUE`; assert `nrow(result) == n_combos * (n_pairs + p)`.

11. **Snapshot update** — regenerate any affected snapshots with `testthat::snapshot_review()`.

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| `group = NULL`, `design@groups` empty | Identical to today — ungrouped |
| `design@groups` set via `group_by()` | Now respected (was silently ignored) |
| `group=` and `design@groups` overlap | `.resolve_groups()` deduplicates |
| NA values in group column | Excluded from group combinations |
| Group combo with 0 in-domain rows | `r = NA`, `n = 0L`; fires `surveycore_warning_small_cell` |
| `format = "wide"`, 2 groups, 3 vars | 6 rows (2 × 3), group col + `variable` + 3 corr cols |
| `redundant = TRUE` with groups | `n_combos × (2 × n_pairs)` long-format rows |
| `diagonal = TRUE` with groups | `n_combos × (n_pairs + p)` long-format rows |
| Single group variable with 1 level | Works; fires `surveycore_warning_single_level` |

---

## Acceptance Criteria

Before opening the PR, all three must be true:

1. `devtools::check()` passes: 0 errors, 0 warnings, ≤ 2 notes
2. `covr::package_coverage()` ≥ 98% line coverage (CI blocks below 95%)
3. No failing snapshots — all reviewed and accepted via `testthat::snapshot_review()`

## Run Before Opening PR

```r
devtools::document()         # regenerates man/get_corr.Rd; commit NAMESPACE + Rd
devtools::test()             # all tests pass
devtools::check()            # 0 errors, 0 warnings, ≤ 2 notes
covr::package_coverage()     # target ≥ 98%; CI blocks below 95%
testthat::snapshot_review()  # review any updated snapshots
```
