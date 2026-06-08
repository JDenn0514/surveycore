# Multi-Survey Container

An S7 container that holds multiple independent `survey_base` objects
(e.g., multiple waves of a panel or cross-sectional series) for
comparative analysis. Create with
[`as_survey_collection()`](https://jdenn0514.github.io/surveycore/reference/as_survey_collection.md).

## Usage

``` r
survey_collection(
  surveys = list(),
  groups = character(0),
  id = ".survey",
  if_missing_var = "error"
)
```

## Arguments

- surveys:

  A named list of `survey_base` objects.

- groups:

  Character vector of grouping variable names. Every member's `@groups`
  must be [`identical()`](https://rdrr.io/r/base/identical.html) to this
  value. Default `character(0)`.

- id:

  Character(1). Identifier column name used when dispatching analysis
  functions across the collection. Default `".survey"`.

- if_missing_var:

  Character(1), one of `c("error", "skip")`. Default `"error"`. Controls
  how dispatched `get_*()` functions behave when a member survey is
  missing a requested variable.

## Value

A `survey_collection` object.

## Details

`survey_collection` deliberately does **not** inherit from
[survey_base](https://jdenn0514.github.io/surveycore/reference/survey_base.md).
This prevents collection-of-collections nesting: a `survey_collection`
passed as an element of another collection fails the element-type check
automatically.

Each element of `@surveys` is an independent `survey_base` subclass
object (e.g., `survey_taylor`, `survey_replicate`, `survey_twophase`,
`survey_nonprob`). Mixed-type collections are allowed — the collection
never combines designs, so heterogeneous classes cannot produce an
invalid state.

## Properties

- `surveys`:

  A fully named list of `survey_base` objects. Length \\\geq 1\\. Names
  are unique, non-`NA`, and non-empty.

- `groups`:

  A character vector of grouping variable names applied uniformly across
  every member survey. Default `character(0)` (ungrouped). When
  non-empty, every member's `@groups` is asserted
  [`identical()`](https://rdrr.io/r/base/identical.html) to this value.

- `id`:

  Character(1). Identifier column name injected by
  `.dispatch_over_collection()` when a `get_*()` is called on the
  collection. Default `".survey"`. Stored on the collection and consumed
  as the per-call default; a non-`NULL` `.id` at the analysis-function
  call site overrides this stored value. Mutate via
  [`set_collection_id()`](https://jdenn0514.github.io/surveycore/reference/set_collection_id.md).

- `if_missing_var`:

  Character(1), one of `c("error", "skip")`. Default `"error"`. Controls
  how dispatched `get_*()` functions behave when a member is missing a
  requested variable. Stored on the collection and consumed as the
  per-call default; a non-`NULL` `.if_missing_var` at the
  analysis-function call site overrides this stored value. Mutate via
  [`set_collection_if_missing_var()`](https://jdenn0514.github.io/surveycore/reference/set_collection_if_missing_var.md).

## See also

[`as_survey_collection()`](https://jdenn0514.github.io/surveycore/reference/as_survey_collection.md)
to build a collection from survey objects;
[`add_survey()`](https://jdenn0514.github.io/surveycore/reference/add_survey.md)
/
[`remove_survey()`](https://jdenn0514.github.io/surveycore/reference/remove_survey.md)
to mutate an existing collection.

Other collections:
[`add_survey()`](https://jdenn0514.github.io/surveycore/reference/add_survey.md),
[`as_survey_collection()`](https://jdenn0514.github.io/surveycore/reference/as_survey_collection.md),
[`remove_survey()`](https://jdenn0514.github.io/surveycore/reference/remove_survey.md),
[`set_collection_id()`](https://jdenn0514.github.io/surveycore/reference/set_collection_id.md),
[`set_collection_if_missing_var()`](https://jdenn0514.github.io/surveycore/reference/set_collection_if_missing_var.md)

## Examples

``` r
d1 <- as_survey(
  gss_2024,
  ids = vpsu,
  weights = wtssps,
  strata = vstrat,
  nest = TRUE
)
coll <- survey_collection(surveys = list(gss = d1))
length(coll)
#> [1] 1
names(coll)
#> [1] "gss"
```
