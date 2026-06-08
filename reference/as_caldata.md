# Build a Calibration Data Element

Constructs a calibration data object from base sampling weights,
g-weights (calibration factors), and a model matrix of calibration
covariates. The returned list is suitable for assignment to the
`@calibration` slot of a
[survey_taylor](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md)
or
[survey_replicate](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md)
object.

## Usage

``` r
as_caldata(base_weights, g_weights, model_matrix)
```

## Arguments

- base_weights:

  A numeric vector of positive, finite base sampling weights (length n).
  These are the original sampling weights before calibration is applied.
  Must not contain `NA`, `NaN`, or `Inf`.

- g_weights:

  A numeric vector of positive, finite g-factors (length n). The
  calibrated weights are `base_weights * g_weights`. g-factors equal to
  1.0 represent no adjustment. Must not contain `NA`, `NaN`, or `Inf`.
  Must have the same length as `base_weights`. The internal quantity
  `g_weights * sqrt(base_weights)` must not have any near-zero values
  (below `sqrt(.Machine$double.eps)`); if it does, a
  `surveycore_error_caldata_weights_near_zero` warning is issued.

- model_matrix:

  A numeric matrix with `n` rows and at least 1 column, representing the
  calibration covariates used during post-stratification or raking. Must
  not contain `NA`, `NaN`, or `Inf`.

## Value

A named list with four elements:

- `qr`:

  A QR decomposition (class `"qr"`) of
  `sqrt(base_weights) * model_matrix`. Used for calibration projection
  in variance estimation.

- `w`:

  A numeric vector of length n equal to
  `g_weights * sqrt(base_weights)`. This intermediate quantity (the
  square root of the calibrated weights scaled by g) is used directly in
  the GREG variance projection formula.

- `stage`:

  Integer scalar `0L`. Currently only between-PSU calibration (stage 0)
  is supported.

- `index`:

  `NULL`. Reserved for future within-PSU calibration support.

## Details

The resulting calibration object is used by the variance estimation
routines to apply a Deville-Sarndal (1992) calibration correction to
Taylor-series and replicate-weight variance estimates.

**GLM limitation**: Using a calibrated `survey_taylor` object with
[`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md)
produces correct but conservative standard errors until GREG-GLM
variance is implemented in a future release. The calibration correction
is not applied in the GLM variance path.

## Inter-package contract

**GREG calibration (single auxiliary variable or multiple uncorrelated
variables):** pass the model matrix from `model.matrix(formula, data)`
directly – one column per calibration variable. The intercept column
(`(Intercept)`) is included by default from
[`model.matrix()`](https://rdrr.io/r/stats/model.matrix.html); it
contributes one degree of freedom to the calibration adjustment.

**Raking (multiple calibration margins, Architecture A):** combine all
margin indicator matrices into a single matrix before calling
`as_caldata()`. Column-bind the matrices and drop one reference column
per margin to avoid rank deficiency (e.g., drop the last column of each
per-margin block). Pass this single combined matrix. Do **not** call
`as_caldata()` once per margin; that uses Architecture B (sequential),
which requires a separate `as_caldata()` element per calibration pass
and stores them all in the `@calibration` list.

**q_k = 1 assumption:** `as_caldata()` always assumes \\q_k = 1\\
(uniform calibration weights). If your calibration uses a non-unity
\\q_k\\ (variance-function weights from
`survey::calibrate( calfun = "linear", variance = ...)`) you must absorb
those weights into `model_matrix` before calling `as_caldata()`.

## For `survey_replicate` designs

`@calibration` on a `survey_replicate` object is **provenance-only**: it
documents that the replicate weights were derived from a calibrated
design, but the variance estimator does not apply any GREG projection.
Calibration is already encoded in the replicate weights themselves. Do
not expect
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md)
SE to differ between a `survey_replicate` with and without
`@calibration` set.

## References

Deville, J.-C., and Sarndal, C.-E. (1992). Calibration estimators in
survey sampling. *Journal of the American Statistical Association*, 87,
376–382.

## See also

[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
for Taylor series designs,
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md)
for replicate-weight designs,
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)
for two-phase designs

Other constructors:
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md),
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md),
[`survey_glm_fit()`](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md),
[`survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/survey_nonprob.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)

## Examples

``` r
# Minimal example: 3-unit design, intercept-only calibration
base_weights <- c(2.5, 3.0, 4.0)
g_weights <- c(1.02, 0.98, 1.01)
model_matrix <- matrix(1, nrow = 3, ncol = 1)

cd <- as_caldata(base_weights, g_weights, model_matrix)
names(cd) # "qr", "w", "stage", "index"
#> [1] "qr"    "w"     "stage" "index"

# Assign to a survey_taylor design
df <- data.frame(y = c(1.2, 2.3, 3.4), wt = base_weights)
design <- as_survey(df, weights = wt)
design@calibration <- list(cd)
is.null(design@calibration) # FALSE
#> [1] FALSE
```
