# Default SE method: extracts from vcov diagonal

Computes `sqrt(diag(vcov(object, ...)))`. Works for any object with a
[`vcov()`](https://rdrr.io/r/stats/vcov.html) method, including `lm`,
`glm`, and
[`survey::svystat`](https://rdrr.io/pkg/survey/man/surveysummary.html)
objects.

## Usage

``` r
# Default S3 method
SE(object, ...)
```

## Arguments

- object:

  An object with a [`vcov()`](https://rdrr.io/r/stats/vcov.html) method.

- ...:

  Forwarded to [`vcov()`](https://rdrr.io/r/stats/vcov.html).

## Value

A named numeric vector of standard errors.

## Note

When
[`surveycore::SE`](https://jdenn0514.github.io/surveycore/reference/SE.md)
masks [`survey::SE`](https://rdrr.io/pkg/survey/man/SE.html), this
default method covers
[`survey::svystat`](https://rdrr.io/pkg/survey/man/surveysummary.html)
objects but NOT
[`survey::svyby`](https://rdrr.io/pkg/survey/man/svyby.html) with
`vartype = "cvpct"`. Use
[`survey::SE()`](https://rdrr.io/pkg/survey/man/SE.html) explicitly in
that case.
