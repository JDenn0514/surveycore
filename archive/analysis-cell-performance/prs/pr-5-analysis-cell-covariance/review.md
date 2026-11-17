PASS

# Review — PR 5: `refactor/analysis-cell-covariance`

Reviewer: opus, 2026-11-13. Diff: `git diff origin/develop...HEAD` at
`fe0f56e` (4 commits: `docs:` PR 4 bookkeeping, `test(analysis)`, the
leader's helper move, `refactor(analysis)`). No FIX-BEFORE-MERGE finding.

## Tasks and acceptance criteria

| Item | Result | Evidence |
|---|---|---|
| Task 1, seven blocks | Present, titles and calls as the plan writes them | `tests/testthat/test-analysis-cell-equivalence.R:459-593` |
| Task 2, tests before `R/` | Met | `7333306` holds only the test file and `_snaps/`; `git diff 7333306 HEAD -- tests/` is empty |
| Task 3 / criterion 5, call counts | Met | implementation.md: blk65 1/2, blk64 1/1, rep_na 0/0 after; 65/65, 64/64, 0/0 before |
| Task 4, §VIII, §II.3, §III.3, §III.4 | Met | see "Results cannot move" |
| Criterion 1 (5.1.9) | Met, wrapped for 2 x `cv_undefined` per D18 | `:459` |
| Criterion 2 (5.2.10, 5.5.2) | Met; 5.5.2 is `simpleError` on the base commit (implementation.md probe) | `:482`, `:579` |
| Criterion 3 (5.3.5, 5.3.11, 5.3.15, 5.3.17) | Met, dual | `:507-577` |
| Criterion 4, snapshots | Five entries, additions only, the five the plan names (5.2.10, 5.3.5, 5.3.11, 5.3.15, 5.3.17); unchanged after the `R/` commit | `_snaps/analysis-cell-equivalence.md:78-119` |
| Criterion 6, goldens | Equivalence file 41 blocks, 2893 expectations, 0 failed, 0 warnings (my run on HEAD) | |
| Criterion 7 / G | See below | |

G, item by item: tests `[FAIL 0 | WARN 254 | SKIP 4 | PASS 16692]`, which
is the D21 baseline of 254; `R CMD check` `Status: 1 NOTE`, the CRAN
incoming note (gate-5-00check.log:14, :82); covr 96.65%. I compared the
gate-7 `UNCOVERED_LINE` list with `git diff -U0 origin/develop...HEAD -- R`:
no added line is uncovered (the uncovered lines in the changed files are
early returns, `next` lines in step 11 and an unchanged `cli_abort()`).
`air format --check` passes on all five changed `.R` files (my run). No
pre-PR-1 test file is modified; the fixture `.rds` is not in the diff; no
`.surveycore-workspace/` path. I re-ran `test-analysis-covariance.R` on
HEAD: 69 blocks, 0 failed, 5 warnings, the builder's figures.

Gate 9 lists five paths outside Files touched: the three `plans/` files of
the leader's `docs:` commit (same precedent as D22) and the two files of the
helper move (judged below).

## Results cannot move

I compared old and new `get_covariance()` and the three pair helpers line by
line.

- Pair ordering: `needed_keys`, the combo loop and the fill loop are
  unchanged. The buffer is filled in loop order and each SE goes back by
  its `(ci_idx, key)` locator, so the block layout decides nothing.
- SE value: the old pair ran `.svy_recvar()` on one column and took
  `sqrt(max(0, v[1, 1]))`. The new flush goes through `.taylor_cell_se()`:
  a block with any non-finite value runs each column alone with the same
  formula; a finite block takes `sqrt(pmax(0, diag(v)))`, equal to the
  one-column value for finite columns (PR 3). `lonely.psu` is read once in
  `.cell_context()`, same option and default.
- NA/NaN: early returns (n_d = 0, n_d < 2) still return `se = NaN` and no
  `infl`, so they stay out of the buffer (`R/analysis-covariance-helpers.R:213-235`).
- Override: the pair is stored with `se = NaN`, then the flush rewrites it
  through `.variance_flush_se()`, which sets `NaN` where the flag is TRUE.
  The override cell still joins the stacked call, so under `"fail"` it can
  abort (row 5.3.17, builder B1).
- Two combinations in one block: the in-loop flush writes to
  `pair_results_this` for the current combination and to
  `all_pair_results` for an earlier one (`R/analysis-covariance.R:442-448`).
  The push comes after `pair_results_this[[key]] <- res`, so the write is
  not lost. The final flush runs after the loop, when every combination is
  stored, and writes only to `all_pair_results` (`:474-481`).
- Moved abort (D6) and condition order: the final flush runs before step 11.
  `cv_undefined` comes from `.add_variance_cols()` in step 16, so it cannot
  fire before the abort. The four lonely-PSU snapshots show no warning, and
  the equivalence file reports 0 warnings. The per-pair warnings and the
  small-cell warning are collected in the loop and raised after the flush,
  as before. No cell on the Taylor route raises a condition inside the loop,
  so D9 adds no new case beyond the `NA` base-weight error of §X.1.
- Replicate path: `rep_mat` comes from `ctx$rep_mat`, the same
  `as.matrix(data[, repweights, drop = FALSE])` the pair used to build;
  `ctx$replicate` covers nonprob with replicate weights. Two-phase and
  nonprob SRS pairs are unchanged.
- No `.vcov` is attached, as §VIII says (row 4.6.3 stays green).

## Findings

- **NOTE N-1, `R/analysis-covariance.R:441`.** No test sees the override
  flag at the in-loop flush. Break K5 below passed `buf_override & FALSE`
  there and the equivalence file stayed green: no covariance scenario puts
  an `na.rm = FALSE` override pair into a full block of 64 (only
  `covariance/tay_narm_false`, 3 variables x few groups, uses
  `na.rm = FALSE`). The rule lives in `.variance_flush_se()`, which the
  final flush reaches (builder B5), so only the argument at this one call
  is unguarded. Same family as D23 and E-3. The fixture is pinned, so a new
  golden scenario is a HOLD. An inline block would close it without the
  fixture, for example `get_covariance(d, c(y1_na, y2), group = g65,
  na.rm = FALSE, ...)` on `tay` checked against per-group domain calls.
  Leader's choice: add it in PR 5, carry it with D23, or accept it.
- **NOTE N-2, `R/analysis-covariance.R:412`.** Removing `res$infl <-
  NULL` stays green (break K4). The fill loop reads named fields only, so
  the line affects memory, not results. §VIII requires it; it is there.
- **NOTE N-3, `R/analysis-covariance-helpers.R:199`.** `mats` is required
  and not read (E-1). As spec §II.3 writes it.
- **NOTE N-4.** Six of seven new titles exceed 80 columns (E-5). The plan
  fixes the titles; `air` passes.

## The leader's move of `.variance_flush_se()`

Correct and complete.

- The body is byte-identical: I extracted the function from
  `origin/develop:R/analysis-variance-helpers.R` and from
  `R/analysis-helpers.R:1420-1424`; `cmp` reports no difference.
- The header comment now names both callers; the `@param` and `@return`
  lines are unchanged. Both file-header indexes are updated
  (`R/analysis-helpers.R:29`, the line removed from
  `R/analysis-variance-helpers.R`). The pointer comment at
  `R/analysis-covariance.R:375` names the new file.
- No stale reference: `grep` for `variance_flush_se` and for "get_variance()'s
  Taylor buffer" in `R/`, `tests/` and `plans/` finds only the definition,
  the index line, the two callers in `R/analysis-variance.R` and the two in
  `R/analysis-covariance.R`. No test calls the helper directly.
- The name still says "variance" while it serves two functions. A rename
  (E-2 suggested `.taylor_flush_se()`) is cosmetic; not worth more churn.

Gate 9 exception: accept it. `code-style.md` §Internal helpers says the
helper moves in the same PR that adds the second call site, and the other
options are worse: deferring leaves a rule breach on `develop`, and a copy
duplicates the override rule (engineering preference 1). The move is 20
lines, a separate commit, and changes no behaviour. Record it as a leader
edit in the decisions log, as D22 did for the `docs:` commit.

## Errata E-1 to E-5

- E-1: agree. Same shape as PR 3 and PR 4 E-1.
- E-2: agree; the leader resolved it with the move above.
- E-3: agree, and I confirmed the wider gap (N-1). B4 green and K5 green
  both mean the in-loop flush is guarded by coverage only.
- E-4: agree. The commit split meets task 2.
- E-5: agree (N-4).

## Break-it results

Each break applied alone to `R/analysis-covariance.R`, the equivalence file
run (`devtools::load_all()` + `testthat::test_file()`), then restored with
`git checkout --`.

| Break | Target | Result |
|---|---|---|
| K1 | In-loop flush always writes to `all_pair_results` (current combination's SE lost) | RED: covariance noisy golden, 4 |
| K2 | Final flush writes every SE to the last combination, not `buf_ci[[b]]` | RED: noisy golden 35, row 5.1.9 1 |
| K3 | Final flush moved after the small-cell warning (step 12) | RED: "a call that errors under lonely.psu fail raises no small-cell warning", 1 |
| K4 | `res$infl <- NULL` removed | GREEN (N-2: memory only) |
| K5 | In-loop flush ignores the override flag | GREEN (N-1) |

After the last restore, on HEAD: equivalence file 41 blocks, 2893
expectations, 0 failed, 0 warnings; `test-analysis-covariance.R` 69 blocks,
0 failed, 5 warnings. `git status --short` shows only the untracked
`plans/proposal-slim-pipeline.md`; `git diff --stat` is empty.

## Blind tester comparison

A tester reading only `test-spec.md` would have checked the seven rows, the
five snapshot entries and the gates. All of these hold, so it would have
passed the PR, as I do. It would not have found N-1: no row asks for an
override pair in a full in-loop block, and the gap shows only to a break at
that call. It would not have judged the helper move or the gate 9
exception, which need the plan and `code-style.md`. Nothing here is a
finding a tester would have caught and I missed.
