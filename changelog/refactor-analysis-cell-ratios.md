# Changelog: refactor/analysis-cell-ratios

**Branch:** `refactor/analysis-cell-ratios`
**Status:** Complete
**Date:** 2026-11-16

## Summary

This is plan PR 8 of the analysis-cell-performance arc
(`plans/decisions-analysis-cell-performance.md`). `get_ratios()` now builds
its design context once per call for all three per-cell calls, and takes its
Taylor standard errors from stacked calls in blocks of `TAYLOR_SE_BLOCK`
(64) after the loop. No result moves: the golden equivalence tests from #364
pass unchanged at `tolerance = 1e-12`.

Call counts for one `get_ratios()` call (`trace()` counters):

| Scenario | `.build_cluster_matrices()` / `.svy_recvar()` before | after |
|---|---|---|
| `ratios/tay_ungrouped` | 4 / 4 | 1 / 4 |
| `ratios/blk65` (65 cells) | 196 / 196 | 1 / 133 |
| `ratios/rep_na` (replicate) | 0 / 0 | 0 / 0 |

**No behaviour changes.** The suite's warning count is unchanged.

## Files Modified

- `R/analysis-ratios.R`: `get_ratios()` builds the context once, passes it
  to the three per-cell calls, and runs the SE step in blocks after the
  loop
- `R/analysis-ratios-helpers.R`: `.delta_ratio_cell()` and
  `.replicate_ratio_cell()` take the context's matrices; call 3 on the
  Taylor route returns the influence column and no SE
- `tests/testthat/test-analysis-cell-equivalence.R`: 7 blocks for rows
  5.1.7, 5.2.6, 5.3.6, 5.3.12, 5.5.7, 5.5.9 and 5.7.1, written on the
  unchanged ratios code
- `tests/testthat/_snaps/analysis-cell-equivalence.md`: 4 new error
  snapshots, recorded on the unchanged code and unchanged after it
- `plans/decisions-analysis-cell-performance.md`: D30
- `plans/implementation-plan-analysis-cell-performance.md`,
  `plans/pr-budget-calibration.md`: PR 7 bookkeeping

## Changes

- test: the `get_ratios()` cell rows and snapshots
- refactor: `get_ratios()` builds its cells on the shared cell helpers
