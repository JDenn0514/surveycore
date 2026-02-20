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
df <- data.frame(
  psu = rep(1:5, each = 4),
  st  = rep(c("A", "B"), each = 10),
  wt  = rep(c(2, 3, 2, 4, 3), each = 4),
  y   = rnorm(20)
)
d <- as_survey(df, ids = psu, strata = st, weights = wt)
#> Warning: ! Some PSUs appear in more than one stratum: "3". If PSUs are nested within
#>   strata, set `nest = TRUE`.
get_means(d, y)
#> $variable
#> [1] "y"
#> 
#> $mean
#> [1] 0.03564473
#> 
#> $se
#> [1] 0.1617288
#> 
```
