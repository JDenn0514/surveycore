PASS

# Review: PR 8, `refactor/analysis-cell-ratios`

Reviewer: opus, 2026-11-16. Diff: `git diff origin/develop...HEAD -- R tests`,
three commits on `1d78525`: `d520a7e` docs, `68dde6f` test, `6deb376`
refactor. The gates ran on tree `41f0e00`, which is `HEAD^{tree}`.

## Findings

No finding moves a result, a warning or an error. One item is for the PR
description only.

- FIX-BEFORE-MERGE (PR description only, no code). `R/analysis-ratios-helpers.R:155`
  (`joint$value <- joint$value / total_x` under `compute_se = TRUE`) has no
  caller left. It is the old line, re-indented into the new `if`, so the diff
  counts it as added and the gate lists it as unreached. Criterion 7 bullet 1
  says no added line is unreached. List the line in the PR description with
  the three criterion 7 lines, name its branch, and record in `decisions.md`
  that bullet 1 reads "no new logic is unreached". Keep the line (see
  §Line 155).
- FOLLOW-UP (test gap). No test has a negative denominator total in a
  `.vcov` assertion. Break K2 (scale the joint column by `abs(total_x)`)
  stays green in the equivalence file and in `test-analysis-ratios.R`.
  `y1` is `N(50, 10)` in `make_survey_data()`, so no golden id has a negative
  `total_x`. My sweep shows the shipped code is right on 16 negative-total
  calls; nothing would catch a later regression. A row with `x_neg` (one
  group's denominator negated) and a `vcov()` assertion closes it. Not this
  PR's defect: the base had the same gap.
- NOTE. Five new `test_that()` lines run 82 to 112 columns. The plan fixes
  the titles; the file already holds 50 such lines on `develop`; `air`
  does not wrap strings. The house rule is breached by the plan, not by
  the builder. Same as PR 7 E-4.
- NOTE. The new banner `# ── Taylor SE step ──…` is 80 characters (324
  bytes in UTF-32 with the newline). Not a breach.

## Diff against spec §IX, §III.3 and §II.3

- Calls 1 and 2 pass `mats = ctx$mats`, `compute_se = TRUE`,
  `rep_mat = ctx$rep_mat`. The lonely-PSU aborts still fire in call 1, before
  the zero-denominator check (§III.4 row 3). The aborts depend on the design
  only (`R/variance-taylor.R:58-88`), so call 3 cannot raise one that call 1
  did not.
- Call 3, Taylor: `compute_se = !ctx$taylor` is `FALSE`. The projection in
  `.taylor_total_cell()` runs before the `compute_se` branch, so the
  calibrated `qr.resid()` aborts stay in the loop, in the same cell.
- Call 3, replicate: `.replicate_ratio_cell(..., rep_mat = ctx$rep_mat)`.
  The removed `as.matrix()` in the cell equals `ctx$rep_mat`.
- Call 3, nonprob SRS and two-phase: `mats = NULL` (`ctx$mats` is `NULL` off
  Taylor), `compute_se = TRUE`. Three `nonprob_srs_fallback` warnings per
  live cell, unchanged.
- SE step: `live` is the non-`NULL` `acc_infl` positions; blocks of at most
  64; per block one `.taylor_cell_se()` with its own finite check;
  `/ abs(acc_total_x[blk])`; then the signed scaled column into
  `joint$value` and `acc_infl[j] <- list(NULL)`. It runs before the
  small-cell warning, and no condition can rise from it that call 1 did not
  raise first, so the warning order cannot move.
- `.vcov`: `.joint_vcov(design, acc_joint, mats = ctx$mats)` on the scaled
  columns, then `.attach_joint_vcov(..., v = v_all)`. `.attach_joint_vcov()`
  still returns early on zero rows, so a zero-row result stores no matrix,
  as before. With no live cell, `.joint_vcov()` returns the all-`NA` matrix
  without a variance call, as before.
- Every live column is unnamed (`infl_mat[, 1L]`), so `cbind()` gives no
  column names and the SEs carry none.
- The context is built after the single-level warning and the group combos.
  `.build_cluster_matrices()` raises no condition of its own, so a call with
  no live cell (E-4) gains a build and no condition.

## Independent equivalence

`git worktree add` of `origin/develop` in the scratchpad (removed after).
Script `grid.R`, one R process per side, `pkgload::load_all()`, helpers from
`tests/testthat/`. Each call captured value (all attributes, `.vcov` values
and dimnames), warnings (class and message, in order), and error (class and
message). Compared with `identical()`.

- **1664 calls, 1664 identical.**
- 46 distinct designs: 35 golden designs (Taylor, labelled, no-FPC, probs,
  SRS, strata-only, multistage, lonely, five calibrated, eight replicate
  incl. `NA`/`Inf`/zero/all-`NA` replicate weights, two-phase, empty domain,
  `NA` and `Inf` base weights, six `_dom` designs), `gss`, and 10 of my own
  (Taylor, no-FPC, multistage, calibrated, lonely, SRS, replicate, nonprob
  SRS, two-phase, domain), each with added columns: a denominator negated in
  group B, a mixed-sign denominator, groups of 63, 128, 129 and 130 cells,
  `NA` denominators in cells 3, 64 and 65 of 130 (shifts every live position
  across a block edge), `Inf` numerators in block 2 and `NA` in block 3, an
  `Inf` denominator, and a 1e12-scaled numerator.
- 28 calls per design (ratios ungrouped, grouped, default arguments,
  16/64/65 groups, `NA` numerator and denominator with `na.rm` both ways,
  `Inf` in either variable, zero denominator, the all-`NA`-over-zero cell,
  all-`NA` numerator, `NA` group with `na.rm` both ways, two group
  variables, 65-group `NA` and `Inf` and gap ids, single level, decimals,
  small cell; three `get_totals()` calls), plus 13 more on my own designs.
- `survey.lonely.psu` set to remove, adjust, average, certainty, fail and
  `unknown_value` on `lonely`, my lonely design, `multi` and `cal_multi`.
- The set holds 481 errors (157 zero denominator, 156 `simpleError`, 110
  all-replicates-`NA`, 29 lonely PSU, 29 unknown option), 987 `.vcov`
  matrices and 8180 warnings. 14 of 16 negative-denominator calls give a
  negative ratio.

## Criterion 5 counts (`trace()`, my run)

| Scenario | Base build / recvar | HEAD build / recvar |
|---|---|---|
| `ratios/tay_ungrouped` | 4 / 4 | 1 / 4 |
| `ratios/blk65` | 196 / 196 | 1 / 133 |
| `ratios/rep_na` | 0 / 0 | 0 / 0 |
| `ratios/blk64` | 193 / 193 | 1 / 130 |
| `ratios/blk65_na` | 196 / 196 | 1 / 133 |
| `ratios/tay_empty_dom` | 0 / 0 | 1 / 0 (E-4) |
| `ratios/tph`, `ratios/np_srs`, `totals/tay` | unchanged | unchanged |

All agree with the builder's table.

## Criterion 7 unreached lines

Static check of every call site in `R/` and `tests/testthat/`:

- `R/analysis-helpers.R:1245`: `.joint_vcov()` reaches it only from
  `.attach_joint_vcov()` with `v = NULL`, which is off the Taylor route,
  where no joint is kind `"infl"`. Dead.
- `R/analysis-totals-helpers.R:79`: every Taylor `compute_se = TRUE` caller
  (ratios calls 1 and 2) passes `ctx$mats`; `get_totals()` and the ratio
  call 3 pass `compute_se = FALSE`. Dead.
- `R/analysis-totals-helpers.R:156`: every replicate caller passes
  `ctx$rep_mat`. The `.total_cell()` inside `.delta_ratio_cell()` passes no
  `rep_mat` but never runs on the replicate route. Dead.

The only direct test call, `.total_cell(list(fake = TRUE), ...)`, errors
before any branch. The builder's list is right.

## Line 155

`R/analysis-ratios-helpers.R:155` runs only when `compute_se = TRUE` and
`.total_cell()` returns a `joint`. `compute_se = TRUE` reaches only the
nonprob SRS and two-phase routes, and `.calibrated_total_cell()` and
`.twophase_total_cell()` return no `joint`. No caller reaches it.

Keep it. `compute_se` has no default, so any later call with `TRUE` on a
Taylor design gets a real SE. Without line 155 that call would return an
unscaled `joint$value`, and `.vcov` would be off by `total_x^2` with no
error. The line is the old behaviour, moved into a branch. It costs one
uncovered line. A `# nocov` with a comment is allowed by
`testing-standards.md` for a defensive branch unreachable through the
public API; that choice belongs to PR 9 with the other three lines.

## Errata

- E-1 (no shared helper with `.taylor_se_step()`): agree. The ratio step
  passes no `v`, blocks in the caller, divides by `abs(total_x)`, and drops
  each column per block. A shared helper would need a mode flag for all four,
  and the drop must run in `get_ratios()`'s frame to free memory. The two
  calls they share are already helpers. Not a DRY breach.
- E-2 (`is_replicate` replaced by `ctx$replicate`): agree. Same expression
  (`R/analysis-helpers.R:1331-1333`). My K4 shows the predicate matters and
  is guarded.
- E-3 (`mats = ctx$mats, compute_se = !ctx$taylor` in one call site): agree.
  `ctx$mats` is `NULL` off Taylor; `survey_twophase` does not inherit
  `survey_taylor` (counts 0 builds on `ratios/tph`).
- E-4 (one build on calls with no live cell): agree. Speed only; no
  condition, as above.
- E-5 (D23 family): agree. I add K2 below: a sign defect in `.vcov` that
  no test catches (FOLLOW-UP above).
- E-6 (titles): see NOTE. Fact correct.
- E-7 (live set as non-`NULL` `acc_infl`): agree. A cell that reaches call 3
  has a non-`NA` `total_x`, so its domain has `n_d > 0` and `N_d > 0`, and the
  `z` total returns kind `"infl"`.

## Break-it (scratch worktree at HEAD, equivalence file and `test-analysis-ratios.R`, `NOT_CRAN=true`)

| Break | Equivalence file | Ratios file |
|---|---|---|
| K1 SE divided by signed `total_x` (no `abs()`) | GREEN | RED, 9 failures (Taylor and SRS oracle, domain filter) |
| K2 joint column divided by `abs(total_x)` | GREEN | GREEN (FOLLOW-UP) |
| K3 SE step passes `"remove"` for `lonely.psu` | RED, 2 failures (ratios quiet golden) | GREEN |
| K4 dispatch on `survey_replicate` only, so nonprob with replicate weights takes the delta route | RED, 4 failures (ratios quiet and noisy golden) | GREEN |

None overlaps the builder's a to e. The worktree was removed after the
last run.

## Rules

- `R/` files and the test file pass `air format --check`.
- New `expect_equal()`: none outside `expect_groups_match_domain()`, which
  sets `tolerance = 1e-12`.
- Dual pattern on the four surveycore conditions (5.2.6, 5.3.6, 5.3.12,
  5.7.1); class only, with a comment, on the three `simpleError` calls.
- Snapshot commit `68dde6f` holds only the test file and `_snaps/`; the
  refactor commit holds only the two `R/` files. No `DESCRIPTION` change.
- Gates: `[ FAIL 0 | WARN 254 | SKIP 4 | PASS 16750 ]` (254 is the D21
  baseline), `Status: 1 NOTE`, coverage 96.31%.
