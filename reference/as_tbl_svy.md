# Convert a surveycore Design Object to an srvyr tbl_svy

Converts a surveycore design object to an `srvyr` `tbl_svy` by first
converting to a `survey` design via
[`as_svydesign()`](https://jdenn0514.github.io/surveycore/reference/as_svydesign.md)
and then wrapping with
[`srvyr::as_survey()`](http://gdfe.co/srvyr/reference/as_survey.md).
Requires both `survey` and `srvyr`.

## Usage

``` r
as_tbl_svy(x)
```

## Arguments

- x:

  A `survey_taylor`, `survey_replicate`, or `survey_twophase` object.

## Value

A [`srvyr::tbl_svy`](http://gdfe.co/srvyr/reference/tbl_svy.md) object.

## Details

Metadata (variable labels, value labels) is NOT carried over.

## See also

[`from_tbl_svy()`](https://jdenn0514.github.io/surveycore/reference/from_tbl_svy.md)
to convert back from a `tbl_svy` object

Other conversion:
[`as_svydesign()`](https://jdenn0514.github.io/surveycore/reference/as_svydesign.md),
[`from_svydesign()`](https://jdenn0514.github.io/surveycore/reference/from_svydesign.md),
[`from_tbl_svy()`](https://jdenn0514.github.io/surveycore/reference/from_tbl_svy.md)

## Examples

``` r
df <- data.frame(y = rnorm(20), w = runif(20, 0.5, 2))
d  <- as_survey(df, weights = w)
if (requireNamespace("survey", quietly = TRUE) &&
    requireNamespace("srvyr",  quietly = TRUE)) {
  ts <- as_tbl_svy(d)
}
```
