# Decisions Log — surveycore variable-direction

This file records planning decisions made during variable-direction.
Each entry corresponds to one planning session.

---

## 2026-05-07 — Stage 4 Code Review Resolution

### Context

Resolving 12 issues (1 blocking, 8 required, 3 suggestions) from the Stage 3
adversarial review of `plans/spec-variable-direction.md`.

### Questions & Decisions

**Q: The console output example had rows 1 and 4 transposed for `favorable`/`backlash` under `higher_is = "worse"`. Fix the example or fix the table?**
- Options considered:
  - **Fix the example:** Table is internally consistent with the footnote; example was wrong.
  - **Fix the table:** Would reverse intended semantics.
- **Decision:** Fix the example (row 1: FALSE TRUE; row 4: TRUE FALSE).
- **Rationale:** The logic table and footnote are correct: negative diff on a "worse" variable is favorable.

---

**Q: The `get_diffs()` `direction` argument name collides with `set_higher_is()`'s `direction` argument (different semantics). What should the `get_diffs()` toggle be called?**
- Options considered:
  - **`direction = FALSE`:** Existing proposal; collides with setter's `direction` which means `"better"`/`"worse"`.
  - **`favorability = FALSE`:** Names the concept.
  - **`show_favorability = FALSE`:** Follows the existing `show_*` pattern in `get_diffs()` (`show_means`, `show_pct_change`).
  - **Character `show_impact` with values `"favorability"/"backlash"/"both"`:** User proposed; rejected because `favorable`/`backlash` are always computed together (no value in selective visibility) and character defaults are awkward vs. boolean.
- **Decision:** `show_favorability = FALSE` — follows `show_*` naming pattern, unambiguous, no collision.
- **Rationale:** Consistent with `show_means` and `show_pct_change` already in the signature. Boolean is appropriate since the feature is binary (both columns always appear together).

---

**Q: Convention 3 for `set_higher_is()` — should scalar `direction = "worse"` be recycled to match `variable` length, or require exact match?**
- Options considered:
  - **Option A (scalar recycles):** `direction = "worse"` with 2 variables applies "worse" to both. Natural for setting many variables to the same direction.
  - **Option B (exact match required):** Consistent with `set_var_label()` and all other setters using `.parse_setter_input()`, which errors with `surveycore_error_setter_mismatched_lengths` on length mismatch.
- **Decision:** Option B — exact match required; reuse existing `surveycore_error_setter_mismatched_lengths`.
- **Rationale:** `set_higher_is()` uses `.parse_setter_input()` which already enforces exact length match. Deviating would create inconsistency across all setters.

---

**Q: Convention 2 for `set_higher_is()` — spec showed `list(...)` but detection rule uses named character vector. Fix example?**
- Options considered:
  - **Correct to `c(anxiety = "worse", agreement = "better")`:** Matches `.parse_setter_input()` `content_type = "scalar"` detection (named character vector, not named list).
  - **Keep `list(...)`:** Wrong; would not be detected as Convention 2.
- **Decision:** Correct to `c(...)` and document the detection rule.
- **Rationale:** `.parse_setter_input()` with `content_type = "scalar"` matches named character vectors; named lists are the `content_type = "vector"` path used by `set_val_labels()`.

---

**Q: Should the spec reference existing variable-name resolution helpers to prevent DRY violations?**
- Options considered:
  - **Reference existing patterns:** Name `.parse_setter_input()`, `set_sata()` pattern, `extract_var_label()` pattern in Section II.
  - **Leave to implementer:** Patterns are in the codebase and discoverable.
- **Decision:** Add explicit implementation notes to Section II.
- **Rationale:** User preference; reduces guesswork and ensures each function follows the right pattern.

### Outcome

Spec v0.2 approved. All 12 issues resolved: 1 blocking (example fixed), 8 required
(error table entries added, test plan expanded, `show_favorability` rename, length mismatch
behavior documented), 3 suggestions (implementation notes, Convention 2 corrected, grouped test added).

---

## 2026-05-07 — Stage 4 Code Review Resolution (Pass 2)

### Context

Resolving 4 remaining issues (0 blocking, 3 required, 1 suggestion) from the
Pass 2 adversarial review of `plans/spec-variable-direction.md`.

### Questions & Decisions

**Q: Convention 2 was spec'd for `set_higher_is()` but had no test in the PR 1 test plan. Add a test or remove Convention 2?**
- Options considered:
  - **Add happy-path test:** One test line; `.parse_setter_input()` already handles Convention 2 and is tested.
  - **Remove Convention 2:** Simplifies the API; Conventions 1 and 3 cover all real use cases.
- **Decision:** Add the test (Option A).
- **Rationale:** Convention 2 is already documented and the backend is tested; removing it would be a needless breaking change before the feature ships.

---

**Q: `favorable`/`backlash` column `label` attributes are specified but not tested. Add assertions?**
- Options considered:
  - **Add `expect_identical(attr(..., "label"), ...)` to the happy-path test:** Consistent with how all other output column labels are tested.
  - **Do nothing:** Risk of silent regression.
- **Decision:** Add label attribute assertions to the `show_favorability = TRUE` happy-path test (Option A).
- **Rationale:** The spec explicitly defines these attributes; one assertion per column costs nothing.

---

**Q: `alpha = NA`, `alpha = Inf`, and `alpha = c(0.05, 0.1)` are explicitly named as invalid in the spec but absent from the error-path test plan. Add them?**
- Options considered:
  - **Add all three:** Closes all explicitly-named invalid cases; cli `{.val}` renders NA/vectors acceptably.
  - **Add only NA and Inf:** Non-scalar is implied by "single numeric value."
- **Decision:** Add all three (Option A).
- **Rationale:** All are realistic user mistakes and the cost is three test lines.

---

**Q: `.meta$higher_is` test description said "is populated" — ambiguous. Should the test assert the actual value?**
- Options considered:
  - **Assert the actual value `"worse"`:** Consistent with all existing `.meta` tests which use `expect_identical()` with exact values.
  - **Keep "is populated":** Non-NULL check is the intent.
- **Decision:** Assert actual value (Option A).
- **Rationale:** Matches the pattern established by all existing `.meta` assertions in test-analysis-diffs.R.

### Outcome

Spec v0.3 approved. All 4 Pass 2 issues resolved: 3 required (Convention 2 test added,
label attribute assertions added, alpha=NA/Inf/vector test cases added) and 1 suggestion
(`.meta` test sharpened to assert actual value). No scope changes — test plan only.

---

## 2026-05-07 — Stage 4 Code Review Resolution (Passes 3 & 4)

### Context

Resolving 4 remaining issues (0 blocking, 3 required, 1 suggestion) carried over from
Pass 3 and Pass 4 adversarial reviews of `plans/spec-variable-direction.md`.

### Questions & Decisions

**Q: §I scope table still listed `direction` for PR 3 instead of the renamed `show_favorability`. Fix or leave?**
- Options considered:
  - **Fix the table:** Trivial one-word change; a reviewer scanning only the table would see the wrong argument name.
  - **Do nothing:** Body is correct; table is vestigial.
- **Decision:** Fix the table (Option A).
- **Rationale:** Consistency — a stale name in a public-facing table is a documentation bug.

---

**Q: `surveycore_error_setter_mixed_dots` is referenced in the Convention 2 description for `set_higher_is()` but was absent from the error table and test plan. Add it?**
- Options considered:
  - **Add to error table (marked existing) + add test block:** Reachable error via documented input; belongs in the table.
  - **Note as delegated to `.parse_setter_input()`; no test needed:** Leaves an untested reachable error path.
- **Decision:** Add to table and test plan (Option A).
- **Rationale:** Convention 2 is a documented calling convention; the error that fires on malformed Convention 2 input must be testable.

---

**Q: `show_favorability = TRUE` produces a 9-column `survey_diffs` layout not covered by any print snapshot. Add one?**
- Options considered:
  - **Add `expect_snapshot(print(result))`:** Category 13 requirement per testing-standards.md; §V example defines expected output.
  - **Rely on value assertions only:** Formatting regressions go undetected.
- **Decision:** Add print snapshot to the `show_favorability = TRUE` happy-path test block (Option A).
- **Rationale:** Non-negotiable per testing-standards.md; cost is zero since the expected output is already shown in §V.

---

**Q: `direction = NA_character_` is a realistic mistake for `set_higher_is()` but absent from the `direction_invalid` test block. Add it?**
- Options considered:
  - **Add `NA_character_` test:** Verifies CLI `{.val}` rendering with NA; consistent with Pass 2 `alpha = NA` precedent (that was REQUIRED).
  - **Accept `"neutral"` as sufficient:** Same code path; NA rendering is slightly different but rarely diverges.
- **Decision:** Add `NA_character_` to the `direction_invalid` test block (Option A).
- **Rationale:** Establishes consistency with Pass 2 decision; CLI formatting with NA values has a known edge case worth confirming.

### Outcome

Spec v0.4 approved. All 4 issues resolved: 1 vestigial name in §I scope table corrected,
`surveycore_error_setter_mixed_dots` added to error table and test plan, print snapshot
requirement added for `show_favorability = TRUE`, and `NA_character_` test case added to
`direction_invalid` error block. No scope changes — table and test plan only.

---

## 2026-05-08 — Stage 3 Plan Review Resolution (8 issues)

### Context

Resolving all 8 open issues from plan review passes 1–3 of `plans/impl-variable-direction.md`
before handing off to `/r-implement`.

### Questions & Decisions

**Q: Issue 2 — Convention 3 `direction_invalid` untested. Does Convention 2 also need a test for this error?**
- Options considered:
  - **Convention 2 test needed:** Adds coverage for a distinct calling form.
  - **Convention 2 shares the per-pair loop path with Convention 1:** The existing Convention 1 test covers the loop. Only Convention 3's pre-check is a distinct path.
- **Decision:** Add only the Convention 3 test. Convention 2 does not need a separate `direction_invalid` test.
- **Rationale:** Convention 2 direction values pass through the same per-pair loop as Convention 1. The pre-check fires only for Convention 3 scalar inputs.

---

**Q: Issue 3 — After Issue 2 adds the Convention 3 test, what is the correct error-path block count for PR 1?**
- Options considered:
  - **8 blocks:** Original count before Issue 2 addition.
  - **9 blocks:** Original 8 + the new Convention 3 `direction_invalid` test.
- **Decision:** 9 error-path blocks for PR 1 (5 unique classes; `not_survey_or_df` and `ambiguous_input` tested separately for setter and extractor; `direction_invalid` tested for Convention 1 and Convention 3).
- **Rationale:** Issue 2's new test is an addition to the plan, so acceptance criteria must reflect the final required count.

---

**Q: Issue 5 — Favorability block reads `attr(result, ".meta")$x[[x_name]]$higher_is` but `.meta` is not yet attached at the intended insertion point. Fix by changing the read or tightening the insertion point?**
- Options considered:
  - **Use `x_meta$higher_is`:** Local variable available before insertion point; eliminates ordering constraint entirely.
  - **Tighten insertion-point wording:** Still depends on implementer reading carefully.
- **Decision:** Use `x_meta$higher_is` (local variable, not `attr(result, ".meta")`).
- **Rationale:** Removes the silent wrong-answer bug with zero trade-off. `x_meta` is assigned at line 448 and does not constrain exact insertion position.

---

**Q: Issue 8 — `direction` pre-check uses `&&` which only checks the first element of vector inputs. Fix by restricting to scalar or removing?**
- Options considered:
  - **Restrict pre-check to `length(direction) == 1L`:** Scalars caught early; vectors always validated per-element in the loop. Consistent.
  - **Remove pre-check entirely:** Fully consistent; slightly more code executed for scalar errors.
- **Decision:** Restrict pre-check to scalar with `length(direction) == 1L`.
- **Rationale:** One word scopes the pre-check to the scalar Convention 3 case it was designed for, without removing the early-exit optimization.

### Outcome

All 8 issues resolved. Coverage criteria added to all three PRs; Convention 3 `direction_invalid`
test added (PR 1 now 9 error-path blocks); acceptance criteria count corrected; Convention 3
happy-path test added to PR 2; favorability block switched to `x_meta$higher_is`; spec file
line 61 corrected (`show_favorability`); NEWS.md added to all three PRs' file lists and acceptance
criteria; pre-check restricted to scalar direction. Plan is approved and ready for `/r-implement`.

---
