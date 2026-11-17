## What

`get_ratios()` builds its design context once for its three per-cell calls and takes its Taylor standard errors from stacked calls in blocks of 64, with results that do not move (plan PR 8 of the analysis-cell-performance arc).

## Changes

- `R/analysis-ratios.R`: the context is built once before the loop. Calls 1 and 2 (the two totals) take its matrices. Call 3 on the Taylor route returns the influence column only, and one SE step after the loop computes the SEs in blocks of `TAYLOR_SE_BLOCK`, divides them by `abs(total_x)`, and builds `.vcov` from the scaled columns. The function dispatches on `ctx$replicate` in place of its own copy of the same test (E-2).
- `R/analysis-ratios-helpers.R`: `.delta_ratio_cell()` and `.replicate_ratio_cell()` take the context's matrices as arguments with no default.
- `tests/testthat/test-analysis-cell-equivalence.R`: 7 blocks for rows 5.1.7, 5.2.6, 5.3.6, 5.3.12, 5.5.7, 5.5.9 and 5.7.1, written on the unchanged ratios code.
- `tests/testthat/_snaps/analysis-cell-equivalence.md`: 4 new error snapshots, recorded on the unchanged code and unchanged after it. The first commit that touches `_snaps/` holds no `R/` file.
- `plans/`: PR 7 bookkeeping and decision D30.

The ratio SE step does not share code with `.taylor_se_step()`: it differs in four ways the spec fixes, and the calls the two steps share are already helpers (E-1).

## Measurements

Call counts for one `get_ratios()` call (criterion 5):

| Scenario | `.build_cluster_matrices()` / `.svy_recvar()` before | after |
|---|---|---|
| `ratios/tay_ungrouped` | 4 / 4 | 1 / 4 |
| `ratios/blk65` (65 cells, 2 blocks) | 196 / 196 | 1 / 133 |
| `ratios/rep_na` (replicate) | 0 / 0 | 0 / 0 |

Conditions on the base commit, unchanged after:

| Row | Class |
|---|---|
| 5.5.7 (grouped, a base weight is `Inf`) | `simpleError` ("missing value where TRUE/FALSE needed") |
| 5.5.9, numerator `NA` on a calibrated design | `simpleError` ("NA/NaN/Inf in foreign function call (arg 5)"), raised in call 2 |
| 5.5.9, denominator `NA` on a calibrated design | `simpleError` (same message), raised in call 1 |

Lines with no caller left after this PR (criterion 7). The defaults stay, as `spec.md` §II.3 sets them:

| Line | Branch |
|---|---|
| `R/analysis-helpers.R:1245` | `.joint_vcov()`, the `mats = NULL` build |
| `R/analysis-totals-helpers.R:79` | `.taylor_total_cell()`, the `mats = NULL` build |
| `R/analysis-totals-helpers.R:156` | `.replicate_total_cell()`, the `rep_mat = NULL` conversion |
| `R/analysis-ratios-helpers.R:155` | `.delta_ratio_cell()`, `joint$value / total_x` under `compute_se = TRUE`: the base line, re-indented. Only the nonprob SRS and two-phase routes pass `compute_se = TRUE`, and neither returns a joint element. The line stays so that a later Taylor caller cannot get an unscaled `.vcov`. |

The builder compared 180 golden and extra calls on `develop` and on this branch with `identical()`, and the reviewer compared 1664 calls on 46 designs the same way, with six `lonely.psu` settings and negative denominators: all matched, `.vcov` dimnames, warning order and errors included.

Full suite: `[ FAIL 0 | WARN 254 | SKIP 4 | PASS 16750 ]`. 254 is the clean-`develop` count on the gate machine (D21), so the PR adds no warning. R CMD check `--as-cran`: `Status: 1 NOTE` (CRAN incoming feasibility). Coverage 96.31%; the two changed files read 98.15% and 100%.

## Checklist

- [x] Tests written and passing (`devtools::test()`)
- [x] R CMD check: 0 errors, 0 warnings (`devtools::check()`)
- [x] Roxygen docs updated and `devtools::document()` run (no change to `man/` or `NAMESPACE`)
- [x] `plans/error-messages.md` updated (if new errors/warnings added): none added
- [x] `VENDORED.md` updated (if variance code vendored in this PR): none vendored
- [x] PR title is a valid Conventional Commit (`feat(scope): description`)
- [x] PR targets `develop`, not `main`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
