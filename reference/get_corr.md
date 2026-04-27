# Survey-Weighted Correlation (Pearson, Polychoric, Polyserial)

Compute pairwise correlations between two or more variables in a survey
design, with design-based standard errors and confidence intervals.
Returns results in long or wide format. The estimator is selected by
`method`: `"pearson"` (default) for two numeric variables,
`"polychoric"` for two ordinal variables under a bivariate-normal latent
model (Olsson 1979), or `"polyserial"` for one ordinal + one continuous
variable (Cox 1974). The survey-weighted polychoric and polyserial
estimators (point estimates and design-based variance) are implemented
from scratch following Mannan (2025); they are not derived from the
`survey` package, which does not provide these estimators.

## Usage

``` r
get_corr(
  design,
  x,
  group = NULL,
  format = c("long", "wide"),
  redundant = FALSE,
  diagonal = FALSE,
  variance = "ci",
  conf_level = 0.95,
  n_weighted = FALSE,
  decimals = NULL,
  min_cell_n = 30L,
  na.rm = TRUE,
  label_values = TRUE,
  label_vars = TRUE,
  name_style = "surveycore",
  method = "pearson",
  ...,
  .id = NULL,
  .if_missing_var = NULL
)
```

## Arguments

- design:

  A survey design object: `survey_taylor`, `survey_replicate`,
  `survey_twophase`, or `survey_nonprob`. `method` values `"polychoric"`
  and `"polyserial"` are supported on `survey_taylor` and
  `survey_replicate` only; other design classes raise
  `surveycore_error_polychoric_design_unsupported`.

- x:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Two or more unquoted variable names. For `method = "pearson"`,
  non-numeric columns are dropped with a warning. For
  `method = "polychoric"`, every selected column must classify as
  ordinal (ordered factor, unordered factor, or integer with `<= 10`
  distinct values) — non-ordinal columns raise
  `surveycore_error_polychoric_requires_ordinal`. For
  `method = "polyserial"`, each pair is canonicalized by type (one
  ordinal

  - one continuous); logical / character / high-cardinality integer
    columns raise
    `surveycore_error_polyserial_canonicalization_ambiguous`.

- group:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Optional grouping variable(s). Combined with any grouping set by
  `group_by()`. Default `NULL`.

- format:

  `"long"` (default) or `"wide"`. Long format returns one row per
  variable pair with inference statistics. Wide format returns the
  correlation matrix (`r` values only — no variance or inference
  columns). When `group` is active, group columns are prepended in both
  formats. Case-sensitive.

- redundant:

  Logical. If `FALSE` (default), each pair appears once (lower triangle:
  pairs where var1 precedes var2 in input order). If `TRUE`, both
  `(A, B)` and `(B, A)` are included (full directed pairs). Only affects
  long format; wide format always shows the full symmetric matrix.

- diagonal:

  Logical. If `FALSE` (default), self-correlations are excluded
  (diagonal is `NA` in wide format). If `TRUE`, self-correlations (r
  equals 1) are included.

- variance:

  `NULL` or a character vector of one or more of `"se"`, `"ci"`,
  `"var"`, `"cv"`, `"moe"`, `"deff"`. Default `"ci"`. CI bounds use the
  Fisher Z transform (guaranteeing bounds in (-1, 1)). Only applies to
  long format.

- conf_level:

  Numeric scalar in (0, 1). Default `0.95`.

- n_weighted:

  Logical. If `TRUE`, add an `n_weighted` column with the pairwise sum
  of weights (both variables non-NA). Default `FALSE`.

- decimals:

  Integer or `NULL`. If an integer, rounds all numeric output columns
  (e.g., `r`, `se`, `ci_low`, `ci_high`) to this many decimal places.
  Default `NULL` (no rounding).

- min_cell_n:

  Integer. Minimum pairwise unweighted count before
  `surveycore_warning_small_cell` fires. Default `30L` (AAPOR guidance).

- na.rm:

  Logical. If `TRUE` (default), pairs use complete cases for each
  variable pair separately (pairwise deletion), and observations where
  any group variable is `NA` are excluded from the output. If `FALSE`,
  pairwise complete cases are still used for each variable pair, and
  observations where a group variable is `NA` are collected into their
  own group row in the output (appearing after all non-`NA` group rows).

- label_values:

  Logical. If `TRUE` (default) and the grouping variable has value
  labels, the group column is converted to a labelled factor. Has no
  visible effect when no groups are active.

- label_vars:

  Logical. If `TRUE` (default) and variable labels are set in metadata,
  `var1`/`var2` columns (long) and `variable` column (wide) show labels
  instead of raw names. Falls back to raw names if labels are unset.

- name_style:

  `"surveycore"` (default) or `"broom"`. When `"broom"`, renames `r` →
  `estimate`, `se` → `std.error`, etc. Only affects long format.

- method:

  Character(1). Estimator applied to every pair. One of `"pearson"`
  (default, sample-based product-moment correlation), `"polychoric"`
  (MLE under a bivariate-normal latent model for two ordinal variables),
  or `"polyserial"` (MLE for one ordinal + one continuous variable). The
  same `method` applies to every pair; it cannot be vectorised.
  Non-matching values raise the standard
  [`base::match.arg()`](https://rdrr.io/r/base/match.arg.html) signal.

- ...:

  Unused. Reserved so that `.id` and `.if_missing_var` remain named-only
  when a `survey_collection` is passed as `design`.

- .id:

  Character(1) or `NULL`. Column name used to identify each survey when
  `design` is a
  [`survey_collection`](https://jdenn0514.github.io/surveycore/reference/survey_collection.md).
  For collection inputs, `NULL` (the default) resolves to the
  collection's stored `@id` property. Pass a non-`NULL` value to
  override. Ignored when `design` is a single survey.

- .if_missing_var:

  `"error"`, `"skip"`, or `NULL`. How to handle surveys in a collection
  that lack one of the requested NSE variables. For collection inputs,
  `NULL` (the default) resolves to the collection's stored
  `@if_missing_var` property. Pass a non-`NULL` value to override.
  Ignored when `design` is a single survey.

## Value

A `survey_corr` tibble (also inheriting `survey_result`).

When `group` is active, group variable columns are prepended before all
other columns in both long and wide formats.

**Long format** columns:

- `[group_cols...]` — group variable columns (when active), first.

- `var1`, `var2` — variable names (or labels when `label_vars = TRUE`).

- `r` — Pearson correlation coefficient.

- Variance columns (`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`,
  `deff`) — only those requested via `variance`.

- `p_value` — two-tailed p-value.

- `statistic` — t-statistic.

- `df` — degrees of freedom for the t-test (n minus 2).

- `n` — pairwise unweighted count.

- `n_weighted` — pairwise sum of weights (only when requested).

**Wide format** columns:

- `[group_cols...]` — group variable columns (when active), first.

- `variable` — row variable names (or labels).

- One column per focal variable, containing `r` values.

Use `meta(result)` to access design type, variable labels, and `method`
(`"pearson"`, `"polychoric"`, or `"polyserial"`). For
`method != "pearson"`, `meta(result)$bivariate_normal_cdf` is
`"pbivnorm"` (the bivariate-normal CDF used internally). When the
replicate variance path observed one or more non-converged replicates,
`meta(result)$n_failed_replicates_total` carries the scalar total.

## Details

**Polychoric / polyserial semantics.** For `method != "pearson"`, each
pair is fit by a two-step MLE: weighted marginal thresholds (and, for
polyserial, a weighted standardization of the continuous side) are
estimated first, then `rho` is maximised over the weighted
log-likelihood via
[`stats::optimize()`](https://rdrr.io/r/stats/optimize.html) on
`(-1 + 1e-6, 1 - 1e-6)`. Confidence intervals are constructed on the
Fisher-z scale (`atanh(rho)`) and back-transformed via `tanh` with
truncation to `[-1, 1]`. The Wald statistic `zeta.hat / SE(zeta.hat)` is
referred to a standard normal distribution, so `df = NA_integer_` —
distinct from the Pearson case where `df = n - 2` and the t-distribution
is used. Column label attributes are method-neutral (e.g. `"statistic"`,
not `"t-statistic"` / `"z-statistic"`); check `meta(result)$method` to
interpret the values.

**Bivariate-normal assumption.** The polychoric / polyserial MLEs assume
the underlying latent variables are jointly bivariate-normal. This is an
unverified assumption; no runtime diagnostic is performed.

**Taylor-path cost.** On a `survey_taylor` design, the variance path for
`method != "pearson"` is `O(n)` re-optimisations per variable pair (a
perturbation-based influence function). For large `n` and many pairs,
passing a `survey_replicate` design (one re-fit per replicate, not per
respondent) is substantially faster.

**Replicate-type caveat.** Mannan (2025) verifies the replicate-weight
variance formula for jackknife and bootstrap replicates. BRR and Fay
replicates are admitted mechanically via the design's stored `scale` /
`rscales` coefficients, but the paper does not validate their behaviour
for this non-linear pseudo-likelihood estimator.

## References

Cox, N. R. (1974). Estimation of the correlation between a continuous
and a discrete variable. *Biometrics*, 30(1), 171-178.

Mannan, H. (2025). SAS programs for estimation of weighted polychoric
and weighted polyserial correlations in a complex survey. SSRN.
[doi:10.2139/ssrn.6580480](https://doi.org/10.2139/ssrn.6580480)

Olsson, U. (1979). Maximum likelihood estimation of the polychoric
correlation coefficient. *Psychometrika*, 44(4), 443-460.

## See also

Other analysis:
[`clean()`](https://jdenn0514.github.io/surveycore/reference/clean.md),
[`get_anova()`](https://jdenn0514.github.io/surveycore/reference/get_anova.md),
[`get_covariance()`](https://jdenn0514.github.io/surveycore/reference/get_covariance.md),
[`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md),
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_pairwise()`](https://jdenn0514.github.io/surveycore/reference/get_pairwise.md),
[`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md),
[`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md),
[`get_t_test()`](https://jdenn0514.github.io/surveycore/reference/get_t_test.md),
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
[`get_variance()`](https://jdenn0514.github.io/surveycore/reference/get_variance.md),
[`meta()`](https://jdenn0514.github.io/surveycore/reference/meta.md)

## Examples

``` r
d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
               strata = sdmvstra, nest = TRUE)
get_corr(d, x = c(ridageyr, bpxsy1))
#> # A tibble: 1 × 9
#>   var1                  var2      r ci_low ci_high p_value statistic    df     n
#>   <fct>                 <fct> <dbl>  <dbl>   <dbl>   <dbl>     <dbl> <int> <int>
#> 1 Age in years at scre… Syst… 0.544  0.529   0.559       0      51.5  6300  6302

# Wide correlation matrix
get_corr(d, x = c(ridageyr, bpxsy1), format = "wide")
#> # A tibble: 2 × 3
#>   variable                         Age in years at scre…¹ Systolic: Blood pres…²
#>   <chr>                                             <dbl>                  <dbl>
#> 1 Age in years at screening                        NA                      0.544
#> 2 Systolic: Blood pres (1st rdg) …                  0.544                 NA    
#> # ℹ abbreviated names: ¹​`Age in years at screening`,
#> #   ²​`Systolic: Blood pres (1st rdg) mm Hg`

# AAPOR-compliant
get_corr(d, x = c(ridageyr, bpxsy1),
         variance = c("ci", "moe"), n_weighted = TRUE)
#> # A tibble: 1 × 11
#>   var1           var2      r ci_low ci_high    moe p_value statistic    df     n
#>   <fct>          <fct> <dbl>  <dbl>   <dbl>  <dbl>   <dbl>     <dbl> <int> <int>
#> 1 Age in years … Syst… 0.544  0.529   0.559 0.0151       0      51.5  6300  6302
#> # ℹ 1 more variable: n_weighted <dbl>

# Polychoric correlation between two ordinal variables
df <- data.frame(
  id = 1:200,
  wt = runif(200, 0.5, 2),
  o1 = factor(sample(1:4, 200, replace = TRUE), ordered = TRUE),
  o2 = factor(sample(1:4, 200, replace = TRUE), ordered = TRUE)
)
d_ord <- as_survey(df, weights = wt)
get_corr(d_ord, x = c(o1, o2), method = "polychoric")
#> # A tibble: 1 × 9
#>   var1  var2        r ci_low ci_high p_value statistic    df     n
#>   <fct> <fct>   <dbl>  <dbl>   <dbl>   <dbl>     <dbl> <int> <int>
#> 1 o1    o2    -0.0110 -0.299   0.279   0.942   -0.0725    NA   200
```
