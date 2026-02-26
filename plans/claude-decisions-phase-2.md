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

## 2026-02-25 — Stage 3 spec resolution (Issues 13–16)

### Context

Fourth batch. Issues 13–16: two REQUIRED issues (df floor, complex LHS) and
two REQUIRED issues (predict type, deviance residuals).

### Questions & Decisions

**Q: How should negative `df_residual` be handled? (Issue 13)**
- Options considered:
  - **[A] Warn + clamp to 1:** Conservative CIs; no `NaN`. Matches `survey::svyglm()`.
  - **[B] Error:** Force user to reduce predictors.
- **Decision:** Option A — warn with `surveycore_warning_insufficient_df`, clamp `df_residual = 1`. Added as P2-15.
- **Rationale:** Silent `NaN` is worse than conservative estimates; warning preserves usability.

**Q: How should response variable extraction handle in-formula transforms? (Issue 14)**
- **Decision:** Use `all.vars(formula[[2]])` to extract all variable names referenced in the LHS. Document `cbind()` LHS as unsupported (multinomial deferred).
- **Rationale:** `as.character(formula[[2]])` fails for `log(y) ~ x`; `all.vars()` is the standard R idiom for extracting variable names from expressions.

**Q: Should `predict(newdata = NULL, type = "link")` respect `type`? (Issue 15)**
- **Decision:** Yes — delegate to `stats::predict(object@fit_, type = type)` for both `newdata = NULL` and `newdata` cases. `object@fitted_values` shortcut removed.
- **Rationale:** Matches base R behavior; `type = "link"` must return link-scale values.

**Q: Should `residuals(type = "deviance")` be supported? (Issue 16)**
- **Decision:** Yes — add `"deviance"` to the residuals table, delegating to `residuals(object@fit_, type = "deviance")`. GAP note removed.
- **Rationale:** Trivially available from `object@fit_`; standard residual type users expect.

### Outcome

Spec updated with: (1) `df_residual` floor rule + P2-15, (2) `all.vars()`
response extraction with `cbind()` documented as unsupported, (3) `predict()`
always delegates to `stats::predict()` respecting `type`, (4) deviance
residuals added to Section 5.7.

---

## 2026-02-25 — Stage 3 spec resolution (Issues 17–20)

### Context

Fifth batch. Issues 17–20: one BLOCKING (survey_glm_summary undefined),
two REQUIRED (term format, n_observations), one REQUIRED with user correction
(variable_labels fallback).

### Questions & Decisions

**Q: Specify `survey_glm_summary` class structure? (Issue 17)**
- **Decision:** Option A — added Section 5.2.1 with a 10-field table and `print.survey_glm_summary()` output format. Fields: `coefficients`, `deviance`, `null_deviance`, `df_residual`, `df_null`, `dispersion`, `family`, `call`, `design_type`, `degf`.
- **Rationale:** Last blocking gap; implementer cannot write `summary()` or its tests without this.

**Q: Exact algorithm for reference row `term` column? (Issue 18)**
- **Decision:** `paste0(var_name, ref_level, " [ref]")` where `ref_level = setdiff(levels(col), colnames(contrasts(col)))`. Worked example with `employment_status` factor added.
- **Rationale:** Follows R's factor dummy coding convention exactly; algorithm is deterministic and testable.

**Q: What does `n_observations` count after domain + na.action? (Issue 19)**
- **Decision:** `nrow(model.matrix(fit))` — after both domain filtering and `na.action`.
- **Rationale:** This is the actual GLM input size, unambiguous and directly readable from the fitted model.

**Q: What is `variable_labels` when no labels are set? (Issue 20)**
- Options considered:
  - **[A] Named list with `NULL` values:** `list(x1 = NULL, x2 = NULL)`
  - **[User direction] Named list with variable name as value:** `list(x1 = "x1", x2 = "x2")`
- **Decision:** User-specified: values fall back to the variable name string itself. Never `NULL` for any entry.
- **Rationale:** Provides a usable display label even when no metadata is set; avoids NULL-checking downstream.

### Outcome

Spec updated with: (1) full `survey_glm_summary` structure + print format,
(2) explicit reference-term algorithm with worked example, (3) `n_observations`
defined as `nrow(model.matrix(fit))`, (4) `variable_labels` always a named
list of character strings (falls back to variable name).

---

## 2026-02-25 — Stage 3 spec resolution (Issues 21–24)

### Context

Sixth batch. Issues 21–24: one SUGGESTION (family extraction) and three
REQUIRED issues (degf domain behavior, validator tests, dual test pattern).

### Questions & Decisions

**Q: How is family name extracted for `.build_glm_meta()`? (Issue 21)**
- **Decision:** `model@family$family` for family name, `model@family$link` for link name. These fields exist on every R family object — confirmed for gaussian, binomial, Poisson, Gamma, and all other families accepted by `stats::glm()`.
- **Rationale:** Explicit extraction path avoids implementer guessing `class(model@family)` (returns `"function"`) or similar wrong approaches.

**Q: Does `degf()` use full design or in-domain rows when domain is active? (Issue 22)**
- **Decision:** Full design always — consistent with the domain estimation contract in Section 4.5.
- **Rationale:** Design-based inference uses full-design variance; domain membership affects fitting only, not the variance frame.

**Q: Add S7 validator error tests to test plan? (Issue 23)**
- **Decision:** Yes — item 11 added to `test-glm.R` covering all 7 validator conditions with `class=` only (no snapshot), per Layer 1 pattern.
- **Rationale:** 98%+ coverage requirement; validator branches are non-trivial and must be explicitly tested.

**Q: Clarify dual error-test pattern in test plan? (Issue 24)**
- **Decision:** Item 7 updated to spell out: Layer 3 (constructor) errors use dual pattern; Layer 1 (S7 validator) errors use `class=` only. `testing-surveycore.md` cited.
- **Rationale:** Removes ambiguity; prevents implementer from writing only one assertion for constructor errors.

### Outcome

Spec updated with: (1) explicit `$family`/`$link` extraction note covering all
families, (2) degf full-design-always rule at top of Section 7.5, (3) test
plan item 11 for validator errors, (4) item 7 updated with dual pattern + layer
distinction.

---
