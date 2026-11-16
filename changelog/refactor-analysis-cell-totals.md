# Changelog: refactor/analysis-cell-totals

**Branch:** `refactor/analysis-cell-totals`
**Status:** Complete
**Date:** 2026-11-16

## Summary

This is plan PR 7 of the analysis-cell-performance arc
(`plans/decisions-analysis-cell-performance.md`). `get_totals()` now builds
its design context once per call and takes its Taylor standard errors and
`.vcov` from one stacked call after the loop. No result moves: the golden
equivalence tests from #364 pass unchanged at `tolerance = 1e-12`.

Before that change, the PR moves the step after the loop, which was
byte-identical in `get_freqs()` and `get_means()`, into one internal helper,
`.taylor_se_step(design, acc_joint, acc_se, ctx)` in `R/analysis-helpers.R`
(D28). All three functions now call it.

Call counts for one `get_totals()` call (`trace()` counters):

| Scenario | `.build_cluster_matrices()` / `.svy_recvar()` before | after |
|---|---|---|
| `totals/tay` | 4 / 4 | 1 / 1 |
| `totals/rep` (replicate) | 0 / 0 | 0 / 0 |

**No behaviour changes.** The suite's warning count is unchanged.

## Files Modified

- `R/analysis-helpers.R`: `.taylor_se_step()`
- `R/analysis-freqs.R`, `R/analysis-means.R`: call `.taylor_se_step()` in
  place of their copies of the step
- `R/analysis-totals.R`, `R/analysis-totals-helpers.R`: `get_totals()`
  builds the context once and calls `.taylor_se_step()`; two comments
  corrected, and the `.total_cell()` `@return` line no longer claims a `df`
- `tests/testthat/test-analysis-cell-equivalence.R`: 7 blocks for rows
  5.1.5, 5.1.6, 5.2.8, 5.3.3, 5.3.9, 5.5.4 and 5.5.6, written on the
  unchanged totals code
- `tests/testthat/_snaps/analysis-cell-equivalence.md`: 3 new error
  snapshots, recorded on the unchanged code and unchanged after it
- `plans/decisions-analysis-cell-performance.md`: D29
- `plans/implementation-plan-analysis-cell-performance.md`,
  `plans/pr-budget-calibration.md`: PR 6 bookkeeping

## Changes

- refactor: share the stacked Taylor SE step
- test: the `get_totals()` cell rows and snapshots
- refactor: `get_totals()` builds its cells on the shared cell helpers
