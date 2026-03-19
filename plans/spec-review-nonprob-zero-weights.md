# Spec Review: nonprob-zero-weights — Pass 1 (2026-03-18)

### New Issues

#### Section: I. Scope

No new issues found.

#### Section: II. Architecture

No new issues found.

#### Section: III. Change 1 — Relax `survey_nonprob` Validator Condition 4

**Issue 1: Condition 4b reuses `surveycore_error_weights_all_zero` but the existing condition 3 usage has a different message**
Severity: REQUIRED
Violates DRY (Lens 1) and contract completeness (Lens 3)

The spec says condition 4b reuses `surveycore_error_weights_all_zero` and that conditions 3 and 4b are "mutually exclusive, so the shared class is unambiguous." This is correct for dispatching — but the *message text* differs between the two conditions. Condition 3 (all-NA) currently says `"Weight column {.field {weights_var}} has no non-NA values."` while the new condition 4b says `"Weight column {.field {weights_var}} has no positive values."` Snapshot tests match on exact message text, not just error class. Two different messages with the same class is fine for programmatic `tryCatch(class=)` usage but could confuse snapshot reviewers who see `surveycore_error_weights_all_zero` producing different text depending on the path.

This is not blocking because the conditions are mutually exclusive and the error class semantics are correct. But it's worth noting explicitly in the spec that the two messages intentionally differ.

Options:
- **[A]** Add a note in §III acknowledging the different message text under the shared class. — Effort: low, Risk: low, Impact: clarifies for implementer and snapshot reviewer, Maintenance: none
- **[B] Do nothing** — The implementer can figure this out from context.

**Recommendation: A** — A one-line note prevents confusion during snapshot review.

---

**Issue 2: Spec says `as_survey_nonprob()` constructor "still requires positive weights at creation time" but doesn't state which validation function enforces this**
Severity: SUGGESTION
Lens 3 (Contract Completeness)

The "What Does NOT Change" section says the constructor retains strict positivity via `.validate_weights()`, but doesn't name the file or function explicitly. The implementer needs to know that `.validate_weights()` in `R/core-validators.R` (line 95) is the function that enforces this — and that it must NOT be modified. This is inferrable from the code, but stating it explicitly prevents an implementer from accidentally relaxing `.validate_weights()` instead of the S7 validator.

Options:
- **[A]** Add a line: "The constructor's `.validate_weights()` (`R/core-validators.R`) retains `<= 0` check — do not modify." — Effort: low, Risk: low, Impact: prevents wrong-file edit, Maintenance: none
- **[B] Do nothing** — The non-deliverables table already says constructor is unchanged.

**Recommendation: A** — Cheap insurance against a common implementation mistake.

---

#### Section: IV. Change 2 — Update `test_invariants()`

**Issue 3: `test_invariants()` change is not scoped to `survey_nonprob` — it will break other design types**
Severity: BLOCKING
Violates contract completeness (Lens 3)

The spec shows the new `test_invariants()` code as:
```r
testthat::expect_true(
  all(wt_col[!is.na(wt_col)] >= 0),
  label = "weight column has all non-negative non-NA values"
)
```

But `test_invariants()` already has a **separate code path** for `survey_nonprob` (lines 245–301 of `helper-test-data.R`). The weight positivity check at line 287 is inside the `survey_nonprob` branch. The spec doesn't mention that this is a nonprob-specific path — it reads as though there's a single weight check to update.

The main branch (for `survey_taylor`, `survey_replicate`, etc.) also has a `> 0` weight check (around line 340+). If the implementer updates the wrong branch, `survey_taylor` objects would accept zero weights in tests, masking real bugs.

The spec must explicitly state: **only the `survey_nonprob` branch of `test_invariants()` is modified.** The main branch retains `> 0`.

Options:
- **[A]** Add explicit scoping: "Update only the `survey_nonprob` branch of `test_invariants()` (lines ~286-289 in `helper-test-data.R`). The main branch (for `survey_taylor`, `survey_replicate`, `survey_twophase`) retains strict `> 0`." — Effort: low, Risk: low, Impact: prevents breaking all design type tests, Maintenance: none
- **[B] Do nothing** — Implementer might update the wrong branch and break 2000+ tests.

**Recommendation: A** — This is essential disambiguation.

---

#### Section: V. Error Table Changes

**Issue 4: Error table row 33 narrowing note not specified precisely**
Severity: SUGGESTION
Lens 3 (Contract Completeness)

The spec says to "add a note that [row 33] applies to `survey_taylor`/`survey_replicate` only." But it doesn't show the exact wording to add to `plans/error-messages.md`. Given how the error table is used as the single source of truth, the spec should show the exact change.

Options:
- **[A]** Add the exact text: update row 33's "Function" column from `S7 validator (survey_taylor)` to `S7 validator (survey_taylor, survey_replicate)` and add a note: "No longer thrown by `survey_nonprob` validator (see `surveycore_error_weights_negative`)." — Effort: low, Risk: low, Impact: keeps error table precise, Maintenance: none
- **[B] Do nothing** — Implementer can infer the wording.

**Recommendation: A** — The error table is a contract; changes to it should be exact.

---

**Issue 5: New error class `surveycore_error_weights_negative` needs a row number in `plans/error-messages.md`**
Severity: REQUIRED
Lens 3 (Contract Completeness)

The spec's error table in §V shows the new class and its message template, but doesn't assign a row number for `plans/error-messages.md`. The error table uses sequential numbering (currently up to row 100 for `get_diffs()`). The new class needs row 101 (or similar) assigned explicitly so the coverage map in the error table stays traceable.

Similarly, the reuse of `surveycore_error_weights_all_zero` for condition 4b needs a new row or a note on row 10, since the existing row 10 documents `as_survey()` usage, not the `survey_nonprob` validator.

Options:
- **[A]** Assign row 101 for `surveycore_error_weights_negative` (thrown by `survey_nonprob` validator) and add a note to row 10 that `surveycore_error_weights_all_zero` is also thrown by the `survey_nonprob` validator condition 4b. — Effort: low, Risk: low, Impact: traceability, Maintenance: none
- **[B] Do nothing** — The implementer can assign the number.

**Recommendation: A** — Spec should be complete before handing off.

---

#### Section: VI. Testing

**Issue 6: Tests use `survey_nonprob()` constructor directly — but the constructor doesn't accept bare `data` + `variables` like that**
Severity: BLOCKING
Lens 2 (Test Completeness)

The happy-path test in §VI constructs a `survey_nonprob` as:
```r
obj <- survey_nonprob(
  data = df,
  variables = list(weights = "w", probs_provided = FALSE)
)
```

This is the raw S7 constructor, which works. But the `variables` list is incomplete — it's missing `ids`, `strata`, `fpc`, `nest`, and `visible_vars` keys. Per `code-style.md §2`, all keys must always be present. The existing tests (e.g., `test-s7-classes.R` line 754) pass the full list. The spec's test code would likely still work (S7 doesn't validate key completeness at the class level, `test_invariants()` does), but `test_invariants(obj)` will fail because it checks for specific keys.

Looking at the `test_invariants()` nonprob branch: it checks `"weights" %in% names(design@variables)` and `"probs_provided" %in% names(design@variables)`, but the happy-path test calls `test_invariants(obj)`. Since the spec only passes `weights` and `probs_provided`, the invariant check will pass. BUT: if `test_invariants()` is ever expanded to check for `visible_vars` or other keys, these tests will break.

More importantly, the tests should mirror the **realistic creation path**. The spec should use `as_survey_nonprob()` for happy-path tests (which exercises the constructor + validator) and the raw `survey_nonprob()` constructor only for validator-specific error tests.

Options:
- **[A]** Rewrite happy-path and edge-case tests to use `as_survey_nonprob()`, and use the raw constructor only for error-path tests where direct construction is needed. For error-path tests, use the full `variables` list. — Effort: low, Risk: low, Impact: tests match real usage, Maintenance: lower
- **[B]** Keep raw constructor but add all required keys to the `variables` list. — Effort: low, Risk: low, Impact: consistent with existing test patterns
- **[C] Do nothing** — Tests may pass but don't follow established patterns.

**Recommendation: A** — Happy-path tests should use the public API. Error-path tests that need to bypass the constructor to test the S7 validator directly should use the full `variables` list (matching the pattern in existing `test-s7-classes.R` tests).

BUT — there's a catch. The happy-path tests are testing whether the **validator** accepts zero weights. If you use `as_survey_nonprob()`, the constructor's `.validate_weights()` will reject zero weights before the S7 validator ever sees them. The spec explicitly says "zeros only arise from post-construction operations." So happy-path tests for zero weights must:

1. Create a valid `survey_nonprob` via `as_survey_nonprob()` (positive weights)
2. Then mutate the weights to include zeros (triggering the S7 validator)

The spec's test approach of calling the raw constructor with zero weights will work, but it bypasses the intended workflow. The spec should include **both**: a raw-constructor test (proving the validator accepts zeros) and a workflow test (proving that post-construction weight assignment works).

**Revised recommendation:** Add a workflow-style test that constructs via `as_survey_nonprob()` and then assigns zero weights via `@data<-`, which is the actual use case this change enables. This is the test that proves the surveywts integration works.

---

**Issue 7: No test for the S7 re-validation trigger path (the actual use case)**
Severity: REQUIRED
Violates Lens 6 (API Coherence & User Expectations)

The entire motivation for this change (§I "Why This Change") is that S7 re-triggers the validator on `@data<-` assignment when surveywts sets nonrespondent weights to 0. But §VI has no test that exercises this path:

```r
test_that("survey_nonprob allows zero weights after post-construction assignment", {
  df <- data.frame(x = 1:5, w = c(1, 2, 3, 4, 5))
  obj <- as_survey_nonprob(df, weights = w)

  # Simulate surveywts adjust_nonresponse() setting zeros
  new_data <- obj@data
  new_data$w <- c(1, 0, 0, 4, 0)
  obj@data <- new_data  # This triggers S7 re-validation

  test_invariants(obj)
  expect_equal(sum(obj@data$w == 0), 3L)
})
```

This is the test that proves the feature works for its intended purpose. Without it, all other tests are proving a tangential case (direct construction with zeros).

Options:
- **[A]** Add this test to §VI as a new category: "Workflow path — post-construction weight assignment triggers validator." — Effort: low, Risk: low, Impact: tests the actual use case, Maintenance: none
- **[B] Do nothing** — The raw-constructor tests prove the validator logic is correct, but don't prove the integration path works.

**Recommendation: A** — This is the most important test in the spec.

---

**Issue 8: Missing Layer 1 vs Layer 3 testing distinction**
Severity: REQUIRED
Violates `testing-surveycore.md` (Layer 1 vs Layer 3 error testing)

Per `testing-surveycore.md`, Layer 1 (S7 validator) errors use `class=` only — no snapshot. Layer 3 (constructor) errors use the dual pattern (`class=` + snapshot). The spec's error-path tests for conditions 4a and 4b use the raw constructor (`survey_nonprob()`), which means they're testing Layer 1 errors. The spec correctly uses only `expect_error(class=)` without snapshots — good.

However, the "Existing Tests to Update" section says existing tests that assert `surveycore_error_weights_nonpositive` for `survey_nonprob` must be updated. The existing test at `test-constructors.R:1672` uses the dual pattern (class= + snapshot) because it goes through `as_survey_nonprob()` (Layer 3). The spec needs to clarify: the constructor test at `test-constructors.R:1672` still uses `.validate_weights()` which retains `<= 0`, so that test should NOT be updated — it should remain as-is with `surveycore_error_weights_nonpositive`.

The tests that DO need updating are:
- `test-constructors.R:1835` — uses raw `survey_nonprob()` constructor, currently asserts `surveycore_error_weights_nonpositive` for negative weights → change to `surveycore_error_weights_negative`
- `test-constructors.R:1672` — uses `as_survey_nonprob()` with zero weight → this will STILL error via `.validate_weights()` with `surveycore_error_weights_nonpositive` because the constructor validator is unchanged. **Do not update this test.**

The spec's §VI "Existing Tests to Update" section is imprecise about which tests use the raw constructor vs. `as_survey_nonprob()`.

Options:
- **[A]** Add an explicit table of existing tests that need updating vs. those that should remain unchanged, distinguishing Layer 1 (raw constructor) from Layer 3 (`as_survey_nonprob()`) tests. — Effort: medium, Risk: low, Impact: prevents implementer from breaking working tests, Maintenance: none
- **[B] Do nothing** — Implementer must figure out which tests to touch by reading the test files.

**Recommendation: A** — The distinction is subtle and important.

---

**Issue 9: Snapshot update guidance is vague**
Severity: SUGGESTION
Lens 2 (Test Completeness)

§VI "Snapshot Updates" says "Snapshot files in `_snaps/test-s7-classes.md` will need updating via `snapshot_review()`." But the `survey_nonprob` validator tests in `test-s7-classes.R` currently only have `class=` assertions (Layer 1 — no snapshots). The tests in `test-constructors.R` that use `as_survey_nonprob()` do have snapshots, but those tests are unchanged (the constructor still rejects zero weights).

So which snapshots actually need updating? Likely none — unless the spec's new tests add snapshots. The spec should state: "No existing snapshots are affected. New validator tests use `class=` only per Layer 1 convention."

Options:
- **[A]** Replace the vague guidance with: "No existing snapshots are affected by this change. New S7 validator tests use `class=` only (Layer 1 convention — no snapshot)." — Effort: low, Risk: low, Impact: saves implementer time investigating, Maintenance: none
- **[B] Do nothing** — Implementer runs `snapshot_review()` and finds nothing to review.

**Recommendation: A** — Precision saves time.

---

**Issue 10: Test completeness — 13 categories audit**
Severity: SUGGESTION
Lens 2 (Test Completeness)

This spec modifies a validator, not an exported analysis function, so most of the 13 test categories are N/A. For completeness:

1. **Happy path** — ✅ Covered (zero weights accepted)
2. **Numerical oracle** — N/A (validator, not estimator)
3. **Grouped analysis** — N/A
4. **Domain estimation** — N/A
5. **Variance argument** — N/A
6. **label_values** — N/A
7. **label_vars** — N/A
8. **meta() contract** — N/A
9. **name_style = "broom"** — N/A
10. **Error paths** — ✅ Covered (conditions 4a, 4b)
11. **Edge cases** — ✅ Covered (single positive among zeros, mix of zeros+NAs, mix of zeros+negatives)
12. **Multi-variable** — N/A
13. **Print snapshot** — N/A

Mechanic checks:
- `test_invariants()` as first assertion? ✅ Specified in happy-path tests
- Dual pattern for Layer 3? N/A — no Layer 3 changes
- `class=` only for Layer 1? ✅ Correctly specified
- `class=` on every error/warning? ✅

No issues found in this audit.

---

#### Section: VII. Quality Gates

No new issues found. The gates are comprehensive and match the deliverables.

#### Section: VIII. Integration

No new issues found. The dependency chain and release order are clear.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 3 |
| SUGGESTION | 5 |

**Total issues:** 10

**Overall assessment:** The spec is well-structured and the core logic change is clearly defined. The two blocking issues are: (1) the `test_invariants()` change lacks scoping to the `survey_nonprob` branch only, which could break all other design type tests if implemented carelessly; and (2) the test code uses incomplete `variables` lists and doesn't test the actual workflow path (post-construction `@data<-` assignment). Both are straightforward to fix. The required issues involve error table precision and test layer distinctions that prevent implementer mistakes. Once these are resolved, the spec is ready for implementation.

---

# Spec Review: nonprob-zero-weights — Pass 2 (2026-03-18)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Condition 4b reuses `surveycore_error_weights_all_zero` with different message text | ✅ Resolved — §III lines 138–143 now explicitly note that "the message text intentionally differs between the three call sites that use this class" |
| 2 | Constructor `.validate_weights()` location not stated explicitly | ✅ Resolved — §III lines 153–158 now name `.validate_weights()` (`R/core-validators.R`, line ~135) with an explicit "Do not modify" directive |
| 3 | `test_invariants()` change not scoped to `survey_nonprob` branch | ✅ Resolved — §IV lines 164–170 explicitly scope to the `survey_nonprob` branch (~line 287), note the main branch retains `> 0`, and reference the early `return(invisible(design))` separator at ~line 301 |
| 4 | Error table row 33 narrowing note not precisely specified | ✅ Resolved — §V lines 222–225 show the exact row 33 edit (Function column text + cross-reference note) |
| 5 | New error class needs row number in error table | ✅ Resolved — §V assigns row 101 for `surveycore_error_weights_negative` and adds a note to row 10 for the `survey_nonprob` condition 4b reuse |
| 6 | Tests use incomplete `variables` lists in raw constructor | ✅ Resolved — all raw-constructor tests in §VI now use the full `variables` list (all 7 keys: `weights`, `probs_provided`, `ids`, `strata`, `fpc`, `nest`, `visible_vars`) |
| 7 | No test for S7 re-validation trigger path | ✅ Resolved — §VI now leads with a "Workflow path" test that creates via `as_survey_nonprob()` then mutates weights via `@data<-` |
| 8 | Missing Layer 1 vs Layer 3 testing distinction | ✅ Resolved — §VI now has an "Existing Tests — Action Table" with explicit Layer, current class, and required action per test, including "Unchanged" for Layer 3 constructor tests |
| 9 | Snapshot update guidance vague | ✅ Resolved — §VI "Snapshot Updates" now states "No existing snapshots are affected" and clarifies Layer 1 convention |
| 10 | Test completeness 13-category audit | ✅ No action needed (informational — all categories audited, no gaps found) |

### New Issues

#### Section: I. Scope

No new issues found.

#### Section: II. Architecture

No new issues found.

#### Section: III. Change 1 — Relax `survey_nonprob` Validator Condition 4

No new issues found. The two-check split (4a negative, 4b all-zero) is clearly specified with exact code, rationale, and explicit "What Does NOT Change" boundaries.

#### Section: IV. Change 2 — Update `test_invariants()`

No new issues found. The scoping to the `survey_nonprob` branch is explicit, the replacement code mirrors the validator logic, and the main branch is explicitly protected.

#### Section: V. Error Table Changes

No new issues found. Row assignments (101 new, row 10 note, row 33 update) are precise.

#### Section: VI. Testing

**Issue 11: Missing edge case — all-zero weights with NAs**
Severity: SUGGESTION
Lens 4 (Edge Cases)

The test section covers `c(0, 0, 0)` (all-zero, no NAs) and `c(0, NA, 1, 0)` (zeros+NAs with one positive). But there is no test for the boundary between conditions 3 and 4b: weights like `c(0, NA, 0)` where non-NA values exist (condition 3 doesn't fire) but none are positive (condition 4b fires with `surveycore_error_weights_all_zero`).

The logic is simple (`length(non_na) == 2L` so condition 3 passes, `!any(c(0, 0) > 0)` so condition 4b fires), but this exact boundary is worth an explicit test since conditions 3 and 4b share the same error class with different messages.

Options:
- **[A]** Add an edge-case test with `w = c(0, NA, 0)` asserting `class = "surveycore_error_weights_all_zero"`. — Effort: low, Risk: low, Impact: covers condition 3/4b boundary, Maintenance: none
- **[B] Do nothing** — The existing all-zero test (`c(0, 0, 0)`) and zeros+NAs test (`c(0, NA, 1, 0)`) cover the individual paths; the boundary is inferrable.

**Recommendation: A** — One extra test block for a boundary between two conditions that share a class name is cheap insurance.

---

**Issue 12: Action table line 1835 — test name should also update**
Severity: SUGGESTION
Lens 3 (Contract Completeness)

The action table says to change the error class at `test-constructors.R:1835` from `surveycore_error_weights_nonpositive` to `surveycore_error_weights_negative`, but doesn't mention updating the test description from `"survey_nonprob validator rejects non-positive weight column"` to `"survey_nonprob validator rejects negative weight column"`. After the change, zero weights are no longer "non-positive" violations for `survey_nonprob`, so the old name is misleading.

Options:
- **[A]** Add a note to the action table: also rename the test to `"survey_nonprob validator rejects negative weights"`. — Effort: low, Risk: low, Impact: test names match behavior, Maintenance: none
- **[B] Do nothing** — The implementer can infer the rename.

**Recommendation: A** — Test names should describe the behavior they verify.

---

#### Section: VII. Quality Gates

No new issues found.

#### Section: VIII. Integration

No new issues found.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 0 |
| SUGGESTION | 2 |

**Total new issues:** 2

**Prior issues:** 10/10 resolved

**Overall assessment:** The spec comprehensively addressed all 10 Pass 1 issues. The two remaining suggestions are minor polish — an additional edge-case test for the condition 3/4b boundary and a test rename in the action table. Neither blocks implementation. The spec is ready for implementation.
