# Spec: Refactor `analysis-diffs.R`

**ID:** `refactor-diffs`
**Version:** 0.3
**Date:** 2026-04-01
**Status:** Approved

---

## Document Purpose

This is the source of truth for the internal refactoring of `R/analysis-diffs.R`.
The public API of `get_diffs()` must not change. This spec governs only
internal structure: helper extraction, duplication elimination, and file
organization. No new behavior is introduced.

---

## I. Scope

### Delivers

| Item | Description |
|------|-------------|
| `.extract_clean_estimates()` | Helper encapsulating the clean-path estimate extraction (currently inline in `get_diffs()`, lines ~352–410) |
| `.extract_me_estimates()` | Helper encapsulating the marginaleffects-path estimate extraction (currently inline, lines ~412–537) |
| `.build_diffs_output()` | Unified helper replacing the near-identical non-group and grouped branches of Steps 12–17 (~600 lines of duplication) |
| Removal of inline closure | Remove the `if (!has_group)` inline `.build_output_rows()` closure (lines 551–633); its logic is absorbed into `.build_diffs_output()` |
| File organization | All three new helpers live in `R/analysis-diffs-helpers.R` |

### Does NOT deliver

- Any change to the public signature of `get_diffs()`
- Any change to the output tibble structure, column names, or S3 class
- Any change to `.meta` shape or keys
- Any behavioral change observable by callers
- New analysis features or arguments

### Design-class support matrix

This refactor does not change which design classes `get_diffs()` accepts.
The matrix is unchanged: `survey_taylor`, `survey_replicate`,
`survey_twophase`, `survey_nonprob`.

---

## II. Architecture

### File organization after refactor

```
R/
  analysis-diffs.R          # get_diffs() only; thin orchestrator; ~400 lines
  analysis-diffs-helpers.R  # .stars_pval() + three new helpers; ~300 lines
```

`get_diffs()` after refactor:

```
Steps 1–10  (validation, formula build, model fit, path determination)
  → .extract_clean_estimates()  OR  .extract_me_estimates()
  → .build_diffs_output()
Steps 17a–22 (label_values, decimals, name_style, .meta, col labels, class)
```

### Placement rule (from `code-style.md`)

All three new helpers are used only by `get_diffs()` but are moved to
`analysis-diffs-helpers.R` because that file already exists as the
designated location for diffs-specific internal helpers. Co-location in
`analysis-diffs.R` is reserved for zero-call-site closures that don't
exist after this refactor.

### Shared helpers (unchanged)

The following helpers from `R/analysis-helpers.R` are called by
`get_diffs()` and are not touched by this refactor:

| Helper | Called from |
|--------|-------------|
| `.validate_shared_args()` | Step 1 (unchanged) |
| `.check_unsupported_class()` | Step 2 (unchanged) |
| `.resolve_groups()` | Step 3 (unchanged) |
| `.apply_domain()` | Step 12 (result passed into `.build_diffs_output()` as `domain_mask`) |
| `.build_meta()` | Step 20 (unchanged) |
| `.extract_var_meta()` | Step 20 (unchanged) |
| `.build_group_meta()` | Step 20 (unchanged) |
| `.apply_group_labels()` | Step 17a (unchanged) |
| `.apply_decimals()` | Step 18 (unchanged) |
| `.apply_name_style()` | Step 19 (unchanged) |

---

## III. Helper Specifications

### 3.1 `.extract_clean_estimates(fit, treats_name, conf_level)`

**Purpose:** Extract treatment-level estimates, SEs, CIs, p-values, and
level means from the direct-coefficient (clean) path.

**Placement:** `R/analysis-diffs-helpers.R`

**Signature:**

```r
.extract_clean_estimates <- function(fit, treats_name, conf_level)
```

**Arguments:**

| Name | Type | Description |
|------|------|-------------|
| `fit` | `survey_glm_fit` | Fitted survey GLM model |
| `treats_name` | `character(1)` | Name of the treatment variable column |
| `conf_level` | `numeric(1)` | Confidence level in (0, 1) |

**Returns:** Named list with the following keys (all vectors are
parallel — element `i` corresponds to the `i`-th non-reference level):

| Key | Type | Description |
|-----|------|-------------|
| `result_levels` | `character` | Non-reference factor level names |
| `result_estimates` | `double` | Treatment effect coefficients |
| `result_ses` | `double` | Standard errors |
| `result_ci_lows` | `double` | Lower confidence bounds |
| `result_ci_highs` | `double` | Upper confidence bounds |
| `result_p_values` | `double` | P-values |
| `result_means` | `double` | Level means (`reference_mean + estimate`) |
| `result_groups` | `NULL` | Always `NULL` for clean path |
| `reference_mean` | `double(1)` | Intercept (reference group mean) |
| `preds_df` | `NULL` | Always `NULL` for clean path |

**Behavior:**

1. Calls `clean(fit, conf_level = conf_level, include_reference = TRUE, n = TRUE, statistic = FALSE)`.
2. Identifies the intercept row (`term == "(Intercept)"`). Aborts with
   `surveycore_error_reference_row_not_found` if exactly one intercept row
   is not present.
3. Identifies non-reference treatment rows (not intercept, not
   `reference_row == TRUE`).
4. Strips the `treats_name` prefix from the `term` column to recover bare
   level names via `sub(paste0("^", treats_name), "", term)`.
5. Computes `result_means` as `reference_mean + result_estimates`.

**Errors:**

| Class | Trigger |
|-------|---------|
| `surveycore_error_reference_row_not_found` | Intercept row absent or duplicated in `clean()` output |

---

### 3.2 `.extract_me_estimates(fit, treats_name, group_names, ref_level, scale, suppress_mean)`

**Purpose:** Extract treatment-level estimates and level means via
`marginaleffects::avg_slopes()` and `marginaleffects::avg_predictions()`.
Handles both the grouped and non-grouped cases.

**Placement:** `R/analysis-diffs-helpers.R`

**Signature:**

```r
.extract_me_estimates <- function(
  fit, treats_name, group_names, ref_level, scale, suppress_mean
)
```

**Arguments:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `fit` | `survey_glm_fit` | — | Fitted survey GLM model |
| `treats_name` | `character(1)` | — | Treatment variable column name |
| `group_names` | `character` | — | Group variable names; `character(0)` for no groups |
| `ref_level` | `character(1)` | — | Reference level name (for contrast parsing) |
| `scale` | `character(1)` | — | `"ame"` or `"link"` |
| `suppress_mean` | `logical(1)` | — | If `TRUE`, skip `avg_predictions()` call |

**Returns:** Named list with the same keys as `.extract_clean_estimates()`,
with these differences:

| Key | Type | Description |
|-----|------|-------------|
| `result_means` | `double` or `NULL` | Level means from `preds_df` lookup; `NULL` when `suppress_mean = TRUE` |
| `result_groups` | `data.frame` or `NULL` | Group columns from `slopes` output; `NULL` when `length(group_names) == 0` |
| `reference_mean` | `NULL` | Clean-path concept; not applicable here |
| `preds_df` | `data.frame` or `NULL` | Raw `avg_predictions()` output as data frame; `NULL` when `suppress_mean = TRUE` |

**Behavior:**

1. Computes residual df as `max(1, fit@degf - (p - 1))` where `p = length(stats::coef(fit))`.
2. Sets `me_type` to `"link"` when `scale == "link"`, else `"response"`.
3. Calls `marginaleffects::avg_slopes()` using a conditional call structure:
   - When `length(group_names) > 0`: `avg_slopes(fit, variables = treats_name, by = group_names, type = me_type, wts = fit@weights, df = res_df)`
   - When `length(group_names) == 0`: `avg_slopes(fit, variables = treats_name, type = me_type, wts = fit@weights, df = res_df)` (the `by` argument is absent, not `NULL`)
4. Unless `suppress_mean`, calls `marginaleffects::avg_predictions()` using a conditional call structure:
   - When `length(group_names) > 0`: `avg_predictions(fit, by = c(treats_name, group_names), type = me_type, wts = fit@weights, df = res_df)`
   - When `length(group_names) == 0`: `avg_predictions(fit, by = treats_name, type = me_type, wts = fit@weights, df = res_df)`
5. Parses level names from the `contrast` column using `sub(paste0("^(.+) - ", ref_level, "$"), "\\1", contrast)`.
6. When `group_names` is non-empty, populates `result_groups` from the group columns of `slopes_df`.
6a. When `length(group_names) == 0` and `!suppress_mean`, populates `result_means` by building a named vector from `preds_df$estimate` keyed by the `treats_name` column values, then looking up each element of `result_levels` in that vector. When `suppress_mean = TRUE`, sets `result_means = NULL`.
7. When `group_names` is non-empty and `!suppress_mean`, matches `result_means` row-by-row from `preds_df` using `treats_name` + group columns as a composite key. When `suppress_mean = TRUE`, sets `result_means = NULL`.

---

### 3.3 `.build_diffs_output(result, design, treats_name, group_names, ref_level, domain_mask, wt_var, show_means, use_marginaleffects, pval_adj, show_pct_change, suppress_mean, min_cell_n, variance, n_weighted)`

**Purpose:** Unified replacement for the duplicated non-group and grouped
branches of Steps 12–17 in `get_diffs()`. Builds reference and treatment
rows, checks cell sizes, adjusts p-values, computes stars and
`pct_change`, and assembles the final `col_vecs` + `groups_df`.

**Placement:** `R/analysis-diffs-helpers.R`

**Signature:**

```r
.build_diffs_output <- function(
  result,
  design,
  treats_name,
  group_names,
  ref_level,
  domain_mask,
  wt_var,
  show_means,
  use_marginaleffects,
  pval_adj,
  show_pct_change,
  suppress_mean,
  min_cell_n,
  variance,
  n_weighted
)
```

**Arguments:**

| Name | Type | Description |
|------|------|-------------|
| `result` | named list | Output of `.extract_clean_estimates()` or `.extract_me_estimates()` |
| `design` | `survey_base` | The survey design (for `@data` access) |
| `treats_name` | `character(1)` | Treatment variable column name |
| `group_names` | `character` | Group variable names; `character(0)` for no groups |
| `ref_level` | `character(1)` | Reference level name |
| `domain_mask` | `logical` | Row mask from `.apply_domain(design)` |
| `wt_var` | `character(1)` or `NULL` | Weight column name |
| `show_means` | `logical(1)` | Include reference row and `mean` column |
| `use_marginaleffects` | `logical(1)` | Which estimation path was used |
| `pval_adj` | `character(1)` or `NULL` | P-value adjustment method |
| `show_pct_change` | `logical(1)` | Include `pct_change` column |
| `suppress_mean` | `logical(1)` | Omit mean-related columns (link-scale suppression) |
| `min_cell_n` | `integer(1)` | Small-cell warning threshold |
| `variance` | `character` or `NULL` | Which uncertainty columns to include |
| `n_weighted` | `logical(1)` | Include `n_weighted` column |

**Returns:** Named list:

```r
list(
  col_vecs  = list,        # named list of parallel vectors (non-group columns)
  groups_df = data.frame   # group columns; 0-column data.frame when no groups
)
```

**Behavior:**

#### 3.3.1 Group iteration

When `length(group_names) == 0`, the function treats the entire dataset as
one implicit group (equivalent to iterating over one "null" combination).
This eliminates the separate non-group branch entirely.

When `length(group_names) > 0`, `result$result_groups` is used to derive
`unique_group_combos` (from `unique(result$result_groups)`). The defensive
`!use_marginaleffects && has_group` branch from the current implementation
(lines 808–813, labeled "Should not happen") is intentionally removed: the
invariant that `has_group` always implies `use_marginaleffects = TRUE` is
enforced by Step 10 of `get_diffs()`.

In both cases, the same row-building logic applies per "group combo".

#### 3.3.2 Row building per group combo

For each group combo, the function builds:

**Reference row** (when `show_means = TRUE`):
- `level = ref_level`
- `estimate = 0`
- `n` = unweighted count of rows in `design@data` where `domain_mask` is
  `TRUE`, `treats_name == ref_level`, and all group columns match the
  current combo
- `n_weighted` = sum of `wt_var` for those rows (or `as.numeric(n)` if
  `wt_var` is `NULL`)
- `mean` = reference group mean (from `result$reference_mean` on the clean
  path; from `result$preds_df` on the ME path; `NA_real_` if
  `suppress_mean`)
- All uncertainty fields (`se`, `ci_low`, `ci_high`, `p_value`) =
  `NA_real_`
- `stars = ""`

**Treatment rows** (one per non-reference level in the current group combo):
- `level` = level name from `result$result_levels`
- `estimate`, `se`, `ci_low`, `ci_high`, `p_value` from `result$result_*`
- `n` and `n_weighted` computed same way as reference row, filtered to the
  treatment level
- `mean` from `result$result_means` (or `NA_real_` if absent/suppressed)
- `stars = ""` (filled in Step 3.3.5)

**Tracking `ref_mean` for `pct_change` when `show_means = FALSE`:** When
`show_means = FALSE`, no reference row is added to the row list. However,
when `show_pct_change = TRUE` and `!suppress_mean`, `ref_mean` is still
required for the `pct_change` computation in §3.3.5. In that case, obtain
`ref_mean` as follows:

- Clean path (`!use_marginaleffects`): use `result$reference_mean` directly.
- ME path (`use_marginaleffects`): filter `result$preds_df` to the row where
  `treats_name == ref_level` (and all group columns match the current combo)
  and use its `estimate` value.
- If neither is available (e.g., `suppress_mean = TRUE`): `ref_mean = NA_real_`.

#### 3.3.3 Small-cell warnings

After building all rows, emit `surveycore_warning_small_cell` for each row
where `!is.na(r$n) && r$n > 0L && r$n < min_cell_n`. Warn once per
qualifying row; the warning fires for both reference and treatment rows.

#### 3.3.4 P-value adjustment

When `!is.null(pval_adj)`:
- When `length(group_names) == 0`: adjust p-values for all non-reference
  rows globally.
- When `length(group_names) > 0`: adjust independently within each group
  combo.
- Only non-reference rows (those where `estimate != 0`) are adjusted.
- Uses `stats::p.adjust(pvals, method = pval_adj)`.

#### 3.3.5 Stars and `pct_change`

For each row:
- Set `stars = .stars_pval(r$p_value)`.
- When `show_pct_change && !suppress_mean`:
  - For the reference row: `pct_change = NA_real_`.
  - For treatment rows: `pct_change = estimate / ref_mean` where `ref_mean`
    is the reference row mean for the same group combo (when `show_means = TRUE`),
    or the fallback value obtained per §3.3.2 (when `show_means = FALSE`).
  - If `ref_mean` is `NA` or `abs(ref_mean) < .Machine$double.eps * 100`:
    `pct_change = NA_real_`.
  - Emit `surveycore_warning_pct_change_zero_ref` once per group combo
    where the reference mean is effectively zero and `show_pct_change` is
    `TRUE`.

#### 3.3.6 Column vector assembly

Assemble `col_vecs` as a named list of parallel vectors extracted from the
row list. Conditional columns follow the same inclusion rules as the
current implementation:

| Column | Included when |
|--------|---------------|
| `{treats_name}` | Always |
| `estimate` | Always |
| `pct_change` | `show_pct_change && !suppress_mean` |
| `mean` | `show_means && !suppress_mean` |
| `n` | Always |
| `n_weighted` | `n_weighted == TRUE` |
| `se` | `!is.null(variance) && "se" %in% variance` |
| `ci_low` | `!is.null(variance) && "ci" %in% variance` |
| `ci_high` | `!is.null(variance) && "ci" %in% variance` |
| `p_value` | Always |
| `stars` | Always |

`groups_df` is assembled by `rbind`-ing the per-row group data frames. For
the no-group case, it is a 0-column `data.frame` (e.g., `data.frame()`).

**Errors:**

| Class | Trigger |
|-------|---------|
| `surveycore_warning_small_cell` | Any row with `0 < n < min_cell_n` |
| `surveycore_warning_pct_change_zero_ref` | Reference mean ≈ 0 and `show_pct_change && !suppress_mean` |

---

## IV. `get_diffs()` Internal Structure After Refactor

The function body after refactor follows this skeleton. Steps retain their
existing numbers for traceability.

```
Steps 1–4a  Validation (unchanged)
Step 5      Handle ref_level (unchanged)
Steps 6–8   na.rm, relevel, build formula (unchanged)
Step 9      Fit model: survey_glm() (unchanged)
Step 10     Determine path: use_marginaleffects, suppress_mean (unchanged)

Step 11     Extract estimates:
              if (!use_marginaleffects) {
                estimate_method <- "coefficient"
                mean_method     <- "intercept"
                estimate_scale  <- "coefficient"
                result <- .extract_clean_estimates(fit, treats_name, conf_level)
              } else {
                estimate_method <- "avg_slopes"
                mean_method     <- "avg_predictions"
                estimate_scale  <- if (scale == "link") "coefficient" else "ame"
                result <- .extract_me_estimates(
                  fit, treats_name, group_names, ref_level, scale, suppress_mean
                )
              }
              # estimate_method, mean_method, estimate_scale are consumed at Step 20

Steps 12–17 Build output:
              out <- .build_diffs_output(
                result, design, treats_name, group_names, ref_level,
                domain_mask, wt_var, show_means, use_marginaleffects,
                pval_adj, show_pct_change, suppress_mean,
                min_cell_n, variance, n_weighted
              )
              col_vecs  <- out$col_vecs
              groups_df <- out$groups_df

Step 17a    Apply label_values (unchanged, uses col_vecs + groups_df)
Step 18     Apply decimals (unchanged)
Step 19     Apply name_style (unchanged)
Step 20     Attach .meta (unchanged)
Step 21     Column-level labels (unchanged)
Step 22     Set class + return (unchanged)
```

The inline closure `.build_output_rows()` (currently defined inside the
`if (!has_group)` branch) is **removed**. Its logic is absorbed into
`.build_diffs_output()`.

---

## V. Testing

### 5.1 Behavior preservation (regression tests)

The primary test requirement for this refactor is that all existing
`get_diffs()` tests continue to pass without modification. No new
behavioral edge cases are introduced by this refactor.

Run the full test suite before and after refactoring to confirm identical
results:

```r
devtools::test(filter = "diffs")
```

### 5.2 New unit tests for helpers

Each new helper gets direct tests in `tests/testthat/test-analysis-diffs.R`
(or a new `test-analysis-diffs-helpers.R` if that file does not exist).

#### `.extract_clean_estimates()`

| Test | Description |
|------|-------------|
| Happy path | Returns all 10 expected keys for a 3-level treatment design |
| Level name parsing | Strips variable prefix correctly from term column |
| `result_means` | Equals `reference_mean + result_estimates` |
| `result_groups` / `preds_df` | Both `NULL` always |
| Error: missing intercept | Aborts with `surveycore_error_reference_row_not_found`; dual-pattern test: `expect_error(class = "surveycore_error_reference_row_not_found")` on the helper call directly, plus `expect_snapshot(error = TRUE)` on both the helper call and a `get_diffs()` call that surfaces the same error via the public API |

#### `.extract_me_estimates()`

| Test | Description |
|------|-------------|
| Happy path (no groups) | Returns `result_groups = NULL`, `reference_mean = NULL` |
| Happy path (with groups) | `result_groups` is a data.frame with correct group columns |
| `suppress_mean = TRUE` | `preds_df` is `NULL`; `result_means` is `NULL` |
| Contrast parsing | Level names parsed correctly from `"X - ref"` format |
| `scale = "link"` | `me_type = "link"` passed to `avg_slopes()` |

#### `.build_diffs_output()`

For unit tests, construct mock `result` lists inline for edge cases (e.g., `n == 0`, `suppress_mean`, `pct_change` fallback); call `.extract_clean_estimates()` or `.extract_me_estimates()` first for happy-path behavioral comparison.

| Test | Description |
|------|-------------|
| No-group, clean path | Returns same col_vecs as current implementation |
| No-group, ME path | Same |
| Grouped path | `groups_df` has correct columns and row count |
| Small-cell warning | Fires for rows with `0 < n < min_cell_n` — use `expect_warning(class = "surveycore_warning_small_cell")` only, no snapshot |
| No warning when `n == 0` | Edge case: zero-count reference level does not warn |
| P-value adjustment, no groups | Adjusts non-reference rows globally |
| P-value adjustment, with groups | Adjusts independently within each group |
| `pct_change` computation | Correct value for each treatment row |
| `pct_change` with `show_means = FALSE` | `ref_mean` obtained from fallback (§3.3.2); `pct_change` computed correctly on both clean and ME paths |
| `pct_change` with `show_means = FALSE`, grouped ME path | `pct_change` is computed (not `NA`) when `show_means = FALSE` + grouped design + `show_pct_change = TRUE` + `!suppress_mean`; regression test locking in the behavioral fix from §3.3.2 |
| `pct_change` zero-ref warning | Fires once when reference mean ≈ 0 — use `expect_warning(class = "surveycore_warning_pct_change_zero_ref")` only, no snapshot |
| `suppress_mean` | `mean` and `pct_change` columns absent |
| Conditional columns | Each `variance`, `n_weighted`, `show_means` combination |

### 5.3 Coverage

All new helpers must be covered at 100% line coverage. Run
`covr::file_coverage()` on `R/analysis-diffs-helpers.R` to verify before
opening a PR.

---

## VI. Quality Gates

All must be satisfied before handing off to `/implementation-workflow`.

- [ ] `devtools::test(filter = "diffs")` passes with 0 failures and 0 skips
- [ ] All existing `get_diffs()` snapshots pass unchanged
- [ ] `devtools::check()` passes with 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `R/analysis-diffs.R` is ≤ 500 lines (from ~1265)
- [ ] `R/analysis-diffs-helpers.R` grows to reflect the extracted helpers
- [ ] No `list()` or `data.frame()` with `ncol == 0` edge cases are handled differently from current behavior
- [ ] `get_diffs()` output is byte-for-byte identical to current output on the existing test suite (verified by running tests, not manual inspection). **Exception:** the `show_means = FALSE` + grouped ME + `show_pct_change = TRUE` + `!suppress_mean` combination is excluded from this gate. The current grouped implementation returns `pct_change = NA` in this case (a behavioral inconsistency vs. the no-group path); this refactor aligns both paths to compute `pct_change` correctly. No existing test covers this combination, so no existing test will fail — but a new regression test (see §5.2) is required to lock in the corrected behavior.
- [ ] `devtools::document()` run; no NAMESPACE or `.Rd` changes (refactor is internal-only)
