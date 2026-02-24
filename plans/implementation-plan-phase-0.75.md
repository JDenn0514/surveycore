# surveycore Phase 0.75 — Implementation Plan

**Version:** 1.0
**Date:** February 2026
**Spec:** `plans/phase-0.75-formal-specification.md`
**Status:** Draft — awaiting review

---

## Overview

Phase 0.75 delivers the two-phase variance engine for `survey_twophase` designs. It is
implemented across three PRs in dependency order: a file-structure refactor (preparatory),
a constructor tightening (precondition for the engine's NA invariant), and the engine + dispatch
(the core deliverable). Each PR passes `devtools::check()` independently.

---

## PR Map

- [ ] PR 1: `feature/variance-file-split` — Split `R/06-variance-estimation.R` into four
  engine-specific files and split the corresponding test file
- [ ] PR 2: `feature/twophase-constructor-na` — Change Warning 23b to a hard error
  (`surveycore_error_subset_na`) and remove Warning 25 from `as_survey_twophase()`; rename
  `phase2_ind` → `subset` in the test data generator
- [ ] PR 3: `feature/variance-twophase` — Implement the two-phase variance engine, extend
  `make_survey_data()`, update dispatch and roxygen, add oracle tests, update VENDORED.md

---

## PR 1: File Structure Refactor

**Branch:** `feature/variance-file-split`
**Depends on:** none

### Files

| Action | File | Content |
|--------|------|---------|
| Create | `R/06-variance-taylor.R` | Attribution header, `.svy_onestrat()`, `.svy_onestage()`, `.svy_multistage()`, `.svy_recvar()`, `.taylor_build_inputs()`, `.taylor_mean()`, `.taylor_total()` |
| Create | `R/06-variance-replicate.R` | `.svy_rep_var()`, `.replicate_estimate()`, `.replicate_mean()`, `.replicate_total()` |
| Create | `R/06-variance-srs.R` | `.srs_mean()`, `.srs_total()` |
| Create | `R/06-variance-dispatch.R` | `.validate_estimation_input()`, `get_means()`, `get_totals()` |
| Delete | `R/06-variance-estimation.R` | — |
| Create | `tests/testthat/test-variance-taylor.R` | Taylor engine tests (see section mapping below) |
| Create | `tests/testthat/test-variance-replicate.R` | Replicate engine tests |
| Create | `tests/testthat/test-variance-srs.R` | SRS engine tests |
| Create | `tests/testthat/test-variance-dispatch.R` | Dispatch + public API tests |
| Delete | `tests/testthat/test-variance-estimation.R` | — |

### Test block mapping

The 887-line `test-variance-estimation.R` maps to the four new files as follows:

**`test-variance-taylor.R`:** Blocks 1 (NHANES Taylor mean/total), 3 (stratified
design), 4 (clustered design), 5 (FPC), 6 (na.rm with NAs), 13 (fraction FPC),
14 (lonely PSU — all 6 option variants + the `make_lonely_design()` fixture), 15
(census FPC → SE = 0). These test `.svy_recvar()` and `.taylor_build_inputs()` via
the public API.

**`test-variance-replicate.R`:** Blocks 10 (BRR oracle), 12 (na.rm = FALSE on
replicate designs), 16 (`.svy_rep_var()` direct tests — NA replicates skipped; all
NA errors).

**`test-variance-srs.R`:** Blocks 2 (SRS uniform weights), 17 (SRS oracle — all
FPC variants), 18 (SRS structure + edge cases — all-NA, n=1, na.rm=FALSE).

**`test-variance-dispatch.R`:** Blocks 7 (return structure for `get_means()` /
`get_totals()`), 8 (error paths: twophase "not yet implemented", var not found,
non-numeric), 9 (trivial known-value correctness), 11 (non-survey-design input
errors).

### Implementation notes

- This PR is a pure cut-and-paste split. No function signatures, behaviors, or
  test assertions change.
- Each new R file begins with a comment header naming its contents (matching the
  style already present in `R/06-variance-estimation.R`).
- The attribution block at the top of the file lives in `R/06-variance-taylor.R`
  (the Taylor helpers are the vendored code). `R/06-variance-replicate.R` gets its
  own vendored attribution header (adapted from `survey:::svrVar`, same GPL
  attribution text, already present in the current file's Section 3b comment).
- `R/06-variance-srs.R` and `R/06-variance-dispatch.R` are surveycore-original
  code; they need no vendored attribution header.
- `devtools::document()` produces no diff (no roxygen changes). Run it to confirm.
- Confirm no remaining references to `06-variance-estimation.R` in NAMESPACE,
  roxygen, or test files after the delete.

### Acceptance criteria

- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `R/06-variance-estimation.R` deleted; `tests/testthat/test-variance-estimation.R` deleted
- [ ] All test counts from the original file pass in the new files
- [ ] `grep -r "variance-estimation" R/ tests/` returns no matches

---

## PR 2: Constructor Tightening

**Branch:** `feature/twophase-constructor-na`
**Depends on:** PR 1

### Files

| Action | File | Change |
|--------|------|--------|
| Modify | `R/03-constructors.R` | Warning 23b → Error; remove Warning 25 block |
| Modify | `tests/testthat/test-constructors.R` | Convert warning test blocks to error test blocks |
| Modify | `tests/testthat/_snaps/constructors.md` | Delete the snapshot entry for Warning 23b |
| Modify | `tests/testthat/helper-test-data.R` | `phase2_ind` → `subset` in `make_survey_data()` and `make_all_designs()` |
| Modify | `tests/testthat/test-variance-dispatch.R` | Update "twophase not yet implemented" test blocks |
| Modify | `plans/error-messages.md` | Remove rows 23b and 25; add `surveycore_error_subset_na` |

### `R/03-constructors.R` changes

**Replace** the Warning 23b block (around line 905–918):

```r
# REMOVE:
n_na <- sum(is.na(subset_vals))
if (n_na > 0L) {
  cli::cli_warn(
    c(
      "!" = paste0("{.arg subset} column {.field {subset_var}} contains {n_na} NA value(s)."),
      "i" = paste0("Rows with NA are excluded from Phase 2. This may affect variance estimation.")
    ),
    class = "surveycore_warning_subset_na"
  )
}
```

**Replace with** (per spec Section 3.3):

```r
n_na <- sum(is.na(subset_vals))
if (n_na > 0L) {
  cli::cli_abort(
    c(
      "x" = "{.arg subset} column {.field {subset_var}} contains {n_na} NA value(s).",
      "i" = "The phase 2 membership indicator must be fully observed for all phase 1 units.",
      "v" = "Remove rows with missing {.arg subset} values before calling {.fn as_survey_twophase}."
    ),
    class = "surveycore_error_subset_na"
  )
}
```

**Remove** the Warning 25 block entirely (around lines 979–995):

```r
# REMOVE entirely:
no_phase2_info <- is.null(ids2_vars) && is.null(strata2_var) &&
                  is.null(probs2_var) && is.null(fpc2_var)
if (method == "full" && no_phase2_info) {
  cli::cli_warn(
    c(
      "!" = paste0('No Phase 2 design information provided with {.code method = "full"}. ...'),
    ),
    class = "surveycore_warning_full_no_phase2"
  )
}
```

The `no_phase2_info` variable is no longer needed in the constructor — it is computed
inside `.twophasevar()` at estimation time (PR 3).

### `tests/testthat/test-constructors.R` changes

Find every block matching:
```r
test_that("as_survey_twophase() warns for NA in subset column", {
  expect_warning(
    result <- as_survey_twophase(ph1, subset = has_na_col, method = "approx"),
    class = "surveycore_warning_subset_na"
  )
  test_invariants(result)
})
```

Replace with the dual-pattern (per spec Section 9.6 and testing-standards.md):
```r
test_that("as_survey_twophase() errors for NA in subset column", {
  expect_error(
    as_survey_twophase(ph1, subset = has_na_col, method = "approx"),
    class = "surveycore_error_subset_na"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_twophase(ph1, subset = has_na_col, method = "approx")
  )
})
```

Also find and delete every test block that expects `surveycore_warning_full_no_phase2`:
```r
# DELETE: any block of this form
test_that("as_survey_twophase() warns when method='full' has no Phase 2 info", {
  expect_warning(..., class = "surveycore_warning_full_no_phase2")
})
```

### `tests/testthat/_snaps/constructors.md` changes

Delete the snapshot entry whose test name is:
```
`as_survey_twophase() warns for NA in subset column`
```

New error snapshots are auto-generated on first `devtools::test()` run and must be
committed before opening the PR.

### `tests/testthat/helper-test-data.R` changes

**In `make_survey_data()`** — two-phase branch (around line 144–147):
```r
# BEFORE:
if (design == "twophase") {
  df$phase2_ind <- runif(n) < 0.4
}

# AFTER:
if (design == "twophase") {
  df$subset <- runif(n) < 0.4
}
```

**In `make_all_designs()`** — twophase creation block (around line 446):
```r
# BEFORE:
twophase <- suppressWarnings(as_survey_twophase(phase1, subset = phase2_ind))

# AFTER:
twophase <- as_survey_twophase(phase1, subset = subset, method = "approx")
```

No `suppressWarnings()` needed: Warning 23b no longer fires (it's now an error,
and the synthetic data has no NAs in `subset`). Warning 25 is removed. The column
reference changes from `phase2_ind` to `subset`.

### `tests/testthat/test-variance-dispatch.R` changes

Update the two "not yet implemented" test blocks (moved from `test-variance-estimation.R`
Block 8 in PR 1). The `phase2_ind` column no longer exists after the generator rename:

```r
# BEFORE (both blocks):
d <- make_survey_data(design = "twophase", seed = 1)
phase1 <- as_survey(d, ids = psu, strata = strata, weights = wt)
two    <- suppressWarnings(
  as_survey_twophase(phase1, subset = phase2_ind)
)

# AFTER (both blocks):
d <- make_survey_data(design = "twophase", seed = 1)
phase1 <- as_survey(d, ids = psu, strata = strata, weights = wt)
two    <- as_survey_twophase(phase1, subset = subset, method = "approx")
```

Keep the `expect_error(class = "surveycore_error_unsupported_class")` assertion — it
remains valid until PR 3. Remove `suppressWarnings()` (Warning 25 is gone; the synthetic
data has no NAs in `subset`, so no error either).

### `plans/error-messages.md` changes

- **Remove** row `23b` (`surveycore_warning_subset_na`)
- **Remove** row `25` (`surveycore_warning_full_no_phase2`)
- **Add** row for `surveycore_error_subset_na` (construction-time, `as_survey_twophase()`)
  with message template from spec Section 8.3
- Update the Coverage Map table: remove the `23b` reference from `test-constructors.R`
  row; add the new error class reference

### Acceptance criteria

- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `as_survey_twophase()` throws `surveycore_error_subset_na` (not a warning) for NA subset
- [ ] No remaining reference to `surveycore_warning_subset_na` anywhere in the codebase
- [ ] No remaining reference to `surveycore_warning_full_no_phase2` anywhere in the codebase
- [ ] `make_survey_data(design = "twophase")` produces `subset` column; `phase2_ind` is gone
- [ ] `make_all_designs()` creates the twophase design without `suppressWarnings()`
- [ ] Error snapshot committed and matching spec Section 3.3 template
- [ ] `plans/error-messages.md` updated: rows 23b and 25 removed; `surveycore_error_subset_na` added
- [ ] The two "not yet implemented" blocks in `test-variance-dispatch.R` use `subset` and still pass

---

## PR 3: Two-Phase Variance Engine + Dispatch

**Branch:** `feature/variance-twophase`
**Depends on:** PR 2

### Files

| Action | File | Change |
|--------|------|--------|
| Create | `R/06-variance-twophase.R` | Full two-phase variance engine |
| Modify | `R/06-variance-dispatch.R` | Remove twophase rejection block; add dispatch branches; update roxygen |
| Create | `tests/testthat/test-variance-twophase.R` | Engine unit tests + error paths + oracle tests + edge cases |
| Modify | `tests/testthat/test-variance-dispatch.R` | Remove "not yet implemented" blocks; add Section 9.1a dispatch tests |
| Modify | `tests/testthat/helper-test-data.R` | Extend `make_survey_data(design = "twophase")` with new parameters + columns |
| Modify | `VENDORED.md` | Four new function-level attribution entries |
| Modify | `plans/error-messages.md` | Add `surveycore_error_full_requires_phase2` row |
| Run | `devtools::document()` | Regenerate NAMESPACE + man/ for updated get_means / get_totals roxygen |

### `R/06-variance-twophase.R` — new file

Top-of-file attribution block (per spec Section 4.2):
```r
# ---------------------------------------------------------------------------
# R/06-variance-twophase.R
# ---------------------------------------------------------------------------
# Two-phase sampling variance estimation for survey_twophase designs.
#
# ATTRIBUTION — VENDORED CODE:
# The functions .twophasevar(), .twophase_phase1_var(), .twophase_phase2_var(),
# and .compute_phase2_probs() are adapted from the survey package by Thomas Lumley
# (https://cran.r-project.org/package=survey), licensed under GPL-2 | GPL-3.
# Modifications: integrated with S7 classes; three-method dispatch made
# explicit; RCPP path removed; error messages converted to cli format;
# data access via @variables instead of survey's internal list structure.
# ---------------------------------------------------------------------------
```

Functions to implement (in this order, mirroring the spec):

1. **`.twophasevar(influence, design, lonely.psu)`** — general engine (spec Section 4.2).
   Reads `method` and `subset` from `design@variables`. Checks `"full"` + no phase2 info →
   throws `surveycore_error_full_requires_phase2`. Calls `.compute_phase2_probs()`,
   `.twophase_phase1_var()`, conditionally `.twophase_phase2_var()`. Returns scalar variance.

2. **`.twophase_phase1_var(influence, design, pi2, method, lonely.psu)`** — Phase 1
   variance contribution (spec Section 4.3). Builds `clusters_mat`, `strata_mat`, `fpcs`
   from `design@variables$phase1` using the matrix-building logic documented in spec Section
   4.3 (analogous to `.taylor_build_inputs()`, with `na.rm` handling removed). Calls
   `.svy_recvar()` on all Phase 1 rows. Extracts `[1L, 1L]` before returning.

   The Phase 1 score differs by method:
   - `"full"` / `"approx"`: `influence[i] / pi2[i]` for Phase 2 rows; `0` for Phase 1-only
   - `"simple"`: `influence[i]` for Phase 2 rows; `0` for Phase 1-only

3. **`.twophase_phase2_var(influence, design, subset, lonely.psu)`** — Phase 2 variance
   contribution (spec Section 4.4). Used only by `"full"` and `"approx"` methods. Score:
   `influence[i] * sqrt(1 / w1[i])` where `w1[i]` is extracted as
   `design@data[[design@variables$phase1$weights]][subset]`. Calls `.svy_recvar()` on Phase 2
   rows only. Builds Phase 2 `fpcs` per the detailed spec Section 4.4 matrix construction:
   - `sampsize`: unique Phase 2 PSU IDs per Phase 2 stratum among `subset == TRUE` rows
   - `popsize`: from explicit `@variables$phase2$fpc`, or auto-computed as unique Phase 2 PSU
     counts per stratum across **all Phase 1 rows** if `fpc` is NULL (mirrors `survey`
     behavior). If no Phase 2 strata or PSU IDs: `fpcs = NULL`.
   Extracts `[1L, 1L]` before returning.

4. **`.compute_phase2_probs(design, subset)`** — derives π₂|₁ (spec Section 4.5).
   Priority: explicit `@variables$phase2$probs` → within-stratum fraction (if strata2) →
   overall fraction `n₂ / n₁`. Returns numeric vector of length `nrow(design@data)` with `1`
   for Phase 1-only rows.

5. **`.twophase_build_inputs(design, y_col, na.rm)`** — prepares standard estimand inputs
   (spec Section 4.6). Returns named list: `y`, `w`, `influence_mean`, `influence_total`,
   `ybar_w`, `total_w`, `n_phase2`. NA handling: `na.rm = TRUE` excludes Phase 2 rows with
   NA `y` and sets their influence to `0`; `na.rm = FALSE` propagates NA through.

6. **`.twophase_mean(design, y_col, na.rm)`** — thin adapter (spec Section 4.7).
   Calls `.twophase_build_inputs()`, passes `influence_mean` to `.twophasevar()`.
   Returns `list(mean = ..., var = ..., se = ...)`.

7. **`.twophase_total(design, y_col, na.rm)`** — thin adapter (spec Section 4.7).
   Returns `list(total = ..., var = ..., se = ...)`.

8. **`.twophase_df(design)`** — degrees of freedom (spec Section 5.6).
   Reads `design@variables$phase1$strata`, `design@variables$phase1$ids`,
   `design@variables$phase1$nest`. Handles the `nest = TRUE` PSU interaction.
   Returns `as.integer(sum(psu_per_stratum) - length(psu_per_stratum))`.

### `R/06-variance-dispatch.R` changes

**Remove** the twophase rejection block from `.validate_estimation_input()` (spec Section 6.1):
```r
# REMOVE:
if (S7::S7_inherits(design, survey_twophase)) {
  cli::cli_abort(
    c(
      "x" = "Two-phase designs are not yet supported in estimation functions.",
      "i" = "Support for {.cls survey_twophase} will be added in Phase 1."
    ),
    class = "surveycore_error_unsupported_class"
  )
}
```

**Add** twophase dispatch branch in `get_means()` (spec Section 6.2). Insert before the
`survey_taylor` fallthrough — `survey_twophase` does not inherit from `survey_taylor`:
```r
} else if (S7::S7_inherits(design, survey_twophase)) {
  .twophase_mean(design, var_name, na.rm = na.rm)
} else {
  .taylor_mean(design, var_name, na.rm = na.rm)
```

**Add** identical dispatch branch in `get_totals()` using `.twophase_total()`.

**Update roxygen** for both `get_means()` and `get_totals()` (spec Section 6.4):
- `@param design`: remove the "not yet supported" sentence; add `[survey_twophase]` to the
  list of supported classes.
- `@section Variance estimation by design type:`: add the `survey_twophase` entry with all
  three method descriptions (`"full"`, `"approx"`, `"simple"`) per spec Section 6.4 template.

### `tests/testthat/test-variance-twophase.R` — new file

Implement all blocks from spec Section 9.3 in order:

**Section 1 — Engine unit tests (synthetic data):**
- `.twophasevar()` returns finite non-negative scalar for valid approx input
- `.twophasevar()` phase 1 variance component is nonzero for clustered phase 1
- `.twophasevar()` full variance > phase 1 variance alone
- `.twophasevar()` with `"simple"` equals phase 1 component only
- `.twophase_mean()` returns list with mean, var, se of correct types
- `.twophase_total()` returns list with total, var, se of correct types
- `.twophase_df()` returns a nonneg integer (class integer)
- `.twophase_df()` nest = TRUE test (inline data, expected df = 8L per spec Section 9.3)

**Section 2 — Error paths:**
- `.twophase_mean()` errors for `method = "full"` with no phase 2 design info:
  `expect_error(class = "surveycore_error_full_requires_phase2")` +
  `expect_snapshot(error = TRUE, ...)`

**Section 3 — Oracle: `survival::pbc`** (spec Section 9.4):
- `get_means()` full method matches `survey::svymean` on pbc (tolerance 1e-10 / 1e-8)
- `get_means()` approx method matches `survey::svymean` on pbc
- `get_totals()` full method matches `survey::svytotal` on pbc
- `get_totals()` approx method matches `survey::svytotal` on pbc
- All four blocks have `skip_if_not_installed("survival")` + `skip_if_not_installed("survey")`

**Section 4 — Oracle: `survival::nwtco`** (spec Section 9.5):
- Four blocks matching the pbc pattern, using nwtco construction from spec Section 9.5

**Section 5 — Edge cases:**
- `.twophase_mean()` returns NA estimate when all Phase 2 y values are NA and `na.rm = TRUE`
- `.twophase_mean()` propagates NA when `na.rm = FALSE` and y has NA
- `.twophase_mean()` returns NA se when Phase 2 has only one observation
- `.twophase_mean()` works when all rows are Phase 2 (`phase2_frac = 1`)

Oracle dataset construction follows spec Sections 9.4 and 9.5 exactly. The `pbc` oracle uses
`method = "full"` (no clustering, no strata); the `nwtco` oracle uses `ids = seqno` in Phase 1
and `strata2 = rel` in Phase 2 for the stratified case.

### `tests/testthat/test-variance-dispatch.R` changes

**Remove** the two "not yet implemented" test blocks (which were updated in PR 2 to use the
`subset` column). These test the old rejection behavior that no longer applies:
```r
# REMOVE both:
test_that("get_means() errors on two-phase design (not yet implemented)", { ... })
test_that("get_totals() errors on two-phase design (not yet implemented)", { ... })
```

**Add** two new dispatch test blocks from spec Section 9.1a:
```r
test_that("get_means() dispatches to .twophase_mean() for survey_twophase input", {
  df  <- make_survey_data(design = "twophase", seed = 1)
  ph1 <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  d   <- as_survey_twophase(ph1, subset = subset, method = "approx")
  result <- get_means(d, y1)
  expect_true(is.list(result))
  expect_named(result, c("variable", "mean", "se"))
  expect_true(is.numeric(result$mean))
  expect_true(is.numeric(result$se) && result$se >= 0)
})

test_that("get_totals() dispatches to .twophase_total() for survey_twophase input", {
  df  <- make_survey_data(design = "twophase", seed = 1)
  ph1 <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  d   <- as_survey_twophase(ph1, subset = subset, method = "approx")
  result <- get_totals(d, y1)
  expect_true(is.list(result))
  expect_named(result, c("variable", "total", "se"))
  expect_true(is.numeric(result$total))
  expect_true(is.numeric(result$se) && result$se >= 0)
})
```

### `tests/testthat/helper-test-data.R` changes

**Extend `make_survey_data(design = "twophase")`** — add the `phase2_frac` parameter
(new, optional, default `0.4`) and generate the two new columns:

```r
# New function signature addition:
make_survey_data <- function(
  ...
  phase2_frac = 0.4,    # NEW: fraction of Phase 1 selected into Phase 2
  ...
)
```

**In the two-phase branch** (around line 144), replace the current single-column
generation with the full schema from spec Section 9.2:

```r
if (design == "twophase") {
  # Phase 2 membership: Bernoulli sampling at rate phase2_frac
  df$subset      <- runif(n) < phase2_frac
  # Phase 1 inclusion probability (= n_psu_stratum / pop_stratum)
  df$phase1_prob <- stratum_n[strata] / stratum_pop[strata]
  # Conditional Phase 2 inclusion probability (= phase2_frac, Bernoulli)
  df$phase2_prob <- rep(phase2_frac, n)
}
```

Note: `phase1_prob` uses `strata` (integer stratum index) and the already-computed
`stratum_n` and `stratum_pop` vectors from earlier in the function. `phase2_prob` is
constant (Bernoulli sampling rate), per spec Issue 18 resolution: Bernoulli sampling
retained for simplicity; oracle tests use real datasets, not the synthetic generator.

**Update the `make_survey_data` docstring** to add `phase2_frac` parameter documentation
and update the "Additional columns by design" section:
```
#' - design = "twophase":  subset (logical, ~40% TRUE), phase1_prob (numeric),
#'   phase2_prob (numeric)
```

### `VENDORED.md` changes

Add four entries to the existing attribution table (spec Section 10):

| surveycore function | Adapted from | survey version | Modified? | Modification notes |
|---|---|---|---|---|
| `.twophasevar()` | `survey:::twophasevar` | 4.4.x | Yes | S7 data access via `@variables`; three-method dispatch made explicit; `attr(rval, "phases")` output removed; cli error format |
| `.twophase_phase1_var()` | `survey:::svyrecvar.phase1` | 4.4.x | Yes | S7 class integration; RCPP path removed; delegates to existing `.svy_recvar()` |
| `.twophase_phase2_var()` | Phase 2 component of `survey:::twophasevar` | 4.4.x | Yes | Extracted as standalone function; delegates to existing `.svy_recvar()` |
| `.compute_phase2_probs()` | Internal probability logic in `survey/R/twophase.R` | 4.4.x | Yes | Simplified three-priority rule; S7 `@variables$phase2` data access |

### `plans/error-messages.md` changes

**Add** row for `surveycore_error_full_requires_phase2` (estimation-time,
`.twophasevar()` called via `.twophase_mean()` / `.twophase_total()`), with message
template from spec Section 8.3:
```
"x" = 'Two-phase variance method {.val full} requires phase 2 design structure.'
"i" = 'No {.arg ids2}, {.arg strata2}, or {.arg probs2} were specified in {.fn as_survey_twophase}.'
"v" = 'Reconstruct with {.arg method = "approx"} or supply phase 2 design variables.'
```

**Update** the Coverage Map table to add `test-variance-twophase.R` covering the new error classes.

### Implementation notes

**Shared matrix-building logic** — `.twophase_phase1_var()` duplicates the PSU ID /
strata / FPC matrix-building steps from `.taylor_build_inputs()`. This duplication is
intentional and accepted (see spec Section 4.3 tech-debt note). Do NOT extract a shared
helper in this PR. The refactor is deferred to Phase 1.

**`lonely.psu` option** — read **once** at the start of `.twophasevar()`:
`lonely.psu <- getOption("survey.lonely.psu", "remove")`. Pass this same value to both
`.twophase_phase1_var()` and `.twophase_phase2_var()`. Do not re-read the option inside
the sub-functions.

**`[1L, 1L]` extraction** — `.svy_recvar()` returns a `p×p` matrix. Both
`.twophase_phase1_var()` and `.twophase_phase2_var()` must extract `[1L, 1L]` before
returning so that `v1 + v2` in `.twophasevar()` is scalar-scalar arithmetic.

**`"full"` error check** — the `surveycore_error_full_requires_phase2` check in
`.twophasevar()` fires only when `method == "full"` AND `@variables$phase2` has `NULL`
ids, strata, and probs. `fpc2` alone is not sufficient to specify Phase 2 design
structure (it's a correction factor, not a sampling design). Follow spec Section 4.2
exactly: `!is.null(vars$phase2$ids) || !is.null(vars$phase2$strata) || !is.null(vars$phase2$probs)`.

**Oracle test datasets** — `survival::pbc` and `survival::nwtco` are in `Suggests` already
(via the `survival` package dependency chain). All oracle test blocks must be wrapped in
`skip_if_not_installed("survival")` + `skip_if_not_installed("survey")`. See spec Sections
9.4 and 9.5 for exact data preparation and oracle comparison construction.

**`devtools::document()`** — must be run and `NAMESPACE` + `man/get_means.Rd` +
`man/get_totals.Rd` committed in this PR, since the roxygen changes alter the `@param design`
and add a `@section` entry.

### Acceptance criteria

- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `R/06-variance-twophase.R` coverage ≥ 98%
- [ ] Total package coverage ≥ 98%
- [ ] `get_means()` and `get_totals()` dispatch to `.twophase_mean()` / `.twophase_total()`
  for `survey_twophase` inputs — verified by `test-variance-dispatch.R`
- [ ] `.twophasevar()` with `"full"` + no Phase 2 design info throws
  `surveycore_error_full_requires_phase2` — tested with `expect_error(class=)` +
  `expect_snapshot(error = TRUE)`
- [ ] All three methods return finite, non-negative variance for valid synthetic inputs
- [ ] `pbc` oracle: all four combinations (`get_means`/`get_totals` × `full`/`approx`) pass
  at tolerance 1e-10 (point) and 1e-8 (SE)
- [ ] `nwtco` oracle: same four combinations pass at same tolerances
- [ ] `get_means()` and `get_totals()` roxygen no longer say two-phase is unsupported
- [ ] `@section Variance estimation` includes `survey_twophase` entry with all three methods
- [ ] `plans/error-messages.md` updated: `surveycore_error_full_requires_phase2` row added
- [ ] `VENDORED.md` updated: four new function-level attribution entries
- [ ] `make_survey_data(design = "twophase")` produces `subset`, `phase1_prob`, `phase2_prob`
  columns; no NAs in `subset`; `phase1_prob` and `phase2_prob` in range (0, 1]

---

## Completion Criteria

Phase 0.75 is complete when all three PRs are merged into `main` and all quality gates
from spec Section 11 pass. Run the full Phase 1 readiness check informally: confirm that
a Phase 1 function can call `.twophasevar(influence, design)` with a custom influence vector
and obtain a numerically correct variance.
