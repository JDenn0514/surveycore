# Estimate Weighted Mean for a Survey Design

Computes the weighted mean and its standard error for a single variable
using the appropriate variance estimator for the survey design type. For
`survey_taylor` designs, Taylor series linearization is used.

## Usage

``` r
get_means(design, var, na.rm = TRUE)
```

## Arguments

- design:

  A `survey_taylor` design object created by
  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md).

- var:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  A single unquoted variable name to estimate the mean of.

- na.rm:

  Logical. If `TRUE` (default), missing values are excluded before
  computing the mean. Set to `FALSE` to propagate `NA`.

## Value

A named list with elements:

- `variable`:

  Character. Name of the estimated variable.

- `mean`:

  Numeric. Weighted mean estimate.

- `se`:

  Numeric. Standard error of the mean.

## See also

Other estimation:
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md)

## Examples

``` r
# NHANES 2017-2018: estimated mean age of U.S. civilian population
d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
               strata = sdmvstra, nest = TRUE)
get_means(d, ridageyr)
#> $variable
#> [1] "ridageyr"
#> 
#> $mean
#> [1] 38.42397
#> 
#> $se
#> [1] 0.5244057
#> 
```
