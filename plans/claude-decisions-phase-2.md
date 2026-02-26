# Claude Decisions Log — surveycore Phase 2

This file records planning decisions made during implementation of Phase 2.
Each entry corresponds to one planning session.

---

## 2026-02-25 — Stage 3 spec resolution (Issues 1–4)

### Context

Working through the adversarial review (`plans/spec-review-phase-2.md`) in
Stage 3. First batch covered Issues 1–4 from the review file.

### Questions & Decisions

**Q: What variance formula should `survey_glm()` use for `survey_calibrated` designs? (Issue 1)**
- Options considered:
  - **[A] SRS sandwich (conservative):** No calibration adjustment; same path as `survey_srs`. Matches Phase 1 precedent for means/totals on calibrated designs.
  - **[B] Explicit error (`surveycore_error_unsupported_design_class`):** Defer `survey_calibrated` support to Phase 3.
- **Decision:** Option A — SRS sandwich, conservative, no calibration adjustment.
- **Rationale:** User confirmed this matches `survey::svyglm()`'s behavior and is statistically correct. Consistent with the Phase 1 precedent already established for `survey_calibrated` means and totals.

**Q: Is Issue 2 (`survey_twophase` prerequisite) still applicable?**
- **Decision:** Closed as no-longer-applicable. Phase 0.75 is complete per CLAUDE.md. The spec's prerequisite table is correct as written.

**Q: How should Taylor variance pass-through work for GLM scores? (Issue 3)**
- Options considered:
  - **[A] New `.taylor_var_score_matrix(score_matrix, design)` wrapper** around `.svy_recvar()` that accepts a pre-computed `n × p` score matrix directly.
  - **[B] Call `.taylor_total()` p times** (once per coefficient column). Simple but hides the matrix structure.
- **Decision:** Option A — add `.taylor_var_score_matrix()` to Section 2.2.
- **Rationale:** The spec claims architectural reuse of Phase 0 machinery; it must name the specific function and document the expected input format. A dedicated wrapper makes the interface explicit and avoids p separate variance calls. `.svy_recvar()` accepts a matrix natively.

**Q: Is the `degf()` GAP note in Section 2.2 still valid? (Issue 4)**
- **Decision:** Remove the GAP — `.degf()` already exists in `R/09-analysis-helpers.R` (implemented in Phase 1, covers all 5 design classes). Update the Section X quality gate to reference the existing function rather than requiring a new implementation.

### Outcome

Spec updated with: (1) explicit `survey_calibrated` SRS-sandwich contract,
(2) `.taylor_var_score_matrix()` helper added to Section 2.2, (3) `.degf()`
GAP removed and quality gate corrected.

---

## 2026-02-25 — Stage 3 spec resolution (Issues 5–8)

### Context

Continuing the Stage 3 resolution pass. Second batch covered Issues 5–8:
two BLOCKING issues (math error, broken signature) and two REQUIRED issues
(residual type, dispatch mechanism).

### Questions & Decisions

**Q: Correct the SRS variance formula in Section 7.4? (Issue 5)**
- Options considered:
  - **[A] Fix to `σ̂² · (X'WX)⁻¹`** with a note deriving it from the general Binder sandwich.
  - **[B] Do nothing** — wrong formula gets coded.
- **Decision:** Option A.
- **Rationale:** The original `(X'WX)⁻¹ · σ̂² · (X'WX)` simplifies to `σ̂² · I`, which is plainly wrong. Trivial fix.

**Q: How to handle `control = list(...)` in the function signature? (Issue 6)**
- Options considered:
  - **[A] `control = list()`** — no variadic pass-through; explicit named args only.
  - **[B] Add standalone `...`** after `control` for forwarding to `stats::glm()`.
- **Decision:** Option A — `control = list()`, no `...`.
- **Rationale:** Survey GLM wrappers don't typically expose raw `stats::glm()` variadic forwarding. Keeping the contract explicit avoids the `R CMD check` warning and prevents users from passing undocumented args that may interact badly with survey weights.

**Q: Which residual type does `.glm_score()` use? (Issue 7)**
- **Decision:** `residuals(fit, type = "working")` — working residuals from the final IRLS step.
- **Rationale:** Binder (1983) sandwich requires working residuals. For non-Gaussian families (logistic, Poisson), this differs from Pearson/response residuals. Spec now states this explicitly.

**Q: Specify dispatch mechanism in Section 7.1? (Issue 8)**
- **Decision:** One sentence added: if/else chain with `S7::S7_inherits()`, following `R/06-variance-dispatch.R`.
- **Rationale:** Consistency with existing codebase pattern; prevents accidental use of S7 method dispatch which would require different registration.

### Outcome

Spec updated with: (1) corrected SRS formula, (2) clean `control = list()`
signature, (3) explicit working-residual extraction in `.glm_score()`,
(4) dispatch mechanism named in Section 7.1.

---

## 2026-02-25 — Stage 3 spec resolution (Issues 9–12)

### Context

Third batch. Issues 9–12: one suggestion (formula type constraint) and three
REQUIRED issues (vcov names, error class naming, NA weights).

### Questions & Decisions

**Q: Add type constraint for `formula` property in S7 validator? (Issue 9)**
- **Decision:** Yes — add `!is.null(self@formula) && !inherits(self@formula, "formula")` check to the S7 validator. `call` left untyped (language objects are harder to constrain in S7).
- **Rationale:** Catches construction errors before they produce cryptic downstream failures in `as.character(model@formula)`.

**Q: Where do `vcov` row/column names come from? (Issue 10)**
- **Decision:** Add to Section 4.4 Step 6: set `dimnames(vcov_matrix) <- list(names(coef(fit)), names(coef(fit)))` where `coef(fit)` is the `stats::glm()` result.
- **Rationale:** Makes the name-propagation path explicit; prevents a silent name-mismatch between `coef()` and `vcov()`.

**Q: Which error class for "design not a survey object" in `survey_glm()`? (Issue 11)**
- Options considered:
  - **`surveycore_error_not_survey_object`** — used in Phase 0 conversion methods.
  - **`surveycore_error_unsupported_class`** — canonical class in Phase 1 analysis helpers, thrown by `.check_unsupported_class()` already used by every analysis function.
- **Decision:** Use `surveycore_error_unsupported_class` via `.check_unsupported_class(design, "survey_glm")`, matching Phase 1's established pattern.
- **Rationale:** `survey_glm()` is an analysis function; it should follow the Phase 1 analysis-function pattern, not the Phase 0 conversion-method pattern. DRY.

**Q: How should NA weights be handled in `survey_glm()`? (Issue 12)**
- Options considered:
  - **[A] Error with `surveycore_error_na_weights`** before applying `na.action`.
  - **[B] Silently drop** rows with NA weights.
- **Decision:** Option A — explicit error.
- **Rationale:** Consistent with Phase 0/1 constructor validation. NA weights indicate a data problem the user should fix, not silently suppress. New class `surveycore_error_na_weights` added to Section 4.7 (row 11) and Section IX (P2-11).

### Outcome

Spec updated with: (1) `formula` type check in S7 validator, (2) explicit
`dimnames` assignment in Step 6, (3) `surveycore_error_unsupported_class` via
`.check_unsupported_class()` in Step 1, (4) NA weight pre-check in Step 3 with
new `surveycore_error_na_weights` class. Error table renumbered to 14 entries.

---
