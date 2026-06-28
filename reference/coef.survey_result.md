# Extract coefficients from a survey result object

Returns a named numeric vector of point estimates from a `survey_result`
object (produced by
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
[`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md),
[`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md),
[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md),
[`get_covariance()`](https://jdenn0514.github.io/surveycore/reference/get_covariance.md),
or
[`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md)).

## Usage

``` r
# S3 method for class 'survey_result'
coef(object, ...)
```

## Arguments

- object:

  A `survey_result` object from any supported `get_*()` function.

- ...:

  Unused. Reserved for future extensions.

## Value

A named numeric vector. Names follow variable-major, group-secondary
ordering matching
[`survey::coef.svyby()`](https://rdrr.io/pkg/survey/man/svyby.html). For
grouped results, names are `"group_value:variable_name"` (e.g.,
`"A:y1"`, `"B:y1"`). For ungrouped results, names are the variable name
(e.g., `"y1"`). See the spec for class-specific naming rules.

## Details

Not all `survey_result` subclasses support
[`coef()`](https://rdrr.io/r/stats/coef.html). `survey_t_test` and
`survey_pairwise` objects throw
`surveycore_error_result_method_unsupported`. Wide-format `survey_corr`
objects (from `get_corr(format = "wide")`) also throw this error. For
those objects, access columns directly (e.g., `result$estimate`,
`result$se`).

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
coef(result)
#> ridageyr 
#> 38.42397 
```
