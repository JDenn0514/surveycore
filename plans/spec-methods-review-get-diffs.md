# Methodology Review: get-diffs

## Pass 1 (2026-03-16)

### New Issues

#### Lens 1 — Estimator Specification

**Issue 1: Contrast function not validated — clean path assumes treatment contrasts**
Severity: BLOCKING
Resolution type: UNAMBIGUOUS

The clean path (Section 3.7) extracts the intercept as the reference group mean:
> "Extract reference row (intercept): the row where `term == "(Intercept)"`.
> `reference_mean <- tidy_result$estimate` for this row (the intercept IS the
> reference group mean for a factor-only model)."

This formula holds **only under treatment contrasts** (`contr.treatment()`). Under
Helmert contrasts the intercept is the grand mean; under sum contrasts it is the
unweighted mean of level means. The spec coerces `treats` to factor (Section 3.6)
but does not validate which contrast function is in effect.

`stats::reformulate()` builds the formula, and `survey_glm()` fits the model using
whatever contrasts are set on the factor. If a user pre-sets non-treatment contrasts
(via `contrasts<-()` or `options(contrasts = ...)`), the clean path silently produces
wrong reference means and wrong treatment effects.

Options:
- **[A]** Add validation in Section 3.6 (after `relevel()`): check that the
  effective contrast function is `contr.treatment`. If not, either error
  (`surveycore_error_unsupported_contrasts`) or force treatment contrasts
  explicitly via `contrasts(data[[treats_name]]) <- contr.treatment`. Add the
  error class to `error-messages.md`. — Effort: low, Risk: low, Impact: prevents
  silent wrong results, Maintenance: none
- **[B]** Route all configurations through the marginaleffects path (which
  computes AMEs without depending on contrast interpretation). — Effort: medium,
  Risk: low, Impact: removes the clean path entirely, Maintenance: adds
  marginaleffects as a hard dependency for all calls
- **[C] Do nothing** — Rely on R's default `contr.treatment`. Wrong results if
  the user has changed contrasts.

**Recommendation: [A]** — Validate and/or force treatment contrasts. Low cost,
eliminates a class of silent errors.

Source: R documentation for `stats::contr.treatment()`; Phase 2 spec Section 6.3
(reference level detection assumes treatment contrasts).

---

**Issue 2: Interaction model and group-specific slopes not explained**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Section 3.5 builds `x ~ treats * group + covariates` when `group` is provided, and
Section 3.8.1 calls `avg_slopes(fit, variables = treats_name, by = group_names)`.
The spec does not explain how the interaction term creates group-specific treatment
effects:

```
x ~ treats + group + treats:group + covariates
dY/d(treats) = beta_treats + beta_interact * I(group = g)
```

A reader might assume the model is additive (no interaction). The spec should
document that the `treats:group` interaction allows the treatment effect to differ
by subgroup, and that `avg_slopes(by = group)` correctly incorporates this.

Options:
- **[A]** Add explanatory paragraph to Section 3.5 describing the interaction
  expansion and its effect on slope computation. Note that hypothesis testing on
  the interaction coefficient itself requires `summary(fit)`. — Effort: low,
  Risk: low, Impact: clarity, Maintenance: none
- **[C] Do nothing** — Readers must infer from the formula notation.

**Recommendation: [A]** — One paragraph of documentation clarifies a non-obvious
statistical dependency.

Source: Standard GLM interaction theory; marginaleffects documentation for `by`
argument.

---

**Issue 3: SRS full covariance matrix verification needed in tests**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Phase 2 spec Section 8.4 explicitly warns:
> "Using only the diagonal (column-wise variances) is incorrect when bread is
> non-diagonal, which is almost always the case with multiple predictors."

The `get_diffs()` test plan (Section 9.1) specifies a multivariate oracle test but
does not explicitly verify that off-diagonal elements of the design-based vcov match
`survey::svyglm()`. A diagonal-only implementation would pass point-estimate tests
but produce wrong SEs for treatment effects when covariates are correlated.

Options:
- **[A]** Add to Section 9.1 (Numerical Tests): for multivariate tests, verify
  that off-diagonal elements of `fit@vcov` are non-zero (where expected) and
  match `survey::svyglm()` within tolerance 1e-8. — Effort: low, Risk: low,
  Impact: catches a common variance implementation bug, Maintenance: one test
- **[C] Do nothing** — Rely on SE matching to implicitly catch this.

**Recommendation: [A]** — Explicit off-diagonal verification is a stronger test.

Source: Phase 2 spec Section 8.4 (SRS variance formula with full meat matrix).

---

**Issue 4: Reference row extraction needs defensive validation**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

Section 3.7 Step 3 extracts the reference row via `term == "(Intercept)"` from
`clean()` output. If `clean()` output format changes or the GLM fit is degenerate,
this extraction could silently fail.

Options:
- **[A]** Add validation: if zero or multiple rows match `term == "(Intercept)"`,
  error with `surveycore_error_reference_row_not_found`. — Effort: low, Risk:
  low, Impact: defensive, Maintenance: none
- **[C] Do nothing** — `clean()` contract guarantees exactly one intercept row.

**Recommendation: [A]** — Low-cost defensive check.

---

#### Lens 2 — Variance Estimation

**Issue 5: Clean path variance not documented as design-class-aware**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Section 3.7 extracts `se`, `ci_low`, `ci_high` from `clean()` output without
stating that these are computed via the design-class-specific Binder sandwich
variance from `survey_glm()@vcov`. Readers must cross-reference Phase 2 spec
Section VIII to confirm variance correctness for Taylor, replicate, two-phase, SRS,
and nonprob designs.

Options:
- **[A]** Add one sentence to Section 3.7 after Step 2: "The `clean()` function
  returns `std_error` and CI bounds computed from `fit@vcov`, which is the
  design-based Binder sandwich variance (per Phase 2 spec Section VIII). Variance
  computation is design-class-specific." — Effort: low, Risk: low, Impact:
  clarity, Maintenance: none
- **[C] Do nothing** — Cross-reference to Phase 2 is implicit.

**Recommendation: [A]** — One sentence makes the spec self-contained.

---

**Issue 6: Delta method chain for marginaleffects path not documented**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

*Cross-lens: also flagged by Lens 1 (delta method) and Lens 5 (AME convention).*

Section 3.8.1 shows the `avg_slopes()` call and states that it returns `estimate`
and `std.error`, but does not document that:

1. The SE is computed via the delta method using `vcov()` from `survey_glm_fit`
2. The Phase 2 marginaleffects extension registers `get_vcov()` returning the
   Binder sandwich variance
3. For non-gaussian families, the numerical Jacobian of the inverse link converts
   from linear predictor to response scale

Without this, readers cannot verify the correctness of the SE chain.

Options:
- **[A]** Add a "Methodological Note" paragraph in Section 3.8 explaining: (a)
  marginaleffects uses the delta method on `vcov()`, (b) `get_vcov()` returns the
  design-based sandwich, (c) the Jacobian is model-based (numerical derivatives),
  (d) this hybrid (design-based variance + model-based Jacobian) is standard. —
  Effort: low, Risk: low, Impact: critical for reviewers, Maintenance: none
- **[C] Do nothing** — Assume readers know marginaleffects internals.

**Recommendation: [A]** — This is the most important variance chain in the spec;
document it.

Source: Phase 2 spec Section VII (marginaleffects extension interface); Binder
(1983), JASA 78(382):626-631.

---

**Issue 7: Non-gaussian oracle tests missing from test plan**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Section 9.1 (Numerical Tests) specifies oracle tests for bivariate OLS but does not
require oracle tests comparing non-gaussian AMEs against a reference pipeline
(`survey::svyglm()` + `marginaleffects::avg_slopes()`).

For logistic regression, the score includes family-specific working residuals. A
Gaussian-specific formula (using response residuals instead of working residuals)
produces no error — just wrong SEs. Without oracle testing, this bug is invisible.

Options:
- **[A]** Add to Section 9.1:
  - Logistic regression: binary DV, compare AME and SE against
    `survey::svyglm(..., family = quasibinomial()) + marginaleffects::avg_slopes()`.
    Tolerance: 1e-6 for AME, 1e-6 for SE.
  - Poisson regression: count response, same comparison.
  — Effort: medium, Risk: low, Impact: catches sandwich bugs for non-gaussian,
  Maintenance: two test blocks
- **[C] Do nothing** — Phase 2 spec already has these tests; assume they catch
  bugs before `get_diffs()` uses them.

**Recommendation: [A]** — End-to-end oracle tests at the `get_diffs()` level catch
integration bugs that unit-level Phase 2 tests may miss.

---

**Issue 8: Marginaleffects oracle test tolerances not specified**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Section 9.1 specifies tolerances only for "Bivariate OLS" tests (1e-8 for
estimates, 1e-6 for SEs). The marginaleffects path has no stated tolerances.

Options:
- **[A]** Add to Section 9.1: "Marginaleffects oracle tests use: 1e-10 for point
  estimates, 1e-8 for SEs, 1e-6 for CI bounds — matching Phase 2 spec Section
  IX." — Effort: low, Risk: low, Impact: implementers have a clear target,
  Maintenance: none
- **[C] Do nothing** — Implementers guess.

**Recommendation: [A]** — State the tolerances explicitly.

---

#### Lens 3 — Degrees of Freedom and Inference

**Issue 9: P-value distribution inconsistent across estimation paths (t vs Z)**
Severity: BLOCKING
Resolution type: JUDGMENT CALL

The clean path produces p-values from `clean()`, which uses the t-distribution with
design-based df = `degf(design) - (p - 1)` (Phase 2 spec Section 6.3):
> "`p_value` — Two-sided p-value from t-distribution with `degf - (p - 1)` df."

The marginaleffects path produces p-values from `avg_slopes()`, which by default
uses the **normal (Z) distribution** — i.e., infinite df. This creates a
discontinuity: the same treatment effect can produce different p-values and narrower
CIs depending on whether the user adds one covariate (forcing the marginaleffects
path).

No warning alerts the user to this regime change, and the output labels p-values
identically regardless of path.

Options:
- **[A]** Document the inconsistency explicitly. Add `.meta$pvalue_distribution`
  key recording `"t"` or `"z"` per path. Consider emitting
  `surveycore_warning_inference_method_change` when the marginaleffects path is
  used. — Effort: medium, Risk: low, Impact: transparency without changing
  inference, Maintenance: low
- **[B]** Force design-based df on the marginaleffects path. Pass `df` to
  `marginaleffects::avg_slopes()` via the `vcov` or `df` argument (if supported)
  to force t-distribution inference. — Effort: high, Risk: medium
  (marginaleffects API compatibility), Impact: full consistency across paths,
  Maintenance: tied to marginaleffects API evolution
- **[C] Do nothing** — Silent inconsistency between paths.

**Recommendation: [B] if feasible, else [A]** — Full consistency is ideal. If
marginaleffects supports a `df` argument (check API), use it. Otherwise, document
the inconsistency so users can make informed decisions.

Source: Phase 2 spec Section 6.3 (t-distribution with design df); marginaleffects
documentation (default Wald Z); [verify] marginaleffects source for df parameter
support.

---

**Issue 10: DF formula for p-values not explicitly specified in get_diffs()**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec does not state the degrees of freedom formula used for computing p-values
in either path. Phase 2 spec Section 8.5 defines `df_residual = degf(design) -
(p - 1)`, but `get_diffs()` does not cross-reference this.

Options:
- **[A]** Add to Section 3.8.3 (Assembly): "P-values are computed using
  design-based residual df: `df = degf(design) - (p - 1)`, where `p` is the total
  number of GLM coefficients (including intercept). This follows Phase 2 spec
  Section 8.5." — Effort: low, Risk: low, Impact: clarity, Maintenance: none
- **[C] Do nothing** — Readers cross-reference Phase 2.

**Recommendation: [A]** — Cross-reference explicitly.

---

**Issue 11: P-value and CI labels should differentiate by estimation path for
non-gaussian families**
Severity: REQUIRED
Resolution type: JUDGMENT CALL

When `marginaleffects::avg_slopes()` is used for non-gaussian families, `estimate`
is the AME on the response scale (e.g., probability for logistic), and `p_value`
tests whether the AME differs from zero. The clean path's `estimate` is the
coefficient. The spec labels both identically (Section 5.5):
> `estimate` label: `"Difference relative to {ref_level}"`
> `p_value` label: `"P-Value"`

A user seeing `p_value = 0.03` cannot tell from the label whether this tests a
coefficient or an AME.

Options:
- **[A]** Dynamically set column labels based on path:
  - Clean path: `"Difference relative to {ref_level}"` (coefficient)
  - Marginaleffects path (non-gaussian): `"Avg. Marginal Effect vs {ref_level}"`
  — Effort: low, Risk: low, Impact: users see the scale in the output,
  Maintenance: label logic in `.attach_col_labels()`
- **[B]** Add `.meta$estimate_scale` key recording `"coefficient"` or `"ame"`.
  Leave column labels generic. — Effort: low, Risk: low, Impact: transparent in
  metadata but not visible in print, Maintenance: none
- **[C] Do nothing** — Assume users understand the scale from the family.

**Recommendation: [A]** — Dynamic labels are low-cost and solve the problem at the
point of use.

Source: Lens 3 output-labeling check: "Does every displayed quantity match its
label?"

---

**Issue 12: Non-integer df must be preserved (not truncated)**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

For replicate designs, `degf()` returns non-integer values (e.g., 99.0 for 100 BRR
replicates). The spec does not explicitly forbid integer coercion of df values. If
downstream code truncates df to integer, t-distribution quantiles become
inconsistent.

Options:
- **[A]** Add to spec: "All df values are numeric (double), never integer.
  Preserve decimal places through t-distribution quantile lookup." Add test:
  replicate design with non-integer degf produces CI bounds matching manual
  `qt(0.975, df = degf_value)`. — Effort: low, Risk: low, Impact: prevents
  subtle rounding, Maintenance: none
- **[C] Do nothing** — Phase 2 already specifies numeric df.

**Recommendation: [A]** — Explicit guidance + one test.

Source: Phase 2 spec Section 2.2 (df computation preserves numeric type).

---

**Issue 13: Reference row p_value = NA semantics not explained**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

Section 5.4 specifies `p_value = NA_real_` for the reference row but does not
explain why. Users may interpret `NA` as a computation failure rather than an
intentional absence.

Options:
- **[A]** Add one sentence to Section 5.4: "The reference row has `p_value = NA`
  because no hypothesis test exists for the baseline (the difference from itself
  is zero by definition)." — Effort: negligible, Risk: none, Impact: clarity,
  Maintenance: none
- **[C] Do nothing** — Users infer from context.

**Recommendation: [A]** — One sentence.

---

#### Lens 4 — Domain Estimation

**Issue 14: Replicate domain convergence with marginaleffects unspecified**
Severity: BLOCKING
Resolution type: UNAMBIGUOUS

Phase 2 spec Section 4.5 specifies: "If a replicate refit on in-domain rows fails
to converge, warn with `surveycore_warning_glm_convergence` and use beta_r = beta
(zero deviation)." This handles the `survey_glm()` layer.

However, `get_diffs()` uses `marginaleffects::avg_slopes()` on the fitted model. If
a domain filter leaves very few in-domain rows and some replicate subsets are
degenerate, the marginaleffects delta method computation may fail or produce `NaN`
SEs. The spec does not specify behavior when `avg_slopes()` encounters degenerate
replicate subsets.

Options:
- **[A]** Add test in Section 9.1 (`test-diffs-numerical.R`): call `get_diffs()`
  on a replicate design with a tight domain filter causing some replicates to have
  near-zero in-domain rows. Verify that `avg_slopes()` handles gracefully (with
  warning) or errors with a typed message. Document the expected behavior. —
  Effort: medium, Risk: low, Impact: prevents silent NaN propagation, Maintenance:
  one test
- **[C] Do nothing** — Assume Phase 2 catches this before marginaleffects sees it.

**Recommendation: [A]** — Integration test at the `get_diffs()` level catches
problems that unit-level Phase 2 tests may miss.

Source: Phase 2 spec Section 4.5 (domain estimation contract).

---

**Issue 15: Empty domain error not in get_diffs() error table**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Section 3.13 states `survey_glm()` respects the domain mask from `filter()`, but
Section VI (Error & Warning Conditions) does not list
`surveycore_error_empty_domain` as a propagated error. If a user calls
`filter(impossible_condition) |> get_diffs(...)`, the error comes from
`survey_glm()` but is not documented in the `get_diffs()` error table.

Options:
- **[A]** Add `surveycore_error_empty_domain` to Section 6.1 with note: "from
  `survey_glm()`, propagates unchanged." — Effort: negligible, Risk: none,
  Impact: complete error documentation, Maintenance: none
- **[C] Do nothing** — Users discover it at runtime.

**Recommendation: [A]** — Add to error table.

---

**Issue 16: `n` column calculation ambiguous with domain filtering**
Severity: REQUIRED
Resolution type: JUDGMENT CALL

Section 3.8.3 says: "Compute `n` per treatment level (+ group) from `design@data`
directly (unweighted count)."

With domain filtering, `design@data` contains both in-domain and out-of-domain rows
(domain mask is in `..surveycore_domain..`). The spec does not specify whether `n`
counts all rows or only in-domain rows.

Options:
- **[A]** Report in-domain counts only: "Compute `n` per treatment level by
  counting rows where `design@data[[..surveycore_domain..]] == TRUE`." This
  matches the sample size used for variance estimation. — Effort: low, Risk: low,
  Impact: internal consistency, Maintenance: none
- **[B]** Report total counts with a separate `.meta$n_domain` tracking in-domain
  count. — Effort: medium, Risk: low, Impact: full transparency, Maintenance:
  document new `.meta` key
- **[C] Do nothing** — Ambiguous; implementer decides.

**Recommendation: [A]** — `n` should reflect the observations used for inference.

---

**Issue 17: `.meta$n_respondents` definition ambiguous with domain filtering**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Section IV defines `n_respondents` as "Total rows in design (regardless of
groups/domain)." This is ambiguous: does "design" mean the original design or the
design after `filter()`?

Phase 2 `clean()` provides `n_observations` = "Unweighted row count after domain
filtering and na.action" (Section 6.3), which is post-filtering. Using a different
definition in `get_diffs()` creates confusion.

Options:
- **[A]** Clarify: `n_respondents` = `nrow(design@data)` — total rows in the
  design object as passed to `get_diffs()`, before `na.action`. This includes
  out-of-domain rows (they are still in `@data`). Document this explicitly. —
  Effort: low, Risk: low, Impact: unambiguous, Maintenance: none
- **[C] Do nothing** — Readers guess.

**Recommendation: [A]** — State the definition precisely.

---

**Issue 18: Domain + @groups interaction not clarified**
Severity: ADVISORY
Resolution type: JUDGMENT CALL

Section 3.14 says groups are "combined with the `group` argument" but does not
specify how domain filtering interacts with grouping. When both are present, the
spec should clarify that the domain filter is applied uniformly across all group
strata.

Options:
- **[A]** Add to Section 3.14: "When both domain filtering and `@groups` are
  active, the domain filter is applied uniformly to all group strata. The GLM is
  fit on rows matching both domain and non-missing group values." — Effort: low,
  Risk: low, Impact: clarity, Maintenance: none
- **[C] Do nothing** — Behavior is implicit in `survey_glm()`.

**Recommendation: [A]** — One clarifying sentence.

---

#### Lens 5 — Established Practice and Literature

**Issue 19: AME choice for non-gaussian families not documented as intentional
deviation from survey package**
Severity: REQUIRED
Resolution type: JUDGMENT CALL

The spec uses `marginaleffects::avg_slopes()` for non-gaussian families (Section
3.8.1), returning average marginal effects on the response scale (e.g., probability
differences for logistic). The `survey` package reports coefficients on the **link
scale** (log-odds for logistic). This is a deliberate design choice but the spec
does not document it as a deviation or explain the rationale.

Options:
- **[A]** Add to Section 3.8 or roxygen `@details`: "For non-gaussian families,
  `get_diffs()` reports average marginal effects (AMEs) on the response scale, not
  coefficients on the link scale. This departs from `survey::svyglm()` convention
  and is intentional: AMEs are more interpretable for treatment effect reporting
  (see Gomila 2021)." — Effort: low, Risk: low, Impact: users understand the
  design choice, Maintenance: none
- **[B]** Add `scale` argument (`"ame"` or `"link"`) for user control. — Effort:
  medium, Risk: medium, Impact: flexibility, Maintenance: ongoing
- **[C] Do nothing** — SOP documents the choice separately.

**Recommendation: [A]** — Document the deviation in the spec itself.

Source: Gomila, R. (2021). *Journal of Experimental Psychology: General*,
150(3):700-709 [verify]; SOP Section 7.3.

---

**Issue 20: P-value adjustment scope with groups undefined**
Severity: REQUIRED
Resolution type: JUDGMENT CALL

Section 3.9 says: "Apply `stats::p.adjust(p_values, method = pval_adj)` to
comparison rows only." When `group` is active, the output has multiple comparison
rows per group. The spec does not define whether p-adjustment is:

1. Applied separately within each group (each group's comparisons adjusted
   independently)
2. Applied globally across all comparison rows (pooled across groups)

These produce different adjusted p-values. The SOP (Section 6.4) recommends BH
adjustment for "multiple DVs and multiple subgroups" — suggesting group-stratified
adjustment.

Options:
- **[A]** Apply adjustment separately within each group. Document: "When `group` is
  active, `p.adjust()` is applied independently within each group stratum. The
  multiple testing correction applies to comparisons against the reference within a
  group, not across groups." — Effort: low, Risk: low, Impact: correctness,
  Maintenance: none
- **[B]** Apply adjustment globally across all comparison rows. — Effort: low,
  Risk: low, Impact: more conservative, Maintenance: none
- **[C] Do nothing** — Implementer decides.

**Recommendation: [A]** — Group-stratified adjustment is the standard for subgroup
analysis and aligns with the SOP.

Source: Benjamini & Hochberg (1995), JRSS-B 57(1):289-300 [verify]; SOP Section
6.4.

---

**Issue 21: Percentage change — no variance, small-ref caveat, not standard
estimand**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

*Cross-lens: flagged by Lens 1 (small reference mean), Lens 2 (no variance), and
Lens 5 (not a standard survey estimand).*

Section 3.10 computes `pct_change = estimate / reference_mean` as a point estimate.
Three concerns:

1. **No variance:** The `se`, `ci_low`, `ci_high` columns apply to `estimate`, not
   `pct_change`. The spec does not state that `pct_change` has no uncertainty
   quantification.
2. **Small reference mean:** When `reference_mean` is very small (but nonzero),
   `pct_change` becomes very large and potentially misleading. The spec only
   handles the exact-zero case.
3. **Not a standard survey estimand:** The survey literature does not define
   `estimate / reference_mean` as a formal estimand with known statistical
   properties.

Options:
- **[A]** Add documentation to Section 3.10:
  - "Only the point estimate `pct_change` is reported. SE and CI are not computed
    for `pct_change`; users requiring confidence intervals should apply the delta
    method to `estimate` and `reference_mean`."
  - "Percentage change is substantively interpretable only when `reference_mean` is
    a meaningful nonzero baseline. For outcomes with baseline near zero, consider
    reporting the absolute difference (`estimate`) instead."
  — Effort: low, Risk: low, Impact: clarity and statistical integrity, Maintenance:
  none
- **[B]** Compute delta-method SE/CI for `pct_change`. — Effort: high, Risk:
  medium, Impact: completeness, Maintenance: substantial
- **[C] Do nothing** — Users figure it out.

**Recommendation: [A]** — Document the limitations. Computing variance for the
ratio adds substantial complexity for an optional display feature.

Source: Korn & Graubard (1999), *Analysis of Health Surveys* (delta method for
ratios) [verify].

---

**Issue 22: Clean path coefficient = AME equivalence assumption not documented**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec uses two different estimation methods that produce identical results only
under specific conditions. The clean path (Section 3.7) extracts OLS coefficients;
the marginaleffects path (Section 3.8) computes AMEs. These are mathematically
identical **only when**: (a) family is Gaussian with identity link, (b) the model
has a single factor predictor (no covariates), (c) no interactions.

The routing logic (Section 7.2) enforces these conditions, but the spec does not
explicitly state this equivalence or explain why it holds.

Options:
- **[A]** Add to Section 3.7: "This equivalence (coefficient = AME) holds only for
  Gaussian/identity + factor-only models. The routing logic (Section 7.2)
  guarantees these conditions. If the routing conditions change, the clean path
  must be re-validated." — Effort: low, Risk: low, Impact: clarity, Maintenance:
  none
- **[C] Do nothing** — Readers reverse-engineer the routing logic.

**Recommendation: [A]** — Make the assumption explicit.

Source: Angrist & Pischke (2009), *Mostly Harmless Econometrics* [verify].

---

**Issue 23: CI bounds unaffected by pval_adj not documented for users**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

Section 3.9 correctly states CIs are not recalculated after p-value adjustment, but
this should be surfaced in roxygen documentation so users don't assume CIs reflect
the adjusted significance level.

Options:
- **[A]** Add to roxygen `@details`: "Confidence intervals reflect the specified
  `conf_level` and are not affected by p-value adjustment." — Effort: low, Risk:
  none, Impact: prevents confusion, Maintenance: none
- **[C] Do nothing** — Spec is clear; roxygen inherits from spec.

**Recommendation: [A]** — One sentence.

---

**Issue 24: Unweighted `n` vs effective sample size distinction**
Severity: ADVISORY
Resolution type: JUDGMENT CALL

Section 5.2 includes an `n` column: unweighted observation count. The `survey`
package does not report unweighted N in estimation output. For design-based
inference, the "effective sample size" (`n_eff = (sum(w))^2 / sum(w^2)`) is more
relevant than the raw count.

The unweighted `n` is useful for quality assurance (small cell detection, per the
`surveycore_warning_small_cell` at n < 30), but users might misinterpret it as a
design-effective sample size.

Options:
- **[A]** Document: "`n` reports unweighted counts and is provided primarily for
  quality assurance. Inference (estimates, SEs, p-values) is design-based and uses
  weighted data." — Effort: low, Risk: low, Impact: clarity, Maintenance: none
- **[B]** Add `n_eff` column alongside `n`. — Effort: medium, Risk: low, Impact:
  completeness, Maintenance: ongoing
- **[C] Do nothing** — Users understand from context.

**Recommendation: [A]** — Document the distinction.

Source: Korn & Graubard (1999) (effective sample size definition) [verify].

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 3 |
| REQUIRED | 15 |
| ADVISORY | 6 |

**Total issues:** 24

| # | Title | Lens | Severity | Resolution |
|---|---|---|---|---|
| 1 | Contrast function not validated | 1, 5 | BLOCKING | UNAMBIGUOUS |
| 2 | Interaction model not explained | 1 | REQUIRED | UNAMBIGUOUS |
| 3 | SRS covariance matrix verification | 1 | REQUIRED | UNAMBIGUOUS |
| 4 | Reference row defensive validation | 1 | ADVISORY | UNAMBIGUOUS |
| 5 | Clean path variance not documented | 2 | REQUIRED | UNAMBIGUOUS |
| 6 | Delta method chain not documented | 1, 2 | REQUIRED | UNAMBIGUOUS |
| 7 | Non-gaussian oracle tests missing | 2 | REQUIRED | UNAMBIGUOUS |
| 8 | Marginaleffects test tolerances | 2 | REQUIRED | UNAMBIGUOUS |
| 9 | P-value distribution t vs Z | 3 | BLOCKING | JUDGMENT CALL |
| 10 | DF formula not specified | 1, 3 | REQUIRED | UNAMBIGUOUS |
| 11 | Labels by estimation path | 3 | REQUIRED | JUDGMENT CALL |
| 12 | Non-integer df preservation | 3 | REQUIRED | UNAMBIGUOUS |
| 13 | Reference row NA semantics | 3 | ADVISORY | UNAMBIGUOUS |
| 14 | Replicate domain convergence | 4 | BLOCKING | UNAMBIGUOUS |
| 15 | Empty domain error undocumented | 4 | REQUIRED | UNAMBIGUOUS |
| 16 | n column with domain filtering | 4 | REQUIRED | JUDGMENT CALL |
| 17 | n_respondents ambiguous | 4 | REQUIRED | UNAMBIGUOUS |
| 18 | Domain + groups interaction | 4 | ADVISORY | JUDGMENT CALL |
| 19 | AME deviation not documented | 5 | REQUIRED | JUDGMENT CALL |
| 20 | P-value adjustment scope | 5 | REQUIRED | JUDGMENT CALL |
| 21 | Percentage change limitations | 1, 2, 5 | REQUIRED | UNAMBIGUOUS |
| 22 | Coefficient = AME equivalence | 1, 5 | REQUIRED | UNAMBIGUOUS |
| 23 | CI unaffected by pval_adj | 5 | ADVISORY | UNAMBIGUOUS |
| 24 | Unweighted n vs n_eff | 5 | ADVISORY | JUDGMENT CALL |

**Assessment:** The estimation architecture is sound — `get_diffs()` correctly
delegates to `survey_glm()` for variance and `marginaleffects` for AMEs. The three
blocking issues are: (1) missing contrast validation in the clean path, which would
silently produce wrong reference means under non-treatment contrasts; (2)
inconsistent p-value distributions between the t-based clean path and Z-based
marginaleffects path; and (3) unspecified behavior when replicate domain subsets are
degenerate in the marginaleffects path. The remaining 15 required issues are
documentation gaps, missing oracle tests, and underspecified edge cases — all
addressable without architectural changes.
