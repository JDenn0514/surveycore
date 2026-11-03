# Confidence intervals for survey result objects

Computes confidence intervals for the parameters of a `survey_result`
object using the t-distribution with per-parameter degrees of freedom
stored in `attr(object, ".survey_result")$df`.

## Usage

``` r
# S3 method for class 'survey_result'
confint(object, parm, level = 0.95, ...)
```

## Arguments

- object:

  A `survey_result` object from any supported `get_*()` function.

- parm:

  A numeric, integer, or character vector selecting a subset of
  parameters, or missing (all parameters). Character `parm` is matched
  against `names(coef(object))`.

- level:

  Confidence level, strictly between 0 and 1. Default `0.95`.

- ...:

  Unused.

## Value

A numeric matrix with two columns. Column names are `"2.5 %"` and
`"97.5 %"` for `level = 0.95` (matching
[`stats::confint.default()`](https://rdrr.io/r/stats/confint.html)
format). Rownames are `names(coef(object))[parm]`. Dimensions:
`length(parm) × 2`.

## Details

For non-calibrated Taylor, replicate, and nonprob designs, `df = Inf` is
stored, so `qt(1 - (1 - level)/2, df = Inf)` equals `qnorm(...)` — a
normal approximation. For calibrated Taylor designs, per-cell finite df
values are used. Either way the stored df is the one behind the result's
`ci_low` and `ci_high` columns, so for
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
[`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md)
and
[`get_covariance()`](https://jdenn0514.github.io/surveycore/reference/get_covariance.md),
`confint(object, level = l)` returns the same interval as those columns
when the result was computed at `conf_level = l`. This holds on a
filtered (domain) design too.

When `SE(object)[i]` is `NA`, the corresponding CI row is `c(NA, NA)`.

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
confint(result)
#>             2.5 %   97.5 %
#> ridageyr 37.39616 39.45179
confint(result, level = 0.90)
#>              5 %     95 %
#> ridageyr 37.5614 39.28654
```
