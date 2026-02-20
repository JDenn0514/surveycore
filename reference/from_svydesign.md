# Convert a survey Package Design to a surveycore Design Object

Converts a `survey` package design object (`svydesign`, `svrepdesign`,
or `twophase`) to the corresponding surveycore S7 object. The data,
design variables, and replicate weights are preserved; metadata
(variable labels, value labels) is not — the `survey` package has no
metadata system.

## Usage

``` r
from_svydesign(x)
```

## Arguments

- x:

  A
  [`survey::svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html),
  [`survey::svrepdesign`](https://rdrr.io/pkg/survey/man/svrepdesign.html),
  [`survey::twophase`](https://rdrr.io/pkg/survey/man/twophase.html), or
  [`srvyr::tbl_svy`](http://gdfe.co/srvyr/reference/tbl_svy.md) object.

## Value

A `survey_taylor`, `survey_replicate`, or `survey_twophase` object.

## Details

Weight column names are recovered from the design call when available.
When the call does not contain a formula (e.g., weights were passed as a
vector), the weight column is identified by matching the stored weight
values against columns in the data. If no match is found, a
`..surveycore_wt..` column is added.

## See also

[`as_svydesign()`](https://jdenn0514.github.io/surveycore/reference/as_svydesign.md)
to convert in the other direction

Other conversion:
[`as_svydesign()`](https://jdenn0514.github.io/surveycore/reference/as_svydesign.md),
[`as_tbl_svy()`](https://jdenn0514.github.io/surveycore/reference/as_tbl_svy.md),
[`from_tbl_svy()`](https://jdenn0514.github.io/surveycore/reference/from_tbl_svy.md)

## Examples

``` r
df <- data.frame(
  id  = 1:20,
  wt  = runif(20, 0.5, 2),
  st  = rep(c("A", "B"), 10),
  y   = rnorm(20)
)
if (requireNamespace("survey", quietly = TRUE)) {
  sv <- survey::svydesign(ids = ~1, weights = ~wt, strata = ~st, data = df)
  d  <- from_svydesign(sv)
  survey_data(d)
}
#>    id        wt st          y
#> 1   1 1.2864202  A  1.0120018
#> 2   2 1.2452379  B -0.9190516
#> 3   3 0.5220782  A  0.5633801
#> 4   4 1.9368787  B  0.3224827
#> 5   5 1.1796339  A  0.3666744
#> 6   6 1.9722978  B  1.1298352
#> 7   7 1.3170577  A -0.9414981
#> 8   8 1.0400636  B  0.2178376
#> 9   9 1.2547192  A  1.4154123
#> 10 10 0.6119504  B -0.3837330
#> 11 11 1.9546878  A -0.1740864
#> 12 12 1.4727520  B -0.2217445
#> 13 13 1.9768482  A -1.0095287
#> 14 14 1.3041999  B  0.4807253
#> 15 15 1.6415891  A  1.6044073
#> 16 16 1.3465786  B -1.5150245
#> 17 17 1.6676815  A -1.4160239
#> 18 18 1.4585915  B  0.8767773
#> 19 19 1.0684411  A  0.6241324
#> 20 20 1.0392960  B  2.1122773
```
