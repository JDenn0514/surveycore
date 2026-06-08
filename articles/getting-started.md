# Getting Started with surveycore

`surveycore` is a tidyverse-compatible alternative to `survey` and
`srvyr`, covering the full workflow for survey data analysis. The
variance estimation code for probability samples is vendored from
`survey` and tested against it, so estimates using
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
and
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)
match the reference implementation. This vignette covers two things:

1.  Creating survey objects

2.  Conducting analysis

------------------------------------------------------------------------

## Creating the survey object

The first step when conducting survey analysis is creating the right
survey object where we specify the sampling design, weights, and
whatever other information is needed. Without this information, point
estimates may be biased and standard errors are almost certainly wrong
([Lumley 2010](#ref-lumley2010); [Lohr 2022](#ref-lohr2022)).

Fortunately, we don’t have to worry about that — that’s what survey
objects are for. They give the analysis functions everything they need
to correctly account for variance and bias from the sampling design.

`surveycore` has four different survey object constructors:

1.  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)

2.  [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md)

3.  [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md)

4.  [`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)

Rather than going into detail on each constructor, here is a quick
overview of each. For more information on the different constructors
visit
[`vignette("creating-survey-objects")`](https://jdenn0514.github.io/surveycore/articles/creating-survey-objects.md).

### `as_survey()`

Use
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
for two types of designs:

1.  A stratified or clustered sample

2.  A simple random sample (SRS)

If you know your data is a stratified/clustered sample or your data
comes with variables identifying the cluster IDs or strata, use this
function. All datasets used in this vignette are bundled with
`surveycore`. In this first example, we’ll use the General Social
Survey, which has variables for clustering, strata, and design weights.

``` r

gss_svy <- as_survey(
  gss_2024,
  # the cluster ids
  ids = vpsu,
  # the strata
  strata = vstrat,
  # the weights
  weights = wtssps,
  nest = TRUE
)

gss_svy
```

    #> 

    #> ── Survey Design ───────────────────────────────────────────────────────────────

    #> <survey_taylor> (Taylor series linearization)

    #> Sample size: 3309

    #> 

    #> # A tibble: 3,309 × 27
    #>     vpsu vstrat wtssps wtssnrps ballot  year    id   age   sex  race hispanic
    #>    <dbl>  <dbl>  <dbl>    <dbl>  <dbl> <dbl> <dbl> <dbl> <dbl> <dbl>    <dbl>
    #>  1     1   3401  1.89     2.37       2  2024     1    33     1     2        1
    #>  2     1   3401  1.15     1.39       2  2024     2    64     1     1        1
    #>  3     1   3401  0.916    1.17       3  2024     3    69     2     1        1
    #>  4     1   3401  2.29     2.74       1  2024     4    19     1     3        1
    #>  5     1   3401  1.01     1.27       3  2024     5    70     2     1        1
    #>  6     1   3401  1.17     1.34       2  2024     6    53     1     3        5
    #>  7     1   3401  3.21     4.07       2  2024     7    48     2     1        1
    #>  8     1   3401  0.424    0.533      3  2024     8    30     2     1        1
    #>  9     1   3401  2.15     2.75       3  2024     9    60     2     2        1
    #> 10     1   3401  2.24     2.94       1  2024    10    25     1     2        1
    #> # ℹ 3,299 more rows
    #> # ℹ 16 more variables: educ <dbl>, degree <dbl>, income16 <dbl>, marital <dbl>,
    #> #   wrkstat <dbl>, hrs1 <dbl>, adults <dbl>, partyid <dbl>, polviews <dbl>,
    #> #   happy <dbl>, health <dbl>, trust <dbl>, natfare <dbl>, abany <dbl>,
    #> #   attend <dbl>, relig <dbl>

Each survey object has a print method that shows the first 10 rows of
the data, similar to a tibble, but also includes a brief description of
the survey design.

If your data doesn’t have strata or clusters, but each respondent had
equal probability of being sampled (a simple random sample), then you
still want to use this function. However, unlike before, you leave
`strata` and `ids` NULL since you don’t have any. A good example of this
is the 2000 California API survey.

``` r

ca_api_2000_svy <- as_survey(
  ca_api_2000,
  weights = pw,
  fpc = fpc # reduces SEs
)

ca_api_2000_svy
```

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

### `as_survey_replicate()`

Use this when the data you have is from a probability sample and has
replicate weight columns like `repwt_1`, `repwt_2`. For example, Pew’s
Jewish American study from 2020 uses replicate weights.

``` r

pew_jewish_svy <- as_survey_replicate(
  pew_jewish_2020,
  weights = extweight,
  repweights = extweight1:extweight100,
  type = "JK2"
)

pew_jewish_svy
```

    #> 

    #> ── Survey Design ───────────────────────────────────────────────────────────────

    #> <survey_replicate> (JK2, 100 replicates)

    #> Sample size: 5881

    #> 

    #> # A tibble: 5,881 × 130
    #>    extweight extweight1 extweight2 extweight3 extweight4 extweight5 extweight6
    #>        <dbl>      <dbl>      <dbl>      <dbl>      <dbl>      <dbl>      <dbl>
    #>  1      271.       267.       272.       271.       272.       269.       265.
    #>  2      186.       183.       236.       186.       189.       185.       182.
    #>  3      182.       181.       185.       188.       184.       181.       189.
    #>  4      308.       307.       312.       324.       308.       305.       320.
    #>  5      165.       165.       167.       170.       166.       163.       164.
    #>  6      173.       170.       175.       173.       174.       173.       168.
    #>  7      352.       347.       353.       351.       358.       353.       338.
    #>  8      314.       312.       318.       316.       314.       314.       309.
    #>  9      395.       394.       395.       394.       392.       392.       392.
    #> 10      176.       177.       178.       181.       177.       175.       172.
    #> # ℹ 5,871 more rows
    #> # ℹ 123 more variables: extweight7 <dbl>, extweight8 <dbl>, extweight9 <dbl>,
    #> #   extweight10 <dbl>, extweight11 <dbl>, extweight12 <dbl>, extweight13 <dbl>,
    #> #   extweight14 <dbl>, extweight15 <dbl>, extweight16 <dbl>, extweight17 <dbl>,
    #> #   extweight18 <dbl>, extweight19 <dbl>, extweight20 <dbl>, extweight21 <dbl>,
    #> #   extweight22 <dbl>, extweight23 <dbl>, extweight24 <dbl>, extweight25 <dbl>,
    #> #   extweight26 <dbl>, extweight27 <dbl>, extweight28 <dbl>, …

### `as_survey_nonprob()`

Use this if your data comes from a non-probability sample (e.g., via an
opt-in panel like Qualtrics Panels, Cint/Lucid, Dynata, etc.) and has
weights (e.g., calibration weights, inverse-probability weights, etc.).
To illustrate we’ll use Wave 1 from the Nationscape dataset.

``` r

ns_wave1_svy <- as_survey_nonprob(ns_wave1, weights = weight)

ns_wave1_svy
```

    #> 

    #> ── Survey Design ───────────────────────────────────────────────────────────────

    #> <survey_nonprob> (non-probability) [experimental]

    #> • Variance: SRS approximation (no bootstrap replicate weights)

    #> Sample size: 6422

    #> 

    #> # A tibble: 6,422 × 171
    #>    response_id start_date          right_track economy_better interest
    #>    <chr>       <dttm>                    <dbl>          <dbl>    <dbl>
    #>  1 00100002    2019-07-18 08:11:41           2              2        2
    #>  2 00100003    2019-07-18 08:12:31           1              3        1
    #>  3 00100004    2019-07-18 08:12:04           2              3        2
    #>  4 00100005    2019-07-18 08:12:05           2              2        2
    #>  5 00100007    2019-07-18 08:11:43           1              1        1
    #>  6 00100008    2019-07-18 08:12:24           2              2        2
    #>  7 00100009    2019-07-18 08:13:15           2              2        4
    #>  8 00100010    2019-07-18 08:13:06           1              1        1
    #>  9 00100011    2019-07-18 08:11:47           2              2        3
    #> 10 00100012    2019-07-18 08:12:25           2              3        2
    #> # ℹ 6,412 more rows
    #> # ℹ 166 more variables: registration <dbl>, news_sources_facebook <dbl>,
    #> #   news_sources_cnn <dbl>, news_sources_msnbc <dbl>, news_sources_fox <dbl>,
    #> #   news_sources_network <dbl>, news_sources_localtv <dbl>,
    #> #   news_sources_telemundo <dbl>, news_sources_npr <dbl>,
    #> #   news_sources_amtalk <dbl>, news_sources_new_york_times <dbl>,
    #> #   news_sources_local_newspaper <dbl>, news_sources_other <dbl>, …

### `as_survey_twophase()`

Two-phase sampling involves collecting a large initial sample, then
sampling a subset of those respondents as a follow-up. This is not a
very common survey method, but common examples include case-cohort
studies, medical validation studies, or surveys with a screening phase.
If your data is a two-phase sample, use
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md).

We will use the nwtco data from the `survival` package.

``` r

nwtco <- survival::nwtco

# in.subcohort is stored as 0/1 — must be logical for as_survey_twophase()
nwtco$in.subcohort <- as.logical(nwtco$in.subcohort)

# Phase 1: all 4,028 enrolled patients (each patient is their own unit)
phase1 <- as_survey(nwtco, ids = seqno)
```

    #> Warning: ! No weights provided.
    #> ℹ Treating as equal-probability sampling within clusters (unknown population
    #>   size).
    #> ℹ Population totals will equal sample totals, not estimated population totals.

``` r

# Phase 2: subcohort, with Phase 2 sampling stratified by relapse status
nwtco_svy <- as_survey_twophase(
  phase1,
  strata2 = rel, # Phase 2 strata: cases (rel=1) vs. non-cases (rel=0)
  subset = in.subcohort, # Logical column: TRUE = selected into Phase 2
  method = "full"
)

nwtco_svy
```

    #> 

    #> ── Survey Design ───────────────────────────────────────────────────────────────

    #> <survey_twophase> (method: full)

    #> Phase 1 sample size: 4028

    #> Phase 2 sample size: 668

    #> 

    #> # A tibble: 4,028 × 10
    #>    seqno instit histol stage study   rel edrel   age in.subcohort
    #>    <int>  <int>  <int> <int> <int> <int> <int> <int> <lgl>       
    #>  1     1      2      2     1     3     0  6075    25 FALSE       
    #>  2     2      1      1     2     3     0  4121    50 FALSE       
    #>  3     3      2      2     1     3     0  6069     9 FALSE       
    #>  4     4      2      1     4     3     0  6200    28 TRUE        
    #>  5     5      2      2     2     3     0  1244    55 FALSE       
    #>  6     6      1      1     2     3     0  2932    32 FALSE       
    #>  7     7      1      1     4     3     1   324    45 FALSE       
    #>  8     8      1      1     2     3     0  5408    44 FALSE       
    #>  9     9      1      1     1     3     0  5215   123 FALSE       
    #> 10    10      2      1     2     3     0  1381    31 FALSE       
    #> # ℹ 4,018 more rows
    #> # ℹ 1 more variable: ..surveycore_wt.. <int>

------------------------------------------------------------------------

## Analysis functions

In addition to creating survey objects, `surveycore` has several
functions designed to make analysis easier:

- [`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md)

- [`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md)

- [`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md)

- [`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md)

- [`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md)

- [`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md)

- [`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md)

- [`get_t_test()`](https://jdenn0514.github.io/surveycore/reference/get_t_test.md)

- [`get_pairwise()`](https://jdenn0514.github.io/surveycore/reference/get_pairwise.md)

- [`get_variance()`](https://jdenn0514.github.io/surveycore/reference/get_variance.md)

### Frequency tables — `get_freqs()`

[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md)
calculates weighted frequencies (aka proportions). The first argument is
the survey design, the second is the variable you want to get the
frequencies for. Here’s a simple example where we calculate whether
people are willing to consider voting for Trump.

``` r

get_freqs(ns_wave1_svy, consider_trump)
```

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 3 × 3
    #>   consider_trump   pct     n
    #>   <fct>          <dbl> <int>
    #> 1 Yes            0.321  2087
    #> 2 No             0.555  3615
    #> 3 Don't know     0.125   705

#### Analyzing multiple variables at once

A key piece of survey research involves select-all-that-apply style
questions. For example, the Nationscape data asked people: “We’re
interested in where you might have heard news about politics in the last
week. Please indicate which of the following sources you used.” Rather
than looking at each one individually,
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md)
accepts `tidy-select` expressions, which allows you to pass in multiple
variables. Let’s look at an example:

``` r

get_freqs(ns_wave1_svy, c(news_sources_facebook:news_sources_other))
```

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 24 × 4
    #>    name                                   value   pct     n
    #>    <fct>                                  <chr> <dbl> <int>
    #>  1 Social media (e.g., Facebook, Twitter) Yes   0.615  4187
    #>  2 Social media (e.g., Facebook, Twitter) No    0.385  2235
    #>  3 CNN                                    Yes   0.400  2532
    #>  4 CNN                                    No    0.600  3890
    #>  5 MSNBC                                  Yes   0.266  1667
    #>  6 MSNBC                                  No    0.734  4755
    #>  7 Fox News (cable)                       Yes   0.361  2360
    #>  8 Fox News (cable)                       No    0.639  4062
    #>  9 Network news (ABC, CBS, NBC) or PBS    Yes   0.580  3711
    #> 10 Network news (ABC, CBS, NBC) or PBS    No    0.420  2711
    #> # ℹ 14 more rows

The `name` column identifies which variable each row belongs to; `value`
holds the response code. You can also change the name of the columns if
you want. For example:

``` r

ns_wave1_svy |>
  get_freqs(
    c(news_sources_facebook:news_sources_other),
    names_to = "news_source",
    values_to = "choice"
  )
```

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 24 × 4
    #>    news_source                            choice   pct     n
    #>    <fct>                                  <chr>  <dbl> <int>
    #>  1 Social media (e.g., Facebook, Twitter) Yes    0.615  4187
    #>  2 Social media (e.g., Facebook, Twitter) No     0.385  2235
    #>  3 CNN                                    Yes    0.400  2532
    #>  4 CNN                                    No     0.600  3890
    #>  5 MSNBC                                  Yes    0.266  1667
    #>  6 MSNBC                                  No     0.734  4755
    #>  7 Fox News (cable)                       Yes    0.361  2360
    #>  8 Fox News (cable)                       No     0.639  4062
    #>  9 Network news (ABC, CBS, NBC) or PBS    Yes    0.580  3711
    #> 10 Network news (ABC, CBS, NBC) or PBS    No     0.420  2711
    #> # ℹ 14 more rows

### Weighted means — `get_means()`

[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md)
estimates the survey-weighted mean of a continuous variable.

``` r

# Average favorability towards Biden
ns_wave1_svy |>
  # remove those who said "Not sure" (coded as 999)
  surveytidy::filter_out(cand_favorability_biden == 999) |>
  get_means(cand_favorability_biden)
```

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 1 × 4
    #>    mean ci_low ci_high     n
    #>   <dbl>  <dbl>   <dbl> <int>
    #> 1  2.44   2.39    2.49  5371

### Population totals — `get_totals()`

[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md)
estimates the weighted total for the target population. When called
without `x`, it simply provides a sum of the weights. The meaning of the
result depends on how the weights are scaled. Pew’s Jewish-American
study scales the weights so it gives the estimated size of the Jewish-
American population:

``` r

pew_jewish_svy |>
  # only include jews by religion and jews of no religion to match Pew's report
  surveytidy::filter(jewishcat %in% c(1:2)) |>
  get_totals()
```

    #> # A tibble: 1 × 3
    #>      total   ci_low  ci_high
    #>      <dbl>    <dbl>    <dbl>
    #> 1 5782142. 5597865. 5966419.

Compare that to the GSS data from earlier, where the weights are scaled
to the sample size (N = 3,309):

``` r

get_totals(gss_svy)
```

    #> # A tibble: 1 × 3
    #>   total ci_low ci_high
    #>   <dbl>  <dbl>   <dbl>
    #> 1  3309  3132.   3486.

Specifying a variable in `x` computes the weighted total for that
variable. To show this, we’ll use the `ca_api_2000_svy` object from
before to determine how many students are enrolled in the California API
system.

``` r

get_totals(ca_api_2000_svy, x = enroll)
```

    #> # A tibble: 1 × 4
    #>      total   ci_low  ci_high     n
    #>      <dbl>    <dbl>    <dbl> <int>
    #> 1 3621074. 3288822. 3953327.   200

To see the weighted total within each level of a categorical variable,
use the `group` argument. To show this, we’ll look at how how many
Jewish-Americans fall in each age category:

``` r

pew_jewish_svy |>
  # only include jews by religion and jews of no religion to match Pew's report
  surveytidy::filter(jewishcat %in% c(1:2)) |>
  get_totals(group = age4cat)
```

    #> # A tibble: 5 × 4
    #>   age4cat      total   ci_low  ci_high
    #>   <fct>        <dbl>    <dbl>    <dbl>
    #> 1 18-29     1035017.  941600. 1128434.
    #> 2 30-49     1830689. 1729928. 1931451.
    #> 3 50-64     1144573. 1055704. 1233441.
    #> 4 65+       1656759. 1556108. 1757411.
    #> 5 No Answer  115103.   81093.  149113.

------------------------------------------------------------------------

### Weighted correlations — `get_corr()`

[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md)
estimates survey-weighted Pearson correlations between two or more
continuous variables. Confidence intervals use the Fisher Z
transformation, guaranteeing bounds in (−1, 1).

Let’s look at favorability for Trump and Biden. First we clean the
underlying data frame using the `surveytidy` package by dropping rows
with missing values and removing “Not sure” responses (coded `999`).

``` r

ns_wave1_clean_svy <- ns_wave1_svy |>
  surveytidy::drop_na(
    cand_favorability_trump,
    cand_favorability_biden
  ) |>
  surveytidy::filter_out(
    cand_favorability_trump == 999,
    cand_favorability_biden == 999
  )

get_corr(
  ns_wave1_clean_svy,
  c(cand_favorability_trump, cand_favorability_biden)
)
```

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 1 × 9
    #>   var1         var2            r  ci_low ci_high p_value statistic    df     n
    #>   <fct>        <fct>       <dbl>   <dbl>   <dbl>   <dbl>     <dbl> <int> <int>
    #> 1 Donald Trump Joe Biden -0.0351 -0.0434 -0.0267 0.00622     -2.74  6078  6080

Next, let’s look at favorability across multiple variables.

``` r

fav_vars <- c(
  "cand_favorability_trump",
  "cand_favorability_biden",
  "cand_favorability_harris",
  "cand_favorability_sanders",
  "cand_favorability_warren",
  "cand_favorability_buttigieg",
  "cand_favorability_pence"
)

ns_wave1_multi <- ns_wave1_clean_svy |>
  # remove NAs from all variables of interest
  surveytidy::drop_na(tidyselect::all_of(fav_vars)) |>
  # remove those who said "not sure" to any variable of interest
  surveytidy::filter_out(
    dplyr::if_any(
      tidyselect::all_of(fav_vars),
      \(x) x == 999
    )
  )

get_corr(
  ns_wave1_multi,
  c(cand_favorability_trump:cand_favorability_pence)
)
```

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 36 × 9
    #>    var1         var2          r   ci_low ci_high   p_value statistic    df     n
    #>    <fct>        <fct>     <dbl>    <dbl>   <dbl>     <dbl>     <dbl> <int> <int>
    #>  1 Donald Trump Barack…  0.0441  2.50e-3  0.0855 2.11e-  2     2.31   2734  2736
    #>  2 Donald Trump Alexan…  0.131   8.29e-2  0.179  5.30e- 12     6.93   2737  2739
    #>  3 Donald Trump Joe Bi… -0.519  -5.56e-1 -0.479  4.31e-189   -31.8    2746  2748
    #>  4 Donald Trump Kamala… -0.604  -6.34e-1 -0.572  5.40e-273   -39.7    2746  2748
    #>  5 Donald Trump Pete B… -0.526  -5.63e-1 -0.487  4.03e-195   -32.4    2746  2748
    #>  6 Donald Trump Elizab… -0.582  -6.13e-1 -0.549  7.02e-249   -37.5    2746  2748
    #>  7 Donald Trump Bernie… -0.526  -5.64e-1 -0.486  1.36e-195   -32.4    2746  2748
    #>  8 Donald Trump Mike P…  0.779   7.64e-1  0.793  0            65.1    2746  2748
    #>  9 Barack Obama Alexan…  0.0179 -2.16e-2  0.0574 3.50e-  1     0.935  2726  2728
    #> 10 Barack Obama Joe Bi…  0.0218 -7.00e-4  0.0444 2.53e-  1     1.14   2734  2736
    #> # ℹ 26 more rows

The output defaults to a long version where each row is a unique
variable pair. It shows the correlation in `r`, the confidence
intervals, p-values, and other relevant information.

Switch to wide format for a more familiar correlation-matrix layout:

``` r

get_corr(
  ns_wave1_multi,
  c(cand_favorability_trump:cand_favorability_pence),
  format = "wide"
)
```

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 9 × 10
    #>   variable      `Donald Trump` `Barack Obama` Alexandria Ocasio-Co…¹ `Joe Biden`
    #>   <chr>                  <dbl>          <dbl>                  <dbl>       <dbl>
    #> 1 Donald Trump         NA             0.0441                  0.131      -0.519 
    #> 2 Barack Obama          0.0441       NA                       0.0179      0.0218
    #> 3 Alexandria O…         0.131         0.0179                 NA          -0.0456
    #> 4 Joe Biden            -0.519         0.0218                 -0.0456     NA     
    #> 5 Kamala Harris        -0.604         0.0214                 -0.0425      0.690 
    #> 6 Pete Buttigi…        -0.526        -0.0437                 -0.0258      0.692 
    #> 7 Elizabeth Wa…        -0.582        -0.0511                 -0.0184      0.677 
    #> 8 Bernie Sande…        -0.526        -0.00508                -0.0225      0.667 
    #> 9 Mike Pence            0.779         0.00538                 0.100      -0.387 
    #> # ℹ abbreviated name: ¹​`Alexandria Ocasio-Cortez`
    #> # ℹ 5 more variables: `Kamala Harris` <dbl>, `Pete Buttigieg` <dbl>,
    #> #   `Elizabeth Warren` <dbl>, `Bernie Sanders` <dbl>, `Mike Pence` <dbl>

------------------------------------------------------------------------

### Ratio estimation — `get_ratios()`

[`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md)
estimates the ratio of two weighted totals. This is useful when you want
an estimate that doesn’t change relative to the scale of the weights,
like wages per hour, spending per household member, or disease
prevalence ratios.

We’ll illustrate this with a less conventional example, comparing
Trump’s favorability to Biden’s favorability. In this example, a score
below 1 would mean that Trump is viewed more favorably, and a score
above 1 would mean Biden is viewed more favorably. We’ll also use the
`ns_wave1_multi` object from the
[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md)
section since it already has missing values and “Not sure” responses
(999) removed.

``` r

get_ratios(
  ns_wave1_multi,
  numerator = cand_favorability_trump,
  denominator = cand_favorability_biden
)
```

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 1 × 4
    #>   ratio ci_low ci_high     n
    #>   <dbl>  <dbl>   <dbl> <int>
    #> 1  1.09   1.03    1.14  2748

------------------------------------------------------------------------

### Weighted quantiles — `get_quantiles()`

[`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md)
estimates survey-weighted quantiles using the Woodruff (1952) confidence
interval method. Confidence intervals are derived by inverting the
weighted CDF rather than assuming normality, so they are generally
**asymmetric** around the estimate and always respect the range of the
data. By default, it calculates the quantiles at the 25th, 50th, and
75th percentile.

``` r

# Quartiles and median of age (default probs = c(0.25, 0.5, 0.75))
get_quantiles(ns_wave1_svy, age)
```

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 3 × 5
    #>   quantile estimate ci_low ci_high     n
    #>   <chr>       <dbl>  <dbl>   <dbl> <int>
    #> 1 p25            32     31      34  6422
    #> 2 p50            47     46      49  6422
    #> 3 p75            62     62      63  6422

------------------------------------------------------------------------

### Treatment effects — `get_diffs()`

[`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md)
estimates the difference in means between each group and a reference
group using survey-weighted regression. Use it when you have a
categorical treatment variable with two or more levels and want to
compare each group against a baseline.

Here we estimate how Biden favorability differs by party identification.
The first factor level is used as the reference group by default; use
`ref_level` to change it.

``` r

ns_wave1_svy |>
  surveytidy::filter_out(cand_favorability_biden == 999) |>
  get_diffs(cand_favorability_biden, treats = pid3)
```

    #> Warning: ! pid3 coerced to factor.

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 4 × 8
    #>   pid3           estimate  mean     n ci_low ci_high    p_value stars
    #>   <fct>             <dbl> <dbl> <int>  <dbl>   <dbl>      <dbl> <chr>
    #> 1 Democrat          0      1.80  2064 NA      NA     NA         ""   
    #> 2 Republican        1.27   3.07  1625  1.16    1.38   1.75e-121 "***"
    #> 3 Independent       0.721  2.52  1477  0.604   0.837  6.66e- 34 "***"
    #> 4 Something else    0.859  2.66   274  0.648   1.07   1.30e- 15 "***"

Use `show_pct_change = TRUE` to add a column showing how much each group
differs from the reference mean in percentage terms:

``` r

ns_wave1_svy |>
  surveytidy::filter_out(cand_favorability_biden == 999) |>
  get_diffs(
    cand_favorability_biden,
    treats = pid3,
    show_pct_change = TRUE
  )
```

    #> Warning: ! pid3 coerced to factor.

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 4 × 9
    #>   pid3           estimate pct_change  mean     n ci_low ci_high    p_value stars
    #>   <fct>             <dbl>      <dbl> <dbl> <int>  <dbl>   <dbl>      <dbl> <chr>
    #> 1 Democrat          0         NA      1.80  2064 NA      NA     NA         ""   
    #> 2 Republican        1.27       0.706  3.07  1625  1.16    1.38   1.75e-121 "***"
    #> 3 Independent       0.721      0.400  2.52  1477  0.604   0.837  6.66e- 34 "***"
    #> 4 Something else    0.859      0.477  2.66   274  0.648   1.07   1.30e- 15 "***"

------------------------------------------------------------------------

### Two-sample t-test — `get_t_test()`

[`get_t_test()`](https://jdenn0514.github.io/surveycore/reference/get_t_test.md)
compares weighted means between exactly two groups using a design-based
t-test. The `by` variable must have exactly two levels.

``` r

get_t_test(gss_svy, hrs1, by = sex)
```

    #> Warning: ! sex coerced to factor. Level order:
    #> "1" and "2".

    #> # A tibble: 1 × 13
    #>   level_a level_b estimate mean_a mean_b   n_a   n_b ci_low ci_high t_stat    df
    #>   <chr>   <chr>      <dbl>  <dbl>  <dbl> <int> <int>  <dbl>   <dbl>  <dbl> <dbl>
    #> 1 male    female     -5.32   42.6   37.3   869   891  -7.13   -3.51  -5.88    66
    #> # ℹ 2 more variables: p_value <dbl>, stars <chr>

The output includes the estimated difference, the mean for each group,
standard error/confidence interval, t-statistic, degrees of freedom, and
p-value.

------------------------------------------------------------------------

### All-pairs comparisons — `get_pairwise()`

When your grouping variable has more than two levels,
[`get_pairwise()`](https://jdenn0514.github.io/surveycore/reference/get_pairwise.md)
runs all k(k−1)/2 pairwise t-tests in one call. P-values are adjusted
for multiple comparisons using the Holm method by default.

``` r

get_pairwise(ns_wave1_svy, age, by = pid3)
```

    #> Warning: ! pid3 coerced to factor. Level order:
    #> "1", "2", "3", and "4".

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 6 × 13
    #>   level_a level_b estimate mean_a mean_b   n_a   n_b ci_low ci_high t_stat    df
    #>   <chr>   <chr>      <dbl>  <dbl>  <dbl> <int> <int>  <dbl>   <dbl>  <dbl> <dbl>
    #> 1 Democr… Republ…     4.56   46.8   51.4  2291  1819   2.64   6.47    4.67   Inf
    #> 2 Democr… Indepe…    -1.28   46.8   45.6  2291  1868  -3.27   0.716  -1.26   Inf
    #> 3 Democr… Someth…    -6.53   46.8   40.3  2291   437  -9.29  -3.77   -4.63   Inf
    #> 4 Republ… Indepe…    -5.83   51.4   45.6  1819  1868  -7.83  -3.83   -5.72   Inf
    #> 5 Republ… Someth…   -11.1    51.4   40.3  1819   437 -13.9   -8.32   -7.85   Inf
    #> 6 Indepe… Someth…    -5.25   45.6   40.3  1868   437  -8.08  -2.43   -3.65   Inf
    #> # ℹ 2 more variables: p_value <dbl>, stars <chr>

Each row is one pair of groups. Use `pval_adj` to change the correction
method: `"bonferroni"`, `"BH"`, `"none"`, etc.

------------------------------------------------------------------------

### Population variance — `get_variance()`

[`get_variance()`](https://jdenn0514.github.io/surveycore/reference/get_variance.md)
estimates the finite-population variance of a variable — how spread out
the variable is in the population, not the uncertainty of the estimate.
It accepts the same `group`, `variance`, and `n_weighted` arguments as
the other functions.

``` r

get_variance(ns_wave1_svy, age)
```

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 1 × 5
    #>   name                                             variance ci_low ci_high     n
    #>   <chr>                                               <dbl>  <dbl>   <dbl> <int>
    #> 1 What is your age? Provided by LUCID. Response i…     309.   296.    323.  6422

### Subgroup analysis — the `group` argument

Every analysis function accepts a `group` argument for computing
estimates separately within levels of a categorical variable. Pass a
bare column name or multiple using
[`c()`](https://rdrr.io/r/base/c.html). For example, we’ll look at Trump
consideration by party identification.

``` r

get_freqs(ns_wave1_svy, consider_trump, group = pid3)
```

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    #> ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 12 × 4
    #>    pid3           consider_trump    pct     n
    #>    <fct>          <fct>           <dbl> <int>
    #>  1 Democrat       Yes            0.0501   136
    #>  2 Democrat       No             0.887   2042
    #>  3 Democrat       Don't know     0.0626   111
    #>  4 Republican     Yes            0.775   1403
    #>  5 Republican     No             0.128    227
    #>  6 Republican     Don't know     0.0969   183
    #>  7 Independent    Yes            0.238    475
    #>  8 Independent    No             0.566   1071
    #>  9 Independent    Don't know     0.195    316
    #> 10 Something else Yes            0.209     73
    #> 11 Something else No             0.570    272
    #> 12 Something else Don't know     0.221     91

Rows where the grouping variable is `NA` are excluded from all groups
and do not appear in the output. Responses within each group sum to 100%
for
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md).

------------------------------------------------------------------------

### Controlling uncertainty output

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

get_means(
  ns_wave1_svy,
  age,
  variance = c("se", "ci", "moe"),
  conf_level = 0.9
)
```

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 1 × 6
    #>    mean    se ci_low ci_high   moe     n
    #>   <dbl> <dbl>  <dbl>   <dbl> <dbl> <int>
    #> 1  47.2 0.396   46.5    47.8 0.651  6422

Set `variance = NULL` to suppress all uncertainty columns and return
point estimates and sample counts only.

Add `n_weighted = TRUE` to include the estimated population count, the
sum of weights, alongside the unweighted sample count `n`. Using
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md)
on Pew’s Jewish-Americans data, we can see both the proportion and the
estimated population size for each age category:

``` r

get_freqs(pew_jewish_svy, age4cat, n_weighted = TRUE)
```

    #> # A tibble: 5 × 4
    #>   age4cat      pct     n n_weighted
    #>   <fct>      <dbl> <int>      <dbl>
    #> 1 18-29     0.192    554   1916708.
    #> 2 30-49     0.314   1430   3129220.
    #> 3 50-64     0.231   1431   2300014.
    #> 4 65+       0.241   2336   2406454.
    #> 5 No Answer 0.0220   130    218962.

------------------------------------------------------------------------

## Regression

surveycore supports design-based regression via
[`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md).
It fits a weighted generalized linear model with support for Gaussian
(OLS), logistic, Poisson, and other methods, and returns a
`survey_glm_fit` object.

``` r

fit <- gss_svy |>
  # convert race to a factor so one variable is a factor
  surveytidy::mutate(
    race_f = surveytidy::make_factor(race)
  ) |>
  survey_glm(hrs1 ~ sex + degree + age + race_f)

fit
```

    #> Survey-weighted GLM
    #> 
    #> Family:  gaussian (identity link)
    #> Formula: hrs1 ~ sex + degree + age + race_f
    #> Design:  Taylor series
    #> 
    #> Coefficients:
    #> (Intercept)         sex      degree         age race_fblack race_fother 
    #>     48.7382     -5.0626     -0.0881     -0.0197     -1.3358     -0.2031 
    #> 
    #> Degrees of freedom: 67 (design-based)

Use
[`clean()`](https://jdenn0514.github.io/surveycore/reference/clean.md)
to tidy the output into a one-row-per-coefficient tibble with estimates,
standard errors, confidence intervals, and p-values:

``` r

clean(fit)
```

    #> # A tibble: 7 × 11
    #>   term       variable var_label label reference_row estimate std_error statistic
    #> * <chr>      <chr>    <chr>     <chr> <lgl>            <dbl>     <dbl>     <dbl>
    #> 1 (Intercep… (Interc… NA        (Int… FALSE          48.7       1.80      27.1  
    #> 2 sex        sex      responde… resp… FALSE          -5.06      0.943     -5.37 
    #> 3 degree     degree   r's high… r's … FALSE          -0.0881    0.321     -0.275
    #> 4 age        age      age of r… age … FALSE          -0.0197    0.0290    -0.680
    #> 5 race_fwhi… race_f   race of … white TRUE           NA        NA         NA    
    #> 6 race_fbla… race_f   race of … black FALSE          -1.34      1.41      -0.949
    #> 7 race_foth… race_f   race of … other FALSE          -0.203     1.53      -0.132
    #> # ℹ 3 more variables: p_value <dbl>, conf_low <dbl>, conf_high <dbl>

For logistic or Poisson models, pass `exponentiate = TRUE` to
[`clean()`](https://jdenn0514.github.io/surveycore/reference/clean.md)
to report odds ratios or rate ratios instead of log-scale coefficients.

------------------------------------------------------------------------

## Summary

| Function | Use for |
|----|----|
| [`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md) | Categorical variables — weighted distributions, percentages |
| [`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md) | Continuous variables — weighted means |
| [`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md) | Population counts or aggregates — weighted sums |
| [`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md) | Pairwise Pearson correlations |
| [`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md) | Ratios of two weighted totals |
| [`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md) | Weighted quantiles and median — Woodruff CIs |
| [`get_diffs()`](https://jdenn0514.github.io/surveycore/reference/get_diffs.md) | Group comparisons — treatment effects vs. a reference group |
| [`get_t_test()`](https://jdenn0514.github.io/surveycore/reference/get_t_test.md) | Two-group mean comparison — design-based t-test |
| [`get_pairwise()`](https://jdenn0514.github.io/surveycore/reference/get_pairwise.md) | All-pairs t-tests with multiple-comparison adjustment |
| [`get_variance()`](https://jdenn0514.github.io/surveycore/reference/get_variance.md) | Finite-population variance of a continuous variable |
| [`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md) + [`clean()`](https://jdenn0514.github.io/surveycore/reference/clean.md) | Design-based regression — OLS, logistic, Poisson |

All functions: - Return a tibble subclass ready for further analysis or
display - Accept a `group` argument for subgroup estimates - Accept a
`variance` argument to control which uncertainty columns appear - Handle
all survey design classes: `survey_taylor`, `survey_replicate`,
`survey_twophase`, and `survey_nonprob`

Lohr, Sharon L. 2022. *Sampling: Design and Analysis*. 3rd ed. CRC
Press.

Lumley, Thomas. 2010. *Complex Surveys: A Guide to Analysis Using R*.
John Wiley & Sons. <https://doi.org/10.1002/9780470580066>.
