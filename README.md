<!-- README.md is generated from README.Rmd. Please edit that file -->

# surveycore <a href = "https://jdenn0514.github.io/surveycore/index.html"><img src="man/figures/logo.png" align="right" height="138" /></a>

<!-- badges: start -->

[![CRAN
status](https://www.r-pkg.org/badges/version/surveycore)](https://CRAN.R-project.org/package=surveycore)
[![Project Status: Active – The project has reached a stable, usable
state and is being actively
developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![R-CMD-check](https://github.com/JDenn0514/surveycore/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/JDenn0514/surveycore/actions/workflows/R-CMD-check.yaml)
[![pkgcheck](https://github.com/JDenn0514/surveycore/workflows/pkgcheck/badge.svg)](https://github.com/JDenn0514/surveycore/actions?query=workflow%3Apkgcheck)
[![Codecov test
coverage](https://codecov.io/gh/JDenn0514/surveycore/graph/badge.svg)](https://app.codecov.io/gh/JDenn0514/surveycore)
<!-- badges: end -->

**surveycore** is the foundation of the surveyverse ecosystem, a modern
tidyverse-compatible replacement for the `survey` and `srvyr` packages
in R.

It provides S7-based survey design objects with:

- A tidy-select interface (`ids = c(psu, ssu)`, no formula syntax)
- Automatic preservation of haven-style variable labels and value labels
- Exact variance estimation (Taylor linearization, replicate weights,
  two-phase designs)
- Seamless conversion to and from `survey::svydesign` and
  `srvyr::tbl_svy`

For a side-by-side comparison with `survey` and `srvyr`, see
`vignette("surveycore-vs-survey")`.

## Installation

    # From CRAN:
    install.packages("surveycore")

    # Development version from GitHub:
    # install.packages("pak")
    pak::pak("JDenn0514/surveycore")

## What surveycore provides

- **S7 survey objects**: `survey_taylor`, `survey_replicate`,
  `survey_twophase`, `survey_nonprob`, `survey_collection`
- **Constructors**: `as_survey()`, `as_survey_replicate()`,
  `as_survey_twophase()`, `as_survey_nonprob()`,
  `as_survey_collection()`
- **Metadata system**: variable labels, value labels, question prefaces,
  notes, universe annotations, missing codes, SATA flags, and direction
  metadata. Set via `set_var_label()`, `set_val_labels()`, `set_sata()`,
  `set_higher_is()`, `set_universe()`, and more; extract with the
  matching `extract_*()` family. Haven-style label attributes are
  imported automatically.
- **Analysis functions**: `get_freqs()`, `get_means()`, `get_totals()`,
  `get_corr()`, `get_quantiles()`, `get_ratios()`, `get_diffs()`,
  `get_t_test()`, `get_pairwise()`, `get_variance()`,
  `get_covariance()`, `get_anova()`, `get_effective_n()`
- **Regression**: `survey_glm()` for survey-weighted GLMs with `clean()`
  for tidy coefficient tables
- **Calibration**: `as_caldata()` constructs calibration data for
  GREG-corrected variance on Taylor and replicate designs
- **Design utilities**: `update_design()`, `as_svydesign()`,
  `from_svydesign()`, `as_tbl_svy()`, `from_tbl_svy()`
- **Bundled datasets**: `ca_api_2000`, `nhanes_2017`, `acs_pums_wy`,
  `anes_2024`, `gss_2024`, and more

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

Thirteen analysis functions cover means, totals, frequencies,
correlations, ratios, differences, t-tests, pairwise comparisons, ANOVA,
variance, covariance, quantiles, and effective sample size.
`survey_glm()` fits survey-weighted generalized linear models.

## Basic usage

    library(surveycore)

    # Simple random sample: 2000 California API schools
    d <- as_survey(ca_api_2000, weights = pw, fpc = fpc)
    d
    #> 
    #> ── Survey Design ───────────────────────────────────────────────────────────────
    #> <survey_taylor> (Taylor series linearization)
    #> Sample size: 200
    #> 
    #> # A tibble: 200 × 38
    #>    cds       stype name  sname  snum dname  dnum cname  cnum pcttest api00 api99
    #>    <chr>     <int> <chr> <chr> <dbl> <chr> <int> <chr> <int>   <int> <int> <int>
    #>  1 15739081…     2 "McF… McFa…  1039 McFa…   432 Kern     14      98   462   448
    #>  2 19642126…     1 "Sto… Stow…  1124 ABC …     1 Los …    18     100   878   831
    #>  3 30664493…     2 "Bre… Brea…  2868 Brea…    79 Oran…    29      98   734   742
    #>  4 19644516…     1 "Ala… Alam…  1273 Down…   187 Los …    18      99   772   657
    #>  5 40688096…     1 "Sun… Sunn…  4926 San …   640 San …    39      99   739   719
    #>  6 19734456…     1 "Los… Los …  2463 Haci…   284 Los …    18      93   835   822
    #>  7 19647336…     3 "Nor… Nort…  2031 Los …   401 Los …    18      98   456   472
    #>  8 19647336…     1 "Gla… Glas…  1736 Los …   401 Los …    18      99   506   474
    #>  9 19648166…     1 "Max… Maxs…  2142 Moun…   470 Los …    18     100   543   458
    #> 10 38684786…     1 "Tre… Trea…  4754 San …   632 San …    37      90   649   604
    #> # ℹ 190 more rows
    #> # ℹ 26 more variables: target <int>, growth <int>, sch_wide <int>,
    #> #   comp_imp <int>, both <int>, awards <int>, meals <int>, ell <int>,
    #> #   yr_rnd <int>, mobility <int>, acs_k3 <int>, acs_46 <int>, acs_core <int>,
    #> #   pct_resp <int>, not_hsg <int>, hsg <int>, some_col <int>, col_grad <int>,
    #> #   grad_sch <int>, avg_ed <dbl>, full <int>, emer <int>, enroll <int>,
    #> #   api_stu <int>, pw <dbl>, fpc <dbl>

    # Weighted mean API score and total enrollment
    get_means(d, api00)
    #> # A tibble: 1 × 4
    #>    mean ci_low ci_high     n
    #>   <dbl>  <dbl>   <dbl> <int>
    #> 1  657.   638.    675.   200
    get_totals(d, enroll)
    #> # A tibble: 1 × 4
    #>      total   ci_low  ci_high     n
    #>      <dbl>    <dbl>    <dbl> <int>
    #> 1 3621074. 3288822. 3953327.   200

## Complex survey designs

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
    #>          y    wt  rep1  rep2  rep3  rep4
    #>      <dbl> <dbl> <dbl> <dbl> <dbl> <dbl>
    #>  1 -0.634   1.10 0.653 0.690 1.09  0.968
    #>  2  0.642   1.05 1.48  1.14  1.97  0.688
    #>  3  0.0802  2.96 1.18  0.582 1.92  1.22 
    #>  4  0.270   2.68 1.44  1.79  0.947 1.31 
    #>  5 -0.251   2.24 0.665 1.29  1.95  0.546
    #>  6 -0.131   2.69 0.632 0.773 0.508 1.03 
    #>  7 -1.64    2.69 1.41  1.58  1.56  1.78 
    #>  8 -0.919   1.41 0.656 1.18  1.52  0.818
    #>  9 -0.325   1.08 1.91  0.998 1.13  0.954
    #> 10  0.285   2.09 1.82  1.68  1.70  1.09 
    #> # ℹ 10 more rows

`survey_collection` groups multiple designs for comparative analysis
across waves or design variants. All analysis functions dispatch across
members and return a combined result:

    coll <- as_survey_collection(wave1 = d_wave1, wave2 = d_wave2)
    get_means(coll, api00)

## Variable labels

surveycore preserves haven-style labels automatically when reading
`.xpt` or `.sav` files. You can also set labels manually:

    d2 <- set_var_label(d, api00 = "Academic Performance Index score (2000)")
    d2 <- set_var_label(d2, enroll = "Number of students enrolled")

    extract_var_label(d2, api00)
    #>                                     api00 
    #> "Academic Performance Index score (2000)"
    extract_var_label(d2, enroll)
    #>                        enroll 
    #> "Number of students enrolled"

## Conversion to/from survey and srvyr

    # To survey::svydesign
    svy <- as_svydesign(d)
    class(svy)
    #> [1] "survey.design2" "survey.design"

    # Back to surveycore
    d_rt <- from_svydesign(svy)
    d_rt

## The surveyverse ecosystem

surveycore is the foundation of the surveyverse, a family of packages
built around it:

- **[surveytidy](https://jdenn0514.github.io/surveytidy/)**: dplyr verbs
  (`filter()`, `select()`, `mutate()`, `group_by()`) that respect survey
  design structure, so grouped summaries and subsetting always propagate
  weights and strata correctly.
- **surveywts**: weight adjustment utilities for survey data.
  Calibration-adjusted variance is already available in surveycore via
  `as_caldata()`; additional weight adjustment methods are in
  development.

## Development status

The package API is stable (v1.0.0). All classes, constructors, metadata
functions, and analysis functions are not expected to change in breaking
ways. New analysis functions and utilities may be added in future
releases. See `NEWS.md` for the full changelog.

## Code of Conduct

Please note that the surveycore project is released with a [Contributor
Code of
Conduct](https://jdenn0514.github.io/surveycore/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.

## License

GPL-3. Variance estimation code vendored from the
[`survey`](https://cran.r-project.org/package=survey) package (Thomas
Lumley, GPL-2/GPL-3); see `VENDORED.md` for full attribution.

## References

Lumley T (2004). “Analysis of Complex Survey Samples.” *Journal of
Statistical Software*, **9**(1), 1–19.

Lumley T (2010). *Complex Surveys: A Guide to Analysis Using R*. John
Wiley and Sons.
