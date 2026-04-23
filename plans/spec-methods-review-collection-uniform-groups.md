# Methodology Review: collection-uniform-groups

## Pass 1 (2026-04-22)

**Stage 2 not applicable.**

### Scope Assessment

| Question | Answer |
|---|---|
| Does this feature implement, modify, or extend a statistical or mathematical method? | No |
| Does it produce numerical quantities with known statistical properties? | No |
| Does it involve iterative algorithms, closed-form formulas, or numerical procedures that must be exactly specified? | No |

### Reason

The spec at `plans/spec-collection-uniform-groups.md` introduces a structural
uniform-grouping invariant on the `survey_collection` container:

- A new `@groups` property on `survey_collection` (class `S7::class_character`).
- A class validator requiring `identical(coll@groups, coll@surveys[[i]]@groups)`
  for every member.
- A `group =` argument on `as_survey_collection()` that either propagates onto
  members or adopts from uniformly-grouped members.
- `add_survey()` propagation rules (empty → propagate, non-empty + mismatch →
  error).
- A new `[[<-` method that validates `@groups` match before assigning.
- A `Groups:` line in `print.survey_collection`.
- Seven error-class rows (G1–G7).

There are no estimators, no variance formulas, no standard errors or
confidence intervals, no degrees-of-freedom logic, and no numerical
procedures. The spec explicitly routes all inference concerns through the
already-shipped `get_*()` dispatch machinery
(`.dispatch_over_collection()` + `.resolve_groups()`), with no changes to
that layer (§I "NOT delivered"). Per-survey analysis will continue to
produce the same estimates it produces today; the only change this spec
makes is where the grouping vector is physically stored and who owns the
invariant.

All five lenses (Estimator Specification, Variance Estimation, Degrees of
Freedom and Inference, Domain Estimation, Established Practice and
Literature) therefore have no statistical content to review.

### Summary

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 0 |
| ADVISORY | 0 |

**Total issues:** 0

**Assessment:** Stage 2 N/A — spec is purely about container invariants,
mutator propagation rules, and error classes. Proceed to Stage 3
(code/architecture review) without methodology-locking, since no
methodology was defined.
