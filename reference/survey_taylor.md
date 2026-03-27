# Taylor Series Linearization Survey Design

A survey design object using Taylor series (linearization) for variance
estimation. Create with
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md).

## Usage

``` r
survey_taylor(
  data = data.frame(),
  metadata = survey_metadata(),
  variables = list(),
  groups = character(0),
  call = NULL
)
```

## Arguments

- data:

  A `data.frame` containing the survey data. Prefer
  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
  over calling this constructor directly.

- metadata:

  A
  [survey_metadata](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md)
  object. Created automatically by
  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md).

- variables:

  A named list of design specification (ids, weights, strata, fpc, nest,
  probs_provided). Set automatically by
  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md).

- groups:

  Set by surveytidy's `group_by()`. Always `character(0)` in standalone
  surveycore use.

- call:

  Language object capturing the construction call.

## Value

A `survey_taylor` object.

## Design variables (`@variables`)

- `ids`:

  Character vector of cluster ID column names, or `NULL` for simple
  random sampling.

- `weights`:

  Character string naming the weight column.

- `strata`:

  Character string naming the strata column, or `NULL`.

- `fpc`:

  Character string naming the finite population correction column, or
  `NULL`.

- `nest`:

  Logical. `TRUE` if cluster IDs are nested within strata (i.e., the
  same ID value in two strata refers to two distinct PSUs).

- `probs_provided`:

  Logical. `TRUE` if the user supplied `probs` rather than `weights` to
  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md).

## See also

[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
to create a `survey_taylor` object.

Other constructors:
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md),
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_data()`](https://jdenn0514.github.io/surveycore/reference/survey_data.md),
[`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md),
[`survey_glm_fit()`](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md),
[`survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/survey_nonprob.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)

## Examples

``` r
# Prefer as_survey() over calling survey_taylor() directly
d <- as_survey(gss_2024, ids = vpsu, weights = wtssps,
               strata = vstrat, nest = TRUE)
class(d)
#> [1] "surveycore::survey_taylor" "surveycore::survey_base"  
#> [3] "S7_object"                
```
