## What

`get_freqs()` builds its design context once, takes its Taylor standard errors and `.vcov` from one stacked call, and uses guarded replicate subset sums, with results that do not move (plan PR 4 of the analysis-cell-performance arc).

## Changes

- `R/analysis-helpers.R`: completes the helpers from #365. `.cell_context()` gains `check_rep_finite`, and `.taylor_cell_se()` gains `v` and rule 2. `.joint_vcov()` and `.attach_joint_vcov()` take the shared matrices and `v`.
- `R/analysis-freqs-helpers.R`, `R/analysis-freqs.R`: `get_freqs()` builds the context once, takes its standard errors and `.vcov` from one call, and gets replicate cell totals from `.freq_rep_total()`.
- `tests/testthat/test-analysis-cell-equivalence.R`: 5 blocks for rows 5.2.4, 5.3.1, 5.3.7, 5.5.3 and 5.7.2, written on the unchanged code.
- `tests/testthat/_snaps/analysis-cell-equivalence.md`: 4 new error snapshots, recorded on the unchanged code and unchanged after it. The first commit that touches `_snaps/` holds no `R/` file.
- `plans/`: PR 3 bookkeeping and decision D24.

## Measurements

Call counts for one `get_freqs()` call (criterion 5):

| Scenario | `.build_cluster_matrices()` / `.svy_recvar()` before | after |
|---|---|---|
| `freqs/tay` (15 cells) | 16 / 16 | 1 / 1 |
| `freqs/rep` (replicate) | 0 / 0 | 0 / 0 |

Row 5.5.3 (a base weight inside a cell is `NA`): on the base commit the call raises `simpleError` ("missing value where TRUE/FALSE needed"). The block asserts that class, and the error is unchanged.

Full suite: `[ FAIL 0 | WARN 254 | SKIP 4 | PASS 16674 ]`. 254 is the clean-`develop` count on the gate machine (D21), so the PR adds no warning. R CMD check `--as-cran`: `Status: 1 NOTE` (CRAN incoming feasibility). Coverage 96.64%, and every line added under `R/` is reached.

The golden equivalence blocks from #364 pass unchanged.

## Checklist

- [x] Tests written and passing (`devtools::test()`)
- [x] R CMD check: 0 errors, 0 warnings (`devtools::check()`)
- [x] Roxygen docs updated and `devtools::document()` run (no change to `man/` or `NAMESPACE`)
- [x] `plans/error-messages.md` updated (if new errors/warnings added): none added
- [x] `VENDORED.md` updated (if variance code vendored in this PR): none vendored
- [x] PR title is a valid Conventional Commit (`feat(scope): description`)
- [x] PR targets `develop`, not `main`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
