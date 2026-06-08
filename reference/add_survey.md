# Add Surveys to a `survey_collection`

Appends one or more surveys to an existing collection and returns a new
`survey_collection`. The original collection is unchanged. Surveys may
be passed with explicit names or as bare symbols (auto-named, like
[`as_survey_collection()`](https://jdenn0514.github.io/surveycore/reference/as_survey_collection.md)).
Duplicate names are repaired by appending `_1`, `_2`, … Existing names
are never modified during repair.

## Usage

``` r
add_survey(.collection, ...)
```

## Arguments

- .collection:

  A `survey_collection`. Named with a leading dot so it cannot collide
  with user-supplied names in `...` (e.g., a survey named `"x"`).

- ...:

  One or more surveys to append. Accepts named arguments
  (`"wave3" = d3`) or bare symbols (`d3`, auto-named to `"d3"`). If a
  new name collides with an existing one (or with another new one), it
  is repaired by appending `_1`, `_2`, … and a
  `surveycore_warning_collection_duplicate_name_repaired` warning is
  emitted with the mapping.

## Value

A new `survey_collection` with the appended surveys.

## Details

Calling `add_survey(x)` with no additional surveys returns `x`
unchanged; no error is raised.

## See also

[`as_survey_collection()`](https://jdenn0514.github.io/surveycore/reference/as_survey_collection.md),
[`remove_survey()`](https://jdenn0514.github.io/surveycore/reference/remove_survey.md)

Other collections:
[`as_survey_collection()`](https://jdenn0514.github.io/surveycore/reference/as_survey_collection.md),
[`remove_survey()`](https://jdenn0514.github.io/surveycore/reference/remove_survey.md),
[`set_collection_id()`](https://jdenn0514.github.io/surveycore/reference/set_collection_id.md),
[`set_collection_if_missing_var()`](https://jdenn0514.github.io/surveycore/reference/set_collection_if_missing_var.md),
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
d2 <- as_survey(
  gss_2024,
  ids = vpsu,
  weights = wtssps,
  strata = vstrat,
  nest = TRUE
)
coll <- as_survey_collection(a = d1)
coll2 <- add_survey(coll, b = d2)
names(coll2)
#> [1] "a" "b"
```
