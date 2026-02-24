# Simple Random Sample Survey Design

A survey design object for equal-probability simple random samples —
surveys where every unit had an equal chance of selection and there is
no clustering or stratification. Create via
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
with no `ids`, `strata`, or `fpc` arguments.

## Usage

``` r
survey_srs(
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

  A named list of design specification. Set automatically by
  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md).

- groups:

  Set by surveytidy's `group_by()`. Always `character(0)` in standalone
  surveycore use.

- call:

  Language object capturing the construction call.

## Value

A `survey_srs` object.

## When to use this class

Use `survey_srs` (via `as_survey(df)` or `as_survey(df, weights = w)`
with no design structure) when:

- The sample was drawn by simple random sampling (every unit equally
  likely to be selected)

- There are no clusters or strata to specify

- You want the standard SRS variance formula: `s²/n × (1 - f)` where
  `f = n/N` is the sampling fraction (0 when population size is unknown)

For non-probability samples or post-hoc calibrated weights (raking,
post-stratification, propensity matching), use
[`as_survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/as_survey_calibrated.md)
instead.

For complex probability samples with known design structure (PSUs,
strata), use
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
with `ids`, `strata`, and/or `fpc` — which creates a `survey_taylor`
object.

## Design variables (`@variables`)

- `weights`:

  Character string naming the weight column, or `NULL` for uniform
  weights (all equal; auto-generated as `"..surveycore_wt.."`).

- `probs_provided`:

  Logical. `TRUE` if the user supplied sampling probabilities rather
  than weights.

- `fpc`:

  Character string naming a finite population correction column, or
  `NULL`. When `NULL`, assumes infinite population (`f = 0`).

- `fpc_type`:

  Character string: `"population"` when the FPC column contains
  population sizes (values \> 1), `"fraction"` when it contains sampling
  fractions (values in (0, 1\]), or `NULL` when no FPC is specified.

- `ids`:

  Always `NULL`. SRS has no cluster structure.

- `strata`:

  Always `NULL`. SRS has no stratification.

- `nest`:

  Always `FALSE`.

## See also

[`as_survey_srs()`](https://jdenn0514.github.io/surveycore/reference/as_survey_srs.md)
to create a `survey_srs` object directly;
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
for Taylor series designs.

Other constructors:
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/as_survey_calibrated.md),
[`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md),
[`as_survey_srs()`](https://jdenn0514.github.io/surveycore/reference/as_survey_srs.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/survey_calibrated.md),
[`survey_data()`](https://jdenn0514.github.io/surveycore/reference/survey_data.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)
