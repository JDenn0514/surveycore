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
  control = list(),
  quiet = FALSE
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

- quiet:

  Logical. If `TRUE`, suppresses convergence warnings emitted by
  `survey_glm()` and its internal replicate-weight refitting loop.
  Convergence status is always stored in `fit@converged` regardless of
  this setting, so non-convergence can still be detected
  programmatically. Default `FALSE`.

## Value

A
[survey_glm_fit](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md)
S7 object.

## Details

**Variance estimation:** Uses the Binder (1983) sandwich estimator,
which decomposes into per-observation score vectors passed to the Phase
0 variance machinery. The bread `(X'WX)^(-1)` accounts for IRLS working
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

**Formula to model matrix:** `survey_glm()` passes the formula to
[`stats::model.matrix()`](https://rdrr.io/r/stats/model.matrix.html) via
[`stats::glm()`](https://rdrr.io/r/stats/glm.html). Factor and character
predictors are dummy-coded using
[`model.matrix()`](https://rdrr.io/r/stats/model.matrix.html) default
contrasts (treatment coding: first level as reference). Numeric
predictors enter as-is. Interaction terms (`:`, `*`) and inline
transformations ([`log()`](https://rdrr.io/r/base/Log.html),
[`I()`](https://rdrr.io/r/base/AsIs.html)) are supported as in any
standard R formula. The resulting model matrix is `n x p` where `p` is
the number of coefficients including the intercept.

**Predictor variable types:** Predictors may be numeric, integer,
logical, factor, or character. Character predictors are coerced to
factor by
[`stats::model.matrix()`](https://rdrr.io/r/stats/model.matrix.html).
Ordered factors use polynomial contrasts by default. All other R types
(list columns, complex, raw) will produce an error from
[`stats::model.matrix()`](https://rdrr.io/r/stats/model.matrix.html).

**Input assumptions:** surveycore assumes (1) each row of `design@data`
represents one sampled unit; (2) survey weights are positive and finite
for all rows (validated at construction time); (3) the model formula
variables are columns of `design@data`; (4) the design is correctly
specified before calling `survey_glm()`. No centering, scaling, or other
pre-processing is applied to predictor variables beyond what the formula
specifies.

**Data transformations:** No automatic transformation is applied to
predictor or response variables. Factor encoding is handled by
[`stats::model.matrix()`](https://rdrr.io/r/stats/model.matrix.html)
using the active contrasts. Link function transformations (e.g. `log`
link in [`poisson()`](https://rdrr.io/r/stats/family.html)) are applied
by the family object, not by surveycore. To apply custom
transformations, use [`I()`](https://rdrr.io/r/base/AsIs.html) or
[`log()`](https://rdrr.io/r/base/Log.html) etc. inside the formula.

**Row and column names:** The coefficient vector returned in
`fit@coefficients` carries the names produced by
[`stats::model.matrix()`](https://rdrr.io/r/stats/model.matrix.html)
(e.g. `"(Intercept)"`, `"sexFemale"`, `"age"`). `fit@vcov` carries the
same names on rows and columns. `model.frame.survey_glm_fit()` returns
the model frame with row names matching the rows used in fitting (i.e.
the row names of `design@data` after applying `na.action`). Rows
excluded by `na.action = na.omit` do not appear in the model frame.

**Missing values:** `na.action` controls handling of `NA` in model frame
variables (predictors and response). `na.omit` (default) silently drops
rows with any `NA`; the variance estimator uses the full design for
correct sandwich SEs. `na.fail` stops with an informative error listing
all variables containing `NA` and the row count for each. Survey weights
are validated separately at construction time and must not contain `NA`.

**Performance:** Runtime scales as O(*n* · *p*²) for the score matrix
computation and O(*p*³) for the bread matrix (solve). For Taylor
designs, variance estimation adds O(*n* · *H* · *p*²) where *H* is the
number of strata. For replicate designs it adds O(*R* · *n* · *p*) where
*R* is the number of replicates. The dominant cost for large *n* is
typically the [`stats::glm()`](https://rdrr.io/r/stats/glm.html) IRLS
fit (O(*n* · *p*² · *I*) per IRLS iteration).

## References

Binder, D.A. (1983) On the variances of asymptotically normal estimators
from complex surveys. *International Statistical Review* **51**(3),
279–292.

Binder, D.A. (1991) Use of estimating functions for interval estimation
from complex surveys. *Proceedings of the American Statistical
Association, Section on Survey Research Methods*, 34–42.

Lumley, T. and Scott, A. (2014) Tests in surveys with complex sampling.
*Journal of the Royal Statistical Society: Series B* **76**(2), 431–452.

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
