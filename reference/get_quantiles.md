# Survey-Weighted Quantiles

Compute survey-weighted quantiles (including the median) for a single
numeric variable using the Woodruff (1952) confidence interval method.
Supports optional grouping, domain estimation, and all five survey
design classes.

## Usage

``` r
get_quantiles(
  design,
  x,
  probs = c(0.25, 0.5, 0.75),
  group = NULL,
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
  `survey_twophase`, or `survey_nonprob`.

- x:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  A single unquoted numeric variable name. Must resolve to exactly one
  numeric column.

- probs:

  Numeric vector of probabilities in (0, 1). Default
  `c(0.25, 0.5, 0.75)` (IQR + median).

- group:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Optional grouping variable(s). Combined with any grouping set by
  `group_by()`. Default `NULL`.

- variance:

  `NULL` or a character vector from `"se"`, `"ci"`, `"var"`, `"cv"`,
  `"moe"`, `"deff"`. Controls which uncertainty columns appear in the
  output. CIs use the Woodruff (1952) back-transformation method and are
  **not** symmetric around the estimate. `"deff"` is always `NA` for
  quantiles (no closed-form SRS SE). Default `"ci"`.

- conf_level:

  Numeric scalar in (0, 1). Confidence level for Woodruff intervals.
  Default `0.95`.

- n_weighted:

  Logical. If `TRUE`, add an `n_weighted` column with the sum of weights
  for non-NA observations in each group. Default `FALSE`.

- decimals:

  Integer or `NULL`. If an integer, rounds all numeric output columns
  (e.g., `estimate`, `se`, `ci_low`, `ci_high`) to this many decimal
  places. Default `NULL` (no rounding).

- min_cell_n:

  Integer. Minimum unweighted cell count before
  `surveycore_warning_small_cell` fires. Default `30L` (AAPOR guidance).

- na.rm:

  Logical. If `TRUE` (default), `NA` values in the analysis variable are
  excluded from calculations. If `FALSE`, any `NA` values in the
  analysis variable cause all quantile estimates for that cell to be
  `NA_real_`. Observations where any group variable is `NA` are always
  excluded from the output when `na.rm = TRUE`; when `na.rm = FALSE`
  they are collected into their own group row (appearing after all
  non-`NA` rows).

- label_values:

  Logical. Accepted for API consistency across `get_*()` functions. For
  `get_quantiles()`, no value-level cells appear in the output, so this
  parameter has no effect. Default `TRUE`.

- label_vars:

  Logical. Accepted for API uniformity; has no visible effect on
  `get_quantiles()` output. Default `TRUE`.

- name_style:

  `"surveycore"` (default) or `"broom"`. When `"broom"`, renames `se` →
  `std.error`, `ci_low` → `conf.low`, `ci_high` → `conf.high`. The
  `estimate` column is unchanged.

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

A `survey_quantiles` tibble (also inheriting `survey_result`).

- `[group_cols...]` — group variable columns (when active), first.

- `quantile` — probability label: `"p25"`, `"p50"`, etc.

- `estimate` — weighted quantile estimate.

- Variance columns (`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`,
  `deff`) — only those requested via `variance`. CIs are Woodruff
  intervals and are generally asymmetric around `estimate`. `deff` is
  always `NA` for quantile estimates: computing it requires a kernel
  density estimate at the quantile point (the Woodruff SRS approximation
  used by `survey::svyquantile(deff = TRUE)`), which is not implemented.

- `n` — unweighted count of observations in the active domain used in
  the estimate. When `na.rm = TRUE`, counts only non-NA observations;
  when `na.rm = FALSE`, counts all active-domain rows (including NAs,
  though the estimate will be `NA_real_`).

- `n_weighted` — sum of weights (only when requested).

One row per (group combination × quantile probability). The variable
name and `probs` vector are stored in `meta(result)`.

## References

Woodruff, R. S. (1952). Confidence intervals for medians and other
position measures. *Journal of the American Statistical Association*,
**47**(260), 635–646.

## See also

Other analysis:
[`SE()`](https://jdenn0514.github.io/surveycore/reference/SE.md),
[`clean()`](https://jdenn0514.github.io/surveycore/reference/clean.md),
[`get_anova()`](https://jdenn0514.github.io/surveycore/reference/get_anova.md),
[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md),
[`get_covariance()`](https://jdenn0514.github.io/surveycore/reference/get_covariance.md),
[`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md),
[`get_effective_n()`](https://jdenn0514.github.io/surveycore/reference/get_effective_n.md),
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_pairwise()`](https://jdenn0514.github.io/surveycore/reference/get_pairwise.md),
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

# IQR + median (default)
get_quantiles(d, ridageyr)
#> # A tibble: 3 × 5
#>   quantile estimate ci_low ci_high     n
#>   <chr>       <dbl>  <dbl>   <dbl> <int>
#> 1 p25            19     18      21  9254
#> 2 p50            38     37      40  9254
#> 3 p75            57     56      60  9254

# Median only with SE
get_quantiles(d, ridageyr, probs = 0.5, variance = c("ci", "se"))
#> # A tibble: 1 × 6
#>   quantile estimate    se ci_low ci_high     n
#>   <chr>       <dbl> <dbl>  <dbl>   <dbl> <int>
#> 1 p50            38 0.704     37      40  9254

# Grouped quartiles
get_quantiles(d, ridageyr, group = riagendr)
#> # A tibble: 6 × 6
#>   riagendr quantile estimate ci_low ci_high     n
#>      <dbl> <chr>       <dbl>  <dbl>   <dbl> <int>
#> 1        1 p25            18     17      20  4557
#> 2        1 p50            36     34      38  4557
#> 3        1 p75            56     55      58  4557
#> 4        2 p25            20     19      22  4697
#> 5        2 p50            39     38      42  4697
#> 6        2 p75            58     56      61  4697
```
