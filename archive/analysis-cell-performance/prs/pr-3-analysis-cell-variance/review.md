PASS

# Review — PR 3: `refactor/analysis-cell-variance`

**Reviewer**: opus, 2026-11-12, single reviewer under the D17 trial.
**Reviewed**: the uncommitted working tree on `refactor/analysis-cell-variance`
(base `5124100`), `git diff --ignore-cr-at-eol` plus the new untracked
`tests/testthat/_snaps/analysis-cell-equivalence.md`. Read: plan (§How to
read this plan, §Standard gates, PR 3 entry, §Row assignment, P-1), spec
§II.1 to §III.6, §VII, §X, §XI, test-spec rows of PR 3 and §8, decisions
D17 to D19, PR 1 review §Erratum text, `implementation.md`, the gate logs.

The code is correct and matches the spec. No result can move. The one
action before merge is the commit split that criterion 4 needs.

## Findings

**F-1 FIX-BEFORE-MERGE (shipping, criterion 4).** The tree is uncommitted,
so criterion 4 cannot be checked now. The check finds the first commit on
the branch that touches `tests/testthat/_snaps`. That commit must list no
path under `R/`, and `_snaps` must not change after it. Ship at least two
commits: tests and the snapshot file first, `R/` second. Then run the
criterion 4 commands on the branch before the PR opens. See E-4 below for
what the check proves and what it does not.

**F-2 NOTE (shipping, `code-style.md` §General R style).** "Reformat-only
commits stay separate from functional changes." Builder E-2 reformatted
two pre-existing spots: `R/analysis-variance-helpers.R:269-273` (the
`if (isTRUE(...))` in `.replicate_variance_cell()`) and the double blank
line after the contents list at `R/analysis-helpers.R:26`. The cleanest
history is three commits: tests and snapshot, then `style:` with the two
reformats, then the `refactor(analysis):` commit. The PR is squashed into
`develop`, so this affects the branch history only. Not blocking.

**F-3 NOTE (warning baseline, gate G item 2).** The plan, test-spec §8 and
`CLAUDE.md` all say 369. The gate log shows `[FAIL 0 | WARN 254 | SKIP 4 |
PASS 16665]`, and the leader states that `develop` gives 254 on this
machine. No artifact in the run directory records that 254 measurement on
the base commit. Record it (a line in `decisions.md`, or the PR 1 record)
with the commit and the installed-package difference, and quote both
numbers in the PR description. `implementation.md` line 101 also says "the
leader's full-suite count (369) settles it"; that should read 254.

**F-4 NOTE (test guard, found by break-it B2).** No test detects a removed
in-loop flush. With the full-block flush disabled, every column waits for
the final flush, `.taylor_cell_se()` splits it into blocks itself, and
every result, every snapshot and the criterion 6 call counts stay the same
(`variance/blk65` still gives 2 `.svy_recvar()` calls). The in-loop flush
exists only for memory (spec §III.3, D12). The only guard is gate 6: the
four lines inside the `if` at `R/analysis-variance.R:355-360` would go
uncovered. Keep gate 6's added-line check in PR 5, where
`get_covariance()` gets the same buffer. No change needed here.

**F-5 NOTE (`R/analysis-variance-helpers.R:127`).** `mats` is a required
argument that the function never reads (builder E-1). Spec §II.3 fixes the
signature, so this is correct as built.

**F-6 NOTE (helper placement).** `.variance_flush_se()` is used only by
`R/analysis-variance.R` but sits in `R/analysis-variance-helpers.R`. That
matches the existing family convention (every `get_variance()` helper is in
that file), so it is fine. The header contents list names it.

**F-7 NOTE (line length).** All added lines in `R/` are 80 characters or
fewer (the four section rules count as 80 characters; their byte length is
higher). The eight new `test_that()` titles exceed 80 columns. The plan
fixes those titles, and `air` does not wrap strings.

## Correctness check (results cannot move)

- **Finite path.** The old cell called `.svy_recvar()` on one column with
  `dimnames = list(NULL, y_col)` and returned `sqrt(max(0, v[1, 1]))`. The
  new path binds unnamed columns and returns `sqrt(pmax(0, diag(v)))`.
  Column names do not enter the arithmetic. Spec §III.3 records the
  column-wise exactness of the engine (R fact 4). The golden file passes
  2866 of 2866 at 1e-12 on the changed code (builder run; my B2 run on a
  build with an equal result set agrees).
- **Non-finite path.** `!all(is.finite(vals))` sends the whole block to the
  per-column form, which is the old call minus the column name. An `NA`
  base weight on a row outside every cell makes `u` `NA` on that row
  (`NA * 0`), so the block takes the per-column form, as spec §VII and §X.3
  state. An `NA` base weight inside a cell still errors in
  `.taylor_variance_cell()` at `n_d == 0L`, before any buffer (row 5.5.1).
- **Override.** The `na.rm = FALSE` override cell still joins the buffer,
  and the flush writes `NaN` to its row. The old order (SE first, then
  `NaN`) gives the same value. Its column is finite because `.score_variance()`
  leaves `NA` rows out of `active`.
- **Locators.** The push sits after the `acc_*` append, so
  `length(acc_se)` is the cell's own row. Early-return cells have no `infl`
  and keep their `NaN`. The twophase and nonprob SRS cells return no `infl`
  (checked by grep), so they never reach the buffer with `ctx$mats = NULL`.
- **Option read.** `lonely.psu` is read once into `ctx`. Nothing in the
  call sets it. `.joint_vcov()` keeps its own read at
  `R/analysis-helpers.R:1237`.
- **Context.** `.cell_context()` matches the §II.2 table, with
  `rep_finite = FALSE` as P-1 defers. The class hierarchy has
  `survey_twophase` as a child of `survey_base`, not of `survey_taylor`, so
  `taylor` is `FALSE` there. `rep_mat` is the same expression the cell used.
- **Empty and zero-cell calls.** An empty buffer is not flushed. A zero-cell
  call now builds `mats` once; `.build_cluster_matrices()` raises no
  condition (spec §II.5).
- **Callers.** `.variance_cell()` has one caller
  (`R/analysis-variance.R:303`). No test calls the three changed cell
  functions directly.

## Scope and gates

- Files changed are exactly the five of **Files touched**. `DESCRIPTION`
  shows no diff (the leader reverted the roxygen version bump). `NAMESPACE`,
  `man/` and `tests/testthat/fixtures/analysis-cell-golden.rds` show no
  diff. The only modified pre-existing test file is
  `test-analysis-cell-equivalence.R`, which PR 1 created, so gate 9's
  "no pre-PR-1 test file" clause holds.
- Snapshot file: five entries, the five the plan names (5.2.9, 5.3.4,
  5.3.10, 5.3.14, 5.3.16). The messages match the plan text ("Stratum 6
  has only one PSU at stage 1.").
- Gate logs: `Status: 1 NOTE` in both check logs; covr 96.63%. I
  intersected every added line under `R/` (from `git diff -U0`) with
  `added-line-coverage.log`: no added line is uncovered. The reformatted
  `if (` lines are covered.
- Criterion 6: the builder's trace counts (65/65 to 1/2, 64/64 to 1/1,
  0/0 to 0/0) match. I did not re-run them.
- Criterion 7: no `NAMESPACE` diff, so no export.

## Test-spec rows

| Row | Present | Asserts what the row says |
|---|---|---|
| 4.6.3 | Yes | `expect_null(attr(r, ".vcov"))` on the four ids; warnings asserted per D18 item 2 with `expect_warning_count()` |
| 5.1.8 | Yes | `expect_groups_match_domain("variance/tay_y1_inf", "tay", ...)` with `<std>`; no wrapper, quiet on the base per PR 1 erratum item 4 |
| 5.2.9 | Yes | dual, `surveycore_error_all_replicates_na` |
| 5.3.4 | Yes | dual, `surveycore_error_lonely_psu` via `calls$variance()` |
| 5.3.10 | Yes | dual, `surveycore_error_lonely_psu_unknown_option` |
| 5.3.14 | Yes | dual, `group = g65` under `"fail"` |
| 5.3.16 | Yes | dual, ungrouped `y1_na`, `na.rm = FALSE` under `"fail"` |
| 5.5.1 | Yes | `class = "simpleError"`, no snapshot; base class probed and recorded |

No `withCallingHandlers()`, `tryCatch()` or `suppressWarnings()` in a test.
No row id in a title. No new `test_invariants()` call.

## Erratum assessment

- **E-1 Agree.** Spec-mandated; keep it. A later spec revision could drop
  `mats` from `.taylor_variance_cell()` and `.covariance_pair_taylor()`
  together.
- **E-2 Agree** that gate 7 needs the reformat. Add the commit split of F-2.
- **E-3 Agree.** The body matches D18 item 2. The `if (is.null(w))` guard
  in place of `%||%` keeps R < 4.4 working (PR 1 F-4).
- **E-4 Agree in part.** Two commits are needed. The criterion 4 commands
  check separation, not order: they find the first commit that touches
  `_snaps`, check it has no `R/` path, and check `_snaps` is unchanged to
  `HEAD`. An `R/` commit placed before the snapshot commit also passes. So
  "the shipper must make tests and snapshot first" is task 2's requirement,
  not criterion 4's. Ship in task 2's order anyway: then the git history
  matches the claim that the snapshot was recorded on the unchanged code.
  The real proof of that claim is the builder's measurement (recorded on
  the base, byte-identical after).
- **E-5 Agree.** D15 settles it.
- **E-6 Agree.** Rule 4 is guarded by `variance/tay_y1_inf` in the quiet
  loop and by 5.1.8.

New errata: none against the plan or spec. F-3 is a record gap, not a plan
error.

## Break-it result

Each break was applied alone; only `test-analysis-cell-equivalence.R` was
run (`NOT_CRAN=true`, `devtools::load_all()`, `testthat::test_file()`).

| Break | Result |
|---|---|
| B1: flush writes SEs to `rev(buf_row)` (wrong row locator, both flush sites) | Red: variance quiet golden 32, variance noisy golden 3, 5.1.8 2. 37 of 2866 failed. |
| B2: in-loop flush disabled (`== TAYLOR_SE_BLOCK + 100000L`) | Green: 0 of 2866 failed. See F-4. |
| B3: `.cell_context()` stores `lonely.psu = "remove"` (line 1322 only) | Red: 5.3.4, 5.3.10, 5.3.14, 5.3.16 (2 each), variance quiet golden 2, 5.3.13 block 2. 12 failed. |

A first B3 attempt also changed `.joint_vcov()`'s read at line 1237 by a
too-wide `sed`; I discarded that run and repeated B3 on line 1322 alone.

Restore: the three `R/` files were copied back from a backup taken before
the breaks; md5 sums match the originals, and `git diff
--ignore-cr-at-eol` is byte-identical (`cmp`) to the diff saved before the
breaks. The B3 run rewrote the untracked snapshot file and dropped the four
failing entries; I restored it from the backup (md5 `c5d4dc34...` matches).
No `.new.md` [no such file] file is left. `git status` shows only the builder's changes.

## Blind tester comparison

- **What a blind tester would catch that I could not:** criterion 4. A
  tester runs on a committed branch and would run the `git log` check. I
  reviewed an uncommitted tree, so F-1 moves that check to the leader after
  the commits. Under the D17 trial nobody runs it unless the leader does.
- **What a blind tester would likely flag differently:** the warning
  count. Test-spec §8 says 369. A tester reading only the test-spec would
  see 254 and either BLOCK or stop to ask. I accepted the leader's
  254-baseline statement and asked for it to be recorded (F-3).
- **What I caught that a blind tester would not:** F-4 (the in-loop flush
  has no test guard, only coverage), found by break-it, which the old
  tester did not run. The correctness trace of the old and new SE paths
  (override order, row locators, `NA` weight routing, option read) needs
  `spec.md` and the base code, which the tester's brief excluded. F-2 (the
  reformat commit rule) needs `code-style.md` read against the builder's
  errata.
- **What neither checked:** optimized-BLAS behaviour of the stacked call at
  1e-12 (CI on Linux and macOS is the first test of that, as D19 showed
  for the NaN check).
