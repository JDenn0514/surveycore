# Design-Based Population Covariance for a Survey Design

Compute the design-based estimate of the finite-population Pearson
covariance for every (unordered, by default) pair of numeric variables
selected from `x`, with optional grouping, uncertainty quantification,
and metadata-driven labelling. Matches the off-diagonal entries of
[`survey::svyvar()`](https://rdrr.io/pkg/survey/man/surveysummary.html)
(Kish `n/(n-1)` correction) on Taylor, replicate, twophase, and nonprob
designs at numerical parity.

## Usage

``` r
get_covariance(
  design,
  x,
  group = NULL,
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
  ...,
  .id = NULL,
  .if_missing_var = NULL
)
```

## Arguments

- design:

  A survey design object: `survey_taylor`, `survey_replicate`,
  `survey_twophase`, or `survey_nonprob`. Also accepts a
  [`survey_collection`](https://jdenn0514.github.io/surveycore/reference/survey_collection.md).

- x:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Two or more unquoted variable names. Must resolve to at least two
  columns. Non-numeric columns are dropped with a warning; if fewer than
  2 numeric variables remain, an error is raised.

- group:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Optional grouping variable(s). Combined with any grouping set by
  `group_by()`. Default `NULL`. Covariances are estimated separately
  within each group using that group's own weighted means for centring.

- redundant:

  Logical. If `FALSE` (default), each unordered pair appears once in
  supply order (lower-triangle). If `TRUE`, both `(A, B)` and `(B, A)`
  are emitted.

- diagonal:

  Logical. If `FALSE` (default), self-pairs `(x, x)` are excluded. If
  `TRUE`, one self-pair per variable is emitted with
  `covariance = \eqn{\widehat{\mathrm{Var}}(x)}{Var_hat(x)}` (the
  design-based variance – **not** `1`).

- variance:

  `NULL` or a character vector of one or more of `"se"`, `"ci"`,
  `"var"`, `"cv"`, `"moe"`, `"deff"`. Default `"ci"`.

- conf_level:

  Numeric scalar in `(0, 1)`. Default `0.95`.

- n_weighted:

  Logical. If `TRUE`, append an `n_weighted` column with the pair's
  pairwise-complete sum of weights. Default `FALSE`.

- decimals:

  Integer or `NULL`. If integer, rounds all numeric output columns to
  this many places. Default `NULL` (no rounding).

- min_cell_n:

  Integer. Minimum pairwise unweighted count before
  `surveycore_warning_small_cell` fires. Default `30L` (AAPOR).

- na.rm:

  Logical. If `TRUE` (default), pairwise-complete deletion per pair, and
  rows with `NA` in any group variable are excluded from the output. If
  `FALSE`, NAs propagate to produce `NaN` estimates; NA group values are
  retained as their own group row.

- label_values:

  Logical. If `TRUE` (default) and the grouping variable has value
  labels, the group column is converted to a labelled factor.

- label_vars:

  Logical. If `TRUE` (default) and variable labels are set in metadata,
  `var1` and `var2` show labels instead of raw names.

- name_style:

  `"surveycore"` (default) or `"broom"`. Under `"broom"`, renames
  `covariance` -\> `estimate`, `se` -\> `std.error`, `ci_low` -\>
  `conf.low`, `ci_high` -\> `conf.high`.

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

A `survey_covariance` tibble (also inheriting `survey_result`). Columns,
in order:

- `[group_cols...]` — group variable columns (when active), first.

- `var1`, `var2` — factor columns identifying the pair (levels in
  `x`-supply order).

- `covariance` — design-based Pearson covariance estimate
  (Kish-corrected). `NaN` for degenerate cells; `0` for pairs where at
  least one variable is constant on the active domain.

- Uncertainty columns (`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`,
  `deff`) — only those requested via `variance`.

- `n` — pairwise unweighted count.

- `n_weighted` — pair's sum of weights (only when requested).

## Details

Confidence intervals use the normal-Wald approximation on the SE of the
covariance estimate: `ci_low = covariance - z * se`,
`ci_high = covariance + z * se`, where
`z = qnorm((1 + conf_level) / 2)`. The bounds are **not clamped**.
Covariance is unbounded — `ci_low` and `ci_high` may have opposite signs
and may cross zero. Users who want clamped intervals can post-process.
This behaviour matches
[`survey::svyvar()`](https://rdrr.io/pkg/survey/man/surveysummary.html).

NA handling is **pairwise-complete per pair**: each ordered pair drops
rows where either variable is `NA`. There is no `na_handling` argument;
pairwise is the only policy. This matches
[`survey::svyvar()`](https://rdrr.io/pkg/survey/man/surveysummary.html)
off-diagonal pair-at-a-time semantics, **not** `svyvar()`'s default
listwise deletion across a multi-variable formula. Numerical parity
therefore only holds when oracle calls are made pair-at-a-time
(`survey::svyvar(~x + y, design)` per pair).

Under `diagonal = TRUE`, the self-pair `(x, x)` returns the design-based
Kish-corrected **variance** of `x` on the active domain — not `1` as in
[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md).
The covariance matrix diagonal is the variance vector, not the identity.
The diagonal-parity gate guarantees that
`get_covariance(d, c(x, x), diagonal = TRUE)$covariance` and `$se` equal
`get_variance(d, x)$variance` and `$se` numerically (point at `1e-10`,
SE at `1e-8`) when the active domains match.

Design effect (`deff`) uses the Goodnight / Mood-Graybill SRS reference
`SE_SRS(cov) = sqrt((Var(x) * Var(y) + cov^2) / (n - 1))`. When both the
design SE and SRS SE are zero (constant-variable pairs), `deff` is set
to exactly `0` (0 / 0 guard).

## References

Mood, A. M., Graybill, F. A., & Boes, D. C. (1974). *Introduction to the
Theory of Statistics* (3rd ed.). McGraw-Hill.

Lumley, T. (2010). *Complex Surveys: A Guide to Analysis Using R*.
Wiley.

Cochran, W. G. (1977). *Sampling Techniques* (3rd ed.). Wiley.

Demnati, A., & Rao, J. N. K. (2004). Linearization variance estimators
for survey data. *Survey Methodology*, 30, 17–26.

## See also

Other analysis:
[`SE()`](https://jdenn0514.github.io/surveycore/reference/SE.md),
[`clean()`](https://jdenn0514.github.io/surveycore/reference/clean.md),
[`get_anova()`](https://jdenn0514.github.io/surveycore/reference/get_anova.md),
[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md),
[`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md),
[`get_effective_n()`](https://jdenn0514.github.io/surveycore/reference/get_effective_n.md),
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
d <- as_survey(
  nhanes_2017,
  ids = sdmvpsu,
  weights = wtint2yr,
  strata = sdmvstra,
  nest = TRUE
)
get_covariance(d, x = c(ridageyr, bpxsy1))
#> # A tibble: 1 × 6
#>   var1                      var2                 covariance ci_low ci_high     n
#>   <fct>                     <fct>                     <dbl>  <dbl>   <dbl> <int>
#> 1 Age in years at screening Systolic: Blood pre…       197.   184.    210.  6302

# Include the diagonal (self-pairs return Var(x), not 1)
get_covariance(d, x = c(ridageyr, bpxsy1), diagonal = TRUE)
#> # A tibble: 3 × 6
#>   var1                                 var2      covariance ci_low ci_high     n
#>   <fct>                                <fct>          <dbl>  <dbl>   <dbl> <int>
#> 1 Age in years at screening            Systolic…       197.   184.    210.  6302
#> 2 Age in years at screening            Age in y…       515.   497.    534.  9254
#> 3 Systolic: Blood pres (1st rdg) mm Hg Systolic…       316.   296.    336.  6302

# With grouping
get_covariance(d, x = c(ridageyr, bpxsy1), group = riagendr)
#> # A tibble: 2 × 7
#>   riagendr var1                      var2        covariance ci_low ci_high     n
#>      <dbl> <fct>                     <fct>            <dbl>  <dbl>   <dbl> <int>
#> 1        1 Age in years at screening Systolic: …       162.   149.    174.  3115
#> 2        2 Age in years at screening Systolic: …       234.   216.    252.  3187
```
