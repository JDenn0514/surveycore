# ACS PUMS 2022 1-Year: Wyoming Persons

All person records from the 2022 American Community Survey (ACS) 1-Year
Public Use Microdata Sample (PUMS) for Wyoming (state FIPS 56). Wyoming
is the least-populous U.S. state, making this the smallest state-level
PUMS file — ideal for fast tests and examples.

## Usage

``` r
acs_pums_wy
```

## Format

A data frame with 5,962 rows and 96 variables. Variables
`pwgtp1`–`pwgtp80` are eighty successive difference replicate weights
for variance estimation; the remaining 16 variables are:

- puma:

  Public Use Microdata Area code. Use as the cluster ID (PSU) for
  variance estimation.

- st:

  State FIPS code (all `56` = Wyoming).

- pwgtp:

  Person weight. Represents the number of people in the Wyoming
  population that this record represents.

- agep:

  Age (0–99 years).

- sex:

  Sex: `1` = male, `2` = female.

- rac1p:

  Recoded detailed race: `1` = White alone, `2` = Black or African
  American alone, `3` = American Indian alone, `6` = Asian alone, `9` =
  Two or more races.

- hisp:

  Recoded Hispanic origin: `01` = Not Spanish/Hispanic/Latino; `02`–`24`
  = specific Hispanic origin.

- schl:

  Educational attainment (24 categories): `01` = no schooling, `16` =
  regular high school diploma, `21` = bachelor's degree, `24` =
  doctorate degree.

- esr:

  Employment status recode: `1` = civilian employed at work, `2` =
  civilian employed with job but not at work, `3` = unemployed, `4` =
  Armed Forces at work, `5` = Armed Forces not at work, `6` = Not in
  labor force.

- pincp:

  Total person income in the past 12 months (dollars, signed; negative
  values indicate a net loss). Multiply by `adjinc / 1e6` to adjust to
  constant dollars.

- wagp:

  Wages or salary income in the past 12 months (dollars). `NA` if not
  applicable.

- hicov:

  Health insurance coverage: `1` = with health insurance, `2` = without
  health insurance.

- dis:

  Disability recode: `1` = with a disability, `2` = without a
  disability.

- povpip:

  Income-to-poverty ratio (0–501; `501` means 501% or more).

- wkhp:

  Usual hours worked per week in the past 12 months. `NA` if not in the
  labor force.

- adjinc:

  Adjustment factor for income and earnings. Divide by 1,000,000 and
  multiply income variables to convert to 2022 constant dollars.

- pwgtp1:

  Successive difference replicate weight 1 of 80.

- pwgtp2:

  Successive difference replicate weight 2 of 80.

- pwgtp3:

  Successive difference replicate weight 3 of 80.

- pwgtp4:

  Successive difference replicate weight 4 of 80.

- pwgtp5:

  Successive difference replicate weight 5 of 80.

- pwgtp6:

  Successive difference replicate weight 6 of 80.

- pwgtp7:

  Successive difference replicate weight 7 of 80.

- pwgtp8:

  Successive difference replicate weight 8 of 80.

- pwgtp9:

  Successive difference replicate weight 9 of 80.

- pwgtp10:

  Successive difference replicate weight 10 of 80.

- pwgtp11:

  Successive difference replicate weight 11 of 80.

- pwgtp12:

  Successive difference replicate weight 12 of 80.

- pwgtp13:

  Successive difference replicate weight 13 of 80.

- pwgtp14:

  Successive difference replicate weight 14 of 80.

- pwgtp15:

  Successive difference replicate weight 15 of 80.

- pwgtp16:

  Successive difference replicate weight 16 of 80.

- pwgtp17:

  Successive difference replicate weight 17 of 80.

- pwgtp18:

  Successive difference replicate weight 18 of 80.

- pwgtp19:

  Successive difference replicate weight 19 of 80.

- pwgtp20:

  Successive difference replicate weight 20 of 80.

- pwgtp21:

  Successive difference replicate weight 21 of 80.

- pwgtp22:

  Successive difference replicate weight 22 of 80.

- pwgtp23:

  Successive difference replicate weight 23 of 80.

- pwgtp24:

  Successive difference replicate weight 24 of 80.

- pwgtp25:

  Successive difference replicate weight 25 of 80.

- pwgtp26:

  Successive difference replicate weight 26 of 80.

- pwgtp27:

  Successive difference replicate weight 27 of 80.

- pwgtp28:

  Successive difference replicate weight 28 of 80.

- pwgtp29:

  Successive difference replicate weight 29 of 80.

- pwgtp30:

  Successive difference replicate weight 30 of 80.

- pwgtp31:

  Successive difference replicate weight 31 of 80.

- pwgtp32:

  Successive difference replicate weight 32 of 80.

- pwgtp33:

  Successive difference replicate weight 33 of 80.

- pwgtp34:

  Successive difference replicate weight 34 of 80.

- pwgtp35:

  Successive difference replicate weight 35 of 80.

- pwgtp36:

  Successive difference replicate weight 36 of 80.

- pwgtp37:

  Successive difference replicate weight 37 of 80.

- pwgtp38:

  Successive difference replicate weight 38 of 80.

- pwgtp39:

  Successive difference replicate weight 39 of 80.

- pwgtp40:

  Successive difference replicate weight 40 of 80.

- pwgtp41:

  Successive difference replicate weight 41 of 80.

- pwgtp42:

  Successive difference replicate weight 42 of 80.

- pwgtp43:

  Successive difference replicate weight 43 of 80.

- pwgtp44:

  Successive difference replicate weight 44 of 80.

- pwgtp45:

  Successive difference replicate weight 45 of 80.

- pwgtp46:

  Successive difference replicate weight 46 of 80.

- pwgtp47:

  Successive difference replicate weight 47 of 80.

- pwgtp48:

  Successive difference replicate weight 48 of 80.

- pwgtp49:

  Successive difference replicate weight 49 of 80.

- pwgtp50:

  Successive difference replicate weight 50 of 80.

- pwgtp51:

  Successive difference replicate weight 51 of 80.

- pwgtp52:

  Successive difference replicate weight 52 of 80.

- pwgtp53:

  Successive difference replicate weight 53 of 80.

- pwgtp54:

  Successive difference replicate weight 54 of 80.

- pwgtp55:

  Successive difference replicate weight 55 of 80.

- pwgtp56:

  Successive difference replicate weight 56 of 80.

- pwgtp57:

  Successive difference replicate weight 57 of 80.

- pwgtp58:

  Successive difference replicate weight 58 of 80.

- pwgtp59:

  Successive difference replicate weight 59 of 80.

- pwgtp60:

  Successive difference replicate weight 60 of 80.

- pwgtp61:

  Successive difference replicate weight 61 of 80.

- pwgtp62:

  Successive difference replicate weight 62 of 80.

- pwgtp63:

  Successive difference replicate weight 63 of 80.

- pwgtp64:

  Successive difference replicate weight 64 of 80.

- pwgtp65:

  Successive difference replicate weight 65 of 80.

- pwgtp66:

  Successive difference replicate weight 66 of 80.

- pwgtp67:

  Successive difference replicate weight 67 of 80.

- pwgtp68:

  Successive difference replicate weight 68 of 80.

- pwgtp69:

  Successive difference replicate weight 69 of 80.

- pwgtp70:

  Successive difference replicate weight 70 of 80.

- pwgtp71:

  Successive difference replicate weight 71 of 80.

- pwgtp72:

  Successive difference replicate weight 72 of 80.

- pwgtp73:

  Successive difference replicate weight 73 of 80.

- pwgtp74:

  Successive difference replicate weight 74 of 80.

- pwgtp75:

  Successive difference replicate weight 75 of 80.

- pwgtp76:

  Successive difference replicate weight 76 of 80.

- pwgtp77:

  Successive difference replicate weight 77 of 80.

- pwgtp78:

  Successive difference replicate weight 78 of 80.

- pwgtp79:

  Successive difference replicate weight 79 of 80.

- pwgtp80:

  Successive difference replicate weight 80 of 80.

## Source

U.S. Census Bureau. 2022 ACS 1-Year PUMS.
<https://www.census.gov/programs-surveys/acs/microdata/access.html>

## Details

**Survey design:** Successive difference replication (SDR). Use
[`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md)
with all 80 replicate weights:

    svy <- as_survey_rep(
      acs_pums_wy,
      weights    = pwgtp,
      repweights = starts_with("pwgtp") & !matches("^pwgtp$"),
      type       = "successive-difference"
    )

**Income adjustment:** Income variables (`pincp`, `wagp`) are in
survey-year dollars. Multiply by `adjinc / 1e6` to convert to 2022
inflation-adjusted dollars before comparing across ACS years.

**Metadata:** The ACS PUMS source is a plain CSV with no embedded
labels. Columns in `acs_pums_wy` carry no `"label"`, `"labels"`, or
`"question_preface"` attributes. Variable descriptions are documented
here in `?acs_pums_wy` and in `data-raw/README.md`. Use
[`set_variable_labels()`](https://jdenn0514.github.io/surveycore/reference/set_variable_labels.md)
and
[`set_value_labels()`](https://jdenn0514.github.io/surveycore/reference/set_value_labels.md)
to attach labels manually before analysis if needed.

## Examples

``` r
# Wyoming population represented
sum(acs_pums_wy$pwgtp)
#> [1] 581381

# Age distribution
hist(acs_pums_wy$agep, main = "Age distribution, Wyoming 2022",
     xlab = "Age")


# Confirm 80 replicate weights are present
sum(grepl("^pwgtp[0-9]", names(acs_pums_wy)))
#> [1] 80
```
