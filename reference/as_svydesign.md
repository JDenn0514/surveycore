# Convert a surveycore Design Object to a survey Package Design

Converts a `survey_taylor`, `survey_replicate`, or `survey_twophase`
object to the corresponding `survey` package object: `svydesign`,
`svrepdesign`, or `twophase`. Useful for accessing `survey` package
estimation functions or for round-trip testing.

## Usage

``` r
as_svydesign(x)
```

## Arguments

- x:

  A `survey_taylor`, `survey_replicate`, or `survey_twophase` object.

## Value

A [`survey::svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html),
[`survey::svrepdesign`](https://rdrr.io/pkg/survey/man/svrepdesign.html),
or [`survey::twophase`](https://rdrr.io/pkg/survey/man/twophase.html)
object.

## Details

Metadata (variable labels, value labels) is NOT carried over — the
`survey` package has no metadata system.

## See also

[`from_svydesign()`](https://jdenn0514.github.io/surveycore/reference/from_svydesign.md)
to convert back from a `survey` design

Other conversion:
[`as_tbl_svy()`](https://jdenn0514.github.io/surveycore/reference/as_tbl_svy.md),
[`from_svydesign()`](https://jdenn0514.github.io/surveycore/reference/from_svydesign.md),
[`from_tbl_svy()`](https://jdenn0514.github.io/surveycore/reference/from_tbl_svy.md)

## Examples

``` r
d <- as_survey(
  nhanes_2017,
  ids = sdmvpsu,
  weights = wtint2yr,
  strata = sdmvstra,
  nest = TRUE
)
if (requireNamespace("survey", quietly = TRUE)) {
  sv <- as_svydesign(d)
  survey::svymean(~ridageyr, sv, na.rm = TRUE)
}
#>            mean     SE
#> ridageyr 38.424 0.5244
```
