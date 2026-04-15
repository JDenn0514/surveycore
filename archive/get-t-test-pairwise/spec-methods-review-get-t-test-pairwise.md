## Methodology Review: get-t-test-pairwise — Pass 1 (2026-04-13)

### New Issues

#### Lens 1 — Estimator Specification

**Issue 1: `by_empty_cell` error class named in testing requirements but not defined in error registry**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The testing section (§VI) specifies two edge cases that require a `by_empty_cell` error:

> "- [ ] `by` with exactly 2 levels in `get_t_test()` but one level has 0 rows after NA removal — `by_empty_cell` error"
> "- [ ] `group` with a stratum where one `by` level is empty — `by_empty_cell` error includes stratum info in message"

But §V (Error & Warning Conditions) does not define `surveycore_error_by_empty_cell`. The existing class `surveycore_error_by_not_two_levels` (T-1) fires when the model matrix has ≠ 2 columns, which is a different condition — it catches multi-level factors, not empty cells. An empty cell after NA removal would still produce a 2-column model matrix (the binary indicator column exists, but all its 0s or all its 1s are gone), leading to a singular GLM fit rather than a model matrix shape error.

Fix: Add to §V:

| # | Function | Condition | Level | Class | Message Template |
|---|---|---|---|---|---|
| T-3 | `get_t_test()` | After NA removal, one active level of `by` has zero rows | ERROR | `surveycore_error_by_empty_cell` | `"Level {.field {empty_level}} of {.arg by} ({.field {by_name}}) has no non-NA observations. Cannot compute t-test."` |
| T-3 (group) | `get_t_test()` (group case) | Within group stratum, one `by` level has zero rows | ERROR | `surveycore_error_by_empty_cell` | `"In group stratum {.val {group_vals}}, level {.field {empty_level}} of {.arg by} ({.field {by_name}}) has no non-NA observations."` |

This check belongs in step 9.b or 9.d of the execution flow (§3.6), after building `active_mask` and before fitting the GLM.

Options:
- **[A]** Add `surveycore_error_by_empty_cell` to §V with separate message templates for the no-group and group cases. Add the check to §3.6 step 9. — Effort: low, Risk: low, Impact: closes spec/test inconsistency, Maintenance: none
- **[B]** Reuse `surveycore_error_by_not_two_levels` with a revised message that covers both the model-matrix-shape case and the empty-cell case. — Effort: low, Risk: medium (conflates two distinct failure modes), Impact: fewer classes, Maintenance: none
- **[C] Do nothing** — Spec is internally inconsistent; implementer must guess.

**Recommendation: [A]** — Empty cell after NA removal is semantically distinct from "factor has wrong shape." Users deserve a specific error message, and the testing requirements already name the class.

Source: Spec §V, §VI.

---

All other estimator formulas verified correct:
- `estimate = beta[2]` (slope = mean_b - mean_a in Gaussian GLM with binary indicator) ✓
- `se = sqrt(V[2,2])` ✓
- `t_stat = beta[2] / sqrt(V[2,2])` ✓
- `mean_a = beta[1]` (intercept = weighted mean of reference group) ✓
- `mean_b = beta[1] + beta[2]` ✓
- `se_b = sqrt(V[1,1] + V[2,2] + 2*V[1,2])` (correct via `Var(c'β) = c'Vc` with c=[1,1]') ✓

#### Lens 2 — Variance Estimation

**Issue 2: df formula lacks `max(1, ...)` clamping; spec does not match existing codebase contract**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec (§3.3, Step 2) states:
```r
df <- fit@degf - 1     # residual df: design df minus one predictor
```

`fit@degf` stores the **raw design df** (confirmed: `R/glm.R:117` documents it as "Raw design degrees of freedom"; line 576 stores `degf_raw` before any subtraction). The formula `fit@degf - 1` is mathematically correct for a 2-coefficient model and matches `survey::svyttest()` exactly (see Lens 5 Note below). However, the spec omits the edge-case clamp.

When `fit@degf ≤ 1`, the formula yields `df ≤ 0`, which is invalid for `stats::pt()` and `stats::qt()` — both return `NaN`. The existing GLM codebase already warns about this (R/glm.R:550–564) but performs the actual clamp in `.glm_confint()`, not in the spec's extraction step.

Fix: Replace the formula in Step 2 with:
```r
df <- max(1, fit@degf - 1)     # residual df: design df minus (p-1); clamped to 1
```

Add a note: "Clamping to 1 is conservative. If `fit@degf` is small (< 2), t-statistics and CIs should be interpreted with caution."

Options:
- **[A]** Update spec Step 2 to `max(1, fit@degf - 1)` with the above note. — Effort: low, Risk: low, Impact: prevents NaN propagation on edge-case designs, Maintenance: none
- **[B]** Leave formula as-is; rely on `survey_glm()` to validate `@degf > 0`. Note that the `@degf` validator in the S7 class (R/glm.R:178–179) already rejects `degf ≤ 0` objects. — Effort: none, Risk: low (validator prevents `degf ≤ 0`, but `degf = 1` still gives `df = 0`), Impact: partial protection, Maintenance: none
- **[C] Do nothing** — Edge case unreachable in typical surveys; NaN would surface during testing.

**Recommendation: [A]** — One-line fix. The existing codebase already performs this clamp in `.glm_confint()`; the t-test spec should be consistent with that convention.

Source: R/glm.R lines 117, 550–576, 178–179.

---

**Issue 3: FPC inheritance by `survey_glm()` not documented**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

The spec uses `fit@vcov` as the design-based sandwich covariance but does not confirm that this matrix automatically includes FPC when `fpc` is specified at design construction. A reader cannot verify whether variance estimates are correct for FPC designs without reading the `survey_glm()` specification separately.

A single sentence would close this gap: "The `fit@vcov` matrix is the full design-based sandwich covariance, including FPC for `survey_taylor` designs where `fpc` is specified, and the appropriate scale/rscales adjustments for `survey_replicate` designs — all computed by `survey_glm()`."

Options:
- **[A]** Add the clarifying sentence in §3.3 Step 2. — Effort: low, Risk: low, Impact: confirms delegation is complete, Maintenance: must stay in sync if `survey_glm()` spec changes
- **[C] Do nothing** — Spec is correct (FPC flows through automatically); omission is a documentation gap only.

**Recommendation: [A]** — Low effort; eliminates reader uncertainty.

Source: Phase 2 regression spec; `survey::svyglm()` FPC handling.

#### Lens 3 — Degrees of Freedom and Inference

*(Issue 2 above covers the df clamping gap; no additional Lens 3 issues.)*

**Issue 4: Design-based df vs. classical df not explicitly contrasted in §3.3**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec uses design-based df throughout (§3.3, step 2 comment: "design df minus one predictor") but never explicitly states this or contrasts it with classical df (`n - p`). Users familiar with `stats::t.test()` see `df = 4998` for a 5,000-respondent survey; the design-based df for the same survey is typically in the range 20–100. This is not a subtle difference — it materially widens CIs and increases p-values.

The spec claims to follow `survey::svyttest()`, which is design-based by construction, but this connection is not drawn in §3.3.

Fix: Add before Step 1 in §3.3:

> **Degrees of freedom:** This function uses design-based df derived from the survey design structure (`degf` = number of PSUs minus number of strata, or the analogous quantity for replicate designs). The residual df is `degf - 1` for this two-group model. Classical df (`n - p`) is NOT used. This is consistent with `survey::svyttest()` and produces wider CIs and larger p-values than classical inference for large surveys.

Options:
- **[A]** Add the paragraph above to §3.3. — Effort: low, Risk: low, Impact: prevents user confusion, Maintenance: none
- **[B]** Add a single sentence in §3.2 Arguments table for `design`: "Design df (not classical df) is used for all inference." — Effort: low, Risk: low, Impact: earlier signal, Maintenance: none
- **[C] Do nothing** — The comment "design df" in Step 2 is present; readers who read carefully will understand.

**Recommendation: [A]** — This is a material statistical distinction that should be front-loaded. A single short paragraph in §3.3 removes the ambiguity without bloating the spec.

Source: `survey::svyttest()`; Korn & Graubard (1990) on design-based inference.

#### Lens 4 — Domain Estimation

*(Issue 1 above covers the `by_empty_cell` error class; the following addresses domain-estimation mechanism.)*

**Issue 5: Domain-preservation claim (§3.5) is not backed by a specified mechanism for all design paths**
Severity: REQUIRED
Resolution type: JUDGMENT CALL

The spec claims (§3.5):
> "The full design's PSU and stratification structure is preserved for variance estimation — strata are not dropped when subsetting to a group stratum."

And `get_pairwise()` (§4.3, step 1):
> "Subset the design to rows where `by %in% c(a, b)`."

The claim to "preserve full design structure" is true for the Taylor linearization path only if `survey_glm()` uses domain indicators (zeroing out-of-domain score contributions) rather than physically dropping rows. For the replicate path, physical row dropping changes the effective replicate weight matrix and may not preserve the full PSU structure.

The spec does not specify **which mechanism** achieves domain preservation, leaving this as an implicit assumption about `survey_glm()` internals. Additionally, in `get_pairwise()`, step 1 physically subsets the design object before passing to `get_t_test()`, which may silently destroy cross-boundary PSU structure for replicate designs.

The domain preservation claim is accurate for Taylor designs when PSUs are nested within `by` levels (the typical case). It is uncertain for:
- Replicate designs (depending on `.glm_replicate_vcov()` implementation)
- Designs where PSUs span multiple `by` levels (non-nested)

Options:
- **[A] Scope the claim and document the mechanism:** Replace the unqualified claim with: "The full design's PSU and stratification structure is preserved for variance estimation in the Taylor path via domain-indicator score zeroing in `survey_glm()`. For replicate designs, variance is correct when PSUs are nested within `by` groups; designs where PSUs span multiple `by` levels are not guaranteed to preserve variance accuracy." Also verify in the `survey_glm()` spec that the domain indicator approach is used for Taylor, and that the replicate path handles this correctly. — Effort: medium (requires verifying `survey_glm()` behavior), Risk: low, Impact: honest about scope, Maintenance: must stay in sync with `survey_glm()` spec
- **[B] Remove the unqualified claim and replace with a reference:** "Domain-preservation behavior depends on `survey_glm()` internals; see the Phase 2 spec for details." — Effort: low, Risk: low, Impact: defers to existing spec, Maintenance: none
- **[C] Do nothing** — The claim is correct for the dominant use case (nested PSUs); edge cases are handled by oracle testing.

**Recommendation: [A]** — The preservation claim is load-bearing (it appears in both `get_t_test()` and `get_pairwise()` specs). If the replicate path does not actually preserve structure, oracle tests against `survey::svyttest()` will catch it, but users of `get_pairwise()` on replicate designs with non-nested PSUs may silently get wrong variances.

Source: Survey domain estimation theory; Lohr (2022) §9.3.

#### Lens 5 — Established Practice and Literature

**Note on df formula:** The Lens 5 agent initially flagged `df = fit@degf - 1` as incorrect (suggesting `degf - 2`). This is a **false positive**. `survey::svyttest()` internally uses a one-sample trick (fits `difference ~ 1`, one coefficient), so `degf(model) = degf(design) - 0 = degf(design)`, then subtracts 1 → `df = degf(design) - 1`. The spec's two-sample GLM approach (`x ~ by`, two coefficients) stores raw design df in `fit@degf`, and the spec formula `fit@degf - 1` = `degf(design) - 1` matches exactly. The formula is correct.

**Issue 6: Pairwise p-value adjustment applied to correlated design-based test statistics — not documented**
Severity: ADVISORY
Resolution type: JUDGMENT CALL

The spec (§4.4) applies `stats::p.adjust()` to k(k−1)/2 design-based p-values. These p-values are not independent — all pairs share the same PSU and strata structure. Standard adjustment methods (Bonferroni, Holm) are conservative under positive correlation between test statistics, meaning the adjusted p-values will be larger than necessary to control the family-wise error rate at the stated level.

This is a known limitation in the design-based multiple-comparison literature. No published standard corrects for this in complex survey pairwise t-tests. The current approach is pragmatic and the most common practice; it is not wrong, only conservative.

Options:
- **[A]** Add a note to §4.4: "P-value adjustment via `stats::p.adjust()` is applied uniformly. Design-based pairwise t-statistics are correlated through shared PSU and strata structure; standard adjustment methods (Bonferroni, Holm) are therefore conservative — adjusted p-values are larger than the FWER-optimal values. No design-based correction is implemented." — Effort: low, Risk: low, Impact: transparent about limitation, Maintenance: none
- **[C] Do nothing** — Conservatism is acceptable and expected; many users will prefer this to an underdocumented correction.

**Recommendation: [A]** — Transparency note only; no code change required.

Source: Lumley (2010), *Complex Surveys*, §4.4; Westfall & Young (1993), *Resampling-Based Multiple Testing*.

**Issue 7: Pair-subsetting approach (k separate GLMs) vs. k-level GLM + contrasts — choice not justified**
Severity: ADVISORY
Resolution type: JUDGMENT CALL

The spec fits k(k−1)/2 separate 2-level GLMs rather than one k-level GLM plus contrast extraction via `svycontrast()`. This is a deliberate design choice but is not justified in the spec. Both approaches are statistically valid under design-based inference; the pair-subsetting approach is simpler but slightly less efficient.

Options:
- **[A]** Add a brief methodological note in §4.3: "Pair-subsetting (fitting a separate 2-level GLM per pair) is used rather than a single k-level GLM with contrasts. Both approaches produce asymptotically equivalent estimates; the pair-subsetting approach is simpler and avoids the need for `svycontrast()`, at the cost of fitting k(k−1)/2 models." — Effort: low, Risk: low, Impact: eliminates reviewer ambiguity, Maintenance: none
- **[C] Do nothing** — Implementation is sound; the rationale is implicit in the design.

**Recommendation: [A]** — One sentence removes the reviewer ambiguity without any code change.

Source: Lumley, `survey` package vignette on contrasts.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 4 |
| ADVISORY | 3 |

**Total issues:** 7

**Issue index:**

| # | Title | Lens(es) | Severity |
|---|---|---|---|
| 1 | `by_empty_cell` error class not defined in §V | 1, 4 | REQUIRED |
| 2 | df formula lacks `max(1, …)` clamping | 2, 3 | REQUIRED |
| 3 | FPC inheritance by `survey_glm()` not documented | 2 | ADVISORY |
| 4 | Design df vs. classical df not explicitly contrasted | 3 | REQUIRED |
| 5 | Domain-preservation claim lacks specified mechanism | 4 | REQUIRED |
| 6 | p-value adjustment conservatism not documented | 5 | ADVISORY |
| 7 | Pair-subsetting rationale not justified | 5 | ADVISORY |

**Assessment:** The estimator formulas and t-distribution choice are mathematically correct and consistent with `survey::svyttest()`. Four REQUIRED issues are present: one error class gap, one missing edge-case clamp in the df formula, one missing explicit statement about design-based df, and one underspecified claim about domain-preservation behavior in the domain/group estimation paths. No BLOCKING issues — oracle tests against `survey::svyttest()` would pass for the core numerical quantities as specified.
