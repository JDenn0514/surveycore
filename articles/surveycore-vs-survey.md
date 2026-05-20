# surveycore vs. survey and srvyr

If you’re coming from `survey` or `srvyr`, this vignette is a
side-by-side reference showing how surveycore maps to the workflows you
already know. Every section shows the same task three ways: `survey`,
`srvyr`, and `surveycore`.

**Two things to know upfront:**

- surveycore is **not** a wrapper around `survey`. Its variance code is
  vendored from `survey` — so every estimate surveycore produces matches
  `survey` output numerically — but `survey` is not a runtime
  dependency.
- `survey` → `srvyr` added tidyverse syntax. surveycore rethinks the
  interface further: tidy-select constructors, dedicated analysis
  functions, automatic label handling from haven-imported data, and
  richer tibble output.

**Constructor comparisons** use the `api` dataset from the `survey`
package — the same reference dataset as the [srvyr comparison
vignette](https://CRAN.R-project.org/package=srvyr), so
cross-referencing is easy. **Analysis comparisons** use `ns_wave1`
(Nationscape Wave 1, Democracy Fund + UCLA) from surveycore’s bundled
data.

------------------------------------------------------------------------

## 1. Creating Survey Design Objects

### 1.1 Simple Random Sample

`apisrs` is a simple random sample of California schools.

**survey**

``` r

srs_sv <- svydesign(ids = ~1, fpc = ~fpc, weights = ~pw, data = apisrs)
srs_sv
```

    #> Independent Sampling design
    #> svydesign(ids = ~1, fpc = ~fpc, weights = ~pw, data = apisrs)

**srvyr**

``` r

srs_srvyr <- apisrs |> as_survey_design(ids = 1, fpc = fpc, weights = pw)
srs_srvyr
```

    #> Independent Sampling design
    #> Called via srvyr
    #> Sampling variables:
    #>   - ids: `1` 
    #>   - fpc: fpc 
    #>   - weights: pw 
    #> Data variables: 
    #>   - cds (chr), stype (fct), name (chr), sname (chr), snum (dbl), dname (chr),
    #>     dnum (int), cname (chr), cnum (int), flag (int), pcttest (int), api00
    #>     (int), api99 (int), target (int), growth (int), sch.wide (fct), comp.imp
    #>     (fct), both (fct), awards (fct), meals (int), ell (int), yr.rnd (fct),
    #>     mobility (int), acs.k3 (int), acs.46 (int), acs.core (int), pct.resp (int),
    #>     not.hsg (int), hsg (int), some.col (int), col.grad (int), grad.sch (int),
    #>     avg.ed (dbl), full (int), emer (int), enroll (int), api.stu (int), pw
    #>     (dbl), fpc (dbl)

**surveycore**

``` r

srs_sc <- surveycore::as_survey(apisrs, weights = pw, fpc = fpc)
srs_sc
```

    #> 

    #> ── Survey Design ───────────────────────────────────────────────────────────────

    #> <survey_taylor> (Taylor series linearization)

    #> Sample size: 200

    #> 

    #> # A tibble: 200 × 39
    #>    cds       stype name  sname  snum dname  dnum cname  cnum  flag pcttest api00
    #>    <chr>     <fct> <chr> <chr> <dbl> <chr> <int> <chr> <int> <int>   <int> <int>
    #>  1 15739081… H     "McF… McFa…  1039 McFa…   432 Kern     14    NA      98   462
    #>  2 19642126… E     "Sto… Stow…  1124 ABC …     1 Los …    18    NA     100   878
    #>  3 30664493… H     "Bre… Brea…  2868 Brea…    79 Oran…    29    NA      98   734
    #>  4 19644516… E     "Ala… Alam…  1273 Down…   187 Los …    18    NA      99   772
    #>  5 40688096… E     "Sun… Sunn…  4926 San …   640 San …    39    NA      99   739
    #>  6 19734456… E     "Los… Los …  2463 Haci…   284 Los …    18    NA      93   835
    #>  7 19647336… M     "Nor… Nort…  2031 Los …   401 Los …    18    NA      98   456
    #>  8 19647336… E     "Gla… Glas…  1736 Los …   401 Los …    18    NA      99   506
    #>  9 19648166… E     "Max… Maxs…  2142 Moun…   470 Los …    18    NA     100   543
    #> 10 38684786… E     "Tre… Trea…  4754 San …   632 San …    37    NA      90   649
    #> # ℹ 190 more rows
    #> # ℹ 27 more variables: api99 <int>, target <int>, growth <int>, sch.wide <fct>,
    #> #   comp.imp <fct>, both <fct>, awards <fct>, meals <int>, ell <int>,
    #> #   yr.rnd <fct>, mobility <int>, acs.k3 <int>, acs.46 <int>, acs.core <int>,
    #> #   pct.resp <int>, not.hsg <int>, hsg <int>, some.col <int>, col.grad <int>,
    #> #   grad.sch <int>, avg.ed <dbl>, full <int>, emer <int>, enroll <int>,
    #> #   api.stu <int>, pw <dbl>, fpc <dbl>

`ids = ~1` is `survey`’s idiom for “no clusters” — not immediately
obvious to new users.
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
without `ids` or `strata` creates an SRS design directly, making the
design type clear from context.

### 1.2 Stratified Design

`apistrat` is stratified by school type (`stype`: E = elementary, M =
middle, H = high school).

**survey**

``` r

strat_sv <- svydesign(
  ids = ~1, strata = ~stype, weights = ~pw, fpc = ~fpc, data = apistrat
)
strat_sv
```

    #> Stratified Independent Sampling design
    #> svydesign(ids = ~1, strata = ~stype, weights = ~pw, fpc = ~fpc, 
    #>     data = apistrat)

**srvyr**

``` r

strat_srvyr <- apistrat |>
  as_survey_design(strata = stype, weights = pw, fpc = fpc)
strat_srvyr
```

    #> Stratified Independent Sampling design
    #> Called via srvyr
    #> Sampling variables:
    #>   - ids: `1` 
    #>   - strata: stype 
    #>   - fpc: fpc 
    #>   - weights: pw 
    #> Data variables: 
    #>   - cds (chr), stype (fct), name (chr), sname (chr), snum (dbl), dname (chr),
    #>     dnum (int), cname (chr), cnum (int), flag (int), pcttest (int), api00
    #>     (int), api99 (int), target (int), growth (int), sch.wide (fct), comp.imp
    #>     (fct), both (fct), awards (fct), meals (int), ell (int), yr.rnd (fct),
    #>     mobility (int), acs.k3 (int), acs.46 (int), acs.core (int), pct.resp (int),
    #>     not.hsg (int), hsg (int), some.col (int), col.grad (int), grad.sch (int),
    #>     avg.ed (dbl), full (int), emer (int), enroll (int), api.stu (int), pw
    #>     (dbl), fpc (dbl)

**surveycore**

``` r

strat_sc <- surveycore::as_survey(apistrat, strata = stype, weights = pw, fpc = fpc)
strat_sc
```

    #> 

    #> ── Survey Design ───────────────────────────────────────────────────────────────

    #> <survey_taylor> (Taylor series linearization)

    #> Sample size: 200

    #> 

    #> # A tibble: 200 × 39
    #>    cds       stype name  sname  snum dname  dnum cname  cnum  flag pcttest api00
    #>    <chr>     <fct> <chr> <chr> <dbl> <chr> <int> <chr> <int> <int>   <int> <int>
    #>  1 19647336… E     Open… Open…  2077 Los …   401 Los …    18    NA      99   840
    #>  2 19647336… E     Belv… Belv…  1622 Los …   401 Los …    18    NA     100   516
    #>  3 19648816… E     Alta… Alta…  2236 Pasa…   541 Los …    18    NA      99   531
    #>  4 19647336… E     Soto… Soto…  1921 Los …   401 Los …    18    NA     100   501
    #>  5 56739406… E     Waln… Waln…  6140 Moor…   460 Vent…    55    NA     100   720
    #>  6 56726036… E     Athe… Athe…  6077 Simi…   689 Vent…    55    NA     100   805
    #>  7 56726036… E     Town… Town…  6071 Simi…   689 Vent…    55    NA      99   778
    #>  8 15633216… E     Thor… Thor…   904 Bake…    41 Kern     14    NA      98   731
    #>  9 37683956… E     Nico… Nico…  4637 Sout…   702 San …    36    NA     100   592
    #> 10 37680236… E     Vall… Vall…  4311 Chul…   135 San …    36    NA     100   669
    #> # ℹ 190 more rows
    #> # ℹ 27 more variables: api99 <int>, target <int>, growth <int>, sch.wide <fct>,
    #> #   comp.imp <fct>, both <fct>, awards <fct>, meals <int>, ell <int>,
    #> #   yr.rnd <fct>, mobility <int>, acs.k3 <int>, acs.46 <int>, acs.core <int>,
    #> #   pct.resp <int>, not.hsg <int>, hsg <int>, some.col <int>, col.grad <int>,
    #> #   grad.sch <int>, avg.ed <dbl>, full <int>, emer <int>, enroll <int>,
    #> #   api.stu <int>, pw <dbl>, fpc <dbl>

### 1.3 Cluster Design

`apiclus1` is a one-stage cluster sample with school districts (`dnum`)
as the primary sampling units.

**survey**

``` r

clus_sv <- svydesign(ids = ~dnum, fpc = ~fpc, weights = ~pw, data = apiclus1)
clus_sv
```

    #> 1 - level Cluster Sampling design
    #> With (15) clusters.
    #> svydesign(ids = ~dnum, fpc = ~fpc, weights = ~pw, data = apiclus1)

**srvyr**

``` r

clus_srvyr <- apiclus1 |>
  as_survey_design(ids = dnum, fpc = fpc, weights = pw)
clus_srvyr
```

    #> 1 - level Cluster Sampling design
    #> With (15) clusters.
    #> Called via srvyr
    #> Sampling variables:
    #>   - ids: dnum 
    #>   - fpc: fpc 
    #>   - weights: pw 
    #> Data variables: 
    #>   - cds (chr), stype (fct), name (chr), sname (chr), snum (dbl), dname (chr),
    #>     dnum (int), cname (chr), cnum (int), flag (int), pcttest (int), api00
    #>     (int), api99 (int), target (int), growth (int), sch.wide (fct), comp.imp
    #>     (fct), both (fct), awards (fct), meals (int), ell (int), yr.rnd (fct),
    #>     mobility (int), acs.k3 (int), acs.46 (int), acs.core (int), pct.resp (int),
    #>     not.hsg (int), hsg (int), some.col (int), col.grad (int), grad.sch (int),
    #>     avg.ed (dbl), full (int), emer (int), enroll (int), api.stu (int), fpc
    #>     (dbl), pw (dbl)

**surveycore**

``` r

clus_sc <- surveycore::as_survey(apiclus1, ids = dnum, fpc = fpc, weights = pw)
clus_sc
```

    #> 

    #> ── Survey Design ───────────────────────────────────────────────────────────────

    #> <survey_taylor> (Taylor series linearization)

    #> Sample size: 183

    #> 

    #> # A tibble: 183 × 39
    #>    cds       stype name  sname  snum dname  dnum cname  cnum  flag pcttest api00
    #>    <chr>     <fct> <chr> <chr> <dbl> <chr> <int> <chr> <int> <int>   <int> <int>
    #>  1 01612910… H     San … San …   236 San …   637 Alam…     1    NA      97   608
    #>  2 01612916… E     Garf… Garf…   237 San …   637 Alam…     1    NA     100   684
    #>  3 01612916… E     Jeff… Jeff…   238 San …   637 Alam…     1    NA     100   612
    #>  4 01612916… E     Madi… Madi…   239 San …   637 Alam…     1    NA     100   710
    #>  5 01612916… E     McKi… McKi…   240 San …   637 Alam…     1    NA      99   729
    #>  6 01612916… E     Monr… Monr…   241 San …   637 Alam…     1    NA     100   714
    #>  7 01612916… E     Roos… Roos…   242 San …   637 Alam…     1    NA      99   759
    #>  8 01612916… E     Wash… Wash…   243 San …   637 Alam…     1    NA      99   585
    #>  9 01612916… E     Wils… Wils…   244 San …   637 Alam…     1    NA     100   625
    #> 10 01612916… M     Banc… Banc…   245 San …   637 Alam…     1    NA     100   664
    #> # ℹ 173 more rows
    #> # ℹ 27 more variables: api99 <int>, target <int>, growth <int>, sch.wide <fct>,
    #> #   comp.imp <fct>, both <fct>, awards <fct>, meals <int>, ell <int>,
    #> #   yr.rnd <fct>, mobility <int>, acs.k3 <int>, acs.46 <int>, acs.core <int>,
    #> #   pct.resp <int>, not.hsg <int>, hsg <int>, some.col <int>, col.grad <int>,
    #> #   grad.sch <int>, avg.ed <dbl>, full <int>, emer <int>, enroll <int>,
    #> #   api.stu <int>, fpc <dbl>, pw <dbl>

### 1.4 Replicate Weights

Replicate weights are common in government surveys like the ACS PUMS (80
successive-difference replicates) and Pew’s Jewish Americans Study (100
JK1 replicates). Both datasets are bundled with surveycore.

The key interface difference: `survey` selects replicate columns with a
raw regex string; surveycore uses tidyselect — the same composable
selection language used throughout the tidyverse.

**ACS PUMS Wyoming — successive-difference replicates**

``` r

acs_sv <- svrepdesign(
  data             = acs_pums_wy,
  weights          = ~pwgtp,
  repweights       = "pwgtp[0-9]+",   # regex string
  type             = "successive-difference",
  combined.weights = TRUE
)
acs_sv
```

    #> Call: svrepdesign.default(data = acs_pums_wy, weights = ~pwgtp, repweights = "pwgtp[0-9]+", 
    #>     type = "successive-difference", combined.weights = TRUE)
    #> Successive difference with 80 replicates.

``` r

acs_srvyr <- acs_pums_wy |>
  as_survey_rep(
    weights          = pwgtp,
    repweights       = matches("^pwgtp[0-9]+$"), # tidyselect
    type             = "successive-difference",
    combined_weights = TRUE
  )
acs_srvyr
```

    #> Call: Called via srvyr
    #> Successive difference with 80 replicates.
    #> Sampling variables:
    #>   - repweights: `pwgtp1 + pwgtp2 + pwgtp3 + pwgtp4 + pwgtp5 + pwgtp6 + pwgtp7 +
    #>     pwgtp8 + pwgtp9 + pwgtp10 + pwgtp11 + pwgtp12 + pwgtp13 + pwgtp14 + pwgtp15
    #>     + pwgtp16 + pwgtp17 + pwgtp18 + pwgtp19 + pwgtp20 + pwgtp21 + pwgtp22 +
    #>     pwgtp23 + pwgtp24 + pwgtp25 + pwgtp26 + pwgtp27 + pwgtp28 + pwgtp29 +
    #>     pwgtp30 + pwgtp31 + pwgtp32 + pwgtp33 + pwgtp34 + pwgtp35 + pwgtp36 +
    #>     pwgtp37 + pwgtp38 + pwgtp39 + pwgtp40 + pwgtp41 + pwgtp42 + pwgtp43 +
    #>     pwgtp44 + pwgtp45 + pwgtp46 + pwgtp47 + pwgtp48 + pwgtp49 + pwgtp50 +
    #>     pwgtp51 + pwgtp52 + pwgtp53 + pwgtp54 + pwgtp55 + pwgtp56 + pwgtp57 +
    #>     pwgtp58 + pwgtp59 + pwgtp60 + pwgtp61 + pwgtp62 + pwgtp63 + pwgtp64 +
    #>     pwgtp65 + pwgtp66 + pwgtp67 + pwgtp68 + pwgtp69 + pwgtp70 + pwgtp71 +
    #>     pwgtp72 + pwgtp73 + pwgtp74 + pwgtp75 + pwgtp76 + pwgtp77 + pwgtp78 +
    #>     pwgtp79 + pwgtp80` 
    #>   - weights: pwgtp 
    #> Data variables: 
    #>   - puma (int), st (int), pwgtp (int), pwgtp1 (int), pwgtp2 (int), pwgtp3
    #>     (int), pwgtp4 (int), pwgtp5 (int), pwgtp6 (int), pwgtp7 (int), pwgtp8
    #>     (int), pwgtp9 (int), pwgtp10 (int), pwgtp11 (int), pwgtp12 (int), pwgtp13
    #>     (int), pwgtp14 (int), pwgtp15 (int), pwgtp16 (int), pwgtp17 (int), pwgtp18
    #>     (int), pwgtp19 (int), pwgtp20 (int), pwgtp21 (int), pwgtp22 (int), pwgtp23
    #>     (int), pwgtp24 (int), pwgtp25 (int), pwgtp26 (int), pwgtp27 (int), pwgtp28
    #>     (int), pwgtp29 (int), pwgtp30 (int), pwgtp31 (int), pwgtp32 (int), pwgtp33
    #>     (int), pwgtp34 (int), pwgtp35 (int), pwgtp36 (int), pwgtp37 (int), pwgtp38
    #>     (int), pwgtp39 (int), pwgtp40 (int), pwgtp41 (int), pwgtp42 (int), pwgtp43
    #>     (int), pwgtp44 (int), pwgtp45 (int), pwgtp46 (int), pwgtp47 (int), pwgtp48
    #>     (int), pwgtp49 (int), pwgtp50 (int), pwgtp51 (int), pwgtp52 (int), pwgtp53
    #>     (int), pwgtp54 (int), pwgtp55 (int), pwgtp56 (int), pwgtp57 (int), pwgtp58
    #>     (int), pwgtp59 (int), pwgtp60 (int), pwgtp61 (int), pwgtp62 (int), pwgtp63
    #>     (int), pwgtp64 (int), pwgtp65 (int), pwgtp66 (int), pwgtp67 (int), pwgtp68
    #>     (int), pwgtp69 (int), pwgtp70 (int), pwgtp71 (int), pwgtp72 (int), pwgtp73
    #>     (int), pwgtp74 (int), pwgtp75 (int), pwgtp76 (int), pwgtp77 (int), pwgtp78
    #>     (int), pwgtp79 (int), pwgtp80 (int), agep (int), sex (int), rac1p (int),
    #>     hisp (int), schl (int), esr (int), pincp (int), wagp (int), hicov (int),
    #>     dis (int), povpip (int), wkhp (int), adjinc (int)

``` r

acs_sc <- as_survey_replicate(
  acs_pums_wy,
  weights    = pwgtp,
  repweights = tidyselect::matches("^pwgtp[0-9]+$"), # tidyselect
  type       = "successive-difference"
)
acs_sc
```

    #> 

    #> ── Survey Design ───────────────────────────────────────────────────────────────

    #> <survey_replicate> (SUCCESSIVE-DIFFERENCE, 80 replicates)

    #> Sample size: 5962

    #> 

    #> # A tibble: 5,962 × 96
    #>     puma    st pwgtp pwgtp1 pwgtp2 pwgtp3 pwgtp4 pwgtp5 pwgtp6 pwgtp7 pwgtp8
    #>    <int> <int> <int>  <int>  <int>  <int>  <int>  <int>  <int>  <int>  <int>
    #>  1   500    56    25     24     28     20     24     27     26     27     25
    #>  2   400    56   128    158    145    133    141    133    128    124    116
    #>  3   200    56   121    104     93    121     97     94    146    169    147
    #>  4   300    56    24      0     22     41      0      5     43     24     20
    #>  5   500    56    26     31     33     28     32     29     26     28     27
    #>  6   300    56    25     26      0     24      0     25     24      0     22
    #>  7   300    56    91     85     93     80     80     99    100     97     96
    #>  8   500    56    20     21     19     36     23     32     16     20     43
    #>  9   500    56   132    138    143    138    143    151    150    134    144
    #> 10   100    56    89    113     83    146     71     76    141    117     10
    #> # ℹ 5,952 more rows
    #> # ℹ 85 more variables: pwgtp9 <int>, pwgtp10 <int>, pwgtp11 <int>,
    #> #   pwgtp12 <int>, pwgtp13 <int>, pwgtp14 <int>, pwgtp15 <int>, pwgtp16 <int>,
    #> #   pwgtp17 <int>, pwgtp18 <int>, pwgtp19 <int>, pwgtp20 <int>, pwgtp21 <int>,
    #> #   pwgtp22 <int>, pwgtp23 <int>, pwgtp24 <int>, pwgtp25 <int>, pwgtp26 <int>,
    #> #   pwgtp27 <int>, pwgtp28 <int>, pwgtp29 <int>, pwgtp30 <int>, pwgtp31 <int>,
    #> #   pwgtp32 <int>, pwgtp33 <int>, pwgtp34 <int>, pwgtp35 <int>, …

**Pew Jewish Americans 2020 — JK1 jackknife replicates**

``` r

pew_sc <- as_survey_replicate(
  pew_jewish_2020,
  weights    = extweight,
  repweights = extweight1:extweight100,
  type       = "JK1"
)
pew_sc
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

### 1.5 Calibrated / Non-Probability Samples

`ns_wave1` is the Nationscape Wave 1 survey — a non-probability quota
panel with raking weights calibrated to ACS demographics and 2016 vote.

`survey` and `srvyr` have no dedicated constructor for calibrated or
non-probability designs. The design intent is lost in the code:

``` r

# No way to signal this is calibrated or non-probability
ns_sv <- svydesign(ids = ~1, weights = ~weight, data = ns_wave1)
```

``` r

ns_srvyr <- ns_wave1 |> as_survey_design(weights = weight)
```

``` r

# as_survey_nonprob() makes the design type explicit
ns_sc <- as_survey_nonprob(ns_wave1, weights = weight)
ns_sc
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

[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md)
preserves the distinction in code, output, and documentation. Standard
errors are approximate — they assume the calibration weights produce
approximately correct variance estimates ([Elliott and Valliant
2017](#ref-elliott2017)).

### 1.6 Two-Phase Designs

Two-phase designs are uncommon. surveycore’s
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)
matches
[`survey::twophase()`](https://rdrr.io/pkg/survey/man/twophase.html) for
the Breslow-Cain variance estimator ([Breslow and Cain
1988](#ref-breslow1988)). For a full worked example using
[`survival::nwtco`](https://rdrr.io/pkg/survival/man/nwtco.html), see
[`vignette("creating-survey-objects")`](https://jdenn0514.github.io/surveycore/articles/creating-survey-objects.md).

### 1.7 Constructor Summary

| Design | survey | srvyr | surveycore |
|----|----|----|----|
| SRS | `svydesign(ids=~1, ...)` | `as_survey_design(ids=1, ...)` | `as_survey(...)` (no `ids`/`strata`) |
| Stratified | `svydesign(strata=~s, ...)` | `as_survey_design(strata=s, ...)` | `as_survey(..., strata=s)` |
| Cluster | `svydesign(ids=~d, ...)` | `as_survey_design(ids=d, ...)` | `as_survey(..., ids=d)` |
| Replicate wts | `svrepdesign(repweights="regex")` | `as_survey_rep(repweights=matches(...))` | `as_survey_replicate(repweights=matches(...))` |
| Calibrated/NPS | `svydesign(ids=~1, weights=~w)` ⚠ | `as_survey_design(weights=w)` ⚠ | `as_survey_nonprob(...)` |
| Two-phase | `twophase(...)` | `as_survey_twophase(...)` | `as_survey_twophase(...)` |

⚠ No dedicated non-probability constructor — design intent is not
preserved.

------------------------------------------------------------------------

## 2. Summary Statistics

The sections below use `ns_sc` (already created above) alongside the
equivalent `survey` and `srvyr` designs. The **label contrast** — raw
integer codes in `survey`/`srvyr` vs. human-readable labels in
surveycore — is the recurring theme. `ns_wave1` was imported with
`haven` labels intact; surveycore resolves them automatically.

### 2.1 Weighted Means (Grouped)

Estimated discrimination experienced by Black Americans, broken out by
party identification (`pid3`).

**survey** — group values appear as raw codes (1, 2, 3, 4)

``` r

svyby(~discrimination_blacks, ~pid3, ns_sv, svymean, na.rm = TRUE)
```

    #>   pid3 discrimination_blacks         se
    #> 1    1              1.827663 0.03845797
    #> 2    2              3.044733 0.04709251
    #> 3    3              2.517407 0.05141302
    #> 4    4              2.360898 0.09929886

**srvyr** — also raw codes unless `pid3` is manually factored first

``` r

ns_srvyr |>
  group_by(pid3) |>
  summarise(m = survey_mean(discrimination_blacks, vartype = "ci", na.rm = TRUE))
```

    #> # A tibble: 5 × 4
    #>    pid3     m m_low m_upp
    #>   <dbl> <dbl> <dbl> <dbl>
    #> 1     1  1.83 1.75   1.90
    #> 2     2  3.04 2.95   3.14
    #> 3     3  2.52 2.42   2.62
    #> 4     4  2.36 2.17   2.56
    #> 5    NA  1.17 0.814  1.53

**surveycore** — “Democrat”, “Republican”, “Independent”, “Something
else” from the haven labels, automatically

``` r

get_means(ns_sc, discrimination_blacks, group = pid3)
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

    #> # A tibble: 4 × 5
    #>   pid3            mean ci_low ci_high     n
    #>   <fct>          <dbl>  <dbl>   <dbl> <int>
    #> 1 Democrat        1.83   1.75    1.90  2272
    #> 2 Republican      3.04   2.95    3.14  1805
    #> 3 Independent     2.52   2.42    2.62  1856
    #> 4 Something else  2.36   2.17    2.56   427

### 2.2 Proportions / Frequency Tables

Distribution of willingness to consider voting for Trump
(`consider_trump`).

**survey** — `svymean()` on a factor produces column names like
`consider_trump1`, `consider_trump2`, `consider_trump999`

``` r

svymean(~factor(consider_trump), ns_sv, na.rm = TRUE)
```

    #>                              mean     SE
    #> factor(consider_trump)1   0.32052 0.0102
    #> factor(consider_trump)2   0.55475 0.0110
    #> factor(consider_trump)999 0.12473 0.0075

**srvyr**

``` r

ns_srvyr |>
  group_by(consider_trump) |>
  summarise(pct = survey_mean(na.rm = TRUE))
```

    #> Warning: There was 1 warning in `dplyr::summarise()`.
    #> ℹ In argument: `pct = survey_mean(na.rm = TRUE)`.
    #> ℹ In group 1: `consider_trump = 1`.
    #> Caused by warning:
    #> ! na.rm argument has no effect on survey_mean when calculating grouped proportions. 
    #> This warning is displayed once per session.

    #> # A tibble: 4 × 3
    #>   consider_trump     pct  pct_se
    #>            <dbl>   <dbl>   <dbl>
    #> 1              1 0.320   0.0102 
    #> 2              2 0.553   0.0110 
    #> 3            999 0.124   0.00744
    #> 4             NA 0.00276 0.00134

**surveycore** — `consider_trump` column shows “Yes”, “No”, “Don’t know”

``` r

get_freqs(ns_sc, consider_trump)
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

### 2.3 Population Totals

`ns_wave1` uses calibration weights scaled to the sample size (weights
sum to 6,422 — the number of respondents).
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md)
with no variable argument returns the estimated population size — here,
it confirms the calibration:

**survey** — `svytotal(~1, design)` is not supported; the sum of weights
gives the estimated N, and `svytotal()` requires a real variable

``` r

sum(weights(ns_sv))                         # estimated population N
```

    #> [1] 6422

``` r

svytotal(~age, ns_sv, na.rm = TRUE)         # total of a continuous variable
```

    #>      total     SE
    #> age 302835 6025.5

**srvyr** — `survey_total(1)` computes estimated N

``` r

ns_srvyr |> summarise(n_pop = survey_total(1))       # estimated N
```

    #> # A tibble: 1 × 2
    #>   n_pop n_pop_se
    #>   <dbl>    <dbl>
    #> 1  6422     117.

``` r

ns_srvyr |> summarise(age_total = survey_total(age, na.rm = TRUE))
```

    #> # A tibble: 1 × 2
    #>   age_total age_total_se
    #>       <dbl>        <dbl>
    #> 1   302835.        6025.

**surveycore**

``` r

get_totals(ns_sc)           # estimated N (no x argument)
```

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 1 × 3
    #>   total ci_low ci_high
    #>   <dbl>  <dbl>   <dbl>
    #> 1  6422  6192.   6652.

``` r

get_totals(ns_sc, age)      # total of a continuous variable
```

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 1 × 4
    #>     total  ci_low ci_high     n
    #>     <dbl>   <dbl>   <dbl> <int>
    #> 1 302835. 291026. 314645.  6422

For a design with probability weights that sum to the actual population
(like the Pew Jewish Americans study),
[`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md)
returns the estimated population count in millions:

``` r

get_totals(pew_sc)
```

    #> # A tibble: 1 × 3
    #>      total   ci_low  ci_high
    #>      <dbl>    <dbl>    <dbl>
    #> 1 9971358. 9971322. 9971394.

### 2.4 Quantiles

Weighted age distribution of Nationscape respondents.

**survey**

``` r

svyquantile(~age, ns_sv, quantiles = c(0.25, 0.5, 0.75), na.rm = TRUE)
```

    #> $age
    #>      quantile ci.2.5 ci.97.5        se
    #> 0.25       32     31      34 0.7651759
    #> 0.5        47     46      49 0.7651759
    #> 0.75       62     62      63 0.2550586
    #> 
    #> attr(,"hasci")
    #> [1] TRUE
    #> attr(,"class")
    #> [1] "newsvyquantile"

**srvyr**

``` r

ns_srvyr |>
  summarise(q = survey_quantile(age, c(0.25, 0.5, 0.75), na.rm = TRUE))
```

    #> # A tibble: 1 × 6
    #>   q_q25 q_q50 q_q75 q_q25_se q_q50_se q_q75_se
    #>   <dbl> <dbl> <dbl>    <dbl>    <dbl>    <dbl>
    #> 1    32    47    62    0.765    0.765    0.255

**surveycore** — Woodruff (1952) confidence intervals, guaranteed to
respect the data range

``` r

get_quantiles(ns_sc, age)
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

### 2.5 Ratios

`api00` / `api99` is a natural ratio: Academic Performance Index in 2000
relative to 1999. We use `apisrs` here because it provides a clear
probability design where the ratio estimator is unambiguous.

**survey** — positional argument order requires knowing which formula is
numerator vs. denominator

``` r

svyratio(~api00, ~api99, srs_sv)
```

    #> Ratio estimator: svyratio.survey.design2(~api00, ~api99, srs_sv)
    #> Ratios=
    #>          api99
    #> api00 1.051066
    #> SEs=
    #>             api99
    #> api00 0.003603991

**srvyr**

``` r

srs_srvyr |> summarise(ratio = survey_ratio(api00, api99))
```

    #> # A tibble: 1 × 2
    #>   ratio ratio_se
    #>   <dbl>    <dbl>
    #> 1  1.05  0.00360

**surveycore** — named arguments make direction self-documenting

``` r

get_ratios(srs_sc, numerator = api00, denominator = api99)
```

    #> # A tibble: 1 × 4
    #>   ratio ci_low ci_high     n
    #>   <dbl>  <dbl>   <dbl> <int>
    #> 1  1.05   1.04    1.06   200

`numerator =` / `denominator =` remove the ambiguity present in
`svyratio(~y, ~x, design)`.

### 2.6 Correlations

Pearson correlation between Trump and Biden favorability
(`cand_favorability_*` is a 1–4 scale; 999 codes respondents who haven’t
heard enough — filtered below).

``` r

# Pre-filter non-substantive responses before creating the design
ns_corr <- ns_wave1[
  !is.na(ns_wave1$cand_favorability_trump) &
    ns_wave1$cand_favorability_trump != 999 &
    !is.na(ns_wave1$cand_favorability_biden) &
    ns_wave1$cand_favorability_biden != 999,
]
ns_corr_sc <- as_survey_nonprob(ns_corr, weights = weight)
```

**survey** — matrix output, no confidence intervals

``` r

ns_corr_sv <- svydesign(ids = ~1, weights = ~weight, data = ns_corr)
jtools::svycor(~cand_favorability_trump + cand_favorability_biden, ns_corr_sv)
```

    #>                         cand_favorability_trump cand_favorability_biden
    #> cand_favorability_trump                    1.00                   -0.49
    #> cand_favorability_biden                   -0.49                    1.00

**srvyr** — no dedicated `survey_corr()` verb; users must fall back to
`survey`

**surveycore** — long tibble with Fisher-Z confidence intervals (bounds
guaranteed in \[−1, 1\])

``` r

get_corr(ns_corr_sc, c(cand_favorability_trump, cand_favorability_biden))
```

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 1 × 9
    #>   var1         var2           r ci_low ci_high p_value statistic    df     n
    #>   <fct>        <fct>      <dbl>  <dbl>   <dbl>   <dbl>     <dbl> <int> <int>
    #> 1 Donald Trump Joe Biden -0.495 -0.524  -0.464       0     -41.3  5276  5278

`svycor()` returns a matrix with no CIs.
[`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md)
returns a tidy tibble with Fisher-Z confidence intervals. srvyr has no
`survey_corr()` verb at all — users fall back to `survey` directly.

------------------------------------------------------------------------

## 3. Controlling Uncertainty Output

All surveycore analysis functions share a `variance` argument that
controls which uncertainty columns appear. In `survey`, you call a
separate function per metric. In `srvyr`, you repeat the `summarise()`
call for each type.

**survey** — separate call per uncertainty type

``` r

m <- svymean(~age, ns_sv, na.rm = TRUE)
m                      # SE only in the estimate
```

    #>       mean     SE
    #> age 47.156 0.3956

``` r

confint(m)             # CI — separate call
```

    #>        2.5 %   97.5 %
    #> age 46.38062 47.93123

``` r

cv(m)                  # CV — separate call
```

    #>             age
    #> age 0.008388587

``` r

svymean(~age, ns_sv, deff = TRUE, na.rm = TRUE) # DEFF — different return structure
```

    #>         mean       SE DEff
    #> age 47.15593  0.39557  Inf

**srvyr** — one call per type; the variable is estimated multiple times

``` r

ns_srvyr |>
  summarise(
    m_se   = survey_mean(age, vartype = "se",   na.rm = TRUE),
    m_ci   = survey_mean(age, vartype = "ci",   na.rm = TRUE),
    m_cv   = survey_mean(age, vartype = "cv",   na.rm = TRUE),
    m_deff = survey_mean(age, deff = TRUE,      na.rm = TRUE)
  )
```

    #> # A tibble: 1 × 10
    #>    m_se m_se_se  m_ci m_ci_low m_ci_upp  m_cv m_cv_cv m_deff m_deff_se
    #>   <dbl>   <dbl> <dbl>    <dbl>    <dbl> <dbl>   <dbl>  <dbl>     <dbl>
    #> 1  47.2   0.396  47.2     46.4     47.9  47.2 0.00839   47.2     0.396
    #> # ℹ 1 more variable: m_deff_deff <dbl>

**surveycore** — one call, any combination of metrics

``` r

get_means(ns_sc, age, variance = c("se", "ci", "cv", "deff"))
```

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 1 × 7
    #>    mean    se      cv ci_low ci_high  deff     n
    #>   <dbl> <dbl>   <dbl>  <dbl>   <dbl> <dbl> <int>
    #> 1  47.2 0.396 0.00839   46.4    47.9  3.47  6422

Set `variance = NULL` to return point estimates and sample counts only:

``` r

get_means(ns_sc, age, variance = NULL)
```

    #> Warning: ! <survey_nonprob> object has no bootstrap replicate weights. Standard errors
    #>   use an SRS approximation that underestimates calibration uncertainty.
    #> ℹ Run `surveywts::create_bootstrap_weights()` on this design for correct SEs.

    #> # A tibble: 1 × 2
    #>    mean     n
    #>   <dbl> <int>
    #> 1  47.2  6422

Available `variance` codes:

| Code     | What it returns                          |
|----------|------------------------------------------|
| `"se"`   | Standard error                           |
| `"ci"`   | Confidence interval: `ci_low`, `ci_high` |
| `"var"`  | Variance (SE²)                           |
| `"cv"`   | Coefficient of variation (SE / estimate) |
| `"moe"`  | Margin of error at `conf_level`          |
| `"deff"` | Design effect (complex / SRS variance)   |

The `conf_level` argument controls the level for `"ci"` and `"moe"`.
Default is `0.95`; for a 90% interval:
`get_means(ns_sc, age, conf_level = 0.9)`.

------------------------------------------------------------------------

## 4. Features With No survey / srvyr Equivalent

### 4.1 Automatic Value Labels

`ns_wave1` was imported with `haven` labels intact. surveycore resolves
them automatically — no manual recoding required.

**survey / srvyr** — group column values are raw integer codes

``` r

# pid3 values: 1, 2, 3, 4 — the reader must consult the codebook
svyby(~discrimination_blacks, ~pid3, ns_sv, svymean, na.rm = TRUE)
```

    #>   pid3 discrimination_blacks         se
    #> 1    1              1.827663 0.03845797
    #> 2    2              3.044733 0.04709251
    #> 3    3              2.517407 0.05141302
    #> 4    4              2.360898 0.09929886

**surveycore** — “Democrat”, “Republican”, “Independent”, “Something
else”

``` r

get_means(ns_sc, discrimination_blacks, group = pid3)
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

    #> # A tibble: 4 × 5
    #>   pid3            mean ci_low ci_high     n
    #>   <fct>          <dbl>  <dbl>   <dbl> <int>
    #> 1 Democrat        1.83   1.75    1.90  2272
    #> 2 Republican      3.04   2.95    3.14  1805
    #> 3 Independent     2.52   2.42    2.62  1856
    #> 4 Something else  2.36   2.17    2.56   427

Opt out with `label_values = FALSE` to see raw codes:

``` r

get_means(ns_sc, discrimination_blacks, group = pid3, label_values = FALSE)
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

    #> # A tibble: 4 × 5
    #>    pid3  mean ci_low ci_high     n
    #>   <dbl> <dbl>  <dbl>   <dbl> <int>
    #> 1     1  1.83   1.75    1.90  2272
    #> 2     2  3.04   2.95    3.14  1805
    #> 3     3  2.52   2.42    2.62  1856
    #> 4     4  2.36   2.17    2.56   427

### 4.2 Multiple Variables in One Call

`ns_wave1` includes a battery of 13 news source items
(`news_sources_facebook`, `news_sources_cnn`, …, `news_sources_other`).
Analyzing all at once requires a loop in `survey` and `srvyr`;
surveycore stacks them in a single call.

**survey / srvyr** — must loop; output is a list that the user binds
manually

``` r

news_vars <- c(
  "news_sources_facebook", "news_sources_cnn", "news_sources_fox",
  "news_sources_npr", "news_sources_new_york_times"
)
results_sv <- lapply(news_vars, function(v) {
  f <- as.formula(paste0("~", v))
  svymean(f, ns_sv, na.rm = TRUE)
})
# Results are a list — user must bind rows and add a name column manually
do.call(rbind, lapply(seq_along(results_sv), function(i) {
  data.frame(name = news_vars[[i]], coef(results_sv[[i]]))
}))
```

    #>                                                    name coef.results_sv..i...
    #> news_sources_facebook             news_sources_facebook              1.384971
    #> news_sources_cnn                       news_sources_cnn              1.599659
    #> news_sources_fox                       news_sources_fox              1.639275
    #> news_sources_npr                       news_sources_npr              1.862283
    #> news_sources_new_york_times news_sources_new_york_times              1.727273

**surveycore** — one call; a `name` column identifies each item;
variable labels are applied automatically

``` r

get_freqs(
  ns_sc,
  c(news_sources_facebook:news_sources_other)
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

### 4.3 Minimum Cell Size Warnings

`survey` and `srvyr` return estimates for tiny cells silently — the user
may not notice that a group has only 8 respondents. surveycore warns
when any unweighted cell count falls below `min_cell_n` (default: 30).

``` r

# Construct a design with deliberately small cells
small_df <- data.frame(
  group = rep(c("A", "B", "C"), c(8, 15, 200)),
  x     = rnorm(223),
  w     = 1
)
small_svy <- surveycore::as_survey(small_df, weights = w)

get_means(small_svy, x, group = group)
```

    #> Warning: ! 2 cells have fewer than 30 unweighted observations. Estimates in these cells
    #>   may be unreliable for public reporting (AAPOR guidance).

    #> # A tibble: 3 × 5
    #>   group   mean  ci_low ci_high     n
    #>   <chr>  <dbl>   <dbl>   <dbl> <int>
    #> 1 A     -0.486 -1.31     0.335     8
    #> 2 B     -0.186 -0.683    0.312    15
    #> 3 C      0.105 -0.0377   0.248   200

Suppress the warning when small cells are expected:

``` r

get_means(small_svy, x, group = group, min_cell_n = 0L)
```

### 4.4 Weighted Sample Size

In `survey` and `srvyr`, getting both the unweighted and estimated
population count for each cell requires a separate `svytotal(~1, ...)`
call. surveycore adds it with one argument:

**survey** — extra call for weighted N

``` r

# Proportions by group (unweighted n not shown in output)
svyby(~factor(consider_trump), ~pid3, ns_sv, svymean, na.rm = TRUE)
```

    #>   pid3 factor(consider_trump)1 factor(consider_trump)2
    #> 1    1               0.0500996               0.8873073
    #> 2    2               0.7749952               0.1281248
    #> 3    3               0.2384136               0.5662499
    #> 4    4               0.2090438               0.5703057
    #>   factor(consider_trump)999 se.factor(consider_trump)1
    #> 1                0.06259312                0.007599112
    #> 2                0.09688000                0.017249294
    #> 3                0.19533655                0.017201021
    #> 4                0.22065055                0.033161961
    #>   se.factor(consider_trump)2 se.factor(consider_trump)999
    #> 1                 0.01183081                  0.009518794
    #> 2                 0.01417166                  0.011797172
    #> 3                 0.02051542                  0.016804745
    #> 4                 0.03924281                  0.033059895

``` r

# Estimated weighted N per group — requires a separate call
svyby(~as.numeric(!is.na(consider_trump)), ~pid3, ns_sv, svytotal, na.rm = TRUE)
```

    #>   pid3 as.numeric(!is.na(consider_trump))       se
    #> 1    1                           2198.163 78.10298
    #> 2    2                           1784.745 69.80846
    #> 3    3                           1874.555 74.13607
    #> 4    4                            538.104 41.74667

**surveycore** — one argument

``` r

get_freqs(ns_sc, consider_trump, group = pid3, n_weighted = TRUE)
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

    #> # A tibble: 12 × 5
    #>    pid3           consider_trump    pct     n n_weighted
    #>    <fct>          <fct>           <dbl> <int>      <dbl>
    #>  1 Democrat       Yes            0.0501   136       110.
    #>  2 Democrat       No             0.887   2042      1950.
    #>  3 Democrat       Don't know     0.0626   111       138.
    #>  4 Republican     Yes            0.775   1403      1383.
    #>  5 Republican     No             0.128    227       229.
    #>  6 Republican     Don't know     0.0969   183       173.
    #>  7 Independent    Yes            0.238    475       447.
    #>  8 Independent    No             0.566   1071      1061.
    #>  9 Independent    Don't know     0.195    316       366.
    #> 10 Something else Yes            0.209     73       112.
    #> 11 Something else No             0.570    272       307.
    #> 12 Something else Don't know     0.221     91       119.

The `n_weighted` column is the sum of weights within each cell — the
estimated population size that cell represents.

### 4.5 Metadata-Rich Results (`.meta`)

surveycore attaches a `.meta` attribute to every result tibble. It
contains the variable label, value labels, and question preface for each
focal and grouping variable — everything needed to build a
publication-ready table without consulting the codebook separately.

``` r

result <- get_means(ns_sc, discrimination_blacks, group = pid3)
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

``` r

# Variable label for the focal variable
attr(result, ".meta")$x$discrimination_blacks$variable_label
```

    #> [1] "Blacks"

``` r

# Value labels for the grouping variable
attr(result, ".meta")$group$pid3$value_labels
```

    #>       Democrat     Republican    Independent Something else 
    #>              1              2              3              4

In `survey` and `srvyr`, metadata is not attached to results — label
information is lost after estimation.

------------------------------------------------------------------------

## 5. Notable Differences

|  | survey | srvyr | surveycore |
|----|----|----|----|
| **Output format** | S3 `svystat` / matrix | Tibble with `_se`/`_low`/`_upp` suffix columns | S3 tibble subclass with CI columns by default |
| **Interface** | `~formula` throughout | Mixed: tidy constructor, formula in `summarise()` | Bare names throughout (tidy-select) |
| **Value labels** | Not applied | Not applied | Applied automatically from `haven` attributes |
| **Multiple variables** | Loop required | Loop required | `c(x, y, z)` in one call |
| **Min-cell warning** | None | None | Default `min_cell_n = 30L` |
| **Weighted N** | Separate call | Separate call | `n_weighted = TRUE` |
| **Correlation CIs** | None (`svycor()`) | No verb | Fisher-Z CIs via [`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md) |
| **Non-probability design** | No dedicated constructor | No dedicated constructor | [`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md) |
| **Manipulation** | Pre/post construction | Bundled via pipe | `surveytidy` (companion package) |
| **Runtime `survey` dep.** | Is `survey` | Wraps `survey` | Vendored — `survey` not required |

------------------------------------------------------------------------

## 6. Function Reference Table

| Task | survey | srvyr | surveycore |
|----|----|----|----|
| SRS design | `svydesign(ids=~1, ...)` | `as_survey_design(ids=1, ...)` | `as_survey(...)` (no `ids`/`strata`) |
| Stratified design | `svydesign(strata=~s, ...)` | `as_survey_design(strata=s, ...)` | `as_survey(..., strata=s)` |
| Cluster design | `svydesign(ids=~d, ...)` | `as_survey_design(ids=d, ...)` | `as_survey(..., ids=d)` |
| Replicate weights | `svrepdesign(repweights="regex")` | `as_survey_rep(repweights=matches(...))` | `as_survey_replicate(repweights=matches(...))` |
| Calibrated/NPS | `svydesign(weights=~w)` ⚠ | `as_survey_design(weights=w)` ⚠ | `as_survey_nonprob(...)` |
| Two-phase | `twophase(...)` | `as_survey_twophase(...)` | `as_survey_twophase(...)` |
| Weighted mean | `svymean(~x, d)` | `summarise(survey_mean(x))` | `get_means(d, x)` |
| Grouped mean | `svyby(~x, ~g, d, svymean)` | `group_by(g) \|> summarise(...)` | `get_means(d, x, group=g)` |
| Proportions | `svymean(~factor(x), d)` | `group_by(x) \|> summarise(survey_mean())` | `get_freqs(d, x)` |
| Total | `svytotal(~x, d)` | `summarise(survey_total(x))` | `get_totals(d, x)` |
| Population N | `svytotal(~1, d)` | `summarise(survey_total(1))` | `get_totals(d)` |
| Quantiles | `svyquantile(~x, d, q)` | `summarise(survey_quantile(x, q))` | `get_quantiles(d, x, probs=q)` |
| Ratio | `svyratio(~y, ~x, d)` | `summarise(survey_ratio(y, x))` | `get_ratios(d, numerator=y, denominator=x)` |
| Correlation | `svycor(~x+y, d)` ⚠ no CI | ✗ no verb | `get_corr(d, c(x, y))` with CI |
| Multiple variables | Loop + bind | Loop + bind | `get_means(d, c(x, y, z))` |
| Value labels | Manual recode | Manual recode | `label_values = TRUE` (default) |
| Min-cell warning | ✗ | ✗ | `min_cell_n = 30L` (default) |
| Weighted N | Separate call | Separate call | `n_weighted = TRUE` |
| Domain filter | `subset(d, cond)` | `filter(cond)` | `filter(cond)` (`surveytidy`) |
| Mutate | Modify df, recreate | `mutate(...)` | `mutate(...)` (`surveytidy`) |
| Group by | `svyby(...)` | `group_by(...)` | `group_by(...)` (`surveytidy`) or `group=` arg |

⚠ = partial / workaround; ✗ = no equivalent

------------------------------------------------------------------------

## 7. Learning More

- [`vignette("getting-started")`](https://jdenn0514.github.io/surveycore/articles/getting-started.md)
  — full surveycore overview with worked examples
- [`vignette("creating-survey-objects")`](https://jdenn0514.github.io/surveycore/articles/creating-survey-objects.md)
  — all five constructors, including two-phase designs and the `nest`
  argument
- [srvyr comparison vignette](https://CRAN.R-project.org/package=srvyr)
  — the original side-by-side that this vignette is modeled on
- Lumley ([2010](#ref-lumley2010)) — the definitive reference on complex
  survey analysis in R

Breslow, Norman E., and Kevin C. Cain. 1988. “Logistic Regression for
Two-Stage Case-Control Data.” *Biometrika* 75 (1): 11–20.
<https://doi.org/10.1093/biomet/75.1.11>.

Elliott, Michael R., and Richard Valliant. 2017. “Inference for
Nonprobability Samples.” *Statistical Science* 32 (2): 249–64.
<https://doi.org/10.1214/16-STS598>.

Lumley, Thomas. 2010. *Complex Surveys: A Guide to Analysis Using R*.
John Wiley & Sons. <https://doi.org/10.1002/9780470580066>.
