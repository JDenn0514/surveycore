# Implementation

## Step 1 — Add `.print_domain_info()` helper

Add to the `# ── Internal helpers ──` section of `methods-print.R`, after the existing helpers (~line 68):

```r
# Print domain membership line when a domain filter is active.
# Only renders when SURVEYCORE_DOMAIN_COL is present in @data.
#' @noRd
.print_domain_info <- function(x) {
  if (SURVEYCORE_DOMAIN_COL %in% names(x@data)) {
    n_domain <- sum(x@data[[SURVEYCORE_DOMAIN_COL]], na.rm = TRUE)
    n_total  <- nrow(x@data)
    cli::cli_text("Domain: {.val {n_domain}} of {.val {n_total}} rows")
  }
}
```

---

## Step 2 — Call `.print_domain_info()` in all 5 print methods

Insert `.print_domain_info(x)` in each method's `# ── Header ──` section, after the sample size line(s) and before the `@groups` check. This placement is logical: total rows → domain subset of those rows → grouping.

**`survey_taylor` (~line 104):**
```r
cli::cli_text("Sample size: {.val {nrow(x@data)}}")
.print_domain_info(x)    # ← add here
if (length(x@groups) > 0L) {
```

**`survey_srs` (~line 231):**
```r
cli::cli_text("Sample size: {.val {nrow(x@data)}}")
.print_domain_info(x)    # ← add here
if (length(x@groups) > 0L) {
```

**`survey_replicate` (~line 348):**
```r
cli::cli_text("Sample size: {.val {nrow(x@data)}}")
.print_domain_info(x)    # ← add here
if (length(x@groups) > 0L) {
```

**`survey_twophase` (~lines 453–460) — insert after both phase size lines:**
```r
if (!is.na(n_phase2)) {
  cli::cli_text("Phase 2 sample size: {.val {n_phase2}}")
}
.print_domain_info(x)    # ← add here
if (length(x@groups) > 0L) {
```

**`survey_nonprob` (~line 564):**
```r
cli::cli_text("Sample size: {.val {nrow(x@data)}}")
.print_domain_info(x)    # ← add here
if (length(x@groups) > 0L) {
```

---

## Tests

### Snapshot updates

The `_snaps/` files for print methods in `surveycore` will need to be updated to include the new `"Domain:"` line after a filter has been applied.

Run after implementing:

```r
devtools::test()             # identify which snapshots changed
testthat::snapshot_review()  # review each diff individually and accept
devtools::test()             # confirm all pass
```

### New test cases

If a snapshot test for print-after-filter doesn't already exist, add one for each design type demonstrating the domain line appears:

```r
test_that("print shows domain line after filter()", {
  # Each design type, after a filter applied via surveytidy
  # Snapshot shows "Domain: N of M rows" in header
})

test_that("print does NOT show domain line when no filter applied", {
  # No domain column → no domain line in header
})
```

---

## Verification

Quick smoke test in console:

```r
library(surveytidy)
d <- surveycore::as_survey(data.frame(age = 1:100, wt = 1), weights = wt)
d                         # should show NO domain line

df <- dplyr::filter(d, age > 65)
df                        # should show "Domain: 35 of 100 rows"
```