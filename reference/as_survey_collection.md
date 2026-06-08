# Create a Collection of Survey Designs

Builds a
[survey_collection](https://jdenn0514.github.io/surveycore/reference/survey_collection.md)
from one or more survey design objects for comparative analysis across
waves, cross-sections, or sub-populations. Each element is stored
independently — designs are never combined, and variance estimation is
never re-specified.

## Usage

``` r
as_survey_collection(..., group, .id = ".survey", .if_missing_var = "error")
```

## Arguments

- ...:

  One or more `survey_base` objects, passed with explicit names or as
  bare symbols. At least one argument is required.

- group:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Grouping variable(s) to apply uniformly across every member survey.
  Accepts bare names (`region`, `c(region, stratum)`), `all_of()`, etc.
  When supplied and resolving to a non-empty character vector, the named
  columns must exist in every member's `@data`; they are propagated onto
  each member's `@groups` and set as `coll@groups`. If a member already
  carries a non-empty `@groups` that differs from the resolved target,
  the target takes precedence and a
  `surveycore_warning_collection_group_overridden` warning is emitted
  (one per divergent member). When missing or resolving to an empty
  vector (`NULL`, `character(0)`,
  [`c()`](https://rdrr.io/r/base/c.html), `all_of(character(0))`), the
  collection adopts the members' uniform `@groups` if they are all
  identical, or errors `surveycore_error_collection_group_divergent` if
  they differ. Default: missing (adopt-from-members).

- .id:

  Character(1). Identifier column name used when dispatching analysis
  functions across the collection. Default `".survey"`. Stored on the
  returned collection's `@id` property and used as the default by
  `.dispatch_over_collection()` when a per-call `.id` is not supplied
  (i.e., when an analysis function is called with `.id = NULL`). Mutate
  via
  [`set_collection_id()`](https://jdenn0514.github.io/surveycore/reference/set_collection_id.md).

- .if_missing_var:

  Character(1), one of `c("error", "skip")`. Default `"error"`. Stored
  on the returned collection's `@if_missing_var` property and used as
  the default by `.dispatch_over_collection()` when a per-call
  `.if_missing_var` is not supplied (i.e., when an analysis function is
  called with `.if_missing_var = NULL`). When `"skip"`, member surveys
  missing a requested variable are dropped from the dispatched result;
  when `"error"`, the dispatcher aborts. Mutate via
  [`set_collection_if_missing_var()`](https://jdenn0514.github.io/surveycore/reference/set_collection_if_missing_var.md).

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

# Explicit names
coll <- as_survey_collection("2020" = d1, "2024" = d2)
names(coll)
#> [1] "2020" "2024"

# Bare-symbol auto-naming
coll2 <- as_survey_collection(d1, d2)
names(coll2)
#> [1] "d1" "d2"

# Uniform grouping across members
coll3 <- as_survey_collection(d1, d2, group = vstrat)
names(survey_data(coll3[[1L]]))
#>  [1] "vpsu"     "vstrat"   "wtssps"   "wtssnrps" "ballot"   "year"    
#>  [7] "id"       "age"      "sex"      "race"     "hispanic" "educ"    
#> [13] "degree"   "income16" "marital"  "wrkstat"  "hrs1"     "adults"  
#> [19] "partyid"  "polviews" "happy"    "health"   "trust"    "natfare" 
#> [25] "abany"    "attend"   "relig"   
```
