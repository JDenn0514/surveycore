## NHANES 2017-2018: Download and prepare package dataset
##
## Source: National Center for Health Statistics (NCHS), CDC
## URL: https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/default.aspx?BeginYear=2017
## License: Public domain (US Government work)
##
## Output dataset: nhanes_2017
##   9,254 participants (exam weight subsample: 8,704)
##   Design: Stratified multi-stage cluster (SDMVPSU / SDMVSTRA / WTMEC2YR)
##
## Run this script from the package root: source("data-raw/download-nhanes.R")

library(haven)
library(janitor)
library(usethis)

BASE_URL <- "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles"
DEST_DIR <- file.path(here::here(), "data-raw", "nhanes")

## ---- 1. Download ----

nhanes_files <- c("DEMO_J.xpt", "BPX_J.xpt")

for (f in nhanes_files) {
  dest <- file.path(DEST_DIR, f)
  if (!file.exists(dest)) {
    message("Downloading ", f, "...")
    download.file(paste0(BASE_URL, "/", f), destfile = dest, mode = "wb", quiet = FALSE)
  } else {
    message(f, " already exists, skipping download.")
  }
}

## ---- 2. Read ----

message("Reading NHANES files...")

demo_raw <- read_xpt(file.path(DEST_DIR, "DEMO_J.xpt"))
bpx_raw  <- read_xpt(file.path(DEST_DIR, "BPX_J.xpt"))

## ---- 3. Select columns ----

# Demographics: sequence number + design vars + key person characteristics
demo_cols <- c(
  "SEQN",      # Respondent sequence number (join key)
  "SDMVPSU",   # Masked variance pseudo-PSU (cluster ID for variance estimation)
  "SDMVSTRA",  # Masked variance pseudo-stratum
  "WTMEC2YR",  # 2-year MEC examination weight (use with blood pressure data)
  "WTINT2YR",  # 2-year interview weight (use with interview-only data)
  "RIDSTATR",  # Interview/examination status: 1=interview only, 2=both
  "RIAGENDR",  # Gender: 1=male, 2=female
  "RIDAGEYR",  # Age in years at screening (top-coded at 80)
  "RIDRETH3",  # Race/Hispanic origin (6 categories, incl. Non-Hispanic Asian)
  "INDFMPIR",  # Family income to poverty ratio (continuous, 0-5+)
  "DMDEDUC2"   # Education level, adults 20+ (1=<9th grade ... 5=college+)
)

# Blood pressure: sequence number + key readings
bpx_cols <- c(
  "SEQN",    # Respondent sequence number (join key)
  "BPXSY1",  # Systolic BP, 1st reading (mm Hg)
  "BPXDI1",  # Diastolic BP, 1st reading (mm Hg)
  "BPXPLS"   # 60-second pulse (beats per minute)
)

demo_sub <- demo_raw[, demo_cols]
bpx_sub  <- bpx_raw[, bpx_cols]

## ---- 4. Merge ----
##
## merge() silently drops non-standard column attributes (like "label" from
## haven). Save them before the merge and restore them after.

save_col_attrs <- function(df) {
  lapply(df, function(x) list(
    label  = attr(x, "label",  exact = TRUE),
    labels = attr(x, "labels", exact = TRUE)
  ))
}

restore_col_attrs <- function(df, saved) {
  for (nm in intersect(names(df), names(saved))) {
    if (!is.null(saved[[nm]]$label))  attr(df[[nm]], "label")  <- saved[[nm]]$label
    if (!is.null(saved[[nm]]$labels)) attr(df[[nm]], "labels") <- saved[[nm]]$labels
  }
  df
}

attrs_demo <- save_col_attrs(demo_sub)
attrs_bpx  <- save_col_attrs(bpx_sub)

nhanes_merged <- merge(demo_sub, bpx_sub, by = "SEQN", all.x = TRUE)

nhanes_merged <- restore_col_attrs(nhanes_merged, c(attrs_demo, attrs_bpx))

## ---- 5. Strip haven class if present, keeping label/labels attributes ----
##
## haven::read_xpt() on NHANES returns plain numeric columns (not haven_labelled)
## with a "label" attribute. No column carries a "labels" attribute: the SAS
## XPORT format stores a label for each variable but no labels for the codes
## inside a variable, so the NHANES code meanings live only in the published
## codebooks. The as_plain() call below is a no-op for NHANES since columns
## aren't haven_labelled, but is included for consistency with the BRFSS script
## and as a safeguard for future file changes.

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

nhanes_2017 <- as_plain(nhanes_merged)

## ---- 6. Standardise column names to snake_case ----
##
## janitor::clean_names() lowercases all names. Label/labels attributes on
## individual columns are unaffected (renaming the data frame's names vector
## does not touch the column vectors themselves).
##
## NHANES column mapping:
##   SEQN → seqn | SDMVPSU → sdmvpsu | SDMVSTRA → sdmvstra
##   WTMEC2YR → wtmec2yr | WTINT2YR → wtint2yr | RIDSTATR → ridstatr
##   RIAGENDR → riagendr | RIDAGEYR → ridageyr | RIDRETH3 → ridreth3
##   INDFMPIR → indfmpir | DMDEDUC2 → dmdeduc2
##   BPXSY1 → bpxsy1 | BPXDI1 → bpxdi1 | BPXPLS → bpxpls

nhanes_2017 <- clean_names(nhanes_2017)

## ---- 7. Save ----

message("Saving nhanes_2017 to data/...")
usethis::use_data(nhanes_2017, overwrite = TRUE)

message("Done. nhanes_2017: ", nrow(nhanes_2017), " rows x ", ncol(nhanes_2017), " cols")
message("Columns: ", paste(names(nhanes_2017), collapse = ", "))
message("Document with: ?nhanes_2017")
