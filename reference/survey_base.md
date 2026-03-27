# Abstract Base Survey Design Class

All survey design objects (`survey_taylor`, `survey_replicate`,
`survey_twophase`, `survey_nonprob`) inherit from `survey_base`. This
class is abstract and cannot be instantiated directly — use
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
or
[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md)
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

## Value

Cannot be instantiated directly. See
[survey_taylor](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[survey_replicate](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[survey_twophase](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md),
or
[survey_nonprob](https://jdenn0514.github.io/surveycore/reference/survey_nonprob.md)
for concrete subclasses.

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

  Character vector of active grouping variables. Set by surveytidy's
  `group_by()`. Always `character(0)` in standalone surveycore use.

- `call`:

  The language object capturing the construction call, or `NULL`.
