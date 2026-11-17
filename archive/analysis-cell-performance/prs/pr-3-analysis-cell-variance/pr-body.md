## What

`get_variance()` builds the Taylor standard errors of its cells in blocks of up to 64, through three new internal helpers, with results that do not move (plan PR 3 of the analysis-cell-performance arc).

## Changes

- `R/analysis-helpers.R`: adds `TAYLOR_SE_BLOCK` (64), `.cell_context()` and `.taylor_cell_se()`, all internal.
- `R/analysis-variance-helpers.R`, `R/analysis-variance.R`: `get_variance()` buffers its cells and flushes the buffer every 64 cells and at the end.
- `tests/testthat/test-analysis-cell-equivalence.R`: 8 blocks for rows 4.6.3, 5.1.8, 5.2.9, 5.3.4, 5.3.10, 5.3.14, 5.3.16 and 5.5.1, written on the unchanged code.
- `tests/testthat/_snaps/analysis-cell-equivalence.md` (new): 5 error snapshots, recorded on the unchanged code and byte-identical after the change. The first commit that touches `_snaps/` holds no `R/` file (criterion 4).
- A separate `style:` commit: `air` reformats two spots that were not `air`-clean on `develop`.
- `plans/`: PR 1 and 2 bookkeeping, and decisions D20 to D23.

## Measurements

Call counts for one `get_variance()` call, `TAYLOR_SE_BLOCK` at 64 (criterion 6):

| Scenario | `.build_cluster_matrices()` / `.svy_recvar()` before | after |
|---|---|---|
| `variance/blk65` | 65 / 65 | 1 / 2 |
| `variance/blk64` | 64 / 64 | 1 / 1 |
| `variance/rep_na` | 0 / 0 | 0 / 0 |

Row 5.5.1 (a base weight inside a cell is `NA`): on the base commit the call raises `simpleError` ("missing value where TRUE/FALSE needed"). The block asserts that class, and the error is unchanged.

Full suite: `[ FAIL 0 | WARN 254 | SKIP 4 | PASS 16665 ]`. 254 is the clean-`develop` count on the gate machine, which has `surveytidy` and `srr` installed (D21), so the PR adds no warning. R CMD check `--as-cran`: `Status: 1 NOTE` (CRAN incoming feasibility). Coverage 96.63%, and every line added under `R/` is reached.

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
