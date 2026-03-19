# surveycore Phase 0.75 — Two-Phase Variance Pre-Work

**Version:** 1.0
**Date:** February 2026
**Status:** Required before Phase 1 implementation begins

---

## Purpose

Phase 0 vendored the Taylor series linearization and replicate weight variance
engines (`R/06-variance-estimation.R`). Two-phase designs (`survey_twophase`)
require a separate variance formula that accounts for the joint selection
probabilities across both sampling phases. Without this code, all six Phase 1
analysis functions must throw `surveycore_error_unsupported_class` for
`survey_twophase`.

Phase 0.75 vendors the two-phase variance code and adds `survey_twophase`
dispatch to the variance engine — before any Phase 1 analysis function PRs
are opened.

---

## Scope

### What Phase 0.75 Delivers

1. **Vendored two-phase variance functions** in `R/06-variance-estimation.R`
   (or a new `R/06b-variance-twophase.R`), with GPL attribution matching the
   existing vendored code pattern.

2. **Public variance stubs updated**: The existing `get_means()` and
   `get_totals()` stubs in `R/06-variance-estimation.R` are extended to
   dispatch on `survey_twophase` using the vendored two-phase code.

3. **Numerical oracle tests** in `tests/testthat/test-variance-estimation.R`
   comparing two-phase estimates to `survey::svymean()` and
   `survey::svytotal()` on two-phase designs, within established tolerances
   (point: `1e-10`, SE: `1e-8`).

### What Phase 0.75 Does NOT Deliver

- The full Phase 1 analysis functions (`get_freqs()`, `get_corr()`,
  `get_quantiles()`, `get_ratios()`) — those are Phase 1.
- Two-phase support for `get_quantiles()` — Woodruff's method adapted for
  two-phase designs is complex; defer to Phase 1 if feasible, Phase 2 otherwise.
- `survey_nonprob` two-phase variance — deferred to Phase 2.5.

---

## Implementation Plan

### Step 1 — Identify code to vendor

Read the survey package source for two-phase variance:

- `survey::svymean.twophase()` — mean estimation for two-phase designs
- `survey::svytotal.twophase()` — total estimation for two-phase designs
- Helper functions referenced by the above (the "full", "approx", and "simple"
  method branches)

The relevant functions live in `survey/R/twophase.R` in the survey package
source. Study both the "approx" method (uses phase 1 design variance + a
phase 2 correction term) and the "full" method (joint linearization).

### Step 2 — Vendor into R/06-variance-estimation.R (or 06b)

Add vendored functions following the existing pattern:

```r
# ── Two-phase variance (vendored from survey v4.4.x) ─────────────────────────
#
# Source: survey::svymean.twophase() and helpers
# License: GPL-2 or GPL-3 (see VENDORED.md for full attribution)
# Modifications: [describe any]
```

Internal functions to add:
- `.twophase_mean()` — two-phase weighted mean with variance
- `.twophase_total()` — two-phase weighted total with variance

### Step 3 — Add dispatch in variance stubs

The existing stubs in `R/06-variance-estimation.R` throw
`surveycore_error_unsupported_class` for `survey_twophase`. Add dispatch:

```r
get_means <- function(design, var) {
  if (S7::S7_inherits(design, survey_taylor)) {
    .taylor_mean(design, var)
  } else if (S7::S7_inherits(design, survey_replicate)) {
    .replicate_mean(design, var)
  } else if (S7::S7_inherits(design, survey_twophase)) {
    .twophase_mean(design, var)     # NEW in Phase 0.75
  } else {
    cli::cli_abort(
      c("x" = "{.fn get_means} does not support {.cls {class(design)[[1]]}}."),
      class = "surveycore_error_unsupported_class"
    )
  }
}
```

### Step 4 — Update VENDORED.md

Add attribution entry for the two-phase functions, consistent with existing
entries for Taylor and replicate variance code.

### Step 5 — Tests

Add to `tests/testthat/test-variance-estimation.R`:

```r
# Block 3: Two-phase designs — numerical oracle against survey::
test_that("two-phase mean matches survey::svymean for synthetic data [numerical]", {
  skip_if_not_installed("survey")
  # ... set up two-phase design ...
  # ... compare get_means() to survey::svymean() ...
  expect_equal(sc_est$mean, sv_est_mean, tolerance = 1e-10)
  expect_equal(sc_est$se,   sv_est_se,   tolerance = 1e-8)
})
```

Use `make_survey_data(design = "twophase")` for synthetic data.
Use `nhanes_2017` for a real-data cross-check if a suitable two-phase
structure can be constructed from it.

---

## Degrees of Freedom for Two-Phase Designs

The spec (Section 2.6) states: "`survey_twophase`: `degf` from phase 1 design."

For CI computation, use the phase 1 design's degrees of freedom:
`degf = sum(PSUs per stratum in phase 1) - number of strata in phase 1`.

This is consistent with the `survey` package's treatment of two-phase designs.

---

## Branch and PR

- **Branch:** `feature/variance-twophase` (or `chore/phase-0.75-variance-twophase`)
- **PR title:** `feat(variance): vendor two-phase variance code (Phase 0.75)`
- **Must pass before Phase 1 PRs open:** CI green, 0/0/0, oracle tests pass

---

## Supported Methods

| `@variables$method` | Variance approach | Notes |
|---|---|---|
| `"full"` | Full two-phase linearization | Most accurate; requires phase 2 design info |
| `"approx"` | Phase 1 variance + phase 2 correction | Good approximation when full info unavailable |
| `"simple"` | Phase 1 variance only | Conservative; ignores phase 2 design; valid when phase 2 is SRS within phase 1 |

---

## Quality Gate

Phase 0.75 is complete when:

- [ ] `devtools::check()` passes (0 errors, 0 warnings, ≤ 2 notes)
- [ ] Numerical oracle tests pass for two-phase designs (point: `1e-10`, SE: `1e-8`)
- [ ] `get_means()` and `get_totals()` stubs dispatch correctly on `survey_twophase`
- [ ] `VENDORED.md` updated with attribution for two-phase functions
- [ ] `plans/error-messages.md` unchanged — `surveycore_error_unsupported_class` is
      still thrown for `survey_twophase` by `get_freqs()`, `get_corr()`,
      `get_quantiles()`, `get_ratios()` until Phase 1 adds those functions
