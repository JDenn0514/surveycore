# Abstract Base Survey Design Class

All survey design objects (`survey_srs`, `survey_taylor`,
`survey_replicate`, `survey_twophase`, `survey_calibrated`) inherit from
`survey_base`. This class is abstract and cannot be instantiated
directly — use
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
or
[`as_survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/as_survey_calibrated.md)
instead.

## Usage

``` r
survey_base(
  data = data.frame(),
  metadata = survey_metadata(),
  variables = list(),
  groups = character(0),
  call = NULL
)
```

## Properties

- `data`:

  A `data.frame` containing the survey data.

- `metadata`:

  A
  [survey_metadata](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md)
  object.

- `variables`:

  A named list of design specification (varies by subclass).

- `groups`:

  Character vector of active grouping variables. Always `character(0)`
  in Phase 0. Reserved for Phase 0.5 (`group_by()` support in
  surveytidy).

- `call`:

  The language object capturing the construction call, or `NULL`.
