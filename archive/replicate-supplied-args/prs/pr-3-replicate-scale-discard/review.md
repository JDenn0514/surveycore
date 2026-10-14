# Review — PR 3 — replicate-scale-discard

**Verdict**: PASS
**Date**: 2026-10-13 10:00

Branch `fix/replicate-scale-discard`, HEAD `56caab0`, tree `fb291a3`
(`git rev-parse 'HEAD^{tree}'` equals the audit's `Tree:` line). Diff against
`origin/develop` `0d2faa2`. No comprehension.md exists, so Step 6 does not
apply.

## Convergence checks

- Spec coverage: y. PR 3 carries spec §III step 9, the `"scale"` half only.
  - `R/core-constructors.R`: one hunk, +36 lines at 963-998, inside
    `as_survey_replicate()`. It sits after the Fay/`rho` step (905-961) and
    before the `if (is.null(scale))` default `switch()` (1002), as step 9
    requires.
  - The condition is the spec's code, line for line:
    `.replicate_ignores_scale(type) && !identical(type, "Fay") && !is.null(scale)`.
  - The three bullets of the `cli::cli_warn()` match the spec §III "Warnings"
    template and register row RS-1 in `plans/error-messages.md` (line 608)
    character for character, plural markers included. `n_ignored` is
    `length(ignored)`. The class is `surveycore_warning_replicate_arg_ignored`.
  - After the warning, `scale <- NULL` when `"scale"` is in `ignored`, so the
    `switch()` stores the type's own value. The `"rscales"` condition is
    absent, as the plan assigns it to PR 4.
  - All 12 rows of the PR 3 budget (5.1, 5.2, 5.3, 5.4, 5.6, 5.10, 5.12,
    5.13, 5.20, 5.24, 5.25, 5.28) and criteria 1 to 8 have rows in the audit
    table.
- Test coverage of spec: y for this PR's scope. Every scale edge case in
  spec §III "Edge cases" has a row: R = 1 (5.24), explicit `NULL` (5.13),
  value equal to the default (5.3), non-numeric (5.4), `NA_real_`, `Inf`,
  `-1`, `0` and a length-R vector (5.28), Fay with a supplied scale (5.2,
  5.28b), all-`NA` outcome (5.25). The "Equality property" of §III "Returns"
  is pinned by `expect_identical(d@variables, d_plain@variables)` in 5.1 and
  5.28. The two-warning orderings (5.23 and the JK2/ACS/SD triple) are PR 6
  rows.
- Tolerance integrity: y. A parse of the 11 new blocks (`getParseData()`
  walk, not `grep`) finds 9 `expect_equal()` call sites. All 9 carry
  `tolerance = 1e-8`, the test-spec §11 value for a stored scale. None uses
  the testthat default. The audit reports 1e-8 on every numeric row.
- Scope discipline: y. `git diff --name-only origin/develop...HEAD` lists the
  three Files touched plus two `plans/` paths from leader commit `e759983`,
  which G9 allows. No `.surveycore-workspace/` path. The implementation.md
  write surface equals the plan's list. No other function in
  `R/core-constructors.R` changed.
- Regression safety: y. Full suite `FAIL 0 | WARN 256 | SKIP 4 | PASS 12509`
  against develop's 12375. The +134 equals the sum of the 11 new blocks. The
  test file diff is 338 added lines and 0 removed, so no existing block
  changed. The existing Fay block (line 1514) is unchanged and passes.

Further checks:

- Block titles equal the plan's task titles, and none carries a row id.
- Banned calls in the new blocks (`suppressWarnings`, `expect_failure`,
  `withCallingHandlers`, `tryCatch`, `test_invariants`): 0 each, by parse.
- G8: `_snaps/constructors.md` gains one entry (+11 lines, 0 removed). The
  entry shows the singular text the spec renders for BRR.
- G10: tester compared the `as_survey_nonprob()` expression text by parse;
  identical.
- CRAN cookbook: "None", and audit verdict is PASS. No profile gate was
  skipped. pkgdown ran.
- `R CMD check`: `Status: 1 NOTE` in `gate-5-00check.log`; the note is
  `checking CRAN incoming feasibility`.
- Coverage: 96.18% (develop 96.17%). Uncovered lines in
  `R/core-constructors.R` are 414, 2062 and 2153 (`gate-7-covr.log`). None
  is in the added hunk 963-998.
- air: `R/core-constructors.R` is clean. The pre-existing failures in
  `test-constructors.R` start at line 3853, outside the added lines
  1650-1986.

## Carried-forward items

1. PR 1's comments in `R/utils.R` (1205-1206, 1214-1215) and
   `R/methods-conversion.R` (378-379) name `as_survey_replicate()` as a
   caller of both predicates. This PR makes the claim true for
   `.replicate_ignores_scale()`: it is called at `R/core-constructors.R:972`.
   It stays false for `.replicate_ignores_rscales()`, which has one caller
   (`R/methods-conversion.R:386`) until PR 4.
2. This PR makes no sentence of `?as_survey_replicate` false. The `@param
   scale` default paragraph, the Fay paragraph, the JK2 paragraph ("survey
   forces both") and the "Pass `scale` explicitly ... `JKn` ... `bootstrap`"
   sentence all stay true. The help page is silent on the new discard and
   its warning for BRR, JK2, ACS and successive-difference until PR 6 adds
   roxygen facts 1, 2, 4 and 5 of spec §III. The `rscales = NULL` sentence
   at line 639 is still false from PR 2; PR 6 removes it.

## Cross-consistency notes

- Rows 5.4 and 5.28 name BRR only in test-spec. The blocks cover all four
  warning types, per plan tasks 3 and 5. The audit records this. Superset,
  no finding.
- Row 5.12 says "no `scale`, no `rscales`". The block passes `rscales = NULL`
  and `rho = NULL` as written-out arguments for the types that do not need
  them. Spec §III makes explicit `NULL` the same as not supplied, and the
  `d_plain` builds in 5.1 and 5.28 cover the omitted form for the four
  discarding types. Non-blocking.
- `vignettes/creating-survey-objects.Rmd` 347-349 says to override `scale`
  and `rscales` "only when your codebook's technical documentation specifies
  custom values". After this PR an override of `scale` for four types is
  ignored with a warning. The sentence is incomplete, not false. Spec §I
  excludes vignettes (decisions.md L5-3). Non-blocking; a candidate for PR 6
  or a follow-up.

## Decision

The implementation is spec §III step 9 (scale half) word for word, every
budget row is validated in the audit at the test-spec tolerance, the write
surface equals the plan, and all gates hold with no new warning, no new note
and no uncovered added line. PASS.
