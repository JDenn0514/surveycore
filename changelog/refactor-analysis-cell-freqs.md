# Changelog: refactor/analysis-cell-freqs

**Branch:** `refactor/analysis-cell-freqs`
**Status:** Complete
**Date:** 2026-11-12

## Summary

This is plan PR 4 of the analysis-cell-performance arc
(`plans/decisions-analysis-cell-performance.md`). `get_freqs()` now builds
its design context once per call. It takes the Taylor standard errors of
all its cells and the joint `.vcov` from one stacked call. Its replicate
path sums only the rows inside each cell when every replicate weight is
finite. No result moves: the golden equivalence tests from #364 pass
unchanged at `tolerance = 1e-12`.

The PR completes the two shared helpers that PR 3 (#365) added:

- `.cell_context(design, check_rep_finite = FALSE)`: with
  `check_rep_finite = TRUE` on a replicate design, it records whether every
  replicate weight is finite.
- `.taylor_cell_se(vals, mats, v = NULL, lonely.psu)`: with a `v` supplied,
  it returns the covariance matrix with the standard errors (rule 2).

Call counts for one `get_freqs()` call (`trace()` counters):

| Scenario | `.build_cluster_matrices()` / `.svy_recvar()` before | after |
|---|---|---|
| `freqs/tay` (15 cells) | 16 / 16 | 1 / 1 |
| `freqs/rep` (replicate) | 0 / 0 | 0 / 0 |

**No behaviour changes.** The suite's warning count is unchanged.

## Files Modified

- `R/analysis-helpers.R`: completes `.cell_context()` and
  `.taylor_cell_se()`; `.joint_vcov()` and `.attach_joint_vcov()` take the
  shared matrices and `v`
- `R/analysis-freqs-helpers.R`: the cell helpers take the shared context;
  `.freq_rep_total()` gives the replicate cell totals by the subset sum or
  the full product
- `R/analysis-freqs.R`: `get_freqs()` builds the context once and takes its
  standard errors and `.vcov` from one stacked call
- `tests/testthat/test-analysis-cell-equivalence.R`: 5 blocks for rows
  5.2.4, 5.3.1, 5.3.7, 5.5.3 and 5.7.2, written on the unchanged code
- `tests/testthat/_snaps/analysis-cell-equivalence.md`: 4 new error
  snapshots, recorded on the unchanged code and unchanged after it
- `plans/decisions-analysis-cell-performance.md`: D24
- `plans/implementation-plan-analysis-cell-performance.md`,
  `plans/pr-budget-calibration.md`: PR 3 bookkeeping

## Changes

- test: the `get_freqs()` cell rows and snapshots
- refactor: `get_freqs()` builds its cells on the shared cell helpers
