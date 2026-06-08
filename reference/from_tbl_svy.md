# Convert an srvyr tbl_svy to a surveycore Design Object

Converts an `srvyr` `tbl_svy` to a surveycore design object by
delegating to
[`from_svydesign()`](https://jdenn0514.github.io/surveycore/reference/from_svydesign.md).
A `tbl_svy` IS a `survey.design`, so the conversion is structurally
identical. Requires both `survey` and `srvyr`.

## Usage

``` r
from_tbl_svy(x)
```

## Arguments

- x:

  A [`srvyr::tbl_svy`](http://gdfe.co/srvyr/reference/tbl_svy.md)
  object.

## Value

A `survey_taylor`, `survey_replicate`, or `survey_twophase` object.

## See also

[`as_tbl_svy()`](https://jdenn0514.github.io/surveycore/reference/as_tbl_svy.md)
to convert in the other direction

Other conversion:
[`as_svydesign()`](https://jdenn0514.github.io/surveycore/reference/as_svydesign.md),
[`as_tbl_svy()`](https://jdenn0514.github.io/surveycore/reference/as_tbl_svy.md),
[`from_svydesign()`](https://jdenn0514.github.io/surveycore/reference/from_svydesign.md)

## Examples

``` r
if (
  requireNamespace("survey", quietly = TRUE) &&
    requireNamespace("srvyr", quietly = TRUE)
) {
  ts <- srvyr::as_survey(
    survey::svydesign(
      ids = ~sdmvpsu,
      weights = ~wtint2yr,
      strata = ~sdmvstra,
      data = nhanes_2017,
      nest = TRUE
    )
  )
  d <- from_tbl_svy(ts)
}
```
