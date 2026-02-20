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

[`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md)
for replicate-weight designs,
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)
for two-phase designs,
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_variable_labels()`](https://jdenn0514.github.io/surveycore/reference/set_variable_labels.md)
to add variable metadata

Other constructors:
[`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_data()`](https://jdenn0514.github.io/surveycore/reference/survey_data.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)

## Examples

``` r
df <- data.frame(
  id  = 1:100,
  psu = rep(1:10, each = 10),
  st  = rep(c("A", "B"), 50),
  wt  = runif(100, 0.5, 2),
  fpc = rep(500L, 100),
  y   = rnorm(100)
)

# Simple random sample (no weights specified)
d_srs <- as_survey(df)
#> Warning: ! No weights or population size provided.
#> ℹ Treating as equal-probability SRS with unknown population size.
#> ✔ Valid: means, proportions, correlations, and their standard errors.
#> ✖ Invalid: population totals (will equal sample totals, not population totals).
#> ℹ To fix: provide `fpc` = population size, or `weights` = N / n.

# Weighted sample
d_wt <- as_survey(df, weights = wt)

# Stratified
d_strat <- as_survey(df, weights = wt, strata = st)

# Cluster
d_clust <- as_survey(df, ids = psu, weights = wt)

# Stratified cluster with FPC
d_full <- as_survey(df, ids = psu, weights = wt, strata = st, fpc = fpc)
#> Warning: ! Some PSUs appear in more than one stratum: "1", "10", "2", "3", and "4". If
#>   PSUs are nested within strata, set `nest = TRUE`.

# NHANES-style: PSU IDs nested within strata
d_nhanes <- as_survey(df, ids = psu, weights = wt, strata = st, nest = TRUE)
```
