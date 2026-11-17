PASS

# Review: PR 7, `refactor/analysis-cell-totals`

Reviewer: opus, 2026-11-16. Diff: `git diff origin/develop...HEAD`, four
commits (`282b4ca` docs, `9b243c2` D28 refactor, `992549e` tests,
`d504bc1` totals refactor). HEAD tree `daad0a4` equals the tree line in
`gates-summary.txt`.

## Findings

No FIX-BEFORE-MERGE finding.

- NOTE (`R/analysis-helpers.R:1467`). A `.taylor_se_step()` that returns
  `v = NULL` on the Taylor route stays green (break K2). `.attach_joint_vcov()`
  then rebuilds the same matrix, so only call counts would show it. This is
  the D23 / PR 6 E-3 shape, and builder E-3 records the totals case. No new
  action.
- NOTE (`tests/testthat/test-analysis-cell-equivalence.R`). Row 5.2.8 calls
  `get_totals()` ungrouped, as the plan task fixes it. Correct as written.
- NOTE. Two added banner lines (`R/analysis-helpers.R:1434`,
  `R/analysis-totals.R:367`) read 82+ bytes; they are 80 characters of
  box-drawing glyphs, the house banner form. Not a breach.

## Write surface and commits

- D28 commit: `R/analysis-helpers.R`, `R/analysis-freqs.R`,
  `R/analysis-means.R` only. Test commit: the test file and `_snaps/` only,
  before any totals change under `R/`. Totals commit:
  `R/analysis-totals.R`, `R/analysis-totals-helpers.R` only. Docs commit:
  three `plans/` files (D22).
- No pre-PR-1 test file and no fixture `.rds` changed. `DESCRIPTION`
  unchanged. `get_ratios()` call sites (`R/analysis-ratios.R:296, 331`,
  `R/analysis-ratios-helpers.R:126`) untouched and positional-only, so the
  new defaults give them the base path.

## D28 extraction

`.taylor_se_step()` (`R/analysis-helpers.R:1451-1468`) is the removed
freqs/means block line for line: `.joint_vcov(design, acc_joint, mats =
ctx$mats)`, `live <- kinds == "infl"`, `.taylor_cell_se(vals, ctx$mats,
ctx$lonely.psu, v = v_all[live, live, drop = FALSE])`. The off-Taylor
early return equals the old `v_all <- NULL` with `acc_se` unchanged. All
three call sites pass `(design, acc_joint, acc_se, ctx)` and read back
`se`/`v`. The header Contents entry is added; the SE-step comment stays at
each call site. `grep` finds no other copy of the block in `R/`. Judgment:
correct and complete.

## Tasks and acceptance criteria

1-3: the seven rows exist with the plan's titles, calls and classes;
dual pattern on 5.2.8, 5.3.3, 5.3.9; `simpleError` with a comment and no
snapshot on 5.5.4, 5.5.6. 4: three snapshot entries, additions only, and
the gate-2 suite passes on the changed code. 5: builder counts, `totals/tay`
1/1, `totals/rep` 0/0. 6: golden blocks pass; the two §III.7 comments are
corrected and both claims are true (`.quantile_woodruff_cell()` calls
`.mean_cell()` at `R/analysis-quantiles-helpers.R:154`; nonprob SRS goes to
`.calibrated_total_cell()`). 7 (G): gates pass, warnings 254 (D21),
`Status: 1 NOTE` (CRAN incoming only), covr 96.66%.

## Results cannot move (independent sweep)

Scratch script, `origin/develop` (via `git archive`) against HEAD, one R
process each: 33 golden designs (Taylor, multi, lonely, four calibrated,
five replicate incl. NA/Inf/zero/all-NA, nonprob rep and SRS, two-phase,
empty domain, NA/Inf weights, six `_dom` designs) x 16 calls (totals: y1
grouped and ungrouped, `y1_na` with `na.rm` both ways, `y1_inf`, categorical
`f5` and `f5_na`, population size, 65 groups, all-NA, NA group, default
`min_cell_n`; plus `get_ratios()`, `get_freqs()`, `get_means()` x2), with
`lonely.psu` remove/adjust/average/certainty/fail on four designs. 784
calls; each result, `.vcov` (dimnames included), warning class and
message in order, and error class and message compared with `identical()`:
784 of 784 identical. The set holds 118 errors, 588 `.vcov` matrices and
369 warnings.

## Errata

E-1 (D28 files) agrees with D28. E-2 holds. E-3 confirmed by my K2. E-4,
E-5 accepted (air passed at gate). E-6 followed: commit order is as
suggested. E-7 is a true pre-existing comment error; the fix is comment
only. The builder's hand-written addition (projection before the optional
`mats` build) cannot move a result: the sweep shows none moved.

## Break-it (equivalence file, `NOT_CRAN=true`, one process each)

| Break | Result |
|---|---|
| K1 off-Taylor branch returns `acc_se * NA` | RED, 6 blocks / 35 expectations (freqs, means, totals quiet and noisy golden) |
| K2 Taylor route returns `v = NULL` | GREEN (see NOTE) |
| K3 drop `drop = FALSE` in `v_all[live, live]` | RED: totals noisy golden, four means self-consistency blocks; `test-analysis-totals.R` 26 erroring blocks |
| K4 `get_totals()` passes `ctx$rep_mat * 1.01` | RED, 2 blocks / 7 expectations (totals quiet and noisy golden) |

Each break restored from a byte copy. After the last restore
`git diff --ignore-cr-at-eol --stat -- R tests` is empty, no `.new.md` [no such file]
exists, and `git status` shows only the other session's three files.

## Blind tester comparison

No tester ran on this PR (slim trial, D17); this review is the single
gate. My break set does not overlap the builder's B1-B5, and the result
agrees with it: every break that changes a number turns red, and the two
perf-only breaks (B4, K2) stay green, guarded only by call counts.
