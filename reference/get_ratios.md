# Survey-Weighted Ratio Estimation

Estimate the ratio of two survey-weighted totals (numerator /
denominator) for a survey design object. Uses the delta method
(linearization) for variance estimation for Taylor, SRS, calibrated, and
two-phase designs, and direct per-replicate computation for
replicate-weight designs. Both approaches are equivalent to
[`survey::svyratio()`](https://rdrr.io/pkg/survey/man/svyratio.html) for
their respective design types. Supports optional grouping, domain
estimation, and all five survey design classes.

## Usage

``` r
get_ratios(
  design,
  numerator,
  denominator,
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

- numerator:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  A single unquoted numeric variable name for the numerator. Must
  resolve to exactly one numeric column.

- denominator:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  A single unquoted numeric variable name for the denominator. Must
  resolve to exactly one numeric column. All in-domain values must not
  sum to zero.

- group:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Optional grouping variable(s). Combined with any grouping set by
  `group_by()`. Rows where the grouping variable is `NA` are excluded
  from all groups and do not appear in the output. This matches
  [`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html)
  semantics. Default `NULL`.

- variance:

  `NULL` or a character vector from `"se"`, `"ci"`, `"var"`, `"cv"`,
  `"moe"`, `"deff"`. Controls which uncertainty columns appear in the
  output. Default `"ci"`.

- conf_level:

  Numeric scalar in (0, 1). Confidence level for confidence intervals.
  Default `0.95`.

- n_weighted:

  Logical. If `TRUE`, add an `n_weighted` column with the sum of weights
  for rows where both numerator and denominator are non-NA in each
  group. Default `FALSE`.

- decimals:

  Integer or `NULL`. If an integer, rounds all numeric output columns
  (e.g., `ratio`, `se`, `ci_low`, `ci_high`) to this many decimal
  places. Default `NULL` (no rounding).

- min_cell_n:

  Integer. Minimum unweighted cell count before
  `surveycore_warning_small_cell` fires. Default `30L` (AAPOR guidance).

- na.rm:

  Logical. If `TRUE` (default), `NA` values are excluded from analysis:
  observations where the analysis variable is `NA` are dropped from
  calculations, and observations where any group variable is `NA` are
  excluded from the output. If `FALSE`, `NA` observations in the
  analysis variable are included in calculations, and observations where
  a group variable is `NA` are collected into their own group row in the
  output (appearing after all non-`NA` group rows).

- label_values:

  Logical. Accepted for API consistency across `get_*()` functions. For
  `get_ratios()`, no value-level cells appear in the output, so this
  parameter has no effect. Default `TRUE`.

- label_vars:

  Logical. Accepted for API uniformity; has no visible effect on
  `get_ratios()` output. Default `TRUE`.

- name_style:

  `"surveycore"` (default) or `"broom"`. When `"broom"`, renames `ratio`
  → `estimate`, `se` → `std.error`, `ci_low` → `conf.low`, `ci_high` →
  `conf.high`.

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

A `survey_ratios` tibble (also inheriting `survey_result`).

- `[group_cols...]` — group variable columns (when active), first.

- `ratio` — estimated ratio (weighted total of numerator / weighted
  total of denominator).

- Variance columns (`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`,
  `deff`) — only those requested via `variance`.

- `n` — unweighted count of rows where both numerator and denominator
  are non-NA.

- `n_weighted` — sum of weights (only when requested).

Numerator and denominator variable names are stored in `meta(result)`,
not as output columns. Use `meta(result)$numerator` and
`meta(result)$denominator` to access them.

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
[`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md),
[`get_t_test()`](https://jdenn0514.github.io/surveycore/reference/get_t_test.md),
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
[`get_variance()`](https://jdenn0514.github.io/surveycore/reference/get_variance.md),
[`meta()`](https://jdenn0514.github.io/surveycore/reference/meta.md)

## Examples

``` r
d <- as_survey(pew_npors_2025, weights = weight, strata = stratum)

# Ratio of prayer frequency to in-person attendance frequency
get_ratios(d, numerator = pray, denominator = attendper)
#> # A tibble: 1 × 4
#>   ratio ci_low ci_high     n
#>   <dbl>  <dbl>   <dbl> <int>
#> 1 0.871  0.808   0.935  5022

# With grouped estimates
get_ratios(d, pray, attendper, group = gender)
#> Warning: ! 1 cell has fewer than 30 unweighted observations. Estimates in these cells
#>   may be unreliable for public reporting (AAPOR guidance).
#> # A tibble: 4 × 5
#>   gender            ratio ci_low ci_high     n
#>   <fct>             <dbl>  <dbl>   <dbl> <int>
#> 1 A man             0.908  0.853   0.964  2194
#> 2 A woman           0.852  0.747   0.958  2758
#> 3 In some other way 0.953 -0.123   2.03     45
#> 4 Refused/Web blank 0.616  0.208   1.02     25

# AAPOR-compliant output
get_ratios(d, pray, attendper, variance = c("ci", "moe"), n_weighted = TRUE)
#> # A tibble: 1 × 6
#>   ratio ci_low ci_high    moe     n n_weighted
#>   <dbl>  <dbl>   <dbl>  <dbl> <int>      <dbl>
#> 1 0.871  0.808   0.935 0.0637  5022      5022.
```
