# Changelog: refactor/analysis-cell-covariance

**Branch:** `refactor/analysis-cell-covariance`
**Status:** Complete
**Date:** 2026-11-13

## Summary

This is plan PR 5 of the analysis-cell-performance arc
(`plans/decisions-analysis-cell-performance.md`). `get_covariance()` now
builds the Taylor standard errors of its pair cells in blocks of up to 64,
on the shared helpers from #365 and #366. The lonely-PSU abort under
`survey.lonely.psu = "fail"` now fires after the loop, as the spec allows
(D6). No result moves: the golden equivalence tests from #364 pass
unchanged at `tolerance = 1e-12`.

`.variance_flush_se()` now has two callers, so it moves from
`R/analysis-variance-helpers.R` to `R/analysis-helpers.R`
(`code-style.md`, D25).

Call counts for one `get_covariance()` call (`trace()` counters):

| Scenario | `.build_cluster_matrices()` / `.svy_recvar()` before | after |
|---|---|---|
| `covariance/blk65` (65 pairs) | 65 / 65 | 1 / 2 |
| `covariance/blk64` (64 pairs) | 64 / 64 | 1 / 1 |
| `covariance/rep_na` (replicate) | 0 / 0 | 0 / 0 |

**No behaviour changes.** The suite's warning count is unchanged.

## Files Modified

- `R/analysis-covariance.R`: `get_covariance()` buffers its Taylor pair
  cells and flushes the buffer every 64 cells and at the end
- `R/analysis-covariance-helpers.R`: the pair-cell helpers take the shared
  context and return the cell's influence column for the buffer
- `R/analysis-helpers.R`, `R/analysis-variance-helpers.R`: the move of
  `.variance_flush_se()`
- `tests/testthat/test-analysis-cell-equivalence.R`: 7 blocks for rows
  5.1.9, 5.2.10, 5.3.5, 5.3.11, 5.3.15, 5.3.17 and 5.5.2, written on the
  unchanged code
- `tests/testthat/_snaps/analysis-cell-equivalence.md`: 5 new error
  snapshots, recorded on the unchanged code and unchanged after it
- `plans/decisions-analysis-cell-performance.md`: D25
- `plans/implementation-plan-analysis-cell-performance.md`,
  `plans/pr-budget-calibration.md`: PR 4 bookkeeping

## Changes

- test: the `get_covariance()` cell rows and snapshots
- refactor: move `.variance_flush_se()` to the shared helpers
- refactor: `get_covariance()` builds its cells on the shared cell helpers
