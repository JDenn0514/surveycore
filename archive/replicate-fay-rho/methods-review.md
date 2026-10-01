# Methodology Review: replicate-fay-rho — Pass 1 (2026-09-30)

Six lens agents (sonnet), run in parallel on `spec.md` as drafted at DRAFT.

Lens 1 — Estimator Specification: no issues found.
Lens 4 — Domain Estimation: no issues found. `[.svyrep.design` keeps `$scale`
and `$rho`, and CB-4 runs before `.restrict_to_domain()`.
Lens 5 — Established Practice: no issues found. `svrepdesign(type = "Fay",
rho = 0)` keeps `type = "Fay"` (P5 agrees). `survey` prints
"Fay's variance method (rho= 0 ) with 8 replicates."

### New Issues

**Issue 1: The spec does not state the degrees-of-freedom precondition for the
confidence-bound oracle**
Lens: 3
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

Quality gate 2 asserts agreement on both confidence bounds. That holds only
while both sides use the normal approximation (surveycore `degf <- Inf`;
`survey`'s `confint()` default `df = Inf`), per the confidence-bound clause in
`.claude/rules/testing-surveycore.md`. `spec.md` never mentions degrees of
freedom. Fix: one sentence in Quality gate 2 stating the precondition and that
a change to replicate degrees of freedom on either side requires the Fay oracle
block to be revisited.

**Issue 2: The spec does not carry the formula's validity assumptions**
Lens: 6
Severity: ADVISORY
Resolution type: JUDGMENT CALL — resolved by the orchestrator: option A

`comprehension.md` §Assumptions: the Fay scale assumes a two-PSU-per-stratum
layout with Hadamard-balanced half samples, which surveycore does not check;
the shrinkage identity is exact for linear estimators (totals) and first-order
for means and ratios. Fix: one sentence in §I Out (no runtime check) and in
the `@param rho` roxygen text.

**Issue 3: A replicate phase 1 in `as_survey_twophase()` gets a Taylor-style
phase-1 variance that ignores the replicate scale**
Lens: 2
Severity: BLOCKING
Resolution type: JUDGMENT CALL — resolved by the user: refuse (decisions.md S9)

`.twophase_phase1_var()` (`R/variance-twophase.R:92-185`) reads only
`strata`, `ids` and `fpc`; a replicate phase 1 has none, so every row is its
own PSU. The spec's scope table says `rho` "rides along", which suggests the
path works. `survey` has no such design. Fix: per S9, `as_survey_twophase()`
refuses a `survey_replicate` phase 1 with a new typed error, a new register
row, and the dual test pattern; every existing block that builds one is
enumerated and converted.

**Issue 4: `update_design(repweights = )` keeps a stale scale when `R`
changes**
Lens: 2
Severity: REQUIRED
Resolution type: JUDGMENT CALL — resolved by the user: separate issue (S10)

Pre-existing for every type. Filed as issue #300. Fix: the spec's §I Out entry
cites #300.

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 (resolved by S9) |
| REQUIRED | 2 |
| ADVISORY | 1 |

Verdict: FAIL — all four issues have a resolution; route to Stage 2r.

## Methodology Review: replicate-fay-rho — Pass 2 (2026-09-30, delta)

Two agents (sonnet) on the sections the resolver changed.

- Issues 1 to 4: RESOLVED, each with quoted text in spec.md and test-spec.md.
- A reported gap, "row 19 not restated in plans/error-messages.md", needs no
  change: spec §IX.4 restates row 19 in the same PR as the code, the same
  pattern as CB-4. New classes (FR-1 to FR-3, TP-1) go in the register before
  code; restatements of existing rows go with the code.
- An independent search confirms the S9 site list is complete: three test
  blocks (test-constructors.R:1704 and :1720, test-variance-twophase.R:487),
  register row 19 and its snapshot at `_snaps/constructors.md:165`. No
  helper, example, vignette or README builds a replicate phase 1.

Verdict: PASS (the pass needed no change to either artifact).
