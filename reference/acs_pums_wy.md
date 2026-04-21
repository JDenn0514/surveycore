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

A data frame with 5,962 rows and 96 variables. Columns `pwgtp1` through
`pwgtp80` are the 80 successive difference replicate weights for
variance estimation; the remaining 16 variables are:

- `puma`: Public Use Microdata Area code. Use as the cluster ID (PSU)
  for variance estimation.

- `st`: State FIPS code (all 56 = Wyoming).

- `pwgtp`: Person weight. Represents the number of people in the Wyoming
  population that this record represents.

- `agep`: Age (0–99 years).

- `sex`: Sex (1 = male, 2 = female).

- `rac1p`: Recoded detailed race (1 = White alone, 2 = Black or African
  American alone, 3 = American Indian alone, 6 = Asian alone, 9 = Two or
  more races).

- `hisp`: Recoded Hispanic origin (01 = Not Spanish/Hispanic/Latino;
  02–24 = specific Hispanic origin).

- `schl`: Educational attainment (24 categories: 01 = no schooling, 16 =
  regular high school diploma, 21 = bachelor's degree, 24 = doctorate
  degree).

- `esr`: Employment status recode (1 = civilian employed at work, 2 =
  civilian employed with job but not at work, 3 = unemployed, 4 = Armed
  Forces at work, 5 = Armed Forces not at work, 6 = Not in labor force).

- `pincp`: Total person income in the past 12 months (dollars, signed;
  negative values indicate a net loss). Multiply by `adjinc / 1e6` to
  adjust to constant dollars.

- `wagp`: Wages or salary income in the past 12 months (dollars). `NA`
  if not applicable.

- `hicov`: Health insurance coverage (1 = with health insurance, 2 =
  without health insurance).

- `dis`: Disability recode (1 = with a disability, 2 = without a
  disability).

- `povpip`: Income-to-poverty ratio (0–501; 501 means 501% or more).

- `wkhp`: Usual hours worked per week in the past 12 months. `NA` if not
  in the labor force.

- `adjinc`: Adjustment factor for income and earnings. Divide by
  1,000,000 and multiply income variables to convert to 2022 constant
  dollars.

## Source

U.S. Census Bureau. 2022 ACS 1-Year PUMS.
<https://www.census.gov/programs-surveys/acs/microdata/access.html>

## Details

**Survey design:** Successive difference replication (SDR). Use
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md)
with all 80 replicate weights:

    svy <- as_survey_replicate(
      acs_pums_wy,
      weights    = pwgtp,
      repweights = pwgtp1:pwgtp80,
      type       = "successive-difference"
    )

**Income adjustment:** Income variables (`pincp`, `wagp`) are in
survey-year dollars. Multiply by `adjinc / 1e6` to convert to 2022
inflation-adjusted dollars before comparing across ACS years.

**Metadata:** The ACS PUMS source is a plain CSV with no embedded
labels. Columns in `acs_pums_wy` carry no `"label"`, `"labels"`, or
`"question_preface"` attributes. Variable descriptions are documented
here in `?acs_pums_wy` and in `data-raw/README.md`. Use
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md)
and
[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md)
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
