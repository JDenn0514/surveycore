# Pew NPORS 2025: National Public Opinion Reference Survey

The 2025 National Public Opinion Reference Survey (NPORS), conducted
February 5 – June 18, 2025, by Pew Research Center (n = 5,022). An
address-based sample (ABS) drawn from the USPS Computerized Delivery
Sequence File, with respondents completing the survey online, by paper,
or by telephone in English or Spanish. All 65 columns from the public
release file are retained.

## Usage

``` r
pew_npors_2025
```

## Format

A data frame with 5,022 rows and 65 variables. The 11 `smuse_*`
variables form a battery asking about social media platform use and
share a `"question_preface"` attribute. All other variables are
documented individually below:

- respid:

  Case ID. Unique respondent identifier.

- stratum:

  Sampling stratum (10 levels, defined by census block group
  demographics).

- basewt:

  Base weight — inverse probability of selection, with adaptive mode
  adjustment.

- weight:

  Final weight — `basewt` after raking to Census population targets. Use
  for all population-level estimates.

- mode:

  Data collection mode: `1` = Online, `2` = Paper, `3` = Phone.

- language:

  Language interview completed in: `1` = English, `2` = Spanish.

- languageinitial:

  Language interview started in.

- interview_start:

  Interview start timestamp.

- interview_end:

  Interview end timestamp.

- econ1mod:

  Economic conditions in your community today (Excellent / Good / Fair /
  Poor).

- econ1bmod:

  Economic conditions one year from now (Better / Worse / Same).

- comtype2:

  Community type: Urban / Suburban / Rural.

- unity:

  Americans united vs. divided on values.

- crimesafe:

  Area safety in terms of crime (Extremely safe – Not at all safe).

- govprotct:

  Government's role in protecting people from themselves.

- moregunimpact:

  Impact of more gun ownership on crime.

- fin_sit:

  Household financial situation (Comfortable – Can't meet basics).

- vet1:

  Military service in household.

- vol12_cps:

  Volunteered for any organization in past 12 months.

- eminuse:

  Uses internet or email at least occasionally.

- intmob:

  Accesses internet on a mobile device.

- intfreq:

  Internet use frequency (6 categories).

- intfreq_collapsed:

  Internet use frequency (4 categories, derived).

- home4nw2:

  Subscribes to home internet service.

- bbhome:

  Home internet type (dial-up, broadband, etc.).

- smuse_fb:

  Facebook. Part of social media use battery (see Details).

- smuse_yt:

  YouTube. Part of social media use battery (see Details).

- smuse_x:

  X (formerly Twitter). Part of social media use battery.

- smuse_ig:

  Instagram. Part of social media use battery.

- smuse_sc:

  Snapchat. Part of social media use battery.

- smuse_wa:

  WhatsApp. Part of social media use battery.

- smuse_tt:

  TikTok. Part of social media use battery.

- smuse_rd:

  Reddit. Part of social media use battery.

- smuse_bsk:

  Bluesky. Part of social media use battery.

- smuse_th:

  Threads. Part of social media use battery.

- smuse_ts:

  Truth Social. Part of social media use battery.

- radio:

  Listens to radio.

- device1a:

  Has a cell phone.

- smart2:

  Cell phone is a smartphone.

- nhisll:

  Has a working landline telephone at home.

- relig:

  Current religion (12 categories).

- religcat1:

  Religion (4 categories: Protestant, Catholic, Unaffiliated, Other).

- born:

  Born-again or evangelical Christian.

- attendper:

  In-person religious service attendance (6 categories).

- attendonline2:

  Online/TV religious service participation (6 categories).

- relimp:

  Importance of religion in life (Very – Not at all).

- pray:

  Prayer frequency outside of services (7 categories).

- educcat:

  Education level (categorical).

- hisp:

  Hispanic origin.

- racecmb:

  Race (5 categories).

- racethn:

  Race-ethnicity (5 categories including Asian non-Hispanic).

- agegrp:

  Age in 13 five-year groups.

- agecat:

  Age (4 categories: 18-29, 30-49, 50-64, 65+).

- birthplace:

  U.S. born vs. foreign born.

- gender:

  Gender (man / woman / other).

- adults:

  Number of adults in household.

- inc_sdt1:

  Total family income (8 categories from \< \$30,000 to \$150,000+).

- cregion:

  Census region (NE / MW / S / W).

- metro:

  Metropolitan area indicator.

- registration:

  Registered to vote at current address.

- party:

  Party affiliation (Rep / Dem / Ind / Other).

- partyln:

  Party lean for Independents (Rep / Dem).

- partysum:

  Party summary (Rep+Lean Rep / Dem+Lean Dem / No lean).

- voted2024:

  Voted in the 2024 presidential election.

- votegen_post:

  2024 presidential vote choice (Trump / Harris / Other).

## Source

Pew Research Center. 2025 National Public Opinion Reference Survey.
<https://www.pewresearch.org/datasets/> (free account required to
download raw data; the processed `.rda` is included in the package).
Prepared by `data-raw/prepare-pew-npors-2025.R`.

## Details

**Survey design:** Stratified address-based sample with raking
post-stratification — use Taylor series linearization. NPORS has no PSU
(each address is its own unit, effectively a stratified SRS):

    svy <- as_survey(pew_npors_2025,
      strata  = stratum,
      weights = weight
    )

Use `basewt` instead of `weight` for sensitivity analyses comparing pre-
and post-raking estimates.

**Social media battery:** All 11 `smuse_*` variables share the question
stem
`"Please indicate whether or not you ever use the following websites or apps."`
Values: `1` = Selected, `2` = Not selected, `99` = Refused. Each
variable additionally carries a `"question_preface"` attribute with this
shared stem.

**Metadata:** All columns carry variable labels and value labels as R
attributes from the original SPSS file. The 11 `smuse_*` battery
variables additionally carry a `"question_preface"` attribute with the
shared question stem. All three attribute types are automatically
extracted into surveycore's metadata system when you call
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md).

- **Variable labels** (`"label"` attribute): A human-readable
  description of each column — for `smuse_*` variables this is just the
  platform name (e.g., `"Facebook"`). Example:
  `attr(pew_npors_2025$smuse_fb, "label")` returns `"Facebook"`.

- **Value labels** (`"labels"` attribute): A named numeric vector
  mapping each code to its meaning. Example:
  `attr(pew_npors_2025$smuse_fb, "labels")` returns
  `c(Selected = 1, "Not selected" = 2, Refused = 99)`.

- **Question preface** (`"question_preface"` attribute): The shared
  question stem for battery items, set on all `smuse_*` columns.
  Example: `attr(pew_npors_2025$smuse_fb, "question_preface")` returns
  `"Please indicate whether or not you ever use the following websites or apps."`.

## Examples

``` r
# Variables in the dataset
names(pew_npors_2025)
#>  [1] "respid"            "mode"              "language"         
#>  [4] "languageinitial"   "stratum"           "interview_start"  
#>  [7] "interview_end"     "econ1mod"          "econ1bmod"        
#> [10] "comtype2"          "unity"             "crimesafe"        
#> [13] "govprotct"         "moregunimpact"     "fin_sit"          
#> [16] "vet1"              "vol12_cps"         "eminuse"          
#> [19] "intmob"            "intfreq"           "intfreq_collapsed"
#> [22] "home4nw2"          "bbhome"            "smuse_fb"         
#> [25] "smuse_yt"          "smuse_x"           "smuse_ig"         
#> [28] "smuse_sc"          "smuse_wa"          "smuse_tt"         
#> [31] "smuse_rd"          "smuse_bsk"         "smuse_th"         
#> [34] "smuse_ts"          "radio"             "device1a"         
#> [37] "smart2"            "nhisll"            "relig"            
#> [40] "religcat1"         "born"              "attendper"        
#> [43] "attendonline2"     "relimp"            "pray"             
#> [46] "educcat"           "registration"      "party"            
#> [49] "partyln"           "partysum"          "hisp"             
#> [52] "racecmb"           "racethn"           "agegrp"           
#> [55] "agecat"            "birthplace"        "gender"           
#> [58] "adults"            "voted2024"         "votegen_post"     
#> [61] "inc_sdt1"          "cregion"           "metro"            
#> [64] "basewt"            "weight"           

# Create survey design (no PSU for ABS design)
svy <- as_survey(
  pew_npors_2025,
  strata = stratum,
  weights = weight
)

# Inspect variable label
attr(pew_npors_2025$smuse_fb, "label")
#> [1] "Facebook"

# Inspect value labels
attr(pew_npors_2025$smuse_fb, "labels")
#>     Selected Not selected      Refused 
#>            1            2           99 

# Inspect question preface (shared stem for all smuse_* battery items)
attr(pew_npors_2025$smuse_fb, "question_preface")
#> [1] "Please indicate whether or not you ever use the following websites or apps."
```
