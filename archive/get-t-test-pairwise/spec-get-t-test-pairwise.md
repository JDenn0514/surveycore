# Spec: `get_t_test()` and `get_pairwise()`

**Version:** 0.4
**Date:** April 2026
**Status:** Approved

---

## Document Purpose

This document is the authoritative specification for `get_t_test()` and
`get_pairwise()`. It supersedes `plans/spec-get-pairwise.md`, which specified
a now-abandoned regression-based approach.

`get_t_test()` is a design-based two-sample t-test comparing group means.
`get_pairwise()` is a thin wrapper that runs `get_t_test()` over all k(k−1)/2
pairs and applies multiple-comparison adjustment.

Neither function uses the `survey` package. Both use surveycore's own
`survey_glm()` for variance estimation, following the mathematical model of
`survey::svyttest()`.

---

## I. Scope

### What This Delivers

| Component | Description |
|---|---|
| `get_t_test()` | Exported: design-based t-test comparing two group means |
| `get_pairwise()` | Exported: all-vs-all pairwise t-tests with p-value adjustment |
| `survey_t_test` S3 class | Result tibble with column-level labels and `.meta` |
| `survey_pairwise` S3 class | Result tibble with column-level labels and `.meta` |
| `print.survey_t_test()` | Custom header + tibble body |
| `print.survey_pairwise()` | Custom header + tibble body |
| `T_TEST_META_KEYS` | Meta-key constant for `.make_result_tibble()` validation |
| `PAIRWISE_META_KEYS` | Meta-key constant for `.make_result_tibble()` validation |

### What This Does NOT Deliver

- **Covariate-adjusted comparisons** — no `covariates` argument. Add covariates
  by fitting `survey_glm()` directly and using `svycontrast()` or clean contrast
  extraction.
- **Non-Gaussian outcomes** — proportions and counts are out of scope. Use
  `get_diffs()` for those via the marginaleffects path.
- **One-sample t-test** — test against a fixed mu. Not in scope.
- **Paired t-test** — no `paired` argument. Not in scope.
- **Welch vs. pooled variance choice** — the design-based approach does not
  distinguish these; the GLM-based variance estimate is already design-consistent.
- **p-value adjustment in `get_t_test()`** — a single comparison produces one
  p-value; adjustment belongs only in `get_pairwise()`.

### Supported Design Classes

| Class | Supported |
|---|---|
| `survey_taylor` | Yes |
| `survey_replicate` | Yes |
| `survey_twophase` | Yes |
| `survey_nonprob` | Yes |

### Relationship to Other Functions

| Function | When to use |
|---|---|
| `get_t_test()` | One comparison (exactly 2 groups) |
| `get_pairwise()` | All pairwise comparisons (k ≥ 2 groups) |
| `get_diffs()` | All-vs-one reference, optional covariates, non-Gaussian |
| `get_rank_test()` | Nonparametric rank-based comparisons (planned separately) |

---

## II. File Organization

```
R/
├── analysis-t-test.R          # get_t_test(), get_pairwise(), .enumerate_pairs()

tests/testthat/
├── test-analysis-t-test.R     # happy paths, error paths, edge cases, print
└── test-analysis-t-test-numerical.R  # oracle tests vs survey::svyttest
```

`PAIRWISE_META_KEYS` and `T_TEST_META_KEYS` are added to `R/analysis-helpers.R`
alongside the other meta-key constants.

`.enumerate_pairs()` is defined in `analysis-t-test.R` (used only there).

---

## III. `get_t_test()` Specification

### 3.1 Signature

```r
get_t_test <- function(
  design,
  x,
  by,
  group        = NULL,
  conf_level   = 0.95,
  variance     = "ci",
  na.rm        = TRUE,
  min_cell_n   = 30L,
  decimals     = NULL,
  label_values = TRUE,
  label_vars   = TRUE,
  name_style   = "surveycore"
)
```

### 3.2 Arguments

| Argument | Type | Description |
|---|---|---|
| `design` | survey object | A `survey_base` subclass. Required. |
| `x` | bare name | The outcome variable. Must resolve to exactly one numeric column. |
| `by` | bare name | The grouping variable. Must produce a model matrix with exactly 2 columns after fitting (intercept + one binary indicator). Empty factor levels are dropped automatically, so a filtered design with a multi-level factor works as long as only 2 levels are active. See §3.4. |
| `group` | bare name(s) or `NULL` | Optional subgroup variable(s). When supplied, the t-test is run separately within each unique combination of group values; see §3.4. |
| `conf_level` | numeric(1) | Confidence level strictly in (0, 1). Default `0.95`. |
| `variance` | character | Which uncertainty columns to include. Valid values: `"se"`, `"ci"`. Default `"ci"`. Both may be requested: `c("se", "ci")`. |
| `na.rm` | logical(1) | Controls how NA `group` rows are handled. NA rows in `x` or `by` are always excluded (the GLM requires complete cases for the outcome and grouping variable). When `na.rm = FALSE`, rows where a `group` variable is NA are included as their own stratum; when `na.rm = TRUE` (default), they are excluded. Must be `TRUE` or `FALSE`. |
| `min_cell_n` | integer(1) | Warn when either group has fewer than this many unweighted observations. Default `30L`. Not validated — negative values silently suppress the warning (use `0L` to suppress intentionally). |
| `decimals` | integer(1) or `NULL` | Round all double output columns to this many decimal places. `NULL` = no rounding. |
| `label_values` | logical(1) | When `TRUE` (default), convert `by` and `group` factor codes to their value labels in the output. |
| `label_vars` | logical(1) | Accepted for API uniformity with other `get_*()` functions; has no visible effect on this function's output because column names are fixed (`level_a`, `level_b`, `estimate`, etc.). Default `TRUE`. |
| `name_style` | character(1) | Output column naming style. `"surveycore"` (default) uses package-standard names; `"broom"` renames via `.apply_name_style()`: `se`→`std.error`, `ci_low`→`conf.low`, `ci_high`→`conf.high`, `p_value`→`p.value`, `df`→`parameter`. `t_stat` is not in the broom map and stays as `t_stat` in both modes (intentional). |

### 3.3 Statistical Model

`get_t_test()` follows the mathematical model of `survey::svyttest()`.

**Degrees of freedom:** This function uses design-based df derived from the
survey design structure (`degf` = number of PSUs minus number of strata, or
the analogous quantity for replicate designs). The residual df is `degf - 1`
for this two-group model. Classical df (`n - p`) is NOT used. This is
consistent with `survey::svyttest()` and produces wider CIs and larger
p-values than classical inference for large surveys — for a 5,000-respondent
NHANES design, `degf` is typically in the range 20–100, not 4,998.

**Step 1 — Fit a Gaussian GLM:**

```r
fit <- survey_glm(x ~ by, design = [active design], family = gaussian())
```

The `by` variable is treated as a factor with two levels. The model matrix
has two columns: an intercept (1s) and a binary group indicator (0/1) where
0 = `level_a` (reference, first factor level) and 1 = `level_b` (comparison,
second factor level).

**Step 2 — Extract t-statistic and df:**

```r
beta <- coef(fit)                      # length-2 vector: [intercept, slope]
V    <- fit@vcov                        # 2x2 design-based sandwich covariance matrix
# V is the full design-based sandwich covariance, including FPC for
# survey_taylor designs where fpc is specified, and the appropriate
# scale/rscales adjustments for survey_replicate designs — all computed
# by survey_glm().

t_stat <- beta[2] / sqrt(V[2, 2])
df     <- max(1, fit@degf - 1)         # residual df: design df minus (p-1); clamped to 1
```

Note: Clamping to 1 is conservative. If `fit@degf` is small (< 2), t-statistics
and CIs should be interpreted with caution.

**Step 3 — Compute p-value and CI:**

```r
p_value <- 2 * stats::pt(-abs(t_stat), df = df)
ci_low  <- beta[2] - stats::qt((1 + conf_level) / 2, df = df) * sqrt(V[2, 2])
ci_high <- beta[2] + stats::qt((1 + conf_level) / 2, df = df) * sqrt(V[2, 2])
```

**Step 4 — Recover group means:**

```r
mean_a <- beta[1]              # intercept = weighted mean of level_a
mean_b <- beta[1] + beta[2]   # mean of level_b
```

SE for each group mean (not included in the output but available for internal
use if needed):

```r
se_a <- sqrt(V[1, 1])
se_b <- sqrt(V[1, 1] + V[2, 2] + 2 * V[1, 2])
```

**Summary of key quantities:**

| Quantity | Formula |
|---|---|
| `estimate` | `beta[2]` = `mean_b − mean_a` |
| `se` | `sqrt(V[2, 2])` |
| `t_stat` | `beta[2] / sqrt(V[2, 2])` |
| `df` | `max(1, fit@degf − 1)` |
| `p_value` | `2 * pt(-abs(t_stat), df)` |
| `ci_low` / `ci_high` | `beta[2] ± qt((1+conf_level)/2, df) * sqrt(V[2,2])` |
| `mean_a` | `beta[1]` |
| `mean_b` | `beta[1] + beta[2]` |

**Sign convention:** `estimate = mean_b − mean_a`, where `level_a` is the
first factor level and `level_b` is the second. This matches the sign of the
slope coefficient in the GLM and the `estimate` slot of `svyttest()`.

### 3.4 `by` Variable Handling

This approach follows `survey::svyttest()`, which validates the grouping
variable by inspecting the model matrix after fitting rather than checking
factor levels upfront. `model.matrix()` drops empty factor levels
automatically, so a design domain-filtered to two groups works even when
the underlying factor has more levels.

1. **Resolve** `by` to a column name via `rlang::as_name(rlang::ensym(by))`.
2. **Coerce** non-factor columns to factor: character, integer, and logical
   columns all trigger `surveycore_warning_by_coerced` when coerced.
   Ordered factors are accepted as-is (no warning).
3. **Check model matrix after fitting:** After `survey_glm()` returns,
   inspect the model matrix:
   - Exactly 2 columns (intercept + one binary indicator whose values are
     all in `{0, 1}` or `{1, 2}`) → proceed.
   - Any other shape → `surveycore_error_by_not_two_levels`.

   This check passes naturally when a domain-filtered design has only 2
   active levels — `model.matrix()` drops the empty levels. Example:

   ```r
   # Works: education has 4 levels but domain contains only 2
   design |>
     filter(education %in% c("HS", "College")) |>
     get_t_test(x = income, by = education)
   ```

4. **Set reference level:** The first non-empty factor level (column 2 of
   the model matrix = 0) is `level_a`. The second (column 2 = 1) is
   `level_b`. To control which group is the reference, re-level `by`
   before calling: `mutate(by = factor(by, levels = c("B", "A")))`.
5. **Label display:** When `label_values = TRUE` and the `by` column has
   value labels in `design@metadata`, the `level_a` and `level_b` output
   columns show label strings instead of raw codes. Use the same pattern as
   `get_diffs()` uses for its `treats` column: wrap the two level values in
   a temporary one-column data frame named `by_name`, call
   `.apply_group_labels(tmp_df, by_name, design, label_values)`, then
   extract the results back into `level_a` / `level_b`.

### 3.5 `group` Argument

When `group` is supplied, `get_t_test()` runs a separate t-test within each
unique combination of `group` values and returns one row per stratum.

**Stratum analysis:** For each group stratum, only rows matching that stratum
(and passing `na.rm` filtering) are used to fit the GLM. Domain-based
masking (not physical row removal) is used so that the full PSU and
stratification structure is available for variance estimation:

- **Taylor/twophase:** `survey_glm()` zeroes out non-domain score
  contributions before passing the full-length score matrix to the Taylor
  variance machinery. All PSUs and strata — including those with units in
  multiple group strata — are correctly accounted for.
- **Replicate:** `survey_glm()` restricts replicate refits to domain rows.
  Replicate weights are unit-level, so this is correct regardless of
  whether PSUs span group strata.

**Stratum ordering:** Group strata appear in ascending order of group variable
values. Rows where any `group` variable is `NA` are excluded from all strata
regardless of `na.rm`. (`na.rm` controls NA handling for `x` and `by` only;
see §3.2.)

**p-value adjustment:** Does not apply in `get_t_test()`. Each group stratum
produces one unadjusted p-value. If the user is running multiple strata and
wants adjustment, they should use `get_pairwise()` or adjust the p-values
themselves after the fact.

**Label display:** When `label_values = TRUE` and a `group` variable has value
labels, group column values show label strings.

### 3.6 Execution Flow

1. Validate design class via `.check_unsupported_class(design, "get_t_test")`.
2. Validate `na.rm`, `conf_level`, `decimals`, `name_style` via
   `.validate_shared_args(variance, conf_level, name_style, decimals, na.rm)`.
3. Validate `variance`: must be a subset of `c("se", "ci")`. Error:
   `surveycore_error_invalid_variance_arg`.
4. Resolve `x` to a single column name via `rlang::as_name(rlang::ensym(x))`.
   Error if the column is not found or if the expression is not a bare symbol:
   `surveycore_error_wrong_variable_count`.
5. Validate `x` is numeric. Error: `surveycore_error_non_numeric_variable`.
6. Resolve `by` to a column name; coerce to factor (warn if needed).
7. Resolve `group` to column names (or `character(0)` if `NULL`) via
   `.resolve_groups(design, group_quo)`.
8. Build group strata via `.build_group_combos()`. If `group` is `NULL`,
   a single pseudo-stratum covering all rows is used.
9. **For each group stratum:**
   a. Build `active_mask`: rows in this group stratum with non-NA `x` and `by`.
      NA rows in `x` or `by` are always excluded regardless of `na.rm` — the
      GLM cannot use them. `na.rm` only governs whether NA `group` rows appear
      as a stratum (handled by `.build_group_combos()`). `n_a` and `n_b` are
      computed from this same mask, so cell counts are always consistent with
      the GLM's effective rows.
   b. Check for empty cells first: if either active `by` level has zero
      in-mask rows, error immediately. Error: `surveycore_error_by_empty_cell`
      (use T-3 message when no `group` is active; T-3g message with
      `group_vals` populated when inside a group stratum). Then check
      `min_cell_n`: warn if either active `by` level has more than zero but
      fewer than `min_cell_n` in-mask rows. Warning:
      `surveycore_warning_small_cell`.
   c. Fit `survey_glm(x ~ by, design = [masked design], family = gaussian())`.
   d. Verify the model has exactly 2 coefficients: `length(coef(fit)) == 2L`.
      Error if not: `surveycore_error_by_not_two_levels`. This catches
      multi-level factors — a 3-level `by` produces 3 coefficients (intercept
      + 2 dummies). The binary constraint on the second predictor is
      guaranteed by factor coercion in step 6 and does not need a runtime
      check. Use `length(coef(fit))` (reads `fit@coefficients`, O(1)) rather
      than `ncol(model.matrix(fit))` (re-evaluates the design matrix, O(n)).
   e. Extract `beta`, `V`, compute `t_stat`, `df`, `p_value`, CI per §3.3.
   f. Compute `mean_a`, `mean_b`, `n_a`, `n_b` (unweighted in-mask counts
      per active level).
   g. Assemble result row.
10. Stack all stratum rows; prepend group columns.
11. Apply `label_values` to group columns via `.apply_group_labels()`.
12. Apply `decimals` rounding via `.apply_decimals()`.
13. Apply `name_style` column renaming via `.apply_name_style(result, name_style)`.
14. Attach column-level labels (§3.7).
15. Assemble `.meta`; construct `survey_t_test` tibble via
    `.make_result_tibble()`.

### 3.7 Output Contract

**S3 class:** `c("survey_t_test", "survey_result", "tbl_df", "tbl", "data.frame")`

**Column order:**

| Column | Type | Always? | Notes |
|---|---|---|---|
| Group columns | factor or raw | When `group` active | One column per group var; leftmost |
| `level_a` | character | Yes | First factor level of `by` |
| `level_b` | character | Yes | Second factor level of `by` |
| `estimate` | double | Yes | `mean_b − mean_a` |
| `mean_a` | double | Yes | Weighted mean of level_a group |
| `mean_b` | double | Yes | Weighted mean of level_b group |
| `n_a` | integer | Yes | Unweighted count for level_a |
| `n_b` | integer | Yes | Unweighted count for level_b |
| `se` | double | When `"se"` in `variance` | SE of `estimate` |
| `ci_low` | double | When `"ci"` in `variance` | Lower bound of CI |
| `ci_high` | double | When `"ci"` in `variance` | Upper bound of CI |
| `t_stat` | double | Yes | t-statistic |
| `df` | double | Yes | Residual degrees of freedom |
| `p_value` | double | Yes | Two-sided, unadjusted |
| `stars` | character | Yes | Significance stars via `.stars_pval()` |

**Column-level labels** (stored as `attr(col, "label")`):

| Column | Label |
|---|---|
| `level_a` | `"{by_label} (A)"` |
| `level_b` | `"{by_label} (B)"` |
| `estimate` | `"Difference (B − A)"` |
| `mean_a` | `"Mean (A)"` |
| `mean_b` | `"Mean (B)"` |
| `n_a` | `"N (A)"` |
| `n_b` | `"N (B)"` |
| `se` | `"Std. Error"` |
| `ci_low` | `"Low CI"` |
| `ci_high` | `"High CI"` |
| `t_stat` | `"t"` |
| `df` | `"df"` |
| `p_value` | `"P-Value"` |
| `stars` | `""` |

Where `{by_label}` is the variable label from `design@metadata`, or the
column name if no label is set.

### 3.8 `.meta` Contract

`T_TEST_META_KEYS <- c("group", "x", "by")`

| Key | Type | Value |
|---|---|---|
| `design_type` | char(1) | Auto-derived by `.build_meta()` |
| `n_respondents` | integer(1) | `nrow(design@data)` |
| `conf_level` | numeric(1) | As supplied |
| `call` | language | `match.call()` |
| `group` | named list | `.build_group_meta(design, group_vars)` |
| `x` | named list | `.extract_var_meta(design, x_name)` |
| `by` | named list | `.extract_var_meta(design, by_name)` with appended `levels` key: the two factor levels in order |

### 3.9 Print Method

```
# A survey_t_test result
# Design: Taylor series | N: 5,000
# DV: {x_label} | By: {by_label} ({level_a} vs. {level_b})
```

Followed by the tibble body. The snapshot test uses `nhanes_design` with
`x = bpxsy1`, `by = riagendr` (2 levels: 1 = Male, 2 = Female), and
`decimals = 2`. The snapshot captures the full `print()` output including
the tibble body.

---

## IV. `get_pairwise()` Specification

### 4.1 Signature

```r
get_pairwise <- function(
  design,
  x,
  by,
  group        = NULL,
  pval_adj     = "holm",
  conf_level   = 0.95,
  variance     = "ci",
  na.rm        = TRUE,
  min_cell_n   = 30L,
  decimals     = NULL,
  label_values = TRUE,
  label_vars   = TRUE,
  name_style   = "surveycore"
)
```

### 4.2 Arguments

All arguments except `pval_adj` have the same semantics as `get_t_test()`.

| Argument | Type | Description |
|---|---|---|
| `pval_adj` | character(1) | A valid method for `stats::p.adjust()`. Default `"holm"`. Use `"none"` for unadjusted. Always recorded in `.meta`. Error: `surveycore_error_invalid_pval_adj`. |

`by` must have **≥ 2 levels** (not exactly 2 as in `get_t_test()`). Error
if < 2 levels: `surveycore_error_by_one_level`.

### 4.3 Pair Enumeration

All k(k−1)/2 pairs are generated from the factor levels of `by` in
lexicographic order by `.enumerate_pairs()`:

```r
.enumerate_pairs <- function(levels) {
  pairs <- utils::combn(levels, 2, simplify = FALSE)
  # pairs is a list of character(2) vectors: c(level_a, level_b)
  # ordered: all pairs starting with level[1], then level[2], etc.
  pairs
}
```

For each pair `(a, b)`:
1. Create `design_ab` as a copy of `design` with `design_ab@data[[SURVEYCORE_DOMAIN_COL]]`
   set to a full-length logical vector: `by_col %in% c(a, b) & domain_mask`,
   where `domain_mask` is the result of `.apply_domain(design)` (all-`TRUE` if
   no prior domain column exists). This is **not** physical row removal — all
   rows are retained so that `survey_glm()` can apply the correct zero-score /
   replicate mechanism for variance estimation via `.apply_domain()` (see §3.5).
   Do **not** call `surveytidy::filter()` (it would create a circular package
   dependency: surveycore → surveytidy → surveycore).
2. Re-level `by` so that `a` is the reference (first factor level).
3. Call `get_t_test(design_ab, x, by = by, group = group, ...)`.
4. Collect the result row(s).

**The `by` re-leveling in step 2 ensures `estimate = mean_b − mean_a` is
consistent with the pair ordering.** Level `a` is always `level_a`; level
`b` is always `level_b`.

**Methodological note:** Pair-subsetting (fitting a separate 2-level GLM per
pair) is used rather than a single k-level GLM with contrasts. Both approaches
produce asymptotically equivalent estimates under design-based inference; the
pair-subsetting approach is simpler and avoids the need for `svycontrast()`,
at the cost of fitting k(k−1)/2 models.

### 4.4 P-value Adjustment

After all pairs are run and results stacked:

- **Without `group`:** Apply `stats::p.adjust(p_values, method = pval_adj)`
  to all k(k−1)/2 p-values.
- **With `group`:** Apply adjustment **separately within each group stratum**.
  Each stratum has k(k−1)/2 p-values; they are adjusted independently.

The adjusted p-values replace `p_value` in the output. The unadjusted
p-values are not retained in the output (they are available in the `.meta` for
debugging only if needed, but this is not required in v1).

`stars` are computed from the **adjusted** p-values.

Even when `pval_adj = "none"`, call `p.adjust(..., method = "none")` (returns
unadjusted values unchanged) so the code path is uniform. Record
`pval_adj = "none"` in `.meta`.

**Conservatism note:** Design-based pairwise t-statistics are correlated
through shared PSU and strata structure. Standard adjustment methods
(Bonferroni, Holm) assume independence or positive dependence and are
therefore conservative — adjusted p-values are larger than the
FWER-optimal values. No design-based correction for this correlation is
implemented; the standard `p.adjust()` approach is consistent with common
practice in complex-survey pairwise comparisons.

### 4.5 Execution Flow

1. Validate design class.
2. Validate `na.rm`, `conf_level`, `decimals`, `name_style`, `variance` via
   `.validate_shared_args(variance, conf_level, name_style, decimals, na.rm)`.
3. Validate `pval_adj`: must be a valid `stats::p.adjust` method.
4. Resolve `x` to a column name string:
   `x_name <- rlang::as_name(rlang::ensym(x))`. Validate numeric.
4a. Compute domain mask: `domain_mask <- .apply_domain(design)`. Called once
   before the pair loop; not recomputed per pair.
5. Resolve `by` to a column name string:
   `by_name <- rlang::as_name(rlang::ensym(by))`. Coerce to factor (warn if
   needed). Compute active levels — those with ≥ 1 non-NA observation after
   applying the domain mask: `levels(by_col)[tabulate(by_col[domain_mask]) > 0]`.
   NA values in `by` are excluded from the active-level count regardless of
   `na.rm`; NA `by` rows are always excluded from the GLM fit.
   Check ≥ 2 active levels. Error: `surveycore_error_by_one_level`. Pair
   enumeration uses active levels only, so a domain-filtered design with 3
   of 4 levels present produces 3 pairs, not 6.
6. Resolve `group` variables. Capture `group_sym` via `rlang::enquo(group)`
   for forwarding.
7. Enumerate all k(k−1)/2 pairs via `.enumerate_pairs(active_levels)`.
8. **For each pair `(a, b)`:**
   a. Subset design to rows where `by %in% c(a, b)`.
   b. Re-level `by` factor by assigning back into the design data:
      `design_ab@data[[by_name]] <- factor(design_ab@data[[by_name]], levels = c(a, b))`.
      This does not trigger S7 validators because `by` is not a design variable
      (`@variables` is unchanged).
   c. Forward to `get_t_test()` using rlang injection so that `x_name` and
      `by_name` (already-resolved strings) are passed as bare symbols:
      ```r
      rlang::inject(get_t_test(
        design_ab,
        x     = !!rlang::sym(x_name),
        by    = !!rlang::sym(by_name),
        group = !!group_sym,
        ...
      ))
      ```
      Use `rlang::ensym()` (not `enquo()`) for `x` and `by` capture because
      both arguments must be bare column-name symbols, not arbitrary expressions.
      Errors from `get_t_test()` — including `surveycore_error_by_empty_cell`
      when a group stratum has no observations for one or both `by` levels —
      propagate unchanged and abort `get_pairwise()`. Filter the design or
      `group` variable before calling to exclude problematic strata.
   d. Collect result (one row per group stratum).
   e. Add `level_a = a`, `level_b = b` columns (overwriting whatever
      `get_t_test()` produced, since subsetting may affect factor display).
9. Stack all pair results in pair-enumeration order (all pairs starting with
   level[1] first, etc.).
10. Apply p-value adjustment (separately per group stratum) per §4.4.
11. Recompute `stars` from adjusted p-values.
12. Apply `decimals` rounding.
13. Apply `name_style` column renaming via `.apply_name_style(result, name_style)`.
14. Attach column-level labels (§4.6).
15. Assemble `.meta`; construct `survey_pairwise` tibble.

### 4.6 Output Contract

**S3 class:** `c("survey_pairwise", "survey_result", "tbl_df", "tbl", "data.frame")`

**Column order:** identical to `survey_t_test` (§3.7). `p_value` is adjusted.

**Column-level labels:** identical to `survey_t_test` (§3.7), except:

| Column | Label |
|---|---|
| `p_value` | `"P-Value ({pval_adj})"` — e.g., `"P-Value (holm)"` |

### 4.7 `.meta` Contract

`PAIRWISE_META_KEYS <- c("group", "x", "by", "pval_adj")`

All keys from `T_TEST_META_KEYS`, plus:

| Key | Type | Value |
|---|---|---|
| `pval_adj` | char(1) | Method passed to `p.adjust()`. Never `NULL`. |

### 4.8 Print Method

```
# A survey_pairwise result
# Design: Taylor series | N: 5,000
# DV: {x_label} | By: {by_label} ({k} levels, {k*(k-1)/2} pairs)
# Adjustment: {pval_adj}
```

Followed by the tibble body. The snapshot test uses `nhanes_design` with
`x = bpxsy1`, `by = riagendr` (2 levels, 1 pair), `pval_adj = "holm"`,
and `decimals = 2`. The snapshot captures the full `print()` output
including the tibble body.

---

## V. Error & Warning Conditions

New classes to add to `plans/error-messages.md`:

| # | Function | Condition | Level | Class | Message Template |
|---|---|---|---|---|---|
| T-1 | `get_t_test()` | Model matrix has ≠ 2 columns after fitting (active `by` levels ≠ 2) | ERROR | `surveycore_error_by_not_two_levels` | `"{.arg by} ({.field {by_name}}) must produce exactly 2 active groups, not {n_active}. Filter the design to 2 groups with {.fn surveytidy::filter}, or use {.fn get_pairwise} for k > 2 groups."` |
| T-2 | `get_t_test()` | `by` is character, integer, or logical — coerced to factor | WARN | `surveycore_warning_by_coerced` | `"{.field {by_name}} coerced to factor. Level order: {.val {levels}}."` |
| T-3 | `get_t_test()` | After NA removal, one active level of `by` has zero rows (no `group`) | ERROR | `surveycore_error_by_empty_cell` | `"Level {.field {empty_level}} of {.arg by} ({.field {by_name}}) has no non-NA observations. Cannot compute t-test."` |
| T-3g | `get_t_test()` | Within a group stratum, one active level of `by` has zero rows | ERROR | `surveycore_error_by_empty_cell` | `"In group stratum {.val {group_vals}}, level {.field {empty_level}} of {.arg by} ({.field {by_name}}) has no non-NA observations."` |
| P-1 | `get_pairwise()` | `by` has < 2 active levels | ERROR | `surveycore_error_by_one_level` | `"{.arg by} ({.field {by_name}}) must have at least 2 active groups, not {n_active}."` |

**Reused classes (no new rows needed):**

| Class | Reused from |
|---|---|
| `surveycore_error_unsupported_class` | `.check_unsupported_class()` |
| `surveycore_error_non_numeric_variable` | row 43 |
| `surveycore_error_wrong_variable_count` | row 92 |
| `surveycore_error_invalid_conf_level` | row 45a |
| `surveycore_error_invalid_decimals` | row 45b |
| `surveycore_error_invalid_variance_arg` | row 45 |
| `surveycore_error_invalid_pval_adj` | row 96 |
| `surveycore_error_na_rm_not_logical` | row 81 |
| `surveycore_warning_small_cell` | row 49 |
| `surveycore_error_empty_domain` | row 83 — via `survey_glm()` when the combined `active_mask` + prior domain filter leaves 0 in-domain rows, even though both `by` levels have non-NA observations in `active_mask`. Can occur when a `surveytidy::filter()`-narrowed design is used with a `group` stratum containing no domain-matching rows. |

---

## VI. Testing Requirements

### Happy Path — `get_t_test()`

- [ ] Returns `survey_t_test` tibble with correct columns, types, and S3 class
- [ ] One row when no `group`; one row per stratum when `group` is active
- [ ] `estimate = mean_b − mean_a` matches manual calculation
- [ ] `mean_a`, `mean_b` match manual weighted group means
- [ ] `t_stat = estimate / se`
- [ ] `p_value = 2 * pt(-abs(t_stat), df = df)`
- [ ] CI bounds use `qt((1 + conf_level)/2, df) * se`
- [ ] `variance = "se"` omits CI columns; `variance = c("se", "ci")` includes both
- [ ] `label_values = TRUE` converts factor codes to label strings
- [ ] `label_values = FALSE` keeps raw codes
- [ ] `label_vars = TRUE` and `label_vars = FALSE` both accepted without error;
  output column names are unchanged (they are fixed as `level_a`, `level_b`,
  `estimate`, etc.)
- [ ] `name_style = "broom"` renames columns to tidymodels conventions
  (`estimate`, `std.error`, `conf.low`, `conf.high`, `p.value`, `parameter`);
  surveycore column names (`se`, `ci_low`, `ci_high`, `df`) are absent;
  `t_stat` remains `t_stat` (not in broom map; intentional)
- [ ] `decimals` rounds all double columns
- [ ] All four design classes: `survey_taylor`, `survey_replicate`,
  `survey_twophase`, `survey_nonprob`
- [ ] Print snapshot matches expected header format
- N/A: Multi-variable `x` — single column enforced; `>1` fires
  `surveycore_error_wrong_variable_count` (covered in Error Paths)

### Happy Path — `get_pairwise()`

- [ ] Returns `survey_pairwise` tibble with one row per pair (no group)
- [ ] Returns one row per pair per group stratum (with group)
- [ ] Pairs in lexicographic factor-level order
- [ ] `pval_adj = "holm"` applies Holm correction across all pairs
- [ ] `pval_adj = "none"` returns unadjusted p-values
- [ ] `stars` computed from adjusted p-values
- [ ] With group: p-value adjustment applied separately within each stratum
- [ ] `label_vars = TRUE` and `label_vars = FALSE` both accepted without error;
  output column names are unchanged
- [ ] `name_style = "broom"` renames columns to tidymodels conventions
  (`estimate`, `std.error`, `conf.low`, `conf.high`, `p.value`, `parameter`);
  surveycore column names (`se`, `ci_low`, `ci_high`, `df`) are absent;
  `t_stat` remains `t_stat` (not in broom map; intentional)
- [ ] All four design classes
- [ ] Print snapshot matches expected header (including k levels, k*(k-1)/2 pairs,
  and adjustment method)
- N/A: Multi-variable `x` — single column enforced (same as `get_t_test()`)

### Error Paths — both functions

One `expect_error(class = ...)` + `expect_snapshot(error = TRUE)` block per
new error class (T-1, T-2, P-1), plus one block for each reused class
that is newly triggered by these functions (e.g., `non_numeric_variable`).

### Edge Cases

- [ ] `by` is a character column — coerces to factor, warning issued
- [ ] `by` with exactly 2 levels in `get_t_test()` but one level has 0 rows
  after NA removal — `by_empty_cell` error
- [ ] `group` with a stratum where one `by` level is empty —
  `by_empty_cell` error includes stratum info in message
- [ ] `by` with 2 levels in `get_pairwise()` — produces exactly 1 pair
- [ ] `by` with 4 levels in `get_pairwise()` — produces exactly 6 pairs
- [ ] `na.rm = FALSE` when `x` has no NAs — identical result to `na.rm = TRUE`
- [ ] `na.rm = FALSE` when `x` has NAs — estimates match `na.rm = TRUE` (NA
  rows excluded from GLM in both cases); `n_a`/`n_b` counts do not include
  NA rows (count consistent with GLM's effective rows)
- [ ] Domain estimation (`get_t_test()`): design pre-filtered via
  `surveytidy::filter()` produces the same `estimate`, `se`, and `p_value`
  as running on the physically subsetted data (with `survey_taylor` design)
- [ ] Domain estimation (`get_pairwise()`): same equivalence holds for
  `get_pairwise()` — pair-loop domain composition produces correct estimates
  on a domain-filtered design
- [ ] `conf_level = 0.99` — CI bounds are wider than at 0.95
- [ ] `min_cell_n = 0L` — suppresses small-cell warning

### Meta Contract

- [ ] `meta(result)` for `survey_t_test` contains all keys in `T_TEST_META_KEYS`
  plus `design_type`, `n_respondents`, `conf_level`, `call`
- [ ] `meta(result)$by` contains a `levels` sub-key with the two active factor
  levels in reference-first order (i.e., `c(level_a, level_b)`)
- [ ] `meta(result)` for `survey_pairwise` contains all `T_TEST_META_KEYS` keys
  plus `pval_adj` matching the method passed

### Numerical Tests (`test-analysis-t-test-numerical.R`)

Compare against `survey::svyttest()` using `nhanes_2017`:

```r
skip_if_not_installed("survey")

# get_t_test() must match svyttest() exactly
t1 <- get_t_test(nhanes_design, bpxsy1, by = gender)
sv <- survey::svyttest(bpxsy1 ~ gender, nhanes_svydesign)

expect_equal(t1$estimate, coef(sv)[["difference in mean"]], tolerance = 1e-10)
expect_equal(t1$t_stat,   sv$statistic[["t"]],              tolerance = 1e-10)
expect_equal(t1$df,       sv$parameter[["df"]],             tolerance = 1e-10)
expect_equal(t1$p_value,  sv$p.value,                       tolerance = 1e-10)
```

Tolerances follow the project standard: 1e-10 for point estimates, 1e-8 for
SEs, 1e-6 for CI bounds.

---

## VII. Quality Gates

- [ ] `devtools::check()` — 0 errors, 0 warnings, ≤ 2 notes
- [ ] 98%+ line coverage on `R/analysis-t-test.R`
- [ ] All error classes in §V have typed tests (`expect_error(class = ...)`)
- [ ] All four design classes have ≥ 1 happy-path test each
- [ ] Numerical oracle tests pass vs `survey::svyttest()`
- [ ] `get_pairwise()` vs `get_t_test()` consistency: `get_pairwise()` on a
  2-level `by` produces the same estimate, SE, and unadjusted p-value as
  `get_t_test()` on the same data
- [ ] `plans/error-messages.md` updated with new error/warning classes (T-1,
  T-2, P-1)
- [ ] `MEMORY.md` updated to reflect these functions as planned
