# Calibrated / Non-Probability Survey Design

A survey design object for non-probability samples and post-hoc
calibrated designs (e.g., raked online panels, post-stratified samples).
Create with
[`as_survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/as_survey_calibrated.md).

## Usage

``` r
survey_calibrated(
  data = data.frame(),
  metadata = survey_metadata(),
  variables = list(),
  groups = character(0),
  call = NULL,
  calibration = NULL
)
```

## Arguments

- data:

  A `data.frame` containing the survey data. Prefer
  [`as_survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/as_survey_calibrated.md)
  over calling this constructor directly.

- metadata:

  A
  [survey_metadata](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md)
  object. Created automatically by
  [`as_survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/as_survey_calibrated.md).

- variables:

  A named list of design specification (`weights`, `probs_provided`).
  Set automatically by
  [`as_survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/as_survey_calibrated.md).

- groups:

  Reserved for Phase 0.5. Always `character(0)` in Phase 0.

- call:

  Language object capturing the construction call.

- calibration:

  The calibration provenance object returned by a surveyweights
  calibration function (e.g., `surveyweights::rake()`), or `NULL` if
  calibration was performed externally. Stores the calibration targets,
  variables, and trimming parameters for reproducibility and future
  bootstrap re-calibration. Default `NULL`.

## Value

A `survey_calibrated` object.

## Phase 2.5 skeleton

This class is a **skeleton** added in Phase 0 to reserve its place in
the class hierarchy. The constructor
[`as_survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/as_survey_calibrated.md)
accepts pre-computed calibration weights and stores calibration
provenance from surveyweights output.

Full functionality — including bootstrap variance with re-calibration on
each replicate — will be implemented in Phase 2.5 alongside the
surveyweights package. Until then, estimation uses SRS-based variance
(same assumption as
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
with weights only).

## Non-probability samples

Unlike
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md),
and
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
this class does **not** assume a probability sampling design. Standard
errors produced from a `survey_calibrated` object rest on a
model-assisted SRS assumption, which is consistent with common practice
for calibrated non-probability samples (e.g., raked online panels). See
`vignette("creating-survey-objects")` for guidance on when this is
appropriate and what the limitations are.

## Design variables (`@variables`)

- `weights`:

  Character string naming the (calibrated) weight column.

- `probs_provided`:

  Always `FALSE` for calibrated designs.

## Calibration provenance (`@calibration`)

When calibration is performed via surveyweights, the returned
calibration object is stored here. It contains the calibration targets,
variables used, trimming cap, effective sample size before and after,
and design effect. `NULL` when calibration was performed externally
(e.g., via `anesrake`).

## See also

[`as_survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/as_survey_calibrated.md)
to create a `survey_calibrated` object.

Other constructors:
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/as_survey_calibrated.md),
[`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_data()`](https://jdenn0514.github.io/surveycore/reference/survey_data.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)
