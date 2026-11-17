# Changelog: refactor/analysis-cell-performance

**Branch:** `refactor/analysis-cell-performance`
**Status:** In progress
**Date:** 2026-11-17

## Summary

This is plan PR 9, the last PR of the analysis-cell-performance arc
(`plans/decisions-analysis-cell-performance.md`). It sets the Taylor SE
block size from a measured table.

## Block-size table

`TAYLOR_SE_BLOCK` sets the number of influence columns in one stacked
`.svy_recvar()` call in `get_variance()`, `get_covariance()` and
`get_ratios()` (decision D12). Measured on the branch head at `1eb5bd6`,
installed with `R CMD INSTALL`, with the constant set per size by
`utils::assignInNamespace()`. Each time is the median of 3 runs after one
warm-up call, in seconds (the warm-up took more than 1 s in every case).
R 4.6.1 ucrt on Windows 11, reference BLAS, `getOption("matprod")` =
`"default"`.

- V3: `get_variance(b_tay, c(y1, y2, y3), group = c(g20, g3))`, 180 cells
- C2: `get_covariance(b_tay, c(y1, y2, y3), group = c(g20, g3), diagonal = TRUE)`, 360 cells
- R4: `get_ratios(b_tay, y1, y2, group = c(g20, g3))`, 60 cells

| `B` | V3 (s) | C2 (s) | R4 (s) | Sum (s) | V3 vs base | C2 vs base | R4 vs base |
|---|---|---|---|---|---|---|---|
| 16 | 1.55 | 2.23 | 4.03 | 7.81 | `identical()` | `identical()` | `identical()` |
| 32 | 1.55 | 2.21 | 3.37 | 7.13 | `identical()` | `identical()` | `identical()` |
| 64 | 1.51 | 2.21 | 3.62 | 7.34 | `identical()` | `identical()` | `identical()` |

"vs base" compares the whole result with the same call on the base commit
`0c0a987`. Every result is `identical()` at every size, so no 1e-12
comparison was needed.

The smallest sum is 7.13 s, at `B` = 32. The rule of `spec.md` §XII.5
selects the smallest `B` whose sum is within 5% of it (7.49 s or less):
16 gives 7.81 s and does not qualify, so `TAYLOR_SE_BLOCK` is 32. V3 and
C2 differ by 0.04 s or less across the three sizes; R4 decides the
selection.
