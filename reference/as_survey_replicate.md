# Create a Replicate Weights Survey Design

Creates a survey design object using replicate weights for variance
estimation. Supports all common replicate methods: jackknife (JK1, JK2,
JKn), balanced repeated replication (BRR, Fay), bootstrap, ACS,
successive-difference, and user-defined types. Uses a tidy-select
interface for weight and replicate-weight columns.

## Usage

``` r
as_survey_replicate(
  data,
  weights,
  repweights,
  type = c("JK1", "JK2", "JKn", "BRR", "Fay", "bootstrap", "ACS",
    "successive-difference", "other"),
  scale = NULL,
  rscales = NULL,
  fpc = NULL,
  fpctype = c("fraction", "correction"),
  mse = TRUE,
  calibration = NULL
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
  Case-sensitive.

- scale:

  Numeric. Scaling factor applied to the replicate variance formula. If
  `NULL` (default), computed automatically from `type` and the number of
  replicates `R`: `(R-1)/R` for `"JK1"`, `"JK2"`, and `"JKn"`; `1/R` for
  `"BRR"`, `"Fay"`, `"bootstrap"`, and `"ACS"`; `2/R` for
  `"successive-difference"`; `1` for `"other"`.

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
  Default `"fraction"`. Case-sensitive.

- mse:

  Logical. If `TRUE` (default), use mean-squared-error estimates
  (subtract the full-sample estimate rather than the mean replicate
  estimate when computing variance). Recommended for most designs.

- calibration:

  A list of calibration data elements, each produced by
  [`as_caldata()`](https://jdenn0514.github.io/surveycore/reference/as_caldata.md),
  or `NULL` (default). Stored at `@calibration` for provenance and
  reproducibility. **Not used in variance estimation**: the replicate
  variance estimator ignores `@calibration` entirely — calibration is
  already encoded in the replicate weights.

  **Known limitations** (not validated at construction time):

  - *Weight consistency*: surveycore cannot verify that `cd$w` encodes
    the same base weights as the design weight column.

  - *Stale calibration after
    [`update_design()`](https://jdenn0514.github.io/surveycore/reference/update_design.md)*:
    changing the weight column makes `@calibration` stale; clear it
    manually.

## Value

A `survey_replicate` object.

## Tidy-select

Both `weights` and `repweights` support tidy-select syntax:

    # Bare name for weights
    as_survey_replicate(
      df, weights = wt, repweights = starts_with("repwt"), type = "BRR"
    )
    # c() for explicit replicate columns
    as_survey_replicate(
      df, weights = wt, repweights = c(rep1, rep2, rep3), type = "JK1"
    )

## Replicate weight matrix

The replicate weight matrix is **not stored** in the object. Only the
column names are stored in `@variables$repweights`. Variance estimation
computes the matrix on demand:
`as.matrix(design@data[, design@variables$repweights])`.

## Memory usage

Each call to an estimation function (e.g.,
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md))
materialises the full replicate weight matrix from the data frame. For
large designs (e.g., ACS PUMS with 500k+ rows × 80 replicates), this is
roughly `nrow * n_replicates * 8` bytes per call (~363 MB for ACS
Wyoming × 80). If you are estimating many variables, this is repeated
for each call. This behaviour matches the `survey` package reference
implementation.

## References

Canty, A.J. and Davison, A.C. (1999) Resampling-based variance
estimation for labour force surveys. *The Statistician* **48**(3),
379–391.

Deville, J.-C. and Sarndal, C.-E. (1992) Calibration estimators in
survey sampling. *Journal of the American Statistical Association*
**87**(418), 376–382.

Deville, J.-C., Sarndal, C.-E. and Sautory, O. (1993) Generalized raking
procedures in survey sampling. *Journal of the American Statistical
Association* **88**(423), 1013–1020.

Judkins, D.R. (1990) Fay's method for variance estimation. *Journal of
the American Statistical Association* **85**(410), 895–904.

Rao, J.N.K., Wu, C.F.J. and Yue, K. (1992) Some recent work on
resampling methods for complex surveys. *Survey Methodology* **18**(2),
209–217.

Shao, J. and Tu, D. (1995) *The Jackknife and Bootstrap*. Springer.

## See also

[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
for Taylor series designs,
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)
for two-phase designs,
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md)
to add variable labels

Other constructors:
[`as_caldata()`](https://jdenn0514.github.io/surveycore/reference/as_caldata.md),
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md),
[`survey_glm_fit()`](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md),
[`survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/survey_nonprob.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)

## Examples

``` r
# ACS PUMS Wyoming: 80 successive-difference replicate weights
d_acs <- as_survey_replicate(
  acs_pums_wy,
  weights = pwgtp,
  repweights = pwgtp1:pwgtp80,
  type = "successive-difference"
)

# Explicit replicate columns using c()
d_sub <- as_survey_replicate(
  acs_pums_wy,
  weights = pwgtp,
  repweights = c(pwgtp1, pwgtp2, pwgtp3, pwgtp4),
  type = "JK1"
)
```
