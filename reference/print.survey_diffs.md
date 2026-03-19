# Print a Survey Diffs Result

Prints a structured header showing design type, family, dependent
variable, treatment variable with reference level, and estimation
method, then delegates to the tibble print method for the body.

## Usage

``` r
# S3 method for class 'survey_diffs'
print(x, ...)
```

## Arguments

- x:

  A `survey_diffs` object.

- ...:

  Passed to the tibble print method.

## Value

`x`, invisibly.
