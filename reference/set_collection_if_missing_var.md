# Set the Missing-Variable Behaviour on a `survey_collection`

Updates the `@if_missing_var` property of a `survey_collection`. The new
value is the per-call default `.dispatch_over_collection()` uses when an
analysis function
([`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
etc.) is dispatched across the collection without an explicit per-call
`.if_missing_var`.

## Usage

``` r
set_collection_if_missing_var(x, if_missing_var)
```

## Arguments

- x:

  A
  [survey_collection](https://jdenn0514.github.io/surveycore/reference/survey_collection.md).

- if_missing_var:

  Character(1), one of `c("error", "skip")`. When `"skip"`, member
  surveys missing a requested variable are dropped from the dispatched
  result; when `"error"`, the dispatcher aborts.

## Value

The modified `survey_collection`, invisibly.

## Details

Setting the same value as the existing `@if_missing_var` returns the
collection unchanged (no error, no warning). All other invariants on the
collection (`@surveys`, `@groups`, `@id`) are preserved.

Pipes naturally with the rest of the collection API:

    coll |> set_collection_if_missing_var("skip") |> get_means(y1)

## See also

Other collections:
[`add_survey()`](https://jdenn0514.github.io/surveycore/reference/add_survey.md),
[`as_survey_collection()`](https://jdenn0514.github.io/surveycore/reference/as_survey_collection.md),
[`remove_survey()`](https://jdenn0514.github.io/surveycore/reference/remove_survey.md),
[`set_collection_id()`](https://jdenn0514.github.io/surveycore/reference/set_collection_id.md),
[`survey_collection()`](https://jdenn0514.github.io/surveycore/reference/survey_collection.md)

## Examples

``` r
d1 <- as_survey(
  gss_2024,
  ids = vpsu,
  weights = wtssps,
  strata = vstrat,
  nest = TRUE
)
coll <- as_survey_collection(a = d1)
coll <- set_collection_if_missing_var(coll, "skip")
coll@if_missing_var
#> [1] "skip"
```
