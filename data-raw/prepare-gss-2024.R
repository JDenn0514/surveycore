## GSS 2024: Prepare package dataset
##
## Source: NORC at the University of Chicago, General Social Survey
## URL: https://gss.norc.org/get-the-data
## License: Requires free NORC account; processed subsets permitted for
##          academic/non-commercial use per GSS terms of use.
##
## Output dataset: gss_2024
##   3,309 respondents (combined cross-section)
##   Design: Stratified multi-stage cluster (vpsu / vstrat / wtssps)
##
## The raw .sav file must be manually downloaded from the GSS website
## (free account required) and placed at:
##   data-raw/gss/gss-2024/GSS2024.sav
##
## Run this script from the package root: source("data-raw/prepare-gss-2024.R")

library(haven)
library(janitor)
library(usethis)

SAV_FILE <- file.path(here::here(), "data-raw", "gss", "gss-2024", "GSS2024.sav")

if (!file.exists(SAV_FILE)) {
  stop(
    "Raw file not found: ", SAV_FILE, "\n",
    "Download the GSS 2024 SPSS file from:\n",
    "  https://gss.norc.org/get-the-data\n",
    "(free account required) and place it at the path above."
  )
}

## ---- 1. Read ----

message("Reading GSS2024.sav (~13 MB)...")
gss_raw <- read_spss(SAV_FILE)
message("Read ", nrow(gss_raw), " rows x ", ncol(gss_raw), " cols")

## ---- 2. Select columns ----
##
## Design variables:
##   vpsu:     Variance primary sampling unit
##   vstrat:   Variance stratum
##   wtssps:   Person post-stratification weight
##   wtssnrps: Person post-stratification weight (non-response adjusted)
##   ballot:   Split-ballot form (A / B / C)
##
## Respondent background:
##   year:     Survey year
##   id:       Case ID
##   age:      Age in years (top-coded 89)
##   sex:      Sex (1=male, 2=female)
##   race:     Race (1=white, 2=black, 3=other)
##   hispanic: Hispanic origin (1=not hispanic; 2-50=specific origins)
##   educ:     Years of education (0–20)
##   degree:   Highest degree (0=<HS, 1=HS, 2=associate, 3=BA, 4=grad)
##   income16: Total family income (26-category recode)
##   marital:  Marital status (1=married ... 5=never married)
##   wrkstat:  Labor force status (1=working FT, 2=PT, 3=temp not working ...)
##   hrs1:     Hours worked last week (if employed)
##   adults:   Number of adults in household
##
## Social/political attitudes:
##   partyid:  Party identification (0=strong D ... 6=strong R)
##   polviews: Political views (1=extremely liberal ... 7=extremely conservative)
##   happy:    General happiness (1=very happy, 2=pretty happy, 3=not too happy)
##   health:   Self-rated health (1=excellent, 2=good, 3=fair, 4=poor)
##   trust:    Can people be trusted (1=yes, 2=no, 3=depends)
##   natfare:  Spending on welfare (1=too little, 2=about right, 3=too much)
##   abany:    Abortion for any reason (1=yes, 2=no)
##   attend:   Religious attendance (0=never ... 8=several times a week)
##   relig:    Religion (1=protestant, 2=catholic, 3=jewish ... 13=none)

keep_cols <- c(
  # Design
  "vpsu", "vstrat", "wtssps", "wtssnrps", "ballot",
  # ID / admin
  "year", "id",
  # Demographics
  "age", "sex", "race", "hispanic", "educ", "degree",
  "income16", "marital", "wrkstat", "hrs1", "adults",
  # Social/political attitudes
  "partyid", "polviews", "happy", "health", "trust",
  "natfare", "abany", "attend", "relig"
)

missing_cols <- setdiff(keep_cols, names(gss_raw))
if (length(missing_cols) > 0) {
  warning("These expected columns were not found: ", paste(missing_cols, collapse = ", "))
  keep_cols <- intersect(keep_cols, names(gss_raw))
}

gss_sub <- gss_raw[, keep_cols]
rownames(gss_sub) <- NULL

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

gss_2024 <- as_plain(gss_sub)

## ---- 4. Standardise column names to snake_case ----
##
## GSS names are already lowercase; clean_names() is a no-op here but
## applied for consistency. All names pass through unchanged.

gss_2024 <- clean_names(gss_2024)

## ---- 5. Save ----

message("Saving gss_2024 to data/...")
usethis::use_data(gss_2024, overwrite = TRUE)

message("Done. gss_2024: ", nrow(gss_2024), " rows x ", ncol(gss_2024), " cols")
message("  Design: psu = vpsu, stratum = vstrat, weight = wtssps")
message("  Alt weight (non-response adjusted): wtssnrps")
message("Document with: ?gss_2024")
