# Extract variance-covariance matrix from a survey result object

Returns a named numeric matrix from a `survey_result` object. The
diagonal contains per-parameter variances (`se^2`). Off-diagonal
elements are structural zeros for most classes (except `survey_corr`
with multiple pair rows, which uses `NA_real_`).

## Usage

``` r
# S3 method for class 'survey_result'
vcov(object, ...)
```

## Arguments

- object:

  A `survey_result` object from any supported `get_*()` function.

- ...:

  Unused.

## Value

A `p × p` numeric matrix with `rownames` and `colnames` equal to
`names(coef(object))`. When `p > 1`, emits
`surveycore_warning_vcov_diagonal_only`. When the `se` column is absent,
returns a `p × p` matrix of `NA_real_` with no warning.

## Details

Off-diagonal elements represent the covariance between estimates. For
survey results, only the diagonal (per-estimate variances) is available
from stored per-row data. Cross-estimate covariances require joint
influence-function estimation from the original design. Zeros in
off-diagonal positions are approximations that may not hold when groups
share PSUs.

`survey_corr` (long-format) results with more than one pair row have
`NA_real_` off-diagonal elements and emit
`surveycore_warning_vcov_incomplete`.

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
vcov(result)
#>           ridageyr
#> ridageyr 0.2750013
```
