# Fit a Survey-Weighted Generalised Linear Model

Fits a GLM to survey data, producing design-based coefficient estimates
and variance-covariance matrix via the Binder (1983) sandwich estimator.
All five surveycore design classes are supported.

## Usage

``` r
survey_glm(
  design,
  formula = NULL,
  response = NULL,
  predictors = NULL,
  family = stats::gaussian(),
  na.action = stats::na.omit,
  start = NULL,
  etastart = NULL,
  mustart = NULL,
  control = list()
)
```

## Arguments

- design:

  A survey design object created by
  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
  [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
  [`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
  or
  [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md).

- formula:

  A model formula in standard R notation (e.g. `y ~ x1 + x2`). Mutually
  exclusive with `response`/`predictors`. If `NULL` and `response` is
  also `NULL`, errors with `surveycore_error_formula_missing`.

- response:

  Character string naming the outcome variable. Programmatic alternative
  to `formula`. Mutually exclusive with `formula`. Use with `predictors`
  to build a model formula via `reformulate(predictors, response)`.
  Suitable for [`lapply()`](https://rdrr.io/r/base/lapply.html)
  iteration.

- predictors:

  Character vector of predictor variable names. Used with `response` to
  build the model formula. If `response` is supplied and `predictors` is
  `NULL`, an intercept-only model is fitted.

- family:

  A GLM family object specifying the error distribution and link
  function. Default [`gaussian()`](https://rdrr.io/r/stats/family.html).
  Any family accepted by
  [`stats::glm()`](https://rdrr.io/r/stats/glm.html) is supported. For
  [`binomial()`](https://rdrr.io/r/stats/family.html) and
  [`quasibinomial()`](https://rdrr.io/r/stats/family.html) families, the
  "non-integer \#successes" warning is suppressed because survey weights
  are non-integer by design.

- na.action:

  How to handle `NA` values in the model frame. Default `na.omit`
  (silently drops rows with any `NA` in model variables). `na.fail`
  errors with `surveycore_error_na_in_data` listing the offending
  columns and NA counts. Note: `na.action` applies only to model frame
  variables; survey weights are validated separately.

- start:

  Starting values for the coefficient vector.

- etastart:

  Starting values for the linear predictor.

- mustart:

  Starting values for the mean.

- control:

  A list of GLM control parameters passed to
  [`stats::glm.control()`](https://rdrr.io/r/stats/glm.control.html).

## Value

A
[survey_glm_fit](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md)
S7 object.

## Details

**Variance estimation:** Uses the Binder (1983) sandwich estimator,
which decomposes into per-observation score vectors passed to the Phase
0 variance machinery. The bread `(X'W̃X)⁻¹` accounts for IRLS working
weights and is correct for all GLM families including binomial and
Poisson.

**[`binomial()`](https://rdrr.io/r/stats/family.html) family:** Wraps
the [`stats::glm()`](https://rdrr.io/r/stats/glm.html) call in
[`suppressWarnings()`](https://rdrr.io/r/base/warning.html) to suppress
the "non-integer \#successes" warning that fires for every
survey-weighted binomial model.

**Domain estimation:** Use `surveytidy::filter()` before calling
`survey_glm()`. The GLM is fit on in-domain rows only; variance
estimation uses the full design for correct design-based SEs.

**Multinomial response:** [`cbind()`](https://rdrr.io/r/base/cbind.html)
on the LHS of `formula` is not supported. Multinomial logistic
regression is deferred to a later phase.

## See also

Other constructors:
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md),
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_data()`](https://jdenn0514.github.io/surveycore/reference/survey_data.md),
[`survey_glm_fit()`](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md),
[`survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/survey_nonprob.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)

## Examples

``` r
d <- as_survey(gss_2024, ids = vpsu, weights = wtssps, strata = vstrat,
               nest = TRUE)

# Linear model: respondent age predicted by education and sex
fit <- survey_glm(d, age ~ educ + sex)
fit@coefficients
#> (Intercept)        educ         sex 
#>  41.7912598   0.4033772   0.3367356 
fit@vcov
#>             (Intercept)         educ          sex
#> (Intercept)   7.5695740 -0.363231367 -1.401719626
#> educ         -0.3632314  0.025187314  0.002071918
#> sex          -1.4017196  0.002071918  0.895403410

# Programmatic interface — suitable for lapply()
results <- lapply(c("age", "educ"), function(v) {
  survey_glm(d, response = v, predictors = "sex")
})
```
