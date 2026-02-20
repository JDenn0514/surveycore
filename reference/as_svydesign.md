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
df <- data.frame(
  id  = 1:20,
  wt  = runif(20, 0.5, 2),
  st  = rep(c("A", "B"), 10),
  y   = rnorm(20)
)
d <- as_survey(df, weights = wt, strata = st)
if (requireNamespace("survey", quietly = TRUE)) {
  sv <- as_svydesign(d)
  survey::svymean(~y, sv)
}
#>       mean     SE
#> y -0.15598 0.2015
```
