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
  rho = NULL,
  scale = NULL,
  rscales = NULL,
  fpc = NULL,
  fpctype = NULL,
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
  jackknife), `"JK2"` (paired jackknife, two PSUs per stratum), `"JKn"`
  (delete-1 jackknife with varying replication counts), `"BRR"`
  (balanced repeated replication), `"Fay"` (Fay's method, a modified
  BRR; needs `rho`), `"bootstrap"`, `"ACS"` (used in American Community
  Survey), `"successive-difference"`, or `"other"` (user-specified
  scale). Case-sensitive.

- rho:

  Numeric scalar or `NULL` (default). The Fay shrinkage factor: the
  factor the replicate weights were built with. Each Fay replicate
  multiplies the weights of one half sample by `2 - rho` and the weights
  of the other half sample by `rho`. Required when `type = "Fay"`. The
  valid range is `[0, 1)`, and `rho = 0` gives BRR. An integer is
  accepted and stored as a double; a value with a `dim` attribute is
  refused. Find the value in the survey's technical documentation, where
  it is often called the Fay coefficient or epsilon. surveycore cannot
  check that the value matches the replicate columns.

  The Fay scale `1 / (R * (1 - rho)^2)` assumes a two-PSU-per-stratum
  layout with Hadamard-balanced half samples, which surveycore does not
  check; the scale is exact for totals and first-order for means and
  ratios. `type` stays `"Fay"` at `rho = 0`, unlike
  [`survey::as.svrepdesign()`](https://rdrr.io/pkg/survey/man/as.svrepdesign.html),
  which relabels it `"BRR"`.

  For every other `type`, a supplied `rho` is ignored with a warning and
  the design stores no `rho`. The warning has the class
  `surveycore_warning_rho_ignored` and also the class
  `surveycore_warning_replicate_arg_ignored`. For `"JKn"` with no
  `rscales`, the refusal fires and no `rho` warning is raised, where
  [`survey::svrepdesign()`](https://rdrr.io/pkg/survey/man/svrepdesign.html)
  raises both.

- scale:

  Numeric. Scaling factor applied to the replicate variance formula. If
  `NULL` (default), computed automatically from `type` and the number of
  replicates `R`: `(R-1)/R` for `"JK1"`; `1/R` for `"BRR"`;
  `1 / (R * (1 - rho)^2)` for `"Fay"`; `1/(R-1)` for `"bootstrap"`;
  `4/R` for `"ACS"` and `"successive-difference"` (per Ash 2014 / Fay &
  Train 1995); `1` for `"JKn"`, `"JK2"` and `"other"`.

  For `"JK1"`, `"JKn"`, `"bootstrap"` and `"other"`, a supplied `scale`
  is stored as given.

  For `"BRR"`, `"JK2"`, `"ACS"` and `"successive-difference"`, a
  supplied `scale` is ignored with a warning of class
  `surveycore_warning_replicate_arg_ignored`, and the design stores the
  type's own value from the list above.
  [`survey::svrepdesign()`](https://rdrr.io/pkg/survey/man/svrepdesign.html)
  also ignores a supplied `scale` for these four types. Any value other
  than `NULL` counts as supplied, even one equal to the type's own
  value, and surveycore does not check it.

  surveycore warns only when the caller supplies `scale` or `rscales`.
  [`survey::svrepdesign()`](https://rdrr.io/pkg/survey/man/svrepdesign.html)
  warns on every `"JK2"` call, even when the caller supplies neither.
  surveycore does not copy that warning: a warning that fires when the
  caller passed nothing tells the caller nothing, and warnings that no
  one asserts hide new ones.

  For `"Fay"`, a supplied `scale` is discarded with no warning, as
  [`survey::svrepdesign()`](https://rdrr.io/pkg/survey/man/svrepdesign.html)
  does, and the Fay scale always comes from `rho`.

  `"JK2"` is the paired jackknife. Each replicate is a half sample, so
  the per-stratum factor is already inside the replicate weights:
  `rscales` stays at `rep(1, R)` and the overall scale stays at `1`.
  [`survey::svrepdesign()`](https://rdrr.io/pkg/survey/man/svrepdesign.html)
  forces both.
  [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md)
  uses the same scale of `1` but requires `rscales` for `"JK2"`.

  `"JKn"` is the stratified delete-one jackknife. Its per-stratum factor
  belongs in `rscales` and not in the overall scale. The factor is
  `(n_h - 1) / n_h` when PSUs are selected with replacement, or when the
  sampling fraction is negligible. `"JKn"` requires `rscales`, and
  `rscales = NULL` is refused, as
  [`survey::svrepdesign()`](https://rdrr.io/pkg/survey/man/svrepdesign.html)
  refuses it for combined weights.

  A caller who samples PSUs without replacement at a sampling fraction
  that is not negligible folds the correction into each `rscales` entry
  by hand, which makes the entry `(n_h - 1) * (1 - n_h / N_h) / n_h`.
  Here `n_h` is the number of sample PSUs in stratum `h`, and `N_h` is
  the number of population PSUs in stratum `h`. The caller supplies
  `N_h` from their own sampling frame. The `fpc` argument applies the
  same correction: `fpc = n_h / N_h` per replicate, with
  `fpctype = "fraction"`.

  `"bootstrap"` divides by `R - 1`, which is the value
  [`survey::svrepdesign()`](https://rdrr.io/pkg/survey/man/svrepdesign.html)
  computes at `bootstrap.average = 1`. surveycore has no
  `bootstrap.average` argument, so a caller cannot build a design with
  one and this default is always `1/(R-1)`; a design imported from
  `survey` keeps its effective scale exactly, in both directions. A
  bootstrap design of one replicate column gives `scale = Inf`, and
  [`survey::svrepdesign()`](https://rdrr.io/pkg/survey/man/svrepdesign.html)
  stores `Inf` for the same input.

  [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md)
  keeps `1/R` for `"bootstrap"`, so the same `type` string means a
  different divisor in the two constructors. The difference is a
  decision and not a defect; see
  [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md)
  for the reason and the size of the gap.

  Pass `scale` explicitly to reproduce numbers published before these
  two defaults moved: `scale = (R - 1) / R` for `"JKn"` and
  `scale = 1 / R` for `"bootstrap"`. An old `"JKn"` call that passed no
  `rscales` also needs `rscales = rep(1, R)`, because `"JKn"` refuses
  `rscales = NULL`.

- rscales:

  Numeric vector of replicate-specific scaling factors, or `NULL`. If
  provided, must have the same length as the number of replicate weight
  columns selected by `repweights`, with no `NA` and no negative value.
  These length and value checks run on a supplied `rscales` for every
  `type`, including the three that ignore it.

  Required for `"JKn"`: `rscales = NULL` is refused with
  `surveycore_error_stratified_jk_rscales_unset`.

  For `"JK2"`, `"ACS"` and `"successive-difference"`, a supplied
  `rscales` is ignored with the same warning as a supplied `scale`,
  `surveycore_warning_replicate_arg_ignored`. The design stores `NULL`,
  which the variance treats as `rep(1, R)`.
  [`survey::svrepdesign()`](https://rdrr.io/pkg/survey/man/svrepdesign.html)
  forces `rep(1, R)` for these three types.

  For `"JKn"` and the other five types, `"JK1"`, `"BRR"`, `"Fay"`,
  `"bootstrap"` and `"other"`, a supplied `rscales` is stored as given.

  For a stratified jackknife whose PSUs are selected without replacement
  at a sampling fraction that is not negligible, the `scale` argument
  gives the entry to build here.

- fpc:

  A finite population correction, as a number or as one value per
  replicate column, or `NULL` (default, no correction). A number is
  recycled to every replicate. Accepted for `"JK1"`, `"JKn"` and
  `"other"` only, as in
  [`survey::svrepdesign()`](https://rdrr.io/pkg/survey/man/svrepdesign.html);
  every other type raises an error of class
  `surveycore_error_replicate_fpc_type_unsupported`. For `"bootstrap"`
  the correction belongs in the replicate weights themselves.

  The correction is applied the way
  [`survey::svrepdesign()`](https://rdrr.io/pkg/survey/man/svrepdesign.html)
  applies its own `fpc`: each `rscales` entry is multiplied by `1 - f`,
  where `f` is the sampling fraction for that replicate. A `NULL`
  `rscales` starts from `rep(1, R)`. For `"JKn"`, `f` is the sampling
  fraction of the stratum the replicate drops a PSU from, and `rscales`
  is still required. The design stores the corrected `rscales` and
  records the fraction, so
  [`print()`](https://rdrr.io/r/base/print.html) shows it.

  A column is not accepted. A bare name, or a single string, that names
  a column of `data` raises an error of class
  `surveycore_error_replicate_fpc_unsupported`, even when a variable of
  the same name exists in the calling environment. No replicate variance
  formula reads a per-row FPC column. To use such a variable, write
  `.env$name`. Any other expression is evaluated in the calling
  environment. A value that is not numeric, has the wrong length, holds
  `NA` or lies out of range raises an error of class
  `surveycore_error_replicate_fpc_invalid`.

- fpctype:

  How to read `fpc`: `"fraction"` (the sampling fraction `f`, with
  `0 <= f < 1`) or `"correction"` (`1 - f`, used as given, with
  `0 < 1 - f <= 1`). Required whenever `fpc` is supplied, as in
  [`survey::svrepdesign()`](https://rdrr.io/pkg/survey/man/svrepdesign.html),
  because the same number reads either way and the two give different
  standard errors. Must match exactly. Supplying `fpctype` without `fpc`
  raises an error of class `surveycore_error_replicate_fpc_unsupported`.

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

A `survey_replicate` object. Columns imported with `haven`-style value
labels are stored as their underlying type: the `label` and `labels`
attributes are kept, and the value labels are also recorded in the
metadata system, but the `haven_labelled` class is not stored. Use
`survey_data(x, haven_class = TRUE)` to read the data back with that
class rebuilt.

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
Official Statistics* **6**(3), 223–239.

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

# A finite population correction: a 5% sampling fraction, folded into
# the replicate scales
d_fpc <- as_survey_replicate(
  acs_pums_wy,
  weights = pwgtp,
  repweights = c(pwgtp1, pwgtp2, pwgtp3, pwgtp4),
  type = "JK1",
  fpc = 0.05,
  fpctype = "fraction"
)

# Fay's method: 4 replicate columns built with rho = 0.5
set.seed(1)
df_fay <- data.frame(
  y = rnorm(20),
  wt = runif(20, 1, 3)
)
for (r in 1:4) {
  factor_r <- sample(c(0.5, 1.5), 20, replace = TRUE)
  df_fay[[paste0("rep", r)]] <- df_fay$wt * factor_r
}
d_fay <- as_survey_replicate(
  df_fay,
  weights = wt,
  repweights = starts_with("rep"),
  type = "Fay",
  rho = 0.5
)
d_fay
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_replicate> (FAY, 4 replicates, rho = 0.5)
#> Sample size: 20
#> 
#> # A tibble: 20 × 6
#>         y    wt  rep1  rep2  rep3  rep4
#>     <dbl> <dbl> <dbl> <dbl> <dbl> <dbl>
#>  1 -0.626  2.64 1.32  3.96  3.96  3.96 
#>  2  0.184  2.29 3.44  3.44  3.44  3.44 
#>  3 -0.836  2.57 3.85  1.28  3.85  1.28 
#>  4  1.60   2.11 3.16  1.05  1.05  1.05 
#>  5  0.330  2.06 3.09  1.03  1.03  3.09 
#>  6 -0.820  2.58 3.87  3.87  1.29  1.29 
#>  7  0.487  1.05 1.57  0.523 0.523 0.523
#>  8  0.738  1.95 0.977 2.93  2.93  2.93 
#>  9  0.576  2.46 3.70  1.23  1.23  3.70 
#> 10 -0.305  2.39 3.58  3.58  1.19  1.19 
#> # ℹ 10 more rows
```
