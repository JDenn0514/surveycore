# Remove Surveys from a `survey_collection`

Drops one or more named surveys from a collection and returns a new
`survey_collection`. Errors if any requested name is not present.

## Usage

``` r
remove_survey(x, name)
```

## Arguments

- x:

  A `survey_collection`.

- name:

  Character vector of survey names to drop. All names must be present in
  `names(x)`.

## Value

A new `survey_collection` without the dropped surveys. Errors
`surveycore_error_collection_empty` if removing would leave the
collection empty. This error is raised by the S7 class validator, not by
`remove_survey()` itself.

## See also

[`as_survey_collection()`](https://jdenn0514.github.io/surveycore/reference/as_survey_collection.md),
[`add_survey()`](https://jdenn0514.github.io/surveycore/reference/add_survey.md)

Other collections:
[`add_survey()`](https://jdenn0514.github.io/surveycore/reference/add_survey.md),
[`as_survey_collection()`](https://jdenn0514.github.io/surveycore/reference/as_survey_collection.md),
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
coll <- as_survey_collection(a = d1, b = d2)
coll2 <- remove_survey(coll, "a")
names(coll2)
#> [1] "b"
```
