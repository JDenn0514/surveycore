## BRFSS 2023: Download and prepare package dataset
##
## Source: Behavioral Risk Factor Surveillance System, CDC
## URL: https://www.cdc.gov/brfss/annual_data/annual_2023.html
## License: Public domain (US Government work)
##
## Output dataset: brfss_2023
##   Stratified random sample: up to 200 respondents per state/territory (~10,000 rows)
##   Design: Stratified with raking weights (_PSU / _STSTR / _LLCPWT)
##
## Note: The full file (LLCP2023.XPT) is ~1.1 GB. This script reads the entire
## file into memory before subsetting. Expect ~2-4 minutes and ~4 GB peak RAM.
##
## Run this script from the package root: source("data-raw/download-brfss.R")

library(haven)
library(janitor)
library(usethis)

DEST_DIR <- file.path(here::here(), "data-raw", "brfss")
ZIP_FILE <- file.path(DEST_DIR, "LLCP2023XPT.zip")
XPT_FILE <- file.path(DEST_DIR, "LLCP2023.XPT")
ZIP_URL  <- "https://www.cdc.gov/brfss/annual_data/2023/files/LLCP2023XPT.zip"

## ---- 1. Download ----

if (!file.exists(XPT_FILE)) {
  if (!file.exists(ZIP_FILE)) {
    message("Downloading LLCP2023XPT.zip (~89 MB)...")
    download.file(ZIP_URL, destfile = ZIP_FILE, mode = "wb", quiet = FALSE)
  }
  message("Unzipping...")
  unzip(ZIP_FILE, exdir = DEST_DIR)
  # The unzipped file has a trailing space; rename it if needed
  spaced <- file.path(DEST_DIR, "LLCP2023.XPT ")
  if (file.exists(spaced)) file.rename(spaced, XPT_FILE)
} else {
  message("LLCP2023.XPT already exists, skipping download.")
}

## ---- 2. Read ----

message("Reading LLCP2023.XPT (~1.1 GB) — this may take several minutes...")
brfss_raw <- read_xpt(XPT_FILE)
message("Read ", nrow(brfss_raw), " rows x ", ncol(brfss_raw), " cols")

## ---- 3. Select columns ----

keep_cols <- c(
  # Design variables
  "_STATE",    # State FIPS code
  "_PSU",      # Primary sampling unit
  "_STSTR",    # Stratification variable
  "_LLCPWT",   # Final combined weight (landline + cell)
  "_LLCPWT2",  # Landline-only weight (for landline stratum)
  "DISPCODE",  # Disposition: 1100=complete, 1200=partial
  # Respondent characteristics
  "SEXVAR",    # Sex (1=male, 2=female) — renamed from SEX in 2022+
  "_AGE80",    # Age (continuous, top-coded at 80)
  "_AGEG5YR",  # Age in 5-year groups
  "_RACE",     # Race/ethnicity (5 categories)
  "_EDUCAG",   # Education (4 groups)
  "_INCOMG1",  # Annual household income (8 categories)
  # General health
  "GENHLTH",   # General health: 1=excellent ... 5=poor
  "PHYSHLTH",  # Days physical health not good (past 30 days; 88=none)
  "MENTHLTH",  # Days mental health not good (past 30 days; 88=none)
  "POORHLTH",  # Days poor health prevented usual activity (past 30 days)
  # Health coverage
  "_HLTHPL1",  # Has health plan: 1=yes, 2=no
  # Health behaviors
  "SMOKE100",  # Smoked 100+ cigarettes in lifetime: 1=yes, 2=no
  "DRNKANY6",  # Drank any alcohol in past 30 days: 1=yes, 2=no
  "EXERANY2",  # Exercise in past 30 days (other than job): 1=yes, 2=no
  # Weight/BMI
  "_BMI5CAT",  # BMI category: 1=underweight, 2=normal, 3=overweight, 4=obese
  "WTKG3"      # Computed weight in kg (2 decimal places implicit)
)

# Keep only columns that exist in this year's data (names vary slightly by year)
keep_cols <- intersect(keep_cols, names(brfss_raw))
brfss_sub <- brfss_raw[, keep_cols]

## ---- 4. Stratified sample (≤200 per state) ----
##
## The full dataset has 433,000+ respondents across 50 states + DC + territories.
## For a package dataset, sample up to 200 per state to keep the size manageable
## while preserving the multi-state stratified structure.

set.seed(42)
state_col <- brfss_sub[["_STATE"]]
idx <- unlist(lapply(split(seq_len(nrow(brfss_sub)), state_col), function(i) {
  if (length(i) <= 200) i else sample(i, 200)
}))
brfss_sub <- brfss_sub[sort(idx), ]
rownames(brfss_sub) <- NULL

message("Sampled down to ", nrow(brfss_sub), " rows across ",
        length(unique(brfss_sub[["_STATE"]])), " states/territories")

## ---- 5. Strip haven class, preserve label/labels attributes ----

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

brfss_2023 <- as_plain(brfss_sub)

## ---- 6. Standardise column names to snake_case ----
##
## BRFSS column mapping (key variables, leading underscores stripped):
##   _STATE → state | _PSU → psu | _STSTR → ststr
##   _LLCPWT → llcpwt | _LLCPWT2 → llcpwt2
##   _AGE80 → age80 | _AGEG5YR → ageg5yr | _RACE → race
##   _EDUCAG → educag | _INCOMG1 → incomg1 | _HLTHPL1 → hlthpl1
##   _BMI5CAT → bmi5cat
##   GENHLTH → genhlth | PHYSHLTH → physhlth | MENTHLTH → menthlth
##   SMOKE100 → smoke100 | DRNKANY6 → drnkany6 | EXERANY2 → exerany2

brfss_2023 <- clean_names(brfss_2023)

## ---- 7. Save ----

message("Saving brfss_2023 to data/...")
usethis::use_data(brfss_2023, overwrite = TRUE)

message("Done. brfss_2023: ", nrow(brfss_2023), " rows x ", ncol(brfss_2023), " cols")
message("Columns: ", paste(names(brfss_2023), collapse = ", "))
message("Document with: ?brfss_2023")
