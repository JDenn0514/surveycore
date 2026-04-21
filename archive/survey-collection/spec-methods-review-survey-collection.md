# Methodology Review: survey-collection — Pass 1 (2026-04-20)

## Scope Assessment

Applied the three gating questions from `stage-2-methods-review.md`:

1. **Does this feature implement, modify, or extend a statistical or
   mathematical method?** No. `survey_collection` is an S7 container holding
   independent `survey_base` objects. The dispatch helper
   `.dispatch_over_collection()` calls existing `get_*()` functions per
   survey and row-binds results with an `.id` column.
2. **Does it produce numerical quantities with known statistical
   properties?** No. All numerical output originates in the constituent
   `get_*()` functions, whose methodology is already locked. The collection
   never combines designs, never re-specifies variance, and never pools
   estimates. Pooling / meta-analytic combination is explicitly out of scope
   (§I "Pooled estimation"; §X "Out of Scope").
3. **Does it involve iterative algorithms, closed-form formulas, or
   numerical procedures that must be exactly specified?** No. The only
   computations in the spec are `dplyr::bind_rows()`, `.id` column
   placement, and `.meta` attribute carry-over — all structural.

None of the Stage 2 trigger conditions (variance estimation section,
estimator definition, standard errors / confidence intervals / test
statistics, degrees-of-freedom formulas) are present in this spec. The two
`get_*()`-adjacent concerns that could touch methodology — `survey_glm()`
and `get_anova()` on collections — are explicitly deferred (§I "What This
Does NOT Deliver"; §X).

## Lens Applicability

| Lens | Applicable | Reason |
|---|---|---|
| 1 — Estimator Specification | No | No estimator is defined or modified. |
| 2 — Variance Estimation | No | No variance machinery is invoked or re-specified. |
| 3 — Degrees of Freedom & Inference | No | No inference, CIs, or test statistics produced by this feature. |
| 4 — Domain Estimation | No | Each survey is analyzed independently; domain estimation is the existing per-survey path. |
| 5 — Established Practice | No | No methodological convention is being adopted or departed from. |

## Decision

**Stage 2 not applicable.** This spec delivers a container class and a
structural dispatch layer. All statistical correctness concerns reduce to
those of the underlying per-survey `get_*()` calls, which are methodology-
locked independently.

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 0 |
| ADVISORY | 0 |

**Total issues:** 0

**Assessment:** No methodology to review. `survey_collection` does not
produce, combine, or alter statistical estimates — it only iterates
existing estimators across independent designs and row-binds the output.
Proceed directly to Stage 3 (code / architecture review), which is where
the meaningful risk surface of this spec lives (API shape, `.on_missing`
semantics, `.meta` carry-over, error taxonomy, test plan coverage).
