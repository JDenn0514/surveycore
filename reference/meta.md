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
  `"srs"`, or `"calibrated"`.

- `conf_level`:

  Numeric(1). Confidence level used (e.g. `0.95`).

- `call`:

  Language. Matched call to the `get_*()` function.

- `group_names`:

  Character vector. Grouping variable names; `character(0)` if none.

- `group_labels`:

  Named list. Group variable → label; `NULL` values for unlabeled group
  variables.

- `n_respondents`:

  Integer(1). Total rows in the design, regardless of groups, domain
  status, or weights.

- `value_labels`:

  Named list. One key per focal variable; value is a named vector of
  label → raw value mappings, or `NULL` for numeric/unlabelled
  variables.

Additional function-specific fields are described in the Phase 1
specification.

## Details

This is the **only** supported way to access result metadata — do not
use `attr(result, ".meta")` directly.

## See also

Other analysis:
[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md),
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md),
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
    group_names   = character(0),
    group_labels  = list(),
    n_respondents = 100L,
    variable      = "x",
    variable_label   = NULL,
    question_preface = NULL,
    value_labels     = list(x = NULL)
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
