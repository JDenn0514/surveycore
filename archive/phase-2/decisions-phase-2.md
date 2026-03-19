# Claude Decisions Log — surveycore Phase 2

This file records planning decisions made during implementation of Phase 2.
Each entry corresponds to one planning session.

---

## 2026-03-07 — Methodology lock: GLM variance, residuals, degrees of freedom

### Context

Stage 2 Resolve worked through 16 issues from the adversarial methodology
review of spec v0.8. 11 issues had one mathematically correct answer (applied
as a batch without discussion). 5 required judgment calls resolved in this
session.

### Questions & Decisions

**Q: BLOCKING-2 — SRS variance formula `σ̂² (X'WX)⁻¹` is wrong for
non-Gaussian families. Which fix?**
- Options considered:
  - **[A] Unified score-based path:** Remove analytic formula; use score-based
    sandwich for all families — `.glm_score()` → SRS variance of score total
    (`N²(1-f)/n · S²_u`) → `bread · meat · bread`.
  - **[B] Gaussian analytic + score-based fallback:** Keep analytic formula for
    Gaussian; add score-based branch for all other families.
- **Decision:** Option A — unified score-based path for all families.
- **Rationale:** Single code path, correct for all 8 families, no family
  dispatch inside the SRS variance function. Analytic formula is equivalent for
  Gaussian but adds no benefit given the unified path.

---

**Q: BLOCKING-4 — `residuals(type = "response")` needs original response `y`,
not stored in the S7 object. Where does `y` come from?**
- Options considered:
  - **[A] Require `@fit_`:** Extract via `model.response(model.frame(fit_))`;
    error with `surveycore_error_predict_no_fit` if `fit_` is NULL.
  - **[B] Store `@response` property:** New property populated at construction.
    Available even after `fit_` is stripped.
- **Decision:** Option A — require `@fit_` for `type = "response"`.
- **Rationale:** Consistent with existing `@fit_` requirement for `"pearson"`,
  `"deviance"`, and `"partial"`. Adding `"response"` is a small extension of an
  established pattern. Tradeoff (unavailable post-serialization without `fit_`)
  is acceptable since the same limitation already applies to four other types.

---

**Q: REQUIRED-5 — `@df_null` computation unspecified. Classical `n - 1` or
design-based `degf(design)`?**
- Options considered:
  - **[A] Classical `fit$df.null`:** Store `n - 1` from `stats::glm()`. Remove
    `"(design-based)"` label from null deviance line. Matches `survey::svyglm()`.
  - **[B] Design-based `degf(design)`:** For NHANES: ~17 instead of 199.
- **Decision:** Option A — classical `fit$df.null`.
- **Rationale:** Matches `survey::svyglm()` and base `summary.glm()` output.
  The `"(design-based)"` label in the v0.8 example was inconsistent with 199
  (clearly `n - 1` for 200 rows). Design-based inference is shown separately
  in the Design df line; the deviance block is a descriptive goodness-of-fit
  display.

---

**Q: REQUIRED-12 — `@df_residual` is used for deviance display (classical `n - p`)
and t-tests (design-based `degf - (p-1)`) — two incompatible values. How to resolve?**
- Options considered:
  - **[A] Classical storage + inline design-based:** `@df_residual` stores
    `fit$df.residual` (classical `n - p`) for deviance display. Design-based
    `degf(design) - (p - 1)` computed inline in `confint()`, `clean()`, and
    `summary()` from `model@degf`. No new property.
  - **[B] Design-based storage + classical property:** `@df_residual` stores
    design-based value; add `@df_residual_classical` for deviance line.
- **Decision:** Option A — classical `@df_residual` + inline design-based.
- **Rationale:** Matches `survey::svyglm()` exactly. Avoids a second property
  whose only use is one summary line. Design-based df is derivable from
  `model@degf` (stored) and `p` (from `length(model@coefficients)`), so no
  information is lost.

---

**Q: ADVISORY-14 — `@vcov` not validated as PSD; non-PSD produces silent NaN SEs.
Add check where?**
- Options considered:
  - **[A] Quality gate only:** Add PSD assertion to Section XI; verify against
    all oracle fits. No overhead on construction.
  - **[B] S7 validator:** `all(eigen(self@vcov)$values >= -1e-10)` runs on
    every `survey_glm_fit` construction.
  - **[C] Do nothing.**
- **Decision:** Option A — quality gate only.
- **Rationale:** Running `eigen()` on every GLM fit adds overhead with no
  benefit for well-behaved designs (99%+ of use cases). Quality gate catches
  implementation bugs without penalizing normal usage.

### Outcome

Spec updated to v0.9, methodology-locked. Key changes: Section 8.2 bread
corrected to `summary(fit)$cov.unscaled`; Section 8.4 SRS formula replaced
with unified score-based path; Section 5.2 deviance residuals use
`residuals(fit_, type="deviance")`; Section 5.7 `"response"` type requires
`@fit_`; `@df_null`/`@df_residual` property types changed to `S7::class_numeric`;
classical/design-based df split documented in Section 8.5; `confint()` and
`clean()` CI formulas updated to use `model@degf - (p-1)` inline; new error
class `surveycore_error_cbind_response_unsupported` added.

---

## 2026-02-27 — Stage 3 spec resolution (Issues 43–46)

### Context

Second batch of the third review pass. Issues 43–46: one REQUIRED (zero-weight
rows), one REQUIRED (wrong quality gate key name), and two SUGGESTIONS (both
accepted as do-nothing).

### Questions & Decisions

**Q: How should `survey_glm()` handle zero or negative weights? (Issue 43)**
- Options considered:
  - **[A] Warn with `surveycore_warning_nonpositive_weights`** and proceed —
    matches base R `glm()` behavior; preserves zero-weight-as-exclusion pattern.
  - **[B] Error** — breaks intentional zero-weight exclusion workflows.
  - **[C] Document as pre-condition violation** — silent behavior.
- **Decision:** Option A — warn and proceed.
- **Rationale:** Zero-weight rows as soft exclusion is a valid workflow pattern.
  Warning is more informative than silence and less disruptive than an error.
  P2-19 added to Section X; check added to Section 4.4 Step 3.

**Q: Fix quality gate `$variable_labels` → `$variables`? (Issue 44)**
- **Decision:** Yes — quality gate updated to "`meta(clean(fit))$variables`
  populated with one named entry per predictor; each entry has `var_label`,
  `var_class`, `var_type`, and optionally populated `value_labels`."
- **Rationale:** `$variable_labels` does not exist in `survey_glm_tidy` `.meta`
  per Section 6.3. Confirmed by reviewing the full `meta()` output.

**Q: Specify `confint()` behavior for invalid `parm`? (Issue 45)**
- **Decision:** Do nothing — standard R delegation behavior applies.
- **Rationale:** Over-specifying a SUGGESTION-level gap.

**Q: Specify ordered factor `^N` suffix stripping? (Issue 46)**
- **Decision:** Do nothing — rare edge case; acceptable for a SUGGESTION.

### Outcome

Spec updated to v0.8: `surveycore_warning_nonpositive_weights` (P2-19) added
to Section 4.4 Step 3 and Section X; quality gate corrected to `$variables`.
Issues 45 and 46 closed as do-nothing. All 46 review issues are now resolved.

---

## 2026-02-27 — Stage 3 spec resolution (Issues 39–42)

### Context

Working through a third review pass (Issues 39–46). First batch covered
Issues 39–42: one BLOCKING (missing test plan for 12 expanded S3 methods),
one REQUIRED subsumed by that fix, and two REQUIRED issues (print format,
label-stripping algorithm).

### Questions & Decisions

**Q: Should test plan items be added individually per method, or as a
catch-all? (Issue 39)**
- Options considered:
  - **[A] Individual items (17–36):** One happy-path block per method plus
    per-call-site NULL-`fit_` error blocks. Verbose but each item is
    independently verifiable against a quality gate.
  - **[B] Single catch-all item:** Faster to spec, ambiguous to implement.
- **Decision:** Option A — items 17–36 added to the `test-glm-methods.R`
  plan, covering `clean()`, `confint()`, `formula()`, `terms()`,
  `model.matrix()`, `model.frame()`, `deviance()`, `df.residual()`, `nobs()`,
  `hatvalues()`, `logLik()`, `AIC()/BIC()`, and `update()`.
- **Rationale:** Per engineering-preferences.md §2, individual items make
  coverage explicit and the quality gate verifiable.

**Q: How should `surveycore_error_predict_no_fit` be tested for the 6 additional
call sites? (Issue 40)**
- **Decision:** Subsumed by Issue 39[A] — items 22, 24, 26, 31, 33, 35 in
  the new test plan each cover a NULL-`fit_` block with the dual pattern. No
  separate action needed.

**Q: Should `print(clean(fit))` output be specified in Section 6.6 or inline in 6.3? (Issue 41)**
- Options considered:
  - **[A] New Section 6.6** documenting inheritance from `print.survey_result()`
    plus a verbatim console example.
  - **[B] Inline verbatim block** added to Section 6.3.
- **Decision:** Option A — Section 6.6 added. Explicitly states no
  `print.survey_glm_tidy()` is defined; uses Phase 1's `print.survey_result()`.
- **Rationale:** Keeps Section 6.3 focused on column contracts; print format
  belongs in its own subsection.

**Q: How should the `label` column recover factor level names from coefficient names? (Issue 42)**
- Options considered:
  - **[A] Model-frame lookup:** find `l` such that `paste0(var_name, l) == coef_name`
    from `levels(model_frame[[var_name]])`. Unambiguous; consistent with
    reference-level detection.
  - **[B] String prefix removal** (`sub()`): fragile when variable name is a
    prefix of the level name.
- **Decision:** Option A — model-frame lookup specified in Section 6.3.
- **Rationale:** The model frame is already required for reference-level
  detection; using it for non-reference levels is consistent and avoids the
  silent wrong-output edge case of string removal.

### Outcome

Spec updated to v0.7: Section 6.3 `label` column updated with model-frame
lookup algorithm; Section 6.6 added (print format + verbatim example);
test plan items 17–36 added to `test-glm-methods.R` plan (Section 9.2).
Issue 40 closed as subsumed.

---

---

## 2026-02-27 — marginaleffects extension interface added to Phase 2

### Context

Discussion about `get_diffs()` scope: whether to implement `avg_slopes()` and
`avg_predictions()` functionality natively inside surveycore (porting marginaleffects
code), or to use marginaleffects' extension interface. Two questions were resolved:
where the extension interface belongs in the phase plan, and where `get_diffs()`
belongs.

### Questions & Decisions

**Q: Should Phase 2 implement the marginaleffects extension interface, or defer it?**

- Options considered:
  - **[A] Add to Phase 2** — these are S3 methods *on the model class*, analogous
    to `tidy()` and `print()`. They complete the class API.
  - **[B] Defer to Phase 3** — group them with `get_diffs()` as an "analysis layer."
  - **[C] Reimplement `avg_slopes()`/`avg_predictions()` natively** — port
    marginaleffects logic without importing the package.

- **Decision:** Option A — add to Phase 2.

- **Rationale:** The extension interface (`get_coef`, `set_coef`, `get_vcov`,
  `get_predict`) is a set of S3 methods *on the `survey_glm_fit` class*. Like
  `tidy()` and `print()`, they define how the class integrates with the ecosystem;
  they belong with the class, not with downstream analysis functions. Shipping Phase
  2 without them would mean the class doesn't work with marginaleffects — a missing
  integration that would need patching immediately.

  Option C was evaluated and rejected: implementing full marginaleffects
  functionality natively (covering interaction terms, non-linear transformations,
  arbitrary link functions, multi-level factors, delta method SEs for all cases)
  is equivalent to reimplementing a ~15,000-line package. The extension interface
  achieves the same outcome in ~100 lines by delegating to a well-tested
  implementation. The only non-trivial piece is `set_coef` (patching both `@coefficients`
  and the internal `fit_$coefficients` so `stats::predict.glm()` uses the perturbed
  coefficients during delta method gradient computation).

**Q: Should `get_diffs()` go in Phase 2 or Phase 3?**

- **Decision:** Phase 3 — separate phase.

- **Rationale:** `get_diffs()` is a user-facing analysis function, analogous to
  `get_means()` and `get_freqs()`. It uses GLM machinery but is conceptually an
  analysis layer, not class infrastructure. This mirrors the existing Phase 0/1
  pattern: the class was built in Phase 0, then analysis functions were built on
  top in Phase 1. Same split applies here.

**Q: Should `marginaleffects` be `Imports` or `Suggests`?**

- **Decision:** `Suggests`.

- **Rationale:** The extension methods are registered only when marginaleffects is
  installed. All core `survey_glm_fit` functionality is usable without it. Making it
  `Suggests` avoids a hard dependency while still providing first-class marginaleffects
  integration for users who have it. Follows the same pattern as `broom` in Phase 2
  and `survey` in all phases.

### Outcome

Spec updated to v0.5: new Section VII added (marginaleffects extension interface,
7 subsections); old Sections VII–XI renumbered to VIII–XII; scope table updated;
file organization updated (`R/14-glm-marginaleffects.R`,
`tests/testthat/test-glm-marginaleffects.R`); quality gates and integration
contract updated; `get_diffs()` cross-reference updated to "Phase 3 spec."

---

## 2026-02-27 — Round 2 spec review resolution (Issues 31–38)

### Context

Working through the Round 2 adversarial review (`plans/spec-review-phase-2.md`)
of the v0.3 spec. Seven new issues found; all resolved in this session except
Issue 36 (binomial oracle GLM family list — pending clarification on one family
name before the edit is finalized).

### Questions & Decisions

**Q: Issue 31 — Add 13 expanded S3 methods to spec or defer to Phase 2.5?**
- Options considered:
  - **[A]** Add all 13 to Section V now, with full contracts.
  - **[B]** Defer to Phase 2.5, narrow Phase 2 back to original 7 methods.
- **Decision:** Option A — add all 13 to the spec.
- **Rationale:** The decisions were already made and recorded in the 2026-02-26 log entry. The spec just hadn't caught up. The delegation methods are trivial to spec; `confint()` and `update()` warranted real subsections.

**Q: Issue 35 — How should `survey_glm()` handle an empty domain?**
- Options considered:
  - **[A]** Error with `surveycore_error_empty_domain` before calling `stats::glm()`.
  - **[B]** Let `stats::glm()` fail naturally with a cryptic base R error.
- **Decision:** Option A — explicit typed error.
- **Rationale:** Consistent with Phase 1's defensive handling of degenerate inputs. A typed error lets users catch it programmatically.

**Q: Issue 36 — Binomial oracle test template: which additional families to include?**
- User specified all 8 standard GLM families: `gaussian(link = "identity")`,
  `binomial(link = "logit")`, `Gamma(link = "inverse")`,
  `inverse.gaussian(link = "1/mu^2")`, `poisson(link = "log")`,
  `quasi(link = "identity", variance = "constant")`,
  `quasibinomial(link = "logit")`, `quasipoisson(link = "log")`.
- All are supported by `survey::svyglm()`.
- **Decision:** All 8 families get oracle tests in `test-glm-numerical.R`.
  Binomial and Poisson get full templates in Section 8.1; Gamma, inverse.gaussian,
  quasi, and quasibinomial reference the binomial template pattern.
- **Key note captured in spec:** For binomial oracle tests, `survey::svyglm()`
  is called with `quasibinomial()` to suppress the non-integer weights warning.
  The Binder sandwich is invariant to the dispersion parameter so SEs match.

### Outcome

Spec updated to v0.3.1: Section I scope table updated to 20 S3 methods;
Sections 5.8–5.19 added; `"partial"` residual type added to Section 5.7;
test items 11–16 added to `test-glm-methods.R` plan; `surveycore_error_empty_domain`
added to Section 4.5, 4.7, and IX; stale GAP note in Section 6.3 replaced with
forward reference to Section 8.3; stale footer replaced with approved status note.

---

## 2026-02-26 — snake_case arguments on all S3 methods; expanded method set

### Context

Discussion of method parity with `survey::svyglm()`. Two decisions made:

**1. Explicit snake_case arguments on `predict()`**

`predict.survey_glm_fit` uses snake_case argument names throughout:
- `newdata` → `new_data`
- `se.fit` → `se_fit` (explicitly named, not available via `...` passthrough)
- `na.action` → `na_action`

`se_fit = TRUE` returns a named list with components `$fit`, `$se_fit`,
`$residual_scale` — renaming base R's `$se.fit` and `$residual.scale` to match
surveycore conventions. The implementation delegates to `stats::predict()` and
renames the list components before returning.

This applies to all S3 methods on `survey_glm_fit`: all argument names use
snake_case. Where base R uses dot-separated names (e.g., `na.action`), the
surveycore method uses underscores.

**2. Expanded method set to match `svyglm` (where appropriate)**

Methods to add in Phase 2 (beyond what the original spec listed):
- `confint()` — design-based CIs using `@vcov` and `@df_residual`
- `residuals("partial")` — delegate to `residuals(object@fit_, type = "partial")`
- `formula()` — return `object@formula`
- `terms()` — delegate to `terms(object@fit_)`
- `model.matrix()` — delegate to `model.matrix(object@fit_)`
- `model.frame()` — delegate to `model.frame(object@fit_)`
- `deviance()` — return `object@deviance`
- `df.residual()` — return `object@df_residual`
- `nobs()` — return `length(object@fitted_values)`
- `hatvalues()` — delegate to `hatvalues(object@fit_)` (model-based)
- `logLik()` — delegate to `logLik(object@fit_)` (model-based; note in docs)
- `AIC()` / `BIC()` — delegate to `AIC(object@fit_)` / `BIC(object@fit_)` (model-based)
- `update()` — requires `getCall.survey_glm_fit` returning `object@call`

**Deferred (not Phase 2):**
- `anova()` — requires Wald F-test machinery (non-trivial); Phase 3+

**Explicitly excluded:**
- `influence()`, `cooks.distance()`, `rstandard()`, `rstudent()` — silently
  wrong for survey designs (assume iid); `svyglm` only has them by inheritance
  accident. Not adding them.

---

## 2026-02-26 — print vs. summary output split

### Context

Discussion of `print.survey_glm_fit` vs `summary.survey_glm_fit` output revealed
a design tension: the original spec had `print()` showing the full inference
table (Estimate, Std. Error, t value, Pr(>|t|)), leaving `summary()` to add
only the deviance block. This gave users little reason to call `summary()` and
deviated from base R conventions.

### Decision

**`print.survey_glm_fit`** follows `print.glm` — shows only the design header
(family, formula, design type) and the coefficient estimates as a named vector.
No SEs, no t-values, no p-values.

**`summary.survey_glm_fit`** is where the full inference table lives:
coefficient estimates + Std. Error + t value + Pr(>|t|) + significance stars,
plus the deviance residuals block, dispersion parameter, null/residual deviance,
AIC, and design df.

**Rationale:** Clean split. Users get quick estimates from `print()` and reach
for `summary()` when they want inference — exactly the R convention for `lm`
and `glm`. Spec updated in Section 5.1 and 5.2.

---

## 2026-02-25 — Stage 3 spec resolution (Issues 1–4)

### Context

Working through the adversarial review (`plans/spec-review-phase-2.md`) in
Stage 3. First batch covered Issues 1–4 from the review file.

### Questions & Decisions

**Q: What variance formula should `survey_glm()` use for `survey_nonprob` designs? (Issue 1)**
- Options considered:
  - **[A] SRS sandwich (conservative):** No calibration adjustment; same path as `survey_srs`. Matches Phase 1 precedent for means/totals on calibrated designs.
  - **[B] Explicit error (`surveycore_error_unsupported_design_class`):** Defer `survey_nonprob` support to Phase 3.
- **Decision:** Option A — SRS sandwich, conservative, no calibration adjustment.
- **Rationale:** User confirmed this matches `survey::svyglm()`'s behavior and is statistically correct. Consistent with the Phase 1 precedent already established for `survey_nonprob` means and totals.

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

Spec updated with: (1) explicit `survey_nonprob` SRS-sandwich contract,
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

## 2026-02-26 — Stage 3 spec resolution (Issue 30)

### Context

Final issue. Issue 30 was the last BLOCKING gap: how out-of-domain score
contributions are handled in the GLM sandwich estimator when the design has
an active domain from `surveytidy::filter()`.

### Questions & Decisions

**Q: How should out-of-domain observations contribute to the GLM score for variance estimation? (Issue 30)**
- Options considered:
  - **[A] Set out-of-domain scores to zero:** `u_i = w_i x_i e_i · I(i ∈ domain)`.
    Full-design variance of `Σ u_i` is then computed. Follows Phase 1 `.apply_domain()` precedent.
  - **[B] Do nothing** — implementer guesses; oracle test catches failures.
- **Decision:** Option A.
- **Rationale:** The math is standard for domain total estimation via Taylor linearization.
  The Phase 1 precedent (`.apply_domain()` multiplying by a domain indicator) applies directly.
  For replicate variance, the same indicator restricts refitting to in-domain rows.
  An oracle comparison against `survey::svyglm(..., subset=)` validates the implementation.

### Outcome

Section 4.5 GAP resolved: out-of-domain score formula specified as
`u_i = w_i x_i e_i · I(i ∈ domain)`. Zero-score mechanism described for
both Taylor and replicate paths. Section 8.2 item 10 upgraded to a full
oracle test (coefficients + SEs vs `survey::svyglm` subset).

---

## 2026-02-25 — Stage 3 spec resolution (Issues 25–28)

### Context

Seventh batch. Issues 25–28: two REQUIRED issues (oracle test coverage,
`.degf()` testing), one REQUIRED issue (untestable error class), and one
REQUIRED issue (error-messages.md sync).

### Questions & Decisions

**Q: Should oracle test templates be written for replicate/SRS/twophase/calibrated? (Issue 25)**
- Options considered:
  - **[A] Write full templates for each** — verbose but unambiguous.
  - **[B] State that other designs follow the Taylor pattern** — lean, sufficient.
- **Decision:** Option B, with `survey_nonprob` explicitly added to the oracle
  datasets table (user noted this design was missing entirely). Quality gate updated
  to include `survey_nonprob` alongside Taylor, replicate, SRS, and twophase.
  For `survey_nonprob`, the oracle uses synthetic data from `make_survey_data(seed = 42)`
  calibrated via `survey::calibrate()` then converted with `from_svydesign()`.
- **Rationale:** The Taylor template is a sufficient pattern reference; duplicating
  boilerplate for each design type adds noise. But `survey_nonprob` was entirely
  absent from the oracle table and quality gates — that gap is now closed.

**Q: Should `.degf()` accuracy be independently tested? (Issue 26)**
- **Decision:** Yes — add a test block to `test-glm-numerical.R` verifying
  `.degf(d_sc)` matches `survey::degf(d_sv)` for all five design classes.
- **Rationale:** Phase 2 adds new usage of `.degf()` for CI/t-test df computation;
  the replicate formula may need validation. An explicit oracle comparison guards
  against silent df errors propagating to CIs.

**Q: How should `surveycore_error_formula_missing` be made testable? (Issue 27)**
- Options considered:
  - **[A] `formula = NULL` default + explicit NULL check** — testable with dual pattern.
  - **[B] Remove the error class** — let base R's missing-argument error surface.
- **Decision:** Option A — `formula = NULL` default + explicit `is.null(formula)` check.
- **Rationale:** Consistent with Phase 1 pattern. Makes the error class testable
  with `expect_error(class=)` + `expect_snapshot(error=TRUE)`. Signature updated
  in Section 4.1; Step 1 updated in Section 4.4.

**Q: Were all Phase 2 error/warning classes added to `plans/error-messages.md`? (Issue 28)**
- **Decision:** Yes — rows 65–77 added covering all 13 new Phase 2 classes (not
  reuses). Coverage map updated with `test-glm.R` and `test-glm-methods.R`.
- **Rationale:** Section IX requires this before implementation begins.

### Outcome

Spec updated with: (1) `survey_nonprob` added to oracle datasets table and
quality gate; "follow Taylor pattern" note for other designs, (2) `.degf()` oracle
test described in Section 8.1, (3) `formula = NULL` + explicit NULL check in
Section 4.1/4.4, (4) `plans/error-messages.md` updated with rows 65–77.

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

## 2026-03-08 — Stage 4 resolve: Pass 4 issues (47–55)

### Context

Working through the 9 issues from the Pass 4 adversarial review of the v1.0
spec. Zero blocking issues; 6 REQUIRED and 3 SUGGESTION. All 9 resolutions
were chosen interactively with the user.

### Questions & Decisions

**Q: Issue 47 — Add `test_glm_fit_invariants()` helper for `survey_glm_fit`?**
- Options considered:
  - **Option A:** Add Section 9.3a with the helper (6 structural checks); require as first assertion in all `survey_glm()` happy-path test blocks.
  - **Option B:** Leave inline checks scattered across test blocks.
- **Decision:** Option A.
- **Rationale:** The `test_glm_tidy_invariants()` pattern was added for the same reason; `survey_glm_fit` deserves equivalent treatment. Consistent with `engineering-preferences.md §2`.

---

**Q: Issue 48 — `summary()` NULL-`fit_` gap: error table row + test item?**
- Options considered:
  - **Option A:** Add P2-14a to Section X error table; add test item 2a (renamed 2b after 52 was added) for the NULL path.
  - **Option B:** Extend P2-14 to list all call sites.
- **Decision:** Option A.
- **Rationale:** Per-method error table rows keep auditing clear.

---

**Q: Issue 49 — `confint()` error table: separate row vs. extend P2-13?**
- Options considered:
  - **Option A:** Add P2-13a for `confint.survey_glm_fit()`.
  - **Option B:** Extend P2-13 to list both `clean()` and `confint()`.
- **Decision:** Option A.
- **Rationale:** One row per function+condition pair; consistent with Issue 48 decision.

---

**Q: Issue 50 — Add explicit `predict(type = "link")` and `predict(type = "terms")` test items?**
- Options considered:
  - **Option A:** Add items 5a and 6a with explicit `type` tests.
  - **Option B:** Amend item 5 to broaden wording.
- **Decision:** Option A.
- **Rationale:** The `type = "link"` path is the exact fix from Issue 15 (Round 1); it must be explicitly tested to guard against silent regression.

---

**Q: Issue 51 — DRY: shared `.glm_confint()` helper vs. cross-reference note?**
- Options considered:
  - **Option A:** Add `.glm_confint()` to Section 2.2; both `confint()` and `clean()` call it.
  - **Option B:** Cross-reference note only.
  - **Option C:** Do nothing.
- **Decision:** Option A.
- **Rationale:** `engineering-preferences.md §1` (DRY, highest priority): duplicated CI formula is a bug waiting to happen. Shared helper makes the "must match" promise a structural guarantee.

---

**Q: Issue 52 — Add `print(summary(fit))` snapshot test?**
- Options considered:
  - **Option A:** Add test item 2a between items 2 and 2a (NULL-fit test).
  - **Option B:** Do nothing.
- **Decision:** Option A.
- **Rationale:** Three result classes (`survey_glm_fit`, `survey_glm_summary`, `survey_glm_tidy`) all have `print()` methods; all three require snapshot tests. Consistent with Lens 2 / testing-standards.md.

---

**Q: Issue 53 — Fix misleading `set_coef()` "bypasses validator" description?**
- Options considered:
  - **Option A:** Replace with accurate description.
  - **Option B:** Do nothing.
- **Decision:** Option A.
- **Rationale:** Prevents wasted investigation into S7 validator bypass mechanisms.

---

**Q: Issue 54 — Add `n_weighted` computation source?**
- Options considered:
  - **Option A:** Add exact derivation (`sum(model.frame(model@fit_)$"(weights)")`).
  - **Option B:** Do nothing.
- **Decision:** Option B.
- **Rationale:** Conceptual definition is clear enough. Acceptable implementation latitude.

---

**Q: Issue 55 — Add `lapply()` state leakage test item 7b?**
- Options considered:
  - **Option A:** Add numbered item 7b.
  - **Option B:** Do nothing.
- **Decision:** Option A.
- **Rationale:** State leakage across `lapply()` calls is a real risk when closures or global state are used; explicit test item makes the expectation concrete.

### Outcome

All 9 Pass 4 issues resolved. Spec updated to v1.1 with status "Approved —
all Stage 3 code/architecture issues resolved; ready for implementation plan."
Key changes: `test_glm_fit_invariants()` helper added (Section 9.3a); `.glm_confint()`
shared CI helper added (Section 2.2); error table extended with P2-13a and
P2-14a; test plan extended with items 2a, 2b, 5a, 6a, 7b.

---

## 2026-03-08 — Implementation plan Stage 3: resolve adversarial review issues

### Context

Stage 3 of the implementation workflow: working through the 9 issues (1 BLOCKING,
5 REQUIRED, 3 SUGGESTIONS) identified in the Stage 2 adversarial review of
`plans/impl-phase-2.md`.

### Questions & Decisions

**Q: Error class count was inconsistent — PR 1 said 20, Quality Gates said 16. Which is correct?**
- **Decision:** 20 (from spec §X), updated further to 21 after adding a new error class (see below).
- **Rationale:** Actual unique class count from spec §X is the authoritative source. "16" was stale.

**Q: `na.action = na.fail` — propagate base R error, or throw a custom surveycore error?**
- Options considered:
  - **Propagate base R:** Matches original spec. Base R message: `"missing values in object"` — uninformative.
  - **Custom `surveycore_error_na_in_data`:** Pre-check for NAs before calling `stats::glm()`; message lists offending columns and NA counts with a `"v"` bullet suggesting `na.omit`.
- **Decision:** Custom surveycore error (`surveycore_error_na_in_data`, now P2-21 in spec §X).
- **Rationale:** Base R's `na.fail()` message gives users no actionable information. The pre-check is straightforward (we know the model frame variables). Consistent with surveycore's approach of always providing typed, informative errors. Added to spec §X, spec §9.4, spec §XI quality gates, and both PR 1 and PR 2 acceptance criteria. Error count updated from 20 to 21.

**Q: `predict()` with missing `newdata` columns — custom surveycore error or base R propagation?**
- Options considered:
  - **Custom error:** Pre-check `newdata` columns against model terms. Non-trivial: must handle interactions, transformations, polynomials.
  - **Base R propagation:** `stats::predict.glm()` already says `"variable 'x2' was used in fitting but is not available in 'newdata'"` — informative.
- **Decision:** Keep base R propagation. Document in `@param newdata` roxygen. Test with `expect_error()` (no `class=`).
- **Rationale:** Unlike `na.fail`, base R's `predict()` error for missing columns is already informative. Adding a pre-check would require non-trivial term parsing (interactions, polys) for marginal UX improvement — over-engineered per engineering-preferences.md §3.

### Outcome

All 10 review issues resolved. Plan updated with: corrected error class counts (21 total),
new `surveycore_error_na_in_data` class (P2-21), PR 6 dependency on PR 5, `R/utils.R` added
to PR 2 Files, `predict()` missing-column test added to PR 3, `insufficient_df` warning test
added to PR 2, Poisson oracle template column name fixed (`weight` → `wt`), domain oracle
placement note added to PR 6, and §X reference disambiguated throughout.

---
