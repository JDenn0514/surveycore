# data-raw/

Raw source data and prepare scripts for the six real-world datasets bundled
with surveycore. Each dataset is stored as a compressed `.rda` file in `data/`
and is available immediately when the package is loaded (via `LazyData: true`).

---

## Why these datasets exist

surveycore uses real survey data for two purposes:

1. **Demonstrating all three design types** — Taylor linearization, successive
   difference replication, and jackknife replication. No single government
   dataset covers all three, so the package includes six datasets spanning the
   full range.
2. **Numerical validation** — estimates from `get_means()`, `get_totals()`,
   etc., can be cross-checked against the `survey` package using the same
   design objects.

For unit tests, use the synthetic generators in
`tests/testthat/helper-test-data.R` instead of these real datasets. Synthetic
data is faster, fully controlled, and has no file I/O overhead.

---

## Dataset overview

| Dataset | Rows | Cols | Design type | Weight variable(s) | Source |
|---------|-----:|-----:|-------------|-------------------|--------|
| `nhanes_2017` | 9,254 | 14 | Stratified multi-stage cluster (Taylor) | `wtmec2yr`, `wtint2yr` | CDC / Public domain |
| `acs_pums_wy` | 5,962 | 96 | Successive difference replication (80 rep. wts.) | `pwgtp` + `pwgtp1`–`pwgtp80` | Census / Public domain |
| `anes_2024` | 5,521 | 19 | Stratified cluster (Taylor) | `v240103a` (pre), `v240103b` (post) | ANES / Free account |
| `gss_2024` | 3,309 | 27 | Stratified multi-stage cluster (Taylor) | `wtssps`, `wtssnrps` | NORC / Free account |
| `pew_npors_2025` | 5,022 | 65 | Stratified with raking (Taylor) | `weight` | Pew / Free account |
| `pew_jewish_2020` | 5,881 | 130 | Jackknife replication (100 rep. wts.) | `extweight` + `extweight1`–`extweight100` | Pew / Free account |

---

## Metadata system integration

All six datasets carry column-level metadata attributes that plug directly into
surveycore's metadata system:

- **`label`** — A human-readable variable description (e.g.,
  `attr(nhanes_2017$riagendr, "label")` → `"Gender"`). Set by haven on import
  for NHANES, ANES, GSS, and Pew datasets; manually assigned for ACS PUMS
  (no labels in CSV source).
- **`labels`** — A named numeric vector mapping codes to their meaning (e.g.,
  `attr(gss_2024$sex, "labels")` → `c(male = 1, female = 2, ...)`).
- **`question_preface`** — Set only on battery and select-all-that-apply
  variables (see `pew_jewish_2020` and `pew_npors_2025` below). Contains the
  shared question stem; `label` holds only the unique item text.

`extract_var_label()`, `extract_val_labels()`, and `extract_question_preface()`
read these attributes. They are preserved through all surveycore operations
(select, rename, filter, etc.).

---

## Dataset details

---

### `nhanes_2017` — NHANES 2017-2018 Demographics & Blood Pressure

**File:** `data/nhanes_2017.rda` (205 KB on disk, ~1.0 MB in RAM)
**Prepare script:** `data-raw/download-nhanes.R` (downloads automatically)
**Source:** National Center for Health Statistics, CDC — public domain

#### What it is

A merged dataset from the 2017-2018 National Health and Nutrition Examination
Survey combining the DEMO_J (demographics) and BPX_J (blood pressure)
examination components. NHANES uses a complex, stratified four-stage cluster
design with oversampling of minorities and low-income populations. The "masked
variance" PSU and stratum variables (`sdmvpsu`, `sdmvstra`) are published
rather than the true design variables to protect respondent confidentiality;
they are nonetheless appropriate for variance estimation.

#### Survey design

**Type:** Stratified multi-stage cluster — use Taylor series linearization.
Two weights are available depending on what analysis you are running:

| Weight | When to use |
|--------|-------------|
| `wtmec2yr` | Any variable collected during the physical examination (blood pressure, BMI, lab results) |
| `wtint2yr` | Variables collected during the interview only (demographics, self-reported health, income) |

```r
# Examination-based analysis (blood pressure)
svy <- as_survey(nhanes_2017,
  ids     = sdmvpsu,
  strata  = sdmvstra,
  weights = wtmec2yr
)

# Interview-only analysis
svy <- as_survey(nhanes_2017,
  ids     = sdmvpsu,
  strata  = sdmvstra,
  weights = wtint2yr
)
```

#### Variables

| Variable | Label | Notes |
|----------|-------|-------|
| `seqn` | Respondent sequence number | Join key; unique per person |
| `sdmvpsu` | Masked variance pseudo-PSU | Cluster ID for variance estimation |
| `sdmvstra` | Masked variance pseudo-stratum | Stratum for variance estimation |
| `wtmec2yr` | 2-year MEC exam weight | Use for blood pressure / exam data |
| `wtint2yr` | 2-year interview weight | Use for interview-only variables |
| `ridstatr` | Interview/examination status | `1` = interview only; `2` = interview + exam |
| `riagendr` | Gender | `1` = male; `2` = female |
| `ridageyr` | Age at screening | Years; top-coded at 80 |
| `ridreth3` | Race/Hispanic origin | 6 categories including NH Asian |
| `indfmpir` | Income-to-poverty ratio | Continuous 0–5; top-coded at 5 |
| `dmdeduc2` | Education (adults 20+) | `1`–`5` from < 9th grade to college grad |
| `bpxsy1` | Systolic BP, 1st reading | mm Hg; `NA` for interview-only cases |
| `bpxdi1` | Diastolic BP, 1st reading | mm Hg; `NA` for interview-only cases |
| `bpxpls` | 60-second pulse | Beats per minute; `NA` for interview-only cases |

#### Role in surveycore

The canonical example for **Taylor linearization** with a complex multi-stage
design. Used in vignettes to demonstrate blood pressure analysis with proper
variance estimation. The two-weight structure (`wtmec2yr` vs `wtint2yr`) makes
it useful for teaching weight selection.

---

### `acs_pums_wy` — ACS PUMS 2022, Wyoming Persons

**File:** `data/acs_pums_wy.rda` (528 KB on disk, ~2.3 MB in RAM)
**Prepare script:** `data-raw/download-acs-pums.R` (downloads automatically)
**Source:** U.S. Census Bureau, American Community Survey — public domain

#### What it is

All 5,962 person records from the 2022 ACS 1-Year Public Use Microdata Sample
(PUMS) for Wyoming (state FIPS 56). Wyoming is the least-populous state, making
this the smallest state-level PUMS file and ideal for tests and examples that
need realistic replicate weight structure without a large dataset.

The ACS PUMS uses **successive difference replication (SDR)**: 80 replicate
weights (`pwgtp1`–`pwgtp80`) are provided alongside the base weight (`pwgtp`).
Variance is estimated by computing the statistic once with the base weight and
80 more times with each replicate, then applying the SDR formula.

#### Survey design

**Type:** Successive difference replication — use `as_survey_rep()`.

```r
svy <- as_survey_rep(
  acs_pums_wy,
  weights    = pwgtp,
  repweights = starts_with("pwgtp") & !matches("^pwgtp$"),
  type       = "successive-difference"
)
```

#### Variables

**Design (cols 1–3):**

| Variable | Description |
|----------|-------------|
| `puma` | Public Use Microdata Area — geographic cluster (PSU analog) |
| `st` | State FIPS code — all `56` (Wyoming) |
| `pwgtp` | Person weight — number of people this record represents |

**Replicate weights (cols 4–83):** `pwgtp1` through `pwgtp80` — 80 successive
difference replicate weights for variance estimation.

**Person characteristics (cols 84–96):**

| Variable | Description |
|----------|-------------|
| `agep` | Age in years (0–99) |
| `sex` | `1` = male; `2` = female |
| `rac1p` | Detailed race recode (1=White, 2=Black, 3=AIAN, 6=Asian, 9=Multiracial) |
| `hisp` | Hispanic origin (`01` = not Hispanic; `02`–`24` = specific origin) |
| `schl` | Educational attainment (01–24; 16 = HS diploma, 21 = bachelor's, 24 = doctorate) |
| `esr` | Employment status (1=employed FT, 2=employed with job not at work, 3=unemployed, 6=NILF) |
| `pincp` | Total person income (dollars, signed; negative = net loss) |
| `wagp` | Wages/salary income (dollars; `NA` if not applicable) |
| `hicov` | Health insurance: `1` = covered; `2` = not covered |
| `dis` | Disability: `1` = with disability; `2` = without disability |
| `povpip` | Income-to-poverty ratio (0–501; `501` = 501%+) |
| `wkhp` | Usual hours worked per week (`NA` if not in labor force) |
| `adjinc` | Income adjustment factor — divide by 1,000,000 and multiply income variables to get 2022 constant dollars |

**Note:** ACS PUMS columns have no `label` or `labels` attributes — the source
is a plain CSV. Variable descriptions live only in this README and the
`?acs_pums_wy` help page.

#### Role in surveycore

The canonical example for **successive difference replication**. The 80
replicate weights stress-test `as_survey_rep()` and `repweights =
starts_with(...)` tidy-select syntax. Income variables demonstrate adjustment
factor usage and sign handling.

---

### `anes_2024` — American National Election Studies 2024 Time Series

**File:** `data/anes_2024.rda` (95 KB on disk, ~0.9 MB in RAM)
**Prepare script:** `data-raw/prepare-anes-2024.R` (raw file requires free ANES account)
**Source:** American National Election Studies — free account at electionstudies.org

#### What it is

A 19-variable extract from the 2024 ANES Time Series Study, a landmark
biennial pre- and post-election survey of the American electorate conducted via
face-to-face (FTF) interview and web. The full dataset has 5,521 respondents
and 1,722 variables; this extract retains the combined FTF+Web design variables
and the core demographic and political items most useful for survey methods
demonstrations.

The ANES uses a **stratified cluster design** with raked weights. Eight
separate sets of PSU/stratum/weight variables are provided for different sample
combinations (FTF only, Web only, combined, with/without panel, etc.). This
extract uses the **FTF + Web combined** variables (`v240103a/b/c/d`), which is
the recommended set for most analyses.

#### Survey design

**Type:** Stratified cluster — use Taylor series linearization.
Two weights exist depending on whether the analysis uses pre- or post-election
variables:

| Weight | When to use |
|--------|-------------|
| `v240103a` | Pre-election variables (asked before November 5, 2024) |
| `v240103b` | Post-election variables (asked after November 5, 2024) |

```r
# Pre-election analysis (party ID, ideology, candidate preference)
svy <- as_survey(anes_2024,
  ids     = v240103c,
  strata  = v240103d,
  weights = v240103a
)

# Post-election analysis (validated vote choice)
svy <- as_survey(anes_2024,
  ids     = v240103c,
  strata  = v240103d,
  weights = v240103b
)
```

**Missing/invalid codes:** The ANES uses negative integer codes for missing
data (`-9` = Refused, `-8` = Don't know, `-4` = Error, `-1` = Inapplicable,
etc.). These must be recoded to `NA` before analysis. Check
`attr(anes_2024$v241177, "labels")` for the full set of codes per variable.

#### Variables

All columns carry `label` and `labels` attributes from the original Stata file.
Variable names are lowercase V-codes — consult `attr(x, "label")` for the
human-readable description.

| Variable | Label | Notes |
|----------|-------|-------|
| `v240001` | 2024 Time Series Case ID | Unique respondent identifier |
| `v240003` | Sample type | `1`=Panel, `2`=Fresh Web, `3`=Fresh FTF, `4`=GSS |
| `v240002c` | Pre/Post interview completion | `1`=Pre only; `2`=Pre+Post |
| `v240103a` | **Pre-election weight** (FTF+Web combined) | Use for pre-election variables |
| `v240103b` | **Post-election weight** (FTF+Web combined) | Use for post-election variables |
| `v240103c` | **PSU** (FTF+Web combined) | Cluster ID for variance estimation |
| `v240103d` | **Stratum** (FTF+Web combined) | Stratum for variance estimation |
| `v243002` | State FIPS code | Sample location state |
| `v243007` | Census region | `1`=NE, `2`=MW, `3`=S, `4`=W |
| `v241458x` | Age on Election Day | Summary; top-coded at 80; `-2`=missing |
| `v241550` | Sex | `1`=male; `2`=female |
| `v241501x` | Race/ethnicity (5-category summary) | White NH, Black NH, Hispanic, Asian/NHPI NH, Other/Multi NH |
| `v241465x` | Education (5-category summary) | `1`=< HS; `2`=HS; `3`=some college; `4`=BA; `5`=grad degree |
| `v241566x` | Household income (28 categories) | Fine-grained income bands from < $5K to $250K+ |
| `v241177` | 7-pt liberal-conservative self-placement | `1`=extremely liberal; `7`=extremely conservative; `99`=haven't thought |
| `v241222` | Party identification strength | `1`=strong; `2`=not strong (applies to whichever party in `v241223`) |
| `v241223` | Party ID lean (Independents) | `1`=closer to Rep; `2`=neither; `3`=closer to Dem |
| `v242066` | Did R vote for President (POST) | `1`=yes; `2`=no |
| `v242067` | For whom did R vote for President (POST) | `1`=Harris; `2`=Trump; `3`=RFK Jr; `4`=West; `5`=Stein; `6`=Other |

#### Role in surveycore

Demonstrates Taylor linearization with a **political survey** and the common
complication of two weights (pre vs. post). The opaque V-code naming is typical
of large academic datasets; it exercises the `label` attribute path in
surveycore's print/summary methods. The fine-grained income variable (`v241566x`
with 28 categories) is useful for testing quantile and distribution functions.

---

### `gss_2024` — General Social Survey 2024

**File:** `data/gss_2024.rda` (82 KB on disk, ~0.8 MB in RAM)
**Prepare script:** `data-raw/prepare-gss-2024.R` (raw file requires free NORC account)
**Source:** NORC at the University of Chicago — free account at gss.norc.org

#### What it is

A 27-variable extract from the 2024 General Social Survey, one of the longest-
running sociological surveys in the United States (fielded annually or
biennially since 1972). The GSS uses a complex stratified multi-stage area
probability design. All 3,309 respondents from the 2024 cross-section are
included; no subsampling was needed.

The GSS provides two post-stratification weights. `wtssps` is the standard
weight; `wtssnrps` additionally adjusts for differential non-response across
demographic groups and is preferred when non-response bias is a concern.

#### Survey design

**Type:** Stratified multi-stage cluster — use Taylor series linearization.

```r
svy <- as_survey(gss_2024,
  ids     = vpsu,
  strata  = vstrat,
  weights = wtssps       # or wtssnrps for non-response-adjusted weight
)
```

**Missing value codes:** The GSS uses a rich system of negative integer codes
for missing data that is consistent across all variables. Common codes:

| Code | Meaning |
|------|---------|
| `-100` | Inapplicable (question not asked of this respondent) |
| `-99` | No answer |
| `-98` | Don't know |
| `-97` | Skipped on web |
| `-90` | Refused |

These are stored as value labels on every column (check `attr(x, "labels")`).
They must be recoded to `NA` before most analyses.

#### Variables

| Variable | Label | Notes |
|----------|-------|-------|
| `vpsu` | Variance PSU | Cluster ID for variance estimation |
| `vstrat` | Variance stratum | Stratum for variance estimation |
| `wtssps` | Person post-stratification weight | Standard analysis weight |
| `wtssnrps` | Person weight (non-response adjusted) | Preferred when non-response is a concern |
| `ballot` | Ballot form (A/B/C/D) | GSS uses split-ballot design; not all questions appear on every ballot |
| `year` | Survey year | All `2024` in this extract |
| `id` | Respondent ID | Unique case identifier |
| `age` | Age of respondent | Years; `89` = 89 or older |
| `sex` | Sex | `1`=male; `2`=female |
| `race` | Race | `1`=white; `2`=black; `3`=other |
| `hispanic` | Hispanic origin | `1`=not Hispanic; `2`–`5`=specific origins |
| `educ` | Highest year of school completed | `0`–`20` years |
| `degree` | Highest degree | `0`=< HS; `1`=HS; `2`=associate; `3`=bachelor's; `4`=graduate |
| `income16` | Total family income | 26 categories from < $1K to $170K+ |
| `marital` | Marital status | `1`=married; `2`=widowed; `3`=divorced; `4`=separated; `5`=never married |
| `wrkstat` | Labor force status | `1`=FT; `2`=PT; `3`=temp not working; `4`=unemployed; `5`=retired; etc. |
| `hrs1` | Hours worked last week | Only for employed respondents |
| `adults` | Adults in household | Count; `8` = 8 or more |
| `partyid` | Party identification | `0`=strong Democrat; `6`=strong Republican; `7`=other party |
| `polviews` | Political views | `1`=extremely liberal; `7`=extremely conservative |
| `happy` | General happiness | `1`=very happy; `2`=pretty happy; `3`=not too happy |
| `health` | Self-rated health | `1`=excellent; `2`=good; `3`=fair; `4`=poor |
| `trust` | Social trust | `1`=most people can be trusted; `2`=can't be too careful; `3`=depends |
| `natfare` | Government spending on welfare | `1`=too little; `2`=about right; `3`=too much |
| `abany` | Abortion for any reason | `1`=yes; `2`=no |
| `attend` | Religious service attendance | `0`=never; `8`=several times a week |
| `relig` | Religious preference | `1`=Protestant; `2`=Catholic; `3`=Jewish; `4`=none; etc. |

#### Role in surveycore

The GSS is the **classic social science survey** used in thousands of published
studies, making it ideal for reproducibility comparisons. The split-ballot
design (`ballot`) demonstrates how to handle situations where not all questions
are asked of all respondents (inapplicable codes). The long time series of the
GSS variables makes them familiar to most social scientists, reducing the
cognitive load when demonstrating surveycore's API.

---

### `pew_npors_2025` — Pew NPORS 2025

**File:** `data/pew_npors_2025.rda` (132 KB on disk, ~1.4 MB in RAM)
**Prepare script:** `data-raw/prepare-pew-npors-2025.R` (raw file requires free Pew account)
**Source:** Pew Research Center — free account at pewresearch.org/datasets

#### What it is

The 2025 National Public Opinion Reference Survey (NPORS), conducted February
5–June 18, 2025, by Pew Research Center. NPORS is an address-based sample
(ABS) drawn from the USPS Computerized Delivery Sequence File, with respondents
completing the survey online, by paper, or by telephone in English or Spanish
(n = 5,022). Because the sample frame is residential mailing addresses rather
than a list of phone numbers, it achieves broader coverage than traditional
telephone surveys.

All 65 columns from the public release file are retained. The dataset is small
enough that no subsampling was needed.

#### Survey design

**Type:** Stratified sample with raking post-stratification — use Taylor series
linearization. The 10 strata are defined by crossing census block group
demographics (proportion Black, proportion Hispanic, education level).

| Variable | Role |
|----------|------|
| `stratum` | Sampling stratum (10 strata based on neighborhood demographics) |
| `basewt` | Base weight — inverse probability of selection, with adaptive mode adjustment |
| `weight` | Final weight — `basewt` after raking to Census population targets |

Use `weight` for all population-level estimates. `basewt` is provided for
methodological transparency and sensitivity analyses.

```r
svy <- as_survey(pew_npors_2025,
  strata  = stratum,
  weights = weight
)
```

**Note:** NPORS has no PSU/cluster variable because the ABS design treats each
address as its own unit (effectively a stratified simple random sample). Omit
`ids` or set `ids = 1` when creating the design object.

#### Variable labels and metadata

All 65 variables carry `label` and `labels` attributes, sourced from the SPSS
release file. Variable labels have been cleaned — the original Pew format
`"VARNAME. Question text"` has had the variable name prefix stripped, leaving
only the question text.

The 11 `smuse_*` variables form a **select-all-that-apply battery** and carry
an additional `question_preface` attribute:

```r
attr(pew_npors_2025$smuse_fb, "label")
#> [1] "Facebook"

attr(pew_npors_2025$smuse_fb, "question_preface")
#> [1] "Please indicate whether or not you ever use the following websites or apps."

attr(pew_npors_2025$smuse_fb, "labels")
#> Selected Not selected      Refused
#>        1            2           99
```

#### Variables

**Design:**

| Variable | Description |
|----------|-------------|
| `respid` | Case ID |
| `stratum` | Sampling stratum (10 levels) |
| `basewt` | Base weight (pre-raking) |
| `weight` | Final raked weight |

**Mode and language:**

| Variable | Description |
|----------|-------------|
| `mode` | Data collection mode: `1`=Online; `2`=Paper; `3`=Phone |
| `language` | Language interview completed in: `1`=English; `2`=Spanish |
| `languageinitial` | Language interview started in |
| `interview_start` | Interview start timestamp |
| `interview_end` | Interview end timestamp |

**Topical items:**

| Variable | Question summary |
|----------|-----------------|
| `econ1mod` | Economic conditions in your community today (Excellent–Poor) |
| `econ1bmod` | Economic conditions one year from now (Better/Worse/Same) |
| `comtype2` | Community type: Urban/Suburban/Rural |
| `unity` | Americans united vs. divided on values |
| `crimesafe` | Area safety in terms of crime (Extremely safe–Not at all safe) |
| `govprotct` | Government's role in protecting people from themselves |
| `moregunimpact` | Impact of more gun ownership on crime |
| `fin_sit` | Household financial situation (Comfortable–Can't meet basics) |
| `vet1` | Military service in household |
| `vol12_cps` | Volunteered for any organization in past 12 months |

**Internet and technology:**

| Variable | Description |
|----------|-------------|
| `eminuse` | Uses internet or email at least occasionally |
| `intmob` | Accesses internet on a mobile device |
| `intfreq` | Internet use frequency (6 categories) |
| `intfreq_collapsed` | Internet use frequency (4 categories, derived) |
| `home4nw2` | Subscribes to home internet service |
| `bbhome` | Home internet type (dial-up, broadband, etc.) |
| `radio` | Listens to radio |
| `device1a` | Has a cell phone |
| `smart2` | Cell phone is a smartphone |
| `nhisll` | Has a working landline telephone at home |

**Social media use (select-all-that-apply battery):**
`question_preface` = "Please indicate whether or not you ever use the following
websites or apps." Values: `1`=Selected, `2`=Not selected, `99`=Refused.

| Variable | Platform |
|----------|----------|
| `smuse_fb` | Facebook |
| `smuse_yt` | YouTube |
| `smuse_x` | X (formerly Twitter) |
| `smuse_ig` | Instagram |
| `smuse_sc` | Snapchat |
| `smuse_wa` | WhatsApp |
| `smuse_tt` | TikTok |
| `smuse_rd` | Reddit |
| `smuse_bsk` | Bluesky |
| `smuse_th` | Threads |
| `smuse_ts` | Truth Social |

**Religion:**

| Variable | Description |
|----------|-------------|
| `relig` | Current religion (12 categories) |
| `religcat1` | Religion (4 categories: Protestant, Catholic, Unaffiliated, Other) |
| `born` | Born-again or evangelical Christian |
| `attendper` | In-person religious service attendance (6 categories) |
| `attendonline2` | Online/TV religious service participation (6 categories) |
| `relimp` | Importance of religion in life (Very–Not at all) |
| `pray` | Prayer frequency outside of services (7 categories) |

**Demographics:**

| Variable | Description |
|----------|-------------|
| `hisp` | Hispanic origin |
| `racecmb` | Race (5 categories) |
| `racethn` | Race-ethnicity (5 categories including Asian NH) |
| `agegrp` | Age in 13 5-year groups |
| `agecat` | Age (4 categories: 18-29, 30-49, 50-64, 65+) |
| `birthplace` | U.S. born vs. foreign born |
| `gender` | Gender (man/woman/other) |
| `adults` | Number of adults in household |
| `inc_sdt1` | Total family income (8 categories from < $30K to $150K+) |
| `cregion` | Census region (NE/MW/S/W) |
| `metro` | Metropolitan area indicator |

**Politics and civic engagement:**

| Variable | Description |
|----------|-------------|
| `registration` | Registered to vote at current address |
| `party` | Party affiliation (Rep/Dem/Ind/Other) |
| `partyln` | Party lean for Independents (Rep/Dem) |
| `partysum` | Party summary (Rep+Lean Rep / Dem+Lean Dem / No lean) |
| `voted2024` | Voted in the 2024 presidential election |
| `votegen_post` | 2024 presidential vote choice (Trump/Harris/Other) |

#### Role in surveycore

Demonstrates a **stratified ABS design with raking weights** — increasingly
common in modern survey research as telephone response rates have declined.
The `smuse_*` battery is the primary vehicle for testing `question_preface`
metadata extraction. The dual-weight approach (`basewt` / `weight`) illustrates
the difference between base and post-stratification weights.

---

### `pew_jewish_2020` — Pew Jewish Americans in 2020

**File:** `data/pew_jewish_2020.rda` (3.5 MB on disk, ~6.2 MB in RAM)
**Prepare script:** `data-raw/prepare-pew-jewish-2020.R` (raw file requires free Pew account)
**Source:** Pew Research Center — free account at pewresearch.org/datasets

#### What it is

The extended survey dataset from Pew Research Center's 2019-2020 Survey of
U.S. Jews, fielded November 19, 2019–June 3, 2020. Respondents were drawn from
a national, stratified random sample of residential mailing addresses. All
5,881 respondents who completed the extended survey are included. The dataset
is notably large (3.5 MB) because it carries 100 jackknife replicate weights
alongside the main weight.

The survey oversampled households likely to contain Jewish respondents based on
surname and geographic concentration. The `jewishcat` variable classifies
respondents into the five Jewish identity categories used in the published
report. Analysts should use `jewishcat` rather than constructing their own
classification from the raw religion variables.

#### Survey design

**Type:** Jackknife replication — use `as_survey_rep()` with all 100 replicate
weights.

```r
svy <- as_survey_rep(
  pew_jewish_2020,
  weights    = extweight,
  repweights = starts_with("extweight") & !matches("^extweight$"),
  type       = "JK1"
)
```

| Variable | Role |
|----------|------|
| `extweight` | Full-sample base weight |
| `extweight1`–`extweight100` | 100 jackknife replicate weights |

#### Battery question metadata

Three question batteries in this dataset have been processed so that each
variable carries the unique item text in its `label` attribute and the shared
question stem in its `question_preface` attribute.

**`relconsider_a`–`relconsider_d`** — Select-all-that-apply
`question_preface`: "Aside from religion, do you consider yourself to be any
of the following in any way (for example, ethnically, culturally, or because
of your family's background)?"
Values: `1`=Selected, `2`=Not selected, `99`=Refused

| Variable | Item label |
|----------|-----------|
| `relconsider_a` | Jewish |
| `relconsider_b` | Catholic |
| `relconsider_c` | Mormon |
| `relconsider_d` | Muslim |

**`relraised_a`–`relraised_d`** — Select-all-that-apply
`question_preface`: "Please indicate whether you were raised in any of the
following traditions or had a parent from any of the following backgrounds."
Values: `1`=Selected, `2`=Not selected, `99`=Refused

| Variable | Item label |
|----------|-----------|
| `relraised_a` | Jewish |
| `relraised_b` | Catholic |
| `relraised_c` | Mormon |
| `relraised_d` | Muslim |

**`discrim_a`–`discrim_f`** — Rating-scale battery
`question_preface`: "Please tell us how much discrimination there is against
each of these groups in our society today."
Values: `1`=A lot, `2`=Some, `3`=Not much, `4`=None at all, `99`=Not answered

| Variable | Item label |
|----------|-----------|
| `discrim_a` | Evangelical Christians |
| `discrim_b` | Muslims |
| `discrim_c` | Jews |
| `discrim_d` | Blacks |
| `discrim_e` | Hispanics |
| `discrim_f` | Gays and lesbians |

#### Variables

**Design (cols 1–101):** `extweight` (base weight) + `extweight1`–`extweight100`
(100 jackknife replicate weights).

**Identity and classification:**

| Variable | Description |
|----------|-------------|
| `qkey` | Unique respondent identifier |
| `jewishcat` | Jewish identity category: `1`=Jews by religion; `2`=Jews of no religion; `3`=Jewish background; `4`=Jewish affinity; `5`=Not Jewish |
| `finalmode` | Collection mode: `1`=CAWI (online); `2`=Teleform (mail); `3`=Screener CAWI + Extended Teleform |

**Geography and demographics:**

| Variable | Description |
|----------|-------------|
| `region` | Census region: `1`=NE; `2`=MW; `3`=S; `4`=W |
| `sexask` | Sex: `1`=male; `2`=female; `99`=not answered |
| `age4cat` | Age: `1`=18-29; `2`=30-49; `3`=50-64; `4`=65+; `999`=no answer |
| `educ4cat` | Education: `1`=HS or less; `2`=some college; `3`=college grad; `4`=postgrad; `99`=no answer |
| `religmod` | Current religion (24 categories including Jewish subgroups and combinations) |
| `hisp` | Hispanic origin: `1`=yes; `2`=no |
| `racecmb` | Race (5 categories) |
| `racethn` | Race-ethnicity (4 categories) |

**Attitudes:**

| Variable | Description |
|----------|-------------|
| `presapp` | Presidential approval (Trump): `1`=Strongly approve; `2`=Somewhat approve; `3`=Somewhat disapprove; `4`=Strongly disapprove |
| `track` | Right track/wrong track: `1`=Right direction; `2`=Wrong track |
| `satisfpersmod` | Personal life satisfaction: `1`=Excellent; `2`=Good; `3`=Only fair; `4`=Poor |
| `localrating` | Community as a place to live: `1`=Excellent; `2`=Good; `3`=Only fair; `4`=Poor |

#### Role in surveycore

The only dataset with **jackknife replication** (100 replicate weights), making
it the primary test case for `as_survey_rep(..., type = "JK1")`. The three
question batteries (two select-all-that-apply and one rating scale) are the
primary test vehicle for `extract_question_preface()` and the battery metadata
pathway in surveycore's metadata system. The specialized population (Jewish
Americans) and `jewishcat` classification variable demonstrate domain estimation
use cases.

---

## Preparing datasets from raw source files

### Public domain (auto-downloadable)

These scripts download and process data entirely automatically:

```r
source("data-raw/download-nhanes.R")    # → data/nhanes_2017.rda
source("data-raw/download-acs-pums.R")  # → data/acs_pums_wy.rda
```

### Account-gated (manual download required)

These scripts expect the raw file to already be present. Download instructions
are in each script's header comment.

| Script | Raw file location | Account |
|--------|-------------------|---------|
| `prepare-anes-2024.R` | `data-raw/anes/anes_timeseries_2024_stata_20250808/` | electionstudies.org |
| `prepare-gss-2024.R` | `data-raw/gss/gss-2024/GSS2024.sav` | gss.norc.org |
| `prepare-pew-npors-2025.R` | `data-raw/pew/NPORS 2025/NPORS_2025_for_public_release_FINAL.sav` | pewresearch.org/datasets |
| `prepare-pew-jewish-2020.R` | `data-raw/pew/Jewish_Americans_2020_Datasets_v2/Jewish Americans in 2020 Extended Dataset.dta` | pewresearch.org/datasets |

Raw data directories (`data-raw/anes/`, `data-raw/gss/`, `data-raw/pew/`) are
in `.gitignore` and are never committed — only the processed `.rda` files in
`data/` are version-controlled.

---

## Design type coverage summary

| Design type | Dataset(s) | surveycore constructor |
|-------------|-----------|----------------------|
| Stratified multi-stage cluster (Taylor) | `nhanes_2017`, `anes_2024`, `gss_2024`, `pew_npors_2025` | `as_survey()` |
| Successive difference replication | `acs_pums_wy` | `as_survey_rep(..., type = "successive-difference")` |
| Jackknife replication | `pew_jewish_2020` | `as_survey_rep(..., type = "JK1")` |
