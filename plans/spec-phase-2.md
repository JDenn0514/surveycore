# surveycore Phase 2 — Survey GLM: Weighted Regression

**Version:** 0.8
**Date:** February 2026
**Status:** Revised — Issues 39–46 resolved; pending final approval before implementation plan

---

## Document Purpose

This document is the authoritative specification for Phase 2 of the surveycore
package. Every API contract, behavioral rule, output structure, and design
decision is explicitly defined here. Implementation must follow these rules
exactly. Where a rule is already defined in `code-style.md`,
`r-package-conventions.md`, or `surveycore-conventions.md`, this document
references those rules rather than restating them.

---

## I. Scope

### What Phase 2 Delivers

Three components added to the `surveycore` package:

| Component | Description |
|---|---|
| `survey_glm_fit` S7 class | Model object holding all regression output |
| `survey_glm()` | Survey-weighted GLM constructor |
| S3 methods on `survey_glm_fit` | `print`, `summary`, `coef`, `vcov`, `predict`, `fitted`, `residuals`, `confint`, `formula`, `terms`, `model.matrix`, `model.frame`, `deviance`, `df.residual`, `nobs`, `hatvalues`, `logLik`, `AIC`, `BIC`, `update` (20 methods total) |
| `clean()` | Tidy the model into a `survey_glm_tidy` result tibble |
| `broom::tidy.survey_glm_fit()` | Compatibility shim; delegates to `clean()` |
| marginaleffects extension interface | `get_coef`, `set_coef`, `get_vcov`, `get_predict` S3 methods enabling `marginaleffects::avg_slopes()` and `marginaleffects::avg_predictions()` on `survey_glm_fit` objects |

### What Phase 2 Does NOT Deliver

- `get_diffs()` — Phase 3 spec; depends on `survey_glm()` and the marginaleffects
  extension interface (Section VII)
- `get_crosstab()` — separate spec
- `broom::glance.survey_glm_fit()` — deferred; flagged as future extension
- Covariate-adjusted means computed natively without `marginaleffects` — deferred;
  use the marginaleffects extension interface (Section VII) instead
- `survey_glm()` for polytomous outcomes (multinomial logistic) — deferred
- `survey_glm()` with `subset =` domain argument — deferred; domain estimation
  is handled upstream via `surveytidy::filter()` before calling `survey_glm()`

### Supported Design Classes

All functions in Phase 2 support these design classes:

| Class | Variance method for GLM |
|---|---|
| `survey_taylor` | Binder (1983) sandwich estimator via Taylor linearization of score |
| `survey_replicate` | Refit GLM per replicate; weighted sum of squared coefficient deviations |
| `survey_srs` | Weighted OLS sandwich estimator |
| `survey_twophase` | Two-phase linearization of score (requires Phase 0.75 complete) |
| `survey_calibrated` | Weighted SRS approximation (conservative) |

**`survey_calibrated` contract:** `survey_glm()` uses the same SRS sandwich
formula for `survey_calibrated` designs as it does for `survey_srs` designs.
No calibration adjustment is made to the GLM variance — this is the
conservative approach used consistently in Phase 1 (see
`plans/phase-1-formal-specification.md` Section I). This matches
`survey::svyglm()`'s behavior when `calibrate()` output is passed without
additional variance adjustment. An oracle test using synthetic calibrated data
is required (Section VIII).

### Prerequisites

| Prerequisite | What Phase 2 Needs From It |
|---|---|
| Phase 0.75 complete | Two-phase variance infrastructure (`R/06-variance-twophase.R`) used for `survey_twophase` designs |
| Phase 1 complete | `survey_result` base class (`R/09-meta.R`), `meta()` generic, `survey_result` S3 hierarchy used by `survey_glm_tidy` |

`survey_glm_fit` (the model object S7 class) is independent of Phase 1.
`clean()` (which returns a `survey_result`) requires Phase 1.

---

## II. Architecture

### 2.1 File Organization

```
R/
├── 14-glm.R                      # survey_glm_fit S7 class + survey_glm() + .glm_score()
├── 14-glm-methods.R              # S3 methods: print, summary, coef, vcov, predict, fitted, residuals
├── 14-glm-clean.R                # clean() + .build_glm_meta() + broom::tidy registration
├── 14-glm-marginaleffects.R      # marginaleffects extension: get_coef, set_coef, get_vcov, get_predict

tests/testthat/
├── test-glm.R                    # survey_glm() happy paths + error paths + edge cases
├── test-glm-methods.R            # S3 methods: correct output + error paths
├── test-glm-numerical.R          # Oracle tests vs survey::svyglm() — all design types
└── test-glm-marginaleffects.R    # marginaleffects extension tests (all gated with skip_if_not_installed)
```

### 2.2 Internal Helpers

All internal helpers are not exported and prefixed with `.`, per `code-style.md §4`.

#### `.glm_score(fit, design)`

Computes the per-observation score vector for the sandwich estimator. The
score for observation `i` is `u_i = w_i * x_i * e_i` where `w_i` is the
survey weight, `x_i` is the row of the model matrix, and `e_i` is the
working residual extracted as `residuals(fit, type = "working")` — the
residuals from the final IRLS step. For Gaussian/identity link this equals
Pearson and response residuals; for other families (binomial, Poisson) it
does not. Returns a matrix with `nrow(design@data)` rows and `p` columns
(one per coefficient).

```r
.glm_score <- function(fit, design) {
  # fit: result of stats::glm() with survey weights
  # design: the survey_base object
  # Returns: n × p score matrix for sandwich variance computation
}
```

#### `.glm_sandwich_vcov(score_matrix, meat_vcov, info_matrix)`

Assembles the sandwich variance-covariance matrix:

```
Var(β̂) = info⁻¹ · meat · info⁻¹
```

where `meat = V_design(Σ_i u_i)` (the design-based variance of the total
score vector) and `info = X'WX / n` (the weighted information matrix).

```r
.glm_sandwich_vcov <- function(score_matrix, meat_vcov, info_matrix) {
  # Returns: p × p variance-covariance matrix
}
```

#### `.build_glm_meta(model, conf_level, call)`

Constructs the `.meta` list for a `survey_glm_tidy` result. Returns a named
list with all required keys always present (unset values `NULL`, never absent).

Family and link extraction: `model@family$family` gives the family name string
(e.g., `"gaussian"`, `"binomial"`, `"poisson"`, `"Gamma"`) and
`model@family$link` gives the link function string (e.g., `"identity"`,
`"logit"`, `"log"`, `"inverse"`). These `$family` and `$link` fields are
present on every R family object — this works for all families accepted by
`stats::glm()`, not just Gaussian. Do not use `class(model@family)` (returns
`"function"`) or `model@family$family()` (a function call, not a string).

#### `.taylor_var_score_matrix(score_matrix, design)`

Computes the design-based variance of the total score vector for the Taylor
sandwich estimator. This is the bridge between `.glm_score()` and the Phase 0
variance machinery.

```r
.taylor_var_score_matrix <- function(score_matrix, design) {
  # score_matrix: n × p matrix; column j is u_ij = w_i * x_ij * e_i
  # (pre-weighted scores; no further centering is applied here)
  # design: a survey_taylor or survey_twophase object
  # Returns: p × p meat matrix = Var_design(T) where T = colSums(score_matrix)
}
```

Internally calls `.svy_recvar()` (the vendored function in
`R/06-variance-taylor.R`) directly with the score matrix. The scores are
already in the form expected by `.svy_recvar()`: per-observation weighted
deviations. Each column is treated as a separate survey-weighted total.
The return value is the `p × p` variance matrix of the total score vector
`T = Σ_i u_i`, which becomes the "meat" in the sandwich
`Var(β̂) = I⁻¹ · Var_design(T) · I⁻¹`.

This helper is NOT used for replicate designs (those refit the GLM per
replicate — see Section 8.3) or SRS designs (analytic formula — see
Section 8.4).

#### `.glm_degrees_of_freedom(design, n_predictors)`

Computes the residual degrees of freedom for t-tests and CIs:

```
df_residual = degf(design) - (p - 1)
```

where `p` is the total number of coefficients including the intercept and
`degf(design)` is the design-based degrees of freedom.

**`.degf()` already exists in `R/09-analysis-helpers.R`** (implemented in
Phase 1). It covers all five design classes. Phase 2 calls `.degf()` directly —
no new `degf()` implementation is needed.

---

## III. `survey_glm_fit` S7 Class

### 3.1 Class Definition

```r
survey_glm_fit <- S7::new_class(
  "survey_glm_fit",
  properties = list(
    coefficients   = S7::new_property(S7::class_numeric),
    vcov           = S7::new_property(S7::class_matrix),
    fitted_values  = S7::new_property(S7::class_numeric),
    residuals      = S7::new_property(S7::class_numeric),
    weights        = S7::new_property(S7::class_numeric),
    design         = S7::new_property(class = survey_base),
    degf           = S7::new_property(S7::class_numeric),
    family         = S7::new_property(S7::class_list),
    formula        = S7::new_property(default = NULL),
    null_deviance  = S7::new_property(S7::class_numeric),
    deviance       = S7::new_property(S7::class_numeric),
    df_null        = S7::new_property(S7::class_integer),
    df_residual    = S7::new_property(S7::class_integer),
    converged      = S7::new_property(S7::class_logical),
    call           = S7::new_property(default = NULL),
    fit_           = S7::new_property(default = NULL)   # internal; the stats::glm() result
  )
)
```

### 3.2 Property Descriptions

| Property | Type | Description |
|---|---|---|
| `coefficients` | named numeric vector | Length `p`; coefficient estimates |
| `vcov` | `p × p` matrix | Design-based variance-covariance matrix |
| `fitted_values` | numeric vector | Length `n`; fitted values on the response scale |
| `residuals` | numeric vector | Length `n`; working residuals |
| `weights` | numeric vector | Length `n`; survey weights used in fitting |
| `design` | `survey_base` | The original survey design object |
| `degf` | numeric, length 1 | Design degrees of freedom |
| `family` | list | The GLM family object (output of e.g. `gaussian()`) |
| `formula` | formula | The model formula |
| `null_deviance` | numeric, length 1 | Deviance of the null model (intercept only) |
| `deviance` | numeric, length 1 | Residual deviance of the fitted model |
| `df_null` | integer, length 1 | Degrees of freedom for the null model |
| `df_residual` | integer, length 1 | Residual degrees of freedom (n − p) |
| `converged` | logical, length 1 | Whether the IRLS algorithm converged |
| `call` | language or NULL | The `survey_glm()` call |
| `fit_` | any or NULL | Internal: raw `stats::glm()` fit; used by `predict()`. Not part of public API; may be `NULL` after serialization. |

### 3.3 S7 Validator

The S7 class validator enforces structural invariants. These errors use `class=`
only (no snapshot), per `testing-surveycore.md §S7 error testing layers`:

```r
validator = function(self) {
  p <- length(self@coefficients)
  if (p == 0L) "coefficients must be non-empty"
  else if (!identical(dim(self@vcov), c(p, p))) {
    paste0("vcov must be ", p, "x", p, " (same dimension as coefficients)")
  } else if (length(self@fitted_values) == 0L) {
    "fitted_values must be non-empty"
  } else if (length(self@residuals) != length(self@fitted_values)) {
    "residuals and fitted_values must have the same length"
  } else if (length(self@weights) != length(self@fitted_values)) {
    "weights and fitted_values must have the same length"
  } else if (length(self@degf) != 1L || self@degf <= 0) {
    "degf must be a single positive number"
  } else if (!is.null(self@formula) && !inherits(self@formula, "formula")) {
    "formula must be a formula object or NULL"
  } else {
    NULL
  }
}
```

---

## IV. `survey_glm()` Function

### 4.1 Signature

```r
survey_glm <- function(
  design,
  formula     = NULL,
  response    = NULL,
  predictors  = NULL,
  family      = gaussian(),
  na.action   = na.omit,
  start       = NULL,
  etastart    = NULL,
  mustart     = NULL,
  control     = list()
)
```

Two mutually exclusive interfaces specify the model:

- **Formula interface:** Pass a formula object as `formula`, e.g.
  `y ~ x1 + x2`. This is the standard R modeling interface and matches
  `survey::svyglm()`.
- **Programmatic interface:** Pass `response` (a character string naming
  the outcome variable) and optionally `predictors` (a character vector of
  predictor names; defaults to `"1"` for an intercept-only model if omitted).
  Internally constructs `reformulate(predictors %||% "1", response)`. Use
  this interface when building models programmatically, e.g. iterating over
  a list of outcome variables in `lapply()` or `purrr::map()` without
  needing to call `reformulate()` manually.

Specifying both `formula` and either `response` or `predictors` is an error
(`surveycore_error_formula_conflict`). Specifying neither is an error
(`surveycore_error_formula_missing`). Specifying `predictors` without
`response` is also an error (`surveycore_error_formula_missing`, with an
informative message noting that `response` is required).

`formula` has a `NULL` default so that missing model specification fires a
typed surveycore error rather than a base R missing-argument error. The
explicit NULL check in Step 1 makes this error class testable with the
standard dual pattern.

Argument order follows `code-style.md §4`: `design` first (required survey
object), `formula` second (NULL default; primary model specification),
`response`/`predictors` third (programmatic alternative to `formula`), then
`family` and optional scalars. No `...` — variadic pass-through to
`stats::glm()` is not supported. GLM control options are passed via
`control`.

### 4.2 Argument Table

| Argument | Type | Default | Description |
|---|---|---|---|
| `design` | `survey_base` | — | A survey design object created by `as_survey()` or family. |
| `formula` | `formula` or NULL | `NULL` | Model formula in standard R notation, e.g. `y ~ x1 + x2`. Mutually exclusive with `response`/`predictors`. Errors with `surveycore_error_formula_missing` if neither `formula` nor `response` is supplied. |
| `response` | character, length 1 or NULL | `NULL` | Response (outcome) variable name as a character string. Programmatic alternative to `formula`; mutually exclusive with it. Errors with `surveycore_error_formula_missing` if `predictors` is supplied without `response`. |
| `predictors` | character vector or NULL | `NULL` | Predictor variable names as a character vector. Used with `response` to build the model formula via `reformulate(predictors, response)`. If `response` is supplied and `predictors` is `NULL`, an intercept-only model (`response ~ 1`) is fitted. Mutually exclusive with `formula`. |
| `family` | glm family object | `gaussian()` | A family object specifying the error distribution and link function. Any family accepted by `stats::glm()` is supported. |
| `na.action` | function | `na.omit` | How to handle `NA` values. `na.omit` (default) removes rows with any `NA` in the model variables. `na.fail` errors on any `NA`. |
| `start` | numeric or NULL | `NULL` | Starting values for the coefficient vector. Passed to `stats::glm()`. |
| `etastart` | numeric or NULL | `NULL` | Starting values for the linear predictor. Passed to `stats::glm()`. |
| `mustart` | numeric or NULL | `NULL` | Starting values for the mean. Passed to `stats::glm()`. |
| `control` | list | `list()` | GLM control parameters passed to `stats::glm.control()`. |

### 4.3 Output Contract

Returns a `survey_glm_fit` S7 object (Section III). The returned object is
always a complete, valid `survey_glm_fit` — the validator runs on construction.

### 4.4 Behavior Rules

`survey_glm()` executes these steps in order:

**Step 1: Validate inputs**

Call `.check_unsupported_class(design, "survey_glm")` — this throws
`surveycore_error_unsupported_class` if `design` does not inherit from
`survey_base`, matching the pattern used by all Phase 1 analysis functions.

**Formula resolution.** Resolve the model specification from the two mutually
exclusive interfaces:

1. If `formula` is non-NULL AND (`response` is non-NULL OR `predictors` is
   non-NULL): error `surveycore_error_formula_conflict`.
2. If `formula` is NULL AND `response` is NULL AND `predictors` is NULL:
   error `surveycore_error_formula_missing`.
3. If `formula` is NULL AND `response` is NULL AND `predictors` is non-NULL:
   error `surveycore_error_formula_missing` with an informative `"i"` bullet
   noting that `{.arg response}` is required when using `{.arg predictors}`.
4. If `formula` is NULL AND `response` is non-NULL: construct the formula via
   `reformulate(predictors %||% "1", response)`. After construction, the
   remainder of Step 1 proceeds as if the user had supplied this formula
   directly. The constructed formula is stored in the returned `survey_glm_fit`
   object's `@formula` property.

Validate `formula` is a formula object — error `surveycore_error_formula_invalid`
if not. (This check applies to the user-supplied formula in the formula
interface; the programmatic interface always produces a valid formula via
`reformulate()`.)

Resolve all variables in `formula` against `design@data`. Extract response
variable names using `all.vars(formula[[2]])` — this handles in-formula
transformations such as `log(y) ~ x` or `I(y > 0) ~ x` correctly (R's
formula parser returns the variable names referenced in the expression, not the
expression text). Validate each extracted name against `design@data`. Error
`surveycore_error_response_not_found` if any response variable is absent;
error `surveycore_error_predictor_not_found` if any predictor is absent.
`cbind()` on the LHS (multinomial response) is not supported; specifying
`cbind(y1, y2) ~ x` will error with `surveycore_error_response_not_found` for
`y2` or similar — document in the function-level roxygen that multinomial
logistic is deferred to a later phase.

Warn `surveycore_warning_response_is_design_var` if the response variable is
one of the design variables (`ids`, `weights`, `strata`, `fpc` from
`design@variables`).

**Step 2: Apply domain**

If the design has an active domain (`.apply_domain(design)` returns a non-`all(TRUE)`
vector), restrict the data to in-domain rows for fitting. Domain membership
from `surveytidy::filter()` is stored as `..surveycore_domain..` in
`design@data`. The variance estimation uses the full design (all rows) to
produce correct design-based standard errors. See Section 4.5 for the domain
contract.

**Step 3: Check weights for NAs, then apply `na.action`**

Before applying `na.action`, check the weight vector
(`design@data[[design@variables$weights]]`) for `NA` values. If any are
present, error with `surveycore_error_na_weights`. This check is necessary
because `na.action` applies only to the model frame (formula variables);
survey weights are passed separately to `stats::glm()` and are not covered
by `na.action`.

Also check for non-positive weights: if any weights are `≤ 0`, warn with
`surveycore_warning_nonpositive_weights` and proceed. Zero-weight rows are
treated as excluded observations by `stats::glm()` — this matches base R
behavior and is an intentional pattern in some workflows. The warning ensures
users are not silently surprised by the exclusion.

Apply `na.action` to the model frame derived from `formula` and the (possibly
domain-restricted) data. Rows removed by `na.action` are excluded from
fitting and from variance estimation.

**Step 4: Fit weighted GLM**

Call `stats::glm(formula, family, data, weights)` with the survey weights
from `design@variables$weights`. This produces the coefficient estimates β̂
and the fitted values under the specified family and link function.

Warn `surveycore_warning_glm_convergence` if `fit$converged` is `FALSE`.

Warn `surveycore_warning_perfect_separation` if any fitted probability is
numerically 0 or 1 (for binomial family).

Error `surveycore_error_singular_model_matrix` if `stats::glm()` produces a
singular or aliased model matrix (i.e., `any(is.na(coef(fit)))` after fitting).

**Step 5: Compute design-based variance**

Dispatch to the appropriate variance method based on design class (see Section VII).
Returns the design-based `p × p` variance-covariance matrix for the
coefficients.

**Step 6: Assemble and return**

Construct and return a `survey_glm_fit` S7 object from all computed quantities.
Set `dimnames(vcov_matrix) <- list(names(coef(fit)), names(coef(fit)))` where
`coef(fit)` is the `stats::glm()` result, so that `vcov` row/column names
match `names(object@coefficients)`.
Store the raw `stats::glm()` result in `fit_` (used by `predict()`).

### 4.5 Domain Estimation Contract

`survey_glm()` does not have a `domain =` argument. Domain estimation is
performed upstream with `surveytidy::filter()` before calling `survey_glm()`.

```r
# Correct domain estimation pattern
design |>
  surveytidy::filter(age >= 18) |>
  survey_glm(income ~ education + sex)
```

When the design has an active domain:
- The GLM is **fit only on in-domain rows** (coefficient estimation uses
  in-domain observations only)
- The **variance estimation uses all rows** of the original design to compute
  correct design-based standard errors (same domain-estimation contract as
  Phase 1 analysis functions; see `plans/phase-1-formal-specification.md §2.2`)

**Out-of-domain score treatment:** For out-of-domain observations, the working
residual `e_i` is undefined (the GLM was not fit on those rows). The score
contribution is set to zero:

```
u_i = w_i · x_i · e_i · I(i ∈ domain)
```

In-domain rows (`I = 1`) use their GLM working residuals as normal.
Out-of-domain rows (`I = 0`) contribute zero to the score total `T = Σ u_i`.
The full-design Taylor linearization of `T` is then computed over all `n` rows
(including the zero out-of-domain rows), producing correct design-based
standard errors for the domain estimator.

This follows directly from the Phase 1 precedent: `.apply_domain()` in
`R/07-utils.R` multiplies per-observation contributions by a domain indicator
vector. For GLM, the same indicator is applied to the score matrix
before passing to `.taylor_var_score_matrix()`. Replicate variance applies
the same indicator to replicate-weight refits: refit on in-domain rows, set
`u_i = 0` for out-of-domain rows when computing deviations.

**Empty domain:** If the active domain contains zero in-domain rows after
domain restriction, error with `surveycore_error_empty_domain` before calling
`stats::glm()`. This check occurs in Step 2 of Section 4.4, after the domain
filter is applied but before the model frame is constructed. A zero-row
GLM call would produce a cryptic base R error; a typed surveycore error is
required for defensive, Phase-1-consistent design. See Section 4.7 row 12
and Section IX.

**Validation:** `test-glm-numerical.R` includes an oracle comparison of
`survey_glm()` on a `surveytidy::filter()`-domain design against
`survey::svyglm(..., subset = domain_indicator)` using `nhanes_2017`. The
coefficients and SEs must match within the standard tolerances (1e-10 point,
1e-8 SE). This oracle test is item 10 of Section 9.2.

### 4.6 `@groups` and Grouping

`survey_glm()` does **not** support `group =` or `@groups`. Grouped regression
(fitting separate models per group) is a Phase 3+ feature. If the design has
`@groups` set (from `surveytidy::group_by()`), `survey_glm()` issues a warning
`surveycore_warning_groups_ignored_in_glm` and proceeds with the ungrouped
fit.

### 4.7 Error Table

| # | Function | Condition | Level | Error Class | Message Template |
|---|---|---|---|---|---|
| 1 | `survey_glm()` | `design` not a survey object | ERROR | `surveycore_error_unsupported_class` | Thrown by `.check_unsupported_class(design, "survey_glm")` — reuse Phase 1 definition. |
| 2 | `survey_glm()` | No model specified (`formula`, `response`, and `predictors` all NULL; or `predictors` non-NULL but `response` NULL) | ERROR | `surveycore_error_formula_missing` | `{.arg formula} is required.` (bare case) / `{.arg response} is required when using {.arg predictors}.` (`predictors`-without-`response` case) |
| 2a | `survey_glm()` | Both `formula` and `response`/`predictors` supplied | ERROR | `surveycore_error_formula_conflict` | `{.arg formula} and {.arg response}/{.arg predictors} are mutually exclusive. {.i Specify the model using either {.arg formula} or {.arg response}/{.arg predictors}, not both.}` |
| 3 | `survey_glm()` | `formula` not a formula | ERROR | `surveycore_error_formula_invalid` | `{.arg formula} must be a formula object, not {.cls {class(formula)[1]}}.` |
| 4 | `survey_glm()` | Response variable absent from `design@data` | ERROR | `surveycore_error_response_not_found` | `Response variable {.field {resp}} not found in survey data.` |
| 5 | `survey_glm()` | Predictor absent from `design@data` | ERROR | `surveycore_error_predictor_not_found` | `Predictor {.field {pred}} not found in survey data. Available columns: {.field {names(design@data)}}.` |
| 6 | `survey_glm()` | GLM did not converge | WARN | `surveycore_warning_glm_convergence` | `{.fn survey_glm} did not converge. {.i Increase {.arg control$maxit} or simplify the model.}` |
| 7 | `survey_glm()` | Response is a design variable | WARN | `surveycore_warning_response_is_design_var` | `Response variable {.field {resp}} is a design variable ({.field {role}}). Results may be misleading.` |
| 8 | `survey_glm()` | Perfect separation (binomial) | WARN | `surveycore_warning_perfect_separation` | `Fitted probabilities are numerically 0 or 1. Perfect or quasi-complete separation may have occurred.` |
| 9 | `survey_glm()` | Singular model matrix | ERROR | `surveycore_error_singular_model_matrix` | `Model matrix is singular. Check for perfect collinearity or empty factor levels.` |
| 10 | `survey_glm()` | `@groups` set on design | WARN | `surveycore_warning_groups_ignored_in_glm` | `{.fn survey_glm} does not support grouped designs. {.i The {.field @groups} property is ignored. Use {.fn surveytidy::group_by} after fitting to group results.}` |
| 11 | `survey_glm()` | Weight column contains `NA` | ERROR | `surveycore_error_na_weights` | `Weight column {.field {wt_var}} contains {sum(is.na(wt))} NA value(s). {.i Survey weights must be fully observed. Remove rows with missing weights or impute before calling {.fn survey_glm}.}` |
| 12 | `survey_glm()` | Active domain contains zero in-domain rows | ERROR | `surveycore_error_empty_domain` | `Active domain contains no in-domain rows. {.i Apply a less restrictive {.fn surveytidy::filter} before calling {.fn survey_glm}.}` |
| 13 | `survey_glm()` | Weight column contains zero or negative values | WARN | `surveycore_warning_nonpositive_weights` | `Weight column {.field {wt_var}} contains {sum(wt <= 0)} non-positive value(s). {.i Zero-weight rows are excluded from fitting by {.fn stats::glm}. Negative weights are statistically invalid.}` |

---

## V. S3 Methods on `survey_glm_fit`

S3 methods are registered in `.onLoad()` via `registerS3method()`, exactly as
surveytidy registers dplyr verbs. Per `code-style.md §2`, S3 dispatch does not
work for S7 objects via `UseMethod()`; dynamic registration is required.

All S3 method implementations are in `R/14-glm-methods.R`. Each method is a
plain function (named `print.survey_glm_fit`, etc.) with `@noRd`; it is not
exported directly but becomes available via the registered S3 method.

### 5.1 `print.survey_glm_fit(x, digits = 4, ...)`

Produces a lean header + coefficient estimates only — matching the convention
of `print.glm()` (which does not show standard errors or p-values). Users who
want the full inference table call `summary()`.

**Output format:**

```
Survey-weighted GLM

Family:  gaussian (identity link)
Formula: y ~ x1 + x2
Design:  Taylor series (NHANES-like)

Coefficients:
(Intercept)       x1       x2
      3.241    0.612   -0.023

Degrees of freedom: 18 (design-based)
```

Returns `invisible(x)`.

### 5.2 `summary.survey_glm_fit(object, ...)`

Produces the full inference table (Estimate, Std. Error, t value, Pr(>|t|))
plus the deviance block — matching the structure of `summary.glm()`, augmented
with design information. This is the primary output for inference; `print()`
is intentionally lean so there is a clear reason to call `summary()`.

**What `summary()` shows that `print()` does not:**

- The `Call:` block
- Deviance residuals summary (min, 1Q, median, 3Q, max) via `fivenum()`
- Full coefficient table with Std. Error, t value, Pr(>|t|), and significance
  stars
- Dispersion parameter
- Null deviance and residual deviance (with df)
- AIC
- Design df labeled with design type

Returns a `survey_glm_summary` S3 list, with a `print` method, for
compatibility with code that captures `summary()` output.

#### 5.2.1 `survey_glm_summary` Structure

`survey_glm_summary` is a named list with S3 class `"survey_glm_summary"`:

| Field | Type | Description |
|---|---|---|
| `coefficients` | `p × 4` named matrix | Columns: `"Estimate"`, `"Std. Error"`, `"t value"`, `"Pr(>|t|)"`. Row names are coefficient names. |
| `deviance` | numeric, length 1 | Residual deviance of the fitted model (`model@deviance`). |
| `null_deviance` | numeric, length 1 | Deviance of the intercept-only model (`model@null_deviance`). |
| `df_residual` | integer, length 1 | Design-based residual df (`model@df_residual`). |
| `df_null` | integer, length 1 | Null model df (`model@df_null`). |
| `dispersion` | numeric, length 1 | Dispersion parameter estimate (`σ̂²` for Gaussian; `1` for binomial/Poisson). |
| `family` | list | The GLM family object (`model@family`). |
| `call` | language or NULL | The `survey_glm()` call (`model@call`). |
| `design_type` | character, length 1 | One of `"taylor"`, `"replicate"`, `"srs"`, `"twophase"`, `"calibrated"`. |
| `degf` | numeric, length 1 | Design degrees of freedom (`model@degf`). |

#### 5.2.2 `print.survey_glm_summary()` Output Format

```
Survey-weighted GLM

Call:
survey_glm(design = d, formula = y ~ x1 + x2)

Deviance Residuals:
    Min      1Q  Median      3Q     Max
 -2.345  -0.612   0.021   0.589   2.234

Coefficients:
             Estimate Std. Error t value Pr(>|t|)
(Intercept)    3.241      0.184   17.61  < 2e-16 ***
x1             0.612      0.089    6.88  < 2e-16 ***
x2            -0.023      0.041   -0.56    0.581

(Dispersion parameter for gaussian family taken to be 1.234)

    Null deviance: 456.7 on 199 degrees of freedom (design-based)
Residual deviance: 321.4 on 181 degrees of freedom (design-based)
AIC: 892.3

Design df: 18 (taylor series)
```

Significance stars follow standard R convention (`***` < 0.001, `**` < 0.01,
`*` < 0.05, `.` < 0.1). Deviance residuals are computed from the working
residuals stored in `model@residuals` (five-number summary via `fivenum()`).
`print.survey_glm_summary()` returns `invisible(x)`.

### 5.3 `coef.survey_glm_fit(object, ...)`

Returns `object@coefficients` — the named numeric vector of coefficient
estimates. Same contract as `coef.glm()`.

### 5.4 `vcov.survey_glm_fit(object, ...)`

Returns `object@vcov` — the design-based `p × p` variance-covariance matrix.
Row and column names match `names(object@coefficients)`.

### 5.5 `predict.survey_glm_fit(object, new_data = NULL, type = "response", se_fit = FALSE, na_action = na.pass, ...)`

All argument names use snake_case. The mapping to `stats::predict.glm()`
arguments is: `new_data` → `newdata`, `se_fit` → `se.fit`,
`na_action` → `na.action`. `type` is the same in both.

Requires `object@fit_` to be non-`NULL`. Errors with
`surveycore_error_predict_no_fit` if `object@fit_` is `NULL` (e.g., after
deserialization that strips internal slots).

`type` controls the scale of predictions:

| `type` | Returns |
|---|---|
| `"response"` (default) | Fitted values on the response scale (probabilities for binomial, counts for Poisson, fitted means for Gaussian) |
| `"link"` | Values of the linear predictor |
| `"terms"` | Matrix of per-term contributions to the linear predictor |

`se_fit`: if `TRUE`, returns a named list instead of a plain vector:

| Component | Description |
|---|---|
| `$fit` | Predictions (same as when `se_fit = FALSE`) |
| `$se_fit` | Model-based standard errors of the predictions |
| `$residual_scale` | Residual standard deviation (square root of the dispersion) |

Note: `$se_fit` and `$residual_scale` use snake_case to match surveycore
conventions; base R names them `$se.fit` and `$residual.scale`. The
implementation renames these components after delegating to `stats::predict()`.

Predictions are always model-based, not design-based — same as
`survey::svyglm()`'s `predict` behavior.

> ⚠️ **GAP:** Survey-design-based prediction intervals (accounting for complex
> design variance in predictions) are not specified here. This is a Phase 3+
> feature.

### 5.6 `fitted.survey_glm_fit(object, ...)`

Returns `object@fitted_values`. Identical to `predict(object, newdata = NULL)`.

### 5.7 `residuals.survey_glm_fit(object, type = "response", ...)`

Returns residuals based on `type`:

| `type` | Returns |
|---|---|
| `"response"` | `y - fitted_values` (on response scale) |
| `"working"` | Working residuals from IRLS (`object@residuals`) |
| `"pearson"` | Delegates to `residuals(object@fit_, type = "pearson")` |
| `"deviance"` | Delegates to `residuals(object@fit_, type = "deviance")` |
| `"partial"` | Delegates to `residuals(object@fit_, type = "partial")` |

For `"pearson"`, `"deviance"`, and `"partial"`, `object@fit_` must be
non-`NULL`. If `object@fit_` is `NULL`, errors with
`surveycore_error_predict_no_fit` (same error class used by `predict()` for
the same condition).

### 5.8 `confint.survey_glm_fit(object, parm, level = 0.95, ...)`

Returns design-based confidence intervals using the survey variance stored in
`object@vcov` and the design df `object@df_residual`.

CIs are computed as:

```
estimate ± qt((1 + level) / 2, df = object@df_residual) * se
```

where `se = sqrt(diag(object@vcov)[parm])` for the requested parameters.

`parm`: coefficient names (character) or integer indices. If omitted, all
coefficients are returned. Same semantics as `stats::confint()`.

Returns a named numeric matrix with column names `paste0(100 * c((1 - level)/2, (1 + level)/2), " %")` (standard R convention, e.g. `"2.5 %"` and `"97.5 %"`), with row names equal to the coefficient names for the requested `parm`.

`level` must be in `(0, 1)`. Invalid `level` errors with
`surveycore_error_invalid_conf_level` (reuse Phase 1 definition).

This is the same CI formula used by `clean()` (Section 6.3). The two must
produce identical numerical results for equivalent `conf_level` / `level`
values.

### 5.9 `formula.survey_glm_fit(x, ...)`

Returns `x@formula` — the model formula stored in the S7 object. No delegation
to `x@fit_` is needed; the formula is stored directly as an S7 property.

### 5.10 `terms.survey_glm_fit(x, ...)`

Delegates to `terms(x@fit_)`. Returns the terms object from the fitted
`stats::glm()` result. Requires `x@fit_` to be non-`NULL`; errors with
`surveycore_error_predict_no_fit` if `NULL`.

### 5.11 `model.matrix.survey_glm_fit(object, ...)`

Delegates to `model.matrix(object@fit_)`. Returns the design matrix used in
the GLM fit. Requires `object@fit_` to be non-`NULL`; errors with
`surveycore_error_predict_no_fit`.

### 5.12 `model.frame.survey_glm_fit(formula, ...)`

First argument named `formula` per the base R `model.frame` generic convention.
Delegates to `model.frame(formula@fit_)`. Returns the model frame from the
GLM fit. Requires `formula@fit_` to be non-`NULL`; errors with
`surveycore_error_predict_no_fit`.

### 5.13 `deviance.survey_glm_fit(object, ...)`

Returns `object@deviance` — the residual deviance stored in the S7 object.
No `fit_` delegation needed.

### 5.14 `df.residual.survey_glm_fit(object, ...)`

Returns `object@df_residual` — the design-based residual degrees of freedom.
No `fit_` delegation needed.

### 5.15 `nobs.survey_glm_fit(object, ...)`

Returns `length(object@fitted_values)` — the number of observations used in
the fit. No `fit_` delegation needed.

### 5.16 `hatvalues.survey_glm_fit(model, ...)`

Delegates to `hatvalues(model@fit_)`. Returns model-based hat values
(leverages). Requires `model@fit_` to be non-`NULL`; errors with
`surveycore_error_predict_no_fit`.

**Note:** Hat values are model-based, not design-based. They reflect
observation leverage in the weighted GLM fit, not in the survey design.
This matches `survey::svyglm()` behavior.

### 5.17 `logLik.survey_glm_fit(object, ...)`

Delegates to `logLik(object@fit_)`. Returns the model-based log-likelihood.
Requires `object@fit_` to be non-`NULL`; errors with
`surveycore_error_predict_no_fit`.

**Note:** Log-likelihood is model-based, not design-adjusted. This matches
`survey::svyglm()` behavior.

### 5.18 `AIC.survey_glm_fit(object, ..., k = 2)` / `BIC.survey_glm_fit(object, ...)`

Both delegate to the corresponding base R function on `object@fit_` and are
model-based (not design-adjusted), consistent with `survey::svyglm()` behavior.

`AIC.survey_glm_fit`: delegates to `AIC(object@fit_, k = k)`.
`BIC.survey_glm_fit`: delegates to `BIC(object@fit_)`.

Both require `object@fit_` to be non-`NULL`; error with
`surveycore_error_predict_no_fit` if `NULL`.

### 5.19 `update.survey_glm_fit(object, formula., ...)`

Delegates to `stats::update.default()` via `getCall.survey_glm_fit()` which
returns `object@call`.

Requires `getCall.survey_glm_fit` to be registered as an S3 method on the
`stats::getCall` generic. Registration in `R/zzz.R` `.onLoad()`:

```r
registerS3method("getCall", "survey_glm_fit", getCall.survey_glm_fit,
                 envir = asNamespace("stats"))
```

where:

```r
getCall.survey_glm_fit <- function(x, ...) x@call
```

`stats::update.default()` uses `getCall()` to retrieve and modify the original
call, re-evaluating it to produce a new `survey_glm_fit` object. Requires
`object@call` to be non-`NULL`; if `NULL` (e.g., manually constructed object),
`stats::update.default()` will error naturally with a base R error.

---

## VI. `clean()` and `broom::tidy()` Compatibility

### 6.1 Decision: Both `clean()` and `broom::tidy.survey_glm_fit()`

**RECOMMENDED:** `clean()` is the surveycore-first function. It returns
`survey_glm_tidy`, a `survey_result` with full metadata (variable labels,
reference levels, design info via `.meta`).

`broom::tidy.survey_glm_fit()` is a thin compatibility shim, registered in
`.onLoad()` via `registerS3method("tidy", "survey_glm_fit", ...)`. It calls
`clean(model, ...)` and returns the same object. `broom` goes in `Suggests`
(not `Imports`). The shim is registered only when `broom` is installed —
checked in `.onLoad()` via `requireNamespace("broom", quietly = TRUE)`.

**Rationale:** `clean()` is the right name for surveycore's house style.
`broom::tidy()` compatibility ensures users familiar with the tidyverse
ecosystem can use it without learning a new function name. One implementation,
two access paths — DRY.

**Argument for Stage 2 to challenge:** Whether `broom::tidy.survey_glm_fit()`
should be in `Suggests` vs. not included at all (forcing users to use
`clean()` only). The counter-argument is API proliferation.

### 6.2 `clean()` Signature

```r
clean <- function(
  model,
  conf_level        = 0.95,
  include_reference = TRUE,
  n                 = FALSE,
  statistic         = TRUE,
  exponentiate      = FALSE,
  interaction_sep   = " * ",
  ...
)
```

| Argument | Type | Default | Description |
|---|---|---|---|
| `model` | `survey_glm_fit` | — | A fitted survey GLM object from `survey_glm()`. |
| `conf_level` | numeric, length 1 | `0.95` | Confidence level for CIs. Must be in `(0, 1)`. |
| `include_reference` | logical | `TRUE` | If `TRUE`, reference levels for factor predictors are included as rows with `estimate = NA` and all other statistic columns `NA`. No effect for ordered factors or no-intercept models (which have no reference level). |
| `n` | logical | `FALSE` | If `TRUE`, adds an `n_obs` column with the unweighted observation count per term. |
| `statistic` | logical | `TRUE` | If `TRUE`, includes the `statistic` (t-statistic) column. Set to `FALSE` to drop it from the output. |
| `exponentiate` | logical | `FALSE` | If `TRUE`, exponentiates `estimate`, `conf_low`, and `conf_high`. Useful for logistic regression (odds ratios) and Poisson regression (rate ratios). `std_error` is left on the log scale (matching `broom` convention). Fires `surveycore_warning_exponentiate_nonlog` when the model's link function is not log-based. |
| `interaction_sep` | character, length 1 | `" * "` | Separator used when constructing the `label` for interaction terms by joining component labels (e.g. `"Age * Male"`). |
| `...` | — | — | Currently unused; reserved for future arguments. |

### 6.3 Output Contract

#### Column structure

| Column | Type | Present when | Description |
|---|---|---|---|
| `term` | character | always | Coefficient name from the model matrix (e.g. `"(Intercept)"`, `"x1"`, `"sexMale"`). Reference rows use the bare factor-level term (e.g. `"sexFemale"`); reference information is encoded in `reference_row`, not in a `[ref]` suffix. |
| `variable` | character | always | Parent variable name. For bare variables: the column name (e.g. `"sex"`). For interaction terms: component variables joined by `":"` (e.g. `"age:sex"`). For transformation/spline terms: the full expression with any numeric suffix stripped (e.g. `"poly(age, 2)"`, `"ns(age, df = 3)"`). For ordered factor polynomial contrasts: the variable name without the `.L`/`.Q`/`.C` suffix. For `(Intercept)`: `"(Intercept)"`. |
| `var_label` | character | always | Variable label for the parent variable from `design@metadata`. Falls back to the variable name if no label is set. `NA` for interaction terms, transformation terms, and `(Intercept)`. |
| `label` | character | always | Display-ready term label for use in tables and plots. For continuous variables: same as `var_label`. For factor levels (including reference rows): value label from `design@metadata` if set, otherwise the level name recovered from the model frame — find level `l` such that `paste0(var_name, l) == coef_name` from `levels(model_frame[[var_name]])`. Do not use string prefix removal (`sub()`) — it is fragile when the variable name is a prefix of a level name. This is consistent with the reference-level detection algorithm already specified for `reference_row`. For interaction terms: component labels joined by `interaction_sep` (e.g. `"Age in years * Male"`). For transformation/spline terms (`log()`, `I()`, `poly()`, `ns()`, etc.): the raw term name kept as-is. For `(Intercept)`: `"(Intercept)"`. Never `NA`. |
| `reference_row` | logical | always | `TRUE` if this row is a reference level row added by `include_reference = TRUE`; `FALSE` otherwise. Reference level is the factor level absent from the contrasts matrix: `setdiff(levels(model_frame[[var]]), colnames(contrasts(model_frame[[var]])))`. Always `FALSE` for ordered factors and no-intercept models (which have no reference level). |
| `estimate` | double | always | Coefficient estimate. When `exponentiate = TRUE`: `exp(estimate)`. `NA` for reference rows. |
| `std_error` | double | always | Design-based standard error. Always on the log scale even when `exponentiate = TRUE` (matching `broom` convention). `NA` for reference rows. |
| `statistic` | double | `statistic = TRUE` | t-statistic (`estimate / std_error`, computed before any exponentiation). `NA` for reference rows. |
| `p_value` | double | always | Two-sided p-value from t-distribution with `degf - (p - 1)` df. Computed on the log scale; unaffected by `exponentiate`. `NA` for reference rows. |
| `conf_low` | double | always | Lower CI bound at `conf_level`. When `exponentiate = TRUE`: `exp(conf_low)`. `NA` for reference rows. |
| `conf_high` | double | always | Upper CI bound at `conf_level`. When `exponentiate = TRUE`: `exp(conf_high)`. `NA` for reference rows. |
| `n_obs` | integer | `n = TRUE` | Unweighted observation count for this term. For continuous and transformation terms: count of non-`NA` observations. For factor levels (including reference rows): count of observations in that level. For interaction terms: count of non-`NA` observations in the intersection of all component levels. |

CIs are computed as `estimate ± qt((1 + conf_level)/2, df = df_residual) * std_error` (before any exponentiation).

#### S3 class hierarchy

```r
c("survey_glm_tidy", "survey_result", "tbl_df", "tbl", "data.frame")
```

`survey_glm_tidy` is a `survey_result`. This requires Phase 1 to be complete
(Phase 1 defines the `survey_result` base class in `R/09-meta.R`).

#### `.meta` attribute

Accessed via `meta(result)` (Phase 1's `meta()` generic). All keys always
present; unset values `NULL`, never absent.

| Key | Type | Description |
|---|---|---|
| `formula` | formula | The model formula |
| `family` | character | Family name, e.g. `"gaussian"` |
| `link` | character | Link function name, e.g. `"identity"` |
| `design_type` | character | One of `"taylor"`, `"replicate"`, `"srs"`, `"twophase"`, `"calibrated"` — same mapping as Phase 1 `.build_meta()` |
| `conf_level` | numeric | The `conf_level` argument |
| `call` | language | The `clean()` call |
| `group_names` | character | Always `character(0)` (regression does not have groups) |
| `group_labels` | NULL | Always `NULL` |
| `n_observations` | integer | Unweighted row count after domain filtering and `na.action`; equals `nrow(model.matrix(fit))` from the `stats::glm()` result |
| `n_weighted` | numeric | Sum of survey weights for in-model observations (after `na.action`) |
| `degf` | numeric | Design degrees of freedom (`model@degf`) |
| `exponentiate` | logical | The `exponentiate` argument value |
| `include_reference` | logical | The `include_reference` argument value |
| `converged` | logical | Whether the GLM converged (`model@converged`) |
| `variables` | named list | Per-variable metadata; one entry per predictor variable in the model formula (see below). Keyed by variable name. Does not include entries for `(Intercept)`, interaction terms, or transformation expressions. |

#### `$variables` structure

Each entry in `meta(result)$variables` is keyed by the bare variable name
(e.g. `"sex"`, `"age"`) and contains:

| Sub-key | Type | Description |
|---|---|---|
| `var_label` | character | Variable label from `design@metadata`; falls back to the variable name if not set. Never `NULL`. |
| `var_class` | character | R class of the column in the model frame: `"numeric"`, `"factor"`, `"ordered"`, etc. |
| `var_type` | character | One of `"continuous"`, `"categorical"`, `"ordered"` |
| `var_nlevels` | integer or NULL | Number of factor levels; `NULL` for continuous variables |
| `contrasts` | character or NULL | Contrast function name (e.g. `"contr.treatment"`, `"contr.helmert"`); `NULL` for continuous variables |
| `reference_level` | character or NULL | The reference level name for unordered factors with treatment contrasts; `NULL` for continuous variables and ordered factors |
| `value_labels` | named character or NULL | Named vector of value labels from `design@metadata` (e.g. `c(Female = "Female", Male = "Male")`); `NULL` if no value labels are set on this variable |

`$variables` replaces the flat `variable_labels` key from Phase 1 `survey_result`
objects. The `variable_labels` key is **not** present in `survey_glm_tidy`
`.meta`; downstream code must use `meta(result)$variables[[var]]$var_label`
instead. This is an intentional deviation from the Phase 1 `.meta` contract,
providing richer per-variable structure needed by `plot()`, `table()`, and
export methods.

Use `test_glm_tidy_invariants()` (Section 9.3) instead of
`test_result_invariants()` for `survey_glm_tidy` objects.

### 6.4 `broom::tidy.survey_glm_fit()` wrapper

```r
# In R/14-glm-clean.R — not exported; registered dynamically
tidy.survey_glm_fit <- function(x, conf.int = TRUE, conf.level = 0.95,
                                exponentiate = FALSE, ...) {
  clean(
    model        = x,
    conf_level   = conf.level,
    exponentiate = exponentiate,
    ...
  )
}
```

Note `conf.level` (broom convention, period separator) vs. `conf_level`
(surveycore convention, underscore). `exponentiate` uses the same name in
both broom and surveycore.

`include_reference = TRUE` is always used in the broom wrapper (broom users
expect full factor structures). This is not configurable via `broom::tidy()`.

Registration in `R/zzz.R` `.onLoad()`:

```r
if (requireNamespace("broom", quietly = TRUE)) {
  registerS3method("tidy", "survey_glm_fit", tidy.survey_glm_fit,
                   envir = asNamespace("broom"))
}
```

### 6.5 `clean()` Error Table

| # | Condition | Level | Error Class | Message Template |
|---|---|---|---|---|
| 1 | `model` not a `survey_glm_fit` | ERROR | `surveycore_error_not_glm_fit` | `{.arg model} must be a {.cls survey_glm_fit} object, not {.cls {class(model)[1]}}.` |
| 2 | `conf_level` invalid | ERROR | `surveycore_error_invalid_conf_level` | Reuse Phase 1 definition. |
| 3 | `exponentiate = TRUE` and link is not log-based | WARN | `surveycore_warning_exponentiate_nonlog` | `{.arg exponentiate = TRUE} with a non-log link ({.val {model@family$link}}) may produce uninterpretable estimates.` |

### 6.6 `print()` for `survey_glm_tidy`

No custom `print.survey_glm_tidy()` method is defined in Phase 2.
`print(clean(fit))` inherits `print.survey_result()` from Phase 1
(`R/analysis-meta.R`), which prints a surveycore-style header then delegates
to tibble:

```
# A <survey_glm_tidy> [4 × 11]
  term        variable    var_label   label       reference_row estimate std_error statistic p_value conf_low conf_high
  <chr>       <chr>       <chr>       <chr>       <lgl>            <dbl>     <dbl>     <dbl>   <dbl>    <dbl>     <dbl>
1 (Intercept) (Intercept) (Intercept) (Intercept) FALSE             1.24      0.33      3.76   0.001     0.59      1.89
2 age         age         Age         Age         FALSE             0.05      0.01      4.28   0.000     0.03      0.07
3 sexFemale   sex         Sex         Female      TRUE                NA        NA        NA      NA       NA        NA
4 sexMale     sex         Sex         Male        FALSE            -0.18      0.12     -1.48   0.135    -0.42      0.06
```

Example: `y ~ age + sex`, value labels set on `sex`, default `clean()`
arguments (`include_reference = TRUE`, `statistic = TRUE`, `n = FALSE`).

**No Phase 2 registration needed:** `survey_glm_tidy` inherits
`print.survey_result()` automatically via S3 class dispatch. A snapshot test
of `print(clean(fit))` is required in `test-glm-methods.R` (Section 9.2,
item 17).

---

## VII. marginaleffects Extension Interface

### 7.1 Overview and Motivation

`survey_glm_fit` implements the marginaleffects extension interface, enabling
`marginaleffects::avg_slopes()`, `marginaleffects::avg_predictions()`, and the
full marginaleffects API to work natively on survey-weighted GLM fits.

Rather than implementing average marginal effect computation inside surveycore,
Phase 2 implements the four S3 generics that marginaleffects dispatches through.
This gives users the full marginaleffects function suite — including subgroup
analyses, comparisons, and plotting — on `survey_glm_fit` objects while keeping
surveycore's scope on the model class itself.

`marginaleffects` is added to `Suggests` (not `Imports`). The extension methods
are registered conditionally in `.onLoad()`. All core `survey_glm_fit`
functionality (`clean()`, all 20 S3 methods, the variance engine) is fully
usable without marginaleffects installed.

### 7.2 Registration

Four methods are registered in `R/zzz.R` `.onLoad()`, conditionally on
marginaleffects being installed:

```r
if (requireNamespace("marginaleffects", quietly = TRUE)) {
  registerS3method("get_coef",    "survey_glm_fit", get_coef.survey_glm_fit,
                   envir = asNamespace("marginaleffects"))
  registerS3method("set_coef",    "survey_glm_fit", set_coef.survey_glm_fit,
                   envir = asNamespace("marginaleffects"))
  registerS3method("get_vcov",    "survey_glm_fit", get_vcov.survey_glm_fit,
                   envir = asNamespace("marginaleffects"))
  registerS3method("get_predict", "survey_glm_fit", get_predict.survey_glm_fit,
                   envir = asNamespace("marginaleffects"))
}
```

Implementation lives in `R/14-glm-marginaleffects.R`. None of the four methods
are exported; all are registered dynamically.

### 7.3 `get_coef.survey_glm_fit(model, ...)`

Returns the named coefficient vector. Direct delegation to the S7 property:

```r
get_coef.survey_glm_fit <- function(model, ...) {
  model@coefficients
}
```

Returns a named numeric vector of length `p`.

### 7.4 `set_coef.survey_glm_fit(model, coefs, ...)`

Returns a modified copy of `model` with coefficients replaced by `coefs`. Used
internally by marginaleffects for numerical differentiation during delta method
gradient computation.

**Both the S7 property and the internal `fit_` object must be updated:**

```r
set_coef.survey_glm_fit <- function(model, coefs, ...) {
  model@coefficients <- coefs
  if (!is.null(model@fit_)) {
    model@fit_$coefficients <- coefs
  }
  model
}
```

**Why `fit_` must be patched:** `predict.survey_glm_fit` delegates to
`stats::predict.glm(object@fit_)`. `stats::predict.glm()` reads coefficients
from `fit$coefficients`, not from the S7 `@coefficients` property. Without
patching `fit_`, predictions during marginaleffects' gradient evaluation would
ignore the perturbed coefficients and every AME would silently equal zero.

**Validity:** `set_coef` bypasses the S7 validator. The perturbed object it
returns is not a valid `survey_glm_fit` for inference — its `@vcov` is stale
relative to the new `@coefficients`. This is correct: the perturbed object is
used only during marginaleffects' internal numerical differentiation, never
returned to users.

### 7.5 `get_vcov.survey_glm_fit(model, ...)`

Returns the design-based variance-covariance matrix. Direct delegation:

```r
get_vcov.survey_glm_fit <- function(model, ...) {
  model@vcov
}
```

Returns a named `p × p` numeric matrix. Row and column names match
`names(model@coefficients)`.

### 7.6 `get_predict.survey_glm_fit(model, newdata, ...)`

Returns predictions as a data frame with columns `rowid` (integer) and
`estimate` (numeric). This satisfies the marginaleffects prediction contract.

```r
get_predict.survey_glm_fit <- function(model, newdata, ...) {
  pred <- predict(model, new_data = newdata, type = "response")
  data.frame(
    rowid    = seq_len(nrow(newdata)),
    estimate = as.numeric(pred)
  )
}
```

`type = "response"` is always used: marginaleffects operates on the response
scale (probabilities for binomial, counts for Poisson, means for Gaussian).

Requires `model@fit_` to be non-`NULL`. If `fit_` is `NULL` (e.g., after
deserialization), errors with `surveycore_error_predict_no_fit` — the same
error class used by `predict.survey_glm_fit` for the same condition.

### 7.7 Testing

Extension tests live in `tests/testthat/test-glm-marginaleffects.R`. All
blocks use `skip_if_not_installed("marginaleffects")`.

**Test items:**

1. **`get_coef()`** — returns `fit@coefficients` (`expect_identical`, not just
   `expect_equal`).
2. **`get_vcov()`** — returns `fit@vcov` (`expect_identical`).
3. **`set_coef()` — S7 property updated** — returned object has modified
   `@coefficients` matching the supplied vector.
4. **`set_coef()` — `fit_` patched** — returned object's `fit_$coefficients`
   matches the supplied vector.
5. **`set_coef()` — original unchanged** — the original `fit` object is
   unmodified after `set_coef()` (R copy-on-modify semantics; no mutation).
6. **`get_predict()`** — returns a data frame with `rowid` and `estimate`
   columns; `nrow(result) == nrow(newdata)`.
7. **`avg_slopes()` — Gaussian** — `marginaleffects::avg_slopes(fit)` AME for
   a continuous predictor matches the OLS coefficient within `1e-6` (for
   Gaussian identity link the AME equals the coefficient exactly).
8. **`avg_slopes()` — binomial** — result is on the probability scale (values
   in `(-1, 1)`); estimate differs from the log-odds coefficient.
9. **`avg_predictions()`** — `marginaleffects::avg_predictions(fit)` returns a
   data frame; `estimate` values are in `[0, 1]` for binomial family.
10. **`get_predict()` with `fit_` = NULL** — errors with
    `surveycore_error_predict_no_fit`.

---

## VIII. Variance Estimation

### 8.1 Architectural Principle: Reuse Phase 0 Machinery

`survey_glm()` does **not** introduce new vendored variance code. Instead, it
computes the GLM score vectors (Section 2.2, `.glm_score()`) and then passes
them to the existing Phase 0 variance machinery:

| Design class | Variance dispatch |
|---|---|
| `survey_taylor` | `.glm_score()` → existing Taylor variance function in `R/06-variance-taylor.R` |
| `survey_replicate` | Refit GLM per replicate → weighted sum of squared coefficient deviations |
| `survey_srs` | Weighted OLS sandwich: `σ̂² (X'WX)⁻¹` |
| `survey_twophase` | `.glm_score()` → existing two-phase variance function in `R/06-variance-twophase.R` |
| `survey_calibrated` | Falls back to SRS sandwich (conservative) |

This is an architecture decision: the Binder (1983) sandwich estimator
decomposes cleanly into (a) score computation and (b) design-based variance
of the score. Step (b) is already implemented in Phase 0.

Dispatch uses an if/else chain with `S7::S7_inherits()`, following the
pattern in `R/06-variance-dispatch.R`. No S7 method dispatch or switch
statement.

**Validation:** All variance paths must produce numerical results matching
`survey::svyglm()` within the tolerance specified in Section VIII.

### 8.2 Taylor Series Variance (Binder 1983)

The design-based variance of β̂ is:

```
Var(β̂) = I⁻¹ · Var_design(T) · I⁻¹
```

where:
- `I = (1/n) X'WX` is the (rescaled) information matrix
- `T = Σ_i u_i` is the total score vector
- `u_i = w_i x_i e_i` is the score contribution for observation `i`
- `e_i` is the working residual from the GLM IRLS
- `Var_design(T)` is computed by applying Taylor linearization to the `n × p`
  score matrix, treating each column as a survey-weighted total to be estimated

The implementation passes the `n × p` score matrix to the existing Taylor
variance function as if computing `p` weighted totals simultaneously.

### 8.3 Replicate Weights Variance

For each replicate weight set `r = 1, ..., R`:

1. Refit `stats::glm(formula, family, data, weights = repweights_r)` to obtain
   `β̂_r`
2. Compute deviation: `d_r = β̂_r - β̂` (full-sample estimate)
3. Apply replicate scale: `Var(β̂) = Σ_r c_r d_r d_r'`

where `c_r` are the design-specific replicate scale factors stored in
`design@variables`. This reuses the same scale factor structure as Phase 0
replicate variance.

**Performance note:** Refitting the full GLM `R` times is expensive for large
`R` (e.g., 160 bootstrap replicates). No optimization is specified in Phase 2;
performance improvements are Phase 3+.

### 8.4 SRS Variance

Weighted OLS formula:

```
Var(β̂) = σ̂² · (X'WX)⁻¹
```

where `σ̂²` is the survey-weighted mean squared residual:

```
σ̂² = Σ_i w_i e_i² / (n - p)
```

This follows from the general Binder sandwich `I⁻¹ · Var_design(T) · I⁻¹`
when `Var_design(T) = σ̂² (X'WX)` for iid equal-probability observations (SRS
case). The `survey_calibrated` path uses the same formula (conservative
approximation — see Section I).

### 8.5 Design Degrees of Freedom

`degf(design)` computes the design degrees of freedom used for t-tests and CIs:

| Class | Formula |
|---|---|
| `survey_taylor` | Number of unique PSUs − number of unique strata |
| `survey_replicate` | Derived from replicate type (see `survey::degf()` for reference) |
| `survey_srs` | `nrow(design@data) − 1` |
| `survey_twophase` | Phase-1 design degrees of freedom |
| `survey_calibrated` | Same as `survey_srs` |

`.degf()` always uses the full design (all rows), not the in-domain subset.
This is consistent with the domain estimation contract in Section 4.5:
variance estimation uses the full design regardless of domain membership.

GLM residual df for t-tests: `degf(design) − (p − 1)` where `p` is the number
of coefficients including the intercept.

If `df_residual` would be ≤ 0 (e.g., design with 2 PSUs and a model with 3+
coefficients), warn with `surveycore_warning_insufficient_df` and clamp
`df_residual = 1`. The resulting CI bounds and p-values are conservative but
well-defined (no `NaN`). This matches `survey::svyglm()`'s fallback behavior.

---

## IX. Testing Strategy

### 9.1 File Structure and Oracle Tests

Numerical oracle tests live in `test-glm-numerical.R` and always call
`skip_if_not_installed("survey")`. marginaleffects extension tests live in
`test-glm-marginaleffects.R` (see Section 7.7 for test items); all blocks call
`skip_if_not_installed("marginaleffects")`.

**Oracle function:** `survey::svyglm(formula, design = svydesign_obj, family)`

**Numerical tolerances** (same as Phase 0 / Phase 1):

| Estimand | Tolerance |
|---|---|
| Coefficients (point estimates) | `1e-10` |
| Standard errors | `1e-8` |
| CI bounds | `1e-6` |

**Oracle datasets:**

| Design class | Dataset |
|---|---|
| `survey_taylor` | `nhanes_2017` with `sdmvpsu`, `wtmec2yr`, `sdmvstra` |
| `survey_replicate` | `acs_pums_wy` |
| `survey_srs` | Synthetic from `make_survey_data(design = "srs", seed = 42)` |
| `survey_twophase` | Synthetic from `make_survey_data(design = "twophase", seed = 42)` |
| `survey_calibrated` | Synthetic from `make_survey_data(seed = 42)`, calibrated via `survey::calibrate()` then converted with `from_svydesign()` |

**Oracle test structure for each design class:**

The Taylor template is shown in full below. The replicate, SRS, twophase, and
calibrated oracle tests follow the same structure; substitute the appropriate
design constructor, oracle dataset from the table above, and a relevant model
formula.

```r
test_that("survey_glm() coefficients match svyglm() for Taylor design [numerical]", {
  skip_if_not_installed("survey")
  d_sc <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr,
                    strata = sdmvstra, nest = TRUE)
  d_sv <- survey::svydesign(ids = ~sdmvpsu, weights = ~wtmec2yr,
                             strata = ~sdmvstra, data = nhanes_2017, nest = TRUE)
  fit_sc <- survey_glm(d_sc, bpxsy1 ~ ridageyr + riagendr, family = gaussian())
  fit_sv <- survey::svyglm(bpxsy1 ~ ridageyr + riagendr, design = d_sv, family = gaussian())

  expect_equal(coef(fit_sc), coef(fit_sv),                  tolerance = 1e-10)
  expect_equal(sqrt(diag(vcov(fit_sc))), SE(fit_sv),         tolerance = 1e-8)
})

test_that("survey_glm() programmatic interface matches formula interface [numerical]", {
  skip_if_not_installed("survey")
  d_sc <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr,
                    strata = sdmvstra, nest = TRUE)
  fit_formula     <- survey_glm(d_sc, bpxsy1 ~ ridageyr + riagendr,
                                family = gaussian())
  fit_programmatic <- survey_glm(d_sc,
                                 response   = "bpxsy1",
                                 predictors = c("ridageyr", "riagendr"),
                                 family     = gaussian())

  expect_equal(coef(fit_formula), coef(fit_programmatic),          tolerance = 1e-15)
  expect_equal(vcov(fit_formula),  vcov(fit_programmatic),          tolerance = 1e-15)
})
```

**Family coverage for oracle tests:**

All 8 GLM families supported by `stats::glm()` and `survey::svyglm()` require
oracle tests against `survey::svyglm()`. Binomial is the most critical: for
`gaussian(link = "identity")` the working residuals equal response residuals so
a wrong residual type in the sandwich is invisible; binomial (and Poisson) are
the only way to catch that class of bug.

All family oracle tests use the Taylor design. `nhanes_2017` is the dataset for
all families except Poisson and quasipoisson (which require integer count data).

| Family | Response variable | Dataset | Notes |
|---|---|---|---|
| `gaussian(link = "identity")` | `bpxsy1` | `nhanes_2017` | Baseline; template above |
| `binomial(link = "logit")` | `I(bpxsy1 > 130)` (0/1 hypertension) | `nhanes_2017` | Critical sandwich validation path |
| `Gamma(link = "inverse")` | `bpxsy1` (always positive) | `nhanes_2017` | |
| `inverse.gaussian(link = "1/mu^2")` | `bpxsy1` (strictly positive) | `nhanes_2017` | |
| `quasi(link = "identity", variance = "constant")` | `bpxsy1` | `nhanes_2017` | Quasi-Gaussian |
| `quasibinomial(link = "logit")` | `I(bpxsy1 > 130)` | `nhanes_2017` | Same response as binomial |
| `poisson(link = "log")` | `y_count` — see template | `make_survey_data(seed = 42)` | Integer count response; see template |
| `quasipoisson(link = "log")` | `y_count` — same as Poisson | `make_survey_data(seed = 42)` | |

**Binomial oracle template** (most important non-Gaussian case):

```r
test_that("survey_glm() matches svyglm() for binomial family [numerical]", {
  skip_if_not_installed("survey")
  d_sc <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtmec2yr,
                    strata = sdmvstra, nest = TRUE)
  d_sv <- survey::svydesign(ids = ~sdmvpsu, weights = ~wtmec2yr,
                            strata = ~sdmvstra, data = nhanes_2017, nest = TRUE)
  # survey::svyglm() is called with quasibinomial() to suppress the
  # "non-integer successes" warning from fractional survey weights.
  # Coefficients and SEs are identical to binomial() — the Binder sandwich
  # does not depend on the dispersion parameter.
  fit_sc <- survey_glm(d_sc, I(bpxsy1 > 130) ~ ridageyr + riagendr,
                       family = binomial(link = "logit"))
  fit_sv <- survey::svyglm(I(bpxsy1 > 130) ~ ridageyr + riagendr,
                           design = d_sv,
                           family = quasibinomial(link = "logit"))

  expect_equal(coef(fit_sc), coef(fit_sv),           tolerance = 1e-10)
  expect_equal(sqrt(diag(vcov(fit_sc))), SE(fit_sv),  tolerance = 1e-8)
})
```

**Poisson oracle template** (integer count response using synthetic data):

```r
test_that("survey_glm() matches svyglm() for Poisson family [numerical]", {
  skip_if_not_installed("survey")
  df        <- make_survey_data(n = 300, seed = 42)
  set.seed(42)
  df$y_count <- rpois(nrow(df), lambda = exp(0.3 * df$y1 + 0.5))
  d_sc <- as_survey(df, ids = psu, weights = weight, strata = strata)
  d_sv <- survey::svydesign(ids = ~psu, weights = ~weight, strata = ~strata,
                            data = df, nest = TRUE)
  fit_sc <- survey_glm(d_sc, y_count ~ y1 + y2, family = poisson(link = "log"))
  fit_sv <- survey::svyglm(y_count ~ y1 + y2, design = d_sv,
                           family = poisson(link = "log"))

  expect_equal(coef(fit_sc), coef(fit_sv),           tolerance = 1e-10)
  expect_equal(sqrt(diag(vcov(fit_sc))), SE(fit_sv),  tolerance = 1e-8)
})
```

The `Gamma`, `inverse.gaussian`, `quasi`, and `quasibinomial` oracle tests
follow the binomial template structure above, substituting the appropriate
family, response variable, and dataset from the table.

Additionally, `test-glm-numerical.R` includes a test block verifying that
`.degf()` matches `survey::degf()` for each of the five supported design
classes. This validates the degrees-of-freedom computation used for t-tests
and CIs across all variance paths. The block uses `skip_if_not_installed("survey")`
and calls `.degf(d_sc)` vs `survey::degf(d_sv)` for Taylor, replicate, SRS,
twophase, and calibrated designs.

### 9.2 Per-Function Test Categories

**`test-glm.R`** covers `survey_glm()` and `clean()`:

1. **Happy path** — basic call produces a valid `survey_glm_fit`; verify key
   properties (coefficients length, vcov dimension, converged = TRUE,
   degf > 0).
2. **`clean()` happy path** — produces correct class hierarchy; all required
   columns present including `variable`, `var_label`, `label`, `reference_row`;
   `test_glm_tidy_invariants()` passes (Section 9.3).
3. **`clean()` reference levels** — factor predictor with `include_reference = TRUE`
   has a row with `reference_row = TRUE` and `estimate = NA`; with
   `include_reference = FALSE` no row has `reference_row = TRUE`.
4. **`clean()` `.meta` contract** — all top-level keys present, `$variables`
   present with one entry per predictor, `formula` matches original,
   `n_observations` equals number of non-NA rows, `n_weighted` is numeric and
   positive.
5. **Variable label integration** — when design has variable labels set on
   predictors, `meta(clean(fit))$variables[[var]]$var_label` contains those
   labels; `var_label` column in the tibble shows the labels; `label` column
   shows value labels for factor levels when set.
5a. **`n` argument** — `clean(fit, n = TRUE)` adds `n_obs` column;
    `clean(fit, n = FALSE)` (default) does not.
5b. **`statistic` argument** — `clean(fit, statistic = FALSE)` drops the
    `statistic` column; `statistic = TRUE` (default) includes it.
5c. **`exponentiate` argument** — `clean(fit, exponentiate = TRUE)` on a
    logistic fit: `estimate` equals `exp(coef(fit))` within tolerance;
    `std_error` is unchanged; fires `surveycore_warning_exponentiate_nonlog`
    when link is not log-based.
5d. **`interaction_sep` argument** — `clean(fit, interaction_sep = " × ")`
    produces `label` for interaction terms using `" × "` as separator.
6. **`broom::tidy()` compatibility** — `broom::tidy(fit)` returns same object
   as `clean(fit)` (`skip_if_not_installed("broom")`).
7. **Programmatic interface** — `response = "y", predictors = c("x1", "x2")`
   produces coefficients identical to `formula = y ~ x1 + x2`; `response = "y"`
   alone produces an intercept-only model; `response` without `predictors`
   (NULL) and `predictors` without `response` each fire typed errors.
8. **Error paths** — every row in Sections 4.7 and 6.5 error tables. User-facing
   constructor errors (Layer 3) use the dual pattern:
   `expect_error(class = "surveycore_error_...")` + `expect_snapshot(error = TRUE)`.
   S7 validator errors (Section 3.3, Layer 1) use `class=` only — no snapshot.
   Per `testing-surveycore.md §S7 error testing layers`.
9. **Convergence warning** — force non-convergence; verify
   `surveycore_warning_glm_convergence` fires and fit is still returned.
10. **`@groups` warning** — group_by() design triggers
    `surveycore_warning_groups_ignored_in_glm`.
11. **Domain estimation oracle** — `surveytidy::filter()` domain produces
    coefficients and SEs matching `survey::svyglm(..., subset = domain_indicator)`
    within standard tolerances (1e-10 point, 1e-8 SE). Uses `nhanes_2017`.
    `skip_if_not_installed("survey")` + `skip_if_not_installed("surveytidy")`.
    Validates the zero-score mechanism specified in Section 4.5.
12. **S7 validator errors** — one `test_that()` block per condition in Section
    3.3 (7 conditions: empty `coefficients`; wrong `vcov` dimensions; empty
    `fitted_values`; `residuals` length mismatch; `weights` length mismatch;
    `degf` not positive length-1; `formula` non-formula object). Each uses
    `expect_error(class = ...)` only — no snapshot, per `testing-surveycore.md`
    Layer 1 error pattern.

**`test-glm-methods.R`** covers S3 methods:

1. **`print()`** — output matches expected format (snapshot); returns
   `invisible(x)`.
2. **`summary()`** — produces output (structural, not numerical); returns
   `survey_glm_summary` class.
3. **`coef()`** — returns named numeric vector identical to
   `fit@coefficients`.
4. **`vcov()`** — returns matrix with correct row/col names.
5. **`predict(newdata = NULL)`** — returns fitted values.
6. **`predict(newdata = df)`** — returns numeric vector of correct length.
7. **`predict(newdata = df)` with NULL `fit_`** — errors with
   `surveycore_error_predict_no_fit`.
8. **`fitted()`** — returns same as `predict(newdata = NULL)`.
9. **`residuals(type = "response")`** — returns `y - fitted`.
10. **`residuals(type = "working")`** — returns `fit@residuals`.
11. **`residuals(type = "pearson")`** — delegates to `object@fit_`; verifies
    values differ from working residuals for binomial family.
12. **`residuals(type = "deviance")`** — delegates to `object@fit_`; verifies
    values differ from response residuals for non-Gaussian family.
13. **`residuals(type = "partial")`** — delegates to `object@fit_`; returns
    matrix with one column per predictor.
14. **`residuals(type = "pearson")` with `fit_` = NULL** — errors with
    `surveycore_error_predict_no_fit` (dual pattern: `class=` +
    `expect_snapshot(error = TRUE)`).
15. **`residuals(type = "deviance")` with `fit_` = NULL** — errors with
    `surveycore_error_predict_no_fit` (dual pattern).
16. **`residuals(type = "partial")` with `fit_` = NULL** — errors with
    `surveycore_error_predict_no_fit` (dual pattern).
17. **`clean()` happy path** — snapshot of `print(clean(fit))` output matches
    expected format (Section 6.6); result class is `c("survey_glm_tidy",
    "survey_result", "tbl_df", "tbl", "data.frame")`; `test_glm_tidy_invariants()`
    passes.
18. **`confint()` happy path** — returns matrix with correct row and column
    names; bounds match manual `estimate ± qt((1 + conf_level)/2, df_residual) * std_error`.
19. **`confint()` invalid `level`** — errors with
    `surveycore_error_invalid_conf_level` (dual pattern).
20. **`formula()` happy path** — returns `object@formula`; identical to the
    formula passed to `survey_glm()`.
21. **`terms()` happy path** — returns same object as `terms(object@fit_)`.
22. **`terms()` with `fit_` = NULL** — errors with
    `surveycore_error_predict_no_fit` (dual pattern).
23. **`model.matrix()` happy path** — returns matrix with correct dimensions
    (rows = n_observations, columns = p).
24. **`model.matrix()` with `fit_` = NULL** — errors with
    `surveycore_error_predict_no_fit` (dual pattern).
25. **`model.frame()` happy path** — returns data frame with the correct
    columns for the model formula.
26. **`model.frame()` with `fit_` = NULL** — errors with
    `surveycore_error_predict_no_fit` (dual pattern).
27. **`deviance()` happy path** — returns `object@deviance`.
28. **`df.residual()` happy path** — returns `object@df_residual`.
29. **`nobs()` happy path** — returns `length(object@fitted_values)`.
30. **`hatvalues()` happy path** — returns numeric vector of length
    n_observations; matches `hatvalues(object@fit_)`.
31. **`hatvalues()` with `fit_` = NULL** — errors with
    `surveycore_error_predict_no_fit` (dual pattern).
32. **`logLik()` happy path** — returns same value as `logLik(object@fit_)`.
33. **`logLik()` with `fit_` = NULL** — errors with
    `surveycore_error_predict_no_fit` (dual pattern).
34. **`AIC()` / `BIC()` happy path** — each returns same value as
    `AIC(object@fit_)` / `BIC(object@fit_)`.
35. **`AIC()` / `BIC()` with `fit_` = NULL** — errors with
    `surveycore_error_predict_no_fit` (dual pattern).
36. **`update()` happy path** — `update(fit, family = poisson())` returns a
    `survey_glm_fit` with Poisson family; matches re-running `survey_glm()`
    directly with the same data and new family.

### 9.3 `test_glm_tidy_invariants(result)`

Defined in `tests/testthat/helper-test-data.R`. Called as the **first
assertion** in every `clean()` happy-path test block.

```r
test_glm_tidy_invariants <- function(result) {
  # 1. Correct S3 class hierarchy
  expect_true(inherits(result, "survey_glm_tidy"))
  expect_true(inherits(result, "survey_result"))
  expect_true(tibble::is_tibble(result))
  # 2. Required columns always present
  expected_cols <- c("term", "variable", "var_label", "label", "reference_row",
                     "estimate", "std_error", "p_value", "conf_low", "conf_high")
  expect_true(all(expected_cols %in% names(result)))
  # 3. reference_row is logical, no NAs
  expect_type(result$reference_row, "logical")
  expect_false(anyNA(result$reference_row))
  # 4. label is character, never NA
  expect_type(result$label, "character")
  expect_false(anyNA(result$label))
  # 5. meta() returns non-NULL list with required keys
  m <- meta(result)
  expect_false(is.null(m))
  required_keys <- c("formula", "family", "link", "design_type", "conf_level",
                     "call", "group_names", "group_labels", "n_observations",
                     "n_weighted", "degf", "exponentiate", "include_reference",
                     "converged", "variables")
  expect_true(all(required_keys %in% names(m)))
  # 6. group_names is always character(0) for regression
  expect_identical(m$group_names, character(0))
  # 7. n_observations is positive integer
  expect_type(m$n_observations, "integer")
  expect_gt(m$n_observations, 0L)
  # 8. n_weighted is positive numeric
  expect_type(m$n_weighted, "double")
  expect_gt(m$n_weighted, 0)
  # 9. degf is positive numeric
  expect_type(m$degf, "double")
  expect_gt(m$degf, 0)
  # 10. $variables is a named list; each entry has required sub-keys
  vars <- m$variables
  expect_type(vars, "list")
  var_subkeys <- c("var_label", "var_class", "var_type", "var_nlevels",
                   "contrasts", "reference_level", "value_labels")
  for (v in vars) {
    expect_true(all(var_subkeys %in% names(v)))
    expect_type(v$var_label, "character")   # never NULL; falls back to name
    expect_false(is.null(v$var_label))
  }
}
```

### 9.4 Edge Cases Requiring Explicit Tests

- `survey_glm()`: Gaussian family, binomial family, Poisson family — all
  produce valid fits (oracle comparison for at least Gaussian and binomial)
- `survey_glm()`: programmatic interface `response = "y", predictors = c("x1", "x2")`
  produces identical output to `formula = y ~ x1 + x2`
- `survey_glm()`: `response = "y"` with `predictors = NULL` produces an
  intercept-only model (`y ~ 1`)
- `survey_glm()`: specifying both `formula` and `response` errors with
  `surveycore_error_formula_conflict`
- `survey_glm()`: specifying `predictors` without `response` errors with
  `surveycore_error_formula_missing`
- `survey_glm()`: programmatic interface is suitable for `lapply()`/`purrr::map()`
  iteration over outcome variables (verify no state leakage across calls)
- `survey_glm()`: formula with only an intercept (`y ~ 1`) — produces a
  1-coefficient fit
- `survey_glm()`: formula with a factor predictor — `coefficients` excludes
  the reference level; `clean()` adds a reference row when
  `include_reference = TRUE`
- `survey_glm()`: formula with interaction terms — coefficients include
  interaction terms; `clean()` `term` column shows the interaction name
- `survey_glm()`: response variable contains `NA` with `na.action = na.omit`
  — those rows are silently excluded; `meta(clean(fit))$n_observations`
  reflects the post-NA count
- `clean()`: `include_reference = FALSE` — no rows have `reference_row = TRUE`;
  all `estimate` values are non-`NA`
- `clean()`: model with no factor predictors — `include_reference` argument
  accepted without error; all `reference_row` values are `FALSE`
- `clean()`: no predictors have variable labels set —
  `meta(result)$variables[[var]]$var_label` equals the variable name (e.g.,
  `"x1"`); `var_label` column in tibble shows the variable name
- `clean()`: all predictors have variable labels set —
  `meta(result)$variables[[var]]$var_label` contains the label strings;
  `var_label` column in tibble shows the labels
- `clean()`: factor predictor with value labels set — `label` column shows
  value labels for each level; `meta(result)$variables[[var]]$value_labels`
  contains the named label vector
- `clean(fit, n = TRUE)` — `n_obs` column present; values are positive integers
  summing to at most `m$n_observations`
- `clean(fit, statistic = FALSE)` — `statistic` column absent from output
- `clean(fit, exponentiate = TRUE)` on logistic fit — `estimate` equals
  `exp(coef(fit))` within 1e-10; `std_error` unchanged; `conf_low`/`conf_high`
  equal `exp()` of the non-exponentiated bounds
- `clean(fit, exponentiate = TRUE)` on Gaussian identity fit — fires
  `surveycore_warning_exponentiate_nonlog`
- `predict.survey_glm_fit()`: `newdata` with missing predictor columns —
  should error via standard `stats::predict()` error
- `predict.survey_glm_fit()`: `fit_` is `NULL` — errors with
  `surveycore_error_predict_no_fit`
- `residuals.survey_glm_fit()`: `type = "response"` vs `"working"` —
  different values for non-identity links (e.g., binomial logistic)

---

## X. Error Message Table

This section lists all new error and warning classes introduced in Phase 2.
These must be added to `plans/error-messages.md` before implementation begins.

| # | Function | Condition | Level | Class |
|---|---|---|---|---|
| P2-1 | `survey_glm()` | `design` not survey object | ERROR | `surveycore_error_unsupported_class` (reuse Phase 1 definition via `.check_unsupported_class()`) |
| P2-2 | `survey_glm()` | No model specified (all of `formula`, `response`, `predictors` NULL; or `predictors` non-NULL but `response` NULL) | ERROR | `surveycore_error_formula_missing` |
| P2-16 | `survey_glm()` | Both `formula` and `response`/`predictors` supplied | ERROR | `surveycore_error_formula_conflict` |
| P2-3 | `survey_glm()` | `formula` not a formula | ERROR | `surveycore_error_formula_invalid` |
| P2-4 | `survey_glm()` | Response variable absent | ERROR | `surveycore_error_response_not_found` |
| P2-5 | `survey_glm()` | Predictor absent | ERROR | `surveycore_error_predictor_not_found` |
| P2-6 | `survey_glm()` | GLM did not converge | WARN | `surveycore_warning_glm_convergence` |
| P2-7 | `survey_glm()` | Response is design variable | WARN | `surveycore_warning_response_is_design_var` |
| P2-8 | `survey_glm()` | Perfect separation (binomial) | WARN | `surveycore_warning_perfect_separation` |
| P2-9 | `survey_glm()` | Singular model matrix | ERROR | `surveycore_error_singular_model_matrix` |
| P2-10 | `survey_glm()` | `@groups` on design | WARN | `surveycore_warning_groups_ignored_in_glm` |
| P2-11 | `survey_glm()` | Weight column contains `NA` | ERROR | `surveycore_error_na_weights` |
| P2-12 | `clean()` | `model` not `survey_glm_fit` | ERROR | `surveycore_error_not_glm_fit` |
| P2-13 | `clean()` | `conf_level` invalid | ERROR | `surveycore_error_invalid_conf_level` (reuse Phase 1 definition) |
| P2-18 | `clean()` | `exponentiate = TRUE` with non-log link | WARN | `surveycore_warning_exponentiate_nonlog` |
| P2-14 | `predict.survey_glm_fit()` | `fit_` is NULL | ERROR | `surveycore_error_predict_no_fit` |
| P2-15 | `survey_glm()` | `df_residual ≤ 0` | WARN | `surveycore_warning_insufficient_df` |
| P2-17 | `survey_glm()` | Active domain has zero in-domain rows | ERROR | `surveycore_error_empty_domain` |
| P2-19 | `survey_glm()` | Weight column contains zero or negative values | WARN | `surveycore_warning_nonpositive_weights` |

---

## XI. Quality Gates

Phase 2 is complete when all of the following pass:

- [ ] `devtools::check()` returns 0 errors, 0 warnings, ≤ 2 notes
- [ ] `response`/`predictors` programmatic interface produces identical output
      to equivalent `formula` call; `surveycore_error_formula_conflict` fires
      when both are supplied; `surveycore_error_formula_missing` fires when
      `predictors` is supplied without `response`
- [ ] Coefficient oracle tests pass for all five design classes within specified
      tolerances (1e-10 point, 1e-8 SE)
- [ ] SE oracle tests pass for Taylor, replicate, SRS, twophase, and calibrated
      designs
- [ ] `vcov()` oracle: `diag(vcov(fit_sc))^0.5` matches `SE(fit_sv)` within 1e-8
- [ ] `clean()` produces correct columns, correct S3 class, valid `.meta` for
      all design types
- [ ] `include_reference = TRUE` adds reference rows; `FALSE` omits them
- [ ] `meta(clean(fit))$formula` matches the original formula
- [ ] `meta(clean(fit))$variables` populated with one named entry per predictor; each entry has `var_label`, `var_class`, `var_type`, and optionally populated `value_labels`
- [ ] `broom::tidy(fit)` returns same object as `clean(fit)` (tested with
      `skip_if_not_installed("broom")`)
- [ ] All 20 S3 methods (`coef`, `vcov`, `print`, `summary`, `predict`,
      `fitted`, `residuals`, `confint`, `formula`, `terms`, `model.matrix`,
      `model.frame`, `deviance`, `df.residual`, `nobs`, `hatvalues`, `logLik`,
      `AIC`, `BIC`, `update`) work correctly
- [ ] `predict(fit, newdata = df)` produces expected values for Gaussian
      and logistic families
- [ ] Oracle tests pass for all 8 GLM families (`gaussian`, `binomial`,
      `Gamma`, `inverse.gaussian`, `quasi`, `quasibinomial`, `poisson`,
      `quasipoisson`) against `survey::svyglm()` within standard tolerances
- [ ] Domain estimation via `surveytidy::filter()` produces different
      coefficients from full-sample fit
- [ ] `surveycore_warning_groups_ignored_in_glm` fires when design has `@groups`
- [ ] All 16 error/warning classes in Section X are tested (typed class +
      snapshot for constructor errors; typed class only for S7 validator errors)
- [ ] Test coverage ≥ 98% line coverage for all new Phase 2 files
- [ ] `plans/error-messages.md` updated with Phase 2 error/warning classes
- [ ] `.degf()` in `R/09-analysis-helpers.R` returns correct df values for
      all five design classes (oracle comparison vs. `survey::degf()` per
      Section 9.1 Issue 26 test plan)
- [ ] `survey_glm_summary` S3 class specified and its `print()` method works
- [ ] All four marginaleffects extension methods registered and functional
      (`skip_if_not_installed("marginaleffects")`):
      `get_coef(fit)` returns `fit@coefficients` (identical);
      `get_vcov(fit)` returns `fit@vcov` (identical);
      `set_coef(fit, new_coefs)` updates both `@coefficients` and internal
      `fit_$coefficients`; original object unchanged (copy semantics verified);
      `get_predict(fit, newdata)` returns data frame with `rowid` and `estimate`
      columns of correct length
- [ ] `marginaleffects::avg_slopes(fit)` for Gaussian family: AME for a
      continuous predictor matches the OLS coefficient within `1e-6`
- [ ] `marginaleffects::avg_predictions(fit)` returns a data frame with
      `estimate` column; values in `[0, 1]` for binomial family

---

## XII. Integration Contract

### surveycore → surveytidy

`survey_glm()` is called on a `survey_base` object. If the user applies
`surveytidy::filter()` to the design before calling `survey_glm()`, domain
estimation is applied per the contract in Section 4.5.

`surveytidy::group_by()` is **not supported** as input to `survey_glm()`.
The `@groups` property is ignored with a warning.

### surveycore → broom

`broom::tidy.survey_glm_fit()` is a compatibility shim (Section 6.4). It
returns a `survey_glm_tidy` object, which IS a tibble and satisfies broom's
contract of returning a tidy tibble from `tidy()`.

`broom::glance.survey_glm_fit()` is deferred. Users needing model-level
statistics should inspect `fit@deviance`, `fit@null_deviance`, and `fit@degf`
directly.

`broom::augment.survey_glm_fit()` is deferred.

### surveycore Phase 2 → marginaleffects

`survey_glm_fit` implements the marginaleffects extension interface (Section VII).
When marginaleffects is installed, users can call `marginaleffects::avg_slopes()`,
`marginaleffects::avg_predictions()`, and the full marginaleffects function suite
on `survey_glm_fit` objects. `marginaleffects` is in `Suggests`; the interface is
registered conditionally in `.onLoad()`.

### surveycore Phase 2 → get_diffs() (Phase 3 spec)

`get_diffs()` calls `survey_glm()` and uses both `clean()` and the marginaleffects
extension interface (Section VII) to compute treatment effects and absolute levels
per arm. The stable interfaces defined here — `survey_glm_fit`, `clean()`, and the
four marginaleffects generics — are what `get_diffs()` depends on.

### surveycore Phase 2 → get_crosstab() (future spec)

`get_crosstab()` is independent of `survey_glm()`. It will implement
Rao-Scott chi-square tests separately.

---

*Reviewed and approved via Stage 2/3 spec workflow. All issues resolved — see `plans/claude-decisions-phase-2.md`. Section VII (marginaleffects extension) added 2026-02-27.*
