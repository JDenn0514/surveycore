## Spec Review: nonprob-bootstrap-variance — Pass 1 (2026-05-19)

### New Issues

#### Section: Goals

**Issue 1: Goal 4 contradicts §3 on replicate helper modifications**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever).

Goal 4 states: "No new internal helpers are needed — the existing
`.replicate_mean_cell()` and `.replicate_variance_cell()` helpers work without
modification once `survey_nonprob`'s `@variables` carries the required keys."
But §3 "Replicate helper modifications" states each of the six replicate helpers
requires "one targeted modification each: add a threshold-based NA-drop warning."
These directly contradict. An implementer reading Goal 4 may skip the §3
modifications.

Options:
- **[A]** Narrow Goal 4 to its actual meaning: "The existing replicate variance
  calculation requires no changes — the routing described in §3 and the
  `@variables` keys are sufficient for SE computation. However, the six replicate
  helpers each require one targeted modification to emit
  `surveycore_warning_domain_replicates_na` for `survey_nonprob` objects." Effort:
  trivial, Risk: none, Impact: removes ambiguity
- **[B]** Remove Goal 4 entirely — it's already captured in §3. Effort: trivial,
  Risk: low, Impact: loses the explicit design rationale
- **[C] Do nothing** — implementer is expected to reconcile the contradiction.

**Recommendation: Option A** — Explicit is better than relying on cross-section
reconciliation.

---

#### Section: Design §1.1 — @calibration provenance schema

**Issue 2: "Issue 5 Option B" self-reference in spec text**
Severity: SUGGESTION
Violates engineering-preferences.md §5 (explicit over clever).

The spec says in §1.1: "The construction-time check `design@calibration$bootstrap`
is the validator's test for Issue 5 Option B." This is internal design-discussion
language. A reader of the published spec (or any future maintainer) cannot know
what "Issue 5 Option B" refers to.

Options:
- **[A]** Replace with: "...is the validator's test that replicate weights were
  produced by re-running the adjustment procedure (not by rescaling)." Effort:
  trivial, Risk: none, Impact: spec is self-contained
- **[B] Do nothing** — remove the parenthetical entirely. Effort: trivial, Risk:
  none, Impact: slightly less context than Option A

**Recommendation: Option A**

---

**Issue 3: `calibration != NULL, repweights == NULL` case unspecified**
Severity: REQUIRED
Violates engineering-preferences.md §4 (handle more edge cases, not fewer).

The spec defines validator behavior when `repweights` is non-NULL and
`calibration` is NULL ("no error is thrown — the no-provenance path is valid").
But the reverse case — `calibration` is non-NULL and `repweights` is NULL — is
never addressed. A user who stores a calibration provenance object for future use
but has not yet added bootstrap weights would hit this case. Is it valid? Does
the validator fire the provenance-consistency checks? (Answer: no — those checks
only run when `@variables$repweights` is non-NULL. But this isn't stated.)

Options:
- **[A]** Add a sentence to §1.1: "When `@calibration` is non-NULL and
  `@variables$repweights` is NULL, no error is thrown. The provenance object
  is stored for future use (e.g., the user may plan to add bootstrap weights
  later)." Effort: trivial, Risk: none, Impact: spec is unambiguous
- **[B] Do nothing** — leave to implementer inference.

**Recommendation: Option A**

---

**Issue 4: `calibration` schema — missing required-key check unspecified**
Severity: SUGGESTION
Violates engineering-preferences.md §4 (handle more edge cases).

The provenance validator checks `@calibration$bootstrap` and `@calibration$R`,
but if a user passes a `calibration` list with missing keys (`$bootstrap` = NULL),
the R check `calibration$bootstrap == TRUE` silently becomes `NULL == TRUE` →
FALSE → throws `surveycore_error_provenance_not_bootstrap`. The error message
would say "calibration$bootstrap must be TRUE" when the real issue is a missing
key. Only `surveywts` produces calibration objects, but the spec allows external
passing (that's why the constructor accepts it).

Options:
- **[A]** Add a pre-check in the validator: when `@calibration` is non-NULL,
  verify all four required keys are present — throw `surveycore_error_provenance_missing_keys`
  with a message listing missing keys. Add to error table. Effort: low, Risk:
  low, Impact: accurate error messages for malformed calibration objects
- **[B] Do nothing** — accept the confusing error for malformed calibration.
  `surveywts` controls production and users rarely pass it manually. Effort:
  zero.

**Recommendation: Option B** — `surveywts` is the only producer; external manual
construction of this object is unlikely. Keep the spec minimal.

---

#### Section: Design §2 — Constructor `as_survey_nonprob()`

**Issue 5: `rscales` NA values not validated**
Severity: REQUIRED
Violates engineering-preferences.md §4 (handle more edge cases).

The existing `.validate_rscales()` (R/core-validators.R:374) only checks
length. It does not validate that `rscales` is numeric or that it is free of NA
values. If a user supplies `rscales = c(1, NA, 1, ...)`, the variance formula
`sum((thetas - meantheta)^2 * rscales) * scale` silently returns `NA_real_`
for any term where `rscales[r]` is NA, potentially producing a wrong total
variance without error. This gap also exists in `as_survey_replicate()` but
the new spec should not inherit the gap.

Options:
- **[A]** Add to the validator spec: "When `rscales` is non-NULL, verify no
  element is NA (throw `surveycore_error_rscales_na`). Also verify all elements
  are numeric and non-negative." Add the error class to the error table and
  `plans/error-messages.md`. Effort: low, Risk: low, Impact: prevents silent
  wrong variance
- **[B]** Note the gap and defer: "NA in rscales is not validated in this spec;
  behavior is inherited from the existing `.validate_rscales()` helper. Address
  in a future hardening pass." Effort: trivial, Risk: medium, Impact: defers
  the fix
- **[C] Do nothing** — accept silent NA propagation.

**Recommendation: Option A** — the spec adds a new constructor accepting rscales;
it should validate it correctly.

---

#### Section: Design §3 — Variance dispatch

**Issue 6: `na_frac` and `na_dropped` not defined**
Severity: BLOCKING
Violates engineering-preferences.md §5 (explicit over clever).

The spec describes a warning block using `na_frac` and `na_dropped`:
```r
if (S7::S7_inherits(design, survey_nonprob) && na_frac > 0.05) {
  cli::cli_warn(... "{na_dropped} of {R} ..." ...)
}
```
And says "`na_frac` is computed inside the helper after the per-replicate
estimate vector is assembled but before `.svy_rep_var()` is called." But the
formula for `na_frac` and `na_dropped` is never given. The implementer must
guess. From the existing code (e.g., `.replicate_mean_cell()` computes `rep_p`
as a length-R vector where empty-domain replicates are `NA_real_`), the natural
definition would be `na_dropped <- sum(is.na(rep_p))` and
`na_frac <- na_dropped / R`, but this is not stated.

Options:
- **[A]** Add to §3: "Before calling `.svy_rep_var()`, compute:
  `na_dropped <- sum(is.na(per_replicate_estimates))` and
  `na_frac <- na_dropped / R` where `R = length(per_replicate_estimates)`.
  The `per_replicate_estimates` variable name differs per helper (e.g., `rep_p`
  in `.replicate_mean_cell()`, `rep_ybar` in `.replicate_variance_cell()`)."
  Effort: trivial, Risk: none, Impact: implementer has unambiguous spec
- **[B] Do nothing** — implementer infers from the existing code pattern.
  Risk: inconsistent implementations across the 6 helpers.

**Recommendation: Option A**

---

**Issue 7: NA-drop warning / all-replicates-NA error interaction unspecified**
Severity: REQUIRED
Violates engineering-preferences.md §4 (handle more edge cases).

The spec adds `surveycore_warning_domain_replicates_na` when `na_frac > 0.05`.
But `.svy_rep_var()` (R/variance-replicate.R:29) already throws
`surveycore_error_all_replicates_na` when ALL replicates are NA (`na_frac = 1.0`).
For a `survey_nonprob` domain cell where `na_frac = 1.0`, the current spec would:
1. Fire `surveycore_warning_domain_replicates_na` (1.0 > 0.05) ✓
2. Pass all-NA `rep_p` to `.svy_rep_var()` → throws
   `surveycore_error_all_replicates_na`

The user sees a warning about "100% of R bootstrap replicates have no
observations" followed by a cryptic error "All replicates produced NA
estimates." The error message is correct but loses the domain-context framing
the warning provides. The spec must specify whether `na_frac = 1.0` is handled
by intercepting before `.svy_rep_var()` (return `NA_real_` for SE, emit warning
only) or by letting the error fire.

Options:
- **[A]** Add a `na_frac == 1.0` early return before calling `.svy_rep_var()`,
  analogous to the `n_d == 0` empty-domain early return that already exists in
  `.replicate_mean_cell()`: return `se = NA_real_` with the warning only. Update
  §3 to specify this. Effort: low, Risk: low, Impact: coherent user experience
  (warning only, no unexpected error for a domain-estimation scenario)
- **[B]** Explicitly state: "When `na_frac = 1.0`, the warning fires and
  `.svy_rep_var()` subsequently throws `surveycore_error_all_replicates_na`.
  This error surfaces as-is; no interception is added." Effort: trivial, Risk:
  low, Impact: preserves existing error semantics; error message may confuse users
  doing domain estimation
- **[C] Do nothing** — leave the interaction undefined.

**Recommendation: Option A** — domain estimation with 100% NA replicates is
qualitatively different from a programming error (which `surveycore_error_all_replicates_na`
implies). Return NA gracefully with a clear warning.

---

**Issue 8: DRY — identical NA-drop warning block will be copy-pasted into 6 helpers**
Severity: REQUIRED
Violates engineering-preferences.md §1 (flag repetition aggressively).

The spec describes the same `if (S7::S7_inherits(design, survey_nonprob) && na_frac > 0.05) { cli::cli_warn(...) }` block being added to each of the six replicate helpers. Engineering-preferences.md §1 says "Repeated patterns in 2+ functions → extract a shared internal helper." The `na_dropped`, `na_frac`, `R`, `scale` values are all available at the call site in each helper.

Options:
- **[A]** Extract `.nonprob_rep_na_warn(design, na_frac, na_dropped, R, scale)` as an
  internal helper in `R/analysis-helpers.R` (the shared analysis helper file). Each
  of the six replicate helpers calls it. Effort: low, Risk: low, Impact: one place
  to update if the 5% threshold or message changes; eliminates 6-way duplication
- **[B]** Leave as copy-paste across 6 files. Effort: zero now. Risk: medium
  long-term (message or threshold changes require 6 edits)
- **[C] Do nothing**

**Recommendation: Option A** — this is exactly what engineering-preferences.md §1
requires; 6 call sites is a clear DRY violation.

Note: If Issue 8-A is adopted, update Goal 4 (see Issue 1) to acknowledge the new
internal helper.

---

#### Section: Design §4 — Degrees-of-freedom helper

**Issue 9: `.degf()` §4 contradicts Design Decisions for no-repweights `survey_nonprob`**
Severity: BLOCKING
Violates engineering-preferences.md §5 (explicit over clever).

The Design Decisions section states: "survey_nonprob objects **always** use the
normal approximation (degf = Inf) for confidence interval construction,
**regardless of whether repweights are present**." But §4 says "The existing
`n - 1` fallback for no-repweights `survey_nonprob` is unchanged." If
`survey_glm()` calls `.degf()` on a no-repweights `survey_nonprob`, it gets
`n - 1`, not `Inf` — directly contradicting the design decision. Confirmed by
reading R/analysis-helpers.R:1000: the `survey_nonprob` catch-all returns
`max(1L, nrow(design@data) - 1L)`.

The spec is partially fixing a pre-existing bug (`.degf()` returns `n - 1` for
all `survey_nonprob`) but only fixing it for the repweights case, leaving the
no-repweights case in contradiction with the stated design decision.

Options:
- **[A]** Make `.degf()` return `Inf` for ALL `survey_nonprob` objects, regardless
  of repweights. The branch in §4 becomes unconditional:
  ```r
  if (S7::S7_inherits(design, survey_nonprob)) return(Inf)
  ```
  Update §4 to state this clearly. Update the quality gate accordingly. Effort:
  trivial, Risk: low, Impact: `survey_glm()` Wald CIs always use normal
  approximation for NPS — consistent with the design decision
- **[B]** Narrow the Design Decisions claim to say "regardless of whether
  repweights are present" only applies to `get_*()` analysis functions (which
  already hardcode `degf <- Inf` before dispatch). Accept that `survey_glm()` on
  no-repweights NPS uses `n - 1`. Update §4 to document this deliberately. Effort:
  trivial, Risk: low, Impact: `survey_glm()` inconsistency with `get_*()` is
  acknowledged but not fixed
- **[C] Do nothing** — leave the contradiction in the spec.

**Recommendation: Option A** — the design decision is correct (no probability
design → no design-based df), the implementation §4 is the bug. Fix the
implementation, not the principle.

---

#### Section: Testing

**Issue 10: Test spec missing dual pattern for Layer 3 constructor errors**
Severity: REQUIRED
Violates testing-standards.md §3 ("Constructor error testing: dual pattern").

The test plan's "Error paths" section lists `expect_error(class = ...)` for all
eight error classes. But testing-standards.md §3 requires the dual pattern for
all Layer 3 (constructor) errors: `expect_error(class = ...)` AND
`expect_snapshot(error = TRUE, ...)`. The following constructor errors need
snapshot counterparts:
- `surveycore_error_type_invalid`
- `surveycore_error_repweights_single`
- `surveycore_error_repweights_empty`
- `surveycore_error_rscales_length`
- `surveycore_error_reference_sample_nonprob`
- `surveycore_error_provenance_not_bootstrap`
- `surveycore_error_provenance_R_mismatch`

`surveycore_error_design_var_missing` is a Layer 1/2 validator error reused
from `as_survey_replicate()` — existing snapshot coverage suffices if the
trigger description matches; add a new snapshot only if the message text differs.

Options:
- **[A]** Add `expect_snapshot(error = TRUE, ...)` pairs to each error path
  block in the test plan. Effort: low, Risk: none, Impact: message text is
  version-controlled and regressions are caught
- **[B]** Add a note: "Apply dual pattern from testing-standards.md §3 to all
  constructor errors." Without listing each explicitly. Effort: trivial, Risk:
  medium (easy to miss in implementation)
- **[C] Do nothing**

**Recommendation: Option A** — testing-standards.md is explicit; the test plan
should be too.

---

**Issue 11: No routing tests for `get_freqs()`, `get_totals()`, `get_corr()`, `get_covariance()`**
Severity: REQUIRED
Violates testing-standards.md §2 (three mandatory categories for every exported
function).

The test plan explicitly covers `get_means()` for all routing and SE tests.
`get_freqs()`, `get_totals()`, `get_corr()`, `get_quantiles()`, `get_ratios()`,
and `get_covariance()` are not tested with a repweight-equipped `survey_nonprob`
object. §3 adds a dispatch branch to all six helper files — each branch needs at
least a happy-path routing test confirming:
(a) the call succeeds without emitting `surveycore_warning_nonprob_srs_fallback`
(b) the result is a valid output for the given function type

Options:
- **[A]** Add one happy-path routing test per additional function to the test
  plan under "Happy path": "get_freqs() / get_totals() / get_corr() /
  get_covariance() / get_quantiles() / get_ratios() on a repweight-equipped
  survey_nonprob return results without emitting surveycore_warning_nonprob_srs_fallback."
  Effort: low, Risk: none, Impact: confirms all 6 dispatch branches are wired
- **[B]** Accept that `get_means()` tests are representative and add a spec note.
  Effort: trivial, Risk: medium (dispatch error in `get_freqs()` would pass CI)
- **[C] Do nothing**

**Recommendation: Option A** — these are six separate dispatch branches; each
needs one smoke test.

---

## Spec Review: nonprob-bootstrap-variance — Pass 2 (2026-05-19)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Goal 4 contradicts §3 on replicate helper modifications | ✅ Resolved |
| 2 | "Issue 5 Option B" self-reference in spec text | ✅ Resolved |
| 3 | `calibration != NULL, repweights == NULL` case unspecified | ✅ Resolved |
| 4 | `calibration` schema — missing required-key check unspecified | ⚠️ Still open (intentional — recommendation was Option B) |
| 5 | `rscales` NA values not validated | ✅ Resolved |
| 6 | `na_frac` and `na_dropped` not defined | ✅ Resolved |
| 7 | NA-drop warning / all-replicates-NA error interaction unspecified | ✅ Resolved |
| 8 | DRY — identical NA-drop warning block will be copy-pasted into 6 helpers | ✅ Resolved |
| 9 | `.degf()` §4 contradicts Design Decisions for no-repweights `survey_nonprob` | ✅ Resolved |
| 10 | Test spec missing dual pattern for Layer 3 constructor errors | ✅ Resolved |
| 11 | No routing tests for `get_freqs()`, `get_totals()`, `get_corr()`, `get_covariance()` | ✅ Resolved |

### New Issues

#### Section: Design §3 — Variance dispatch

**Issue 12: `.nonprob_rep_na_warn()` return value contradicts its own note**
Severity: BLOCKING
Violates engineering-preferences.md §5 (explicit over clever).

The helper implementation returns `list(estimate = NA_real_, se = NA_real_)` for `na_frac == 1.0`, and the specified call-site pattern is:

```r
early_out <- .nonprob_rep_na_warn(design, na_frac, na_dropped, R, vars$scale)
if (!is.null(early_out)) return(early_out)
```

This means the caller returns the helper's return value directly. But the note immediately following says: *"the exact fields in the early-return list (`estimate`, `se`, etc.) differ per helper — each helper must return its own NA-filled result structure matching its normal return shape."*

These two statements are mutually exclusive:
- `return(early_out)` → caller uses helper's structure (one generic shape for all six helpers)
- "each helper must return its own NA-filled result structure" → caller ignores helper's structure and builds its own

An implementer cannot satisfy both. For example, `.replicate_mean_cell()` returns a list with `mean`, `se`, `n`, and CI fields — not `estimate` and `se`. If the caller does `return(early_out)`, the result structure is wrong. If the caller builds its own, the `return(early_out)` call-site pattern is wrong.

Options:
- **[A]** Change the helper's `na_frac == 1.0` path to return a sentinel signal (e.g., `TRUE`) rather than a list. Each caller then uses the signal to branch and return its own NA-filled structure:
  ```r
  if (isTRUE(.nonprob_rep_na_warn(...))) {
    return(list(mean = NA_real_, se = NA_real_, n = NA_integer_, ...))
  }
  ```
  Effort: low, Risk: low, Impact: call-site pattern is explicit and correct per the note
- **[B]** Remove the `na_frac == 1.0` branch from the helper entirely. Each of the six callers handles `na_frac == 1.0` directly with its own NA structure (helper only handles the warning). The helper always returns `NULL`. Effort: low, Risk: low, Impact: slightly more call-site code but unambiguous
- **[C] Do nothing** — implementer must guess which interpretation is correct.

**Recommendation: Option A** — sentinel return is the cleanest DRY solution: the helper owns the warning+gate logic, each caller owns its return shape.

---

**Issue 13: `.degf_woodruff()` no-repweights NPS path conflicts with Design Decisions**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever).

The Design Decisions section states: *"`survey_nonprob` objects always use the normal approximation (`degf = Inf`) for confidence interval construction, **regardless of whether repweights are present**."*

But the §3 dispatch table says:

> `R/analysis-quantiles-helpers.R` | `.degf_woodruff()` | Add branch: repweight-equipped `survey_nonprob` → `Inf` | Existing `n - 1` path unchanged

"Existing `n - 1` path unchanged" means no-repweights `survey_nonprob` continues to yield `n - 1` from `.degf_woodruff()`. Confirmed by reading the current implementation: `.degf_woodruff()` falls through to `max(1L, nrow(design@data) - 1L)` for any design that is not `survey_taylor`, `survey_replicate`, or `survey_twophase`. `.degf_woodruff()` and `.degf()` are entirely independent functions — they share no code.

After this spec's §4 change, `.degf()` returns `Inf` for **all** `survey_nonprob`. But `.degf_woodruff()` still returns `n - 1` for no-repweights NPS. The two functions disagree on the same object, violating the "regardless of repweights" principle for `get_quantiles()`.

Options:
- **[A]** Change `.degf_woodruff()` to return `Inf` for **all** `survey_nonprob`, regardless of repweights. The §3 table entry becomes: "Add branch: `survey_nonprob` (any) → `Inf`". Effort: trivial, Risk: low, Impact: `get_quantiles()` CI on no-repweights NPS changes from t(n−1) to normal — behavior change, but correct per the Design Decision
- **[B]** Narrow the Design Decision to exclude `get_quantiles()`: acknowledge that `get_quantiles()` uses `n − 1` for no-repweights NPS via `.degf_woodruff()`. Document this as a deliberate exception. Effort: trivial, Risk: low, Impact: inconsistency between `get_*()` and `get_quantiles()` is explicitly acknowledged
- **[C] Do nothing** — leaves the contradiction for the implementer to resolve.

**Recommendation: Option A** — the Design Decision is correct; `n − 1` has no statistical meaning for NPS regardless of which CI helper uses it.

---

#### Section: Design §2 — Constructor `as_survey_nonprob()`

**Issue 14: `@variables` content for no-repweights case is underspecified**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever).

The spec states: *"The five new keys are always written to `@variables` in every constructor call, following the `code-style.md` rule that all keys must be present (values are `NULL` when the argument is not supplied)."* The backward-compatibility test asserts: *"`@variables` contains all five repweight keys (`repweights`, `type`, `scale`, `rscales`, `mse`) with `NULL` values when no repweights are provided."*

But `type = "bootstrap"` has a non-NULL default, and `mse = TRUE` has a non-NULL default. The constructor resolution section specifies behavior only "when `repweights` is non-NULL." An implementer must guess: when `repweights = NULL`, are `type` and `mse` stored as their constructor defaults (`"bootstrap"` and `TRUE`) or overridden to `NULL`?

The backward-compatibility test implies `NULL`, but the constructor signature implies their defaults are passed through. These produce different stored states.

Options:
- **[A]** Add one sentence to §2: *"When `repweights = NULL`, all five repweight-related keys (`repweights`, `type`, `scale`, `rscales`, `mse`) are written as `NULL` to `@variables`, regardless of the `type` and `mse` argument defaults. Resolved non-NULL values are written only when `repweights` is non-NULL."* Effort: trivial, Risk: none, Impact: unambiguous
- **[B] Do nothing** — leave to implementer inference from the test.

**Recommendation: Option A**

---

#### Section: Design §1 — Class `survey_nonprob`

**Issue 15: Provenance and `reference_sample` validator layer is ambiguous**
Severity: REQUIRED
Violates testing-standards.md §2 (Layer 1 vs. Layer 3 testing requirements).

§1 places four checks under *"Validator additions"* — implying they belong in the S7 class validator (Layer 1):
- Repweight columns exist in `@data` → `surveycore_error_design_var_missing`
- `@reference_sample` is a `survey_taylor` → `surveycore_error_reference_sample_nonprob`
- `@calibration$bootstrap` is `TRUE` → `surveycore_error_provenance_not_bootstrap`
- `@calibration$R` matches repweight count → `surveycore_error_provenance_R_mismatch`

But the testing section calls all four *"Layer 3 (constructor `cli_abort()`) errors"* and applies the dual pattern.

Layer 1 and Layer 3 are mutually exclusive. Testing-surveycore.md §2 states explicitly: Layer 1 → `class=` only (no snapshot); Layer 3 → dual pattern. An implementer cannot satisfy both testing requirements for the same check.

Options:
- **[A]** Resolve to Layer 3 (constructor): move all four checks into the `as_survey_nonprob()` body via `cli_abort()`. Keep the S7 validator structural-only. Apply dual pattern in tests. Consistent with the testing section and with how `as_survey_replicate()` places `surveycore_error_design_var_missing` in the constructor. Effort: low, Risk: low
- **[B]** Resolve to Layer 1 (S7 validator): checks remain in `validator = function(self) {...}`. Update the testing section to use `class=` only (no snapshot) for these four errors. Effort: low, Risk: low
- **[C] Do nothing** — implementer chooses; one test pattern will be wrong.

**Recommendation: Option A** — the established surveycore pattern puts user-facing input validation in the constructor (Layer 3). `surveycore_error_design_var_missing` is reused from `as_survey_replicate()` (constructor path). Keeping all four in the constructor is consistent.

---

#### Section: Testing

**Issue 16: "Six new arguments added after `calibration`" wording is incorrect**
Severity: SUGGESTION
Violates engineering-preferences.md §5 (explicit over clever).

The spec says *"Six new optional arguments added after `calibration`"* but the shown constructor signature has `calibration` as the **last** argument, with all six new arguments appearing **before** it. The new arguments were inserted before `calibration` (which moved to final position), not after it.

Options:
- **[A]** Change to: *"Six new optional arguments inserted before `calibration`, which moves to the final position in the signature."* Effort: trivial
- **[B] Do nothing**

**Recommendation: Option A**

---

**Issue 17: No test for `surveycore_error_rscales_na` in the `as_survey_replicate()` path**
Severity: SUGGESTION
Violates testing-standards.md §2 (mandatory error-path coverage).

The spec notes: *"`surveycore_error_rscales_na` check is added to the shared `.validate_rscales()` helper in `R/core-validators.R`, so it also closes the same gap in `as_survey_replicate()`."* This is a new error class thrown via an existing constructor. The test plan specifies dual-pattern coverage only for `as_survey_nonprob()`. `as_survey_replicate()` gets the same fix but no new test is mentioned.

Options:
- **[A]** Add to the test plan: *"Add `surveycore_error_rscales_na` dual-pattern test to `test-constructors.R` for the `as_survey_replicate()` path, since `.validate_rscales()` is shared."* Effort: trivial
- **[B] Do nothing** — the new test implicitly exercises the shared helper.

**Recommendation: Option A** — the error is newly introduced to the replicate path; it deserves an explicit test there.

---

**Issue 18: No manual numerical oracle for the full bootstrap SE formula**
Severity: SUGGESTION
Violates testing-standards.md §2 (Numerical oracle category).

The test plan confirms routing (bitwise-identical to `survey_replicate`) and the `sqrt()` step (`se^2 == .svy_rep_var()`). But there is no test that independently computes the expected SE from raw replicate estimates and compares against `get_means()$se^2`. For example: compute `theta_r = sum(repwt_r * y) / sum(repwt_r)` per replicate, then `var = (1/R) * sum((theta_r - theta)^2)`, and verify `get_means()$se^2 ≈ var` at tolerance `1e-8`. This would confirm `scale`, `rscales`, and `mse` are wired correctly end-to-end, not just that routing reaches the right helper.

Options:
- **[A]** Add one oracle test computing the variance manually from replicate estimates. Effort: low, Impact: confirms scale/mse wiring is correct end-to-end
- **[B] Do nothing** — bitwise-identity test + `.svy_rep_var()` check provide sufficient coverage since `survey_replicate` already has numerical oracle tests against the `survey` package.

**Recommendation: Option A** — a new variance path deserves at least one independently verified numerical check.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 7 |
| SUGGESTION | 3 |

**Total issues:** 12

**Overall assessment:** The spec is methodologically sound and architecturally
coherent, but has two blocking implementation gaps (undefined `na_frac` formula,
`.degf()` / Design Decisions contradiction) and seven required gaps concentrated
in the testing section and the NA-drop warning spec. None require architectural
rethinking — all are resolvable with targeted spec edits.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 3 |
| SUGGESTION | 3 |

**Total new issues:** 7

**Overall assessment:** Pass 1's resolutions were thorough — 10 of 11 issues closed. Pass 2 found one blocking spec contradiction (`.nonprob_rep_na_warn()` return value vs. its own note), three required gaps (`.degf_woodruff()` / Design Decision conflict, unspecified no-repweights `@variables` content, validator-layer ambiguity), and three suggestions. None require redesign — all are resolvable with targeted spec edits. The spec is close to implementation-ready.
