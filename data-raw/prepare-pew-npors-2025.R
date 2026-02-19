## Pew Research Center — 2025 National Public Opinion Reference Survey (NPORS)
## Prepare package dataset
##
## Source: Pew Research Center
## URL: https://www.pewresearch.org/datasets/
## License: Requires free Pew Research Center account; processed subsets
##          permitted for academic/non-commercial use per Pew terms of use.
##
## Output dataset: pew_npors_2025
##   5,022 respondents (national address-based sample, multimode)
##   Dates: February 5 – June 18, 2025
##   Modes: Online, Paper, Telephone (English and Spanish)
##   Design: Stratified sample with raking adjustment (STRATUM / WEIGHT)
##
## We read from the SPSS (.sav) file rather than the CSV because the SPSS file
## carries variable and value labels that the CSV lacks.
##
## The raw files must be manually downloaded from the Pew Research Center
## (free account required) and placed at:
##   data-raw/pew/NPORS 2025/NPORS_2025_for_public_release_FINAL.sav
##
## Run this script from the package root: source("data-raw/prepare-pew-npors-2025.R")

library(haven)
library(janitor)
library(usethis)

SAV_FILE <- file.path(
  here::here(), "data-raw", "pew", "NPORS 2025",
  "NPORS_2025_for_public_release_FINAL.sav"
)

if (!file.exists(SAV_FILE)) {
  stop(
    "Raw file not found: ", SAV_FILE, "\n",
    "Download the 2025 NPORS public release SPSS file from:\n",
    "  https://www.pewresearch.org/datasets/\n",
    "(free account required) and place it at the path above."
  )
}

## ---- 1. Read ----
##
## The SPSS file has the same data as the CSV but includes variable labels and
## value labels on every column. We read it as the primary source.

message("Reading NPORS_2025_for_public_release_FINAL.sav (~566 KB)...")
pew_raw <- read_spss(SAV_FILE)
message("Read ", nrow(pew_raw), " rows x ", ncol(pew_raw), " cols")

## ---- 2. Column inventory ----
##
## All 65 columns are retained — the dataset is small and every column is
## potentially relevant for survey methods demonstrations.
##
## Design variables:
##   STRATUM:  10 sampling strata (crossed by mode × language × region)
##   BASEWT:   Base weight (before raking)
##   WEIGHT:   Final post-stratification weight (after raking)
##
## Respondent identifiers and mode:
##   RESPID, MODE, LANGUAGE, LANGUAGEINITIAL
##   INTERVIEW_START, INTERVIEW_END
##
## Topical content (see NPORS_2025_codebook_FINAL.xlsx for full details):
##   ECON1MOD, ECON1BMOD: Economic evaluations
##   UNITY, CRIMESAFE, GOVPROTCT, MOREGUNIMPACT: Policy opinions
##   FIN_SIT: Financial situation
##   VET1, VOL12_CPS: Civic participation
##   EMINUSE, INTMOB, INTFREQ*: Internet use
##   HOME4NW2, BBHOME: Home internet
##   SMUSE_*: Social media platform use (11 platforms) [select-all-that-apply]
##   RADIO, DEVICE1A, SMART2: Media device use
##   NHISLL: Landline telephone
##   RELIG, RELIGCAT1, BORN, ATTENDPER, ATTENDONLINE2, RELIMP, PRAY: Religion
##   EDUCCAT, REGISTRATION, PARTY, PARTYLN, PARTYSUM: Politics
##   HISP, RACECMB, RACETHN: Race/ethnicity
##   AGEGRP, AGECAT, BIRTHPLACE, GENDER, ADULTS: Demographics
##   VOTED2024, VOTEGEN_POST: 2024 election
##   INC_SDT1: Income
##   CREGION, METRO: Geography

## No column subsetting needed — all 65 are informative and the file is small.
pew_npors_2025 <- as.data.frame(pew_raw)
rownames(pew_npors_2025) <- NULL

## ---- 3. Strip haven class, preserve label/labels attributes ----

as_plain <- function(df) {
  df[] <- lapply(df, function(x) {
    if (!inherits(x, "haven_labelled")) return(x)
    raw  <- as.vector(x)
    lbl  <- attr(x, "label",  exact = TRUE)
    lbvl <- attr(x, "labels", exact = TRUE)
    if (!is.null(lbl))  attr(raw, "label")  <- lbl
    if (!is.null(lbvl)) attr(raw, "labels") <- lbvl
    raw
  })
  df
}

pew_npors_2025 <- as_plain(pew_npors_2025)

## ---- 4. Clean variable labels and split battery labels ----
##
## (a) Variable name prefix stripping
##     Many SPSS labels follow the pattern "VARNAME. Question text".
##     Strip the uppercase prefix so labels are just the question text.
##     Pattern: one or more uppercase letters/digits/underscores, followed by
##     ". " at the start of the string.
##
## (b) SMUSE_* battery  [select-all-that-apply]
##     SPSS label format: "SMUSE_XX. Platform // Please indicate whether or
##       not you ever use the following websites or apps."
##     Split on " // " → label = platform name, question_preface = shared stem.
##     Value labels simplified to: 1=Selected, 2=Not selected, 99=Refused.

## Mapping of SMUSE variable → platform name
smuse_items <- c(
  SMUSE_FB  = "Facebook",
  SMUSE_YT  = "YouTube",
  SMUSE_X   = "X (formerly Twitter)",
  SMUSE_IG  = "Instagram",
  SMUSE_SC  = "Snapchat",
  SMUSE_WA  = "WhatsApp",
  SMUSE_TT  = "TikTok",
  SMUSE_RD  = "Reddit",
  SMUSE_BSK = "Bluesky",
  SMUSE_TH  = "Threads",
  SMUSE_TS  = "Truth Social"
)
smuse_preface <- "Please indicate whether or not you ever use the following websites or apps."
smuse_vals    <- c("Selected" = 1, "Not selected" = 2, "Refused" = 99)

for (col in names(pew_npors_2025)) {
  lbl <- attr(pew_npors_2025[[col]], "label", exact = TRUE)
  if (is.null(lbl)) next

  if (col %in% names(smuse_items)) {
    ## SMUSE battery: replace label with platform name, add preface, simplify values
    attr(pew_npors_2025[[col]], "label")            <- smuse_items[[col]]
    attr(pew_npors_2025[[col]], "question_preface") <- smuse_preface
    attr(pew_npors_2025[[col]], "labels")           <- smuse_vals
  } else {
    ## Strip leading "VARNAME. " prefix from other variable labels
    cleaned <- sub("^[A-Z][A-Z0-9_]*\\. ", "", lbl)
    attr(pew_npors_2025[[col]], "label") <- cleaned
  }
}

## ---- 5. Standardise column names to snake_case ----
##
## Key mapping (SCREAMING_SNAKE → lower_snake_case):
##   RESPID → respid | STRATUM → stratum | WEIGHT → weight | BASEWT → basewt
##   MODE → mode | LANGUAGE → language | GENDER → gender | AGEGRP → agegrp
##   RACETHN → racethn | EDUCCAT → educcat | PARTY → party | PARTYLN → partyln
##   VOTED2024 → voted2024 | CREGION → cregion | METRO → metro
##   SMUSE_FB → smuse_fb | (all SMUSE_* follow same pattern)
##   INTERVIEW_START → interview_start | INTERVIEW_END → interview_end

pew_npors_2025 <- clean_names(pew_npors_2025)

## ---- 6. Save ----

message("Saving pew_npors_2025 to data/...")
usethis::use_data(pew_npors_2025, overwrite = TRUE)

message("Done. pew_npors_2025: ", nrow(pew_npors_2025), " rows x ", ncol(pew_npors_2025), " cols")
message("  Design: stratum = stratum, weight = weight")
message("  Base weight (pre-raking): basewt")
message("  SMUSE battery: smuse_fb through smuse_ts (question_preface set)")
message("Document with: ?pew_npors_2025")
