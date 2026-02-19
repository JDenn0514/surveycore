## ACS PUMS 2022 1-Year (Wyoming): Download and prepare package dataset
##
## Source: U.S. Census Bureau, American Community Survey
## URL: https://www.census.gov/programs-surveys/acs/microdata/access.html
## License: Public domain (US Government work)
##
## Output dataset: acs_pums_wy
##   All Wyoming persons (~7,500 rows), design vars + 80 replicate weights
##   Design: Successive difference replication (PWGTP / PWGTP1-80)
##   State FIPS 56 = Wyoming (smallest state → fast tests)
##
## Run this script from the package root: source("data-raw/download-acs-pums.R")

library(janitor)
library(usethis)

DEST_DIR <- file.path(here::here(), "data-raw", "acs-pums")
ZIP_FILE <- file.path(DEST_DIR, "csv_pwy.zip")
CSV_FILE <- file.path(DEST_DIR, "psam_p56.csv")
ZIP_URL  <- "https://www2.census.gov/programs-surveys/acs/data/pums/2022/1-Year/csv_pwy.zip"

## ---- 1. Download ----

if (!file.exists(CSV_FILE)) {
  if (!file.exists(ZIP_FILE)) {
    message("Downloading csv_pwy.zip (~1.2 MB)...")
    download.file(ZIP_URL, destfile = ZIP_FILE, mode = "wb", quiet = FALSE)
  }
  message("Unzipping...")
  unzip(ZIP_FILE, exdir = DEST_DIR)
} else {
  message("psam_p56.csv already exists, skipping download.")
}

## ---- 2. Read ----

message("Reading psam_p56.csv...")
acs_raw <- read.csv(CSV_FILE, stringsAsFactors = FALSE)
message("Read ", nrow(acs_raw), " rows x ", ncol(acs_raw), " cols")

## ---- 3. Select columns ----

# Design variables
design_cols <- c(
  "PUMA",   # Public Use Microdata Area (geographic cluster, use as PSU)
  "ST",     # State FIPS code (all 56 for Wyoming; use as stratum)
  "PWGTP"  # Person weight
)

# Replicate weights: PWGTP1 through PWGTP80 (successive difference replication)
repwgt_cols <- paste0("PWGTP", 1:80)

# Person characteristics (analysis variables)
person_cols <- c(
  "AGEP",    # Age (0–99)
  "SEX",     # Sex: 1=male, 2=female
  "RAC1P",   # Recoded detailed race: 1=White, 2=Black, 3=AIAN, 6=Asian, 9=Multiracial
  "HISP",    # Recoded Hispanic origin (01=not Hispanic; 02–24=specific origin)
  "SCHL",    # Educational attainment (01=no schooling ... 24=doctorate)
  "ESR",     # Employment status recode (1=employed ... 6=not in labor force)
  "PINCP",   # Total person income (signed, in adjustment-year dollars)
  "WAGP",    # Wages or salary income (past 12 months)
  "HICOV",   # Health insurance coverage: 1=yes, 2=no
  "DIS",     # Disability recode: 1=with disability, 2=without
  "POVPIP",  # Income-to-poverty ratio (0–501, 501 = 501%+)
  "WKHP",    # Usual hours worked per week (past 12 months)
  "ADJINC"   # Adjustment factor for income and earnings (divide by 1,000,000)
)

all_cols <- c(design_cols, repwgt_cols, person_cols)

# Verify all columns exist
missing_cols <- setdiff(all_cols, names(acs_raw))
if (length(missing_cols) > 0) {
  warning("These expected columns were not found: ", paste(missing_cols, collapse = ", "))
  all_cols <- intersect(all_cols, names(acs_raw))
}

acs_pums_wy <- acs_raw[, all_cols]
rownames(acs_pums_wy) <- NULL

## ---- 4. Standardise column names to snake_case ----
##
## ACS PUMS names are already lowercase-friendly; clean_names() just lowercases.
## Column mapping:
##   PUMA → puma | ST → st | PWGTP → pwgtp | PWGTP1-80 → pwgtp1-pwgtp80
##   AGEP → agep | SEX → sex | RAC1P → rac1p | HISP → hisp
##   SCHL → schl | ESR → esr | PINCP → pincp | WAGP → wagp
##   HICOV → hicov | DIS → dis | POVPIP → povpip | WKHP → wkhp | ADJINC → adjinc

acs_pums_wy <- clean_names(acs_pums_wy)

## ---- 5. Save ----
##
## No haven labels to strip — the CSV has no attribute metadata.
## Column types are plain integer/numeric from read.csv().

message("Saving acs_pums_wy to data/...")
usethis::use_data(acs_pums_wy, overwrite = TRUE)

message("Done. acs_pums_wy: ", nrow(acs_pums_wy), " rows x ", ncol(acs_pums_wy), " cols")
message("  Design columns: puma, st, pwgtp")
message("  Replicate weights: pwgtp1-pwgtp80")
message("  Analysis columns: agep, sex, rac1p, hisp, schl, esr, pincp, wagp, ...")
message("Document with: ?acs_pums_wy")
