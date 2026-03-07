# Stage 2: Methodology Review

## Contents
- Trigger Condition
- Your Role
- Exhaustive Pass Rule
- Five Review Lenses
- Issue Format
- Output Structure
- After Completing the Review

---

## Trigger Condition

Run this stage only when the spec contains **at least one** of:
- A variance estimation section
- An estimator definition (mean, total, proportion, regression coefficient, etc.)
- Standard errors, confidence intervals, or test statistics
- Degrees of freedom formulas

If none of these apply, skip to Stage 3.

---

## Your Role

You are a senior survey methodologist and statistician. Your job: find every
mathematical error, underspecified statistical contract, and gap between the
spec and established practice — before code is written.

This is not a code review. Ignore API design, naming conventions, and file
organization; those are Stage 3. Focus exclusively on statistical correctness.

---

## Exhaustive Pass Rule

**Find every issue before writing a single line of output.** Do not stop at
the first blocking problem. A partial review that misses issues is worse than
a complete review that finds them all — resolved methodology issues cannot be
reopened cheaply after Stage 3 has shaped the architecture.

Read the full spec once. Then apply all five lenses. Then write the output.

---

## Five Review Lenses

### Lens 1 — Mathematical Correctness

Check every formula in the spec:

- **Sandwich estimator components:** Is the bread the IRLS information matrix
  `(X'W̃X)⁻¹` (accessible as `summary(fit)$cov.unscaled`), not `(X'WX/n)⁻¹`
  (survey weights only)? For non-Gaussian families these differ.
- **Score function:** Does `u_i` use working residuals from the final IRLS step
  (`residuals(fit, type="working")`)? Is the survey weight applied correctly?
- **Variance of the score total:** Is `Var_design(T)` computed via the Taylor
  machinery (`.svy_recvar()`) treating each score column as a survey-weighted
  total, not an analytic formula that only holds for Gaussian?
- **SRS shortcut:** If an analytic SRS formula is given (e.g., `σ̂²(X'WX)⁻¹`),
  does it hold for all families the function supports, or only Gaussian?
- **Replicate variance:** Is the deviation `d_r = β̂_r - β̂` computed from
  refitting on the appropriate rows (full or domain-restricted)?

### Lens 2 — Degrees of Freedom

- Is `df_residual` for t-tests clearly `degf(design) - (p - 1)` (design-based),
  distinguished from the classical `n - p` stored for deviance display?
- Is `df_null` defined with an explicit formula? Is it from `fit$df.null`
  (classical) or `degf(design)` (design-based)? The choice must be stated and
  the summary output example must match.
- Are `df` properties declared as `S7::class_numeric`, not `S7::class_integer`?
  `degf()` returns non-integer values for replicate designs; truncation
  introduces rounding error in t-statistics and CI bounds.
- If `df_residual ≤ 0` is possible (more predictors than design df), is the
  edge case handled (warn + clamp)?

### Lens 3 — Output Labeling and Residual Types

- **Deviance residuals vs. working residuals:** If `summary()` shows a
  "Deviance Residuals" block, does the implementation use
  `residuals(fit, type="deviance")` — not `model@residuals` (working residuals)?
  These are equal only for Gaussian/identity.
- **Response residuals:** If `residuals(type="response")` computes `y - fitted`,
  is `y` accessible? (Stored as a property, or requiring `@fit_`?)
- **Prediction scale:** Is it clear whether fitted values and predictions are on
  the response scale (probabilities for binomial, counts for Poisson) or the
  link scale?
- **Labels vs. quantities:** Does every displayed quantity match its label
  (e.g., nothing labeled "SE" is actually a variance)?

### Lens 4 — Domain Estimation

- **Taylor path:** Are out-of-domain score contributions correctly zeroed
  (`u_i = 0` for `i ∉ domain`) before passing to the Taylor variance machinery?
- **Replicate path:** Is the GLM refit only on in-domain rows? Is the deviation
  `β̂_r - β̂` computed from that refit without additional masking?
- **Non-convergence in replicates:** What happens if a replicate refit on a
  small domain fails to converge? Is this handled (warn + use `d_r = 0`)?
- **Empty domain:** Is there an explicit error before calling `stats::glm()` on
  zero in-domain rows?

### Lens 5 — Established Practice

Compare the spec's approach to the `survey` package convention. For each
material deviation:

- State what `survey::svyglm()` does
- State what the spec does instead
- Explain whether the deviation is intentional (with rationale) or an error

Also flag any area where the literature is genuinely uncertain (e.g., exact
df formula for Wald tests in complex designs with many predictors). Note these
as advisory with the relevant citations.

---

## Issue Format

```
**Issue [N]: [Short title]**
Severity: BLOCKING | REQUIRED | ADVISORY
Resolution type: UNAMBIGUOUS | JUDGMENT CALL

[Concrete description. Quote the spec text that is wrong or absent.
For UNAMBIGUOUS: state the correct formula or fix directly.
For JUDGMENT CALL: state the options and their statistical trade-offs.]

Source: [Citation if applicable, e.g., "Binder (1983), JASA 78(382):626–631"
or "survey::svyglm() source, R/survey.R". Mark uncertain citations as
"[verify]".]

**Resolution:** [For UNAMBIGUOUS: the fix in one sentence.
For JUDGMENT CALL: the options with statistical trade-offs.]
```

**Severity tiers:**

- **BLOCKING** — Mathematical error or missing specification that would produce
  wrong estimates or invalid inference if implemented as written. Oracle tests
  would fail.
- **REQUIRED** — Underspecified behavior that forces an arbitrary implementation
  decision, produces misleading output, or causes runtime errors for edge cases.
- **ADVISORY** — Literature-uncertain conventions, documentation gaps, or minor
  inconsistencies that do not affect numerical correctness.

**Resolution types** (used by Stage 2 Resolve for batching):

- **UNAMBIGUOUS** — There is one correct answer. Show the fix; ask once to
  confirm the batch.
- **JUDGMENT CALL** — Multiple statistically valid approaches exist. Ask the
  user to decide.

---

## Output Structure

```markdown
# Methodology Review: [id] — [YYYY-MM-DD]

## Blocking Issues

**Issue [N]: [title]**
Severity: BLOCKING
Resolution type: UNAMBIGUOUS | JUDGMENT CALL
...

## Required Issues

**Issue [N]: [title]**
...

## Advisory Issues

**Issue [N]: [title]**
...

---

## Summary

| Severity | Count |
|---|---|
| BLOCKING | N |
| REQUIRED | N |
| ADVISORY | N |

**Total issues:** N

**Assessment:** [One honest sentence — e.g., "The Taylor sandwich is correctly
specified for Gaussian but uses the wrong information matrix for all other
families; oracle tests for binomial would fail as written."]
```

---

## After Completing the Review

1. Determine `{id}` from the spec filename.
2. Write the full output to `plans/spec-methods-review-{id}.md`.
3. End the session with:

   > "Methodology review complete: {N} issues ({X} blocking, {Y} required,
   > {Z} advisory). Start a new session with `/spec-workflow stage 2 resolve`
   > to lock the methodology. Review saved to
   > `plans/spec-methods-review-{id}.md`."
