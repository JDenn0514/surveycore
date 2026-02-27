## Pew Research Center — Jewish Americans in 2020: Prepare package dataset
##
## Source: Pew Research Center
## URL: https://www.pewresearch.org/datasets/
## License: Requires free Pew Research Center account; processed subsets
##          permitted for academic/non-commercial use per Pew terms of use.
##
## Output dataset: pew_jewish_2020
##   5,881 respondents (adults who completed the extended survey)
##   Design: Jackknife replication (EXTWEIGHT / EXTWEIGHT1–EXTWEIGHT100)
##
## The raw .dta file must be manually downloaded from the Pew Research Center
## (free account required) and placed at:
##   data-raw/pew/Jewish_Americans_2020_Datasets_v2/
##     Jewish Americans in 2020 Extended Dataset.dta
##
## Run this script from the package root: source("data-raw/prepare-pew-jewish-2020.R")

library(haven)
library(janitor)
library(usethis)

DTA_FILE <- file.path(
  here::here(),
  "data-raw",
  "pew",
  "Jewish_Americans_2020_Datasets_v2",
  "Jewish Americans in 2020 Extended Dataset.dta"
)

if (!file.exists(DTA_FILE)) {
  stop(
    "Raw file not found: ",
    DTA_FILE,
    "\n",
    "Download the Jewish Americans in 2020 Extended Dataset (.dta) from:\n",
    "  https://www.pewresearch.org/datasets/\n",
    "(free account required) and place it at the path above."
  )
}

## ---- 1. Read ----

message("Reading Jewish Americans in 2020 Extended Dataset.dta (~6.2 MB)...")
pew_raw <- haven::read_dta(DTA_FILE)
message("Read ", nrow(pew_raw), " rows x ", ncol(pew_raw), " cols")

## ---- 2. Select columns ----
##
## Design variables:
##   EXTWEIGHT:      Full-sample jackknife base weight
##   EXTWEIGHT1–100: Jackknife replicate weights (100 replicates)
##
## Respondent background:
##   QKEY:         Unique respondent identifier
##   JEWISHCAT:    Jewish identity category (core variable)
##   FINALMODE:    Data collection mode (online, phone, mail)
##   REGION:       Census region
##   SEXASK:       Sex (male / female)
##   AGE4CAT:      Age in 4 categories
##   EDUC4CAT:     Education in 4 categories
##   RELIGMOD:     Current religion
##   HISP:         Hispanic origin
##   RACECMB:      Race (combined)
##   RACETHN:      Race/ethnicity
##
## Religious identity and practice:
##   RELCONSIDER_A–D: Self-described religious identity (multi-select)
##   RELRAISED_A–D:   Religion raised in (multi-select)
##   ATTEND:          Synagogue/church attendance frequency (if present)
##
## Attitudes and opinions:
##   PRESAPP:         Presidential approval (Trump)
##   TRACK:           Country right/wrong track
##   DISCRIM_A–F:     Perceived discrimination against various groups
##   SATISFPERSMOD:   Personal satisfaction with community
##   LOCALRATING:     Community as a place to live

keep_cols <- c(
  # Design: main weight + 100 jackknife replicates
  "EXTWEIGHT",
  paste0("EXTWEIGHT", 1:100),
  # ID / admin
  "QKEY",
  "JEWISHCAT",
  "FINALMODE",
  "REGION",
  # Demographics
  "SEXASK",
  "AGE4CAT",
  "EDUC4CAT",
  "RELIGMOD",
  "HISP",
  "RACECMB",
  "RACETHN",
  # Religious identity
  "RELCONSIDER_A",
  "RELCONSIDER_B",
  "RELCONSIDER_C",
  "RELCONSIDER_D",
  "RELRAISED_A",
  "RELRAISED_B",
  "RELRAISED_C",
  "RELRAISED_D",
  # Attitudes
  "PRESAPP",
  "TRACK",
  "DISCRIM_A",
  "DISCRIM_B",
  "DISCRIM_C",
  "DISCRIM_D",
  "DISCRIM_E",
  "DISCRIM_F",
  "SATISFPERSMOD",
  "LOCALRATING"
)

missing_cols <- setdiff(keep_cols, names(pew_raw))
if (length(missing_cols) > 0) {
  warning(
    "These expected columns were not found: ",
    paste(missing_cols, collapse = ", ")
  )
  keep_cols <- intersect(keep_cols, names(pew_raw))
}

pew_sub <- pew_raw[, keep_cols]
rownames(pew_sub) <- NULL

## ---- 3. Strip haven class, preserve label/labels attributes ----

as_plain <- function(df) {
  df[] <- lapply(df, function(x) {
    if (!inherits(x, "haven_labelled")) {
      return(x)
    }
    raw <- as.vector(x)
    lbl <- attr(x, "label", exact = TRUE)
    lbvl <- attr(x, "labels", exact = TRUE)
    if (!is.null(lbl)) {
      attr(raw, "label") <- lbl
    }
    if (!is.null(lbvl)) {
      if (!is.null(names(lbvl))) {
        clean <- sub("^[0-9]+ = ", "", names(lbvl))
        names(lbvl) <- gsub(
          "(^|[[:space:]])([[:alpha:]])",
          "\\1\\U\\2",
          tolower(clean),
          perl = TRUE
        )
      }
      attr(raw, "labels") <- lbvl
    }
    raw
  })
  df
}

pew_jewish_2020 <- as_plain(pew_sub)

## ---- 4. Standardise column names to snake_case ----
##
## Key mapping (SCREAMING_SNAKE → lower_snake_case):
##   QKEY → qkey | JEWISHCAT → jewishcat | FINALMODE → finalmode
##   REGION → region | SEXASK → sexask | AGE4CAT → age4cat
##   EDUC4CAT → educ4cat | RELIGMOD → religmod | HISP → hisp
##   RACECMB → racecmb | RACETHN → racethn
##   RELCONSIDER_A → relconsider_a | (all RELCONSIDER_* follow same pattern)
##   RELRAISED_A → relraised_a
##   PRESAPP → presapp | TRACK → track
##   DISCRIM_A → discrim_a | (all DISCRIM_* follow same pattern)
##   EXTWEIGHT → extweight | EXTWEIGHT1 → extweight1 ... EXTWEIGHT100 → extweight100

pew_jewish_2020 <- clean_names(pew_jewish_2020)

## ---- 5. Attach battery question_preface attributes ----
##
## The .dta label field is truncated; set the full question stem as
## question_preface so surveycore battery helpers can surface it.
##
## Battery 3 (discrim_a–f):
##   "Please tell us how much discrimination there is against each of
##    these groups in our society today."

discrim_preface <- paste0(
  "Please tell us how much discrimination there is against each of ",
  "these groups in our society today."
)
for (col in grep("^discrim_", names(pew_jewish_2020), value = TRUE)) {
  attr(pew_jewish_2020[[col]], "question_preface") <- discrim_preface
}

## ---- 6. Save ----

message("Saving pew_jewish_2020 to data/...")
usethis::use_data(pew_jewish_2020, overwrite = TRUE)

message(
  "Done. pew_jewish_2020: ",
  nrow(pew_jewish_2020),
  " rows x ",
  ncol(pew_jewish_2020),
  " cols"
)
message("  Design: jackknife replication")
message("  Base weight: extweight")
message("  Replicate weights: extweight1–extweight100")
message("Document with: ?pew_jewish_2020")
