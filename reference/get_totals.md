# Weighted Total for a Survey Design

Compute the estimated population total of a numeric variable in a survey
design, one total per level of a categorical variable, or the estimated
population size when no variable is supplied. Supports optional
grouping, uncertainty quantification, and metadata-driven labelling.

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
  Optional single unquoted variable name. When `NULL` (default),
  estimates the population size (sum of weights). When numeric,
  estimates the weighted sum (sum of w_i \* x_i). When a factor or
  character vector, returns one row per level: the level's total is the
  weighted sum of its 0/1 indicator, the same estimate and standard
  error as
  [`survey::svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html)
  on a factor. Factor levels keep their declared order and character
  levels sort ascending. A level with no observed rows in the active
  domain is dropped, as in
  [`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md);
  [`survey::svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html)
  returns it as a zero row. Logical and other column types are rejected.

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
  and is included for API uniformity. For a numeric `x`, adds the sum of
  weights for non-NA observations. For a categorical `x`, adds the sum
  of weights at each level, which equals `total`. Default `FALSE`.

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
  output (appearing after all non-`NA` group rows). For a categorical
  `x`, `FALSE` also adds an `NA` level row after the other levels,
  holding the total of the rows where `x` is `NA`.

- label_values:

  Logical. If `TRUE` (default), group columns and the level column of a
  categorical `x` show value labels where they exist. For a numeric `x`,
  no value-level cells appear in the output.

- label_vars:

  Logical. Accepted for API uniformity. Default `TRUE`.

- name_style:

  `"surveycore"` (default) or `"broom"`.

- ...:

  Additional arguments forwarded to `.dispatch_over_collection()` when
  `design` is a
  [`survey_collection`](https://jdenn0514.github.io/surveycore/reference/survey_collection.md).
  For single-survey inputs these arguments are ignored.

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

A `survey_totals` tibble (also inheriting `survey_result`). Columns:

- `[group_cols...]` — group variable columns (when active), first.

- `[x]` — the level of a categorical `x`, named after the variable
  (categorical `x` only).

- `total` — the weighted sum estimate.

- Variance columns — only those requested via `variance`.

- `n` — unweighted count (omitted in no-variable mode). For a
  categorical `x`, the count of rows at the level.

- `n_weighted` — sum of weights (only when requested).

The variable name (or `NULL` for no-variable mode) is in
`meta(result)$x`. Use `meta(result)` for additional metadata.

On a Taylor or replicate design (including a `survey_nonprob` design
with replicate weights), the result also stores the joint covariance
matrix of its estimates, covering every pair of rows. Read it with
`vcov(result)`; see
[`vcov.survey_result()`](https://jdenn0514.github.io/surveycore/reference/vcov.survey_result.md).

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
[`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md),
[`get_t_test()`](https://jdenn0514.github.io/surveycore/reference/get_t_test.md),
[`get_variance()`](https://jdenn0514.github.io/surveycore/reference/get_variance.md),
[`meta()`](https://jdenn0514.github.io/surveycore/reference/meta.md)

## Examples

``` r
d <- as_survey_replicate(
  acs_pums_wy,
  weights = pwgtp,
  repweights = pwgtp1:pwgtp80,
  type = "successive-difference"
)

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
#> 1 23089173 22977428. 23200918.  5962

# Grouped
get_totals(d, agep, group = sex)
#> # A tibble: 2 × 5
#>     sex    total    ci_low   ci_high     n
#>   <int>    <dbl>     <dbl>     <dbl> <int>
#> 1     1 11652675 11536209. 11769141.  2985
#> 2     2 11436498 11336376. 11536620.  2977

# One total per level of a factor
acs <- acs_pums_wy
acs$sex_f <- factor(acs$sex, levels = 1:2, labels = c("Male", "Female"))
d_f <- as_survey_replicate(
  acs,
  weights = pwgtp,
  repweights = pwgtp1:pwgtp80,
  type = "successive-difference"
)
get_totals(d_f, sex_f)
#> # A tibble: 2 × 5
#>   sex_f   total  ci_low ci_high     n
#>   <fct>   <dbl>   <dbl>   <dbl> <int>
#> 1 Male   299103 296292. 301914.  2985
#> 2 Female 282278 279467. 285089.  2977
```
