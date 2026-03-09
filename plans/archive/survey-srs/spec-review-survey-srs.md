# Spec Review: `survey_srs` Formal Specification

**Reviewed:** 2026-02-23
**Spec file:** `plans/survey-srs-formal-specification.md`
**Reviewer:** spec-reviewer skill (adversarial review)

---

## Section III — `survey_srs` S7 Class

**Issue 1: `test_invariants()` doesn't check `fpc_type` key**
Severity: REQUIRED
[Violates testing-standards.md — `test_invariants()` is required as the first
assertion in every constructor test block, but it doesn't verify the SRS-only
invariant that `fpc_type` is always present in `@variables`.]

`test_invariants()` in `helper-test-data.R` checks six keys: `ids`, `weights`,
`strata`, `fpc`, `nest`, `probs_provided`. `survey_srs` adds a seventh:
`fpc_type`. The function has explicit branches for `survey_calibrated` and
`survey_twophase` but nothing for `survey_srs`. Without a branch, a `survey_srs`
object missing `fpc_type` from `@variables` passes `test_invariants()` silently;
the `fpc_type` check only exists in `test-s7-classes.R` test #5 and is not
called on every constructor test.

Options:
- **[A] Add a `survey_srs` branch to `test_invariants()`** that adds
  `"fpc_type" %in% names(design@variables)` — Effort: low, Risk: none.
- **[B] Add a `test_srs_invariants()` wrapper** that calls `test_invariants()`
  and appends the `fpc_type` check — Effort: low, adds naming burden for
  every SRS constructor test block.
- **[C] Do nothing** — `fpc_type` gap only caught in `test-s7-classes.R`;
  a constructor that omits it passes all constructor tests.

**Recommendation: A** — mirrors the existing `survey_calibrated` branch
pattern; one new `if (S7::S7_inherits(design, survey_srs))` block.

---

## Section IV — `as_survey_srs()` Constructor

**Issue 2: `@call` property not specified**
Severity: REQUIRED
[Violates contract completeness — every existing constructor sets `@call =
match.call()`; the spec omits this for `as_survey_srs()`.]

The `@variables` construction template in Section IV shows seven keys but
never mentions `@call`. A `survey_srs` object constructed without `@call`
would print differently and fail any test that inspects the `@call` slot.

Options:
- **[A] Add `call = match.call()` to the `survey_srs(...)` constructor call
  in Section IV** — Effort: trivial.
- **[B] Do nothing** — implementer infers from other constructors; low risk
  but violates "no decisions left to judgment."

**Recommendation: A**.

---

**Issue 3: FPC validation check ordering not specified**
Severity: REQUIRED
[Violates contract completeness — when multiple FPC checks fire simultaneously,
snapshots depend on which fires first.]

Given `fpc = c(-1, 0.5, 1000)`:
- `fpc_nonpositive` fires (−1 ≤ 0)
- `fpc_ambiguous` fires (0.5 ≤ 1 and 1000 > 1 are both present)

Both checks trigger on the same column. The spec lists them as table rows
with no ordering statement. An implementer without guidance could fire either
first, producing different snapshot output and breaking snapshot tests.

Same ambiguity for `fpc = c(-5, 2000)`: `fpc_nonpositive` fires (−5 ≤ 0);
`fpc_ambiguous` could also fire (−5 ≤ 1 and 2000 > 1). The "correct" behavior
is debatable, which is exactly why the spec must be explicit.

Options:
- **[A] Specify check order**: nonpositive → ambiguous → below_sample.
  Rationale: catch obviously invalid values before statistically nuanced checks.
  Add one sentence: "Run FPC checks in this order: (1) NA check, (2)
  nonpositive, (3) ambiguous, (4) below_sample." — Effort: trivial.
- **[B] Do nothing** — Risk: snapshot divergence between implementers.

**Recommendation: A**.

---

**Issue 4: `n` in variance formulas is ambiguous**
Severity: REQUIRED
[Violates contract completeness — the formulas use `n` without defining
whether it means `nrow(data)` or non-NA count for the outcome.]

Section VIII introduces `n_used` in the df rule ("the count of non-NA
observations after applying `na.rm`"). The variance formulas use bare `n`:

```
var(ȳ) = (1 - f) × s² / n
f = n / N  (if fpc_type == "population")
```

When `na.rm = TRUE` and the outcome has NAs, `n_used < nrow(data)`. Should
`n` be `nrow(data)` or `n_used`? For `f = n/N`: if fpc is row-level and `n`
is `n_used`, then `f` excludes NA-outcome rows from the sampling fraction.
The spec says `df = n_used - 1`, implying `n = n_used` — but this is never
stated in the formula section.

Options:
- **[A] Replace bare `n` with `n_used` throughout Section VIII** and add one
  sentence defining `n_used`: "`n_used` equals `nrow(data)` when `na.rm =
  FALSE` or no NAs exist; otherwise it is the count of non-NA observations
  in the outcome variable." — Effort: trivial.
- **[B] Do nothing** — Risk: implementers compute `f` differently; oracle
  tests fail for NA-containing data at `1e-10` tolerance.

**Recommendation: A**.

---

**Issue 5: `fpc_below_sample` check semantics: per-row vs. aggregate**
Severity: REQUIRED
[Violates contract completeness — the error table and the formula section use
different semantics for the same check.]

Section IV table: "fpc column is population size AND **any value** < n".
Error message: "has {n_bad} value(s) smaller than the sample size ({n})."
→ Implies **per-row** check: fire when ANY individual FPC value < n.

Section VIII formula: "`f = n / N` where `N = mean of fpc column`."
→ Uses the **mean**, not individual rows.

A column with `fpc = c(1000, 400)` and `n = 500`: per-row check fires
(400 < 500); aggregate check does not (mean = 700 ≥ 500). These disagree.

Options:
- **[A] Clarify as per-row** (consistent with "any value" in the table and
  `{n_bad}` in the message template) and add a note: "FPC values varying
  across rows is itself a misuse of `survey_srs`; the per-row check
  catches the most common practical error." — Effort: trivial.
- **[B] Clarify as aggregate** — weakens the check; changes the error
  condition.
- **[C] Do nothing** — implementations diverge; tests inconsistent.

**Recommendation: A**.

---

## Section V — `as_survey()` Dispatch Update

**Issue 6: `as_survey()` → `as_survey_srs()` handoff is underspecified — BLOCKING**
Severity: BLOCKING
[The spec explicitly states "No implementation decisions are left to judgment"
but leaves the most architecturally significant part of this PR — the
`as_survey()` refactoring — entirely unspecified.]

Four interlocked problems:

**6a — Dispatch-before vs. forward-quosures:**
Section V says "all validation and `@variables` construction happens inside
`as_survey_srs()`." But the existing `as_survey()` code resolves `weights`,
`probs`, and the no-weights fallback (lines ~119–202 of
`R/03-constructors.R`) **before** the point where a dispatch decision could
be made. Implementing "all processing in `as_survey_srs()`" requires moving
the dispatch check to before weight resolution and forwarding raw quosures.
The spec never describes this restructuring.

**6b — `probs_provided = TRUE` flag lost:**
Section V says "set `probs_provided = TRUE`... before forwarding `weights`
to `as_survey_srs()`." But `as_survey_srs()` has no `probs` argument, and
its `@variables` construction (Section IV template) hardcodes
`probs_provided = FALSE`. There is no mechanism specified for `as_survey()`
to communicate `probs_provided = TRUE` to the resulting object. An
implementer must choose between:
1. Adding a `probs_provided` argument to `as_survey_srs()` (not in spec)
2. Having `as_survey()` construct the `survey_srs` object directly for the
   probs case (violates "call `as_survey_srs()`")
3. Some other mechanism not described

**6c — Row 7 fires twice without spec guidance:**
The existing `as_survey()` fires `surveycore_warning_srs_no_weights` (row 7)
when no weights/probs are provided. After dispatch, `as_survey_srs()` fires
`surveycore_warning_srs_no_weights` (row 60 — same class). Unless the row 7
code is removed from `as_survey()`'s SRS path, both fire. The spec adds row
60 but never says to remove or conditionally suppress row 7 for the SRS path.
It also doesn't address that row 7 must still fire for the Taylor path (users
who call `as_survey(df, ids = psu)` with no weights).

**6d — Warning firing order unspecified:**
Section V says both `surveycore_warning_as_survey_srs_fallback` and
`surveycore_warning_srs_no_weights` fire when `as_survey()` is called with
no ids, strata, or weights. The natural order is fallback (from `as_survey()`)
then no-weights (from `as_survey_srs()`). This must be stated explicitly
because `expect_snapshot()` tests capture both warnings in sequence — wrong
order fails the snapshot.

Options:
- **[A] Add a "Required refactoring of `as_survey()`" subsection to Section V**
  that explicitly specifies:
  (1) The dispatch check is inserted before weight/probs resolution
  (2) For the SRS path: forward raw `weights` and `fpc` quosures to
      `as_survey_srs()`, handle probs conversion before the call and pass
      `probs_provided` via a new parameter to `as_survey_srs()`
  (3) The no-weights code block in `as_survey()` is retained for the Taylor
      path but not executed for the SRS path
  (4) `surveycore_warning_as_survey_srs_fallback` fires before the
      `as_survey_srs()` call; `surveycore_warning_srs_no_weights` fires
      inside `as_survey_srs()` — Effort: medium (clarifying prose, no new
      API), Risk: low, Impact: unblocks implementation.
- **[B] Do nothing** — Risk: BLOCKING — implementers cannot make consistent
  architectural choices; test outputs vary by implementation.

**Recommendation: A** — This is the highest-priority gap in the entire spec.

---

## Section VI — Print and Summary Methods

**Issue 7: `summary.survey_srs` has no tests in Section X**
Severity: REQUIRED
[Violates testing-standards.md §2 — every exported function must have tests
in all three categories (happy path, error paths, edge cases).]

Section VI defines `summary.survey_srs` returning a named list with 7 fields.
The `test-methods-print.R` test plan in Section X has 5 snapshot blocks —
all for `print()`. There is no `test_that()` block for `summary()`.

Missing tests at minimum:
- `summary(srs_design)` returns a list with all 7 keys present
- `summary(srs_design)$n == nrow(x@data)`
- `summary(srs_design)$fpc_specified` is `TRUE`/`FALSE` correctly
- `summary(srs_design)$fpc_type` is `NULL`/`"population"`/`"fraction"` correctly

Options:
- **[A] Add `summary.survey_srs` test blocks to the test plan in Section X**
  — Effort: low.
- **[B] Do nothing** — `summary()` goes untested; coverage drops below 98%.

**Recommendation: A**.

---

## Section VII — Error and Warning Classes

**Issue 8: Row 59 message template doesn't match the Section V code block**
Severity: SUGGESTION
[Violates error-messages.md rule: "spec prose and plan templates must match
this table exactly."]

Section V code block (three-bullet format):
```r
c(
  "!" = "No {.arg ids} or {.arg strata} specified.",
  "i" = "Creating a {.cls survey_srs} design (equal-probability SRS).",
  "v" = "Use {.fn as_survey_srs} to create SRS designs without this warning."
)
```

Section VII row 59 (single-line template):
`"No {.arg ids} or {.arg strata} specified. Creating a {.cls survey_srs}
design. Use {.fn as_survey_srs} to create SRS designs without this warning."`

The table omits "(equal-probability SRS)" and collapses the bullets into one
string. `error-messages.md` is supposed to be the authoritative source but it
doesn't match the canonical implementation.

Options:
- **[A] Update row 59 to use multi-bullet notation matching Section V** —
  Effort: trivial.
- **[B] Do nothing** — minor inconsistency; implementer defers to Section V.

**Recommendation: A** — keeps `error-messages.md` as the single source of truth.

---

## Section VIII — Variance Estimation

**Issue 9: Variance formula correctness for non-uniform weights needs explicit verification**
Severity: REQUIRED
[Violates engineering-preferences.md §4 — the oracle tests use non-uniform
weights but the formula's equivalence to the reference implementation for
non-uniform inputs is asserted, not proven.]

The spec states: "SRS weights are proportional to the same constant (N/n), so
the unweighted and weighted sample variances are identical for a true SRS
design. We use the unweighted formula here."

This claim holds only for equal weights. `make_survey_data()` generates weights
from a lognormal distribution (`wt = base_wt[strata] * exp(rnorm(n, 0, 0.2))`),
so oracle test data has non-uniform weights. The spec's formula:

```
var(ȳ) = (1 - f) × s² / n     [unweighted s², deviations from WEIGHTED mean]
```

The `survey` package reference uses Taylor series linearization for the
Horvitz-Thompson estimator. Whether `survey::svymean()` for `svydesign(ids=~1)`
simplifies to the same formula for non-uniform weights is not self-evident and
is not documented in the spec. If the formulas diverge, oracle tests at `1e-10`
and `1e-8` tolerance will fail and nobody will know why.

Options:
- **[A] Add a verification requirement to Section VIII or the quality gate:**
  "Before committing oracle tests, verify with `survey::svymean()` on
  non-uniform weights that `(1-f) * var(y_uw) / n` matches the reference.
  Document the result in a comment in `R/06-variance-estimation.R`." —
  Effort: one R session, Risk: none, Impact: oracle tests are reliable.
- **[B] Change oracle test data to equal-weight SRS** for the variance
  tests — avoids the question but misses the most common real-world case.
- **[C] Do nothing** — Risk: silent oracle failures; confusing tolerances.

**Recommendation: A**.

---

**Issue 10: `na.rm = FALSE` partial-NA case unspecified and untested**
Severity: REQUIRED
[Violates engineering-preferences.md §4 — partial-NA inputs with `na.rm =
FALSE` are the most common NA scenario in real survey data; the spec covers
all-NA but not partial-NA.]

Section VIII edge case table covers:
- All `yᵢ` NA + `na.rm = TRUE` → `mean = NA_real_`, `df = 0L` ✓
- All `yᵢ` NA + `na.rm = FALSE` → `mean = NA_real_`, `df = n - 1` ✓ (with `df`
  left implicit — see Issue 4)
- `n = 1` after NA removal ✓

Missing: **some** `yᵢ` NA + `na.rm = FALSE`. Standard R NA propagation gives
`Σwᵢyᵢ = NA` when any `yᵢ` is NA (with `na.rm = FALSE`). The result should be
`mean = NA_real_`, `se = NA_real_`, `df = n - 1` (all rows counted). This case
appears in Section X as oracle test #6 ("NA removal, `na.rm = TRUE`") but there
is no corresponding test for `na.rm = FALSE` with partial NAs.

Options:
- **[A] Add the case to the edge case table AND add a test** in Section X:
  "`.srs_mean()` with one NA outcome + `na.rm = FALSE` → `mean = NA_real_`,
  `se = NA_real_`, `df = n - 1`" — Effort: low.
- **[B] Add a clarifying note only**: "partial NA + `na.rm = FALSE` propagates
  via standard R NA arithmetic; result follows the all-NA + `na.rm = FALSE`
  row" — Effort: trivial, leaves test gap.

**Recommendation: A**.

---

**Issue 11: Oracle test for total with FPC-as-fraction missing**
Severity: REQUIRED
[Violates testing-standards.md §2 — oracle tests required for all estimand ×
design combinations; the fraction formula for totals is structurally different
and untested.]

Section X oracle tests include:
- Test 3: Mean, FPC as population size ✓
- Test 4: Total, FPC as population size ✓
- Test 5: Mean, FPC as sampling fraction ✓
- ~~Total, FPC as sampling fraction~~ — **MISSING**

The total formula for `fpc_type = "fraction"` is:
```
var(T̂) = (Σwᵢ)² × (1 - f) × s² / n
```

This differs from the population-size formula `N² × (1-f) × s²/n`. Without
a reference comparison, the fraction formula could be silently wrong. The spec
also lists `.srs_total()` edge cases (all-NA, `n = 1`) but these only appear in
prose — they are not in the Section X test plan.

Options:
- **[A] Add test 8 (Total, FPC as sampling fraction) and test 9 (Total, NA
  removal) to the oracle test table**, and add edge-case tests for total with
  all-NA and `n = 1` to the non-oracle block — Effort: low.
- **[B] Add only test 8** (the oracle gap is the critical one) and note
  that total edge cases follow the same rule as mean edge cases — Effort:
  trivial.

**Recommendation: A** — both gaps are real; the fraction-formula oracle is
the higher-priority fix.

*(Note: The quality gate in Section XII says "all 7 variance scenarios" but
Section X specifies tests #1–9. Update Section XII to read "9 oracle tests.")*

---

## Section X — Test Requirements

**Issue 12: Coverage map omits row 60**
Severity: REQUIRED
[Coverage tracking gap — row 60 is a new error class defined in Section VII
but absent from the Section XI coverage table.]

Section XI shows:
```
test-constructors.R  |  1–26, 56–59
```

Row 60 (`surveycore_warning_srs_no_weights` from `as_survey_srs()`) is tested
by warning test #20 in Section X, but it never appears in the coverage map.
Additionally, because row 60 shares its class name with row 7, the coverage
map should note that rows 7 and 60 use the same class (`surveycore_warning_srs_no_weights`)
but fire from different functions.

Options:
- **[A] Update Section XI** to add row 60 to `test-constructors.R` and add a
  note explaining the shared class with row 7 — Effort: trivial.
- **[B] Do nothing** — coverage tracking is wrong; coverage map maintenance
  erodes.

**Recommendation: A**.

---

**Issue 13: `@variables` key set in test #5 not spelled out**
Severity: SUGGESTION
[Violates engineering-preferences.md §5 (explicit over clever) — test code
that's "obvious" to the spec author is not obvious to an implementer reading
the test plan.]

Section X test #5 says:
```r
keys <- c("weights", "fpc", "fpc_type", "probs_provided", "ids", "strata", "nest")
expect_true(all(keys %in% names(...)))
```

This IS spelled out in the current spec (verbatim R code). No action required
unless the spec is reviewed by someone who missed this. Leaving as SUGGESTION
to confirm.

No change needed — correctly specified.

---

## Section XII — Quality Gate

**Issue 14: Quality gate says "7 variance scenarios" but test plan has 9**
Severity: REQUIRED
[Documentation inconsistency — the quality gate criterion doesn't match the
test plan; implementers can't determine when the PR is complete.]

Section XII: "Oracle tests pass for all **7** variance scenarios."
Section X: Oracle tests #1–9 = **9 tests**.

The "7" is stale from an earlier draft.

Options:
- **[A] Change "7" to "9"** in Section XII — Effort: trivial.
- **[B] Do nothing** — ambiguous completion criterion.

**Recommendation: A**.

---

## Cross-Cutting

**Issue 15: DRY — data-level and weight validation helpers not referenced**
Severity: SUGGESTION
[Violates engineering-preferences.md §1 (DRY) — duplicated validation is a
bug waiting to happen.]

Section IV says "All existing data-level checks from `as_survey()` apply
unchanged (rows 1–4)." The spec does not say `as_survey_srs()` should call
the same internal helpers (`validate_weights()`, `.validate_fpc()`,
`.resolve_single_col()`) that `as_survey()` already uses. Without an explicit
reference, an implementer may re-implement these checks inline, causing the
two constructors to diverge the next time a check is modified.

Options:
- **[A] Add one sentence**: "These checks must be implemented via the existing
  `.validate_weights()`, `.validate_fpc()`, and `.resolve_single_col()`
  helpers — not reimplemented inline." — Effort: trivial.
- **[B] Do nothing** — implementer likely infers it; low risk but violates
  "no decisions left to judgment."

**Recommendation: A**.

---

**Issue 16: `as_survey_srs()` roxygen documentation requirements not specified**
Severity: SUGGESTION
[Violates r-package-conventions.md §1 — `@return` and `@examples` required
on all exported functions; an implementer will write inconsistent docs.]

The spec covers signature, validation, and return value but never states the
required roxygen tags. Every other constructor spec documents `@family`,
`@seealso`, `@return`, and `@examples` expectations.

Options:
- **[A] Add a "Documentation" subsection to Section IV** specifying: `@family
  constructors`, `@seealso [as_survey()]`, `@return A \code{survey_srs} object.`,
  `@examples` — one minimal runnable example: `as_survey_srs(data.frame(y = 1:5))`
  — Effort: low.
- **[B] Do nothing** — implementer infers from context; docs likely inconsistent
  with `as_survey()` and `as_survey_repweights()`.

**Recommendation: A**.

---

## Summary

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 10 |
| SUGGESTION | 4 |

**Total issues:** 15

**Blocking issues:**
- Issue 6: `as_survey()` → `as_survey_srs()` handoff underspecified — covers
  dispatch position, `probs_provided` flag propagation, row-7 double-firing,
  and warning order.

**Overall assessment:** The spec is nearly implementable — class definition,
constructor contract, variance formulas, and test structure are all well
thought out. One blocking gap must be resolved before any constructor code
is written: the spec says "all processing happens inside `as_survey_srs()`"
but never describes how `as_survey()` must be restructured to make that true,
leaving three architectural decisions (dispatch position, probs flag, row-7
split) without answers. The remaining required issues are individually
small clarifications but are dense enough that skipping them would produce
a PR where oracle tests fail at random and coverage tracking is wrong from
day one.
