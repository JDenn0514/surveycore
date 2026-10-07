# Review — PR 1 — replicate-export-ignored-args

**Verdict**: PASS
**Date**: 2026-10-07 12:12

Branch `fix/replicate-export-ignored-args`, HEAD `1650f93`, tree `5fb3cb8`
(confirmed with `git rev-parse 'HEAD^{tree}'`; equals the audit's `Tree:`
line). Diff against `origin/develop` `a9e501b`. No comprehension.md exists;
Step 6 does not apply.

## Convergence checks

- Spec coverage: y. PR 1 carries spec §II "Functions added", §IV and §VI.
  - `R/utils.R`: both predicates match spec §II word for word, comment
    headers included.
  - `R/methods-conversion.R`: `scale_arg` and `rscales_arg` go through the
    predicates, each inside `isTRUE()`, and reach the call as `scale =` and
    `rscales =`. No other argument or step changed (diff hunks 370-390 and
    482 only). The rewritten comment states the three facts §IV lists.
  - `plans/error-messages.md`: the new section is at the end of the file.
    RS-1 and RS-2 match the spec §III templates verbatim. RS-3 matches the
    shipped `as_survey_nonprob()` source (`R/core-constructors.R`
    1692-1704). The FR-3 note sits under the required heading.
  - Every PR 1 row (6.10, 7.2, 7.3, 7.4, T12, 9.1) has rows in the audit
    table, and so does each of the 7 criteria.
- Test coverage of spec: y for this PR's scope. §IV's type table and
  conditions table are covered by 7.1 to 7.4. The §IV edge cases are covered
  as follows:
  - the imported ACS and successive-difference design: row 7.2;
  - a nonprob bootstrap design: the existing block named in task 9;
  - a nonprob JK2 design: out of scope by spec §I;
  - the `NULL` stored type: the task 8 block.
- Tolerance integrity: y. Five new `expect_equal()` calls were written,
  and six run, because one sits in a two-type loop. Each carries
  `tolerance = 1e-8` (SE or scale), which is the test-spec §11 value. No
  call relies on the testthat default. The audit reports the same values.
  No row is looser and no row is tighter.
- Scope discipline: y. `git diff --name-status origin/develop...HEAD`
  lists exactly the nine paths in the plan's PR 1 Files touched. The four
  `plans/*-replicate-supplied-args.md` copies are byte-identical to the
  run-directory artifacts (`diff --strip-trailing-cr`). No path under
  `.surveycore-workspace/` is in the diff, and no commit in the range touches
  one. `R/core-constructors.R`, `_snaps/`, `man/`, `NAMESPACE` and
  `DESCRIPTION` are not in the diff.
- Regression safety: y. The suite went from 12353 to 12374 passes, +21.
  That equals the expectations the five new blocks run: 8 + 4 + 4 + 4 + 1.
  FAIL is 0, SKIP is 4 and WARN is 256 at both baseline and head, so no
  test outside the PR changed state.

## Gates and integrity

- The register commit `49be866` is an ancestor of the first `R/` commit
  `cc98f9b` (`git merge-base --is-ancestor` exit 0).
- No `suppressWarnings(` or `expect_failure(` appears on an added code line
  (count 0). Every line the PR removes from `test-conversion.R` is a comment
  (count 0). `ignore a scale` appears 0 times, `with type ACS scale=` 0
  times, and `only JK2` (any case) 2 times.
- Gate logs: `[ FAIL 0 | WARN 256 | SKIP 4 | PASS 12374 ]`; the check log
  reads `Status: 1 NOTE`, and that note is `checking CRAN incoming
  feasibility`. pkgdown finished. covr is 96.17% against a 96.17% baseline.
  The three uncovered lines in the changed files (methods-conversion.R:635,
  utils.R:377, utils.R:487) are not added lines. Every gate has a result,
  and none was skipped.
- CRAN cookbook: the audit reports none, with a PASS verdict. This is
  consistent.
- The AC-2 red-against-develop evidence is in both artifacts. The builder
  ran it before task 7, and the tester ran it in a worktree.

## Cross-consistency notes

Non-blocking:

1. The predicate headers in `R/utils.R` name `as_survey_replicate()` as a
   call site. The route comment in `R/methods-conversion.R` says the
   predicates are "the sets as_survey_replicate() reads". Both statements
   are false at this head and become true when PR 3 and PR 4 land. The spec
   mandates the header text word for word, and the linear PR order is by
   design. The PR 3/4 reviewer should confirm that the constructor calls
   the predicates.
2. `.claude/rules/code-style.md` keeps a helper inline until a second
   file calls it. PR 1 puts both predicates in `R/utils.R` with one caller,
   as spec D-g and the plan direct. This is a settled decision and is not a
   defect.
3. The audit's "6 of 6" for explicit tolerances counts executed calls (5
   written, one in a two-iteration loop). The figure is consistent.

## Decision

All seven checks are clean. Implementation and audit agree with the spec,
the test-spec and the plan on every PR 1 row and criterion. The tolerances
equal the test-spec values, and the write surface equals the plan. No test
outside the PR changed state, and coverage did not drop.
