# Review — PR 2 — replicate-jkn-rscales-required

**Verdict**: PASS
**Date**: 2026-10-07 14:45

Branch `fix/replicate-jkn-rscales-required`, HEAD `c5d7621`, tree `da29423`
(`git rev-parse 'HEAD^{tree}'` equals the audit's `Tree:` line). Diff against
`origin/develop` `9e9f09e`. No comprehension.md exists, so Step 6 does not
apply.

## Convergence checks

- Spec coverage: y. PR 2 carries spec §III step 7 and the RS-2 call site.
  - `R/core-constructors.R`: one hunk (+25 lines at 874-898) inside
    `as_survey_replicate()`. It sits after `.validate_rscales(rscales, n_rep)`
    and before the Fay/`rho` step, as step 7 requires. The guard is
    `identical(type, "JKn") && is.null(rscales)`, after `match.arg(type)`
    at line 818.
  - The three bullets match the spec §III "Errors" template character for
    character, and the class is `surveycore_error_stratified_jk_rscales_unset`.
    The new snapshot entry renders all three.
  - Spec edge cases "before step 7": the existing blocks at lines 957 (empty
    frame), 982 (`repweights_empty`) and 1830 (mixed zero weights) build JKn
    with no `rscales` and pin their own classes. They still pass, so the order
    holds. A parse-based scan of the five test files that name `"JKn"` found
    no other JKn call without `rscales` outside the two new blocks. No
    classless `expect_error()` can mask the new refusal.
  - Every PR 2 row (5.16, 5.18, T1 to T10) and criteria 1 to 7 have rows in
    the audit table.
- Test coverage of spec: y for this PR's scope. Step 7 is covered by 5.16
  (dual pattern on F1) and 5.18 (no `rho` warning). The explicit
  `rscales = NULL` form (5.17) and the one-row JKn frame (5.19) are assigned
  to PR 4 in §Row assignment. Both reach the same `is.null()` branch.
- Tolerance integrity: y. The two new blocks contain no `expect_equal()`.
  The retargeted blocks keep their develop assertions unchanged. See note 1
  for the one rewritten line.
- Scope discipline: y. `git diff --name-only origin/develop...HEAD` lists the
  three Files touched plus two `plans/` paths from leader commit `f2aba10`,
  which G9 allows. No `.surveycore-workspace/` path. The implementation.md
  write surface equals the plan's list.
- Regression safety: y. Full suite `FAIL 0 | WARN 256 | SKIP 4 | PASS 12375`
  against develop's 12374. The +1 is -3 (deleted T4 block) +4 (two new blocks
  of 2). Warnings and skips hold. The `as_survey_nonprob()` body is
  byte-identical (G10), and its JKn/JK2 snapshots match.

Further checks:

- AC-6: the removed-`expect_` count is 4, re-run here. Every other changed
  line in the nine retargeted blocks adds `rscales`, the helper formal
  `rscales = NULL`, or a trailing comma.
- Banned-call count over added non-comment test lines: 0, re-run here.
- G8: `_snaps/constructors.md` gains one entry and loses no line.
- CRAN cookbook: "None", and audit verdict is PASS. No profile gate was
  skipped.
- `R CMD check`: `Status: 1 NOTE` in `gate-5-00check.log`. The note is
  `checking CRAN incoming feasibility`.
- Coverage: 96.17%, unchanged from baseline. Uncovered lines in
  `R/core-constructors.R` are 414, 2026 and 2117. None is in the added hunk
  874-898.
- air: `R/core-constructors.R` is clean. `test-constructors.R` fails air
  identically on develop, and no proposed rewrite falls in a PR hunk. This
  follows the archive/svydesign-replicate-bridge D16 precedent.

## Cross-consistency notes

1. Tester note 1, T6 tolerance. Ruling: not a Tolerance Integrity violation.
   The line `expect_equal(stored("JKn", rscales = rep(1, 20)), 1)` is the
   develop line `expect_equal(stored("JKn"), 1)` with one argument added.
   No tolerance was relaxed relative to develop. Plan task 4 gives the line
   word for word, and AC-6 allows no other change. The audit reports the
   tolerance as "—", which is the truth, and does not claim the 1e-8 value.
   The stored value is the switch literal `JKn = 1`, so the comparison is
   exact in practice. The plan is inconsistent here: §How to read requires
   an explicit `tolerance =` on every numeric `expect_equal()`, and task 4
   fixes a line without one. A follow-up could add explicit tolerances to
   the pre-existing `expect_equal()` lines in T1 to T6. That is outside
   PR 2's closed change list.
2. Tester note 2, title length. Ruling: accepted. The plan fixes the 5.18
   title, the `test_that(` line then exceeds 80 columns, and air does not
   wrap strings. T5, T7 and T9 already exceed 80 on develop.
   archive/replicate-oracle-tests S4/S5 is the precedent for a deliberate
   breach that the plan forces.
3. test-spec §8 T4 says "rows 5.16 and 5.17 replace it", but plan task 4
   names the blocks of 5.16 and 5.18. The plan's §Row assignment gives 5.17
   to PR 4. The explicit `rscales = NULL` call is therefore not pinned
   between PR 2 and PR 4. It runs the same `is.null()` branch as 5.16, so
   the gap is small. PR 4's reviewer must confirm that 5.17 lands.
4. Carried from PR 1: comments in `R/utils.R` and `R/methods-conversion.R`
   say that `as_survey_replicate()` calls `.replicate_ignores_scale()` and
   `.replicate_ignores_rscales()`. PR 2 adds neither call, so the statement
   stays untrue until PRs 3 and 4. No action in this PR.
5. `?as_survey_replicate` (`R/core-constructors.R` line 639) still says
   "`rscales = NULL` leaves no jackknife factor". PR 2 makes that false.
   The plan leaves it for PR 6 (§Order and concurrency).

## Decision

PASS. The refusal matches spec §III step 7 and the error template exactly,
in the required position. All 12 budget rows and 7 criteria are met, with
the write surface the plan names. The gates are clean, and no tolerance was
relaxed. The two tester notes are rulings on lines that the plan fixed, not
defects.
