# Design-Based Two-Sample T-Test for Survey Designs

Compares the weighted means of two groups using a design-based t-test.
Follows the mathematical model of
[`survey::svyttest()`](https://rdrr.io/pkg/survey/man/svyttest.html) but
uses surveycore's own variance machinery
([`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md)).
Supports all four survey design classes and optional subgroup analysis
via `group`.

## Usage

``` r
get_t_test(
  design,
  x,
  by,
  group = NULL,
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
  A single unquoted numeric variable name for the outcome variable. Must
  resolve to exactly one numeric column.

- by:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  A single unquoted variable name for the grouping variable. Must
  produce a model matrix with exactly 2 columns after fitting
  (intercept + one binary indicator). Character, integer, and logical
  columns are coerced to factor with a warning. Ordered factors are
  accepted as-is.

- group:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Optional subgroup variable(s). When supplied, the t-test is run
  separately within each unique combination of group values. Combined
  with any grouping set by `group_by()`. Default `NULL`.

- conf_level:

  Numeric(1). Confidence level strictly in (0, 1). Default `0.95`.

- variance:

  Character. Which uncertainty columns to include. Valid values: `"se"`,
  `"ci"`. Default `"ci"`. Both may be requested: `c("se", "ci")`.

- na.rm:

  Logical(1). Accepted for API uniformity with other `get_*()`
  functions. NA rows in `x` or `by` are always excluded (the GLM
  requires complete cases). Default `TRUE`.

- min_cell_n:

  Integer(1). Warn when either group has fewer than this many unweighted
  observations. Default `30L`. Use `0L` to suppress.

- decimals:

  Integer(1) or `NULL`. Round all double output columns to this many
  decimal places. `NULL` = no rounding. Default `NULL`.

- label_values:

  Logical(1). When `TRUE` (default), convert `by` and `group` factor
  codes to their value labels in the output.

- label_vars:

  Logical(1). Accepted for API uniformity; has no visible effect because
  column names are fixed. Default `TRUE`.

- name_style:

  Character(1). Output column naming style. `"surveycore"` (default) or
  `"broom"` (renames `se` to `std.error`, `ci_low` to `conf.low`,
  `ci_high` to `conf.high`, `p_value` to `p.value`, `df` to
  `parameter`). `t_stat` is not renamed.

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

A `survey_t_test` tibble (also inheriting `survey_result`). Columns:
group columns (when active), `level_a`, `level_b`, `estimate`, `mean_a`,
`mean_b`, `n_a`, `n_b`, `se` (optional), `ci_low` (optional), `ci_high`
(optional), `t_stat`, `df`, `p_value`, `stars`. Use
[`meta()`](https://jdenn0514.github.io/surveycore/reference/meta.md) to
access design type, conf_level, and variable metadata.

## See also

Other analysis:
[`clean()`](https://jdenn0514.github.io/surveycore/reference/clean.md),
[`get_anova()`](https://jdenn0514.github.io/surveycore/reference/get_anova.md),
[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md),
[`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md),
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_pairwise()`](https://jdenn0514.github.io/surveycore/reference/get_pairwise.md),
[`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md),
[`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md),
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
[`meta()`](https://jdenn0514.github.io/surveycore/reference/meta.md)

## Examples

``` r
gss_sub <- gss_2024[gss_2024$sex %in% c(1L, 2L) & !is.na(gss_2024$age), ]
gss_sub$sex <- factor(gss_sub$sex, levels = c(1, 2), labels = c("Male", "Female"))
gss_design <- as_survey(gss_sub,
  ids = vpsu, weights = wtssps, strata = vstrat, nest = TRUE)
get_t_test(gss_design, age, by = sex)
#> # A tibble: 1 × 13
#>   level_a level_b estimate mean_a mean_b   n_a   n_b ci_low ci_high t_stat    df
#>   <chr>   <chr>      <dbl>  <dbl>  <dbl> <int> <int>  <dbl>   <dbl>  <dbl> <dbl>
#> 1 Male    Female     0.260   47.8   48.1  1424  1773  -1.65    2.17  0.271    66
#> # ℹ 2 more variables: p_value <dbl>, stars <chr>
```
