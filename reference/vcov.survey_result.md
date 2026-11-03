# Extract variance-covariance matrix from a survey result object

Returns a named numeric matrix from a `survey_result` object: the
covariance matrix of the estimates in `coef(object)`, with the
per-estimate variances on the diagonal.

## Usage

``` r
# S3 method for class 'survey_result'
vcov(object, ...)
```

## Arguments

- object:

  A `survey_result` object from any supported `get_*()` function.

- ...:

  Unused.

## Value

A `p × p` numeric matrix with `rownames` and `colnames` equal to
`names(coef(object))`.

## Details

For
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md)
and
[`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md)
on a Taylor or replicate design (including a `survey_nonprob` design
with replicate weights), the full covariance matrix is computed when the
result is built and stored with it. It covers every pair of rows: two
levels of one variable, the same level in two groups, and rows on a
filtered design. It is the same matrix `survey::vcov()` returns for
[`survey::svymean()`](https://rdrr.io/pkg/survey/man/surveysummary.html),
[`survey::svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html),
[`survey::svyratio()`](https://rdrr.io/pkg/survey/man/svyratio.html) or
`survey::svyby(covmat = TRUE)`. Two complementary proportions, for
example, have covariance `-var`. The stored matrix is read by name, so
[`vcov()`](https://rdrr.io/r/stats/vcov.html) still returns the right
block after the result's rows are filtered or reordered, and it does not
need an `se` column.

Every other result holds no joint covariance.
[`vcov()`](https://rdrr.io/r/stats/vcov.html) then returns the
per-estimate variances (`se^2`) on the diagonal and `NA_real_` off it,
and emits `surveycore_warning_vcov_incomplete` when `p > 1`. These are
results from
[`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md),
[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md),
[`get_covariance()`](https://jdenn0514.github.io/surveycore/reference/get_covariance.md)
and
[`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md);
the four functions above on a two-phase design or on a `survey_nonprob`
design without replicate weights; and a stored matrix that no longer
matches the result's rows. When the `se` column is absent as well, the
matrix is all `NA_real_`, with no warning.

## Examples

``` r
d_sex <- as_survey(
  transform(nhanes_2017, sex = factor(riagendr, 1:2, c("Male", "Female"))),
  ids = sdmvpsu,
  weights = wtint2yr,
  strata = sdmvstra,
  nest = TRUE
)
# Two complementary proportions: the covariance is -var
vcov(get_freqs(d_sex, sex))
#>                 sex.Male    sex.Female
#> sex.Male    6.137735e-05 -6.137735e-05
#> sex.Female -6.137735e-05  6.137735e-05

# Means by group: the groups share PSUs, so they covary
vcov(get_means(d_sex, ridageyr, group = sex))
#>                 Male:ridageyr Female:ridageyr
#> Male:ridageyr       0.2432529       0.2332761
#> Female:ridageyr     0.2332761       0.3505437
```
