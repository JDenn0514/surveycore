## What

Plan PR 9, the last of the analysis-cell-performance arc: `TAYLOR_SE_BLOCK` is set from a measured table, and the arc's speed table, `NEWS.md` entry and changelog are added. **The committed value is `TAYLOR_SE_BLOCK = 32`** (was 64). No result moves: every one of the 31 speed scenarios gives a result `identical()` to the base commit `0c0a987`.

## Changes

- `R/analysis-helpers.R`: `TAYLOR_SE_BLOCK <- 32L`, with a comment naming the rule and the changelog. This is its own commit, `32de4c5`, which is the commit installed for the speed run (criterion 2).
- `NEWS.md`: a `# surveycore (development version)` section with `## Performance`: the speed bullet and the lonely-PSU timing bullet, as `spec.md` §XIII gives them.
- `changelog/refactor-analysis-cell-performance.md`: the arc changelog with the block-size table, the speed table, the environment and the `identical()` evidence.
- `plans/`: PR 8 bookkeeping and decision D31.

## Block size

Median of 3 runs after one warm-up, in seconds, on `b_tay` (50,000 rows):

| `B` | V3 | C2 | R4 | Sum |
|---|---|---|---|---|
| 16 | 1.55 | 2.23 | 4.03 | 7.81 |
| 32 | 1.55 | 2.21 | 3.37 | 7.13 |
| 64 | 1.51 | 2.21 | 3.62 | 7.34 |

The rule (§XII.5) takes the smallest `B` within 5% of the smallest sum, so 32. The pick sits inside run-to-run noise: R4 moved 0.77 s between two passes at the same size, and the reviewer's second pass at 32 would have picked 16. Every size gives `identical()` results, so the choice moves speed and memory only.

## Speed table

Base `0c0a987` against `32de4c5`, one library each, one R process at a time. Median of 5 runs after one warm-up (3 when the warm-up took more than 1 s). Counts are `.build_cluster_matrices()` / `.svy_recvar()` calls for one call. R 4.6.1 ucrt on Windows 11, reference BLAS and LAPACK, `matprod` `"default"`.

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

Gate 9 flags no scenario. The reviewer re-timed M7, C2, F5 and R2 in fresh sessions: after/before 0.16, 0.11, 0.13 and 0.31.

## Checks

Full suite: `[ FAIL 0 | WARN 254 | SKIP 4 | PASS 16750 ]`. 254 is the clean-`develop` count on the gate machine (D21). The golden `blk16` to `blk65` ids pass at the committed size. R CMD check `--as-cran`: `Status: 1 NOTE` (CRAN incoming feasibility). Coverage 96.31%.

## Checklist

- [x] Tests written and passing (`devtools::test()`): no new tests; speed is measured outside the suite
- [x] R CMD check: 0 errors, 0 warnings (`devtools::check()`)
- [x] Roxygen docs updated and `devtools::document()` run (no change to `man/` or `NAMESPACE`)
- [x] `plans/error-messages.md` updated (if new errors/warnings added): none added
- [x] `VENDORED.md` updated (if variance code vendored in this PR): none vendored
- [x] PR title is a valid Conventional Commit (`feat(scope): description`)
- [x] PR targets `develop`, not `main`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
