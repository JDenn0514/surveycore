# Print a Survey Result Object

Prints a labelled header showing the specific result class and
dimensions, then delegates to the tibble print method for the tabular
content.

## Usage

``` r
# S3 method for class 'survey_result'
print(x, ...)
```

## Arguments

- x:

  A `survey_result` object.

- ...:

  Passed to the tibble print method.

## Value

`x`, invisibly.

## Examples

``` r
result <- structure(
  tibble::tibble(mean = 42.0, se = 1.5, n = 100L),
  .meta = list(
    design_type = "taylor", conf_level = 0.95,
    call = quote(get_means(d, x)), group_names = character(0),
    group_labels = list(), n_respondents = 100L,
    variable = "x", variable_label = NULL,
    question_preface = NULL, value_labels = list(x = NULL)
  ),
  class = c("survey_means", "survey_result", "tbl_df", "tbl", "data.frame")
)
print(result)
#> # A tibble: 1 × 3
#>    mean    se     n
#> * <dbl> <dbl> <int>
#> 1    42   1.5   100
```
