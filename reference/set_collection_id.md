# Set the Identifier Column on a `survey_collection`

Updates the `@id` property of a `survey_collection`. The new value is
the column name `.dispatch_over_collection()` injects when an analysis
function
([`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
etc.) is dispatched across the collection without an explicit per-call
`.id`.

## Usage

``` r
set_collection_id(x, id)
```

## Arguments

- x:

  A
  [survey_collection](https://jdenn0514.github.io/surveycore/reference/survey_collection.md).

- id:

  Character(1). The new identifier column name. Must be non-`NA` and
  non-empty.

## Value

The modified `survey_collection`, invisibly.

## Details

Setting the same value as the existing `@id` returns the collection
unchanged (no error, no warning). All other invariants on the collection
(`@surveys`, `@groups`, `@if_missing_var`) are preserved.

Pipes naturally with the rest of the collection API:

    coll |> set_collection_id("wave") |> get_means(y1)

## See also

Other collections:
[`add_survey()`](https://jdenn0514.github.io/surveycore/reference/add_survey.md),
[`as_survey_collection()`](https://jdenn0514.github.io/surveycore/reference/as_survey_collection.md),
[`remove_survey()`](https://jdenn0514.github.io/surveycore/reference/remove_survey.md),
[`set_collection_if_missing_var()`](https://jdenn0514.github.io/surveycore/reference/set_collection_if_missing_var.md),
[`survey_collection()`](https://jdenn0514.github.io/surveycore/reference/survey_collection.md)

## Examples

``` r
d1 <- as_survey(gss_2024, ids = vpsu, weights = wtssps,
                strata = vstrat, nest = TRUE)
coll <- as_survey_collection(a = d1)
coll <- set_collection_id(coll, "wave")
coll@id
#> [1] "wave"
```
