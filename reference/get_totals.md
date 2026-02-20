# Estimate Weighted Total for a Survey Design

Computes the weighted total and its standard error for a single variable
using the appropriate variance estimator for the survey design type. For
`survey_taylor` designs, Taylor series linearization is used.

## Usage

``` r
get_totals(design, var, na.rm = TRUE)
```

## Arguments

- design:

  A `survey_taylor` design object created by
  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md).

- var:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  A single unquoted variable name to estimate the total of.

- na.rm:

  Logical. If `TRUE` (default), missing values are excluded before
  computing the total. Set to `FALSE` to propagate `NA`.

## Value

A named list with elements:

- `variable`:

  Character. Name of the estimated variable.

- `total`:

  Numeric. Weighted total estimate.

- `se`:

  Numeric. Standard error of the total.

## See also

Other estimation:
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md)

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
get_totals(d, y)
#> $variable
#> [1] "y"
#> 
#> $total
#> [1] 9.168519
#> 
#> $se
#> [1] 10.36028
#> 
```
