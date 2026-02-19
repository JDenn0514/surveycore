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
#' Use `wtint2yr` instead of `wtmec2yr` for interview-only variables
#' (e.g., income, education).
#'
#' **Metadata:**
#' All columns carry variable labels and value labels as R attributes,
#' automatically extracted into surveycore's metadata system when you call
#' `as_survey()`.
#'
#' - **Variable labels** (`"label"` attribute): A human-readable description of
#'   each column. Example: `attr(nhanes_2017$riagendr, "label")` returns
#'   `"Gender"`.
#' - **Value labels** (`"labels"` attribute): A named numeric vector mapping
#'   each code to its meaning. Example: `attr(nhanes_2017$riagendr, "labels")`
#'   returns `c(Male = 1, Female = 2)`.
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
#' # Inspect variable label
#' attr(nhanes_2017$riagendr, "label")
#'
#' # Inspect value labels
#' attr(nhanes_2017$riagendr, "labels")
#'
#' # Inspect value labels for race/ethnicity
#' attr(nhanes_2017$ridreth3, "labels")
"nhanes_2017"


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
#' **Metadata:**
#' The ACS PUMS source is a plain CSV with no embedded labels. Columns in
#' `acs_pums_wy` carry no `"label"`, `"labels"`, or `"question_preface"`
#' attributes. Variable descriptions are documented here in `?acs_pums_wy` and
#' in `data-raw/README.md`. Use `set_variable_labels()` and
#' `set_value_labels()` to attach labels manually before analysis if needed.
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


#' ANES 2024: American National Election Studies Time Series
#'
#' A 19-variable extract from the 2024 American National Election Studies
#' (ANES) Time Series Study, a landmark biennial pre- and post-election survey
#' of the American electorate. Fielded via face-to-face interview and web
#' (n = 5,521). This extract uses the FTF + Web combined design variables
#' (`v240103a`–`v240103d`), the recommended set for most analyses.
#'
#' @format A data frame with 5,521 rows and 19 variables.
#'
#' **Design variables:**
#' \describe{
#'   \item{v240103a}{Pre-election weight (FTF+Web combined). Use for
#'     variables asked before November 5, 2024.}
#'   \item{v240103b}{Post-election weight (FTF+Web combined). Use for
#'     variables asked after November 5, 2024.}
#'   \item{v240103c}{PSU (FTF+Web combined). Use as the cluster ID for
#'     variance estimation.}
#'   \item{v240103d}{Stratum (FTF+Web combined). Use as the stratification
#'     variable.}
#' }
#'
#' **Case and sample variables:**
#' \describe{
#'   \item{v240001}{2024 Time Series Case ID. Unique respondent identifier.}
#'   \item{v240003}{Sample type: `1` = Panel, `2` = Fresh Web, `3` = Fresh
#'     FTF, `4` = GSS.}
#'   \item{v240002c}{Pre/Post interview completion: `1` = Pre-election only,
#'     `2` = Pre- and post-election.}
#' }
#'
#' **Geographic:**
#' \describe{
#'   \item{v243002}{State FIPS code.}
#'   \item{v243007}{Census region: `1` = Northeast, `2` = Midwest,
#'     `3` = South, `4` = West.}
#' }
#'
#' **Demographics:**
#' \describe{
#'   \item{v241458x}{Age on Election Day (summary). Top-coded at 80.
#'     `-2` = missing.}
#'   \item{v241550}{Sex: `1` = male, `2` = female.}
#'   \item{v241501x}{Race/ethnicity (5-category summary): White non-Hispanic,
#'     Black non-Hispanic, Hispanic, Asian/NHPI non-Hispanic,
#'     Other/Multiracial non-Hispanic.}
#'   \item{v241465x}{Education (5-category summary): `1` = less than HS,
#'     `2` = HS diploma, `3` = some college, `4` = bachelor's degree,
#'     `5` = graduate degree.}
#'   \item{v241566x}{Household income (28 categories from < $5,000 to
#'     $250,000+).}
#' }
#'
#' **Political attitudes:**
#' \describe{
#'   \item{v241177}{Liberal-conservative self-placement (7-point scale):
#'     `1` = extremely liberal, `7` = extremely conservative.
#'     `99` = haven't thought about this.}
#'   \item{v241222}{Party identification strength: `1` = strong,
#'     `2` = not very strong.}
#'   \item{v241223}{Party identification lean (Independents): `1` = closer to
#'     Republican, `2` = neither, `3` = closer to Democrat.}
#' }
#'
#' **Post-election variables (pre/post completers only):**
#' \describe{
#'   \item{v242066}{Did respondent vote for President (POST): `1` = yes,
#'     `2` = no.}
#'   \item{v242067}{Presidential vote choice (POST): `1` = Harris,
#'     `2` = Trump, `3` = RFK Jr., `4` = West, `5` = Stein, `6` = Other.}
#' }
#'
#' @details
#' **Survey design:** Stratified cluster — use Taylor series linearization.
#' Two weights are available depending on whether the analysis uses pre- or
#' post-election variables:
#'
#' ```r
#' # Pre-election analysis (party ID, ideology, candidate preference)
#' svy_pre <- as_survey(anes_2024,
#'   ids     = v240103c,
#'   strata  = v240103d,
#'   weights = v240103a
#' )
#'
#' # Post-election analysis (validated vote choice)
#' svy_post <- as_survey(anes_2024,
#'   ids     = v240103c,
#'   strata  = v240103d,
#'   weights = v240103b
#' )
#' ```
#'
#' **Missing value codes:** The ANES uses negative integer codes for missing
#' data throughout: `-9` = Refused, `-8` = Don't know, `-4` = Technical error,
#' `-1` = Inapplicable, and others. These must be recoded to `NA` before
#' analysis. Check `attr(anes_2024$v241177, "labels")` for the full set of
#' codes for a given variable.
#'
#' **Metadata:**
#' All columns carry variable labels and value labels as R attributes from the
#' original Stata file, automatically extracted into surveycore's metadata
#' system when you call `as_survey()`.
#'
#' - **Variable labels** (`"label"` attribute): A human-readable description of
#'   each column. Example: `attr(anes_2024$v241550, "label")` returns
#'   `"PRE: What is your sex?"` (or similar ANES phrasing).
#' - **Value labels** (`"labels"` attribute): A named numeric vector mapping
#'   each code to its meaning, including all missing-value codes. Example:
#'   `attr(anes_2024$v241550, "labels")` returns a vector with entries for
#'   `Male`, `Female`, and the applicable negative missing codes.
#'
#' @source
#' American National Election Studies. 2024 Time Series Study.
#' \url{https://electionstudies.org} (free account required to download raw
#' data; the processed `.rda` is included in the package).
#' Prepared by `data-raw/prepare-anes-2024.R`.
#'
#' @examples
#' # Variables in the dataset
#' names(anes_2024)
#'
#' # Create pre-election design
#' # svy <- as_survey(anes_2024, ids = v240103c, strata = v240103d,
#' #                  weights = v240103a)
#'
#' # Inspect variable label (ANES uses opaque V-codes; labels give context)
#' attr(anes_2024$v241177, "label")
#'
#' # Inspect value labels, including missing-value codes
#' attr(anes_2024$v241177, "labels")
"anes_2024"


#' GSS 2024: General Social Survey
#'
#' A 27-variable extract from the 2024 General Social Survey (GSS), one of
#' the longest-running sociological surveys in the United States (fielded
#' annually or biennially since 1972). All 3,309 respondents from the 2024
#' cross-section are included.
#'
#' @format A data frame with 3,309 rows and 27 variables.
#'
#' **Design variables:**
#' \describe{
#'   \item{vpsu}{Variance primary sampling unit. Use as the cluster ID for
#'     variance estimation.}
#'   \item{vstrat}{Variance stratum. Use as the stratification variable.}
#'   \item{wtssps}{Person post-stratification weight. Standard analysis
#'     weight.}
#'   \item{wtssnrps}{Person post-stratification weight adjusted for
#'     differential non-response. Preferred when non-response bias is a
#'     concern.}
#' }
#'
#' **Case variables:**
#' \describe{
#'   \item{id}{Respondent ID. Unique case identifier.}
#'   \item{year}{Survey year (all `2024` in this extract).}
#'   \item{ballot}{Ballot form (`A`, `B`, `C`, or `D`). The GSS uses a
#'     split-ballot design; not all questions appear on every ballot.
#'     Inapplicable items are coded `-100`.}
#' }
#'
#' **Demographics:**
#' \describe{
#'   \item{age}{Age in years (`89` = 89 or older).}
#'   \item{sex}{Sex: `1` = male, `2` = female.}
#'   \item{race}{Race: `1` = white, `2` = black, `3` = other.}
#'   \item{hispanic}{Hispanic origin: `1` = not Hispanic; `2`–`50` = specific
#'     Hispanic origin.}
#'   \item{educ}{Highest year of school completed (0–20 years).}
#'   \item{degree}{Highest degree: `0` = less than HS, `1` = high school,
#'     `2` = associate, `3` = bachelor's, `4` = graduate.}
#'   \item{income16}{Total family income (26 categories from < $1,000 to
#'     $170,000+).}
#'   \item{marital}{Marital status: `1` = married, `2` = widowed,
#'     `3` = divorced, `4` = separated, `5` = never married.}
#' }
#'
#' **Employment:**
#' \describe{
#'   \item{wrkstat}{Labor force status: `1` = full time, `2` = part time,
#'     `3` = temporarily not working, `4` = unemployed, `5` = retired,
#'     `6` = in school, `7` = keeping house, `8` = other.}
#'   \item{hrs1}{Hours worked last week (for employed respondents only).}
#'   \item{adults}{Number of adults in household (`8` = 8 or more).}
#' }
#'
#' **Social and political attitudes:**
#' \describe{
#'   \item{partyid}{Party identification: `0` = strong Democrat,
#'     `3` = Independent, `6` = strong Republican, `7` = other party.}
#'   \item{polviews}{Political views: `1` = extremely liberal,
#'     `7` = extremely conservative.}
#'   \item{happy}{General happiness: `1` = very happy, `2` = pretty happy,
#'     `3` = not too happy.}
#'   \item{health}{Self-rated health: `1` = excellent, `2` = good,
#'     `3` = fair, `4` = poor.}
#'   \item{trust}{Social trust: `1` = most people can be trusted,
#'     `2` = can't be too careful, `3` = depends.}
#'   \item{natfare}{Government spending on welfare: `1` = too little,
#'     `2` = about right, `3` = too much.}
#'   \item{abany}{Abortion for any reason: `1` = yes, `2` = no.}
#'   \item{attend}{Religious service attendance: `0` = never,
#'     `8` = several times a week.}
#'   \item{relig}{Religious preference: `1` = Protestant, `2` = Catholic,
#'     `3` = Jewish, `4` = none, and others.}
#' }
#'
#' @details
#' **Survey design:** Stratified multi-stage cluster — use Taylor series
#' linearization:
#'
#' ```r
#' svy <- as_survey(gss_2024,
#'   ids     = vpsu,
#'   strata  = vstrat,
#'   weights = wtssps       # or wtssnrps for non-response-adjusted weight
#' )
#' ```
#'
#' **Missing value codes:** The GSS uses a consistent system of negative
#' integer codes for missing data across all variables:
#'
#' | Code | Meaning |
#' |------|---------|
#' | `-100` | Inapplicable (question not asked of this respondent) |
#' | `-99` | No answer |
#' | `-98` | Don't know |
#' | `-97` | Skipped on web |
#' | `-90` | Refused |
#'
#' These codes are stored as value labels on every column (check
#' `attr(gss_2024$happy, "labels")`). Recode them to `NA` before analysis.
#'
#' **Split-ballot design:** The `ballot` variable indicates which question
#' module a respondent received. Variables asked only on some ballots will
#' have `-100` (Inapplicable) for respondents on other ballots.
#'
#' **Metadata:**
#' All columns carry variable labels and value labels as R attributes from the
#' original SPSS file, automatically extracted into surveycore's metadata
#' system when you call `as_survey()`.
#'
#' - **Variable labels** (`"label"` attribute): A human-readable description of
#'   each column. Example: `attr(gss_2024$happy, "label")` returns
#'   `"GENERAL HAPPINESS"`.
#' - **Value labels** (`"labels"` attribute): A named numeric vector mapping
#'   each code to its meaning, including all missing-value codes. Example:
#'   `attr(gss_2024$happy, "labels")` returns entries for `Very happy`,
#'   `Pretty happy`, `Not too happy`, and the negative missing codes.
#'
#' @source
#' NORC at the University of Chicago. General Social Survey 2024.
#' \url{https://gss.norc.org} (free account required to download raw data;
#' the processed `.rda` is included in the package).
#' Prepared by `data-raw/prepare-gss-2024.R`.
#'
#' @examples
#' # Variables in the dataset
#' names(gss_2024)
#'
#' # Create survey design
#' # svy <- as_survey(gss_2024, ids = vpsu, strata = vstrat, weights = wtssps)
#'
#' # Inspect variable label
#' attr(gss_2024$happy, "label")
#'
#' # Inspect value labels (includes GSS missing-value codes)
#' attr(gss_2024$happy, "labels")
#'
#' # Split-ballot: how many respondents per ballot form?
#' table(gss_2024$ballot)
"gss_2024"


#' Pew NPORS 2025: National Public Opinion Reference Survey
#'
#' The 2025 National Public Opinion Reference Survey (NPORS), conducted
#' February 5 – June 18, 2025, by Pew Research Center (n = 5,022). An
#' address-based sample (ABS) drawn from the USPS Computerized Delivery
#' Sequence File, with respondents completing the survey online, by paper,
#' or by telephone in English or Spanish. All 65 columns from the public
#' release file are retained.
#'
#' @format A data frame with 5,022 rows and 65 variables.
#'
#' **Design variables:**
#' \describe{
#'   \item{respid}{Case ID. Unique respondent identifier.}
#'   \item{stratum}{Sampling stratum (10 levels, defined by census block
#'     group demographics).}
#'   \item{basewt}{Base weight — inverse probability of selection, with
#'     adaptive mode adjustment.}
#'   \item{weight}{Final weight — `basewt` after raking to Census population
#'     targets. Use for all population-level estimates.}
#' }
#'
#' **Mode and language:**
#' \describe{
#'   \item{mode}{Data collection mode: `1` = Online, `2` = Paper,
#'     `3` = Phone.}
#'   \item{language}{Language interview completed in: `1` = English,
#'     `2` = Spanish.}
#'   \item{languageinitial}{Language interview started in.}
#'   \item{interview_start}{Interview start timestamp.}
#'   \item{interview_end}{Interview end timestamp.}
#' }
#'
#' **Topical items:**
#' \describe{
#'   \item{econ1mod}{Economic conditions in your community today
#'     (Excellent / Good / Fair / Poor).}
#'   \item{econ1bmod}{Economic conditions one year from now
#'     (Better / Worse / Same).}
#'   \item{comtype2}{Community type: Urban / Suburban / Rural.}
#'   \item{unity}{Americans united vs. divided on values.}
#'   \item{crimesafe}{Area safety in terms of crime (Extremely safe – Not at
#'     all safe).}
#'   \item{govprotct}{Government's role in protecting people from themselves.}
#'   \item{moregunimpact}{Impact of more gun ownership on crime.}
#'   \item{fin_sit}{Household financial situation (Comfortable – Can't meet
#'     basics).}
#'   \item{vet1}{Military service in household.}
#'   \item{vol12_cps}{Volunteered for any organization in past 12 months.}
#' }
#'
#' **Internet and technology:**
#' \describe{
#'   \item{eminuse}{Uses internet or email at least occasionally.}
#'   \item{intmob}{Accesses internet on a mobile device.}
#'   \item{intfreq}{Internet use frequency (6 categories).}
#'   \item{intfreq_collapsed}{Internet use frequency (4 categories, derived).}
#'   \item{home4nw2}{Subscribes to home internet service.}
#'   \item{bbhome}{Home internet type (dial-up, broadband, etc.).}
#'   \item{radio}{Listens to radio.}
#'   \item{device1a}{Has a cell phone.}
#'   \item{smart2}{Cell phone is a smartphone.}
#'   \item{nhisll}{Has a working landline telephone at home.}
#' }
#'
#' **Social media use battery (`smuse_*`, 11 variables):**
#' All 11 `smuse_*` variables share `question_preface` = `"Please indicate
#' whether or not you ever use the following websites or apps."` Values:
#' `1` = Selected, `2` = Not selected, `99` = Refused.
#' \describe{
#'   \item{smuse_fb}{Facebook.}
#'   \item{smuse_yt}{YouTube.}
#'   \item{smuse_x}{X (formerly Twitter).}
#'   \item{smuse_ig}{Instagram.}
#'   \item{smuse_sc}{Snapchat.}
#'   \item{smuse_wa}{WhatsApp.}
#'   \item{smuse_tt}{TikTok.}
#'   \item{smuse_rd}{Reddit.}
#'   \item{smuse_bsk}{Bluesky.}
#'   \item{smuse_th}{Threads.}
#'   \item{smuse_ts}{Truth Social.}
#' }
#'
#' **Religion:**
#' \describe{
#'   \item{relig}{Current religion (12 categories).}
#'   \item{religcat1}{Religion (4 categories: Protestant, Catholic,
#'     Unaffiliated, Other).}
#'   \item{born}{Born-again or evangelical Christian.}
#'   \item{attendper}{In-person religious service attendance (6 categories).}
#'   \item{attendonline2}{Online/TV religious service participation
#'     (6 categories).}
#'   \item{relimp}{Importance of religion in life (Very – Not at all).}
#'   \item{pray}{Prayer frequency outside of services (7 categories).}
#' }
#'
#' **Demographics:**
#' \describe{
#'   \item{hisp}{Hispanic origin.}
#'   \item{racecmb}{Race (5 categories).}
#'   \item{racethn}{Race-ethnicity (5 categories including Asian
#'     non-Hispanic).}
#'   \item{agegrp}{Age in 13 five-year groups.}
#'   \item{agecat}{Age (4 categories: 18-29, 30-49, 50-64, 65+).}
#'   \item{birthplace}{U.S. born vs. foreign born.}
#'   \item{gender}{Gender (man / woman / other).}
#'   \item{adults}{Number of adults in household.}
#'   \item{inc_sdt1}{Total family income (8 categories from < $30,000 to
#'     $150,000+).}
#'   \item{cregion}{Census region (NE / MW / S / W).}
#'   \item{metro}{Metropolitan area indicator.}
#' }
#'
#' **Politics and civic engagement:**
#' \describe{
#'   \item{registration}{Registered to vote at current address.}
#'   \item{party}{Party affiliation (Rep / Dem / Ind / Other).}
#'   \item{partyln}{Party lean for Independents (Rep / Dem).}
#'   \item{partysum}{Party summary (Rep+Lean Rep / Dem+Lean Dem / No lean).}
#'   \item{voted2024}{Voted in the 2024 presidential election.}
#'   \item{votegen_post}{2024 presidential vote choice (Trump / Harris /
#'     Other).}
#' }
#'
#' @details
#' **Survey design:** Stratified address-based sample with raking
#' post-stratification — use Taylor series linearization. NPORS has no PSU
#' (each address is its own unit, effectively a stratified SRS):
#'
#' ```r
#' svy <- as_survey(pew_npors_2025,
#'   strata  = stratum,
#'   weights = weight
#' )
#' ```
#'
#' Use `basewt` instead of `weight` for sensitivity analyses comparing
#' pre- and post-raking estimates.
#'
#' **Metadata:**
#' All columns carry variable labels and value labels as R attributes from the
#' original SPSS file. The 11 `smuse_*` battery variables additionally carry
#' a `"question_preface"` attribute with the shared question stem. All three
#' attribute types are automatically extracted into surveycore's metadata
#' system when you call `as_survey()`.
#'
#' - **Variable labels** (`"label"` attribute): A human-readable description of
#'   each column — for `smuse_*` variables this is just the platform name
#'   (e.g., `"Facebook"`). Example: `attr(pew_npors_2025$smuse_fb, "label")`
#'   returns `"Facebook"`.
#' - **Value labels** (`"labels"` attribute): A named numeric vector mapping
#'   each code to its meaning. Example:
#'   `attr(pew_npors_2025$smuse_fb, "labels")` returns
#'   `c(Selected = 1, "Not selected" = 2, Refused = 99)`.
#' - **Question preface** (`"question_preface"` attribute): The shared question
#'   stem for battery items, set on all `smuse_*` columns. Example:
#'   `attr(pew_npors_2025$smuse_fb, "question_preface")` returns
#'   `"Please indicate whether or not you ever use the following websites or
#'   apps."`.
#'
#' @source
#' Pew Research Center. 2025 National Public Opinion Reference Survey.
#' \url{https://www.pewresearch.org/datasets} (free account required to
#' download raw data; the processed `.rda` is included in the package).
#' Prepared by `data-raw/prepare-pew-npors-2025.R`.
#'
#' @examples
#' # Variables in the dataset
#' names(pew_npors_2025)
#'
#' # Create survey design (no PSU for ABS design)
#' # svy <- as_survey(pew_npors_2025, strata = stratum, weights = weight)
#'
#' # Inspect variable label
#' attr(pew_npors_2025$smuse_fb, "label")
#'
#' # Inspect value labels
#' attr(pew_npors_2025$smuse_fb, "labels")
#'
#' # Inspect question preface (shared stem for all smuse_* battery items)
#' attr(pew_npors_2025$smuse_fb, "question_preface")
"pew_npors_2025"


#' Pew Jewish Americans 2020
#'
#' The extended survey dataset from Pew Research Center's 2019-2020 Survey
#' of U.S. Jews, fielded November 19, 2019 – June 3, 2020 (n = 5,881).
#' Respondents were drawn from a national, stratified random sample of
#' residential mailing addresses with oversampling of households likely to
#' contain Jewish respondents. The dataset carries 100 jackknife replicate
#' weights alongside the main weight.
#'
#' @format A data frame with 5,881 rows and 130 variables.
#'
#' **Design variables (101 columns):**
#' \describe{
#'   \item{extweight}{Full-sample base weight. Use for all estimates.}
#' }
#' `extweight1`–`extweight100`: 100 jackknife replicate weights for variance
#' estimation. Use with `as_survey_rep(..., type = "JK1")`.
#'
#' **Identity and classification:**
#' \describe{
#'   \item{qkey}{Unique respondent identifier.}
#'   \item{jewishcat}{Jewish identity category: `1` = Jews by religion,
#'     `2` = Jews of no religion, `3` = Jewish background,
#'     `4` = Jewish affinity, `5` = Not Jewish.}
#'   \item{finalmode}{Collection mode: `1` = CAWI (online),
#'     `2` = Teleform (mail),
#'     `3` = Screener CAWI + Extended Teleform.}
#' }
#'
#' **Geography and demographics:**
#' \describe{
#'   \item{region}{Census region: `1` = Northeast, `2` = Midwest,
#'     `3` = South, `4` = West.}
#'   \item{sexask}{Sex: `1` = male, `2` = female, `99` = not answered.}
#'   \item{age4cat}{Age: `1` = 18-29, `2` = 30-49, `3` = 50-64, `4` = 65+;
#'     `999` = no answer.}
#'   \item{educ4cat}{Education: `1` = HS or less, `2` = some college,
#'     `3` = college graduate, `4` = postgraduate; `99` = no answer.}
#'   \item{religmod}{Current religion (24 categories including Jewish
#'     subgroups and combinations).}
#'   \item{hisp}{Hispanic origin: `1` = yes, `2` = no.}
#'   \item{racecmb}{Race (5 categories).}
#'   \item{racethn}{Race-ethnicity (4 categories).}
#' }
#'
#' **Attitudes:**
#' \describe{
#'   \item{presapp}{Presidential approval (Trump): `1` = Strongly approve,
#'     `2` = Somewhat approve, `3` = Somewhat disapprove,
#'     `4` = Strongly disapprove.}
#'   \item{track}{Right track/wrong track: `1` = Right direction,
#'     `2` = Wrong track.}
#'   \item{satisfpersmod}{Personal life satisfaction: `1` = Excellent,
#'     `2` = Good, `3` = Only fair, `4` = Poor.}
#'   \item{localrating}{Community as a place to live: `1` = Excellent,
#'     `2` = Good, `3` = Only fair, `4` = Poor.}
#' }
#'
#' **Battery 1 — Religious identity (select-all-that-apply, 4 variables):**
#' `relconsider_a`–`relconsider_d` share `question_preface` = `"Aside from
#' religion, do you consider yourself to be any of the following in any way
#' (for example, ethnically, culturally, or because of your family's
#' background)?"` Values: `1` = Selected, `2` = Not selected, `99` = Refused.
#' \describe{
#'   \item{relconsider_a}{Jewish.}
#'   \item{relconsider_b}{Catholic.}
#'   \item{relconsider_c}{Mormon.}
#'   \item{relconsider_d}{Muslim.}
#' }
#'
#' **Battery 2 — Religious background (select-all-that-apply, 4 variables):**
#' `relraised_a`–`relraised_d` share `question_preface` = `"Please indicate
#' whether you were raised in any of the following traditions or had a parent
#' from any of the following backgrounds."` Values: `1` = Selected,
#' `2` = Not selected, `99` = Refused.
#' \describe{
#'   \item{relraised_a}{Jewish.}
#'   \item{relraised_b}{Catholic.}
#'   \item{relraised_c}{Mormon.}
#'   \item{relraised_d}{Muslim.}
#' }
#'
#' **Battery 3 — Discrimination perceptions (rating scale, 6 variables):**
#' `discrim_a`–`discrim_f` share `question_preface` = `"Please tell us how
#' much discrimination there is against each of these groups in our society
#' today."` Values: `1` = A lot, `2` = Some, `3` = Not much,
#' `4` = None at all, `99` = Not answered.
#' \describe{
#'   \item{discrim_a}{Evangelical Christians.}
#'   \item{discrim_b}{Muslims.}
#'   \item{discrim_c}{Jews.}
#'   \item{discrim_d}{Blacks.}
#'   \item{discrim_e}{Hispanics.}
#'   \item{discrim_f}{Gays and lesbians.}
#' }
#'
#' @details
#' **Survey design:** Jackknife replication — use `as_survey_rep()` with all
#' 100 replicate weights:
#'
#' ```r
#' svy <- as_survey_rep(
#'   pew_jewish_2020,
#'   weights    = extweight,
#'   repweights = starts_with("extweight") & !matches("^extweight$"),
#'   type       = "JK1"
#' )
#' ```
#'
#' **Jewish identity classification:** The `jewishcat` variable classifies
#' respondents into five mutually exclusive categories used in the published
#' Pew report. Use `jewishcat` rather than constructing your own
#' classification from the raw religion variables.
#'
#' **Metadata:**
#' All columns carry variable labels and value labels as R attributes from the
#' original Stata file. The three battery variable groups additionally carry a
#' `"question_preface"` attribute with the shared question stem. All three
#' attribute types are automatically extracted into surveycore's metadata
#' system when you call `as_survey_rep()`.
#'
#' - **Variable labels** (`"label"` attribute): A human-readable description of
#'   each column — for battery items this is the unique item text (e.g.,
#'   `"Jewish"`). Example: `attr(pew_jewish_2020$relconsider_a, "label")`
#'   returns `"Jewish"`.
#' - **Value labels** (`"labels"` attribute): A named numeric vector mapping
#'   each code to its meaning. Example:
#'   `attr(pew_jewish_2020$relconsider_a, "labels")` returns
#'   `c(Selected = 1, "Not selected" = 2, Refused = 99)`.
#' - **Question preface** (`"question_preface"` attribute): The shared question
#'   stem for each battery group. Example:
#'   `attr(pew_jewish_2020$discrim_a, "question_preface")` returns
#'   `"Please tell us how much discrimination there is against each of these
#'   groups in our society today."`.
#'
#' @source
#' Pew Research Center. Jewish Americans in 2020 (Extended Dataset).
#' \url{https://www.pewresearch.org/datasets} (free account required to
#' download raw data; the processed `.rda` is included in the package).
#' Prepared by `data-raw/prepare-pew-jewish-2020.R`.
#'
#' @examples
#' # Design variables
#' head(pew_jewish_2020[, c("qkey", "extweight", "jewishcat")])
#'
#' # Confirm 100 replicate weights are present
#' sum(grepl("^extweight[0-9]", names(pew_jewish_2020)))
#'
#' # Inspect variable label (unique item text for battery variable)
#' attr(pew_jewish_2020$discrim_a, "label")
#'
#' # Inspect value labels
#' attr(pew_jewish_2020$discrim_a, "labels")
#'
#' # Inspect question preface (shared stem across the battery)
#' attr(pew_jewish_2020$discrim_a, "question_preface")
#'
#' # Jewish identity distribution (use jewishcat, not raw religion vars)
#' table(pew_jewish_2020$jewishcat)
"pew_jewish_2020"
