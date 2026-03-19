# Decisions Log — surveycore nonprob-zero-weights

This file records planning decisions made during nonprob-zero-weights.
Each entry corresponds to one planning session.

---

## 2026-03-18 — Code review resolution (Stage 4)

### Context

Resolved 10 issues from the adversarial code review of the
`nonprob-zero-weights` spec (2 blocking, 3 required, 5 suggestions).

### Questions & Decisions

**Q: Should happy-path tests use the raw `survey_nonprob()` constructor or the
real workflow (`as_survey_nonprob()` + `@data<-` assignment)?**
- Options considered:
  - **Option A:** Workflow tests use `as_survey_nonprob()` then mutate weights
    to zero via `@data<-`; error-path tests use raw constructor with full
    `variables` list.
  - **Option B:** All tests use raw constructor with complete `variables` list.
- **Decision:** Option A — two test categories: workflow tests (real path) and
  validator tests (raw constructor for Layer 1 coverage).
- **Rationale:** The entire feature exists so surveywts can assign zero weights
  via `@data<-`. Testing the workflow path is the most important validation.
  Raw constructor tests complement by proving validator logic in isolation.

**Q: Should the spec include an explicit action table for existing tests?**
- Options considered:
  - **Option A:** Table listing each existing test, its layer (1 or 3), and
    required action (update/unchanged/delete).
  - **Option B:** Keep the prose description ("tests with negative inputs
    should change class").
- **Decision:** Option A — explicit table with line numbers and actions.
- **Rationale:** The Layer 1 vs Layer 3 distinction is subtle. Line 1672
  (`as_survey_nonprob()`, Layer 3) must remain unchanged because
  `.validate_weights()` still rejects zeros. Line 1835 (`survey_nonprob()`,
  Layer 1) must change class. A table prevents the implementer from updating
  the wrong tests.

**Q: Should the `test_invariants()` change be scoped explicitly?**
- Options considered:
  - **Option A:** Add note: "Update only the `survey_nonprob` branch (~line 287);
    main branch (~line 359) retains `> 0`."
  - **Option B:** Let implementer infer from code.
- **Decision:** Option A — explicit scoping.
- **Rationale:** `test_invariants()` has two separate weight-check branches
  separated by an early return. Updating the wrong branch would silently allow
  zero weights in `survey_taylor`/`survey_replicate` tests.

### Outcome

Spec updated to version 0.2 (approved). All blocking and required issues
resolved with explicit scoping, full `variables` lists, workflow tests, and
an action table for existing tests. Ready for `/implementation-workflow`.

---

## 2026-03-18 — Code review Pass 2 resolution (Stage 4)

### Context

Resolved 2 remaining suggestions from the Pass 2 code review. All 10 Pass 1
issues had already been addressed in the spec.

### Questions & Decisions

**Q: Should we add an edge-case test for all-zero weights with NAs (`c(0, NA, 0)`)?**
- Options considered:
  - **Option A:** Add the test — covers the condition 3/4b boundary where
    non-NA values exist but none are positive.
  - **Option B:** Do nothing — existing tests cover the individual paths.
- **Decision:** Option A — add the test.
- **Rationale:** Conditions 3 and 4b share the same error class with different
  messages. Testing the exact boundary between them is cheap insurance
  (`engineering-preferences.md §4` — handle more edge cases, not fewer).

**Q: Should the action table note a test rename at line 1835?**
- Options considered:
  - **Option A:** Add rename note alongside the class change.
  - **Option B:** Let implementer infer the rename.
- **Decision:** Option A — explicit rename note.
- **Rationale:** Test names should describe the behavior they verify. After
  the change, "rejects non-positive" is inaccurate since zeros are no longer
  rejected for `survey_nonprob`.

### Outcome

Spec updated to version 0.3 (approved). Two suggestions resolved: added
all-zero-with-NAs edge-case test and test rename note. Spec is fully approved
and ready for `/implementation-workflow`.

---

## 2026-03-18 — Implementation plan review resolution (Stage 3)

### Context

Resolved 2 issues from the adversarial review of the implementation plan
(0 blocking, 1 required, 1 suggestion).

### Questions & Decisions

**Q: Should B9's failure reason be corrected to reflect the dual-stage failure?**
- Options considered:
  - **Option A:** Correct B9 to note that the S7 validator rejects zeros on
    `@data<-` first, then after the validator fix `test_invariants()` still
    requires `> 0`.
  - **Option B:** Do nothing — the test fails either way.
- **Decision:** Option A — fix the description.
- **Rationale:** Accurate failure reasons prepare the implementer for the
  two-stage dependency between the validator change and `test_invariants()`.

**Q: Should sections D and E be swapped to fix the TDD progression?**
- Options considered:
  - **Option A:** Swap D and E — update `test_invariants()` first (safe because
    existing nonprob weights are all positive), then implement the validator
    change so all 9 new tests go GREEN at once.
  - **Option B:** Split D2 into D2a/D2b to document partial pass expectations.
  - **Option C:** Do nothing — implementer discovers the issue.
- **Decision:** Option A — swap sections D and E.
- **Rationale:** Relaxing `test_invariants()` from `> 0` to `>= 0 && any > 0`
  is safe to do first — all existing nonprob test data uses positive weights.
  This gives a clean RED → GREEN progression where the validator change (now
  section E) is the single point where all tests go green.

### Outcome

Implementation plan updated: B9 failure reason corrected, sections D and E
swapped for clean TDD progression. Plan is fully approved and ready for
implementation.

---
