# Plan Review — doc-fixes

**Verdict**: PASS
**Date**: 2026-06-05

---

## Lens Results

| Lens | Verdict | Notes |
|------|---------|-------|
| PR Granularity | PASS (see note) | BLOCK overridden — see rationale below |
| Dependency Ordering | PASS | Correct throughout |
| Acceptance Criteria | PASS | All criteria observable; map 1:1 to test-spec |
| Spec Coverage | PASS | All B/D/W/S/T/M/X items scheduled |
| File Completeness | PASS | All 40 PR 2 files + all 9 PR 1 files present |

---

## Granularity Finding — Overridden

The granularity lens flagged PR 1 as a BLOCK due to 26 tasks across 14 files.

**Override rationale:**

1. **Task inflation from TDD sub-steps.** Each behavior fix generates 3 tasks (write failing test → implement → verify). The 26 tasks represent ~12 distinct behavioral changes plus 3 administrative tasks (error-messages.md registration, @method tags, devtools check). The actual review surface is 8 source files — manageable.

2. **Spec explicitly defines this 2-PR structure.** The spec's Architecture section names exactly these two PRs and designates both as `Pipeline split: optional`. Splitting PR 1 further would deviate from the spec's approved design without justification.

3. **Single logical unit.** All PR 1 changes are code bugs in existing functions: no new exports, no class changes, no statistical behavior changes. They form a coherent "bug-fix" unit, not a mixed bag.

4. **File overlap with PR 2 is expected.** `R/analysis-t-test.R` appears in both PRs because D74 is intentionally split: the `@method` tag addition (code-adjacent, required for dispatch) goes in PR 1 alongside B1/B2; the remaining doc stubs (D38, D74 doc part, D75) go in PR 2. This matches the spec's Architecture section exactly.

---

## Cross-Consistency Notes

- **D32 double-assignment**: The plan correctly assigns D32 to both `R/analysis-helpers.R` (task 6) and `R/analysis-means-helpers.R` (task 10, labeled "second instance"), matching the spec's Architecture section which lists D32 under both files.

- **T3 in two PR 2 tasks**: Task 2 handles T3 for `survey_nonprob` in `R/core-classes.R`; task 20 applies the same type of fix (drop `@keywords internal`) to `print.survey_result` (T4) and `print.survey_diffs` (T5) in `R/analysis-meta.R`. The plan's "T3 second instance" label in task 20 is a minor labeling imprecision — the fix being applied is correct and matches the spec's intent for T4/T5.

- **E2 (variance-replicate)**: Task 25 (confirm E2 test coverage) correctly describes this as registration-only for `plans/error-messages.md` — if a test already exists, no test file change is needed.

---

## Decision

The plan is complete and executable. All spec items are scheduled, all write surfaces are disjoint between PRs, and all acceptance criteria are observable. The granularity concern does not warrant splitting PR 1 given the spec's explicit design and the inflated task count from TDD sub-steps. The plan is ready for implementation.
