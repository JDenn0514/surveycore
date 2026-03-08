# Stage 2: Methodology Review

## Contents
- Trigger Condition
- Scope Assessment
- Your Role
- Exhaustive Pass Rule
- Five Review Lenses
- Issue Format
- If a Review File Already Exists
- Output Structure
- Before Outputting
- Mini-Pass Mode
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

## Scope Assessment

Before applying the lenses, answer the following to determine which lenses apply:

- Does this feature implement, modify, or extend a statistical or mathematical method?
- Does it produce numerical quantities (estimates, test statistics, weights) with known
  statistical properties?
- Does it involve iterative algorithms, closed-form formulas, or numerical procedures
  that must be exactly specified?

**If none apply** — e.g., the feature is a `print()` method, a format change, a utility
with no mathematical content — declare Stage 2 not applicable and skip to Stage 3.
Note the reason briefly in the output file.

**If any apply**, proceed with all five lenses below. Within each lens, skip
sub-questions that genuinely don't apply to the feature being reviewed — but err
toward checking rather than skipping.

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

Apply all five lenses to every spec. Lenses 1–4 include regression-specific
checks indented under each general check — apply these when the spec includes
regression coefficients or model-based estimators.

### Lens 1 — Estimator Specification

- Is the point estimator formula mathematically correct?
- Does it reduce correctly under SRS and simple designs (e.g., ratio estimate
  → sample proportion, weighted mean → sample mean under equal weights)?
- For non-linear estimators (ratios, regression coefficients, quantiles,
  correlations): is the delta method / linearization / influence function
  correctly derived?
  - *Regression:* Is the information matrix `(X'W̃X)⁻¹` (IRLS) not
    `(X'WX/n)⁻¹` (survey weights only)? For non-Gaussian families these
    differ.
  - *Regression:* Does the score function `u_i` use working residuals from
    the final IRLS step? Is the survey weight applied at the correct step?
- Are denominators and near-singularity conditions handled (e.g., ratio with
  near-zero denominator, quantile crossing, perfect collinearity in regression)?
- Is the estimator consistent with the survey weighting scheme in use?

### Lens 2 — Variance Estimation

- **Taylor linearization:** Is the linearized variable / influence function /
  score treated as a survey-weighted total before passing to variance machinery
  (e.g., `.svy_recvar()`)? Is the influence function correctly derived for the
  estimator type?
  - *Regression:* Is `Var_design(T)` computed via the Taylor machinery treating
    each score column as a survey-weighted total — not an analytic formula that
    only holds for Gaussian?
- **Replicate weights:** Is the deviation formula correct for each supported
  type (BRR, JK1/JK2/JKn, bootstrap)? Are scale factors applied at the right
  step?
  - *Regression:* Is the deviation `d_r = β̂_r - β̂` computed from refitting
    on the appropriate rows (full or domain-restricted)?
- **Two-phase designs:** Is phase-1 and phase-2 variance correctly decomposed?
- **FPC:** Applied at the correct stage, and only when meaningful?
- **SRS shortcuts:** If an analytic SRS formula is given, does it hold for all
  supported variants — not just the simplest case?
  - *Regression:* Does a stated analytic SRS formula hold for all supported
    families, or only Gaussian?

### Lens 3 — Degrees of Freedom and Inference

- Is df design-based (derived from `degf(design)`) vs. classical (`n - p`)?
  Is the choice explicit and consistent?
  - *Regression:* Is `df_residual` for t-tests clearly
    `degf(design) - (p - 1)` (design-based), distinguished from `fit$df.residual`
    (classical)? Is `df_null` defined with an explicit formula?
- Are df properties declared as numeric, not integer? `degf()` returns
  non-integer values for replicate designs; truncation introduces rounding
  error in t-statistics and CI bounds.
- For confidence intervals: is the t-distribution used with design df, or
  normal approximation? Is this stated explicitly and consistent across design
  types?
- For hypothesis tests: are p-values computed from the correct distribution
  with the correct df?
- If df ≤ 0 is possible (e.g., more groups or predictors than design df), is
  the edge case handled (warn + clamp)?
- **Output labeling:** Does every displayed quantity match its label? Nothing
  labeled "SE" is actually a variance; nothing labeled a probability is on the
  link scale.
  - *Regression:* If `summary()` shows a "Deviance Residuals" block, does the
    implementation use `residuals(fit, type="deviance")` — not working
    residuals? These are equal only for Gaussian/identity.

### Lens 4 — Domain Estimation

- **Taylor path:** Are out-of-domain influence/score contributions correctly
  zeroed before passing to variance machinery?
- **Replicate path:** Are replicate weights correctly handled for domain
  estimation (restricted refit, or zeroing contributions)?
  - *Regression:* If a replicate refit on a small domain fails to converge,
    is behavior specified (warn + use `d_r = 0`)?
- **Empty domain:** Is there an explicit error or warning before computation
  proceeds on zero in-domain rows?
- **Domain + grouping:** Are these correctly composed when both are present?
- **Non-convergence or degenerate conditions:** Is behavior specified for
  replicate subsets that produce degenerate estimates?

### Lens 5 — Established Practice and Literature

Compare the spec's approach to the `survey` package convention for each
estimand. For each material deviation:

- State what `survey` does
- State what the spec does instead
- Explain whether the deviation is intentional (with rationale) or an error

Flag any area where the methodological literature is genuinely uncertain
(e.g., exact df formula for Wald tests in complex designs). Note these as
ADVISORY with citations. Mark uncertain citations as `[verify]`.

---

## Issue Format

```
**Issue [N]: [Short title]**
Severity: BLOCKING | REQUIRED | ADVISORY
Resolution type: UNAMBIGUOUS | JUDGMENT CALL

[Concrete description. Quote the spec text that is wrong or absent.
For UNAMBIGUOUS: state the correct formula or fix directly.
For JUDGMENT CALL: state the options and their statistical trade-offs.]

Options:
- **[A]** [Description] — Effort: [low/medium/high], Risk: [low/medium/high],
  Impact: [what], Maintenance: [ongoing burden]
- **[B]** [Alternative description]
- **[C] Do nothing** — [what stays wrong or ambiguous]

**Recommendation: [A/B/C]** — [One sentence rationale]

Source: [Citation if applicable, e.g., "Binder (1983), JASA 78(382):626–631"
or "survey::svyglm() source, R/survey.R". Mark uncertain citations as
"[verify]".]
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

## If a Review File Already Exists

Before writing any output, check for `plans/spec-methods-review-{id}.md`.

**If it exists:**
1. Read the full existing file
2. Complete your fresh review of the current spec
3. In the new pass section, list every previously flagged issue with a status:
   - ✅ Resolved — the spec was updated to address it
   - ⚠️ Still open — the spec was not changed
4. **Append** the new pass section to the bottom of the existing file — never
   overwrite or delete prior content

**If it does not exist:** create the file with Pass 1.

---

## Output Structure

Organize all issues by lens. If a lens has no issues, say "No issues found."
If a lens was skipped, say "Lens [N] not applicable: [reason]."

```markdown
## Methodology Review: [id] — Pass [N] ([YYYY-MM-DD])

### Prior Issues (Pass [N-1])
_Omit this section on Pass 1._

| # | Title | Lens | Status |
|---|---|---|---|
| 1 | [title] | 1 | ✅ Resolved |
| 2 | [title] | 3 | ⚠️ Still open |

### New Issues

#### Lens 1 — Estimator Specification

**Issue [N]: [title]**
Severity: BLOCKING
Resolution type: UNAMBIGUOUS
...

#### Lens 2 — Variance Estimation

No issues found.

#### Lens 3 — Degrees of Freedom and Inference

Lens 3 not applicable: this feature does not involve inference or confidence intervals.

[continue for all five lenses]

---

## Summary (Pass [N])

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

## Before Outputting

Ask yourself:

- Did I complete the Scope Assessment and determine which lenses apply?
- Have I applied all applicable lenses, even for features that seem
  straightforward?
- Have I flagged every formula that is described vaguely instead of stated
  exactly?
- Have I checked every iterative procedure for a concrete convergence
  criterion?
- Have I flagged unstated statistical assumptions, not just code-level gaps?
- Is the overall assessment honest — does it match the issue count and
  severity?
- Have I assigned UNAMBIGUOUS or JUDGMENT CALL to every issue?

If the methodology is genuinely sound, say so. Adversarial means rigorous, not
performatively negative.

---

## Mini-Pass Mode

Use this mode when a wrong formula is discovered in Stage 3 or during
implementation and the methodology lock needs a targeted update.

1. Read only the affected section of the spec, not the full document.
2. Apply only the relevant lenses to that section.
3. Write a `### Mini-Pass [N] ([YYYY-MM-DD])` section and **append** it to
   the existing `plans/spec-methods-review-{id}.md` — never overwrite.
4. End with: `"Mini-pass complete: {N} issues found. Resolve via Stage 2
   Resolve targeting these issues only."`

---

## After Completing the Review

1. Determine `{id}` from the spec filename.
2. Append the new pass section to `plans/spec-methods-review-{id}.md` (create on Pass 1).
3. End the session with:

   > "Methodology review Pass [N] complete: {N} issues ({X} blocking, {Y} required,
   > {Z} advisory). Start a new session with `/spec-workflow stage 2 resolve`
   > to lock the methodology. Review saved to
   > `plans/spec-methods-review-{id}.md`."
