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
values are used.

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
#> ridageyr 37.30623 39.54172
confint(result, level = 0.90)
#>               5 %     95 %
#> ridageyr 37.50466 39.34328
```
