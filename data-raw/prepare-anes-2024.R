## ANES 2024 Time Series Study: Prepare package dataset
##
## Source: American National Election Studies (ANES)
## URL: https://electionstudies.org/data-center/2024-time-series-study/
## License: Requires free ANES account; redistribution of processed subset permitted
##          for academic/educational use per ANES terms of use.
##
## Output dataset: anes_2024
##   5,521 respondents (pre- and/or post-election interviews)
##   Design: Stratified cluster sample (V240103c = PSU, V240103d = Stratum)
##   Weights: V240103a (pre-election), V240103b (post-election) — FTF+Web combined
##
## The raw .dta file (75 MB) must be manually downloaded from the ANES website
## (free account required) and placed at:
##   data-raw/anes/anes_timeseries_2024_stata_20250808/
##     anes_timeseries_2024_stata_20250808.dta
##
## Run this script from the package root: source("data-raw/prepare-anes-2024.R")

library(haven)
library(janitor)
library(usethis)

DTA_FILE <- file.path(
  here::here(), "data-raw", "anes",
  "anes_timeseries_2024_stata_20250808",
  "anes_timeseries_2024_stata_20250808.dta"
)

if (!file.exists(DTA_FILE)) {
  stop(
    "Raw file not found: ", DTA_FILE, "\n",
    "Download the ANES 2024 Time Series Stata file from:\n",
    "  https://electionstudies.org/data-center/2024-time-series-study/\n",
    "(free account required) and place it at the path above."
  )
}

## ---- 1. Read ----

message("Reading ANES 2024 .dta (~75 MB) — this may take a minute...")
anes_raw <- read_dta(DTA_FILE)
message("Read ", nrow(anes_raw), " rows x ", ncol(anes_raw), " cols")

## ---- 2. Select columns ----
##
## Design variables (FTF + Web combined sample — most inclusive):
##   V240103a: Pre-election raked weight
##   V240103b: Post-election raked weight
##   V240103c: PSU
##   V240103d: Stratum
##
## Demographics and political core:
##   V240001:  Case ID
##   V240003:  Sample type (FTF=1, Web=2, PAPI=3)
##   V240002c: Pre/Post interview completion status
##   V243002:  State FIPS code
##   V243007:  Census region (1=NE, 2=MW, 3=S, 4=W)
##   V241458x: Age on Election Day (summary, top-coded 80)
##   V241550:  Sex (1=male, 2=female)
##   V241501x: Race/ethnicity (5-category summary)
##   V241465x: Education (5-category summary)
##   V241566x: Household income (6-category summary)
##   V241177:  7pt liberal-conservative self-placement
##   V241222:  Party identification (strong D ... strong R)
##   V241223:  Party ID for independents (lean D/R/neither)
##   V242066:  POST: Did R vote for President
##   V242067:  POST: For whom did R vote for President

keep_cols <- c(
  # Design
  "V240001",  "V240003",  "V240002c",
  "V240103a", "V240103b", "V240103c", "V240103d",
  # Geography
  "V243002",  "V243007",
  # Demographics
  "V241458x", "V241550",  "V241501x", "V241465x", "V241566x",
  # Political
  "V241177",  "V241222",  "V241223",
  "V242066",  "V242067"
)

missing_cols <- setdiff(keep_cols, names(anes_raw))
if (length(missing_cols) > 0) {
  warning("These expected columns were not found: ", paste(missing_cols, collapse = ", "))
  keep_cols <- intersect(keep_cols, names(anes_raw))
}

anes_sub <- anes_raw[, keep_cols]

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

anes_2024 <- as_plain(anes_sub)

## ---- 4. Standardise column names to snake_case ----
##
## ANES column mapping (opaque V-codes → meaningful snake_case):
##   V240001  → v240001  (case_id)      V240003  → v240003  (sample_type)
##   V240002c → v240002c (interview_completion)
##   V240103a → v240103a (weight_pre)   V240103b → v240103b (weight_post)
##   V240103c → v240103c (psu)          V240103d → v240103d (stratum)
##   V243002  → v243002  (state_fips)   V243007  → v243007  (region)
##   V241458x → v241458x (age)          V241550  → v241550  (sex)
##   V241501x → v241501x (race_eth)     V241465x → v241465x (educ)
##   V241566x → v241566x (income)
##   V241177  → v241177  (libcon_self)  V241222  → v241222  (party_id)
##   V241223  → v241223  (party_id_lean)
##   V242066  → v242066  (voted_pres)   V242067  → v242067  (vote_pres)
##
## Note: clean_names() lowercases; the V-code names become e.g. "v240103a".
## The variable labels (accessible via attr(x, "label")) provide human-readable
## descriptions of each variable.

anes_2024 <- clean_names(anes_2024)

## ---- 5. Save ----

message("Saving anes_2024 to data/...")
usethis::use_data(anes_2024, overwrite = TRUE)

message("Done. anes_2024: ", nrow(anes_2024), " rows x ", ncol(anes_2024), " cols")
message("  Design: psu = v240103c, stratum = v240103d")
message("  Weights: v240103a (pre-election), v240103b (post-election)")
message("Document with: ?anes_2024")
