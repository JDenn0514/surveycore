# Implementation — PR 8: `refactor/analysis-cell-ratios`

**Builder**: opus, 2026-11-16. Branch `refactor/analysis-cell-ratios` at
`d520a7e` (`develop` `1d78525` plus the PR 7 `docs:` commit). Nothing is
committed. Base copy (`git archive HEAD R tests`): `base/` in this
directory. Snapshot and test file after task 2: `after-tests/`. Final
`R/` files: `changed/`.

## Files changed

| File | Change |
|---|---|
| `R/analysis-ratios.R` | `ctx <- .cell_context(design)` before the loop; calls 1 and 2 pass `mats`, `compute_se = TRUE`, `rep_mat`; call 3 passes `rep_mat` or `mats` and `compute_se = !ctx$taylor`; `acc_infl` and `acc_total_x`; the Taylor SE step after the loop; `.attach_joint_vcov(..., v = v_all)`; `is_replicate` removed (now `ctx$replicate`) |
| `R/analysis-ratios-helpers.R` | `.replicate_ratio_cell(..., rep_mat)` and `.delta_ratio_cell(..., mats, compute_se)`, no defaults; comments |
| `tests/testthat/test-analysis-cell-equivalence.R` | 7 new blocks under "get_ratios() rows" |
| `tests/testthat/_snaps/analysis-cell-equivalence.md` | 4 new entries |

`DESCRIPTION` not touched; `devtools::document()` not run (no roxygen
content changed; both helpers are `#'  @noRd` with plain `#` comments).

## What the change does

- **Context.** Built once, after the accumulators and before the loop
  (`R/analysis-ratios.R:272`).
- **Calls 1 and 2.** `.total_cell(..., mats = ctx$mats, compute_se = TRUE,
  rep_mat = ctx$rep_mat)`. They keep their own variance call (spec §IX).
- **Call 3.** Replicate route (both replicate classes, `ctx$replicate`):
  `.replicate_ratio_cell(..., rep_mat = ctx$rep_mat)`; the cell no longer
  converts the replicate columns. Other routes: `.delta_ratio_cell(...,
  mats = ctx$mats, compute_se = !ctx$taylor)`. On the Taylor route that is
  `mats = ctx$mats, compute_se = FALSE`; on nonprob SRS and two-phase it is
  `mats = NULL` (`ctx$mats` is `NULL` there), `compute_se = TRUE`.
- **`.delta_ratio_cell()` with `compute_se = FALSE`** returns `se =
  NA_real_`, `infl` = the unscaled `z` column after projection, and a joint
  element with kind `"infl"`, scaled `est` and `value = NULL` (set with
  `joint["value"] <- list(NULL)` so the element keeps its name and order).
  With `TRUE` it returns as before plus `infl = NULL`.
- **SE step** (`R/analysis-ratios.R:400-424`), Taylor route only, before the
  small-cell warning: `live` = cells with a non-`NULL` `acc_infl` entry;
  blocks of at most `TAYLOR_SE_BLOCK`; per block `acc_se[blk] <-
  .taylor_cell_se(vals, ctx$mats, ctx$lonely.psu) / abs(acc_total_x[blk])`,
  then per cell `acc_joint[[j]]$value <- acc_infl[[j]] / acc_total_x[[j]]`
  and `acc_infl[j] <- list(NULL)`. After the last block, `v_all <-
  .joint_vcov(design, acc_joint, mats = ctx$mats)`. Off the Taylor route
  `v_all` stays `NULL` and `.attach_joint_vcov()` computes as before.

## Tests added (rows)

Written and run on the unchanged code. All passed. Base probe: no call in
the 7 blocks warns (5.1.7 grouped and both ungrouped sides included), so no
`expect_warning()` wrapper (D18).

| Row | Block | Pattern |
|---|---|---|
| 5.1.7 | "get_ratios() gives each clean group the SE of its own domain when another group's numerator is NA" | `expect_groups_match_domain()` |
| 5.2.6 | "get_ratios() errors when the numerator is NA in a cell with na.rm = FALSE on a replicate design" | dual |
| 5.3.6 | "get_ratios() errors on a single-PSU stratum when lonely.psu is fail" | dual |
| 5.3.12 | "get_ratios() errors on a single-PSU stratum when lonely.psu is an unknown value" | dual |
| 5.7.1 | "get_ratios() errors when a group's denominator total is zero" | dual |
| 5.5.7 | "grouped get_ratios() still errors when a base weight is Inf" | `simpleError` |
| 5.5.9 | "get_ratios() still errors on a calibrated design when either variable is NA and na.rm = FALSE" | two `simpleError` calls |

## Base-commit condition classes and messages

| Row | Class | Message |
|---|---|---|
| 5.2.6 | `surveycore_error_all_replicates_na` | "All replicates produced NA estimates." (from `.svy_rep_var()`) |
| 5.3.6 | `surveycore_error_lonely_psu` | "Stratum 6 has only one PSU at stage 1." |
| 5.3.12 | `surveycore_error_lonely_psu_unknown_option` | "Unknown `lonely.psu` value: "unknown_value"." |
| 5.7.1 | `surveycore_error_ratio_zero_denominator` | "All values of the denominator (y1_c_zero) are zero. Cannot compute ratio." plus the "i" bullet |
| 5.5.7 | `simpleError` | "missing value where TRUE/FALSE needed" |
| 5.5.9 numerator call | `simpleError` | "NA/NaN/Inf in foreign function call (arg 5)" |
| 5.5.9 denominator call | `simpleError` | "NA/NaN/Inf in foreign function call (arg 5)" |

5.5.9 location, checked with a `.total_cell()` trace on the base: the
numerator call aborts in group B's call 2 (`y_col = y3_na`), the
denominator call in group B's call 1 (`y_col = y1_na`), both inside
`.taylor_total_cell()`. This matches spec §IX. All classes are the same
after the change (the `identical()` capture below includes these calls).

## Snapshot entries (4, additions only)

5.2.6 (`.svy_rep_var()`), 5.3.6 and 5.3.12 (`.svy_onestrat()`), 5.7.1
(`get_ratios()`). First run: 4 snapshot notices; second run: none. After
the `R/` change the snapshot file is byte-identical (`cmp`) to
`after-tests/analysis-cell-equivalence.md` [not archived].

## Call counts (scratch `trace()`, `.build_cluster_matrices()` / `.svy_recvar()`)

| Scenario | Before | After |
|---|---|---|
| `ratios/tay_ungrouped` | 4 / 4 | **1 / 4** |
| `ratios/blk65` | 196 / 196 | **1 / 133** |
| `ratios/rep_na` | 0 / 0 | **0 / 0** |
| `ratios/tay` (and the other 3-cell Taylor ids, `cal`, `multi`, ...) | 10 / 10 | 1 / 8 |
| `ratios/gss` | 16 / 16 | 1 / 12 |
| `ratios/tay_num_na`, `multi_num_na`, `tay_c_zero_den` | 10 / 10 | 1 / 10 |
| `ratios/tay_den_na` | 8 / 8 | 1 / 7 |
| `ratios/blk16` / `blk17` / `blk32` / `blk33` / `blk64` | 49 / 52 / 97 / 100 / 193 | 1 / 34, 1 / 36, 1 / 66, 1 / 68, 1 / 130 |
| `ratios/blk65_na` | 196 / 196 | 1 / 133 |
| `ratios/tay_empty_dom`, `tay_allna`, `zero_combos` | 0 / 0 | 1 / 0 (see E-4) |
| `ratios/tph`, `tph_dom` | 0 / 9 | 0 / 9 |
| `ratios/rep`, `np_rep`, `np_srs`, `*_dom` replicate | 0 / 0 | 0 / 0 |
| `totals/tay`, `totals/tay_ungrouped` | 1 / 1 | 1 / 1 |
| `totals/tay_y1_inf`, `means/tay_y1_na` | 1 / 4 | 1 / 4 |
| `means/tay`, `freqs/tay` | 1 / 1 | 1 / 1 |
| `quantiles/tay` | 9 / 9 | 9 / 9 |

Criterion 5 holds: 1 and 4 (1 + 1 + 1 + 1), 1 and 133 (65 + 65 + 2 + 1),
0 and 0. Full lists: scratchpad `counts-before.txt`, `counts-after.txt`.

## Test runs (`NOT_CRAN=true`, `load_all()` + `test_file()`)

Equivalence file:

| Code | Blocks | Expectations | Failed | Warnings |
|---|---|---|---|---|
| base + new blocks, 1st run | 65 | 2955 | 0 | 4 (snapshot notices) |
| base + new blocks, 2nd run | 65 | 2951 | 0 | 0 |
| changed | 65 | 2951 | 0 | 0 |

Fifteen more files that call `get_ratios()` or `get_totals()`, base and
changed: the summary lines (blocks, expectations, failed, skipped,
warnings, errors) are identical (`diff` empty), 0 failures.
`test-analysis-ratios.R` 79 / 378 / 0 failed / 21 warnings;
`test-analysis-totals.R` 79 / 453 / 0 / 17; also coef-vcov, calibration,
collection-if-missing-var-rename, constructors, conversion,
labelled-analysis, labelled-storage, nonprob-bootstrap-variance,
survey-collection-dispatch, variance-replicate, variance-srs,
variance-taylor, variance-twophase.

The full suite and `devtools::check()` were not run (leader's gates).

## identical() comparison

Every golden scenario under `ratios/` (42), `totals/`, `means/`, `freqs/`,
`quantiles/`, `effn/`, plus 10 extra `get_ratios()` calls (the five error
calls of this PR and the `lonely` design under `fail`, `unknown_value`,
`remove`, `adjust`, `average`): value (the result with all attributes,
`.vcov` included, or the error class and message) and warning classes in
order. Base and changed: **180 of 180 `identical()`**. `ratios/np_srs` keeps
its 3 `surveycore_warning_nonprob_srs_fallback` warnings.

## Break-it checks

Each applied alone to `R/analysis-ratios.R`, the equivalence file run, the
counts taken, then restored from `changed/`. After the last restore `cmp`
passes for both `R/` files and the snapshot file.

| Break | Result | blk65 counts |
|---|---|---|
| a. SE not divided by `abs(total_x)` | RED, 30 failures (ratios quiet and noisy golden) | 1 / 133 |
| b. `acc_infl[[j]] <- NULL` in place of `acc_infl[j] <- list(NULL)` | RED, 4 blocks error (ratios quiet and noisy golden, NA-marker Taylor, 5.1.7) | 1 / 131 |
| c1. Block end off by one (`- 2L`): each block skips its last cell | RED, 1 block errors (ratios noisy golden, which holds the `blk*` ids) | 1 / 133 |
| c2. Block indices shifted by one, so each block reads the next cell's column | RED, 15 failures and 2 errors (ratios quiet and noisy golden, 5.1.7) | 1 / 131 |
| c3. Block size 1 (one `.svy_recvar()` per cell) | GREEN | 1 / 196 |
| d. Call 3 keeps `compute_se = TRUE` | GREEN | 1 / 196 |
| e. `acc_infl[j] <- list(NULL)` removed (no column dropped) | GREEN | 1 / 133 |

c3 and d are D23-family: the results are the same, and only the call
counts (and, for d, gate 6 coverage, since the `compute_se = FALSE` branch
of `.delta_ratio_cell()` goes unreached) catch them. e changes memory only;
nothing catches it. See E-5.

## Criterion 7: lines with no caller left

Static reading of every call site in `R/` and `tests/testthat/` (no test
calls these helpers directly with the defaults; the only direct call is
`.total_cell(list(fake = TRUE), ...)`, which errors before any branch). The
counts above confirm the two build lines: no golden id builds the matrices
more than once. The leader's gate 6 `zero_coverage` run is the authority.

| File:line | Branch |
|---|---|
| `R/analysis-helpers.R:1245` | `.joint_vcov()`, `mats = NULL` build branch: `mats <- .build_cluster_matrices(design@data, design@variables)`. Every Taylor caller now passes `mats = ctx$mats` (`.taylor_se_step()` `:1455`, `get_ratios()` `R/analysis-ratios.R:423`); `.attach_joint_vcov()` `:1294` calls it with no `mats` only when `v` is `NULL`, which is off the Taylor route. |
| `R/analysis-totals-helpers.R:79` | `.taylor_total_cell()`, `mats = NULL` branch under `compute_se = TRUE`: `mats <- .build_cluster_matrices(data, vars)`. |
| `R/analysis-totals-helpers.R:156` | `.replicate_total_cell()`, `rep_mat = NULL` branch: `rep_mat <- as.matrix(data[, vars$repweights, drop = FALSE])`. |

The `if (is.null(...))` condition lines (`R/analysis-helpers.R:1244`,
`R/analysis-totals-helpers.R:78`, `:155`) are still evaluated, so they stay
covered. No signature changed. No line this PR adds should be unreached:
the SE step runs on every Taylor golden id with a live cell, `blk65` runs
two blocks (D15), and the `compute_se = TRUE` branch of
`.delta_ratio_cell()` runs on `ratios/tph` and `ratios/np_srs`.

## air

`R/analysis-ratios.R`, `R/analysis-ratios-helpers.R` and the test file were
`air`-clean on the base and pass `air format --check` now. `git diff --stat`
equals `git diff --ignore-cr-at-eol --stat`.

## Errata

- **E-1 (DRY, `.taylor_se_step()`).** Not shared; `.taylor_se_step()` and
  its three callers are unchanged. The two steps share only their two
  calls, `.joint_vcov(..., mats = ctx$mats)` and `.taylor_cell_se()`, and
  both are already helpers. They differ in four ways the spec fixes:
  - the ratio step passes no `v` and runs in caller blocks (§III.3 row 2);
  - it divides each SE by `abs(total_x)`;
  - it writes the scaled column into `joint$value` and drops the unscaled
    one, per block, for memory;
  - `.vcov` comes after the SEs, on the scaled columns, not before.
  A shared helper would need a mode flag for all four, and the per-block
  drop must run in `get_ratios()`'s frame: a helper that receives
  `acc_infl` holds a second reference to every column, so the memory the
  drop saves is not freed until the helper returns. So the step stays
  inline in `get_ratios()`.
- **E-2 (`is_replicate`).** `get_ratios()` kept its own copy of the
  replicate-route predicate, the same expression as `ctx$replicate` in
  `.cell_context()`. I removed it and dispatch on `ctx$replicate`. Same
  definition, so no result moves (180 of 180 `identical()`).
- **E-3 (spec wording, call 3 on nonprob SRS and two-phase).** The plan
  writes `mats = NULL, compute_se = TRUE` there. The code passes
  `mats = ctx$mats, compute_se = !ctx$taylor`: `ctx$mats` is `NULL` off the
  Taylor route, so the values are the ones the plan names, with one call
  site instead of two branches.
- **E-4 (context built for calls with no live cell).** `.cell_context()`
  runs before the loop, so `ratios/tay_empty_dom`, `tay_allna` and
  `zero_combos` now build the cluster matrices once where the base built
  them zero times. Speed only, one build per call; `get_totals()` and
  `get_means()` do the same since PRs 6 and 7. Criterion 5 does not name
  these ids.
- **E-5 (D23 family).** Breaks c3 (block size 1) and d (call 3 keeps its
  own variance call) stay green: only the call counts catch them, and d
  also leaves the `compute_se = FALSE` branch uncovered for gate 6. Break e
  (unscaled column never dropped) changes memory only and nothing catches
  it. Same shape as PR 6 E-3 and PR 7 E-3.
- **E-6 (title length).** All seven new titles pass 80 columns; the plan
  fixes them. `air` passes.
- **E-7 (live set).** The spec defines `live` as "the cells that reached
  call 3". The code takes it as the cells with a non-`NULL` `acc_infl`
  entry. On the Taylor route these are the same set: a cell that reaches
  call 3 has a non-`NA` `total_x`, so its `z` total runs on the same
  non-empty, positive-weight domain and returns kind `"infl"`.
- Rows 5.5.7 and 5.5.9 raise `simpleError` on the base commit; the PR
  description quotes the classes (table above).

## Hand-written additions (not dictated by the plan)

- E-2: `is_replicate` replaced by `ctx$replicate`.
- `joint["value"] <- list(NULL)` in `.delta_ratio_cell()` (keeps the
  element, as `.joint_na()` does), and `infl = NULL` in the return on the
  `compute_se = TRUE` route.
- Comments: the context comment, the calls 1 and 2 comment, the call 3
  dispatch comment, the `acc_infl` comment, the SE-step comment (says why
  `acc_infl[j] <- list(NULL)`), the `.attach_joint_vcov()` comment, the
  `@param` and `@return` lines of both cell helpers, and a sentence in the
  `.delta_ratio_cell()` header. The 5.5.9 block carries a comment naming
  the call that aborts.

## Suggested commit order

1. `test(analysis)`: `tests/testthat/test-analysis-cell-equivalence.R` and
   `tests/testthat/_snaps/analysis-cell-equivalence.md` (byte-identical to
   `after-tests/`).
2. `refactor(analysis)`: `R/analysis-ratios.R` and
   `R/analysis-ratios-helpers.R`.
