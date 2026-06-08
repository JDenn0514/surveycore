# Non-probability Samples

A survey design object for non-probability samples (e.g., online panels,
quota samples, volunteer panels) with calibration weights (including
raking and post-stratification) or inverse probability weighting (IPW)
pseudo-weights. Create with
[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md).

## Usage

``` r
survey_nonprob(
  data = data.frame(),
  metadata = survey_metadata(),
  variables = list(),
  groups = character(0),
  call = NULL,
  calibration = NULL,
  reference_sample = NULL
)
```

## Arguments

- data:

  A `data.frame` containing the survey data. Prefer
  [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md)
  over calling this constructor directly.

- metadata:

  A
  [survey_metadata](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md)
  object. Created automatically by
  [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md).

- variables:

  A named list of design specification (`weights`, `probs_provided`).
  Set automatically by
  [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md).

- groups:

  Set by surveytidy's `group_by()`. Always `character(0)` in standalone
  surveycore use.

- call:

  Language object capturing the construction call.

- calibration:

  The calibration provenance object returned by a surveywts calibration
  function (e.g., `surveywts::rake()`), or `NULL` if calibration was
  performed externally. Stores the calibration targets, variables, and
  trimming parameters for reproducibility and future bootstrap
  re-calibration. Default `NULL`.

- reference_sample:

  Optional
  [survey_taylor](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md)
  object representing the probability-based reference sample used to
  estimate propensity scores or calibration targets. Stored for
  reproducibility. Default `NULL`.

## Value

A `survey_nonprob` object.

## Variance estimation

Two modes are available, selected by whether `@variables$repweights` is
`NULL`:

- **SRS approximation** (no replicate weights):

  Standard errors treat the calibrated weights as fixed and assume
  simple random sampling. This understates calibration uncertainty and
  should only be used when replicate weights are unavailable.

- **Replicate variance** (repweights supplied):

  Bootstrap or jackknife replicate weights propagate calibration
  uncertainty into the variance estimate. Each replicate column must
  contain calibrated weights re-estimated on one replicate draw. This is
  the recommended approach.

See
[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md)
for the full parameter interface, including `type`, `scale`, `rscales`,
and `mse`.

## Non-probability samples

Unlike
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
and
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
this class does **not** assume a probability sampling design. When no
replicate weights are supplied, standard errors rest on a model-assisted
SRS assumption, which is consistent with common practice for calibrated
non-probability samples (e.g., raked online panels). When replicate
weights are supplied, bootstrap or jackknife variance is used instead.
See
[`vignette("creating-survey-objects")`](https://jdenn0514.github.io/surveycore/articles/creating-survey-objects.md)
for guidance on choosing between these modes and the limitations of
each.

## Design variables (`@variables`)

- `weights`:

  Character string naming the (calibrated) weight column.

- `repweights`:

  Character vector of bootstrap replicate weight column names, or `NULL`
  when no replicate weights are present.

- `type`:

  Replicate type. Only `"bootstrap"` is supported for non-probability
  samples (`"JK1"`, `"JK2"`, and `"JKn"` are not accepted); or `NULL`
  when no replicate weights are present.

- `scale`:

  Numeric scale factor for the variance formula, or `NULL`.

- `rscales`:

  Per-replicate scale factors, or `NULL`.

- `mse`:

  Logical. `TRUE` for MSE form of variance, or `NULL`.

- `probs_provided`:

  Always `FALSE` for calibrated designs.

## Calibration provenance (`@calibration`)

When calibration is performed via surveywts, the returned calibration
object is stored here. It contains the calibration targets, variables
used, trimming cap, effective sample size before and after, and design
effect. `NULL` when calibration was performed externally (e.g., via
`anesrake`).

## See also

[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md)
to create a `survey_nonprob` object.

Other constructors:
[`as_caldata()`](https://jdenn0514.github.io/surveycore/reference/as_caldata.md),
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md),
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md),
[`survey_glm_fit()`](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)
