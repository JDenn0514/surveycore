# Design-Based Population Variance for a Survey Design

Compute the design-based estimate of the finite-population variance for
one or more numeric variables in a survey design, with optional
grouping, uncertainty quantification, and metadata-driven labelling.
Matches
[`survey::svyvar()`](https://rdrr.io/pkg/survey/man/surveysummary.html)
numerically (Kish `n/(n-1)` correction) on Taylor, replicate, twophase,
and nonprob designs.

## Usage

``` r
get_variance(
  design,
  x,
  group = NULL,
  variance = "ci",
  conf_level = 0.95,
  n_weighted = FALSE,
  decimals = NULL,
  min_cell_n = 30L,
  na.rm = TRUE,
  na_handling = c("pairwise", "listwise"),
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
  `survey_twophase`, or `survey_nonprob`. Also accepts a
  [`survey_collection`](https://jdenn0514.github.io/surveycore/reference/survey_collection.md).

- x:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  One or more unquoted numeric variable names. Must resolve to at least
  one numeric column; non-numeric columns are rejected (no silent drop).

- group:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Optional grouping variable(s). Combined with any grouping set by
  `group_by()`. Default `NULL`.

- variance:

  `NULL` or a character vector of one or more of `"se"`, `"ci"`,
  `"var"`, `"cv"`, `"moe"`, `"deff"`. Controls which uncertainty columns
  appear in the output. Default `"ci"`.

- conf_level:

  Numeric scalar in (0, 1). Confidence level for intervals. Default
  `0.95`.

- n_weighted:

  Logical. If `TRUE`, add an `n_weighted` column with the sum of weights
  for non-NA, positive-weight observations in each row's estimate.
  Default `FALSE`.

- decimals:

  Integer or `NULL`. If an integer, rounds all numeric output columns to
  this many decimal places. Default `NULL` (no rounding).

- min_cell_n:

  Integer. Minimum unweighted cell count before
  `surveycore_warning_small_cell` fires. Default `30L` (AAPOR guidance).

- na.rm:

  Logical. If `TRUE` (default), `NA` values in the focal variable are
  excluded from the estimate and rows with `NA` in any grouping variable
  are excluded from the output. If `FALSE`, `NA` propagates to produce
  `NaN` estimates.

- na_handling:

  `"pairwise"` (default) or `"listwise"`. In multi-variable mode
  controls whether each focal variable uses its own complete-case set
  (`"pairwise"`) or the intersection across all focal variables
  (`"listwise"`). Ignored when `na.rm = FALSE`.

- label_values:

  Logical. Accepted for API consistency across `get_*()` functions. Used
  to convert grouping-variable codes to value labels. Default `TRUE`.

- label_vars:

  Logical. If `TRUE` (default), the `name` column shows variable labels
  when available (falling back to raw names).

- name_style:

  `"surveycore"` (default) or `"broom"`. Under `"broom"`, renames
  `variance` → `estimate`, `se` → `std.error`, `ci_low` → `conf.low`,
  `ci_high` → `conf.high`.

- ...:

  Unused. Reserved so that `.id` and `.if_missing_var` remain named-only
  when a `survey_collection` is passed as `design`.

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

A `survey_variance` tibble (also inheriting `survey_result`). Columns,
in order:

- `[.id]` — survey identifier column, only when `design` is a
  [`survey_collection`](https://jdenn0514.github.io/surveycore/reference/survey_collection.md).

- `[group_cols...]` — group variable columns (when active), first.

- `name` — focal variable name (or its label when `label_vars = TRUE`).

- `variance` — design-based point estimate of the finite-population
  variance. Note: the column is always named `variance` regardless of
  the `variance` parameter (which controls uncertainty columns, not this
  column). `NaN` for degenerate cells; exact `0` for constant-in-domain
  variables.

- Uncertainty columns (`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`,
  `deff`) — only those requested via the `variance` parameter. The `var`
  uncertainty column is the variance of the estimated variance, distinct
  from the `variance` point estimate column.

- `n` — unweighted count of non-NA observations used.

- `n_weighted` — sum of weights (only when `n_weighted = TRUE`).

## Details

Confidence intervals use the normal-Wald approximation on the SE of the
variance estimate: `ci_low = variance - z * se`,
`ci_high = variance + z * se`, where `z = qnorm((1 + conf_level) / 2)`.
The bounds are **not clamped**. When the true variance is near zero with
wide SE, `ci_low` may be negative. Users who want non-negative lower
bounds can clamp at `0` post-hoc. This behaviour matches
[`survey::svyvar()`](https://rdrr.io/pkg/survey/man/surveysummary.html).

Under `na_handling = "pairwise"` (the default), each focal variable
contributes its own per-variable complete-case count to `n`. Under
`na_handling = "listwise"`, every output row shares the intersection
complete-case count — rows with `NA` in any selected variable are
excluded from every variable's calculation.

## See also

Other analysis:
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
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
[`meta()`](https://jdenn0514.github.io/surveycore/reference/meta.md)

## Examples

``` r
d <- as_survey(
  nhanes_2017,
  ids = sdmvpsu,
  weights = wtint2yr,
  strata = sdmvstra,
  nest = TRUE
)
get_variance(d, ridageyr)
#> # A tibble: 1 × 5
#>   name                      variance ci_low ci_high     n
#>   <chr>                        <dbl>  <dbl>   <dbl> <int>
#> 1 Age in years at screening     515.   497.    534.  9254

# Multiple variables
get_variance(d, c(ridageyr, bpxsy1))
#> # A tibble: 2 × 5
#>   name                                 variance ci_low ci_high     n
#>   <chr>                                   <dbl>  <dbl>   <dbl> <int>
#> 1 Age in years at screening                515.   497.    534.  9254
#> 2 Systolic: Blood pres (1st rdg) mm Hg     316.   296.    336.  6302

# With grouping
get_variance(d, ridageyr, group = riagendr)
#> # A tibble: 2 × 6
#>   riagendr name                      variance ci_low ci_high     n
#>      <dbl> <chr>                        <dbl>  <dbl>   <dbl> <int>
#> 1        1 Age in years at screening     505.   481.    530.  4557
#> 2        2 Age in years at screening     523.   502.    544.  4697
```
