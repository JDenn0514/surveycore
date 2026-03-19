# Implementation Plan: Allow Zero Weights in `survey_nonprob`

**Spec:** `plans/spec-nonprob-zero-weights.md` (v0.3, Approved)
**Review:** `plans/spec-review-nonprob-zero-weights.md` (Pass 2 — 0 blocking, 0 required)
**Date:** 2026-03-18

---

## Overview

This plan delivers the three deliverables from the spec: relax the
`survey_nonprob` S7 validator to allow zero weights (split condition 4 into
4a/4b), update `test_invariants()` for the nonprob branch, and register the
new `surveycore_error_weights_negative` error class. This is a single PR —
the scope is small (one source file edit, one test helper edit, one test file
update, one error table update) and all changes are tightly coupled.

---

## PR Map

- [x] PR 1: `feature/nonprob-zero-weights` — Relax `survey_nonprob` validator to allow zero weights; update tests and error table

---

## PR 1: Relax `survey_nonprob` Validator — Zero Weights

**Branch:** `feature/nonprob-zero-weights`
**Depends on:** none

### Files (in TDD order — tests first):

1. `plans/error-messages.md` — Add row 101 (`surveycore_error_weights_negative`); update rows 10 and 33
2. `tests/testthat/test-s7-classes.R` — Add new validator tests; no existing tests to modify in this file (line 748 unchanged)
3. `tests/testthat/test-constructors.R` — Delete duplicate test at line 1797; update test at line 1835 (class + name); existing tests at lines 1672 and 1816 unchanged
4. `R/core-classes.R` — Split condition 4 into 4a (negative → error) and 4b (all-zero → error)
5. `tests/testthat/helper-test-data.R` — Update `test_invariants()` nonprob branch (line ~287)

### Step-by-step task list

#### A. Error table update

- [ ] **A1.** Read `plans/error-messages.md` rows 10 and 33 to confirm current state.
- [ ] **A2.** Update row 33: change Function column from `S7 validator (survey_taylor)` to `S7 validator (survey_taylor, survey_replicate)`. Add note: "No longer thrown by `survey_nonprob` validator (see row 101, `surveycore_error_weights_negative`)."
- [ ] **A3.** Update row 10: add note that `surveycore_error_weights_all_zero` is also thrown by the `survey_nonprob` validator condition 4b (all non-NA weights are zero, no positive values).
- [ ] **A4.** Add row 101: `surveycore_error_weights_negative` — thrown by `survey_nonprob` validator (condition 4a), condition: any non-NA weight is negative (< 0). Full message template per spec §V.

#### B. Write failing tests (RED phase)

- [ ] **B1.** In `test-s7-classes.R`, add the **workflow path** test: create via `as_survey_nonprob()` with positive weights, then mutate weights to include zeros via `@data<-`, call `test_invariants()`, assert 3 zeros. (This will fail because the current validator rejects zeros.)
- [ ] **B2.** In `test-s7-classes.R`, add the **happy-path validator** test: raw `survey_nonprob()` with `w = c(1, 0, 0, 2, 0)` and full `variables` list. Call `test_invariants()` and assert 3 zeros. (Will fail — current validator rejects zeros.)
- [ ] **B3.** In `test-s7-classes.R`, add the **error-path condition 4a** test: raw `survey_nonprob()` with `w = c(1, -0.5, 2)` and full `variables` list. `expect_error(class = "surveycore_error_weights_negative")`. (Will fail — current code throws `surveycore_error_weights_nonpositive`.)
- [ ] **B4.** In `test-s7-classes.R`, add the **error-path condition 4b** test: raw `survey_nonprob()` with `w = c(0, 0, 0)` and full `variables` list. `expect_error(class = "surveycore_error_weights_all_zero")`. (Will fail — current code throws `surveycore_error_weights_nonpositive`.)
- [ ] **B5.** In `test-s7-classes.R`, add **edge case**: single positive among zeros `w = c(0, 0, 0, 0, 0.001)`, full `variables` list. Call `test_invariants()`. (Will fail.)
- [ ] **B6.** In `test-s7-classes.R`, add **edge case**: mix of zeros and NAs with one positive `w = c(0, NA, 1, 0)`, full `variables` list. Call `test_invariants()`. (Will fail.)
- [ ] **B7.** In `test-s7-classes.R`, add **edge case**: mix of zeros and negatives `w = c(0, -1, 0)`, full `variables` list. `expect_error(class = "surveycore_error_weights_negative")`. (Will fail.)
- [ ] **B8.** In `test-s7-classes.R`, add **edge case**: all-zero weights with NAs `w = c(0, NA, 0)`, full `variables` list. `expect_error(class = "surveycore_error_weights_all_zero")`. (Will fail.)
- [ ] **B9.** In `test-s7-classes.R`, add **`test_invariants()` verification** test: create via `as_survey_nonprob()`, mutate weights to include zeros via `@data<-`, `expect_no_error(test_invariants(obj))`. (Will fail — current `survey_nonprob` validator rejects zeros on `@data<-` assignment. After E1, will continue to fail because `test_invariants()` still requires `> 0`, fixed in D1.)
- [ ] **B10.** Run `devtools::test(filter = "s7-classes")` to confirm all new tests fail (RED). Do NOT proceed until all new tests fail as expected.

#### C. Update existing tests

- [ ] **C1.** In `test-constructors.R`, **delete** the duplicate test at line 1797 (`"survey_nonprob validator rejects non-numeric weight column"` — duplicate of `test-s7-classes.R` line 748).
- [ ] **C2.** In `test-constructors.R`, **update** the test at line 1835: rename from `"survey_nonprob validator rejects non-positive weight column"` to `"survey_nonprob validator rejects negative weights"`; change `class` from `"surveycore_error_weights_nonpositive"` to `"surveycore_error_weights_negative"`. Keep input data `w = c(1, -1, 1, 1, 1)` — it has negatives, which is correct for this test.
- [ ] **C3.** Verify these tests remain **unchanged** (do not modify):
  - `test-constructors.R:1672` — `as_survey_nonprob() rejects non-positive weights` (Layer 3, `.validate_weights()` still rejects zeros)
  - `test-constructors.R:1816` — `survey_nonprob validator rejects all-NA weight column` (unchanged)
  - `test-constructors.R:1936` — `as_survey_nonprob() rejects non-numeric weight column` (unchanged)
  - `test-s7-classes.R:748` — `survey_nonprob validator rejects non-numeric weight column` (unchanged)

#### D. Update `test_invariants()` (safe relaxation — no test impact)

- [ ] **D1.** In `tests/testthat/helper-test-data.R`, locate the `survey_nonprob` branch weight check at line ~287. Replace `all(wt_col[!is.na(wt_col)] > 0)` with two assertions:
  - `all(wt_col[!is.na(wt_col)] >= 0)` — "weight column has all non-negative non-NA values"
  - `any(wt_col[!is.na(wt_col)] > 0)` — "weight column has at least one positive non-NA value"
- [ ] **D2.** Verify the **main branch** weight check (~line 359) is **NOT modified** — it must retain strict `> 0` for `survey_taylor`, `survey_replicate`, `survey_twophase`.
- [ ] **D3.** Run `devtools::test(filter = "s7-classes")` and `devtools::test(filter = "constructors")` — all existing tests must still pass (relaxing `> 0` to `>= 0 && any > 0` is safe because all existing nonprob test data has positive weights).

#### E. Implement validator change (GREEN phase)

- [ ] **E1.** In `R/core-classes.R`, locate the `survey_nonprob` validator condition 4 (lines ~700–710). Replace the single `<= 0` check with two checks:
  - **Condition 4a** — reject negative weights (`< 0`): `n_neg <- sum(non_na < 0)`, error class `surveycore_error_weights_negative`, message per spec §III.
  - **Condition 4b** — reject all-zero weights (`!any(non_na > 0)`): error class `surveycore_error_weights_all_zero`, message per spec §III.
- [ ] **E2.** Run `devtools::test(filter = "s7-classes")` to confirm all 9 new tests pass (GREEN). Run `devtools::test(filter = "constructors")` to confirm existing tests still pass (especially the unchanged ones from C3).

#### F. Full test suite + quality gates

- [ ] **F1.** Run `devtools::test()` — full suite. All tests must pass, including all existing `survey_taylor` and `survey_replicate` tests (which are unchanged).
- [ ] **F2.** Run `devtools::check()` — 0 errors, 0 warnings, ≤2 pre-approved notes.
- [ ] **F3.** Run `devtools::document()` — no roxygen changes expected, but confirm NAMESPACE and man/ are in sync.
- [ ] **F4.** Verify 98%+ line coverage is maintained.

### Acceptance criteria

- [ ] `survey_nonprob` validator condition 4 split into 4a (negative) and 4b (all-zero)
- [ ] Zero weights accepted by `survey_nonprob` validator when at least one positive weight exists
- [ ] Negative weights rejected with `surveycore_error_weights_negative`
- [ ] All-zero weights (no positive) rejected with `surveycore_error_weights_all_zero`
- [ ] `survey_taylor` and `survey_replicate` validators unchanged (strict > 0)
- [ ] `test_invariants()` updated: `>= 0` with `any > 0` for `survey_nonprob` path only
- [ ] `plans/error-messages.md` updated with row 101 + row 10 note + row 33 update
- [ ] All existing `survey_nonprob` weight tests updated per action table
- [ ] New happy-path, workflow-path, and edge-case tests for zero-weight `survey_nonprob` objects
- [ ] `R CMD check`: 0 errors, 0 warnings, ≤2 notes
- [ ] 98%+ line coverage maintained
- [ ] No snapshot changes needed (all new tests use `class=` only per Layer 1 convention)

### Notes

- **Do NOT modify `.validate_weights()` in `R/core-validators.R`.** It retains the `<= 0` check. The constructor still requires positive weights at creation time; zeros only arise from post-construction operations.
- **Do NOT modify the `survey_taylor` or `survey_replicate` validators.** They retain strict positivity (`> 0`).
- The `test_invariants()` main branch (~line 359 in `helper-test-data.R`) is separated from the `survey_nonprob` branch by an early `return(invisible(design))` at ~line 301. Only the nonprob branch is modified.
- The test at `test-constructors.R:1672` (`as_survey_nonprob() rejects non-positive weights`) uses `as_survey_nonprob()` which goes through `.validate_weights()`. That validator still rejects zeros with `surveycore_error_weights_nonpositive`. This test is **unchanged**.
- No existing snapshots are affected. New S7 validator tests use `class=` only per Layer 1 convention — no snapshot.
