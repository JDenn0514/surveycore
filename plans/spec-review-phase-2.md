# Spec Review: Phase 2 — Survey GLM: Weighted Regression

**Reviewer:** Claude (adversarial batch pass)
**Date:** 2026-02-25
**Spec file:** `plans/phase-2-glm-formal-specification.md`
**Codebase snapshot:** `feature/phase1-freqs` (post Phase 1 merge)

---

## Section I: Scope

**Issue 1: `survey_calibrated` GLM variance completely unspecified**
Severity: BLOCKING
Violates engineering-preferences.md §4 (handle edge cases explicitly)

The spec flags this as a GAP in Section I: "The behavior of `survey_glm()` with `survey_calibrated` designs is not fully specified." But this gap is never resolved — it appears only as a warning note. The testing section (Section VIII) has no oracle dataset for `survey_calibrated`. The dispatch in Section 7.1 says it "falls back to SRS sandwich (conservative)" but this is a one-line architectural note, not a contract.

If a user passes a `survey_calibrated` design to `survey_glm()`, the implementation must make a choice — but the spec gives no guidance on what that choice should be.

Options:
- **[A]** Specify `survey_calibrated` as "uses SRS sandwich formula; no calibration adjustment; conservative" — add it to Section 7 with the SRS formula and a test using synthetic calibrated data. Effort: low, Risk: low, Impact: removes a blocking gap.
- **[B]** Raise `surveycore_error_unsupported_design_class` for `survey_calibrated` in `survey_glm()` with a clear message and no fallback. Defer support to Phase 3. Effort: low, Risk: low, Impact: explicit failure mode.
- **[C] Do nothing** — implementer must guess; no oracle test can be written.

**Recommendation: [A]** — The SRS sandwich for calibrated designs is the same choice Phase 1 makes. Document it explicitly and add a test.

---

**Issue 2: `survey_twophase` depends on Phase 0.75 which is still in-progress**
Severity: REQUIRED
Violates contract completeness (Section I states the prerequisite).

CLAUDE.md reports: "Phase 0.75 — In progress." The spec lists Phase 0.75 as a prerequisite but provides no fallback if it isn't complete. The quality gates (Section X) require SE oracle tests for twophase designs. If Phase 0.75 isn't merged before Phase 2 begins, the `survey_twophase` support in Phase 2 is unimplementable.

Options:
- **[A]** Explicitly state that `survey_twophase` support is contingent on Phase 0.75 completion; if not complete, `survey_glm()` should raise `surveycore_error_unsupported_design_class` for `survey_twophase` designs. Remove twophase oracle test from Phase 2 quality gates; move to Phase 2.5. Effort: low, Risk: low, Impact: clear dependency management.
- **[B]** Defer all of Phase 2 until Phase 0.75 is complete. No fallback needed. Effort: none now, Risk: blocks Phase 2 start.
- **[C] Do nothing** — Phase 0.75 will presumably be done first; no change needed.

**Recommendation: [A]** — Sequencing ambiguity should be resolved in the spec, not left to scheduling.

---

## Section II: Architecture

**Issue 3: Taylor variance pass-through is architecturally underspecified**
Severity: BLOCKING
Violates Lens 3 (contract completeness — behavior not defined at boundaries).

Section 7.2 says: "The implementation passes the `n × p` score matrix to the existing Taylor variance function as if computing `p` weighted totals simultaneously."

Codebase exploration reveals:
- The public-facing `R/06-variance-taylor.R` functions (`.taylor_mean()`, `.taylor_total()`) each take a single `y_col` string — NOT a matrix.
- The internal vendored `.svy_recvar()` function DOES accept a matrix — but it expects pre-weighted, pre-centered scores: `x_centered * w / psum`.
- For GLM sandwich, the scores `u_i = w_i x_i e_i` are already weighted. The "centering" step for a total (vs. a mean) is different from what `.taylor_mean()` applies.

The spec says "reuse Phase 0 machinery" but the Phase 0 machinery's public interface doesn't accept pre-computed score matrices. The spec must specify:
1. Which function is called — `.svy_recvar()` directly, or a new wrapper?
2. Whether a new `p`-total Taylor helper is written, or `.taylor_total()` is called `p` times.
3. What scaling/centering is applied to GLM scores before passing to `.svy_recvar()`.

Options:
- **[A]** Add a `.taylor_var_score_matrix(score_matrix, design)` internal helper to Section 2.2 that wraps `.svy_recvar()` for pre-computed scores, documenting the required format (scores must be the final weighted deviations, as in `u_i - ū_h` within each stratum). Effort: medium, Risk: medium, Impact: eliminates a blocking ambiguity.
- **[B]** Specify calling `.taylor_total()` once per coefficient column — simple but `p` separate calls. Effort: low, Risk: low, Impact: avoids the matrix interface question; slightly less efficient.
- **[C] Do nothing** — implementer must reverse-engineer the internal interface.

**Recommendation: [A]** — The spec claims architectural reuse; it must specify how that reuse works at the interface level.

---

**Issue 4: `degf()` GAP is outdated — `.degf()` already exists**
Severity: REQUIRED
Factual error in the spec.

Section 2.2 states: "`degf()` is not yet an exported surveycore function. It exists in the `survey` package as `survey::degf()`." This is incorrect. Codebase exploration confirms `.degf()` exists in `R/09-analysis-helpers.R` (Phase 1), with dispatch for all five design classes:

```r
.degf <- function(design) {
  if (S7::S7_inherits(design, survey_taylor))   .degf_taylor(design@data, design@variables)
  else if (S7::S7_inherits(design, survey_replicate)) length(design@variables$repweights) - 1L
  else if (S7::S7_inherits(design, survey_twophase))  .degf_taylor(design@data, design@variables$phase1)
  else if (S7::S7_inherits(design, survey_srs))       nrow(design@data) - 1L
  else if (S7::S7_inherits(design, survey_calibrated)) nrow(design@data) - 1L
}
```

The spec's recommendation to "Add a `degf()` function to `R/07-utils.R` as part of Phase 2" is unnecessary — `.degf()` already covers all five design classes. Additionally, the replicate formula `length(design@variables$repweights) - 1L` is for BRR-style R replicates; this may or may not be correct for JK1 (which uses `R - 1`) vs. Fay vs. bootstrap — this should be verified against Phase 0's replicate design.

The spec's Section 7.5 table is also inconsistent with the existing implementation:
- Spec: `survey_replicate` → "Derived from replicate type (see `survey::degf()`)"
- Codebase: `length(design@variables$repweights) - 1L`

Options:
- **[A]** Remove the GAP note and the recommendation to implement `degf()`. Update Section 2.2 and Section 7.5 to reference `.degf()` in `R/09-analysis-helpers.R`. Verify the replicate formula covers all replicate types. Effort: low, Risk: low, Impact: fixes a factual error and avoids duplicate code.
- **[B] Do nothing** — a second `degf()` is written, duplicating the existing one.

**Recommendation: [A]** — Use the existing function; remove the GAP note.

---

**Issue 5: SRS variance formula is mathematically wrong**
Severity: BLOCKING
Plain mathematical error.

Section 7.4 states:

```
Var(β̂) = (X'WX)⁻¹ · σ̂² · (X'WX)
```

This formula is incorrect. `(X'WX)⁻¹ · σ̂² · (X'WX)` = `σ̂² · I` (the identity matrix scaled by σ̂²), which is wrong for any non-trivial model. The correct formula for the weighted OLS variance in the SRS case is:

```
Var(β̂) = σ̂² · (X'WX)⁻¹
```

where σ̂² is the survey-weighted mean squared residual. The formula in the spec appears to have been written as a partial sandwich `A⁻¹ B A⁻¹` where B was meant to be `σ̂² (X'WX)`, resulting in the incorrect expanded form.

If the intent was to write the Binder sandwich for SRS (which reduces to `σ̂² (X'WX)⁻¹` in the homoskedastic case), the spec should state that and derive it from the general sandwich.

Options:
- **[A]** Correct the formula to `Var(β̂) = σ̂² · (X'WX)⁻¹` and note this follows from the general Binder sandwich when `Var_design(T) = σ̂² (X'WX)` for iid SRS observations. Effort: trivial, Risk: none, Impact: removes a mathematical error before it's coded wrong.
- **[B] Do nothing** — implementer codes the wrong variance, oracle tests catch it.

**Recommendation: [A]** — Fix before implementation.

---

**Issue 6: `control = list(...)` swallows `...`, leaving no variadic pass-through**
Severity: BLOCKING
Violates code-style.md §4 (argument order and function design).

Section 4.1 signature:

```r
survey_glm <- function(
  design, formula, family = gaussian(), na.action = na.omit,
  start = NULL, etastart = NULL, mustart = NULL,
  control = list(...)
)
```

`control = list(...)` captures `...` inside the default expression, so the function has no standalone `...` argument. This means:
1. Users cannot pass additional arguments through to `stats::glm()` beyond those explicitly named.
2. There is no mechanism to forward unknown arguments.
3. `R CMD check` will warn about `...` used in default expression.

The intended design seems to be: extra arguments go into `control`, which is passed to `stats::glm.control()`. But the standard R pattern is `control = glm.control(...)`, not `control = list(...)`.

Options:
- **[A]** Change the signature to add a standalone `...` after `control`, or use `control = list()` with no `...` capture in the default. If variadic pass-through isn't needed, remove `...` entirely and make the contract explicit. Effort: trivial, Risk: low, Impact: clean function signature.
- **[B]** Use `control = glm.control(...)` as the default — this is the pattern `stats::glm()` uses. Effort: trivial, Risk: low.
- **[C] Do nothing** — code fails `R CMD check`.

**Recommendation: [A]** — Remove `...` from the default expression; use `control = list()` or add `...` as a standalone argument after `control`.

---

**Issue 7: `.glm_score()` residual type not specified**
Severity: REQUIRED
Leaves implementer to guess for non-Gaussian families.

Section 2.2 says the score is `u_i = w_i * x_i * e_i` where `e_i` is the "working residual." For Gaussian/identity, working = Pearson = response residuals. For logistic, Poisson, etc., they differ. The Binder (1983) sandwich for GLMs requires the working residuals from the IRLS iterations (`residuals(fit, type = "working")`), not Pearson or response residuals. This distinction is critical for non-Gaussian families.

The spec should explicitly state `e_i = residuals(fit, type = "working")`.

Options:
- **[A]** Add to Section 2.2: "Working residuals are `residuals(fit, type = 'working')` — the residuals from the final IRLS step. For Gaussian/identity this equals Pearson and response residuals; for other families it does not." Effort: trivial, Risk: none.
- **[B] Do nothing** — implementer may use the wrong residual type for binomial/Poisson, causing oracle test failures.

**Recommendation: [A]**

---

**Issue 8: Variance dispatch mechanism not specified**
Severity: REQUIRED
Inconsistency with codebase patterns.

Section 7.1 says "dispatch to the appropriate variance method based on design class" without specifying the mechanism. The codebase uses an if/else chain with `S7::S7_inherits()` (confirmed in `R/06-variance-dispatch.R`). The spec should state this explicitly so Phase 2 follows the same pattern rather than implementing S7 method dispatch or a switch.

Options:
- **[A]** Add to Section 7.1: "Dispatch uses an if/else chain with `S7::S7_inherits()`, following the pattern in `R/06-variance-dispatch.R`." Effort: trivial, Risk: none.
- **[B] Do nothing** — implementer will likely follow the existing pattern anyway.

**Recommendation: [A]** — Spec should be explicit about codebase patterns.

---

## Section III: `survey_glm_fit` S7 Class

**Issue 9: `formula` and `call` properties lack type constraints**
Severity: SUGGESTION
Minor spec gap.

Section 3.1 defines `formula = S7::new_property(default = NULL)` and `call = S7::new_property(default = NULL)` without type constraints. Any object can be stored. If `formula` stores a non-formula object, downstream methods that call `as.character(model@formula)` or `update(model@formula, ...)` will fail silently.

Options:
- **[A]** Add validator checks for `formula` (if non-NULL, must pass `inherits(self@formula, "formula")`) and leave `call` as untyped. Effort: low, Risk: none, Impact: catches construction errors.
- **[B] Do nothing** — the validator doesn't check these; user gets a cryptic error downstream.

**Recommendation: [A]**

---

**Issue 10: `vcov` row/column names: source not specified**
Severity: REQUIRED
Leaves an observable behavior unspecified.

Section 5.4 says `vcov.survey_glm_fit()` returns the vcov matrix where "row and column names match `names(object@coefficients)`." But the spec doesn't say where these names come from during construction. The `stats::glm()` result has named coefficients; the implementation must copy those names to `object@coefficients` and ensure `vcov` inherits the same names. This should be stated in Section 4.4 Step 6.

Options:
- **[A]** Add to Section 4.4 Step 6: "Set `dimnames(vcov_matrix) <- list(names(coef_vector), names(coef_vector))` where `coef_vector` comes from `coef(fit)` (the `stats::glm()` result)." Effort: trivial.
- **[B] Do nothing** — likely handled naturally but not guaranteed.

**Recommendation: [A]**

---

## Section IV: `survey_glm()` Function

**Issue 11: Error class name conflicts with existing codebase**
Severity: REQUIRED
Will cause a silent discrepancy between error classes.

Section 4.7 row 1 specifies `surveycore_error_not_survey_object` for "design not a survey object." However, codebase exploration of `plans/error-messages.md` and `R/06-variance-dispatch.R` shows existing code uses `surveycore_error_not_survey_design` (and the error-messages.md canonical list uses `surveycore_error_unsupported_class`). Three different names for the same condition across the codebase is a DRY violation and makes programmatic error handling fragile.

Options:
- **[A]** Audit `plans/error-messages.md` before implementation; use the single canonical class for "not a survey object" everywhere including in `survey_glm()`. Update Section 4.7 row 1 to match the canonical name. Effort: low, Risk: low.
- **[B] Do nothing** — Phase 2 introduces a third name for the same condition.

**Recommendation: [A]** — DRY; one class per condition.

---

**Issue 12: `na.action` does not cover NAs in the weight column**
Severity: REQUIRED
Edge case absent from spec (Lens 4).

Section 4.4 Step 3 says "`na.action` is applied to the model frame." The model frame includes formula variables — response and predictors. Survey weights are passed separately to `stats::glm()` as the `weights=` argument, NOT as part of the model frame. Therefore, `na.action` does not handle NAs in the weight column.

If `design@data[[design@variables$weights]]` contains `NA`, `stats::glm()` will propagate NAs silently or fail with a cryptic error. The spec must state what happens.

Options:
- **[A]** Add to Section 4.4 Step 3: "Before applying `na.action`, check the weight vector for NAs. If any are present, error with `surveycore_error_na_weights`." Add to Section 4.7 error table and Section IX. Effort: low.
- **[B]** Silently drop rows with NA weights (treat NA weight as `na.omit` behavior). Document this choice.
- **[C] Do nothing** — users get a cryptic base R error when weights contain NA.

**Recommendation: [A]** — Phase 0/1 constructors already validate weights; GLM should maintain the same guarantee by re-checking (the design may have been mutated after construction).

---

**Issue 13: Negative `df_residual` when design df is small**
Severity: REQUIRED
Edge case with unspecified behavior.

Section 7.5 specifies `df_residual = degf(design) - (p - 1)`. For a Taylor design with 2 PSUs and 1 stratum, `degf = 1`. With `p = 3` coefficients, `df_residual = 1 - 2 = -1`. A negative df passed to `qt()` for t-test critical values will produce `NaN`.

The spec doesn't address this. `survey::svyglm()` handles this by using `max(1, df_residual)` or by erroring. A behavior must be specified.

Options:
- **[A]** Add to Section 7.5: "If `df_residual` would be ≤ 0, warn with `surveycore_warning_insufficient_df` and set `df_residual = 1`. CI bounds and p-values will be conservative." Add to error table. Effort: low.
- **[B]** Error with `surveycore_error_insufficient_df` when `df_residual ≤ 0`. Inform user to reduce the number of predictors.
- **[C] Do nothing** — `qt(-1)` returns `NaN`; users get silent garbage in CI columns.

**Recommendation: [A]** — Match `survey::svyglm()`'s conservative fallback; warn rather than error.

---

**Issue 14: Complex formula LHS not addressed**
Severity: REQUIRED
Edge case that will cause silent failures.

Section 4.4 Step 1 extracts the response variable to validate it against `design@data`. For a simple formula `y ~ x`, this is `as.character(formula[[2]])`. But formulas like `log(y) ~ x`, `I(y > 0) ~ x`, or `cbind(y1, y2) ~ x` (multinomial) have compound LHS expressions. The spec doesn't say what happens.

`log(y)` as a response: the column `log(y)` doesn't exist in `design@data`, so `surveycore_error_response_not_found` fires — but this is wrong; `log(y)` is a valid in-formula transformation.

Options:
- **[A]** Specify that response extraction uses `all.vars(formula[[2]])` to get all variable names referenced in the LHS (handles in-formula transforms). Validate each variable name against `design@data`. Document that `cbind()` LHS is unsupported (multinomial is deferred). Effort: low.
- **[B]** Use `formula[[2]]` as a character; document that in-formula transforms (e.g., `log(y)`) must use pre-transformed columns. Effort: trivial, but breaks normal R usage.
- **[C] Do nothing** — `surveycore_error_response_not_found` fires for `log(y) ~ x`; users get a confusing error.

**Recommendation: [A]**

---

## Section V: S3 Methods

**Issue 15: `predict(newdata=NULL, type="link")` silently ignores `type`**
Severity: REQUIRED
Inconsistent contract; will surprise users.

Section 5.5: "When `newdata = NULL`: returns `object@fitted_values` (already on the response scale regardless of `type`)."

This means `predict(fit, type = "link")` and `predict(fit, type = "response")` both return response-scale values when `newdata = NULL`. A user expecting link-scale fitted values gets response-scale values with no warning. This violates the principle of least surprise and differs from how `stats::predict.glm()` behaves (it respects `type` even without `newdata`).

Options:
- **[A]** When `newdata = NULL` and `type != "response"`, delegate to `stats::predict(object@fit_, type = type)` so link-scale values are returned correctly. If `object@fit_` is NULL, error with `surveycore_error_predict_no_fit`. Effort: low.
- **[B]** When `newdata = NULL` and `type != "response"`, issue a warning that `type` is ignored when `newdata = NULL` and return response-scale values. Effort: trivial, but still surprising.
- **[C] Do nothing** — users get wrong-scale values silently.

**Recommendation: [A]** — Match base R behavior.

---

**Issue 16: `residuals(type="deviance")` is in a GAP but not in the return table**
Severity: REQUIRED
Contract is incomplete.

Section 5.7 table lists three `type` values: `"response"`, `"working"`, `"pearson"`. The GAP note says deviance residuals "should be implemented." But the official table doesn't include `"deviance"`. This means:
- If the test plan checks `residuals(fit, type = "deviance")`, there's no spec to test against.
- If it's not tested, the quality gate "all S3 methods work correctly" is ambiguous.

Options:
- **[A]** Add `"deviance"` to the residuals table: delegates to `object@fit_$residuals` (which contains deviance residuals by default in `stats::glm()`) or `residuals(object@fit_, type = "deviance")`. Specify behavior when `object@fit_` is NULL. Effort: low.
- **[B]** Explicitly unsupport `"deviance"`: "Raises `surveycore_error_unsupported_residual_type` for `type = 'deviance'`; use `model@fit_` directly." Effort: trivial.
- **[C] Do nothing** — GAP unresolved; test coverage is ambiguous.

**Recommendation: [A]** — Deviance residuals are standard and easy to implement via `object@fit_`.

---

**Issue 17: `survey_glm_summary` class is a BLOCKING GAP**
Severity: BLOCKING
Quality gate X requires it; structure is undefined.

Section 5.2 says: "`survey_glm_summary` is a new S3 class returned by `summary.survey_glm_fit()`. Its structure must be fully specified (fields, print method) before implementation."

Section X (quality gates) requires: "`survey_glm_summary` S3 class specified and its `print()` method works."

But the structure is deferred to the "implementation plan" — not this spec. This is circular: the spec says "specify later" but the quality gate requires "specified." An implementer cannot write `summary.survey_glm_fit()` or its test without knowing the fields of `survey_glm_summary`.

Minimum needed: field list (what names does the list contain?), and the `print.survey_glm_summary()` output format (analogous to Section 5.1's format for `print.survey_glm_fit()`).

Options:
- **[A]** Add a Section 5.2.1 specifying `survey_glm_summary` as a named list with fields: `coefficients` (the coefficient table), `deviance`, `null_deviance`, `df_residual`, `df_null`, `family`, `dispersion`, `call`, `design_type`. Add the `print.survey_glm_summary()` output format. Effort: medium.
- **[B]** Remove `summary.survey_glm_fit()` from Phase 2 scope. Defer to Phase 3. Effort: trivial — adjust quality gates accordingly.
- **[C] Do nothing** — implementer must invent the class structure; spec review says "specified" when it isn't.

**Recommendation: [A]** — `summary()` is a standard method users will call immediately.

---

## Section VI: `clean()` and broom

**Issue 18: `term` column format for reference rows is underspecified**
Severity: REQUIRED
Two interpretations of the example are possible.

Section 6.3 column table says reference row `term` is `"sexMale [ref]"`. From the example, `sex` is the variable name, `Male` is the reference level, and the format is `"{var}{level} [ref]"`. But this is shown for a factor named `sex` where R generates the non-reference term `"sexFemale"`. The pattern `{var}{level}` means "variable name concatenated with level" — but for factors with long names or multi-word levels, this may produce confusing strings.

The spec should state the exact algorithm: is it `paste0(var_name, ref_level, " [ref]")` (R's factor dummy coding convention) or something else? What if the factor is named `employment_status` with levels `Full-time` and `Part-time`? Term would be `employment_statusPart-time [ref]` — is that correct?

Options:
- **[A]** Specify the exact rule: "Reference row `term` is constructed by `paste0(names(alias_row), ' [ref]')` where `alias_row` is the omitted level from `stats::alias(fit)$Complete` or derived from the contrasts matrix." Include a full worked example with a multi-word factor. Effort: low.
- **[B]** Specify simply: "Reference row `term` is the coefficient name that WOULD have appeared if the reference level had not been dropped, with ` [ref]` appended." No algorithm specified — implementer derives it. Effort: trivial but pushes ambiguity to implementation.
- **[C] Do nothing** — different implementers will produce different term strings for reference rows.

**Recommendation: [A]**

---

**Issue 19: `n_observations` definition is ambiguous after domain + na.action**
Severity: REQUIRED
Two plausible values; spec picks one without clarity.

Section 6.3 says `n_observations` = "Number of observations used in the model fit (after `na.action`)." Section 4.5 says the GLM is "fit only on in-domain rows." So the full pipeline is: all rows → domain filter → na.action → GLM fit.

`n_observations` could mean:
- Rows after domain filter only (before na.action)
- Rows after domain filter AND na.action (the actual GLM input)
- Rows in the full design (before both)

The parenthetical "(after `na.action`)" implies the third interpretation is wrong, but doesn't distinguish the first two.

Options:
- **[A]** Clarify: "`n_observations` is the number of rows in the final model matrix after both domain filtering and `na.action`; this matches `nrow(model.matrix(fit))`." Effort: trivial.
- **[B] Do nothing** — implementers may use different counts; test coverage catches it.

**Recommendation: [A]**

---

**Issue 20: `variable_labels` meta key behavior when no labels are set**
Severity: REQUIRED
Edge case not specified.

Section 6.3 says `variable_labels` is "one entry per predictor variable; value is the variable label from `design@metadata` or `NULL` if unlabelled." But what is the structure of the list when NO predictors have labels? Is it:
- An empty list `list()`?
- A named list with all `NULL` values: `list(x1 = NULL, x2 = NULL)`?
- `NULL` (the whole key)?

The spec says "All keys always present; unset values `NULL`, never absent" — but this applies to the `.meta` keys, not to entries within `variable_labels`. The inner structure is ambiguous.

Section 8.2 item 5 tests the case when labels ARE set. There's no test for when they are NOT set.

Options:
- **[A]** Specify: "When no labels are set, `variable_labels` is a named list with `NULL` for each predictor name (not an empty list). This preserves the predictor structure even when unlabelled." Add an edge case test. Effort: low.
- **[B]** Specify: "When no labels are set, `variable_labels` is an empty named list `list()`." Simpler but loses predictor structure.
- **[C] Do nothing** — `test_glm_tidy_invariants()` will catch inconsistency during tests, but the spec doesn't define expected behavior.

**Recommendation: [A]** — Consistent with the "always present" principle applied to the inner structure.

---

**Issue 21: `family` extraction from S7 property to meta string not specified**
Severity: SUGGESTION
Minor implementation gap.

Section 6.3 meta key `family` is described as "Family name, e.g. `'gaussian'`" — a character string. The S7 class stores `family` as a list (the full family object from e.g. `gaussian()`). The mapping `model@family$family` gives the family name string. This should be stated explicitly in `.build_glm_meta()` to avoid implementers using `class(model@family)` or other incorrect extractions.

Options:
- **[A]** Add to Section 2.2 `.build_glm_meta()` description: "Extract family name as `model@family$family` (e.g. `'gaussian'`) and link function as `model@family$link` (e.g. `'identity'`)." Effort: trivial.
- **[B] Do nothing** — R's family objects always have `$family` and `$link` fields; discoverable.

**Recommendation: [A]** — Spec should be explicit on extraction.

---

## Section VII: Variance Estimation

*Issues 3 (Taylor interface), 4 (degf already exists), and 5 (SRS formula wrong) already reported above.*

**Issue 22: `degf()` behavior when domain is active: uses full design or in-domain rows?**
Severity: REQUIRED
Observable behavior not specified.

Section 7.5: `survey_srs` df = `nrow(design@data) - 1`. But if domain is active, the GLM is fit on in-domain rows only. Should the df be computed from the full design (correct for design-based inference) or the in-domain subset?

For `survey_taylor`, `.degf_taylor()` uses all PSUs and strata from the full design — this is correct (domain estimation uses full design variance). For `survey_srs`, `nrow(design@data)` is also the full design — also correct. But this should be explicitly confirmed in the context of GLM domain estimation.

Options:
- **[A]** Add to Section 7.5: "`degf()` always uses the full design (all rows), not the in-domain subset. This is consistent with the domain estimation contract in Section 4.5." Effort: trivial.
- **[B] Do nothing** — likely correct by default, but implicit.

**Recommendation: [A]**

---

## Section VIII: Testing Strategy

**Issue 23: S7 validator error tests absent from test plan**
Severity: REQUIRED
Violates testing-surveycore.md (Layer 1 error testing requirement).

The validator in Section 3.3 has five error conditions:
1. `coefficients` empty
2. `vcov` dimensions wrong
3. `fitted_values` empty
4. `residuals` length mismatch
5. `weights` length mismatch
6. `degf` not positive length-1

None of these are in the test plan (Section 8.2). Per `testing-surveycore.md`, Layer 1 errors use `class=` only (no snapshot). These tests must be added.

Options:
- **[A]** Add a Section 8.2 item 11: "S7 validator errors — test each of the 6 validator conditions using `class=` only (no snapshot), per `testing-surveycore.md` Layer 1 error pattern." Effort: low.
- **[B] Do nothing** — validator branches may go untested; coverage below 98%.

**Recommendation: [A]**

---

**Issue 24: Error test dual-pattern not stated in test plan**
Severity: REQUIRED
Violates testing-surveycore.md Layer 3 pattern.

Section 8.2 item 7 says "every row in Section 4.7 and 6.5 error tables" but does not specify the dual pattern (`expect_error(class=)` + `expect_snapshot(error=TRUE)`) required by `testing-surveycore.md` for Layer 3 (constructor input validation) errors.

Options:
- **[A]** Update item 7 in Section 8.2: "Every row in the error tables is tested with the dual pattern: `expect_error(class = ...)` + `expect_snapshot(error = TRUE)` for user-facing constructor errors (Layer 3). S7 validator errors (Layer 1) use `class=` only — no snapshot." Effort: trivial.
- **[B] Do nothing** — testing standards rule applies implicitly, but the test plan is ambiguous.

**Recommendation: [A]** — Consistency with existing test infrastructure is important.

---

**Issue 25: Oracle test structure provided for Taylor only; replicate/SRS/twophase missing**
Severity: REQUIRED
Quality gate requires all four design types; spec only structures one test.

Section 8.1 shows a detailed oracle test template for `survey_taylor`. Section X quality gates require "SE oracle tests pass for Taylor, replicate, SRS, and twophase designs." But no oracle test template exists for replicate, SRS, or twophase. The oracle datasets are named (Section 8.1 table) but the test structure for each isn't provided.

This will result in inconsistent oracle test implementations across design types if not specified.

Options:
- **[A]** Add oracle test templates for `survey_replicate` (using `acs_pums_wy`), `survey_srs` (using `make_survey_data(design="srs")`), and `survey_twophase` (using `make_survey_data(design="twophase")`). Each template follows the same pattern as the Taylor example. Effort: medium.
- **[B]** State "the replicate, SRS, and twophase oracle tests follow the same pattern as the Taylor test; substitute the appropriate design and dataset." Leave structure implicit. Effort: trivial.
- **[C] Do nothing** — inconsistent oracle tests; possible wrong tolerance or missing SE comparison.

**Recommendation: [B]** — Explicit template for Taylor is sufficient; state that others follow the same pattern.

---

**Issue 26: `degf()` function not independently tested**
Severity: REQUIRED
`.degf()` is already implemented but the spec adds behavior assumptions. Phase 2 uses `.degf()` in ways that should be tested.

The spec assumes `.degf()` exists and works for all 5 design classes. Given Phase 2 adds new usage of `.degf()`, and the existing implementation for `survey_replicate` may use a simplified formula (`R - 1`), there should be at least a brief oracle comparison of `degf(design)` vs. `survey::degf()` for each design class.

Options:
- **[A]** Add to `test-glm-numerical.R`: a test block verifying `degf(design)` matches `survey::degf(svydesign_obj)` for each supported design class. `skip_if_not_installed("survey")`. Effort: low.
- **[B]** Defer degf accuracy testing — it was presumably tested in Phase 1. Effort: none.
- **[C] Do nothing** — wrong df propagates to CI bounds.

**Recommendation: [A]** — Given the replicate formula question (Issue 4), an oracle test is warranted.

---

**Issue 27: `surveycore_error_formula_missing` (P2-2) cannot be tested with the standard typed-class pattern**
Severity: REQUIRED
Untestable error class as specified.

Section 4.7 row 2: error class `surveycore_error_formula_missing` fires when `formula` is missing. But `formula` is a required argument with no default. In R, calling `survey_glm(design)` without `formula` raises a base R error *before* the function body executes: "argument 'formula' is missing, with no default." This means `cli_abort(class = "surveycore_error_formula_missing")` can never be reached by `survey_glm()` unless `formula` is given a default of `NULL` and then checked.

Either the error class is unreachable (incorrect architecture), or the signature needs `formula = NULL` with an explicit check.

Options:
- **[A]** Change the signature to `formula = NULL` and add an explicit check in Step 1: `if (is.null(formula)) cli_abort(..., class = "surveycore_error_formula_missing")`. This makes the error class testable. Effort: trivial.
- **[B]** Remove `surveycore_error_formula_missing` from the error table. Let base R's missing-argument error surface naturally. Effort: trivial; reduces error table by one untestable class.
- **[C] Do nothing** — error class is listed but untestable; oracle test is written expecting a surveycore error but gets a base R error.

**Recommendation: [A]** — Consistent with how Phase 1 handles required arguments.

---

## Section IX: Error Message Table

**Issue 28: Three new error classes not in `plans/error-messages.md` per Section IX instruction**
Severity: REQUIRED
Section IX explicitly states "These must be added to `plans/error-messages.md` before implementation begins."

The spec creates 13 new error/warning classes (P2-1 through P2-13). Additionally, the issues above suggest at least 3 more are needed:
- `surveycore_warning_insufficient_df` (Issue 13)
- `surveycore_error_na_weights` (Issue 12)
- Potentially `surveycore_error_unsupported_design_class` for calibrated/twophase fallback (Issues 1, 2)

The current spec's error table doesn't include these. They must be added before implementation.

Options:
- **[A]** Add all new error/warning classes identified in this review to Section IX, then update `plans/error-messages.md` before implementation. Effort: low.
- **[B] Do nothing** — `plans/error-messages.md` is out of sync with implementation; quality gate fails.

**Recommendation: [A]**

---

## Section X: Quality Gates

**Issue 29: Quality gate for `survey_glm_summary` depends on unspecified class**
Severity: BLOCKING (secondary consequence of Issue 17)

The last quality gate: "`survey_glm_summary` S3 class specified and its `print()` method works." But the class structure is flagged as a GAP in Section 5.2. The quality gate cannot be verified if the class isn't specified. This gate effectively blocks phase completion unless Issue 17 is resolved first.

This is subsumed by Issue 17; no additional options needed.

---

## Cross-Cutting Issues

**Issue 30: Domain estimation sandwich mechanism for out-of-domain observations is unresolved**
Severity: BLOCKING
This is the existing GAP in Section 4.5, flagged by the spec itself as unresolved.

The GAP reads: "The exact mechanism for 'fit on in-domain, variance on full design'... must be specified how out-of-domain scores are set (likely to zero) so that the full-design variance formula applies."

This is not a suggestion for resolution — it is an open architectural question. The spec says "likely to zero" but "likely" is not implementable. Without resolving this, the GLM sandwich for domain-filtered designs cannot be coded, and the domain estimation test (Section 8.2 item 10) cannot be validated.

The Phase 1 precedent (`.apply_domain()` in `R/07-utils.R`) sets out-of-domain observations' score contributions to zero by multiplying by the domain indicator. For GLM, the same principle applies: out-of-domain scores `u_i = 0` for `i ∉ domain`. This is mathematically correct for the Taylor linearization of a domain total.

Options:
- **[A]** Resolve the GAP explicitly: "Out-of-domain score contributions are set to zero: `u_i = w_i x_i e_i * I(i ∈ domain)`. In-domain observations use their GLM working residuals; out-of-domain scores are zero. The full-design variance of `Σ u_i` is then computed over all rows." Add an oracle comparison against `survey::svyglm()` with a domain subset to validate this. Effort: medium (requires verification against `survey` package).
- **[B] Do nothing** — implementer must guess; domain oracle test catches failures.

**Recommendation: [A]** — The math is standard; the spec just needs to commit to it and validate.

---

## Summary

| Severity | Count |
|---|---|
| BLOCKING | 7 |
| REQUIRED | 19 |
| SUGGESTION | 3 |

**Total issues:** 29

**Blocking issues:** SRS variance formula is mathematically incorrect (Issue 5); `survey_glm_summary` structure undefined (Issue 17); Taylor variance pass-through architecture unspecified (Issue 3); `control = list(...)` signature broken (Issue 6); `survey_calibrated` behavior unspecified (Issue 1); domain estimation out-of-domain score treatment unresolved (Issue 30); `survey_glm_summary` quality gate depends on unspecified class (Issue 29, subsumed by 17).

**Overall assessment:** The spec has serious blocking gaps — a mathematical error in the SRS variance formula, an undefined class required by the quality gates, an underspecified architectural interface for variance computation, and a broken function signature — that must be fixed before implementation begins. The REQUIRED issues are largely edge cases and testing specifics that are well within scope to resolve. Most blocking issues have low-effort resolutions; this spec is 2-3 focused edits away from being implementable.
