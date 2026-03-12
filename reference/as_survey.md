# Create a Taylor Series Linearization Survey Design

Creates a survey design object using Taylor series (linearization) for
variance estimation. Supports simple random samples, stratified designs,
single- and multi-stage cluster designs, and designs with finite
population correction. Uses a tidy-select interface for all design
variable arguments.

## Usage

``` r
as_survey(
  data,
  ids = NULL,
  probs = NULL,
  weights = NULL,
  strata = NULL,
  fpc = NULL,
  nest = FALSE
)
```

## Arguments

- data:

  A `data.frame` containing the survey responses. Must have at least one
  row and unique column names.

- ids:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Cluster (PSU) ID column(s). For single-stage: `ids = psu`. For
  multi-stage: `ids = c(psu, ssu)`. Omit entirely for simple random
  sampling.

- probs:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Sampling probability column (a single column, values in (0, 1\]).
  Converted to weights `= 1/probs` and stored internally. Cannot be used
  together with `weights` unless the values are consistent
  (`weights == 1/probs`).

- weights:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Sampling weight column (a single column, values strictly \> 0).

- strata:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Stratification variable column (a single column).

- fpc:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Finite population correction column (a single column). Accepts either
  total population size (integer) or sampling fraction (numeric, 0–1).
  Cannot contain `NA`.

- nest:

  Logical. If `TRUE`, PSU IDs are treated as nested within strata —
  i.e., the same ID value in two different strata refers to two distinct
  PSUs. Set `nest = TRUE` when PSU IDs are not globally unique (e.g.,
  NHANES, where PSU IDs restart from 1 in each stratum). Requires
  `strata` to be specified. Default `FALSE`.

## Value

A `survey_taylor` object.

## Tidy-select

All design variable arguments (`ids`, `probs`, `weights`, `strata`,
`fpc`) support tidy-select syntax:

    # Bare name
    as_survey(df, weights = wt)
    # c() for multi-stage ids
    as_survey(df, ids = c(psu, ssu), weights = wt)
    # tidy-select helpers also work (e.g., starts_with())

## Simple random sample

If `ids`, `weights`, and `probs` are all omitted, an equal-probability
SRS is assumed. A warning is issued because population totals cannot be
estimated without weights or population size.

## See also

[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md)
for replicate-weight designs,
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)
for two-phase designs,
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md)
to add variable labels

Other constructors:
[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md),
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
[`as_survey_srs()`](https://jdenn0514.github.io/surveycore/reference/as_survey_srs.md),
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
# Full NHANES design: stratified cluster with PSU IDs nested within strata
d <- as_survey(
  nhanes_2017,
  ids     = sdmvpsu,
  weights = wtint2yr,
  strata  = sdmvstra,
  nest    = TRUE
)

# Stratified design without PSU cluster IDs
d_strat <- as_survey(nhanes_2017, weights = wtint2yr, strata = sdmvstra)

# Blood pressure analysis: filter to exam participants, use MEC weight
exam <- nhanes_2017[nhanes_2017$ridstatr == 2, ]
d_bp <- as_survey(exam, ids = sdmvpsu, weights = wtmec2yr,
                  strata = sdmvstra, nest = TRUE)
```
