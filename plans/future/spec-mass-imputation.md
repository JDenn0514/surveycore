> **API STILL NEEDS DISCUSSION. DO NOT PROCEED UNTIL CLEARED.**

# surveycore Mass Imputation Spec

**Version:** 0.1 — Draft
**Date:** 2026-05-19
**Status:** Draft
**ID:** `mass-imputation`

---

## Document Purpose

This spec is the source of truth for `mass_imputation()` — the primary function for
non-probability sample (NPS) inference via outcome regression. `mass_imputation()`
belongs in surveycore (not surveywts) because it is an estimation function: it
produces a population mean estimate, not survey weights. The inference machinery is
anchored entirely to the probability sample's existing design weights.

Four MI variants are covered: GLM, nearest-neighbor (NN), nonparametric/GAM (NPAR),
and predictive mean matching (PMM-A and PMM-B).

Every implementation decision, API contract, and error condition must be resolved here
before any R code is written.

---

## I. Scope

### Deliverables

| Deliverable | Function / object | Source file |
|---|---|---|
| Mass imputation estimator | `mass_imputation()` | `R/analysis-mi.R` (new) |
| MI result class | `survey_mi_mean` S3 class | `R/analysis-mi.R` |
| Print method | `print.survey_mi_mean()` | `R/analysis-mi.R` |
| GLM imputation engine | `.fit_mi_glm()` (file-local) | `R/analysis-mi.R` |
| NN imputation engine | `.fit_mi_nn()` (file-local) | `R/analysis-mi.R` |
| NPAR imputation engine | `.fit_mi_npar()` (file-local) | `R/analysis-mi.R` |
| PMM imputation engine | `.fit_mi_pmm()` (file-local) | `R/analysis-mi.R` |
| GLM analytic variance | `.compute_mi_variance_glm()` (file-local) | `R/analysis-mi.R` |
| PMM analytic variance | `.compute_mi_variance_pmm()` (file-local) | `R/analysis-mi.R` |

The source file follows the `analysis-*.R` naming convention used in surveycore (see
`analysis-means.R`, `analysis-totals.R`, etc.). The bootstrap spec pre-spec reference
(`surveywts/plans/spec-methodology-nps-bootstrap.md`) cited `R/mass-imputation.R` —
this surveycore file at `R/analysis-mi.R` is the canonical implementation location.

### What This Phase Does NOT Deliver

- **Doubly robust (DR) estimators** — DR combines MI and IPW; `ipw()` is not yet
  implemented in `surveywts`. DR belongs in a later phase once both components exist.
- **`surveywts::create_bootstrap_weights(type = "hybrid")`** — reads the MI history
  entry; a separate `surveywts` deliverable in the NPS bootstrap phase.
- **Approximate Bayesian variance for GAM** — Chen, Yang & Kim (2022) propose this
  alternative to the hybrid bootstrap for GAM imputation. Deferred; the hybrid
  bootstrap covers the use case.
- **Yang et al. (2021) calibration efficiency step** — when NPS overlap membership is
  observable in the probability sample, a second-phase calibration can reduce variance.
  Requires knowing which reference units are also in the NPS. Deferred.
- **Domain (subgroup) estimation** — `mass_imputation()` estimates a single population
  mean. Subgroup estimation deferred.
- **Quantile estimation** — deferred.
- **High-dimensional outcome models** (LASSO, random forests) — deferred to a future
  minor bump.

### Input Class Support

| Argument | Accepted classes |
|---|---|
| `data` (NPS, Sample B) | `data.frame`, `survey_nonprob` |
| `reference` (probability sample, Sample A) | `survey_taylor` only |

`survey_replicate` is not supported as either input. `survey_taylor` as `data` is an
error — the NPS cannot be a probability sample with known inclusion probabilities.

### Identifying Assumption

Mass imputation requires the **transportability / noninformative sampling** condition
(Wu 2022, assumption A3): the conditional distribution P(Y|X) is the same in the NPS
as in the target population. This is *weaker* than MAR/ignorability — it does not
require modeling why units entered the NPS. Consistency also requires positivity (A2):
every population unit has positive probability of selection into the NPS.

These assumptions are untestable from the data. `mass_imputation()` does not test
them; the print method reminds the user of this assumption.

---

## II. How Variance and Confidence Intervals Are Computed

This is the central statistical question for MI. After fitting the outcome model on
the NPS (Sample B) and predicting Ŷ for every unit in the reference (Sample A), the
MI estimator is:

$$\hat{\bar{Y}}_{MI} = \frac{\sum_{i \in A} d_i \hat{y}_i}{\sum_{i \in A} d_i}$$

where $d_i$ are the reference design weights. This is a design-weighted mean of
imputed values — structurally identical to any other survey-weighted mean, with Ŷ
as the analysis variable.

### Two Variance Components

Variance has two additive components:

**1. Design variance (dominant)**

Treat $\hat{y}_i$ as a fixed analysis variable and compute the standard survey
variance of the design-weighted mean under the reference design. For a `survey_taylor`
reference, this is the Taylor linearization variance of the Hájek mean estimator
applied to the imputed values. This component is computed using surveycore's existing
variance machinery — the same path used by `get_means()`.

**2. Imputation variance (secondary)**

The imputed values $\hat{y}_i$ are predictions, not true Y values. Their prediction
error introduces a second source of uncertainty. The form of this component depends
on the imputation method:

| Method | Imputation variance | Source |
|---|---|---|
| GLM | $\frac{1}{N^2 n_B}\sum_{i \in A} d_i^2 \hat{\sigma}^2$, where $\hat{\sigma}^2$ is the mean NPS residual | Kim & Wang (2021) |
| PMM-A | $\frac{1}{k N^2}\sum_{i \in A} d_i^2 \hat{\sigma}^2_{m_i}$, donor variance per reference unit | Chlebicki et al. (2024) Thm 1 |
| PMM-B | $\frac{1}{k N^2}\sum_{i \in A} d_i^2 \hat{\tau}^2_{m_i}$, variance of ŷ-y matched donors | Chlebicki et al. (2024) Thm 2 |
| NN | No closed form | Hybrid bootstrap required |
| NPAR/kernel | No closed form in this release | Hybrid bootstrap required |
| NPAR/GAM | No closed form | Hybrid bootstrap required |

Total SE = $\sqrt{V_{\text{design}} + V_{\text{imputation}}}$.

> ⚠️ GAP: The GLM imputation variance formula above treats prediction error as
> homoskedastic. Kim & Wang (2021) §3 use unit-level residuals from the probability
> sample; using NPS residuals as a proxy is an approximation. The methodology review
> must verify whether the NPS-residual approximation is sufficient or whether the
> exact unit-level formula is required.

> ⚠️ GAP: The PMM variance formulas above are a faithful transcription from the
> knowledge wiki but must be verified against Chlebicki et al. (2024) Theorems 1 and 2
> before implementation.

### Confidence Intervals

Wald-type 95% CI: estimate ± 1.96 × SE. No small-sample df correction is applied —
NPS designs have no well-defined degrees of freedom (Wu 2022 §4.2; consistent with
the `degf = Inf` decision in `decisions-nonprob-bootstrap-variance.md`).

### When Analytic Variance Is Not Available

For NN, NPAR/kernel, and NPAR/GAM, `$se` is `NULL`. The print method informs the
user to use the hybrid bootstrap:

```r
surveywts::create_bootstrap_weights(result$nps, type = "hybrid", replicates = 200L)
```

The hybrid bootstrap (Chen, Yang & Kim 2022) captures both variance components
simultaneously: independently resample the NPS (SRS with replacement) and the
reference (according to its own design), re-fit the imputation model on each draw,
re-predict, re-estimate. The spread across draws is the variance estimate.

---

## III. Architecture

### Source File Map

```
R/
  analysis-mi.R   ← NEW: mass_imputation(), survey_mi_mean S3 class,
                          print.survey_mi_mean(), file-local helpers
```

### Shared Helpers Used from `R/utils.R`

| Helper | Used for |
|---|---|
| `.get_weight_vec()` (if it exists in surveycore) | Extracting design weights from reference |
| `.variance_taylor_cell()` or equivalent | Design variance component of MI SE |

> ⚠️ GAP: Confirm which surveycore internal variance helper to use for the design
> variance component. This is the same computation as `get_means()` applied to the
> imputed values — the implementation should reuse that path, not duplicate it.

### `@family` Tag

`mass_imputation()` joins the `"analysis"` family, consistent with `get_means()`,
`get_totals()`, etc. Add `@family analysis` to the roxygen2 block.

---

## IV. `mass_imputation()` — Function Spec

### Signature

```r
mass_imputation(
  data,              # NPS (Sample B): data.frame or survey_nonprob
  reference,         # probability sample (Sample A): survey_taylor
  formula = NULL,    # outcome model formula (y ~ x1 + x2)
  response = NULL,   # character(1): Y column name in data
  predictors = NULL, # character vector: covariate names in data and reference
  method = c("glm", "nn", "npar", "pmm_a", "pmm_b"),
  ...                # method-specific control args (see §IV.D)
)
```

Argument order follows `code-style.md`: `data` first, then `reference`, then
optional arguments (formula, response, predictors, method), then `...`.

### Argument Table

| Argument | Type | Default | Description |
|---|---|---|---|
| `data` | `data.frame` or `survey_nonprob` | — | NPS (Sample B). Has both Y and covariates X; selection mechanism unknown. |
| `reference` | `survey_taylor` | — | Probability sample (Sample A). Has design weights and X, but not Y. |
| `formula` | `formula` or `NULL` | `NULL` | Outcome model formula, e.g. `y ~ x1 + x2`. Mutually exclusive with `response`/`predictors`. |
| `response` | `character(1)` or `NULL` | `NULL` | Name of the Y column in `data`. Programmatic alternative to `formula`. |
| `predictors` | `character` vector or `NULL` | `NULL` | Covariate names. Used with `response` via `reformulate()`. If `response` is supplied and `predictors` is `NULL`, fits intercept-only model (`y ~ 1`). |
| `method` | `character(1)` | `"glm"` | Imputation method. One of `"glm"`, `"nn"`, `"npar"`, `"pmm_a"`, `"pmm_b"`. |
| `...` | — | — | Method-specific control arguments. |

### Formula Construction

When `response` is supplied (and `formula` is `NULL`):

```r
reformulate(predictors %||% "1", response)
```

- `response = "y", predictors = c("x1", "x2")` → `y ~ x1 + x2`
- `response = "y", predictors = NULL` → `y ~ 1`

All RHS variables must exist in both `data` and `reference`. The LHS (Y) must exist
in `data` only.

### Method-Specific Control Arguments (`...`)

Unrecognized `...` args emit `surveycore_warning_unused_control_args`.

**`method = "glm"`:**

| Arg | Type | Default | Description |
|---|---|---|---|
| `family` | `family` | `gaussian()` | GLM family. Passed to `stats::glm()`. |

**`method = "nn"`:**

| Arg | Type | Default | Description |
|---|---|---|---|
| `k` | `integer(1)` | `1L` | Number of nearest neighbors. `k = 1` is Rivers (2007) sample matching. |
| `distance` | `character(1)` | `"euclidean"` | Distance metric. Currently only `"euclidean"` supported. |

**`method = "npar"`:**

| Arg | Type | Default | Description |
|---|---|---|---|
| `npar_method` | `character(1)` | `"gam"` | Nonparametric imputer: `"gam"` or `"kernel"`. |
| `bandwidth` | `numeric(1)` or `NULL` | `NULL` | Kernel bandwidth. `NULL` = cross-validation selection. Only for `npar_method = "kernel"`. |
| `k_gam` | `integer(1)` | `10L` | GAM basis dimension (`k` in `mgcv::s()`). Only for `npar_method = "gam"`. |

**`method = "pmm_a"` and `method = "pmm_b"`:**

| Arg | Type | Default | Description |
|---|---|---|---|
| `k` | `integer(1)` | `5L` | Number of PMM donors per reference unit. |
| `family` | `family` | `gaussian()` | Working model family for generating predicted values. |

### Validation Sequence

1. `data` is `data.frame` or `survey_nonprob`; error if `survey_replicate` or other
2. `reference` is `survey_taylor`; error if any other class
3. Formula conflict: error if `formula` is non-NULL and `response` or `predictors` is non-NULL
4. Formula presence: error if both `formula` and `response` are NULL
5. Predictors without response: error if `predictors` is non-NULL but `response` is NULL
6. `method` via `match.arg()`
7. LHS variable exists in `data`; RHS variables exist in both `data` and `reference`
8. Y column has no NAs in `data`
9. Predictor columns have no NAs in `data` or `reference`
10. Reference design weights are valid (positive, no NAs)
11. `nrow(data) > 0` and `nrow(reference) > 0`
12. `k` is a positive integer (for `nn` and `pmm_*`)
13. `npar_method` via `match.arg()` (for `npar`)
14. Unrecognized `...`: `surveycore_warning_unused_control_args`

### Computation

**Step 1 — Build formula.** If `response` is supplied, call
`reformulate(predictors %||% "1", response)`.

**Step 2 — Fit imputation model on NPS (`data`).** Dispatch to engine helper by
`method`:

- `.fit_mi_glm(data, formula, family)` → `glm` object from `stats::glm()`
- `.fit_mi_nn(data, formula, k, distance)` → list with NPS covariate matrix and outcome vector
- `.fit_mi_npar(data, formula, npar_method, bandwidth, k_gam)` → `gam` or `npreg` object
- `.fit_mi_pmm(data, formula, k, family)` → list with NPS predicted values and outcome vector

**Step 3 — Predict on reference.** Apply fitted model to `reference` covariates →
`y_hat`, a numeric vector of length `nrow(reference)`:

- GLM: `stats::predict(fit, newdata = ref_data, type = "response")`
- NN: kNN search in NPS covariate space; average observed Y of k donors
- NPAR/kernel: `np::npreg()` prediction on reference covariates
- NPAR/GAM: `mgcv::predict.gam()` on reference covariates
- PMM-A: match each reference unit's predicted ŷ to k closest NPS donor ŷ values; average donor observed Y
- PMM-B: match each reference unit's predicted ŷ to k closest NPS donor observed Y values; average

**Step 4 — Design-weighted estimate.**

```r
d        <- .get_weight_vec(reference)   # or equivalent surveycore internal
estimate <- sum(d * y_hat) / sum(d)
```

**Step 5 — Analytic variance.** For GLM and PMM, compute SE via §II formulas.
For NN and NPAR, `se <- NULL`.

**Step 6 — Build history entry** (§V). Store in `survey_mi_mean$history`.

**Step 7 — Build and return `survey_mi_mean`** (§VI).

### Output Contract

Returns `survey_mi_mean`: an S3 tibble subclass (see §VI) with one row containing
the estimate and SE for the specified outcome variable.

---

## V. History Entry Format

`mass_imputation()` produces one history entry, stored in `survey_mi_mean$history`
and (when `data` is `survey_nonprob`) appended to
`data@metadata@weighting_history`. This format must satisfy the contract in
`surveywts/plans/spec-methodology-nps-bootstrap.md` §Method 2:

```r
list(
  operation        = "mass_imputation",
  step             = <integer>,
  timestamp        = Sys.time(),
  formula          = <formula>,
  method           = <character>,      # internal code (see table below)
  family           = <character|NULL>, # "gaussian", "binomial", etc.; NULL for NN/PMM
  parameters       = list(...),        # method-specific
  reference_design = <survey_taylor>
)
```

`method` mapping from API to history code:

| API `method` | `npar_method` | History `method` |
|---|---|---|
| `"glm"` | — | `"glm"` |
| `"nn"` | — | `"nn"` |
| `"npar"` | `"gam"` | `"gam"` |
| `"npar"` | `"kernel"` | `"kernel"` |
| `"pmm_a"` | — | `"pmm_a"` |
| `"pmm_b"` | — | `"pmm_b"` |

`parameters` by method:

| Method | `parameters` |
|---|---|
| `"glm"` | `list(family = deparse(family))` |
| `"nn"` | `list(k = k, distance = distance)` |
| `"gam"` | `list(k_gam = k_gam)` |
| `"kernel"` | `list(bandwidth = resolved_bandwidth)` |
| `"pmm_a"` | `list(k = k, family = deparse(family))` |
| `"pmm_b"` | `list(k = k, family = deparse(family))` |

For kernel, `resolved_bandwidth` is the CV-selected value (not `NULL`) so the
hybrid bootstrap can reuse it without re-running CV in each draw.

`reference_design` stores the full `survey_taylor` object so the hybrid bootstrap
can resample the probability sample according to its design.

---

## VI. `survey_mi_mean` S3 Class

### Design

`survey_mi_mean` is a tibble subclass — the same pattern as `survey_mean`,
`survey_total`, and other surveycore result classes. Class vector:

```r
c("survey_mi_mean", "tbl_df", "tbl", "data.frame")
```

### Columns

| Column | Type | Always present? | Description |
|---|---|---|---|
| `outcome` | `character` | Yes | The Y variable name. |
| `estimate` | `numeric` | Yes | Design-weighted population mean estimate. |
| `se` | `numeric` or `NA` | Yes | Standard error. `NA_real_` for NN / NPAR. |
| `ci_lower` | `numeric` or `NA` | Yes | `estimate - 1.96 * se`. `NA_real_` when `se` is `NA`. |
| `ci_upper` | `numeric` or `NA` | Yes | `estimate + 1.96 * se`. `NA_real_` when `se` is `NA`. |
| `method` | `character` | Yes | The API method used: `"glm"`, `"nn"`, `"npar"`, `"pmm_a"`, `"pmm_b"`. |

### Attributes

Stored on the tibble via `attr()`:

| Attribute | Contents |
|---|---|
| `"mi_history"` | The history entry list (§V). |
| `"mi_model"` | The fitted model object (for diagnostics and bootstrap re-fitting). |
| `"mi_imputed"` | Numeric vector of imputed Ŷ values for reference units. |
| `"mi_reference"` | The `survey_taylor` reference design. |
| `"mi_nps"` | The NPS input (`survey_nonprob` with history appended, or original `data.frame`). |

### Constructor

`survey_mi_mean` is produced only as output from `mass_imputation()`. Users never
construct it directly.

### Print Method

`print.survey_mi_mean()` returns `invisible(x)`.

Verbatim console output for `method = "glm"`:

```
# A <survey_mi_mean> [method: GLM | gaussian]
# NPS (n_B): 1,200 units  |  Reference (n_A): 800 units
#
# Assumption: Transportability (Wu 2022, A3) — P(Y|X) is the same in the
# NPS as in the target population. This assumption is untestable.

 outcome    estimate    se    ci_lower    ci_upper
 <chr>         <dbl> <dbl>       <dbl>       <dbl>
 y             12.34  0.41       11.54       13.14
```

Verbatim console output for `method = "nn"` (no SE):

```
# A <survey_mi_mean> [method: NN | k = 1]
# NPS (n_B): 1,200 units  |  Reference (n_A): 800 units
#
# Assumption: Transportability (Wu 2022, A3) — P(Y|X) is the same in the
# NPS as in the target population. This assumption is untestable.
# Variance: SE requires the hybrid bootstrap. Use:
#   surveywts::create_bootstrap_weights(attr(result, "mi_nps"), type = "hybrid")

 outcome    estimate    se    ci_lower    ci_upper
 <chr>         <dbl> <lgl>      <lgl>       <lgl>
 y             12.34    NA          NA          NA
```

Verbatim console output for `method = "pmm_b"`:

```
# A <survey_mi_mean> [method: PMM-B | k = 5]
# NPS (n_B): 1,200 units  |  Reference (n_A): 800 units
#
# Assumption: Transportability (Wu 2022, A3) — P(Y|X) is the same in the
# NPS as in the target population. This assumption is untestable.

 outcome    estimate    se    ci_lower    ci_upper
 <chr>         <dbl> <dbl>       <dbl>       <dbl>
 y             12.34  0.44       11.48       13.20
```

---

## VII. Error and Warning Table

All new classes must be added to `plans/error-messages.md` before implementation.

### Errors

| Class | Trigger | Message template |
|---|---|---|
| `surveycore_error_unsupported_class` | `data` is not `data.frame` or `survey_nonprob` | `"x"`: `{.arg data}` must be a {.cls data.frame} or {.cls survey_nonprob}. `"i"`: Got {.cls {class(data)[[1]]}}. |
| `surveycore_error_replicate_not_supported` | `data` is `survey_replicate` | `"x"`: {.arg data} is a {.cls survey_replicate}, which is not supported. `"v"`: Pass the underlying {.cls survey_nonprob} instead. |
| `surveycore_error_reference_not_taylor` | `reference` is not `survey_taylor` | `"x"`: {.arg reference} must be a {.cls survey_taylor}. `"i"`: Got {.cls {class(reference)[[1]]}}. |
| `surveycore_error_formula_conflict` | Both `formula` and `response`/`predictors` supplied | `"x"`: {.arg formula} and {.arg response} cannot both be supplied. `"v"`: Use {.arg formula} or {.arg response}/{.arg predictors}, not both. |
| `surveycore_error_formula_missing` | Neither `formula` nor `response` supplied | `"x"`: An outcome formula is required. `"v"`: Supply {.arg formula} (e.g. {.code formula = y ~ x1}) or {.arg response}. |
| `surveycore_error_formula_missing` | `predictors` supplied without `response` | `"x"`: {.arg predictors} requires {.arg response}. `"v"`: Add {.arg response = "<column>"}. |
| `surveycore_error_response_not_in_nps` | LHS variable not found in `data` | `"x"`: Response variable {.field {response_var}} not found in {.arg data}. |
| `surveycore_error_predictor_not_in_nps` | RHS variable not found in `data` | `"x"`: Predictor {.field {missing_var}} not found in {.arg data}. |
| `surveycore_error_predictor_not_in_reference` | RHS variable not found in `reference` | `"x"`: Predictor {.field {missing_var}} not found in {.arg reference}. `"i"`: All predictor variables must appear in both {.arg data} and {.arg reference}. |
| `surveycore_error_response_has_na` | Y has NAs in `data` | `"x"`: Response {.field {response_var}} has {n_na} NA value{?s} in {.arg data}. `"v"`: Remove rows with missing {.field {response_var}} before calling {.fn mass_imputation}. |
| `surveycore_error_predictor_has_na_nps` | Predictor has NAs in `data` | `"x"`: Predictor {.field {pred_var}} has {n_na} NA value{?s} in {.arg data}. |
| `surveycore_error_predictor_has_na_reference` | Predictor has NAs in `reference` | `"x"`: Predictor {.field {pred_var}} has {n_na} NA value{?s} in {.arg reference}. |
| `surveycore_error_empty_data` | `nrow(data) == 0` | `"x"`: {.arg data} has 0 rows. (Reuse existing class.) |
| `surveycore_error_empty_data` | `nrow(reference) == 0` | `"x"`: {.arg reference} has 0 rows. (Reuse existing class.) |
| `surveycore_error_k_not_positive` | `k` ≤ 0 or non-integer | `"x"`: {.arg k} must be a positive integer. `"i"`: Got {.val {k}}. |
| `surveycore_error_package_required` | `np` not installed for `npar_method = "kernel"` | `"x"`: Package {.pkg np} is required for {.code method = "npar"} with {.code npar_method = "kernel"}. `"v"`: Install with {.code install.packages("np")}. |
| `surveycore_error_package_required` | `FNN` not installed for `method = "nn"` | `"x"`: Package {.pkg FNN} is required for {.code method = "nn"}. `"v"`: Install with {.code install.packages("FNN")}. |

### Warnings

| Class | Trigger | Message template |
|---|---|---|
| `surveycore_warning_unused_control_args` | Unrecognized `...` args | `"!"`: Unrecognized control argument{?s} {.field {paste(unused, collapse = ", ")}} ignored for {.code method = "{method}"}. |
| `surveycore_warning_k_exceeds_nps` | `k > nrow(data)` | `"!"`: {.arg k} ({k}) exceeds NPS size ({nrow(data)}). Using {.arg k = {nrow(data)}} instead. |
| `surveycore_warning_intercept_only_model` | `predictors = NULL` with `response` | `"!"`: No predictors supplied — fitting intercept-only model. The MI estimate reduces to the design-weighted NPS mean and does not leverage covariate information. |

---

## VIII. Dependencies

### Package Dependencies

| Package | Used for | Dependency type |
|---|---|---|
| `stats` | `stats::glm()`, `stats::predict.glm()`, `stats::reformulate()` | `Imports` (already in DESCRIPTION) |
| `mgcv` | `mgcv::gam()`, `mgcv::predict.gam()` for NPAR/GAM | `Imports` (widely available; GAM is a core MI method) |
| `np` | `np::npreg()` for NPAR/kernel | `Suggests`; runtime check + `surveycore_error_package_required` |
| `FNN` | `FNN::get.knnx()` for NN | `Suggests`; runtime check + `surveycore_error_package_required` |

> ⚠️ GAP: Confirm whether `mgcv` is already in DESCRIPTION. If not, adding it to
> `Imports` is the right call — `mgcv` ships with R (it is a recommended package) and
> GAM imputation is the default NPAR method.

---

## IX. Testing Plan

### File Mapping

| Source file | Test file |
|---|---|
| `R/analysis-mi.R` | `tests/testthat/test-analysis-mi.R` |

### Test Categories

Per `testing-standards.md`, all three categories are required.

#### 1. Happy-Path Tests

One block per method × input class combination:

- `method = "glm"`, `data = data.frame` — returns `survey_mi_mean`, numeric estimate, numeric SE
- `method = "glm"`, `data = survey_nonprob` — history appended to `attr(result, "mi_nps")`
- `method = "glm"`, `response`/`predictors` interface — estimate matches `formula` interface
- `method = "nn"`, k=1 — returns `survey_mi_mean`, `se` is `NA_real_`
- `method = "nn"`, k=3 — returns `survey_mi_mean`, `se` is `NA_real_`
- `method = "npar"`, `npar_method = "gam"` — returns `survey_mi_mean`, `se` is `NA_real_`
- `method = "npar"`, `npar_method = "kernel"` — returns `survey_mi_mean`, `se` is `NA_real_`
- `method = "pmm_a"` — returns `survey_mi_mean`, numeric SE
- `method = "pmm_b"` — returns `survey_mi_mean`, numeric SE
- Intercept-only (`predictors = NULL`) — valid; emits `surveycore_warning_intercept_only_model`

#### 2. Numerical Correctness Tests

Each uses `skip_if_not_installed("nonprobsvy")` inside the block:

- GLM estimate matches `nonprobsvy::nonprobSvy()` with `method = "glm"` within `1e-8`
- NN estimate matches `nonprobsvy::nonprobSvy()` with `method = "nn"` within `1e-8`
- PMM-A and PMM-B estimates match nonprobsvy within `1e-6`

> ⚠️ GAP: Verify nonprobsvy's PMM interface before writing these tests — PMM-A and
> PMM-B may not be exposed as separate method strings in nonprobsvy.

#### 3. Error-Path Tests

Dual pattern (`expect_error(class=)` + `expect_snapshot(error=TRUE)`) for every
class in §VII. One block per class.

#### 4. Warning Tests

- `surveycore_warning_unused_control_args`: `mass_imputation(..., unknown_arg = 1)`
- `surveycore_warning_k_exceeds_nps`: `k = 9999` with small NPS
- `surveycore_warning_intercept_only_model`: `response = "y", predictors = NULL`

#### 5. Edge Cases

- `k = nrow(data)` for NN — valid; uses all NPS units as potential donors
- Binary outcome with `family = binomial()` for GLM
- Very small NPS (n_B = 5) — produces estimate with (potentially unreliable) SE
- Single-predictor formula

#### 6. History / Attribute Tests

- `attr(result, "mi_history")$operation == "mass_imputation"`
- `attr(result, "mi_history")$method` matches history method code (not API string)
- `attr(result, "mi_history")$reference_design` is a `survey_taylor`
- When `data` is `survey_nonprob`, history appended to `@metadata@weighting_history`
  (length increases by 1)
- `attr(result, "mi_model")` is non-NULL for all methods
- `attr(result, "mi_imputed")` has length equal to `nrow(reference)`

#### 7. Print Snapshot Tests

One snapshot per method (6 total).

### Synthetic Test Data

Use the GSS dataset (per CLAUDE.md) or inline data for unit tests. For the
probability sample reference, add a helper `make_mi_reference()` to
`tests/testthat/helper-survey-mi.R`:

```r
make_mi_reference <- function(n = 300, seed = 42) {
  set.seed(seed)
  data.frame(
    age   = sample(18:90, n, replace = TRUE),
    sex   = sample(c("M", "F"), n, replace = TRUE),
    edu   = sample(1:4, n, replace = TRUE),
    stratum = sample(1:4, n, replace = TRUE),
    wt    = exp(rnorm(n, 0, 0.3))
  ) |>
    as_survey(weights = wt, strata = stratum)
}
```

### Numerical Tolerances

| Check | Tolerance |
|---|---|
| Estimate vs. nonprobsvy reference | `1e-8` |
| SE vs. nonprobsvy reference | `1e-6` |
| Design-weighted sum check | `1e-10` |

---

## X. Open Design Questions

**Q1: Internal variance helper reuse.**
The design variance component of GLM/PMM SE is the Taylor variance of a design-weighted
mean of Ŷ values. Surveycore already computes this inside `get_means()`. Should
`mass_imputation()` call an internal helper shared with `get_means()`, or construct
the design variance separately? Reuse is preferred (DRY) but requires confirming which
internal helper handles the Taylor mean variance.

**Q2: History storage when `data` is a plain `data.frame`.**
When `data` is a plain `data.frame`, there is no `survey_nonprob` to append history
to. The history entry in `attr(result, "mi_history")` is always present, but the
`surveywts` hybrid bootstrap also looks at `survey_nonprob@metadata@weighting_history`.
If the user passes a plain `data.frame` and later wants to run the hybrid bootstrap,
they must pass `attr(result, "mi_nps")`. Confirm this is the intended workflow and
document it clearly in `?mass_imputation`.

**Q3: `mgcv` in Imports vs. Suggests.**
`mgcv` ships with R as a recommended package, so it is available in all standard R
installations. Adding it to `Imports` rather than `Suggests` eliminates a runtime
check and simplifies the code. Confirm with the user.

**Q4: FNN vs. RANN for NN backend.**
Both `FNN::get.knnx()` and `RANN::nn2()` support fast approximate kNN. `FNN` is more
established; `RANN` is faster in high dimensions. Decision needed before implementation.

**Q5: GLM variance formula precision.**
See §II ⚠️ GAP. The methodology review must verify whether the NPS-residual
approximation for the imputation variance component matches or deviates materially
from Kim & Wang (2021) §3.

**Q6: PMM variance formula verification.**
See §II ⚠️ GAP. Chlebicki et al. (2024) Theorems 1 and 2 must be checked directly.

---

## XI. Quality Gates

The phase is complete when all of the following are true:

- [ ] `mass_imputation()` implemented for all five `method` values
- [ ] All error and warning classes added to `plans/error-messages.md`
- [ ] `print.survey_mi_mean()` output matches verbatim examples in §VI
- [ ] History entry format matches §V exactly (verified by test)
- [ ] All happy-path, error-path, warning, edge case, and history tests pass
- [ ] All 6 print snapshots committed
- [ ] Numerical correctness tests pass within stated tolerances
- [ ] `devtools::check()` passes: 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] New error/warning classes added to `plans/error-messages.md`

---

## XII. References

| Source | Role |
|---|---|
| Kim, Park, Chen & Wu (2021) | Foundational asymptotic theory; linearization and bootstrap variance for MI-GLM; transportability condition |
| Yang, Kim & Hwang (2021) | k-NN, GAM, and calibration-efficiency mass imputation; variance decomposition |
| Chen, Yang & Kim (2022) | Kernel and GAM imputers; hybrid bootstrap; noninformative sampling assumption |
| Chlebicki, Chrostowski & Beresewicz (2024) | PMM-A and PMM-B; closed-form analytic variance |
| Chrostowski, Chlebicki & Beresewicz (2025) | nonprobsvy reference implementation |
| Wu (2022) | Formal A1-A4 assumptions; df = ∞ for NPS; bootstrap preferred over jackknife |
| `surveywts/plans/spec-methodology-nps-bootstrap.md` | Pre-decided history entry format; hybrid bootstrap reads this entry |
| `plans/decisions-nonprob-bootstrap-variance.md` | df = Inf policy for NPS; bootstrap-only restriction |
