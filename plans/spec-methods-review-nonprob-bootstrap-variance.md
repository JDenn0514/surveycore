## Methodology Review: nonprob-bootstrap-variance — Pass 1 (2026-05-18)

### New Issues

#### Lens 1 — Estimator Specification

---

**Issue 1: Scale default is type-agnostic; non-bootstrap types will use wrong variance scaling**
Lens: 1
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec's `@variables` table (§1) and constructor argument table (§2) both state `scale` defaults to `1/R` unconditionally. This is correct only for `type = "bootstrap"` and `type = "ACS"`. For jackknife types the correct default is `(R - 1) / R`; for `successive-difference` it is `2 / R`. The existing `as_survey_replicate()` already implements a type-dependent switch. Since the spec exposes the same `type` argument with the same valid values, a user who passes jackknife repweights would receive `scale = 1/R` when the correct default is `(R-1)/R`, producing variance estimates that are systematically too small.

Fix: Replace the flat `1/R` default in §1 and §2 with a reference to the same type-dependent switch already in `as_survey_replicate()`, extracted into a shared `.default_rep_scale(type, n_rep)` helper in `07-utils.R`.

Options:
- **[A]** Spec the constructor to apply a type-dependent `switch()` block (as in `as_survey_replicate()`), extracted to a shared helper. — Effort: low, Risk: low, Impact: correct default for all replicate types, Maintenance: one place to update
- **[B]** Restrict `as_survey_nonprob()` to `type = "bootstrap"` only, making `scale = 1/R` always correct within scope. — Effort: low, Risk: low, Impact: closes the jackknife gap by not accepting jackknife types, Maintenance: revisit if JK NPS support added later
- **[C] Do nothing** — Jackknife replicate weights on `survey_nonprob` will silently produce SEs too small by a factor of `sqrt((R-1)/R)`.

**Recommendation: B** — The only replicate weight method `surveywts` currently produces for NPS inputs is bootstrap. Restricting `type = "bootstrap"` also resolves Issue 3 (see below). Note: if Option B is chosen, this issue and Issue 3 collapse into a single restriction.

Source: surveycore `R/core-constructors.R` lines 711–724; Lumley (2004), *survey* package documentation.

---

**Issue 2: Workflow diagram is structurally inconsistent with how `create_bootstrap_weights()` actually works**
Lens: 1
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec's Background workflow (lines 27–34) shows:

```
surveywts::rake(data, benchmarks)
  └── surveywts::create_bootstrap_weights(result, R = 200)
        └── as_survey_nonprob(data, weights = cal_wt,
                              repweights = starts_with("repwt_"),
                              calibration = boot$provenance)
```

This is incoherent in two ways: (1) `create_bootstrap_weights()` returns a `survey_replicate` object, not raw data — the user cannot pipe its output into `as_survey_nonprob()` and re-select repweight columns without three extra undocumented steps; `boot$provenance` does not exist as a field on any current `surveywts` return type. (2) Correct NPS bootstrap variance requires re-running calibration inside each bootstrap draw (acknowledged in the Background text). But the diagram shows raking once, then bootstrapping from the raked design — if `create_bootstrap_weights()` only perturbs final weights without re-fitting the calibration model, the SEs miss calibration uncertainty entirely.

The spec text and diagram contradict each other on the re-calibration requirement.

Options:
- **[A]** Replace the workflow diagram with the actual current API path. Clarify that the `survey_nonprob` repweights path is for a `surveywts` workflow that re-runs calibration per draw and stores per-draw weight columns in the data frame. Remove the reference to `boot$provenance`. — Effort: low, Risk: low, Impact: spec accurately reflects implementation and user workflow, Maintenance: update diagram when surveywts provenance is finalized
- **[B]** Remove the diagram and describe both cases in prose. — Effort: low, Risk: low, Impact: less clarity but avoids the false implication
- **[C] Do nothing** — `boot$provenance` refers to a non-existent field; users following the diagram get either an error or silently incorrect SEs.

**Recommendation: A** — The diagram is the spec's primary communication of when this feature applies. Getting it right is essential for both correct implementation and correct user behavior.

Source: `nonprob_variance_estimation.md` — "calibration or propensity estimation must be re-run within each bootstrap draw"; surveywts `R/replicate-weights.R` `@return` documenting `survey_replicate` output.

---

**Issue 3: `mse = TRUE` is correct for bootstrap NPS, but the spec exposes non-bootstrap `type` values for which it is wrong — should restrict `type = "bootstrap"` only**
Lens: 1 + 2 (merged)
Severity: REQUIRED
Resolution type: JUDGMENT CALL

The spec accepts the full `type` value set from `as_survey_replicate()` including `"JK1"`, `"JK2"`, `"JKn"`, `"BRR"`, etc. For jackknife methods, the statistically correct setting is `mse = FALSE`; the spec hardcodes `mse = TRUE` universally and does not document this. More fundamentally, Wu (2022) notes that jackknife variance has known problems in complex NPS structures and should not be used for NPS at all.

`surveywts::create_bootstrap_weights()` is the only supported repweight producer in the specified workflow. Accepting jackknife and other `type` values creates a footgun: users who supply `type = "JK1"` or `type = "JKn"` will get a statistically incorrect variance formula with no warning.

Additionally, the `mse = TRUE` default (centering on the full-sample estimate rather than the mean of replicates) is methodologically the correct choice for NPS bootstrap — the full-sample calibrated estimate is the target, and its variability is what is being estimated. But this is not documented.

Options:
- **[A]** Restrict `type` to `"bootstrap"` only for `survey_nonprob`. Add `surveycore_error_type_invalid` logic to block all other types. Add one sentence to the `mse` argument documentation explaining why `mse = TRUE` is correct for NPS bootstrap. — Effort: low, Risk: low, Impact: eliminates the jackknife footgun; documents mse semantics, Maintenance: update when future NPS variance methods are added
- **[B]** Keep the full `type` set but add a warning when `type != "bootstrap"`: `surveycore_warning_nonprob_type_not_bootstrap`. Add documentation to `mse`. — Effort: low, Risk: medium (warning is softer than the error users deserve), Impact: partial guard
- **[C] Do nothing** — Users can set `type = "JK1"` with `mse = TRUE` and get a statistically incorrect result with no diagnostic.

**Recommendation: A** — Wu (2022) explicitly flags jackknife as problematic for NPS structures. Restricting `type = "bootstrap"` is the principled position and simplifies the scale default (Issue 1) to a constant `1/R`. If Option A is chosen for Issue 1, both issues are resolved by a single `type = "bootstrap"` restriction.

Source: Wu (2022), *Statistical Inference with Non-probability Survey Samples*; `nonprob_variance_estimation.md` §"Bootstrap as the Practical Default".

---

**Issue 4: `scale` NULL resolution timing not specified in the constructor body — stored NULL would break the replicate helpers**
Lens: 1 + 2 (merged)
Severity: BLOCKING
Resolution type: UNAMBIGUOUS

The spec's `@variables` table says `scale` key defaults to `"1/R"`. The constructor argument table says "When NULL and `repweights` is non-NULL, defaults to `1 / R` where `R = length(repweights_vars)`." However, the spec does not say this computation runs **at construction time** before writing to `@variables`. An implementer could store the raw `NULL` in `@variables$scale` and leave default resolution to the helpers.

The replicate helpers read `vars$scale` directly with no NULL-fallback — `NULL * anything` returns `NULL` in R, silently propagating to the variance formula. The analogous code in `as_survey_replicate()` explicitly resolves scale before constructing `@variables`:

```r
if (is.null(scale)) {
  scale <- switch(type, ..., bootstrap = 1 / n_rep, ...)
}
```

The spec must state explicitly: when `repweights` is non-NULL and `scale` is NULL, compute the resolved value at construction time and store the numeric result in `@variables$scale`. The raw NULL is never written to `@variables` when repweights are present.

Fix: Add a "Constructor body" sub-section under §2 stating the resolution order: evaluate R, compute scale from R if NULL, then construct `@variables` with resolved values.

Options:
- **[A]** Add explicit constructor-body resolution language: "When `repweights` is non-NULL and `scale` is NULL, resolve `scale <- 1 / R` (or the appropriate type-dependent formula per Issue 1) before writing to `@variables$scale`." — Effort: low, Risk: none, Impact: prevents silent NULL propagation into `.svy_rep_var()`, Maintenance: none
- **[B] Do nothing** — Relies on implementer to infer this from the `@variables` defaults table; the helpers have no NULL guard and will silently return NULL SE.

**Recommendation: A** — This is the same pattern as `as_survey_replicate()`; the spec should mirror it explicitly. This is BLOCKING because a NULL scale reaching `.svy_rep_var()` produces silent wrong output.

Source: `R/core-constructors.R` lines 708–724 (scale resolution in `as_survey_replicate()`); `R/analysis-means-helpers.R` lines 143–148.

---

#### Lens 2 — Variance Estimation

---

**Issue 5: Re-calibration precondition for correct variance is not documented**
Lens: 2 + 5 (merged)
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec Background correctly states that correct NPS variance "requires re-running the adjustment step (raking, calibration, or propensity estimation) on each bootstrap replicate" and delegates this to `surveywts`. However, this critical precondition appears only in Background as implicit context — it is absent from the argument documentation for `repweights` and from the Design Decisions section.

A user who supplies externally produced replicate weights (not from `surveywts::create_bootstrap_weights()`) that simply rescale the original calibration weights without re-fitting the model will receive SEs that underestimate calibration uncertainty. This is the same failure mode as the SRS fallback, but without any warning.

The `nonprob_variance_estimation.md` wiki is explicit: "calibration or propensity estimation must be re-run within each bootstrap draw — treating the adjustment step as fixed loses the adjustment uncertainty that bootstrap is supposed to capture." The roxygen documentation for `repweights` must state this condition prominently.

Required language (in `@param repweights` or `@details`):

> Bootstrap variance estimation is valid only when each replicate weight column was produced by re-running the full calibration or propensity estimation procedure on a bootstrap resample. Replicate weights that rescale the original calibration weights without re-fitting the adjustment model underestimate variance by omitting calibration estimation uncertainty. `surveywts::create_bootstrap_weights()` re-runs calibration by default.

Options:
- **[A]** Add the above text to the `@param repweights` documentation in the spec's constructor section. No code change. — Effort: low, Risk: none, Impact: makes the precondition explicit for users supplying external repweights, Maintenance: none
- **[B]** Add Option A plus a runtime check using `@calibration` provenance to verify the repweights were produced by re-calibration. — Effort: medium, Risk: medium (surveywts provenance format not yet finalized), Impact: runtime guard, Maintenance: ongoing coupling to surveywts
- **[C] Do nothing** — Precondition is implicit; users with rescaled-only repweights receive silently understated SEs.

**Recommendation: A** — Documentation is the appropriate guard at Phase 2.5 before the surveywts provenance format is finalized.

Source: `nonprob_variance_estimation.md` §"Bootstrap as the Practical Default", condition (1); Wu (2022); Chen et al. (2021).

---

**Issue 6: `rscales = rep(1, R)` default assumes exchangeable replicates — assumption not documented**
Lens: 2
Severity: ADVISORY
Resolution type: JUDGMENT CALL

The uniform `rscales` default assumes all R bootstrap draws are exchangeable (IID from the same distribution). NPS bootstrap replicates produced via re-calibration may not be fully exchangeable — some draws may up-weight rare population segments more aggressively, giving different effective sample sizes. The spec does not state the exchangeability assumption or note when custom `rscales` might be appropriate.

Options:
- **[A]** Add a note to the `rscales` argument documentation: "The default `rep(1, R)` assumes all replicate bootstrap draws are exchangeable. If `surveywts::create_bootstrap_weights()` produces replicates with known unequal precision, supply custom `rscales` to weight deviations accordingly." — Effort: low, Risk: none, Impact: informs users, Maintenance: none
- **[B] Do nothing** — The assumption is standard across all replicate weight implementations; stating it is optional.

**Recommendation: A** — One sentence costs nothing and correctly sets user expectations.

Source: Lumley (2004), *survey* package documentation for `svrepdesign()`.

---

**Issue 7: FPC absence not stated as a deliberate out-of-scope decision**
Lens: 2
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

The spec omits `fpc` from `as_survey_nonprob()` (correct — FPC is not meaningful for NPS), but the Out of Scope section does not mention FPC. An implementer who later extends `survey_nonprob` might add FPC support by analogy with `as_survey_replicate()`.

Fix: Add one sentence to the Out of Scope section: "FPC is not applicable to non-probability samples — there is no sampling design from which to compute a finite population correction, and bootstrap replicate variance does not require it."

Options:
- **[A]** Add the sentence to Out of Scope. — Effort: low, Risk: none
- **[B] Do nothing** — Absence of `fpc` in the constructor implicitly excludes it.

**Recommendation: A** — Explicit "not applicable" documentation in a spec prevents future scope creep.

---

**Issue 8: Quality gate tolerance `1e-8` is too loose for an internal consistency test**
Lens: 2
Severity: ADVISORY
Resolution type: JUDGMENT CALL

The quality gate states: "`get_means()` on a repweight-equipped `survey_nonprob` produces SE within `1e-8` of the value from an equivalent `survey_replicate` object." Since both paths route to the same `.replicate_mean_cell()` with identical inputs, the results should be bitwise identical — a `1e-8` tolerance would pass even if the nonprob path accidentally applied a different scale factor or routed to the wrong helper.

Options:
- **[A]** Change the quality gate to require bitwise identity (`expect_identical()`) for the internal consistency test. Keep `1e-8` for tests that compare against the external `survey` package. — Effort: none, Risk: none, Impact: catches dispatch errors that `1e-8` would miss
- **[B]** Keep `1e-8` — consistent with the project's existing SE tolerance from `testing-surveycore.md`.

**Recommendation: A** — `testing-surveycore.md` defines `1e-8` for comparisons against the external `survey` package. For internal consistency between two surveycore objects calling the same helper, bitwise identity is achievable and is a stronger correctness signal.

Source: `testing-surveycore.md` tolerance table.

---

#### Lens 3 — Degrees of Freedom and Inference

---

**Issue 9: df for `survey_nonprob` with repweights is unspecified; `.degf()` fallback is wrong for this path**
Lens: 3 (merged L3-1 + L3-3)
Severity: BLOCKING
Resolution type: JUDGMENT CALL

The spec says nothing about degrees of freedom for CI construction when a `survey_nonprob` carries bootstrap replicate weights. Currently `.degf()` returns `max(1L, nrow(design@data) - 1L)` (i.e., `n - 1`) for any `survey_nonprob`. This is the wrong value for the new repweight path:

- `get_means()` / `get_freqs()` / `get_totals()` all hardcode `degf <- Inf` before dispatch, so they are unaffected for now.
- `survey_glm()` calls `.degf()` directly for Wald interval df. A 500-row NPS object with 200 replicates would receive `df = 499` instead of the more defensible `df = Inf` — giving subtly narrower intervals than any principled NPS variance approach would support.

The NPS literature (Wu 2022, Elliott & Valliant 2017) is explicit that design-based df formulas do not apply to NPS; there is no randomization distribution to reference. The two defensible choices are `R - 1` (by analogy with probability-sample replicate designs) or `Inf` (normal approximation, acknowledging no known design structure). The spec must choose one and update `.degf()` accordingly.

Options:
- **[A] `degf = Inf`** — Update `.degf()` to return `Inf` for repweight-equipped `survey_nonprob`. Consistent with `get_*()` behavior across all design types; does not falsely imply a known probability design structure; matches the "normal approximation" position that the NPS literature supports for large-sample inference. — Effort: low, Risk: low, Impact: `survey_glm()` CIs use normal approximation for NPS, Maintenance: none
- **[B] `degf = R - 1`** — Update `.degf()` to return `ncol(rep_mat) - 1L` for repweight-equipped `survey_nonprob`. Parallels `survey_replicate` behavior; gives slightly conservative intervals for small R; implies NPS bootstrap replicates map onto probability-sample design df (which the literature does not support). — Effort: low, Risk: low but methodologically questionable
- **[C] Do nothing** — `.degf()` returns `n - 1` for NPS with repweights; `survey_glm()` uses wrong df silently.

**Recommendation: A** — `degf = Inf` is the intellectually honest position: it does not claim a known design structure, matches existing `get_*()` behavior for all designs, and avoids false precision. The spec must state this choice in the Design Decisions section: "Degrees of freedom for CI construction use the normal approximation (`degf = Inf`) for `survey_nonprob` regardless of whether repweights are present. Design-based df are not defined for non-probability samples (Wu 2022)."

Source: Wu (2022) §4.2; Elliott & Valliant (2017) §3; `.degf()` in `R/analysis-helpers.R`.

---

**Issue 10: Spec is silent on CI distribution choice (t vs. normal) for the repweight path**
Lens: 3
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Every other design type in surveycore has an explicit df policy. The spec introduces a new dispatch path for `survey_nonprob` with repweights but states nothing about what `degf` value flows into `.add_variance_cols()` (which calls `stats::qt(... df = degf)`) or what critical value is used to construct confidence intervals.

The current `analysis-means.R` hardcodes `degf <- Inf` before dispatch, meaning the replicate helper path inherits normal approximation. This is the correct behavior (per Issue 9), but it is an accidental consequence of the architecture, not a stated policy.

Fix: Add the following to the Design Decisions section:

> Confidence intervals for replicate-weight `survey_nonprob` objects use the normal approximation (`degf = Inf`), consistent with all `get_*()` analysis functions. Design-based degrees of freedom are not defined for non-probability samples (Wu 2022), so `R − 1` is not used.

Options:
- **[A]** Add the sentence to Design Decisions. — Effort: none, Impact: documents intent; prevents accidental finite-df introduction
- **[B] Do nothing** — The policy is implicit from the code; implementers must discover it by reading `analysis-means.R`.

**Recommendation: A** — Explicit is always better than implicit in a spec.

---

**Issue 11: df type undeclared — integer vs. numeric**
Lens: 3
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

The spec does not state whether df quantities are stored as integer or numeric. The existing `.degf()` for replicate designs uses `max(1L, ncol(rep_mat) - 1L)`, which returns an integer. If `degf = Inf` is adopted (Issue 9 Option A), this is moot — `Inf` is always numeric. But the spec should still state the convention explicitly: "df quantities are stored as `numeric`, not `integer`, to preserve fractional precision if scaling formulas change."

---

**Issue 12: R = 1 edge case (df = 0) is unspecified**
Lens: 3
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec blocks R = 0 via `surveycore_error_repweights_empty`, but not R = 1. With a single bootstrap replicate, the variance estimate is computed from one deviation — numerically meaningless. Under `degf = Inf` (Issue 9 Option A), `stats::qt()` produces finite values so no hard crash occurs, but SE is effectively zero (or computed from a single-term sum). One bootstrap replicate is always methodologically invalid.

Fix: Add `surveycore_error_repweights_single` (or a similar error class) to the error table: thrown when `R = 1` at construction time. Add a corresponding row to `plans/error-messages.md`.

Options:
- **[A]** Error at construction when R = 1: `surveycore_error_repweights_single`. Bootstrap variance requires ≥ 2 replicates. — Effort: low, Risk: low, Impact: clear diagnostic, Maintenance: one new class in error-messages.md
- **[B]** Warning at construction when R = 1: SE = NA at estimation time. — Effort: low, Risk: low, Impact: softer stop
- **[C] Do nothing** — R = 1 silently produces degenerate SE with no diagnostic.

**Recommendation: A** — Consistent with blocking R = 0; one replicate is as meaningless as zero.

---

**Issue 13: No explicit output-label assertion (se vs. var) in the test plan**
Lens: 3
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

`.replicate_mean_cell()` applies `sqrt()` to convert variance to SE. The quality gate verifies numerical agreement with `survey_replicate` but does not assert that the `se` output is a square root of the variance. This would catch an accidental removal of the `sqrt()` step.

Fix: Add one test assertion: `result$se^2 ≈ .svy_rep_var(...)` for a non-degenerate case.

---

#### Lens 4 — Domain Estimation

---

**Issue 14: Silent dropping of domain-empty replicates understates SE for small NPS subgroups**
Lens: 4
Severity: REQUIRED
Resolution type: JUDGMENT CALL

The spec claims the existing replicate helpers "work without modification" for domain estimation on `survey_nonprob`. This is true for large domains in probability replicate designs, where bootstrap resampling almost never produces a replicate with zero domain representation. For NPS bootstrap with re-raking, it is not guaranteed: calibration constraints may force zero effective weight to a domain in some draws. When a replicate has `rep_N_d = 0`, `.replicate_mean_cell()` sets that replicate's estimate to `NA_real_`, and `.svy_rep_var()` silently drops it — but applies `scale = 1/R` computed for the full R replicates to only the surviving replicates. This understates variance.

Small domains, rare categories, and interaction cells (group × domain) are most at risk.

Options:
- **[A]** Add a warning when the fraction of dropped NA replicates exceeds a threshold (e.g., 5% of R): `surveycore_warning_domain_replicates_na`, emitted by the six replicate helpers when called on a `survey_nonprob` object. Note: this requires modifying the replicate helpers, contradicting the spec's "no modification needed" claim. — Effort: medium, Risk: low, Impact: warns users about unreliable SEs on small NPS domains, Maintenance: low
- **[B]** Document the limitation: add a note to the spec acknowledging that NA-dropped replicates understate SE for small NPS domains. Add a test that verifies the NA-drop behavior and documents the implication. Accept inherited behavior. — Effort: low, Risk: medium (silent wrong SEs persist), Impact: spec is honest about the limitation, Maintenance: none
- **[C] Do nothing** — Users working with small NPS subgroups receive understated SEs with no indication.

**Recommendation: A** — The NA-drop is benign for large probability-sample domains but is a meaningful accuracy hazard for NPS small-domain analysis (a primary use case). Adding a threshold-based warning costs little and prevents a category of silent errors. However, this requires modifying the replicate helpers, which the spec currently says are unchanged — the spec must update its "no modification needed" claim accordingly.

Source: Lumley (2010) *Complex Surveys* §9.3; the `survey` package emits a note when dropped replicates exceed 10% of R [verify exact threshold].

---

**Issue 15: Re-raking scope for domain estimation is unstated**
Lens: 4
Severity: REQUIRED
Resolution type: JUDGMENT CALL

The spec's Background states: "requires re-running the adjustment step... on each bootstrap replicate." For domain estimation, there are two re-raking strategies: (1) **full-sample re-raking** — rake over all NPS respondents per draw, estimate domain post-hoc by masking; (2) **domain-restricted re-raking** — rake only within the domain per draw. The spec uses full-sample replicate weights (one weight vector per draw for all respondents), which implies strategy (1). This is methodologically sound for most subgroup analyses, but the domain-specific SE reflects only full-sample calibration uncertainty, not domain-specific calibration uncertainty.

The spec does not state this assumption. Users analyzing small subgroups from calibration-heavy NPS designs may interpret the SEs as fully domain-specific when they are not.

Options:
- **[A]** Add one sentence to Background or Design: "Replicate weights from `surveywts::create_bootstrap_weights()` are full-sample calibration replicates. Domain SEs therefore reflect full-sample calibration uncertainty; domain-restricted re-calibration (which would require per-domain replicate weights) is out of scope." — Effort: low, Risk: none, Impact: users understand what their SEs measure, Maintenance: none
- **[B]** Do nothing — full-sample re-raking is standard; the distinction is implicit.

**Recommendation: A** — Single clarifying sentence removes an ambiguity that could cause users to over-interpret subgroup SEs in calibration-heavy NPS designs.

Source: Wu (2022) §4; Chen et al. (2021) — full-sample vs. domain-restricted calibration bootstrap.

---

**Issue 16: Empty-domain guard uses full-sample base weights — asymmetry with per-replicate NA handling not documented**
Lens: 4
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

The empty-domain early-return in `.replicate_mean_cell()` checks `sum(w * domain) <= 0` using the full-sample base weights. It does not check per-replicate domain weight. This is intentionally correct — per-replicate zero-domain handling is done by the `NA_real_` path in `.svy_rep_var()`. But the spec does not state this asymmetry or confirm it is deliberate.

Fix: Add one sentence in §3 confirming the empty-domain guard is intentionally on full-sample base weights, with per-replicate zero-domain behavior handled by `.svy_rep_var()`'s NA-drop.

---

**Issue 17: No test for domain + grouping composition path**
Lens: 4
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec's Testing section has tests for full-sample `get_means()` (with and without repweights) but no test for domain + grouping composition — e.g., `get_means(design, y, domain = age_group > 30, group = sex)`. This is the most common real-world NPS analysis pattern and exercises a different code path than either a pure domain test or a pure grouping test. The spec's correctness claim ("the existing helpers work without modification") cannot be fully validated without it.

Fix: Add the following to the Testing section under Happy path:

> - `get_means()` on a repweight-equipped `survey_nonprob` with both a domain filter and a `group` argument returns correct SE for each group × domain cell

---

#### Lens 5 — Established Practice and Literature

---

**Issue 18: Bootstrap `scale = 1/R` deviates from `survey` package convention (`1/(R-1)`) — undocumented**
Lens: 5
Severity: ADVISORY
Resolution type: JUDGMENT CALL

The `survey` package sets bootstrap scale to `1/(R-1)` by default. The spec inherits `1/R` from `as_survey_replicate()`. The statistical impact is a factor of `R/(R-1)` on variance — for `R = 200` this is 0.5%, negligible in practice. The deviation is intentional within surveycore but is not documented. Users comparing NPS bootstrap SEs to the `survey` package will encounter a small unexplained discrepancy.

Options:
- **[A]** Add a `@details` note to `as_survey_nonprob()` documentation explaining the `1/R` vs. `1/(R-1)` choice and why surveycore uses `1/R` (consistent with `as_survey_replicate()`). — Effort: low, Risk: none
- **[B]** Change to `1/(R-1)` — but this creates internal inconsistency with `as_survey_replicate()`, which is worse. Not recommended.
- **[C] Do nothing** — undocumented discrepancy from `survey` persists.

**Recommendation: A**

Source: `survey:::svrepdesign.default`, bootstrap section; Chrostowski et al. (2025) `nonprobsvy` package uses `1/R` form [verify].

---

**Issue 19: `mse = TRUE` default deviates from `survey` package default (`mse = FALSE`) — undocumented**
Lens: 5
Severity: ADVISORY
Resolution type: JUDGMENT CALL

The `survey` package defaults `mse` to `FALSE` (centering deviations on the mean of replicates). The spec inherits `mse = TRUE` from `as_survey_replicate()` (centering on the full-sample estimate). The choice is methodologically correct for NPS bootstrap — the full-sample calibrated estimate is the target and `mse = TRUE` correctly estimates variability relative to it — but the deviation from `survey` default is not documented.

Options:
- **[A]** Add a `@details` note explaining `mse = TRUE` deviates from `survey` default and why it is preferred for NPS bootstrap. — Effort: low
- **[B] Do nothing** — deviation persists undocumented.

**Recommendation: A**

Source: `survey:::svrVar`; `getOption("survey.replicates.mse")` returns `FALSE`; Lumley (2010) Chapter 9 [verify].

---

**Issue 20: Combined-weights assumption not documented**
Lens: 5
Severity: ADVISORY
Resolution type: JUDGMENT CALL

The replicate variance formula assumes `repweights` columns contain complete calibrated weights (combined weights), not fractional adjustment factors. The spec implies this via the workflow (surveywts produces bootstrap draws with full calibrated weights), but does not state it explicitly. A user who passes non-combined repweights (adjustment factors only) will receive silently wrong estimates — the Hájek-type estimator `sum(repwt * y) / sum(repwt)` requires combined weights.

Options:
- **[A]** Add a `@details` note stating that `repweights` must contain combined weights (full calibrated weight per replicate, not fractional adjustment factors), referencing `surveywts::create_bootstrap_weights()` as the intended source. — Effort: low
- **[B]** Add Option A plus a runtime heuristic plausibility check (e.g., warn if mean replicate weight is far from mean base weight). — Effort: medium, false-positive risk for extreme calibration designs
- **[C] Do nothing** — combined-weights assumption remains implicit.

**Recommendation: A** for Phase 2.5; revisit B if externally produced repweights from arbitrary sources are to be supported.

Source: `survey:::svrepdesign.default` `combined.weights` argument and plausibility checks; Wu (2022) §3.

---

**Issue 21: `get_quantiles()` is not in the dispatch table — uses `n-1` df instead of `Inf` for repweight-equipped `survey_nonprob`**
Lens: 5
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec's dispatch table (§3) covers six analysis helper files but omits `analysis-quantiles-helpers.R`. The `.degf_woodruff()` function in that file dispatches on class:

- `survey_replicate` → `R - 1`
- All others (including `survey_nonprob`) → `n - 1`

A repweight-equipped `survey_nonprob` should return `Inf` (per Issue 9, Option A). With `n = 5000` and `R = 200`, both `n-1 = 4999` and `R-1 = 199` are large enough to give near-identical CIs. But for `R = 50`, `n-1` gives meaningfully wider or narrower intervals at tail percentiles.

Fix: Add a branch to `.degf_woodruff()` for repweight-equipped `survey_nonprob` returning `Inf` (consistent with Issue 9). Add `analysis-quantiles-helpers.R` to the dispatch table in §3.

Options:
- **[A]** Add the `.degf_woodruff()` branch and the dispatch table row. — Effort: low, Risk: none, Impact: correct df for quantile CIs, Maintenance: none
- **[B] Do nothing** — `n-1` used for all `survey_nonprob` quantile CIs; small inconsistency with Issue 9 resolution.

**Recommendation: A**

Source: `survey:::svyquantile` uses `degf(design)` → `ncol(repweights) - 1` for `svrepdesign` objects.

---

**Issue 22: `get_ratios()` bypasses replicate dispatch for `survey_nonprob` — omitted from spec's dispatch table**
Lens: 5
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec's dispatch table omits `analysis-ratios-helpers.R`. In `get_ratios()`, the routing is:

```r
is_replicate <- S7::S7_inherits(design, survey_replicate)
```

A `survey_nonprob` with repweights is not a `survey_replicate`, so `get_ratios()` routes to `.delta_ratio_cell()` (Taylor linearization SE) even when repweights are present — silently inconsistent with `get_means()`, `get_freqs()`, and `get_totals()` on the same object.

Fix: Change the dispatch flag to:

```r
is_replicate <- S7::S7_inherits(design, survey_replicate) ||
  (S7::S7_inherits(design, survey_nonprob) &&
   !is.null(design@variables$repweights))
```

And add `analysis-ratios-helpers.R` to the dispatch table in §3.

Options:
- **[A]** Fix the dispatch flag and add the dispatch table row. — Effort: low, Risk: none, Impact: `get_ratios()` uses replicate variance consistently with other estimands, Maintenance: none
- **[B] Do nothing** — `get_ratios()` uses delta-method SE for `survey_nonprob` with repweights; inconsistent with all other `get_*()` functions on the same object.

**Recommendation: A** — Straightforward consistency fix.

Source: `analysis-ratios.R` line 210: `is_replicate <- S7::S7_inherits(design, survey_replicate)`.

---

**Issue 23: Methodological basis for routing to replicate helpers not cited**
Lens: 5
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

Goal 2 states: "all analysis functions compute SE from the replicate spread — identical machinery to `survey_replicate`." This is statistically correct, but the spec does not cite or articulate the justification. The justification is: the replicate variance formula `scale * sum(rscales * (theta_r - theta)^2)` is a general-purpose variance estimator that works for any estimand whose variability is captured by the spread of per-replicate estimates. When repweights encode full re-calibration (per Issue 5), the spread captures both sampling uncertainty and calibration estimation uncertainty — the two sources Wu (2022) and Chen et al. (2021) identify.

Fix: Add a `@section Variance estimation` paragraph to `as_survey_nonprob()` roxygen citing Wu (2022) and Chen et al. (2021) for the claim that bootstrap with re-calibration captures both variance sources.

---

### Summary (Pass 1)

| Severity | Count |
|----------|-------|
| BLOCKING | 2 |
| REQUIRED | 11 |
| ADVISORY | 10 |

**Total issues: 23**

**Blocking issues:** Issue 4 (scale NULL resolution — implementation ambiguity that would produce silent NULL SE) and Issue 9 (df policy entirely absent — `.degf()` returns wrong value for `survey_glm()` on NPS objects).

**Critical structural gaps:** Issue 2 (workflow diagram contradicts itself on whether calibration is re-run per draw), Issue 21 (quantiles dispatch table omission), Issue 22 (ratios dispatch table omission), Issue 3 (type restriction — jackknife is statistically invalid for NPS).

**Assessment:** The variance machinery chosen (routing to existing replicate helpers) is statistically defensible and consistent with established NPS bootstrap practice. The two blocking issues are specification ambiguities, not methodological errors — the approach is correct. The eleven REQUIRED issues are completeness gaps: two missing dispatch table entries (quantiles, ratios), a missing df policy, undocumented preconditions, and test plan gaps. None of the issues require fundamental redesign. Resolving Issues 1 and 3 together via a `type = "bootstrap"` restriction would also simplify the scale default logic and eliminate the mse footgun in a single decision.
