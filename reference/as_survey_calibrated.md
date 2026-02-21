# Create a Calibrated / Non-Probability Survey Design

Creates a survey design object for non-probability samples and post-hoc
calibrated designs (e.g., raked online panels, post-stratified samples).
Accepts pre-computed calibration weights and optionally stores
calibration provenance from surveyweights output for reproducibility.

## Usage

``` r
as_survey_calibrated(data, weights, calibration = NULL)
```

## Arguments

- data:

  A `data.frame` containing the survey responses with pre-computed
  calibration weights. Must have at least one row and unique column
  names.

- weights:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Calibration weight column (a single column, values strictly \> 0).
  Typically produced by an external raking function (e.g.,
  `anesrake::anesrake()`) or a surveyweights calibration function.

- calibration:

  Optional. The calibration provenance object returned by a
  surveyweights calibration function (e.g., `surveyweights::rake()`).
  Stored in `@calibration` for reproducibility. Supply `NULL` (the
  default) when calibration was performed externally and provenance
  metadata is not available. The object's structure is defined by
  surveyweights and will be formally specified in Phase 2.5.

## Value

A `survey_calibrated` object.

## Phase 2.5 skeleton

This constructor is a **skeleton**. The resulting `survey_calibrated`
object supports estimation via a model-assisted SRS variance assumption
— the same as calling
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
with weights only. Full bootstrap re-calibration variance (which
re-applies the raking procedure on each replicate) will be implemented
in Phase 2.5 alongside the surveyweights package.

## When to use

Use `as_survey_calibrated()` instead of
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
when:

- Your data comes from a non-probability sample (online panel, quota
  sample, MTurk/Prolific, etc.)

- You have calibration or raking weights but no probability sampling
  design structure (no PSU IDs, strata, etc.)

- You want to explicitly record the provenance of your calibration
  weights for reproducibility

If your data comes from a probability sample with known design
structure, use
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md),
or
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)
instead.

## Variance estimation note

Standard errors from a `survey_calibrated` object assume simple random
sampling within the calibrated weights. This is consistent with common
applied practice for raked non-probability samples, but is technically a
model-assisted approximation rather than design-based variance. See
`vignette("creating-survey-objects")` for details and limitations.

## See also

[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
for probability designs with Taylor variance,
[`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md)
for replicate-weight designs

Other constructors:
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/survey_calibrated.md),
[`survey_data()`](https://jdenn0514.github.io/surveycore/reference/survey_data.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)

## Examples

``` r
# Minimal: pre-computed calibration weights from an external tool
df <- data.frame(
  y      = rnorm(200),
  age    = sample(c("18-34", "35-54", "55+"), 200, replace = TRUE),
  cal_wt = runif(200, 0.5, 2.5)
)
d <- as_survey_calibrated(df, weights = cal_wt)
```
