# Weighted Frequency Tables for Categorical Survey Variables

Compute weighted proportions (percentages) for one or more categorical
variables in a survey design, with optional grouping, uncertainty
quantification, and metadata-driven labelling.

## Usage

``` r
get_freqs(
  design,
  x,
  ...,
  group = NULL,
  names_to = "name",
  values_to = "value",
  variance = NULL,
  conf_level = 0.95,
  n_weighted = FALSE,
  min_cell_n = 30L,
  na.rm = TRUE,
  label_values = TRUE,
  label_vars = TRUE,
  name_style = "surveycore"
)
```

## Arguments

- design:

  A survey design object: `survey_taylor`, `survey_replicate`,
  `survey_twophase`, `survey_srs`, or `survey_calibrated`.

- x:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  One or more categorical variables. Bare names or tidy-select helpers
  (e.g., `c(q1, q2, q3)`). When two or more variables are selected,
  multi-variable stacking mode is activated (see Details).

- ...:

  Additional arguments passed to tidy-select (future-proof; currently
  unused).

- group:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Optional grouping variable(s). Combined with any grouping set by
  `group_by()`. Default `NULL`.

- names_to:

  Character(1). Column name for the variable identifier in
  multi-variable mode. Default `"name"`.

- values_to:

  Character(1). Column name for the response value in multi-variable
  mode. Default `"value"`.

- variance:

  `NULL` or a character vector of one or more of `"se"`, `"ci"`,
  `"var"`, `"cv"`, `"moe"`, `"deff"`. Controls which uncertainty columns
  appear in the output. Default `NULL` (no uncertainty columns).

- conf_level:

  Numeric scalar in (0, 1). Confidence level for intervals. Default
  `0.95`.

- n_weighted:

  Logical. If `TRUE`, add an `n_weighted` column with the sum of weights
  (estimated population count) per cell. Default `FALSE`.

- min_cell_n:

  Integer. Minimum unweighted cell count before
  `surveycore_warning_small_cell` fires. Default `30L` (AAPOR guidance).

- na.rm:

  Logical. If `TRUE` (default), `NA` values are excluded from all
  proportions; `NA` does not appear as a level. If `FALSE`, `NA` appears
  as its own last row and the denominator includes `NA` rows.

- label_values:

  Logical. If `TRUE` (default), convert raw variable values to labels
  using metadata or `haven` attributes. Falls back to raw values when no
  labels exist.

- label_vars:

  Logical. If `TRUE` (default), use variable labels from metadata in the
  `names_to` column (multi-variable mode only). Falls back to the raw
  variable name when no label is set.

- name_style:

  `"surveycore"` (default) or `"broom"`. When `"broom"`, renames `pct` →
  `estimate`, `se` → `std.error`, etc.

## Value

A `survey_freqs` tibble (also inheriting `survey_result`). Columns:

- `[group_cols...]` — group variable columns (when active), first.

- `[variable_name]` (single) or `[names_to]` + `[values_to]` (multi).

- `pct` — weighted proportion as a percentage (0–100).

- Variance columns (`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`,
  `deff`) — only those requested via `variance`.

- `n` — unweighted cell count (sample basis of each estimate).

- `n_weighted` — estimated population count (only when requested).

Use `meta(result)` to access design type, variable labels, value labels,
and other metadata.

## Details

**Single-variable mode** (when `x` resolves to exactly one variable):
The focal variable name becomes the first column. Rows follow the factor
level order (if the variable is a factor) or ascending sort order
otherwise.

**Multi-variable mode** (when `x` resolves to two or more variables):
Results are stacked in long format. The `names_to` column contains the
variable label (when `label_vars = TRUE`) or the raw variable name as
fallback. The `values_to` column contains the response values.

**Domain estimation:** Proportions use the ratio linearization approach,
equivalent to
[`survey::svymean()`](https://rdrr.io/pkg/survey/man/surveysummary.html)
on a binary indicator within the active domain. The full design
structure is used for variance estimation — rows are not physically
removed for domain/group subsets.

**`na.rm = FALSE`:** `NA` is appended as the last level. All proportions
(including non-`NA` levels) have their denominator inflated to include
`NA` rows, so the `pct` column sums to 100.

## See also

Other analysis:
[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md),
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md),
[`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md),
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
[`meta()`](https://jdenn0514.github.io/surveycore/reference/meta.md)

## Examples

``` r
# NHANES exam weights are 0 for non-examined participants; filter first
nhanes_sub <- nhanes_2017[nhanes_2017$wtmec2yr > 0, ]
d <- as_survey(nhanes_sub, ids = sdmvpsu, weights = wtmec2yr,
               strata = sdmvstra, nest = TRUE)

# Single variable
get_freqs(d, riagendr)
#> # A tibble: 2 × 3
#>   riagendr   pct     n
#>   <chr>    <dbl> <int>
#> 1 1         48.9  4273
#> 2 2         51.1  4431

# With confidence intervals
get_freqs(d, riagendr, variance = "ci")
#> # A tibble: 2 × 5
#>   riagendr   pct ci_low ci_high     n
#>   <chr>    <dbl>  <dbl>   <dbl> <int>
#> 1 1         48.9   47.4    50.4  4273
#> 2 2         51.1   49.6    52.6  4431

# Grouped
get_freqs(d, riagendr, group = sdmvstra)
#> # A tibble: 30 × 4
#>    sdmvstra riagendr   pct     n
#>       <dbl> <chr>    <dbl> <int>
#>  1      134 1         45.0   217
#>  2      134 2         55.0   253
#>  3      135 1         47.6   277
#>  4      135 2         52.4   324
#>  5      136 1         47.7   321
#>  6      136 2         52.3   332
#>  7      137 1         47.0   250
#>  8      137 2         53.0   273
#>  9      138 1         49.0   274
#> 10      138 2         51.0   295
#> # ℹ 20 more rows

# Multi-variable (stacked)
get_freqs(d, c(riagendr, ridreth3), names_to = "item", values_to = "value")
#> # A tibble: 8 × 4
#>   item     value   pct     n
#>   <chr>    <chr> <dbl> <int>
#> 1 riagendr 1     48.9   4273
#> 2 riagendr 2     51.1   4431
#> 3 ridreth3 1     10.8   1298
#> 4 ridreth3 2      7.27   773
#> 5 ridreth3 3     59.1   2931
#> 6 ridreth3 4     11.8   2010
#> 7 ridreth3 6      5.59  1086
#> 8 ridreth3 7      5.32   606
```
