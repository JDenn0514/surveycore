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
[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md),
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md),
[`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md),
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
[`meta()`](https://jdenn0514.github.io/surveycore/reference/meta.md)
