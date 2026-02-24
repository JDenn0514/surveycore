# Estimate Weighted Total for a Survey Design

Computes the weighted total and its standard error for a single variable
using the appropriate variance estimator for the survey design type.

## Usage

``` r
get_totals(design, var, na.rm = TRUE)
```

## Arguments

- design:

  A survey design object. Supported classes:
  [survey_taylor](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md)
  (created by
  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)),
  [survey_replicate](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md)
  (created by
  [`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md)),
  [survey_srs](https://jdenn0514.github.io/surveycore/reference/survey_srs.md)
  (created by
  [`as_survey_srs()`](https://jdenn0514.github.io/surveycore/reference/as_survey_srs.md)
  or
  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)),
  [survey_twophase](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)
  (created by
  [`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)),
  and
  [survey_calibrated](https://jdenn0514.github.io/surveycore/reference/survey_calibrated.md)
  (created by
  [`as_survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/as_survey_calibrated.md)).

- var:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  A single unquoted variable name to estimate the total of.

- na.rm:

  Logical. If `TRUE` (default), missing values are excluded before
  computing the total. Set to `FALSE` to propagate `NA`.

## Value

A named list with elements:

- `variable`:

  Character. Name of the estimated variable.

- `total`:

  Numeric. Weighted total estimate.

- `se`:

  Numeric. Standard error of the total.

## Variance estimation by design type

- `survey_taylor`:

  Taylor series linearization.

- `survey_replicate`:

  Replicate-weight variance estimator.

- `survey_twophase`:

  Two-phase linearization (Saei and Roberts 1999; Lumley 2010 §9.2).
  Three methods are supported, set at construction time via
  [`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md):

  - `"full"` — joint phase 1 + phase 2 linearization. Most accurate.
    Requires `ids2`, `strata2`, or `probs2` to be specified in
    [`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md).

  - `"approx"` — phase 1 variance with phase 2 correction, using
    within-stratum sampling fractions as phase 2 probabilities. Valid
    for most two-phase designs.

  - `"simple"` — phase 1 variance only. Conservative; valid when phase 2
    sampling fraction is high or phase 1 variance dominates.

- `survey_calibrated`:

  SRS-based (model-assisted) variance. Standard errors assume simple
  random sampling within the calibrated weights. This is consistent with
  common practice for raked non-probability samples but may understate
  uncertainty. Full bootstrap re-calibration variance will be available
  in Phase 2.5.

## See also

Other estimation:
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md)

## Examples

``` r
# ACS PUMS Wyoming: estimated total population by age
d <- as_survey_rep(acs_pums_wy, weights = pwgtp,
                   repweights = pwgtp1:pwgtp80,
                   type = "successive-difference")
get_totals(d, agep)
#> $variable
#> [1] "agep"
#> 
#> $total
#> [1] 23089173
#> 
#> $se
#> [1] 40314.74
#> 
```
