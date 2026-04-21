# Extract Metadata from a Survey Result

Retrieves the structured metadata list attached to a survey result
object returned by any `get_*()` analysis function.

## Usage

``` r
meta(x, ...)

# S3 method for class 'survey_result'
meta(x, ...)
```

## Arguments

- x:

  A `survey_result` object returned by any `get_*()` function.

- ...:

  Currently unused. Reserved for future extensions.

## Value

A named list. Common fields present on every result:

- `design_type`:

  Character(1). Design class: `"taylor"`, `"replicate"`, `"twophase"`,
  `"srs"`, or `"nonprob"`.

- `conf_level`:

  Numeric(1). Confidence level used (e.g. `0.95`).

- `call`:

  Language. Matched call to the `get_*()` function.

- `n_respondents`:

  Integer(1). Total rows in the design, regardless of groups, domain
  status, or weights.

- `group`:

  Named list. One entry per grouping variable; empty list
  ([`list()`](https://rdrr.io/r/base/list.html)) when no groups are
  active. Each entry is a named list with: `variable_label` (character
  or `NULL`), `question_preface` (character or `NULL`), `value_labels`
  (named vector or `NULL`).

- `x`:

  Named list. One entry per focal variable. Length 1 for single-x
  functions (`get_means`, `get_totals`, `get_quantiles`); length N for
  multi-x functions (`get_freqs`, `get_corr`). Each entry has the same
  sub-structure as `group` entries. `NULL` for
  [`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md)
  when called without an `x` argument.

Function-specific additional fields:

- `probs`:

  (`get_quantiles` only) Numeric vector of quantile probabilities.

- `method`:

  (`get_corr` only) Character(1) correlation method.

- `numerator`, `denominator`:

  (`get_ratios` only) Flat named lists with keys `name`,
  `variable_label`, `question_preface`, `value_labels`.

## Details

This is the **only** supported way to access result metadata — do not
use `attr(result, ".meta")` directly.

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
[`get_t_test()`](https://jdenn0514.github.io/surveycore/reference/get_t_test.md),
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md)

## Examples

``` r
# Construct a minimal survey_result to illustrate meta():
result <- structure(
  tibble::tibble(mean = 42.0, se = 1.5, n = 100L),
  .meta = list(
    design_type   = "taylor",
    conf_level    = 0.95,
    call          = quote(get_means(d, x)),
    n_respondents = 100L,
    group         = list(),
    x             = list(
      x = list(variable_label = NULL, question_preface = NULL,
               value_labels = NULL)
    )
  ),
  class = c("survey_means", "survey_result", "tbl_df", "tbl", "data.frame")
)
meta(result)$design_type    # "taylor"
#> [1] "taylor"
meta(result)$n_respondents  # 100L
#> [1] 100
meta(result)$conf_level     # 0.95
#> [1] 0.95
```
