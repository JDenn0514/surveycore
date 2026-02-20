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
[`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)

## Examples

``` r
df <- data.frame(y = rnorm(10), w = runif(10, 0.5, 2))
d  <- as_survey(df, weights = w)
head(survey_data(d))
#>              y         w
#> 1 -0.098550690 1.9507087
#> 2  0.034766060 0.6290585
#> 3  0.386127022 0.8606919
#> 4  0.020831228 1.4583256
#> 5  0.007586777 1.2550926
#> 6  0.930844030 0.8757849
```
