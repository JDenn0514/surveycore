# Plan Review — calibrate-survey-taylor

**Verdict**: PASS
**Date**: 2026-06-03
**Resolved**: 2026-06-03 (all BLOCKs and HOLDs addressed inline — plan updated)

---

## Lens Results

| Lens | Verdict | Summary |
|------|---------|---------|
| PR Granularity | BLOCK | PR 2 has 17 tasks + 20 new test blocks; scope is overloaded |
| Dependency Ordering | PASS | PR sequence and TDD task ordering are correct |
| Acceptance Criteria | HOLD | Vague AC for `survey_replicate` tests, snapshot, and full-suite run |
| Spec Coverage | PASS | All 14 error classes, all quality gates, and all function contracts scheduled |
| File Completeness | BLOCK | `NEWS.md` absent from write surfaces; new export + property change require entry |

---

## Findings

### BLOCK-1 — PR 2 task count exceeds granularity threshold
- **Lens**: PR Granularity
- **Detail**: PR 2 comprises 17 tasks and adds ~20 new test blocks, spanning 6 files. The 10-task threshold is exceeded, and the df-adjustment logic is dispersed across three functions (.taylor_mean, .taylor_total, .taylor_mean_cell) with no single integration test covering the complete df flow.
- **Resolution required**: Restructure PR 2 so the df adjustment is extracted into an explicit step (or note the shared helper already implements this). Add one end-to-end df integration test that exercises all three code paths. Alternatively, consider splitting PR 2 into variance-wiring (tasks 1–11) and guard+numerical tests (tasks 12–17), but this is optional if df is made clearly traceable.

### BLOCK-2 — NEWS.md absent from write surfaces
- **Lens**: File Completeness
- **Detail**: `as_caldata()` is a new exported function and `@calibration` is a new public property on two classes — both are user-visible changes. R package convention requires a `NEWS.md` entry.
- **Resolution required**: Add `NEWS.md` to PR 1 write surface. Note that the spec's Architecture section did not list it, so this is an addendum to the plan, not a spec conflict.

### HOLD-1 — `survey_replicate` AC in PR 1 uses vague "analogous" phrasing
- **Lens**: Acceptance Criteria
- **Detail**: PR 1 AC line says "Analogous four `survey_replicate` tests" without naming them. The test-spec has exact names.
- **Resolution required**: Replace with the four explicit test names from `test-spec.md` lines 58–71.

### HOLD-2 — Snapshot AC criterion lacks observable detail
- **Lens**: Acceptance Criteria
- **Detail**: "Snapshot files committed and reviewed via `snapshot_review()`" is not measurable — does not name the file or state which snapshots are expected.
- **Resolution required**: Replace with: "`tests/testthat/_snaps/test-calibration.md` contains 13 error-path snapshots for `as_caldata()` and is committed after `testthat::snapshot_review()`."

### HOLD-3 — "Full `devtools::test()` green" AC is non-specific
- **Lens**: Acceptance Criteria
- **Detail**: PR 2 AC line "Full `devtools::test()` green" is vague — does not state which test count increase is expected.
- **Resolution required**: Replace with: "All previously passing tests continue to pass; 20+ new test blocks in `test-calibration.R` and 1 in `test-update-design.R` all pass."

### HOLD-4 — NEWS.md downgraded note (aligned with File Completeness BLOCK-2)
- Already covered by BLOCK-2 above. No separate action needed.

---

## Decision

Two BLOCKs prevent advancement: PR 2 task organization is over the granularity threshold (remediable without spec changes), and `NEWS.md` is missing from write surfaces. Three HOLDs require AC wording improvements. All are resolvable by updating the plan document — no spec changes or user decisions required.
