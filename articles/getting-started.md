# Getting Started with surveycore

`surveycore` gives you a (mostly) complete workflow for survey data
analysis. This vignette is designed to give you a quick overview of the
main functionality present in this package. It is comprised of three
main sections:

1.  Creating survey objects

2.  Conducting simple analysis

3.  Using `surveytidy` for data manipulation

**Quick PSA before jumping in:**

`surveycore` was built as an alternative to `survey` and `srvyr`.
However, the code powering the variance estimation and analysis is
vendored from the `survey` package. Every aspect of this package that
calculates anything has been tested to ensure it provides the same
numerical results. This means every estimate `surveycore` produces has
been numerically verified to match `survey` output. Without Thomas
Lumley’s work on that package, surveycore would not be possible.

------------------------------------------------------------------------

## Creating the survey object

The first step when conducting survey analysis is creating the right
survey object where we specify the sampling design, weights, and
whatever other information is needed. Without this information, point
estimates may be biased and standard errors are almost certainly wrong
([Lumley 2010](#ref-lumley2010); [Lohr 2022](#ref-lohr2022)).

Fortunately, we don’t have to calculate that uncertainty ourselves!
That’s what the survey objects are for. They tell the analysis functions
how to conduct their analysis so they can properly take into account the
variance and bias from the survey design.

`surveycore` has five different survey object constructors:

1.  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)

2.  [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md)

3.  [`as_survey_srs()`](https://jdenn0514.github.io/surveycore/reference/as_survey_srs.md)

4.  [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md)

5.  [`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)

Rather than going into detail on each constructor, I’m just going to
provide a quick overview of each. For more information visit
[`vignette("creating-survey-objects")`](https://jdenn0514.github.io/surveycore/articles/creating-survey-objects.md).

### `as_survey()`

You want to use this if you used a probability sample and the data you
have has cluster IDs, strata, and/or design weights. In this example
we’ll use the General Social Survey which has variables for clustering,
strata, and design weights.

``` r
gss_svy <- as_survey(
  gss_2024,
  ids = vpsu,
  strata = vstrat,
  weights = wtssps
)
```

    #> Warning: ! Some PSUs appear in more than one stratum: "1" and "2". If PSUs are nested
    #>   within strata, set `nest = TRUE`.

``` r
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

### `as_survey_replicate()`

Use this when the data you have comes with pre-built replicate weight
columns like `repwt_1`, `repwt_2`. For example, Pew’s Jewish American
study from 2020 uses replicate weights.

``` r
pew_jewish_svy <- as_survey_replicate(
  pew_jewish_2020,
  weights = extweight,
  repweights = extweight1:extweight100,
  type = "JK1"
)

pew_jewish_svy
```

    #> 

    #> ── Survey Design ───────────────────────────────────────────────────────────────

    #> <survey_replicate> (JK1, 100 replicates)

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

### `as_survey_srs()`

Use this when your survey was a pure simple random sample, meaning each
respondent had equal probability of selection and there are neither
clustering nor strata.

I don’t have a specific dataset example to use, so I’ll just make a fake
one. This fake dataset is meant to replicate a school district survey.

``` r
set.seed(101)
N <- 400 # total schools in district
n <- 80 # schools sampled

school_survey <- data.frame(
  school_id = sample(seq_len(N), n),
  avg_score = round(rnorm(n, mean = 72, sd = 11), 1),
  pct_frpl = round(runif(n, 0.10, 0.85), 2), # % free/reduced price lunch
  enrollment = round(runif(n, 180, 850)),
  sw = N / n, # equal sampling weight = 400/80 = 5.0
  fpc = N # population size for FPC
)

school_svy <- as_survey_srs(
  school_survey,
  weights = sw, # each sampled school represents 5 schools in the population
  fpc = fpc # reduces SEs: we sampled 20% of the population
)

school_svy
```

    #> 

    #> ── Survey Design ───────────────────────────────────────────────────────────────

    #> <survey_srs> (simple random sample)

    #> Sample size: 80

    #> 

    #> # A tibble: 80 × 6
    #>    school_id avg_score pct_frpl enrollment    sw   fpc
    #>        <int>     <dbl>    <dbl>      <dbl> <dbl> <dbl>
    #>  1       329      72.3     0.55        610     5   400
    #>  2       313      75.2     0.36        294     5   400
    #>  3        95      60.1     0.17        187     5   400
    #>  4       209      73.4     0.24        729     5   400
    #>  5       351      81.6     0.18        324     5   400
    #>  6       317      71.3     0.38        296     5   400
    #>  7       315      57.4     0.11        188     5   400
    #>  8       246      68.3     0.16        545     5   400
    #>  9       355      66.2     0.32        531     5   400
    #> 10       128      71.5     0.54        656     5   400
    #> # ℹ 70 more rows

### `as_survey_nonprob()`

Use this when you used a non-probability panel (e.g., Qualtrics Panels,
Cint/Lucid, Dynata, YouGov, etc.) and have created weights designed to
ensure the sample is representative of the population you are interested
in.

``` r
ns_wave1_svy <- as_survey_nonprob(ns_wave1, weights = weight)

ns_wave1_svy
```

    #> 

    #> ── Survey Design ───────────────────────────────────────────────────────────────

    #> <survey_nonprob> (calibrated / non-probability) [experimental]

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

This is very rare, so it’s unlikely you have this. But, if you took a
large sample of a population and then resampled a subset of them, then
you might have a two-phase design. Some common contexts are: case-cohort
studies, medical validation studies, or surveys with a screening phase.

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

As you may have noticed, each survey object has a print method that
shows the first 10 rows of each data set, similar to a tibble, but also
includes a brief description of the survey design.

------------------------------------------------------------------------

## Conducting Simple Analysis

In addition to creating survey objects, `surveycore` has several
functions designed to make analysis easier:

- [`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md)

- [`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md)

- [`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md)

- [`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md)

- [`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md)

- [`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md)

### Frequency tables — `get_freqs()`

[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md)
calculates weighted frequencies (aka proportions). The first argument is
the survey design, the second is the variable you want to get the
frequencies for. Here’s a simple example where we calculate whether or
not people are willing to consider voting for Trump.

``` r
get_freqs(ns_wave1_svy, consider_trump)
```

    #> # A tibble: 3 × 3
    #>   consider_trump   pct     n
    #>   <fct>          <dbl> <int>
    #> 1 Yes            0.321  2087
    #> 2 No             0.555  3615
    #> 3 Don't know     0.125   705

**Analyzing multiple variables at once**

A key piece of survey research involves select-all-that-apply style
questions. For example, the Nationscape data asked people: “We’re
interested in where you might have heard news about politics in the last
week. Please indicate which of the following sources you used.” Rather
than looking at each one individually,
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md)
allows you to pass in multiple variables (it uses `tidy-select` under
the hood to do this). Let’s look at an example:

``` r
get_freqs(ns_wave1_svy, c(news_sources_facebook:news_sources_other))
```

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
# Mean discrimination against blacks
get_means(ns_wave1_svy, discrimination_blacks)
```

    #> # A tibble: 1 × 4
    #>    mean ci_low ci_high     n
    #>   <dbl>  <dbl>   <dbl> <int>
    #> 1  2.41   2.36    2.47  6364

### Population totals — `get_totals()`

[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md)
estimates the weighted sum: the total count or aggregate for the target
population. It’s important to note that the weights typically used in
non-probability samples are calibration weights which are designed to
ensure the sample is representative of the population it is sampled
from. These weights will not give you accurate population totals.
However, design weights scaled to represent the target population will
give estimated population size.

To show the difference, we will use Pew’s Jewish-Americans Study from
2020 to show a study with weights that show population totals and the
Nationscape data to show how calibrated weights do not.

First, we will look at the Nationscape data. Since these are calibration
weights, the totals will add up to the number of rows (6,422).

``` r
get_totals(ns_wave1_svy)
```

    #> # A tibble: 1 × 3
    #>   total ci_low ci_high
    #>   <dbl>  <dbl>   <dbl>
    #> 1  6422  6192.   6652.

However, the Pew Jewish-Americans study shows us the estimated total
population of Jews in the US:

``` r
get_totals(pew_jewish_svy)
```

    #> # A tibble: 1 × 3
    #>      total   ci_low  ci_high
    #>      <dbl>    <dbl>    <dbl>
    #> 1 9971358. 9971322. 9971394.

Note how we did not use any variables. That’s because we are interested
in the sample’s population size. However, if we are interested in the
estimated total income or age, we can do that by specifying it in the
`x` argument.

If we wanted to understand how many estimated people selected a specific
response option, we use the `group` argument. For example: if we wanted
to know how many Jews are in each age category we would calculate it
like this:

``` r
get_totals(pew_jewish_svy, group = age4cat)
```

    #> # A tibble: 5 × 4
    #>   age4cat      total   ci_low  ci_high
    #>   <fct>        <dbl>    <dbl>    <dbl>
    #> 1 18-29     1916708. 1752196. 2081221.
    #> 2 30-49     3129220. 2977800. 3280639.
    #> 3 50-64     2300014. 2181724. 2418305.
    #> 4 65+       2406454. 2293478. 2519431.
    #> 5 No Answer  218962.  163386.  274537.

------------------------------------------------------------------------

### Weighted correlations — `get_corr()`

[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md)
estimates survey-weighted Pearson correlations between two or more
continuous variables. Confidence intervals use the Fisher Z
transformation, guaranteeing bounds in (−1, 1).

Let’s look at approval for Trump and Biden, but first we’ll do some
quick data cleaning using the `surveytidy` package (I’ll go more
in-depth later showing what this package can do).

``` r
library(surveytidy)

ns_wave1_svy |>
  # drop NAs
  drop_na(cand_favorability_trump, cand_favorability_biden) |>
  # remove "Not sure" responses (coded 999)
  filter_out(cand_favorability_trump == 999 | cand_favorability_biden == 999) |>
  # calculate correlations
  get_corr(c(cand_favorability_trump, cand_favorability_biden))
```

Next, let’s look at favorability across multiple variables.

``` r
ns_wave1_svy |>
  drop_na(c(cand_favorability_trump:cand_favorability_pence)) |>
  # filter out any respondents who said "Not sure"
  filter_out(
    dplyr::if_any(
      c(cand_favorability_trump:cand_favorability_pence),
      ~ .x == 999
    )
  ) |>
  get_corr(c(cand_favorability_trump:cand_favorability_pence))
```

The output defaults to a long version where each row is a unique
variable pair. It shows the correlation in `r`, the confidence
intervals, p-values, and other relevant information.

Switch to wide format for a more familiar correlation-matrix layout:

``` r
ns_wave1_svy |>
  drop_na(c(cand_favorability_trump:cand_favorability_pence)) |>
  # filter out any respondents who said "Not sure"
  filter_out(
    dplyr::if_any(
      c(cand_favorability_trump:cand_favorability_pence),
      ~ .x == 999
    )
  ) |>
  get_corr(c(cand_favorability_trump:cand_favorability_pence), format = "wide")
```

------------------------------------------------------------------------

### Ratio estimation — `get_ratios()`

[`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md)
estimates the ratio of two weighted totals:

$$\widehat{R} = \frac{\sum\limits_{i}w_{i}\, y_{i}}{\sum\limits_{i}w_{i}\, x_{i}}$$

Variance is estimated via the delta method (linearization), equivalent
to [`survey::svyratio()`](https://rdrr.io/pkg/survey/man/svyratio.html)
([Lumley 2010](#ref-lumley2010)).

Ratios are useful when you want an estimate that is invariant to the
scale of the weights — for example, wages per hour, spending per
household member, or disease prevalence ratios.

A good example uses the Nationscape data. The favorability scale runs
from 1 (Very favorable) to 4 (Very unfavorable), so we can estimate the
ratio of Trump’s aggregate favorability score to Biden’s. A ratio less
than 1 means Trump’s aggregate score is lower — i.e., he is viewed more
favorably on average; a ratio greater than 1 means Biden is viewed more
favorably.

``` r
ns_wave1_svy |>
  # drop NAs
  drop_na(cand_favorability_trump, cand_favorability_biden) |>
  # remove people who don't know enough about Trump or Biden
  filter_out(cand_favorability_trump == 999 | cand_favorability_biden == 999) |>
  # get the ratio of favorability
  get_ratios(
    numerator = cand_favorability_trump,
    denominator = cand_favorability_biden
  )
```

------------------------------------------------------------------------

### `get_quantiles()`

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

    #> # A tibble: 3 × 5
    #>   quantile estimate ci_low ci_high     n
    #>   <chr>       <dbl>  <dbl>   <dbl> <int>
    #> 1 p25            32     31      34  6422
    #> 2 p50            47     46      49  6422
    #> 3 p75            62     62      63  6422

#### Choosing quantiles

Pass any numeric vector to `probs`. For the median alone:

``` r
get_quantiles(ns_wave1_svy, age, probs = 0.5)
```

    #> # A tibble: 1 × 5
    #>   quantile estimate ci_low ci_high     n
    #>   <chr>       <dbl>  <dbl>   <dbl> <int>
    #> 1 p50            47     46      49  6422

For deciles of age:

``` r
get_quantiles(ns_wave1_svy, age, probs = seq(0.1, 0.9, 0.1))
```

    #> # A tibble: 9 × 5
    #>   quantile estimate ci_low ci_high     n
    #>   <chr>       <dbl>  <dbl>   <dbl> <int>
    #> 1 p10            24     24      25  6422
    #> 2 p20            29     29      31  6422
    #> 3 p30            35     34      37  6422
    #> 4 p40            40     40      42  6422
    #> 5 p50            47     46      49  6422
    #> 6 p60            53     52      55  6422
    #> 7 p70            59     59      61  6422
    #> 8 p80            64     63      66  6422
    #> 9 p90            71     71      72  6422

### Subgroup analysis — the `group` argument

Every analysis function accepts a `group` argument for computing
estimates separately within levels of a categorical variable. Pass a
bare column name or multiple using
[`c()`](https://rdrr.io/r/base/c.html). For example, we’ll look at Trump
consideration by party identification.

``` r
get_freqs(ns_wave1_svy, consider_trump, group = pid3)
```

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

    #> # A tibble: 1 × 6
    #>    mean    se ci_low ci_high   moe     n
    #>   <dbl> <dbl>  <dbl>   <dbl> <dbl> <int>
    #> 1  47.2 0.396   46.5    47.8 0.651  6422

Set `variance = NULL` to suppress all uncertainty columns and return
point estimates and sample counts only.

### Estimated population counts

Add `n_weighted = TRUE` to any function to include the estimated
population count — the sum of weights — alongside the unweighted sample
count `n`. Let’s look at Pew’s Jewish-Americans data again. Using
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md)
and `n_weighted = TRUE` we can see proportions and estimated
populations. In this example, we’re looking at the proportion (`pct`),
the number of people from the sample (`n`), and the estimated population
size (`n_weighted`) of Jewish- Americans in each age category.

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

## Using `surveytidy`

``` r
pak::pak("jacobdennen/surveytidy")
```

All analysis functions make it easy to pipe in the survey design as
well. This allows you to manipulate the data with dplyr-like verbs from
the `surveytidy` package. We briefly saw an example of this earlier when
looking at correlations. The `surveytidy` package provides dplyr verbs
like: [`filter()`](https://rdrr.io/r/stats/filter.html), `select()`,
`mutate()`, `group_by()`, `rename()`, and a few others that work
directly on survey objects. We’ll show a few of those in play with the
Nationscape data again.

We’ll rename the variable for Biden’s favorability, then create a new
one where we add 1 to it, and then select the relevant columns to
compare.

``` r
ns_wave1_svy |>
  # rename the variable
  rename(fav_biden = cand_favorability_biden) |>
  # let's start with a simple example of adding 1 to favorability of Biden
  mutate(fav_biden_1 = fav_biden + 1) |>
  # now let's look at the results
  select(fav_biden, fav_biden_1)
```

### Grouped analysis with `group_by()`

Now let’s do a slightly more in-depth example. We’re going to look at
how people view Trump by age group. First, let’s create the necessary
variables.

``` r
ns_wave1_svy <- ns_wave1_svy |>
  # rename trump favorability
  rename(fav_trump = cand_favorability_trump) |>
  mutate(
    # convert favorability of Trump to a 3 level factor
    fav_trump_f3 = dplyr::recode_values(
      fav_trump,
      c(1:2) ~ "Favorable",
      c(3:4) ~ "Unfavorable",
      999 ~ "Haven't heard enough"
    ),
    age_f4 = dplyr::case_when(
      age < 30 ~ "18-29",
      age < 50 ~ "30-49",
      age < 65 ~ "50-64",
      age > 64 ~ "65+",
      .default = NA_character_
    )
  )

ns_wave1_svy |> select(fav_trump, fav_trump_f3, age, age_f4)
```

Now let’s look at the grouped frequencies. So far, we’ve used the
`group` argument, but we can also `group_by()` from surveytidy. Looking
below, we can see that they return identical results.

``` r
ns_wave1_svy |>
  group_by(age_f4) |>
  get_freqs(fav_trump_f3)

ns_wave1_svy |>
  get_freqs(fav_trump_f3, group = age_f4)
```

### Using `filter()` for domain estimation

It is very common in survey analysis to calculate results among
subgroups. For example, you may be interested in knowing how people
under 30 view Trump. One way is to do what we just did, use `group_by()`
on an age category. A simpler method is using the
[`filter()`](https://rdrr.io/r/stats/filter.html) and `filter_out()`
functions from surveytidy. For example:

``` r
ns_wave1_svy |>
  # keep only people under 30 in the domain
  filter(age < 30) |>
  # calculate frequencies
  get_freqs(fav_trump_f3)
```

As you can see, the results are the same as those calculated via
`group_by()` and `group`. That’s because the method for estimating
subpopulation results is the same in both.

For more information on domain estimation, a vignette on surveytidy’s
website will be up shortly.

------------------------------------------------------------------------

## Summary

| Function                                                                               | Use for                                                     |
|----------------------------------------------------------------------------------------|-------------------------------------------------------------|
| [`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md)         | Categorical variables — weighted distributions, percentages |
| [`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md)         | Continuous variables — weighted means                       |
| [`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md)       | Population counts or aggregates — weighted sums             |
| [`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md)       | Ratios of two weighted totals                               |
| [`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md)           | Pairwise Pearson correlations                               |
| [`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md) | Weighted quantiles and median — Woodruff CIs                |

All functions: - Return a tibble subclass ready for further analysis or
display - Accept a `group` argument for subgroup estimates - Accept a
`variance` argument to control which uncertainty columns appear - Handle
all five survey design classes: `survey_taylor`, `survey_replicate`,
`survey_srs`, `survey_twophase`, and `survey_nonprob`

Lohr, Sharon L. 2022. *Sampling: Design and Analysis*. 3rd ed. CRC
Press.

Lumley, Thomas. 2010. *Complex Surveys: A Guide to Analysis Using R*.
John Wiley & Sons. <https://doi.org/10.1002/9780470580066>.
