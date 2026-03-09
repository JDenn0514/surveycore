# Replace synthetic examples with real package datasets

| Field | Value |
|-------|-------|
| **Package** | surveycore |
| **Phase** | 0 |
| **Branch** | main (direct doc commit) |
| **PR** | N/A |
| **Date** | 2026-02-20 |

## Executive Summary

All `@examples` sections that previously constructed small synthetic data frames
with `data.frame()`, `rnorm()`, and `runif()` have been replaced with real
datasets that ship with the package (`nhanes_2017` and `acs_pums_wy`). Users
reading the documentation now see realistic survey designs — NHANES stratified
cluster designs and ACS PUMS replicate-weight designs — rather than random
20-row toy data frames. This also fixed a pre-existing bug in the
`as_survey_repweights()` example where `starts_with("pwgtp")` inadvertently included
the main weight column `pwgtp` in the replicate weights list.

---

## Commits

### — docs(examples): replace synthetic data with nhanes_2017 and acs_pums_wy

**Purpose:** All `@examples` in the package now use real package datasets so
that every example serves as a working, realistic demonstration of the
function. Using `nhanes_2017` and `acs_pums_wy` also exercises the data's
haven-style labels, the NHANES dual-weight pattern (`wtint2yr` vs `wtmec2yr`),
and the ACS replicate-weight pattern that real analysts encounter.

**Key changes:**

- `R/01-metadata-system.R`: All six metadata extractor/setter examples now use
  `nhanes_2017`. The `extract_*` examples show auto-extracted haven labels
  (`riagendr → "Gender"`). The `set_*` examples add or override labels on real
  NHANES variables (`bpxsy1`, `bpxdi1`, `indfmpir`, `ridstatr`).

- `R/03-constructors.R`:
  - `as_survey()`: replaced 6 synthetic examples with 3 NHANES examples
    covering a full stratified-cluster design, a stratified-only design, and
    a blood pressure analysis (filtered to exam participants with `wtmec2yr`).
  - `as_survey_repweights()`: fixed bug — `starts_with("pwgtp")` was matching the
    main weight column `pwgtp` in addition to the 80 replicate weights; replaced
    with `matches("^pwgtp[0-9]+$")`. Corrected type from `"ACS"` to
    `"successive-difference"` to match the data documentation.

- `R/05-methods-conversion.R`: All four conversion functions (`as_svydesign()`,
  `as_tbl_svy()`, `from_svydesign()`, `from_tbl_svy()`) now use `nhanes_2017`.

- `R/06-variance-estimation.R`:
  - `get_means()`: uses `nhanes_2017` to estimate mean age (`ridageyr`).
  - `get_totals()`: uses `acs_pums_wy` to demonstrate totals on a
    replicate-weight design (`agep`), showing both design types in the examples.

- `R/07-utils.R`: `survey_data()` example uses `nhanes_2017`.

- `R/08-update-design.R`: `update_design()` example demonstrates the real NHANES
  use case — starting with the MEC examination weight (`wtmec2yr`) and switching
  to the interview weight (`wtint2yr`).

- `man/` (16 Rd files): regenerated via `devtools::document()`.
