## Methodology Review: effective-n — Pass 1 (2026-05-04)

### Scope Assessment

This spec defines two closed-form estimators — the Kish (1965) weight-based
effective N and a DEFF-based effective N delegating to `get_means()`. It
involves exact numerical formulas, domain estimation, and design-effect
computation. All five lenses apply. No regression-specific sub-checks apply.

---

### New Issues

#### Lens 1 — Estimator Specification

**Issue 1: `deff` column is semantically ambiguous across methods** *(merged: Lenses 2, 3, 5)*
Severity: REQUIRED
Resolution type: JUDGMENT CALL

Three lenses independently flagged this. The spec outputs a single `deff`
column that holds two mathematically unrelated quantities:

- **Kish method** (spec §III, rule 4): `deff = n / n_eff`, derived purely from
  the weight vector. Ignores clustering and stratification entirely.
- **DEFF method** (spec §I, §III output contract line 164):
  `deff = Var_design / Var_SRS`, a variable-specific ratio of design-based to
  SRS variance, fully capturing clustering, stratification, and weights.

These differ for any design with clustering or stratification but uniform
weights: Kish gives `deff = 1.0`; the DEFF method gives `deff > 1.0`. A user
who extracts the `deff` column and does not check `meta(result)$method` will
silently interpret a weight-only heuristic as a full design effect (or vice
versa). The survey literature and established software treat these as distinct
concepts; naming both `deff` is not consistent with established practice.

Options:
- **[A] Rename the Kish output column** — Use `deff_kish` (or `weight_effect`)
  for method = "kish"; keep `deff` for method = "deff". Column name itself
  signals the method. — Effort: low, Risk: low (spec is in DRAFT; no existing
  users to break), Impact: eliminates silent misinterpretation,
  Maintenance: document both column conventions.
- **[B] Keep `deff` for both; add `meta(result)$deff_type` field** — Add a
  metadata field documenting which formula was used. Print method already shows
  `method:` header, so no print-output change needed. — Effort: low, Risk: low,
  Impact: programmatic disambiguation possible but not forced,
  Maintenance: minimal.
- **[C] Do nothing** — Rely on the print header (`method: kish` / `method: deff`)
  and documentation. — Effort: none, Risk: high (silent misinterpretation in
  downstream code), Impact: ambiguity persists, Maintenance: user education burden.

**Recommendation: [A]** — The spec is in DRAFT; the cost of a column rename now
is zero. Downstream code that extracts `deff_kish` vs. `deff` cannot misuse the
values without at least reading the column name.

Source: Kish (1965) "Survey Sampling"; Lohr (2010) "Sampling: Design and
Analysis"; Lenses 2, 3, and 5 all independently flagged this.

---

**Issue 2: Ambiguous "floating-point exact for integer weights" phrasing**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

Spec line 218: "When all weights in a domain are equal, `n_eff == n` and
`deff == 1.0` (floating-point exact for integer weights)."

The parenthetical is misleading. The algebraic identity holds for **any
constant weights** (integer or real). For constant c: `(n·c)² / (n·c²) = n`
exactly. The claim should not be limited to integers — equal real weights also
yield an exact result up to floating-point representation of the constant
itself.

Options:
- **[A] Remove the parenthetical** — Keep only "When all weights in a domain
  are equal, `n_eff == n` and `deff == 1.0`." — Effort: low, Risk: low.
- **[B] Clarify** — "(algebraically exact for any constant weight vector;
  subject to floating-point rounding only when weights are stored as
  non-exact floats)." — Effort: low, Risk: low.
- **[C] Do nothing** — Misleading text only; won't affect implementation. —
  Effort: none, Risk: none (text-only).

**Recommendation: [A]** — Simpler and more accurate.

Source: Lens 1 analysis.

---

**Issue 3: Kish deff = 0 case not explicitly addressed for Kish method**
Severity: ADVISORY
Resolution type: JUDGMENT CALL

Spec rule 5 (DEFF method, line 230) covers `deff == 0` → `n_eff = NA`. For
the **Kish method**, `deff = n / n_eff`. For deff to be 0 requires `n = 0`
(already handled by rule 6) or `n_eff = ∞` (unreachable: the Kish formula
always yields a finite result when `n > 0` and weights are finite). The spec
is silent on this, leaving an implementer to wonder whether Kish deff needs its
own zero-guard.

Options:
- **[A] Add one sentence to Kish rule set** — "In the Kish method, `n_eff` is
  always finite and positive when `n > 0` and weights are finite; `deff`
  therefore cannot be 0, and no special zero-guard is needed." — Effort: low.
- **[C] Do nothing** — Theoretically unreachable; omission is acceptable.

**Recommendation: [A]** — One sentence removes ambiguity for implementers at
zero cost.

Source: Lens 1 analysis.

---

**Issue 4: Invalid weights (NaN, Inf, negative) not addressed for Kish method**
Severity: ADVISORY
Resolution type: JUDGMENT CALL

The Kish formula assumes finite, non-negative weights. If any weight is NaN,
Inf, or negative, the formula will produce NaN or an incorrect result without
any error. The spec does not state whether input weight validity is the
caller's responsibility or should be checked.

Options:
- **[A] Add an explicit assumption statement** — "The weight vector for each
  domain is assumed to be finite and non-negative. If weights contain NaN, Inf,
  or negative values, behavior is undefined (R arithmetic applies)." — Effort: low.
- **[B] Add validation in `.kish_effective_n()`** — Check `all(is.finite(w))` 
  and `all(w >= 0)` before computing. — Effort: medium, Risk: low.
- **[C] Do nothing** — Standard R practice; upstream responsibility. —
  Effort: none.

**Recommendation: [C]** — Survey design objects already reject invalid weights
at construction time. A diagnostic function need not re-validate.

Source: Lens 1 analysis.

---

**Issue 5: DEFF method's dependency on `get_means()` deff definition not cross-referenced**
Severity: REQUIRED
Resolution type: JUDGMENT CALL

Spec §III, DEFF rule 3 (lines 226–229): "`get_means(design, x, group=group,
variance='deff', ...)`... extracts n and deff... derives n_eff = n / deff."

The spec asserts that `get_means(..., variance = "deff")` returns `deff =
Var_design / Var_SRS` (line 28) without citing the source or verifying it. If
`get_means()` uses a different formula (e.g., SE ratio rather than variance
ratio, which would give DEFF^(1/2) instead of DEFF), the formula
`n_eff = n / deff` would be wrong.

Per code inspection (`analysis-helpers.R` line ~947), the actual computation is
`deff = (se / se_srs)^2`, which equals `Var_design / Var_SRS`. The spec should
either cite this explicitly or require a gate test.

Options:
- **[A] Add a cross-reference in §III** — After rule 3: "The `deff` column
  returned by `get_means()` is defined as `(SE_design / SE_SRS)^2 =
  Var_design / Var_SRS`. Confirm this holds for all supported design types
  before implementing the extraction step." — Effort: low.
- **[B] Strengthen test §IV 2d** — The existing gate test (spec line 289)
  requires that `deff` from `get_effective_n(method = "deff")` matches `deff`
  from `get_means(variance = "deff")` (tolerance 1e-10). This implicitly
  validates the extraction. Keep as-is and note the test is the gate. —
  Effort: none.
- **[C] Do nothing** — Delegation to `get_means()` is a DRY choice; tests will
  catch inconsistency. — Effort: none.

**Recommendation: [A]** — One sentence makes the spec self-documenting and
prevents implementers from introducing a silent factor-of-DEFF error.

Source: Lens 1 analysis; `analysis-helpers.R` line ~947 [verify exact line].

---

#### Lens 2 — Variance Estimation

*(Issue 1 — `deff` naming — merged into Issue 1 above.)*

**Issue 6: SE_SRS reference population not specified in DEFF definition**
Severity: ADVISORY
Resolution type: JUDGMENT CALL

The spec defines DEFF as `Var_design / Var_SRS` (line 28) without specifying
the reference population for the SRS denominator. The implementation in
`analysis-means-helpers.R` computes SE_SRS from the **domain-restricted**
sample of size `n_d` (not the full sample `n`), which is the standard
survey-package convention. For subgroup analyses with unequal domain sizes,
this choice affects DEFF values and therefore n_eff.

Options:
- **[A] Add a clarifying sentence to §III, DEFF rule 3** — "SE_SRS is computed
  under SRS of the domain-restricted sample of size `n_d` (standard
  `survey`-package convention), not under SRS of the full sample." —
  Effort: low, Risk: low.
- **[C] Accept implicit standard practice** — Domain-conditional SRS is
  unambiguous to survey methodologists. — Effort: none.

**Recommendation: [A]** — One sentence eliminates an ambiguity that is
non-obvious to non-specialists.

Source: Lens 2 analysis; `analysis-means-helpers.R` lines 92–98, 153–159,
217–223, 279–284.

---

**Issue 7: FPC application in DEFF computation not mentioned**
Severity: ADVISORY
Resolution type: JUDGMENT CALL

The spec is entirely silent on FPC when describing the DEFF method. In
practice, the delegated `get_means()` applies FPC to the design SE but not to
SE_SRS, which is the correct approach. The spec should document this.

Options:
- **[A] Add one sentence to §III, DEFF rule 3** — "When the design includes
  FPC, it is incorporated in SE_design via the mean estimation pipeline.
  SE_SRS does not include FPC, consistent with the SRS reference model." —
  Effort: low.
- **[C] Do nothing** — FPC correctness is already covered by `get_means()`
  tests. — Effort: none.

**Recommendation: [A]** — Documents the assumption for future maintainers at
minimal cost.

Source: Lens 2 analysis; `analysis-means-helpers.R` line ~76.

---

**Issue 8: Design-type dispatch maintenance risk for DEFF method**
Severity: ADVISORY
Resolution type: JUDGMENT CALL

The spec supports five design classes. The DEFF method delegates to
`get_means()`, which handles dispatch via `.mean_cell()`. If a new design class
is added to `get_means()` but not explicitly tested in `get_effective_n()`, the
dispatch could silently fail.

Options:
- **[A] Add a parametrized test in §IV** — Test that each supported design class
  (taylor, replicate, twophase, nonprob, collection) returns a finite `deff`
  for method = "deff". — Effort: low, Risk: low.
- **[C] Do nothing** — Rely on existing code review and `get_means()` tests. —
  Effort: none.

**Recommendation: [A]** — Add the parametrized test to §IV. Low effort and
catches regressions when new designs are added.

Source: Lens 2 analysis; `analysis-means-helpers.R` lines 298–322.

---

#### Lens 3 — Degrees of Freedom and Inference

*(Issue 1 — `deff` column ambiguity — merged into Issue 1 above.)*

**Issue 9: Implicit df dependency in `method = "deff"` delegation not documented**
Severity: REQUIRED
Resolution type: JUDGMENT CALL

The spec claims "Effective N is a design-diagnostic, not an estimate with a
sampling distribution" (§I). This is true for n_eff itself. However, n_eff is
*derived* from DEFF, which is computed from the design-based variance of the
mean — a quantity that depends on design degrees of freedom. The spec never
mentions that:

1. DEFF computation relies on design-based df (from the cluster/strata
   structure).
2. When design df is very small (e.g., 2–3 clusters per stratum), DEFF may be
   unstable and n_eff unreliable.

A user with a small complex design who sees an extreme n_eff has no spec text
warning them to inspect the underlying design structure.

Options:
- **[A] Add a note to §III, DEFF method** — "DEFF is estimated from the
  design-based variance of the mean, which depends on degrees of freedom
  derived from the cluster/strata structure. When design df is small (e.g.,
  few clusters per stratum), DEFF — and therefore n_eff — may be unstable.
  Inspect the underlying `get_means()` output in such cases." — Effort: low.
- **[B] Add a stability warning** — If `degf(design) < some_threshold`, emit
  `surveycore_warning_effective_n_low_df`. — Effort: medium, Risk: medium
  (threshold selection uncertain).
- **[C] Do nothing** — Assume users understand design df. — Effort: none,
  Risk: medium (silent unreliable output in small designs).

**Recommendation: [A]** — Documentation cost is zero; stability warning
threshold would be hard to justify from literature.

Source: Lens 3 analysis.

---

**Issue 10: No handling of negative DEFF (unstable variance)**
Severity: ADVISORY
Resolution type: JUDGMENT CALL

Spec rule 5 (DEFF method, line 230) handles `deff == 0` → `n_eff = NA`. But
negative DEFF (Var_design < 0) can occur when design-based variance estimation
is numerically unstable due to extremely low df. If `deff < 0`, then
`n_eff = n / deff < 0`, which is nonsensical.

The test plan (§IV, §4.b) covers "deff == 0 (degenerate)" but not deff < 0.

Options:
- **[A] Extend rule 5** — "When `deff ≤ 0` (degenerate or unstable), return
  `n_eff = NA_real_`." Add a test case for `deff < 0` in §IV, §4.b. —
  Effort: low, Risk: low.
- **[B] Add a warning** — When `deff < 0`, return `n_eff = NA` and fire
  `surveycore_warning_effective_n_negative_deff`. — Effort: medium.
- **[C] Do nothing** — Rare edge case; users inspecting n_eff < 0 will notice.

**Recommendation: [A]** — Extend the degenerate rule to `deff ≤ 0` and add
one test case. Very low effort for meaningful correctness improvement.

Source: Lens 3 analysis.

---

#### Lens 4 — Domain Estimation

**Issue 11: Kish subdomain semantics underspecified**
Severity: REQUIRED
Resolution type: JUDGMENT CALL

Spec §III, Kish rule 1: "select the weight vector for observations in that
domain where neither the weight nor any group variable is NA." The spec then
applies `.kish_effective_n(w)` to that subset independently.

The statistical interpretation is not made explicit. Applying the Kish formula
to a domain's weight vector gives the **effective N within that domain for
point estimation**, not the effective N of domain-level estimates from the full
design. These can differ materially. A clustered design where most domain
members fall in the same clusters has a high within-domain clustering effect
that the Kish formula (which sees only weights, not cluster structure) misses
entirely.

Users who want effective N for domain-level inference should use `method =
"deff"`, but the spec provides no guidance on this distinction.

Options:
- **[A] Add a clarifying note to §III, Kish rule 1** — "The weight vector used
  is the full-design weights for domain members; weights are not renormalized.
  This estimates the weight-based effective N within the domain and does not
  account for clustering or stratification within the domain. For a design-
  aware domain effective N, use `method = 'deff'` with `x` specified." —
  Effort: low.
- **[B] Change to domain-renormalized weights** — Divide domain weights by
  their total before applying Kish. — Effort: medium, Risk: high (changes
  numerical results; algebraically equivalent when only weights vary but
  different when combined with grouping).
- **[C] Do nothing** — Technical accuracy is unaffected; interpretation is
  user responsibility. — Effort: none.

**Recommendation: [A]** — Clarifying comment prevents misuse without changing
behavior.

Source: Lens 4 analysis.

---

**Issue 12: Empty domain handling — no warning fired**
Severity: ADVISORY
Resolution type: JUDGMENT CALL

Spec §III, Kish rule 6: empty domains (`n == 0`) return `n=0, n_eff=NA,
deff=NA` silently. The spec does not specify whether a warning is issued. A
user with many group levels where some are empty will see silent NA values
in the output.

Options:
- **[A] Add an explicit warning** — `surveycore_warning_empty_domain` when
  `n == 0` for any domain. — Effort: medium (new class in error-messages.md).
- **[B] Document reliance on `min_cell_n`** — Clarify that `min_cell_n`
  already fires for `n < 30` (default), and `n == 0` produces `NA` which is
  visible in the output. No additional warning needed. — Effort: low.
- **[C] Do nothing** — Silent NA is consistent with R convention. — Effort: none.

**Recommendation: [B]** — The `min_cell_n` mechanism is already in place.
Document that zero-row domains produce `NA`; users can inspect the `n` column
to detect empty cells.

Source: Lens 4 analysis; spec §III line 246 (min_cell_n warning).

---

**Issue 13: DEFF method domain composition with grouping not explicitly stated**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Spec §III, DEFF rule 3 delegates to `get_means()` for domain semantics but
does not explicitly state:

- Whether each `group` level becomes one row in the output.
- How empty group levels are handled (zero observations after NA removal).
- Whether the domain semantics match `get_means(variance = "deff")` identically.

A maintainer reading only `get_effective_n()`'s spec cannot determine the
domain behavior without reading `get_means()` source code.

Options:
- **[A] Add explicit bullets to §III, DEFF rule 3** — "Each `group` combination
  produces one row. If a group level has zero in-domain observations after NA
  removal, `get_means()` handles it identically to the Kish rule 6 convention:
  `n = 0L`, `deff = NA_real_`, `n_eff = NA_real_`. Domain estimation semantics
  are inherited from `get_means(variance = 'deff')` and do not diverge for any
  supported design type." — Effort: low.
- **[C] Do nothing** — Trust maintainers to read `get_means()`. — Effort: none,
  Risk: maintenance brittleness.

**Recommendation: [A]** — The spec should be self-contained for its own output
contract.

Source: Lens 4 analysis.

---

**Issue 14: Replicate weight handling for domain subsets not specified**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec lists `survey_replicate` as a supported design type (§I, line 32) and
includes a replicate test (§IV, test 2.c). However, it never states how the
Kish method handles replicate weight structures. Specifically:

- Does `.kish_effective_n()` operate on the **main weights only** (not
  replicate weights) for each domain?
- Or are replicate weights iterated over (which would not make sense for a
  point diagnostic)?

The answer is presumably "main weights only," which is correct — the Kish
formula is a design diagnostic based on weights, not a replicate-variance
estimate. But this is unstated.

Options:
- **[A] Add one sentence to §III, shared behavior or Kish rules** — "For
  `survey_replicate` designs, `.kish_effective_n()` operates on the main
  (analysis) weights only; replicate weights are not used in the Kish
  computation." — Effort: low.
- **[C] Do nothing** — Implied by the formula; implementers will figure it out.
  — Effort: none, Risk: implementers could mistakenly loop over replicate
  weights.

**Recommendation: [A]** — One sentence prevents a plausible implementation
mistake.

Source: Lens 4 analysis.

---

#### Lens 5 — Established Practice and Literature

*(Issue 1 — `deff` naming — merged into Issue 1 above.)*

**Issue 15: Kish method limitations not documented**
Severity: ADVISORY
Resolution type: JUDGMENT CALL

The spec describes `method = "kish"` as "Kish (1965) effective N from weights
alone" (§I) but does not document the method's well-known limitation: it
ignores clustering and stratification. For a clustered design with equal
weights, Kish gives `n_eff = n` (deff = 1.0), while the correct design effect
may be substantially greater than 1.

The methodological literature explicitly notes this: "The formula takes only
the weights into account. Calculating the correct effective sample size also
requires an understanding of the correlation between the weight and the data
that is being weighted." (The Data Story Guide on Effective Sample Size).

Users who apply `method = "kish"` to a clustered design without understanding
this limitation will significantly overestimate effective N.

Options:
- **[A] Add a documentation note in the roxygen/help text** — Note that
  `method = "kish"` is a weight-only approximation and that `method = "deff"`
  captures the full design effect for a specific variable. Add one sentence to
  the spec's §I scope description. — Effort: low.
- **[C] Do nothing** — The `method = "kish"` label is self-documenting for
  survey methodologists. — Effort: none.

**Recommendation: [A]** — Users new to survey methodology will misapply Kish to
complex designs. A one-sentence note in the roxygen docs costs nothing.

Source: Kish (1965) "Survey Sampling"; The Data Story Guide on Effective Sample
Size [verify]; Lohr (2010) "Sampling: Design and Analysis."

---

**Issue 16: `survey_nonprob` effective N interpretation not documented**
Severity: ADVISORY
Resolution type: JUDGMENT CALL

Spec §III, DEFF rule 6: "`survey_nonprob` inputs: DEFF computation proceeds
exactly as for probability designs; the caller is responsible for interpreting
the result appropriately."

This defers the methodological responsibility entirely to the caller. But the
methodological issue is real: DEFF = Var_design / Var_SRS assumes a
probability-design framework (known inclusion probabilities, Horvitz–Thompson
estimation). For nonprobability samples, neither the Var_design numerator nor
the SRS comparison denominator has the same theoretical grounding. The
computed DEFF is mechanically valid but lacks the design-based inference
interpretation.

Options:
- **[A] Add a documentation note (roxygen) and expand the spec note** — "For
  `survey_nonprob` designs, DEFF is computed mechanically using the same
  formula as probability designs. The result does not carry a design-based
  inference interpretation; treat it as a weight-efficiency diagnostic only." —
  Effort: low.
- **[B] Add a runtime warning for `method = "deff"` on `survey_nonprob`** —
  Emit `surveycore_warning_effective_n_nonprob_deff` to alert users at
  computation time. — Effort: medium.
- **[C] Do nothing** — The spec already shifts responsibility to the caller. —
  Effort: none.

**Recommendation: [A]** — Documentation is appropriate and consistent with how
the rest of surveycore treats `survey_nonprob` (computes correctly, user
interprets appropriately). A runtime warning risks being too noisy for users
who understand the limitation.

Source: Lens 5 analysis; Baker et al. (2013) on nonprobability samples [verify].

---

**Issue 17: No numerical validation against `survey::svymean(..., deff = TRUE)`**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Spec §IV includes a manual formula validation for the Kish method (lines
320–327). It does **not** include a test comparing `get_effective_n(method =
"deff")$deff` to the deff column from `survey::svymean(~x, design, deff =
TRUE)`.

The `survey` package is the canonical reference implementation for design-based
analysis in R. Without a parity test, the DEFF method cannot be validated
against established practice. Test §IV 2d (lines 288–289) only checks parity
with `get_means(variance = "deff")` — an internal consistency test, not an
external validation.

The fix: add a test block in §IV guarded by `skip_if_not_installed("survey")`
that compares `get_effective_n(d, x, method = "deff")$deff` to
`coef(survey::svymean(~x, d_sv, deff = TRUE))` / `coef(...)` … or more
precisely, the deff attribute of `svymean(..., deff = TRUE)`.

Options:
- **[A] Add external validation test to §IV** — One test block:
  `skip_if_not_installed("survey")` + compare
  `get_effective_n(d, ridageyr, method = "deff")$deff` to
  `deff(survey::svymean(~ridageyr, d_sv, deff = TRUE))["ridageyr"]`,
  tolerance 1e-10. — Effort: low, Risk: low.
- **[C] Rely on internal parity with `get_means()`** — Effective external
  validation via transitivity. — Effort: none, Risk: medium (if `get_means()`
  deff diverges from survey, no test catches it).

**Recommendation: [A]** — Add the external validation test. The `survey`
package is the reference; transitivity through `get_means()` alone is
insufficient for a new exported function.

Source: Lens 5 analysis; survey package `svymean()` documentation.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 7 |
| ADVISORY | 10 |

**Total issues:** 17

| # | Title | Lens(es) | Severity |
|---|---|---|---|
| 1 | `deff` column semantically ambiguous across methods | 2, 3, 5 | REQUIRED |
| 2 | Ambiguous "floating-point exact for integer weights" phrasing | 1 | ADVISORY |
| 3 | Kish deff = 0 case not addressed | 1 | ADVISORY |
| 4 | Invalid weights (NaN, Inf) not addressed | 1 | ADVISORY |
| 5 | DEFF dependency on `get_means()` deff definition not cross-referenced | 1 | REQUIRED |
| 6 | SE_SRS reference population not specified | 2 | ADVISORY |
| 7 | FPC application in DEFF computation not mentioned | 2 | ADVISORY |
| 8 | Design-type dispatch maintenance risk | 2 | ADVISORY |
| 9 | Implicit df dependency in DEFF delegation undocumented | 3 | REQUIRED |
| 10 | Negative DEFF not handled | 3 | ADVISORY |
| 11 | Kish subdomain semantics underspecified | 4 | REQUIRED |
| 12 | Empty domain — no warning | 4 | ADVISORY |
| 13 | DEFF method domain composition with grouping unclear | 4 | REQUIRED |
| 14 | Replicate weight handling for domain subsets not stated | 4 | REQUIRED |
| 15 | Kish method limitations not documented | 5 | ADVISORY |
| 16 | `survey_nonprob` effective N interpretation undocumented | 5 | ADVISORY |
| 17 | No external validation against `survey::svymean(deff=TRUE)` | 5 | REQUIRED |

**Assessment:** The core formulas (Kish and DEFF) are mathematically correct
and reduce properly under SRS. No blocking errors found. The seven REQUIRED
issues are primarily specification clarity gaps — the most significant being
the shared `deff` column name for two different quantities (Issues 1, 5, 9, 11,
13, 14, 17). None would cause wrong computation for standard inputs; several
(especially Issue 1) set up silent misinterpretation in downstream code.
