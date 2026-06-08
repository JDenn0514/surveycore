# Create a Non-probability Survey Design

Creates a survey design object for non-probability samples (e.g., online
panels, quota samples, volunteer panels). Accepts pre-computed
calibration weights (including raking and post-stratification) or
inverse probability weighting (IPW) pseudo-weights.

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
  Replicate weight columns (bootstrap or jackknife; at least 2). Each
  column must be numeric and represents one set of calibrated weights
  re-estimated on one replicate draw (calibration already applied within
  each replicate). Supply `NULL` (the default) to use SRS-based variance
  approximation. See `type` for supported replicate schemes.

- type:

  Character scalar. Replicate variance type. When `repweights = NULL`,
  this argument is ignored. Case-sensitive. Valid values:

  `"bootstrap"`

  :   Bootstrap variance. Default scale: `1/R`. Default value for
      `type`.

  `"JK1"`

  :   Delete-one jackknife for unclustered nonprob designs. Default
      scale: `(R-1)/R`. Appropriate when each unit is its own
      replication unit. For clustered designs, use `"JK2"` or `"JKn"`
      with explicit `rscales`.

  `"jackknife"`

  :   Alias for `"JK1"`. Normalized to `"JK1"` before storage — the
      stored value is always `"JK1"`, never `"jackknife"`.

  `"JK2"`

  :   Stratified jackknife. Default scale: `1`. Requires explicit
      `rscales` (stratum-specific scale factors of the form
      `(n_h - 1) / n_h`).

  `"JKn"`

  :   Equivalent to `"JK2"` for stratified nonprob designs. Default
      scale: `1`. Requires explicit `rscales`.

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

  Optional. A calibration provenance object returned by a surveywts
  weighting function. Stored in `@calibration` for reproducibility only
  — it is not used in variance estimation (unlike
  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
  where `@calibration` drives GREG variance correction). When
  `repweights` is also supplied, two consistency checks are applied: for
  `type = "bootstrap"`, `calibration$bootstrap` must be `TRUE`; for all
  types, `calibration$R` must equal the number of replicate columns when
  `calibration$R` is non-`NULL`. Supply `NULL` (the default) when no
  provenance metadata is available.

## Value

A `survey_nonprob` object.

## Details

Unlike probability samples, non-probability samples have no design
weights derived from known selection probabilities, which means
estimates carry additional uncertainty not captured by standard
design-based variance formulas. Per Elliott and Valliant (2017),
Valliant, Dever, and Kreuter (2018), and Brick (2015), bootstrap or
jackknife replicate weights are the recommended approach for variance
estimation — they propagate calibration uncertainty into standard
errors. Note, however, that replicate variance addresses calibration
uncertainty only; it does not resolve uncertainty about the selection
mechanism itself, which requires untestable modeling assumptions about
the relationship between sample membership and the survey variables of
interest. Without replicate weights, standard errors use a
model-assisted SRS approximation that systematically underestimates
variance for non-probability samples.

When `repweights` is supplied, the variance estimator uses the replicate
formula: `V = scale * sum(rscales * (theta_r - theta)^2)`. For bootstrap
replicates (`type = "bootstrap"`), the default `scale = 1/R` follows Wu
(2022) and Chen et al. (2021). For jackknife replicates (`type = "JK1"`,
`"JK2"`, or `"JKn"`), scale and rscales follow the standard jackknife
variance conventions; see `type` for defaults.

When `repweights = NULL`, standard errors use an SRS approximation
(treating each observation as its own PSU). This understates calibration
uncertainty; see
[`vignette("creating-survey-objects")`](https://jdenn0514.github.io/surveycore/articles/creating-survey-objects.md)
for details.

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

## Variance estimation

Two modes are available, depending on whether `repweights` is supplied:

- **SRS approximation** (`repweights = NULL`, the default):

  Standard errors treat the calibrated weights as fixed and assume
  simple random sampling. This is a model-assisted approximation that
  understates calibration uncertainty. Use this mode only when replicate
  weights are unavailable; interpret standard errors with caution
  (Valliant 2020; Elliott and Valliant 2017).

- **Bootstrap variance** (`repweights` supplied):

  Each replicate weight column must contain calibrated weights
  re-estimated on one bootstrap draw (i.e., raking or
  post-stratification was re-applied within each replicate). This
  propagates calibration uncertainty into the variance estimate and is
  the recommended approach (Chrostowski et al. 2025; Kolenikov 2014).

See
[`vignette("creating-survey-objects")`](https://jdenn0514.github.io/surveycore/articles/creating-survey-objects.md)
for guidance on choosing between these modes and on the limitations of
SRS-based variance for calibrated non-probability samples.

## References

Valliant, R. (2020). Comparing alternatives for estimation from
nonprobability samples. *Journal of Survey Statistics and Methodology*
**8**(2), 231–263.
[doi:10.1093/jssam/smz003](https://doi.org/10.1093/jssam/smz003)

Elliott, M.R. and Valliant, R. (2017). Inference for nonprobability
samples. *Statistical Science* **32**(2), 249–264.

Chrostowski, M.J., Guzman, C.A. and Malm, L. (2025). Variance estimation
for non-probability surveys. *Journal of Survey Statistics and
Methodology* (forthcoming).

Brick, J.M. (2015). Compositional model inference. In *Proceedings of
the Section on Survey Research Methods*, pp. 299–307. American
Statistical Association, Alexandria, VA.

Valliant, R., Dever, J.A. and Kreuter, F. (2018). *Practical Tools for
Designing and Weighting Survey Samples*, 2nd ed. Springer, New York.

Kolenikov, S. (2014). Calibrating variance estimation with proxy
variables. *Survey Methodology* **40**(1), 21–38.

Wu, C. (2022). Statistical inference with non-probability survey
samples. *Survey Methodology* **48**(2), 283–311.

Chen, Y., Li, P. and Wu, C. (2021). Doubly robust inference with
non-probability survey samples. *Journal of the American Statistical
Association* **115**(532), 2011–2021.

## See also

[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
for probability designs with Taylor variance,
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md)
for replicate-weight designs

Other constructors:
[`as_caldata()`](https://jdenn0514.github.io/surveycore/reference/as_caldata.md),
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md),
[`survey_glm_fit()`](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md),
[`survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/survey_nonprob.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)

## Examples

``` r
# Minimal: pre-computed calibration weights, SRS-based variance
df <- data.frame(
  y = rnorm(200),
  age = sample(c("18-34", "35-54", "55+"), 200, replace = TRUE),
  cal_wt = runif(200, 0.5, 2.5)
)
d <- as_survey_nonprob(df, weights = cal_wt)

# Bootstrap variance: replicate weights with calibration re-applied in each
set.seed(1)
R <- 50
rep_cols <- setNames(
  as.data.frame(
    matrix(runif(200 * R, 0.5, 2.5), nrow = 200)
  ),
  paste0("rep_", seq_len(R))
)
df_rep <- cbind(df, rep_cols)
d_boot <- as_survey_nonprob(
  df_rep,
  weights = cal_wt,
  repweights = starts_with("rep_"),
  type = "bootstrap"
)

# Jackknife variance (JK1): delete-one replicate weights
d_jk <- as_survey_nonprob(
  df_rep,
  weights = cal_wt,
  repweights = starts_with("rep_"),
  type = "JK1"
)
```
