# Audit — PR 2 — replicate-jkn-rscales-required

**Verdict**: PASS
**Date**: 2026-10-07

Branch `fix/replicate-jkn-rscales-required`, HEAD `c5d7621`, tree
`da29423`, base `origin/develop` `9e9f09e` (holds PR 1, #311). The branch
also carries `f2aba10`, a `plans/` commit by the leader. That commit is not
builder scope.

## Per-Test Result Table

Fixture F1 = `make_survey_data(n = 200, n_psu = 20, n_strata = 4, design =
"replicate", type = "jk1", seed = 15)`, R = 20. Both new blocks build F1
exactly as `test-spec.md` §4 gives it. The blocks were run with
`testthat::test_file()` under `NOT_CRAN=true`, so the snapshot comparison
was active. Afterwards the tree was clean (`git status` empty).

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 5.16 JKn, no `rscales`: condition class | `surveycore_error_stratified_jk_rscales_unset` | same | exact | ✓ |
| 5.16 dual pattern: `expect_error(class =)` plus `expect_snapshot(error = TRUE)` on the same call | both present; 2 expectations, 0 failed, not skipped | both | — | ✓ |
| 5.16 snapshot entry: three bullets | "`type = \"JKn\"` requires `rscales`.", "JKn replicate weights are combined weights ...", "Pass `rscales` with one entry per replicate column ..." | the three openings of AC-1 | exact | ✓ |
| 5.18 JKn, no `rscales`, `rho = 0.3` | error of the class above; no warning | `expect_no_warning(expect_error(..., class =))` | exact | ✓ |
| 5.26 (task 5) existing `as_survey_nonprob()` blocks for JK2 and JKn with `rscales = NULL` | 2 + 2 expectations, 0 failed; snapshots matched | pass, snapshots unchanged | exact | ✓ |
| T1 "JKn and bootstrap defaults rise by R/(R-1)" | JKn call gains `rscales = rep(1, n_rep)` only; 11 expectations, 0 failed | as T1 | — | ✓ |
| T2 "scale at one and two replicate columns" | one-column JKn call gains `rscales = 1` only; 5, 0 failed | as T2 | — | ✓ |
| T3 "stores an explicit scale verbatim" | JKn call gains `rscales = rep(1, n_rep)` only; 2, 0 failed | as T3 | — | ✓ |
| T4 "JKn with rscales = NULL stores scale = 1" | absent at HEAD (parse-based title list: the only title removed) | deleted | — | ✓ |
| T5 "stores both changed defaults on a two-row frame" | JKn call gains `rscales = rep(1, n_rep)`, with `n_rep <- 20L` in the block; 6, 0 failed | `rep(1, 20)` | — | ✓ |
| T6 "stores the default scale of all nine types, Fay with rho" | helper gains `rscales = NULL` and passes it on; JKn line is `expect_equal(stored("JKn", rscales = rep(1, 20)), 1)`; 10, 0 failed | as T6 | — | ✓ |
| T7 "warns and discards rho for the eight other types" | both loop calls gain `rscales = if (identical(ty, "JKn")) rep(1, 20) else NULL`; 24, 0 failed | as T7 | — | ✓ |
| T8 "stores the rho key for every type" | same JKn-only `rscales`; 17, 0 failed | as T8 | — | ✓ |
| T9 "raises no warning for the eight other types with no rho" | same JKn-only `rscales`; 8, 0 failed | as T9 | — | ✓ |
| T10 "as_survey_twophase() refuses a replicate phase-1 of all nine types" | `rscales = if (identical(rep_type, "JKn")) rep(1, 5) else NULL`; 9, 0 failed | `rep(1, 5)` for JKn | — | ✓ |
| AC-6 removed `expect_` lines | 4: `expect_no_condition(`, `expect_equal(d@variables$scale, 1)`, `expect_null(d@variables$rscales)`, `expect_equal(stored("JKn"), 1)` | 4, those lines | exact | ✓ |
| 5.19 context: "refuses five frames before the scale switch" | 5, 0 failed | still passes | — | ✓ |
| Block titles (parse-based) | develop 308, HEAD 309; removed T4; added the two task 1 and 2 titles; no duplicate titles | −1 +2 | exact | ✓ |
| `test_invariants()` calls added | 0 | 0 (§10) | exact | ✓ |
| Added `suppressWarnings(` / `expect_failure(` code lines in `tests/` | 0 | 0 | exact | ✓ |
| `test-constructors.R` whole file | 892 expectations, 0 failed, 0 errors, 309 blocks | 0 failed | — | ✓ |

Pass delta, develop 12374 to HEAD 12375 (+1): the deleted T4 block carried
3 expectations. The two new blocks carry 2 each (`expect_error` and
`expect_snapshot`; `expect_no_warning` and `expect_error`). The nine
retargeted blocks change only arguments, so their counts hold. The sum is
−3 + 4 = +1, the gate's figure. SKIP stays at 4 on both sides.

## Before/After Comparison

Before = dispatch baseline (develop after PR 1). After = leader's gate run
on tree `da29423`.

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 12374 | 12375 | +1 |
| test failures | 0 | 0 | 0 |
| test warnings | 256 | 256 | 0 |
| test skips | 4 | 4 | 0 |
| coverage | 96.17% | 96.17% | 0.00 |
| R CMD check notes | 1 (pre-approved) | 1 (`checking CRAN incoming feasibility`) | 0 |

## Profile gates

The leader ran the gates on this tree. This audit did not re-run them, as
the dispatch directs. The `Status:` line, the test summary and the coverage
lines were read in the logs under `logs/`.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | wrote nothing |
| devtools::test() | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12375 ]`; 256 = baseline, no new warning |
| devtools::run_examples() | PASS | |
| R CMD build | PASS | |
| R CMD check --as-cran --no-manual | PASS | `Status: 1 NOTE` is in `gate-5-check.log` and `gate-5-00check.log`; the note is `checking CRAN incoming feasibility` (pre-approved) |
| pkgdown | PASS | site finished; one pandoc `[WARNING] Duplicate identifier 'non-probability-samples'` from an article, not a page error; the PR touches no article |
| covr (NOT_CRAN=true) | 96.17% | uncovered in `R/core-constructors.R`: 414, 2026, 2117. Added hunk: 874–898. No added line is uncovered |
| air format --check | PASS (PR files) | `R/core-constructors.R` exit 0. `tests/testthat/test-constructors.R` exits 1, but air rewrites 383 diff lines on develop's copy and 383 on the branch copy, and no rewrite falls in a PR hunk. Pre-existing (archive/svydesign-replicate-bridge D16) |
| Snapshots (G8) | PASS | one entry added to `_snaps/constructors.md`; 0 deleted lines; no other snapshot file in the diff |
| Diff paths (G9) | PASS | no `.surveycore-workspace/` path; `R/core-constructors.R`, `tests/testthat/test-constructors.R`, `tests/testthat/_snaps/constructors.md` are Files touched; the other two are under `plans/` |
| `as_survey_nonprob()` body (G10) | PASS | function source taken from the parse srcref on `origin/develop` and on HEAD: 9063 characters each, `identical()` TRUE |
| CRAN cookbook scan | PASS | none |

Tree: da294236ca366b15b1d630e60ab5ca351d18baa8

## CRAN cookbook violations

None. Scanned the 25 added lines under `R/` for every pattern in
`r-package-profile.md` §CRAN cookbook scan. No `@importFrom` in `R/`.

## Notes

1. Tolerance on T6. The rewritten line
   `expect_equal(stored("JKn", rscales = rep(1, 20)), 1)` has no
   `tolerance =`. This is the pre-existing assertion
   `expect_equal(stored("JKn"), 1)` with one argument added. The plan's task 4
   gives the line verbatim, and AC-6 allows no other change on it. The
   other eight `expect_equal()` lines in that block, and the other
   pre-existing ones in T1 to T5, also carry no `tolerance =` on develop.
   No tolerance moved. The two new blocks contain no `expect_equal()`. The
   reviewer may want a follow-up that adds explicit tolerances to these
   pre-existing lines; it is outside PR 2's closed change list.
2. Line length. The new title "as_survey_replicate() refuses JKn with no
   rscales before the rho warning" puts its `test_that(` line over 80
   columns. The plan fixes the title, air does not wrap strings, and
   neighbouring titles (T5, T7, T9) already exceed 80.
3. Rows 5.17, 5.19 and 5.20 are not in PR 2's budget; they belong to a later
   PR. The empty-frame block that 5.19 names still passes.
