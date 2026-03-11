# Spec Review: Phase 2 — Survey GLM: Weighted Regression

**Reviewer:** Claude (adversarial batch pass)
**Date:** 2026-02-25
**Spec file:** `plans/phase-2-glm-formal-specification.md`
**Codebase snapshot:** `feature/phase1-freqs` (post Phase 1 merge)

---

## Section I: Scope

**Issue 1: `survey_nonprob` GLM variance completely unspecified**
Severity: BLOCKING
Violates engineering-preferences.md §4 (handle edge cases explicitly)

The spec flags this as a GAP in Section I: "The behavior of `survey_glm()` with `survey_nonprob` designs is not fully specified." But this gap is never resolved — it appears only as a warning note. The testing section (Section VIII) has no oracle dataset for `survey_nonprob`. The dispatch in Section 7.1 says it "falls back to SRS sandwich (conservative)" but this is a one-line architectural note, not a contract.

If a user passes a `survey_nonprob` design to `survey_glm()`, the implementation must make a choice — but the spec gives no guidance on what that choice should be.

Options:
- **[A]** Specify `survey_nonprob` as "uses SRS sandwich formula; no calibration adjustment; conservative" — add it to Section 7 with the SRS formula and a test using synthetic calibrated data. Effort: low, Risk: low, Impact: removes a blocking gap.
- **[B]** Raise `surveycore_error_unsupported_design_class` for `survey_nonprob` in `survey_glm()` with a clear message and no fallback. Defer support to Phase 3. Effort: low, Risk: low, Impact: explicit failure mode.
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
  else if (S7::S7_inherits(design, survey_nonprob)) nrow(design@data) - 1L
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

**Blocking issues:** SRS variance formula is mathematically incorrect (Issue 5); `survey_glm_summary` structure undefined (Issue 17); Taylor variance pass-through architecture unspecified (Issue 3); `control = list(...)` signature broken (Issue 6); `survey_nonprob` behavior unspecified (Issue 1); domain estimation out-of-domain score treatment unresolved (Issue 30); `survey_glm_summary` quality gate depends on unspecified class (Issue 29, subsumed by 17).

**Overall assessment:** The spec has serious blocking gaps — a mathematical error in the SRS variance formula, an undefined class required by the quality gates, an underspecified architectural interface for variance computation, and a broken function signature — that must be fixed before implementation begins. The REQUIRED issues are largely edge cases and testing specifics that are well within scope to resolve. Most blocking issues have low-effort resolutions; this spec is 2-3 focused edits away from being implementable.

---

## Round 2 Review: v0.3 (Post-Stage 3 Resolution)

**Reviewer:** Claude (adversarial batch pass — second pass)
**Date:** 2026-02-27
**Spec version:** 0.3 — marked "Approved — ready for implementation plan"

**Status of Issues 1–30:** All resolved. Decisions recorded in
`plans/claude-decisions-phase-2.md`. The spec has been updated accordingly.
The issues below are NEW gaps found in the updated v0.3 spec.

---

### Section I: Scope

**Issue 31: Expanded S3 method set (13 methods) is in the decisions log but absent from the spec**
Severity: BLOCKING
Violates contract completeness (Lens 3) and DRY/engineering-preferences.md §2.

The 2026-02-26 decisions log entry "snake_case arguments on all S3 methods; expanded method set" explicitly adds 13 S3 methods to Phase 2 scope:

> `confint()`, `residuals("partial")`, `formula()`, `terms()`, `model.matrix()`,
> `model.frame()`, `deviance()`, `df.residual()`, `nobs()`, `hatvalues()`,
> `logLik()`, `AIC()` / `BIC()`, `update()`

None of these appear in Section V of the spec. No signatures. No behavior contracts. No error conditions. No test coverage.

The Section I scope table still reads: "S3 methods on `survey_glm_fit`: `print`, `summary`, `coef`, `vcov`, `predict`, `fitted`, `residuals`" — seven methods, not twenty. Section X quality gate says "All S3 methods work correctly" but never lists which methods that includes.

An implementer reading the spec alone (not the decisions log) will implement seven methods and miss thirteen. The decisions log is not the spec.

Options:
- **[A]** Add one subsection per expanded method to Section V, following the style of existing subsections: signature, one-sentence behavior, return value, error conditions. For the delegation methods (`formula()`, `terms()`, etc.) these are trivial. For `confint()` the contract is non-trivial: design-based CIs using `qt((1 + conf_level)/2, df = df_residual)` (same formula as `clean()`). For `update()`, document the `getCall.survey_glm_fit` requirement. Update the Section I scope table and quality gates accordingly. Effort: medium, Risk: low, Impact: unblocks implementation of the expanded method set.
- **[B]** Explicitly narrow Phase 2 scope back to the original seven methods. Move the 13 additional methods to a Phase 2.5 spec. Update the decisions log accordingly. Effort: trivial scope decision, Risk: defers method parity, Impact: cleaner Phase 2.
- **[C] Do nothing** — implementer must reconcile spec with decisions log; one of them is wrong about Phase 2 scope.

**Recommendation: [A]** — The decisions were made and recorded; the spec just hasn't caught up. The delegation methods are trivial to spec. `confint()` is non-trivial and warrants a real subsection.

---

**Issue 32: Section I scope table lists seven S3 methods; decision expanded it to twenty**
Severity: REQUIRED
Factual inaccuracy; linked to Issue 31.

The scope table in Section I has not been updated to reflect the 2026-02-26 expanded method set. Any reader using the scope table as the authoritative list of deliverables will undercount by thirteen methods.

This is a secondary consequence of Issue 31 but warrants its own entry because the scope table is typically the first thing an implementer reads to bound their work.

Options:
- **[A]** Update the scope table row "S3 methods on `survey_glm_fit`" to list all twenty methods. Effort: trivial.
- **[B]** Resolve as part of Issue 31 (no separate action needed). Effort: none.

**Recommendation: [B]** — Subsumed by Issue 31 but must not be forgotten when updating Section V.

---

### Section V: S3 Methods

**Issue 33: Section 6.5 referenced in test plan but does not exist**
Severity: REQUIRED
Dangling cross-reference; violates contract completeness.

Section 8.2 item 7 reads: "every row in Sections 4.7 and 6.5 error tables." There is no Section 6.5. Section 6 ends at 6.4. The `clean()` error conditions are listed in Section IX (P2-12, P2-13) but never collected into a dedicated error table under Section VI. The cross-reference is broken.

Options:
- **[A]** Add a Section 6.5 error table for `clean()` containing P2-12 (`surveycore_error_not_glm_fit`) and P2-13 (`surveycore_error_invalid_conf_level`), mirroring the format of Section 4.7. Update item 7 in Section 8.2 to reference the correct section. Effort: low.
- **[B]** Change Section 8.2 item 7 to reference "Section 4.7 and Section IX (P2-12, P2-13)" instead of "Section 6.5." Effort: trivial.

**Recommendation: [A]** — Giving `clean()` its own error table (6.5) makes it parallel to `survey_glm()` (4.7) and easier to find during implementation.

---

**Issue 34: `test-glm-methods.R` test plan omits residuals types `"pearson"`, `"deviance"`, and `"partial"`, plus the NULL `fit_` case for all three**
Severity: REQUIRED
Violates testing-standards.md §2 (all behavioral branches must be covered).

Section 5.7 specifies four residual types: `"response"`, `"working"`, `"pearson"`, `"deviance"`. The 2026-02-26 decisions log also adds `"partial"` (delegating to `residuals(object@fit_, type = "partial")`). All three of `"pearson"`, `"deviance"`, and `"partial"` require `object@fit_` to be non-`NULL`, and the spec specifies `surveycore_error_predict_no_fit` for the NULL case.

Section 8.2 `test-glm-methods.R` test plan:
- Item 9: `residuals(type = "response")` ✓
- Item 10: `residuals(type = "working")` ✓
- Missing: `residuals(type = "pearson")`
- Missing: `residuals(type = "deviance")`
- Missing: `residuals(type = "partial")` (from 2026-02-26 decisions)
- Missing: all three with `fit_` = NULL → `surveycore_error_predict_no_fit`

The quality gate says "All S3 methods (`coef`, `vcov`, `print`, `summary`, `predict`, `fitted`, `residuals`) work correctly" — but "residuals works correctly" is untestable without tests for all four (five) types.

Options:
- **[A]** Add items 11–16 to the `test-glm-methods.R` test plan: one block per residual type (`"pearson"`, `"deviance"`, `"partial"`) and one block per type for the NULL-`fit_` error path. Effort: low.
- **[B]** Extend item 10 to say "all residual types specified in Section 5.7 are tested." Effort: trivial but underspecified.

**Recommendation: [A]** — Individual test blocks per type make it clear what must pass.

---

### Section IV: `survey_glm()` Function

**Issue 35: Empty-domain edge case not specified**
Severity: REQUIRED
Violates Lens 4 (edge cases: empty inputs).

Section 4.5 describes domain estimation via `surveytidy::filter()` upstream of `survey_glm()`. If the filter removes all rows (active domain indicator is all `FALSE`), `survey_glm()` receives an effective dataset of 0 rows when fitting. `stats::glm()` called with 0 rows either fails with a cryptic error or returns a degenerate fit. The spec is silent on this case.

The analogous situation in Phase 1 analysis functions (e.g., `get_means()` on an empty domain) presumably has defined behavior — whether an error or a warning with NA results. `survey_glm()` should follow the same pattern.

Options:
- **[A]** Add to Section 4.5 (or 4.4 Step 2): "If the active domain contains zero in-domain rows after domain restriction, error with `surveycore_error_empty_domain` before calling `stats::glm()`. Add to Section 4.7 and Section IX." Effort: low, consistent with defensive design.
- **[B]** Let `stats::glm()` fail naturally on 0 rows; document that the error is propagated as-is. Effort: trivial, but error class is non-surveycore and the message is cryptic.
- **[C] Do nothing** — behavior is undefined; user gets a base R error.

**Recommendation: [A]** — Consistent with Phase 1's defensive approach to degenerate inputs.

---

### Section VIII: Testing Strategy

**Issue 36: Binomial oracle test is required by the quality gates but has no template or placement in `test-glm-numerical.R`**
Severity: REQUIRED
Violates Lens 2 (numerical oracle per design type and family).

Section 8.4 edge cases mention: "Gaussian family, binomial family, Poisson family — all produce valid fits (oracle comparison for at least Gaussian and binomial)." The quality gate says: "`predict(fit, newdata = df)` produces expected values for Gaussian and logistic families." But:

1. Section 8.1 only provides an oracle template for Gaussian family on a Taylor design.
2. There is no guidance on where the binomial oracle test lives, which dataset to use, or what formula to test.
3. Binomial oracles are more important than Gaussian for validating the `residuals(type = "working")` path, since for Gaussian/identity, working = response = Pearson residuals (the bug from Issue 7 is invisible in Gaussian tests).

An oracle for binomial family is the only way to validate that the GLM working-residual sandwich is correct for non-Gaussian families. Without it, the variance computation for logistic regression is untested numerically.

Options:
- **[A]** Add a second oracle test template to Section 8.1 for binomial family using `nhanes_2017` with a binary outcome (e.g., `ridexprg` — pregnancy status — as a 0/1 outcome, `y ~ ridageyr + riagendr`, `family = binomial()`). State that the tolerance rules (1e-10 point, 1e-8 SE) apply equally. Effort: low.
- **[B]** State in Section 8.1 that "at least one binomial oracle test using the Taylor design is required" without providing a full template; leave specific formula/variable choice to the implementer. Effort: trivial.

**Recommendation: [A]** — Binomial is the critical validation path for non-Gaussian sandwich variance; it deserves an explicit template, not just a mention in edge cases.

---

### Section VI: `clean()` and broom

**Issue 37: GAP note in Section 6.3 not removed after Section 8.3 resolves it**
Severity: SUGGESTION
Stale documentation.

Section 6.3 contains a `⚠️ GAP` note:

> "The absence of `value_labels` in `survey_glm_tidy` meta means `test_result_invariants()` from Phase 1 will fail if called directly on a `survey_glm_tidy` object (invariant 5 checks `value_labels`). Either: (a) extend `test_result_invariants()` to accept an optional `skip_keys` argument, or (b) define a separate `test_glm_tidy_invariants()` for this class. This must be resolved before implementation."

Section 8.3 defines `test_glm_tidy_invariants()` — option (b) — which resolves the gap. The GAP note should be replaced with a forward reference to Section 8.3: "See `test_glm_tidy_invariants()` in Section 8.3 for the invariant checker that replaces `test_result_invariants()` for this class."

Options:
- **[A]** Remove the GAP note. Add a sentence: "Use `test_glm_tidy_invariants()` (Section 8.3) instead of `test_result_invariants()` for `survey_glm_tidy` objects." Effort: trivial.
- **[B] Do nothing** — stale note causes confusion but doesn't block implementation.

**Recommendation: [A]** — A resolved GAP note that still says "must be resolved before implementation" undermines confidence in the spec's current state.

---

**Issue 38: Stale "first draft" footer at end of spec**
Severity: SUGGESTION
Cosmetic; inconsistent with "Approved" status.

Line 1136 (the final line of the spec) reads:

> *This is a first draft. Expect gaps — run Stage 2 in a new session to get an adversarial review before resolving anything.*

The spec header says "Status: Approved — ready for implementation plan." The footer is inconsistent and creates doubt about whether the document is final.

Options:
- **[A]** Remove or replace with: "*Reviewed and approved via Stage 2/3 spec workflow. All issues resolved — see `plans/claude-decisions-phase-2.md`.*" Effort: trivial.
- **[B] Do nothing** — cosmetic only; implementer will follow the header status.

**Recommendation: [A]**

---

## Updated Summary

### Round 1 Issues (Issues 1–30) — All Resolved

All 30 issues from the original 2026-02-25 review are resolved. Decisions recorded in `plans/claude-decisions-phase-2.md`. The spec was updated to v0.3.

### Round 2 Issues (Issues 31–38)

| # | Section | Title | Severity |
|---|---|---|---|
| 31 | I / V | 13 expanded S3 methods in decisions log, absent from spec | BLOCKING |
| 32 | I | Scope table lists 7 methods; decisions expanded to 20 | REQUIRED (subsumed by 31) |
| 33 | VIII | Section 6.5 referenced in test plan but does not exist | REQUIRED |
| 34 | VIII | `test-glm-methods.R` misses pearson/deviance/partial residual types + NULL fit_ | REQUIRED |
| 35 | IV | Empty-domain edge case not specified | REQUIRED |
| 36 | VIII | Binomial oracle test required but has no template | REQUIRED |
| 37 | VI | Stale GAP note in Section 6.3 after Section 8.3 resolves it | SUGGESTION |
| 38 | — | Stale "first draft" footer | SUGGESTION |

| Severity | Round 1 | Round 2 |
|---|---|---|
| BLOCKING | 7 (all resolved) | 1 |
| REQUIRED | 19 (all resolved) | 4 (+1 subsumed) |
| SUGGESTION | 3 (all resolved) | 2 |

**Total new issues:** 7 (one BLOCKING, four REQUIRED, two SUGGESTION)

**Overall assessment:** The v0.3 spec is nearly implementation-ready. The one blocking gap — thirteen S3 methods decided in the decisions log but absent from the spec — must be added to Section V before implementation begins. The REQUIRED issues are localized test plan gaps and one missing edge case. This spec is one focused editing pass away from being complete.

---

## Round 3 Review: v0.6 (Post-Round-2 Resolution)

**Reviewer:** Claude (adversarial batch pass — third pass)
**Date:** 2026-02-27
**Spec version:** 0.6 — status "Revised — `clean()` API updated; pending re-approval before implementation plan"

### Prior Issues (Round 2)

| # | Title | Status |
|---|---|---|
| 31 | 13 expanded S3 methods in decisions log, absent from spec | ✅ Resolved — Sections 5.8–5.19 added; scope table updated to 20 methods |
| 32 | Scope table lists 7 methods; decisions expanded to 20 | ✅ Resolved (subsumed by 31) |
| 33 | Section 6.5 referenced in test plan but does not exist | ✅ Resolved — Section 6.5 error table for `clean()` added |
| 34 | `test-glm-methods.R` misses pearson/deviance/partial residual types + NULL `fit_` | ✅ Resolved — items 11–16 added to test plan |
| 35 | Empty-domain edge case not specified | ✅ Resolved — `surveycore_error_empty_domain` added to Section 4.5, 4.7, and IX |
| 36 | Binomial oracle test required but has no template | ✅ Resolved — all 8 families now in Section 9.1 with Binomial and Poisson templates |
| 37 | Stale GAP note in Section 6.3 after Section 8.3 resolves it | ✅ Resolved — GAP note replaced with forward reference |
| 38 | Stale "first draft" footer | ✅ Resolved — footer replaced with approved-status note |

---

### New Issues (Pass 3)

#### Section VIII / IX: Testing Strategy

**Issue 39: Test plan for 12 expanded S3 methods (Sections 5.8–5.19) is entirely absent**
Severity: BLOCKING
Violates Lens 2 (test completeness) and engineering-preferences.md §2 (more tests is better).

Issue 31 added Sections 5.8–5.19 to the spec (12 new methods). The `test-glm-methods.R` test plan in Section 9.2 was updated only to add items 11–16 for residuals types. The following methods from Sections 5.8–5.19 have **no test plan items at all**:

- `confint()` (5.8) — design-based CIs; non-trivial formula using `@vcov` and `@df_residual`
- `formula()` (5.9) — returns `x@formula`
- `terms()` (5.10) — delegates to `terms(x@fit_)`; errors with `surveycore_error_predict_no_fit` when `fit_` is NULL
- `model.matrix()` (5.11) — delegates to `model.matrix(object@fit_)`; same NULL error
- `model.frame()` (5.12) — delegates to `model.frame(formula@fit_)`; same NULL error
- `deviance()` (5.13) — returns `object@deviance`
- `df.residual()` (5.14) — returns `object@df_residual`
- `nobs()` (5.15) — returns `length(object@fitted_values)`
- `hatvalues()` (5.16) — delegates to `hatvalues(model@fit_)`; same NULL error
- `logLik()` (5.17) — delegates to `logLik(object@fit_)`; same NULL error
- `AIC()/BIC()` (5.18) — delegates to base; same NULL error
- `update()` (5.19) — via `getCall.survey_glm_fit`; requires `object@call` non-NULL

The quality gate says "All 20 S3 methods work correctly" but the test plan has no specification of what "correctly" means for these 12 methods. An implementer cannot write compliant tests without this.

Options:
- **[A]** Add test plan items 17–28 to the `test-glm-methods.R` plan: one happy-path block per method (verifying the return value matches the property or delegation result), plus one NULL-`fit_` error block for each of `terms()`, `model.matrix()`, `model.frame()`, `hatvalues()`, `logLik()`, `AIC()/BIC()`. `confint()` warrants two blocks: happy path (returns correct bounds vs. manual `qt()` computation) and invalid `level` error. `update()` warrants one block verifying the result matches re-running `survey_glm()` with a different `family`. Effort: medium, Risk: low, Impact: unblocks quality gate.
- **[B]** Add a single catch-all item: "All methods in Sections 5.8–5.19 are tested for correct return values and NULL `fit_` error conditions where applicable." Effort: trivial, but leaves coverage ambiguous.
- **[C] Do nothing** — quality gate "all 20 methods work correctly" is untestable for 12 of them.

**Recommendation: [A]** — Each method warrants at minimum one test block; the quality gate cannot be verified without it.

---

**Issue 40: `surveycore_error_predict_no_fit` is untested for 6 additional call sites**
Severity: REQUIRED
Violates testing-standards.md §2 (every error class gets a test) and Lens 2 (error paths).

The error class `surveycore_error_predict_no_fit` (P2-14) is specified for these call sites:

| Method | NULL-`fit_` test in spec? |
|---|---|
| `predict.survey_glm_fit()` | ✅ item 7 |
| `residuals(type = "pearson")` | ✅ item 14 |
| `residuals(type = "deviance")` | ✅ item 15 |
| `residuals(type = "partial")` | ✅ item 16 |
| `terms()` (5.10) | ❌ absent |
| `model.matrix()` (5.11) | ❌ absent |
| `model.frame()` (5.12) | ❌ absent |
| `hatvalues()` (5.16) | ❌ absent |
| `logLik()` (5.17) | ❌ absent |
| `AIC()/BIC()` (5.18) | ❌ absent |
| `get_predict()` (7.6) | ✅ item 10 in marginaleffects plan |

Six call sites throw `surveycore_error_predict_no_fit` with no test plan entry. The error class is tested at the `predict()` call site; but the class is described in Section X as covering only `predict.survey_glm_fit` (P2-14). Implementations that add the NULL check to the other methods need test coverage to pass quality gates.

Options:
- **[A]** Add one NULL-`fit_` test block per call site in the `test-glm-methods.R` test plan (these can be grouped under the expanded method test items added by Issue 39's resolution). Dual pattern (`class=` + `expect_snapshot(error=TRUE)`) per `testing-surveycore.md`. Effort: low.
- **[B]** Add a single combined test block: "For all methods that require `fit_` to be non-NULL, `surveycore_error_predict_no_fit` is thrown when `fit_` is `NULL`." Simpler but doesn't specify which methods.
- **[C] Do nothing** — six error paths are uncovered; coverage below 98%.

**Recommendation: [A]** — Individual test blocks per method make intent clear and coverage explicit.

---

#### Section VI: `clean()` and broom

**Issue 41: `print(clean(fit))` output format not shown and not specified**
Severity: REQUIRED
Violates Lens 3 (for every result class with a `print()` method, exact console output must be shown).

Section 6.3 defines `survey_glm_tidy` with class hierarchy `c("survey_glm_tidy", "survey_result", "tbl_df", "tbl", "data.frame")`. Phase 1 defines `survey_result` and presumably defines `print.survey_result()` (since all Phase 1 analysis functions return `survey_result` subclasses with headers). The spec says nothing about:

1. Whether a `print.survey_glm_tidy()` method is defined in Phase 2.
2. Whether `print(clean(fit))` inherits `survey_result`'s print or tibble's default print.
3. What the output looks like on the console.

Per the review lens: "For every result class with a `print()` or `format()` method: is the exact console output shown as a verbatim example block, including any header line? Vague descriptions like 'prints as a tibble' are flagged as REQUIRED."

The test plan (item 1 in `test-glm-methods.R`) has a snapshot for `print()` on the *model* object (`survey_glm_fit`). No snapshot or print contract exists for the *result* object (`survey_glm_tidy`).

Options:
- **[A]** Add a Section 6.6: "print method for `survey_glm_tidy`." If using `survey_result` inheritance unchanged, state: "No custom `print.survey_glm_tidy()` is defined. `print(clean(fit))` uses `print.survey_result()` defined in Phase 1; its output format is specified in the Phase 1 spec." Add a snapshot test in `test-glm.R` for `print(clean(fit))` output. Effort: low.
- **[B]** Show a verbatim example of `print(clean(fit))` in Section 6.3 (similar to how Sections 5.1 and 5.2.2 show print output for the model objects). Effort: low.
- **[C] Do nothing** — implementer must discover the print format by running Phase 1 code; snapshot test will catch regressions but only after implementation is complete.

**Recommendation: [A] or [B]** — [A] if inheriting Phase 1's print unchanged; [B] if any customization is needed. Either satisfies the lens requirement.

---

**Issue 42: `label` column stripping algorithm for factor dummy names is unspecified**
Severity: REQUIRED
Violates Lens 3 (contract completeness — observable behavior left implicit).

Section 6.3 defines the `label` column: "For factor levels (including reference rows): value label from `design@metadata` if set, otherwise the stripped level name (e.g., 'Male' from 'sexMale')."

The algorithm for "stripping" the variable name prefix from the coefficient name is not stated. R generates factor dummy coefficient names via `paste0(var_name, level)` — so `sex` + `Male` = `sexMale`. Recovering `Male` from `sexMale` requires either:

1. **String removal:** `sub(paste0("^", var_name), "", coef_name)` — fragile if the variable name is a prefix of the level name (e.g., variable `"s"`, level `"exMale"` → coefficient `"sexMale"` → incorrectly strips to `"exMale"`).
2. **Model frame lookup:** Enumerate all levels of the factor from the model frame, then match `coef_name` against `paste0(var_name, levels)`. This is unambiguous but requires access to the model frame.
3. **Contrasts matrix:** Inspect `colnames(contrasts(model_frame[[var]]))` to get non-reference level names.

An implementer who uses approach 1 will produce wrong labels whenever a variable name is a prefix of a level name. The spec must specify which approach is used.

The reference row algorithm (Section 6.3) already specifies `setdiff(levels(model_frame[[var]]), colnames(contrasts(model_frame[[var]])))` using the model frame — approach 3 for reference level detection. Approach 2 (model frame levels lookup) is the consistent choice for non-reference levels.

Options:
- **[A]** Add to Section 6.3 `label` column description: "For factor levels, the level name is recovered from the model frame: for each coefficient belonging to variable `var_name`, the level is `setdiff(levels(model_frame[[var_name]]), colnames(contrasts(model_frame[[var_name]])))[i]` for ordered matching against `coef_name`. Or equivalently: enumerate `levels(model_frame[[var]])` and find the level `l` such that `paste0(var_name, l) == coef_name`." Effort: low, Risk: none.
- **[B]** Specify: "Level names are recovered by stripping the variable name prefix: `sub(paste0('^', var_name), '', coef_name)`. Document that variable names that are prefixes of level names produce incorrect output." Effort: trivial, Risk: high (silent wrong output for edge cases).
- **[C] Do nothing** — implementers will use string prefix removal; breaks for variable-name-is-prefix-of-level edge case.

**Recommendation: [A]** — The model frame is already required for reference level detection; using it for all label recovery is consistent and unambiguous.

---

**Issue 44: Quality gate uses wrong meta key name `variable_labels` instead of `variables`**
Severity: REQUIRED
Factual error; quality gate cannot be satisfied as written.

Section XI (quality gates) includes:

> `[ ] meta(clean(fit))$variable_labels populated from design metadata`

But Section 6.3 explicitly states:

> "`$variables` replaces the flat `variable_labels` key from Phase 1 `survey_result` objects. The `variable_labels` key is **not** present in `survey_glm_tidy` `.meta`."

A developer checking off quality gates will write a test that looks for `meta(result)$variable_labels` — a key the spec says does not exist. The test will always fail. The correct key is `meta(result)$variables`.

Options:
- **[A]** Replace the quality gate line: "`meta(clean(fit))$variables` is populated with one named entry per predictor; each entry has `var_label`, `var_class`, `var_type`, and optionally populated `value_labels`." Effort: trivial.
- **[B] Do nothing** — quality gate refers to a non-existent key; developers write failing tests.

**Recommendation: [A]** — One-line fix that prevents a confusing quality gate failure.

---

#### Section IV: `survey_glm()` Function

**Issue 43: Zero-weight rows in design data: behavior undefined**
Severity: REQUIRED
Violates Lens 4 (edge case: zero-weight rows in `@data` not addressed).

Section 4.4 Step 3 checks for `NA` weights and errors with `surveycore_error_na_weights` (P2-11). But zero or negative weights are not addressed. `stats::glm()` accepts zero-weight rows and treats them as excluded observations (same as `na.omit` on that row). Negative weights are unlikely to be valid but `stats::glm()` may not error on them.

The Phase 0 constructors validate that weights are positive (`surveycore_error_weights_nonpositive`). But after construction, `surveytidy::mutate()` can modify weight columns, potentially introducing zero-weight rows. `survey_glm()` is documented to accept any `survey_base` design — it cannot assume constructor-level guarantees hold.

If `survey_glm()` silently passes zero-weight rows to `stats::glm()`, those rows are excluded from fitting and from variance computation. Users may not realize this is happening. The spec should state explicitly what happens.

Options:
- **[A]** Add to Section 4.4 Step 3 (after the NA weights check): "Also check for zero or negative weights. If any weights are ≤ 0, warn with `surveycore_warning_nonpositive_weights` and proceed (matching base R `glm()` behavior of treating zero-weight rows as excluded). Add to Section 4.7 and Section X." Effort: low.
- **[B]** Add to Step 3: "Validate that no survey weights are ≤ 0; error with `surveycore_error_weights_nonpositive` (reuse Phase 0 definition) if any are found." Effort: low, Risk: medium (breaks code that relies on zero-weight-as-exclusion pattern).
- **[C]** Explicitly state: "`survey_glm()` relies on the design constructor's weight validation. Non-positive weights are considered a pre-condition violation; behavior is undefined." Effort: trivial — just document the assumption.
- **[D] Do nothing** — users get silent exclusion of zero-weight rows; no diagnostic.

**Recommendation: [A]** — A warning is less surprising than an error (users may intentionally use zero-weight rows as a soft exclusion), and more informative than silent behavior.

---

#### Cross-Cutting

**Issue 45: `confint()` error for invalid `parm` argument not specified**
Severity: SUGGESTION
Minor contract gap.

Section 5.8 specifies `parm` as "coefficient names (character) or integer indices. If omitted, all coefficients are returned. Same semantics as `stats::confint()`." But it doesn't say what happens when `parm` contains names not in `names(object@coefficients)` or indices out of range.

The delegation is to `sqrt(diag(object@vcov)[parm])`. If `parm` is an invalid name, this produces `NA` silently. If `parm` is an out-of-range index, `diag(object@vcov)[parm]` may return `NA` or throw a subscript error depending on R version.

Options:
- **[A]** Add: "If `parm` contains names absent from `names(object@coefficients)`, the invalid names are ignored and only matching names are returned — matching base R `confint.default()` behavior." Effort: trivial.
- **[B] Do nothing** — base R's confint behavior applies; acceptable for a delegation method.

**Recommendation: [B]** — Standard R delegation behavior is acceptable; over-specifying may over-constrain the implementation.

---

**Issue 46: Ordered factor `.L`/`.Q`/`.C` suffix stripping algorithm ambiguous**
Severity: SUGGESTION
Minor gap for an uncommon case.

Section 6.3 `variable` column description: "For ordered factor polynomial contrasts: the variable name without the `.L`/`.Q`/`.C` suffix." R uses `contr.poly` for ordered factors, generating names like `age.L`, `age.Q`, `age.C` for a 3-level ordered factor. But for more than 4 levels, R may generate additional contrast names (`age^4`, `age^5`, etc.) that don't follow the `.L`/`.Q`/`.C` pattern. The spec's stripping rule doesn't handle these.

Options:
- **[A]** Specify: "Strip trailing `.L`, `.Q`, `.C`, or `^N` (where N is an integer) from the coefficient name to recover the variable name for polynomial contrasts." Effort: low.
- **[B] Do nothing** — ordered factors with >4 levels are rare; the edge case is SUGGESTION-level.

**Recommendation: [B]** — Acceptable for a SUGGESTION; implementation can handle the common cases and fail gracefully for exotic polynomial contrasts.

---

### Updated Summary

#### Round 1 Issues (1–30) — All Resolved
All 30 issues from 2026-02-25 are resolved. Decisions recorded in `plans/claude-decisions-phase-2.md`.

#### Round 2 Issues (31–38) — All Resolved
All 8 issues from 2026-02-27 (Round 2, v0.3 spec) are resolved. Decisions recorded in `plans/claude-decisions-phase-2.md`.

#### Round 3 Issues (39–46)

| # | Section | Title | Severity |
|---|---|---|---|
| 39 | VIII/IX | Test plan missing for all 12 expanded S3 methods (Sections 5.8–5.19) | BLOCKING |
| 40 | VIII | `surveycore_error_predict_no_fit` untested for 6 additional call sites | REQUIRED |
| 41 | VI | `print(clean(fit))` output format not shown or specified | REQUIRED |
| 42 | VI | `label` column stripping algorithm for factor dummy names unspecified | REQUIRED |
| 43 | IV | Zero-weight rows in design data: behavior undefined | REQUIRED |
| 44 | XI | Quality gate uses wrong meta key `variable_labels` instead of `variables` | REQUIRED |
| 45 | V | `confint()` error for invalid `parm` argument unspecified | SUGGESTION |
| 46 | VI | Ordered factor `.L`/`.Q`/`.C` stripping algorithm ambiguous | SUGGESTION |

| Severity | Round 1 | Round 2 | Round 3 |
|---|---|---|---|
| BLOCKING | 7 (resolved) | 1 (resolved) | 1 |
| REQUIRED | 19 (resolved) | 4 (resolved) | 4 |
| SUGGESTION | 3 (resolved) | 2 (resolved) | 2 |

**Total new issues (Pass 3):** 7 (one BLOCKING, four REQUIRED, two SUGGESTION)

**Overall assessment:** The v0.6 spec is close but not yet implementation-ready. The one blocking gap — no test plan for the 12 expanded S3 methods added in Round 2 — is a direct consequence of those methods being added to the spec without updating the test plan section. The four REQUIRED issues are tight, localized, and low-effort to resolve (wrong meta key in quality gate; missing `label` algorithm; unspecified print format; undefined zero-weight behavior). Two rounds of improvements have substantially strengthened this spec; one more targeted editing pass will close the remaining gaps.

---

## Spec Review: phase-2 — Pass 4 (2026-03-08)

**Reviewer:** Claude (adversarial batch pass — fourth pass)
**Spec version:** 1.0 — "Methodology-locked — ready for Stage 3 code/architecture review"

### Prior Issues (Pass 3)

| # | Title | Status |
|---|---|---|
| 39 | Test plan missing for all 12 expanded S3 methods (Sections 5.8–5.19) | ✅ Resolved — items 17–36 added to `test-glm-methods.R` plan |
| 40 | `surveycore_error_predict_no_fit` untested for 6 additional call sites | ✅ Resolved — dual-pattern items added per method |
| 41 | `print(clean(fit))` output format not shown or specified | ✅ Resolved — Section 6.6 added with verbatim example |
| 42 | `label` column stripping algorithm for factor dummy names unspecified | ✅ Resolved — model-frame lookup algorithm specified |
| 43 | Zero-weight rows in design data: behavior undefined | ✅ Resolved — `surveycore_warning_nonpositive_weights` added |
| 44 | Quality gate uses wrong meta key `variable_labels` instead of `variables` | ✅ Resolved — quality gate updated to `$variables` |
| 45 | `confint()` error for invalid `parm` unspecified | ✅ Resolved — delegated to base R behavior (SUGGESTION accepted as-is) |
| 46 | Ordered factor `.L`/`.Q`/`.C` stripping algorithm ambiguous | ✅ Resolved — recommendation B accepted (SUGGESTION deferred) |

---

### New Issues

#### Section III / IX: `survey_glm_fit` Class + Testing Strategy

**Issue 47: No `test_glm_fit_invariants()` helper defined for `survey_glm_fit` objects**
Severity: REQUIRED
Violates testing-surveycore.md (invariant checker pattern) and engineering-preferences.md §2 (more tests is better).

Section 9.3 defines `test_glm_tidy_invariants()` as the **first assertion** in every `clean()` happy-path test block. This is the established surveycore pattern for domain objects. But `survey_glm_fit` — the output of `survey_glm()` — has no analogous helper.

Section 9.2, test-glm.R item 1 says: "basic call produces a valid `survey_glm_fit`; verify key properties (coefficients length, vcov dimension, converged = TRUE, degf > 0)." These inline checks duplicate invariant logic that will be scattered across every construction test block rather than centralized in a helper.

The structural invariants for `survey_glm_fit` are already defined in Section 3.3 (the S7 validator). A `test_glm_fit_invariants(fit)` helper — analogous to `test_glm_tidy_invariants()` — would:
1. Centralize property checks that must hold for every valid `survey_glm_fit`
2. Ensure consistent invariant coverage across all construction test blocks
3. Make it obvious when a new test block fails to check required structure

Options:
- **[A]** Add a Section 9.3a defining `test_glm_fit_invariants(fit)` with at least: `expect_true(S7::S7_inherits(fit, survey_glm_fit))`, `expect_true(length(fit@coefficients) > 0)`, `expect_identical(dim(fit@vcov), c(p, p))` where `p = length(fit@coefficients)`, `expect_gt(fit@degf, 0)`, `expect_type(fit@converged, "logical")`, `expect_true(inherits(fit@formula, "formula"))`. Specify it as the first assertion in every `survey_glm()` happy-path test block. Effort: low, Risk: none, Impact: consistent invariant coverage.
- **[B] Do nothing** — each test block checks properties inline; coverage exists but is inconsistent.

**Recommendation: [A]** — The `test_glm_tidy_invariants()` pattern was added specifically to avoid scattered inline checks. `survey_glm_fit` deserves the same treatment.

---

**Issue 48: `summary()` with `fit_` = NULL not in Section X error table or test plan**
Severity: REQUIRED
Violates Lens 2 (error paths) and Lens 3 (contract completeness).

Section 5.2.2 states: "Requires `model@fit_` to be non-`NULL`; if `NULL`, `summary()` errors with `surveycore_error_predict_no_fit`."

Two gaps follow from this:

1. **Section X error table (P2-14)** currently reads: "`predict.survey_glm_fit()` | `fit_` is NULL | ERROR | `surveycore_error_predict_no_fit`." The call site in `summary()` is not listed. Since `summary()` is a separate S3 method, its `fit_`-is-NULL path is effectively undocumented in the error table.

2. **Test plan** (Section 9.2, test-glm-methods.R) has item 2: "`summary()` — produces output (structural, not numerical); returns `survey_glm_summary` class." No item covers `summary(fit_with_null_fit_)`.

Per `testing-standards.md §2`: "every typed error class gets a test." `surveycore_error_predict_no_fit` from `summary()` is an untested error path.

Options:
- **[A]** Add to Section X: a row for `summary.survey_glm_fit()` | `fit_` is NULL | ERROR | `surveycore_error_predict_no_fit` (note: same class as P2-14, shared across call sites). Add a test plan item to test-glm-methods.R: "`summary()` with `fit_` = NULL — errors with `surveycore_error_predict_no_fit` (dual pattern: `class=` + `expect_snapshot(error = TRUE)`)." Effort: low.
- **[B]** Add a note to P2-14 in Section X: "Also thrown by `summary()`, `terms()`, `model.matrix()`, `model.frame()`, `hatvalues()`, `logLik()`, `AIC()`, `BIC()` when `fit_` is NULL." Add a single catch-all test. Effort: trivial.

**Recommendation: [A]** — Explicit per-method test items prevent the coverage ambiguity that round 3 Issue 40 was introduced to fix.

---

#### Section V / X: S3 Methods + Error Table

**Issue 49: `confint()` error `surveycore_error_invalid_conf_level` missing from Section X error table**
Severity: REQUIRED
Violates Lens 3 (contract completeness — all errors must appear in the error table).

Section 5.8 specifies: "`level` must be in `(0, 1)`. Invalid `level` errors with `surveycore_error_invalid_conf_level` (reuse Phase 1 definition)."

Section 6.5 (clean() error table) lists: "P2-13 | `conf_level` invalid | ERROR | `surveycore_error_invalid_conf_level`."

Section X error table also lists P2-13 for `clean()` only.

`confint.survey_glm_fit()` fires the same error class but it appears in neither Section 6.5 nor Section X. An implementer reading the error tables to understand all call sites for this error class will miss `confint()`. The test plan (item 19) correctly has this test — but it has no corresponding error table entry.

Options:
- **[A]** Add a row to Section X: "`confint.survey_glm_fit()` | `level` not in (0, 1) | ERROR | `surveycore_error_invalid_conf_level` (reuse Phase 1 definition; same class as P2-13)." Effort: trivial.
- **[B]** Extend P2-13's "Function" column to list both `clean()` and `confint.survey_glm_fit()`. Effort: trivial.

**Recommendation: [A]** — Each error table row maps one function+condition pair; one entry per call site keeps auditing clear.

---

#### Section V: `predict.survey_glm_fit()`

**Issue 50: `predict(new_data = NULL, type = "link")` contract not verified in test plan**
Severity: REQUIRED
Violates Lens 2 (behavioral branches must be covered) and Lens 6 (API coherence — type is silently ignored in early spec versions; the fix must be tested).

Issue 15 (Round 1, now resolved) identified that when `new_data = NULL` and `type != "response"`, the original spec silently ignored `type` and always returned response-scale values. The fix was to delegate to `stats::predict(object@fit_, type = type)` for all non-NULL and NULL `new_data` cases.

The current spec (Section 5.5) defines `type` as controlling the scale of predictions with values `"response"`, `"link"`, and `"terms"`. But the test plan items for `predict()` are:
- Item 5: "`predict(newdata = NULL)` — returns fitted values" (no `type` specified; implies `"response"` only)
- Item 6: "`predict(newdata = df)` — returns numeric vector of correct length" (no `type` specified)

Neither item tests `type = "link"` or `type = "terms"`. The fix for Issue 15 introduced two code paths that neither of these items exercises. Without tests for non-response `type`, the fix can silently regress.

Options:
- **[A]** Add to Section 9.2 test-glm-methods.R:
  - After item 5: "`predict(new_data = NULL, type = 'link')` — returns link-scale values (same as `predict(object@fit_, type = 'link')`); differs from response-scale for binomial/Poisson families."
  - After item 6: "`predict(new_data = df, type = 'terms')` — returns a matrix with one column per model term."
  Effort: low.
- **[B]** Amend item 5: "returns fitted values on the correct scale for each `type` value." Effort: trivial but underspecified.

**Recommendation: [A]** — The `"link"` path is the exact fix from Issue 15; it deserves an explicit test.

---

#### Section V / VI: DRY

**Issue 51: `confint()` and `clean()` independently implement the same CI formula**
Severity: REQUIRED
Violates engineering-preferences.md §1 (DRY — highest priority; repeated logic in two functions).

Both `confint.survey_glm_fit()` (Section 5.8) and `clean()` (Section 6.3) compute confidence intervals using the identical formula:

```
estimate ± qt((1 + level) / 2, df = model@degf - (p - 1)) * se
```

Section 5.8 says the two "must produce identical numerical results for equivalent `conf_level` / `level` values." This promise cannot be enforced by tests alone — if one implementation has a typo (e.g., `model@df_residual` instead of `model@degf - (p - 1)`) and the other is correct, the test plan has no oracle to compare them against each other.

The right fix is a shared internal helper `.glm_confint(coefs, vcov, degf, level, parm)` called by both `confint()` and `clean()`. The spec currently describes two separate implementations. DRY violations in the spec lead to DRY violations in the code.

Options:
- **[A]** Add `.glm_confint(estimates, se, degf_design, n_coef, level, parm = NULL)` to Section 2.2 internal helpers. Specify that it computes `estimate ± qt((1 + level)/2, df = degf_design - (n_coef - 1)) * se` and returns a two-column matrix with row names from `parm`. Both `confint.survey_glm_fit()` and `clean()` call this helper. Effort: low, Risk: none, Impact: single implementation of the CI formula; the "must match" promise becomes a structural guarantee.
- **[B]** Add a cross-reference: "The CI formula used in `clean()` (Section 6.3) is identical to the one in `confint()` (Section 5.8). Implementations must use the same helper or be numerically verified against each other in tests." Leave implementation to the coder. Effort: trivial.
- **[C] Do nothing** — two separate CI implementations; a typo in one is undetectable without a cross-function oracle test.

**Recommendation: [A]** — engineering-preferences.md §1 is explicit: "Duplicated logic is a bug waiting to happen." Two functions that describe the same formula should share a helper. This is DRY, not over-engineering.

---

#### Section IX / test-glm-methods.R: Test Completeness

**Issue 52: `print.survey_glm_summary()` has no snapshot test**
Severity: REQUIRED
Violates Lens 2, category 13 (Print snapshot required for every result class with a `print()` method).

`survey_glm_summary` is an S3 class returned by `summary.survey_glm_fit()`. Section 5.2.2 defines `print.survey_glm_summary()` and shows its exact verbatim output format. Per the review instruction: "Print snapshot — required for every result class that has a `print()` method."

The test plan has:
- Item 1 in test-glm-methods.R: snapshot for `print(fit)` (the model object) ✅
- Item 17 in test-glm-methods.R: snapshot for `print(clean(fit))` (the tidy result) ✅

But there is no item for `print(summary(fit))` (the `survey_glm_summary` object). The output format is fully specified in Section 5.2.2 — a snapshot test is both possible and required.

Options:
- **[A]** Add a test plan item to test-glm-methods.R between current items 2 and 3: "`print(summary(fit))` — snapshot of `print.survey_glm_summary()` output matches expected format (Section 5.2.2); returns `invisible(x)`." Effort: low.
- **[B] Do nothing** — the print format is specified but never snapshot-tested; regressions in the summary output format are silent.

**Recommendation: [A]** — Three result classes (fit, tidy, summary) each have a `print()` method; all three must have snapshot tests.

---

#### Section II: Internal Helpers (Suggestions)

**Issue 53: `set_coef()` "bypasses the S7 validator" claim is technically incorrect**
Severity: SUGGESTION
Misleading description; may cause implementer confusion.

Section 7.4 states: "**Validity:** `set_coef` bypasses the S7 validator. The perturbed object it returns is not a valid `survey_glm_fit` for inference — its `@vcov` is stale relative to the new `@coefficients`."

S7 property assignments via `@<-` trigger the class validator. The assignment `model@coefficients <- coefs` in `set_coef` DOES trigger the S7 validator. The validator checks: same `p = length(self@coefficients)`, same `vcov` dimensions (p × p), etc. — all structural invariants. Since marginaleffects perturbs coefficient values without changing their count, the structural validator passes.

The semantic invalidity (stale `@vcov`) is different from bypassing the validator. The current phrasing implies the implementer needs to find a way to bypass S7's validation mechanism — which is not true. The correct statement is: "The S7 validator runs normally but only checks structural invariants (dimensions, types). Semantic validity (vcov consistent with coefficients) is not enforced by the validator; the returned object has structurally valid but semantically stale vcov."

Options:
- **[A]** Replace the Validity note with: "The S7 validator runs normally on `model@coefficients <- coefs` but only enforces structural invariants (dimensions, types). The returned object is structurally valid but semantically stale (`@vcov` was computed for the original `@coefficients`). This is intentional: marginaleffects uses the perturbed object only for numerical differentiation, never for inference." Effort: trivial.
- **[B] Do nothing** — developer will discover the correct behavior empirically; not a blocking gap.

**Recommendation: [A]** — One sentence clarification prevents a potentially wasted investigation into S7 validator bypass mechanisms.

---

**Issue 54: `n_weighted` computation source not specified**
Severity: SUGGESTION
Minor contract gap; leaves one `.meta` value's derivation implicit.

Section 6.3 defines `n_weighted` as "Sum of survey weights for in-model observations (after `na.action`)." The source data is unambiguous conceptually but the implementation detail is not stated: which vector is summed?

The candidates are:
1. `sum(model.frame(fit)$"(weights)")` — weights as seen by the GLM model frame
2. `sum(design@data[[design@variables$weights]][in_model_rows])` — survey weights column in design data, subset to rows not dropped by `na.action`

Both should give the same result for non-domain designs, but may differ when rows are excluded. Option 1 is more robust (the GLM's model frame is the canonical record of what was fitted) and is already accessible via `model@fit_`.

Options:
- **[A]** Add to Section 6.3 `n_weighted` description: "Computed as `sum(model.frame(model@fit_)$'(weights)')` — the sum of survey weights in the final model frame after domain filtering and `na.action`." Effort: trivial.
- **[B] Do nothing** — derivable by a competent implementer; edge cases only matter when rows are dropped.

**Recommendation: [B]** — Acceptable implementation latitude; the conceptual definition is clear.

---

**Issue 55: `lapply()` state leakage test (Section 9.4) not mapped to a numbered test plan item**
Severity: SUGGESTION
Orphaned test requirement; may be skipped during implementation.

Section 9.4 edge cases include: "`survey_glm()`: programmatic interface is suitable for `lapply()`/`purrr::map()` iteration over outcome variables (verify no state leakage across calls)."

Section 9.2 (the numbered test plan for test-glm.R) has item 7 covering the programmatic interface, but no item for the `lapply()` state leakage check. Edge cases from Section 9.4 that are not mirrored in the Section 9.2 numbered plan may be missed during implementation because the numbered plan is what engineers use as a checklist.

Options:
- **[A]** Add to Section 9.2 test-glm.R: "7b. **Programmatic interface — `lapply()` iteration** — run `lapply(c('y1', 'y2'), function(v) survey_glm(d, response = v, predictors = 'x1'))` and verify each result is an independent `survey_glm_fit` with the correct `@formula`; check that `coef(results[[1]])` differs from `coef(results[[2]])` when the outcomes have different means." Effort: low.
- **[B] Do nothing** — item 7 covers the programmatic interface; state leakage test is implicit.

**Recommendation: [A]** — State leakage across `lapply()` calls is a real risk when global state or environment closures are used incorrectly. An explicit test item makes the expectation concrete.

---

### Summary (Pass 4)

#### Prior Issues Status

| Round | Total Issues | Status |
|---|---|---|
| Round 1 (Issues 1–30) | 30 | ✅ All resolved |
| Round 2 (Issues 31–38) | 8 | ✅ All resolved |
| Round 3 (Issues 39–46) | 8 | ✅ All resolved |

#### New Issues (Pass 4)

| # | Section | Title | Severity |
|---|---|---|---|
| 47 | IX | No `test_glm_fit_invariants()` helper for `survey_glm_fit` objects | REQUIRED |
| 48 | V / X | `summary()` with `fit_` = NULL not in error table or test plan | REQUIRED |
| 49 | V / X | `confint()` error `surveycore_error_invalid_conf_level` missing from Section X | REQUIRED |
| 50 | V / IX | `predict(new_data = NULL, type = "link")` not in test plan | REQUIRED |
| 51 | II / V / VI | DRY: `confint()` and `clean()` implement same CI formula independently | REQUIRED |
| 52 | IX | `print.survey_glm_summary()` snapshot test missing from test plan | REQUIRED |
| 53 | VII | `set_coef()` "bypasses validator" description technically incorrect | SUGGESTION |
| 54 | VI | `n_weighted` computation source not specified | SUGGESTION |
| 55 | IX | `lapply()` state leakage test not in numbered test plan items | SUGGESTION |

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 6 |
| SUGGESTION | 3 |

**Total new issues (Pass 4):** 9 (zero blocking, six required, three suggestions)

**Overall assessment:** The v1.0 spec is nearly implementation-ready. Three rounds of review have eliminated all blocking gaps. The six REQUIRED issues are localized and low-effort: two test plan omissions (`summary()` NULL-fit and `predict()` type), two error table gaps (`summary()` and `confint()`), one missing invariant helper, and one DRY violation in the CI formula. The DRY issue (Issue 51) is the most substantive — two separate CI implementations are a maintenance risk that a shared helper eliminates cleanly. Resolving all six REQUIRED items in Stage 4 will produce a spec ready for the implementation plan.

