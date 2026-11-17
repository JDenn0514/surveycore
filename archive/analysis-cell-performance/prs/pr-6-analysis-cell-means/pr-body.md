## What

`get_means()` builds its design context once, takes its Taylor standard errors and `.vcov` from one stacked call, uses one `crossprod()` per replicate cell, and runs `.degf_taylor()` only where it is needed, with results that do not move (plan PR 6 of the analysis-cell-performance arc).

## Changes

- `R/analysis-means.R`, `R/analysis-means-helpers.R`: the cells skip their own variance call; one call after the loop gives the standard errors and `.vcov`. `.degf_taylor()` runs only on a calibrated design, on the two columns it needs; the degrees of freedom are unchanged for every design class.
- `R/analysis-helpers.R`: a comment at `.degf_taylor()`.
- `tests/testthat/test-analysis-cell-equivalence.R`: 10 blocks for rows 5.1.1 to 5.1.4, 5.1.10, 5.2.5, 5.3.2, 5.3.8, 5.5.5 and 5.5.8, written on the unchanged code.
- `tests/testthat/_snaps/analysis-cell-equivalence.md`: 3 new error snapshots, recorded on the unchanged code and unchanged after it. The first commit that touches `_snaps/` holds no `R/` file.
- `DESCRIPTION`: `Config/roxygen2/version` 8.1.1, as its own `chore:` commit.
- `plans/`: PR 5 bookkeeping and decisions D26 to D28. D28 moves the step after the loop, now byte-identical in `get_freqs()` and `get_means()`, into one shared helper in the next PR.

## Measurements

Call counts for one call, `.build_cluster_matrices()` / `.svy_recvar()` / `.degf_taylor()` (criterion 5):

| Scenario | before | after |
|---|---|---|
| `means/tay` | 4 / 4 / 3 | 1 / 1 / 0 |
| `means/tay_ungrouped` | 2 / 2 / 1 | 1 / 1 / 0 |
| `means/rep_na` | 0 / 0 / 0 | 0 / 0 / 0 |
| `means/cal` | 4 / 4 / 3 | 1 / 1 / 3 |
| `quantiles/tay` | 9 / 9 / 12 | 9 / 9 / 3 |

Rows 5.5.5 and 5.5.8 (a base weight inside a cell is `NA`): on the base commit the call raises `simpleError` ("missing value where TRUE/FALSE needed"). The blocks assert that class, and the error is unchanged.

The reviewer also ran 2,412 `get_means()` and `get_quantiles()` calls on `develop` and on this branch, across 33 designs, and compared them with `identical()`: all matched, `.vcov` dimnames, warning order and error text included.

Full suite: `[ FAIL 0 | WARN 254 | SKIP 4 | PASS 16719 ]`. 254 is the clean-`develop` count on the gate machine (D21), so the PR adds no warning. R CMD check `--as-cran`: `Status: 1 NOTE` (CRAN incoming feasibility). Coverage 96.65%, and every line added under `R/` is reached.

## Checklist

- [x] Tests written and passing (`devtools::test()`)
- [x] R CMD check: 0 errors, 0 warnings (`devtools::check()`)
- [x] Roxygen docs updated and `devtools::document()` run (no change to `man/` or `NAMESPACE`)
- [x] `plans/error-messages.md` updated (if new errors/warnings added): none added
- [x] `VENDORED.md` updated (if variance code vendored in this PR): none vendored
- [x] PR title is a valid Conventional Commit (`feat(scope): description`)
- [x] PR targets `develop`, not `main`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
