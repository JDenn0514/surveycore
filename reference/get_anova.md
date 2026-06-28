# Design-Based Analysis of Variance and Wald Tests for Survey GLM Fits

Rao-Scott design-based ANOVA and design-based Wald tests for
[`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md)
fits. Accepts three input shapes on `object`:

## Usage

``` r
get_anova(
  object,
  formula = NULL,
  response = NULL,
  predictors = NULL,
  ...,
  method = c("LRT", "Wald"),
  test = c("F", "Chisq"),
  null = NULL,
  tolerance = sqrt(.Machine$double.eps),
  decimals = NULL,
  label_vars = TRUE,
  name_style = "surveycore"
)
```

## Arguments

- object:

  A
  [survey_glm_fit](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md),
  a list of
  [survey_glm_fit](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md)
  objects, or a survey design
  ([survey_base](https://jdenn0514.github.io/surveycore/reference/survey_base.md)
  subclass).

- formula:

  A model formula (e.g. `y ~ x1 + x2`). Only used when `object` is a
  survey design. Passed through to
  [`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md);
  supplying `formula` alongside `response` / `predictors` is rejected by
  [`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md)'s
  validator.

- response:

  Character string naming the outcome variable. Only used when `object`
  is a survey design. Forwarded to
  [`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md).

- predictors:

  Character vector of predictor variable names. Only used when `object`
  is a survey design. Forwarded to
  [`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md).

- ...:

  Additional arguments forwarded to
  [`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md)
  when `object` is a survey design (e.g. `family`, `na.action`,
  `quiet`). For fit or list inputs, `...` must be empty — any extras
  error via
  [`rlang::check_dots_empty()`](https://rlang.r-lib.org/reference/check_dots_empty.html)
  with fuzzy typo detection.

- method:

  Character(1). `"LRT"` (default) or `"Wald"`.

- test:

  Character(1). `"F"` (default) or `"Chisq"` reference distribution.

- null:

  Numeric or `NULL`. Hypothesized value for the tested coefficients
  (Wald only). Only used when `object` is a single
  [survey_glm_fit](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md)
  or a survey design (reducing to single-model mode); ignored with
  warning `surveycore_warning_anova_null_ignored` when `object` is a
  list of fits.

- tolerance:

  Numeric(1). Reciprocal-condition-number threshold for the
  naive-covariance near-singular gate in the Rao-Scott LRT. Default
  `sqrt(.Machine$double.eps)`.

- decimals:

  Integer(1) or `NULL`. Round double output columns.

- label_vars:

  Logical(1). When `TRUE`, compose term-row labels from
  `@metadata@variable_labels` for the `term` column. Default `TRUE`.

- name_style:

  Character(1). `"surveycore"` (default) or `"broom"`.

## Value

A `survey_anova` tibble with columns `term`, `statistic`, `df`, `ddf`,
`deff`, `p_value`, `stars` and a `.meta` attribute. When
`name_style = "broom"`, `p_value` is renamed to `p.value` and `ddf` is
renamed to `df.residual`.

## Details

- A single
  [survey_glm_fit](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md)
  — sequential mode, one row per term.

- A list of
  [survey_glm_fit](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md)
  objects — chained pairwise comparison, producing `length(object) - 1`
  rows.

- A survey design (any
  [survey_base](https://jdenn0514.github.io/surveycore/reference/survey_base.md)
  subclass) — fits the model internally via
  [`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md)
  using `formula` (or `response` + `predictors`), then runs sequential
  anova on the fit.

Supports the four method x test combinations shared with
[`survey::anova.svyglm()`](https://rdrr.io/pkg/survey/man/anova.svyglm.html):
Rao-Scott working-LRT with F or Chisq reference, and design-based Wald
with F or Chisq reference.

## See also

Other analysis:
[`SE()`](https://jdenn0514.github.io/surveycore/reference/SE.md),
[`clean()`](https://jdenn0514.github.io/surveycore/reference/clean.md),
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
gss_cc <- gss_2024[stats::complete.cases(gss_2024[, c("age", "sex", "educ")]), ]
gss_design <- as_survey(
  gss_cc,
  ids = vpsu,
  weights = wtssps,
  strata = vstrat,
  nest = TRUE
)

# Single fit
fit <- survey_glm(gss_design, age ~ sex + educ)
get_anova(fit)
#> # A tibble: 2 × 7
#>   term  statistic    df   ddf  deff p_value stars
#>   <chr>     <dbl> <dbl> <dbl> <dbl>   <dbl> <chr>
#> 1 sex        52.2     1    66  734.  0.784  ""   
#> 2 educ     4521.      1    65  700.  0.0141 "*"  

# Design + formula (fits internally)
get_anova(gss_design, age ~ sex + educ)
#> # A tibble: 2 × 7
#>   term  statistic    df   ddf  deff p_value stars
#>   <chr>     <dbl> <dbl> <dbl> <dbl>   <dbl> <chr>
#> 1 sex        52.2     1    66  734.  0.784  ""   
#> 2 educ     4521.      1    65  700.  0.0141 "*"  

# List of fits (chained pairwise comparison)
fit_s <- survey_glm(gss_design, age ~ sex)
fit_b <- survey_glm(gss_design, age ~ sex + educ)
get_anova(list(fit_s, fit_b))
#> # A tibble: 1 × 7
#>   term       statistic    df   ddf  deff p_value stars
#>   <chr>          <dbl> <dbl> <dbl> <dbl>   <dbl> <chr>
#> 1 educ | sex     4521.     1    65  700.  0.0141 *    
```
