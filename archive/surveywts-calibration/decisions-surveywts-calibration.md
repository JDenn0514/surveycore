# Decisions — surveywts-calibration

Append-only log of HOLD resolutions.

---

## HOLD-1 — Raking architecture: A vs B

**Date:** 2026-06-04
**Signal:** HOLD raised in comprehension.md §Potential HOLD signals
**Question:** Should surveywts produce (A) a single combined indicator matrix X
(all margins column-bound) or (B) separate caldata entries per margin (the JC-4
approach)?

**Resolution:** Architecture A only.

surveywts must produce the combined indicator matrix X (all margin indicator
columns bound into a single matrix). This breaks from the JC-4 approach.
Architecture B (per-margin caldata with sequential QR projection) is **not**
supported going forward. The spec should document that `@calibration` for raking
designs requires a single caldata entry with the full combined model matrix.

**Rationale:** Architecture A matches D&S 1992 exactly and is correct for
non-orthogonal margins (the common case). Architecture B is an approximation
whose validity depends on margin orthogonality, which cannot be verified at
runtime. The cleaner contract (surveywts builds the combined matrix) is preferred.

---

## HOLD-2 — Calibration scope for survey_replicate

**Date:** 2026-06-04
**Signal:** HOLD raised in comprehension.md §Potential HOLD signals
**Question:** Is calibration on survey_replicate out of scope, metadata-only, or
a documented calibrated-replicate-weights path?

**Resolution:** Both paths in scope.

- `survey_taylor`: QR projection variance correction via `@calibration` / `as_caldata()`.
- `survey_replicate`: `@calibration` is supported as provenance metadata only. No
  variance adjustment is applied — the user is expected to pass already-calibrated
  replicate weights. The spec documents this distinction explicitly: for replicate
  designs, calibration is handled by re-calibrating each replicate weight column
  (surveywts's responsibility); surveycore stores the caldata for provenance but
  does not apply any additional variance adjustment.

**Rationale:** Complete contract coverage. Users need to know that for replicate
designs, calibration is already baked into the replicate weights, and that
`@calibration` on `survey_replicate` is provenance — not a computation trigger.
