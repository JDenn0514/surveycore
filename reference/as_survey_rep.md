# Create a Replicate Weights Survey Design

Creates a survey design object using replicate weights for variance
estimation. Supports all common replicate methods: jackknife (JK1, JK2,
JKn), balanced repeated replication (BRR, Fay), bootstrap, ACS,
successive-difference, and user-defined types. Uses a tidy-select
interface for weight and replicate-weight columns.

## Usage

``` r
as_survey_rep(
  data,
  weights,
  repweights,
  type = c("JK1", "JK2", "JKn", "BRR", "Fay", "bootstrap", "ACS",
    "successive-difference", "other"),
  scale = NULL,
  rscales = NULL,
  fpc = NULL,
  fpctype = c("fraction", "correction"),
  mse = TRUE
)
```

## Arguments

- data:

  A `data.frame` containing the survey responses. Must have at least one
  row and unique column names.

- weights:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Sampling weight column (a single column, values strictly \> 0).
  Required.

- repweights:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Replicate weight columns. Must select at least one column. Supports
  tidy-select helpers (e.g., `starts_with("repwt")`). Required.

- type:

  Character. Replicate weight method. One of `"JK1"` (delete-1
  jackknife), `"JK2"` (delete-1 jackknife, stratified), `"JKn"`
  (delete-1 jackknife with varying replication counts), `"BRR"`
  (balanced repeated replication), `"Fay"` (Fay's method, a modified
  BRR), `"bootstrap"`, `"ACS"` (used in American Community Survey),
  `"successive-difference"`, or `"other"` (user-specified scale).

- scale:

  Numeric. Scaling factor applied to the replicate variance formula. If
  `NULL` (default), computed automatically from `type` and the number of
  replicates: `(R-1)/R` for jackknife methods, `1/4` for BRR/Fay, `1/R`
  for bootstrap/ACS, `2/R` for successive-difference, `1` for other.

- rscales:

  Numeric vector of replicate-specific scaling factors, or `NULL`. If
  provided, must have the same length as the number of replicate weight
  columns selected by `repweights`.

- fpc:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Finite population correction column (a single column). Used by some
  replicate methods to adjust the variance estimator. `NULL` means no
  FPC correction.

- fpctype:

  Character. How `fpc` is interpreted: `"fraction"` (sampling fraction,
  0–1) or `"correction"` (multiplier for the replicate variance).
  Default `"fraction"`.

- mse:

  Logical. If `TRUE` (default), use mean-squared-error estimates
  (subtract the full-sample estimate rather than the mean replicate
  estimate when computing variance). Recommended for most designs.

## Value

A `survey_replicate` object.

## Tidy-select

Both `weights` and `repweights` support tidy-select syntax:

    # Bare name for weights
    as_survey_rep(df, weights = wt, repweights = starts_with("repwt"), type = "BRR")
    # c() for explicit replicate columns
    as_survey_rep(df, weights = wt, repweights = c(rep1, rep2, rep3), type = "JK1")

## Replicate weight matrix

The replicate weight matrix is **not stored** in the object. Only the
column names are stored in `@variables$repweights`. Variance estimation
computes the matrix on demand:
`as.matrix(design@data[, design@variables$repweights])`.

## See also

[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
for Taylor series designs,
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)
for two-phase designs,
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_variable_labels()`](https://jdenn0514.github.io/surveycore/reference/set_variable_labels.md)
to add variable metadata

Other constructors:
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/as_survey_calibrated.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/survey_calibrated.md),
[`survey_data()`](https://jdenn0514.github.io/surveycore/reference/survey_data.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)

## Examples

``` r
# ACS PUMS Wyoming: 80 successive-difference replicate weights
d_acs <- as_survey_rep(
  acs_pums_wy,
  weights    = pwgtp,
  repweights = pwgtp1:pwgtp80,
  type       = "successive-difference"
)

# Explicit replicate columns using c()
d_sub <- as_survey_rep(
  acs_pums_wy,
  weights    = pwgtp,
  repweights = c(pwgtp1, pwgtp2, pwgtp3, pwgtp4),
  type       = "JK1"
)
```
