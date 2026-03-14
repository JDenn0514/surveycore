# Decisions Log — surveycore get-corr-grouping

This file records planning decisions made during get-corr-grouping.
Each entry corresponds to one planning session.

---

## 2026-02-27 — Plan review resolution (Stage 3)

### Context

Working through the 8 issues raised in the Stage 2 adversarial review of
`plans/get-corr-grouping-implementation-plan.md`. All issues were resolved
in one session.

### Questions & Decisions

**Q: Should `.corr_wide()` be kept (with callers) or deleted (dead code)?**
- Options considered:
  - **Keep, route ungrouped wide path through it:** `.corr_wide()` stays alive; adds a branching check in B4
  - **Delete entirely:** `get_corr()` calls `.corr_build_matrix_col_vecs()` directly for all combos; no dead code
- **Decision:** Delete `.corr_wide()` entirely
- **Rationale:** The ungrouped case is a degenerate single-combo loop; the new helper handles it directly. Eliminates dead code (engineering-preferences.md §1).

**Q: Should the numerical accuracy test (Test #6) include `skip_if_not_installed("survey")`?**
- Options considered:
  - **Keep skip:** Also extend test to compare against `survey` package output
  - **Remove skip:** Oracle is `get_corr()` on a subsetted design — no external dependency
- **Decision:** Remove `skip_if_not_installed("survey")`
- **Rationale:** The oracle is surveycore-vs-surveycore; the `survey` package is not involved. The skip would silently suppress the test on most machines (testing-standards.md block-level skip rule).

**Q: Should the three SUGGESTION edge case tests be added?**
- Options considered:
  - **Add all three:** zero-row combo, NA group values, `redundant`/`diagonal` row counts
  - **Skip as excessive:** behaviors are implied by existing tests or standard R semantics
- **Decision:** Add all three
- **Rationale:** All three scenarios are explicitly listed in the plan's edge cases table. Engineering preferences §2 and §4 — more tests is better; handle more edge cases, not fewer.

### Outcome

Plan updated with: `.corr_wide()` deletion, explicit B5 loop boundary, corrected
Test #6 skip guard, `NEWS.md` in file list, formal Acceptance Criteria section,
and 3 additional edge case test blocks (total: 10 new test blocks).

---
