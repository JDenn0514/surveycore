# Replicate Weights Survey Design

A survey design object using replicate weights for variance estimation.
Create with
[`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md).

## Usage

``` r
survey_replicate(
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
  [`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md)
  over calling this constructor directly.

- metadata:

  A
  [survey_metadata](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md)
  object. Created automatically by
  [`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md).

- variables:

  A named list of design specification (weights, repweights, type,
  scale, rscales, fpc, fpctype, mse). Set automatically by
  [`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md).

- groups:

  Reserved for Phase 0.5. Always `character(0)` in Phase 0.

- call:

  Language object capturing the construction call.

## Value

A `survey_replicate` object.

## Design variables (`@variables`)

- `weights`:

  Character string naming the weight column.

- `repweights`:

  Character vector of replicate weight column names. The replicate
  weight matrix is computed on demand from
  `design@data[, design@variables$repweights]` — it is not stored as a
  property.

- `type`:

  Replicate weight method: one of `"JK1"`, `"JK2"`, `"JKn"`, `"BRR"`,
  `"Fay"`, `"bootstrap"`, `"ACS"`, `"successive-difference"`, or
  `"other"`.

- `scale`:

  Numeric scaling factor for variance estimation.

- `rscales`:

  Numeric vector of replicate-specific scales, or `NULL`.

- `fpc`:

  FPC column name or `NULL`.

- `fpctype`:

  `"fraction"` or `"correction"`.

- `mse`:

  Logical. Use MSE estimates?

## See also

[`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md)
to create a `survey_replicate` object.

Other constructors:
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/as_survey_calibrated.md),
[`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md),
[`as_survey_srs()`](https://jdenn0514.github.io/surveycore/reference/as_survey_srs.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/survey_calibrated.md),
[`survey_data()`](https://jdenn0514.github.io/surveycore/reference/survey_data.md),
[`survey_srs()`](https://jdenn0514.github.io/surveycore/reference/survey_srs.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)
