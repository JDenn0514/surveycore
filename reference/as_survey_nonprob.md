# Create a Calibrated / Non-Probability Survey Design

**\[experimental\]**

## Usage

``` r
as_survey_nonprob(
  data,
  weights,
  repweights = NULL,
  type = "bootstrap",
  scale = NULL,
  rscales = NULL,
  mse = TRUE,
  reference_sample = NULL,
  calibration = NULL
)
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
  `anesrake::anesrake()`) or a surveywts calibration function.

- repweights:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Bootstrap replicate weight columns (at least 2). Each column must be
  numeric and represents one set of combined bootstrap weights
  (calibration already applied). Supply `NULL` (the default) to use
  SRS-based variance approximation. Columns are combined-weights: the
  calibration adjustment has already been re-applied within each
  replicate column.

- type:

  Character. Replicate type. Must be `"bootstrap"` — jackknife and other
  replicate types are not supported for non-probability samples. Ignored
  when `repweights = NULL`. Default `"bootstrap"`.

- scale:

  Numeric scalar. Scaling factor for the replicate variance formula.
  Default `NULL`, which sets `scale = 1 / R` (where `R` is the number of
  replicate columns). Note: this default differs from
  [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
  which uses type-specific defaults.

- rscales:

  Numeric vector of length `R`. Per-replicate scale factors. All values
  must be non-negative and non-NA. Default `NULL`, which sets
  `rscales = rep(1, R)`.

- mse:

  Logical. If `TRUE` (the default), the mean-squared-error form of the
  variance estimator is used: `(1/R) * sum((theta_r - theta)^2)`. If
  `FALSE`, the centered form is used instead. Default `TRUE`. Note: this
  default differs from
  [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md)
  — `mse = TRUE` is the appropriate default for bootstrap replicates
  from calibrated non-probability samples (Wu 2022).

- reference_sample:

  Optional. A
  [survey_taylor](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md)
  object representing the probability-based reference sample used to
  estimate propensity scores or calibration targets. Stored in
  `@reference_sample` for reproducibility. Supply `NULL` (the default)
  when no reference sample is available.

- calibration:

  Optional. The calibration provenance object returned by a surveywts
  calibration function (e.g., `surveywts::create_bootstrap_weights()`).
  Stored in `@calibration` for reproducibility. When `repweights` is
  also supplied, `calibration` is validated: `calibration$bootstrap`
  must be `TRUE` and `calibration$R` must equal the number of replicate
  columns. Supply `NULL` (the default) when calibration was performed
  externally and provenance metadata is not available.

## Value

A `survey_nonprob` object.

## Details

Creates a survey design object for non-probability samples and post-hoc
calibrated designs (e.g., raked online panels, post-stratified samples).
Accepts pre-computed calibration weights and optionally stores
calibration provenance from surveywts output for reproducibility.

When `repweights` is supplied, the variance estimator uses the bootstrap
replicate formula: `V = scale * sum(rscales * (theta_r - theta)^2)`. The
default `scale = 1/R` follows Wu (2022) and Chen et al. (2021) for
calibrated non-probability bootstrap variance.

When `repweights = NULL`, standard errors use an SRS approximation
(treating each observation as its own PSU). This understates calibration
uncertainty; see
[`vignette("creating-survey-objects")`](https://jdenn0514.github.io/surveycore/articles/creating-survey-objects.md)
for details.

## Phase 2.5 skeleton

This constructor is a **skeleton**. The resulting `survey_nonprob`
object supports estimation via a model-assisted SRS variance assumption
— the same as calling
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
with weights only. Full bootstrap re-calibration variance (which
re-applies the raking procedure on each replicate) will be implemented
in Phase 2.5 alongside the surveywts package.

## When to use

Use `as_survey_nonprob()` instead of
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
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
or
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)
instead.

## Variance estimation note

Standard errors from a `survey_nonprob` object assume simple random
sampling within the calibrated weights. This is consistent with common
applied practice for raked non-probability samples, but is technically a
model-assisted approximation rather than design-based variance. See
[`vignette("creating-survey-objects")`](https://jdenn0514.github.io/surveycore/articles/creating-survey-objects.md)
for details and limitations.

## References

Wu, C. (2022) Statistical inference with non-probability survey samples.
*Survey Methodology* **48**(2), 283–311.

Chen, Y., Li, P. and Wu, C. (2021) Doubly robust inference with
non-probability survey samples. *Journal of the American Statistical
Association* **115**(532), 2011–2021.

## See also

[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
for probability designs with Taylor variance,
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md)
for replicate-weight designs

Other constructors:
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_data()`](https://jdenn0514.github.io/surveycore/reference/survey_data.md),
[`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md),
[`survey_glm_fit()`](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md),
[`survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/survey_nonprob.md),
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
d <- as_survey_nonprob(df, weights = cal_wt)
```
