# Implementation — PR 7: `refactor/analysis-cell-totals`

**Builder**: opus, 2026-11-16. Branch `refactor/analysis-cell-totals` at
`282b4ca` (`develop` `c77c07d` plus the PR 6 `docs:` commit). Nothing is
committed. Base copy for comparisons: `git archive HEAD`.

## D28 extraction (do this commit first)

**Files, and only these:** `R/analysis-helpers.R`, `R/analysis-freqs.R`,
`R/analysis-means.R`. None of the three changes again after the extraction;
the copies taken after the extraction are byte-identical to the final tree.

**Final signature:** `.taylor_se_step(design, acc_joint, acc_se, ctx)`,
returning `list(se, v)`. The reviewer's proposal stands unchanged. The
three call sites (freqs, means, totals) need the same four inputs and the
same two outputs, so no argument was added or dropped:

```r
se_step <- .taylor_se_step(design, acc_joint, acc_se, ctx)
acc_se <- se_step$se
v_all <- se_step$v
```

- Off the Taylor route it returns `list(se = acc_se, v = NULL)`, which is
  what the old `v_all <- NULL; if (ctx$taylor) ...` gave.
- On the Taylor route the body is the old block unchanged: `.joint_vcov()`
  with `ctx$mats`, `live <- kinds == "infl"`, `.taylor_cell_se(..., v =
  v_all[live, live, drop = FALSE])`.
- Placed after `.variance_flush_se()`, with a comment block and a header
  "Contents" entry. The SE-step comment stays at each call site.

**Test results** (`NOT_CRAN=true`, `load_all()` + `test_file()`), base copy
against the tree after the extraction. Identical:

| File | Blocks | Expectations | Failed | Warnings |
|---|---|---|---|---|
| `test-analysis-cell-equivalence.R` | 51 | 2920 | 0 | 0 |
| `test-analysis-freqs.R` | 112 | 518 | 0 | 51 |
| `test-analysis-means.R` | 80 | 348 | 0 | 20 |

No new test row (D28).

## Files changed (whole PR)

| File | Change |
|---|---|
| `R/analysis-helpers.R` | D28: `.taylor_se_step()` and its header entry |
| `R/analysis-freqs.R` | D28: SE step replaced by the helper call |
| `R/analysis-means.R` | D28: SE step replaced by the helper call |
| `R/analysis-totals-helpers.R` | §II.3 signatures with defaults for `.taylor_total_cell()`, `.replicate_total_cell()`, `.total_cell()`; the two §III.7 comments |
| `R/analysis-totals.R` | `ctx <- .cell_context(design)` after step 5b, new `.total_cell()` call, SE step via `.taylor_se_step()`, `.attach_joint_vcov(..., v = v_all)` |
| `tests/testthat/test-analysis-cell-equivalence.R` | 7 new blocks under "get_totals() rows" |
| `tests/testthat/_snaps/analysis-cell-equivalence.md` | 3 new entries |

`DESCRIPTION` is not touched: I did not run `devtools::document()` (no
roxygen content changed; every edited comment is a plain `#` comment).
The `get_ratios()` call sites of `.total_cell()` (`R/analysis-ratios.R`
296 and 331, `R/analysis-ratios-helpers.R` 126) are untouched.

## What the totals change does

- `.taylor_total_cell(design, y_col, domain, mats = NULL, compute_se =
  TRUE)`: influence column and projection as before. `compute_se = TRUE`
  builds `mats` when `NULL` and runs its own `.svy_recvar()` (the
  `get_ratios()` path). `FALSE` returns `se = NA_real_`.
- `.replicate_total_cell(design, y_col, domain, rep_mat = NULL)`: takes
  `ctx$rep_mat`, or converts when `NULL`. The `%*%` product is unchanged.
- `.total_cell(..., mats = NULL, compute_se = TRUE, rep_mat = NULL)`:
  `mats`/`compute_se` to the Taylor cell, `rep_mat` to the replicate cell
  on both replicate classes; two-phase and nonprob SRS get neither.
- `get_totals()`: context built just before the loop, after the indicator
  columns of step 5b. SE step after the loop, before the small-cell warning.

## Tests added (rows)

All written and run on the unchanged totals code (after D28). All passed.
Base probe: neither 5.1 call (grouped or either ungrouped side) warns, so
no wrapper (D18).

| Row | Block |
|---|---|
| 5.1.5 | "get_totals() gives each clean group the SE of its own domain when another group has an NA and na.rm = FALSE" |
| 5.1.6 | the same, ", two-stage design with FPC" (`totals/multi_y1_na`, `multi`) |
| 5.2.8 | "get_totals() errors when every replicate weight is NA on a row outside the domain" — dual |
| 5.3.3 | "get_totals() errors on a single-PSU stratum when lonely.psu is fail" — dual |
| 5.3.9 | "... when lonely.psu is an unknown value" — dual |
| 5.5.4 | "get_totals() still errors on a calibrated design when x is NA and na.rm = FALSE" — `simpleError` |
| 5.5.6 | "grouped get_totals() still errors when a base weight is Inf" — `simpleError` |

Base-commit condition classes (scratch `tryCatch()`, base copy):

| Row | Class | Message |
|---|---|---|
| 5.2.8 | `surveycore_error_all_replicates_na` | "All replicates produced NA estimates." |
| 5.3.3 | `surveycore_error_lonely_psu` | "Stratum 6 has only one PSU at stage 1." |
| 5.3.9 | `surveycore_error_lonely_psu_unknown_option` | "Unknown `lonely.psu` value: "unknown_value"." |
| 5.5.4 | `simpleError` | "NA/NaN/Inf in foreign function call (arg 5)" |
| 5.5.6 | `simpleError` | "missing value where TRUE/FALSE needed" |

No row raised a warning on the base.

## Snapshot entries (3, additions only)

5.2.8 (`.svy_rep_var()`), 5.3.3 and 5.3.9 (`.svy_onestrat()`), messages as
above. After the `R/` change the snapshot file is byte-identical (`cmp`) to
the copy taken after task 2.

## Call counts (scratch, `trace()`, counters reset with `ls(all.names = TRUE)`)

`.build_cluster_matrices()` / `.svy_recvar()`:

| Scenario | Before | After |
|---|---|---|
| `totals/tay` | 4 / 4 | 1 / 1 |
| `totals/tay_ungrouped` | 2 / 2 | 1 / 1 |
| `totals/tay_categorical` | 16 / 16 | 1 / 1 |
| `totals/tay_popsize` | 4 / 4 | 1 / 1 |
| `totals/multi_y1_na` | 4 / 4 | 1 / 4 |
| `totals/tay_y1_inf` | 4 / 4 | 1 / 4 |
| `totals/rep` | 0 / 0 | 0 / 0 |
| `totals/rep_na` | 0 / 0 | 0 / 0 |
| `ratios/tay_ungrouped` | 4 / 4 | 4 / 4 |
| `quantiles/tay` | 9 / 9 | 9 / 9 |

Criterion 5 holds (`totals/tay` 1/1, `totals/rep` 0/0). The two non-finite
ids give 1 stacked call plus 3 per-column calls (rule 4). `get_ratios()`
counts do not move: it uses the defaults.

## Test runs

Equivalence file, `NOT_CRAN=true`:

| Code | Blocks | Expectations | Failed | Warnings |
|---|---|---|---|---|
| base totals + new blocks, 1st run | 58 | 2939 | 0 | 3 (snapshot notices) |
| base totals + new blocks, 2nd run | 58 | 2936 | 0 | 0 |
| changed | 58 | 2936 | 0 | 0 |

`test-analysis-totals.R` 79/453/0 failed/17 warnings and
`test-analysis-ratios.R` 79/378/0/21 on base and changed. Fifteen more files
that call `get_totals()`/`get_ratios()` (coef-vcov, calibration,
collection-if-missing-var-rename, constructors, conversion,
labelled-analysis, labelled-storage, nonprob-bootstrap-variance,
survey-collection-dispatch, variance-replicate, variance-srs,
variance-taylor, variance-twophase, analysis-quantiles, edge-conditions):
the summary lines are byte-identical on base and changed (0 failures).

Extra check: all 170 `totals/`, `ratios/`, `freqs/`, `means/`,
`quantiles/`, `effn/` golden scenarios run on base and changed, value and
warning classes saved: 170 of 170 `identical()`.

The full suite was not run (leader's gate; D21 baseline 254).

## Break-it check

Each break applied alone, the equivalence file run, then restored from the
byte copy. After the last restore `cmp` passes for all five `R/` files, the
test file and the snapshot file, and `git diff --stat` equals
`git diff --ignore-cr-at-eol --stat` (7 files, 285+/65-).

| Break | Result |
|---|---|
| B1 `.taylor_se_step()` returns `se * (1 + 1e-9)` | RED, 81 failures: freqs, means, totals quiet and noisy golden blocks, and quantiles/effn |
| B2 `get_totals()` sets the `.vcov` diagonal to `se^2` (removes the kept rescaled diagonal) | RED, 3 failures, totals quiet golden block |
| B3 `.taylor_se_step()` reads every live SE from the stacked diagonal (no finite check) | RED, 21 failures: means and totals quiet golden, 5.1.1 to 5.1.4, 5.1.10, 5.1.5, 5.1.6. Freqs stays green: no freqs input is non-finite (§IV, PR 4 E-4) |
| B4 `get_totals()` passes `compute_se = TRUE` | GREEN; counts show `totals/tay` 1 / 4. See E-3 |
| B5 SE step removed from `get_totals()` | RED, 31 failures: totals quiet and noisy golden, and "a call that errors under lonely.psu fail raises no small-cell warning". 5.3.3 and 5.3.9 stay green: the abort then fires in `.attach_joint_vcov()` (same as PR 6 B6) |

## Errata

- **E-1 (D28 file list).** The leader's `refactor` commit for the
  extraction is `R/analysis-helpers.R`, `R/analysis-freqs.R`,
  `R/analysis-means.R`. The last two are outside plan PR 7 Files touched;
  D28 adds them.
- **E-2 (second callers).** No other helper gained a second call site in
  another file. `.taylor_se_step()` was created in the shared file.
- **E-3 (D23 family).** B4 stays green: a `get_totals()` that keeps each
  cell's own variance call gives the same results, because the SE step
  overwrites the SE. Only the call counts guard it. Gate 6 does not:
  `get_ratios()` reaches the `compute_se = TRUE` branch. Same shape as
  PR 6 E-3.
- **E-4 (title length).** All seven new titles pass 80 columns; the plan
  fixes them. `air` passes.
- **E-5 (air).** All five changed `.R` files and the test file were
  `air`-clean on the base and pass `air format --check` now. No base-file
  air failure.
- **E-6 (commit order).** I did not commit. Suggested order: D28
  `refactor` (3 files), then tests and `_snaps/`, then
  `R/analysis-totals.R` and `R/analysis-totals-helpers.R`.
- **E-7 (pre-existing doc error).** The `.total_cell()` `@return` line on
  the base said "df (Taylor path only)". No total cell returns `df`. I
  corrected it with the new `@param` lines (comment only).
- Rows 5.5.4 and 5.5.6 raise `simpleError` on the base commit; the PR
  description quotes it (table above).

## Hand-written additions (not dictated by the plan)

- In `.taylor_total_cell()` the projection now runs before the optional
  `mats` build (as PR 6 did for means). The base built `mats` first; the
  build reads only design columns, so no result or condition moves (170 of
  170 `identical()`).
- Comments: the call-context comment in `get_totals()` (says why the
  context sits after step 5b), the SE-step and `.attach_joint_vcov()`
  comments (text as in freqs and means), the `@param` lines of the three
  changed helpers, a two-caller note on `.total_cell()`, and the
  `qr.resid()` comment in 5.5.4.
