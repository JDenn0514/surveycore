# Access the Data Component of a Survey Design Object

Returns the underlying data frame stored in a survey design object. This
is a thin accessor for `x@data` that provides a stable public name
independent of the S7 property structure.

## Usage

``` r
survey_data(x)
```

## Arguments

- x:

  A `survey_taylor`, `survey_replicate`, or `survey_twophase` object.

## Value

A `data.frame` with all variables, including design variables.

## See also

Other constructors:
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md),
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md),
[`survey_glm_fit()`](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md),
[`survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/survey_nonprob.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)

## Examples

``` r
d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
               strata = sdmvstra, nest = TRUE)
head(survey_data(d))
#>    seqn sdmvpsu sdmvstra  wtmec2yr  wtint2yr ridstatr riagendr ridageyr
#> 1 93703       2      145  8539.731  9246.492        2        2        2
#> 2 93704       1      143 42566.615 37338.768        2        1        2
#> 3 93705       2      145  8338.420  8614.571        2        2       66
#> 4 93706       2      134  8723.440  8548.633        2        1       18
#> 5 93707       1      138  7064.610  6769.345        2        1       13
#> 6 93708       2      138 14372.489 13329.451        2        2       66
#>   ridreth3 indfmpir dmdeduc2 bpxsy1 bpxdi1 bpxpls
#> 1        6     5.00       NA     NA     NA     NA
#> 2        3     5.00       NA     NA     NA     NA
#> 3        4     0.82        2     NA     NA     52
#> 4        6       NA       NA    112     74     82
#> 5        7     1.88       NA    128     38    100
#> 6        6     1.63        1     NA     NA     68
```
