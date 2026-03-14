# Adversarial Methodological Review — surveycore Phase 2 (spec v0.8)

**Reviewer:** Claude (senior survey methodologist / statistician role)
**Date:** 2026-03-07
**Spec version reviewed:** v0.8 (`plans/spec-phase-2.md`)
**Status:** Pre-implementation — must be resolved before implementation plan is drafted

---

## BLOCKING Issues — Will produce wrong estimates or invalid inference

---

### BLOCKING-1: Information matrix specification is wrong for non-Gaussian families (Section 8.2)

**Location:** Section 8.2 — "where `I = (1/n) X'WX` is the (rescaled) information matrix"

**Problem:** The spec defines `I = (1/n) X'WX` where `W = diag(w_i)` is the diagonal matrix of *survey weights* only. For the Binder (1983) sandwich, the bread must be the *inverse of the IRLS information matrix*, not the inverse of the survey-weighted cross-product.

The correct Hessian of the weighted log-likelihood for a GLM is:

```
J = Σ_i w_i * [μ̇_i² / V(μ_i)] * x_i x_i'
```

where `μ̇_i = dμ/dη_i`. For Gaussian/identity: `μ̇ = 1`, `V(μ) = 1`, so `J = X'WX`. For binomial/logit: `μ̇_i = p̂_i(1-p̂_i)` and `V(μ_i) = p̂_i(1-p̂_i)`, so `J = Σ w_i p̂_i(1-p̂_i) x_i x_i' = X' W̃ X` where `W̃ ≠ W`.

The spec's `I = X'WX/n` equals `J/n` only for Gaussian. For binomial and Poisson, `X'WX` (survey weights only) is the wrong matrix, and `(X'WX/n)⁻¹` inflates every standard error by a factor that varies across observations.

In practice, `survey::svyglm` uses the `cov.unscaled` slot from `summary.glm()`, which is `(X'W̃X)⁻¹` from the final IRLS step — accessible as `summary(fit)$cov.unscaled`. This is what the spec must specify.

**Why it matters:** The oracle comparison for binomial and Poisson families would fail against `survey::svyglm()`. Any implementation following the spec as written would produce SEs that are incorrect for every family except Gaussian. This is the most common use case: logistic regression on binary outcomes.

**Resolution:** Replace `I = (1/n) X'WX` throughout Section 8.2 and `.glm_sandwich_vcov()` with:

```r
# Bread: IRLS information matrix inverse (family-aware)
bread <- summary(fit)$cov.unscaled  # = (X'W̃X)^{-1}, correct for all families
Var(β̂) = bread %*% meat %*% bread
```

Document that `summary(fit)$cov.unscaled` is `(X'W̃X)⁻¹` where `W̃` uses IRLS working weights incorporating both the survey weights and the variance function. Confirm that the formula is then `Var(β̂) = (X'W̃X)⁻¹ · Var_design(T) · (X'W̃X)⁻¹`.

---

### BLOCKING-2: SRS variance formula is only valid for Gaussian (Section 8.4)

**Location:** Section 8.4 — "Weighted OLS formula: `Var(β̂) = σ̂² · (X'WX)⁻¹`"

**Problem:** `σ̂² (X'WX)⁻¹` is the weighted OLS formula for Gaussian regression. The spec claims it "follows from the general Binder sandwich" for SRS, but this derivation only holds under Gaussian where `Var_design(T) = σ̂² X'WX`. For binomial or Poisson with SRS sampling:

```
Var_design(Σ u_i) ≈ σ²_u X'WX    ← only if u_i = w x_i (y_i - μ_i) residuals are Gaussian
```

For logistic SRS, working residuals `r_i = (y_i - p̂_i)/(p̂_i(1-p̂_i))` produce a score whose design variance has a completely different structure.

The spec simultaneously requires oracle tests for all 8 families on `survey_srs` designs (quality gate: "all 8 GLM families... oracle tests"), but the implemented formula would produce wrong SEs for 6 of those 8 families on SRS designs.

**Why it matters:** An SRS binomial or Poisson model using the spec's formula would silently produce incorrect standard errors. The oracle test for those families on SRS designs would fail.

**Resolution:** The SRS path should use the same score-based sandwich as Taylor, except using the SRS formula for the design variance of the score total. Specifically: compute `.glm_score()`, then compute `Var_design(T)` using the standard SRS approximation `N²(1-f)/n * S²_u` (with `f = n/N`), or more simply: fall back to calling `.taylor_var_score_matrix()` with the `survey_srs` design (letting the Taylor machinery handle the simplified SRS case). The analytic formula `σ̂² (X'WX)⁻¹` should only be used for Gaussian, or removed entirely in favor of the unified score-based path.

---

### BLOCKING-3: `summary()` labels working residuals as "Deviance Residuals" (Section 5.2, 5.2.2)

**Location:** Section 5.2 — "Deviance residuals are computed from the working residuals stored in `model@residuals` (five-number summary via `fivenum()`)"

**Problem:** Working residuals and deviance residuals are different quantities for every non-Gaussian family:

| Family | Working residual `r_i` | Deviance residual |
|--------|------------------------|-------------------|
| Gaussian | `y_i - μ̂_i` | `y_i - μ̂_i` (same) |
| Binomial | `(y_i - p̂_i) / (p̂_i(1-p̂_i))` | `±sqrt(-2 * log-lik contribution)` |
| Poisson | `(y_i - λ̂_i) / λ̂_i` | `sign(y_i - λ̂_i) * sqrt(2(y log(y/λ̂) - (y-λ̂)))` |

Showing a five-number summary of working residuals labeled "Deviance Residuals" will mislead users: the scale and interpretation are entirely different. For logistic regression the displayed "residuals" would routinely exceed ±10 (logit scale) while true deviance residuals are bounded near 0.

`summary.glm()` correctly computes deviance residuals via `residuals(g, type="deviance")`. The spec should do the same.

**Why it matters:** This is a silent correctness error in the primary inference output, not just cosmetic. Users comparing outputs to `summary(svyglm(...))` would see numerically different residual summaries for any non-Gaussian family. Diagnostic interpretation of the residual distribution would be wrong.

**Resolution:** Replace `fivenum(model@residuals)` (working residuals) with `fivenum(residuals(model, type = "deviance"))` (true deviance residuals). This requires `@fit_` to be non-`NULL`. Add `surveycore_error_predict_no_fit` as a possible error for `summary()` when `@fit_` is `NULL`, or pre-compute deviance residuals and store them as an `@deviance_residuals` property at construction time.

---

### BLOCKING-4: `residuals(type = "response")` requires `y`, which is not stored (Section 5.7)

**Location:** Section 5.7 — "`"response"` — `y - fitted_values` (on response scale)"

**Problem:** The S7 object stores `@fitted_values` but not the original response vector `y`. Computing `y - fitted_values` requires extracting `y` from somewhere. The two options are:

1. `model.response(model.frame(fit))` — requires `@fit_` to be non-`NULL`
2. A stored `@response` property

The spec does NOT list `@fit_` as a requirement for `type = "response"` in Section 5.7. It only lists `fit_` as required for `"pearson"`, `"deviance"`, and `"partial"`. But `type = "response"` cannot be computed without it (or a stored response vector).

There is a secondary issue: for in-formula transforms like `log(y) ~ x`, `model.response(model.frame(fit))` returns `log(y)`, not `y`. And `fitted_values` is on the response scale (`y`, not `log(y)`) because it was back-transformed via `predict(type="response")`. So `y - fitted_values` would require `y` on the *response* scale, not the *model frame* scale.

**Why it matters:** `residuals(fit, type = "response")` is the most commonly requested residual type. Any call on an object where `@fit_` is `NULL` would error silently or produce a confusing error. For log-transformed responses, the implementation would produce wrong residuals.

**Resolution:** Either: (a) add a `@response` property to `survey_glm_fit` storing the original response vector (on the untransformed scale) at construction time, or (b) explicitly add `@fit_` as a requirement for `type = "response"` in Section 5.7, and add the `surveycore_error_predict_no_fit` error path. Clarify what "response scale" means for transformed responses.

---

## REQUIRED Issues — Underspecified behavior that forces arbitrary implementation decisions

---

### REQUIRED-5: `@df_null` computation is never specified (Section 3.2, 5.2)

**Location:** Section 3.2 property table — "`df_null`: Degrees of freedom for the null model"

**Problem:** The spec lists `@df_null` as a property and shows it in the summary output ("Null deviance: 456.7 on 199 degrees of freedom (design-based)") but never says how to compute it. There are two entirely different values an implementer might choose:

- **`n - 1`** (from `fit$df.null` in the underlying `stats::glm()` result — classical)
- **`degf(design)`** (design-based df for the null/intercept-only model)

The summary output shows 199 for what appears to be a 200-row dataset — consistent with `n - 1`. But the label says "(design-based)", which suggests `degf(design)` (which for NHANES would be ~17, not 199). These are mutually incompatible.

**Why it matters:** An implementer cannot compute `@df_null` from the spec. Any choice is arbitrary. This also affects the `df_null` field of `survey_glm_summary` (Section 5.2.1).

**Resolution:** Specify explicitly: (a) `@df_null` comes from `fit$df.null` (the classical `n - 1`; `stats::glm()` stores this), and update the summary output example and labels to not say "(design-based)" for the null deviance line; or (b) define `@df_null = degf(design)` and update the example output accordingly. The former is consistent with `survey::svyglm()` behavior (which inherits `df.null` from the `glm` object).

---

### REQUIRED-6: `@df_residual` declared as `S7::class_integer` but computed from non-integer `degf()` (Section 3.1, 8.5)

**Location:** Section 3.1 class definition — `df_residual = S7::new_property(S7::class_integer)` vs Section 8.5 — `df_residual = degf(design) - (p - 1)`

**Problem:** `degf(design)` for replicate designs returns non-integer values. Subtracting `(p - 1)` (integer) from a non-integer produces a non-integer. Storing as `S7::class_integer` would silently truncate (via `as.integer()`), introducing rounding error in t-statistics and CI bounds. This contradicts `@degf` which is correctly declared as `S7::class_numeric`.

There is also a secondary inconsistency: `@df_null` is `S7::class_integer` for the same reason.

**Resolution:** Change `df_residual` and `df_null` properties to `S7::class_numeric` throughout the S7 class definition. Update the validator to check `self@df_residual > 0` (already done) without requiring integer type.

---

### REQUIRED-7: Reference row `term` column — spec body contradicts decisions log (Section 6.3 vs decisions log, Issue 18)

**Location:** Section 6.3 `term` column description vs. decisions log entry for Issue 18

**Problem:** Section 6.3 says: "Reference rows use the bare factor-level term (e.g. `"sexFemale"`); reference information is encoded in `reference_row`, not in a `[ref]` suffix."

The decisions log (Issue 18) says: "`paste0(var_name, ref_level, ' [ref]')` where `ref_level = setdiff(levels(col), colnames(contrasts(col)))`" — explicitly including a `[ref]` suffix.

These are mutually exclusive. The decisions log records a decision to use `[ref]`; the spec body says do not use `[ref]`. One of them was presumably updated after the other, but both survive in the document set.

**Why it matters:** This is a test-blocking ambiguity: any snapshot test of `clean()` output will encode one convention or the other. The implementer must pick one, and whichever they pick, either the spec body or the decisions log will be wrong.

**Resolution:** Confirm which is canonical (the spec body, since it supersedes the decisions log) and update the decisions log to note that Issue 18's `[ref]` suffix decision was subsequently reversed in v0.8. Add a cross-reference in Section 6.3 noting this reversal explicitly.

---

### REQUIRED-8: Replicate domain estimation mechanism is ambiguous and contradictory (Section 4.5)

**Location:** Section 4.5 — "Replicate variance applies the same indicator to replicate-weight refits: refit on in-domain rows, set `u_i = 0` for out-of-domain rows when computing deviations."

**Problem:** The sentence contains two incompatible descriptions:

1. "Refit on in-domain rows" — the replicate GLM is fitted only on the domain subset (correct replicate domain estimation)
2. "Set `u_i = 0` for out-of-domain rows when computing deviations" — there are no `u_i` in replicate variance estimation; the deviation is `β̂_r - β̂`, a scalar difference at the coefficient level

Phrase (2) is Taylor-variance language applied incorrectly to replicate variance. For replicate variance, `β̂_r` is already implicitly "zero contribution from out-of-domain rows" because the GLM is refit on in-domain rows. There is nothing to zero out.

Additionally, the spec does not address what happens when domain restriction produces near-empty cells in some replicates (e.g., a small subgroup where certain replicates have 0 or 1 in-domain observations). This can produce non-convergence in the replicate refit.

**Why it matters:** An implementer reading this might introduce a spurious masking step that is either a no-op or actively wrong for replicate variance. The non-convergence edge case is unhandled.

**Resolution:** Replace the second sentence with: "For replicate designs, the GLM is refit using only in-domain rows with each replicate weight set. The deviation `d_r = β̂_r - β̂` is then computed as usual. No additional masking is needed." Add a note: if a replicate refit on in-domain rows fails to converge, warn with `surveycore_warning_glm_convergence` and use `β̂_r = β̂` (zero deviation) for that replicate, consistent with the Phase 0 replicate variance convention.

---

### REQUIRED-9: `cbind()` LHS error detection mechanism is wrong (Section 4.4, Step 1)

**Location:** Section 4.4 — "Specifying `cbind(y1, y2) ~ x` will error with `surveycore_error_response_not_found` for `y2` or similar"

**Problem:** `all.vars(cbind(y1, y2))` returns `c("y1", "y2")`. If both `y1` and `y2` exist in `design@data`, no `response_not_found` error fires. The spec says "or similar" which acknowledges uncertainty, but the described mechanism is wrong.

The actual error, if the user specifies `cbind(y1, y2) ~ x`, would be from `stats::glm()` itself — either a "non-numeric argument" error or it would attempt to fit a multinomial model and fail with a different message. The typed error `surveycore_error_response_not_found` would not be triggered.

**Why it matters:** The spec claims a specific typed error fires for a specific user action, but it would not fire. Users who accidentally supply a `cbind()` LHS would receive a cryptic base R error instead of the promised typed surveycore error.

**Resolution:** Add an explicit pre-check in Step 1: after extracting `all.vars(formula[[2]])`, check whether the formula's LHS is a `call` object (vs a `name`), and specifically whether it is a `cbind()` call via `identical(formula[[2]][[1]], quote(cbind))`. If so, error with a new class `surveycore_error_cbind_response_unsupported`. Do not claim `surveycore_error_response_not_found` fires for this case.

---

### REQUIRED-10: `na.action = na.fail` is specified as supported but has no test (Section 4.2, 9.2)

**Location:** Section 4.2 argument table — "`na.fail` errors on any `NA`"; Section 9.2/9.4 — no test for this behavior

**Problem:** `na.action = na.fail` is documented as a first-class option, but no test in the test plan (Sections 9.2, 9.4) covers: (1) that `na.fail` correctly errors when the response has `NA`s, or (2) that it errors when predictors have `NA`s. The 98%+ coverage requirement means this branch would be hit by an undocumented test, but the spec provides no guidance.

**Resolution:** Add an edge case item to Section 9.4: "`survey_glm()` with `na.action = na.fail` and a response containing `NA` — errors (the error is from base R `na.fail`, not a typed surveycore error; document this distinction in the roxygen `@param na.action`)."

---

### REQUIRED-11: Binomial family "non-integer successes" warning from `stats::glm()` is unhandled (Section 4.4)

**Location:** Section 4.4 Step 4; oracle tests Section 9.1

**Problem:** When survey weights are used with `family = binomial()`, `stats::glm()` internally computes weighted success counts that are non-integer, triggering: `"In eval(expr, p, parent) : non-integer #successes in a binomial glm!"`. This warning fires for virtually every real survey dataset with non-round weights and a binary outcome.

The spec acknowledges this in the oracle template: "survey::svyglm() is called with quasibinomial() to suppress the non-integer successes warning." But `survey_glm()` itself is called with `binomial()`. The spec does not say whether surveycore should: (a) suppress this warning, (b) re-emit it as a typed `surveycore_warning_*` class, or (c) pass it through as-is.

**Why it matters:** Users calling `survey_glm(design, outcome ~ predictors, family = binomial())` on any real survey dataset would see spurious warning messages from R's GLM internals that are irrelevant to survey-weighted regression. No guidance exists for how to handle or document this.

**Resolution:** Add to Step 4 of Section 4.4: "If `family` is `binomial()` or `quasibinomial()`, suppress the `'non-integer #successes'` warning from `stats::glm()` using `suppressWarnings()`, as survey weights invariably produce fractional weighted counts. Document this suppression in the roxygen `@details`."

---

### REQUIRED-12: `@df_residual` conflates design-based df (for t-tests) and classical df (for deviance display) (Section 8.5, 5.2)

**Location:** Section 8.5 — `df_residual = degf(design) - (p - 1)`; Section 5.2.2 summary output — "Residual deviance: 321.4 on 181 degrees of freedom"

**Problem:** The spec's single `@df_residual` property is used for two different purposes that require two different quantities:

- **t-tests and CIs:** `degf(design) - (p - 1)` — design-based. For NHANES with 3 predictors: ~16.
- **Deviance display in `summary()`:** `n - p` — classical. For a 200-row dataset with 3 predictors: 197.

The summary example shows 181 degrees of freedom for residual deviance — consistent with classical `n - p`, not design-based. `survey::svyglm()` handles this by inheriting `df.residual = n - p` from the `glm` object but using `degf(design) - (p-1)` for CIs and t-tests separately.

**Why it matters:** If `@df_residual` stores the design-based value (~16), the summary output will show the wrong (design-based) df next to deviance — confusing to users expecting classical output. If it stores classical `n - p`, CIs will be wrong (using 197 df instead of 16).

**Resolution:** Introduce two distinct quantities:
- `@df_residual`: from `fit$df.residual` (classical `n - p`) — stored in S7 object, shown in deviance display
- `@degf - (p - 1)`: computed inline in `confint()` and `clean()` using `model@degf` — used for t-tests and CIs, not stored separately

Update Section 3.1, 8.5, 5.8, and 6.3 to reflect this distinction.

---

## ADVISORY Issues — Edge cases that should be addressed but will not cause silent failures

---

### ADVISORY-13: `marginaleffects` AME SEs blend design-based and model-based variance — should be documented (Section 7.1, 7.5)

The `get_vcov` method returns the design-based `@vcov`, which marginaleffects uses to compute AME SEs via the delta method: `Var(AME) = J · Vcov(β̂) · J'`. This is methodologically valid and consistent with what `survey::svyglm` + `marginaleffects` would produce. But the resulting SEs are a hybrid: the variance of β̂ is design-based (correct), while the Jacobian J is computed numerically at a single point estimate (delta method approximation). This should be documented in the roxygen for the marginaleffects extension methods so users understand the provenance of AME SEs.

---

### ADVISORY-14: `@vcov` is not validated as positive semi-definite (Section 3.3)

The S7 validator checks dimensions but not PSD. For replicate variance with very few replicates or near-collinear predictors, it is possible to obtain a non-PSD `@vcov` from numerical issues in the quadratic form `Σ c_r d_r d_r'`. A non-PSD vcov produces `sqrt(diag(vcov)) = NaN` for some coefficients — confusing and silent. Consider adding a PSD check in the validator (e.g., `all(eigen(self@vcov)$values >= -1e-10)`) or at minimum in the quality gates.

---

### ADVISORY-15: `predict(se_fit = TRUE)` SEs are model-based, not design-based — asymmetry with `vcov()` (Section 5.5)

The `$se_fit` returned by `stats::predict.glm()` uses the model's own vcov (OLS/IRLS-based), not the design-based `@vcov`. This means `se_fit = TRUE` gives model-based prediction SEs while `vcov(fit)` gives design-based coefficient SEs — a potentially confusing asymmetry. The existing GAP note acknowledges design-based prediction intervals are Phase 3+, but should also explicitly note that `$se_fit` is model-based (not from `@vcov`) so users do not use it for design-based inference.

---

### ADVISORY-16: `logLik()` / `AIC()` / `BIC()` are model-based but `clean()` `.meta` implies completeness for inference (Section 5.17–5.18, 6.3)

The spec notes these are model-based, not design-adjusted (matching `survey::svyglm()`). But `clean()` includes `meta(result)$converged` and `meta(result)$n_observations`, which implies the `.meta` structure is intended to give users enough context for correct inference. A model-based AIC from a survey-weighted GLM is not a valid model selection criterion (the log-likelihood does not account for design variance). Consider adding a documentation note in the `clean()` roxygen warning that AIC/BIC should not be used for model selection without design-aware penalization.

---

## Summary: The 3 Highest-Risk Gaps

**1. Wrong information matrix for non-Gaussian families (BLOCKING-1 + BLOCKING-2)**

The spec specifies `I = X'WX/n` (survey weights only) for the Binder sandwich bread, and `σ̂² (X'WX)⁻¹` for SRS variance. Both use the wrong matrix for any non-Gaussian family. The correct bread is `summary(fit)$cov.unscaled = (X'W̃X)⁻¹` from the IRLS step. This is the most dangerous error because: (a) it would silently produce wrong SEs for binomial and Poisson models — the two most common non-Gaussian use cases; (b) the oracle comparison tests for non-Gaussian families would fail against `survey::svyglm()`, exposing the bug — but only if those tests are run; and (c) the SRS analytic formula makes the error invisible for the Gaussian case, which is where most unit testing would naturally start.

**2. Mislabeled "Deviance Residuals" in `summary()` (BLOCKING-3)**

Working residuals displayed as deviance residuals is a false label for every non-Gaussian family. For a logistic regression with a large dataset, working residuals exceed ±5 routinely (`(y-p̂)/(p(1-p))`), whereas deviance residuals are bounded near 0–3. This error makes the output of `summary.survey_glm_fit()` factually incorrect for the most important validation step a user would perform after fitting a model. It cannot be caught by numerical oracle tests.

**3. `residuals(type="response")` and deviance residuals in `summary()` both require the original response, which is not stored (BLOCKING-4 + BLOCKING-3)**

Two components of the API require access to `y` (the original response vector), but `y` is not stored in the S7 object and the spec does not require `@fit_` for `residuals(type="response")`. Fixing BLOCKING-3 (using `residuals(fit_, type="deviance")`) resolves both, but it makes `@fit_` effectively required for more operations than the spec states — which needs to be made explicit in the property table and error table.

---

## Note on Genuine Uncertainty in the Literature

One area where practice diverges from a single authoritative answer: the correct degrees of freedom for the t-reference distribution in survey GLM Wald tests. The `degf(design) - (p-1)` formula (Korn & Graubard 1990) is the most widely cited, and `survey::svyglm()` uses it — so following that convention is defensible. But the choice of `(p-1)` vs `p` vs `(p - num_strata)` remains contested for complex designs with many predictors relative to design df, and there is no consensus in the literature for designs where `degf(design) < p`. The spec's warn-and-clamp approach (BLOCKING-1 of the prior review, now resolved as `surveycore_warning_insufficient_df`) is the right call given the uncertainty.

---

## Methodology Review: phase-2 — Pass 2 (2026-03-08)

**Spec version reviewed:** v0.9 (`plans/spec-phase-2.md`)

---

### Prior Issues (Pass 1 — v0.8)

| # | Title | Lens | Status |
|---|---|---|---|
| BLOCKING-1 | Information matrix wrong for non-Gaussian families | 1 | ✅ Resolved — Section 8.2 now specifies `bread = summary(fit)$cov.unscaled = (X'W̃X)⁻¹` with explicit documentation that `(X'WX/n)⁻¹` is Gaussian-only |
| BLOCKING-2 | SRS variance formula only valid for Gaussian | 2 | ✅ Resolved — Section 8.4 replaced with score-based SRS sandwich using `N²(1-f)/n · S²_{u_j}` for all families |
| BLOCKING-3 | `summary()` labels working residuals as "Deviance Residuals" | 3 | ✅ Resolved — Section 5.2.2 now uses `fivenum(residuals(model@fit_, type = "deviance"))` |
| BLOCKING-4 | `residuals(type="response")` requires `y`, not stored | 1 | ✅ Resolved — Section 5.7 now specifies `model.response(model.frame(object@fit_))` with explicit `@fit_` requirement and note on transformed-response scale |
| REQUIRED-5 | `@df_null` computation never specified | 3 | ✅ Resolved — Section 3.2 now specifies `df_null` = `fit$df.null` (classical `n - 1`) |
| REQUIRED-6 | `@df_residual` declared `class_integer` but computed from non-integer `degf()` | 3 | ✅ Resolved — Section 3.1 class definition now uses `S7::class_numeric` for both `df_null` and `df_residual` |
| REQUIRED-7 | Reference row `term` column contradicts decisions log | 3 | ✅ Resolved — Section 6.3 explicitly notes the v0.8 reversal of the `[ref]` suffix decision; spec body is canonical |
| REQUIRED-8 | Replicate domain estimation mechanism contradictory | 4 | ✅ Resolved — Section 4.5 now cleanly separates Taylor (zero-score masking) from replicate (restricted refit, no masking); non-convergence behavior specified |
| REQUIRED-9 | `cbind()` LHS error detection mechanism wrong | 1 | ✅ Resolved — Section 4.4 now adds explicit `is.call(formula[[2]]) && identical(formula[[2]][[1]], quote(cbind))` pre-check for `surveycore_error_cbind_response_unsupported` |
| REQUIRED-10 | `na.action = na.fail` has no test | 3 | ✅ Resolved — Section 9.4 now includes an explicit edge case for `na.action = na.fail` |
| REQUIRED-11 | Binomial "non-integer successes" warning unhandled | 2 | ✅ Resolved — Section 4.4 Step 4 now specifies `suppressWarnings()` for `binomial()`/`quasibinomial()` |
| REQUIRED-12 | `@df_residual` conflates design-based and classical df | 3 | ✅ Resolved — Section 8.5 now defines two distinct quantities: `@df_residual` (classical `n - p`) for deviance display; `degf - (p-1)` computed inline for t-tests |
| ADVISORY-13 | marginaleffects AME SEs provenance not documented | 5 | ✅ Resolved — Section 7.5 now includes a documentation note on the hybrid design-based / delta-method provenance |
| ADVISORY-14 | `@vcov` not validated as PSD | 2 | ✅ Resolved — Quality gate in Section XI now requires `all(eigen(vcov(fit))$values >= -1e-10)` for all oracle test fits |
| ADVISORY-15 | `predict(se_fit=TRUE)` SEs are model-based — asymmetry not documented | 5 | ✅ Resolved — Section 5.5 now includes explicit "Note on se_fit" documenting the model-based / design-based asymmetry |
| ADVISORY-16 | `logLik()`/`AIC()`/`BIC()` model-based warning not in clean() `.meta` | 5 | ✅ Resolved — Section 5.18 now requires `@note` roxygen warning against using AIC/BIC for model selection |

All 16 prior issues resolved. Spec correctly promoted to v0.9.

---

### New Issues

#### Lens 1 — Estimator Specification

**Issue 17: SRS meat matrix specifies only diagonal entries — off-diagonal covariance terms absent**
Severity: BLOCKING
Resolution type: UNAMBIGUOUS

Section 8.4 specifies the SRS meat matrix entry for a single score-total column as:

```
Var_SRS(T_j) = N² · (1 - f) / n · S²_{u_j}
```

Step 3 then says "Assemble the p × p meat matrix from these column variances."

The problem: this formula gives the *diagonal* entry `(j, j)` of the `p × p` meat matrix. The off-diagonal entries `Cov_SRS(T_j, T_k)` are never specified. For the Binder sandwich `Var(β̂) = bread · meat · bread`, the full `p × p` meat matrix is required — not a diagonal matrix constructed from the column-wise variances alone.

**Why this is BLOCKING:** When `bread = (X'W̃X)⁻¹` is not diagonal (which it almost never is), `bread · diag(S²_{u_j}) · bread` ≠ `bread · full_meat · bread` for the diagonal elements. Concretely, for a model with intercept and one continuous predictor (p = 2):

```
Var(β̂_1) = b₁₁² · m₁₁  +  2·b₁₁·b₁₂·m₁₂  +  b₁₂² · m₂₂
```

Using only diagonal entries omits the `2·b₁₁·b₁₂·m₁₂` term. Whenever score columns are correlated (`m₁₂ ≠ 0`) and the bread is non-diagonal, every SE from the SRS path is wrong. The oracle comparison for any multivariate SRS model against `survey::svyglm()` would fail.

**Resolution:** Replace Step 2–3 of Section 8.4 with the full `p × p` sample covariance formulation:

```
Cov_SRS(T_j, T_k) = N² · (1 - f) / n · S_{u_j, u_k}
```

where `S_{u_j, u_k}` is the sample covariance between columns `j` and `k` of the score matrix. In matrix form, the meat is:

```r
meat <- N^2 * (1 - f) / n * var(score_matrix)   # uses R's var(), which gives sample cov matrix
# More explicitly:
U_centered <- sweep(score_matrix, 2, colMeans(score_matrix))
meat <- N^2 * (1 - f) / n * (t(U_centered) %*% U_centered) / (n - 1)
```

where `N` and `f` follow the existing rule (from `design@variables$fpc` if available, else `N = sum(weights)`).

The `survey_calibrated` path uses the same formula. Add an explicit oracle test for the SRS path with ≥ 2 predictors (e.g., `y ~ x1 + x2` on synthetic SRS data) verifying that `sqrt(diag(vcov(fit_sc)))` matches `SE(fit_sv)` within 1e-8.

Source: Binder (1983), JASA 78(382):626–631 — the full meat matrix `Var_design(T)` is the design-based covariance matrix of the total score *vector*, not the diagonal matrix of marginal score variances.

---

#### Lens 2 — Variance Estimation

No new issues found beyond Issue 17 (SRS meat matrix). The Taylor path passes the full score matrix to `.svy_recvar()` which handles the complete `p × p` covariance structure. The replicate path constructs the full outer product `Σ c_r d_r d_r'`. Only the SRS path was affected.

---

#### Lens 3 — Degrees of Freedom and Inference

**Issue 18: `df_residual` mislabeled as "design-based" in two places**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Section 8.5 (correctly) establishes that `@df_residual` stores the *classical* `fit$df.residual` (i.e., `n - p`), used only for the deviance display, while the design-based residual df `degf - (p - 1)` is computed inline. However, two other sections of the spec contradict this:

1. **Section 5.2.1** (`survey_glm_summary` structure table): `df_residual` description reads "Design-based residual df (`model@df_residual`)." The value `model@df_residual` is classical `n - p`, so the label "Design-based" is wrong.

2. **Section 5.14** (`df.residual.survey_glm_fit()`): "Returns `object@df_residual` — the **design-based** residual degrees of freedom." Same mislabeling.

An implementer reading only Section 5.2.1 or Section 5.14 would conclude that `@df_residual` holds the design-based df (e.g., ~16 for NHANES), which contradicts Section 8.5. This would cause the deviance display to show design-based df instead of classical df — the opposite of the intended behavior.

**Resolution:**

- Section 5.2.1, `df_residual` description: change to "Classical residual degrees of freedom (`model@df_residual` = `fit$df.residual` = `n - p`). Used for the deviance display only. For t-tests and CIs, design-based df is used (`model@degf - (p - 1)`), computed inline."
- Section 5.14: change "design-based" to "classical (`n - p`) residual degrees of freedom, stored from `fit$df.residual`."

Source: Section 8.5 of the same spec — this is an internal consistency fix, not a methodological judgment.

---

#### Lens 4 — Domain Estimation

No new issues found. Section 4.5 correctly specifies zero-score masking for Taylor, restricted refit (no masking) for replicate, non-convergence handling, and empty-domain error.

---

#### Lens 5 — Established Practice

**Issue 19: `survey_calibrated` N determination not explicitly confirmed for SRS formula**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

Section 8.4 states: "N is the population size (from `design@variables$fpc` if available, otherwise `n/f` from the weight sum)." Section 8.1 confirms that `survey_calibrated` uses the SRS sandwich path. However, the spec does not explicitly confirm which weights' sum to use for N when `survey_calibrated` has no fpc: the pre-calibration weights, the post-calibration weights, or some design-level quantity.

In practice, N = `sum(design@variables$weights)` (the calibrated weights, which are the current `@variables$weights`) is the correct choice — calibrated weights approximately sum to the population total. But this is left implicit. If an implementer mistakenly uses pre-calibration weights (from some other slot) or the raw row count, the SRS variance would be wrong for calibrated designs.

**Resolution:** Add one sentence to Section 8.4 (or Section I): "For `survey_calibrated` designs, N is approximated as `sum(design@variables$weights)` (the calibrated survey weights, which sum to approximately the population size)."

**Issue 20: NA-removed rows' score contribution to variance not explicitly specified**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

Section 4.4 Step 3 states: "Rows removed by `na.action` are excluded from fitting and from variance estimation." For the score-based sandwich, "excluded from variance estimation" means zero score contribution (`u_i = 0` for NA rows). This is the correct and natural behavior — NA rows have no fitted value, so their score is undefined and treated as zero — but the spec never states this explicitly. An implementer unfamiliar with the score-based approach might wonder how to handle the `n × p` score matrix when the GLM was fit on only `n_complete < n` rows.

**Resolution:** Add one sentence to `.taylor_var_score_matrix()` in Section 2.2 or to Step 5 of Section 4.4: "Rows excluded by `na.action` (and out-of-domain rows) have zero score contribution — the `n × p` score matrix has `u_i = 0` for these rows, and `.taylor_var_score_matrix()` is called on the full `n × p` matrix including these zero rows."

---

### Summary (Pass 2)

| # | Title | Severity | Status |
|---|---|---|---|
| 17 | SRS meat matrix diagonal-only — off-diagonal covariance terms absent | BLOCKING | ✅ Resolved — Section 8.4 now specifies full `p × p` sample covariance via `var(score_matrix)`; oracle test for SRS with ≥ 2 predictors added |
| 18 | `df_residual` mislabeled as "design-based" in Section 5.2.1 and 5.14 | REQUIRED | ✅ Resolved — both sections now read "Classical residual df (`n - p`)" with a note that design-based df is computed inline |
| 19 | `survey_calibrated` N determination not explicit | ADVISORY | ✅ Resolved — Section 8.4 now states N = `sum(design@variables$weights)` for calibrated designs |
| 20 | NA-removed rows' zero score contribution not explicit | ADVISORY | ✅ Resolved — Step 5 of Section 4.4 now states `u_i = 0` for NA-excluded rows; full `n × p` matrix passed to `.taylor_var_score_matrix()` |

All 4 Pass 2 issues resolved. Spec promoted to **v1.0 — methodology-locked**.
