# Survey-Weighted GLM Fit Object

S7 class produced by
[`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md).
Holds all regression output from a survey-weighted generalised linear
model: design-based coefficient estimates, variance-covariance matrix,
fitted values, residuals, and model metadata.

## Usage

``` r
survey_glm_fit(
  coefficients = integer(0),
  vcov = NULL,
  fitted_values = integer(0),
  residuals = integer(0),
  weights = integer(0),
  design = survey_base(),
  degf = integer(0),
  family = list(),
  formula = NULL,
  null_deviance = integer(0),
  deviance = integer(0),
  df_null = integer(0),
  df_residual = integer(0),
  converged = logical(0),
  call = NULL,
  fit_ = NULL
)
```

## Arguments

- coefficients:

  Named numeric vector of length `p`.

- vcov:

  `p × p` design-based variance-covariance matrix.

- fitted_values:

  Numeric vector of length `n` (response scale).

- residuals:

  Working residuals from IRLS, length `n`.

- weights:

  Survey weights used in fitting, length `n`.

- design:

  The original
  [survey_base](https://jdenn0514.github.io/surveycore/reference/survey_base.md)
  survey design object.

- degf:

  Raw design degrees of freedom (positive scalar): number of PSUs minus
  number of strata for Taylor designs, number of replicates minus one
  for replicate designs, and `n - 1` for SRS designs. This is *not* the
  residual degrees of freedom used for t-statistics and confidence
  intervals; those are computed as `degf - (p - 1)` where `p` is the
  number of model coefficients.

- family:

  GLM family object (e.g.
  [`gaussian()`](https://rdrr.io/r/stats/family.html),
  [`binomial()`](https://rdrr.io/r/stats/family.html)).

- formula:

  Model formula.

- null_deviance:

  Null model deviance.

- deviance:

  Residual deviance.

- df_null:

  Classical null df (`fit$df.null` from
  [`stats::glm()`](https://rdrr.io/r/stats/glm.html)).

- df_residual:

  Classical residual df (`fit$df.residual`, i.e. `n - p`). Used for the
  deviance display; **not** the design-based residual df.

- converged:

  Logical; whether IRLS converged.

- call:

  The
  [`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md)
  call (language object or `NULL`).

- fit\_:

  Internal raw [`stats::glm()`](https://rdrr.io/r/stats/glm.html)
  result; `NULL` after serialisation.

## Value

A `survey_glm_fit` object.

## See also

[`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md)
to create a `survey_glm_fit`.

Other constructors:
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md),
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_data()`](https://jdenn0514.github.io/surveycore/reference/survey_data.md),
[`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md),
[`survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/survey_nonprob.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)

## Examples

``` r
# survey_glm_fit objects are created by survey_glm(), not directly
d <- as_survey(gss_2024, ids = vpsu, weights = wtssps,
               strata = vstrat, nest = TRUE)
fit <- survey_glm(d, age ~ sex)
fit@coefficients
#> (Intercept)         sex 
#>  47.5603545   0.2595301 
```
