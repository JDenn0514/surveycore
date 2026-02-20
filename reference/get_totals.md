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
# ACS PUMS Wyoming: estimated total population by age
d <- as_survey_rep(acs_pums_wy, weights = pwgtp,
                   repweights = matches("^pwgtp[0-9]+$"),
                   type = "successive-difference")
get_totals(d, agep)
#> $variable
#> [1] "agep"
#> 
#> $total
#> [1] 23089173
#> 
#> $se
#> [1] 40314.74
#> 
```
