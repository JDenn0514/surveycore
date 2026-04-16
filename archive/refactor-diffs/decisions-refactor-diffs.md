# Decisions Log — surveycore refactor-diffs

This file records planning decisions made during refactor-diffs.
Each entry corresponds to one planning session.

---

## 2026-04-01 — Stage 4 code review resolution

### Context

Worked through 9 issues from `plans/spec-review-refactor-diffs.md` (Stage 3
adversarial review). Two blocking gaps required spec changes with real
behavioral implications; the remaining issues were clarifications and
suggestions.

### Questions & Decisions

**Q: When `show_means = FALSE` and `show_pct_change = TRUE`, where does `.build_diffs_output()` get `ref_mean` for `pct_change` computation?**
- Options considered:
  - **Fallback to result:** use `result$reference_mean` (clean path) or matching `result$preds_df` row (ME path) when `show_means = FALSE` — preserves no-group behavior, unifies grouped behavior
  - **Always NA:** simpler rule, but behavioral regression for no-group case that violates the quality gate
- **Decision:** Fallback to `result` (Option A). Spec §3.3.2 and §3.3.5 updated with explicit fallback rule.
- **Rationale:** The quality gate requires byte-for-byte identical output. The no-group branch already uses this fallback; the grouped branch had a bug (always NA). The refactor should unify behavior at the no-group branch's level, not regress to the grouped branch's level.

**Q: Should `.apply_domain()` be called inside `.build_diffs_output()` or externally in `get_diffs()` with `domain_mask` passed as a parameter?**
- Options considered:
  - **External (pass as parameter):** matches existing code, §3.3 signature, and §IV skeleton; `domain_mask` is pre-computed in `get_diffs()` before the call
  - **Internal (inside helper):** matches §II.2 table entry (which was an error); slightly tidier call site, harder to unit-test in isolation
- **Decision:** External / pass as parameter (Option A). §II.2 table entry corrected to read "result passed into `.build_diffs_output()` as `domain_mask`."
- **Rationale:** §3.3 and §IV are the authoritative sections written after §II.2. Passing pre-computed masks is more testable and consistent with the existing code pattern.

**Q: Where should `expect_snapshot(error = TRUE)` go for `surveycore_error_reference_row_not_found` — on the helper call, on `get_diffs()`, or both?**
- Options considered:
  - **`get_diffs()` only:** snapshot on public API; consistent with Layer 3 convention
  - **Both helper and `get_diffs()`:** more coverage; acceptable duplication since message is identical
- **Decision:** Both (Option B). Spec §5.2 updated.
- **Rationale:** User preferred belt-and-suspenders coverage here. The helper is called only from `get_diffs()`, so both snapshots capture the same message — duplication is harmless and ensures the helper itself is exercised in the snapshot baseline.

**Q: Should `avg_slopes()` / `avg_predictions()` use an explicit `if`/`else` call structure (keeping `by` absent for no-groups), or use `by = if (length(group_names) > 0) group_names else NULL`?**
- Options considered:
  - **Conditional if/else:** preserves existing two-branch pattern; `by` is genuinely absent (not `NULL`) in no-group case; no marginaleffects research required
  - **`by = NULL` with verification:** cleaner syntax but requires verifying `by = NULL` ≡ omitting `by` in marginaleffects — adds scope to a pure-refactor
- **Decision:** Conditional if/else (Option A). Spec §3.2 steps 3–4 updated with explicit call structure.
- **Rationale:** This is a pure-refactor with a byte-for-byte quality gate. The existing code deliberately uses separate branches. Adding research scope to verify `by = NULL` equivalence is out of scope. The if/else "duplication" is minimal.

**Q: Should `groups_df` in the no-group case be a 0×0 `data.frame` (matching current behavior) or an N×0 `data.frame` as the original spec specified?**
- Options considered:
  - **0×0 `data.frame()`:** matches current behavior; nrow is never checked downstream; simpler to implement
  - **N×0 with nrow = row count:** overconstrained; adds work without any observable behavioral requirement; diverges from current code
- **Decision:** 0×0 / `data.frame()` (Option A). Spec §3.3.6 updated.
- **Rationale:** Quality gate says no edge cases handled differently from current behavior. Downstream code only checks `ncol(groups_df) > 0L` — nrow is irrelevant. The nrow constraint was a spec error.

### Outcome

All 9 code review issues resolved. Spec version bumped to 0.2 and approved.
Ready for `/implementation-workflow`.

---

## 2026-04-01 — Stage 4 code review resolution (Pass 2)

### Context

Worked through 3 issues from Pass 2 of `plans/spec-review-refactor-diffs.md`. Issues covered the `.extract_me_estimates()` return contract, a deliberate behavioral fix embedded in the refactor's quality gate, and warning test pattern clarity.

### Questions & Decisions

**Q: How should `result_means` be typed in the §3.2 return contract, and how is it populated on the no-group ME path?**
- Options considered:
  - **Add to differences table + step 6a:** `result_means` typed as `double | NULL`; step 6a specifies the named-vector lookup from `preds_df` for the no-group case; `NULL` when `suppress_mean = TRUE`
  - **Do nothing:** implementer infers from code; return type table and test spec remain contradictory
- **Decision:** Add to differences table + step 6a (Option A).
- **Rationale:** The test spec explicitly expects `NULL` when `suppress_mean = TRUE`; the return type table said `double` — a direct contradiction. Gap B is a spec omission that describes only the grouped case; the no-group lookup mechanism must be specified for a complete contract.

**Q: Should the quality gate acknowledge the `show_means = FALSE` + grouped + `show_pct_change = TRUE` behavioral fix, and should a test row be added to lock it in?**
- Options considered:
  - **Gate note + new §5.2 test row:** document the exception in §VI; add a regression test row to §5.2 that validates the corrected behavior
  - **Gate note only:** documents the exception but leaves the fix untested
  - **Do nothing:** undocumented behavioral improvement; future tests produce confusing failures
- **Decision:** Gate note + new test row (Option B).
- **Rationale:** No existing test covers this combination, so the gate technically holds — but adding the regression test ensures the fix is permanently validated and removes any future ambiguity. The gate note gives implementers the context they need.

**Q: Should the §5.2 warning test rows explicitly state the assertion pattern?**
- Options considered:
  - **Add one-sentence note:** `expect_warning(class = ...)` only, no snapshot — prevents confusion from visual proximity to the dual-pattern error spec
  - **Do nothing:** testing-standards.md is authoritative
- **Decision:** Add note (Option A).
- **Rationale:** Trivial addition; the dual-pattern example immediately above creates a real risk of misapplication.

### Outcome

All 3 Pass 2 code review issues resolved. Spec bumped to version 0.3 and approved. Ready for `/implementation-workflow`.

---

## 2026-04-01 — Stage 3 plan review resolution

### Context

Worked through 3 issues from `plans/plan-review-refactor-diffs.md` (Stage 2 adversarial review of the implementation plan). One required fix and two suggestions; all resolved with recommended options.

### Questions & Decisions

**Q: How should the Files section describe `test-analysis-diffs-helpers.R` given that the file already has 267 lines of existing tests?**
- Options considered:
  - **Update Files entry:** explicitly note "Add tests to existing file; existing content unchanged" with an enumerated list of what must not be overwritten
  - **Add a Note section entry:** same protection but less visible to an implementer scanning the Files section first
- **Decision:** Update the Files entry (Option A).
- **Rationale:** An implementer reads the Files section before Notes; the risk of silent test deletion is too high to rely on a Note they may skim.

**Q: What path should the changelog entry use for F5?**
- Options considered:
  - **`changelog/refactor-analysis-diffs.md` (top-level):** matches the existing `chore-*` / `feature-*` top-level pattern for maintenance work
  - **`changelog/refactor/analysis-diffs-helpers.md` (sub-directory):** cleaner if more refactor entries follow
- **Decision:** Top-level `changelog/refactor-analysis-diffs.md` (Option A).
- **Rationale:** No `changelog/refactor/` directory exists; creating one for a single entry adds friction. Top-level is consistent with the existing maintenance-work pattern.

**Q: Should the ≤500 line acceptance criterion be tightened to reflect the spec's ~400 target?**
- Options considered:
  - **Keep ≤500, add note:** surfaces the ~400 intent as informational without hardening an approximate metric
  - **Tighten to ≤450:** catches partial extractions earlier but may need adjustment once the actual post-refactor line count is known
- **Decision:** Keep ≤500, add note (Option B).
- **Rationale:** The ~400 target is an estimate from spec §II; the hard gate of ≤500 provides a practical buffer without requiring the spec to anticipate every comment and blank line. The note surfaces the intent for code review.

### Outcome

All 3 plan review issues resolved. Plan approved. Ready for `/r-implement` starting with PR 1.

---
