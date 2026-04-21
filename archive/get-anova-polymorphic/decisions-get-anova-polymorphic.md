# Decisions Log — surveycore get-anova-polymorphic

This file records planning decisions made during get-anova-polymorphic.
Each entry corresponds to one planning session.

---

## 2026-04-21 — Stage 3 resolution of plan-review issues

### Context

Stage 2 adversarial review produced 12 issues against
`plans/impl-get-anova-polymorphic.md` (2 BLOCKING, 6 REQUIRED, 4
SUGGESTION). This session resolved each and amended the plan.

### Questions & Decisions

**Q: Does `anova.survey_glm_fit()` S3 delegator need updating in this PR?** (Issue 1)
- Options considered:
  - **A — Bring into scope:** update delegator to pass `list(object, others[[1L]])`; include in regression audit.
  - **B — Split into two PRs:** isolate the `model2` removal.
- **Decision:** A.
- **Rationale:** The delegator is 8 lines and directly broken by `model2` removal; leaving it would silently break `anova(fit1, fit2)` through the S3 generic. Splitting into two PRs is scope theater for a trivial edit. Added Task 3.3 and extended Task 9.3.

**Q: How should the fit branch react to non-NULL `formula` / `response` / `predictors`?** (Issues 2 & 7)
- Options considered:
  - **A — Explicit guard:** new error class `surveycore_error_anova_formula_unexpected`.
  - **B — Silent ignore + NEWS warning.**
- **Decision:** A.
- **Rationale:** Q1's hard break must actually break; `check_dots_empty()` doesn't see named params, so without a guard `get_anova(fit1, fit2)` silently drops `fit2` and returns single-model anova of `fit1`. A silent behavior change at a hard-break boundary violates engineering-preferences.md §5 (explicit over clever). One class covers both Issue 2 and Issue 7.

**Q: Should Task 1.1 enumerate every new error/warning class explicitly?** (Issue 3)
- Options considered:
  - **A — Enumerate all five classes as bullets.**
  - **B — Rely on error-class-auditor at PR time.**
- **Decision:** A.
- **Rationale:** Prevents drift between the plan and `plans/error-messages.md`; r-implement cannot lose a class by missing a cross-reference.

**Q: How should `survey_collection` input be handled during the deferral window?** (Issue 4)
- Options considered:
  - **A — Bundle collection dispatch into this PR** (reverses Q10 deferral).
  - **B — Keep Q10 deferral + add pre-check** throwing existing `surveycore_error_collection_not_supported_by_fn`.
  - **C — Do nothing:** collection falls through to `*_anova_object_invalid`.
- **Decision:** B.
- **Rationale:** User confirmed plan to ship collection dispatch as the immediate follow-up PR, so the deferral window is short. The pre-check is one dispatch line that gets replaced (not added-to) when the follow-up lands, so churn is zero. Option C would produce a misleading "not a supported class" error for a class that IS supported in principle, violating the cross-spec contract with `survey_collection` spec §I.

**Q: What are the semantics of `get_anova(list(fit1, fit2, fit3))` (length ≥ 3)?** (Issue 5)
- Options considered:
  - **A — Chained:** k-1 rows, consecutive pairs, mirrors `stats::anova(...)`.
  - **B — All pairwise:** k*(k-1)/2 rows.
  - **C — Error on length ≥ 3:** defer multi-model to later PR.
- **Decision:** A.
- **Rationale:** Matches `stats::anova()` semantics users already know; reuses the existing two-fit kernel in a loop; avoids re-deriving nesting/separation invariants for non-consecutive pairs (those invariants are currently defined only for the consecutive nested-model case).

**Q: NEWS.md wording for `model2`?** (Issue 6)
- Options considered:
  - **A — "removed"** (aligned with Q1 hard break).
  - **B — soft deprecation** (reopens Q1).
- **Decision:** A.
- **Rationale:** Q1 resolved to hard break; "deprecated" in NEWS would mislead users into thinking a shim exists.

**Q: Should the plan include an explicit Acceptance Criteria section?** (Issue 8)
- Options considered:
  - **A — Enumerate every gate** (coverage, tolerances, dual-pattern class IDs, error-class-auditor, NAMESPACE, call-site audit, devtools::check, changelog).
  - **B — Rely on project-wide defaults.**
- **Decision:** A.
- **Rationale:** The project has standardized gates; hard-coding them into the plan prevents r-implement (or auto-ship) from skipping any during execution.

**Q: Split `R/glm-anova.R` or keep one file?** (Issue 9)
- Options considered:
  - **A — Keep as-is** (single file).
  - **B — Split dispatch into `R/glm-anova-dispatch.R`**; kernel stays in `R/glm-anova.R`.
- **Decision:** B.
- **Rationale:** User preference (overriding reviewer recommendation). Keeps `R/glm-anova.R` focused on the kernel; new dispatch logic lives in a sibling file with a matching `tests/testthat/test-glm-anova-dispatch.R` per the one-to-one source-to-test convention.

**Q: Delete no-op Task 1.0?** (Issue 10)
- **Decision:** Yes. Moved precondition note into plan preamble.
- **Rationale:** Ambiguous "done" state is hostile to r-implement.

**Q: Relabel TDD cycles A → B → D?** (Issue 11)
- **Decision:** Relabel to A → B → C.
- **Rationale:** Typo/gap; no substantive content change.

**Q: Order of `null` type-check vs. list-mode warning?** (Issue 12)
- Options considered:
  - **A — Type-check first:** non-numeric `null` always errors.
  - **B — Warn-and-drop first:** list-mode bypasses type check.
- **Decision:** A.
- **Rationale:** A typoed `null = "foo"` is a contract violation; the user should see the type error, not a silently-dropped warning that hides their mistake.

### Outcome

Plan `plans/impl-get-anova-polymorphic.md` is approved for implementation.
Key amendments: `anova.survey_glm_fit()` delegator brought in scope
(Task 3.3); new error class `surveycore_error_anova_formula_unexpected`
added; `survey_collection` pre-check added to dispatch; length-≥3 lists
chained per `stats::anova()`; explicit Acceptance Criteria section added;
dispatch split into `R/glm-anova-dispatch.R` + companion test file.

---
