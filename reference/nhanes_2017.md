# NHANES 2017-2018: Demographics and Blood Pressure

A merged dataset from the National Health and Nutrition Examination
Survey (NHANES) 2017-2018 cycle, combining demographic characteristics
with blood pressure measurements. Covers all 9,254 sampled participants;
blood pressure variables are `NA` for the 550 interview-only
participants (`ridstatr == 1`).

## Usage

``` r
nhanes_2017
```

## Format

A data frame with 9,254 rows and 14 variables:

- seqn:

  Respondent sequence number (unique identifier, join key).

- sdmvpsu:

  Masked variance pseudo-PSU. Use as the cluster ID for variance
  estimation. See Details.

- sdmvstra:

  Masked variance pseudo-stratum. Use as the stratification variable for
  variance estimation. See Details.

- wtmec2yr:

  Full-sample 2-year MEC examination weight. Use for any analysis
  involving examination measurements (e.g., blood pressure).

- wtint2yr:

  Full-sample 2-year interview weight. Use for analyses based on
  interview data only.

- ridstatr:

  Interview/examination status: `1` = interview only, `2` = both
  interview and MEC examination.

- riagendr:

  Gender: `1` = male, `2` = female.

- ridageyr:

  Age in years at screening, top-coded at 80.

- ridreth3:

  Race/Hispanic origin (6 categories): `1` = Mexican American, `2` =
  Other Hispanic, `3` = Non-Hispanic White, `4` = Non-Hispanic Black,
  `6` = Non-Hispanic Asian, `7` = Other/Multiracial.

- indfmpir:

  Ratio of family income to the federal poverty level (continuous, 0–5;
  values \>5 are top-coded at 5).

- dmdeduc2:

  Education level for adults 20+: `1` = Less than 9th grade, `2` =
  9th–11th grade, `3` = High school graduate/GED, `4` = Some college/AA,
  `5` = College graduate or above.

- bpxsy1:

  Systolic blood pressure, 1st reading (mm Hg). `NA` if not examined.

- bpxdi1:

  Diastolic blood pressure, 1st reading (mm Hg). `NA` if not examined.

- bpxpls:

  60-second pulse rate (beats per minute). `NA` if not examined.

## Source

National Center for Health Statistics, CDC. NHANES 2017-2018 Continuous
Survey. <https://www.cdc.gov/nchs/nhanes/>

## Details

**Survey design:** Taylor series linearization. When creating a survey
design object, use `sdmvpsu` as the cluster ID, `sdmvstra` as the
stratum, and `wtmec2yr` as the weight for examination-based analyses:

    svy <- as_survey(nhanes_2017,
      ids     = sdmvpsu,
      strata  = sdmvstra,
      weights = wtmec2yr
    )

Use `wtint2yr` instead of `wtmec2yr` for interview-only variables (e.g.,
income, education).

**Metadata:** All columns carry variable labels and value labels as R
attributes, automatically extracted into surveycore's metadata system
when you call
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md).

- **Variable labels** (`"label"` attribute): A human-readable
  description of each column. Example:
  `attr(nhanes_2017$riagendr, "label")` returns `"Gender"`.

- **Value labels** (`"labels"` attribute): A named numeric vector
  mapping each code to its meaning. Example:
  `attr(nhanes_2017$riagendr, "labels")` returns
  `c(Male = 1, Female = 2)`.

**Source files:** DEMO_J.xpt (demographics) merged with BPX_J.xpt (blood
pressure) on `seqn`. Prepared by `data-raw/download-nhanes.R`.

## Examples

``` r
# All 9,254 participants (interview + exam)
head(nhanes_2017)
#>    seqn sdmvpsu sdmvstra  wtmec2yr  wtint2yr ridstatr riagendr ridageyr
#> 1 93703       2      145  8539.731  9246.492        2        2        2
#> 2 93704       1      143 42566.615 37338.768        2        1        2
#> 3 93705       2      145  8338.420  8614.571        2        2       66
#> 4 93706       2      134  8723.440  8548.633        2        1       18
#> 5 93707       1      138  7064.610  6769.345        2        1       13
#> 6 93708       2      138 14372.489 13329.451        2        2       66
#>   ridreth3 indfmpir dmdeduc2 bpxsy1 bpxdi1 bpxpls
#> 1        6     5.00       NA     NA     NA     NA
#> 2        3     5.00       NA     NA     NA     NA
#> 3        4     0.82        2     NA     NA     52
#> 4        6       NA       NA    112     74     82
#> 5        7     1.88       NA    128     38    100
#> 6        6     1.63        1     NA     NA     68

# Restrict to exam participants for blood pressure analysis
exam_only <- nhanes_2017[nhanes_2017$ridstatr == 2, ]

# Inspect variable label
attr(nhanes_2017$riagendr, "label")
#> [1] "Gender"

# Inspect value labels
attr(nhanes_2017$riagendr, "labels")
#> NULL

# Inspect value labels for race/ethnicity
attr(nhanes_2017$ridreth3, "labels")
#> NULL
```
