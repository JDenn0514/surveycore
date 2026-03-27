# Methodology Review: get-pairwise

## Methodology Review: get-pairwise — Pass 1 (2026-03-24)

### Scope Assessment

- Implements statistical method: **Yes** — pairwise contrasts from survey-weighted regression
- Produces numerical quantities with statistical properties: **Yes** — estimates, SEs, CIs, p-values, adjusted p-values
- Involves formulas that must be exactly specified: **Yes** — contrast extraction from vcov, t-distribution inference, p-value adjustment

**All five lenses apply.**

---

### New Issues

#### Lens 1 — Estimator Specification

**Issue 1: Estimate sign convention for marginaleffects pairwise path**
Severity: BLOCKING
Resolution type: UNAMBIGUOUS

Section 3.9.4 assembly step 1 says:

> Parse `avg_comparisons()` output to extract `level_a` and `level_b` from
> the `contrast` column (format: `"B - A"` → `level_a = "A"`,
> `level_b = "B"`). Normalize ordering to match `.build_pair_labels()`.

Step 3 then directly maps `pw$estimate → estimate` without any sign
adjustment.

However, `marginaleffects::avg_comparisons()` with `comparison = "pairwise"`
returns contrasts in the format `"B - A"` with `estimate = mean(B) - mean(A)`.
For factor levels (A, B, C), marginaleffects produces estimates for B-A, C-A,
C-B.

The output contract (Section 5.2) defines:

> `estimate` | Pairwise difference: mean(level_a) − mean(level_b).

With `level_a = "A"` and `level_b = "B"`, the output `estimate` must be
`mean(A) - mean(B)`, but marginaleffects returns `mean(B) - mean(A)`.
**The estimate sign is reversed.** The spec must specify negation.

Options:
- **[A]** Add explicit instruction in Section 3.9.4 step 1: "When the
  marginaleffects contrast is `'B - A'`, negate the estimate to produce
  `A - B` for output, matching the `mean(level_a) - mean(level_b)`
  convention." — Effort: low, Risk: low, Impact: prevents silent sign
  errors, Maintenance: none
- **[B]** Redefine the output convention (Section 5.2) as
  `mean(level_b) - mean(level_a)` to match marginaleffects' natural
  direction. — Effort: low, Risk: medium (contradicts intuitive A-B
  ordering in column labels), Maintenance: must update label
  "Difference (A − B)"
- **[C] Do nothing** — High risk of silent sign bugs in implementation.

**Recommendation: [A]** — The output contract in Section 5.2 is clear and
matches the column label "Difference (A − B)". Add negation to assembly.

Source: marginaleffects documentation for `comparison = "pairwise"`.

---

**Issue 2: Conditional avg_predictions() join not guarded in assembly**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Section 3.9.3 says:

> When `show_means = TRUE` and link-scale suppression does not apply:
> `preds <- marginaleffects::avg_predictions(...)`

But Section 3.9.4 Assembly step 2 unconditionally says:

> Left-join predicted means from `avg_predictions()` to get `mean_a` and
> `mean_b` for each pair.

If `show_means = FALSE` or link-scale suppression applies, `preds` is never
computed, and the left-join would error. The assembly must be conditioned on
whether `preds` was computed.

Options:
- **[A]** Add explicit conditional to Assembly step 2: "If `preds` was
  computed (i.e., `show_means = TRUE` and no link-scale suppression),
  left-join predicted means. Otherwise, skip this step and omit `mean_a`
  and `mean_b` columns." — Effort: low, Risk: low, Impact: prevents
  runtime errors, Maintenance: none
- **[B] Do nothing** — Assume implementation will guard this. Spec is
  incomplete.

**Recommendation: [A]** — Matches `get_diffs()` pattern which explicitly
says "skip `avg_predictions()` entirely" when suppression applies.

Source: `get_diffs()` Section 3.9.3.

---

**Issue 3: Row ordering in marginaleffects assembly needs explicit sort**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

Section 5.3 specifies deterministic row order matching `utils::combn()` output.
Section 3.9.4 Assembly does not include an explicit sort/reorder step after
extracting from `avg_comparisons()`. Marginaleffects may return pairs in any
order.

Options:
- **[A]** Add step to Section 3.9.4: "After assembly, sort rows to match
  `.build_pair_labels()` order (Section 5.3)." — Effort: low, Risk: low,
  Impact: ensures deterministic output, Maintenance: none
- **[B] Do nothing** — Trust marginaleffects ordering. Risk of silent
  breakage if marginaleffects changes internal ordering.

**Recommendation: [A]** — Explicit sort is cheap and guarantees the output
contract.

Source: Section 5.3.

---

#### Lens 2 — Variance Estimation

**Issue 4: Clean path variance source not documented**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Section 3.8 step 2 says:

> Extract `beta <- coef(fit)` and `V <- fit@vcov`.

It does not state that `fit@vcov` is the **design-based sandwich variance**
(Binder estimator). Compare to `get_diffs()` Section 3.8, which explicitly
says: "The `clean()` function returns `std_error` and CI bounds computed from
`fit@vcov`, which is the design-based Binder sandwich variance."

Without this, readers cannot confirm whether the contrast formula uses
design-based variance (correct) or model-based variance (incorrect for survey
data).

**Fix:** Add one sentence to Section 3.8 step 2:

> "The `fit@vcov` matrix is the design-based sandwich variance (per Phase 2
> spec), computed by `survey_glm()` for the specific design class (Taylor,
> replicate, two-phase, SRS, or nonprob). The contrast formula below uses
> this design-based variance directly."

Source: `get_diffs()` Section 3.8 lines 321-324.

---

**Issue 5: Marginaleffects variance chain documentation missing**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Section 3.9 provides code snippets for `avg_comparisons()` and
`avg_predictions()` but omits the **variance chain methodological note** that
`get_diffs()` Section 3.9 includes (lines 362-376). This note explains:

1. `avg_comparisons()` calls `vcov()` on `survey_glm_fit`, returning the
   Binder sandwich variance
2. The numerical Jacobian converts from link to response scale for
   non-gaussian families
3. The delta method combines the Jacobian with design-based `vcov` to produce
   SEs

This documentation is load-bearing — without it, reviewers cannot verify that
design-based variance (not model-based) is propagated through the
marginaleffects delta method for pairwise contrasts.

**Fix:** Add the parallel variance chain note from `get_diffs()` to Section
3.9, before Section 3.9.1, replacing `avg_slopes()` with
`avg_comparisons()`.

Source: `get_diffs()` Section 3.9, lines 362-376; Binder (1983), JASA
78(382):626-631.

---

**Issue 6: Clean path Gaussian-only equivalence note missing**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

`get_diffs()` Section 3.8 includes a critical note (lines 333-338):

> "Coefficient = AME equivalence: This clean path produces treatment effects
> identical to the marginaleffects path (AMEs) **only when**: (a) family is
> Gaussian with identity link, (b) the model has a single factor predictor
> (no covariates), and (c) no interactions."

`get_pairwise()` Section 3.8 omits this note entirely. Without it, readers
may incorrectly assume the clean path works for non-Gaussian families. The
equivalence condition applies equally to pairwise contrasts.

**Fix:** Add after Section 3.8 step 5:

> "**Coefficient = AME equivalence (Gaussian only):** This clean path
> produces pairwise contrasts identical to the marginaleffects path only when:
> (a) family is Gaussian with identity link, (b) no covariates, (c) no group
> interactions. The routing logic (Section 7.2) guarantees these conditions."

Source: `get_diffs()` Section 3.8, lines 333-338.

---

**Issue 7: FPC / replicate / two-phase variance inheritance not confirmed**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

Section 3.8 uses `fit@vcov` in the contrast formula but does not confirm that
`fit@vcov` already includes:

- Finite population corrections (when `fpc` is specified)
- Replicate weight deviations (for `survey_replicate` designs)
- Two-phase variance decomposition (for `survey_twophase` designs)

These are all handled by `survey_glm()` (Phase 2), but the spec should
explicitly state that the contrast formula inherits correct variance for all
design classes.

**Fix:** Add one sentence to Section 3.8 step 2:

> "For all design classes, `fit@vcov` reflects the full design-based
> variance, including finite population corrections, replicate deviations,
> and two-phase decomposition as applicable. The contrast formula applies
> without modification."

Source: Phase 2 spec Section VIII.

---

#### Lens 3 — Degrees of Freedom and Inference

**Issue 8: Clean path df computation not specified**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Section 3.8 step 4 says:

> "Compute t-statistics, p-values, and CIs using `fit@degf`."

But does not specify the formula for residual df. Compare to Section 3.9.1
(marginaleffects path), which gives:

```r
p <- length(coef(fit))
res_df <- max(1, fit@degf - (p - 1L))
```

The clean path should use identical logic. Without this, it is ambiguous
whether df clamping (`max(1, ...)`) applies and what adjustments are made.

Additionally, the spec does not declare that df values are **numeric
(double)**, not integer. Replicate designs return non-integer `degf` (e.g.,
99.0 for 100 BRR replicates). Truncation to integer would introduce
rounding error in t-quantiles and CI bounds.

**Fix:** Add to Section 3.8 step 4:

> "Residual df: `res_df <- max(1, fit@degf - (p - 1L))` where `p =
> length(coef(fit))`. The `max(1, ...)` clamping prevents `NaN` from
> `qt()` when df would be non-positive. All df values are numeric (double),
> never integer."

Source: `get_diffs()` Section 3.9.1; `get_pairwise()` Section 3.9.1.

---

#### Lens 4 — Domain Estimation

**Issue 9: Domain-aware cell counting mechanism not specified**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Section 5.2 defines `n_a` and `n_b` as "Unweighted in-domain count" but
Section 3.13 just says "Identical to `get_diffs()` Section 3.14: handled
upstream via `surveytidy::filter()`."

This is incomplete. The domain mask must be **used** when computing cell
counts (`n_a`, `n_b`), not just passed to `survey_glm()`. When the design has
a `..surveycore_domain..` column (set by `surveytidy::filter()`), cell counts
must include only rows where `..surveycore_domain.. == TRUE`. When `group` is
active, counts must be restricted to both the domain mask and the group
stratum.

`get_diffs()` Section 5.2 (line 619) specifies this explicitly for `n`. The
pairwise spec must do the same for `n_a` and `n_b`.

Options:
- **[A]** Add to Section 3.13: "When the design has a
  `..surveycore_domain..` column, cell counts (`n_a`, `n_b`) include only
  rows where `..surveycore_domain.. == TRUE`. When `group` is active,
  counts are restricted to both the domain mask and the group stratum." —
  Effort: low, Risk: low, Impact: clarity + correctness, Maintenance: none
- **[B] Do nothing** — Risk of silent domain counting bugs.

**Recommendation: [A]** — Domain-aware counting is load-bearing.

Source: `get_diffs()` Section 5.2, line 619.

---

**Issue 10: Empty treatment level per domain not checked**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

No error or warning is specified for the case where domain filtering
produces zero in-domain rows for a treatment level. If
`filter(design, age > 65)` yields zero observations for one treatment level:

- `n_a = 0` or `n_b = 0` in output
- `survey_glm()` may fail or produce degenerate estimates
- User gets no warning

The existing `min_cell_n` warning fires when a cell is *small* (< 30), but
not when it is *empty* (= 0).

Options:
- **[A]** Add check after na.rm and before fitting: "If any treatment level
  has zero in-domain observations, raise
  `surveycore_error_empty_treatment_cell`." — Effort: low, Risk: low,
  Impact: early detection of degenerate domains, Maintenance: one new
  error class
- **[B]** Rely on `survey_glm()` to error on degenerate model matrices.
  Document that behavior is inherited. — Effort: low, Risk: medium,
  Impact: implicit coupling to Phase 2
- **[C] Do nothing** — Silent degenerate results.

**Recommendation: [A]** — Pairwise contrasts involving a level with zero
observations are meaningless. Explicit error before fitting is cleaner.

Source: `get_diffs()` error table (Section 6.1) — no equivalent check
exists there either, suggesting this is a shared gap.

---

**Issue 11: Domain + grouping composition not explicit**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

Sections 3.13-3.14 delegate to `get_diffs()` but do not specify their
**interaction** for pairwise contrasts. When both domain filtering and
`group` are active, the spec should clarify that pairwise contrasts are
computed within each group stratum, and cell counts are restricted to rows
matching both the domain mask and group membership.

**Fix:** Add to Section 3.13:

> "When both `group` and domain filtering are active, pairwise contrasts
> are computed within each group stratum, and all cell counts (`n_a`,
> `n_b`) are restricted to rows matching both the domain mask and the group
> membership."

Source: `get_diffs()` Section 3.15, lines 564-566.

---

#### Lens 5 — Established Practice and Literature

**Issue 12: Default "holm" adjustment should cite Holm (1979)**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

Section 3.10 describes the Holm adjustment as the default but does not cite
the original paper. The spec should include:

> Holm, S. (1979). "A simple sequentially rejective multiple test procedure."
> Scandinavian Journal of Statistics, 6(2), 65-70.

This also departs from `survey` package convention (`survey::svycontrast()`
does not apply multiple testing corrections by default). The spec should note
this is an intentional design choice matching R base `pairwise.t.test()`
which also defaults to `p.adjust.method = "holm"`.

**Fix:** Add citation to Section 3.10 and add a roxygen `@details` note
documenting the intentional departure from `survey` convention.

Source: Holm (1979); R base `pairwise.t.test()` source.

---

**Issue 13: Within-group p-value adjustment scope should cite rationale**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

Section 3.10 step 2 says:

> When `group` is active: Apply adjustment separately within each group
> stratum (same rationale as `get_diffs()` Section 3.10).

The rationale (Alosh et al. 2014, cited in `get_diffs()`) is not repeated
or confirmed as applicable to pairwise (k(k-1)/2) comparisons rather than
reference (k-1) comparisons.

**Fix:** Add to Section 3.10: "Each group stratum is treated as a separate
family of k(k-1)/2 tests. This follows the exploratory subgroup analysis
convention (Alosh et al. 2014, Statistics in Medicine). For global
adjustment across all comparisons, users can apply `stats::p.adjust()`
post-hoc."

Source: Alosh, M., Bretz, F., Huque, M. (2014). Statistics in Medicine,
33(11):1923-1935.

---

**Issue 14: CI not recalculated after p-value adjustment — add rationale**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

Section 3.10 step 4 states: "CI bounds are NOT recalculated after adjustment."
This is correct but the rationale is absent. Users familiar with
`multcomp::glht()` may expect simultaneous CIs.

**Fix:** Add one sentence: "Confidence intervals reflect the specified
`conf_level` and are not affected by p-value adjustment. P-value adjustment
controls Type I error for hypothesis tests; interval estimation is separate.
For simultaneous CIs, users can use the `multcomp` package post-hoc."

Source: Standard frequentist practice; Bretz, Hothorn, Westfall (2016),
"Multiple Comparisons Using R."

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 7 |
| ADVISORY | 6 |

**Total issues:** 14

**Assessment:** The statistical methodology is fundamentally sound —
`get_pairwise()` correctly delegates estimation to `survey_glm()` and uses
standard contrast formulas and marginaleffects machinery. The one blocking
issue (sign convention in the marginaleffects assembly) would produce
estimates with the wrong sign if implemented as written. The required issues
are predominantly documentation gaps where `get_pairwise()` references
`get_diffs()` but omits key methodological notes that `get_diffs()` includes
(variance chain, Gaussian-only equivalence, df computation). The advisory
issues are citation and clarification improvements. No fundamental
mathematical errors exist beyond the sign convention.
