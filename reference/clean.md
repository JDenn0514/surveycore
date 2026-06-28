# Tidy a Survey GLM Fit

Converts a `survey_glm_fit` object into a `survey_glm_tidy` result
tibble with one row per model coefficient (plus optional reference rows
for factor predictors), design-based standard errors, confidence
intervals, and structured metadata.

## Usage

``` r
clean(
  model,
  conf_level = 0.95,
  include_reference = TRUE,
  n = FALSE,
  statistic = TRUE,
  exponentiate = FALSE,
  interaction_sep = " * ",
  ...
)
```

## Arguments

- model:

  A `survey_glm_fit` object from
  [`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md).

- conf_level:

  Numeric scalar in `(0, 1)`. Confidence level for confidence intervals.
  Default `0.95`.

- include_reference:

  Logical. If `TRUE`, reference levels for unordered factor predictors
  appear as rows with `estimate = NA` and `reference_row = TRUE`.
  Default `TRUE`.

- n:

  Logical. If `TRUE`, adds an `n_obs` column with the unweighted
  observation count per term. Default `FALSE`.

- statistic:

  Logical. If `TRUE` (default), includes the `statistic` (t-statistic)
  column. Set to `FALSE` to drop it.

- exponentiate:

  Logical. If `TRUE`, exponentiates `estimate`, `conf_low`, and
  `conf_high`. `std_error` is left on the log scale (matching `broom`
  convention). Fires `surveycore_warning_exponentiate_nonlog` when the
  model link is not log-based. Default `FALSE`.

- interaction_sep:

  Character scalar. Separator for interaction term labels. Default
  `" * "`.

- ...:

  Currently unused.

## Value

A `survey_glm_tidy` object: a tibble with S3 class
`c("survey_glm_tidy", "survey_result", "tbl_df", "tbl", "data.frame")`.
Metadata is accessed via
[`meta()`](https://jdenn0514.github.io/surveycore/reference/meta.md).

## See also

[`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md)
to fit the model,
[`meta()`](https://jdenn0514.github.io/surveycore/reference/meta.md) to
access metadata.

Other analysis:
[`SE()`](https://jdenn0514.github.io/surveycore/reference/SE.md),
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
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
[`get_variance()`](https://jdenn0514.github.io/surveycore/reference/get_variance.md),
[`meta()`](https://jdenn0514.github.io/surveycore/reference/meta.md)

## Examples

``` r
d <- as_survey(
  gss_2024,
  ids = vpsu,
  weights = wtssps,
  strata = vstrat,
  nest = TRUE
)
fit <- survey_glm(d, age ~ sex)
clean(fit)
#> # A tibble: 2 × 11
#>   term       variable var_label label reference_row estimate std_error statistic
#> * <chr>      <chr>    <chr>     <chr> <lgl>            <dbl>     <dbl>     <dbl>
#> 1 (Intercep… (Interc… NA        (Int… FALSE           47.6       1.54     30.8  
#> 2 sex        sex      responde… resp… FALSE            0.260     0.957     0.271
#> # ℹ 3 more variables: p_value <dbl>, conf_low <dbl>, conf_high <dbl>
clean(fit, conf_level = 0.99, exponentiate = FALSE)
#> # A tibble: 2 × 11
#>   term       variable var_label label reference_row estimate std_error statistic
#> * <chr>      <chr>    <chr>     <chr> <lgl>            <dbl>     <dbl>     <dbl>
#> 1 (Intercep… (Interc… NA        (Int… FALSE           47.6       1.54     30.8  
#> 2 sex        sex      responde… resp… FALSE            0.260     0.957     0.271
#> # ℹ 3 more variables: p_value <dbl>, conf_low <dbl>, conf_high <dbl>
```
