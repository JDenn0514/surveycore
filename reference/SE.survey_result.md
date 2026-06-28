# Extract standard errors from a survey result object

Returns a named numeric vector of standard errors from a `survey_result`
object. Values are `sqrt(diag(vcov(object)))`, ensuring consistency
between [`SE()`](https://jdenn0514.github.io/surveycore/reference/SE.md)
and [`vcov()`](https://rdrr.io/r/stats/vcov.html).

## Usage

``` r
# S3 method for class 'survey_result'
SE(object, ...)
```

## Arguments

- object:

  A `survey_result` object from any supported `get_*()` function.

- ...:

  Unused.

## Value

A named numeric vector. Names are identical to `names(coef(object))`.
`NA` entries propagate from missing `se` column or `NA` in `se`.

## Note

[`vcov.survey_result()`](https://jdenn0514.github.io/surveycore/reference/vcov.survey_result.md)
emits `surveycore_warning_vcov_diagonal_only` when `p > 1`. This warning
is suppressed inside `SE.survey_result()` because the off-diagonal
structure is irrelevant when only standard errors are requested. Call
`vcov(result)` directly to observe this warning.

## Examples

``` r
d <- as_survey(
  nhanes_2017,
  ids = sdmvpsu,
  weights = wtint2yr,
  strata = sdmvstra,
  nest = TRUE
)
result <- get_means(d, ridageyr, variance = "se")
SE(result)
#>  ridageyr 
#> 0.5244057 
```
