PASS

# Review — PR 4: `refactor/analysis-cell-freqs`

**Reviewer**: opus, 2026-11-12. Diff reviewed: `git diff origin/develop...HEAD`
at `223b688` (commits `13afc55` tests and snapshots, `223b688` `R/`; plus the
two leader `docs:` commits `c9d84d7`, `f05a9f9` under `plans/`, outside Files
touched by D22).

No FIX-BEFORE-MERGE finding. Five NOTEs.

## Findings

**N-1 NOTE (`tests/testthat/test-analysis-freqs.R:2048`, builder E-3).** The
existing direct call `.freq_cell(list(fake = TRUE), c(1, 0), c(1, 1))` passes
3 of the 5 required arguments. It passes because the unsupported-class branch
never reads `ctx` or `rep_N_d` (lazy evaluation). If a later edit makes the
dispatcher read `ctx` before the class branches, this test fails with a
missing-argument error, not the class error. Gate 9 forbids editing the file
in this PR, so leave it.

**N-2 NOTE (`R/analysis-freqs-helpers.R:189-195`, `R/analysis-helpers.R:1321`,
builder E-5, my break R4).** The subset sum and `check_rep_finite` change speed
only. Two breaks stay green on every test: `get_freqs()` passing
`check_rep_finite = FALSE` (builder B6) and the `.cell_context()` default
flipped to `TRUE` (my R4). Gate 6 catches the first, because the `TRUE` branch
of `.freq_rep_total()` goes uncovered. Nothing catches the second; it only adds
one pass over `rep_mat` in the five other functions. Same shape as D23.

**N-3 NOTE (`R/analysis-freqs-helpers.R:29`, builder E-1).** `mats` is a
required argument of `.taylor_freq_cell()` that the body never reads. The
spec (§II.3) writes it so. Same as PR 3 E-1.

**N-4 NOTE (`R/analysis-helpers.R:1369-1372`, builder E-4).** The path "not
`ok` and `v` supplied" has no public-API trigger: spec §IV says no
`get_freqs()` input fails the finite check (an `NA` or `Inf` base weight
aborts first, §X.3). The code ignores `v` there, as rule 4 requires. Rule 4's
lines are covered by `get_variance()`.

**N-5 NOTE (`tests/testthat/test-analysis-cell-equivalence.R:375, 398, 405`).**
Three new `test_that()` titles exceed 80 columns. The plan fixes the titles,
`air` does not wrap strings, and `develop` already has 26 lines over 80 in this
file. Not a blocker.

## Tasks and acceptance criteria

| Item | Result |
|---|---|
| Task 1 / AC 1, 2 | Five blocks present with the plan's titles, calls and classes. 5.2.4, 5.3.1, 5.3.7, 5.7.2 dual; 5.5.3 `simpleError`, no snapshot, with a comment. The builder recorded the base class `simpleError` for the PR description. |
| Task 2 / AC 3 | `13afc55` holds only the test file and `_snaps/`; `223b688` holds only `R/`. Leader ran the criterion 4 commands. Four snapshot entries, all appended; no existing entry changed. |
| Task 3 / AC 5 | `freqs/tay` 16/16 → 1/1; `freqs/rep` 0/0 → 0/0 (builder, with the E-6 counter fix). Code reading agrees: one `.build_cluster_matrices()` in `.cell_context()`, one `.svy_recvar()` in `.joint_vcov()`, rule 2 makes no call. |
| Task 4 / AC 6 | `.cell_context(design, check_rep_finite = FALSE)` and `.taylor_cell_se(vals, mats, lonely.psu, v = NULL)` match §II.2. Rule 2 sits before rule 3 and strips names. `.joint_vcov(…, mats = NULL)` and `.attach_joint_vcov(…, v = NULL)` match §III.3; the zero-row early return comes before any read of `v`. The comment at `R/analysis-helpers.R:1209-1215` names both conditions (finite columns; exact arithmetic only). |
| Task 5 | §II.3 signatures exact. `ctx` built with `check_rep_finite = TRUE` before the loop; `rep_N_d` once per variable and combination; SE step after the loop and before the small-cell warning; `.vcov` from `v_all`. §III.5 forms exact, no `colSums()`. |
| AC 4 | Golden blocks pass (gate 2: FAIL 0). |
| AC 7 / G | Gates: tests `[FAIL 0 | WARN 254 | SKIP 4 | PASS 16674]` = D21 baseline; check `Status: 1 NOTE` in both logs (CRAN incoming); covr 96.64%. The 20 UNCOVERED_LINE entries in `gate-7-covr.log` hold no added line: `R/analysis-freqs-helpers.R:293, 303` are in the two-phase/calibrated cells, `R/analysis-freqs.R:474` is unchanged code. So rule 2 (`:1370`) and both branches of `.freq_rep_total()` (`:191-192`, `:194`) are reached. |
| Gate 9 | Paths: the three `R/` files, the test file, the snapshot file, plus D22's `plans/` bookkeeping. No `.surveycore-workspace/` path, no fixture `.rds`, no pre-PR-1 test file modified. `DESCRIPTION` revert held (not in diff). |
| Code style | `::`-free internal code, `<-`, `drop = FALSE`, `.`-prefixed helper, `S7_inherits()` with class objects. `.freq_rep_total()` sits in the freqs helper file, its only users are there: correct placement. No new condition, so no class to add. |

## Results cannot move

- **Taylor SE.** Base: per cell `sqrt(max(0, .svy_recvar(infl)[1, 1]))` on the
  post-calibration column. New: the same column (`.joint_infl(infl_mat)` is
  taken after `.maybe_apply_calibration()`), stacked; `diag()` of the stacked
  call equals the one-column result for finite columns (§III.3). `pmax(0, NaN)`
  and `max(0, NaN)` both give `NaN`.
- **Live set.** `get_freqs()` uses `kinds == "infl"`; `.joint_vcov()` uses
  `kinds != "na"`. On the Taylor route the kinds are only `"infl"` and `"na"`,
  so the two sets agree and `v_all[live, live]` is the right block.
- **Zero cells.** `acc_joint` empty: `.joint_vcov()` returns a 0 x 0 matrix
  with no variance call, `any(live)` is `FALSE`, `.attach_joint_vcov()`
  returns early. No live cell (all `"na"`): no variance call, as base.
- **Empty domain, zero-weight rows, single-level groups.** The cell's
  `n_g == 0 || N_d <= 0` early return is unchanged and gives kind `"na"`.
  `rep_N_d` now runs for such a combination too; it raises nothing and is not
  returned.
- **lonely.psu.** `.joint_vcov()` reads the option itself, `ctx$lonely.psu`
  reads it once; same value. The abort moves from the first live cell to the
  SE step, which §III.4 and §X.1 accept (later `all_na_freqs` / `all_na`
  conditions now come first). The four snapshots did not move.
- **Replicate NA handling.** `rep_finite` is `TRUE` only when every replicate
  weight is finite, so the subset sum drops exact zeros only. Otherwise the
  full products run, as base. `rep_N_d` and `rep_Y` share one helper, so they
  always use the same form. Empty `idx` gives `rep(1, 0) %*% rep_mat[0, ]` =
  zeros, equal to the full product.
- **`.vcov`.** Taylor: `v_all` is the matrix base computed in
  `.attach_joint_vcov()` (same columns, same order, same `mats`), with
  dimnames set afterward. Replicate, two-phase, nonprob SRS: `v_all` is
  `NULL`, so `.attach_joint_vcov()` behaves as base.
- **PR 3's `get_variance()`.** It calls `.cell_context(design)` (default
  `FALSE`; it never reads `rep_finite`) and `.taylor_cell_se(vals, mats,
  lonely.psu)` with no `v`, so rule 3 runs as in PR 3
  (`R/analysis-variance-helpers.R:547`, `R/analysis-variance.R:259`).

## Erratum assessment

| Erratum | Agree? | Note |
|---|---|---|
| E-1 | Yes | N-3. |
| E-2 | Yes | Commit split matches PR 3's; criterion 3 passes. |
| E-3 | Yes | N-1. |
| E-4 | Yes | N-4. |
| E-5 | Yes | N-2. Coverage is the only guard, and gate 7's list confirms the `TRUE` branch is reached. My R4 adds a second invisible break. |
| E-6 | Yes | Method only. |

## Break-it results (mine; targets the builder did not break)

Each break applied alone with `sed`, the named files run with
`devtools::load_all(); testthat::test_file()` (one R process at a time), then
restored with `git checkout --` on the file and `tests/testthat/_snaps`.

| Break | Files run | Result |
|---|---|---|
| R1 replicate domain mask: `rep_N_d` from `as.numeric(domain_mask)` in place of `denom` (`R/analysis-freqs.R:357`) | equivalence | RED: 8 expectations, freqs quiet golden |
| R2 `.vcov` order: pass `v_all` with rows and columns reversed (`R/analysis-freqs.R:531`) | equivalence; `test-analysis-methods-coef-vcov.R` | RED: 23 expectations in both freqs golden blocks; 6 in 5 vcov blocks, including three `survey` oracles and the diag = se^2 block |
| R3 full product zeroes non-finite replicate weights (`R/analysis-freqs-helpers.R:194`) | equivalence | RED: 8 expectations in 3 blocks, including row 5.2.4 |
| R4 `.cell_context()` default `check_rep_finite = TRUE` (`R/analysis-helpers.R:1321`) | equivalence | GREEN, as expected: speed only (N-2) |

After the last restore: `git status --short` lists only the untracked
`plans/proposal-slim-pipeline.md`; `git diff --ignore-cr-at-eol --stat` and
`git diff --stat` are both empty.

## Blind tester comparison

A blind tester with only `test-spec.md` and the gates would check the five
rows, the snapshot set, the warning count and coverage. It would reach the
same PASS. It would not see N-1 to N-4: they need the spec or the code. It
would not run R1 to R4, so it would not learn that the `.cell_context()`
default is unguarded (R4). The reverse also holds: the tester's rule-by-rule
gate reading has nothing I lacked here, because the leader's gate summary
and logs were given to me and I re-read the coverage list myself. Neither
role could catch a platform difference (D19 shape) with Windows-only gates;
CI is still the only guard for that.
