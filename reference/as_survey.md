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
  nest = FALSE,
  calibration = NULL
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
  Finite population correction column(s). For single-stage designs,
  supply one column. For multi-stage designs, supply one column per
  stage: `fpc = c(fpc_stage1, fpc_stage2)`. Each column accepts either
  total population size (integer, all \> 1) or sampling fraction
  (numeric, all in (0, 1\]). Cannot contain `NA`. Cannot have more
  columns than `ids` stages; fewer is allowed (later stages assume
  infinite population).

- nest:

  Logical. If `TRUE`, PSU IDs are treated as nested within strata —
  i.e., the same ID value in two different strata refers to two distinct
  PSUs. Set `nest = TRUE` when PSU IDs are not globally unique (e.g.,
  NHANES, where PSU IDs restart from 1 in each stratum). Requires
  `strata` to be specified. Default `FALSE`.

- calibration:

  A list of calibration data elements, each produced by
  [`as_caldata()`](https://jdenn0514.github.io/surveycore/reference/as_caldata.md),
  or `NULL` (default) for no calibration adjustment. When non-`NULL`,
  variance estimation applies a Deville-Sarndal GREG projection that
  reduces standard errors proportional to the correlation between the
  auxiliary variables and the outcome. Equivalent to assigning
  `design@calibration <- list(cd)` after construction.

  **Known limitations** (not validated at construction time):

  - *Weight consistency*: surveycore cannot verify that `cd$w` encodes
    the same base weights as the design weight column. Mismatched base
    weights produce incorrect variance estimates.

  - *Stale calibration after
    [`update_design()`](https://jdenn0514.github.io/surveycore/reference/update_design.md)*:
    changing the weight column on a calibrated design with
    [`update_design()`](https://jdenn0514.github.io/surveycore/reference/update_design.md)
    makes `@calibration` stale. Clear `@calibration` manually after any
    weight column change.

## Value

A `survey_taylor` object.

## Tidy-select

All design variable arguments (`ids`, `probs`, `weights`, `strata`,
`fpc`) support tidy-select syntax: bare column names,
[`c()`](https://rdrr.io/r/base/c.html) to combine multiple columns
(multi-stage `ids = c(psu, ssu)`, multi-stage `fpc`), and tidyselect
helpers like `starts_with()`. See the Examples section below for
runnable demonstrations.

## Simple random sample

When no `ids` or `strata` are specified, the result is a `survey_taylor`
object with `NULL` ids and strata — i.e., a simple random sample (SRS).
The Taylor variance machinery produces the same estimates as the
classical SRS formula `(1 - f) * s^2 / n`. If `weights` and `probs` are
also both omitted, uniform weights are assigned and a warning is issued.

## Known limitations

`as_survey()` does not support probability-proportional-to-size (PPS)
variance estimation. Taylor series linearization treats all designs as
with-replacement, which overestimates (is conservative for) variance in
PPS-without-replacement designs. The Yates-Grundy and Brewer/Overton
estimators available in
[`survey::svydesign()`](https://rdrr.io/pkg/survey/man/svydesign.html)
via its `pps` and `variance` arguments are not supported.

If your design requires PPS-specific variance estimation, create the
design with
[`survey::svydesign()`](https://rdrr.io/pkg/survey/man/svydesign.html)
and convert it with
[`from_svydesign()`](https://jdenn0514.github.io/surveycore/reference/from_svydesign.md):

    d_survey <- survey::svydesign(
      ids = ~psu, weights = ~wt, strata = ~stratum,
      pps = "brewer", data = mydata
    )
    d <- from_svydesign(d_survey)

## References

Deville, J.-C. and Sarndal, C.-E. (1992) Calibration estimators in
survey sampling. *Journal of the American Statistical Association*
**87**(418), 376–382.

Deville, J.-C., Sarndal, C.-E. and Sautory, O. (1993) Generalized raking
procedures in survey sampling. *Journal of the American Statistical
Association* **88**(423), 1013–1020.

Lumley, T. (2004) Analysis of complex survey samples. *Journal of
Statistical Software* **9**(1), 1–19.

Lumley, T. (2010) *Complex Surveys: A Guide to Analysis Using R*. John
Wiley and Sons.

Rao, J.N.K., Yung, W. and Hidiroglou, M.A. (2002) Estimating equations
for the analysis of survey data using poststratification information.
*Sankhya* **64-A**, 22–36.

Sarndal, C-E., Swensson, B. and Wretman, J. (1992) *Model Assisted
Survey Sampling*. Springer.

## See also

[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md)
for replicate-weight designs,
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)
for two-phase designs,
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md)
to add variable labels

Other constructors:
[`as_caldata()`](https://jdenn0514.github.io/surveycore/reference/as_caldata.md),
[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md),
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
# Full NHANES design: stratified cluster with PSU IDs nested within strata
d <- as_survey(
  nhanes_2017,
  ids = sdmvpsu,
  weights = wtint2yr,
  strata = sdmvstra,
  nest = TRUE
)

# Stratified design without PSU cluster IDs
d_strat <- as_survey(nhanes_2017, weights = wtint2yr, strata = sdmvstra)

# Blood pressure analysis: filter to exam participants, use MEC weight
exam <- nhanes_2017[nhanes_2017$ridstatr == 2, ]
d_bp <- as_survey(
  exam,
  ids = sdmvpsu,
  weights = wtmec2yr,
  strata = sdmvstra,
  nest = TRUE
)

# c() to combine multiple columns — sketched on a synthetic two-stage frame
df <- data.frame(
  psu = rep(1:5, each = 4),
  ssu = 1:20,
  wt = runif(20, 0.5, 2)
)
d_ms <- as_survey(df, ids = c(psu, ssu), weights = wt)

# Tidy-select helpers like starts_with() also work
d_h <- as_survey(
  gss_2024,
  ids = vpsu,
  strata = vstrat,
  weights = starts_with("wtssn"),
  nest = TRUE
)
```
