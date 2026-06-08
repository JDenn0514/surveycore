## California Academic Performance Index 2000: Simple Random Sample
##
## Source: survey::apisrs (Lumley 2004)
## Original data: California Department of Education, 2000 API study
## License: GPL-2 (survey package); reformatted to surveycore conventions
##
## Population: 6,194 California public schools
## Sample: 200 schools (simple random sample)
##
## Output dataset: ca_api_2000
##   200 rows x 39 variables (flag column dropped — all NA)
##
## Run from the package root: source("data-raw/prepare-ca-api-2000.R")

library(janitor)
library(usethis)

## ---- 1. Load ----

data(api, package = "survey")
message(
  "Loaded apisrs: ",
  nrow(apisrs),
  " rows x ",
  ncol(apisrs),
  " cols"
)

## ---- 2. Drop flag (entirely NA across all 200 rows) ----

ca_api_2000 <- apisrs
ca_api_2000$flag <- NULL

## ---- 3. Convert factor columns to integer with labels attributes ----
##
## stype:    "E" -> 1, "H" -> 2, "M" -> 3 (as.integer preserves this)
## Yes/No:   R factor gives No=1, Yes=2; subtract 1L for semantic 0/1

ca_api_2000$stype <- local({
  x <- as.integer(ca_api_2000$stype)
  attr(x, "labels") <- c(Elementary = 1L, High = 2L, Middle = 3L)
  x
})

for (col in c("sch.wide", "comp.imp", "both", "awards", "yr.rnd")) {
  x <- as.integer(ca_api_2000[[col]]) - 1L
  attr(x, "labels") <- c(No = 0L, Yes = 1L)
  ca_api_2000[[col]] <- x
}

## ---- 4. Attach label attributes ----
##
## Source var.labels covers cds through pw (indices 1-38 in original 40-col
## data, excluding flag at index 10). fpc column and ~10 blank entries
## are filled manually per design doc.

src_names <- names(apisrs) # original 40 names (incl. flag)
src_labels <- attr(apisrs, "var.labels") # 38 entries (cds..pw)

# Manual labels for blank source entries and fpc1/fpc2
manual_labels <- c(
  stype = "School type",
  api00 = "API score 2000",
  api99 = "API score 1999",
  target = "API growth target",
  growth = "API score change (api00 - api99)",
  yr.rnd = "Year-round school",
  pct.resp = "Percent of parents responding to survey",
  pw = "Sampling weight (inverse probability of selection)",
  fpc = "FPC (number of schools in the California API system)"
)

for (i in seq_along(src_names)) {
  col <- src_names[i]
  if (col == "flag") {
    next
  }
  if (!col %in% names(ca_api_2000)) {
    next
  } # safety check

  # Source label (var.labels only covers first 38 cols)
  src_lbl <- if (i <= length(src_labels)) src_labels[i] else ""

  # Use source label if non-blank; otherwise use manual override
  lbl <- if (nchar(src_lbl) > 0) src_lbl else manual_labels[col]

  if (!is.na(lbl) && nchar(lbl) > 0) {
    attr(ca_api_2000[[col]], "label") <- as.character(lbl)
  }
}

## ---- 5. Standardise column names to snake_case ----
##
## sch.wide -> sch_wide, comp.imp -> comp_imp, yr.rnd -> yr_rnd,
## acs.k3 -> acs_k3, acs.46 -> acs_46, acs.core -> acs_core,
## pct.resp -> pct_resp, not.hsg -> not_hsg, some.col -> some_col,
## col.grad -> col_grad, grad.sch -> grad_sch, avg.ed -> avg_ed,
## api.stu -> api_stu. All others are already snake_case.

ca_api_2000 <- clean_names(ca_api_2000)

## ---- 6. Save ----

message("Saving ca_api_2000 to data/...")
usethis::use_data(ca_api_2000, overwrite = TRUE)

message(
  "Done. ca_api_2000: ",
  nrow(ca_api_2000),
  " rows x ",
  ncol(ca_api_2000),
  " cols"
)
message("  Design: ids = NULL, weights = pw, fpc = fpc")
message("Document with: ?ca_api_2000")
