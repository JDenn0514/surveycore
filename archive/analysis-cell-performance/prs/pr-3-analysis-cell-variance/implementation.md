# Implementation — PR 3: `refactor/analysis-cell-variance`

**Builder**: opus, 2026-11-12. Branch `refactor/analysis-cell-variance`,
cut from `5124100`. Nothing is committed.

## Files changed

| File | Change |
|---|---|
| `R/analysis-helpers.R` | Adds `TAYLOR_SE_BLOCK`, `.cell_context()`, `.taylor_cell_se()`; three lines in the header contents list |
| `R/analysis-variance.R` | `get_variance()`: call context, flush buffer, end-of-loop flush |
| `R/analysis-variance-helpers.R` | New signatures of `.taylor_variance_cell()`, `.replicate_variance_cell()`, `.variance_cell()`; adds `.variance_flush_se()` |
| `tests/testthat/test-analysis-cell-equivalence.R` | 8 new blocks |
| `tests/testthat/_snaps/analysis-cell-equivalence.md` | New file, 5 entries |

`DESCRIPTION`, `man/` and `NAMESPACE` do not change. `devtools::document()`
bumped `Config/roxygen2/version` from 8.1.0 to 8.1.1 (the same thing PR 1
review F-1 found); I reverted it.

## What each new function does

- `TAYLOR_SE_BLOCK <- 64L`: the largest number of influence columns one
  stacked `.svy_recvar()` call takes. Internal.
- `.cell_context(design)`: returns `taylor`, `replicate`, `mats` (the
  `.build_cluster_matrices()` list when `taylor`, else `NULL`), `rep_mat`
  (the replicate matrix when `replicate`, else `NULL`), `rep_finite`
  (always `FALSE`; PR 4 adds `check_rep_finite`), `lonely.psu`. The
  `replicate` predicate includes a `survey_nonprob` with replicate weights.
- `.taylor_cell_se(vals, mats, lonely.psu = getOption(...))`: rule 1 (one
  finite check), rule 3 (blocks of at most `TAYLOR_SE_BLOCK` columns,
  `sqrt(pmax(0, diag(v)))`), rule 4 (per-column `.svy_recvar()`,
  `sqrt(max(0, v[1, 1]))`). Returns an unnamed vector. No `v` argument
  (PR 4, planner note P-1).
- `.variance_flush_se(columns, override, ctx)` (not named by the plan, see
  hand-written additions): binds the buffered columns, calls
  `.taylor_cell_se()`, and writes `NaN` where the `na.rm = FALSE` override
  flag is `TRUE`.
- `.taylor_variance_cell(design, y_col, domain, mats)`: no longer builds
  matrices or calls `.svy_recvar()`. A cell that reaches the variance step
  returns `se = NA_real_` and `infl = unname(u)`. Early returns are unchanged
  and have no `infl`.
- `.replicate_variance_cell(design, y_col, domain, rep_mat)`: takes
  `rep_mat` from the context instead of converting it per cell.
- `.variance_cell(design, y_col, domain, ctx)`: passes `ctx$mats` to the
  Taylor cell and `ctx$rep_mat` to the replicate cell (both classes).
- `get_variance()`: `ctx <- .cell_context(design)` just before the cell
  loop. Per cell: take `infl` off the cell, set the override flag where the
  existing `na.rm = FALSE` block sets `NaN`, append the result to `acc_*`,
  then push `infl`, its `acc_*` row position and its flag into the buffer.
  When the buffer holds `TAYLOR_SE_BLOCK` columns, flush it into `acc_se`.
  After the loop, before step 7, flush a non-empty partial buffer. No
  `.vcov`.

## Tests added (test-spec row ids)

All written and run on the unchanged code first; all passed there.

| Row | Block |
|---|---|
| 4.6.3 | "get_variance() and get_covariance() results carry no stored covariance matrix" (warnings asserted per D18 / review erratum item 2) |
| 5.1.8 | "get_variance() gives each clean group the SE of its own domain when another group has an Inf" (no warning on the base commit, so no wrapper) |
| 5.2.9 | "get_variance() errors when every replicate weight is NA on a row inside a cell" (dual) |
| 5.3.4 | "get_variance() errors on a single-PSU stratum when lonely.psu is fail" (dual) |
| 5.3.10 | "get_variance() errors on a single-PSU stratum when lonely.psu is an unknown value" (dual) |
| 5.3.14 | "get_variance() errors on a single-PSU stratum under fail when the call has 65 cells" (dual) |
| 5.3.16 | "get_variance() errors on a single-PSU stratum under fail when its only cell has an NA and na.rm = FALSE" (dual) |
| 5.5.1 | "get_variance() still errors when a base weight inside a cell is NA" (`simpleError`) |

Base-commit class probe for 5.5.1, in a scratch session:
`class(tryCatch(<call>, error = identity))` gives
`"simpleError" "error" "condition"`, message "missing value where
TRUE/FALSE needed". For the PR description.

## Snapshot entries added (5)

All recorded on the unchanged code, and byte-identical after the change
(`cmp` against a copy taken before the `R/` edits):

| Row | Message |
|---|---|
| 5.2.9 | Error in `.svy_rep_var()`: "All replicates produced NA estimates." |
| 5.3.4 | Error in `.svy_onestrat()`: "Stratum 6 has only one PSU at stage 1." |
| 5.3.10 | Error in `.svy_onestrat()`: "Unknown `lonely.psu` value: "unknown_value"." |
| 5.3.14 | Error in `.svy_onestrat()`: "Stratum 6 has only one PSU at stage 1." |
| 5.3.16 | Error in `.svy_onestrat()`: "Stratum 6 has only one PSU at stage 1." |

No existing `_snaps/` file changed.

## Test runs (`NOT_CRAN=true`, `devtools::load_all()` + `testthat::test_file()`)

| File | Code | Blocks | Expectations | Failed | Warnings |
|---|---|---|---|---|---|
| `test-analysis-cell-equivalence.R` | base | 29 | 2866 | 0 | 0 |
| `test-analysis-cell-equivalence.R` | changed | 29 | 2866 | 0 | 0 |
| `test-analysis-variance.R` | changed | 47 | 250 | 0 | 2 |
| `test-analysis-variance-collection.R` | changed | 16 | 35 | 0 | 0 |
| `test-analysis-variance-twophase-nonprob.R` | changed | 7 | 55 | 0 | 3 |

The 5 warnings in the last two files are pre-existing and leak from
unchanged paths: one `variance_all_na`, one `small_cell`, three
`nonprob_srs_fallback`. I did not run these files on the base code; the
leader's full-suite count (369) settles it. The full suite was not run.

## Call counts (criterion 6, scratch session, `trace()` counters)

| Scenario | Before: `.build_cluster_matrices()` / `.svy_recvar()` | After |
|---|---|---|
| `variance/blk65` | 65 / 65 | 1 / 2 |
| `variance/blk64` | 64 / 64 | 1 / 1 |
| `variance/rep_na` | 0 / 0 | 0 / 0 |

All three "after" values match criterion 6.

## Break-it check

Each break was applied alone, the equivalence file run, then restored.
After the last restore: the four files pass `air format --check`, the
snapshot file is byte-identical to the pre-change copy, and a final run
gives 29 blocks, 2866 expectations, 0 failed.

| Break | Failed blocks (expectations) |
|---|---|
| Rule 3: `diag(v)` multiplied by `1 + 1e-9` | variance quiet golden (27), variance noisy golden (5), 5.1.8 (2) |
| `.variance_flush_se()`: drop `se[override] <- NaN` | variance quiet golden (3: the `na.rm = FALSE` ids) |
| `get_variance()`: keep override cells out of the buffer | 5.3.16 (2: class and snapshot) |
| `.taylor_cell_se()`: rule 4 disabled (always blocks) | variance quiet golden (1), 5.1.8 (2) |

## Errata

- **E-1 (spec §II.3, plan PR 3 task 5). `.taylor_variance_cell()` takes a
  required `mats` that it never reads.** The spec gives the cell the
  signature `(design, y_col, domain, mats)` and also says the one-caller
  Taylor cells always skip their own `.svy_recvar()` call. With no variance
  call, the cell has no use for `mats`. I kept the signature as written and
  said so in the cell's comment. A reviewer may prefer to drop the
  argument; that is a spec change.
- **E-2 (plan G item 7, gate 7). Two of the PR's files were not `air`-clean
  on the base commit.** `R/analysis-helpers.R` (a double blank line after
  the header) and `R/analysis-variance-helpers.R` (an `if (isTRUE(...))`
  in `.replicate_variance_cell()`) fail `air format --check` at `5124100`.
  Gate 7 requires the changed files to pass, so `air format` reformatted
  those two places. Neither is a behaviour change; the diff shows them.
- **E-3 (plan PR 3 task 1, row 4.6.3; already recorded as D18 and PR 1
  review erratum item 2).** The plan's `character(0), 0L` body fails on
  three of the four ids. I used the recorded warnings from
  `cell_golden_noisy`, with `character(0)` for `variance/blk65`.
- **E-4 (plan PR 3 task 2).** Task 2 says to commit the tests and snapshot
  before any `R/` change. The brief forbids commits, so both are in the
  working tree with the `R/` changes. The ordering of criterion 4 holds by
  measurement (snapshot recorded on the base code, byte-identical after),
  not by git history. The shipper must make two commits for criterion 4's
  `git log` check to pass: tests and snapshot first, `R/` second.
- **E-5 (spec §III.3 rule 3, planner note P-7, D15).** As the plan
  predicted: `get_variance()` never passes more than `TAYLOR_SE_BLOCK`
  columns, so the loop inside `.taylor_cell_se()` runs one block per call.
  The `for` line and its body are still reached; "more than one block" is
  met by the caller (`variance/blk65`: 2 `.svy_recvar()` calls).
- **E-6 (minor, break-it).** Disabling rule 4 turns only one quiet-golden
  expectation and 5.1.8 red. `variance/nawt_out` and `variance/blk65_inf`
  did not fail, so on those fixtures the stacked and per-cell forms agree
  (or the non-finite column is the only live one in its block). Rule 4 is
  still guarded by `variance/tay_y1_inf` and 5.1.8.

## Hand-written additions (not dictated by the plan)

- `.variance_flush_se()` in `R/analysis-variance-helpers.R`: the flush runs
  at two sites (full block, final partial block), and a helper keeps the
  `NaN` override rule in one place (engineering preference 1). PR 5 needs
  the same rule with different locators; it can promote the helper to
  `R/analysis-helpers.R` when it adds the second caller file.
- The buffer is three parallel vectors (`buf_infl`, `buf_row`,
  `buf_override`); the spec names the entry contents, not the structure.
- The buffer push sits after the `acc_*` append, so the row position
  (`length(acc_se)`) exists before a flush writes to it.
- Comments: the section comment above `TAYLOR_SE_BLOCK`, the three helper
  header comments, the buffer comment and the final-flush comment in
  `get_variance()`, the updated `@param`/`@return` lines of the three cell
  functions, three header contents lines in `R/analysis-helpers.R`, and one
  in `R/analysis-variance-helpers.R`.
- In 4.6.3, the `if (is.null(w)) w <- character(0)` guard in place of
  `%||%`, for the one id with no recorded warnings.
- In 5.3.16, a three-line comment saying why the row exists.
