# Survey-Weighted Pearson Correlation

Compute pairwise Pearson correlations between two or more numeric
variables in a survey design, with design-based standard errors and
confidence intervals. Returns results in long or wide format.

## Usage

``` r
get_corr(
  design,
  x,
  format = c("long", "wide"),
  redundant = FALSE,
  diagonal = FALSE,
  variance = "ci",
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
  Two or more unquoted numeric variable names. Non-numeric variables are
  dropped with a warning. At least two numeric variables must remain.

- format:

  `"long"` (default) or `"wide"`. Long format returns one row per
  variable pair with inference statistics. Wide format returns the
  correlation matrix (`r` values only — no variance or inference
  columns).

- redundant:

  Logical. If `FALSE` (default), each pair appears once (lower triangle:
  pairs where var1 precedes var2 in input order). If `TRUE`, both
  `(A, B)` and `(B, A)` are included (full directed pairs). Only affects
  long format; wide format always shows the full symmetric matrix.

- diagonal:

  Logical. If `FALSE` (default), self-correlations are excluded
  (diagonal is `NA` in wide format). If `TRUE`, self-correlations (r
  equals 1) are included.

- variance:

  `NULL` or a character vector of one or more of `"se"`, `"ci"`,
  `"var"`, `"cv"`, `"moe"`, `"deff"`. Default `"ci"`. CI bounds use the
  Fisher Z transform (guaranteeing bounds in (−1, 1)). Only applies to
  long format.

- conf_level:

  Numeric scalar in (0, 1). Default `0.95`.

- n_weighted:

  Logical. If `TRUE`, add an `n_weighted` column with the pairwise sum
  of weights (both variables non-NA). Default `FALSE`.

- min_cell_n:

  Integer. Minimum pairwise unweighted count before
  `surveycore_warning_small_cell` fires. Default `30L` (AAPOR guidance).

- na.rm:

  Logical. If `TRUE` (default), pairs use complete cases for each
  variable pair separately (pairwise deletion).

- label_values:

  Logical. Accepted for API uniformity; has no visible effect. Default
  `TRUE`.

- label_vars:

  Logical. If `TRUE` (default) and variable labels are set in metadata,
  `var1`/`var2` columns (long) and `variable` column (wide) show labels
  instead of raw names. Falls back to raw names if labels are unset.

- name_style:

  `"surveycore"` (default) or `"broom"`. When `"broom"`, renames `r` →
  `estimate`, `se` → `std.error`, etc. Only affects long format.

## Value

A `survey_corr` tibble (also inheriting `survey_result`).

**Long format** columns:

- `var1`, `var2` — variable names (or labels when `label_vars = TRUE`).

- `r` — Pearson correlation coefficient.

- Variance columns (`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`,
  `deff`) — only those requested via `variance`.

- `p_value` — two-tailed p-value.

- `statistic` — t-statistic.

- `df` — degrees of freedom for the t-test (n minus 2).

- `n` — pairwise unweighted count.

- `n_weighted` — pairwise sum of weights (only when requested).

**Wide format** columns:

- `variable` — row variable names (or labels).

- One column per focal variable, containing `r` values.

Use `meta(result)` to access design type, variable labels, and `method`
(`"pearson"`).

## See also

Other analysis:
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md),
[`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md),
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
[`meta()`](https://jdenn0514.github.io/surveycore/reference/meta.md)

## Examples

``` r
d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
               strata = sdmvstra, nest = TRUE)
get_corr(d, x = c(ridageyr, bpxsy1))
#> # A tibble: 1 × 9
#>   var1                  var2      r ci_low ci_high p_value statistic    df     n
#>   <chr>                 <chr> <dbl>  <dbl>   <dbl>   <dbl>     <dbl> <int> <int>
#> 1 Age in years at scre… Syst… 0.544  0.529   0.559       0      51.5  6300  6302

# Wide correlation matrix
get_corr(d, x = c(ridageyr, bpxsy1), format = "wide")
#> # A tibble: 2 × 3
#>   variable                         Age in years at scre…¹ Systolic: Blood pres…²
#>   <chr>                                             <dbl>                  <dbl>
#> 1 Age in years at screening                        NA                      0.544
#> 2 Systolic: Blood pres (1st rdg) …                  0.544                 NA    
#> # ℹ abbreviated names: ¹​`Age in years at screening`,
#> #   ²​`Systolic: Blood pres (1st rdg) mm Hg`

# AAPOR-compliant
get_corr(d, x = c(ridageyr, bpxsy1),
         variance = c("ci", "moe"), n_weighted = TRUE)
#> # A tibble: 1 × 11
#>   var1           var2      r ci_low ci_high    moe p_value statistic    df     n
#>   <chr>          <chr> <dbl>  <dbl>   <dbl>  <dbl>   <dbl>     <dbl> <int> <int>
#> 1 Age in years … Syst… 0.544  0.529   0.559 0.0151       0      51.5  6300  6302
#> # ℹ 1 more variable: n_weighted <dbl>
```
