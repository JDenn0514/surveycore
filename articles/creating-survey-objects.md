# Creating Survey Objects in surveycore

## Introduction

Every analysis function in surveycore —
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
[`get_ratios()`](https://jdenn0514.github.io/surveycore/reference/get_ratios.md),
[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md)
— takes a **survey design object** as its first argument. That object
includes things like which units were clustered together, which strata
were defined, what weights apply, and other relevant information so that
point and variance estimation can be properly calculated. Without it,
point estimates may be biased and standard errors are almost certainly
wrong ([Lumley 2010](#ref-lumley2010); [Lohr 2022](#ref-lohr2022)).

This vignette answers one question: *given my data, which constructor do
I call and how do I call it?*

This vignette covers object *creation* only. Two things not covered
are: - How to create weights and how different weighting mechanisms
work. - What the different analysis/estimation functions
([`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md),
etc.) do. Those are covered in
[`vignette("getting-started")`](https://jdenn0514.github.io/surveycore/articles/getting-started.md).

------------------------------------------------------------------------

## 1. Decision Guide

Read the first row that matches your data.

| My data… | Constructor | Why |
|----|----|----|
| Is a probability sample and has weights and/or cluster IDs, strata | [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md) | Taylor series linearization — the general case |
| Is a probability sample and has replicate weight columns (repwt_1, repwt_2, …) | [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md) | Uses the agency-supplied variance replicates |
| Is a pure simple random sample with no clustering or strata | [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md) | Omit `ids` and `strata`; creates an SRS design |
| Is a non-probability sample with weights but no replicate weights | [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md) | SRS-approximation variance; SEs understate calibration uncertainty |
| Is a non-probability panel with replicate weights | [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md) | Bootstrap/jackknife variance includes calibration uncertainty |
| Was sampled in two stages with an expensive Phase 2 measurement | [`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md) | Two-phase variance accounting for both stages |

### Common surveys at a glance

| Survey | Constructor | Design |
|----|----|----|
| NHANES | [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md) | Stratified cluster, Taylor series |
| ANES | [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md) | Stratified cluster, Taylor series |
| GSS | [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md) | Stratified multi-stage cluster |
| Pew NPORS | [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md) | Stratified address-based sample (no PSU) |
| ACS PUMS (1-year) | [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md) | 80 successive-difference replicate weights |
| Pew Jewish Americans 2020 | [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md) | 100 JK1 jackknife replicate weights |
| BRFSS | [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md) | Bootstrap replicate weights |
| NAEP / PISA | [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md) | JK2 jackknife replicate weights |
| Nationscape (Democracy Fund + UCLA) | [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md) | Non-probability quota panel; ACS-calibrated raking weights |
| Opt-in online panels | [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md) | Non-probability |

------------------------------------------------------------------------

## 2. `as_survey()` — Taylor Series Designs

[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
is the right constructor for probability surveys with cluster and/or
stratum information but no pre-computed replicate weights. It uses
**Taylor series linearization** (also called the linearization or
delta-method estimator), the standard approach for complex probability
surveys ([Lumley 2010](#ref-lumley2010), ch. 2; [Lohr
2022](#ref-lohr2022), ch. 9).

### 2.1 Core arguments

| Argument | Codebook term | What it does |
|----|----|----|
| `ids` | “PSU”, “primary sampling unit”, “cluster ID” | Stage-1 cluster identifier |
| `weights` | “sampling weight”, “person weight”, “design weight” | Inverse of selection probability |
| `strata` | “stratum”, “design stratum”, “sampling stratum” | Stratification variable |
| `fpc` | “FPC”, “finite population correction”, “N” | Population size or sampling fraction |
| `nest` | (see below) | Whether PSU IDs are locally unique |

All arguments accept bare column names — no `~formula` syntax required.

### 2.2 The `nest` argument

Many government surveys assign PSU IDs locally within each stratum.
NHANES, for example, assigns IDs 1 and 2 within *every* stratum — PSU 1
in stratum 31 is a completely different unit from PSU 1 in stratum 32.
If you do not account for this, surveycore treats PSU 1 from stratum 31
and PSU 1 from stratum 32 as the same cluster, which produces incorrect
variance estimates.

Set `nest = TRUE` when PSU IDs are not globally unique across strata
([Lumley 2010, 28](#ref-lumley2010)). A quick diagnostic:

``` r

# NHANES: only two distinct PSU values, but 15 strata
# Each stratum has its own PSU 1 and PSU 2 → nest = TRUE
length(unique(nhanes_2017$sdmvpsu)) # 2
```

    ## [1] 2

``` r

length(unique(nhanes_2017$sdmvstra)) # 15
```

    ## [1] 15

If the number of unique PSU values is much smaller than the number of
strata, the IDs are almost certainly nested and you need `nest = TRUE`.

### 2.3 The `fpc` argument

The finite population correction (FPC) reduces variance estimates when
you have sampled a substantial fraction of the population ([Cochran
1977, sec. 2.8](#ref-cochran1977); [Lohr 2022, sec.
2.8](#ref-lohr2022)). Supply either:

- An **integer column** with the total population size in each stratum
- A **numeric column** (0–1) with the sampling fraction

FPC has a meaningful effect when the sampling rate exceeds roughly 5%
([Cochran 1977](#ref-cochran1977)). For large national surveys like
NHANES and ANES, the sampling fraction is tiny and FPC can be safely
omitted (`fpc = NULL`).

### 2.4 Multi-level clustering

For two-stage designs — counties then households, schools then students
— pass both levels of IDs as a vector:

``` r

as_survey(data, ids = c(county_id, household_id), weights = wt, strata = region)
```

### 2.5 Worked example: NHANES 2017–2018

NHANES uses a stratified, multistage probability cluster sample. The
design variables are documented in the analytic notes on the NHANES
website ([Lumley 2010](#ref-lumley2010), ch. 4):

| Variable | Role | Argument |
|----|----|----|
| `sdmvpsu` | Masked variance PSU (cluster ID) | `ids` |
| `sdmvstra` | Masked variance stratum | `strata` |
| `wtmec2yr` | 2-year MEC examination weight (blood pressure, lab tests) | `weights` |
| `wtint2yr` | 2-year interview weight (income, education, etc.) | `weights` |

``` r

# Subset to MEC exam participants (ridstatr == 2) before using wtmec2yr.
# The 550 interview-only participants have wtmec2yr = 0 and are not part
# of the exam sample.
nhanes_exam <- nhanes_2017[nhanes_2017$ridstatr == 2, ]

svy_nhanes <- as_survey(
  nhanes_exam,
  ids = sdmvpsu,
  strata = sdmvstra,
  weights = wtmec2yr,
  nest = TRUE # PSU IDs are locally unique within strata
)
svy_nhanes
```

    ## 

    ## ── Survey Design ───────────────────────────────────────────────────────────────

    ## <survey_taylor> (Taylor series linearization)

    ## Sample size: 8704

    ## 

    ## # A tibble: 8,704 × 14
    ##     seqn sdmvpsu sdmvstra wtmec2yr wtint2yr ridstatr riagendr ridageyr ridreth3
    ##    <dbl>   <dbl>    <dbl>    <dbl>    <dbl>    <dbl>    <dbl>    <dbl>    <dbl>
    ##  1 93703       2      145    8540.    9246.        2        2        2        6
    ##  2 93704       1      143   42567.   37339.        2        1        2        3
    ##  3 93705       2      145    8338.    8615.        2        2       66        4
    ##  4 93706       2      134    8723.    8549.        2        1       18        6
    ##  5 93707       1      138    7065.    6769.        2        1       13        7
    ##  6 93708       2      138   14372.   13329.        2        2       66        6
    ##  7 93709       1      136   12278.   12043.        2        2       75        4
    ##  8 93710       1      134   16848.   16418.        2        2        0        3
    ##  9 93711       2      134   12391.   11178.        2        1       56        6
    ## 10 93712       2      147   30337.   29040.        2        1       18        1
    ## # ℹ 8,694 more rows
    ## # ℹ 5 more variables: indfmpir <dbl>, dmdeduc2 <dbl>, bpxsy1 <dbl>,
    ## #   bpxdi1 <dbl>, bpxpls <dbl>

For interview-only variables (income, education), use the full dataset
with `wtint2yr` — all 9,254 participants have a positive interview
weight:

``` r

svy_nhanes_int <- as_survey(
  nhanes_2017,
  ids = sdmvpsu,
  strata = sdmvstra,
  weights = wtint2yr,
  nest = TRUE
)
```

### 2.6 Worked example: ANES 2024

The 2024 American National Election Studies uses a stratified cluster
design with separate pre- and post-election weights. Use the correct
weight for the variables you are analyzing:

| Variable   | Role                                                 | Argument  |
|------------|------------------------------------------------------|-----------|
| `v240103c` | PSU (FTF+Web combined) — cluster ID                  | `ids`     |
| `v240103d` | Stratum (FTF+Web combined)                           | `strata`  |
| `v240103a` | Pre-election weight — use for pre-election variables | `weights` |
| `v240103b` | Post-election weight — use for validated vote choice | `weights` |

``` r

# Pre-election analysis (party ID, ideology, candidate preference)
svy_anes_pre <- as_survey(
  anes_2024,
  ids = v240103c,
  strata = v240103d,
  weights = v240103a
)
```

    ## Warning: ! Some PSUs appear in more than one stratum: "1", "10", "11", "12", and "13".
    ##   If PSUs are nested within strata, set `nest = TRUE`.

``` r

# Post-election analysis (validated vote choice: v242066, v242067)
svy_anes_post <- as_survey(
  anes_2024,
  ids = v240103c,
  strata = v240103d,
  weights = v240103b
)
```

    ## Warning: ! Some PSUs appear in more than one stratum: "1", "10", "11", "12", and "13".
    ##   If PSUs are nested within strata, set `nest = TRUE`.

**Missing values:** ANES uses negative integer codes throughout — `−9` =
Refused, `−8` = Don’t know, `−1` = Inapplicable. Recode these to `NA`
before analysis. Check `attr(anes_2024$v241177, "labels")` for the full
set of codes for any variable.

### 2.7 Worked example: GSS 2024

The General Social Survey uses a stratified multi-stage cluster design.
Two weights are available depending on whether non-response bias is a
concern:

| Variable | Role | Argument |
|----|----|----|
| `vpsu` | Variance primary sampling unit | `ids` |
| `vstrat` | Variance stratum | `strata` |
| `wtssps` | Person post-stratification weight — standard analysis weight | `weights` |
| `wtssnrps` | Person post-stratification weight, non-response adjusted | `weights` |

``` r

# Standard analysis weight
svy_gss <- as_survey(
  gss_2024,
  ids = vpsu,
  strata = vstrat,
  weights = wtssps
)
```

    ## Warning: ! Some PSUs appear in more than one stratum: "1" and "2". If PSUs are nested
    ##   within strata, set `nest = TRUE`.

``` r

# Non-response adjusted weight (preferred when non-response bias is a concern)
svy_gss_nr <- as_survey(
  gss_2024,
  ids = vpsu,
  strata = vstrat,
  weights = wtssnrps
)
```

    ## Warning: ! Some PSUs appear in more than one stratum: "1" and "2". If PSUs are nested
    ##   within strata, set `nest = TRUE`.

**Missing values:** GSS uses `−100` = Inapplicable, `−99` = No answer,
`−98` = Don’t know, `−90` = Refused. These are stored as value labels on
every column — check `attr(gss_2024$happy, "labels")` and recode to `NA`
before analysis.

### 2.8 Worked example: Pew NPORS 2025

The 2025 National Public Opinion Reference Survey is an **address-based
sample (ABS)** — units are drawn directly from the USPS Computerized
Delivery Sequence file with no intermediate cluster stage. Each address
is its own sampling unit, so there is no PSU variable. Omit `ids`:

| Variable | Role | Argument |
|----|----|----|
| `stratum` | Sampling stratum (10 levels, defined by census block group) | `strata` |
| `weight` | Final raked weight — base weight calibrated to Census targets | `weights` |

``` r

svy_npors <- as_survey(
  pew_npors_2025,
  strata = stratum,
  weights = weight
)
```

------------------------------------------------------------------------

## 3. `as_survey_replicate()` — Replicate Weight Designs

Use
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md)
when your data provider has supplied pre-computed replicate weight
columns — columns like `repwt_1`, `repwt_2`, …, or `pwgtp1`–`pwgtp80`.
Replicate-based variance estimation works by repeatedly re-estimating
the target statistic under small perturbations of the sample, embedding
variance information directly in the weights ([Wolter
2007](#ref-wolter2007), ch. 1).

**Use the agency-supplied replicate weights when they are available.**
Survey agencies tune these weights for their specific design. Using them
correctly replicates published point estimates and standard errors and
is generally considered the preferred approach for variance estimation
with major public surveys ([Lohr 2022, sec. 9.4](#ref-lohr2022)).

### 3.1 The `type` argument

The `type` argument specifies which replication variance formula
applies. Getting this wrong produces systematically incorrect standard
errors. Identify the correct type from your codebook’s technical
documentation.

| Type | Full name | Identifying signs in codebook | Common surveys |
|----|----|----|----|
| `"JK1"` | Jackknife-1 | “JK1”; one PSU dropped per replicate | NHES, some Pew studies |
| `"JK2"` | Jackknife-2 | “JK2”; paired PSUs; exactly 2 PSUs per stratum | NAEP, PISA, most NCES surveys |
| `"JKn"` | Jackknife-n | One stratum dropped per replicate | Less common; some multi-PSU designs |
| `"BRR"` | Balanced Repeated Replication | “BRR”; exactly 2 PSUs per stratum required | Some CPS variants |
| `"Fay"` | Fay’s Modified BRR | “Fay BRR” or “Fay’s method”; BRR with epsilon | Some Census Bureau surveys ([Fay 1989](#ref-fay1989); [Judkins 1990](#ref-judkins1990)) |
| `"bootstrap"` | Bootstrap | “bootstrap replication weights”; 100–500 replicates | BRFSS |
| `"successive-difference"` | Successive Difference | “SDR” or “successive difference replication” | ACS 1-year PUMS ([U.S. Census Bureau 2022](#ref-census2022)) |
| `"ACS"` | ACS variant | Specific to ACS 5-year methodology | ACS 5-year PUMS |

The Fay epsilon parameter (`fay_rho`) controls how much each replicate
weight differs from the full-sample weight. Its value is specified in
the survey’s technical documentation ([Fay 1989](#ref-fay1989); [Judkins
1990](#ref-judkins1990)).

### 3.2 Worked example: ACS PUMS 2022 — Wyoming

The ACS 1-year PUMS provides 80 successive-difference replicate weights
for variance estimation, documented in the ACS Design and Methodology
report ([U.S. Census Bureau 2022](#ref-census2022)):

| Variable | Role | Argument |
|----|----|----|
| `pwgtp` | Person weight | `weights` |
| `pwgtp1`–`pwgtp80` | Successive-difference replicate weights (80 replicates) | `repweights` |

``` r

svy_acs <- as_survey_replicate(
  acs_pums_wy,
  weights = pwgtp,
  repweights = pwgtp1:pwgtp80,
  type = "successive-difference"
)
svy_acs
```

    ## 

    ## ── Survey Design ───────────────────────────────────────────────────────────────

    ## <survey_replicate> (SUCCESSIVE-DIFFERENCE, 80 replicates)

    ## Sample size: 5962

    ## 

    ## # A tibble: 5,962 × 96
    ##     puma    st pwgtp pwgtp1 pwgtp2 pwgtp3 pwgtp4 pwgtp5 pwgtp6 pwgtp7 pwgtp8
    ##    <int> <int> <int>  <int>  <int>  <int>  <int>  <int>  <int>  <int>  <int>
    ##  1   500    56    25     24     28     20     24     27     26     27     25
    ##  2   400    56   128    158    145    133    141    133    128    124    116
    ##  3   200    56   121    104     93    121     97     94    146    169    147
    ##  4   300    56    24      0     22     41      0      5     43     24     20
    ##  5   500    56    26     31     33     28     32     29     26     28     27
    ##  6   300    56    25     26      0     24      0     25     24      0     22
    ##  7   300    56    91     85     93     80     80     99    100     97     96
    ##  8   500    56    20     21     19     36     23     32     16     20     43
    ##  9   500    56   132    138    143    138    143    151    150    134    144
    ## 10   100    56    89    113     83    146     71     76    141    117     10
    ## # ℹ 5,952 more rows
    ## # ℹ 85 more variables: pwgtp9 <int>, pwgtp10 <int>, pwgtp11 <int>,
    ## #   pwgtp12 <int>, pwgtp13 <int>, pwgtp14 <int>, pwgtp15 <int>, pwgtp16 <int>,
    ## #   pwgtp17 <int>, pwgtp18 <int>, pwgtp19 <int>, pwgtp20 <int>, pwgtp21 <int>,
    ## #   pwgtp22 <int>, pwgtp23 <int>, pwgtp24 <int>, pwgtp25 <int>, pwgtp26 <int>,
    ## #   pwgtp27 <int>, pwgtp28 <int>, pwgtp29 <int>, pwgtp30 <int>, pwgtp31 <int>,
    ## #   pwgtp32 <int>, pwgtp33 <int>, pwgtp34 <int>, pwgtp35 <int>, …

### 3.3 Worked example: Pew Jewish Americans 2020

This Pew study provides 100 jackknife-1 replicate weights alongside the
full-sample weight:

| Variable | Role | Argument |
|----|----|----|
| `extweight` | Full-sample base weight | `weights` |
| `extweight1`–`extweight100` | JK1 jackknife replicate weights (100 replicates) | `repweights` |

``` r

svy_jewish <- as_survey_replicate(
  pew_jewish_2020,
  weights = extweight,
  repweights = extweight1:extweight100,
  type = "JK1"
)
svy_jewish
```

    ## 

    ## ── Survey Design ───────────────────────────────────────────────────────────────

    ## <survey_replicate> (JK1, 100 replicates)

    ## Sample size: 5881

    ## 

    ## # A tibble: 5,881 × 130
    ##    extweight extweight1 extweight2 extweight3 extweight4 extweight5 extweight6
    ##        <dbl>      <dbl>      <dbl>      <dbl>      <dbl>      <dbl>      <dbl>
    ##  1      271.       267.       272.       271.       272.       269.       265.
    ##  2      186.       183.       236.       186.       189.       185.       182.
    ##  3      182.       181.       185.       188.       184.       181.       189.
    ##  4      308.       307.       312.       324.       308.       305.       320.
    ##  5      165.       165.       167.       170.       166.       163.       164.
    ##  6      173.       170.       175.       173.       174.       173.       168.
    ##  7      352.       347.       353.       351.       358.       353.       338.
    ##  8      314.       312.       318.       316.       314.       314.       309.
    ##  9      395.       394.       395.       394.       392.       392.       392.
    ## 10      176.       177.       178.       181.       177.       175.       172.
    ## # ℹ 5,871 more rows
    ## # ℹ 123 more variables: extweight7 <dbl>, extweight8 <dbl>, extweight9 <dbl>,
    ## #   extweight10 <dbl>, extweight11 <dbl>, extweight12 <dbl>, extweight13 <dbl>,
    ## #   extweight14 <dbl>, extweight15 <dbl>, extweight16 <dbl>, extweight17 <dbl>,
    ## #   extweight18 <dbl>, extweight19 <dbl>, extweight20 <dbl>, extweight21 <dbl>,
    ## #   extweight22 <dbl>, extweight23 <dbl>, extweight24 <dbl>, extweight25 <dbl>,
    ## #   extweight26 <dbl>, extweight27 <dbl>, extweight28 <dbl>, …

### 3.4 The `scale` and `rscales` arguments

Most users can omit `scale` and `rscales`. surveycore computes defaults
based on `type` and the number of replicates. Override them only when
your codebook’s technical documentation specifies custom values ([Wolter
2007](#ref-wolter2007), ch. 3).

------------------------------------------------------------------------

## 4. `as_survey_twophase()` — Two-Phase Designs

> **If you are not sure whether your design is two-phase, it almost
> certainly is not.** Skip to [Section 5](#sec-srs) or [Section
> 6](#sec-nps).

### 4.1 What two-phase sampling is

Two-phase (or double-sampling) designs collect data in two stages
([Lumley 2010](#ref-lumley2010), ch. 9):

1.  **Phase 1:** A large, inexpensive sample that records basic
    variables (demographics, a screening question, administrative
    records).
2.  **Phase 2:** A subsample drawn from Phase 1 that collects expensive
    or difficult measurements — lab tests, in-person interviews, expert
    coding.

The variance estimator accounts for uncertainty from both sampling
stages ([Saegusa and Wellner 2013](#ref-saegusa2013)). You must have
retained the Phase 1 data and know which Phase 1 units were selected
into Phase 2.

Common contexts: case-cohort studies, medical validation studies,
surveys with a screening phase ([Breslow and Cain
1988](#ref-breslow1988)).

### 4.2 Arguments

| Argument | What it does |
|----|----|
| `phase1` | A `survey_taylor` object representing the Phase 1 design |
| `subset` | Bare name of a logical column: `TRUE` = selected into Phase 2 |
| `ids2`, `strata2`, `probs2`, `fpc2` | Phase 2 design variables (all optional) |
| `method` | `"full"` (default), `"approx"`, or `"simple"` |

The `method` argument:

- `"full"`: Correct variance accounting for both phases. Requires Phase
  1 cluster information.
- `"approx"`: Faster approximation; adequate when the Phase 1 sampling
  fraction is small.
- `"simple"`: Ignores the Phase 1 design. Use only if Phase 1 is a
  census.

### 4.3 Worked example: National Wilms Tumor Study

The `nwtco` dataset from the `survival` package records outcomes for
4,028 children enrolled in the National Wilms Tumor Study — a
multi-institution clinical trial. This is a case-cohort design: a random
subcohort was selected from all enrolled children (Phase 1), and
expensive central-laboratory histology was measured only for subcohort
members plus all relapse cases ([Breslow and Cain
1988](#ref-breslow1988)).

``` r

nwtco <- survival::nwtco

# in.subcohort is stored as 0/1 — must be logical for as_survey_twophase()
nwtco$in.subcohort <- as.logical(nwtco$in.subcohort)

# Phase 1: all 4,028 enrolled patients (each patient is their own unit)
phase1 <- as_survey(nwtco, ids = seqno)
```

    ## Warning: ! No weights provided.
    ## ℹ Treating as equal-probability sampling within clusters (unknown population
    ##   size).
    ## ℹ Population totals will equal sample totals, not estimated population totals.

``` r

# Phase 2: subcohort, with Phase 2 sampling stratified by relapse status
svy_twophase <- as_survey_twophase(
  phase1,
  strata2 = rel, # Phase 2 strata: cases (rel=1) vs. non-cases (rel=0)
  subset = in.subcohort, # Logical column: TRUE = selected into Phase 2
  method = "full"
)
svy_twophase
```

    ## 

    ## ── Survey Design ───────────────────────────────────────────────────────────────

    ## <survey_twophase> (method: full)

    ## Phase 1 sample size: 4028

    ## Phase 2 sample size: 668

    ## 

    ## # A tibble: 4,028 × 10
    ##    seqno instit histol stage study   rel edrel   age in.subcohort
    ##    <int>  <int>  <int> <int> <int> <int> <int> <int> <lgl>       
    ##  1     1      2      2     1     3     0  6075    25 FALSE       
    ##  2     2      1      1     2     3     0  4121    50 FALSE       
    ##  3     3      2      2     1     3     0  6069     9 FALSE       
    ##  4     4      2      1     4     3     0  6200    28 TRUE        
    ##  5     5      2      2     2     3     0  1244    55 FALSE       
    ##  6     6      1      1     2     3     0  2932    32 FALSE       
    ##  7     7      1      1     4     3     1   324    45 FALSE       
    ##  8     8      1      1     2     3     0  5408    44 FALSE       
    ##  9     9      1      1     1     3     0  5215   123 FALSE       
    ## 10    10      2      1     2     3     0  1381    31 FALSE       
    ## # ℹ 4,018 more rows
    ## # ℹ 1 more variable: ..surveycore_wt.. <int>

------------------------------------------------------------------------

## 5. Simple Random Sample with `as_survey()`

Use
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
without `ids` or `strata` when every unit in your target population had
an equal, known probability of selection — no clustering, no
stratification ([Cochran 1977](#ref-cochran1977), ch. 2; [Lohr
2022](#ref-lohr2022), ch. 2). This design is common in:

- Surveys of a complete organizational roster (all employees at a
  company, all students at a school) where units are drawn directly from
  a list
- Small-scale research with a well-defined, numbered sampling frame
- Pilot studies and classroom experiments

When neither `ids` nor `strata` is specified,
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
creates a `survey_taylor` object with no cluster or stratum structure —
the SRS special case of the Taylor series estimator.

### 5.1 The `fpc` argument matters more here

Without clustering or stratification, the FPC has a proportionally
larger effect on variance estimates than in complex designs ([Cochran
1977, sec. 2.8](#ref-cochran1977)). Supply it when you know the
population size or sampling fraction. For the example below, the
population is N = 400 schools.

### 5.2 Worked example: School district survey

A district administrator draws a simple random sample of 80 schools from
a complete roster of 400 schools. Every school has an equal probability
of selection (80/400 = 0.20) — the textbook SRS case ([Cochran
1977](#ref-cochran1977), ch. 2; [Lohr 2022](#ref-lohr2022), ch. 2):

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

svy_srs <- as_survey(
  school_survey,
  weights = sw, # each sampled school represents 5 schools in the population
  fpc = fpc # reduces SEs: we sampled 20% of the population
)
svy_srs
```

    ## 

    ## ── Survey Design ───────────────────────────────────────────────────────────────

    ## <survey_taylor> (Taylor series linearization)

    ## Sample size: 80

    ## 

    ## # A tibble: 80 × 6
    ##    school_id avg_score pct_frpl enrollment    sw   fpc
    ##        <int>     <dbl>    <dbl>      <dbl> <dbl> <dbl>
    ##  1       329      72.3     0.55        610     5   400
    ##  2       313      75.2     0.36        294     5   400
    ##  3        95      60.1     0.17        187     5   400
    ##  4       209      73.4     0.24        729     5   400
    ##  5       351      81.6     0.18        324     5   400
    ##  6       317      71.3     0.38        296     5   400
    ##  7       315      57.4     0.11        188     5   400
    ##  8       246      68.3     0.16        545     5   400
    ##  9       355      66.2     0.32        531     5   400
    ## 10       128      71.5     0.54        656     5   400
    ## # ℹ 70 more rows

Two things worth making explicit so this example is not misread:

**The unit of analysis is the school, not the student.** Variables like
`avg_score`, `pct_frpl`, and `enrollment` are school-level aggregates
drawn from administrative records for each sampled school. This is a
survey *of schools*. If you wanted individual student-level data from
each selected school, you would need a two-stage cluster design — sample
schools, then sample students within each school — and use
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
with `ids = school_id` to account for the clustering.

**The weight is constant because this is SRS.** Each school was selected
with probability 80/400 = 0.20, so each receives weight 1/0.20 = 5.0.
The weight is the same for every school because no school was
oversampled or undersampled relative to any other. Uniform weights are
not a simplification — they are the defining signature of simple random
sampling.

------------------------------------------------------------------------

## 6. `as_survey_nonprob()` — Non-Probability Samples

If you conduct surveys with non-probability samples, like with opt-in
panels such as Cint, Dynata, Qualtrics panels, Prolific, or others, then
this section is for you.

This section assumes you have, at a minimum, either calibration (raking)
weights or inverse-probability weights (IPW) via propensity scoring, but
ideally you will also have replicate weights based on the calibration
weights or IPW you already have. I’ll go into more detail on why you
want to have replicate weights in §6.2.

### 6.1 The fundamental distinction

A **probability sample** gives every unit in the target population a
known, positive inclusion probability. Design-based variance estimators
are valid because the randomness that justifies them comes from the
sampling mechanism itself ([Cochran 1977](#ref-cochran1977), ch. 1;
[Lohr 2022](#ref-lohr2022), ch. 1).

A **non-probability sample**, like an opt-in online panel, has unknown
inclusion probabilities. The decision to join a panel and to complete a
particular survey is self-selected. No mechanical property of the data
guarantees representativeness ([Baker et al. 2013](#ref-baker2013);
[Elliott and Valliant 2017](#ref-elliott2017)). As a result, there is
additional uncertainty associated with non-probability samples that is
not fully captured by traditional design-based variance estimation.

### 6.2 Variance estimation: two modes

[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md)
has two variance estimation modes:

**SRS approximation** (`repweights = NULL`, the default): If replicate
weights are not supplied to `repweights` (i.e., `repweights = NULL`),
then the standard errors treat the calibrated weights as fixed and apply
a simple random sampling formula. This is convenient but underestimates
the standard errors as the calibration step itself introduces additional
uncertainty that the SRS formula does not capture ([Elliott and Valliant
2017](#ref-elliott2017); [Kolenikov 2014](#ref-kolenikov2014)).

**Bootstrap or jackknife replicate variance** (`repweights` supplied):
If replicate weights are supplied in the `repweights` argument, the
replicate weight variance estimation is used. This approach properly
includes the uncertainty that comes from the calibration into the
variance estimate and is the recommended method when replicate weights
are available ([Elliott and Valliant 2017](#ref-elliott2017); [Kolenikov
2014](#ref-kolenikov2014); [Chrostowski et al.
2025](#ref-chrostowski2025)).

Neither mode resolves the fundamental limitation common to all
non-probability samples: standard errors cannot capture uncertainty from
the unknown selection mechanism itself ([Baker et al.
2013](#ref-baker2013); [Elliott and Valliant 2017](#ref-elliott2017)).

#### Choosing `type`

When `repweights` is supplied, the `type` argument selects the replicate
scheme. Four types are supported for `survey_nonprob` objects:

| `type` | Description | Default `scale` | When to use |
|----|----|----|----|
| `"bootstrap"` | Bootstrap resampling | `1/R` | Most vendor-supplied replicates |
| `"JK1"` | Delete-one jackknife (`"jackknife"` is an alias) | `(R-1)/R` | Some research panels |
| `"JK2"` | Stratified jackknife; requires explicit `rscales` | `1` | Clustered nonprob designs |
| `"JKn"` | Equivalent to JK2 | `1` | Same as JK2 |

### 6.3 What you can and cannot claim

| Claim | Valid? | Notes |
|----|----|----|
| Point estimates representative of calibration margins | ✅ Yes | Calibrated to age, gender, education, etc. targets |
| Estimates more accurate than unweighted | ✅ Usually | Especially for outcomes correlated with demographic variables |
| Standard errors (SRS approx., no `repweights`) | ⚠️ Understated | Treats calibrated weights as fixed; calibration variance not propagated |
| Standard errors (with `repweights`, calibration re-applied per replicate) | ⚠️ Approximately | Captures calibration uncertainty; cannot address selection mechanism uncertainty |
| Results equivalent to a probability-sample estimate | ❌ No | Selection mechanism is unknown and cannot be fully corrected |

This is the standard practice across the industry — used routinely by
academic researchers, major survey organizations, and commercial firms
([Baker et al. 2013](#ref-baker2013); [McPhee et al.
2023](#ref-mcphee2023)). The key is transparency: **your methods section
should state that you used a non-probability sample, detail how the
weights were created, and acknowledge that standard errors are
approximate.**

### 6.4 Worked example: Democracy Fund + UCLA Nationscape (SRS approximation)

The Nationscape is a large-scale non-probability survey conducted by
Democracy Fund + UCLA, fielded weekly from July 2019 through January
2021. Each wave used quota sampling to ensure that the data was
representative and consisted of approximately 6,250 respondents from
Lucid (now known as Cint). The data also contains weights created by
raking the data to the American Community Survey across age, gender,
education, race/ethnicity, region, and 2016 presidential vote choice.
The variable name for these weights is `weight`.

``` r

svy_ns <- as_survey_nonprob(ns_wave1, weights = weight)
svy_ns
```

    ## 

    ## ── Survey Design ───────────────────────────────────────────────────────────────

    ## <survey_nonprob> (non-probability) [experimental]

    ## • Variance: SRS approximation (no bootstrap replicate weights)

    ## Sample size: 6422

    ## 

    ## # A tibble: 6,422 × 171
    ##    response_id start_date          right_track economy_better interest
    ##    <chr>       <dttm>                    <dbl>          <dbl>    <dbl>
    ##  1 00100002    2019-07-18 08:11:41           2              2        2
    ##  2 00100003    2019-07-18 08:12:31           1              3        1
    ##  3 00100004    2019-07-18 08:12:04           2              3        2
    ##  4 00100005    2019-07-18 08:12:05           2              2        2
    ##  5 00100007    2019-07-18 08:11:43           1              1        1
    ##  6 00100008    2019-07-18 08:12:24           2              2        2
    ##  7 00100009    2019-07-18 08:13:15           2              2        4
    ##  8 00100010    2019-07-18 08:13:06           1              1        1
    ##  9 00100011    2019-07-18 08:11:47           2              2        3
    ## 10 00100012    2019-07-18 08:12:25           2              3        2
    ## # ℹ 6,412 more rows
    ## # ℹ 166 more variables: registration <dbl>, news_sources_facebook <dbl>,
    ## #   news_sources_cnn <dbl>, news_sources_msnbc <dbl>, news_sources_fox <dbl>,
    ## #   news_sources_network <dbl>, news_sources_localtv <dbl>,
    ## #   news_sources_telemundo <dbl>, news_sources_npr <dbl>,
    ## #   news_sources_amtalk <dbl>, news_sources_new_york_times <dbl>,
    ## #   news_sources_local_newspaper <dbl>, news_sources_other <dbl>, …

``` r

# Presidential approval rating (July 2019)
get_freqs(svy_ns, pres_approval)
```

    ## Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    ##   use an SRS approximation that underestimates calibration uncertainty.
    ## ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    ## ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    ##   use an SRS approximation that underestimates calibration uncertainty.
    ## ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    ## ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    ##   use an SRS approximation that underestimates calibration uncertainty.
    ## ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    ## ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    ##   use an SRS approximation that underestimates calibration uncertainty.
    ## ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.
    ## ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    ##   use an SRS approximation that underestimates calibration uncertainty.
    ## ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    ## # A tibble: 5 × 3
    ##   pres_approval          pct     n
    ##   <fct>                <dbl> <int>
    ## 1 Strongly approve    0.184   1222
    ## 2 Somewhat approve    0.206   1295
    ## 3 Somewhat disapprove 0.152    871
    ## 4 Strongly disapprove 0.415   2799
    ## 5 Not sure            0.0445   230

This produces a `survey_nonprob` object using SRS-approximation variance
because no replicate weights were supplied. As a result, the standard
errors will be too small as they do not take into account the additional
variance introduced by the raking procedure.

### 6.5 Worked example: Bootstrap replicate weights

When your data provider supplies bootstrap replicate weight columns —
each representing one round of calibration re-applied to a bootstrap
resample of the respondents — use `repweights` with
`type = "bootstrap"`. The resulting variance estimates properly account
for calibration uncertainty rather than treating the weights as fixed
([Kolenikov 2014](#ref-kolenikov2014); [Chrostowski et al.
2025](#ref-chrostowski2025)).

The example below uses synthetic data to illustrate the interface. In
practice the replicate weight columns come from your vendor alongside
the main calibration weight column.

``` r

set.seed(1)
n <- 200
R <- 50

ns_synthetic <- data.frame(
  pres_approval = sample(c("Approve", "Disapprove", "DK"), n, replace = TRUE),
  age_grp = sample(c("18-34", "35-54", "55+"), n, replace = TRUE),
  weight = runif(n, 0.5, 2.5)
)

# Replicate columns: calibration re-applied on each bootstrap draw.
# In practice these come from your vendor alongside the main weight column.
rep_mat <- matrix(runif(n * R, 0.3, 3.0), nrow = n)
colnames(rep_mat) <- paste0("repwt_", seq_len(R))
ns_synthetic <- cbind(ns_synthetic, as.data.frame(rep_mat))

svy_np_boot <- as_survey_nonprob(
  ns_synthetic,
  weights = weight,
  repweights = starts_with("repwt_"),
  type = "bootstrap"
)
svy_np_boot
```

    ## 

    ## ── Survey Design ───────────────────────────────────────────────────────────────

    ## <survey_nonprob> (non-probability, BOOTSTRAP, 50 replicates) [experimental]

    ## Sample size: 200

    ## 

    ## # A tibble: 200 × 53
    ##    pres_approval age_grp weight repwt_1 repwt_2 repwt_3 repwt_4 repwt_5 repwt_6
    ##    <chr>         <chr>    <dbl>   <dbl>   <dbl>   <dbl>   <dbl>   <dbl>   <dbl>
    ##  1 Approve       18-34    2.41    1.47    1.66    1.03    0.403   1.84    2.03 
    ##  2 DK            18-34    2.49    0.439   1.46    1.19    2.58    2.90    2.48 
    ##  3 Approve       18-34    1.71    2.27    1.95    2.63    1.31    2.88    2.78 
    ##  4 Disapprove    18-34    0.559   1.78    2.80    0.597   2.68    1.07    0.458
    ##  5 Approve       18-34    1.17    2.33    0.948   1.39    0.544   2.30    1.59 
    ##  6 DK            18-34    1.06    0.437   1.03    1.40    1.64    0.491   2.18 
    ##  7 DK            35-54    0.734   2.23    2.28    1.48    2.34    2.73    0.421
    ##  8 Disapprove    35-54    0.586   1.10    2.33    0.778   1.94    0.660   2.34 
    ##  9 Disapprove    35-54    1.24    1.07    2.81    1.02    1.73    1.80    1.90 
    ## 10 DK            18-34    1.17    2.54    1.55    2.08    2.76    1.92    1.68 
    ## # ℹ 190 more rows
    ## # ℹ 44 more variables: repwt_7 <dbl>, repwt_8 <dbl>, repwt_9 <dbl>,
    ## #   repwt_10 <dbl>, repwt_11 <dbl>, repwt_12 <dbl>, repwt_13 <dbl>,
    ## #   repwt_14 <dbl>, repwt_15 <dbl>, repwt_16 <dbl>, repwt_17 <dbl>,
    ## #   repwt_18 <dbl>, repwt_19 <dbl>, repwt_20 <dbl>, repwt_21 <dbl>,
    ## #   repwt_22 <dbl>, repwt_23 <dbl>, repwt_24 <dbl>, repwt_25 <dbl>,
    ## #   repwt_26 <dbl>, repwt_27 <dbl>, repwt_28 <dbl>, repwt_29 <dbl>, …

Use `svy_np_boot` with
[`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md),
[`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md),
and other estimation functions exactly as you would a plain
`survey_nonprob` object — the variance estimator switches from SRS
approximation to bootstrap automatically.

### 6.6 Worked example: University snowball sample

A university sends an email to 100 students inviting them to take part
in a survey. At the end of the survey, they encourage the students to
share the survey with other students. In the end they end up recruiting
500 respondents. This is known as a snowball sample and is another
example of non-probability sampling.

If the sample was weighted to represent the broader student body
population, then weights should be applied as shown below:

``` r

svy_campus <- as_survey_nonprob(campus_survey, weights = weight)
```

------------------------------------------------------------------------

## 7. When no constructor applies: convenience and purposive samples

Not every data collection fits the survey design framework.

### 7.1 Example: program evaluation classrooms

A researcher surveys students in five classrooms that volunteered to
participate in a new educational program and wants to assess whether the
program changed their attitudes.

The classrooms were not randomly selected from any defined population.
There is no sampling mechanism to justify a design-based variance
estimator, and no calibration weights that would correct for the
non-random selection. The inferential question — whether the program
*caused* attitude change — is a **causal inference** problem requiring a
control group and appropriate methods (difference-in-differences,
matching, regression discontinuity), not a survey design object.

If the goal is purely **descriptive** — summarizing the attitudes of
students in these specific classrooms without generalizing — you can
treat the participants as a census. Add a column of 1s and use
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
without `ids` or `strata`:

``` r

classroom_data$wt <- 1
svy_participants <- as_survey(classroom_data, weights = wt)
```

Equal weights treat all participants as equally represented. The SEs
reflect variation *among participants*. Do not interpret results as
representative of all students at the school.

### 7.2 General decision rule

| Design | Appropriate tool | Notes |
|----|----|----|
| Probability sample with design weights | [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md), [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md) | Exact variance |
| Pure SRS — equal probability, no clustering/strata | [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md) (no `ids` or `strata`) | Exact variance; SRS special case of Taylor |
| Any non-probability sample with weights | [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md) | Approximate variance |
| Voluntary response or convenience sample, no weights | [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md) with `weights = 1` (no `ids`/`strata`) | Conditional inference only; disclose |

When you use
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
with equal weights and no `ids` or `strata` for a non-probability
sample, surveycore produces estimates and SEs without error. The SEs are
valid as a measure of variability *among the observed participants*.
They should not be interpreted as uncertainty about a broader population
unless the sample can be independently defended as representative.

------------------------------------------------------------------------

## 8. Reference: Common Codebook Variables

A lookup table for common codebook terms and how they map to constructor
arguments:

| Codebook term | Maps to | Notes |
|----|----|----|
| “sampling weight”, “survey weight”, “person weight” | `weights =` |  |
| “PSU”, “primary sampling unit”, “cluster ID” | `ids =` |  |
| “stratum”, “design stratum”, “sampling stratum” | `strata =` |  |
| “FPC”, “finite population correction”, “population size” | `fpc =` |  |
| “replicate weights”, “bootstrap weights”, “BRR weights” | `repweights =` | Use [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md) |
| “base weight”, “design weight” (with separate replicates) | `weights =` in [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md) |  |
| “Fay coefficient”, “Fay factor”, “epsilon” | `fay_rho =` | With `type = "Fay"` |
| “raking weights”, “post-stratification weights”, “cal weights” | `weights =` in [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md) | Non-probability design |
| “two-phase”, “double sampling”, “case-cohort” | Phase 1 → [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md), then [`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md) |  |

------------------------------------------------------------------------

## References

Baker, Reg, J. Michael Brick, Nancy A. Bates, et al. 2013. “Summary
Report of the AAPOR Task Force on Non-Probability Sampling.” *Journal of
Survey Statistics and Methodology* 1 (2): 90–143.
<https://doi.org/10.1093/jssam/smt008>.

Breslow, Norman E., and Kevin C. Cain. 1988. “Logistic Regression for
Two-Stage Case-Control Data.” *Biometrika* 75 (1): 11–20.
<https://doi.org/10.1093/biomet/75.1.11>.

Chrostowski, Matthew J., Cary A. Guzman, and Lara Malm. 2025. “Variance
Estimation for Non-Probability Surveys.” *Journal of Survey Statistics
and Methodology*, ahead of print.
<https://doi.org/10.1093/jssam/smaf003>.

Cochran, William G. 1977. *Sampling Techniques*. 3rd ed. John Wiley &
Sons.

Elliott, Michael R., and Richard Valliant. 2017. “Inference for
Nonprobability Samples.” *Statistical Science* 32 (2): 249–64.
<https://doi.org/10.1214/16-STS598>.

Fay, Robert E. 1989. “Theory and Application of Replicate Weighting for
Variance Calculations.” *Proceedings of the Section on Survey Research
Methods*, 212–17.

Judkins, David R. 1990. “Fay’s Method for Variance Estimation.” *Journal
of Official Statistics* 6 (3): 223–39.

Kolenikov, Stas. 2014. “Calibrating Variance Estimation with Proxy
Variables.” *Survey Methodology* 40 (1): 21–38.

Lohr, Sharon L. 2022. *Sampling: Design and Analysis*. 3rd ed. CRC
Press.

Lumley, Thomas. 2010. *Complex Surveys: A Guide to Analysis Using R*.
John Wiley & Sons. <https://doi.org/10.1002/9780470580066>.

McPhee, Cameron, Frances Barlas, Nancy Brigham, et al. 2023. *Data
Quality Metrics for Online Samples: Considerations for Study Design &
Analysis*. American Association for Public Opinion Research.
<https://aapor.org/wp-content/uploads/2023/02/Task-Force-Report-FINAL.pdf>.

Saegusa, Takumi, and Jon A. Wellner. 2013. “Weighted Likelihood
Estimation Under Two-Phase Sampling.” *Annals of Statistics* 41 (1):
269–95. <https://doi.org/10.1214/12-AOS1073>.

U.S. Census Bureau. 2022. *American Community Survey Design and
Methodology, Chapter 12: Variance Estimation*. U.S. Census Bureau.
<https://www2.census.gov/programs-surveys/acs/methodology/design_and_methodology/2022/acs_design_methodology_ch12_2022.pdf>.

Wolter, Kirk M. 2007. *Introduction to Variance Estimation*. 2nd ed.
Springer. <https://doi.org/10.1007/978-0-387-35099-8>.
