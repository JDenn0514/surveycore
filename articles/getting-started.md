# Getting Started with surveycore

surveycore gives you a complete workflow for survey data analysis:
design objects that encode how your data were collected, analysis
functions that apply those designs when computing estimates, and a
tidyverse-compatible interface that plugs into familiar tools.

This vignette is a practical walkthrough — data to estimates in as few
steps as possible. We will use `nhanes_2017`, a stratified probability
cluster sample, as our running example throughout.

For a deep dive on *creating* survey design objects — choosing the right
constructor, handling replicate weights, two-phase designs, and
non-probability panels — see
[`vignette("creating-survey-objects")`](https://jdenn0514.github.io/surveycore/articles/creating-survey-objects.md).

------------------------------------------------------------------------

## 1. Create a survey design

Every analysis function takes a **survey design object** as its first
argument. The design object captures how the data were collected so that
point estimates and standard errors are computed correctly.

``` r
# NHANES: stratified cluster design using Taylor series linearization.
# Subset to MEC exam participants before using the exam weight (wtmec2yr).
nhanes_exam <- nhanes_2017[nhanes_2017$ridstatr == 2, ]

svy <- as_survey(
  nhanes_exam,
  ids     = sdmvpsu,   # cluster ID
  strata  = sdmvstra,  # stratum
  weights = wtmec2yr,  # examination weight
  nest    = TRUE       # PSU IDs are locally unique within strata
)
svy
```

    #> 

    #> ── Survey Design ───────────────────────────────────────────────────────────────

    #> <survey_taylor> (Taylor series linearization)

    #> Sample size: 8704

    #> 

    #> # A tibble: 8,704 × 14
    #>     seqn sdmvpsu sdmvstra wtmec2yr wtint2yr ridstatr riagendr ridageyr ridreth3
    #>    <dbl>   <dbl>    <dbl>    <dbl>    <dbl>    <dbl>    <dbl>    <dbl>    <dbl>
    #>  1 93703       2      145    8540.    9246.        2        2        2        6
    #>  2 93704       1      143   42567.   37339.        2        1        2        3
    #>  3 93705       2      145    8338.    8615.        2        2       66        4
    #>  4 93706       2      134    8723.    8549.        2        1       18        6
    #>  5 93707       1      138    7065.    6769.        2        1       13        7
    #>  6 93708       2      138   14372.   13329.        2        2       66        6
    #>  7 93709       1      136   12278.   12043.        2        2       75        4
    #>  8 93710       1      134   16848.   16418.        2        2        0        3
    #>  9 93711       2      134   12391.   11178.        2        1       56        6
    #> 10 93712       2      147   30337.   29040.        2        1       18        1
    #> # ℹ 8,694 more rows
    #> # ℹ 5 more variables: indfmpir <dbl>, dmdeduc2 <dbl>, bpxsy1 <dbl>,
    #> #   bpxdi1 <dbl>, bpxpls <dbl>

[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
is the right constructor for probability surveys with cluster and
stratum information. `nest = TRUE` is needed here because NHANES assigns
PSU IDs (1 and 2) locally within each stratum, not globally across the
dataset. Use
[`vignette("creating-survey-objects")`](https://jdenn0514.github.io/surveycore/articles/creating-survey-objects.md)
to find the right constructor for your survey.

------------------------------------------------------------------------

## 2. Frequency tables — `get_freqs()`

[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md)
estimates the weighted distribution of one or more categorical
variables. Pass a bare column name as the second argument.

``` r
# Distribution of sex (1 = Male, 2 = Female)
get_freqs(svy, riagendr)
```

    #> # A tibble: 2 × 3
    #>   riagendr   pct     n
    #>   <chr>    <dbl> <int>
    #> 1 1         48.9  4273
    #> 2 2         51.1  4431

The result is a `survey_freqs` tibble. `pct` is the survey-weighted
percentage; `n` is the unweighted cell count.

### Confidence intervals and margins of error

Add uncertainty columns with the `variance` argument. Any combination of
`"se"`, `"ci"`, `"moe"`, `"var"`, `"cv"`, or `"deff"` is supported.

``` r
get_freqs(svy, riagendr, variance = c("ci", "moe"))
```

    #> # A tibble: 2 × 6
    #>   riagendr   pct ci_low ci_high   moe     n
    #>   <chr>    <dbl>  <dbl>   <dbl> <dbl> <int>
    #> 1 1         48.9   47.4    50.4  1.51  4273
    #> 2 2         51.1   49.6    52.6  1.51  4431

`ci_low` / `ci_high` are 95% Wilson-score confidence interval bounds.
`moe` is the margin of error at the specified confidence level
($\pm {MOE}$ gives the half-width of the CI).

### Multiple variables at once

Pass a [`c()`](https://rdrr.io/r/base/c.html) of variable names to get a
stacked long-format frequency table.

``` r
# Race/ethnicity (ridreth3) and sex (riagendr) in one call
get_freqs(svy, c(riagendr, ridreth3))
```

    #> # A tibble: 8 × 4
    #>   name     value   pct     n
    #>   <chr>    <chr> <dbl> <int>
    #> 1 riagendr 1     48.9   4273
    #> 2 riagendr 2     51.1   4431
    #> 3 ridreth3 1     10.8   1298
    #> 4 ridreth3 2      7.27   773
    #> 5 ridreth3 3     59.1   2931
    #> 6 ridreth3 4     11.8   2010
    #> 7 ridreth3 6      5.59  1086
    #> 8 ridreth3 7      5.32   606

The `name` column identifies which variable each row belongs to; `value`
holds the response code.

### Including `NA` as a level

By default `na.rm = TRUE` drops missing values before computing
percentages. Set `na.rm = FALSE` to include `NA` as a level:

``` r
get_freqs(svy, dmdeduc2, na.rm = FALSE)
```

    #> Warning: ! 2 cells have fewer than 30 unweighted observations. Estimates in these cells
    #>   may be unreliable for public reporting (AAPOR guidance).

    #> # A tibble: 8 × 3
    #>   dmdeduc2      pct     n
    #>   <chr>       <dbl> <int>
    #> 1 1         2.85      454
    #> 2 2         5.57      598
    #> 3 3        20.2      1251
    #> 4 4        22.8      1689
    #> 5 5        22.9      1261
    #> 6 7         0.00917     2
    #> 7 9         0.0773     10
    #> 8 NA       25.6      3439

------------------------------------------------------------------------

## 3. Weighted means — `get_means()`

[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md)
estimates the survey-weighted mean of a continuous variable.

``` r
# Mean systolic blood pressure
get_means(svy, bpxsy1)
```

    #> # A tibble: 1 × 4
    #>    mean ci_low ci_high     n
    #>   <dbl>  <dbl>   <dbl> <int>
    #> 1  120.   120.    121.  6302

The default output includes the mean and 95% confidence interval. Supply
`variance = "se"` to replace the CI with a standard error, or combine
options:

``` r
get_means(svy, bpxsy1, variance = c("se", "ci", "deff"))
```

    #> # A tibble: 1 × 6
    #>    mean    se ci_low ci_high  deff     n
    #>   <dbl> <dbl>  <dbl>   <dbl> <dbl> <int>
    #> 1  120. 0.365   120.    121.  2.10  6302

`deff` is the design effect — the ratio of the complex-design variance
to the variance under simple random sampling. Values above 1 indicate
that clustering and/or stratification inflates sampling uncertainty
compared to SRS.

------------------------------------------------------------------------

## 4. Population totals — `get_totals()`

[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md)
estimates the weighted sum: the total count or aggregate for the target
population.

### Population size

Called without a variable argument,
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md)
estimates the total number of persons (or units) the sample represents —
the sum of the survey weights.

``` r
# Estimated U.S. civilian non-institutionalized population, 2017-2018 (exam)
get_totals(svy)
```

    #> # A tibble: 1 × 3
    #>       total     ci_low    ci_high
    #>       <dbl>      <dbl>      <dbl>
    #> 1 320842721 300192596. 341492846.

### Variable total

Pass a numeric column to estimate its population total.

``` r
# Estimated total pulse (bpxpls) across the population
get_totals(svy, bpxpls)
```

    #> # A tibble: 1 × 4
    #>          total       ci_low      ci_high     n
    #>          <dbl>        <dbl>        <dbl> <int>
    #> 1 20275645692. 19075596836. 21475694549.  6742

------------------------------------------------------------------------

## 5. Subgroup analysis — the `group` argument

Every analysis function accepts a `group` argument for computing
estimates separately within levels of a categorical variable. Pass a
bare column name or a [`c()`](https://rdrr.io/r/base/c.html) of names.

``` r
# Mean systolic blood pressure by sex
get_means(svy, bpxsy1, group = riagendr)
```

    #> # A tibble: 2 × 5
    #>   riagendr  mean ci_low ci_high     n
    #>      <dbl> <dbl>  <dbl>   <dbl> <int>
    #> 1        1  121.   121.    122.  3115
    #> 2        2  119.   118.    120.  3187

``` r
# Population size by race/ethnicity
get_totals(svy, group = ridreth3)
```

    #> # A tibble: 6 × 4
    #>   ridreth3      total     ci_low    ci_high
    #>      <dbl>      <dbl>      <dbl>      <dbl>
    #> 1        1  34787759.  22114139.  47461380.
    #> 2        2  23322412.  18175497.  28469327.
    #> 3        3 189718187. 166510918. 212925457.
    #> 4        4  38011815.  28725817.  47297812.
    #> 5        6  17938340.  12250021.  23626658.
    #> 6        7  17064208.  13886844.  20241572.

``` r
# Education distribution by sex
get_freqs(svy, dmdeduc2, group = riagendr)
```

    #> Warning: ! 3 cells have fewer than 30 unweighted observations. Estimates in these cells
    #>   may be unreliable for public reporting (AAPOR guidance).

    #> # A tibble: 14 × 4
    #>    riagendr dmdeduc2     pct     n
    #>       <dbl> <chr>      <dbl> <int>
    #>  1        1 1         3.95     223
    #>  2        1 2         7.97     322
    #>  3        1 3        28.4      633
    #>  4        1 4        29.5      757
    #>  5        1 5        30.1      601
    #>  6        1 7         0          0
    #>  7        1 9         0.0867     5
    #>  8        2 1         3.72     231
    #>  9        2 2         7.04     276
    #> 10        2 3        25.9      618
    #> 11        2 4        31.7      932
    #> 12        2 5        31.5      660
    #> 13        2 7         0.0238     2
    #> 14        2 9         0.120      5

Rows where the grouping variable is `NA` are excluded from all groups
and do not appear in the output. Responses within each group sum to 100%
for
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md).

------------------------------------------------------------------------

## 6. Ratio estimation — `get_ratios()`

[`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md)
estimates the ratio of two weighted totals:

$$\widehat{R} = \frac{\sum\limits_{i}w_{i}\, y_{i}}{\sum\limits_{i}w_{i}\, x_{i}}$$

Variance is estimated via the delta method (linearization), equivalent
to [`survey::svyratio()`](https://rdrr.io/pkg/survey/man/svyratio.html)
([Lumley 2010](#ref-lumley2010)).

``` r
# Ratio of systolic to diastolic blood pressure
get_ratios(svy, numerator = bpxsy1, denominator = bpxdi1)
```

    #> # A tibble: 1 × 4
    #>   ratio ci_low ci_high     n
    #>   <dbl>  <dbl>   <dbl> <int>
    #> 1  1.74   1.71    1.76  6302

Ratios are useful when you want an estimate that is invariant to the
scale of the weights — for example, wages per hour, spending per
household member, or disease prevalence ratios.

``` r
# Systolic/diastolic ratio by sex
get_ratios(svy, bpxsy1, bpxdi1, group = riagendr)
```

    #> # A tibble: 2 × 5
    #>   riagendr ratio ci_low ci_high     n
    #>      <dbl> <dbl>  <dbl>   <dbl> <int>
    #> 1        1  1.72   1.69    1.75  3115
    #> 2        2  1.75   1.73    1.78  3187

------------------------------------------------------------------------

## 7. Weighted correlations — `get_corr()`

[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md)
estimates survey-weighted Pearson correlations between two or more
continuous variables. Confidence intervals use the Fisher Z
transformation, guaranteeing bounds in (−1, 1).

``` r
# Correlation between systolic BP and diastolic BP
get_corr(svy, c(bpxsy1, bpxdi1))
```

    #> # A tibble: 1 × 9
    #>   var1   var2       r ci_low ci_high   p_value statistic    df     n
    #>   <chr>  <chr>  <dbl>  <dbl>   <dbl>     <dbl>     <dbl> <int> <int>
    #> 1 bpxsy1 bpxdi1 0.441  0.415   0.467 1.46e-298      39.0  6300  6302

Pass three or more variables for a pairwise correlation matrix in long
format:

``` r
get_corr(svy, c(bpxsy1, bpxdi1, bpxpls))
```

    #> # A tibble: 3 × 9
    #>   var1   var2         r  ci_low   ci_high   p_value statistic    df     n
    #>   <chr>  <chr>    <dbl>   <dbl>     <dbl>     <dbl>     <dbl> <int> <int>
    #> 1 bpxsy1 bpxdi1  0.441   0.415   0.467    1.46e-298     39.0   6300  6302
    #> 2 bpxsy1 bpxpls -0.122  -0.156  -0.0868   3.46e- 22     -9.72  6300  6302
    #> 3 bpxdi1 bpxpls -0.0277 -0.0555  0.000135 2.77e-  2     -2.20  6300  6302

Each row is a unique variable pair. `r` is the weighted correlation,
`p_value` is from a two-tailed t-test, and `df = n - 2` are the degrees
of freedom.

Switch to wide format for a more familiar correlation-matrix layout:

``` r
get_corr(svy, c(bpxsy1, bpxdi1, bpxpls), format = "wide")
```

    #> # A tibble: 3 × 4
    #>   variable bpxsy1  bpxdi1  bpxpls
    #>   <chr>     <dbl>   <dbl>   <dbl>
    #> 1 bpxsy1   NA      0.441  -0.122 
    #> 2 bpxdi1    0.441 NA      -0.0277
    #> 3 bpxpls   -0.122 -0.0277 NA

------------------------------------------------------------------------

## 8. Controlling uncertainty output

All analysis functions share a common `variance` argument. You can
request any combination of:

| Code     | What it returns                                        |
|----------|--------------------------------------------------------|
| `"se"`   | Standard error                                         |
| `"ci"`   | Confidence interval: `ci_low`, `ci_high`               |
| `"var"`  | Variance (square of the SE)                            |
| `"cv"`   | Coefficient of variation (SE / estimate)               |
| `"moe"`  | Margin of error at `conf_level`                        |
| `"deff"` | Design effect (complex design variance / SRS variance) |

The `conf_level` argument controls the confidence level for `"ci"` and
`"moe"`. The default is `0.95`; for a 90% CI:

``` r
get_means(svy, bpxsy1, variance = c("se", "ci", "moe"), conf_level = 0.90)
```

    #> # A tibble: 1 × 6
    #>    mean    se ci_low ci_high   moe     n
    #>   <dbl> <dbl>  <dbl>   <dbl> <dbl> <int>
    #> 1  120. 0.365   120.    121. 0.601  6302

Set `variance = NULL` to suppress all uncertainty columns and return
point estimates and sample counts only.

### Estimated population counts

Add `n_weighted = TRUE` to any function to include the estimated
population count — the sum of weights — alongside the unweighted sample
count `n`.

``` r
get_means(svy, bpxsy1, n_weighted = TRUE)
```

    #> # A tibble: 1 × 5
    #>    mean ci_low ci_high     n n_weighted
    #>   <dbl>  <dbl>   <dbl> <int>      <dbl>
    #> 1  120.   120.    121.  6302 259878203.

### Tidyverse-compatible output names

By default surveycore uses its own column names (`mean`, `se`, `ci_low`,
`ci_high`, etc.). Set `name_style = "broom"` to use names compatible
with **broom** and **modelsummary** (`estimate`, `std.error`,
`conf.low`, `conf.high`):

``` r
get_means(svy, bpxsy1, name_style = "broom")
```

    #> # A tibble: 1 × 4
    #>   estimate conf.low conf.high     n
    #>      <dbl>    <dbl>     <dbl> <int>
    #> 1     120.     120.      121.  6302

------------------------------------------------------------------------

## 9. surveytidy integration

The **surveytidy** package provides dplyr verbs —
[`filter()`](https://rdrr.io/r/stats/filter.html), `select()`,
`mutate()`, and `group_by()` — that work directly on survey design
objects. Install it with:

``` r
pak::pak("jacobdennen/surveytidy")
```

### Domain estimation with `filter()`

A common pattern in survey analysis is computing an estimate for a
*subpopulation* — adults aged 60 and over, a particular racial group,
one treatment arm of a study. **Do not physically subset the data frame
before building the design object.** Removing rows changes the cluster
and stratum structure and produces incorrect standard errors ([Lumley
2010](#ref-lumley2010), ch. 4).

Use [`filter()`](https://rdrr.io/r/stats/filter.html) instead. It marks
rows as outside the domain while keeping them in the design object so
that the cluster structure remains intact:

``` r
library(surveytidy)

# Mean systolic BP for adults aged 60 and older
# The full cluster/strata structure is preserved for correct SEs
svy |>
  filter(ridageyr >= 60) |>
  get_means(bpxsy1)
```

### Derived variables with `mutate()`

`mutate()` creates new columns that are available to subsequent analysis
functions while preserving the survey design:

``` r
# Create a hypertension indicator and estimate its prevalence
svy |>
  mutate(hypertension = bpxsy1 >= 130 | bpxdi1 >= 80) |>
  get_freqs(hypertension)
```

### Grouped analysis with `group_by()`

`group_by()` sets persistent grouping that is applied by all downstream
analysis functions — useful when you want multiple estimates from the
same grouped design:

``` r
# Compute both means and frequencies for each sex group
svy_by_sex <- svy |> group_by(riagendr)

get_means(svy_by_sex, bpxsy1)
get_freqs(svy_by_sex, ridreth3)
```

You can also use the `group` argument directly in each function call,
which is equivalent and does not require surveytidy:

``` r
# These two calls produce identical output:
get_means(svy, bpxsy1, group = riagendr)
```

    #> # A tibble: 2 × 5
    #>   riagendr  mean ci_low ci_high     n
    #>      <dbl> <dbl>  <dbl>   <dbl> <int>
    #> 1        1  121.   121.    122.  3115
    #> 2        2  119.   118.    120.  3187

------------------------------------------------------------------------

## Summary

| Function                                                                         | Use for                                                     |
|----------------------------------------------------------------------------------|-------------------------------------------------------------|
| [`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md)   | Categorical variables — weighted distributions, percentages |
| [`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md)   | Continuous variables — weighted means                       |
| [`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md) | Population counts or aggregates — weighted sums             |
| [`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md) | Ratios of two weighted totals                               |
| [`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md)     | Pairwise Pearson correlations                               |

All functions: - Return a tibble subclass ready for further analysis or
display - Accept a `group` argument for subgroup estimates - Accept a
`variance` argument to control which uncertainty columns appear - Handle
all five survey design classes: `survey_taylor`, `survey_replicate`,
`survey_srs`, `survey_twophase`, and `survey_calibrated`

------------------------------------------------------------------------

## References

Lumley, Thomas. 2010. *Complex Surveys: A Guide to Analysis Using R*.
John Wiley & Sons. <https://doi.org/10.1002/9780470580066>.
