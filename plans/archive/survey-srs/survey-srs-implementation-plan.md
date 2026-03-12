# surveycore — `survey_srs` Implementation Plan

**Version:** 1.0
**Date:** February 2026
**Spec:** `plans/survey-srs-formal-specification.md`
**Status:** Ready for implementation

---

## Overview

This plan delivers the `survey_srs` class, `as_survey_srs()` constructor,
`as_survey()` dispatch update, SRS variance estimation (`.srs_mean()` /
`.srs_total()`), and print/summary methods. All components ship in a single
PR (`feature/survey-srs`) per the CLAUDE.md prereq table. The build steps
below sequence work so each layer has a stable foundation before the next
begins.

**Current state (from code review):**
- `R/00-s7-classes.R`: `survey_srs` class body written; validator is correct
  per spec; `@variables` docs and `@seealso` need minor updates.
- `tests/testthat/helper-test-data.R`: `make_all_designs()` has an `srs`
  entry using `as_survey(df_s)` (which will fire a spurious warning once
  dispatch is added); `test_invariants()` lacks the `survey_srs` branch.
- `R/03-constructors.R`: `as_survey_srs()` not yet written; `as_survey()`
  has no SRS dispatch.
- `R/04-methods-print.R`, `R/06-variance-estimation.R`: not yet started.

---

## PR Map

- [x] PR 1: `feature/survey-srs` — Add `survey_srs` constructor, print, and variance estimation

---

## PR 1: `survey_srs` Full Implementation

**Branch:** `feature/survey-srs`
**Depends on:** none (branches from main)

### Files changed

| File | Change |
|---|---|
| `R/00-s7-classes.R` | Update `@variables` docs + `@seealso` for `survey_srs` |
| `R/03-constructors.R` | Add `as_survey_srs()`; update `as_survey()` dispatch |
| `R/04-methods-print.R` | Add `print` and `summary` methods for `survey_srs` |
| `R/06-variance-estimation.R` | Add `.srs_mean()`, `.srs_total()`; update dispatch in stubs |
| `tests/testthat/helper-test-data.R` | Fix `make_all_designs()` srs entry; add `survey_srs` branch to `test_invariants()` |
| `tests/testthat/test-s7-classes.R` | New blocks for `survey_srs` validator (spec §X rows 1–7) |
| `tests/testthat/test-constructors.R` | New blocks for `as_survey_srs()` (spec §X rows 1–22) |
| `tests/testthat/test-methods-print.R` | New snapshots for `survey_srs` print (spec §X rows 1–12) |
| `tests/testthat/test-variance-estimation.R` | New oracle + edge-case blocks for SRS variance (spec §X rows 1–9 + edge cases) |
| `plans/error-messages.md` | Add rows 55–60; update coverage map |
| `CLAUDE.md` | Update phase table: Prereq PR 1 → ✅ Complete |

---

## Build Order

Implement in this sequence. Run `devtools::test()` after each step before
proceeding.

---

### Step 1 — S7 class docs + `test_invariants()` update

**Spec reference:** §III, §X

**Why first:** The class body and validator are already correct. Only docs
and the helper invariant check need updating. No runtime changes — this
step must not break any existing tests.

1. **`R/00-s7-classes.R`** — update the `survey_srs` class docs:
   - Add `fpc_type`, `ids`, `strata`, `nest` to the `@variables` section
     (full list: `weights`, `probs_provided`, `fpc`, `fpc_type`, `ids`,
     `strata`, `nest`)
   - Update `@seealso` to include `[as_survey_srs()]`
   - Validator is correct as-is — do not change it

2. **`tests/testthat/helper-test-data.R`** — add `survey_srs` branch to
   `test_invariants()` (spec §X):
   ```r
   if (S7::S7_inherits(design, survey_srs)) {
     expect_true("fpc_type" %in% names(design@variables))
   }
   ```
   Insert this branch before the existing `survey_nonprob` branch. The
   `make_all_designs()` srs entry update is deferred to Step 2 (requires
   `as_survey_srs()` to exist).

3. **`tests/testthat/test-s7-classes.R`** — add new blocks for `survey_srs`
   (spec §X, rows 1–7). All are Layer 1 (S7 validator) errors: use `class=`
   only, no snapshot (per testing-surveycore.md):
   - Row 1: validator rejects weight column absent from `@data`
   - Row 2: validator rejects non-numeric weight column
   - Row 3: validator rejects non-positive values in weight column
   - Row 4: validator rejects FPC column absent from `@data`
   - Row 5: all 7 `@variables` keys present after construction
   - Row 6: `@variables$ids` is always NULL
   - Row 7: `@variables$strata` is always NULL

   **Note:** Rows 5–7 need a valid `survey_srs` object; construct one inline
   with `survey_srs(data = data.frame(y = 1:5, wt = rep(1,5)), variables = list(weights = "wt", fpc = NULL, fpc_type = NULL, probs_provided = FALSE, ids = NULL, strata = NULL, nest = FALSE))`. Use `test_invariants()` as the first assertion.

**Gate:** `devtools::test(filter = "s7-classes")` passes with 0 failures.

---

### Step 2 — `as_survey_srs()` constructor + `as_survey()` dispatch

**Spec reference:** §IV, §V, §VII

1. **`plans/error-messages.md`** — add rows 55–60 before writing any code
   (class names must match exactly):
   - Row 55: `surveycore_error_weights_probs_both`
   - Row 56: `surveycore_error_fpc_nonpositive`
   - Row 57: `surveycore_error_fpc_ambiguous`
   - Row 58: `surveycore_error_fpc_below_sample`
   - Row 59: `surveycore_warning_as_survey_srs_fallback`
   - Row 60: `surveycore_warning_srs_no_weights`
   - Update coverage map: `test-constructors.R` → rows 1–26, **55–60**

   **Note on row 60:** The spec §XI notes rows 7 and 60 share the class name
   `surveycore_warning_srs_no_weights`. Check whether row 7 already has this
   class in `plans/error-messages.md`. If it does, row 60 is a new entry for
   the same class but fired from a different function — both entries stay.

2. **`R/03-constructors.R`** — add `as_survey_srs()` (spec §IV):
   - Signature: `as_survey_srs(data, weights = NULL, probs = NULL, fpc = NULL)`
   - Roxygen: `@family constructors`, `@seealso [as_survey()]`,
     `@return A \code{survey_srs} object.`, `@examples` (one minimal
     runnable example: `as_survey_srs(data.frame(y = 1:5))`),
     `@param` for `data`, `weights`, `probs`, `fpc`
   - Validation order (stop at first failure):
     1. Data-level checks via existing helpers: `not_data_frame`,
        `empty_data`, `duplicate_names`, `single_row_warning`
     2. `weights`/`probs` mutual exclusion → `surveycore_error_weights_probs_both`
     3. `probs` → weights conversion if `probs` non-NULL:
        resolve `probs` via tidy-select, compute `1 / probs_col`, store in
        `data[["..surveycore_wt.."]]`, set `probs_provided = TRUE`
     4. Weight checks via `.validate_weights()` / `.resolve_single_col()`:
        `weights_not_found`, `weights_multiple`, `weights_all_zero`
     5. No-weights fallback: if `weights = NULL`, assign
        `data[["..surveycore_wt.."]] <- rep(1L, nrow(data))`, fire
        `surveycore_warning_srs_no_weights`
     6. FPC checks (only when `fpc` is non-NULL), in order:
        `fpc_na` → `fpc_nonpositive` → `fpc_ambiguous` → `fpc_below_sample`
        (use `.validate_fpc()` where possible; new checks 56–58 may need
        inline code if `.validate_fpc()` doesn't cover them)
   - `fpc_type` detection per spec §IV: `if (all(fpc_vals > 1)) "population" else "fraction"`
   - `@variables` construction per spec §IV (all 7 keys)
   - Constructor call: `survey_srs(data = data, variables = variables, call = match.call())`
   - Return: visible (not `invisible()`)
   - **Do NOT reimplement** `.validate_weights()`, `.validate_fpc()`,
     `.resolve_single_col()` — delegate to them

3. **`R/03-constructors.R`** — update `as_survey()` for SRS dispatch
   (spec §V):
   - Insert ids/strata null-check at the TOP of `as_survey()`, before any
     weight or probs resolution
   - SRS path (both NULL):
     ```r
     if (is_srs_dispatch) {
       cli::cli_warn(
         c(
           "!" = "No {.arg ids} or {.arg strata} specified.",
           "i" = "Creating a {.cls survey_srs} design (equal-probability SRS).",
           "v" = "Use {.fn as_survey_srs} to create SRS designs without this warning."
         ),
         class = "surveycore_warning_as_survey_srs_fallback"
       )
       return(as_survey_srs(data, weights = weights, probs = probs, fpc = fpc))
     }
     ```
   - `weights`, `probs`, `fpc` forwarded as unresolved quosures — no
     resolution in `as_survey()` for the SRS path
   - Taylor path: unchanged (existing weight/probs/no-weights logic stays)

4. **`tests/testthat/helper-test-data.R`** — fix `make_all_designs()`:
   - Replace `srs <- as_survey(df_s)` with
     `srs <- as_survey_srs(df_s, weights = wt)`
   - This avoids the `surveycore_warning_as_survey_srs_fallback` warning
     in test output (per spec §XIII note)

5. **`tests/testthat/test-constructors.R`** — new blocks (spec §X):
   - **Happy paths (rows 1–9b):** `test_invariants(design)` as first
     assertion in every block
     - Row 1: explicit weights → `survey_srs` class
     - Row 2: FPC as population sizes → `fpc_type == "population"`
     - Row 3: FPC as sampling fractions → `fpc_type == "fraction"`
     - Row 4: no weights → uniform weights auto-assigned
     - Row 5: returns `survey_srs` class (not `survey_taylor`)
     - Row 6: `@variables$fpc_type == "population"` when FPC > 1
     - Row 7: `@variables$fpc_type == "fraction"` when FPC ∈ (0, 1]
     - Row 8: `@variables$fpc_type` is NULL when no FPC
     - Row 9: `as_survey()` with no ids/strata creates `survey_srs` (fires
       `surveycore_warning_as_survey_srs_fallback`)
     - Row 9b: `probs` supplied → `@variables$probs_provided == TRUE`,
       weights stored as `1 / probs`
   - **Error paths (rows 10–19):** dual pattern for each —
     `expect_error(class=)` + `expect_snapshot(error=TRUE)`
   - **Warning paths (rows 20–22):**
     `expect_warning(result <- ..., class = "surveycore_warning_...")`;
     assert on `result` after

**Gate:** `devtools::test(filter = "constructors")` passes; snapshot files
committed (`tests/testthat/_snaps/test-constructors.md`).

---

### Step 3 — print + summary methods

**Spec reference:** §VI

1. **`R/04-methods-print.R`** — add `survey_srs` methods after the
   `survey_taylor` methods, with a comment: `# Class defined in R/00-s7-classes.R`
   - `S7::method(print, survey_srs) <- function(x, n = 10L, design_info = FALSE, weights_info = FALSE, metadata_info = FALSE, full = FALSE, ...) { ... }`
     - Default output: `── Survey Design ───`, `<survey_srs> (simple random sample)`, `Sample size: {n}`
     - `design_info = TRUE` or `full = TRUE`: add `── Design specification ────` section
       with weights label (`"uniform (auto-assigned)"` when `"..surveycore_wt.."` is the column),
       FPC label (`"(population sizes)"` / `"(sampling fractions)"` / `"not specified"`),
       and sampling fraction (only when FPC is specified)
     - `weights_info = TRUE` or `full = TRUE`: add `── Weight distribution ─────` section
     - `metadata_info = TRUE` or `full = TRUE`: identical to `survey_taylor` metadata section
     - NO `strata_info` or `cluster_info` arguments
     - Return `invisible(x)`
   - Update `R/04-methods-print.R` file header comment to include `survey_srs`
   - `S7::method(summary, survey_srs) <- function(x, ...) { ... }` returning
     a 7-key list (spec §VI): `class`, `n`, `weighted_n`, `fpc_specified`,
     `fpc_type`, `n_var_labels`, `n_val_labels`; return visibly (not invisible)

2. **`tests/testthat/test-methods-print.R`** — new blocks (spec §X):
   - Snapshot rows 1–5 for `print()` (default, design_info, fractions, full, uniform)
   - Summary rows 6–12: `expect_identical()` and `expect_true/false/null`
     assertions; keys: `c("class","n","weighted_n","fpc_specified","fpc_type","n_var_labels","n_val_labels")`

**Gate:** `devtools::test(filter = "methods-print")` passes; print snapshots
committed (`tests/testthat/_snaps/test-methods-print.md`).

---

### Step 4 — variance estimation + oracle tests

**Spec reference:** §VIII, §X

1. **`R/06-variance-estimation.R`** — add `.srs_mean()`:
   - Extract weights (`w`) and outcome (`y`) from `design@data`
   - Apply `na.rm`: if TRUE, drop NA rows from `y` (and corresponding `w`)
     and compute `n_used` as count of non-NA obs; if FALSE, `n_used = nrow(data)`
   - Weighted mean: `ybar <- sum(w * y) / sum(w)` (with `na.rm = TRUE` for the sum)
   - Sampling fraction `f`:
     - `fpc_type == "population"`: `f <- n_used / mean(fpc_col)`
     - `fpc_type == "fraction"`: `f <- mean(fpc_col)`
     - `fpc = NULL`: `f <- 0`
   - Unweighted sample variance: `s2 <- sum((y - ybar)^2) / (n_used - 1)`
   - Variance of mean: `var_ybar <- (1 - f) * s2 / n_used`
   - `df <- n_used - 1L`
   - Edge cases per spec §VIII table:
     - All `y` NA + `na.rm = TRUE`: return `list(mean=NA_real_, se=NA_real_, df=0L)`
     - All `y` NA + `na.rm = FALSE`: return `list(mean=NA_real_, se=NA_real_, df=nrow(data)-1L)`
     - Some `y` NA + `na.rm = FALSE`: standard R NA arithmetic propagates; return `list(mean=NA_real_, se=NA_real_, df=nrow(data)-1L)`
     - `n_used = 1`: return `list(mean=y[1], se=NA_real_, df=0L)`
   - **Before committing oracle tests:** run `survey::svymean()` against the
     formula on `make_survey_data(n=500, seed=42)` with non-uniform weights.
     Document the comparison result in a comment at the top of `.srs_mean()`.
   - Return `list(mean = ybar, se = sqrt(var_ybar), df = df)`

2. **`R/06-variance-estimation.R`** — add `.srs_total()`:
   - `T_hat <- sum(w * y)` (with `na.rm`)
   - `N_hat`:
     - `fpc_type == "population"`: `N_hat <- mean(fpc_col)`
     - `fpc_type == "fraction"` or `fpc = NULL`: `N_hat <- sum(w)`
   - `var_T`:
     - `fpc_type == "population"`: `N_hat^2 * (1 - f) * s2 / n_used`
     - `fpc_type == "fraction"`: `sum(w)^2 * (1 - f) * s2 / n_used`
     - `fpc = NULL`: `sum(w)^2 * s2 / n_used`
   - Edge cases: same pattern as `.srs_mean()` (all NA, n=1)
   - Return `list(total = T_hat, se = sqrt(var_T), df = df)`

3. **`R/06-variance-estimation.R`** — update dispatch in `get_means()` and
   `get_totals()` (spec §VIII):
   ```r
   } else if (S7::S7_inherits(design, survey_srs)) {
     .srs_mean(design, var_name, na.rm = na.rm)
   ```
   Insert between the `survey_replicate` branch and the `survey_taylor`
   fallthrough. `survey_nonprob` continues to fall through to
   `.taylor_mean()`.

4. **`tests/testthat/test-variance-estimation.R`** — new blocks (spec §X):
   - Oracle tests 1–9 (all with `skip_if_not_installed("survey")`):
     - Reference: `survey::svydesign(ids=~1, weights=~w, fpc=~fpc_col, data=df)`
     - Data: `make_survey_data(n=500, seed=42)`, dropping `ids`/`strata` columns
     - Tolerances: point `1e-10`, SE `1e-8`
   - Non-oracle edge-case tests for `.srs_mean()` and `.srs_total()`:
     all-NA with `na.rm=TRUE`, all-NA with `na.rm=FALSE`, some-NA with
     `na.rm=FALSE`, `n=1` — use inline data, no oracle reference

**Gate:** `devtools::test(filter = "variance")` passes; oracle tests pass.

---

### Step 5 — final cleanup + quality gate

1. **`CLAUDE.md`** — update phase table: Prereq PR 1 → ✅ Complete
2. Run `devtools::document()` — confirm NAMESPACE and `man/` in sync
3. Run `devtools::check()` — must pass 0 errors, 0 warnings, ≤2 notes
4. Confirm snapshot files are committed:
   - `tests/testthat/_snaps/test-methods-print.md`
   - `tests/testthat/_snaps/test-constructors.md`

---

### Acceptance criteria

- [ ] `devtools::check()` — 0 errors, 0 warnings, ≤2 notes
- [ ] `devtools::test()` — all tests pass, no failures
- [ ] Oracle tests pass for all 9 variance scenarios (point: 1e-10, SE: 1e-8)
- [ ] Formula verified against `survey::svymean()` on non-uniform weights;
      result documented in a comment in `.srs_mean()`
- [ ] `plans/error-messages.md` updated with rows 55–60; coverage map updated
- [ ] Print snapshots committed (`tests/testthat/_snaps/test-methods-print.md`)
- [ ] Constructor error snapshots committed (`tests/testthat/_snaps/test-constructors.md`)
- [ ] `R/04-methods-print.R` file header comment updated to include `survey_srs`
- [ ] `CLAUDE.md` phase table updated: Prereq PR 1 → ✅ Complete
- [ ] `devtools::document()` run; NAMESPACE and `man/` in sync

---

## Implementation Notes

**Class validator is correct as-is.** The `survey_srs` validator in
`R/00-s7-classes.R` already implements all four Layer 1 rules from spec §III.
Do not modify the validator logic, only the roxygen docs.

**`make_all_designs()` ordering constraint.** The `srs <- as_survey(df_s)`
line in `make_all_designs()` must be updated to
`srs <- as_survey_srs(df_s, weights = wt)` in Step 2, after `as_survey_srs()`
is implemented. Until Step 2 completes, the srs entry will create a
`survey_taylor` or fire warnings — do not run `make_all_designs()` until
Step 2 is done.

**`as_survey()` refactoring risk.** The ids/strata null-check must be
inserted at the TOP of `as_survey()`, before any weight resolution. Read the
entire function carefully before modifying. The Taylor path (non-NULL ids or
strata) must be left exactly as-is.

**FPC check ordering.** The four FPC checks must run in this order:
`fpc_na` → `fpc_nonpositive` → `fpc_ambiguous` → `fpc_below_sample`.
Snapshot tests depend on this order.

**Warning ordering.** `surveycore_warning_as_survey_srs_fallback` (row 59)
fires inside `as_survey()` before `as_survey_srs()` is called.
`surveycore_warning_srs_no_weights` (row 60) fires inside `as_survey_srs()`.
When both fire (e.g., `as_survey(df)` with no ids/strata/weights), row 59
always precedes row 60. Snapshot tests depend on this order.

**`fpc_type` = `"fraction"` for FPC = 1.0.** Values exactly equal to 1 are
a sampling fraction of 1.0 (entire population sampled), not a population
size. The detection code `if (all(fpc_vals > 1)) "population" else "fraction"`
handles this correctly — fpc = 1 goes to "fraction", f = 1, variance = 0.

**`probs_provided` flag.** `TRUE` only when caller supplies `probs=`;
`FALSE` when caller supplies `weights=` directly or when uniform weights
are auto-assigned (no `weights` and no `probs` provided).

**Row 60 class name reuse.** Spec §XI notes that rows 7 and 60 share the
class name `surveycore_warning_srs_no_weights` but fire from different
functions (row 7: `as_survey()` Taylor path; row 60: `as_survey_srs()`).
Both entries must appear in `plans/error-messages.md` as separate rows.

**`n_used` definition for `na.rm = FALSE`.** When `na.rm = FALSE`,
`n_used = nrow(data)` — NA rows count toward `n_used` for `df` computation.
Standard R NA arithmetic then propagates through `Σwᵢyᵢ`, producing
`mean = NA_real_`.

**Helper delegation.** `as_survey_srs()` must use `.validate_weights()`,
`.validate_fpc()`, and `.resolve_single_col()` — not reimplement their
logic inline. If new FPC checks (rows 56–58) cannot be expressed through
existing helpers, add them as inline checks after the helper calls.
