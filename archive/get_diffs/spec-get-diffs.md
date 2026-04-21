# surveycore — `get_diffs()`: Treatment Effect Estimation

**Version:** 1.5
**Date:** March 2026
**Status:** Approved — Stage 4 complete (methodology-locked, code-reviewed, Pass 3 resolved)

---

## Document Purpose

This document is the authoritative specification for the `get_diffs()` function
in the surveycore package. It defines the API contract, estimation paths, output
structure, error conditions, and testing requirements. Implementation must follow
these rules exactly. Where a rule is already defined in `code-style.md`,
`r-package-conventions.md`, or `surveycore-conventions.md`, this document
references those rules rather than restating them.

**Reference documents:**
- `SOPs/treatment_effects.md` — Standard Operating Procedures for message
  testing analysis. `get_diffs()` is the primary implementation of this SOP.
- `archive/phase-2/spec-phase-2.md` — Phase 2 spec; `get_diffs()` builds on
  `survey_glm()`, `clean()`, and the marginaleffects extension interface.

---

## I. Scope

### What This Delivers

| Component | Description |
|---|---|
| `get_diffs()` | Exported function: treatment effect estimation via survey-weighted regression |
| `survey_diffs` S3 class | Result tibble with column-level labels and `.meta` |
| `print.survey_diffs()` | Custom print method: 4 header lines + tibble body (overrides `print.survey_result()`) |
| `.stars_pval()` | Internal helper: significance star assignment |
| `DIFFS_META_KEYS` | Constant: function-specific meta keys for `.make_result_tibble()` validation |

### What This Does NOT Deliver

- **Pairwise (Tukey-style) comparisons** — all-vs-all treatment comparisons are
  a separate function (`get_pairwise()` or similar). `get_diffs()` is
  Dunnett-style: all treatment levels compared to one reference level.
- **Combined bivariate + multivariate output** — future feature. Currently the
  analyst calls `get_diffs()` twice (once without covariates, once with).
- **Multiple DVs in one call** — one DV per call. P-value adjustment across DVs
  is the analyst's responsibility.
- **Auto-detection of logistic threshold** — the analyst controls the family via
  `...` (passed to `survey_glm()`). `get_diffs()` does not inspect the
  control-group rate and switch families automatically.
- **Column-level labels on other `get_*()` functions** — backporting column
  labels to `get_means()`, `get_freqs()`, etc. is a separate PR.

### Supported Design Classes

All four surveycore design classes are supported. `get_diffs()` delegates to
`survey_glm()`, which handles variance estimation for each design type (see
Phase 2 spec §I). SRS designs are represented as `survey_taylor` objects
(created via `as_survey()` with no `ids` or `strata`).

| Class | Supported |
|---|---|
| `survey_taylor` | Yes |
| `survey_replicate` | Yes |
| `survey_twophase` | Yes |
| `survey_nonprob` | Yes |

### Prerequisites

| Prerequisite | What `get_diffs()` Needs |
|---|---|
| Phase 2 complete | `survey_glm()`, `clean()`, `survey_glm_fit` S7 class |
| Phase 2 marginaleffects extension | `avg_slopes()` and `avg_predictions()` dispatch on `survey_glm_fit` |
| `marginaleffects` in Imports | Required for multivariate, non-gaussian, and grouped paths |

---

## II. Architecture

### 2.1 File Organization

```
R/
├── analysis-diffs.R              # get_diffs() exported function + inline estimation logic
├── analysis-diffs-helpers.R      # .stars_pval()
├── analysis-helpers.R            # DIFFS_META_KEYS (added alongside existing *_META_KEYS)

tests/testthat/
├── test-analysis-diffs.R                  # get_diffs() happy paths + error paths + edge cases
├── test-analysis-diffs-numerical.R        # Oracle tests vs tidysurvey/manual computation
└── test-analysis-diffs-marginaleffects.R  # avg_slopes/avg_predictions path tests
                                           #   (gated with skip_if_not_installed)
```

### 2.2 Internal Helpers

All internal helpers are not exported and prefixed with `.`, per `code-style.md §4`.

#### `.stars_pval(p)`

Assigns significance stars to a numeric vector of p-values.

```r
.stars_pval <- function(p) {
  # Cutpoints: *** < 0.001, ** < 0.01, * < 0.05, . < 0.1, "" otherwise
  # NA p-values → ""
  # Returns: character vector same length as p
}
```

#### Meta construction

`get_diffs()` builds `meta_args` inline (matching the Phase 1 pattern in
`get_means()`, `get_freqs()`, etc.) and passes them to `.build_meta()` via
`.make_result_tibble()`. No separate `.build_diffs_meta()` helper is needed.
See Section IV for the full `.meta` contract.

#### `DIFFS_META_KEYS`

Defined in `analysis-helpers.R` alongside the other `*_META_KEYS` constants.
Contains the function-specific keys required in `meta_args`. Note that
`conf_level` and `call` are **not** included here — they are common fields
always present in `meta_args` (passed by the caller), not function-specific
keys. The `*_META_KEYS` constants list only the keys that
`.make_result_tibble()` validates as function-specific requirements.
`.build_meta()` auto-injects `design_type` and `n_respondents`.

```r
DIFFS_META_KEYS <- c(
  "group", "x", "treats", "covariates", "family", "link",
  "pval_adj", "estimate_method", "mean_method", "estimate_scale"
)
```

Passed to `.make_result_tibble()` for validation via
`stopifnot(all(required_meta_keys %in% names(meta_args)))`.

#### Estimation path logic

The clean path (Section 3.8) and marginaleffects path (Section 3.9) are
implemented inline in `get_diffs()`, not extracted into separate helpers.
The logic is specific to `get_diffs()` and has no second call site.

#### Column-level labels

Column-level `label` attributes (Section 5.5) are attached inline in
`get_diffs()` after assembly. This will be extracted into a shared helper
when column labels are backported to the other `get_*()` functions (separate
PR, listed in "What This Does NOT Deliver").

---

## III. `get_diffs()` — Function Specification

### 3.1 Signature

```r
get_diffs <- function(
  design,
  x,
  treats,
  group       = NULL,
  covariates  = NULL,
  ref_level   = NULL,
  pval_adj    = NULL,
  show_means  = TRUE,
  show_pct_change = FALSE,
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

> **When `scale = "link"` and family is non-gaussian**, the `mean` and
> `pct_change` columns are suppressed (omitted from output entirely).
> Link-scale means (e.g., predicted log-odds) do not serve the contextual
> purpose of the `mean` column, and link-scale ratios are not meaningful.
> The reference row is still included with `estimate = 0`. When `show_means
> = TRUE`, the reference row appears without a `mean` column. This rule
> applies uniformly across all estimation paths.

All subsequent references to suppression of `mean` or `pct_change` cite
this section rather than restating the rule.

### 3.3 Argument Table

| Argument | Type | Default | Description |
|---|---|---|---|
| `design` | `survey_base` subclass | (required) | Survey design object from `as_survey()`, `as_survey_replicate()`, etc. |
| `x` | tidy-select (single) | (required) | Dependent variable. Must resolve to exactly one numeric column (0/1 binary or continuous). |
| `treats` | tidy-select (single) | (required) | Treatment variable. Must resolve to exactly one column. Coerced to factor if not already. |
| `group` | tidy-select | `NULL` | Subgroup variable(s) for interaction analysis. When provided, `get_diffs()` fits `x ~ treats * group + covariates` and reports effects by group. Combined with `@groups` if set. |
| `covariates` | character vector | `NULL` | Additional model terms as strings. Supports interactions (`"age * gender"`), polynomials (`"poly(edu, 2)"`), and transformations (`"log(income)"`). When provided, forces the `avg_slopes()` / `avg_predictions()` estimation path. |
| `ref_level` | character(1) | `NULL` | Reference level of `treats` for comparisons. If `NULL`, defaults to first factor level. Must match an existing level. |
| `pval_adj` | character(1) | `NULL` | P-value adjustment method. Passed to `stats::p.adjust()`. Options: `"holm"`, `"hochberg"`, `"hommel"`, `"bonferroni"`, `"BH"`, `"BY"`, `"fdr"`, `"none"`. `NULL` = no adjustment. |
| `show_means` | logical | `TRUE` | If `TRUE`, includes a `mean` column and a reference row with `estimate = 0` and `mean = reference_mean`. Subject to link-scale suppression (Section 3.2). |
| `show_pct_change` | logical | `FALSE` | If `TRUE`, includes a `pct_change` column: `estimate / reference_mean`. Subject to link-scale suppression (Section 3.2). |
| `variance` | character | `"ci"` | Which uncertainty columns to include. One or more of: `"se"`, `"ci"`. `NULL` = no uncertainty columns. |
| `conf_level` | numeric(1) | `0.95` | Confidence level for intervals. Must be in (0, 1). |
| `min_cell_n` | integer(1) | `30L` | Minimum unweighted cell size before `surveycore_warning_small_cell` fires. |
| `n_weighted` | logical | `FALSE` | If `TRUE`, includes an `n_weighted` column: sum of weights for each treatment level (within group if applicable). |
| `decimals` | integer(1) or `NULL` | `NULL` | If non-NULL, rounds all numeric output columns. |
| `scale` | character(1) | `"ame"` | Scale for treatment effect estimates. `"ame"` (default): average marginal effects on the response scale (e.g., probability differences for logistic). `"link"`: coefficients on the link scale (e.g., log-odds for logistic). For Gaussian/identity models, both scales are identical. See Section 3.9 for rationale. |
| `na.rm` | logical | `TRUE` | If `TRUE`, drops rows with NA in `x`, `treats`, or `group` columns before fitting. Translated to `na.action = stats::na.omit` when calling `survey_glm()`. If `FALSE`, translated to `na.action = stats::na.fail`. |
| `label_values` | logical | `TRUE` | If `TRUE` (default), the `treats` and `group` columns display value labels from metadata (e.g., "Control", "Message A") instead of raw codes (e.g., 1, 2). When `FALSE`, raw values are used. Applied post-assembly via `.apply_group_labels()` from `analysis-helpers.R`, treating `treats` identically to group columns for labeling purposes. Output type is `factor` when labels are applied, `character` otherwise (matching Phase 1 group column behavior). |
| `name_style` | character(1) | `"surveycore"` | Column naming convention. `"surveycore"` (default) or `"broom"`. When `"broom"`, columns are renamed via `.apply_name_style(result, "broom", exclude = "mean")`. The `mean` column is excluded because `estimate` already holds the point estimate; renaming both to `"estimate"` would create duplicate columns. See `.apply_name_style()` changes below. |
| `...` | | | Passed to `survey_glm()`. Common uses: `family = quasibinomial()`, `control = list(maxit = 50)`. |

**`.apply_name_style()` change:** Add an `exclude` parameter (default `NULL`)
to `.apply_name_style()` in `analysis-helpers.R`. When non-NULL, columns in
`exclude` are removed from `to_rename` before applying the broom map. This is
backward-compatible — all existing `get_*()` call sites pass only 2 arguments
and are unaffected. `get_diffs()` passes `exclude = "mean"`.

### 3.4 Argument Order Rationale

Per `code-style.md §4`: `design` (data, first) → `x`, `treats` (required NSE) →
`group` (optional NSE) → `covariates`, `ref_level`, `pval_adj` (optional scalar,
configuration) → `show_means`, `show_pct_change`, `variance`, `conf_level`,
`decimals`, `na.rm` (optional scalar, formatting/control) → `...`.

### 3.5 Estimation Paths

`get_diffs()` determines the estimation path based on three conditions:

| Condition | Path | Estimates from | Means from |
|---|---|---|---|
| No covariates + `gaussian()` family + no group | **Clean path** | `clean()` coefficients | Intercept from `clean()` |
| Non-gaussian family (any config) | **Marginaleffects path** | `avg_slopes()` | `avg_predictions()` |
| Covariates present (any family) | **Marginaleffects path** | `avg_slopes()` | `avg_predictions()` |
| Group present (any family, any covariates) | **Marginaleffects path** | `avg_slopes(by = group)` | `avg_predictions(by = c(treats, group))` |

**Family detection:** After calling `survey_glm()`, inspect `fit@family$family`.
If it equals `"gaussian"`, the family is gaussian. All other values (including
`"binomial"`, `"quasibinomial"`, `"poisson"`, `"Gamma"`, etc.) trigger the
marginaleffects path.

**Path recorded in `.meta`:** `.meta$estimate_method` and `.meta$mean_method`
record which path was used (see Section IV).

### 3.6 Formula Construction

`get_diffs()` constructs a formula from its arguments and passes it to
`survey_glm()`. The user never writes a formula.

| Configuration | Formula built |
|---|---|
| No covariates, no group | `x ~ treats` |
| Covariates, no group | `x ~ treats + cov1 + cov2 + ...` |
| No covariates, with group | `x ~ treats * group` |
| Covariates, with group | `x ~ treats * group + cov1 + cov2 + ...` |

**Implementation:**

```r
# Build the RHS terms
rhs_terms <- treats_name
if (length(group_names) > 0) {
  # Interaction: treats * group1 * group2 ...
  rhs_terms <- paste(c(treats_name, group_names), collapse = " * ")
}
if (!is.null(covariates)) {
  rhs_terms <- paste(c(rhs_terms, covariates), collapse = " + ")
}
formula <- stats::reformulate(rhs_terms, response = x_name)
```

Note: when `covariates` contains interaction terms (e.g., `"age * gender"`),
`reformulate()` inserts them as formula terms correctly because R parses `*`
inside formula expressions.

**Interaction model semantics:** When `group` is provided, the formula
includes `treats:group` interaction terms. This allows the treatment effect
to differ by subgroup:

```
x ~ treats + group + treats:group + covariates
dY/d(treats) = beta_treats + beta_interact * I(group = g)
```

`marginaleffects::avg_slopes(by = group)` correctly incorporates the
interaction when computing group-specific average marginal effects. Note that
hypothesis testing on the interaction coefficient itself (i.e., whether the
treatment effect significantly differs across groups) requires inspecting
`summary(fit)` directly — `get_diffs()` reports the treatment effects within
each group, not the interaction contrast.

### 3.7 Reference Level Handling

1. Resolve `treats` to a character name via `rlang::as_name(rlang::ensym(treats))`.
2. Coerce the treats column to factor if not already (using `as.factor()`; do NOT
   drop unused levels at this stage — the user may have intentionally defined levels).
   **Handling of unused levels:** Factor levels with zero observations after
   `na.action` are silently omitted from the output. They produce no rows in the
   result because `glm()` excludes them from the model matrix.
3. If `ref_level` is `NULL`, set it to `levels(data[[treats_name]])[1]`.
4. If `ref_level` is non-NULL, validate it exists in `levels(data[[treats_name]])`.
   If not found, error with `surveycore_error_ref_level_not_found`.
5. **Force treatment contrasts:** After coercion and releveling, explicitly set
   `contrasts(design@data[[treats_name]]) <- stats::contr.treatment(nlevels(design@data[[treats_name]]))`.
   This ensures the clean path's intercept-as-reference-mean interpretation is
   always correct, regardless of global contrast settings (`options(contrasts = ...)`
   or per-factor `contrasts<-()`). Without this, non-treatment contrasts (Helmert,
   sum, etc.) silently produce wrong reference means and treatment effects.
6. Use `stats::relevel()` to set the reference level before fitting.

### 3.8 Estimation: Clean Path (Bivariate + Gaussian + No Group)

This path avoids the `marginaleffects` dependency for the simplest case.

1. Fit: `fit <- survey_glm(design, formula, na.action = na_action, ...)`
2. Tidy: `tidy_result <- clean(fit, conf_level = conf_level, include_reference = TRUE, n = TRUE)`
   The `clean()` function returns `std_error` and CI bounds computed from
   `fit@vcov`, which is the design-based Binder sandwich variance (per Phase 2
   spec Section VIII). Variance computation is design-class-specific — Taylor,
   replicate, two-phase, SRS, and nonprob each use their own sandwich formula.
3. Extract reference row (intercept): the row where `term == "(Intercept)"`.
   **Defensive validation:** If zero or multiple rows match
   `term == "(Intercept)"`, error with
   `surveycore_error_reference_row_not_found`. This guards against degenerate
   fits or unexpected `clean()` output changes.
   - `reference_mean <- tidy_result$estimate` for this row (the intercept IS the
     reference group mean for a factor-only model).

**Coefficient = AME equivalence:** This clean path produces treatment effects
identical to the marginaleffects path (AMEs) **only when**: (a) family is
Gaussian with identity link, (b) the model has a single factor predictor (no
covariates), and (c) no interactions. The routing logic (Section VII, Step 10)
guarantees these conditions. If the routing conditions change, the clean path
must be re-validated.
4. Extract treatment rows: all rows where `reference_row == FALSE` and
   `term != "(Intercept)"`. The reference level row (`reference_row == TRUE`,
   `estimate = NA`) is discarded — it is not used in the output.
   - `estimate` = coefficient (difference from reference mean).
   - `mean` = `reference_mean + estimate` (the treatment group mean).
   - `se` = `tidy_result$std_error`.
   - `ci_low` / `ci_high` = `tidy_result$conf_low` / `tidy_result$conf_high`.
   - `p_value` = `tidy_result$p_value`.
   - `n` = `tidy_result$n_obs`.
5. Build the reference row (when `show_means = TRUE`):
   - `{treats_name}` = ref_level
   - `estimate` = 0
   - `mean` = reference_mean
   - `n` = unweighted count of reference-level observations
   - `se`, `ci_low`, `ci_high`, `p_value` = NA
   - `pct_change` = NA
   - `stars` = ""
6. Bind reference row (first) + treatment rows.

### 3.9 Estimation: Marginaleffects Path

Used when covariates are present, family is non-gaussian, or group is active.

**Methodological Note — Variance Chain:** The marginaleffects path computes
SEs via the delta method applied to the design-based sandwich variance:

1. `marginaleffects::avg_slopes()` calls `vcov()` on the `survey_glm_fit`
   object, which returns the Binder sandwich variance registered via the
   Phase 2 `get_vcov()` extension method.
2. For non-gaussian families, the numerical Jacobian of the inverse link
   function converts from linear predictor scale to response scale.
3. The delta method combines the Jacobian with the design-based `vcov` to
   produce SEs for the average marginal effect.

This hybrid — design-based variance estimation (accounting for clustering,
stratification, and weights) combined with model-based Jacobian (capturing
the nonlinear link function) — is the standard approach for survey-weighted
marginal effects (Binder 1983, JASA 78(382):626-631).

**AME as default scale (deviation from survey package):** For non-gaussian
families, `get_diffs()` defaults to reporting average marginal effects (AMEs)
on the response scale (e.g., probability differences for logistic), not
coefficients on the link scale (e.g., log-odds). This departs from
`survey::svyglm()` convention and is intentional: AMEs are more interpretable
for treatment effect reporting, particularly for non-technical audiences
(Gomila 2021, J. Exp. Psych: General 150(3):700-709). Users who need
link-scale coefficients can set `scale = "link"`. Document in roxygen
`@details`: "By default, non-gaussian models report average marginal effects
on the response scale. Set `scale = 'link'` for coefficients on the link
scale (e.g., log-odds for logistic regression)."

#### 3.9.1 Common Parameters for All Marginaleffects Calls

Three parameters are shared across all `avg_slopes()` and `avg_predictions()`
calls in this path. They are defined once here; code blocks below use the
variable names without re-explaining.

```r
# Residual df: design-based, clamped to >= 1
p <- length(coef(fit))
res_df <- max(1, fit@degf - (p - 1L))

# Scale-aware type: "link" when user requests link scale, "response" otherwise
me_type <- if (scale == "link") "link" else "response"
```

- **`df = res_df`** — passes design-based residual degrees of freedom so
  marginaleffects uses the t-distribution (not Z) for p-values and CIs,
  matching the clean path exactly. Uses `fit@degf` (authoritative post-fit
  source). The `max(1, ...)` clamping prevents `NaN` from `qt()` when df
  would be non-positive (matching `.glm_confint()` and `glm-clean.R`).
  Without this, marginaleffects defaults to Z-distribution (infinite df),
  producing narrower CIs and smaller p-values. All df values are numeric
  (double), never integer — replicate designs return non-integer `degf`
  (e.g., 99.0 for 100 BRR replicates). Document in roxygen `@details`:
  "All p-values and confidence intervals use the t-distribution with
  design-based residual degrees of freedom, regardless of estimation path."
- **`type = me_type`** — `"link"` when `scale = "link"`, `"response"`
  otherwise. Without this, `avg_slopes()` defaults to `type = "response"`,
  returning response-scale AMEs even when the user requested link-scale
  coefficients.
- **`wts = TRUE`** — enables survey-weight-aware averaging within
  marginaleffects. Required for correct population-weighted marginal effects.

#### 3.9.2 Estimates (Treatment Effects)

**Without group:**
```r
slopes <- marginaleffects::avg_slopes(
  fit, variables = treats_name, type = me_type, wts = TRUE, df = res_df
)
```

**With group:**
```r
slopes <- marginaleffects::avg_slopes(
  fit, variables = treats_name, by = group_names,
  type = me_type, wts = TRUE, df = res_df
)
```

Returns one row per non-reference treatment level (× group when grouped).
Columns used: `estimate`, `std.error`, `p.value`, `conf.low`, `conf.high`.

#### 3.9.3 Means (Absolute Levels)

When link-scale suppression applies (Section 3.2), skip `avg_predictions()`
entirely.

**Without group:**
```r
preds <- marginaleffects::avg_predictions(
  fit, by = treats_name, type = me_type, wts = TRUE, df = res_df
)
```

**With group:**
```r
preds <- marginaleffects::avg_predictions(
  fit, by = c(treats_name, group_names),
  type = me_type, wts = TRUE, df = res_df
)
```

Returns one row per treatment level (× group). The `estimate` column is the
weighted average predicted outcome for that level.

#### 3.9.4 Assembly

1. Left-join `slopes` and `preds` on treatment level (+ group if applicable).
2. For the reference level: `preds` has a row but `slopes` does not.
   When `show_means = TRUE`, include the reference row with `estimate = 0`,
   `mean = preds$estimate`, and `p_value = NA`.
3. Map marginaleffects column names to `survey_diffs` output names:
   - `slopes$estimate` → `estimate`
   - `slopes$std.error` → `se`
   - `slopes$conf.low` → `ci_low`
   - `slopes$conf.high` → `ci_high`
   - `slopes$p.value` → `p_value`
   - `preds$estimate` → `mean`
4. Compute `n` per treatment level (+ group) — see Section 5.2 for the
   domain-aware counting rule.

### 3.10 P-Value Adjustment

Applied after estimation, before star assignment.

1. Identify comparison rows (exclude reference row where `estimate == 0`).
2. **When `group` is active:** Apply `stats::p.adjust(p_values, method = pval_adj)`
   separately within each group stratum. The multiple testing correction
   applies to comparisons against the reference within a group, not across
   groups. This is standard for exploratory subgroup analysis in survey
   research, where each subgroup represents a separate research question
   (Alosh et al. 2014, Statistics in Medicine). Document in roxygen
   `@details`: "When `group` is active, p-value adjustment is applied
   independently within each group. For global adjustment across all
   comparisons, apply `stats::p.adjust()` to the result manually."
   **When `group` is not active:** Apply `stats::p.adjust()` to all
   comparison rows.
3. If `variance` includes `"ci"`, the CI bounds are NOT recalculated after
   p-value adjustment (they reflect the original unadjusted confidence level).
   This matches standard practice. Document in roxygen `@details`:
   "Confidence intervals reflect the specified `conf_level` and are not
   affected by p-value adjustment."
4. When `pval_adj` is non-NULL, record it in `.meta$pval_adj`.

### 3.11 Percentage Change Calculation

When `show_pct_change = TRUE` (subject to link-scale suppression per
Section 3.2):

```r
pct_change <- estimate / reference_mean
```

- Reference row: `pct_change = NA` (no change from self).
- If `reference_mean == 0`, `pct_change = NA` and fire
  `surveycore_warning_pct_change_zero_ref`.

**Limitations:** Only the point estimate `pct_change` is reported. SE and CI
are not computed for `pct_change`; users requiring confidence intervals for
the ratio should apply the delta method to `estimate` and `reference_mean`
externally. Percentage change is substantively interpretable only when
`reference_mean` is a meaningful nonzero baseline. For outcomes with baseline
near zero, consider reporting the absolute difference (`estimate`) instead.

### 3.12 Rounding

When `decimals` is non-NULL, round these columns:
- `estimate`, `mean`, `se`, `ci_low`, `ci_high`, `p_value`: round to `decimals`
  via `.apply_decimals(result, decimals)`.
- `pct_change`: round to `decimals + 2` (more precision for proportions).
  **Implementation note:** Round `pct_change` separately *after*
  `.apply_decimals()` runs on all other columns. `.apply_decimals()` rounds
  all double columns uniformly, so `pct_change` must be excluded from that
  pass (e.g., temporarily set to `NA`, or round manually after the call).

### 3.13 `na.rm` Translation

**Validation:** `na.rm` is validated by `.validate_shared_args()` (called as
the first step in `get_diffs()`). Non-logical values (e.g., `NA`, `"yes"`, `42`)
trigger `surveycore_error_na_rm_not_logical`. This also validates `variance`,
`conf_level`, `name_style`, and `decimals`. `get_diffs()` passes
`valid_variance = c("se", "ci")` to `.validate_shared_args()` because SEs and
CIs come from `clean()` or `marginaleffects` — the additional variance types
(`"var"`, `"cv"`, `"moe"`, `"deff"`) supported by Phase 1's `.add_variance_cols()`
are not computed by `get_diffs()`.

| `na.rm` | Behavior |
|---|---|
| `TRUE` (default) | Rows with NA in `x`, `treats`, or any `group` column are silently dropped before fitting. Passes `na.action = stats::na.omit` to `survey_glm()`. |
| `FALSE` | NA values cause an error. Passes `na.action = stats::na.fail` to `survey_glm()`, which triggers `surveycore_error_na_in_data`. |

### 3.14 Domain Estimation

`get_diffs()` does not accept a `domain` or `subset` argument. Domain estimation
is handled upstream via `surveytidy::filter()` before calling `get_diffs()`.
`survey_glm()` respects the domain mask set by `filter()`.

### 3.15 `@groups` Integration

If `design@groups` is set (via `surveytidy::group_by()`), those groups are
combined with the `group` argument, per the Phase 1 pattern (see
`.resolve_groups()` in `analysis-helpers.R`). However, for `get_diffs()`, all
resolved group variables receive interaction terms with `treats` in the
formula. When both domain filtering and `@groups` are active, the domain
filter is applied uniformly to all group strata. The GLM is fit on rows
matching both the domain condition and non-missing group values.

---

## IV. `.meta` Contract

The `.meta` attribute on `survey_diffs` is a named list with these keys:

| Key | Type | Description |
|---|---|---|
| `design_type` | character(1) | `"taylor"`, `"replicate"`, `"twophase"`, or `"calibrated"` |
| `conf_level` | numeric(1) | Confidence level used |
| `call` | language | Matched call to `get_diffs()` |
| `n_respondents` | integer(1) | `nrow(design@data)` — total rows in the design object as passed to `get_diffs()`, before `na.action`. This includes out-of-domain rows (they are still in `@data` after `filter()`). |
| `group` | named list | One entry per group variable; `list()` when no groups. Each entry: `list(variable_label, question_preface, value_labels)` |
| `x` | named list | One entry for the DV. Structure: `list({x_name} = list(variable_label, question_preface, value_labels))` |
| `treats` | named list | Treatment variable metadata. Built by calling `.extract_var_meta(design, treats_name)` (returns `list(variable_label, question_preface, value_labels)`) and appending `name = treats_name` and `ref_level = ref_level`. Final structure: `list(variable_label, question_preface, value_labels, name, ref_level)` |
| `covariates` | character or `NULL` | Character vector of covariate terms, or `NULL` if none |
| `family` | character(1) | GLM family name (e.g., `"gaussian"`, `"quasibinomial"`) |
| `link` | character(1) | Link function name (e.g., `"identity"`, `"logit"`) |
| `pval_adj` | character(1) or `NULL` | P-value adjustment method, or `NULL` |
| `estimate_method` | character(1) | `"coefficient"` or `"avg_slopes"` |
| `mean_method` | character(1) | `"intercept"` or `"avg_predictions"` |
| `estimate_scale` | character(1) | `"coefficient"` (clean path or `scale = "link"`) or `"ame"` (marginaleffects path with `scale = "ame"`). For non-gaussian families with `scale = "ame"`, the estimate is on the response scale (e.g., probability difference for logistic). With `scale = "link"`, always `"coefficient"`. |

**Accessing:** `meta(result)` — the `meta()` generic from `analysis-meta.R`.

**Construction:** Uses `.extract_var_meta()` and `.build_group_meta()` from
`analysis-helpers.R` for `group`, `x`, and `treats` entries. The `treats`
entry is built by calling `.extract_var_meta(design, treats_name)` and
appending `name` and `ref_level` fields.

---

## V. Output Contract

### 5.1 S3 Class Hierarchy

```r
class(result) == c("survey_diffs", "survey_result", "tbl_df", "tbl", "data.frame")
```

### 5.2 Output Columns

Columns appear in this order. Optional columns are omitted when not requested.

| Column | Type | Presence | Description |
|---|---|---|---|
| `{group_cols}` | factor/character | When `group` is active | One column per group variable, in order. Type per `label_values` (Section 3.3). |
| `{treats_name}` | factor/character | Always | Treatment level. Column named after the `treats` variable. Type per `label_values` (Section 3.3): `factor` when labels are applied, `character` otherwise. |
| `estimate` | numeric | Always | Treatment effect (difference from reference). Reference row = 0. |
| `pct_change` | numeric | When `show_pct_change = TRUE`, subject to link-scale suppression (Section 3.2) | `estimate / reference_mean`. Reference row = NA. |
| `mean` | numeric | When `show_means = TRUE`, subject to link-scale suppression (Section 3.2) | Weighted mean for this treatment level. |
| `n` | integer | Always | Unweighted in-domain observation count for this treatment level (within group if applicable). When domain filtering is active (`..surveycore_domain..` exists in `@data`), counts only rows where `..surveycore_domain.. == TRUE`. Provided for quality assurance (e.g., small cell detection). Inference is design-based and uses weighted data. |
| `n_weighted` | numeric | When `n_weighted = TRUE` | Sum of weights for this treatment level (within group if applicable). |
| `se` | numeric | When `variance` includes `"se"` | Standard error of the estimate. Reference row = NA. |
| `ci_low` | numeric | When `variance` includes `"ci"` | Lower confidence bound. Reference row = NA. |
| `ci_high` | numeric | When `variance` includes `"ci"` | Upper confidence bound. Reference row = NA. |
| `p_value` | numeric | Always | P-value (possibly adjusted). Reference row = NA. |
| `stars` | character | Always | Significance stars. Reference row = `""`. |

### 5.3 Row Order

1. When `show_means = TRUE`: reference row first, then non-reference levels in
   factor-level order.
2. When `show_means = FALSE`: non-reference levels only, in factor-level order.
3. When `group` is active: rows grouped by group combination, with the above
   ordering within each group.

### 5.4 Reference Row Contract

When `show_means = TRUE`, the reference level appears as a row with the
values below. The reference row has `p_value = NA` because no hypothesis test
exists for the baseline — the difference from itself is zero by definition.

| Column | Value |
|---|---|
| `{treats_name}` | `ref_level` |
| `estimate` | `0` |
| `pct_change` | `NA_real_` |
| `mean` | Weighted mean of reference group |
| `n` | Unweighted in-domain count of reference group |
| `se` | `NA_real_` |
| `ci_low` | `NA_real_` |
| `ci_high` | `NA_real_` |
| `p_value` | `NA_real_` |
| `stars` | `""` |
| `n_weighted` | Sum of weights for reference level (within group if applicable). Only present when `n_weighted = TRUE`. |

### 5.5 Column-Level Labels

Every column in the output has a `label` attribute set via
`attr(col, "label") <- "..."`. These are automatically picked up by
`gt::gt()`. Column labels always use variable labels from metadata when
available, falling back to raw variable names — there is no user-facing
toggle for this behavior.

| Column | `label` value |
|---|---|
| `{treats_name}` | Variable label from metadata, or variable name if no label |
| `{group_cols}` | Variable label from metadata per group variable, or variable name if no label |
| `estimate` | `"Difference relative to {ref_level}"` |
| `pct_change` | `"% Change"` |
| `mean` | `"Mean"` |
| `n` | `"N"` |
| `n_weighted` | `"N (weighted)"` |
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
| `surveycore_error_unsupported_class` | `design` is not a `survey_base` subclass | Reuse `.check_unsupported_class(design, "get_diffs")` |
| `surveycore_error_non_numeric_variable` | `x` column is not numeric | `{.arg x} must be numeric. {.field {x_name}} is {.cls {class}}.` |
| `surveycore_error_treats_single` | `treats` resolves to != 1 column | `{.arg treats} must select exactly one column.` |
| `surveycore_error_wrong_variable_count` | `x` resolves to != 1 column | `{.arg x} must select exactly one column.` |
| `surveycore_error_ref_level_not_found` | `ref_level` not in levels of treats | `{.arg ref_level} {.val {ref_level}} not found in levels of {.field {treats_name}}.` |
| `surveycore_error_treats_one_level` | `treats` has only 1 unique value after NA removal | `{.arg treats} must have at least 2 levels. {.field {treats_name}} has only 1.` |
| `surveycore_error_invalid_pval_adj` | `pval_adj` not a valid method | `{.arg pval_adj} must be a valid method for {.fn stats::p.adjust}.` |
| `surveycore_error_invalid_conf_level` | `conf_level` not in (0, 1) | (reuse existing class from Phase 2) |
| `surveycore_error_covariates_not_character` | `covariates` is not a character vector | `{.arg covariates} must be a character vector of model terms.` |

| `surveycore_error_reference_row_not_found` | `clean()` output has zero or multiple `(Intercept)` rows | `Reference row not found in model output. Expected exactly one intercept row.` |

Errors from `survey_glm()` propagate unchanged (e.g.,
`surveycore_error_formula_missing`, `surveycore_error_singular_model_matrix`,
`surveycore_error_na_in_data`, `surveycore_error_empty_domain`).

### 6.2 Warnings

| Warning class | Trigger | Message template |
|---|---|---|
| `surveycore_warning_pct_change_zero_ref` | `show_pct_change = TRUE` and reference mean is 0 | `Reference group mean is 0; percentage change is undefined.` |
| `surveycore_warning_treats_coerced` | `treats` column is not a factor (coerced) | `{.field {treats_name}} coerced to factor.` |
| `surveycore_warning_small_cell` | Any treatment level (within group) has fewer than `min_cell_n` unweighted observations | `Treatment level {.val {level}} has only {n} observations (threshold: {min_cell_n}).` |

Warnings from `survey_glm()` propagate unchanged (e.g.,
`surveycore_warning_glm_convergence`, `surveycore_warning_perfect_separation`).

---

## VII. Execution Flow

### 7.1 Step-by-Step

```
Step 1:  Validate shared args (.validate_shared_args with
         valid_variance = c("se", "ci"): variance, conf_level,
         name_style, decimals, na.rm)
Step 2:  Validate design class (.check_unsupported_class)
Step 3:  Resolve x, treats, group via tidy-select
Step 4:  Validate x is numeric, treats has ≥ 2 levels
Step 4a: Validate covariates is character or NULL
         (surveycore_error_covariates_not_character);
         validate pval_adj is NULL or in stats::p.adjust.methods
         (surveycore_error_invalid_pval_adj)
Step 5:  Handle ref_level (default or validate user-supplied)
Step 6:  Handle na.rm → na.action translation
Step 7:  Coerce treats to factor, relevel if needed, force treatment
         contrasts (Section 3.7 Step 5: contr.treatment).
         NOTE: Steps 7–8 modify design@data in place before the
         GLM call in Step 9.
Step 8:  Build formula from treats + group + covariates
Step 9:  Call survey_glm(design, formula, na.action, ...)
Step 10: Determine estimation path (clean vs marginaleffects;
         see Section 7.2)
Step 11: Extract estimates and means via chosen path
Step 12: Compute n per treatment level (+ group), domain-aware
         (see Section 5.2 `n` column)
Step 13: Apply pval_adj if requested
Step 14: Apply link-scale suppression (Section 3.2): omit mean
         and pct_change columns if applicable
Step 15: Compute pct_change if requested and not suppressed
Step 16: Assign stars
Step 17: Assemble output tibble in column order
Step 17a: Apply label_values via .apply_group_labels() to
          treats and group columns
Step 18: Apply decimals rounding if requested
Step 19: Apply name_style via .apply_name_style(result,
         name_style, exclude = "mean")
Step 20: Attach .meta via .make_result_tibble()
Step 21: Attach column-level labels (inline; Section 5.5)
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

When `scale = "link"`, non-gaussian models use the clean path (Section 3.8,
coefficients on the link scale) unless covariates or groups are present,
which still require `avg_slopes()` (Section 3.9). When `scale = "ame"`
(default), non-gaussian models always use the marginaleffects path to compute
response-scale AMEs.

---

## VIII. Print Method

`survey_diffs` inherits from `survey_result`, which has a generic
`print.survey_result()` in `analysis-meta.R` that prints a single header line
(`# A <survey_diffs> [N × M]`) then delegates to tibble.

`print.survey_diffs()` **overrides** `print.survey_result()` to add 3
additional context lines before the tibble body. S3 dispatch finds
`print.survey_diffs` before `print.survey_result` because `survey_diffs` is
first in the class vector.

**Registration:** `registerS3method("print", "survey_diffs",
print.survey_diffs)` in `.onLoad()` in `zzz.R`.

**Exact console output:**

```
# A survey_diffs result
# Design: Taylor series | Family: gaussian (identity)
# DV: agree_trope | Treatment: message_arm (ref: Control)
# Method: coefficient / intercept
# A tibble: 4 × 8
  message_arm estimate  mean     n ci_low ci_high p_value stars
  <fct>          <dbl> <dbl> <int>  <dbl>   <dbl>   <dbl> <chr>
1 Control        0     0.401   752 NA      NA      NA      ""
2 Message A      0.082 0.483   748  0.042   0.122   0.001  "**"
3 Message B      0.103 0.504   751  0.063   0.143   0.000  "***"
4 Message C      0.045 0.446   749  0.005   0.085   0.028  "*"
```

The 4 header lines:
- Line 1: Result class name
- Line 2: Design type + family + link (from `.meta$design_type`, `.meta$family`, `.meta$link`)
- Line 3: DV name + treatment variable + reference level (from `.meta$x`, `.meta$treats$name`, `.meta$treats$ref_level`)
- Line 4: Estimation method (from `.meta$estimate_method` / `.meta$mean_method`)

---

## IX. Testing Requirements

### 9.1 Test Categories

Per `testing-standards.md`: happy path + error paths + edge cases for every
exported function.

#### Happy Path Tests (`test-analysis-diffs.R`)

| Test | Description |
|---|---|
| Bivariate gaussian, no group | Basic `DV ~ treats` with `survey_taylor` design |
| Bivariate gaussian, with group | `DV ~ treats * group` with `survey_taylor` |
| With covariates, no group | `DV ~ treats + covariates` |
| With covariates and group | `DV ~ treats * group + covariates` |
| Non-gaussian family (quasibinomial) | Binary DV with `family = quasibinomial()` via `...` |
| `show_means = FALSE` | No reference row, no `mean` column |
| `show_pct_change = TRUE` | `pct_change` column present and correct |
| `pval_adj = "BH"` | P-values adjusted, adjustment recorded in `.meta` |
| `variance = "se"` | SE column present, no CI columns |
| `variance = c("se", "ci")` | Both SE and CI columns present |
| `variance = NULL` | No SE or CI columns |
| `ref_level` specified | Different reference level changes output |
| `decimals` | Numeric columns rounded correctly |
| All 4 design classes | One test per design class (taylor, replicate, twophase, nonprob) |
| Domain estimation | `filter(design, condition) \|> get_diffs(...)` produces in-domain `n` counts and correct estimates. Gated with `skip_if_not_installed("surveytidy")`. |
| Print snapshot | `expect_snapshot(print(result))` captures all 4 header lines + tibble body. Verifies class, design+family, DV+treatment+ref, and method display. |
| `label_values = TRUE` | Treats and group columns display value labels from metadata |
| `label_values = FALSE` | Treats and group columns display raw codes |
| `name_style = "broom"` | Columns renamed: `se` → `std.error`, `ci_low` → `conf.low`, etc.; `mean` excluded |
| `n_weighted = TRUE` | `n_weighted` column present with sum of weights per treatment level |
| `min_cell_n` custom | Custom threshold fires `surveycore_warning_small_cell` at the right count |

#### Error Path Tests (`test-analysis-diffs.R`)

One `test_that()` block per error class in Section VI, using the dual pattern
from `testing-standards.md`: `expect_error(class = ...)` +
`expect_snapshot(error = TRUE, ...)`.

#### Edge Case Tests (`test-analysis-diffs.R`)

| Test | Description |
|---|---|
| `treats` with 2 levels | Simplest case: 1 reference + 1 treatment row |
| `treats` with many levels (10+) | Verify all non-reference levels appear |
| `treats` as character (not factor) | Coerced to factor with warning |
| Reference mean = 0 with `show_pct_change` | Warning + `pct_change = NA` |
| Single observation in one treatment level | `surveycore_warning_small_cell` fires |
| All NA in `x` for one treatment level | Model still fits; that level has `n = 0` |
| `group` with only 1 unique value | `survey_glm()` throws `surveycore_error_singular_model_matrix` due to collinear interaction terms. Verify error propagation. |
| `na.rm = FALSE` with NAs present | Error propagated from `survey_glm()` |
| Gaussian `scale = "ame"` == `scale = "link"` | Both scales produce identical estimates, SEs, and CI bounds (tolerance 1e-10 for point, 1e-8 for SEs). Guards routing logic. |
| `scale = "link"` + non-gaussian | Link-scale suppression (Section 3.2): `mean` and `pct_change` columns omitted |

#### Numerical Tests (`test-analysis-diffs-numerical.R`)

| Test | Description |
|---|---|
| Bivariate OLS vs manual computation | `clean()` coefficient = hand-computed diff of weighted means |
| Multivariate OLS vs `survey::svyglm` + `marginaleffects` | `avg_slopes()` output matches direct `survey::svyglm` → `marginaleffects::avg_slopes()` pipeline |
| Logistic AME vs `survey::svyglm` + `marginaleffects` | Binary DV with `quasibinomial()` family: AME and SE match `survey::svyglm(..., family = quasibinomial()) + marginaleffects::avg_slopes()` |
| Poisson AME vs `survey::svyglm` + `marginaleffects` | Count response with `poisson()` family: same comparison pipeline |
| SRS full covariance matrix verification | For multivariate tests, verify that off-diagonal elements of `fit@vcov` are non-zero (where expected) and match `survey::svyglm()` within tolerance 1e-8. A diagonal-only implementation would pass point-estimate tests but produce wrong SEs when covariates are correlated. |
| Replicate design non-integer df | Replicate design with non-integer `degf` produces CI bounds matching manual `qt(0.975, df = degf_value)`. Verify df is numeric (double), not integer. |
| Replicate domain convergence | Call `get_diffs()` on a replicate design with a tight domain filter causing some replicates to have near-zero in-domain rows. Verify that warnings from `survey_glm()` propagate and that results are finite (no silent NaN propagation). |

**Tolerances:**
- Bivariate OLS (clean path): `1e-8` for estimates, `1e-6` for SEs and CI bounds.
- Marginaleffects oracle tests: `1e-10` for point estimates, `1e-8` for SEs, `1e-6` for CI bounds — matching Phase 2 spec Section IX.

#### Marginaleffects Path Tests (`test-analysis-diffs-marginaleffects.R`)

All tests gated with `skip_if_not_installed("marginaleffects")`.

| Test | Description |
|---|---|
| `avg_slopes()` produces correct number of rows | One row per non-reference treatment level (× group) |
| `avg_predictions()` produces correct means | One row per treatment level (× group) |
| `wts = TRUE` produces weighted averages | Compare against manual weighted computation |

### 9.2 `.meta` Tests

Every happy path test must also verify:
- `meta(result)$estimate_method` matches expected path
- `meta(result)$mean_method` matches expected path
- `meta(result)$treats$ref_level` matches expected reference level
- `meta(result)$family` matches expected family

### 9.3 Column Label Tests

At least one test verifies that every output column has a `label` attribute set:
```r
test_that("get_diffs() sets column-level labels on all columns", {
  result <- get_diffs(d, dv, treatment)
  for (col in names(result)) {
    expect_false(is.null(attr(result[[col]], "label")))
  }
})
```

---

## X. Quality Gates

All gates must pass before `get_diffs()` is merged:

- [ ] `devtools::check()` returns 0 errors, 0 warnings, ≤ 2 pre-approved notes
- [ ] 98%+ line coverage on `analysis-diffs.R` and `analysis-diffs-helpers.R`
- [ ] All error classes from Section VI have corresponding tests
- [ ] All 4 design classes have at least one happy-path test
- [ ] Numerical tests pass against reference implementation
- [ ] `.meta` contract fully tested
- [ ] Column labels tested
- [ ] `marginaleffects` added to `Imports` in DESCRIPTION
- [ ] `plans/error-messages.md` updated with new error/warning classes

---

## XI. Usage Examples

### 11.1 Basic Bivariate (SOP Model A)

```r
d <- as_survey(msg_test_data, ids = resp_id, weights = rake_wt)

# Treatment effect — percentage point difference vs. control
get_diffs(d, agree_trope, message_arm)
```

### 11.2 Multivariate with Covariates (SOP Model B)

```r
get_diffs(d, agree_trope, message_arm,
          covariates = c("age", "gender", "education", "ideology"))
```

### 11.3 Subgroup Analysis (SOP Section 5)

```r
get_diffs(d, agree_trope, message_arm,
          group = age_group,
          covariates = c("gender", "education", "ideology"))
```

### 11.4 Logistic Path (SOP Section 2.2)

```r
# When ≥90% agree in control, use logistic
get_diffs(d, agree_trope, message_arm,
          family = quasibinomial())
```

### 11.5 With P-Value Adjustment (SOP Section 6.4)

```r
get_diffs(d, agree_trope, message_arm,
          pval_adj = "BH")
```

### 11.6 Full Reporting Table

```r
library(gt)

get_diffs(d, agree_trope, message_arm,
          show_pct_change = TRUE,
          variance = c("se", "ci"),
          decimals = 3) |>
  gt::gt()
# Column headers auto-populated from label attributes
```
