#' NHANES 2017-2018: Demographics and Blood Pressure
#'
#' A merged dataset from the National Health and Nutrition Examination Survey
#' (NHANES) 2017-2018 cycle, combining demographic characteristics with blood
#' pressure measurements. Covers all 9,254 sampled participants; blood pressure
#' variables are `NA` for the 550 interview-only participants (`ridstatr == 1`).
#'
#' @format A data frame with 9,254 rows and 14 variables:
#' \describe{
#'   \item{seqn}{Respondent sequence number (unique identifier, join key).}
#'   \item{sdmvpsu}{Masked variance pseudo-PSU. Use as the cluster ID for
#'     variance estimation. See Details.}
#'   \item{sdmvstra}{Masked variance pseudo-stratum. Use as the stratification
#'     variable for variance estimation. See Details.}
#'   \item{wtmec2yr}{Full-sample 2-year MEC examination weight. Use for any
#'     analysis involving examination measurements (e.g., blood pressure).}
#'   \item{wtint2yr}{Full-sample 2-year interview weight. Use for analyses
#'     based on interview data only.}
#'   \item{ridstatr}{Interview/examination status: `1` = interview only,
#'     `2` = both interview and MEC examination.}
#'   \item{riagendr}{Gender: `1` = male, `2` = female.}
#'   \item{ridageyr}{Age in years at screening, top-coded at 80.}
#'   \item{ridreth3}{Race/Hispanic origin (6 categories): `1` = Mexican
#'     American, `2` = Other Hispanic, `3` = Non-Hispanic White,
#'     `4` = Non-Hispanic Black, `6` = Non-Hispanic Asian,
#'     `7` = Other/Multiracial.}
#'   \item{indfmpir}{Ratio of family income to the federal poverty level
#'     (continuous, 0–5; values >5 are top-coded at 5).}
#'   \item{dmdeduc2}{Education level for adults 20+: `1` = Less than 9th grade,
#'     `2` = 9th–11th grade, `3` = High school graduate/GED, `4` = Some
#'     college/AA, `5` = College graduate or above.}
#'   \item{bpxsy1}{Systolic blood pressure, 1st reading (mm Hg). `NA` if not
#'     examined.}
#'   \item{bpxdi1}{Diastolic blood pressure, 1st reading (mm Hg). `NA` if not
#'     examined.}
#'   \item{bpxpls}{60-second pulse rate (beats per minute). `NA` if not
#'     examined.}
#' }
#'
#' @details
#' **Survey design:** Taylor series linearization. When creating a survey
#' design object, use `sdmvpsu` as the cluster ID, `sdmvstra` as the stratum,
#' and `wtmec2yr` as the weight for examination-based analyses:
#'
#' ```r
#' svy <- as_survey(nhanes_2017,
#'   ids     = sdmvpsu,
#'   strata  = sdmvstra,
#'   weights = wtmec2yr
#' )
#' ```
#'
#' **Variable labels:** Each column retains its original NHANES variable label
#' as an R attribute (e.g., `attr(nhanes_2017$riagendr, "label")` returns
#' `"Gender"`). These are used by `extract_haven_metadata()` to auto-populate
#' the surveycore metadata system.
#'
#' **Source files:** DEMO_J.xpt (demographics) merged with BPX_J.xpt (blood
#' pressure) on `seqn`. Prepared by `data-raw/download-nhanes.R`.
#'
#' @source
#' National Center for Health Statistics, CDC. NHANES 2017-2018 Continuous
#' Survey. \url{https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/default.aspx?BeginYear=2017}
#'
#' @examples
#' # All 9,254 participants (interview + exam)
#' head(nhanes_2017)
#'
#' # Restrict to exam participants for blood pressure analysis
#' exam_only <- nhanes_2017[nhanes_2017$ridstatr == 2, ]
#'
#' # Check variable label
#' attr(nhanes_2017$riagendr, "label")
"nhanes_2017"


#' BRFSS 2023: Behavioral Risk Factor Surveillance System
#'
#' A stratified random sample from the 2023 Behavioral Risk Factor Surveillance
#' System (BRFSS), a U.S. telephone survey of health-related behaviors and
#' conditions among non-institutionalized adults 18 and older. Up to 200
#' respondents were sampled per state/territory (52 states/territories, ~10,400
#' rows total) to keep the dataset size manageable.
#'
#' @format A data frame with 10,400 rows and 22 variables:
#' \describe{
#'   \item{state}{State FIPS code (e.g., `1` = Alabama, `6` = California).}
#'   \item{psu}{Primary sampling unit. Use as the cluster ID for variance
#'     estimation.}
#'   \item{ststr}{Stratification variable. Use as the stratum for variance
#'     estimation.}
#'   \item{llcpwt}{Final combined landline and cell phone weight. Use for
#'     population-level estimates.}
#'   \item{llcpwt2}{Landline-only weight (for landline stratum analyses).}
#'   \item{dispcode}{Disposition code: `1100` = completed interview,
#'     `1200` = partial interview.}
#'   \item{sexvar}{Sex: `1` = male, `2` = female. (Renamed from `SEX` in 2022.)}
#'   \item{age80}{Age in years, top-coded at 80 (continuous).}
#'   \item{ageg5yr}{Age group in 5-year intervals (14 categories, 1 = 18–24,
#'     13 = 80+, 14 = don't know/refused/missing).}
#'   \item{race}{Race/ethnicity (5 categories): `1` = White only (non-Hispanic),
#'     `2` = Black only (non-Hispanic), `3` = Other race only (non-Hispanic),
#'     `4` = Multiracial (non-Hispanic), `5` = Hispanic.}
#'   \item{educag}{Education level (4 groups): `1` = Did not graduate high
#'     school, `2` = Graduated high school, `3` = Attended college/technical
#'     school, `4` = Graduated college/technical school.}
#'   \item{incomg1}{Annual household income (8 categories from < $15,000 to
#'     >= $200,000).}
#'   \item{genhlth}{General health: `1` = Excellent, `2` = Very good,
#'     `3` = Good, `4` = Fair, `5` = Poor. `7`/`9` = Don't know/refused.}
#'   \item{physhlth}{Number of days physical health was not good in the past 30
#'     days. `0`–`30` days; `88` = none; `77`/`99` = don't know/refused.}
#'   \item{menthlth}{Number of days mental health was not good in the past 30
#'     days. Same coding as `physhlth`.}
#'   \item{poorhlth}{Number of days poor health prevented usual activities in
#'     the past 30 days. Same coding as `physhlth`.}
#'   \item{hlthpl1}{Has any health care coverage: `1` = yes, `2` = no.}
#'   \item{smoke100}{Smoked at least 100 cigarettes in lifetime: `1` = yes,
#'     `2` = no.}
#'   \item{drnkany6}{Drank any alcoholic beverages in the past 30 days:
#'     `1` = yes, `2` = no.}
#'   \item{exerany2}{Did any physical activity or exercise (other than regular
#'     job) in the past 30 days: `1` = yes, `2` = no.}
#'   \item{bmi5cat}{BMI category: `1` = Underweight (BMI < 18.5),
#'     `2` = Normal weight (18.5–24.9), `3` = Overweight (25.0–29.9),
#'     `4` = Obese (>= 30.0).}
#'   \item{wtkg3}{Computed weight in kilograms (2 implicit decimal places;
#'     divide by 100 for kg).}
#' }
#'
#' @details
#' **Survey design:** Stratified sample with raking (post-stratification)
#' weights. When creating a survey design object:
#'
#' ```r
#' svy <- as_survey(brfss_2023,
#'   ids     = psu,
#'   strata  = ststr,
#'   weights = llcpwt
#' )
#' ```
#'
#' **Subsampling note:** The full 2023 BRFSS has 433,323 respondents. This
#' package dataset uses a stratified random sample of up to 200 respondents per
#' state/territory (set with `set.seed(42)`) to reduce file size. Use
#' `data-raw/download-brfss.R` to rebuild from the full source file.
#'
#' **Variable labels:** Each column retains its original BRFSS variable label as
#' an R attribute (e.g., `attr(brfss_2023$genhlth, "label")` returns
#' `"GENERAL HEALTH"`).
#'
#' @source
#' Centers for Disease Control and Prevention. 2023 BRFSS Survey Data.
#' \url{https://www.cdc.gov/brfss/annual_data/annual_2023.html}
#'
#' @examples
#' # Design summary
#' head(brfss_2023[, c("state", "psu", "ststr", "llcpwt", "genhlth")])
#'
#' # States represented
#' length(unique(brfss_2023$state))
#'
#' # Check variable label
#' attr(brfss_2023$genhlth, "label")
"brfss_2023"


#' ACS PUMS 2022 1-Year: Wyoming Persons
#'
#' All person records from the 2022 American Community Survey (ACS) 1-Year
#' Public Use Microdata Sample (PUMS) for Wyoming (state FIPS 56). Wyoming is
#' the least-populous U.S. state, making this the smallest state-level PUMS
#' file — ideal for fast tests and examples.
#'
#' @format A data frame with 5,962 rows and 96 variables. The first 3 variables
#' are design variables, the next 80 are replicate weights, and the final 13
#' are person characteristics:
#'
#' **Design variables:**
#' \describe{
#'   \item{puma}{Public Use Microdata Area code. Use as the cluster ID (PSU)
#'     for variance estimation.}
#'   \item{st}{State FIPS code (all `56` = Wyoming).}
#'   \item{pwgtp}{Person weight. Represents the number of people in the
#'     Wyoming population that this record represents.}
#' }
#'
#' **Replicate weights (`pwgtp1`–`pwgtp80`):**
#' Eighty successive difference replicate weights for variance estimation via
#' the successive difference replication (SDR) method. Use with
#' `as_survey_rep(..., type = "successive-difference")`.
#'
#' **Person characteristics:**
#' \describe{
#'   \item{agep}{Age (0–99 years).}
#'   \item{sex}{Sex: `1` = male, `2` = female.}
#'   \item{rac1p}{Recoded detailed race: `1` = White alone, `2` = Black or
#'     African American alone, `3` = American Indian alone, `6` = Asian alone,
#'     `9` = Two or more races.}
#'   \item{hisp}{Recoded Hispanic origin: `01` = Not Spanish/Hispanic/Latino;
#'     `02`–`24` = specific Hispanic origin.}
#'   \item{schl}{Educational attainment (24 categories): `01` = no schooling,
#'     `16` = regular high school diploma, `21` = bachelor's degree,
#'     `24` = doctorate degree.}
#'   \item{esr}{Employment status recode: `1` = civilian employed at work,
#'     `2` = civilian employed with job but not at work, `3` = unemployed,
#'     `4` = Armed Forces at work, `5` = Armed Forces not at work,
#'     `6` = Not in labor force.}
#'   \item{pincp}{Total person income in the past 12 months (dollars, signed;
#'     negative values indicate a net loss). Multiply by `adjinc / 1e6` to
#'     adjust to constant dollars.}
#'   \item{wagp}{Wages or salary income in the past 12 months (dollars).
#'     `NA` if not applicable.}
#'   \item{hicov}{Health insurance coverage: `1` = with health insurance,
#'     `2` = without health insurance.}
#'   \item{dis}{Disability recode: `1` = with a disability, `2` = without a
#'     disability.}
#'   \item{povpip}{Income-to-poverty ratio (0–501; `501` means 501% or more).}
#'   \item{wkhp}{Usual hours worked per week in the past 12 months. `NA` if
#'     not in the labor force.}
#'   \item{adjinc}{Adjustment factor for income and earnings. Divide by
#'     1,000,000 and multiply income variables to convert to 2022 constant
#'     dollars.}
#' }
#'
#' @details
#' **Survey design:** Successive difference replication (SDR). Use
#' `as_survey_rep()` with all 80 replicate weights:
#'
#' ```r
#' svy <- as_survey_rep(
#'   acs_pums_wy,
#'   weights    = pwgtp,
#'   repweights = starts_with("pwgtp") & !matches("^pwgtp$"),
#'   type       = "successive-difference"
#' )
#' ```
#'
#' **Income adjustment:** Income variables (`pincp`, `wagp`) are in survey-year
#' dollars. Multiply by `adjinc / 1e6` to convert to 2022 inflation-adjusted
#' dollars before comparing across ACS years.
#'
#' @source
#' U.S. Census Bureau. 2022 ACS 1-Year PUMS.
#' \url{https://www.census.gov/programs-surveys/acs/microdata/access.html}
#'
#' @examples
#' # Wyoming population represented
#' sum(acs_pums_wy$pwgtp)
#'
#' # Age distribution
#' hist(acs_pums_wy$agep, main = "Age distribution, Wyoming 2022",
#'      xlab = "Age")
#'
#' # Confirm 80 replicate weights are present
#' sum(grepl("^pwgtp[0-9]", names(acs_pums_wy)))
"acs_pums_wy"
