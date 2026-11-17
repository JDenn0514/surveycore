## What

`get_covariance()` builds the Taylor standard errors of its pair cells in blocks of up to 64 on the shared cell helpers, with results that do not move (plan PR 5 of the analysis-cell-performance arc).

## Changes

- `R/analysis-covariance.R`, `R/analysis-covariance-helpers.R`: `get_covariance()` buffers its Taylor pair cells and flushes the buffer every 64 cells and at the end. The lonely-PSU abort under `survey.lonely.psu = "fail"` now fires after the loop (spec D6). No `cv_undefined` warning fires before it.
- `R/analysis-helpers.R`, `R/analysis-variance-helpers.R`: `.variance_flush_se()` now has two callers, so it moves to the shared helpers file, body unchanged (`code-style.md`). These two files are outside the plan's Files touched for this PR; D25 records the exception.
- `tests/testthat/test-analysis-cell-equivalence.R`: 7 blocks for rows 5.1.9, 5.2.10, 5.3.5, 5.3.11, 5.3.15, 5.3.17 and 5.5.2, written on the unchanged code. Row 5.1.9 asserts its two `cv_undefined` warnings.
- `tests/testthat/_snaps/analysis-cell-equivalence.md`: 5 new error snapshots, recorded on the unchanged code and unchanged after it. The first commit that touches `_snaps/` holds no `R/` file.
- `plans/`: PR 4 bookkeeping and decision D25.

## Measurements

Call counts for one `get_covariance()` call (criterion 5):

| Scenario | `.build_cluster_matrices()` / `.svy_recvar()` before | after |
|---|---|---|
| `covariance/blk65` (65 pairs) | 65 / 65 | 1 / 2 |
| `covariance/blk64` (64 pairs) | 64 / 64 | 1 / 1 |
| `covariance/rep_na` (replicate) | 0 / 0 | 0 / 0 |

Row 5.5.2 (a base weight inside a cell is `NA`): on the base commit the call raises `simpleError` ("missing value where TRUE/FALSE needed"). The block asserts that class, and the error is unchanged.

Full suite: `[ FAIL 0 | WARN 254 | SKIP 4 | PASS 16692 ]`. 254 is the clean-`develop` count on the gate machine (D21), so the PR adds no warning. R CMD check `--as-cran`: `Status: 1 NOTE` (CRAN incoming feasibility). Coverage 96.65%, and every line added under `R/` is reached.

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
