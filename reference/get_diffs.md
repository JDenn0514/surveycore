# Treatment Effect Estimation for Survey Designs

Estimates treatment effects (differences from a reference group) via
survey-weighted regression. Supports bivariate and multivariate models,
Gaussian and non-Gaussian families, and optional subgroup analysis.

## Usage

``` r
get_diffs(
  design,
  x,
  treats,
  group = NULL,
  covariates = NULL,
  ref_level = NULL,
  pval_adj = NULL,
  show_means = TRUE,
  show_pct_change = FALSE,
  scale = c("ame", "link"),
  variance = "ci",
  conf_level = 0.95,
  alpha = 0.05,
  show_favorability = FALSE,
  min_cell_n = 30L,
  n_weighted = FALSE,
  decimals = NULL,
  na.rm = TRUE,
  label_values = TRUE,
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
  A single unquoted numeric variable name for the dependent variable.
  Must resolve to exactly one numeric column (continuous or 0/1 binary).

- treats:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  A single unquoted variable name for the treatment/group variable. Must
  resolve to exactly one column with at least 2 unique levels. Coerced
  to factor if not already.

- group:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Optional subgroup variable(s) for interaction analysis. When provided,
  treatment effects are reported separately within each subgroup.
  Combined with any grouping set by `group_by()`. Default `NULL`.

- covariates:

  Character vector of additional model terms as strings. Supports
  interactions (`"age * gender"`), polynomials (`"poly(edu, 2)"`), and
  transformations (`"log(income)"`). When provided, forces the
  marginaleffects estimation path. Default `NULL`.

- ref_level:

  Character(1). Reference level of `treats` for comparisons. If `NULL`
  (default), the first factor level is used. Must match an existing
  level.

- pval_adj:

  Character(1) or `NULL`. P-value adjustment method passed to
  [`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html). Options:
  `"holm"`, `"hochberg"`, `"hommel"`, `"bonferroni"`, `"BH"`, `"BY"`,
  `"fdr"`, `"none"`. `NULL` = no adjustment. When `group` is active,
  adjustment is applied independently within each group.

- show_means:

  Logical. If `TRUE` (default), includes a `mean` column and a reference
  row with `estimate = 0`. Subject to link-scale suppression (see
  Details).

- show_pct_change:

  Logical. If `TRUE`, includes a `pct_change` column:
  `estimate / reference_mean`. Subject to link-scale suppression (see
  Details). Default `FALSE`.

- scale:

  Character(1). `"ame"` (default): average marginal effects on the
  response scale. `"link"`: coefficients on the link scale. For
  Gaussian/identity models, both are identical. Case-sensitive.

- variance:

  `NULL` or a character vector of one or more of `"se"`, `"ci"`.
  Controls which uncertainty columns appear. Default `"ci"`.

- conf_level:

  Numeric(1) in (0, 1). Confidence level. Default `0.95`.

- alpha:

  Numeric(1) strictly between 0 and 1. Significance threshold used when
  `show_favorability = TRUE` to classify whether a difference is
  statistically significant. Uses strict `<` (p \< alpha). Default
  `0.05`.

- show_favorability:

  Logical. If `TRUE`, appends two logical columns to the result:
  `favorable` (the difference is statistically significant and in the
  direction indicated by `higher_is` metadata on `x`) and `backlash`
  (significant but in the opposite direction). Requires `higher_is`
  metadata set on `x` via
  [`set_higher_is()`](https://jdenn0514.github.io/surveycore/reference/set_higher_is.md);
  if not set, both columns are all `FALSE`. Default `FALSE`.

- min_cell_n:

  Integer(1). Minimum unweighted cell size before
  `surveycore_warning_small_cell` fires. Default `30L`.

- n_weighted:

  Logical. If `TRUE`, includes an `n_weighted` column with sum of
  weights per treatment level. Default `FALSE`.

- decimals:

  Integer(1) or `NULL`. If non-NULL, rounds numeric output columns.
  `pct_change` is rounded to `decimals + 2`. Default `NULL`.

- na.rm:

  Logical. If `TRUE` (default), rows with `NA` in `x`, `treats`, or
  `group` are dropped before fitting. If `FALSE`, `NA` values cause an
  error.

- label_values:

  Logical. If `TRUE` (default), the `treats` and `group` columns display
  value labels from metadata instead of raw codes. Output type is
  `factor` when labels are applied.

- name_style:

  `"surveycore"` (default) or `"broom"`. When `"broom"`, renames `se` to
  `std.error`, `ci_low` to `conf.low`, etc. The `mean` column is
  excluded from renaming.

- ...:

  Passed to
  [`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md).
  Common uses: `family = quasibinomial()`.

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

A `survey_diffs` tibble (also inheriting `survey_result`). Columns (in
order): group columns (when active), treatment variable, `estimate`,
`pct_change` (optional), `mean` (optional), `n`, `n_weighted`
(optional), `se` (optional), `ci_low` (optional), `ci_high` (optional),
`p_value`, `stars`, `favorable` (optional), `backlash` (optional). Use
[`meta()`](https://jdenn0514.github.io/surveycore/reference/meta.md) to
access design type, family, reference level, and other metadata.

## Details

### Estimation Paths

`get_diffs()` uses two estimation paths:

- **Clean path** (bivariate Gaussian with no covariates and no group, OR
  any family with `scale = "link"`): extracts coefficients directly from
  [`clean()`](https://jdenn0514.github.io/surveycore/reference/clean.md).
  The intercept is the reference group mean; treatment coefficients are
  differences from reference. When `scale = "link"` and the family is
  non-Gaussian, `mean` and `pct_change` are suppressed.

- **Marginaleffects path** (covariates, non-Gaussian with
  `scale = "ame"`, or group): uses `avg_slopes()` for estimates and
  `avg_predictions()` for means.

### Link-Scale Suppression

When `scale = "link"` and the family is non-Gaussian, the `mean` and
`pct_change` columns are suppressed (omitted entirely). Link-scale means
are not substantively meaningful.

### P-Value Adjustment

When `group` is active, p-value adjustment is applied independently
within each group. For global adjustment across all comparisons, apply
[`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html) to the
result manually. Confidence intervals reflect the specified `conf_level`
and are not affected by p-value adjustment.

### Degrees of Freedom

All p-values and confidence intervals use the t-distribution with
design-based residual degrees of freedom, regardless of estimation path.

### Non-Gaussian Models

By default, non-Gaussian models report average marginal effects on the
response scale. Set `scale = "link"` for coefficients on the link scale
(e.g., log-odds for logistic regression).

## See also

Other analysis:
[`clean()`](https://jdenn0514.github.io/surveycore/reference/clean.md),
[`get_anova()`](https://jdenn0514.github.io/surveycore/reference/get_anova.md),
[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md),
[`get_covariance()`](https://jdenn0514.github.io/surveycore/reference/get_covariance.md),
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
# Create survey design with treatment groups
set.seed(42)
df <- data.frame(
  id = 1:200,
  wt = runif(200, 0.5, 2),
  dv = rnorm(200, 50, 10),
  arm = factor(sample(c("Control", "A", "B"), 200, TRUE))
)
d <- as_survey(df, weights = wt)

# Basic treatment effect
get_diffs(d, dv, arm)
#> # A tibble: 3 × 8
#>   arm     estimate  mean     n ci_low ci_high p_value stars
#>   <fct>      <dbl> <dbl> <int>  <dbl>   <dbl>   <dbl> <chr>
#> 1 A          0      50.3    66  NA      NA     NA     ""   
#> 2 B         -2.14   48.2    72  -5.49    1.21   0.209 ""   
#> 3 Control   -0.165  50.2    62  -3.93    3.61   0.931 ""   

# With percentage change and p-value adjustment
get_diffs(d, dv, arm, show_pct_change = TRUE, pval_adj = "BH")
#> # A tibble: 3 × 9
#>   arm     estimate pct_change  mean     n ci_low ci_high p_value stars
#>   <fct>      <dbl>      <dbl> <dbl> <int>  <dbl>   <dbl>   <dbl> <chr>
#> 1 A          0       NA        50.3    66  NA      NA     NA     ""   
#> 2 B         -2.14    -0.0425   48.2    72  -5.49    1.21   0.418 ""   
#> 3 Control   -0.165   -0.00327  50.2    62  -3.93    3.61   0.931 ""   
```
