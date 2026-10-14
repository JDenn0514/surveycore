# Review — PR 4 — replicate-rscales-discard

**Verdict**: PASS
**Date**: 2026-10-13 10:45

Branch `fix/replicate-rscales-discard`, HEAD `c00b2b7`, tree `d4c69f7`
(`git rev-parse 'HEAD^{tree}'` equals the audit's `Tree:` line). Diff against
`origin/develop` `a2d4759`. No comprehension.md exists, so Step 6 does not
apply.

## Convergence checks

- Spec coverage: y. PR 4 carries the `"rscales"` half of spec §III step 9.
  - `R/core-constructors.R`: three hunks, all inside `as_survey_replicate()`.
    Lines 981-983 add the condition
    `.replicate_ignores_rscales(type) && !is.null(rscales)`, which is the
    spec's code line for line. It follows the `"scale"` condition, so the
    order in `ignored` is `"scale"` then `"rscales"`.
  - Lines 1003-1005 set `rscales <- NULL` inside the warning branch, before
    the `@variables` list at 1045. The design stores `NULL`, as spec §I S2
    and §III "Arguments" require.
  - The warning template (986-999) is unchanged, as task 7 requires. The two
    new snapshot entries show the plural form for JK2 with both arguments and
    the singular form for ACS with `rscales` alone. Both match the texts in
    plan tasks 2 and 3 word for word.
  - The comment at 963-971 now describes the `rscales` discard and states
    that `.validate_rscales()` runs first. It is accurate.
  - All 12 rows of the PR 4 budget (5.5, 5.7, 5.8, 5.9, 5.11, 5.14, 5.15,
    5.17, 5.19, 5.21, 5.27, T11) and criteria 1 to 8 have rows in the audit
    table.
- Test coverage of spec: y for this PR's scope. Every `rscales` edge case in
  spec §III "Edge cases" has a row: wrong length for a discarding type
  (5.14), an `NA` for a discarding type (5.15), BRR and Fay keep a supplied
  `rscales` (5.11), explicit `rscales = NULL` for JKn (5.17), the one-row
  frame before the JKn refusal (5.19). Spec §I S6 (JK2 with no `rscales`
  builds and raises nothing) is row 5.21. The §III "Returns" equality
  property is pinned for `rscales` by `expect_identical(d@variables,
  d_plain@variables)` in 5.5. Row 5.27 pins every member and non-member of
  both discard sets. The `scale` + `rscales` + `rho` triple is a PR 6 row
  (plan note P-3).
- Tolerance integrity: y. A parse of the 11 new blocks (`parse()` and a call
  walk, not `grep`) finds 4 `expect_equal()` call sites. All 4 carry
  `tolerance = 1e-8`, the test-spec §11 value for a stored scale and a
  standard error. None uses the testthat default. The audit reports 1e-8 on
  every numeric row.
- Scope discipline: y. `git diff --name-only origin/develop...HEAD` lists the
  four Files touched plus two `plans/` paths from leader commit `15bb7ef`,
  which G9 allows. No `.surveycore-workspace/` path. The implementation.md
  write surface equals the plan's list. `test-conversion.R` changes one line,
  the `rs <-` line, and no assertion.
- Regression safety: y. Full suite `FAIL 0 | WARN 256 | SKIP 4 | PASS 12580`
  against 12509 after PR 3. The +71 equals the expectation count of the 11
  new blocks, which the audit sums row by row; I checked the sum. The
  `test-constructors.R` diff is 310 added lines and 0 removed, so no
  existing block changed. The warning count holds at 256, so T11 raises no
  new JK2 discard warning.

Further checks:

- Block titles equal the plan's task titles, and none carries a row id.
- Banned calls in the new blocks (`suppressWarnings`, `expect_failure`,
  `withCallingHandlers`, `tryCatch`, `test_invariants`): 0 each, by parse.
- G8: `_snaps/constructors.md` gains two entries (+22 lines, 0 removed).
- G10: the tester compared the `as_survey_nonprob()` body by parse;
  identical.

## Profile gates, CRAN cookbook and coverage

- Gate 5: `gate-5-check.log` line 93 reads `Status: 1 NOTE`; the note is
  `checking CRAN incoming feasibility` (line 14), pre-approved.
- Gate 2: `gate-2-test.log` line 3025, as above.
- Gate 7: `COVERAGE_PCT=96.18`, unchanged and above the 95% floor. The
  uncovered lines in `R/core-constructors.R` are 414, 2071 and 2162, which
  are develop's 414, 2062 and 2153 shifted by +9. No added line (964-971,
  981-983, 1003-1005) is in the list.
- Gates 1, 3, 4 and 6: clean per logs. Gate air: clean on the two files it
  can judge; `test-constructors.R` fails only from line 4163, outside this
  PR's lines 1988-2297. No skip is claimed.
- CRAN cookbook table: None, and the audit verdict is PASS. Consistent.

## Carried-forward items

1. Predicate comments (from PR 1 review): resolved. `R/utils.R` lines
   1214-1215 name `as_survey_replicate()` as a call site of
   `.replicate_ignores_rscales()`, and `R/methods-conversion.R` lines
   378-379 say the two predicates are the sets `as_survey_replicate()` reads.
   With line 981 in place, both comments are now accurate for both
   predicates.
2. Row 5.17 (from PR 2 review): landed. The block "as_survey_replicate()
   refuses JKn with rscales = NULL passed explicitly" (line 2255) passes
   `rscales = NULL` written out and asserts
   `surveycore_error_stratified_jk_rscales_unset`. The audit confirms it
   passes. T4 is gone, so 5.16 and 5.17 now replace it in full.
3. Vignette gap (from PR 3 review): this PR touches no vignette. The gap PR 3
   noted now covers `rscales` too: `vignettes/creating-survey-objects.Rmd`
   lines 347-349 say to override `scale` and `rscales` from the codebook,
   and do not say that JK2, ACS and successive-difference discard a
   supplied `rscales`. Spec §I excludes vignettes. Not blocking; the same
   follow-up as PR 3's note should cover both arguments. Line 550 of the
   same file describes `as_survey_nonprob()`, which this work does not
   change, so it stays accurate.

## Cross-consistency notes

implementation.md and audit.md agree on the write surface, the commits, the
11 blocks, the two snapshot entries and the air result.

Row 5.9 asserts the warning count only, not its class, as test-spec §5
specifies. Row 5.27 asserts the class on the same input, so the class is
pinned elsewhere. No action.

## Decision

PASS. The `rscales` half of step 9 matches the spec code, all 12 budget
rows are present and pass with the test-spec tolerances, the write surface
equals the plan, and every gate is clean with the warning count held at 256
and coverage unchanged at 96.18%.
