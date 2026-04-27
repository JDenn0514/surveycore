# Weighted Mean for a Survey Design

Compute the weighted mean of a single numeric variable in a survey
design, with optional grouping, uncertainty quantification, and
metadata-driven labelling.

## Usage

``` r
get_means(
  design,
  x,
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

- group:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Optional grouping variable(s). Combined with any grouping set by
  `group_by()`. Default `NULL`.

- variance:

  `NULL` or a character vector of one or more of `"se"`, `"ci"`,
  `"var"`, `"cv"`, `"moe"`, `"deff"`. Controls which uncertainty columns
  appear in the output. Default `"ci"`.

- conf_level:

  Numeric scalar in (0, 1). Confidence level for intervals. Default
  `0.95`.

- n_weighted:

  Logical. If `TRUE`, add an `n_weighted` column with the sum of weights
  for non-NA observations in each group. Default `FALSE`.

- decimals:

  Integer or `NULL`. If an integer, rounds all numeric output columns
  (e.g., `mean`, `se`, `ci_low`, `ci_high`) to this many decimal places.
  Default `NULL` (no rounding).

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

  Logical. Accepted for API uniformity; has no visible effect since
  `get_means()` output contains no categorical value cells. Default
  `TRUE`.

- label_vars:

  Logical. Accepted for API uniformity; has no visible effect since
  `get_means()` output contains no variable-name value cells. Default
  `TRUE`.

- name_style:

  `"surveycore"` (default) or `"broom"`. When `"broom"`, renames `mean`
  → `estimate`, `se` → `std.error`, etc.

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

A `survey_means` tibble (also inheriting `survey_result`). Columns:

- `[group_cols...]` — group variable columns (when active), first.

- `mean` — weighted mean estimate.

- Variance columns (`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`,
  `deff`) — only those requested via `variance`.

- `n` — unweighted count of non-NA observations used in the estimate.

- `n_weighted` — sum of weights (only when requested).

The variable name is stored in `meta(result)$variable`, not as a column.
Use `meta(result)` to access design type, variable labels, and other
metadata.

## See also

Other analysis:
[`clean()`](https://jdenn0514.github.io/surveycore/reference/clean.md),
[`get_anova()`](https://jdenn0514.github.io/surveycore/reference/get_anova.md),
[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md),
[`get_covariance()`](https://jdenn0514.github.io/surveycore/reference/get_covariance.md),
[`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md),
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
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
get_means(d, ridageyr)
#> # A tibble: 1 × 4
#>    mean ci_low ci_high     n
#>   <dbl>  <dbl>   <dbl> <int>
#> 1  38.4   37.4    39.5  9254

# With grouped estimate
get_means(d, ridageyr, group = riagendr)
#> # A tibble: 2 × 5
#>   riagendr  mean ci_low ci_high     n
#>      <dbl> <dbl>  <dbl>   <dbl> <int>
#> 1        1  37.4   36.5    38.4  4557
#> 2        2  39.4   38.2    40.5  4697

# AAPOR-compliant
get_means(d, ridageyr, variance = c("ci", "moe"), n_weighted = TRUE)
#> # A tibble: 1 × 6
#>    mean ci_low ci_high   moe     n n_weighted
#>   <dbl>  <dbl>   <dbl> <dbl> <int>      <dbl>
#> 1  38.4   37.4    39.5  1.03  9254  320842721
```
