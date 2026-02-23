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

  Reserved for Phase 0.5 (group_by support in surveytidy). Always
  `character(0)` in Phase 0.

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
[`as_survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/as_survey_calibrated.md),
[`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md),
[`as_survey_srs()`](https://jdenn0514.github.io/surveycore/reference/as_survey_srs.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/survey_calibrated.md),
[`survey_data()`](https://jdenn0514.github.io/surveycore/reference/survey_data.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_srs()`](https://jdenn0514.github.io/surveycore/reference/survey_srs.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)
