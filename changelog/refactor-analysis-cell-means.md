# Changelog: refactor/analysis-cell-means

**Branch:** `refactor/analysis-cell-means`
**Status:** Complete
**Date:** 2026-11-13

## Summary

This is plan PR 6 of the analysis-cell-performance arc
(`plans/decisions-analysis-cell-performance.md`). `get_means()` now builds
its design context once per call. Its cells skip their own variance call;
one stacked call after the loop gives the Taylor standard errors and the
`.vcov`. Each replicate cell takes one `crossprod()`. `.degf_taylor()` runs
only on a calibrated design, on the two columns it needs. No result moves:
the golden equivalence tests from #364 pass unchanged at
`tolerance = 1e-12`.

Call counts for one call (`trace()` counters):
`.build_cluster_matrices()` / `.svy_recvar()` / `.degf_taylor()`

| Scenario | before | after |
|---|---|---|
| `means/tay` | 4 / 4 / 3 | 1 / 1 / 0 |
| `means/tay_ungrouped` | 2 / 2 / 1 | 1 / 1 / 0 |
| `means/rep_na` | 0 / 0 / 0 | 0 / 0 / 0 |
| `means/cal` | 4 / 4 / 3 | 1 / 1 / 3 |
| `quantiles/tay` | 9 / 9 / 12 | 9 / 9 / 3 |

**No behaviour changes.** The suite's warning count is unchanged.

## Files Modified

- `R/analysis-means.R`: `get_means()` builds the context once and takes its
  standard errors and `.vcov` from one call after the loop
- `R/analysis-means-helpers.R`: the cell helpers take the shared context;
  one `crossprod()` per replicate cell; `.degf_taylor()` narrowed to
  calibrated designs; a stale comment on non-probability designs corrected
- `R/analysis-helpers.R`: a comment at `.degf_taylor()`
- `tests/testthat/test-analysis-cell-equivalence.R`: 10 blocks for rows
  5.1.1 to 5.1.4, 5.1.10, 5.2.5, 5.3.2, 5.3.8, 5.5.5 and 5.5.8, written on
  the unchanged code
- `tests/testthat/_snaps/analysis-cell-equivalence.md`: 3 new error
  snapshots, recorded on the unchanged code and unchanged after it
- `DESCRIPTION`: `Config/roxygen2/version` 8.1.1
- `plans/decisions-analysis-cell-performance.md`: D26 to D28
- `plans/implementation-plan-analysis-cell-performance.md`,
  `plans/pr-budget-calibration.md`: PR 5 bookkeeping

## Changes

- chore: record roxygen2 8.1.1 in `DESCRIPTION`
- test: the `get_means()` cell rows and snapshots
- refactor: `get_means()` builds its cells on the shared cell helpers
