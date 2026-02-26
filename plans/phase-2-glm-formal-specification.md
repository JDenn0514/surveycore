# surveycore Phase 2 — Survey GLM: Weighted Regression

**Version:** 0.1 (first draft)
**Date:** February 2026
**Status:** Draft — Stage 3 resolution in progress

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
| S3 methods on `survey_glm_fit` | `print`, `summary`, `coef`, `vcov`, `predict`, `fitted`, `residuals` |
| `clean()` | Tidy the model into a `survey_glm_tidy` result tibble |
| `broom::tidy.survey_glm_fit()` | Compatibility shim; delegates to `clean()` |

### What Phase 2 Does NOT Deliver

- `get_diffs()` — separate spec; depends on `survey_glm()` but is not part of
  this component
- `get_crosstab()` — separate spec
- `broom::glance.survey_glm_fit()` — deferred; flagged as future extension
- Covariate-adjusted means (marginal effects) — Phase 3/4
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
├── 14-glm.R                # survey_glm_fit S7 class + survey_glm() + .glm_score()
├── 14-glm-methods.R        # S3 methods: print, summary, coef, vcov, predict, fitted, residuals
├── 14-glm-clean.R          # clean() + .build_glm_meta() + broom::tidy registration

tests/testthat/
├── test-glm.R              # survey_glm() happy paths + error paths + edge cases
├── test-glm-methods.R      # S3 methods: correct output + error paths
└── test-glm-numerical.R    # Oracle tests vs survey::svyglm() — all design types
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
replicate — see Section 7.3) or SRS designs (analytic formula — see
Section 7.4).

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
  formula,
  family      = gaussian(),
  na.action   = na.omit,
  start       = NULL,
  etastart    = NULL,
  mustart     = NULL,
  control     = list()
)
```

Argument order follows `code-style.md §4`: `design` first (required survey
object), `formula` second (required), `family` third (required with default),
then optional scalars. No `...` — variadic pass-through to `stats::glm()` is
not supported. GLM control options are passed via `control`.

### 4.2 Argument Table

| Argument | Type | Default | Description |
|---|---|---|---|
| `design` | `survey_base` | — | A survey design object created by `as_survey()` or family. |
| `formula` | `formula` | — | Model formula in standard R notation, e.g. `y ~ x1 + x2`. |
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

Validate `formula` is a formula object — error `surveycore_error_formula_invalid`
if not.

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

> ⚠️ **GAP:** The exact mechanism for "fit on in-domain, variance on full
> design" in the GLM sandwich estimator is more complex than for means/totals.
> For means, the score `u_i = w_i (y_i - ȳ) · I(in-domain)` extends naturally
> to the full design. For GLM, the score is `u_i = w_i x_i e_i`; for
> out-of-domain rows, `e_i` is undefined (the GLM was not fit on them). The
> implementation must specify how out-of-domain scores are set (likely to
> zero) so that the full-design variance formula applies. This must be resolved
> in the implementation plan and validated against `survey::svyglm()` with
> a domain subset.

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
| 2 | `survey_glm()` | `formula` missing | ERROR | `surveycore_error_formula_missing` | `{.arg formula} is required.` |
| 3 | `survey_glm()` | `formula` not a formula | ERROR | `surveycore_error_formula_invalid` | `{.arg formula} must be a formula object, not {.cls {class(formula)[1]}}.` |
| 4 | `survey_glm()` | Response variable absent from `design@data` | ERROR | `surveycore_error_response_not_found` | `Response variable {.field {resp}} not found in survey data.` |
| 5 | `survey_glm()` | Predictor absent from `design@data` | ERROR | `surveycore_error_predictor_not_found` | `Predictor {.field {pred}} not found in survey data. Available columns: {.field {names(design@data)}}.` |
| 6 | `survey_glm()` | GLM did not converge | WARN | `surveycore_warning_glm_convergence` | `{.fn survey_glm} did not converge. {.i Increase {.arg control$maxit} or simplify the model.}` |
| 7 | `survey_glm()` | Response is a design variable | WARN | `surveycore_warning_response_is_design_var` | `Response variable {.field {resp}} is a design variable ({.field {role}}). Results may be misleading.` |
| 8 | `survey_glm()` | Perfect separation (binomial) | WARN | `surveycore_warning_perfect_separation` | `Fitted probabilities are numerically 0 or 1. Perfect or quasi-complete separation may have occurred.` |
| 9 | `survey_glm()` | Singular model matrix | ERROR | `surveycore_error_singular_model_matrix` | `Model matrix is singular. Check for perfect collinearity or empty factor levels.` |
| 10 | `survey_glm()` | `@groups` set on design | WARN | `surveycore_warning_groups_ignored_in_glm` | `{.fn survey_glm} does not support grouped designs. {.i The {.field @groups} property is ignored. Use {.fn surveytidy::group_by} after fitting to group results.}` |
| 11 | `survey_glm()` | Weight column contains `NA` | ERROR | `surveycore_error_na_weights` | `Weight column {.field {wt_var}} contains {sum(is.na(wt))} NA value(s). {.i Survey weights must be fully observed. Remove rows with missing weights or impute before calling {.fn survey_glm}.}` |

---

## V. S3 Methods on `survey_glm_fit`

S3 methods are registered in `.onLoad()` via `registerS3method()`, exactly as
surveytidy registers dplyr verbs. Per `code-style.md §2`, S3 dispatch does not
work for S7 objects via `UseMethod()`; dynamic registration is required.

All S3 method implementations are in `R/14-glm-methods.R`. Each method is a
plain function (named `print.survey_glm_fit`, etc.) with `@noRd`; it is not
exported directly but becomes available via the registered S3 method.

### 5.1 `print.survey_glm_fit(x, digits = 4, ...)`

Produces a concise regression table. Rows are coefficients; columns are
Estimate, Std. Error, t value, and Pr(>|t|).

**Output format:**

```
Survey-weighted GLM

Family:  gaussian (identity link)
Formula: y ~ x1 + x2
Design:  Taylor series (NHANES-like)

Coefficients:
             Estimate  Std. Error  t value  Pr(>|t|)
(Intercept)    3.241       0.184    17.61    <0.0001 ***
x1             0.612       0.089     6.88    <0.0001 ***
x2            -0.023       0.041    -0.56     0.581

Degrees of freedom: 18 (design-based)
```

Significance stars follow standard R convention: `***` < 0.001, `**` < 0.01,
`*` < 0.05, `.` < 0.1.

Returns `invisible(x)`.

### 5.2 `summary.survey_glm_fit(object, ...)`

Produces detailed output matching the structure of `summary.glm()`, augmented
with design information.

**Output additions over `print()`:**

- Deviance residuals summary (min, 1Q, median, 3Q, max) computed from
  `object@residuals`
- Dispersion parameter
- Null deviance and residual deviance
- Design degrees of freedom (labeled as design-based, not model-based)
- AIC

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
Returns `invisible(x)`.

### 5.3 `coef.survey_glm_fit(object, ...)`

Returns `object@coefficients` — the named numeric vector of coefficient
estimates. Same contract as `coef.glm()`.

### 5.4 `vcov.survey_glm_fit(object, ...)`

Returns `object@vcov` — the design-based `p × p` variance-covariance matrix.
Row and column names match `names(object@coefficients)`.

### 5.5 `predict.survey_glm_fit(object, newdata = NULL, type = "response", ...)`

When `newdata = NULL`: delegates to `stats::predict(object@fit_, type = type)`
so the `type` argument is respected (link scale vs. response scale). Requires
`object@fit_` to be non-`NULL`. Errors with `surveycore_error_predict_no_fit`
if `object@fit_` is `NULL` (e.g., after deserialization that strips internal
slots). This matches `stats::predict.glm()` behavior: `type = "response"`
returns fitted probabilities/means; `type = "link"` returns the linear
predictor; `type = "terms"` returns the contribution of each term.

When `newdata` is a data frame: delegates to
`stats::predict(object@fit_, newdata = newdata, type = type, ...)`. Same
`object@fit_` requirement and error as above.

The `type` argument is passed through: `"response"` (default), `"link"`, or
`"terms"`. Standard predictions do not use design-based SEs; they are
model-based predictions at new data points.

> ⚠️ **GAP:** Survey-design-based prediction intervals (accounting for complex
> design variance in predictions) are not specified here. This is a Phase 3+
> feature. `predict.survey_glm_fit()` produces model-based predictions only,
> consistent with `survey::svyglm()`'s `predict` behavior.

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

For `"pearson"` and `"deviance"`, `object@fit_` must be non-`NULL`. If
`object@fit_` is `NULL`, errors with `surveycore_error_predict_no_fit` (same
error class used by `predict()` for the same condition).

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
  conf_level         = 0.95,
  include_reference  = TRUE,
  ...
)
```

| Argument | Type | Default | Description |
|---|---|---|---|
| `model` | `survey_glm_fit` | — | A fitted survey GLM object from `survey_glm()`. |
| `conf_level` | numeric, length 1 | `0.95` | Confidence level for CIs; passed to `surveycore_error_invalid_conf_level` validation. Must be in `(0, 1)`. |
| `include_reference` | logical | `TRUE` | If `TRUE`, reference levels for factor predictors are included as rows with `estimate = NA` and all other statistic columns `NA`. This preserves the factor structure for downstream display. |
| `...` | — | — | Currently unused; reserved for future arguments. |

### 6.3 Output Contract

#### Column structure

| Column | Type | Description |
|---|---|---|
| `term` | character | Coefficient name (e.g. `"(Intercept)"`, `"x1"`, `"sexFemale"`). For reference rows: `paste0(var_name, ref_level, " [ref]")` where `ref_level` is derived as `setdiff(levels(model_frame[[var_name]]), colnames(contrasts(model_frame[[var_name]])))` — the factor level that does not appear as a column in the contrasts matrix. Example: factor `employment_status` with levels `c("Full-time", "Part-time")` and reference `"Full-time"` yields term `"employment_statusFull-time [ref]"`. |
| `estimate` | double | Coefficient estimate. `NA` for reference rows. |
| `std_error` | double | Design-based standard error. `NA` for reference rows. |
| `statistic` | double | t-statistic (`estimate / std_error`). `NA` for reference rows. |
| `p_value` | double | Two-sided p-value from t-distribution with `degf - (p-1)` df. `NA` for reference rows. |
| `conf_low` | double | Lower CI bound at `conf_level`. `NA` for reference rows. |
| `conf_high` | double | Upper CI bound at `conf_level`. `NA` for reference rows. |

CIs are computed as `estimate ± qt((1 + conf_level)/2, df = df_residual) * std_error`.

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
| `n_observations` | integer | Number of rows in the final model matrix after both domain filtering and `na.action`; equals `nrow(model.matrix(fit))` from the `stats::glm()` result. |
| `degf` | numeric | Design degrees of freedom (`model@degf`) |
| `variable_labels` | named list | One entry per predictor variable. Value is the variable label string from `design@metadata` if set; otherwise the variable name itself as a character string (e.g., `list(x1 = "x1", x2 = "Age in years")` when `x2` is labelled and `x1` is not). Never `NULL` for any entry — always a named list of character strings. |
| `converged` | logical | Whether the GLM converged (`model@converged`) |
| `include_reference` | logical | The `include_reference` argument value |

`value_labels` is **not** included in `survey_glm_tidy` meta (unlike Phase 1
`survey_result` objects). GLM predictors may be continuous or categorical; for
categorical predictors the factor level information is already encoded in the
`term` column. This is an intentional deviation from the Phase 1 `.meta`
contract. The `meta()` generic still works; it just does not include a
`value_labels` key.

> ⚠️ **GAP:** The absence of `value_labels` in `survey_glm_tidy` meta means
> `test_result_invariants()` from Phase 1 will fail if called directly on a
> `survey_glm_tidy` object (invariant 5 checks `value_labels`). Either:
> (a) extend `test_result_invariants()` to accept an optional `skip_keys`
> argument, or (b) define a separate `test_glm_tidy_invariants()` for this
> class. This must be resolved before implementation.

### 6.4 `broom::tidy.survey_glm_fit()` wrapper

```r
# In R/14-glm-clean.R — not exported; registered dynamically
tidy.survey_glm_fit <- function(x, conf.int = TRUE, conf.level = 0.95, ...) {
  clean(
    model      = x,
    conf_level = conf.level,
    ...
  )
}
```

Note `conf.level` (broom convention, period separator) vs. `conf_level`
(surveycore convention, underscore). The wrapper maps the broom argument name.

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

---

## VII. Variance Estimation

### 7.1 Architectural Principle: Reuse Phase 0 Machinery

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

### 7.2 Taylor Series Variance (Binder 1983)

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

### 7.3 Replicate Weights Variance

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

### 7.4 SRS Variance

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

### 7.5 Design Degrees of Freedom

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

## VIII. Testing Strategy

### 8.1 File Structure and Oracle Tests

Numerical oracle tests live in `test-glm-numerical.R` and always call
`skip_if_not_installed("survey")`.

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

**Oracle test structure for each design class:**

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
```

### 8.2 Per-Function Test Categories

**`test-glm.R`** covers `survey_glm()` and `clean()`:

1. **Happy path** — basic call produces a valid `survey_glm_fit`; verify key
   properties (coefficients length, vcov dimension, converged = TRUE,
   degf > 0).
2. **`clean()` happy path** — produces correct class hierarchy, correct
   columns, `test_result_invariants()` equivalent (Section 8.3).
3. **`clean()` reference levels** — factor predictor with `include_reference = TRUE`
   includes a row with `estimate = NA`; with `FALSE` it is absent.
4. **`clean()` `.meta` contract** — all keys present, correct types,
   `formula` matches original, `n_observations` equals number of non-NA rows.
5. **Variable label integration** — when design has variable labels set on
   predictors, `meta(clean(fit))$variable_labels` contains those labels.
6. **`broom::tidy()` compatibility** — `broom::tidy(fit)` returns same object
   as `clean(fit)` (`skip_if_not_installed("broom")`).
7. **Error paths** — every row in Sections 4.7 and 6.5 error tables. User-facing
   constructor errors (Layer 3) use the dual pattern:
   `expect_error(class = "surveycore_error_...")` + `expect_snapshot(error = TRUE)`.
   S7 validator errors (Section 3.3, Layer 1) use `class=` only — no snapshot.
   Per `testing-surveycore.md §S7 error testing layers`.
8. **Convergence warning** — force non-convergence; verify
   `surveycore_warning_glm_convergence` fires and fit is still returned.
9. **`@groups` warning** — group_by() design triggers
   `surveycore_warning_groups_ignored_in_glm`.
10. **Domain estimation** — `surveytidy::filter()` domain is used in fitting;
    verify coefficient differs from full-sample fit
    (`skip_if_not_installed("surveytidy")`).
11. **S7 validator errors** — one `test_that()` block per condition in Section
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

### 8.3 `test_glm_tidy_invariants(result)`

Defined in `tests/testthat/helper-test-data.R`. Called as the **first
assertion** in every `clean()` happy-path test block.

```r
test_glm_tidy_invariants <- function(result) {
  # 1. Correct S3 class hierarchy
  expect_true(inherits(result, "survey_glm_tidy"))
  expect_true(inherits(result, "survey_result"))
  expect_true(tibble::is_tibble(result))
  # 2. Required columns present
  expected_cols <- c("term", "estimate", "std_error", "statistic", "p_value",
                     "conf_low", "conf_high")
  expect_true(all(expected_cols %in% names(result)))
  # 3. meta() returns non-NULL list with required keys
  m <- meta(result)
  expect_false(is.null(m))
  required_keys <- c("formula", "family", "link", "design_type", "conf_level",
                     "call", "group_names", "n_observations", "degf",
                     "variable_labels", "converged")
  expect_true(all(required_keys %in% names(m)))
  # 4. group_names is always character(0) for regression
  expect_identical(m$group_names, character(0))
  # 5. n_observations is positive integer
  expect_type(m$n_observations, "integer")
  expect_gt(m$n_observations, 0L)
  # 6. degf is positive numeric
  expect_type(m$degf, "double")
  expect_gt(m$degf, 0)
  # 7. variable_labels is a named list of character strings (never NULL entries)
  vl <- m$variable_labels
  expect_type(vl, "list")
  expect_true(length(vl) > 0 || is.null(names(vl)))  # named or empty
  if (length(vl) > 0) {
    expect_true(all(nzchar(names(vl))))
    expect_true(all(vapply(vl, is.character, logical(1))))
  }
}
```

### 8.4 Edge Cases Requiring Explicit Tests

- `survey_glm()`: Gaussian family, binomial family, Poisson family — all
  produce valid fits (oracle comparison for at least Gaussian and binomial)
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
- `clean()`: `include_reference = FALSE` — no reference rows; `term` column
  has no `[ref]` suffix entries
- `clean()`: model with no factor predictors — `include_reference` argument
  accepted without error; output unchanged
- `clean()`: no predictors have variable labels set — `meta(result)$variable_labels`
  is a named list where every value equals the variable name (e.g., `list(x1 = "x1")`)
- `clean()`: all predictors have variable labels set — `meta(result)$variable_labels`
  contains the label strings, not the variable names
- `predict.survey_glm_fit()`: `newdata` with missing predictor columns —
  should error via standard `stats::predict()` error
- `predict.survey_glm_fit()`: `fit_` is `NULL` — errors with
  `surveycore_error_predict_no_fit`
- `residuals.survey_glm_fit()`: `type = "response"` vs `"working"` —
  different values for non-identity links (e.g., binomial logistic)

---

## IX. Error Message Table

This section lists all new error and warning classes introduced in Phase 2.
These must be added to `plans/error-messages.md` before implementation begins.

| # | Function | Condition | Level | Class |
|---|---|---|---|---|
| P2-1 | `survey_glm()` | `design` not survey object | ERROR | `surveycore_error_unsupported_class` (reuse Phase 1 definition via `.check_unsupported_class()`) |
| P2-2 | `survey_glm()` | `formula` missing | ERROR | `surveycore_error_formula_missing` |
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
| P2-14 | `predict.survey_glm_fit()` | `fit_` is NULL | ERROR | `surveycore_error_predict_no_fit` |
| P2-15 | `survey_glm()` | `df_residual ≤ 0` | WARN | `surveycore_warning_insufficient_df` |

---

## X. Quality Gates

Phase 2 is complete when all of the following pass:

- [ ] `devtools::check()` returns 0 errors, 0 warnings, ≤ 2 notes
- [ ] Coefficient oracle tests pass for all five design classes within specified
      tolerances (1e-10 point, 1e-8 SE)
- [ ] SE oracle tests pass for Taylor, replicate, SRS, and twophase designs
- [ ] `vcov()` oracle: `diag(vcov(fit_sc))^0.5` matches `SE(fit_sv)` within 1e-8
- [ ] `clean()` produces correct columns, correct S3 class, valid `.meta` for
      all design types
- [ ] `include_reference = TRUE` adds reference rows; `FALSE` omits them
- [ ] `meta(clean(fit))$formula` matches the original formula
- [ ] `meta(clean(fit))$variable_labels` populated from design metadata
- [ ] `broom::tidy(fit)` returns same object as `clean(fit)` (tested with
      `skip_if_not_installed("broom")`)
- [ ] All S3 methods (`coef`, `vcov`, `print`, `summary`, `predict`,
      `fitted`, `residuals`) work correctly
- [ ] `predict(fit, newdata = df)` produces expected values for Gaussian
      and logistic families
- [ ] Domain estimation via `surveytidy::filter()` produces different
      coefficients from full-sample fit
- [ ] `surveycore_warning_groups_ignored_in_glm` fires when design has `@groups`
- [ ] All 13 error/warning classes in Section IX are tested (typed class +
      snapshot for constructor errors; typed class only for S7 validator errors)
- [ ] Test coverage ≥ 98% line coverage for all new Phase 2 files
- [ ] `plans/error-messages.md` updated with Phase 2 error/warning classes
- [ ] `.degf()` in `R/09-analysis-helpers.R` returns correct df values for
      all five design classes (oracle comparison vs. `survey::degf()` per
      Section 8.1 Issue 26 test plan)
- [ ] `survey_glm_summary` S3 class specified and its `print()` method works

---

## XI. Integration Contract

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

### surveycore Phase 2 → get_diffs() (future spec)

`get_diffs()` will call `survey_glm(design, x ~ factor(treats))` and extract
contrasts relative to the reference level using `clean()`. The API contract
for `survey_glm_fit` and `clean()` defined here is the stable interface that
`get_diffs()` will depend on.

### surveycore Phase 2 → get_crosstab() (future spec)

`get_crosstab()` is independent of `survey_glm()`. It will implement
Rao-Scott chi-square tests separately.

---

*This is a first draft. Expect gaps — run Stage 2 in a new session to get an adversarial review before resolving anything.*
