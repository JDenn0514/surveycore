# Weighted Total for a Survey Design

Compute the estimated population total of a numeric variable in a survey
design, or the estimated population size when no variable is supplied.
Supports optional grouping, uncertainty quantification, and
metadata-driven labelling.

## Usage

``` r
get_totals(
  design,
  x = NULL,
  group = NULL,
  variance = "ci",
  conf_level = 0.95,
  n_weighted = FALSE,
  decimals = NULL,
  min_cell_n = 30L,
  na.rm = TRUE,
  label_values = TRUE,
  label_vars = TRUE,
  name_style = "surveycore"
)
```

## Arguments

- design:

  A survey design object: `survey_taylor`, `survey_replicate`,
  `survey_twophase`, or `survey_nonprob`.

- x:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Optional single unquoted numeric variable name. When `NULL` (default),
  estimates the population size (`Σ w_i`). When supplied, estimates the
  weighted sum (`Σ w_i × x_i`).

- group:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Optional grouping variable(s). Default `NULL`.

- variance:

  `NULL` or a character vector from `"se"`, `"ci"`, `"var"`, `"cv"`,
  `"moe"`, `"deff"`. Default `"ci"`.

- conf_level:

  Numeric scalar in (0, 1). Default `0.95`.

- n_weighted:

  Logical. For `get_totals(d)` (no variable), equals the `total` column
  and is included for API uniformity. For variable mode, adds the sum of
  weights for non-NA observations. Default `FALSE`.

- decimals:

  Integer or `NULL`. If an integer, rounds all numeric output columns
  (e.g., `total`, `se`, `ci_low`, `ci_high`) to this many decimal
  places. Default `NULL` (no rounding).

- min_cell_n:

  Integer. Default `30L`.

- na.rm:

  Logical. If `TRUE` (default), `NA` values are excluded from analysis:
  observations where the analysis variable is `NA` are dropped from
  calculations, and observations where any group variable is `NA` are
  excluded from the output. If `FALSE`, `NA` observations in the
  analysis variable are included in calculations, and observations where
  a group variable is `NA` are collected into their own group row in the
  output (appearing after all non-`NA` group rows).

- label_values:

  Logical. Accepted for API uniformity. Default `TRUE`.

- label_vars:

  Logical. Accepted for API uniformity. Default `TRUE`.

- name_style:

  `"surveycore"` (default) or `"broom"`.

## Value

A `survey_totals` tibble (also inheriting `survey_result`). Columns:

- `[group_cols...]` — group variable columns (when active), first.

- `total` — the weighted sum estimate.

- Variance columns — only those requested via `variance`.

- `n` — unweighted count (omitted in no-variable mode).

- `n_weighted` — sum of weights (only when requested).

The variable name (or `NULL` for no-variable mode) is in
`meta(result)$variable`. Use `meta(result)` for additional metadata.

## See also

Other analysis:
[`clean()`](https://jdenn0514.github.io/surveycore/reference/clean.md),
[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md),
[`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md),
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md),
[`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md),
[`meta()`](https://jdenn0514.github.io/surveycore/reference/meta.md)

## Examples

``` r
d <- as_survey_replicate(acs_pums_wy, weights = pwgtp,
                   repweights = pwgtp1:pwgtp80,
                   type = "successive-difference")

# Population size
get_totals(d)
#> # A tibble: 1 × 3
#>    total ci_low ci_high
#>    <dbl>  <dbl>   <dbl>
#> 1 581381 581381  581381

# Total for a variable
get_totals(d, agep)
#> # A tibble: 1 × 4
#>      total    ci_low   ci_high     n
#>      <dbl>     <dbl>     <dbl> <int>
#> 1 23089173 23010158. 23168188.  5962

# Grouped
get_totals(d, agep, group = sex)
#> # A tibble: 2 × 5
#>     sex    total    ci_low   ci_high     n
#>   <int>    <dbl>     <dbl>     <dbl> <int>
#> 1     1 11652675 11570321. 11735029.  2985
#> 2     2 11436498 11365701. 11507295.  2977
```
