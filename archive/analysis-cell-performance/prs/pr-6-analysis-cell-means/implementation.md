# Implementation — PR 6: `refactor/analysis-cell-means`

**Builder**: opus, 2026-11-13. Branch `refactor/analysis-cell-means` at
`7179af4` (base for `R/`: `develop` `a047d4d` plus the PR 5 `docs:` commit).
Nothing is committed.

## Files changed

| File | Change |
|---|---|
| `R/analysis-means.R` | `get_means()`: call context, new `.mean_cell()` call, Taylor SE step after the loop, `.attach_joint_vcov(..., v = v_all)` |
| `R/analysis-means-helpers.R` | New signatures of `.taylor_mean_cell()`, `.replicate_mean_cell()`, `.mean_cell()`; df rules; one `crossprod()`; stale §III.7 comment corrected |
| `R/analysis-helpers.R` | Comment at `.degf_taylor()` (task 5); no code change |
| `tests/testthat/test-analysis-cell-equivalence.R` | 10 new blocks under a new "get_means() rows" section |
| `tests/testthat/_snaps/analysis-cell-equivalence.md` | 3 new entries |
| `DESCRIPTION` | `Config/roxygen2/version` 8.1.0 to 8.1.1 from my `devtools::document()` check. Left in the tree per D26 (own `chore:` commit) |

`man/` and `NAMESPACE` do not change (`devtools::document()` run, no diff).
All three `.R` files were `air`-clean on the base and pass
`air format --check` now, as does the test file. No line-ending change:
`git diff --stat` and `git diff --ignore-cr-at-eol --stat` agree.

## What each change does

- `.taylor_mean_cell(design, y_col, domain, mats = NULL, compute_se = TRUE)`:
  the projection and the influence column run as before. With
  `compute_se = TRUE` (the `get_quantiles()` call) it builds `mats` when
  `NULL`, reads the option and runs its own `.svy_recvar()`, as today. With
  `FALSE` it returns `se = NA_real_` and no variance call. Cell df:
  calibrated design only, `.degf_taylor(data[domain > 0, c(vars$ids[1L],
  vars$strata), drop = FALSE], vars)`, then the rank reduction and the
  zero-df warning, as today. An uncalibrated design skips `.degf_taylor()`
  and the returned list has no `df` element. With `compute_se = TRUE` the
  zero-df warning still follows the variance call, as on the base.
- `.replicate_mean_cell(design, y_col, domain, rep_mat = NULL)`: `rep_mat`
  from the context, or converted when `NULL`. The two products became
  `crossprod(rep_mat, cbind(domain, y_safe * domain))`; column 1 is
  `rep_N_d`, column 2 `rep_Y`, both through `as.numeric()` so they carry no
  names (as the base `%*%` results did not).
- `.mean_cell(design, y_col, domain, mats = NULL, compute_se = TRUE,
  rep_mat = NULL)`: `mats` and `compute_se` to the Taylor cell; `rep_mat` to
  the replicate cell on both replicate classes; two-phase and nonprob SRS
  cells get neither. The `get_quantiles()` call is untouched.
- `get_means()`: `ctx <- .cell_context(design)` just before the loop. After
  the loop and before the small-cell warning, on the Taylor route:
  `v_all <- .joint_vcov(design, acc_joint, mats = ctx$mats)`, then
  `.taylor_cell_se(vals, ctx$mats, ctx$lonely.psu, v = v_all[live, live])`
  for live cells (rule 2 when finite, rule 4 otherwise). `.vcov` is attached
  from `v_all`; on the replicate route `v_all` is `NULL`, as before.
- Task 5: the `.degf_taylor()` roxygen block (`@noRd`) names the three
  things it reads and says a caller may pass only those columns. The
  `.taylor_mean_cell()` `@param design` line now says the nonprob SRS route
  goes to `.calibrated_mean_cell()`.

## Tests added (test-spec row ids)

All ten written and run on the unchanged code first; all passed there.
Base probe: no 5.1 row raises a warning (grouped call and both ungrouped
calls), so none is wrapped beyond the plan's own 5.1.10 wrapper (D18).

| Row | Block | Assertion |
|---|---|---|
| 5.1.1 | "...another group has an NA and na.rm = FALSE" | `expect_groups_match_domain("means/tay_y1_na", "tay", ...)` |
| 5.1.2 | "..., calibrated design" | `means/cal_y1_na`, `cal` |
| 5.1.3 | "..., two-stage design with FPC" | `means/multi_y1_na`, `multi` |
| 5.1.4 | "...another group has an Inf" | `means/tay_y1_inf`, `tay` |
| 5.1.10 | "get_means() keeps a stored variance that differs from se^2 ..." | inside `expect_warning_count(..., character(0), 0L)`; finite `se`, `.vcov[i, i]` not equal to `se^2` |
| 5.2.5 | "get_means() errors when x is NA in a cell with na.rm = FALSE on a replicate design" | dual, `surveycore_error_all_replicates_na` |
| 5.3.2 | "get_means() errors on a single-PSU stratum when lonely.psu is fail" | dual, `surveycore_error_lonely_psu` |
| 5.3.8 | "... when lonely.psu is an unknown value" | dual, `surveycore_error_lonely_psu_unknown_option` |
| 5.5.5 | "grouped get_means() still errors when a base weight is Inf" | `simpleError`, no snapshot |
| 5.5.8 | "get_means() still errors on a calibrated design when x is Inf" | `simpleError`, no snapshot |

5.2.7 adds no block: `means/np_rep_y1_na` passes in the noisy block (1 x
`domain_replicates_na`, as recorded), and `means/rep_y1_inf` and
`means/np_rep_y1_inf` pass in the quiet block. Base probe: both `Inf` ids
raise no warning.

Base-commit condition classes (scratch session, `tryCatch()`):

| Row | Class | Message |
|---|---|---|
| 5.2.5 | `surveycore_error_all_replicates_na` | "All replicates produced NA estimates." |
| 5.3.2 | `surveycore_error_lonely_psu` | "Stratum 6 has only one PSU at stage 1." |
| 5.3.8 | `surveycore_error_lonely_psu_unknown_option` | "Unknown `lonely.psu` value: "unknown_value"." |
| 5.5.5 | `simpleError error condition` | "missing value where TRUE/FALSE needed" |
| 5.5.8 | `simpleError error condition` | "NA/NaN/Inf in foreign function call (arg 5)" |

## Snapshot entries added (3)

Recorded on the unchanged code; additions only. After the `R/` change the
file is byte-identical (`cmp`) to the copy taken after task 1, and stays LF.

| Row | Message |
|---|---|
| 5.2.5 | Error in `.svy_rep_var()`: "All replicates produced NA estimates." |
| 5.3.2 | Error in `.svy_onestrat()`: "Stratum 6 has only one PSU at stage 1." |
| 5.3.8 | Error in `.svy_onestrat()`: "Unknown `lonely.psu` value: "unknown_value"." |

## Call counts (criterion 5; scratch session, `trace()` counters reset with `ls(all.names = TRUE)`)

`.build_cluster_matrices()` / `.svy_recvar()` / `.degf_taylor()`:

| Scenario | Before | After |
|---|---|---|
| `means/tay` | 4 / 4 / 3 | 1 / 1 / 0 |
| `means/tay_ungrouped` | 2 / 2 / 1 | 1 / 1 / 0 |
| `means/rep_na` | 0 / 0 / 0 | 0 / 0 / 0 |
| `means/cal` | 4 / 4 / 3 | 1 / 1 / 3 |
| `means/cal_multi` | 4 / 4 / 3 | 1 / 1 / 3 |
| `quantiles/tay` | 9 / 9 / 12 | 9 / 9 / 3 |
| `effn/tay` | 4 / 4 / 3 | 1 / 1 / 0 |

The four criterion 5 values match. The calibrated ids keep one
`.degf_taylor()` call per cell, as §V says. `get_quantiles()` keeps its own
per-cell matrices and variance calls (its call is unchanged) and loses its
nine `.degf_taylor()` calls through `.mean_cell()`.

## Test runs (`NOT_CRAN=true`, `devtools::load_all()` + `testthat::test_file()`)

Equivalence file:

| Code | Blocks | Expectations | Failed | Warnings |
|---|---|---|---|---|
| base + new blocks, 1st run | 51 | 2923 | 0 | 3 (the three "Adding new snapshot" notices) |
| base + new blocks, 2nd run | 51 | 2920 | 0 | 0 |
| changed | 51 | 2920 | 0 | 0 |

Other files, each run on a `git archive HEAD` copy (base) and on the
changed tree. Every figure is identical on the two trees:

| File | Blocks | Expectations | Failed | Warnings | Skipped |
|---|---|---|---|---|---|
| `test-analysis-means.R` | 80 | 348 | 0 | 20 | 0 |
| `test-analysis-quantiles.R` | 86 | 435 | 0 | 7 | 0 |
| `test-effective-n.R` | 39 | 200 | 4 | 6 | 0 |
| `test-calibration.R` | 69 | 172 | 0 | 0 | 0 |
| `test-analysis-methods-coef-vcov.R` | 128 | 341 | 0 | 0 | 0 |
| `test-nonprob-bootstrap-variance.R` | 27 | 85 | 0 | 3 | 0 |
| `test-labelled-analysis.R` | 52 | 236 | 0 | 0 | 0 |
| `test-edge-conditions.R` | 28 | 39 | 0 | 2 | 1 |
| `test-variance-replicate.R` | 51 | 348 | 0 | 1 | 0 |

The 4 `test-effective-n.R` failures are the four print-method snapshot
blocks, and they fail on the base tree too (E-4). The full suite was not
run (the D21 baseline of 254 is the leader's gate).

## Break-it check

Each break applied alone (byte-level substitution), the equivalence file
run, then the file restored from a byte copy. After the last restore `cmp`
passes for all three `R/` files, the test file and the snapshot file, and
`git diff --stat` equals `git diff --ignore-cr-at-eol --stat` (5 files, 347
insertions, 61 deletions, before the `DESCRIPTION` bump).

| Break | Result |
|---|---|
| B1 SE step writes `se * (1 + 1e-9)` | RED: means quiet golden (30), noisy golden (3), quantiles/effn (1) |
| B2 SE step reads the stacked diagonal for every live cell (no finite check, no rule 4) | RED: 5.1.1, 5.1.2, 5.1.3, 5.1.4 (2 each), 5.1.10 (2), means quiet golden (4) |
| B3 replicate totals from a subset sum over domain rows | RED: means quiet golden (2) |
| B4 df frame narrowed to the ids column only | RED: 3 blocks error (means quiet golden, quantiles/effn, 5.1.2) |
| B5 `get_means()` passes `compute_se = TRUE` | GREEN: see E-3 |
| B6 Taylor SE step removed | RED: means quiet (49), noisy (3), quantiles/effn (1), 5.1.10 (1), and the cross-function row "a call that errors under lonely.psu fail raises no small-cell warning" (1). 5.3.2 and 5.3.8 stay green: the abort then fires in `.attach_joint_vcov()` |

Flush paths: PR 6 adds no flush buffer and no subset-sum path; the SE step
is one post-loop call that passes `v`. So D23/D25 (no scenario puts an
`na.rm = FALSE` override cell into a full block of 64) is unchanged by this
PR: it still concerns `get_variance()` and `get_covariance()` only.

## Errata

- **E-1 (test-spec row 5.1.10 note).** The note says that on an
  uncalibrated design "the stored diagonal is finite but rescaled". On the
  base commit `means/tay_y1_na` gives `se^2` 0.5283716 for group A and a
  `.vcov[A, A]` of `Inf`. The row asserts only "differs from `se^2`", so it
  passes; the note is wrong about the value.
- **E-2 (DRY, engineering preference 1).** The Taylor SE step (`v_all`,
  `kinds`, `live`, `vals`, `.taylor_cell_se(..., v = ...)`) is now the same
  13 lines in `get_freqs()` and `get_means()`, and PR 7 adds a third copy
  in `get_totals()`. A shared helper in `R/analysis-helpers.R`, for example
  `.taylor_se_step(design, acc_joint, acc_se, ctx)` returning `se` and `v`,
  would take all three. `R/analysis-freqs.R` is outside PR 6's Files
  touched, so I did not extract it. Leader's choice: extract in PR 7 (which
  touches the third copy) with a one-line edit to `R/analysis-freqs.R`, or
  accept the copies as the spec writes the step per function. Likewise the
  calibration predicate `!is.null(design@calibration) &&
  length(design@calibration) > 0L` now appears in four places
  (`R/calibration.R` twice, `R/analysis-means.R`, and the new cell
  branch); a `.has_calibration()` would live in `R/calibration.R`, outside
  Files touched.
- **E-3 (D23 family).** B5 stays green: a `get_means()` that keeps each
  cell's own variance call gives the same results, because the SE step
  overwrites the cell's SE. Only the criterion 5 call counts see it. Gate 6
  coverage does not, because `get_quantiles()` reaches the
  `compute_se = TRUE` branch. Same shape as PR 4 E-5.
- **E-4 (pre-existing, not this PR).** `test-effective-n.R` fails its four
  print-method snapshot blocks under `testthat::test_file()` on the base
  tree and on the changed tree alike, and writes
  `tests/testthat/_snaps/effective-n.new.md` [no such file]: the committed snapshot holds
  two header lines per print and the run prints one. I deleted the `.new.md` [no such file]
  file. The leader's full `devtools::test()` gate may not show it; I did
  not investigate.
- **E-5 (minor, title length).** Eight of the ten new `test_that()` titles
  pass 80 columns; the plan fixes the titles (PR 3 F-7, PR 4 N-5, PR 5
  E-5). `air` passes.
- **E-6 (D26).** My `devtools::document()` check bumped
  `Config/roxygen2/version` to 8.1.1. Left in the tree for its `chore:`
  commit, per D26.
- **E-7 (plan task 2).** The brief forbids commits. Ship as PRs 3 to 5 did:
  tests and `_snaps/` in the first commit, `R/` in the second.
- Rows 5.5.5 and 5.5.8 raise `simpleError` on the base commit; the PR
  description quotes it (table above).

## Hand-written additions (not dictated by the plan)

- The cell builds its return list without `df`, then `out$df <- df_final`
  (a `NULL` adds no element) and `out$joint <- ...`, so a calibrated cell
  keeps the base element order.
- The calibrated predicate in the cell omits `S7_inherits(design,
  survey_taylor)`: `.taylor_mean_cell()` is reached only through the
  `survey_taylor` branch of `.mean_cell()`.
- `.get_calibration_df_reduction()` is called inside the calibrated branch only
  (it returns 0 otherwise and has no side effect).
- `as.numeric()` on both `crossprod()` columns, to drop the replicate names
  `crossprod()` puts on the rows.
- Comments: the call-context and SE-step comments in `get_means()` (the
  SE-step text matches `get_freqs()`), the merged-product comment with the
  BLAS warning of §III.2, the df comment, the `@param` lines of the three
  changed helpers, and a two-caller note on `.mean_cell()`.
- In 5.5.8, a comment naming the `qr.resid()` abort; in 5.5.5 and 5.5.8,
  the no-snapshot comment of PRs 3 to 5.
