# Claude Decisions Log — surveycore Phase 0.75

This file records planning decisions made during implementation of Phase 0.75.
Each entry corresponds to one planning session.

---

## 2026-02-24 — Plan review resolution (Stage 3)

### Context

Working through 10 issues flagged by the Stage 2 adversarial review of
`plans/implementation-plan-phase-0.75.md`. Two were BLOCKING, five REQUIRED, three
SUGGESTION.

### Questions & Decisions

**Q: Should the plan acknowledge the 3-PR structure overrides spec Q8's single-PR decision? (Issue 1)**
- Options considered:
  - **[A]:** Add a `## Departure from Spec Q8` section explaining the rationale (each PR independently shippable, smaller diffs, cleaner CI checkpoints).
  - **[B]:** Collapse to a single PR matching the spec.
  - **[C]:** Do nothing — leave the contradiction unresolved.
- **Decision:** [A] — departure note added.
- **Rationale:** The 3-PR structure is strictly better engineering practice. Leaving a silent spec-vs-plan contradiction without resolution guidance creates unnecessary risk for the implementer. Note is low-effort and removes all ambiguity.

**Q: Should the `phase2_ind` → `subset` rename scope be expanded to all 7 affected files? (Issue 2)**
- Options considered:
  - **[A]:** Enumerate all 7 additional files, add specific rename-trap callouts, add grep acceptance criterion.
  - **[B]:** Split into a sub-PR.
  - **[C]:** Do nothing — PR 2 would fail `devtools::check()`.
- **Decision:** [A] — full file list, audit notes, and grep criterion added.
- **Rationale:** Without this, PR 2 fails on first run. 64 untracked references across 7 files including snapshot files is a blocking gap. Specific callouts for the non-obvious rename traps (column name in string literal, `starts_with()` pattern, snapshot regeneration) make the plan a reliable contract.

**Q: How should the BEFORE pattern for Warning 23b be corrected? (Issue 3)**
- Options considered:
  - **[A]:** Update BEFORE pattern to show actual `withCallingHandlers` structure and real test name.
  - **[B]:** Change instruction to search by string literal `surveycore_warning_subset_na`.
- **Decision:** [A] — actual BEFORE state shown.
- **Rationale:** The plan is a precise contract. Showing the real code the implementer will encounter (including that no `test_invariants()` call is present) removes all guesswork.

**Q: Should the `make_all_designs()` caller audit be explicit in the plan or left to CI? (Issue 10)**
- Options considered:
  - **[A]:** Add explicit audit note (grep instruction + confirm before `devtools::check()`).
  - **[B]:** Trust CI — a test failure is the signal.
- **Decision:** [A] — explicit audit note added.
- **Rationale:** User preferred proactive over reactive. The audit costs one grep command and surfaces the breakage before a CI round-trip. Consistent with the engineering preference for explicit over clever.

### Outcome

All 10 issues resolved. The plan now has: a spec-departure acknowledgment, a complete file
manifest for the rename, corrected BEFORE code for the Warning 23b test block, explicit CI
gates for all interim states, `devtools::document()` and coverage criteria on every PR,
Coverage Map updates gated in acceptance criteria, and a Warning 24 preservation note.
Plan is ready to implement.

---
