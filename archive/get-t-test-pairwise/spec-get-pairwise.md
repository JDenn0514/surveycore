# surveycore — `get_pairwise()`: All-vs-All Pairwise Comparisons

**Version:** 0.2
**Date:** March 2026
**Status:** Methodology-locked — Stage 2 complete

---

## Document Purpose

This document is the authoritative specification for the `get_pairwise()`
function in the surveycore package. It defines the API contract, estimation
paths, output structure, error conditions, and testing requirements.
Implementation must follow these rules exactly. Where a rule is already
defined in `code-style.md`, `r-package-conventions.md`, or
`surveycore-conventions.md`, this document references those rules rather than
restating them.

**Reference documents:**
- `plans/spec-get-diffs.md` — `get_diffs()` spec; `get_pairwise()` shares
  architecture, estimation paths, and most arguments.
- `archive/phase-2/spec-phase-2.md` — Phase 2 spec; `get_pairwise()` builds
  on `survey_glm()`, `clean()`, and the marginaleffects extension interface.

---

## I. Scope

### What This Delivers

| Component | Description |
|---|---|
| `get_pairwise()` | Exported function: all-vs-all pairwise comparisons via survey-weighted regression |
| `survey_pairwise` S3 class | Result tibble with column-level labels and `.meta` |
| `print.survey_pairwise()` | Custom print method: header lines + tibble body |
| `PAIRWISE_META_KEYS` | Constant: function-specific meta keys for `.make_result_tibble()` validation |

### What This Does NOT Deliver

- **Dunnett-style (all-vs-one) comparisons** — that is `get_diffs()`.
- **Custom contrast matrices** — user-supplied contrast vectors or hypothesis
  matrices are a future extension (`get_contrasts()`, see roadmap Phase 4).
- **Multiple DVs in one call** — one DV per call. P-value adjustment across
  DVs is the analyst's responsibility.
- **Non-pairwise multiple comparisons** — Scheffé, Dunnett, or custom linear
  combinations are out of scope.
- **Interaction contrasts** — whether the treatment effect *differs* between
  groups is not reported. `get_pairwise()` reports pairwise comparisons
  *within* each group when `group` is active.

### Relationship to `get_diffs()`

`get_pairwise()` is the Tukey-style complement to `get_diffs()`:

| | `get_diffs()` | `get_pairwise()` |
|---|---|---|
| Comparison structure | All-vs-one reference | All-vs-all pairs |
| Rows (k levels) | k − 1 comparisons | k(k−1)/2 comparisons |
| Reference level | Required (explicit or default) | Not applicable |
| `show_means` | Reference row with `estimate = 0` | Per-level means in separate columns |
| Default `pval_adj` | `NULL` (none) | `"holm"` |
| Estimation engine | `survey_glm()` + clean/marginaleffects | Same |

### Supported Design Classes

All four surveycore design classes are supported. `get_pairwise()` delegates
to `survey_glm()`, which handles variance estimation for each design type.

| Class | Supported |
|---|---|
| `survey_taylor` | Yes |
| `survey_replicate` | Yes |
| `survey_twophase` | Yes |
| `survey_nonprob` | Yes |

### Prerequisites

| Prerequisite | What `get_pairwise()` Needs |
|---|---|
| Phase 2 complete | `survey_glm()`, `clean()`, `survey_glm_fit` S7 class |
| Phase 2 marginaleffects extension | `marginaleffects::avg_comparisons()` dispatch on `survey_glm_fit` |
| `marginaleffects` in Imports | Required for pairwise contrasts (all paths) |
| `get_diffs()` merged | Shared infrastructure: `.stars_pval()`, column labels, estimation patterns |

---

## II. Architecture

### 2.1 File Organization

```
R/
├── analysis-pairwise.R          # get_pairwise() exported function
├── analysis-pairwise-helpers.R  # .build_pair_labels(), .pairwise_clean_path()
├── analysis-diffs-helpers.R     # .stars_pval() (already exists, shared)
├── analysis-helpers.R           # PAIRWISE_META_KEYS (added alongside existing)

tests/testthat/
├── test-analysis-pairwise.R              # Happy paths + error paths + edge cases
├── test-analysis-pairwise-numerical.R    # Oracle tests vs manual / survey pkg
└── test-analysis-pairwise-marginaleffects.R  # marginaleffects path tests
```

### 2.2 Internal Helpers

All internal helpers are not exported and prefixed with `.`, per
`code-style.md §4`.

#### `.build_pair_labels(levels)`

Generates all k(k−1)/2 pairwise comparison labels from a factor's levels.

```r
.build_pair_labels <- function(levels) {
  # Returns a data.frame with columns: level_a, level_b
  # Row order: lexicographic by factor level order
  # Example: levels = c("A", "B", "C") →
  #   level_a = c("A", "A", "B")
  #   level_b = c("B", "C", "C")
  combs <- utils::combn(levels, 2)
  data.frame(
    level_a = combs[1, ],
    level_b = combs[2, ],
    stringsAsFactors = FALSE
  )
}
```

#### `.pairwise_clean_path(fit, pair_labels, conf_level)`

Extracts all pairwise contrasts from a fitted Gaussian model using the
coefficient vector and variance-covariance matrix directly (no
marginaleffects dependency).

```r
.pairwise_clean_path <- function(fit, pair_labels, conf_level) {
  # 1. Extract coefficient vector (beta) and vcov matrix from fit
  # 2. For each pair (A, B): contrast = beta_A - beta_B
  #    (where beta_ref = 0, beta_A = coef for level A)
  # 3. SE = sqrt(c' %*% vcov %*% c) where c is the contrast vector
  # 4. t-stat, p-value, CI via t-distribution with fit@degf
  # Returns: data.frame with level_a, level_b, estimate, se, ci_low,
  #          ci_high, p_value
}
```

#### `PAIRWISE_META_KEYS`

Defined in `analysis-helpers.R` alongside the other `*_META_KEYS` constants.

```r
PAIRWISE_META_KEYS <- c(
  "group", "x", "treats", "covariates", "family", "link",
  "pval_adj", "estimate_method", "estimate_scale"
)
```

Note: no `mean_method` or `ref_level` (unlike `DIFFS_META_KEYS`) — pairwise
comparisons have no single reference level, and means are a supplementary
column rather than a core estimation output.

---

## III. `get_pairwise()` — Function Specification

### 3.1 Signature

```r
get_pairwise <- function(
  design,
  x,
  treats,
  group       = NULL,
  covariates  = NULL,
  pval_adj    = "holm",
  show_means  = TRUE,
  scale       = c("ame", "link"),
  variance    = "ci",
  conf_level  = 0.95,
  min_cell_n  = 30L,
  n_weighted  = FALSE,
  decimals    = NULL,
  na.rm       = TRUE,
  label_values = TRUE,
  name_style  = "surveycore",
  ...
)
```

### 3.2 Link-Scale Suppression Rule

Identical to `get_diffs()` Section 3.2:

> **When `scale = "link"` and family is non-gaussian**, the `mean_a` and
> `mean_b` columns are suppressed (omitted from output entirely). Link-scale
> predicted values do not serve the contextual purpose of the mean columns.

### 3.3 Argument Table

| Argument | Type | Default | Description |
|---|---|---|---|
| `design` | `survey_base` subclass | (required) | Survey design object. |
| `x` | tidy-select (single) | (required) | Dependent variable. Must resolve to exactly one numeric column. |
| `treats` | tidy-select (single) | (required) | Treatment variable. Must resolve to exactly one column with at least 2 unique levels. Coerced to factor if not already. |
| `group` | tidy-select | `NULL` | Subgroup variable(s) for interaction analysis. When provided, pairwise comparisons are reported separately within each subgroup. |
| `covariates` | character vector | `NULL` | Additional model terms as strings. When provided, forces the marginaleffects estimation path. |
| `pval_adj` | character(1) | `"holm"` | P-value adjustment method passed to `stats::p.adjust()`. Default `"holm"` — a step-down procedure that controls FWER while being less conservative than Bonferroni. Set to `"none"` to disable. |
| `show_means` | logical | `TRUE` | If `TRUE`, includes `mean_a` and `mean_b` columns showing the weighted mean for each level in the pair. Subject to link-scale suppression (Section 3.2). |
| `scale` | character(1) | `"ame"` | Scale for pairwise contrasts. `"ame"`: average marginal effects on the response scale. `"link"`: contrasts on the link scale. For Gaussian/identity models, both are identical. |
| `variance` | character | `"ci"` | Which uncertainty columns to include. One or more of: `"se"`, `"ci"`. `NULL` = no uncertainty columns. |
| `conf_level` | numeric(1) | `0.95` | Confidence level for intervals. Must be in (0, 1). |
| `min_cell_n` | integer(1) | `30L` | Minimum unweighted cell size before `surveycore_warning_small_cell` fires. |
| `n_weighted` | logical | `FALSE` | If `TRUE`, includes `n_a_weighted` and `n_b_weighted` columns. |
| `decimals` | integer(1) or `NULL` | `NULL` | If non-NULL, rounds all numeric output columns. |
| `na.rm` | logical | `TRUE` | If `TRUE`, drops rows with NA in `x`, `treats`, or `group` before fitting. |
| `label_values` | logical | `TRUE` | If `TRUE`, the `level_a`, `level_b`, and `group` columns display value labels from metadata. |
| `name_style` | character(1) | `"surveycore"` | Column naming convention. `"surveycore"` or `"broom"`. |
| `...` | | | Passed to `survey_glm()`. Common uses: `family = quasibinomial()`. |

### 3.4 Argument Differences from `get_diffs()`

| `get_diffs()` argument | `get_pairwise()` | Rationale |
|---|---|---|
| `ref_level` | Removed | No single reference level in all-vs-all comparisons |
| `show_pct_change` | Removed | Percentage change is ambiguous when there is no fixed reference; users can compute from `mean_a` and `mean_b` |
| `pval_adj` default `NULL` | Default `"holm"` | Pairwise comparisons involve k(k−1)/2 tests; unadjusted p-values are misleading by default |

### 3.5 Estimation Paths

`get_pairwise()` determines the estimation path using the same logic as
`get_diffs()`:

| Condition | Path |
|---|---|
| No covariates + `gaussian()` family + no group | **Clean path** |
| Non-gaussian family (any config) | **Marginaleffects path** |
| Covariates present (any family) | **Marginaleffects path** |
| Group present (any family, any covariates) | **Marginaleffects path** |

### 3.6 Formula Construction

Identical to `get_diffs()` Section 3.6. The same model is fit; only the
contrast extraction differs.

| Configuration | Formula built |
|---|---|
| No covariates, no group | `x ~ treats` |
| Covariates, no group | `x ~ treats + cov1 + cov2 + ...` |
| No covariates, with group | `x ~ treats * group` |
| Covariates, with group | `x ~ treats * group + cov1 + cov2 + ...` |

### 3.7 Treatment Column Handling

Same as `get_diffs()` Section 3.7: coerce to factor, force treatment
contrasts. No releveling to a reference level is needed (all pairwise
contrasts are computed regardless of the factor's reference level), but
treatment contrasts are still forced to ensure a consistent coefficient
interpretation for the clean path.

### 3.8 Estimation: Clean Path (Bivariate + Gaussian + No Group)

For the simple case, pairwise contrasts are extracted directly from the
coefficient vector and variance-covariance matrix without marginaleffects.

1. Fit: `fit <- survey_glm(design, formula, na.action = na_action, ...)`
2. Extract `beta <- coef(fit)` and `V <- fit@vcov`. The `fit@vcov` matrix is
   the design-based sandwich variance (per Phase 2 spec), computed by
   `survey_glm()` for the specific design class (Taylor, replicate, two-phase,
   SRS, or nonprob). For all design classes, `fit@vcov` reflects the full
   design-based variance, including finite population corrections, replicate
   deviations, and two-phase decomposition as applicable. The contrast formula
   applies without modification.
3. For k treatment levels, there are k−1 non-reference coefficients. Each
   coefficient represents the difference from the reference level. To get
   pairwise differences between non-reference levels, use:
   - Level A vs Level B: `beta_A - beta_B` (where reference = 0)
   - SE: `sqrt(V[A,A] + V[B,B] - 2*V[A,B])`
   - For comparisons involving the reference level: `beta_A` directly, with
     `SE = sqrt(V[A,A])`
4. Compute t-statistics, p-values, and CIs. Residual df:
   `res_df <- max(1, fit@degf - (p - 1L))` where `p = length(coef(fit))`.
   The `max(1, ...)` clamping prevents `NaN` from `qt()` when df would be
   non-positive. All df values are numeric (double), never integer.
5. When `show_means = TRUE`, compute means from the intercept:
   - Reference mean = intercept
   - Level A mean = intercept + beta_A

This is implemented in `.pairwise_clean_path()`.

**Coefficient = AME equivalence (Gaussian only):** This clean path produces
pairwise contrasts identical to the marginaleffects path only when: (a) family
is Gaussian with identity link, (b) no covariates, (c) no group interactions.
The routing logic (Section 7.2) guarantees these conditions.

### 3.9 Estimation: Marginaleffects Path

Used when covariates are present, family is non-gaussian, or group is active.

**Variance chain:** `avg_comparisons()` calls `vcov()` on `survey_glm_fit`,
which returns the design-based Binder sandwich variance (not model-based OLS
variance). For non-Gaussian families, marginaleffects computes a numerical
Jacobian to convert coefficients from the link scale to the response scale.
The delta method then combines this Jacobian with the design-based `vcov` to
produce standard errors on the response scale. This ensures that all pairwise
contrast SEs, CIs, and p-values reflect the survey design (stratification,
clustering, weighting) regardless of the estimation path. Reference: Binder
(1983), JASA 78(382):626–631.

#### 3.9.1 Common Parameters

Same as `get_diffs()` Section 3.9.1:

```r
p <- length(coef(fit))
res_df <- max(1, fit@degf - (p - 1L))
me_type <- if (scale == "link") "link" else "response"
```

#### 3.9.2 Pairwise Contrasts

**Without group:**
```r
pw <- marginaleffects::avg_comparisons(
  fit,
  variables = treats_name,
  comparison = "pairwise",
  type = me_type,
  wts = TRUE,
  df = res_df
)
```

**With group:**
```r
pw <- marginaleffects::avg_comparisons(
  fit,
  variables = treats_name,
  comparison = "pairwise",
  by = group_names,
  type = me_type,
  wts = TRUE,
  df = res_df
)
```

`marginaleffects::avg_comparisons()` with `comparison = "pairwise"` produces
one row per pair of treatment levels. The `contrast` column identifies the
pair (e.g., `"B - A"`). Columns used: `estimate`, `std.error`, `p.value`,
`conf.low`, `conf.high`.

#### 3.9.3 Means (Absolute Levels)

When `show_means = TRUE` and link-scale suppression does not apply:

```r
preds <- marginaleffects::avg_predictions(
  fit, by = treats_name, type = me_type, wts = TRUE, df = res_df
)
```

With group: `by = c(treats_name, group_names)`.

#### 3.9.4 Assembly

1. Parse `avg_comparisons()` output to extract `level_a` and `level_b` from
   the `contrast` column (format: `"B - A"` → `level_a = "A"`, `level_b = "B"`).
   Normalize ordering to match `.build_pair_labels()` (alphabetical by factor
   level order, not by subtraction order). **Sign adjustment:** When the
   marginaleffects contrast is `"B - A"` (i.e., `estimate = mean(B) - mean(A)`),
   negate the estimate, and swap `conf.low`/`conf.high` (negated), to produce
   `estimate = mean(A) - mean(B)` matching the output contract
   `mean(level_a) − mean(level_b)`. Only negate when the normalized pair order
   differs from the marginaleffects subtraction order.
2. If `preds` was computed (i.e., `show_means = TRUE` and no link-scale
   suppression), left-join predicted means from `avg_predictions()` to get
   `mean_a` and `mean_b` for each pair. Otherwise, skip this step and omit
   `mean_a` and `mean_b` columns.
3. Map marginaleffects column names to output names:
   - `pw$estimate` → `estimate`
   - `pw$std.error` → `se`
   - `pw$conf.low` → `ci_low`
   - `pw$conf.high` → `ci_high`
   - `pw$p.value` → `p_value`
4. Compute `n_a` and `n_b` per treatment level — see Section 5.2.
5. After assembly, sort rows to match `.build_pair_labels()` order
   (Section 5.3). Do not rely on marginaleffects' internal ordering.

### 3.10 P-Value Adjustment

Applied after estimation, before star assignment.

1. Apply `stats::p.adjust(p_values, method = pval_adj)` to all pairwise
   comparison p-values.
2. **When `group` is active:** Apply adjustment separately within each group
   stratum. Each group stratum is treated as a separate family of k(k−1)/2
   tests. This follows the exploratory subgroup analysis convention (Alosh,
   Bretz, & Huque, 2014, *Statistics in Medicine* 33(11):1923–1935). For
   global adjustment across all comparisons, users can apply
   `stats::p.adjust()` post-hoc.
3. Default method is `"holm"` — controls family-wise error rate while being
   uniformly more powerful than Bonferroni (Holm, 1979, *Scandinavian Journal
   of Statistics* 6(2):65–70). This matches R base `pairwise.t.test()` which
   also defaults to `p.adjust.method = "holm"`. Note: this departs from
   `survey::svycontrast()`, which does not apply multiple testing corrections
   by default — the difference is intentional for pairwise comparisons where
   k(k−1)/2 tests make unadjusted p-values misleading.
4. CI bounds are NOT recalculated after adjustment. Confidence intervals
   reflect the specified `conf_level` and are not affected by p-value
   adjustment. P-value adjustment controls Type I error for hypothesis tests;
   interval estimation is separate. For simultaneous CIs, users can use the
   `multcomp` package post-hoc.
5. When `pval_adj` is `"none"`, `stats::p.adjust()` is still called (it
   returns unadjusted p-values), and `.meta$pval_adj` records `"none"`.

### 3.11 Rounding

When `decimals` is non-NULL, round these columns via `.apply_decimals()`:
`estimate`, `mean_a`, `mean_b`, `se`, `ci_low`, `ci_high`, `p_value`.

### 3.12 `na.rm` Translation

Identical to `get_diffs()` Section 3.13.

### 3.13 Domain Estimation

Domain estimation is handled upstream via `surveytidy::filter()`, which sets a
`..surveycore_domain..` column on the design. When this column is present, cell
counts (`n_a`, `n_b`) include only rows where `..surveycore_domain.. == TRUE`.
When both `group` and domain filtering are active, pairwise contrasts are
computed within each group stratum, and all cell counts (`n_a`, `n_b`) are
restricted to rows matching both the domain mask and the group membership.

### 3.14 `@groups` Integration

Identical to `get_diffs()` Section 3.15.

---

## IV. `.meta` Contract

The `.meta` attribute on `survey_pairwise` is a named list with these keys:

| Key | Type | Description |
|---|---|---|
| `design_type` | character(1) | `"taylor"`, `"replicate"`, `"twophase"`, or `"calibrated"` |
| `conf_level` | numeric(1) | Confidence level used |
| `call` | language | Matched call to `get_pairwise()` |
| `n_respondents` | integer(1) | `nrow(design@data)` — total rows before `na.action` |
| `group` | named list | One entry per group variable; `list()` when no groups |
| `x` | named list | One entry for the DV |
| `treats` | named list | Treatment variable metadata. Built by `.extract_var_meta()` with appended `name = treats_name`. No `ref_level` (unlike `get_diffs()`). |
| `covariates` | character or `NULL` | Covariate terms, or `NULL` |
| `family` | character(1) | GLM family name |
| `link` | character(1) | Link function name |
| `pval_adj` | character(1) | P-value adjustment method (never `NULL`; default `"holm"`) |
| `estimate_method` | character(1) | `"contrast_matrix"` (clean path) or `"avg_comparisons"` (marginaleffects path) |
| `estimate_scale` | character(1) | `"coefficient"` or `"ame"` |

**Accessing:** `meta(result)` — the `meta()` generic from `analysis-meta.R`.

---

## V. Output Contract

### 5.1 S3 Class Hierarchy

```r
class(result) == c("survey_pairwise", "survey_result", "tbl_df", "tbl", "data.frame")
```

### 5.2 Output Columns

Columns appear in this order. Optional columns are omitted when not requested.

| Column | Type | Presence | Description |
|---|---|---|---|
| `{group_cols}` | factor/character | When `group` is active | One column per group variable. |
| `level_a` | factor/character | Always | First level in the pair. Type per `label_values`. |
| `level_b` | factor/character | Always | Second level in the pair. Type per `label_values`. |
| `estimate` | numeric | Always | Pairwise difference: mean(level_a) − mean(level_b). |
| `mean_a` | numeric | When `show_means = TRUE`, subject to link-scale suppression | Weighted mean for `level_a`. |
| `mean_b` | numeric | When `show_means = TRUE`, subject to link-scale suppression | Weighted mean for `level_b`. |
| `n_a` | integer | Always | Unweighted in-domain count for `level_a` (within group if applicable). |
| `n_b` | integer | Always | Unweighted in-domain count for `level_b` (within group if applicable). |
| `n_a_weighted` | numeric | When `n_weighted = TRUE` | Sum of weights for `level_a`. |
| `n_b_weighted` | numeric | When `n_weighted = TRUE` | Sum of weights for `level_b`. |
| `se` | numeric | When `variance` includes `"se"` | Standard error of the contrast. |
| `ci_low` | numeric | When `variance` includes `"ci"` | Lower confidence bound. |
| `ci_high` | numeric | When `variance` includes `"ci"` | Upper confidence bound. |
| `p_value` | numeric | Always | P-value (adjusted by `pval_adj`). |
| `stars` | character | Always | Significance stars. |

### 5.3 Row Order

1. Pairs ordered by factor level: all pairs involving the first level first
   (vs 2nd, vs 3rd, ...), then pairs involving the second level (vs 3rd, ...),
   etc. This matches `utils::combn()` output order.
2. When `group` is active: rows grouped by group combination, with pair
   ordering within each group.

### 5.4 Column-Level Labels

| Column | `label` value |
|---|---|
| `{group_cols}` | Variable label from metadata, or variable name if no label |
| `level_a` | `"{treats_label} (A)"` where `treats_label` is the variable label or name |
| `level_b` | `"{treats_label} (B)"` |
| `estimate` | `"Difference (A − B)"` |
| `mean_a` | `"Mean (A)"` |
| `mean_b` | `"Mean (B)"` |
| `n_a` | `"N (A)"` |
| `n_b` | `"N (B)"` |
| `n_a_weighted` | `"N weighted (A)"` |
| `n_b_weighted` | `"N weighted (B)"` |
| `se` | `"Std. Error"` |
| `ci_low` | `"Low CI"` |
| `ci_high` | `"High CI"` |
| `p_value` | `"P-Value"` |
| `stars` | `""` |

---

## VI. Error & Warning Conditions

### 6.1 Errors

| Error class | Trigger | Message template |
|---|---|---|
| `surveycore_error_unsupported_class` | `design` is not a `survey_base` subclass | Reuse `.check_unsupported_class(design, "get_pairwise")` |
| `surveycore_error_non_numeric_variable` | `x` column is not numeric | Reuse from `get_diffs()` |
| `surveycore_error_treats_single` | `treats` resolves to != 1 column | Reuse from `get_diffs()` |
| `surveycore_error_wrong_variable_count` | `x` resolves to != 1 column | Reuse from `get_diffs()` |
| `surveycore_error_treats_one_level` | `treats` has only 1 unique value after NA removal | Reuse from `get_diffs()` |
| `surveycore_error_invalid_pval_adj` | `pval_adj` not a valid method | Reuse from `get_diffs()` |
| `surveycore_error_invalid_conf_level` | `conf_level` not in (0, 1) | Reuse existing |
| `surveycore_error_covariates_not_character` | `covariates` is not a character vector | Reuse from `get_diffs()` |
| `surveycore_error_empty_treatment_cell` | Any treatment level has zero in-domain observations after NA removal | `"Treatment level {.val {level}} has 0 observations{domain_msg}."` |

Errors from `survey_glm()` propagate unchanged.

### 6.2 Warnings

| Warning class | Trigger | Message template |
|---|---|---|
| `surveycore_warning_treats_coerced` | `treats` column is not a factor | Reuse from `get_diffs()` |
| `surveycore_warning_small_cell` | Any treatment level has fewer than `min_cell_n` unweighted observations | Reuse from `get_diffs()` |

Warnings from `survey_glm()` propagate unchanged.

### 6.3 New Error/Warning Classes

One new error class is introduced:

- `surveycore_error_empty_treatment_cell` — fires when any treatment level has
  zero in-domain observations after NA removal. This catches degenerate domains
  before `survey_glm()` is called, providing a clearer error than the model
  matrix singularity that would otherwise result. This class should also be
  added to `get_diffs()` as a shared gap fix.

---

## VII. Execution Flow

### 7.1 Step-by-Step

```
Step 1:  Validate shared args (.validate_shared_args with
         valid_variance = c("se", "ci"))
Step 2:  Validate design class (.check_unsupported_class)
Step 3:  Resolve x, treats, group via tidy-select
Step 4:  Validate x is numeric, treats has >= 2 levels
Step 4a: Validate covariates is character or NULL;
         validate pval_adj is in stats::p.adjust.methods
Step 5:  Handle na.rm → na.action translation
Step 6:  Coerce treats to factor, force treatment contrasts
Step 6a: Check for empty treatment cells: if any treatment level
         has zero in-domain observations after NA removal, raise
         surveycore_error_empty_treatment_cell
Step 7:  Build formula from treats + group + covariates
Step 8:  Call survey_glm(design, formula, na.action, ...)
Step 9:  Determine estimation path (clean vs marginaleffects)
Step 10: Build pair labels via .build_pair_labels()
Step 11: Extract pairwise contrasts via chosen path
Step 12: Extract means if show_means = TRUE (unless suppressed)
Step 13: Compute n_a, n_b per pair (+ group), domain-aware
Step 14: Apply pval_adj (default "holm")
Step 15: Apply link-scale suppression: omit mean_a, mean_b if applicable
Step 16: Assign stars
Step 17: Assemble output tibble in column order
Step 17a: Apply label_values via .apply_group_labels() to
          level_a, level_b, and group columns
Step 18: Apply decimals rounding if requested
Step 19: Apply name_style via .apply_name_style()
Step 20: Attach .meta via .make_result_tibble()
Step 21: Attach column-level labels (Section 5.4)
Step 22: Set S3 class and return
```

### 7.2 Estimation Path Decision

```r
family_name <- fit@family$family
has_covariates <- !is.null(covariates)
has_group <- length(group_names) > 0
scale <- match.arg(scale)

use_marginaleffects <- has_covariates ||
  has_group ||
  (family_name != "gaussian" && scale == "ame")
```

Identical to `get_diffs()` Section 7.2.

---

## VIII. Print Method

`survey_pairwise` inherits from `survey_result`. `print.survey_pairwise()`
overrides `print.survey_result()` with custom header lines.

**Registration:** `registerS3method("print", "survey_pairwise",
print.survey_pairwise)` in `.onLoad()` in `zzz.R`.

**Exact console output:**

```
# A survey_pairwise result
# Design: Taylor series | Family: gaussian (identity)
# DV: agree_trope | Treatment: message_arm (4 levels, 6 pairs)
# Method: contrast_matrix | Adjustment: holm
# A tibble: 6 x 10
  level_a   level_b   estimate mean_a mean_b  n_a  n_b ci_low ci_high p_value stars
  <fct>     <fct>        <dbl>  <dbl>  <dbl> <int> <int>  <dbl>   <dbl>   <dbl> <chr>
1 Control   Message A    -0.082 0.401 0.483   752   748  -0.122  -0.042   0.001 "**"
2 Control   Message B    -0.103 0.401 0.504   752   751  -0.143  -0.063   0.000 "***"
3 Control   Message C    -0.045 0.401 0.446   752   749  -0.085  -0.005   0.056 ""
4 Message A Message B    -0.021 0.483 0.504   748   751  -0.061   0.019   0.528 ""
5 Message A Message C     0.037 0.483 0.446   748   749  -0.003   0.077   0.142 ""
6 Message B Message C     0.058 0.504 0.446   751   749   0.018   0.098   0.012 "*"
```

The 4 header lines:
- Line 1: Result class name
- Line 2: Design type + family + link
- Line 3: DV name + treatment variable + level count + pair count
- Line 4: Estimation method + adjustment method

---

## IX. Testing Requirements

### 9.1 Test Categories

Per `testing-standards.md`: happy path + error paths + edge cases.

#### Happy Path Tests (`test-analysis-pairwise.R`)

| Test | Description |
|---|---|
| Bivariate gaussian, no group | Basic `DV ~ treats` with 3+ levels; verify k(k-1)/2 rows |
| Bivariate gaussian, with group | Pairwise within each group stratum |
| With covariates, no group | Forces marginaleffects path |
| With covariates and group | Full interaction model |
| Non-gaussian family (quasibinomial) | Binary DV with `family = quasibinomial()` |
| `show_means = FALSE` | No `mean_a` / `mean_b` columns |
| `pval_adj = "bonferroni"` | Bonferroni adjustment; verify adjusted p-values |
| `pval_adj = "none"` | No adjustment; raw p-values |
| `variance = "se"` | SE column present, no CI columns |
| `variance = NULL` | No SE or CI columns |
| `decimals` | Numeric columns rounded correctly |
| All 4 design classes | One test per design class |
| Domain estimation | `filter(design, condition) |> get_pairwise(...)` |
| Print snapshot | `expect_snapshot(print(result))` captures all header lines |
| `label_values = TRUE` | `level_a`, `level_b`, and group columns display value labels |
| `label_values = FALSE` | Raw codes |
| `name_style = "broom"` | Columns renamed |
| `n_weighted = TRUE` | `n_a_weighted` and `n_b_weighted` columns present |
| `min_cell_n` custom | Warning fires at the right threshold |

#### Error Path Tests (`test-analysis-pairwise.R`)

One `test_that()` block per error class in Section VI, using the dual pattern.

#### Edge Case Tests (`test-analysis-pairwise.R`)

| Test | Description |
|---|---|
| `treats` with exactly 2 levels | 1 pair only; simplest case |
| `treats` with many levels (6+) | Verify 15 rows for 6 levels |
| `treats` as character (not factor) | Coerced to factor with warning |
| Single observation in one treatment level | `surveycore_warning_small_cell` fires |
| `na.rm = FALSE` with NAs present | Error propagated from `survey_glm()` |
| Gaussian `scale = "ame"` == `scale = "link"` | Both scales produce identical results |
| `scale = "link"` + non-gaussian | `mean_a` and `mean_b` suppressed |
| Clean path vs marginaleffects equivalence | For bivariate gaussian, both paths produce identical results (tolerance 1e-8) |

#### Numerical Tests (`test-analysis-pairwise-numerical.R`)

| Test | Description |
|---|---|
| Bivariate OLS vs manual computation | Clean path contrasts match hand-computed pairwise diffs of weighted means |
| Pairwise vs `get_diffs()` consistency | For each pair (A, B), `get_pairwise()` estimate matches `get_diffs(ref_level = "B")` estimate for level A |
| Multivariate OLS vs `survey::svyglm` + `marginaleffects` | `avg_comparisons(comparison = "pairwise")` matches direct pipeline |
| Logistic AME vs reference | Binary DV pairwise AMEs match reference pipeline |
| P-value adjustment correctness | `stats::p.adjust(raw_pvals, "holm")` matches output p-values |

**Tolerances:** Same as `get_diffs()`: 1e-10 for point estimates, 1e-8 for
SEs, 1e-6 for CI bounds.

### 9.2 `.meta` Tests

Every happy path test must verify:
- `meta(result)$estimate_method` matches expected path
- `meta(result)$treats$name` matches treatment variable name
- `meta(result)$family` matches expected family
- `meta(result)$pval_adj` records the adjustment method

### 9.3 Column Label Tests

At least one test verifies all output columns have `label` attributes set.

---

## X. Quality Gates

All gates must pass before `get_pairwise()` is merged:

- [ ] `devtools::check()` returns 0 errors, 0 warnings, <= 2 pre-approved notes
- [ ] 98%+ line coverage on `analysis-pairwise.R` and `analysis-pairwise-helpers.R`
- [ ] All error classes from Section VI have corresponding tests
- [ ] All 4 design classes have at least one happy-path test
- [ ] Numerical tests pass against reference implementation
- [ ] Clean path vs marginaleffects equivalence verified
- [ ] Pairwise vs `get_diffs()` consistency verified
- [ ] `.meta` contract fully tested
- [ ] Column labels tested
- [ ] `plans/error-messages.md` updated if any new error/warning classes added
- [ ] `PAIRWISE_META_KEYS` added to `analysis-helpers.R`

---

## XI. Usage Examples

### 11.1 Basic Pairwise Comparisons

```r
d <- as_survey(msg_test_data, ids = resp_id, weights = rake_wt)

# All pairwise comparisons between message arms
get_pairwise(d, agree_trope, message_arm)
```

### 11.2 With Covariates

```r
get_pairwise(d, agree_trope, message_arm,
             covariates = c("age", "gender", "education"))
```

### 11.3 Subgroup Analysis

```r
get_pairwise(d, agree_trope, message_arm,
             group = age_group)
```

### 11.4 Logistic Path

```r
get_pairwise(d, agree_trope, message_arm,
             family = quasibinomial())
```

### 11.5 Bonferroni Adjustment

```r
get_pairwise(d, agree_trope, message_arm,
             pval_adj = "bonferroni")
```

### 11.6 Combined with get_diffs()

```r
# Dunnett-style: all vs control
get_diffs(d, agree_trope, message_arm, ref_level = "Control")

# Tukey-style: all pairwise
get_pairwise(d, agree_trope, message_arm)
```

### 11.7 Full Reporting Table

```r
library(gt)

get_pairwise(d, agree_trope, message_arm,
             variance = c("se", "ci"),
             decimals = 3) |>
  gt::gt()
# Column headers auto-populated from label attributes
```
