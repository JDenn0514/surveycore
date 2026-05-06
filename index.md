# surveycore

**surveycore** is the foundation of the surveyverse ecosystem — a
modern, tidyverse-compatible replacement for the `survey` and `srvyr`
packages in R.

It provides S7-based survey design objects with:

- A tidy-select interface (`ids = c(psu, ssu)`, no formula syntax)
- Automatic preservation of haven-style variable labels and value labels
- Exact variance estimation (Taylor linearization, replicate weights,
  two-phase designs)
- Seamless conversion to and from
  [`survey::svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html)
  and [`srvyr::tbl_svy`](http://gdfe.co/srvyr/reference/tbl_svy.md)

For a side-by-side comparison with `survey` and `srvyr`, see
[`vignette("surveycore-vs-survey")`](https://jdenn0514.github.io/surveycore/articles/surveycore-vs-survey.md).

## Installation

``` R
# From CRAN:
install.packages("surveycore")

# Development version from GitHub:
# install.packages("pak")
pak::pak("JDenn0514/surveycore")
```

## What surveycore provides

- **S7 survey objects**: `survey_taylor`, `survey_replicate`,
  `survey_twophase`, `survey_nonprob`
- **Constructors**:
  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
  [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
  [`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
  [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md)
- **Metadata system**:
  [`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
  [`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
  [`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
  [`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md)
  — with automatic haven attribute import
- **Analysis functions**:
  [`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
  [`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
  [`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
  [`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md),
  [`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md),
  [`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md),
  [`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md)
- **Regression**:
  [`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md)
  for survey-weighted GLMs with
  [`clean()`](https://jdenn0514.github.io/surveycore/reference/clean.md)
  for tidy coefficient tables
- **Design utilities**:
  [`update_design()`](https://jdenn0514.github.io/surveycore/reference/update_design.md),
  [`as_svydesign()`](https://jdenn0514.github.io/surveycore/reference/as_svydesign.md),
  [`from_svydesign()`](https://jdenn0514.github.io/surveycore/reference/from_svydesign.md),
  [`as_tbl_svy()`](https://jdenn0514.github.io/surveycore/reference/as_tbl_svy.md),
  [`from_tbl_svy()`](https://jdenn0514.github.io/surveycore/reference/from_tbl_svy.md)

## Who is this for?

surveycore is intended for:

- **Survey researchers and methodologists** who analyse complex
  probability samples and need design-consistent variance estimates
  (stratified, clustered, replicate-weight, and two-phase designs).
- **Social scientists, epidemiologists, and public health researchers**
  working with population surveys such as NHANES, ACS, GSS, or custom
  organizational surveys.
- **R users who want a tidyverse-compatible interface** for the survey
  analysis workflows currently served by `survey` and `srvyr`.

The software is designed to analyse **rectangular survey microdata**:
one row per respondent, numeric or categorical outcome variables, and
either explicit survey weights or a design specification (ids, strata,
FPC). It supports:

- Data frames, tibbles, and data.table objects as input.
- Variables with haven-style variable labels and value labels (e.g. from
  `.xpt` or `.sav` files read with `haven`).
- Grouped analyses (via `surveytidy::group_by()`).

Each analysis function accepts specific types of outcome variables:

| Function | Accepts |
|----|----|
| [`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md) | Categorical or coded integer variables |
| [`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md) | Numeric variables |
| [`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md) | Numeric variables |
| [`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md) | Pairs of numeric variables |
| [`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md) | Numeric variables |
| [`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md) | Two numeric variables (numerator / denominator) |
| [`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md) | A categorical grouping variable + one or more numeric outcomes |
| [`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md) | Numeric or binary response, numeric or categorical predictors |

## Basic usage

``` R
library(surveycore)

# ── Simple SRS design ──────────────────────────────────────────────────────────
set.seed(42)
df <- data.frame(
  psu = rep(1:10, each = 10),
  strata = rep(c("A", "B"), each = 50),
  weight = runif(100, 0.5, 2),
  income = rnorm(100, 50000, 10000),
  age = sample(18:80, 100, replace = TRUE)
)

d <- as_survey(df, ids = psu, weights = weight, strata = strata, nest = TRUE)
d
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_taylor> (Taylor series linearization)
#> Sample size: 100
#> 
#> # A tibble: 100 × 5
#>      psu strata weight income   age
#>    <int> <chr>   <dbl>  <dbl> <int>
#>  1     1 A       1.87  53219.    42
#>  2     1 A       1.91  42162.    33
#>  3     1 A       0.929 65757.    71
#>  4     1 A       1.75  56429.    41
#>  5     1 A       1.46  50898.    50
#>  6     1 A       1.28  52766.    78
#>  7     1 A       1.60  56793.    55
#>  8     1 A       0.702 50898.    60
#>  9     1 A       1.49  20069.    58
#> 10     1 A       1.56  52849.    39
#> # ℹ 90 more rows

# ── Weighted mean and total ────────────────────────────────────────────────────
get_means(d, income)
#> # A tibble: 1 × 4
#>     mean ci_low ci_high     n
#>    <dbl>  <dbl>   <dbl> <int>
#> 1 50206. 47921.  52490.   100
get_totals(d, income)
#> # A tibble: 1 × 4
#>      total   ci_low  ci_high     n
#>      <dbl>    <dbl>    <dbl> <int>
#> 1 6460063. 5906356. 7013770.   100
```

## Complex survey designs

``` R
# ── Replicate weights (BRR) ───────────────────────────────────────────────────
df_rep <- data.frame(
  y = rnorm(20),
  wt = runif(20, 1, 3),
  rep1 = runif(20, 0.5, 2),
  rep2 = runif(20, 0.5, 2),
  rep3 = runif(20, 0.5, 2),
  rep4 = runif(20, 0.5, 2)
)

d_rep <- as_survey_replicate(
  df_rep,
  weights = wt,
  repweights = starts_with("rep"),
  type = "BRR"
)
d_rep
#> 
#> ── Survey Design ───────────────────────────────────────────────────────────────
#> <survey_replicate> (BRR, 4 replicates)
#> Sample size: 20
#> 
#> # A tibble: 20 × 6
#>         y    wt  rep1  rep2  rep3  rep4
#>     <dbl> <dbl> <dbl> <dbl> <dbl> <dbl>
#>  1 -2.00   2.30 1.09  0.849 0.705 1.71 
#>  2  0.334  2.84 0.619 1.37  0.766 1.90 
#>  3  1.17   1.73 1.74  1.76  1.28  1.75 
#>  4  2.06   2.71 0.609 0.698 1.72  0.691
#>  5 -1.38   1.60 0.672 1.84  0.673 1.47 
#>  6 -1.15   1.93 1.46  1.18  1.84  1.54 
#>  7 -0.706  1.29 0.981 1.84  1.36  0.548
#>  8 -1.05   2.62 0.783 0.873 0.720 1.88 
#>  9 -0.646  2.33 1.09  0.626 1.85  1.22 
#> 10 -0.185  1.12 1.79  0.573 0.880 0.900
#> # ℹ 10 more rows
```

## Variable labels

surveycore preserves haven-style labels automatically when reading
`.xpt` or `.sav` files. You can also set labels manually:

``` R
d2 <- set_var_label(d, income = "Annual household income (USD)")
d2 <- set_var_label(d2, age = "Respondent age in years")

extract_var_label(d2, income)
#>                          income 
#> "Annual household income (USD)"
extract_var_label(d2, age)
#>                       age 
#> "Respondent age in years"
```

## Conversion to/from survey and srvyr

``` R
# To survey::svydesign
svy <- as_svydesign(d)
class(svy)
#> [1] "survey.design2" "survey.design"

# Back to surveycore
d_rt <- from_svydesign(svy)
d_rt
```

## The surveyverse ecosystem

surveycore is the foundation of the surveyverse — a family of packages
built around it:

- **[surveytidy](https://jdenn0514.github.io/surveytidy/)** — dplyr
  verbs ([`filter()`](https://rdrr.io/r/stats/filter.html), `select()`,
  `mutate()`, `group_by()`) that respect survey design structure, so
  grouped summaries and subsetting always propagate weights and strata
  correctly.
- **surveywts** — calibration and post-stratification for survey
  weights. Coming soon.

## Development status

The package API is stable. The core classes, constructors, and analysis
functions
([`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md)
through
[`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md))
are not expected to change in breaking ways. New analysis functions may
be added in future releases. See `NEWS.md` for the full changelog.

## Code of Conduct

Please note that the surveycore project is released with a [Contributor
Code of
Conduct](https://jdenn0514.github.io/surveycore/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.

## License

GPL-3. Variance estimation code vendored from the
[`survey`](https://cran.r-project.org/package=survey) package (Thomas
Lumley, GPL-2/GPL-3) — see `VENDORED.md` for full attribution.

## References

Lumley T (2004). “Analysis of Complex Survey Samples.” *Journal of
Statistical Software*, **9**(1), 1–19.

Lumley T (2010). *Complex Surveys: A Guide to Analysis Using R*. John
Wiley and Sons.
