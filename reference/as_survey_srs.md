# Create a Simple Random Sample Survey Design

Creates a survey design object for equal-probability simple random
samples (SRS). Computes variances using the classical SRS formula
`var(ȳ) = (1 - f) × s² / n`, where `s²` is the unweighted sample
variance, `n` is the sample size, and `f = n/N` is the sampling fraction
(0 when population size is unknown).

## Usage

``` r
as_survey_srs(data, weights = NULL, probs = NULL, fpc = NULL)
```

## Arguments

- data:

  A `data.frame` containing the survey responses. Must have at least one
  row and unique column names.

- weights:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Sampling weight column (a single column, values strictly \> 0). Supply
  either `weights` or `probs`, not both. If both are `NULL`, uniform
  weights (`= 1`) are auto-assigned and a warning is issued; population
  totals will then equal sample totals, not estimated population totals.

- probs:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Sampling probability column (a single column, values in (0, 1\]).
  Converted to weights `= 1/probs` and stored internally as
  `..surveycore_wt..`. Supply either `weights` or `probs`, not both.

- fpc:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Finite population correction column (a single column). Accepts either
  total population size (all values \> 1) or sampling fraction (all
  values in (0, 1\]). Cannot mix the two types. Cannot contain `NA` or
  non-positive values. If any FPC value (of population-size type) is
  less than the sample size, an error is thrown.

## Value

A `survey_srs` object.

## See also

[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
for designs with cluster or stratification structure,
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md)
for replicate-weight designs

Other constructors:
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md),
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_data()`](https://jdenn0514.github.io/surveycore/reference/survey_data.md),
[`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md),
[`survey_glm_fit()`](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md),
[`survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/survey_nonprob.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_srs()`](https://jdenn0514.github.io/surveycore/reference/survey_srs.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)

## Examples

``` r
# Minimal: no weights, no FPC (uniform weights auto-assigned)
d <- suppressWarnings(as_survey_srs(data.frame(y = 1:5)))
```
