# Create a Collection of Survey Designs

Builds a
[survey_collection](https://jdenn0514.github.io/surveycore/reference/survey_collection.md)
from one or more survey design objects for comparative analysis across
waves, cross-sections, or sub-populations. Each element is stored
independently — designs are never combined, and variance estimation is
never re-specified.

## Usage

``` r
as_survey_collection(...)
```

## Arguments

- ...:

  One or more `survey_base` objects, passed with explicit names or as
  bare symbols. At least one argument is required.

## Value

A `survey_collection` object containing the supplied surveys.

## Details

Arguments may be passed with explicit names (`"wave1" = d1`) or as bare
symbols (`d1`, auto-named to `"d1"`). An unnamed argument that is not a
bare symbol (e.g., an inline `as_survey(...)` call) raises
`surveycore_error_collection_unnamed_expr` — name such arguments
explicitly.

Duplicate names are repaired by appending `_1`, `_2`, … to subsequent
occurrences (first occurrence preserved). When any rename occurs, a
`surveycore_warning_collection_duplicate_name_repaired` warning is
emitted showing the `original -> repaired` mapping.

## See also

[survey_collection](https://jdenn0514.github.io/surveycore/reference/survey_collection.md),
[`add_survey()`](https://jdenn0514.github.io/surveycore/reference/add_survey.md),
[`remove_survey()`](https://jdenn0514.github.io/surveycore/reference/remove_survey.md)

Other collections:
[`add_survey()`](https://jdenn0514.github.io/surveycore/reference/add_survey.md),
[`remove_survey()`](https://jdenn0514.github.io/surveycore/reference/remove_survey.md),
[`survey_collection()`](https://jdenn0514.github.io/surveycore/reference/survey_collection.md)

## Examples

``` r
d1 <- as_survey(gss_2024, ids = vpsu, weights = wtssps,
                strata = vstrat, nest = TRUE)
d2 <- as_survey(gss_2024, ids = vpsu, weights = wtssps,
                strata = vstrat, nest = TRUE)

# Explicit names
coll <- as_survey_collection("2020" = d1, "2024" = d2)
names(coll)
#> [1] "2020" "2024"

# Bare-symbol auto-naming
coll2 <- as_survey_collection(d1, d2)
names(coll2)
#> [1] "d1" "d2"
```
