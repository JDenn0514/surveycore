# Effective Sample Size for a Survey Design

Computes the effective sample size of a survey design using either the
Kish (1965) weight-only approximation (`method = "kish"`) or the full
design-effect-based formula for a specified variable
(`method = "deff"`).

## Usage

``` r
get_effective_n(
  design,
  x = NULL,
  group = NULL,
  method = c("kish", "deff"),
  na.rm = TRUE,
  decimals = NULL,
  min_cell_n = 30L,
  ...,
  .id = NULL,
  .if_missing_var = NULL
)
```

## Arguments

- design:

  A survey design object: `survey_taylor`, `survey_replicate`,
  `survey_twophase`, `survey_nonprob`, or a `survey_collection`.

- x:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  A single unquoted numeric variable name. Required when
  `method = "deff"`; ignored (with a message) when `method = "kish"`.
  Default `NULL`.

- group:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Optional grouping variable(s). Combined with any grouping set by
  `group_by()`. Default `NULL`.

- method:

  Character(1). `"kish"` (default) or `"deff"`. Controls the effective-N
  formula. Matched via
  [`match.arg()`](https://rdrr.io/r/base/match.arg.html).

- na.rm:

  Logical. If `TRUE` (default), exclude observations with `NA` weights
  or group variables from the Kish computation; passed to
  [`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md)
  for the DEFF computation.

- decimals:

  Integer or `NULL`. Rounds `n_eff` and deff columns to this many
  decimal places. `n` is always integer and is never rounded. Default
  `NULL`.

- min_cell_n:

  Integer. Minimum unweighted cell count before
  `surveycore_warning_small_cell` fires (Kish method only). Default
  `30L`.

- ...:

  Unused. Reserved so that `.id` and `.if_missing_var` remain named-only
  when a `survey_collection` is passed.

- .id:

  Character(1) or `NULL`. Column name identifying each survey in a
  `survey_collection`. Default `NULL` (uses the collection's stored
  `@id`).

- .if_missing_var:

  `"error"`, `"skip"`, or `NULL`. Handling for surveys in a collection
  that lack `x`. Default `NULL`.

## Value

A `survey_effective_n` tibble (also inheriting `survey_result`).
Columns, in order:

- `[.id]` — survey identifier column (when `design` is a collection).

- `[group_cols...]` — group variable columns (when grouping is active).

- `n` — integer. Unweighted count of observations.

- `n_eff` — numeric. Effective sample size.

- `deff_kish` — numeric. Weight-based design effect (`n / n_eff`).
  Present when `method = "kish"` only.

- `deff` — numeric. Full design effect (`Var_design / Var_SRS`). Present
  when `method = "deff"` only.

Use `meta(result)$method` to retrieve the formula used. For DEFF,
`meta(result)$x` is a named list with variable metadata.

## Details

The **Kish method** (`method = "kish"`) computes effective N from survey
weights alone: `n_eff = (Σw)² / Σw²`. It captures only weight variation.
For clustered designs with equal weights, `deff_kish = 1.0` even when
the true design effect is substantially greater due to clustering. Use
`method = "deff"` to capture the full design effect for a specific
analysis variable.

The **DEFF method** (`method = "deff"`) computes effective N as
`n_eff = n / DEFF`, where `DEFF = Var_design / Var_SRS` for variable
`x`. It captures clustering, stratification, and weight variation
jointly.

## See also

Other analysis:
[`clean()`](https://jdenn0514.github.io/surveycore/reference/clean.md),
[`get_anova()`](https://jdenn0514.github.io/surveycore/reference/get_anova.md),
[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md),
[`get_covariance()`](https://jdenn0514.github.io/surveycore/reference/get_covariance.md),
[`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md),
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
d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
               strata = sdmvstra, nest = TRUE)

# Kish effective N (weight-only approximation)
get_effective_n(d)
#> # A tibble: 1 × 3
#>       n n_eff deff_kish
#>   <int> <dbl>     <dbl>
#> 1  9254 3820.      2.42

# Full DEFF effective N for a specific variable
get_effective_n(d, ridageyr, method = "deff")
#> # A tibble: 1 × 3
#>       n n_eff  deff
#>   <int> <dbl> <dbl>
#> 1  9254 2425.  3.82
```
