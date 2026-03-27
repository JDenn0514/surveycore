# Plan Review: nonprob-zero-weights — Pass 1 (2026-03-18)

### New Issues

#### Section: PR Map

No issues found. Single PR is appropriate — the scope (one source file, one test helper, two test files, one error table) is tightly coupled and too small to split.

#### Section: PR 1 — Files List

No issues found. All five files are listed with accurate line number references. Verified against current source:

- `R/core-classes.R` lines 700–710: confirmed `<= 0` check with `surveycore_error_weights_nonpositive`
- `tests/testthat/helper-test-data.R` line 287: confirmed `all(wt_col[!is.na(wt_col)] > 0)`
- `tests/testthat/test-constructors.R` line 1797: confirmed duplicate of `test-s7-classes.R:748`
- `tests/testthat/test-constructors.R` line 1835: confirmed `surveycore_error_weights_nonpositive`
- `tests/testthat/test-constructors.R` line 1672: confirmed Layer 3 test with `as_survey_nonprob()`
- `tests/testthat/test-s7-classes.R` line 748: confirmed existing nonprob non-numeric test
- `plans/error-messages.md` row 33: confirmed `S7 validator (survey_taylor)` with `surveycore_error_weights_nonpositive`
- `plans/error-messages.md` row 10: confirmed `surveycore_error_weights_all_zero`
- `plans/error-messages.md` last row: 100 (row 101 available for new class)

#### Section: A — Error Table Update

No issues found. Steps A1–A4 are precise, match the spec §V exactly, and correctly assign row 101.

#### Section: B — Write Failing Tests (RED Phase)

**Issue 1: B9's stated failure reason is inaccurate**
Severity: SUGGESTION
Lens 4 (Spec Coverage — accuracy of plan description)

B9 says the test "Will fail — current `test_invariants()` requires `> 0`." But the test creates an object via `as_survey_nonprob()` and then assigns zero weights via `@data<-`. The S7 validator fires on `@data<-` and rejects zeros **before** `test_invariants()` is ever reached. The stated failure reason describes what would happen after D1 (validator fixed) but before E1 (`test_invariants()` fixed) — not the actual RED-phase failure.

Options:
- **[A]** Correct B9: "Will fail — current `survey_nonprob` validator rejects zeros on `@data<-` assignment. After D1, will continue to fail because `test_invariants()` still requires `> 0` (fixed in E1)." — Effort: low, Risk: low, Impact: accurate mental model for implementer
- **[B] Do nothing** — The test fails either way; the reason is secondary.

**Recommendation: A** — The dual-stage failure is the interesting part and prepares the implementer for the D2 ordering issue (see Issue 2).

---

#### Section: C — Update Existing Tests

No issues found. C1 (delete duplicate), C2 (update class + rename), and C3 (verify unchanged) are correctly specified. The C2 rename to `"survey_nonprob validator rejects negative weights"` correctly incorporates spec review Issue 12.

#### Section: D — Implement Validator Change (GREEN Phase)

**Issue 2: D2 claims all new tests pass after D1, but 5 of 9 require E1**
Severity: REQUIRED
Violates TDD progression accuracy

D2 says: "Run `devtools::test(filter = "s7-classes")` to confirm new tests pass."

After D1 (validator change), the following tests still fail because they call `test_invariants()`, which retains the strict `> 0` check until E1:

| Step | Test | Post-D1 Status | Reason |
|------|------|----------------|--------|
| B1 | Workflow path (zero weights via `@data<-`) | FAIL | `test_invariants()` rejects zeros |
| B2 | Happy-path validator (raw constructor with zeros) | FAIL | `test_invariants()` rejects zeros |
| B3 | Error-path 4a (negative weights) | PASS | Error thrown before `test_invariants()` |
| B4 | Error-path 4b (all-zero weights) | PASS | Error thrown before `test_invariants()` |
| B5 | Edge: single positive among zeros | FAIL | `test_invariants()` rejects zeros |
| B6 | Edge: zeros + NAs + one positive | FAIL | `test_invariants()` rejects zeros |
| B7 | Edge: zeros + negatives | PASS | Error thrown before `test_invariants()` |
| B8 | Edge: all-zero + NAs | PASS | Error thrown before `test_invariants()` |
| B9 | `test_invariants()` verification | FAIL | `test_invariants()` rejects zeros |

Only 4 of 9 new tests pass after D1. The remaining 5 need E1 (`test_invariants()` update) to pass. An implementer following D2 literally will see 5 unexpected failures and may incorrectly conclude the validator change is wrong.

Options:
- **[A]** Reorder: swap D and E so `test_invariants()` is updated before the validator. E1 is safe to do first — relaxing from `> 0` to `>= 0 && any > 0` doesn't break any existing tests (existing nonprob objects have all-positive weights, which satisfy both constraints). Then D2 can correctly say "all new tests pass." — Effort: low, Risk: low, Impact: clean TDD progression
- **[B]** Split D2 into two: "D2a. Run `devtools::test(filter = "s7-classes")` — confirm error-path tests B3, B4, B7, B8 pass. Tests B1, B2, B5, B6, B9 will still fail (pending E1 — `test_invariants()` update)." Then at E3: "all 9 new tests pass (GREEN)." — Effort: low, Risk: low, Impact: accurate expectations at each step
- **[C] Do nothing** — Implementer discovers the ordering issue and recovers.

**Recommendation: A** — Reordering is the cleanest fix. `test_invariants()` relaxation is safe to apply first because it doesn't change behavior for any existing test data (all existing nonprob weights are positive). This gives a proper RED → GREEN progression where D (now the last code change) is the point where all tests go green.

---

#### Section: E — Update `test_invariants()` (GREEN Phase)

No issues found. E1 correctly targets only the `survey_nonprob` branch (line ~287). E2 correctly protects the main branch (line ~359). The separation via `return(invisible(design))` at line 301 is accurately documented.

#### Section: F — Full Test Suite + Quality Gates

No issues found. F1–F4 cover the full suite, R CMD check, `devtools::document()`, and coverage. The "no roxygen changes expected" note in F3 is accurate — only the validator body changes, no roxygen blocks.

#### Section: Acceptance Criteria

No issues found. All 12 criteria are objectively verifiable and map 1:1 to spec §VII Quality Gates. The "No snapshot changes needed" criterion is accurate — all new tests are Layer 1 (`class=` only).

#### Section: Notes

No issues found. The four guardrails (don't modify `.validate_weights()`, don't modify `survey_taylor`/`survey_replicate`, `test_invariants()` branch scoping, `test-constructors.R:1672` unchanged) are critical and correctly stated.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 1 |
| SUGGESTION | 1 |

**Total issues:** 2

**Overall assessment:** The plan is well-structured, closely tracks the spec, and all file/line references are verified accurate against the current codebase. The one required issue is a TDD ordering problem: step D2 claims all new tests pass after the validator change, but 5 of 9 tests also depend on the `test_invariants()` update in step E1. Swapping sections D and E (updating `test_invariants()` first, then the validator) gives a clean RED → GREEN progression. Once that's resolved, the plan is ready for implementation.
