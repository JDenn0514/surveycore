# Changelog: refactor/analysis-cell-variance

**Branch:** `refactor/analysis-cell-variance`
**Status:** Complete
**Date:** 2026-11-12

## Summary

This is plan PR 3 of the analysis-cell-performance arc
(`plans/decisions-analysis-cell-performance.md`), and its first change under
`R/`. `get_variance()` now builds the Taylor standard errors of its cells in
blocks of up to 64 cells, in place of one call per cell. No result moves:
the golden equivalence tests from #364 pass unchanged at
`tolerance = 1e-12`.

Three internal helpers in `R/analysis-helpers.R`:

- `TAYLOR_SE_BLOCK` (64): the largest number of cells in one block.
- `.cell_context(design)`: the per-design facts every cell needs, computed
  once per call.
- `.taylor_cell_se(vals, mats, lonely.psu)`: the standard errors of a block
  of cells from one set of cluster matrices.

Call counts for one `get_variance()` call (`trace()` counters):

| Scenario | `.build_cluster_matrices()` / `.svy_recvar()` before | after |
|---|---|---|
| `variance/blk65` (65 cells) | 65 / 65 | 1 / 2 |
| `variance/blk64` (64 cells) | 64 / 64 | 1 / 1 |
| `variance/rep_na` (replicate) | 0 / 0 | 0 / 0 |

**No behaviour changes.** The suite's warning count is unchanged.

## Files Modified

- `R/analysis-helpers.R`: the three helpers
- `R/analysis-variance-helpers.R`: the cell helpers take the shared context
  and return the cell's values for the block; `.variance_flush_se()` writes
  a block's standard errors back to its rows
- `R/analysis-variance.R`: `get_variance()` fills a buffer of cells and
  flushes it every 64 cells and at the end
- `tests/testthat/test-analysis-cell-equivalence.R`: 8 blocks for rows
  4.6.3, 5.1.8, 5.2.9, 5.3.4, 5.3.10, 5.3.14, 5.3.16 and 5.5.1, written on
  the unchanged code
- `tests/testthat/_snaps/analysis-cell-equivalence.md` (new): 5 error
  snapshots, recorded on the unchanged code and unchanged after it
- `plans/decisions-analysis-cell-performance.md`: D20 to D23
- `plans/implementation-plan-analysis-cell-performance.md`,
  `plans/pr-budget-calibration.md`: PR 1 and 2 bookkeeping

## Changes

- style: `air` reformat of two spots that were not clean on `develop`
- test: the `get_variance()` cell rows and snapshots
- refactor: `get_variance()` builds its cells on `.taylor_cell_se()`
