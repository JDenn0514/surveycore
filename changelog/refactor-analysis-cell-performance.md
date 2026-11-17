# Changelog: refactor/analysis-cell-performance

**Branch:** `refactor/analysis-cell-performance`
**Status:** Complete
**Date:** 2026-11-17

## Summary

This is plan PR 9, the last PR of the analysis-cell-performance arc
(`plans/decisions-analysis-cell-performance.md`). It sets the Taylor SE
block size `TAYLOR_SE_BLOCK` from a measured table (64 to 32), records the
speed of the six changed functions against the base commit `0c0a987`, and
adds the `NEWS.md` entry for the arc (#364 to #371).

All 31 benchmark results are `identical()` to the base commit. All six
functions are faster: after/before is 0.05 to 0.60, and 0.54 or less on
every call that took 0.1 s or more before.

Under `survey.lonely.psu = "fail"`, a call that fails now computes every
cell first (in `get_variance()` and `get_covariance()`, every cell up to the
first full block) and then raises the error.

Under `options(warn = 2)`, a warning from one of those cells becomes an
error and replaces the lonely-PSU error.

The base-commit outputs captured for this work stay as a permanent check.
When a later change moves one of these results on purpose, regenerate them
with the generator in `data-raw/`.

## Files Modified

- `R/analysis-helpers.R`: `TAYLOR_SE_BLOCK` is 32, not 64, from the
  block-size table below; the comment names the rule and this file
- `NEWS.md`: the development-version section with the `## Performance`
  entry for the arc
- `changelog/refactor-analysis-cell-performance.md`: this file

## Changes

- perf: `TAYLOR_SE_BLOCK` set from the measured block-size table
- docs: the `NEWS.md` entry, the speed table and the block-size table

## Block-size table

`TAYLOR_SE_BLOCK` sets the number of influence columns in one stacked
`.svy_recvar()` call in `get_variance()`, `get_covariance()` and
`get_ratios()` (decision D12). Measured on the branch head at `1eb5bd6`,
installed with `R CMD INSTALL`, with the constant set per size by
`utils::assignInNamespace()`. Each time is the median of 3 runs after one
warm-up call, in seconds (the warm-up took more than 1 s in every case).

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

The smallest sum is 7.13 s, at `B` = 32. The rule of the spec (§XII.5)
selects the smallest `B` whose sum is within 5% of it (7.49 s or less):
16 gives 7.81 s and does not qualify, so `TAYLOR_SE_BLOCK` is 32. V3 and
C2 differ by 0.04 s or less across the three sizes; R4 decides the
selection.

## Speed table

Base commit `0c0a987` against the branch head `32de4c5` (the commit that
sets the block size), each installed with `R CMD INSTALL` into its own
library and run one after the other with no other R process alive. Each
time is the median of 5 runs after one warm-up call (3 runs when the
warm-up took more than 1 s), in seconds. Counts are
`.build_cluster_matrices()` / `.svy_recvar()` calls for one call, from a
separate `trace()` pass. `identical()` compares the whole saved result.

Environment: R 4.6.1 (2026-06-24 ucrt) on Windows 11;
`extSoftVersion()[["BLAS"]]` and `La_library()` are empty (the reference
BLAS and LAPACK that ship with R); `getOption("matprod")` is `"default"`.

The designs and calls are those of the spec (§XII.2, §XII.3): `gss_d` and
`gss_cal` are `gss_2024`; `a_tay`, `a_rep`, `b_tay` and `b_rep` are
50,000-row synthetic frames, the replicate designs with 80 bootstrap
replicates.

| Scenario | Rows | Before (s) | After (s) | After/before | Counts before | Counts after | `identical()` |
|---|---|---|---|---|---|---|---|
| F1 | 8 | 0.23 | 0.03 | 0.13 | 9 / 9 | 1 / 1 | TRUE |
| F2 | 24 | 0.65 | 0.06 | 0.09 | 25 / 25 | 1 / 1 | TRUE |
| F3 | 22 | 0.58 | 0.03 | 0.05 | 23 / 23 | 1 / 1 | TRUE |
| F4 | 10 | 0.44 | 0.05 | 0.11 | 11 / 11 | 1 / 1 | TRUE |
| F5 | 40 | 1.61 | 0.20 | 0.12 | 41 / 41 | 1 / 1 | TRUE |
| F6 | 25 | 1.08 | 0.13 | 0.12 | 26 / 26 | 1 / 1 | TRUE |
| F7 | 10 | 0.38 | 0.11 | 0.29 | 0 / 0 | 0 / 0 | TRUE |
| F8 | 40 | 1.44 | 0.21 | 0.15 | 0 / 0 | 0 / 0 | TRUE |
| F9 | 25 | 0.89 | 0.29 | 0.33 | 0 / 0 | 0 / 0 | TRUE |
| M1 | 1 | 0.06 | 0.02 | 0.33 | 2 / 2 | 1 / 1 | TRUE |
| M2 | 5 | 0.16 | 0.03 | 0.19 | 6 / 6 | 1 / 1 | TRUE |
| M3 | 6 | 0.22 | 0.03 | 0.14 | 7 / 7 | 1 / 1 | TRUE |
| M4 | 5 | 0.17 | 0.04 | 0.24 | 6 / 6 | 1 / 1 | TRUE |
| M5 | 1 | 0.09 | 0.03 | 0.33 | 2 / 2 | 1 / 1 | TRUE |
| M6 | 20 | 1.03 | 0.13 | 0.13 | 21 / 21 | 1 / 1 | TRUE |
| M7 | 60 | 2.75 | 0.48 | 0.17 | 61 / 61 | 1 / 1 | TRUE |
| M8 | 1 | 0.05 | 0.03 | 0.60 | 0 / 0 | 0 / 0 | TRUE |
| M9 | 20 | 0.79 | 0.37 | 0.47 | 0 / 0 | 0 / 0 | TRUE |
| T1 | 5 | 0.16 | 0.03 | 0.19 | 6 / 6 | 1 / 1 | TRUE |
| T2 | 20 | 0.89 | 0.14 | 0.16 | 21 / 21 | 1 / 1 | TRUE |
| T3 | 20 | 0.56 | 0.28 | 0.50 | 0 / 0 | 0 / 0 | TRUE |
| V1 | 40 | 1.62 | 0.23 | 0.14 | 40 / 40 | 1 / 2 | TRUE |
| V2 | 20 | 0.52 | 0.23 | 0.44 | 0 / 0 | 0 / 0 | TRUE |
| V3 | 180 | 7.64 | 1.12 | 0.15 | 180 / 180 | 1 / 6 | TRUE |
| C1 | 20 | 0.85 | 0.14 | 0.16 | 20 / 20 | 1 / 1 | TRUE |
| C2 | 360 | 13.52 | 1.56 | 0.12 | 360 / 360 | 1 / 12 | TRUE |
| C3 | 20 | 0.68 | 0.37 | 0.54 | 0 / 0 | 0 / 0 | TRUE |
| R1 | 5 | 0.40 | 0.11 | 0.27 | 16 / 16 | 1 / 12 | TRUE |
| R2 | 20 | 2.36 | 0.83 | 0.35 | 61 / 61 | 1 / 42 | TRUE |
| R3 | 20 | 1.84 | 0.96 | 0.52 | 0 / 0 | 0 / 0 | TRUE |
| R4 | 60 | 7.23 | 2.44 | 0.34 | 181 / 181 | 1 / 123 | TRUE |

After/before is computed from the unrounded medians. No scenario is
flagged by the slowdown check (before 0.1 s or more, after more than 10%
and more than 0.02 s slower). The after-counts match the spec's formula at
`B` = 32: one stacked call for `get_freqs()`, `get_means()` and
`get_totals()`; `ceiling(k / 32)` for `get_variance()` and
`get_covariance()` (V1 2, V3 6, C2 12); and for `get_ratios()` one call per
non-empty total cell in each of the two total calls, plus
`ceiling(k / 32)`, plus 1 for `.vcov` (R1 5 + 5 + 1 + 1, R2 20 + 20 + 1 + 1,
R4 60 + 60 + 2 + 1). The replicate scenarios make no Taylor call.

## `identical()` evidence

Before this work, prototypes on `develop` at `0c0a987` (R 4.6.1 ucrt,
Windows 11, reference BLAS, `matprod` `"default"`) gave `identical()`
results:

| Prototype | Result |
|---|---|
| `get_freqs()` fixes 1 and 2 (Taylor) | `identical()` TRUE on the whole result, `.vcov` included, also with `variance = c("se", "ci", "var", "cv", "moe", "deff")` |
| `get_means()` fixes 1, 2, 4 (Taylor) and 3 (replicate) | `identical()` TRUE on 10 scenarios and 12 edge designs (two-stage with FPC, SRS, strata only, each under `remove`, `adjust`, `average`, `certainty`), the calibrated `df` column included |
| `get_means()` one `crossprod()` against two products | `identical()` TRUE on `rep_N_d`, `rep_Y` and the ratios |
| Stacked diagonal against one-column calls, every column finite | `identical()` TRUE under `remove`, `adjust`, `average`, `certainty`, one-stage and two-stage with FPC, with a lonely stratum |
| `crossprod()` with a `NaN` or `Inf` column | The finite block does not move (200 seeds, 0 mismatches) |
| `sqrt(max(0, x))` against `sqrt(pmax(0, x))` for `NaN` and `NA` | `identical()` TRUE |
| `nrow(df[rows, NULL, drop = FALSE])` against `sum(rows)` | Equal for a logical `rows` with no `NA`, all-`FALSE` included |

The shipped code holds the same: the 31 speed scenarios above, and V3, C2
and R4 at each of `B` = 16, 32 and 64, are `identical()` to the base
commit. The golden test file `tests/testthat/test-analysis-cell-equivalence.R`
(#364) compares 261 base-commit scenarios at `tolerance = 1e-12` and passes
at `TAYLOR_SE_BLOCK` = 32, the `blk16` to `blk65` block-boundary scenarios
included.
