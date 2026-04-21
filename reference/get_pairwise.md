# All-Pairs Pairwise T-Tests for Survey Designs

Runs all k(k-1)/2 pairwise two-sample t-tests for a grouping variable
with k levels and applies multiple-comparison p-value adjustment.
Delegates pair-level computations to
[`get_t_test()`](https://jdenn0514.github.io/surveycore/reference/get_t_test.md).

## Usage

``` r
get_pairwise(
  design,
  x,
  by,
  group = NULL,
  pval_adj = "holm",
  conf_level = 0.95,
  variance = "ci",
  na.rm = TRUE,
  min_cell_n = 30L,
  decimals = NULL,
  label_values = TRUE,
  label_vars = TRUE,
  name_style = "surveycore",
  ...,
  .id = ".survey",
  .on_missing = "error"
)
```

## Arguments

- design:

  A survey design object: `survey_taylor`, `survey_replicate`,
  `survey_twophase`, or `survey_nonprob`.

- x:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  A single unquoted numeric variable name for the outcome variable.

- by:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  A single unquoted variable name for the grouping variable. Must have
  at least 2 active levels.

- group:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Optional subgroup variable(s). When supplied, pairwise comparisons are
  run within each group stratum. P-value adjustment is applied
  separately per stratum. Default `NULL`.

- pval_adj:

  Character(1). P-value adjustment method passed to
  [`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html). Default
  `"holm"`. Use `"none"` for unadjusted p-values. Error:
  `surveycore_error_invalid_pval_adj`.

- conf_level:

  Numeric(1). Confidence level strictly in (0, 1). Default `0.95`.

- variance:

  Character. Which uncertainty columns to include. Valid values: `"se"`,
  `"ci"`. Default `"ci"`.

- na.rm:

  Logical(1). Accepted for API uniformity. Default `TRUE`.

- min_cell_n:

  Integer(1). Warn for small cells. Default `30L`.

- decimals:

  Integer(1) or `NULL`. Round all double output columns. Default `NULL`.

- label_values:

  Logical(1). Convert `by`/`group` codes to value labels. Default
  `TRUE`.

- label_vars:

  Logical(1). Accepted for API uniformity; no visible effect. Default
  `TRUE`.

- name_style:

  Character(1). `"surveycore"` (default) or `"broom"`.

- ...:

  Unused. Reserved so that `.id` and `.on_missing` remain named-only
  when a `survey_collection` is passed as `design`.

- .id:

  Character(1). Column name used to identify each survey when `design`
  is a
  [`survey_collection`](https://jdenn0514.github.io/surveycore/reference/survey_collection.md).
  Default `".survey"`. Ignored when `design` is a single survey.

- .on_missing:

  `"error"` (default) or `"skip"`. How to handle surveys in a collection
  that lack one of the requested NSE variables. Ignored when `design` is
  a single survey.

## Value

A `survey_pairwise` tibble (also inheriting `survey_result`). Columns:
group columns (when active), `level_a`, `level_b`, `estimate`, `mean_a`,
`mean_b`, `n_a`, `n_b`, `se` (optional), `ci_low` (optional), `ci_high`
(optional), `t_stat`, `df`, `p_value` (adjusted), `stars`. Use
[`meta()`](https://jdenn0514.github.io/surveycore/reference/meta.md) to
access the adjustment method and other metadata.

## See also

Other analysis:
[`clean()`](https://jdenn0514.github.io/surveycore/reference/clean.md),
[`get_anova()`](https://jdenn0514.github.io/surveycore/reference/get_anova.md),
[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md),
[`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md),
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md),
[`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md),
[`get_t_test()`](https://jdenn0514.github.io/surveycore/reference/get_t_test.md),
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
[`meta()`](https://jdenn0514.github.io/surveycore/reference/meta.md)

## Examples

``` r
gss_sub <- gss_2024[gss_2024$sex %in% c(1L, 2L) & !is.na(gss_2024$age), ]
gss_sub$sex <- factor(gss_sub$sex, levels = c(1, 2), labels = c("Male", "Female"))
gss_design <- as_survey(gss_sub,
  ids = vpsu, weights = wtssps, strata = vstrat, nest = TRUE)
get_pairwise(gss_design, age, by = sex)
#> # A tibble: 1 × 13
#>   level_a level_b estimate mean_a mean_b   n_a   n_b ci_low ci_high t_stat    df
#>   <chr>   <chr>      <dbl>  <dbl>  <dbl> <int> <int>  <dbl>   <dbl>  <dbl> <dbl>
#> 1 Male    Female     0.260   47.8   48.1  1424  1773  -1.65    2.17  0.271    66
#> # ℹ 2 more variables: p_value <dbl>, stars <chr>
```
