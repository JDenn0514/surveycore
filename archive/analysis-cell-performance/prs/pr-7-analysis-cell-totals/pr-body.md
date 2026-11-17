## What

`get_totals()` builds its design context once and takes its Taylor standard errors and `.vcov` from one stacked call, through a new shared helper that `get_freqs()` and `get_means()` now use too, with results that do not move (plan PR 7 of the analysis-cell-performance arc).

## Changes

- `R/analysis-helpers.R`, `R/analysis-freqs.R`, `R/analysis-means.R`: the step after the loop was byte-identical in `get_freqs()` and `get_means()`. It moves into `.taylor_se_step(design, acc_joint, acc_se, ctx)`, which returns `list(se, v)`, before `get_totals()` would add a third copy (decision D28). This is its own commit, before the tests. The freqs and means files are outside the plan's Files touched for this PR; D28 adds them.
- `R/analysis-totals.R`, `R/analysis-totals-helpers.R`: `get_totals()` builds the context once and calls `.taylor_se_step()`. Two comments are corrected, and the `.total_cell()` `@return` line no longer claims a `df`.
- `tests/testthat/test-analysis-cell-equivalence.R`: 7 blocks for rows 5.1.5, 5.1.6, 5.2.8, 5.3.3, 5.3.9, 5.5.4 and 5.5.6, written on the unchanged totals code.
- `tests/testthat/_snaps/analysis-cell-equivalence.md`: 3 new error snapshots, recorded on the unchanged code and unchanged after it. The first commit that touches `_snaps/` holds no `R/` file.
- `plans/`: PR 6 bookkeeping and decision D29.

## Measurements

Call counts for one `get_totals()` call (criterion 5):

| Scenario | `.build_cluster_matrices()` / `.svy_recvar()` before | after |
|---|---|---|
| `totals/tay` | 4 / 4 | 1 / 1 |
| `totals/rep` (replicate) | 0 / 0 | 0 / 0 |

`get_ratios()` call counts do not change.

Rows 5.5.4 and 5.5.6 (a base weight inside a cell is `NA`): on the base commit the call raises `simpleError` ("missing value where TRUE/FALSE needed"). The blocks assert that class, and the error is unchanged.

The builder compared 170 golden scenarios (freqs, means, totals, ratios, quantiles, effective n) on `develop` and on this branch with `identical()`, and the reviewer compared 784 calls over 33 designs and 5 `lonely.psu` settings the same way: all matched, `.vcov` dimnames, warning order and errors included.

Full suite: `[ FAIL 0 | WARN 254 | SKIP 4 | PASS 16735 ]`. 254 is the clean-`develop` count on the gate machine (D21), so the PR adds no warning. R CMD check `--as-cran`: `Status: 1 NOTE` (CRAN incoming feasibility). Coverage 96.66%, and every line added under `R/` is reached.

## Checklist

- [x] Tests written and passing (`devtools::test()`)
- [x] R CMD check: 0 errors, 0 warnings (`devtools::check()`)
- [x] Roxygen docs updated and `devtools::document()` run (no change to `man/` or `NAMESPACE`)
- [x] `plans/error-messages.md` updated (if new errors/warnings added): none added
- [x] `VENDORED.md` updated (if variance code vendored in this PR): none vendored
- [x] PR title is a valid Conventional Commit (`feat(scope): description`)
- [x] PR targets `develop`, not `main`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
