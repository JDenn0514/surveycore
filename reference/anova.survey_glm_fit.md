# ANOVA Method for Survey GLM Fits

S3 method that dispatches to
[`get_anova()`](https://jdenn0514.github.io/surveycore/reference/get_anova.md).
Pass one or two
[survey_glm_fit](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md)
objects; the single-model or pairwise path is chosen automatically.

## Usage

``` r
# S3 method for class 'survey_glm_fit'
anova(object, ..., method = "LRT", test = "F", null = NULL)
```

## Arguments

- object:

  A
  [survey_glm_fit](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md)
  object.

- ...:

  An optional second
  [survey_glm_fit](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md)
  for pairwise comparison; anything else errors.

- method:

  Character(1). `"LRT"` (default) or `"Wald"`.

- test:

  Character(1). `"F"` (default) or `"Chisq"`.

- null:

  Numeric or `NULL`. Hypothesized coefficient value (Wald only).

## Value

A `survey_anova` tibble; see
[`get_anova()`](https://jdenn0514.github.io/surveycore/reference/get_anova.md)
for column details.
